// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "OpenLaunchpad",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "OpenLaunchpad", targets: ["OpenLaunchpad"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "LauncherCore"),
        .target(name: "TrackpadBridge", publicHeadersPath: ".", linkerSettings: [.linkedFramework("CoreFoundation")]),
        .executableTarget(name: "OpenLaunchpad", dependencies: ["LauncherCore", "CSQLite", "TrackpadBridge"]),
        .executableTarget(name: "CoreChecks", dependencies: ["LauncherCore"], path: "Tests/LauncherCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
