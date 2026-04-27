import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

@Suite("JP3DCodec Tests")
struct JP3DCodecTests {

    // MARK: - Helpers

    private func grayscaleVolumeDescriptor(
        rows: Int = 16,
        columns: Int = 16,
        frames: Int = 4
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            numberOfFrames: frames,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
    }

    private func grayscale8VolumeDescriptor(
        rows: Int = 16,
        columns: Int = 16,
        frames: Int = 4
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            numberOfFrames: frames,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
    }

    /// Creates synthetic volume pixel data with a gradient pattern.
    private func makeGradientVolume(descriptor: PixelDataDescriptor) -> Data {
        let bytesPerPixel = descriptor.bitsAllocated / 8
        let totalPixels = descriptor.rows * descriptor.columns * descriptor.numberOfFrames
        var data = Data(capacity: totalPixels * bytesPerPixel)

        for frame in 0..<descriptor.numberOfFrames {
            for row in 0..<descriptor.rows {
                for col in 0..<descriptor.columns {
                    let value = UInt16((frame * 256 + row * 16 + col) & 0x0FFF)
                    if bytesPerPixel == 2 {
                        var le = value.littleEndian
                        data.append(Data(bytes: &le, count: 2))
                    } else {
                        data.append(UInt8(value & 0xFF))
                    }
                }
            }
        }
        return data
    }

    // MARK: - Transfer Syntax Tests

    @Test("JP3D transfer syntaxes are registered correctly")
    func test_transferSyntax_jp3dRegistered() {
        let lossless = TransferSyntax.jp3dLossless
        #expect(lossless.uid == "1.2.826.0.1.3680043.10.511.1")
        #expect(lossless.isLossless)
        #expect(lossless.isJP3D)

        let lossy = TransferSyntax.jp3dLossy
        #expect(lossy.uid == "1.2.826.0.1.3680043.10.511.2")
        #expect(!lossy.isLossless)
        #expect(lossy.isJP3D)
    }

    @Test("JP3D transfer syntaxes can be looked up from UID")
    func test_transferSyntax_fromUID() {
        let lossless = TransferSyntax.from(uid: "1.2.826.0.1.3680043.10.511.1")
        #expect(lossless == .jp3dLossless)

        let lossy = TransferSyntax.from(uid: "1.2.826.0.1.3680043.10.511.2")
        #expect(lossy == .jp3dLossy)
    }

    @Test("JP3D transfer syntaxes can be parsed by name")
    func test_transferSyntax_parseByName() {
        #expect(TransferSyntax.parse("jp3d-lossless") == .jp3dLossless)
        #expect(TransferSyntax.parse("jp3dlossless") == .jp3dLossless)
        #expect(TransferSyntax.parse("jp3d") == .jp3dLossy)
        #expect(TransferSyntax.parse("jp3d-lossy") == .jp3dLossy)
        #expect(TransferSyntax.parse("jp3dlossy") == .jp3dLossy)
    }

    // MARK: - Codec Construction Tests

    @Test("JP3DCodec default construction uses lossless mode")
    func test_codec_defaultIsLossless() {
        let codec = JP3DCodec()
        switch codec.compressionMode {
        case .lossless:
            break // expected
        default:
            Issue.record("Expected lossless default, got different mode")
        }
    }

    @Test("JP3DCodec supported transfer syntaxes include both JP3D UIDs")
    func test_codec_supportedTransferSyntaxes() {
        #expect(JP3DCodec.supportedTransferSyntaxes.contains(TransferSyntax.jp3dLossless.uid))
        #expect(JP3DCodec.supportedTransferSyntaxes.contains(TransferSyntax.jp3dLossy.uid))
    }

    // MARK: - canEncode Tests

    @Test("JP3DCodec can encode multi-frame grayscale 16-bit volumes")
    func test_canEncode_multiframeGrayscale16() {
        let codec = JP3DCodec()
        let desc = grayscaleVolumeDescriptor()
        #expect(codec.canEncode(with: .lossless, descriptor: desc))
    }

    @Test("JP3DCodec can encode multi-frame grayscale 8-bit volumes")
    func test_canEncode_multiframeGrayscale8() {
        let codec = JP3DCodec()
        let desc = grayscale8VolumeDescriptor()
        #expect(codec.canEncode(with: .lossless, descriptor: desc))
    }

