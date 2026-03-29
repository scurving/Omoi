import Cocoa

class AccessibilityPermissions {
    /// Check if Accessibility permissions are granted
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt user to grant Accessibility permissions
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Settings to Privacy & Security pane
    static func openAccessibilitySettings() {
        // Open System Preferences/Settings to Privacy & Security -> Accessibility
        // Direct link to the specific pane saves the user clicks
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        print("✅ Opened System Settings to Privacy & Security")
    }

    /// Reveal the app bundle in Finder so the user can drag it to the Accessibility list manually
    static func revealAppInFinder() {
        if isRunningAsAppBundle {
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        } else {
            // If raw binary, try to select parent directory or self
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            // Maybe show alert?
        }
    }
    
    static var isRunningAsAppBundle: Bool {
        return Bundle.main.bundleURL.pathExtension == "app"
    }
}
