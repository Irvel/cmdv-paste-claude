// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CmdVPasteClaude",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "CmdVPasteClaude",
            path: "Sources/CmdVPasteClaude"
        )
    ]
)
