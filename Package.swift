// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pruefstand",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Pruefstand",
            path: "Sources/Pruefstand"
        )
    ]
)
