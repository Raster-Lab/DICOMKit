import Foundation
import JXLSwift

/// JPEG XL codec backed by the JXLSwift pure-Swift package (ISO/IEC 18181).
///
/// Bridges DICOM pixel data to JXLSwift for the JPEG XL transfer syntaxes added
/// in Supplement 232 (DICOM 2024d). Encodes **lossless** JPEG XL (Modular mode,
/// distance 0) and decodes both lossless (Modular) and general/lossy (VarDCT)
/// JPEG XL back to pixels. Encoding is lossless-only by design: JXLSwift's lossy
/// VarDCT encoder is only partially implemented, so the encoder targets the
/// Lossless transfer syntax exclusively. Also used by the DICOMStudio codec
/// bench to compare JXLSwift against other JPEG XL implementations (libjxl `djxl`).
///
/// Transfer syntaxes:
///   • 1.2.840.10008.1.2.4.110  JPEG XL Lossless          (encode + decode)
///   • 1.2.840.10008.1.2.4.112  JPEG XL (general / lossy)  (decode only)
/// JPEG XL JPEG Recompression (…4.111) is intentionally unsupported: faithful
/// handling requires reconstructing the original JPEG bitstream, not a generic
/// pixel (de)code.
///
/// Pixel bridging: JXLSwift's `ImageFrame.data` is channel-interleaved `[UInt8]`,
/// row-major, 16-bit samples little-endian — matching DICOM little-endian
/// storage. JXLSwift handles only unsigned samples, so signed frames are
/// rejected here rather than silently mis-encoded.
public struct JXLCodec: ImageCodec, ImageEncoder, Sendable {
    /// JPEG XL transfer syntaxes this codec can decode (lossless + general/lossy).
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpegXLLossless.uid,   // 1.2.840.10008.1.2.4.110
        TransferSyntax.jpegXL.uid             // 1.2.840.10008.1.2.4.112
    ]

    /// JPEG XL transfer syntaxes this codec can produce. Encoding is lossless-only,
    /// so only the Lossless transfer syntax is offered.
    public static let supportedEncodingTransferSyntaxes: [String] = [
        TransferSyntax.jpegXLLossless.uid     // 1.2.840.10008.1.2.4.110
    ]

    public init() {}

    // MARK: - Encoding capability

    /// Whether this encoder can compress the given pixel data. JXLSwift's lossless
    /// Modular encoder handles 8- or 16-bit unsigned grayscale or RGB.
    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }
        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }
        guard !descriptor.isSigned else {
            return false
        }
        return true
    }

    // MARK: - Encoding

    public func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor,
                            frameIndex: Int, configuration: CompressionConfiguration) throws -> Data {
        let spp = descriptor.samplesPerPixel
        guard spp == 1 || spp == 3 else {
            throw DICOMError.parsingFailed("JXLSwift: unsupported samplesPerPixel \(spp)")
        }
        guard !descriptor.isSigned else {
            throw DICOMError.parsingFailed("JXLSwift: signed pixel data not supported (apply a rescale offset first)")
        }
        guard descriptor.columns > 0, descriptor.rows > 0 else {
            throw DICOMError.parsingFailed("JXLSwift: invalid frame dimensions")
        }
        let pixelType: PixelType = descriptor.bitsAllocated <= 8 ? .uint8 : .uint16
        let colorSpace: ColorSpace = spp == 1 ? .grayscale : .sRGB

        var frame = ImageFrame(width: descriptor.columns, height: descriptor.rows,
                               channels: spp, pixelType: pixelType,
                               colorSpace: colorSpace, alphaChannels: 0)
        frame.data = interleavedFrameBytes(from: frameData, descriptor: descriptor)

        do {
            return try JXLEncoder(options: .lossless).encode(frame).data
        } catch {
            throw DICOMError.parsingFailed("JXLSwift encode failed: \(error)")
        }
    }

    // MARK: - Decoding

    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG XL data")
        }

        func decode(_ data: Data) throws -> Data {
            let frame = try JXLDecoder().decode(data)
            return dicomFrameBytes(fromInterleaved: frame.data, descriptor: descriptor)
        }

        do {
            return try decode(frameData)
        } catch {
            // DICOM pads an odd-length encapsulated fragment to even length with a
            // trailing 0x00 byte (PS3.5 §A.4). JXLSwift's container parser is strict
            // about trailing bytes and rejects the stray pad ("partial box header"),
            // so retry once with a single trailing null removed before giving up.
            if frameData.count % 2 == 0, frameData.last == 0 {
                do {
                    return try decode(Data(frameData.dropLast()))
                } catch {
                    throw DICOMError.parsingFailed("JXLSwift decode failed: \(error)")
                }
            }
            throw DICOMError.parsingFailed("JXLSwift decode failed: \(error)")
        }
    }
}
