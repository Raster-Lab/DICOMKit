import Testing
import Foundation
@testable import DICOMCore

@Suite("TranscodingConfiguration Tests")
struct TranscodingConfigurationTests {
    
    @Test("Default configuration prefers Explicit VR Little Endian")
    func testDefaultConfiguration() {
        let config = TranscodingConfiguration.default
        
        #expect(config.preferredSyntaxes.count == 2)
        #expect(config.preferredSyntaxes[0].uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(config.preferredSyntaxes[1].uid == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(config.allowLossyCompression == false)
        #expect(config.preservePixelDataFidelity == true)
    }
    
    @Test("Max compression configuration allows lossy")
    func testMaxCompressionConfiguration() {
        let config = TranscodingConfiguration.maxCompression
        
        #expect(config.allowLossyCompression == true)
        #expect(config.preservePixelDataFidelity == false)
        #expect(config.preferredSyntaxes.contains { $0.uid == TransferSyntax.jpegBaseline.uid })
    }
    
    @Test("Lossless compression configuration only includes lossless syntaxes")
    func testLosslessCompressionConfiguration() {
        let config = TranscodingConfiguration.losslessCompression
        
        #expect(config.allowLossyCompression == false)
        #expect(config.preservePixelDataFidelity == true)
        
        // All syntaxes should be lossless
        for syntax in config.preferredSyntaxes {
            #expect(syntax.isLossless == true)
        }
    }
    
    @Test("Custom configuration creation")
    func testCustomConfiguration() {
        let config = TranscodingConfiguration(
            preferredSyntaxes: [.explicitVRBigEndian, .implicitVRLittleEndian],
            allowLossyCompression: true,
            preservePixelDataFidelity: false
        )
        
        #expect(config.preferredSyntaxes.count == 2)
        #expect(config.preferredSyntaxes[0].uid == TransferSyntax.explicitVRBigEndian.uid)
        #expect(config.allowLossyCompression == true)
        #expect(config.preservePixelDataFidelity == false)
    }
    
    @Test("Configuration is hashable")
    func testHashable() {
        let config1 = TranscodingConfiguration.default
        let config2 = TranscodingConfiguration.default
        
        #expect(config1 == config2)
        
        var set: Set<TranscodingConfiguration> = []
        set.insert(config1)
        set.insert(config2)
        
        #expect(set.count == 1)
    }
}

@Suite("TranscodingResult Tests")
struct TranscodingResultTests {
    
    @Test("Transcoding result with actual transcoding")
    func testResultWithTranscoding() {
        let result = TranscodingResult(
            data: Data([0x01, 0x02, 0x03]),
            sourceTransferSyntax: .implicitVRLittleEndian,
            targetTransferSyntax: .explicitVRLittleEndian,
            wasTranscoded: true,
            isLossless: true
        )
        
        #expect(result.data.count == 3)
        #expect(result.sourceTransferSyntax.uid == TransferSyntax.implicitVRLittleEndian.uid)
        #expect(result.targetTransferSyntax.uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(result.wasTranscoded == true)
        #expect(result.isLossless == true)
    }
    
    @Test("Transcoding result without actual transcoding (same syntax)")
    func testResultWithoutTranscoding() {
        let result = TranscodingResult(
            data: Data([0x01, 0x02, 0x03]),
            sourceTransferSyntax: .explicitVRLittleEndian,
            targetTransferSyntax: .explicitVRLittleEndian,
            wasTranscoded: false,
            isLossless: true
        )
        
        #expect(result.wasTranscoded == false)
        #expect(result.isLossless == true)
    }
}

@Suite("TranscodingError Tests")
struct TranscodingErrorTests {
    
