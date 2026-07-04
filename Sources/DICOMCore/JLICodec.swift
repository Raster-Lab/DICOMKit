import Foundation
import JLISwift

/// JPEG codec backed by the JLISwift native-Swift JPEG package.
///
/// Bridges DICOM pixel data (PS3.5 §A.4.1–A.4.3) to JLISwift's pure-Swift
/// implementation of ITU-T T.81 for all four DICOM JPEG transfer syntaxes —
/// **both lossy and lossless**:
///
///   • 1.2.840.10008.1.2.4.50  JPEG Baseline (Process 1)        — lossy DCT, 8-bit  (SOF0)
///   • 1.2.840.10008.1.2.4.51  JPEG Extended (Process 2 & 4)    — lossy DCT, ≤12-bit (SOF1)
///   • 1.2.840.10008.1.2.4.57  JPEG Lossless (Process 14)       — predictive       (SOF3)
///   • 1.2.840.10008.1.2.4.70  JPEG Lossless SV1 (Process 14,1) — predictive, P1   (SOF3)
///
/// **Decoding** is mode-agnostic: `JLIDecoder` auto-detects the SOF marker, so a
/// single decoder serves all four syntaxes (`encodingTransferSyntaxUID` is ignored
/// on the decode path).
///
/// **Encoding** is mode-specific: the JPEG process is selected from
/// `encodingTransferSyntaxUID`. The registry constructs one instance per encode
/// UID (mirroring `J2KSwiftCodec`/`HTJ2KCodec`). The default initialiser targets
/// lossless SV1, so a bare `JLICodec()` round-trips bit-exactly — the contract the
/// DICOMStudio codec bench and the multi-codec adapter tests rely on.
///
/// Pixel bridging: `JLIImage.data` is channel-interleaved `[UInt8]`, row-major,
/// 16-bit samples little-endian — matching DICOM little-endian storage, so only
/// planar→interleaved reshuffling (handled by `interleavedFrameBytes`) is needed.
public struct JLICodec: ImageCodec, ImageEncoder, Sendable {
    /// All four DICOM JPEG transfer syntaxes can be decoded.
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpegBaseline.uid,     // 1.2.840.10008.1.2.4.50
        TransferSyntax.jpegExtended.uid,     // 1.2.840.10008.1.2.4.51
        TransferSyntax.jpegLossless.uid,     // 1.2.840.10008.1.2.4.57
        TransferSyntax.jpegLosslessSV1.uid   // 1.2.840.10008.1.2.4.70
    ]

    /// All four DICOM JPEG transfer syntaxes can be encoded.
    public static let supportedEncodingTransferSyntaxes: [String] = supportedTransferSyntaxes

    /// The transfer syntax this instance encodes to. Selects the JPEG process:
    /// baseline/extended → lossy DCT, lossless/SV1 → SOF3 predictive. Ignored when
    /// decoding (the SOF marker drives the decoder).
    public let encodingTransferSyntaxUID: String

    /// Creates a JPEG codec.
    /// - Parameter encodingTransferSyntaxUID: The target syntax for encoding.
    ///   Defaults to JPEG Lossless SV1 so a bare `JLICodec()` is bit-exact
    ///   (the bench / adapter-test contract).
    public init(encodingTransferSyntaxUID: String = TransferSyntax.jpegLosslessSV1.uid) {
        self.encodingTransferSyntaxUID = encodingTransferSyntaxUID
    }

    /// Whether the target syntax is one of the two lossless (SOF3) JPEG processes.
    private var encodesLossless: Bool {
        encodingTransferSyntaxUID == TransferSyntax.jpegLossless.uid
            || encodingTransferSyntaxUID == TransferSyntax.jpegLosslessSV1.uid
    }

    /// Whether the target syntax is JPEG Baseline (Process 1) — 8-bit only.
    private var encodesBaseline: Bool {
        encodingTransferSyntaxUID == TransferSyntax.jpegBaseline.uid
    }

    // MARK: - Decoding

    /// Decodes a JPEG-compressed frame (any SOF mode) to DICOM pixel bytes.
    /// - Parameters:
    ///   - frameData: A single JPEG codestream.
    ///   - descriptor: Pixel data descriptor (drives the planar reshuffle).
    ///   - frameIndex: Frame index (unused — one codestream per call).
    /// - Returns: Uncompressed pixel data laid out per `descriptor`.
    /// - Throws: `DICOMError` if decoding fails.
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG data")
        }
        do {
            let image = try JLIDecoder().decode(from: [UInt8](frameData))
            return dicomFrameBytes(fromInterleaved: image.data, descriptor: descriptor)
        } catch {
            throw DICOMError.parsingFailed("JLISwift decode failed: \(error)")
        }
    }

    // MARK: - Encoding

    /// Whether this codec can encode the given configuration for its target syntax.
    ///
    /// Constraints follow each JPEG process plus JLISwift's input rules:
    ///   • samples per pixel must be 1 (grayscale) or 3 (RGB);
    ///   • Baseline (.50): 8-bit unsigned only;
    ///   • Extended (.51): ≤12-bit unsigned (the SOF1 precision ceiling);
    ///   • Lossless (.57/.70): 2–16 bit, signed or unsigned (bytes preserved exactly);
    ///   • the lossy DCT path rejects signed samples (undefined level shift).
    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }

        if encodesLossless {
            // SOF3 predictive: 2–16 bit precision, sign-agnostic.
            guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
                return false
            }
            return descriptor.bitsStored >= 2 && descriptor.bitsStored <= 16
        }

        // Lossy DCT: JLISwift's level shift is defined only for unsigned samples.
        if descriptor.isSigned {
            return false
        }
        if encodesBaseline {
            // Process 1 — 8-bit baseline sequential.
            return descriptor.bitsAllocated == 8 && descriptor.bitsStored <= 8
        }
        // Extended (Process 2 & 4) — up to 12-bit.
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }
        return descriptor.bitsStored <= 12
    }

    /// Encodes a single frame to the JPEG process selected by `encodingTransferSyntaxUID`.
    /// - Parameters:
    ///   - frameData: Uncompressed frame bytes laid out per `descriptor`.
    ///   - descriptor: Pixel data descriptor.
    ///   - frameIndex: Zero-based frame index (unused — one codestream per frame).
    ///   - configuration: Compression configuration; for the lossy processes its
    ///     `quality` maps to the JPEG quality factor. Ignored for lossless.
    /// - Returns: The JPEG codestream for this frame.
    /// - Throws: `DICOMError` if encoding fails.
    public func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor,
                            frameIndex: Int, configuration: CompressionConfiguration) throws -> Data {
        let spp = descriptor.samplesPerPixel
        guard spp == 1 || spp == 3 else {
            throw DICOMError.parsingFailed("JLISwift: unsupported samplesPerPixel \(spp)")
        }
        let pixelFormat: JLIPixelFormat = descriptor.bitsAllocated <= 8 ? .uint8 : .uint16
        let colorModel: JLIColorModel = spp == 1 ? .grayscale : .rgb
        let interleaved = interleavedFrameBytes(from: frameData, descriptor: descriptor)

        do {
            let image = try JLIImage(width: descriptor.columns, height: descriptor.rows,
                                     pixelFormat: pixelFormat, colorModel: colorModel,
                                     data: interleaved, isSigned: descriptor.isSigned)
            let cfg = encoderConfiguration(descriptor: descriptor, configuration: configuration,
                                           pixelFormat: pixelFormat)
            return Data(try JLIEncoder().encode(image, configuration: cfg))
        } catch {
            throw DICOMError.parsingFailed("JLISwift encode failed: \(error)")
        }
    }

    // MARK: - Configuration mapping

    /// Builds the JLISwift encoder configuration for the target JPEG process.
    private func encoderConfiguration(descriptor: PixelDataDescriptor,
                                      configuration: CompressionConfiguration,
                                      pixelFormat: JLIPixelFormat) -> JLIEncoderConfiguration {
        if encodesLossless {
            // SOF3 predictor 1, point-transform 0 — bit-exact. Both .57 (Process 14)
            // and .70 (SV1) are valid with the left predictor; .70 *requires* it.
            var cfg = JLIEncoderConfiguration.diagnosticLossless
            cfg.losslessPredictor = 1
            cfg.losslessPointTransform = 0
            if pixelFormat == .uint16 {
                // Pin precision to the stored depth; otherwise JLISwift derives
                // 12-bit and drops the high bits of >12-bit sources.
                cfg.losslessPrecision = min(16, max(2, descriptor.bitsStored))
            }
            return cfg
        }

        // Lossy DCT — start from the tuned perceptual defaults, then force the
        // properties the DICOM JPEG processes mandate:
        //   • sequential, never progressive (Baseline/Extended are non-progressive);
        //   • 4:4:4 chroma — no extra chrominance loss for diagnostic color.
        // Sample precision (SOF0 8-bit vs SOF1 12-bit) follows the pixel format.
        var cfg = JLIEncoderConfiguration.default
        cfg.lossless = false
        cfg.progressive = false
        cfg.chromaSubsampling = .yuv444
        cfg.distance = nil
        cfg.quality = Self.jpegQuality(from: configuration.quality)
        return cfg
    }

    /// Maps a DICOM `CompressionQuality` (0.0–1.0) to a JPEG quality factor (1–100).
    static func jpegQuality(from quality: CompressionQuality) -> Double {
        max(1.0, min(100.0, quality.value * 100.0))
    }
}
