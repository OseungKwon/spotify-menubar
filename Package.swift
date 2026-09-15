// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpotifyMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SpotifyMenuBar",
            path: "Sources/SpotifyMenuBar"
        )
    ]
)
