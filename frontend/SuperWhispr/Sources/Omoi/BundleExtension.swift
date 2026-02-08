import Foundation

extension Bundle {
    /// Returns the app version string from Info.plist (e.g., "1.1.0")
    var appVersionString: String {
        if let version = infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }

    /// Returns the build number from Info.plist (e.g., "2")
    var appBuildString: String {
        if let build = infoDictionary?["CFBundleVersion"] as? String {
            return build
        }
        return "Unknown"
    }

    /// Returns the full version string with build number (e.g., "1.1.0 (2)")
    var appVersionWithBuild: String {
        return "\(appVersionString) (\(appBuildString))"
    }
}
