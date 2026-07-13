// J2KGPUEncodeRoundTripTests.swift
// DICOMCoreTests — Phase 2: guarded GPU lossless encode
//
// Proves that a forced-Metal *lossless* encode through `J2KSwiftCodec.encodeFrame`
// round-trips byte-exactly. `encodeFrame` runs `verifyEncodedRoundTrip` internally
// (it throws on any lossless mismatch), and these tests additionally decode and
// compare, so a GPU-lossless regression fails loudly rather than emitting corrupt
// DICOM. See J2K_ROUTING_ARCHITECTURE.md §9.2.

import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

@Suite("J2K GPU lossless round-trip (Phase 2)")
struct J2KGPUEncodeRoundTripTests {

    // MARK: - Descriptors

    private func grayscaleDescriptor(
        rows: Int, columns: Int, bitsAllocated: Int, bitsStored: Int
    ) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: bitsAllocated, bitsStored: bitsStored,
            highBit: bitsStored - 1, isSigned: false,
            samplesPerPixel: 1, photometricInterpretation: .monochrome2
        )
    }

    private func rgbDescriptor(rows: Int, columns: Int) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: 8, bitsStored: 8, highBit: 7, isSigned: false,
            samplesPerPixel: 3, photometricInterpretation: .rgb, planarConfiguration: 0
        )
    }

    // MARK: - Deterministic frame data

    private func frame8(_ descriptor: PixelDataDescriptor) -> Data {
        let n = descriptor.rows * descriptor.columns * descriptor.samplesPerPixel
        return Data((0..<n).map { UInt8(($0 * 37 + 11) & 0xFF) })
    }

    /// Little-endian 16-bit samples masked to `bitsStored`.
    private func frame16(_ descriptor: PixelDataDescriptor) -> Data {
        let mask = UInt16((1 << descriptor.bitsStored) - 1)
        let n = descriptor.rows * descriptor.columns
        var data = Data(capacity: n * 2)
        for i in 0..<n {
            let v = UInt16((i &* 31 &+ 7) & Int(mask))
            data.append(UInt8(v & 0x00FF))
            data.append(UInt8((v >> 8) & 0x00FF))
        }
        return data
    }

    private func losslessMetalConfig() -> CompressionConfiguration {
        CompressionConfiguration(
            quality: .maximum, speed: .balanced, progressive: false,
            preferLossless: true, maxBitsPerSample: nil, forcedBackend: .metal
        )
    }

    /// Encodes with a forced-Metal lossless config, then decodes and asserts
    /// byte-exact recovery. When Metal is present this exercises `encodeGPU`.
    private func assertLosslessRoundTrip(
        uid: String, descriptor: PixelDataDescriptor, original: Data
    ) throws {
        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: uid)
        // Sanity: the planner routes this to the GPU when Metal is available.
        let plan = J2KRoutePlanner.planEncode(
            transferSyntaxUID: uid, configuration: losslessMetalConfig())
        #expect(plan.lossless == true)
        #expect(plan.useGPU == true)

        let encoded = try codec.encodeFrame(
            original, descriptor: descriptor, frameIndex: 0, configuration: losslessMetalConfig())
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
        #expect(decoded == original)
    }

    private typealias TS = TransferSyntax

    // MARK: - Small-frame integration (correctness of the forced-Metal lossless route)

    @Test("Part-1 lossless-only (.90) 8-bit grayscale forced-Metal round-trips")
    func part1_losslessOnly_gray8() throws {
        let d = grayscaleDescriptor(rows: 64, columns: 64, bitsAllocated: 8, bitsStored: 8)
        try assertLosslessRoundTrip(uid: TS.jpeg2000Lossless.uid, descriptor: d, original: frame8(d))
    }

    @Test("Part-1 lossless (.91) 16-bit grayscale forced-Metal round-trips")
    func part1_lossless_gray16() throws {
        let d = grayscaleDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 16)
        try assertLosslessRoundTrip(uid: TS.jpeg2000.uid, descriptor: d, original: frame16(d))
    }

    @Test("Part-1 lossless (.91) 12-bit grayscale forced-Metal round-trips")
    func part1_lossless_gray12() throws {
        let d = grayscaleDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 12)
        try assertLosslessRoundTrip(uid: TS.jpeg2000.uid, descriptor: d, original: frame16(d))
    }

    @Test("HTJ2K lossless-only (.201) 16-bit grayscale forced-Metal round-trips")
    func htj2k_losslessOnly_gray16() throws {
        let d = grayscaleDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 16)
        try assertLosslessRoundTrip(uid: TS.htj2kLossless.uid, descriptor: d, original: frame16(d))
    }

    @Test("Part-1 lossless (.91) RGB 8-bit forced-Metal round-trips (GPU RCT path)")
    func part1_lossless_rgb8() throws {
        let d = rgbDescriptor(rows: 48, columns: 48)
        try assertLosslessRoundTrip(uid: TS.jpeg2000.uid, descriptor: d, original: frame8(d))
    }

    // MARK: - Part-2 encode is rejected (Phase 3, option 2)
    //
    // J2KSwift v11.0.2 cannot decode real Part-2 MCT (probe: 253/255 error), so
    // DICOMKit refuses to encode .92/.93 rather than emit an unreadable codestream.

    @Test("Part-2 lossless-only (.92) encode is rejected")
    func part2_losslessOnly_rejected() {
        let d = grayscaleDescriptor(rows: 64, columns: 64, bitsAllocated: 16, bitsStored: 16)
        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TS.jpeg2000Part2Lossless.uid)
        #expect(throws: (any Error).self) {
            _ = try codec.encodeFrame(frame16(d), descriptor: d, frameIndex: 0, configuration: losslessMetalConfig())
        }
    }

    @Test("Part-2 (.93) RGB encode is rejected")
    func part2_rgb_rejected() {
        let d = rgbDescriptor(rows: 48, columns: 48)
        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TS.jpeg2000Part2.uid)
        #expect(throws: (any Error).self) {
            _ = try codec.encodeFrame(frame8(d), descriptor: d, frameIndex: 0, configuration: losslessMetalConfig())
        }
    }

    // MARK: - Above the 3 MP GPU forward-5/3 threshold (exercises the GPU DWT stage)

    @Test("Part-1 lossless (.91) 16-bit ≥ 3 MP forced-Metal round-trips (GPU DWT stage)")
    func part1_lossless_gray16_large() throws {
        // 2048×2048 = 4 MP > the 3 MP J2K_GPU_FORWARD_53 threshold, so the GPU
        // forward 5/3 DWT stage fires when Metal is available.
        let d = grayscaleDescriptor(rows: 2048, columns: 2048, bitsAllocated: 16, bitsStored: 16)
        try assertLosslessRoundTrip(uid: TS.jpeg2000.uid, descriptor: d, original: frame16(d))
    }
}
