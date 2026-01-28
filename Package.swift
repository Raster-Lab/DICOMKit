// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftDICOMKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftDICOMKit",
            targets: ["SwiftDICOMKit"]
        ),
        .library(
            name: "DICOMCore",
            targets: ["DICOMCore"]
        ),
        .library(
            name: "DICOMDictionary",
            targets: ["DICOMDictionary"]
        )
    ],
    targets: [
        .target(
            name: "DICOMCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMDictionary",
            dependencies: ["DICOMCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "SwiftDICOMKit",
            dependencies: ["DICOMCore", "DICOMDictionary"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DICOMCoreTests",
            dependencies: ["DICOMCore"]
        ),
        .testTarget(
            name: "DICOMDictionaryTests",
            dependencies: ["DICOMDictionary"]
        ),
        .testTarget(
            name: "SwiftDICOMKitTests",
            dependencies: ["SwiftDICOMKit"]
        )
    ]
)
