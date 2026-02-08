
import SwiftUI
import KeyboardShortcuts

@main
struct OmoiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var contentViewModel = ContentViewModel()

    var body: some Scene {
        // Main application window (opens on launch)
        WindowGroup {
            ContentView(viewModel: contentViewModel)
                .environmentObject(appState)
        }
        .defaultSize(width: 600, height: 700)
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // Menu bar for quick access
        MenuBarExtra("Omoi", systemImage: appState.menuBarIcon) {
            MenuBarContentView(viewModel: contentViewModel)
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        // Settings window for keyboard shortcuts
        WindowGroup(id: "settings") {
            SettingsView()
                .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var permissionMonitor: PermissionMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 [AppDelegate] Application finished launching")

        // Start as regular app (Dock icon visible)
        NSApp.setActivationPolicy(.regular)
        print("   🎯 Set activation policy to .regular (full application)")

        // FORCE Fn+Space as default if no shortcut is set
        if KeyboardShortcuts.getShortcut(for: .toggleRecord) == nil {
            print("🔧 No shortcut found, setting default to Fn+Space")
            let defaultShortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.function])
            KeyboardShortcuts.setShortcut(defaultShortcut, for: .toggleRecord)

            // Verify it was set
            if let verifyShortcut = KeyboardShortcuts.getShortcut(for: .toggleRecord) {
                print("   ✅ Default shortcut set successfully")
                print("      - Raw description: \(verifyShortcut.description)")
                print("      - Formatted: \(ShortcutFormatter.format(verifyShortcut))")
            } else {
                print("   ❌ Failed to set default shortcut!")
            }
        } else {
            let current = KeyboardShortcuts.getShortcut(for: .toggleRecord)!
            print("⌨️ Current shortcut loaded:")
            print("   - Raw description: \(current.description)")
            print("   - Formatted: \(ShortcutFormatter.format(current))")
            print("   - Key: \(current.key)")
            print("   - Modifiers: \(current.modifiers)")
        }

        // Register the global shortcut when the app launches.
        KeyboardShortcuts.onKeyDown(for: .toggleRecord) {
            print("🎤 [Shortcut] Global shortcut triggered!")
            // Post a notification to toggle recording state
            NotificationCenter.default.post(name: .toggleRecord, object: nil)
        }

        // Start backend server
        print("🔧 Starting backend server...")
        BackendManager.shared.startBackend()

        // Start permission monitoring
        permissionMonitor = PermissionMonitor()
        permissionMonitor?.startMonitoring()

        // CHECK ACCESSIBILITY PERMISSIONS with detailed logging
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasPermission = AccessibilityPermissions.hasAccessibilityPermission()
            print("🔐 Accessibility Permission Check:")
            print("   - Has Permission: \(hasPermission)")
            print("   - Bundle ID: \(Bundle.main.bundleIdentifier ?? "none")")
            print("   - Bundle Path: \(Bundle.main.bundlePath)")

            if !hasPermission {
                print("⚠️ Accessibility permissions not granted - auto-paste will not work")
            } else {
                print("✅ Accessibility permissions are granted")
            }
        }

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep app running in menu bar when window closes
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("🪟 [Dock Click] hasVisibleWindows: \(flag)")
        if !flag {
            // No visible windows - show existing or create new main window
            // First, try to find and show existing windows
            for window in NSApp.windows {
                if window.title.isEmpty || window.title.contains("Omoi") {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    print("   → Brought existing window to front")
                    return true
                }
            }

            // If no window found, SwiftUI will create a new one automatically
            print("   → SwiftUI will create new window")
        }
        return true
    }
}

// Define a custom name for the keyboard shortcut for clarity.
extension KeyboardShortcuts.Name {
    static let toggleRecord = Self("toggleRecord", default: .init(.space, modifiers: [.function]))
}

// Define custom notification names.
extension Notification.Name {
    static let toggleRecord = Self("toggleRecordNotification")
    static let pastePermissionDenied = Notification.Name("pastePermissionDenied")
    static let pasteSuccess = Notification.Name("pasteSuccess")
}