    @Test("Error descriptions are meaningful")
    func testErrorDescriptions() {
        let errors: [TranscodingError] = [
            .unsupportedSourceSyntax("1.2.3.4"),
            .unsupportedTargetSyntax("1.2.3.5"),
            .noCompatibleSyntax,
            .pixelDataExtractionFailed("Test reason"),
            .encodingFailed("Test encoding"),
            .parsingFailed("Test parsing"),
            .lossyCompressionNotAllowed,
            .fidelityLost
        ]
        
        for error in errors {
            #expect(!error.description.isEmpty)
        }
    }
    
    @Test("Errors are equatable")
    func testEquatable() {
        let error1 = TranscodingError.unsupportedSourceSyntax("1.2.3.4")
        let error2 = TranscodingError.unsupportedSourceSyntax("1.2.3.4")
        let error3 = TranscodingError.unsupportedSourceSyntax("1.2.3.5")
        
        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

@Suite("TransferSyntaxConverter Tests")
struct TransferSyntaxConverterTests {
    
    @Test("Converter with default configuration")
    func testDefaultConverter() {
        let converter = TransferSyntaxConverter()
        
        #expect(converter.configuration.allowLossyCompression == false)
        #expect(converter.configuration.preservePixelDataFidelity == true)
    }
    
    @Test("Converter with custom configuration")
    func testCustomConverter() {
        let config = TranscodingConfiguration.maxCompression
        let converter = TransferSyntaxConverter(configuration: config)
        
        #expect(converter.configuration.allowLossyCompression == true)
    }
    
    // MARK: - canTranscode Tests
    
    @Test("Can transcode same syntax (no-op)")
    func testCanTranscodeSameSyntax() {
        let converter = TransferSyntaxConverter()
        
        #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .explicitVRLittleEndian) == true)
        #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .implicitVRLittleEndian) == true)
        #expect(converter.canTranscode(from: .explicitVRBigEndian, to: .explicitVRBigEndian) == true)
    }
    
    @Test("Can transcode between uncompressed syntaxes")
    func testCanTranscodeBetweenUncompressed() {
        let converter = TransferSyntaxConverter()
        
        // Explicit to Implicit
        #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .implicitVRLittleEndian) == true)
        
        // Implicit to Explicit
        #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .explicitVRLittleEndian) == true)
        
        // Little Endian to Big Endian
        #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .explicitVRBigEndian) == true)
        
        // Big Endian to Little Endian
        #expect(converter.canTranscode(from: .explicitVRBigEndian, to: .explicitVRLittleEndian) == true)
        
        // Implicit to Big Endian
        #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .explicitVRBigEndian) == true)
    }
    
    #if canImport(ImageIO)
    @Test("Can transcode to compressed syntax with encoder support")
    func testCanTranscodeToCompressed() {
        let converter = TransferSyntaxConverter()
        
        // Can encode to JPEG Baseline if encoder is available
        if CodecRegistry.shared.hasEncoder(for: TransferSyntax.jpegBaseline.uid) {
            #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .jpegBaseline) == true)
        }
        
        // Can encode to JPEG 2000 Lossless if encoder is available
        if CodecRegistry.shared.hasEncoder(for: TransferSyntax.jpeg2000Lossless.uid) {
            #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .jpeg2000Lossless) == true)
        }
    }
    #else
    @Test("Cannot transcode to compressed syntax without ImageIO")
    func testCannotTranscodeToCompressedWithoutImageIO() {
        let converter = TransferSyntaxConverter()
        
        // Cannot encode without ImageIO
        #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .jpegBaseline) == false)
        #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .jpeg2000Lossless) == false)
    }
    #endif
    
    #if canImport(ImageIO)
    @Test("Can decompress JPEG to uncompressed (if codec available)")
    func testCanDecompressJPEG() {
        let converter = TransferSyntaxConverter()
        
        // JPEG to Explicit VR LE (decompression)
        if CodecRegistry.shared.hasCodec(for: TransferSyntax.jpegBaseline.uid) {
            #expect(converter.canTranscode(from: .jpegBaseline, to: .explicitVRLittleEndian) == true)
        }
    }
    #endif
    
    @Test("Can decompress RLE to uncompressed")
    func testCanDecompressRLE() {
        let converter = TransferSyntaxConverter()
        
        // RLE to Explicit VR LE (decompression)
        #expect(converter.canTranscode(from: .rleLossless, to: .explicitVRLittleEndian) == true)
        #expect(converter.canTranscode(from: .rleLossless, to: .implicitVRLittleEndian) == true)
    }
    
    // MARK: - selectTargetSyntax Tests
    
    @Test("Select target syntax from accepted list")
    func testSelectTargetSyntax() {
        let converter = TransferSyntaxConverter()
        
        let accepted = [
            TransferSyntax.implicitVRLittleEndian.uid,
            TransferSyntax.explicitVRLittleEndian.uid
        ]
        
        let target = converter.selectTargetSyntax(
            for: Data(),
            sourceSyntax: .explicitVRLittleEndian,
            acceptedSyntaxes: accepted
        )
        
        // Should select Explicit VR LE (first in preferred list that's accepted)
        #expect(target?.uid == TransferSyntax.explicitVRLittleEndian.uid)
    }
    
    @Test("Select target syntax returns nil when none compatible")
    func testSelectTargetSyntaxNoCompatible() {
        let config = TranscodingConfiguration(
            preferredSyntaxes: [.jpegBaseline], // Cannot encode to JPEG
            allowLossyCompression: true,
            preservePixelDataFidelity: false
        )
        let converter = TransferSyntaxConverter(configuration: config)
        
        let accepted = [TransferSyntax.jpegBaseline.uid]
        
        let target = converter.selectTargetSyntax(
            for: Data(),
            sourceSyntax: .explicitVRLittleEndian,
            acceptedSyntaxes: accepted
        )
        
        // Cannot encode to JPEG, so should return nil
        #expect(target == nil)
    }
    
    @Test("Select target syntax respects lossy constraint")
    func testSelectTargetSyntaxRespectsLossyConstraint() {
        let config = TranscodingConfiguration(
            preferredSyntaxes: [.jpegBaseline, .explicitVRLittleEndian],
            allowLossyCompression: false,
            preservePixelDataFidelity: true
        )
        let converter = TransferSyntaxConverter(configuration: config)
        
        let accepted = [
            TransferSyntax.jpegBaseline.uid,
            TransferSyntax.explicitVRLittleEndian.uid
        ]
        
        let target = converter.selectTargetSyntax(
            for: Data(),
            sourceSyntax: .implicitVRLittleEndian,
            acceptedSyntaxes: accepted
        )
        
        // Should skip JPEG (lossy) and select Explicit VR LE (lossless)
        #expect(target?.uid == TransferSyntax.explicitVRLittleEndian.uid)
    }
    
    // MARK: - transcode Tests
    
    @Test("Transcode same syntax returns unchanged data")
    func testTranscodeSameSyntax() throws {
        let converter = TransferSyntaxConverter()
        let sourceData = Data([0x01, 0x02, 0x03, 0x04])
        
        let result = try converter.transcode(
            dataSetData: sourceData,
            from: .explicitVRLittleEndian,
            to: .explicitVRLittleEndian
        )
        
        #expect(result.data == sourceData)
        #expect(result.wasTranscoded == false)
        #expect(result.isLossless == true)
    }
    
    @Test("Transcode throws for unsupported target")
    func testTranscodeUnsupportedTarget() {
        let converter = TransferSyntaxConverter()
        let sourceData = Data([0x01, 0x02, 0x03, 0x04])
        
        #expect(throws: TranscodingError.self) {
            try converter.transcode(
                dataSetData: sourceData,
                from: .explicitVRLittleEndian,
                to: .jpegBaseline // Cannot encode to JPEG
            )
        }
    }
    
    @Test("Transcoding configuration respects lossy constraint")
    func testTranscodingConfigRespectsLossyConstraint() {
        // Verify that configurations with allowLossyCompression=false
        // correctly filter out lossy transfer syntaxes
        let config = TranscodingConfiguration(
            preferredSyntaxes: [.jpegBaseline, .jpeg2000, .explicitVRLittleEndian],
            allowLossyCompression: false,
            preservePixelDataFidelity: true
        )
        let converter = TransferSyntaxConverter(configuration: config)
        
        // When selecting a target syntax, lossy syntaxes should be skipped
        let accepted = [
            TransferSyntax.jpegBaseline.uid,
            TransferSyntax.explicitVRLittleEndian.uid
        ]
        
        let target = converter.selectTargetSyntax(
            for: Data(),
            sourceSyntax: .implicitVRLittleEndian,
            acceptedSyntaxes: accepted
        )
        
        // Should select Explicit VR LE because JPEG Baseline is lossy
        #expect(target?.uid == TransferSyntax.explicitVRLittleEndian.uid)
        #expect(target?.isLossless == true)
    }
    
    // MARK: - Uncompressed Transcoding Tests
    
    @Test("Transcode simple data element from Explicit to Implicit VR")
    func testTranscodeExplicitToImplicit() throws {
        let converter = TransferSyntaxConverter()
        
        // Create a simple Explicit VR Little Endian data element
        // PatientName (0010,0010), VR=PN, Value="Test^Patient"
        var sourceData = Data()
        // Tag: (0010,0010)
        sourceData.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Group, Element (LE)
        // VR: PN
        sourceData.append(contentsOf: "PN".utf8)
        // Length: 12 (2 bytes for 16-bit VRs)
        sourceData.append(contentsOf: [0x0C, 0x00])
        // Value: "Test^Patient"
        sourceData.append(contentsOf: "Test^Patient".utf8)
        
        let result = try converter.transcode(
            dataSetData: sourceData,
            from: .explicitVRLittleEndian,
            to: .implicitVRLittleEndian
        )
        
        #expect(result.wasTranscoded == true)
        #expect(result.isLossless == true)
        #expect(result.targetTransferSyntax.uid == TransferSyntax.implicitVRLittleEndian.uid)
        
        // Implicit VR should have different structure (no VR field)
        // Tag (4 bytes) + Length (4 bytes) + Value (12 bytes) = 20 bytes
        #expect(result.data.count == 20)
    }
    
    @Test("Transcode simple data element from Implicit to Explicit VR")
    func testTranscodeImplicitToExplicit() throws {
        let converter = TransferSyntaxConverter()
        
        // Create a simple Implicit VR Little Endian data element
        // PatientName (0010,0010), Value="Test^Patient"
        var sourceData = Data()
        // Tag: (0010,0010)
        sourceData.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Group, Element (LE)
        // Length: 12 (4 bytes for Implicit VR)
        sourceData.append(contentsOf: [0x0C, 0x00, 0x00, 0x00])
        // Value: "Test^Patient"
        sourceData.append(contentsOf: "Test^Patient".utf8)
        
        let result = try converter.transcode(
            dataSetData: sourceData,
            from: .implicitVRLittleEndian,
            to: .explicitVRLittleEndian
        )
        
        #expect(result.wasTranscoded == true)
        #expect(result.isLossless == true)
        #expect(result.targetTransferSyntax.uid == TransferSyntax.explicitVRLittleEndian.uid)
    }
    
    @Test("Transcode US (UInt16) data element with byte order change")
    func testTranscodeByteOrderChange() throws {
        let converter = TransferSyntaxConverter()
        
        // Create an Explicit VR Little Endian data element with US (UInt16) value
        // Rows (0028,0010), VR=US, Value=512 (0x0200 LE)
        var sourceData = Data()
        // Tag: (0028,0010)
        sourceData.append(contentsOf: [0x28, 0x00, 0x10, 0x00]) // Group, Element (LE)
        // VR: US
        sourceData.append(contentsOf: "US".utf8)
        // Length: 2 (2 bytes for 16-bit VRs)
        sourceData.append(contentsOf: [0x02, 0x00])
        // Value: 512 (0x0200) in Little Endian = [0x00, 0x02]
        sourceData.append(contentsOf: [0x00, 0x02])
        
        let result = try converter.transcode(
            dataSetData: sourceData,
            from: .explicitVRLittleEndian,
            to: .explicitVRBigEndian
        )
        
        #expect(result.wasTranscoded == true)
        #expect(result.isLossless == true)
        
        // Check that the value was byte-swapped
        // In Big Endian, 512 (0x0200) should be [0x02, 0x00]
        // Tag in BE: [0x00, 0x28, 0x00, 0x10]
        // VR: US
        // Length in BE: [0x00, 0x02]
        // Value in BE: [0x02, 0x00]
        let expectedLength = 4 + 2 + 2 + 2 // Tag + VR + Length + Value
        #expect(result.data.count == expectedLength)
    }
    
    @Test("Transcode multiple data elements")
    func testTranscodeMultipleElements() throws {
        let converter = TransferSyntaxConverter()
        
        var sourceData = Data()
        
        // Element 1: Rows (0028,0010), VR=US, Value=256
        sourceData.append(contentsOf: [0x28, 0x00, 0x10, 0x00]) // Tag (LE)
        sourceData.append(contentsOf: "US".utf8)
        sourceData.append(contentsOf: [0x02, 0x00]) // Length
        sourceData.append(contentsOf: [0x00, 0x01]) // Value: 256
        
        // Element 2: Columns (0028,0011), VR=US, Value=256
        sourceData.append(contentsOf: [0x28, 0x00, 0x11, 0x00]) // Tag (LE)
        sourceData.append(contentsOf: "US".utf8)
        sourceData.append(contentsOf: [0x02, 0x00]) // Length
        sourceData.append(contentsOf: [0x00, 0x01]) // Value: 256
        
        let result = try converter.transcode(
            dataSetData: sourceData,
            from: .explicitVRLittleEndian,
            to: .implicitVRLittleEndian
        )
        
        #expect(result.wasTranscoded == true)
        #expect(result.isLossless == true)
        
        // Each element in Implicit VR: Tag (4) + Length (4) + Value (2) = 10 bytes
        // Two elements: 20 bytes
        #expect(result.data.count == 20)
    }
}

// MARK: - Compression Configuration Tests

@Suite("CompressionQuality Tests")
struct CompressionQualityTests {
    
