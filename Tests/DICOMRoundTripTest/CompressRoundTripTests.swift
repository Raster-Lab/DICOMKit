// CompressRoundTripTests.swift
// Oracle-based round-trip tests for `dicom-compress`.
//
// Every assertion is a mathematical/semantic fact (bit-exact pixel identity,
// PSNR floor, transfer-syntax UID equality, encapsulation presence), never a
// comparison against a re-implementation of the tool.
//
// The tests drive the DICOMKit library directly through `CompressionManager`
// — the exact public entry points the dicom-compress CLI calls
// (`compressData`, `decompressData`, `getCompressionInfo(data:)`,
// `compressFile`, `decompressFile`, `findDICOMFiles`) — never the CLI binary.
//
// Codecs exercised are all pure-Swift and registered on every platform
// (RLECodec, JPEGLSCodec, J2KSwiftCodec, JLICodec), so no platform gate is
// needed. See ROUND_TRIP_TESTS_PLAN.md §3.2.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class CompressRoundTripTests: XCTestCase {

    // Canonical transfer-syntax UIDs (DICOM PS3.5).
    private let explicitLE   = "1.2.840.10008.1.2.1"
    private let implicitLE   = "1.2.840.10008.1.2"
    private let jpegLSLossl  = "1.2.840.10008.1.2.4.80"
    private let j2kLossless  = "1.2.840.10008.1.2.4.90"
    private let j2kLossy     = "1.2.840.10008.1.2.4.91"
    private let rleLossless  = "1.2.840.10008.1.2.5"
    private let jpegBaseline = "1.2.840.10008.1.2.4.50"

    // MARK: - Private helpers

    /// Transfer syntax UID recorded in the output's File Meta Information.
    private func transferSyntaxUID(of data: Data) throws -> String {
        let file = try DICOMFile.read(from: data)
        return try XCTUnwrap(file.fileMetaInformation.string(for: .transferSyntaxUID))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
    }

    /// PSNR (dB) between two equal-length byte buffers interpreted as 8-bit
    /// samples. Returns .infinity when identical. Oracle for lossy quality.
    private func psnr8(_ a: Data, _ b: Data) -> Double {
        XCTAssertEqual(a.count, b.count, "PSNR requires equal-length buffers")
        let n = min(a.count, b.count)
        guard n > 0 else { return .infinity }
        var sumSq = 0.0
        let ab = a.startIndex, bb = b.startIndex
        for i in 0..<n {
            let d = Double(Int(a[ab + i]) - Int(b[bb + i]))
            sumSq += d * d
        }
        let mse = sumSq / Double(n)
        if mse == 0 { return .infinity }
        return 10.0 * log10((255.0 * 255.0) / mse)
    }

    // MARK: - Oracle: lossless compress→decompress is bit-exact (JPEG-LS lossless)

    func testJPEGLSLosslessPixelIdentity() throws {
        let source = makeGrayscale16(rows: 32, cols: 32, fillPattern: { UInt16(($0 * 7) % 4096) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "jpeg-ls-lossless", quality: nil)
        // Encapsulated (compressed) output carries the JPEG-LS lossless TS.
        XCTAssertEqual(try transferSyntaxUID(of: compressed), jpegLSLossl)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let restored = pixelBytes(try DICOMFile.read(from: decompressed))
        // Lossless oracle: decompressed pixel bytes == original, bit-exact.
        XCTAssertEqual(restored, original)
    }

    // MARK: - Oracle: lossless compress→decompress is bit-exact (J2K lossless)

    func testJ2KLosslessPixelIdentity() throws {
        let source = makeGrayscale16(rows: 32, cols: 32, fillPattern: { UInt16(($0 * 13) % 4096) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "jpeg2000-lossless", quality: nil)
        XCTAssertEqual(try transferSyntaxUID(of: compressed), j2kLossless)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let restored = pixelBytes(try DICOMFile.read(from: decompressed))
        // Lossless oracle: bit-exact pixel identity.
        XCTAssertEqual(restored, original)
    }

    // MARK: - Oracle: lossless compress→decompress is bit-exact (RLE)

    func testRLELosslessPixelIdentity() throws {
        let source = makeGrayscale8(rows: 32, cols: 32, fillPattern: { UInt8(($0 * 3) % 256) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "rle", quality: nil)
        XCTAssertEqual(try transferSyntaxUID(of: compressed), rleLossless)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let restored = pixelBytes(try DICOMFile.read(from: decompressed))
        // Lossless oracle: bit-exact pixel identity.
        XCTAssertEqual(restored, original)
    }

    // MARK: - Oracle: lossy JPEG baseline meets PSNR floor; dimensions preserved

    func testJPEGBaselineLossyPSNRAndDimensions() throws {
        // Smooth 8-bit gradient — a realistic case where DCT lossy stays well
        // above the 40 dB floor.
        let rows: UInt16 = 32, cols: UInt16 = 32
        let source = makeGrayscale8(rows: rows, cols: cols,
                                    fillPattern: { UInt8((($0 % 32) * 8) % 256) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(
            inputData, codec: "jpeg-baseline", quality: .maximum)
        XCTAssertEqual(try transferSyntaxUID(of: compressed), jpegBaseline)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let outFile = try DICOMFile.read(from: decompressed)
        let restored = pixelBytes(outFile)

        // Dimensions/bit-depth oracle: unchanged by the lossy round-trip.
        XCTAssertEqual(outFile.dataSet.uint16(for: .rows), rows)
        XCTAssertEqual(outFile.dataSet.uint16(for: .columns), cols)
        XCTAssertEqual(outFile.dataSet.uint16(for: .bitsAllocated), 8)

        // Lossy oracle: PSNR >= 40 dB.
        XCTAssertGreaterThanOrEqual(psnr8(original, restored), 40.0)
    }

    // MARK: - Oracle: lossy J2K meets PSNR floor; dimensions preserved

    func testJ2KLossyPSNRAndDimensions() throws {
        let rows: UInt16 = 32, cols: UInt16 = 32
        let source = makeGrayscale8(rows: rows, cols: cols,
                                    fillPattern: { UInt8((($0 % 32) * 8) % 256) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "jpeg2000", quality: .maximum)
        XCTAssertEqual(try transferSyntaxUID(of: compressed), j2kLossy)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let outFile = try DICOMFile.read(from: decompressed)
        let restored = pixelBytes(outFile)

        // Dimensions oracle: unchanged.
        XCTAssertEqual(outFile.dataSet.uint16(for: .rows), rows)
        XCTAssertEqual(outFile.dataSet.uint16(for: .columns), cols)

        // Lossy oracle: PSNR >= 40 dB.
        XCTAssertGreaterThanOrEqual(psnr8(original, restored), 40.0)
    }

    // MARK: - Oracle: compress preserves non-pixel tags and sets target TS UID

    func testCompressPreservesNonPixelTags() throws {
        var ds = DataSet()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString(rtUID(), for: .sopInstanceUID, vr: .UI)
        ds.setString("Tag^Preserve", for: .patientName, vr: .PN)
        ds.setString("1.2.3.4.5.777", for: .studyInstanceUID, vr: .UI)
        ds.setString("1.2.3.4.5.888", for: .seriesInstanceUID, vr: .UI)
        ds.setString("CT", for: .modality, vr: .CS)
        ds.setUInt16(16, for: .rows)
        ds.setUInt16(16, for: .columns)
        ds.setUInt16(16, for: .bitsAllocated)
        ds.setUInt16(16, for: .bitsStored)
        ds.setUInt16(15, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        var pixels = Data(count: 16 * 16 * 2)
        for i in 0..<(16 * 16) {
            let v = UInt16((i * 5) % 4096)
            pixels[i * 2] = UInt8(v & 0xFF)
            pixels[i * 2 + 1] = UInt8(v >> 8)
        }
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        let source = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")

        let inputData = try source.write()
        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "jpeg-ls-lossless", quality: nil)
        let out = try DICOMFile.read(from: compressed)

        // Preservation oracle: PatientName, StudyInstanceUID, Modality identical.
        XCTAssertEqual(out.dataSet.string(for: .patientName)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "Tag^Preserve")
        XCTAssertEqual(out.dataSet.string(for: .studyInstanceUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "1.2.3.4.5.777")
        XCTAssertEqual(out.dataSet.string(for: .modality)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), "CT")

        // TS oracle: output transfer syntax == target codec's TS UID.
        XCTAssertEqual(try transferSyntaxUID(of: compressed), jpegLSLossl)
    }

    // MARK: - Oracle: decompress removes encapsulation (native pixels, TS==explicit-LE)

    func testDecompressRemovesEncapsulation() throws {
        let source = makeGrayscale16(rows: 24, cols: 24, fillPattern: { UInt16(($0 * 11) % 4096) })
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "jpeg-ls-lossless", quality: nil)
        // Sanity: the compressed source really is encapsulated.
        let compressedFile = try DICOMFile.read(from: compressed)
        XCTAssertNotNil(compressedFile.dataSet[.pixelData]?.encapsulatedFragments)

        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let out = try DICOMFile.read(from: decompressed)

        // Oracle: output TS is Explicit VR Little Endian.
        XCTAssertEqual(try transferSyntaxUID(of: decompressed), explicitLE)
        // Oracle: pixel data is native — no encapsulated fragments remain.
        XCTAssertNil(out.dataSet[.pixelData]?.encapsulatedFragments)
        // And native length equals rows*cols*2 bytes for 16-bit MONOCHROME2.
        XCTAssertEqual(pixelBytes(out).count, 24 * 24 * 2)
    }

    // MARK: - Oracle: decompress to implicit-LE sets the implicit TS UID

    func testDecompressToImplicitLE() throws {
        let source = makeGrayscale8(rows: 20, cols: 20, fillPattern: { UInt8(($0 * 9) % 256) })
        let original = pixelBytes(source)
        let inputData = try source.write()

        let manager = CompressionManager()
        let compressed = try manager.compressData(inputData, codec: "rle", quality: nil)
        let decompressed = try manager.decompressData(
            compressed, syntax: try XCTUnwrap(TransferSyntax.from(uid: implicitLE)))

        // Oracle: target syntax UID is Implicit VR Little Endian.
        XCTAssertEqual(try transferSyntaxUID(of: decompressed), implicitLE)
        // And the RLE round-trip is still lossless through implicit-LE.
        XCTAssertEqual(pixelBytes(try DICOMFile.read(from: decompressed)), original)
    }

    // MARK: - Oracle: batch compress gives every output the correct TS + lossless round-trip

    func testBatchCompressEachOutputCorrectTS() throws {
        let inputDir = try makeTempDir()
        let outputDir = try makeTempDir()

        // Three distinct synthetic files.
        var originals: [String: Data] = [:]
        for idx in 0..<3 {
            let file = makeGrayscale16(rows: 16, cols: 16,
                                       fillPattern: { UInt16((($0 + idx * 100) * 3) % 4096) })
            let name = "case\(idx).dcm"
            let url = inputDir.appendingPathComponent(name)
            try file.write().write(to: url)
            originals[name] = pixelBytes(file)
        }

        let manager = CompressionManager()
        let files = try CompressionManager.findDICOMFiles(in: inputDir.path, recursive: false)
        // Discovery oracle: all three inputs found.
        XCTAssertEqual(files.count, 3)

        for filePath in files {
            let name = URL(fileURLWithPath: filePath).lastPathComponent
            let outPath = outputDir.appendingPathComponent(name).path
            try manager.compressFile(inputPath: filePath, outputPath: outPath,
                                     codec: "jpeg-ls-lossless", quality: nil)
        }

        // Batch produced three outputs.
        XCTAssertEqual(countFiles(in: outputDir, extension: "dcm"), 3)

        for (name, original) in originals {
            let outURL = outputDir.appendingPathComponent(name)
            let outData = try Data(contentsOf: outURL)
            // Oracle: each output carries the JPEG-LS lossless TS UID.
            XCTAssertEqual(try transferSyntaxUID(of: outData), jpegLSLossl)

            // Oracle: each output losslessly round-trips back to its original.
            let decompressed = try manager.decompressData(
                outData, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
            XCTAssertEqual(pixelBytes(try DICOMFile.read(from: decompressed)), original)
        }
    }

    // MARK: - Oracle: getCompressionInfo reports compressed/lossless correctly

    func testCompressionInfoReflectsCompressedState() throws {
        let source = makeGrayscale8(rows: 16, cols: 16)
        let inputData = try source.write()
        let manager = CompressionManager()

        // Uncompressed source: not compressed, lossless.
        let before = try manager.getCompressionInfo(data: inputData)
        XCTAssertFalse(before.isCompressed)
        XCTAssertEqual(before.rows, 16)
        XCTAssertEqual(before.columns, 16)

        // After RLE compression: compressed, lossless, RLE codec flag set.
        let compressed = try manager.compressData(inputData, codec: "rle", quality: nil)
        let after = try manager.getCompressionInfo(data: compressed)
        XCTAssertTrue(after.isCompressed)
        XCTAssertTrue(after.isLossless)
        XCTAssertTrue(after.isRLE)
        XCTAssertEqual(after.transferSyntaxUID, rleLossless)
    }

    // MARK: - Oracle: batch decompress restores native pixels for every file

    func testBatchDecompressRemovesEncapsulation() throws {
        let compressedDir = try makeTempDir()
        let outputDir = try makeTempDir()
        let manager = CompressionManager()

        var originals: [String: Data] = [:]
        for idx in 0..<2 {
            let file = makeGrayscale8(rows: 16, cols: 16,
                                      fillPattern: { UInt8((($0 + idx * 40) * 5) % 256) })
            let name = "c\(idx).dcm"
            let plain = try file.write()
            let compressed = try manager.compressData(plain, codec: "rle", quality: nil)
            try compressed.write(to: compressedDir.appendingPathComponent(name))
            originals[name] = pixelBytes(file)
        }

        let files = try CompressionManager.findDICOMFiles(in: compressedDir.path, recursive: false)
        for filePath in files {
            let name = URL(fileURLWithPath: filePath).lastPathComponent
            let outPath = outputDir.appendingPathComponent(name).path
            try manager.decompressFile(
                inputPath: filePath, outputPath: outPath,
                syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        }

        for (name, original) in originals {
            let outData = try Data(contentsOf: outputDir.appendingPathComponent(name))
            let out = try DICOMFile.read(from: outData)
            // Oracle: TS == explicit-LE, no fragments, pixels bit-exact (RLE lossless).
            XCTAssertEqual(try transferSyntaxUID(of: outData), explicitLE)
            XCTAssertNil(out.dataSet[.pixelData]?.encapsulatedFragments)
            XCTAssertEqual(pixelBytes(out), original)
        }
    }

    // MARK: - Oracle: real corpus J2K-lossless decompresses to native explicit-LE

    func testCorpusJ2KLosslessDecompress() throws {
        let f = try loadCorpus(.j2kLossless)
        try XCTSkipIf(f == nil, "corpus absent")
        let file = try XCTUnwrap(f)

        // Source really is encapsulated J2K lossless.
        XCTAssertNotNil(file.dataSet[.pixelData]?.encapsulatedFragments)

        let inputData = try Data(contentsOf: try XCTUnwrap(corpusURL(.j2kLossless)))
        let manager = CompressionManager()
        let decompressed = try manager.decompressData(
            inputData, syntax: try XCTUnwrap(TransferSyntax.from(uid: explicitLE)))
        let out = try DICOMFile.read(from: decompressed)

        // Oracle: decompressed TS is explicit-LE, pixels are native (no fragments),
        // and dimensions carry over unchanged.
        XCTAssertEqual(try transferSyntaxUID(of: decompressed), explicitLE)
        XCTAssertNil(out.dataSet[.pixelData]?.encapsulatedFragments)
        XCTAssertEqual(out.dataSet.uint16(for: .rows), file.dataSet.uint16(for: .rows))
        XCTAssertEqual(out.dataSet.uint16(for: .columns), file.dataSet.uint16(for: .columns))
    }
}
