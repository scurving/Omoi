import Foundation
import CoreGraphics
import Cocoa
import os.log

// MARK: - KeystrokeMonitor
//
// Continuous keystroke monitoring via CGEvent tap.
// - Runs on its own background thread, isolated from the audio pipeline
// - Counts keystrokes per app + keyboard, never logs actual key characters
// - Finalizes sessions on: inactivity > 30s, app switch, keyboard switch
// - Emits TypingSession for sustained typing >= 30s (bursts)
// - Always rolls data into HourlyAggregate for dashboard stats
// - All persistence via EncryptedStorageManager (AES-256-GCM + Keychain)

@MainActor
final class KeystrokeMonitor: ObservableObject {
    static let shared = KeystrokeMonitor()

    static let inactivityThreshold: TimeInterval = 2.0
    static let burstThreshold: TimeInterval = 2.0

    @Published private(set) var isRunning = false

    // MARK: - Private State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private let monitorQueue = DispatchQueue(label: "com.omoi.keystroke-monitor", qos: .utility)

    /// Current in-flight typing accumulator (nil when no typing is active)
    private var accumulator: ActiveTypingAccumulator?

    /// Periodic flush timer (EncryptedStorageManager also has its own 60s timer)
    private var flushTimer: Timer?

    /// Inactivity timer — fires when user stops typing for > 30s
    private var inactivityTimer: Timer?

    /// Crash recovery: restart attempts for CGEvent tap
    private var restartAttempts = 0
    private let maxRestartAttempts = 3

    /// Reference to KeyboardDetector (non-@MainActor, thread-safe internally)
    private let keyboardDetector = KeyboardDetector.shared

    /// Reference to encrypted storage
    private let storage = EncryptedStorageManager.shared

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        // Start keyboard detection
        keyboardDetector.start()

        // Kick off CGEvent tap on the background queue
        monitorQueue.async { [weak self] in
            self?.installEventTap()
        }

