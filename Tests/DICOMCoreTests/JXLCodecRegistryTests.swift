import Testing
import Foundation
@testable import DICOMCore

/// Verifies that JXLSwift is wired into `CodecRegistry` for the DICOM JPEG XL
/// transfer syntaxes added in Supplement 232 (DICOM 2024d): JPEG XL Lossless
/// (.110) encodes (Modular) + decodes, the general JPEG XL syntax (.112) encodes
/// (lossy VarDCT, with a lossless Modular fallback) + decodes, and JPEG XL JPEG
/// Recompression (.111) is decode-only at the registry level (its pixel decode
/// reconstructs the wrapped JPEG; the forward *encode* is a fragment-level
/// JPEG-bitstream wrap driven by `TransferSyntaxConverter`, not a pixel encoder).
/// Complements the bench-level direct-call coverage in `MultiCodecBenchAdaptersTests`.
@Suite("JXLSwift JPEG XL codec — registry wiring")
struct JXLCodecRegistryTests {

    private let lossless = TransferSyntax.jpegXLLossless.uid            // .110  encode + decode
    private let general = TransferSyntax.jpegXL.uid                     // .112  encode (lossy) + decode
    private let recompression = TransferSyntax.jpegXLRecompression.uid  // .111  decode only (pixel)

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

    @Test("CodecRegistry exposes a JXLSwift encoder for Lossless (.110) and general/lossy (.112)")
    func encoderWiring() {
        let reg = CodecRegistry.shared
        #expect(reg.hasEncoder(for: lossless))
        #expect(reg.encoder(for: lossless) is JXLCodec)
        // General JPEG XL (.112) now encodes too — lossy VarDCT (grayscale/oversized
        // inputs fall back to lossless Modular inside JXLSwift).
        #expect(reg.hasEncoder(for: general))
        #expect(reg.encoder(for: general) is JXLCodec)
    }

    @Test("JPEG XL JPEG Recompression (.111) is decode-only (no pixel encoder)")
    func recompressionDecoderOnly() {
        let reg = CodecRegistry.shared
        // Pixel decode IS registered — a recompressed JXL reconstructs to pixels.
        #expect(reg.hasCodec(for: recompression))
        #expect(reg.codec(for: recompression) is JXLCodec)
        // There is NO pixel encoder: forward recompression wraps a JPEG bitstream at the
        // fragment level (TransferSyntaxConverter), not via the ImageEncoder path.
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

    // MARK: - Lossy encode through the registry (.112)

    @Test("General JPEG XL (.112) grayscale lossy request falls back to lossless (bit-exact)")
    func lossyGrayscaleFallsBackBitExact() throws {
        let reg = CodecRegistry.shared
        let d = descriptor(40, 32, bitsAllocated: 8, bitsStored: 8, spp: 1)
        let original = frame(40, 32, bitsStored: 8, spp: 1, bytesPerSample: 1)

        // JXLSwift's VarDCT lossy encoder is RGB-only; a grayscale frame transparently
        // falls back to the lossless Modular path, so even a lossy (.112) request
        // round-trips bit-exact. This documents (and pins) that fallback behaviour.
        let encoder = try #require(reg.encoder(for: general))
        let decoder = try #require(reg.codec(for: general))
        let lossyCfg = CompressionConfiguration(quality: .high, speed: .balanced)
        #expect(encoder.canEncode(with: lossyCfg, descriptor: d))
        let encoded = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: lossyCfg)
        let decoded = try decoder.decodeFrame(encoded, descriptor: d, frameIndex: 0)
        #expect(decoded == original)
    }

    @Test("General JPEG XL (.112) RGB lossy encode produces a codestream that decodes to the source dimensions")
    func lossyRGBRoundTripsToCorrectSize() throws {
        let reg = CodecRegistry.shared
        let d = descriptor(64, 64, bitsAllocated: 8, bitsStored: 8, spp: 3)
        let original = frame(64, 64, bitsStored: 8, spp: 3, bytesPerSample: 1)

        // RGB 8-bit routes through the true VarDCT lossy path. Lossy output is not
        // bit-exact, so assert a valid, non-empty codestream that decodes back to a
        // frame of the correct size (dimensions/channels preserved) — the wiring
        // contract. VarDCT fidelity itself is covered by JXLSwift's own tests.
        let encoder = try #require(reg.encoder(for: general))
        let decoder = try #require(reg.codec(for: general))
        let lossyCfg = CompressionConfiguration(quality: .high, speed: .balanced)
        let encoded = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: lossyCfg)
        #expect(!encoded.isEmpty)
        let decoded = try decoder.decodeFrame(encoded, descriptor: d, frameIndex: 0)
        #expect(decoded.count == original.count)
    }

    @Test("A …4.111 decoder does NOT silently fall back to the pixel path when reconstruction fails")
    func recompressionDecoderThrowsOnNonRecompressedInput() throws {
        let reg = CodecRegistry.shared
        let d = descriptor(40, 32, bitsAllocated: 8, bitsStored: 8, spp: 1)
        let original = frame(40, 32, bitsStored: 8, spp: 1, bytesPerSample: 1)

        // A valid lossless (.110) JXL codestream carries NO `jbrd` box, so JPEG
        // reconstruction cannot succeed. A …4.111-wired decoder must SURFACE that as an
        // error rather than silently decoding it via the VarDCT pixel path (which would
        // desync the channel count from Samples per Pixel) — the whole point of the reroute.
        let encoder = try #require(reg.encoder(for: lossless))
        let notRecompressed = try encoder.encodeFrame(original, descriptor: d, frameIndex: 0, configuration: .lossless)

        let recompressionDecoder = JXLCodec(decodingTransferSyntaxUID: recompression)
        #expect(throws: (any Error).self) {
            _ = try recompressionDecoder.decodeFrame(notRecompressed, descriptor: d, frameIndex: 0)
        }

        // Contrast: the SAME bytes decode fine through a …4.110 pixel decoder (bit-exact).
        let losslessDecoder = try #require(reg.codec(for: lossless))
        let decoded = try losslessDecoder.decodeFrame(notRecompressed, descriptor: d, frameIndex: 0)
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
