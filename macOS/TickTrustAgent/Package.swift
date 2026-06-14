// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TickTrustAgent",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TickTrustAgent",
            path: "Sources/TickTrustAgent"
        )
    ]
)