        // Periodic flush timer (belt-and-suspenders; EncryptedStorageManager also flushes)
        flushTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flush()
            }
        }

        isRunning = true
        print("⌨️ [KeystrokeMonitor] Started")
    }

    func stop() {
        guard isRunning else { return }

        finalizeAccumulator()
        flush()

        flushTimer?.invalidate()
        flushTimer = nil
        inactivityTimer?.invalidate()
        inactivityTimer = nil

        // Clean up event tap directly — CFRunLoop APIs are thread-safe.
        // removeEventTap() calls CFRunLoopStop which unblocks the GCD thread.
        removeEventTap()

        keyboardDetector.stop()
        isRunning = false
        print("⌨️ [KeystrokeMonitor] Stopped")
    }

    // MARK: - CGEvent Tap

    private func installEventTap() {
        let eventMask = 1 << CGEventType.keyDown.rawValue

        // The CGEvent tap callback runs on the Quartz event tap thread.
        // We need to pass a context pointer so we can dispatch back to the
        // MainActor-isolated KeystrokeMonitor safely.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

            // Handle tap re-enabling (macOS can disable taps that misbehave)
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                let monitorPtr = refcon
                let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(monitorPtr).takeUnretainedValue()
                Task { @MainActor in
                    if let tap = monitor.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            // Only handle keyDown events
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            // Skip keyboard shortcuts (Cmd/Ctrl/Option held) — only count actual typing
            let flags = event.flags
            if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
                return Unmanaged.passUnretained(event)
            }

            // Extract keyboard type for device attribution
            let keyboardType = event.getIntegerValueField(.keyboardEventKeyboardType)

            // Get the frontmost app (this is thread-safe on macOS)
            let frontApp = NSWorkspace.shared.frontmostApplication
            let bundleID = frontApp?.bundleIdentifier ?? "unknown"
            let appName = frontApp?.localizedName ?? "Unknown"

            // Extract keycode for word delimiter detection
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)

            // Classify keyboard source
            let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
            let keyboard = monitor.keyboardDetector.classify(keyboardType: keyboardType)

            // Dispatch keystroke handling to the MainActor
            Task { @MainActor in
                monitor.handleKeystroke(
                    appBundleID: bundleID,
                    appName: appName,
                    keyboard: keyboard,
                    keycode: keycode
                )
            }

            // Pass the event through (listen-only tap — we never intercept keys)
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,       // Critical: observe only, never block keystrokes
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            print("❌ [KeystrokeMonitor] Failed to create CGEvent tap — check Accessibility permissions")
            Task { @MainActor in
                self.handleTapFailure()
            }
            return
        }

        let currentRunLoop = CFRunLoopGetCurrent()
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(currentRunLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Store run loop reference so stop() can clean up from another thread
        Task { @MainActor in
            self.tapRunLoop = currentRunLoop
            self.restartAttempts = 0
        }

        print("✅ [KeystrokeMonitor] CGEvent tap installed")

        // Block this thread to keep the run loop alive.
        // CFRunLoopStop(tapRunLoop) from stop() will unblock this.
        CFRunLoopRun()
        print("ℹ️ [KeystrokeMonitor] Event tap run loop exited")
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let runLoop = tapRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
    }

    /// Handles CGEvent tap failures with exponential-backoff restart (max 3 attempts).
    private nonisolated func handleTapFailure() {
        Task { @MainActor in
            self.restartAttempts += 1
            if self.restartAttempts <= self.maxRestartAttempts {
                print("🔄 [KeystrokeMonitor] Restart attempt \(self.restartAttempts)/\(self.maxRestartAttempts) in 5s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.monitorQueue.async {
                        self?.installEventTap()
                    }
                }
            } else {
                print("❌ [KeystrokeMonitor] Max restart attempts reached. Keystroke monitoring disabled.")
                self.isRunning = false
            }
        }
    }

    // MARK: - Keystroke Handling

    private func handleKeystroke(appBundleID: String, appName: String, keyboard: KeyboardSource, keycode: Int64) {
        let now = Date()

        // Check if current accumulator should be finalized
        if let current = accumulator {
            let appChanged    = current.appBundleID != appBundleID
            let kbChanged     = current.keyboard    != keyboard
            let idleTooLong   = now.timeIntervalSince(current.lastKeystrokeTime) > Self.inactivityThreshold

            if appChanged || kbChanged || idleTooLong {
                finalizeAccumulator()
            }
        }

        // Start or continue accumulator
        if accumulator == nil {
            // Get window title from front app (for display in timeline)
            let windowTitle = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
            accumulator = ActiveTypingAccumulator(
                appBundleID: appBundleID,
                appName: appName,
                windowTitle: windowTitle,
                keyboard: keyboard
            )
        }

        // Increment and update window title
        let windowTitle = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        accumulator?.recordKeystroke(keycode: keycode, windowTitle: windowTitle)

        // Reset inactivity timer
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: Self.inactivityThreshold,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.finalizeAccumulator()
            }
        }
    }

    // MARK: - Accumulator Finalization

    /// Finalize the current accumulator and persist its data.
    /// Called on: inactivity timeout, app switch, keyboard switch, and app termination.
    private func finalizeAccumulator() {
        guard let acc = accumulator else { return }
        accumulator = nil

        inactivityTimer?.invalidate()
        inactivityTimer = nil

        // Don't record empty sessions
        guard acc.keystrokeCount > 0 else { return }

        // Ignore noise: single keystrokes from app switches, stray clicks, etc.
        guard acc.keystrokeCount >= 3 else { return }

        // Always roll into hourly aggregate (even short bursts contribute to stats)
        storage.rollAccumulator(acc)

        print("⌨️ [KeystrokeMonitor] \(acc.appName): \(acc.keystrokeCount) keys, \(acc.wordCount) words, \(Int(acc.duration))s, \(acc.keyboard.displayName)")

        // Emit a TypingSession for the timeline only if sustained typing >= 30s
        if acc.meetsBurstThreshold(threshold: Self.burstThreshold) {
            let session = acc.toTypingSession()
            storage.addTypingSession(session)
        }
    }

    // MARK: - Persistence

    /// Flush accumulated data to disk (encrypted).
    private func flush() {
        storage.flush()
    }

    // MARK: - Debug / Stats

    /// Current in-memory session count (for debugging)
    var sessionCount: Int {
        storage.typingStorage.sessions.count
    }

    /// Today's typed word count
    var todayTypedWords: Int {
        storage.todayTypedWords
    }

    /// Average typed WPM
    var averageTypedWpm: Double {
        storage.averageTypedWpm
    }

    /// WPM breakdown by keyboard source
    var wpmByKeyboard: [KeyboardSource: Double] {
        storage.wpmByKeyboard
    }
}
