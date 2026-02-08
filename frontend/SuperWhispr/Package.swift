// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Omoi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Omoi", targets: ["Omoi"])
    ],
    dependencies: [
        // Upgraded to 1.15.0 (Dec 2023) to fix Recorder focus bugs (GitHub Issue #76)
        // v1.7.0 had known issues with Recorder not capturing input, especially in MenuBarExtra contexts
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "Omoi",
            dependencies: [
                "KeyboardShortcuts"
            ],
            exclude: ["Info.plist"]
        )
    ]
)
