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
        .executable(name: "edgar", targets: ["EdgarCLI"]),
    ],
    targets: [
        .target(name: "Edgar"),
        .executableTarget(name: "EdgarCLI", dependencies: ["Edgar"]),
        .testTarget(name: "EdgarTests", dependencies: ["Edgar"]),
    ]
)
