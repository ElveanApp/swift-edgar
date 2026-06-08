// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-edgar",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "Edgar", targets: ["Edgar"]),
    ],
    targets: [
        .target(name: "Edgar"),
        .testTarget(name: "EdgarTests", dependencies: ["Edgar"]),
    ]
)