    @Test("Quality presets have correct values")
    func testQualityPresetValues() {
        #expect(CompressionQuality.maximum.value == 0.98)
        #expect(CompressionQuality.high.value == 0.90)
        #expect(CompressionQuality.medium.value == 0.75)
        #expect(CompressionQuality.low.value == 0.60)
    }
    
    @Test("Custom quality values are clamped")
    func testCustomQualityClamping() {
        #expect(CompressionQuality.custom(1.5).value == 1.0)
        #expect(CompressionQuality.custom(-0.5).value == 0.0)
        #expect(CompressionQuality.custom(0.5).value == 0.5)
    }
    
    @Test("Maximum quality is considered lossless")
    func testLosslessQuality() {
        #expect(CompressionQuality.maximum.isLossless == true)
        #expect(CompressionQuality.custom(1.0).isLossless == true)
        #expect(CompressionQuality.high.isLossless == false)
    }
    
    @Test("Quality descriptions are meaningful")
    func testQualityDescriptions() {
        #expect(CompressionQuality.maximum.description.contains("Maximum"))
        #expect(CompressionQuality.high.description.contains("High"))
        #expect(CompressionQuality.medium.description.contains("Medium"))
        #expect(CompressionQuality.low.description.contains("Low"))
        #expect(CompressionQuality.custom(0.5).description.contains("50"))
    }
}

@Suite("CompressionSpeed Tests")
struct CompressionSpeedTests {
    
