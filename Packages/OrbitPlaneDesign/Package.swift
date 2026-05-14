// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OrbitPlaneDesign",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "OrbitPlaneDesign", targets: ["OrbitPlaneDesign"]),
    ],
    targets: [
        .target(name: "OrbitPlaneDesign"),
        .testTarget(name: "OrbitPlaneDesignTests", dependencies: ["OrbitPlaneDesign"]),
    ]
)
