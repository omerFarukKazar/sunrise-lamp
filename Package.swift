// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SunriseLamp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SunriseCore"),
        .executableTarget(name: "SunriseLamp", dependencies: ["SunriseCore"]),
        .testTarget(name: "SunriseCoreTests", dependencies: ["SunriseCore"]),
    ]
)