    @Test("Speed descriptions are meaningful")
    func testSpeedDescriptions() {
        #expect(CompressionSpeed.fast.description == "Fast")
        #expect(CompressionSpeed.balanced.description == "Balanced")
        #expect(CompressionSpeed.optimal.description == "Optimal")
    }
}

@Suite("CompressionConfiguration Tests")
struct CompressionConfigurationTests {
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = CompressionConfiguration.default
        
        #expect(config.quality.value == CompressionQuality.high.value)
        #expect(config.speed == .balanced)
        #expect(config.progressive == false)
        #expect(config.preferLossless == false)
        #expect(config.maxBitsPerSample == nil)
    }
    
    @Test("Network configuration optimizes for transfer")
    func testNetworkConfiguration() {
        let config = CompressionConfiguration.network
        
        #expect(config.quality == .medium)
        #expect(config.speed == .fast)
        #expect(config.progressive == true)
        #expect(config.preferLossless == false)
    }
    
    @Test("Archival configuration prioritizes quality")
    func testArchivalConfiguration() {
        let config = CompressionConfiguration.archival
        
        #expect(config.quality == .maximum)
        #expect(config.speed == .optimal)
        #expect(config.preferLossless == true)
    }
    
    @Test("Lossless configuration enforces lossless")
    func testLosslessConfiguration() {
        let config = CompressionConfiguration.lossless
        
        #expect(config.quality == .maximum)
        #expect(config.preferLossless == true)
    }
    
