// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GrabKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "GrabKit", targets: ["GrabKit"])
    ],
    targets: [
        .target(name: "GrabKit", path: "Sources/GrabKit"),
        .testTarget(name: "GrabKitTests", dependencies: ["GrabKit"], path: "Tests/GrabKitTests")
    ]
)
