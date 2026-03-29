import Foundation
import ServiceManagement

class LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let launchAgentLabel = "com.wisprrd.omoi"
    private var launchAgentURL: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func install() throws {
        // Get the app bundle path
        guard let bundlePath = Bundle.main.bundlePath as NSString? else {
            throw LaunchAgentError.bundleNotFound
        }

        guard let executablePath = Bundle.main.executableURL?.path else {
            throw LaunchAgentError.bundleNotFound
        }

        // Create the LaunchAgent plist content
        let plistContent: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": [
                "SuccessfulExit": false
            ],
            "ThrottleInterval": 30,
            "ProcessType": "Interactive"
        ]

        // Create LaunchAgents directory if needed
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        // Write the plist
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
        try plistData.write(to: launchAgentURL)

        print("✅ [LaunchAgentManager] Installed LaunchAgent at \(launchAgentURL.path)")

        // Load the agent
        try load()
    }

    func uninstall() throws {
        // Unload first
        try? unload()

        // Remove the plist file
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
            print("🗑️ [LaunchAgentManager] Removed LaunchAgent from \(launchAgentURL.path)")
        }
    }

    func load() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", launchAgentURL.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("✅ [LaunchAgentManager] LaunchAgent loaded")
        } else {
            throw LaunchAgentError.loadFailed
        }
    }

    func unload() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", "-w", launchAgentURL.path]

        try process.run()
        process.waitUntilExit()

        print("ℹ️ [LaunchAgentManager] LaunchAgent unloaded")
    }

    func restart() throws {
        try unload()
        try load()
    }
}

enum LaunchAgentError: Error, LocalizedError {
    case bundleNotFound
    case loadFailed
    case installFailed

    var errorDescription: String? {
        switch self {
        case .bundleNotFound:
            return "Could not find app bundle path"
        case .loadFailed:
            return "Failed to load LaunchAgent"
        case .installFailed:
            return "Failed to install LaunchAgent"
        }
    }
}
