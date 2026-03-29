import Foundation
import Cocoa
import Combine

class PermissionMonitor: ObservableObject {
    @Published var permissionState: PermissionState = .unknown

    private var permissionCheckTimer: Timer?
    private var lastKnownPermissionState: Bool = false
    private let checkInterval: TimeInterval = 30.0  // Check every 30 seconds

    func startMonitoring() {
        // Check immediately
        updatePermissionState()

        // Set up periodic checking
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.updatePermissionState()
        }

        // Also check when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    private func updatePermissionState() {
        let hasPermission = AccessibilityPermissions.hasAccessibilityPermission()

        // Only log/update if state changed
        if hasPermission != lastKnownPermissionState {
            print("🔐 Permission state changed: \(hasPermission ? "granted" : "denied")")
            lastKnownPermissionState = hasPermission
            permissionState = hasPermission ? .granted : .denied
        }
    }

    @objc private func appDidBecomeActive() {
        updatePermissionState()
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}
