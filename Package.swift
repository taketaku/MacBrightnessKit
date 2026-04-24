// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MacBrightnessKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "MacBrightnessKit",
            targets: ["MacBrightnessKit"]
        ),
        .executable(
            name: "macbrightness",
            targets: ["MacBrightnessKitDemo"]
        )
    ],
    targets: [
        .target(name: "MacBrightnessKit"),
        .executableTarget(
            name: "MacBrightnessKitDemo",
            dependencies: ["MacBrightnessKit"]
        ),
        .testTarget(
            name: "MacBrightnessKitTests",
            dependencies: ["MacBrightnessKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