    @Test("JP3DCodec rejects single-frame images")
    func test_canEncode_rejectsSingleFrame() {
        let codec = JP3DCodec()
        let desc = PixelDataDescriptor(
            rows: 16,
            columns: 16,
            numberOfFrames: 1,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        #expect(!codec.canEncode(with: .lossless, descriptor: desc))
    }

    @Test("JP3DCodec rejects color (RGB) volumes")
    func test_canEncode_rejectsRGB() {
        let codec = JP3DCodec()
        let desc = PixelDataDescriptor(
            rows: 16,
            columns: 16,
            numberOfFrames: 4,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb
        )
        #expect(!codec.canEncode(with: .lossless, descriptor: desc))
    }

    // MARK: - Codec Registry Tests

    @Test("JP3DCodec is registered in CodecRegistry for JP3D transfer syntaxes")
    func test_codecRegistry_jp3dRegistered() {
        let registry = CodecRegistry.shared
        #expect(registry.hasCodec(for: TransferSyntax.jp3dLossless.uid))
        #expect(registry.hasCodec(for: TransferSyntax.jp3dLossy.uid))
        #expect(registry.encoder(for: TransferSyntax.jp3dLossless.uid) != nil)
        #expect(registry.encoder(for: TransferSyntax.jp3dLossy.uid) != nil)
    }

    // MARK: - Volumetric Encode/Decode Round-Trip Tests

    @Test("JP3DCodec lossless round-trip with 8-bit volume")
    func test_roundTrip_lossless8bit() async throws {
        let codec = JP3DCodec(compressionMode: .lossless)
        let desc = grayscale8VolumeDescriptor(rows: 32, columns: 32, frames: 8)
        let original = makeGradientVolume(descriptor: desc)

        let compressed = try await codec.encodeVolume(original, descriptor: desc)
        #expect(compressed.count > 0)

        let decoded = try await codec.decodeVolume(compressed, descriptor: desc)
        #expect(decoded.count == original.count)
        #expect(decoded == original) // Lossless: exact match
    }

    @Test("JP3DCodec lossless round-trip with 16-bit volume")
    func test_roundTrip_lossless16bit() async throws {
        let codec = JP3DCodec(compressionMode: .lossless)
        let desc = grayscaleVolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)

        let compressed = try await codec.encodeVolume(original, descriptor: desc)
        #expect(compressed.count > 0)

        let decoded = try await codec.decodeVolume(compressed, descriptor: desc)
        #expect(decoded.count == original.count)
        #expect(decoded == original) // Lossless: exact match
    }

    @Test("JP3DCodec lossy round-trip preserves volume dimensions")
    func test_roundTrip_lossy() async throws {
        let codec = JP3DCodec(compressionMode: .lossy(psnr: 40.0))
        let desc = grayscale8VolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)

        let compressed = try await codec.encodeVolume(original, descriptor: desc)
        #expect(compressed.count > 0)

