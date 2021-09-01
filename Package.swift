// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Future",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "Future", targets: ["Future"])
    ],
    targets: [
        .target(name: "Future", path: "Source")
    ]
)
