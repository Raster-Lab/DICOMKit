// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DICOMKit",
    platforms: [
        .iOS(.v17),
        // macOS baseline bumped to 15 to satisfy J2KSwift (pure-Swift JPEG 2000 codec).
        // See J2KSWIFT_INTEGRATION_PLAN.md Phase 1.
        .macOS(.v15),
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
        // Phase 1 scope: exclude dicom-print because it is outside JPEG 2000 validation.
        // .executable(
        //     name: "dicom-print",
        //     targets: ["dicom-print"]
        // ),
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
        // Phase 1 scope: exclude dicom-cloud to avoid unrelated aws-sdk-swift dependency during J2K validation.
        // .executable(
        //     name: "dicom-cloud",
        //     targets: ["dicom-cloud"]
        // ),
        .executable(
            name: "dicom-3d",
            targets: ["dicom-3d"]
        ),
        .executable(
            name: "dicom-jpip",
            targets: ["dicom-jpip"]
        ),
        .executable(
            name: "dicom-j2k",
            targets: ["dicom-j2k"]
        ),
        // Phase 1 scope: exclude dicom-ai because it is outside JPEG 2000 validation.
        // .executable(
        //     name: "dicom-ai",
        //     targets: ["dicom-ai"]
        // ),
        .executable(
            name: "dicom-gateway",
            targets: ["dicom-gateway"]
        ),
        // Phase 1 scope: exclude dicom-server because it has unrelated compile issues.
        // .executable(
        //     name: "dicom-server",
        //     targets: ["dicom-server"]
        // ),
        .library(
            name: "DICOMStudio",
            targets: ["DICOMStudio"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        // Phase 1 scope: exclude aws-sdk-swift because it is unrelated to JPEG 2000 verification.
        // .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.6.0"),
        // J2KSwift — pure-Swift JPEG 2000 / HTJ2K / JP3D / JPIP codec
        // See J2KSWIFT_INTEGRATION_PLAN.md for the phased integration.
        .package(url: "https://github.com/Raster-Lab/J2KSwift.git", from: "5.21.0")
    ],
    targets: [
        // OpenJPEG 2.x system library (https://www.openjpeg.org)
        // Requires: brew install openjpeg
        //
        // pkgConfig is intentionally omitted: `pkg-config --libs libopenjp2` emits
        // `-L/opt/homebrew/opt/openjpeg/lib -lopenjp2`, which causes a dynamic link to
        // libopenjp2.7.dylib.  With App Sandbox enabled that path is inaccessible and
        // dyld aborts at launch.  The actual link is handled statically via the
        // .unsafeFlags(["/opt/homebrew/lib/libopenjp2.a"]) in DICOMCore's linkerSettings.
        // Headers are resolved directly from the modulemap (no pkg-config needed).
        .systemLibrary(
            name: "COpenJPEG",
            providers: [.brew(["openjpeg"])]
        ),
        .target(
            name: "DICOMCore",
            dependencies: [
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift"),
                .product(name: "J2KFileFormat", package: "J2KSwift"),
                .product(name: "J2K3D", package: "J2KSwift"),
                // Phase 5: hardware acceleration backends
                .product(name: "J2KAccelerate", package: "J2KSwift"),
                .product(name: "J2KMetal", package: "J2KSwift"),
                // OpenJPEG — decode comparison codec (macOS only, requires brew install openjpeg)
                .target(name: "COpenJPEG", condition: .when(platforms: [.macOS]))
            ],
            exclude: ["CharacterSetHandler+README.md"],
            linkerSettings: [
                // Link the static OpenJPEG library directly so the app has no runtime
                // dependency on /opt/homebrew/lib (avoids dyld rpath failures).
                // Apple Silicon path; for Intel Macs change to /usr/local/lib/libopenjp2.a
                .unsafeFlags(["/opt/homebrew/lib/libopenjp2.a"], .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "DICOMDictionary",
            dependencies: ["DICOMCore"],
            resources: [.process("Resources")]
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
            dependencies: [
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "J2K3D", package: "J2KSwift"),
                // Phase 6: JPIP streaming
                .product(name: "JPIP", package: "J2KSwift")
            ],
            exclude: ["AI/SIMPLIFIED_README.md"]
        ),
        .target(
            name: "DICOMToolbox"
        ),
        .testTarget(
            name: "DICOMCoreTests",
            dependencies: [
                "DICOMCore",
                "DICOMKit",
                .product(name: "J2KCodec", package: "J2KSwift")
            ]
        ),
        .testTarget(
            name: "DICOMDictionaryTests",
            dependencies: ["DICOMDictionary"]
        ),
        // Phase 1 scope: DICOMKitTests re-enabled for JP3D volume integration tests.
        // Only the JP3D-related test files are included to avoid pre-existing
        // concurrency errors in PerformanceTests/ImageCacheTests.swift.
        .testTarget(
            name: "DICOMKitTests",
            dependencies: ["DICOMKit", "DICOMCore"],
            sources: [
                "JP3DVolumeDocumentTests.swift",
                "JPIPTests.swift"
            ]
        ),
        // .testTarget(
        //     name: "DICOMNetworkTests",
        //     dependencies: ["DICOMNetwork"]
        // ),
        .testTarget(
            name: "DICOMWebTests",
            dependencies: ["DICOMWeb", "DICOMKit"]
        ),
        .testTarget(
            name: "DICOMToolboxTests",
            dependencies: ["DICOMToolbox"]
        ),
        // Phase 1 scope: exclude DICOMToolsTests because they depend on server and AI targets outside JPEG 2000 validation.
        // .testTarget(
        //     name: "DICOMToolsTests",
        //     dependencies: ["DICOMKit", "DICOMCore", "DICOMDictionary", "DICOMNetwork", "DICOMWeb", "dicom-server", "dicom-gateway", "dicom-ai", "dicom-echo", "dicom-query"]
        // ),
        .testTarget(
            name: "DICOMViewerTests",
            dependencies: ["DICOMKit", "DICOMCore"],
            path: "Tests/DICOMToolsTests",
            sources: ["DICOMViewerTests.swift"]
        ),
        .executableTarget(
            name: "dicom-info",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift"),
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
                .product(name: "J2KCore", package: "J2KSwift"),
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
        // Phase 1 scope: exclude dicom-print because it is outside JPEG 2000 validation.
        // .executableTarget(
        //     name: "dicom-print",
        //     dependencies: [
        //         "DICOMKit",
        //         "DICOMCore",
        //         "DICOMNetwork",
        //         .product(name: "ArgumentParser", package: "swift-argument-parser")
        //     ],
        //     path: "Sources/dicom-print",
        //     exclude: ["README.md"]
        // ),
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
        // Phase 1 scope: exclude dicom-cloud to avoid unrelated aws-sdk-swift dependency during J2K validation.
        // .executableTarget(
        //     name: "dicom-cloud",
        //     dependencies: [
        //         "DICOMKit",
        //         "DICOMCore",
        //         .product(name: "ArgumentParser", package: "swift-argument-parser"),
        //         .product(name: "AWSS3", package: "aws-sdk-swift")
        //     ],
        //     path: "Sources/dicom-cloud",
        //     exclude: ["README.md"]
        // ),
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
            name: "dicom-jpip",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "JPIP", package: "J2KSwift"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-jpip"
        ),
        .executableTarget(
            name: "dicom-j2k",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift"),
                .product(name: "J2KFileFormat", package: "J2KSwift"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-j2k"
        ),
        // Phase 1 scope: exclude dicom-ai because it is outside JPEG 2000 validation.
        // .executableTarget(
        //     name: "dicom-ai",
        //     dependencies: [
        //         "DICOMKit",
        //         "DICOMCore",
        //         "DICOMDictionary",
        //         .product(name: "ArgumentParser", package: "swift-argument-parser")
        //     ],
        //     path: "Sources/dicom-ai",
        //     exclude: ["README.md"]
        // ),
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
        // Phase 1 scope: exclude dicom-server because it has unrelated compile issues.
        // .executableTarget(
        //     name: "dicom-server",
        //     dependencies: [
        //         "DICOMKit",
        //         "DICOMCore",
        //         "DICOMNetwork",
        //         "DICOMDictionary",
        //         .product(name: "ArgumentParser", package: "swift-argument-parser")
        //     ],
        //     path: "Sources/dicom-server",
        //     exclude: ["README.md"]
        // ),
        .target(
            name: "DICOMStudio",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                "DICOMNetwork",
                "DICOMWeb"
            ],
            path: "Sources/DICOMStudio",
            exclude: ["ARCHITECTURE.md", "App/DICOMStudioApp.swift"]
        ),
        .testTarget(
            name: "DICOMStudioTests",
            dependencies: ["DICOMStudio"]
        ),
        .testTarget(
            name: "dicom-j2kTests",
            dependencies: [
                "DICOMCore",
                "DICOMKit",
                .product(name: "J2KCore", package: "J2KSwift")
            ]
        )
    ]
)
