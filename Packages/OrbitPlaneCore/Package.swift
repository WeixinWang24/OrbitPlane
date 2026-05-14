// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OrbitPlaneCore",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "OrbitPlaneCore", targets: ["OrbitPlaneCore"]),
    ],
    targets: [
        .target(name: "OrbitPlaneCore"),
        .testTarget(name: "OrbitPlaneCoreTests", dependencies: ["OrbitPlaneCore"]),
    ]
)