    @Test("Custom configuration creation")
    func testCustomConfiguration() {
        let config = CompressionConfiguration(
            quality: .custom(0.85),
            speed: .optimal,
            progressive: true,
            preferLossless: false,
            maxBitsPerSample: 12
        )
        
        #expect(config.quality.value == 0.85)
        #expect(config.speed == .optimal)
        #expect(config.progressive == true)
        #expect(config.preferLossless == false)
        #expect(config.maxBitsPerSample == 12)
    }
    
    @Test("Configuration description is informative")
    func testConfigurationDescription() {
        let config = CompressionConfiguration(
            quality: .high,
            speed: .balanced,
            progressive: true,
            preferLossless: true,
            maxBitsPerSample: 16
        )
        
        let description = config.description
        #expect(description.contains("quality"))
        #expect(description.contains("speed"))
        #expect(description.contains("progressive"))
        #expect(description.contains("preferLossless"))
        #expect(description.contains("maxBits"))
    }
}

// MARK: - Codec Registry Encoder Tests

#if canImport(ImageIO)
@Suite("CodecRegistry Encoder Tests")
struct CodecRegistryEncoderTests {
    
    @Test("Registry has encoders for JPEG")
    func testJPEGEncoderAvailable() {
        let registry = CodecRegistry.shared
        
        #expect(registry.hasEncoder(for: TransferSyntax.jpegBaseline.uid) == true)
    }
    
