import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-compress CLI tool functionality
/// Note: Tests focus on DICOMKit/DICOMCore compression and transfer syntax functionality,
/// as CompressionManager is in the executable target and not directly testable
final class DICOMCompressTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a minimal DICOM file with pixel data for testing
    private func createTestDICOMFile(
        rows: UInt16 = 64,
        columns: UInt16 = 64,
        bitsAllocated: UInt16 = 8
    ) -> DICOMFile {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("CT", for: .modality, vr: .CS)
        dataSet.setUInt16(rows, for: .rows)
        dataSet.setUInt16(columns, for: .columns)
        dataSet.setUInt16(bitsAllocated, for: .bitsAllocated)
        dataSet.setUInt16(bitsAllocated, for: .bitsStored)
        dataSet.setUInt16(bitsAllocated - 1, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)

        let pixelDataSize = Int(rows) * Int(columns) * (Int(bitsAllocated) / 8)
        let pixelData = Data(repeating: 128, count: pixelDataSize)
        let vr: VR = bitsAllocated <= 8 ? .OB : .OW
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: vr, data: pixelData)

        return DICOMFile.create(dataSet: dataSet)
    }

    // MARK: - Transfer Syntax Properties Tests

    func testTransferSyntaxEncapsulatedProperty() {
        // Uncompressed syntaxes should not be encapsulated
        XCTAssertFalse(TransferSyntax.implicitVRLittleEndian.isEncapsulated)
        XCTAssertFalse(TransferSyntax.explicitVRLittleEndian.isEncapsulated)
        XCTAssertFalse(TransferSyntax.explicitVRBigEndian.isEncapsulated)

        // Compressed syntaxes should be encapsulated
        XCTAssertTrue(TransferSyntax.jpegBaseline.isEncapsulated)
        XCTAssertTrue(TransferSyntax.jpegLossless.isEncapsulated)
        XCTAssertTrue(TransferSyntax.jpegLosslessSV1.isEncapsulated)
        XCTAssertTrue(TransferSyntax.jpeg2000Lossless.isEncapsulated)
        XCTAssertTrue(TransferSyntax.jpeg2000.isEncapsulated)
        XCTAssertTrue(TransferSyntax.rleLossless.isEncapsulated)
    }

    func testTransferSyntaxLosslessProperty() {
        // Lossless syntaxes
        XCTAssertTrue(TransferSyntax.implicitVRLittleEndian.isLossless)
        XCTAssertTrue(TransferSyntax.explicitVRLittleEndian.isLossless)
        XCTAssertTrue(TransferSyntax.jpegLossless.isLossless)
        XCTAssertTrue(TransferSyntax.jpegLosslessSV1.isLossless)
        XCTAssertTrue(TransferSyntax.jpeg2000Lossless.isLossless)
        XCTAssertTrue(TransferSyntax.rleLossless.isLossless)

        // Lossy syntaxes
        XCTAssertFalse(TransferSyntax.jpegBaseline.isLossless)
        XCTAssertFalse(TransferSyntax.jpeg2000.isLossless)
    }

    func testTransferSyntaxCategoryChecks() {
        // JPEG checks
        XCTAssertTrue(TransferSyntax.jpegBaseline.isJPEG)
        XCTAssertTrue(TransferSyntax.jpegLossless.isJPEG)
        XCTAssertTrue(TransferSyntax.jpegLosslessSV1.isJPEG)
        XCTAssertFalse(TransferSyntax.jpeg2000.isJPEG)
        XCTAssertFalse(TransferSyntax.rleLossless.isJPEG)

        // JPEG 2000 checks
        XCTAssertTrue(TransferSyntax.jpeg2000Lossless.isJPEG2000)
        XCTAssertTrue(TransferSyntax.jpeg2000.isJPEG2000)
        XCTAssertFalse(TransferSyntax.jpegBaseline.isJPEG2000)
        XCTAssertFalse(TransferSyntax.rleLossless.isJPEG2000)

        // RLE checks
        XCTAssertTrue(TransferSyntax.rleLossless.isRLE)
        XCTAssertFalse(TransferSyntax.jpegBaseline.isRLE)
        XCTAssertFalse(TransferSyntax.jpeg2000.isRLE)
    }

    func testTransferSyntaxFromKnownUIDs() {
        let implicitVR = TransferSyntax.from(uid: "1.2.840.10008.1.2")
        XCTAssertNotNil(implicitVR)
        XCTAssertEqual(implicitVR?.uid, TransferSyntax.implicitVRLittleEndian.uid)

        let explicitVR = TransferSyntax.from(uid: "1.2.840.10008.1.2.1")
        XCTAssertNotNil(explicitVR)
        XCTAssertEqual(explicitVR?.uid, TransferSyntax.explicitVRLittleEndian.uid)

        let jpegBaseline = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.50")
        XCTAssertNotNil(jpegBaseline)
        XCTAssertTrue(jpegBaseline?.isJPEG ?? false)

        let jpeg2000Lossless = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.90")
        XCTAssertNotNil(jpeg2000Lossless)
        XCTAssertTrue(jpeg2000Lossless?.isJPEG2000 ?? false)

        let rle = TransferSyntax.from(uid: "1.2.840.10008.1.2.5")
        XCTAssertNotNil(rle)
        XCTAssertTrue(rle?.isRLE ?? false)
    }

    func testTransferSyntaxFromUnknownUID() {
        let unknown = TransferSyntax.from(uid: "1.2.3.4.5.6.7.8.9.99999")
        XCTAssertNil(unknown)

        let empty = TransferSyntax.from(uid: "")
        XCTAssertNil(empty)
    }

    // MARK: - TranscodingConfiguration Tests

    func testDefaultTranscodingConfiguration() {
        let config = TranscodingConfiguration.default
        XCTAssertFalse(config.allowLossyCompression)
        XCTAssertTrue(config.preservePixelDataFidelity)
        XCTAssertFalse(config.preferredSyntaxes.isEmpty)
        XCTAssertTrue(config.preferredSyntaxes.contains(TransferSyntax.explicitVRLittleEndian))
    }

    func testMaxCompressionTranscodingConfiguration() {
        let config = TranscodingConfiguration.maxCompression
        XCTAssertTrue(config.allowLossyCompression)
        XCTAssertFalse(config.preservePixelDataFidelity)
        XCTAssertFalse(config.preferredSyntaxes.isEmpty)
        // Max compression should prefer lossy formats
        XCTAssertTrue(config.preferredSyntaxes.contains(TransferSyntax.jpegBaseline))
    }

    func testLosslessTranscodingConfiguration() {
        let config = TranscodingConfiguration.losslessCompression
        XCTAssertFalse(config.allowLossyCompression)
        XCTAssertTrue(config.preservePixelDataFidelity)
        // Should prefer lossless compressed formats
        XCTAssertTrue(config.preferredSyntaxes.contains(TransferSyntax.jpeg2000Lossless))
    }

    func testCustomTranscodingConfiguration() {
        let config = TranscodingConfiguration(
            preferredSyntaxes: [.explicitVRLittleEndian],
            allowLossyCompression: true,
            preservePixelDataFidelity: false
        )
        XCTAssertTrue(config.allowLossyCompression)
        XCTAssertFalse(config.preservePixelDataFidelity)
        XCTAssertEqual(config.preferredSyntaxes.count, 1)
        XCTAssertEqual(config.preferredSyntaxes.first?.uid, TransferSyntax.explicitVRLittleEndian.uid)
    }

    // MARK: - CompressionConfiguration Tests

    func testCompressionQualityValues() {
        XCTAssertEqual(CompressionQuality.maximum.value, 0.98, accuracy: 0.001)
        XCTAssertEqual(CompressionQuality.high.value, 0.90, accuracy: 0.001)
        XCTAssertEqual(CompressionQuality.medium.value, 0.75, accuracy: 0.001)
        XCTAssertEqual(CompressionQuality.low.value, 0.60, accuracy: 0.001)
    }

    func testCompressionSpeedEnumValues() {
        // Verify all speed values can be used in configuration
        let fast = CompressionConfiguration(quality: .high, speed: .fast)
        let balanced = CompressionConfiguration(quality: .high, speed: .balanced)
        let optimal = CompressionConfiguration(quality: .high, speed: .optimal)

        XCTAssertEqual(fast.speed, .fast)
        XCTAssertEqual(balanced.speed, .balanced)
        XCTAssertEqual(optimal.speed, .optimal)
    }

    func testCompressionPreferLosslessSetting() {
        let losslessConfig = CompressionConfiguration(quality: .high, speed: .balanced, preferLossless: true)
        XCTAssertTrue(losslessConfig.preferLossless)

        let defaultConfig = CompressionConfiguration(quality: .high, speed: .balanced)
        XCTAssertFalse(defaultConfig.preferLossless)
    }

    func testCompressionCustomQualityValue() {
        let customQuality = CompressionQuality.custom(0.42)
        XCTAssertEqual(customQuality.value, 0.42, accuracy: 0.001)

        let config = CompressionConfiguration(quality: .custom(0.55), speed: .fast)
        XCTAssertEqual(config.quality.value, 0.55, accuracy: 0.001)
    }

    // MARK: - TransferSyntaxConverter Tests

    func testConverterInitialization() {
        let converter = TransferSyntaxConverter()
        XCTAssertNotNil(converter)
    }

    func testCanTranscodeBetweenUncompressedSyntaxes() {
        let converter = TransferSyntaxConverter()

        XCTAssertTrue(converter.canTranscode(
            from: .implicitVRLittleEndian,
            to: .explicitVRLittleEndian
        ))
        XCTAssertTrue(converter.canTranscode(
            from: .explicitVRLittleEndian,
            to: .implicitVRLittleEndian
        ))
        XCTAssertTrue(converter.canTranscode(
            from: .explicitVRLittleEndian,
            to: .explicitVRBigEndian
        ))
    }

    func testCanTranscodeFromUncompressedToCompressed() {
        let converter = TransferSyntaxConverter()

        // Compression requires an encoder in the CodecRegistry
        let hasEncoder = CodecRegistry.shared.hasEncoder(for: TransferSyntax.jpegBaseline.uid)
        let canCompressJPEG = converter.canTranscode(
            from: .explicitVRLittleEndian,
            to: .jpegBaseline
        )
        // canTranscode should match encoder availability
        XCTAssertEqual(canCompressJPEG, hasEncoder)
    }

    func testCanTranscodeFromCompressedToUncompressed() {
        let converter = TransferSyntaxConverter()

        // Decompression requires a codec in the CodecRegistry
        let hasCodec = CodecRegistry.shared.hasCodec(for: TransferSyntax.jpegBaseline.uid)
        let canDecompress = converter.canTranscode(
            from: .jpegBaseline,
            to: .explicitVRLittleEndian
        )
        // canTranscode should match codec availability
        XCTAssertEqual(canDecompress, hasCodec)
    }

    func testCanTranscodeSameSyntax() {
        let converter = TransferSyntaxConverter()

        // Same syntax to same syntax should always succeed
        XCTAssertTrue(converter.canTranscode(
            from: .explicitVRLittleEndian,
            to: .explicitVRLittleEndian
        ))
        XCTAssertTrue(converter.canTranscode(
            from: .implicitVRLittleEndian,
            to: .implicitVRLittleEndian
        ))
    }

    // MARK: - CodecRegistry Tests

    func testCodecRegistrySupportedTransferSyntaxes() {
        let registry = CodecRegistry.shared
        let supported = registry.supportedTransferSyntaxes
        // Registry should report at least some supported syntaxes
        XCTAssertNotNil(supported)
    }

    func testCodecRegistryHasCodecForJPEG() {
        let registry = CodecRegistry.shared
        let hasJPEG = registry.hasCodec(for: TransferSyntax.jpegBaseline.uid)
        // Verify consistency: if codec exists, it should also appear in supported list
        if hasJPEG {
            XCTAssertTrue(registry.supportedTransferSyntaxes.contains(TransferSyntax.jpegBaseline.uid))
        }
    }

    func testCodecRegistryHasEncoderCheck() {
        let registry = CodecRegistry.shared
        let hasEncoder = registry.hasEncoder(for: TransferSyntax.jpegBaseline.uid)
        // Verify consistency: if encoder exists, it should also appear in encoding list
        if hasEncoder {
            XCTAssertTrue(registry.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpegBaseline.uid))
        }
    }

    func testCodecRegistryJPEG2000Availability() {
        let registry = CodecRegistry.shared
        let hasJPEG2000 = registry.hasCodec(for: TransferSyntax.jpeg2000Lossless.uid)
        // Verify consistency: if codec exists, it should also appear in supported list
        if hasJPEG2000 {
            XCTAssertTrue(registry.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid))
        }
    }

    // MARK: - DICOM File Compression Info Tests

    func testDICOMFileTransferSyntaxInfo() {
        let file = createTestDICOMFile()
        // DICOMFile.create defaults to Explicit VR Little Endian
        let tsUID = file.transferSyntaxUID
        XCTAssertNotNil(tsUID)
        XCTAssertEqual(tsUID, "1.2.840.10008.1.2.1")
    }

    func testDICOMFileExplicitVRIsUncompressed() {
        let file = createTestDICOMFile()
        let tsUID = file.transferSyntaxUID ?? ""
        let syntax = TransferSyntax.from(uid: tsUID)
        XCTAssertNotNil(syntax)
        XCTAssertFalse(syntax?.isEncapsulated ?? true)
        XCTAssertTrue(syntax?.isExplicitVR ?? false)
    }

    func testDICOMFilePixelDataSize() {
        let rows: UInt16 = 64
        let columns: UInt16 = 64
        let bitsAllocated: UInt16 = 8
        let file = createTestDICOMFile(rows: rows, columns: columns, bitsAllocated: bitsAllocated)

        let pixelElement = file.dataSet[.pixelData]
        XCTAssertNotNil(pixelElement)

        let expectedSize = Int(rows) * Int(columns) * (Int(bitsAllocated) / 8)
        XCTAssertEqual(Int(pixelElement?.length ?? 0), expectedSize)
    }

    func testDICOMFileImageDimensions() {
        let file = createTestDICOMFile(rows: 128, columns: 256)

        let rows = file.dataSet.uint16(for: .rows)
        let columns = file.dataSet.uint16(for: .columns)
        XCTAssertEqual(rows, 128)
        XCTAssertEqual(columns, 256)
    }

    func testDICOMFileBitsAllocatedAndStored() {
        let file8 = createTestDICOMFile(bitsAllocated: 8)
        XCTAssertEqual(file8.dataSet.uint16(for: .bitsAllocated), 8)
        XCTAssertEqual(file8.dataSet.uint16(for: .bitsStored), 8)
        XCTAssertEqual(file8.dataSet.uint16(for: .highBit), 7)

        let file16 = createTestDICOMFile(bitsAllocated: 16)
        XCTAssertEqual(file16.dataSet.uint16(for: .bitsAllocated), 16)
        XCTAssertEqual(file16.dataSet.uint16(for: .bitsStored), 16)
        XCTAssertEqual(file16.dataSet.uint16(for: .highBit), 15)
    }

    func testDICOMFilePhotometricInterpretation() {
        let file = createTestDICOMFile()
        let photometric = file.dataSet.string(for: .photometricInterpretation)
        XCTAssertNotNil(photometric)
        XCTAssertTrue(photometric?.contains("MONOCHROME2") ?? false)
    }

    func testDICOMFileNumberOfFrames() {
        // File without explicit numberOfFrames should return nil
        let file = createTestDICOMFile()
        let frames = file.numberOfFrames
        XCTAssertNil(frames)
    }

    func testDICOMFileWithExplicitNumberOfFrames() {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6.7.8.9", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("Test^Patient", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("CT", for: .modality, vr: .CS)
        dataSet.setUInt16(64, for: .rows)
        dataSet.setUInt16(64, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        dataSet.setString("5", for: .numberOfFrames, vr: .IS)

        let pixelData = Data(repeating: 128, count: 64 * 64 * 5)
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixelData)

        let file = DICOMFile.create(dataSet: dataSet)
        XCTAssertEqual(file.numberOfFrames, 5)
    }

    // MARK: - Transfer Syntax Byte Order and VR Tests

    func testTransferSyntaxByteOrder() {
        XCTAssertEqual(TransferSyntax.implicitVRLittleEndian.byteOrder, .littleEndian)
        XCTAssertEqual(TransferSyntax.explicitVRLittleEndian.byteOrder, .littleEndian)
        XCTAssertEqual(TransferSyntax.explicitVRBigEndian.byteOrder, .bigEndian)
        XCTAssertEqual(TransferSyntax.jpegBaseline.byteOrder, .littleEndian)
    }

    func testTransferSyntaxExplicitVRProperty() {
        XCTAssertFalse(TransferSyntax.implicitVRLittleEndian.isExplicitVR)
        XCTAssertTrue(TransferSyntax.explicitVRLittleEndian.isExplicitVR)
        XCTAssertTrue(TransferSyntax.explicitVRBigEndian.isExplicitVR)
        XCTAssertTrue(TransferSyntax.jpegBaseline.isExplicitVR)
    }

    // MARK: - DICOM File Round-Trip Tests

    func testDICOMFileWriteAndRead() throws {
        let original = createTestDICOMFile(rows: 32, columns: 32, bitsAllocated: 8)
        let data = try original.write()
        let parsed = try DICOMFile.read(from: data)

        XCTAssertEqual(parsed.dataSet.string(for: .modality), "CT")
        XCTAssertEqual(parsed.dataSet.uint16(for: .rows), 32)
        XCTAssertEqual(parsed.dataSet.uint16(for: .columns), 32)
        XCTAssertEqual(parsed.dataSet.uint16(for: .bitsAllocated), 8)
    }

    func testDICOMFilePreservesPixelData() throws {
        let original = createTestDICOMFile(rows: 16, columns: 16, bitsAllocated: 8)
        let data = try original.write()
        let parsed = try DICOMFile.read(from: data)

        let originalPixel = original.dataSet[.pixelData]
        let parsedPixel = parsed.dataSet[.pixelData]
        XCTAssertNotNil(originalPixel)
        XCTAssertNotNil(parsedPixel)
        XCTAssertEqual(originalPixel?.valueData, parsedPixel?.valueData)
    }

    func testDICOMFile16BitPixelData() throws {
        let original = createTestDICOMFile(rows: 32, columns: 32, bitsAllocated: 16)
        let data = try original.write()
        let parsed = try DICOMFile.read(from: data)

        XCTAssertEqual(parsed.dataSet.uint16(for: .bitsAllocated), 16)
        XCTAssertEqual(parsed.dataSet.uint16(for: .bitsStored), 16)

        let pixelElement = parsed.dataSet[.pixelData]
        XCTAssertNotNil(pixelElement)
        let expectedSize = 32 * 32 * 2
        XCTAssertEqual(Int(pixelElement?.length ?? 0), expectedSize)
    }

    // MARK: - Compression Quality Lossless Property Tests

    func testCompressionQualityLosslessProperty() {
        XCTAssertTrue(CompressionQuality.maximum.isLossless)
        XCTAssertFalse(CompressionQuality.high.isLossless)
        XCTAssertFalse(CompressionQuality.medium.isLossless)
        XCTAssertFalse(CompressionQuality.low.isLossless)
    }

    // MARK: - CompressionConfiguration Presets Tests

    func testCompressionConfigurationDefaultPreset() {
        let config = CompressionConfiguration.default
        XCTAssertEqual(config.quality, .high)
        XCTAssertEqual(config.speed, .balanced)
    }

    func testCompressionConfigurationLosslessPreset() {
        let config = CompressionConfiguration.lossless
        XCTAssertTrue(config.preferLossless)
        XCTAssertTrue(config.quality.isLossless)
    }
}
