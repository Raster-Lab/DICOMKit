// swift-tools-version: 6.0

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
        .library(
            name: "DICOMToolbox",
            targets: ["DICOMToolbox"]
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
        ),
        .executable(
            name: "dicom-wado",
            targets: ["dicom-wado"]
        ),
        .executable(
            name: "dicom-echo",
            targets: ["dicom-echo"]
        ),
        .executable(
            name: "dicom-print",
            targets: ["dicom-print"]
        ),
        .executable(
            name: "dicom-mwl",
            targets: ["dicom-mwl"]
        ),
        .executable(
            name: "dicom-mpps",
            targets: ["dicom-mpps"]
        ),
        .executable(
            name: "dicom-pixedit",
            targets: ["dicom-pixedit"]
        ),
        .executable(
            name: "dicom-tags",
            targets: ["dicom-tags"]
        ),
        .executable(
            name: "dicom-uid",
            targets: ["dicom-uid"]
        ),
        .executable(
            name: "dicom-compress",
            targets: ["dicom-compress"]
        ),
        .executable(
            name: "dicom-study",
            targets: ["dicom-study"]
        ),
        .executable(
            name: "dicom-script",
            targets: ["dicom-script"]
        ),
        .executable(
            name: "dicom-report",
            targets: ["dicom-report"]
        ),
        .executable(
            name: "dicom-measure",
            targets: ["dicom-measure"]
        ),
        .executable(
            name: "dicom-viewer",
            targets: ["dicom-viewer"]
        ),
        .executable(
            name: "dicom-cloud",
            targets: ["dicom-cloud"]
        ),
        .executable(
            name: "dicom-3d",
            targets: ["dicom-3d"]
        ),
        .executable(
            name: "dicom-ai",
            targets: ["dicom-ai"]
        ),
        .executable(
            name: "dicom-gateway",
            targets: ["dicom-gateway"]
        ),
        .executable(
            name: "dicom-server",
            targets: ["dicom-server"]
        ),
        .library(
            name: "DICOMStudio",
            targets: ["DICOMStudio"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "DICOMCore",
            exclude: ["CharacterSetHandler+README.md"]
        ),
        .target(
            name: "DICOMDictionary",
            dependencies: ["DICOMCore"]
        ),
        .target(
            name: "DICOMNetwork",
            dependencies: ["DICOMCore", "DICOMDictionary"]
        ),
        .target(
            name: "DICOMWeb",
            dependencies: ["DICOMCore", "DICOMKit"]
        ),
        .target(
            name: "DICOMKit",
            dependencies: ["DICOMCore", "DICOMDictionary"],
            exclude: ["AI/SIMPLIFIED_README.md"]
        ),
        .target(
            name: "DICOMToolbox"
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
            name: "DICOMToolboxTests",
            dependencies: ["DICOMToolbox"]
        ),
        .testTarget(
            name: "DICOMToolsTests",
            dependencies: ["DICOMKit", "DICOMCore", "DICOMDictionary", "DICOMNetwork", "DICOMWeb", "dicom-server", "dicom-gateway", "dicom-ai", "dicom-echo", "dicom-query"]
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
            exclude: ["README.md"]
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
        ),
        .executableTarget(
            name: "dicom-wado",
            dependencies: [
                "DICOMCore",
                "DICOMWeb",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-wado",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-echo",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-echo",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-print",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-print",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-mwl",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-mwl",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-mpps",
            dependencies: [
                "DICOMCore",
                "DICOMNetwork",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-mpps",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-pixedit",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-pixedit",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-tags",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-tags",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-uid",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-uid",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-compress",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-compress",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-study",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-study",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-script",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-script",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-report",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-report",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-measure",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-measure",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-viewer",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-viewer",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-cloud",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AWSS3", package: "aws-sdk-swift")
            ],
            path: "Sources/dicom-cloud",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-3d",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-3d"
        ),
        .executableTarget(
            name: "dicom-ai",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-ai",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-gateway",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-gateway",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "dicom-server",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMNetwork",
                "DICOMDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-server",
            exclude: ["README.md"]
        ),
        .target(
            name: "DICOMStudio",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary"
            ],
            path: "Sources/DICOMStudio"
        ),
        .testTarget(
            name: "DICOMStudioTests",
            dependencies: ["DICOMStudio"]
        )
    ]
)
