import XCTest
import Foundation
@testable import DICOMCore

/// Instruction §17 fuzz coverage for the codec surface.
///
/// M0 fuzzed `DICOMParser`; `PDUFuzzTests` covers the association surface. Codecs are
/// the third attacker-reachable entry point: fragment bytes flow from a C-STORE or a
/// WADO-RS response straight into a decoder, and the RLE header is entirely
/// attacker-controlled (segment count and 15 segment offsets).
///
/// DCMTK fixed a heap buffer under-read in its RLE decoder and an integer overflow in
/// its RLE size check in July 2026; both are the same shape as the guards asserted here.
final class CodecFuzzTests: XCTestCase {

    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private var fuzzIterations: Int {
        ProcessInfo.processInfo.environment["DICOM_FUZZ_ITERATIONS"].flatMap(Int.init) ?? 2000
    }

    private func descriptor(samplesPerPixel: Int = 1, bitsAllocated: Int = 8) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: 4, columns: 4, numberOfFrames: 1,
            bitsAllocated: bitsAllocated, bitsStored: bitsAllocated, highBit: bitsAllocated - 1,
            isSigned: false, samplesPerPixel: samplesPerPixel,
            photometricInterpretation: samplesPerPixel == 3 ? .rgb : .monochrome2,
            planarConfiguration: 0
        )
    }

    /// A single-segment RLE frame: 64-byte header then one PackBits literal run.
    private func validRLEFrame() -> Data {
        var frame = Data(count: 64)
        frame.replaceSubrange(0..<4, with: [1, 0, 0, 0])    // numberOfSegments = 1
        frame.replaceSubrange(4..<8, with: [64, 0, 0, 0])   // segment 0 offset
        frame.append(15)                                     // literal run of 16 bytes
        frame.append(contentsOf: (0..<16).map { UInt8($0) })
        return frame
    }

    // MARK: - Slice-index handling

    /// **Regression guard.** `decodeFrame` reads its header with `readUInt32LE(at:)`,
    /// which is slice-relative, but slices the segment payload with `subdata(in:)`,
    /// which takes *absolute* indices. A `Data` whose `startIndex` is non-zero — which
    /// is what encapsulated fragment extraction naturally produces — therefore mixes
    /// the two index spaces.
    ///
    /// Decoding a slice must produce the same bytes as decoding the equivalent
    /// contiguous buffer, and must never trap.
    func testRLEDecodeIsIndependentOfSliceStartIndex() throws {
        let descriptor = self.descriptor()
        let frame = validRLEFrame()

        let contiguous = try RLECodec().decodeFrame(frame, descriptor: descriptor, frameIndex: 0)

        // The same bytes, but reached through a slice with a non-zero startIndex.
        let padded = Data(count: 100) + frame
        let slice = padded[100...]
        XCTAssertEqual(slice.startIndex, 100, "test precondition: slice must not be rebased")

        let fromSlice = try RLECodec().decodeFrame(slice, descriptor: descriptor, frameIndex: 0)

        XCTAssertEqual(fromSlice, contiguous,
                       "RLE decode must not depend on the Data's startIndex")
    }

    /// The caller-owned destination path (WP-F) must honour the same invariant.
    func testRLECallerOwnedDecodeIsIndependentOfSliceStartIndex() throws {
        let descriptor = self.descriptor()
        let frame = validRLEFrame()
        let padded = Data(count: 100) + frame
        let slice = padded[100...]

        var contiguousOut = [UInt8](repeating: 0, count: descriptor.bytesPerFrame)
        var sliceOut = [UInt8](repeating: 0, count: descriptor.bytesPerFrame)

        try contiguousOut.withUnsafeMutableBytes { buffer in
            _ = try RLECodec().decodeFrame(frame, descriptor: descriptor, frameIndex: 0, into: buffer)
        }
        try sliceOut.withUnsafeMutableBytes { buffer in
            _ = try RLECodec().decodeFrame(slice, descriptor: descriptor, frameIndex: 0, into: buffer)
        }

        XCTAssertEqual(sliceOut, contiguousOut,
                       "caller-owned RLE decode must not depend on the Data's startIndex")
    }

    // MARK: - Header limits

    /// Segment offsets are 32-bit attacker-controlled values. Every combination of
    /// out-of-range, reversed and overflowing offsets must fail closed.
    func testRLEAdversarialSegmentOffsets() {
        let descriptor = self.descriptor()
        let offsets: [UInt32] = [0, 1, 63, 64, 65, 0x7FFF_FFFF, 0x8000_0000, 0xFFFF_FFFF]

        for offset in offsets {
            var frame = Data(count: 64)
            frame.replaceSubrange(0..<4, with: [1, 0, 0, 0])
            frame.replaceSubrange(4..<8, with: withUnsafeBytes(of: offset.littleEndian) { Data($0) })
            frame.append(contentsOf: [15] + (0..<16).map { UInt8($0) })
            // Must throw or decode — never trap.
            _ = try? RLECodec().decodeFrame(frame, descriptor: descriptor, frameIndex: 0)
        }
    }

    /// A truncated frame at every length from 0 to just past the header.
    func testRLETruncationAtEveryLength() {
        let descriptor = self.descriptor()
        let frame = validRLEFrame()
        for length in 0...frame.count {
            _ = try? RLECodec().decodeFrame(frame.prefix(length), descriptor: descriptor, frameIndex: 0)
        }
    }

    // MARK: - Fuzz

    func testRLEDecoderSurvivesRandomByteMutations() {
        let base = validRLEFrame()
        var rng = SplitMix64(state: 0xD1C0_2026_0810_0201)
        let descriptors = [descriptor(), descriptor(samplesPerPixel: 3), descriptor(bitsAllocated: 16)]

        for iteration in 0..<fuzzIterations {
            var mutated = base
            for _ in 0..<Int.random(in: 1...8, using: &rng) {
                let index = Int.random(in: 0..<mutated.count, using: &rng)
                mutated[index] = UInt8.random(in: 0...255, using: &rng)
            }
            if Int.random(in: 0..<10, using: &rng) == 0, mutated.count > 1 {
                mutated = Data(mutated.prefix(Int.random(in: 1..<mutated.count, using: &rng)))
            }
            let descriptor = descriptors[Int.random(in: 0..<descriptors.count, using: &rng)]
            // Reproduce with seed 0xD1C0202608100201, iteration \(iteration).
            _ = try? RLECodec().decodeFrame(mutated, descriptor: descriptor, frameIndex: 0)
            _ = iteration
        }
    }

    // MARK: - Character sets (§17 "invalid character-set transitions")

    /// Arbitrary bytes under every supported Specific Character Set must decode to
    /// *something* or nil — never trap, and never hang on a malformed escape sequence.
    func testCharacterSetDecoderSurvivesRandomBytes() {
        let charsets = [
            nil, "ISO_IR 100", "ISO_IR 101", "ISO_IR 144", "ISO_IR 192",
            "ISO 2022 IR 6", "ISO 2022 IR 87", "ISO 2022 IR 149", "GB18030", "not-a-charset"
        ]
        var rng = SplitMix64(state: 0xD1C0_2026_0810_0202)

        for charset in charsets {
            let handler = CharacterSetHandler.from(specificCharacterSet: charset)
            for _ in 0..<(fuzzIterations / 10) {
                let length = Int.random(in: 0...48, using: &rng)
                var bytes = Data()
                for _ in 0..<length { bytes.append(UInt8.random(in: 0...255, using: &rng)) }
                // Bias towards ESC so code-extension transitions are actually exercised.
                if Int.random(in: 0..<3, using: &rng) == 0, !bytes.isEmpty {
                    bytes[bytes.startIndex] = 0x1B
                }
                _ = handler.decode(bytes)
            }
        }
    }
}
