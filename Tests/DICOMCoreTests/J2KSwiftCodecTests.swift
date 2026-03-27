import XCTest
@testable import DICOMCore

/// Tests for the J2KSwiftCodec — the pure-Swift JPEG 2000 adapter backed by J2KSwift.
///
/// Covers:
/// - Transfer syntax support declarations (6 tests)
/// - Capability queries via `canEncode` (6 tests)
/// - Decode error handling: empty, corrupt, truncated data (3 tests)
/// - Encode validation across all supported pixel configurations (10 tests)
/// - Lossy quality levels with compression ratio validation (8 tests)
/// - Multi-frame encoding (2 tests)
/// - Configuration variations: archival, network, default (3 tests)
/// - Encode with invalid data (1 test)
/// - Codec registry integration (8 tests)
/// - Sendable conformance (1 test)
/// - J2K codestream format validation (2 tests)
///
/// Note: Full encode → decode round-trip tests are deferred pending resolution of
/// a J2KSwift v2.0.0 dequantization overflow in `DecoderPipeline.applyDequantization`
/// (tracked upstream). Encoding produces valid J2K codestreams verified by SOC marker.
final class J2KSwiftCodecTests: XCTestCase {
    private let codec = J2KSwiftCodec()

    // MARK: - Transfer Syntax Declarations (6 tests)

