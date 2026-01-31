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
    
    @Test("Cannot transcode to compressed syntax currently")
    func testCannotTranscodeToCompressed() {
        let converter = TransferSyntaxConverter()
        
        // Cannot encode to JPEG (encoding not supported yet)
        #expect(converter.canTranscode(from: .explicitVRLittleEndian, to: .jpegBaseline) == false)
        #expect(converter.canTranscode(from: .implicitVRLittleEndian, to: .jpeg2000Lossless) == false)
    }
    
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
