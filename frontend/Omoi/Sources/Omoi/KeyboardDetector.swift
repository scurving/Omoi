import Foundation
import IOKit
import IOKit.hid
import os.log

// MARK: - KeyboardDetector
//
// Wraps IOHIDManager to maintain a live map of connected keyboards.
// Classifies devices as: built-in (Apple internal), NuPhy, or external.
// Used by KeystrokeMonitor to attribute keystrokes to a specific keyboard source.

final class KeyboardDetector {
    static let shared = KeyboardDetector()

    private let logger = Logger(subsystem: "com.omoi.Omoi", category: "KeyboardDetector")
    private var hidManager: IOHIDManager?
    private var deviceMap: [Int64: KeyboardSource] = [:]  // (vendorID<<16 | productID) -> source
    private let queue = DispatchQueue(label: "com.omoi.keyboard-detector", qos: .utility)

    /// Thread-safe access to connection state
    private let connectionStateLock = NSLock()
    private let deviceMapLock = NSLock()
    private var _hasNuphyConnected = false
    private var _externalKeyboardCount = 0

    var hasNuphyConnected: Bool {
        connectionStateLock.lock()
        defer { connectionStateLock.unlock() }
        return _hasNuphyConnected
    }

    var externalKeyboardCount: Int {
        connectionStateLock.lock()
        defer { connectionStateLock.unlock() }
        return _externalKeyboardCount
    }

    private init() {}

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in
            self?.setupHIDManager()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let manager = self.hidManager {
                IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
                self.hidManager = nil
            }
            self.deviceMap.removeAll()
            self.connectionStateLock.lock()
            self._hasNuphyConnected = false
            self._externalKeyboardCount = 0
            self.connectionStateLock.unlock()
            print("⌨️ [KeyboardDetector] Stopped")
        }
    }

    // MARK: - Classification

    /// Classify a keyboard by its CGEvent keyboard type value.
    /// Uses direct device map if available; falls back to connection state heuristics.
    func classify(keyboardType: Int64) -> KeyboardSource {
        deviceMapLock.lock()
        let source = deviceMap[keyboardType]
        deviceMapLock.unlock()

        if let source = source {
            return source
        }

        // Fallback: if a NuPhy is connected, assume unrecognized keystrokes come from it
        // (CGEvent keyboardType doesn't map to HID vendorID/productID reliably)
        if hasNuphyConnected {
            return .nuphy
        }

        // Can't determine — assume built-in (safest default)
        return .builtin
    }

    /// Classify a keyboard by (vendorID, productID) tuple.
    /// Used when correlating CGEvent tap keyboard types to HID devices.
    func classify(vendorID: Int, productID: Int) -> KeyboardSource {
        let key = Int64(vendorID << 16 | productID)
        if let source = deviceMap[key] {
            return source
        }
        return .external
    }

    // MARK: - HID Manager Setup

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else {
            logger.error("Failed to create IOHIDManager")
            print("❌ [KeyboardDetector] Failed to create IOHIDManager")
            return
        }

        // Match keyboard devices (Generic Desktop / Keyboard usage)
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        // Register callbacks
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            let detector = Unmanaged<KeyboardDetector>.fromOpaque(context).takeUnretainedValue()
            detector.deviceConnected(device)
        }, context)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            let detector = Unmanaged<KeyboardDetector>.fromOpaque(context).takeUnretainedValue()
            detector.deviceDisconnected(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            logger.info("HID Manager started")
            print("✅ [KeyboardDetector] HID Manager started, scanning keyboards...")

            // Process already-connected devices
            if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
                for device in devices {
                    deviceConnected(device)
                }
            }

            // Run loop blocks until stopped
            CFRunLoopRun()
        } else {
            logger.error("Failed to open HID Manager: \(result)")
            print("❌ [KeyboardDetector] Failed to open HID Manager: \(result)")
        }
    }

    // MARK: - Device Callbacks

    private func deviceConnected(_ device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let vendorID   = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID  = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let transport  = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""

        let key = Int64(vendorID << 16 | productID)
        let source = classifyDevice(productName: productName, vendorID: vendorID, transport: transport)

        deviceMapLock.lock()
        deviceMap[key] = source
        deviceMapLock.unlock()
        updateConnectionState()

        print("⌨️ [KeyboardDetector] Connected: \(productName) (vendor: 0x\(String(vendorID, radix: 16)), transport: \(transport)) → \(source.displayName)")
    }

    private func deviceDisconnected(_ device: IOHIDDevice) {
        let vendorID  = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"

        let key = Int64(vendorID << 16 | productID)
        deviceMapLock.lock()
        deviceMap.removeValue(forKey: key)
        deviceMapLock.unlock()
        updateConnectionState()

        print("⌨️ [KeyboardDetector] Disconnected: \(productName)")
    }

    // MARK: - Classification Logic

    private func classifyDevice(productName: String, vendorID: Int, transport: String) -> KeyboardSource {
        let nameLower = productName.lowercased()

        // NuPhy detection: product name contains "nuphy" (case-insensitive)
        if nameLower.contains("nuphy") {
            return .nuphy
        }

        // Apple built-in: vendor 0x05AC OR "Apple Internal" in name, non-Bluetooth transport
        let appleVendorID = 0x05AC
        let isApple = vendorID == appleVendorID || nameLower.contains("apple internal")
        if isApple && transport.lowercased() != "bluetooth" {
            return .builtin
        }

        // Everything else: external
        return .external
    }

    private func updateConnectionState() {
        connectionStateLock.lock()
        defer { connectionStateLock.unlock() }

        _hasNuphyConnected = deviceMap.values.contains(.nuphy)
        _externalKeyboardCount = deviceMap.values.filter { $0 != .builtin }.count
    }
}
