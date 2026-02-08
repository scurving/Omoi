import Cocoa
import ApplicationServices

class PasteManager {
    static let shared = PasteManager()
    private var lastActiveApp: NSRunningApplication?
    private var lastPasteTime: Date = Date(timeIntervalSince1970: 0)

    func captureCurrentApp() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApp = front
        }
    }
    
    func getLastAppIcon() -> NSImage? {
        return lastActiveApp?.icon
    }
    
    func getLastAppName() -> String {
        return lastActiveApp?.localizedName ?? "Unknown App"
    }
    
    func getLastAppBundleID() -> String? {
        return lastActiveApp?.bundleIdentifier
    }

    /// Tries to get the title of the frontmost window of the last active app
    func getFrontmostWindowTitle() -> String? {
        guard let app = lastActiveApp else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow {
            var title: AnyObject?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
            if titleResult == .success, let titleStr = title as? String {
                return titleStr
            }
        }
        return nil
    }
    
    func paste(text: String) {
        // Prevent duplicate pastes within 500ms (two ViewModels may trigger paste simultaneously)
        let now = Date()
        if now.timeIntervalSince(lastPasteTime) < 0.5 {
            print("⏸️ [PasteManager] Duplicate paste ignored (too soon)")
            NotificationCenter.default.post(name: .pasteSuccess, object: nil)
            return
        }
        lastPasteTime = now

        // CHECK 1: Verify Accessibility permission
        guard AccessibilityPermissions.hasAccessibilityPermission() else {
            print("❌ Auto-paste failed: Accessibility permissions not granted")
            // Post notification to UI to show error
            NotificationCenter.default.post(
                name: .pastePermissionDenied,
                object: nil,
                userInfo: ["reason": "accessibility_denied"]
            )
            return
        }

        // CHECK 2: Verify we have a target app
        guard let app = lastActiveApp else {
            print("❌ Auto-paste failed: No target app captured")
            NotificationCenter.default.post(
                name: .pastePermissionDenied,
                object: nil,
                userInfo: ["reason": "no_target_app"]
            )
            return
        }

        // EXISTING PASTE LOGIC
        print("📋 Pasting to \(app.localizedName ?? "Unknown App")")

        let pasteboard = NSPasteboard.general

        // 1. Save original content
        // Note: For simplicity, saving string data. Full restore requires saving all types.
        let originalString = pasteboard.string(forType: .string)

        // 2. Set new content
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Activate target app
        app.activate(options: .activateIgnoringOtherApps)

        // 4. Simulate Paste & Restore
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateCommandV()

            // Restore after a short delay to ensure OS has consumed the paste event
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let original = originalString {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }

                // Post success notification
                NotificationCenter.default.post(name: .pasteSuccess, object: nil)
            }
        }
    }
    
    private func simulateCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let vKeyCode: CGKeyCode = 9 // 0x09 is 'v'
        
        // Cmd + V Down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true) // 55 is Cmd
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        vDown?.flags = .maskCommand
        
        // Cmd + V Up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)
        
        let loc = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
}
