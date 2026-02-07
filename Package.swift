// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DICOMKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DICOMKit",
            targets: ["DICOMKit"]
        ),
        .library(
            name: "DICOMCore",
            targets: ["DICOMCore"]
        ),
        .library(
            name: "DICOMDictionary",
            targets: ["DICOMDictionary"]
        ),
        .library(
            name: "DICOMNetwork",
            targets: ["DICOMNetwork"]
        ),
        .library(
            name: "DICOMWeb",
            targets: ["DICOMWeb"]
        ),
        .executable(
            name: "dicom-info",
            targets: ["dicom-info"]
        ),
        .executable(
            name: "dicom-convert",
            targets: ["dicom-convert"]
        ),
        .executable(
            name: "dicom-validate",
            targets: ["dicom-validate"]
        ),
        .executable(
            name: "dicom-anon",
            targets: ["dicom-anon"]
        ),
        .executable(
            name: "dicom-dump",
            targets: ["dicom-dump"]
        ),
        .executable(
            name: "dicom-query",
            targets: ["dicom-query"]
        ),
        .executable(
            name: "dicom-send",
            targets: ["dicom-send"]
        ),
        .executable(
            name: "dicom-diff",
            targets: ["dicom-diff"]
        ),
        .executable(
            name: "dicom-retrieve",
            targets: ["dicom-retrieve"]
        ),
        .executable(
            name: "dicom-split",
            targets: ["dicom-split"]
        ),
        .executable(
            name: "dicom-merge",
            targets: ["dicom-merge"]
        ),
        .executable(
            name: "dicom-json",
            targets: ["dicom-json"]
        ),
        .executable(
            name: "dicom-xml",
            targets: ["dicom-xml"]
        ),
        .executable(
            name: "dicom-pdf",
            targets: ["dicom-pdf"]
        ),
        .executable(
            name: "dicom-image",
            targets: ["dicom-image"]
        ),
        .executable(
            name: "dicom-dcmdir",
            targets: ["dicom-dcmdir"]
        ),
        .executable(
            name: "dicom-archive",
            targets: ["dicom-archive"]
        ),
        .executable(
            name: "dicom-export",
            targets: ["dicom-export"]
        ),
        .executable(
            name: "dicom-qr",
            targets: ["dicom-qr"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "DICOMCore",
            exclude: ["CharacterSetHandler+README.md"],
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
            name: "DICOMNetwork",
            dependencies: ["DICOMCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMWeb",
            dependencies: ["DICOMCore", "DICOMKit"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "DICOMKit",
            dependencies: ["DICOMCore", "DICOMDictionary"],
            exclude: ["AI/SIMPLIFIED_README.md"],
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
            name: "DICOMKitTests",
            dependencies: ["DICOMKit"]
        ),
        .testTarget(
            name: "DICOMNetworkTests",
            dependencies: ["DICOMNetwork"]
        ),
        .testTarget(
            name: "DICOMWebTests",
            dependencies: ["DICOMWeb", "DICOMKit"]
        ),
        .testTarget(
            name: "DICOMToolsTests",
            dependencies: ["DICOMKit", "DICOMCore", "DICOMDictionary", "DICOMWeb"]
        ),
        .executableTarget(
            name: "dicom-info",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-info",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-convert",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-convert",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-validate",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-validate",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-anon",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-anon",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-dump",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-dump",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-query",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-query",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-send",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-send",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-diff",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-diff",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-retrieve",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-retrieve",
            exclude: ["README.md"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "dicom-split",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-split",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-merge",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-merge",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-json",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMWeb",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-json",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-xml",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMWeb",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-xml",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-pdf",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-pdf",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-image",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-image",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-dcmdir",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-dcmdir",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-archive",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-archive",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-export",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-export",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-qr",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-qr",
            exclude: ["README.md"]
        )
    ]
)
