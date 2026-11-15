// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusLock",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "FocusLockCore"),
        .executableTarget(name: "focuslockd", dependencies: ["FocusLockCore"]),
        .executableTarget(name: "FocusLock", dependencies: ["FocusLockCore"]),
        .testTarget(name: "FocusLockCoreTests", dependencies: ["FocusLockCore"]),
    ]
)
