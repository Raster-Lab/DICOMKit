import Testing
import Foundation
@testable import DICOMCore

/// Verifies that JXLSwift is wired into `CodecRegistry` for the DICOM JPEG XL
/// transfer syntaxes added in Supplement 232 (DICOM 2024d): JPEG XL Lossless
/// (.110) is both decodable and encodable, the general JPEG XL syntax (.112) is
/// decode-only, and JPEG XL JPEG Recompression (.111) is intentionally absent
/// (faithful handling needs JPEG-bitstream reconstruction, not a generic
/// pixel (de)code). Complements the bench-level direct-call coverage in
/// `MultiCodecBenchAdaptersTests`.
@Suite("JXLSwift JPEG XL codec — registry wiring")
struct JXLCodecRegistryTests {

    private let lossless = TransferSyntax.jpegXLLossless.uid            // .110  encode + decode
    private let general = TransferSyntax.jpegXL.uid                     // .112  decode only
    private let recompression = TransferSyntax.jpegXLRecompression.uid  // .111  unsupported

    // MARK: - Fixtures

    private func descriptor(_ w: Int, _ h: Int, bitsAllocated: Int, bitsStored: Int,
                            spp: Int, isSigned: Bool = false) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: h, columns: w,
            bitsAllocated: bitsAllocated, bitsStored: bitsStored, highBit: bitsStored - 1,
            isSigned: isSigned, samplesPerPixel: spp,
            photometricInterpretation: spp == 1 ? .monochrome2 : .rgb,
            planarConfiguration: 0)
    }

    /// High-frequency XOR pattern — the worst case for prediction/entropy, so a
    /// lossless round-trip that survives it survives anything. Matches the sizes
    /// the JXLSwift bench tests already prove round-trip bit-exactly.
    private func frame(_ w: Int, _ h: Int, bitsStored: Int, spp: Int, bytesPerSample: Int) -> Data {
        let maxVal = (1 << bitsStored) - 1
        var data = Data(count: w * h * spp * bytesPerSample)
        data.withUnsafeMutableBytes { raw in
            let p = raw.bindMemory(to: UInt8.self)
            var i = 0
            for y in 0..<h {
                for x in 0..<w {
                    for c in 0..<spp {
                        let v = ((x * 7 + y * 13 + c * 53) ^ (x &* y)) & maxVal
                        if bytesPerSample == 1 { p[i] = UInt8(v); i += 1 }
                        else { p[i] = UInt8(v & 0xFF); p[i + 1] = UInt8((v >> 8) & 0xFF); i += 2 }
                    }
                }
            }
        }
        return data
    }

    // MARK: - Registry wiring

    @Test("CodecRegistry exposes a JXLSwift decoder for Lossless (.110) and general (.112)")
    func decoderWiring() {
        let reg = CodecRegistry.shared
        #expect(reg.hasCodec(for: lossless))
        #expect(reg.hasCodec(for: general))
        #expect(reg.codec(for: lossless) is JXLCodec)
        #expect(reg.codec(for: general) is JXLCodec)
    }

    @Test("CodecRegistry exposes a JXLSwift encoder for Lossless (.110) only")
    func encoderWiring() {
        let reg = CodecRegistry.shared
        #expect(reg.hasEncoder(for: lossless))
        #expect(reg.encoder(for: lossless) is JXLCodec)
        // General JPEG XL (.112) is decode-only — lossless output must use .110.
        #expect(!reg.hasEncoder(for: general))
    }

    @Test("JPEG XL JPEG Recompression (.111) is not registered (unsupported)")
    func recompressionAbsent() {
        let reg = CodecRegistry.shared
        #expect(!reg.hasCodec(for: recompression))
        #expect(!reg.hasEncoder(for: recompression))
    }

    // MARK: - Lossless round-trip through the registry

    @Test("Registry lossless round-trip (.110) is bit-exact",
          arguments: [
            (w: 40, h: 32, ba: 8, bs: 8, spp: 1),
            (w: 40, h: 32, ba: 16, bs: 12, spp: 1),
            (w: 24, h: 24, ba: 8, bs: 8, spp: 3),
          ])
    func losslessRoundTrip(w: Int, h: Int, ba: Int, bs: Int, spp: Int) throws {
        let reg = CodecRegistry.shared
        let bps = ba <= 8 ? 1 : 2
        let d = descriptor(w, h, bitsAllocated: ba, bitsStored: bs, spp: spp)
        let original = frame(w, h, bitsStored: bs, spp: spp, bytesPerSample: bps)

        let encoder = try #require(reg.encoder(for: lossless))
        let decoder = try #require(reg.codec(for: lossless))
        #expect(encoder.canEncode(with: .lossless, descriptor: d))

        let encoded = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: .lossless)
        let decoded = try decoder.decodeFrame(encoded, descriptor: d, frameIndex: 0)
        #expect(decoded == original, "lossless .110 \(w)x\(h) ba=\(ba) bs=\(bs) spp=\(spp) not bit-exact")
    }

    @Test("General JPEG XL (.112) decoder decodes a JXL codestream")
    func generalDecoderDecodes() throws {
        let reg = CodecRegistry.shared
        let d = descriptor(40, 32, bitsAllocated: 8, bitsStored: 8, spp: 1)
        let original = frame(40, 32, bitsStored: 8, spp: 1, bytesPerSample: 1)

        // Encode via the lossless (.110) encoder, decode via the general (.112)
        // decoder — both resolve to JXLCodec, so a valid JXL codestream round-trips.
        let encoder = try #require(reg.encoder(for: lossless))
        let generalDecoder = try #require(reg.codec(for: general))
        let encoded = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: .lossless)
        let decoded = try generalDecoder.decodeFrame(encoded, descriptor: d, frameIndex: 0)
        #expect(decoded == original)
    }

    // MARK: - canEncode gating

    @Test("canEncode enforces 8/16-bit unsigned grayscale or RGB")
    func canEncodeGating() throws {
        let enc = try #require(CodecRegistry.shared.encoder(for: lossless))

        #expect(enc.canEncode(with: .lossless, descriptor: descriptor(8, 8, bitsAllocated: 8, bitsStored: 8, spp: 1)))
        #expect(enc.canEncode(with: .lossless, descriptor: descriptor(8, 8, bitsAllocated: 16, bitsStored: 16, spp: 1)))
        #expect(enc.canEncode(with: .lossless, descriptor: descriptor(8, 8, bitsAllocated: 8, bitsStored: 8, spp: 3)))
        // Signed not supported — JXLSwift handles unsigned samples only.
        #expect(!enc.canEncode(with: .lossless, descriptor: descriptor(8, 8, bitsAllocated: 16, bitsStored: 16, spp: 1, isSigned: true)))
        // 4-channel (e.g. RGBA) not supported.
        #expect(!enc.canEncode(with: .lossless, descriptor: descriptor(8, 8, bitsAllocated: 8, bitsStored: 8, spp: 4)))
    }

    // MARK: - DICOM even-length pad tolerance (regression for the encapsulated round-trip)

    @Test("Registry decode tolerates the DICOM even-length pad byte",
          arguments: [
            (w: 40, h: 32, ba: 8, bs: 8, spp: 1),
            (w: 40, h: 32, ba: 16, bs: 12, spp: 1),
            (w: 24, h: 24, ba: 8, bs: 8, spp: 3),
          ])
    func decodeToleratesEvenLengthPad(w: Int, h: Int, ba: Int, bs: Int, spp: Int) throws {
        let reg = CodecRegistry.shared
        let bps = ba <= 8 ? 1 : 2
        let d = descriptor(w, h, bitsAllocated: ba, bitsStored: bs, spp: spp)
        let original = frame(w, h, bitsStored: bs, spp: spp, bytesPerSample: bps)

        let encoder = try #require(reg.encoder(for: lossless))
        let decoder = try #require(reg.codec(for: lossless))

        // Mimic DICOM encapsulation: an odd-length fragment is padded to even with a
        // trailing 0x00 (PS3.5 §A.4). The decoder must strip it and still round-trip.
        var fragment = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: .lossless)
        if fragment.count % 2 == 1 { fragment.append(0) }
        let decoded = try decoder.decodeFrame(fragment, descriptor: d, frameIndex: 0)
        #expect(decoded == original, "padded decode \(w)x\(h) ba=\(ba) spp=\(spp) failed")
    }
}
