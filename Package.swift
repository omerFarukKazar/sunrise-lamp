// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SunriseLamp",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SunriseCore", targets: ["SunriseCore"]),
    ],
    targets: [
        .target(name: "SunriseCore"),
        .executableTarget(name: "SunriseLamp", dependencies: ["SunriseCore"]),
        .testTarget(name: "SunriseCoreTests", dependencies: ["SunriseCore"]),
    ]
)
