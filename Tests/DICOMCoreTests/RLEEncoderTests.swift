import Testing
import Foundation
@testable import DICOMCore

@Suite("RLE Encoder Tests")
struct RLEEncoderTests {

    // MARK: - Helpers

    /// Deterministic byte pattern that mixes replicate runs and literal runs so
    /// both PackBits packet types are exercised on the round trip.
    private func patternedData(_ count: Int) -> Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        var seed: UInt8 = 0
        var step = 0
        while bytes.count < count {
            let runLength = (step % 6) + 1            // 1...6 identical bytes
            for _ in 0..<runLength where bytes.count < count { bytes.append(seed) }
            let literalLength = (step % 4) + 1        // 1...4 varied bytes
            for j in 0..<literalLength where bytes.count < count {
                bytes.append(UInt8((Int(seed) + j * 37 + 13) & 0xFF))
            }
            seed = seed &+ 19
            step += 1
        }
        return Data(bytes)
    }

    private func descriptor(
        rows: Int, columns: Int, frames: Int = 1,
        bitsAllocated: Int, samplesPerPixel: Int = 1,
        photometric: PhotometricInterpretation = .monochrome2,
        planar: Int = 0
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows, columns: columns, numberOfFrames: frames,
            bitsAllocated: bitsAllocated, bitsStored: bitsAllocated, highBit: bitsAllocated - 1,
            isSigned: false, samplesPerPixel: samplesPerPixel,
            photometricInterpretation: photometric, planarConfiguration: planar
        )
    }

    // MARK: - Capabilities

    @Test("RLE codec advertises the RLE Lossless encoding transfer syntax")
    func testSupportedEncodingTransferSyntaxes() {
        #expect(RLECodec.supportedEncodingTransferSyntaxes == ["1.2.840.10008.1.2.5"])
    }

    @Test("RLE codec canEncode accepts 8/16-bit gray and RGB, rejects 32-bit")
    func testCanEncode() {
        let codec = RLECodec()
        #expect(codec.canEncode(with: .lossless, descriptor: descriptor(rows: 8, columns: 8, bitsAllocated: 8)))
        #expect(codec.canEncode(with: .lossless, descriptor: descriptor(rows: 8, columns: 8, bitsAllocated: 16)))
        #expect(codec.canEncode(with: .lossless, descriptor: descriptor(rows: 8, columns: 8, bitsAllocated: 8, samplesPerPixel: 3, photometric: .rgb)))
        #expect(!codec.canEncode(with: .lossless, descriptor: descriptor(rows: 8, columns: 8, bitsAllocated: 32)))
    }

    @Test("RLE registered as an encoder in the shared CodecRegistry")
    func testRegistryHasEncoder() {
        #expect(CodecRegistry.shared.hasEncoder(for: "1.2.840.10008.1.2.5"))
        #expect(CodecRegistry.shared.encoder(for: "1.2.840.10008.1.2.5") != nil)
    }

    // MARK: - Round trips (the lossless guarantee)

    @Test("Round-trips 8-bit grayscale losslessly")
    func testRoundTrip8BitGray() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 32, columns: 32, bitsAllocated: 8)
        let original = patternedData(desc.bytesPerFrame)

        let encoded = try codec.encodeFrame(original, descriptor: desc, frameIndex: 0, configuration: .lossless)
        #expect(encoded.count % 2 == 0, "RLE fragment must be even length")
        let decoded = try codec.decodeFrame(encoded, descriptor: desc, frameIndex: 0)
        #expect(decoded == original)
    }

    @Test("Round-trips 16-bit grayscale losslessly (2 segments)")
    func testRoundTrip16BitGray() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 16, columns: 16, bitsAllocated: 16)
        let original = patternedData(desc.bytesPerFrame)

        let encoded = try codec.encodeFrame(original, descriptor: desc, frameIndex: 0, configuration: .lossless)
        // Header must report exactly bytesPerSample * samplesPerPixel = 2 segments.
        #expect(encoded.readUInt32LE(at: 0) == 2)
        let decoded = try codec.decodeFrame(encoded, descriptor: desc, frameIndex: 0)
        #expect(decoded == original)
    }

    @Test("Round-trips RGB interleaved (planar 0) losslessly (3 segments)")
    func testRoundTripRGBInterleaved() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 10, columns: 10, bitsAllocated: 8, samplesPerPixel: 3, photometric: .rgb, planar: 0)
        let original = patternedData(desc.bytesPerFrame)

        let encoded = try codec.encodeFrame(original, descriptor: desc, frameIndex: 0, configuration: .lossless)
        #expect(encoded.readUInt32LE(at: 0) == 3)
        let decoded = try codec.decodeFrame(encoded, descriptor: desc, frameIndex: 0)
        #expect(decoded == original)
    }

    @Test("Round-trips RGB planar (planar 1) losslessly")
    func testRoundTripRGBPlanar() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 10, columns: 10, bitsAllocated: 8, samplesPerPixel: 3, photometric: .rgb, planar: 1)
        let original = patternedData(desc.bytesPerFrame)

        let encoded = try codec.encodeFrame(original, descriptor: desc, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: desc, frameIndex: 0)
        #expect(decoded == original)
    }

    @Test("Round-trips a constant frame (single replicate run) losslessly")
    func testRoundTripConstantFrame() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 64, columns: 64, bitsAllocated: 8)
        let original = Data(repeating: 0x7F, count: desc.bytesPerFrame)

        let encoded = try codec.encodeFrame(original, descriptor: desc, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: desc, frameIndex: 0)
        #expect(decoded == original)
        // A flat frame should compress well below its raw size.
        #expect(encoded.count < original.count)
    }

    @Test("Round-trips multiframe via encode() losslessly")
    func testRoundTripMultiframe() throws {
        let codec = RLECodec()
        let desc = descriptor(rows: 8, columns: 8, frames: 3, bitsAllocated: 16)
        let bytesPerFrame = desc.bytesPerFrame
        let original = patternedData(bytesPerFrame * desc.numberOfFrames)

        let fragments = try codec.encode(original, descriptor: desc, configuration: .lossless)
        #expect(fragments.count == 3)
        for frameIndex in 0..<desc.numberOfFrames {
            let decoded = try codec.decodeFrame(fragments[frameIndex], descriptor: desc, frameIndex: frameIndex)
            let expected = original.subdata(in: (frameIndex * bytesPerFrame)..<((frameIndex + 1) * bytesPerFrame))
            #expect(decoded == expected, "frame \(frameIndex) round-trip mismatch")
        }
    }
}
