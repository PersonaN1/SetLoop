// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SetLoopCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SetLoopCore", targets: ["SetLoopCore"])
    ],
    targets: [
        .target(name: "SetLoopCore"),
        .testTarget(name: "SetLoopCoreTests", dependencies: ["SetLoopCore"])
    ]
)