    @Test("Registry has encoders for JPEG 2000")
    func testJPEG2000EncoderAvailable() {
        let registry = CodecRegistry.shared
        
        #expect(registry.hasEncoder(for: TransferSyntax.jpeg2000.uid) == true)
        #expect(registry.hasEncoder(for: TransferSyntax.jpeg2000Lossless.uid) == true)
    }
    
    @Test("Registry returns encoder for supported syntax")
    func testEncoderRetrieval() {
        let registry = CodecRegistry.shared
        
        let jpegEncoder = registry.encoder(for: TransferSyntax.jpegBaseline.uid)
        #expect(jpegEncoder != nil)
        
        let jp2Encoder = registry.encoder(for: TransferSyntax.jpeg2000.uid)
        #expect(jp2Encoder != nil)
    }
    
    @Test("Registry does not have encoder for RLE")
    func testNoRLEEncoder() {
        let registry = CodecRegistry.shared
        
        // RLE is decode-only
        #expect(registry.hasEncoder(for: TransferSyntax.rleLossless.uid) == false)
    }
    
    @Test("Supported encoding transfer syntaxes list is populated")
    func testSupportedEncodingList() {
        let registry = CodecRegistry.shared
        
        let encodingSyntaxes = registry.supportedEncodingTransferSyntaxes
        #expect(encodingSyntaxes.count >= 3) // JPEG Baseline, JPEG 2000, JPEG 2000 Lossless
    }
}
#endif

