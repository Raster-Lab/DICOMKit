// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DICOMKit",
    platforms: [
        // iOS/macOS baselines track J2KSwift's deployment targets
        // (J2KSwift v10.x requires iOS 18 / macOS 15).
        .iOS(.v18),
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
        // Re-enabled 2026-07-22 (owner approved) after the print enhancement plan
        // Milestones A–C/E brought the tool to production-grade; previously excluded
        // under Phase-1 (JPEG 2000 validation) scope.
        .executable(
            name: "dicom-print",
            targets: ["dicom-print"]
        ),
        // The receiving half of dicom-print: the printer emulator, headless.
        .executable(
            name: "dicom-printscp",
            targets: ["dicom-printscp"]
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
            name: "DICOMPrintKit",
            targets: ["DICOMPrintKit"]
        ),
        .library(
            name: "DICOMStudio",
            targets: ["DICOMStudio"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        // Phase 1 scope: exclude aws-sdk-swift because it is unrelated to JPEG 2000 verification.
        // .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.6.0"),
        // J2KSwift — pure-Swift JPEG 2000 / HTJ2K / JP3D / JPIP codec.
        // URL-consumable as of v10.9.3 (Raster-Lab/J2KSwift#438): its manifest
        // always resolves CompressionFamily from its public Git URL.
        // v11.0.2 is a decoder-only patch: truncated quality-layer prefixes stop
        // at the exact coding-pass boundary and decoder scratch clearing is bounded.
        .package(url: "https://github.com/Raster-Lab/J2KSwift.git", from: "11.0.2"),
        // JLSwift — pure-Swift JPEG-LS (ITU-T T.87 / ISO-IEC 14495-1) codec.
        // Provides the `JPEGLS` product, which backs DICOMCore.JPEGLSCodec.
        .package(url: "https://github.com/Raster-Lab/JLSwift.git", from: "0.9.0"),
        // JLISwift — native-Swift JPEG codec (baseline/extended/progressive/
        // lossless SOF0–3, 8/12/16-bit, Accelerate-backed; jpegli-parity target).
        // Distinct from JLSwift (JPEG-LS). Products: `JLISwift` (core codec) and
        // `JLIDICOM` (DICOM bridge helpers). No external deps → URL-consumable.
        .package(url: "https://github.com/Raster-Lab/JLISwift.git", from: "0.5.0"),
        // JXLSwift — pure-Swift JPEG XL (ISO/IEC 18181) codec. URL-consumable as
        // of v1.0.1: the library target dropped its CompressionFamily dependency
        // (v1.0.0 referenced it via a local path, which SwiftPM rejected for a
        // stable-versioned consumer). Provides the `JXLSwift` product.
        // Floor 1.4.0: JXLCodec relies on the `PixelType.int16` signed-16-bit level
        // shift and `JXLDecoder.decode(_:signedOutput:)` added in that release.
        .package(url: "https://github.com/Raster-Lab/JXLSwift.git", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "DICOMCore",
            dependencies: [
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift"),
                .product(name: "J2KFileFormat", package: "J2KSwift"),
                .product(name: "J2K3D", package: "J2KSwift"),
                // Phase 5: hardware acceleration backend.
                // J2KAccelerate was removed in J2KSwift v11.0.0; the Accelerate
                // path is now guarded by #if canImport in CodecBackend.swift and
                // falls through to the scalar/Apple-Accelerate backend.
                .product(name: "J2KMetal", package: "J2KSwift"),
                // JPEG-LS — JLSwift backs DICOMCore's JPEGLSCodec.
                .product(name: "JPEGLS", package: "JLSwift"),
                // JPEG — JLISwift native-Swift JPEG codec + DICOM bridge helpers.
                .product(name: "JLISwift", package: "JLISwift"),
                .product(name: "JLIDICOM", package: "JLISwift"),
                // JPEG XL — JXLSwift pure-Swift JPEG XL codec.
                .product(name: "JXLSwift", package: "JXLSwift")
            ],
            exclude: ["CharacterSetHandler+README.md"]
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
            // DICOMDictionary: keyword→tag resolution for the shared JSON/XML
            // conversion workflows' --filter-tag handling.
            dependencies: ["DICOMCore", "DICOMKit", "DICOMDictionary"]
        ),
        .target(
            name: "DICOMKit",
            dependencies: [
                "DICOMCore",
                "DICOMDictionary",
                // Level-5 validation (DICOMValidator) checks JPEG 2000 / HTJ2K
                // codestream conformance via J2KCore.
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2K3D", package: "J2KSwift"),
                // Phase 6: JPIP streaming
                .product(name: "JPIP", package: "J2KSwift")
            ],
            exclude: ["AI/SIMPLIFIED_README.md"]
        ),
        .target(
            name: "DICOMToolbox"
        ),
        // Shared DICOM Print core: image preparation, job options, workflow
        // orchestration, and console formatting used by BOTH the dicom-print CLI
        // and DICOMStudio. It sits above DICOMKit (pixel decode/preprocess) and
        // DICOMNetwork (Print SCU DIMSE), which is why it is its own target —
        // DICOMKit itself must not gain a networking dependency.
        .target(
            name: "DICOMPrintKit",
            dependencies: [
                "DICOMCore",
                "DICOMDictionary",
                "DICOMKit",
                "DICOMNetwork"
            ]
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
            exclude: [
                "AI",
                "EncapsulatedDocument",
                "HangingProtocol",
                "ParametricMap",
                "PresentationStateTests",
                "RadiationTherapy",
                "RealWorldValue",
                "SecondaryCapture",
                "Segmentation",
                "StructuredReporting",
                "TestHelpers",
                "Video",
                "Waveform",
                "DICOMFileTests.swift",
                "DICOMWritingTests.swift",
                "DataSetTests.swift",
                "ImagePreparationTests.swift",
                "SequenceParsingTests.swift",
                // Not compiled into the test run (explicit sources: allowlist below);
                // declared here to resolve SwiftPM "unhandled file" warnings. These
                // perf tests carry pre-existing concurrency errors — see note above.
                "PerformanceTests/OptimizedParsingTests.swift",
                "PerformanceTests/DICOMBenchmarkTests.swift",
                "PerformanceTests/ParsingOptionsTests.swift",
                "PerformanceTests/ImageCacheTests.swift"
            ],
            sources: [
                "JP3DVolumeDocumentTests.swift",
                "JPIPTests.swift",
                "DICOMConverterTests.swift",
                "PixelEditorTests.swift",
                "CompressionManagerImplicitVRTests.swift",
                "CompressionManagerMetricsTests.swift",
                "CompressionManagerJPEGEngineTests.swift",
                "CompressionManagerPhotometricInterpretationTests.swift",
                "DICOMFilePixelDataYBRDecodeTests.swift",
                "LossyImageCompressionAttributesTests.swift",
                "CompressedPreviewRenderParityTests.swift",
                "CompressionConsoleTests.swift",
                "ExportWindowParityTests.swift",
                "EncapsulatedPixelDataWriteTests.swift",
                "WaveformParseRegressionTests.swift",
                "OutputPathResolverTests.swift",
                "PerformanceTests/SIMDImageProcessorTests.swift"
            ]
        ),
        .testTarget(
            name: "DICOMNetworkTests",
            dependencies: ["DICOMNetwork", "DICOMCore", "DICOMKit"],
            // PACSIntegrationTests requires a live PACS and has drifted from the
            // current DICOMCore API (Tag(group:element:) labels, DataSet, audit
            // logger types). Quarantined from the unit-test target until ported.
            exclude: ["PACSIntegrationTests.swift"]
        ),
        // Security-critical, no-network regression coverage stays enabled even
        // while the broader legacy DICOMNetworkTests target remains out of scope.
        .testTarget(
            name: "DICOMNetworkSecurityTests",
            dependencies: ["DICOMNetwork"]
        ),
        .testTarget(
            name: "DICOMWebTests",
            dependencies: ["DICOMWeb", "DICOMKit"]
        ),
        // Film composition and output sinks (Print SCP Milestones C/D), plus
        // the emulator end-to-end: SCU → Print SCP → composer → sink.
        .testTarget(
            name: "DICOMPrintKitTests",
            dependencies: ["DICOMPrintKit", "DICOMNetwork", "DICOMCore"]
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
            exclude: [
                "DICOMAITests.swift",
                "DICOMAnonTests.swift",
                "DICOMArchiveTests.swift",
                "DICOMCloudTests.swift",
                "DICOMCompressTests.swift",
                "DICOMConvertTests.swift",
                "DICOMDcmdirTests.swift",
                "DICOMDiffTests.swift",
                "DICOMDumpTests.swift",
                "DICOMEchoTests.swift",
                "DICOMExportTests.swift",
                "DICOMGatewayTests.swift",
                "DICOMImageTests.swift",
                "DICOMInfoTests.swift",
                "DICOMJsonTests.swift",
                "DICOMMeasureTests.swift",
                "DICOMMergeTests.swift",
                "DICOMPdfTests.swift",
                "DICOMPixeditTests.swift",
                "DICOMQRTests.swift",
                "DICOMQueryTests.swift",
                "DICOMReportTests.swift",
                "DICOMRetrieveTests.swift",
                "DICOMScriptTests.swift",
                "DICOMSendTests.swift",
                "DICOMServerTests.swift",
                "DICOMSplitTests.swift",
                "DICOMStudyTests.swift",
                "DICOMTagsTests.swift",
                "DICOMUIDTests.swift",
                "DICOMValidateTests.swift",
                "DICOMXmlTests.swift"
            ],
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
        // Re-enabled 2026-07-22 (owner approved) — see the matching product entry above.
        .executableTarget(
            name: "dicom-print",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMNetwork",
                "DICOMPrintKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-print",
            exclude: ["README.md"]
        ),
        // Milestone F of DICOM_PRINT_SCP_PLAN.md — a thin shell over the same
        // DICOMPrintKit types DICOM Studio's Print SCP screen runs.
        .executableTarget(
            name: "dicom-printscp",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMNetwork",
                "DICOMPrintKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dicom-printscp",
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
                "DICOMKit",
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
            path: "Sources/dicom-3d",
            exclude: ["README.md"]
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
            path: "Sources/dicom-j2k",
            exclude: ["README.md"]
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
                "DICOMPrintKit",
                "DICOMWeb"
            ],
            path: "Sources/DICOMStudio",
            exclude: ["ARCHITECTURE.md", "App/DICOMStudioApp.swift"]
        ),
        .testTarget(
            name: "DICOMStudioTests",
            // DICOMPrintKit: the viewer-presentation geometry and film-pixel
            // transform the print path bakes into marks.
            dependencies: ["DICOMStudio", "DICOMWeb", "DICOMPrintKit", "DICOMNetwork"],
            resources: [
                // Small synthetic DICOM the print tests render (see
                // StudioTestFixtures). PHI-free — generated, not patient data.
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "dicom-j2kTests",
            dependencies: [
                "DICOMCore",
                "DICOMKit",
                .product(name: "J2KCore", package: "J2KSwift")
            ]
        ),
        // Oracle-based round-trip tests for the local (non-network) dicom-* tools.
        // Calls the DICOMKit library directly (not the CLI binaries). See
        // ROUND_TRIP_TESTS_PLAN.md.
        // Path is singular "DICOMRoundTripTest" (where the anonymized corpus lives);
        // the corpus is resolved at runtime via #filePath (skip-if-absent), so it is
        // excluded from compiled sources rather than bundled.
        .testTarget(
            name: "DICOMRoundTripTests",
            dependencies: [
                "DICOMKit",
                "DICOMCore",
                "DICOMDictionary",
                "DICOMWeb",
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift")
            ],
            path: "Tests/DICOMRoundTripTest",
            exclude: ["Corpus"]
        )
    ]
)