        let decoded = try await codec.decodeVolume(compressed, descriptor: desc)
        #expect(decoded.count == original.count)
        // Lossy: not exact, but same size
    }

    @Test("JP3DCodec HTJ2K lossless round-trip")
    func test_roundTrip_htj2kLossless() async throws {
        let codec = JP3DCodec(compressionMode: .losslessHTJ2K)
        let desc = grayscale8VolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)

        let compressed = try await codec.encodeVolume(original, descriptor: desc)
        #expect(compressed.count > 0)

        let decoded = try await codec.decodeVolume(compressed, descriptor: desc)
        #expect(decoded.count == original.count)
        #expect(decoded == original)
    }

    // MARK: - Sync Protocol Bridge Tests

    @Test("JP3DCodec sync decode returns correct data")
    func test_syncDecode_works() async throws {
        let codec = JP3DCodec(compressionMode: .lossless)
        let desc = grayscale8VolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)

        // Encode with async API
        let compressed = try await codec.encodeVolume(original, descriptor: desc)

        // Decode with sync bridge
        let decoded = try codec.decode(compressed, descriptor: desc)
        #expect(decoded == original)
    }

    @Test("JP3DCodec decodeFrame extracts correct frame from volume")
    func test_decodeFrame_extractsCorrectFrame() async throws {
        let codec = JP3DCodec(compressionMode: .lossless)
        let desc = grayscale8VolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)

        let compressed = try await codec.encodeVolume(original, descriptor: desc)

        // Extract frame 2
        let frame2 = try codec.decodeFrame(compressed, descriptor: desc, frameIndex: 2)
        let expectedStart = 2 * desc.bytesPerFrame
        let expectedFrame = original.subdata(in: expectedStart..<(expectedStart + desc.bytesPerFrame))
        #expect(frame2 == expectedFrame)
    }

    @Test("JP3DCodec decodeFrame throws for out-of-bounds frame")
    func test_decodeFrame_outOfBounds() async throws {
        let codec = JP3DCodec(compressionMode: .lossless)
        let desc = grayscale8VolumeDescriptor(rows: 8, columns: 8, frames: 4)
        let original = makeGradientVolume(descriptor: desc)
        let compressed = try await codec.encodeVolume(original, descriptor: desc)

        #expect(throws: DICOMError.self) {
            _ = try codec.decodeFrame(compressed, descriptor: desc, frameIndex: 10)
        }
    }

    // MARK: - Real-DICOM Volume Round-Trip

    private func localDatasetsRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LocalDatasets/medical-dicom-organized", isDirectory: true)
    }

    /// Loads up to `count` consecutive image-bearing CT slices and concatenates
    /// their decoded pixel data into a frame-major volume buffer.
    private func loadCTVolumeSlices(
        relativeStudy: String = "ct/study_002",
        count: Int = 16,
        minFileSize: Int = 400_000
    ) throws -> (descriptor: PixelDataDescriptor, data: Data, sourceCount: Int) {
        let dir = localDatasetsRoot().appendingPathComponent(relativeStudy, isDirectory: true)
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])
            .filter { $0.pathExtension.lowercased() == "dcm" }
            .filter { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) ?? 0 >= minFileSize }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .prefix(count)

        guard !urls.isEmpty else {
            throw DICOMError.parsingFailed("No image-bearing DICOM files found in \(relativeStudy)")
        }

        var firstDescriptor: PixelDataDescriptor?
        var combined = Data()
        for url in urls {
            let file = try DICOMFile.read(from: url)
            let pixel = try file.tryPixelData()
            if firstDescriptor == nil {
                firstDescriptor = pixel.descriptor
            } else if let d = firstDescriptor,
                      d.rows != pixel.descriptor.rows ||
                      d.columns != pixel.descriptor.columns ||
                      d.bitsAllocated != pixel.descriptor.bitsAllocated {
                throw DICOMError.parsingFailed("Heterogeneous slice geometry encountered in \(relativeStudy)")
            }
            combined.append(pixel.data)
        }

        let base = firstDescriptor!
        let volumeDescriptor = PixelDataDescriptor(
            rows: base.rows,
            columns: base.columns,
            numberOfFrames: urls.count,
            bitsAllocated: base.bitsAllocated,
            bitsStored: base.bitsStored,
            highBit: base.highBit,
            isSigned: base.isSigned,
            samplesPerPixel: base.samplesPerPixel,
            photometricInterpretation: base.photometricInterpretation
        )
        return (volumeDescriptor, combined, urls.count)
    }

    @Test("JP3DCodec lossless round-trip on real CT volume from LocalDatasets")
    func test_realCTVolume_losslessRoundTrip() async throws {
        let sample = try loadCTVolumeSlices(relativeStudy: "ct/study_002", count: 16)
        let codec = JP3DCodec(compressionMode: .lossless)

        #expect(codec.canEncode(with: .lossless, descriptor: sample.descriptor))

        let compressed = try await codec.encodeVolume(sample.data, descriptor: sample.descriptor)
        let decoded = try await codec.decodeVolume(compressed, descriptor: sample.descriptor)

        let originalBytes = sample.data.count
        let compressedBytes = compressed.count
        let ratio = Double(originalBytes) / Double(max(compressedBytes, 1))

        print("""

        JP3D real-CT lossless round-trip
          source study:    ct/study_002
          slices loaded:   \(sample.sourceCount)
          dimensions:      \(sample.descriptor.columns)×\(sample.descriptor.rows)×\(sample.descriptor.numberOfFrames) @ \(sample.descriptor.bitsAllocated)-bit
          original bytes:  \(originalBytes)
          compressed:      \(compressedBytes)
          ratio:           \(String(format: "%.2fx", ratio))
        """)

        #expect(compressed.isEmpty == false)
        #expect(decoded.count == sample.data.count)
        #expect(decoded == sample.data, "JP3D lossless must be bit-exact on real CT slices")
    }
}
