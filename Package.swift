// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuBarFolder",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MenuBarFolder",
            path: "Sources/MenuBarFolder"
        )
    ]
)