    func test_supportedTransferSyntaxes_containsLossless() {
        XCTAssertTrue(
            J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid),
            "Should support JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)"
        )
    }

    func test_supportedTransferSyntaxes_containsLossy() {
        XCTAssertTrue(
            J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid),
            "Should support JPEG 2000 Lossy (1.2.840.10008.1.2.4.91)"
        )
    }

    func test_supportedTransferSyntaxes_count() {
        XCTAssertEqual(J2KSwiftCodec.supportedTransferSyntaxes.count, 2)
    }

    func test_supportedEncodingTransferSyntaxes_containsLossless() {
        XCTAssertTrue(
            J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid)
        )
    }

    func test_supportedEncodingTransferSyntaxes_containsLossy() {
        XCTAssertTrue(
            J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid)
        )
    }

    func test_supportedEncodingTransferSyntaxes_count() {
        XCTAssertEqual(J2KSwiftCodec.supportedEncodingTransferSyntaxes.count, 2)
    }

    // MARK: - canEncode Capability (6 tests)

    func test_canEncode_8bitGrayscale_returnsTrue() {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        XCTAssertTrue(codec.canEncode(with: .default, descriptor: desc))
    }

    func test_canEncode_16bitGrayscale_returnsTrue() {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 16, samplesPerPixel: 1)
        XCTAssertTrue(codec.canEncode(with: .default, descriptor: desc))
    }

    func test_canEncode_8bitRGB_returnsTrue() {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 3, photometric: .rgb)
        XCTAssertTrue(codec.canEncode(with: .default, descriptor: desc))
    }

    func test_canEncode_12bitGrayscale_returnsTrue() {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 12, samplesPerPixel: 1)
        XCTAssertTrue(codec.canEncode(with: .default, descriptor: desc))
    }

    func test_canEncode_32bitAllocated_returnsFalse() {
        let desc = PixelDataDescriptor(
            rows: 64, columns: 64, bitsAllocated: 32, bitsStored: 32, highBit: 31,
            isSigned: false, samplesPerPixel: 1, photometricInterpretation: .monochrome2
        )
        XCTAssertFalse(codec.canEncode(with: .default, descriptor: desc))
    }

    func test_canEncode_4samplesPerPixel_returnsFalse() {
        let desc = PixelDataDescriptor(
            rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 4, photometricInterpretation: .rgb
        )
        XCTAssertFalse(codec.canEncode(with: .default, descriptor: desc))
    }

    // MARK: - Decode Error Handling (3 tests)

    func test_decodeFrame_emptyData_throws() {
        let desc = makeDescriptor(rows: 8, columns: 8, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        XCTAssertThrowsError(try codec.decodeFrame(Data(), descriptor: desc, frameIndex: 0)) { error in
            guard case DICOMError.parsingFailed(let msg) = error else {
                XCTFail("Expected DICOMError.parsingFailed, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Empty"))
        }
    }

    func test_decodeFrame_corruptData_throws() {
        let garbage = Data(repeating: 0xAB, count: 100)
        let desc = makeDescriptor(rows: 8, columns: 8, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        XCTAssertThrowsError(try codec.decodeFrame(garbage, descriptor: desc, frameIndex: 0))
    }

    func test_decodeFrame_truncatedData_throws() {
        let truncated = Data([0xFF, 0x4F, 0xFF, 0x51])
        let desc = makeDescriptor(rows: 8, columns: 8, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        XCTAssertThrowsError(try codec.decodeFrame(truncated, descriptor: desc, frameIndex: 0))
    }

    // MARK: - Encoding: 8-bit Grayscale (2 tests)

    func test_encode_8bitGrayscale_lossless_producesValidCodestream() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: 16, height: 16)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty, "Compressed data should not be empty")
        // JPEG 2000 codestream starts with SOC marker: 0xFF 0x4F
        XCTAssertEqual(compressed[0], 0xFF, "SOC marker high byte")
        XCTAssertEqual(compressed[1], 0x4F, "SOC marker low byte")
    }

    func test_encode_8bitGrayscale_128x128_lossless() throws {
        let desc = makeDescriptor(rows: 128, columns: 128, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: 128, height: 128)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
        XCTAssertGreaterThan(compressed.count, 0)
    }

    // MARK: - Encoding: 16-bit Grayscale (2 tests)

    func test_encode_16bitGrayscaleUnsigned_lossless() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 16, bitsStored: 16, samplesPerPixel: 1)
        let pixelData = makeGradientData16(width: 16, height: 16, signed: false)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    func test_encode_16bitGrayscaleSigned_lossless() throws {
        let desc = makeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 16, bitsStored: 16, samplesPerPixel: 1, isSigned: true
        )
        let pixelData = makeGradientData16(width: 16, height: 16, signed: true)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    // MARK: - Encoding: 8-bit RGB (1 test)

    func test_encode_8bitRGB_lossless() throws {
        let desc = makeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 3, photometric: .rgb
        )
        let pixelData = makeRGBGradient8(width: 16, height: 16)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    // MARK: - Encoding: 12-bit Grayscale (1 test)

    func test_encode_12bitGrayscale_lossless() throws {
        let desc = makeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 16, bitsStored: 12, samplesPerPixel: 1
        )
        let pixelData = makeGradientData12(width: 16, height: 16)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    // MARK: - Encoding: Uniform Data (2 tests)

    func test_encode_uniformBlack_lossless() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = Data(repeating: 0, count: 16 * 16)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    func test_encode_uniformWhite_lossless() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = Data(repeating: 255, count: 16 * 16)

        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertFalse(compressed.isEmpty)
    }

    // MARK: - Lossy Quality Levels (8 tests)

    func test_lossyEncode_quality025_compresses() throws {
        try assertLossyCompresses(quality: 0.25)
    }

    func test_lossyEncode_quality050_compresses() throws {
        try assertLossyCompresses(quality: 0.50)
    }

    func test_lossyEncode_quality075_compresses() throws {
        try assertLossyCompresses(quality: 0.75)
    }

    func test_lossyEncode_quality095_compresses() throws {
        try assertLossyCompresses(quality: 0.95)
    }

    func test_lossyEncode_quality025_producesNonEmptyOutput() throws {
        try assertLossyProducesNonEmpty(quality: 0.25)
    }

    func test_lossyEncode_quality050_producesNonEmptyOutput() throws {
        try assertLossyProducesNonEmpty(quality: 0.50)
    }

    func test_lossyEncode_quality075_producesNonEmptyOutput() throws {
        try assertLossyProducesNonEmpty(quality: 0.75)
    }

    func test_lossyEncode_quality095_producesNonEmptyOutput() throws {
        try assertLossyProducesNonEmpty(quality: 0.95)
    }

    // MARK: - Multi-Frame Encoding (2 tests)

    func test_multiFrame_encode_producesCorrectFrameCount() throws {
        let numberOfFrames = 3
        let desc = makeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8,
            samplesPerPixel: 1, numberOfFrames: numberOfFrames
        )
        var allFrameData = Data()
        for frameIndex in 0..<numberOfFrames {
            allFrameData.append(makeGradientData8(width: 16, height: 16, seed: UInt8(frameIndex * 40)))
        }

        let compressedFrames = try codec.encode(allFrameData, descriptor: desc, configuration: .lossless)
        XCTAssertEqual(compressedFrames.count, numberOfFrames, "Should produce one compressed frame per input frame")
    }

    func test_multiFrame_encode_eachFrameNonEmpty() throws {
        let numberOfFrames = 3
        let desc = makeDescriptor(
            rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8,
            samplesPerPixel: 1, numberOfFrames: numberOfFrames
        )
        var allFrameData = Data()
        for frameIndex in 0..<numberOfFrames {
            allFrameData.append(makeGradientData8(width: 16, height: 16, seed: UInt8(frameIndex * 40)))
        }

        let compressedFrames = try codec.encode(allFrameData, descriptor: desc, configuration: .lossless)
        for (index, frame) in compressedFrames.enumerated() {
            XCTAssertFalse(frame.isEmpty, "Frame \(index) should not be empty")
        }
    }

    // MARK: - Configuration Variations (3 tests)

    func test_encode_withArchivalConfig() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let data = makeGradientData8(width: 16, height: 16)
        let compressed = try codec.encodeFrame(data, descriptor: desc, frameIndex: 0, configuration: .archival)
        XCTAssertFalse(compressed.isEmpty)
    }

    func test_encode_withNetworkConfig() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let data = makeGradientData8(width: 16, height: 16)
        let compressed = try codec.encodeFrame(data, descriptor: desc, frameIndex: 0, configuration: .network)
        XCTAssertFalse(compressed.isEmpty)
    }

    func test_encode_withDefaultConfig() throws {
        let desc = makeDescriptor(rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let data = makeGradientData8(width: 16, height: 16)
        let compressed = try codec.encodeFrame(data, descriptor: desc, frameIndex: 0, configuration: .default)
        XCTAssertFalse(compressed.isEmpty)
    }

    // MARK: - Encode with Invalid Data (1 test)

    func test_encode_tooShortPixelData_throws() {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let shortData = Data(count: 10)
        XCTAssertThrowsError(try codec.encodeFrame(shortData, descriptor: desc, frameIndex: 0, configuration: .lossless))
    }

    // MARK: - Codec Registry Integration (8 tests)

    func test_codecRegistry_hasJ2KSwiftCodec_forLossless() {
        let registeredCodec = CodecRegistry.shared.codec(for: TransferSyntax.jpeg2000Lossless.uid)
        XCTAssertNotNil(registeredCodec)
        XCTAssertTrue(registeredCodec is J2KSwiftCodec)
    }

    func test_codecRegistry_hasJ2KSwiftCodec_forLossy() {
        let registeredCodec = CodecRegistry.shared.codec(for: TransferSyntax.jpeg2000.uid)
        XCTAssertNotNil(registeredCodec)
        XCTAssertTrue(registeredCodec is J2KSwiftCodec)
    }

    func test_codecRegistry_hasEncoder_forLossless() {
        let encoder = CodecRegistry.shared.encoder(for: TransferSyntax.jpeg2000Lossless.uid)
        XCTAssertNotNil(encoder)
        XCTAssertTrue(encoder is J2KSwiftCodec)
    }

    func test_codecRegistry_hasEncoder_forLossy() {
        let encoder = CodecRegistry.shared.encoder(for: TransferSyntax.jpeg2000.uid)
        XCTAssertNotNil(encoder)
        XCTAssertTrue(encoder is J2KSwiftCodec)
    }

    func test_codecRegistry_supportedTransferSyntaxes_includesJPEG2000Lossless() {
        XCTAssertTrue(CodecRegistry.shared.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid))
    }

    func test_codecRegistry_supportedTransferSyntaxes_includesJPEG2000Lossy() {
        XCTAssertTrue(CodecRegistry.shared.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid))
    }

    func test_codecRegistry_supportedEncodingTransferSyntaxes_includesJPEG2000Lossless() {
        XCTAssertTrue(CodecRegistry.shared.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid))
    }

    func test_codecRegistry_supportedEncodingTransferSyntaxes_includesJPEG2000Lossy() {
        XCTAssertTrue(CodecRegistry.shared.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid))
    }

    // MARK: - Sendable Conformance (1 test)

    func test_J2KSwiftCodec_isSendable() {
        let _: any Sendable = J2KSwiftCodec()
        let _: any ImageCodec & Sendable = J2KSwiftCodec()
        let _: any ImageEncoder & Sendable = J2KSwiftCodec()
    }

    // MARK: - J2K Codestream Validation (2 tests)

    func test_encode_producesValidSOCMarker() throws {
        let desc = makeDescriptor(rows: 32, columns: 32, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: 32, height: 32)
        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: .lossless)
        XCTAssertGreaterThanOrEqual(compressed.count, 2)
        XCTAssertEqual(compressed[0], 0xFF, "J2K codestream SOC high byte")
        XCTAssertEqual(compressed[1], 0x4F, "J2K codestream SOC low byte")
    }

    func test_encode_lossy_producesValidSOCMarker() throws {
        let desc = makeDescriptor(rows: 32, columns: 32, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: 32, height: 32)
        let config = CompressionConfiguration(quality: .medium, speed: .balanced)
        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: config)
        XCTAssertGreaterThanOrEqual(compressed.count, 2)
        XCTAssertEqual(compressed[0], 0xFF)
        XCTAssertEqual(compressed[1], 0x4F)
    }

    // MARK: - Helpers

    private func makeDescriptor(
        rows: Int,
        columns: Int,
        bitsAllocated: Int,
        bitsStored: Int,
        samplesPerPixel: Int,
        isSigned: Bool = false,
        photometric: PhotometricInterpretation = .monochrome2,
        numberOfFrames: Int = 1
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            numberOfFrames: numberOfFrames,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: bitsStored - 1,
            isSigned: isSigned,
            samplesPerPixel: samplesPerPixel,
            photometricInterpretation: photometric
        )
    }

    private func makeGradientData8(width: Int, height: Int, seed: UInt8 = 0) -> Data {
        var data = Data(count: width * height)
        for i in 0..<(width * height) {
            data[i] = UInt8(truncatingIfNeeded: Int(seed) &+ i)
        }
        return data
    }

    private func makeGradientData16(width: Int, height: Int, signed: Bool) -> Data {
        let count = width * height
        var data = Data(count: count * 2)
        data.withUnsafeMutableBytes { ptr in
            let buf = ptr.bindMemory(to: UInt16.self)
            for i in 0..<count {
                if signed {
                    let signedVal = Int16(truncatingIfNeeded: i &* 13 &- 1000)
                    buf[i] = UInt16(bitPattern: signedVal)
                } else {
                    buf[i] = UInt16(truncatingIfNeeded: i &* 17)
                }
            }
        }
        return data
    }

    private func makeGradientData12(width: Int, height: Int) -> Data {
        let count = width * height
        var data = Data(count: count * 2)
        data.withUnsafeMutableBytes { ptr in
            let buf = ptr.bindMemory(to: UInt16.self)
            for i in 0..<count {
                buf[i] = UInt16(truncatingIfNeeded: (i * 16) & 0x0FFF)
            }
        }
        return data
    }

    private func makeRGBGradient8(width: Int, height: Int) -> Data {
        var data = Data(count: width * height * 3)
        for row in 0..<height {
            for col in 0..<width {
                let offset = (row * width + col) * 3
                data[offset] = UInt8(truncatingIfNeeded: col * 4)
                data[offset + 1] = UInt8(truncatingIfNeeded: row * 4)
                data[offset + 2] = 128
            }
        }
        return data
    }

    private func assertLossyCompresses(quality: Double, file: StaticString = #filePath, line: UInt = #line) throws {
        let width = 64
        let height = 64
        let desc = makeDescriptor(rows: height, columns: width, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: width, height: height)
        let config = CompressionConfiguration(
            quality: .custom(quality), speed: .balanced, progressive: false, preferLossless: false
        )
        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: config)
        XCTAssertLessThan(
            compressed.count, pixelData.count,
            "Lossy at quality \(quality) should compress below raw size",
            file: file, line: line
        )
    }

    private func assertLossyProducesNonEmpty(quality: Double, file: StaticString = #filePath, line: UInt = #line) throws {
        let desc = makeDescriptor(rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8, samplesPerPixel: 1)
        let pixelData = makeGradientData8(width: 64, height: 64)
        let config = CompressionConfiguration(
            quality: .custom(quality), speed: .balanced, progressive: false, preferLossless: false
        )
        let compressed = try codec.encodeFrame(pixelData, descriptor: desc, frameIndex: 0, configuration: config)
        XCTAssertFalse(compressed.isEmpty, "Lossy q=\(quality) should produce non-empty output", file: file, line: line)
    }
}