// MARK: - JPEG Encoder Tests

#if canImport(ImageIO)
@Suite("NativeJPEGCodec Encoder Tests")
struct NativeJPEGCodecEncoderTests {
    
    @Test("Can encode 8-bit grayscale")
    func testCanEncode8BitGrayscale() {
        let codec = NativeJPEGCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.default
        #expect(codec.canEncode(with: config, descriptor: descriptor) == true)
    }
    
    @Test("Can encode 8-bit RGB")
    func testCanEncode8BitRGB() {
        let codec = NativeJPEGCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb
        )
        
        let config = CompressionConfiguration.default
        #expect(codec.canEncode(with: config, descriptor: descriptor) == true)
    }
    
    @Test("Cannot encode 16-bit with JPEG Baseline")
    func testCannotEncode16Bit() {
        let codec = NativeJPEGCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.default
        #expect(codec.canEncode(with: config, descriptor: descriptor) == false)
    }
    
    @Test("Cannot encode when lossless is preferred")
    func testCannotEncodeLossless() {
        let codec = NativeJPEGCodec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.lossless
        #expect(codec.canEncode(with: config, descriptor: descriptor) == false)
    }
    
    @Test("Encode simple 8-bit grayscale frame")
    func testEncodeGrayscaleFrame() throws {
        let codec = NativeJPEGCodec()
        let descriptor = PixelDataDescriptor(
            rows: 4,
            columns: 4,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        // Create 4x4 test image (gradient)
        var pixelData = Data()
        for y in 0..<4 {
            for x in 0..<4 {
                pixelData.append(UInt8(y * 64 + x * 16))
            }
        }
        
        let config = CompressionConfiguration.default
        let encoded = try codec.encodeFrame(pixelData, descriptor: descriptor, frameIndex: 0, configuration: config)
        
        // Verify we got JPEG data (starts with FFD8)
        #expect(encoded.count > 0)
        #expect(encoded[0] == 0xFF)
        #expect(encoded[1] == 0xD8)
    }
}
#endif

// MARK: - JPEG 2000 Encoder Tests

#if canImport(ImageIO)
@Suite("NativeJPEG2000Codec Encoder Tests")
struct NativeJPEG2000CodecEncoderTests {
    
    @Test("Can encode 8-bit grayscale")
    func testCanEncode8BitGrayscale() {
        let codec = NativeJPEG2000Codec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.default
        #expect(codec.canEncode(with: config, descriptor: descriptor) == true)
    }
    
    @Test("Can encode 16-bit grayscale")
    func testCanEncode16BitGrayscale() {
        let codec = NativeJPEG2000Codec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.default
        #expect(codec.canEncode(with: config, descriptor: descriptor) == true)
    }
    
    @Test("Can encode with lossless configuration")
    func testCanEncodeLossless() {
        let codec = NativeJPEG2000Codec()
        let descriptor = PixelDataDescriptor(
            rows: 64,
            columns: 64,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        
        let config = CompressionConfiguration.lossless
        #expect(codec.canEncode(with: config, descriptor: descriptor) == true)
    }
}
#endif

// MARK: - Converter Compression Tests

@Suite("TransferSyntaxConverter Compression Tests")
struct TransferSyntaxConverterCompressionTests {
    
    @Test("Converter with compression configuration")
    func testConverterWithCompressionConfig() {
        let transcodingConfig = TranscodingConfiguration.maxCompression
        let compressionConfig = CompressionConfiguration.network
        
        let converter = TransferSyntaxConverter(
            configuration: transcodingConfig,
            compressionConfiguration: compressionConfig
        )
        
        #expect(converter.configuration.allowLossyCompression == true)
        #expect(converter.compressionConfiguration.progressive == true)
    }
}
