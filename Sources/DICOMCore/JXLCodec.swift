import Foundation
import JXLSwift

/// Bench adapter for the JXLSwift pure-Swift JPEG XL codec.
///
/// Encodes **lossless** JPEG XL (Modular mode, distance 0) and decodes it back,
/// so the DICOMStudio codec bench can compare JXLSwift against other JPEG XL
/// implementations (e.g. libjxl `djxl`). Lossless-only by design: JXLSwift's
/// lossy VarDCT path is only partially implemented, and the bench's axis is
/// bit-exact round-trip + peer decode.
///
/// Pixel bridging: JXLSwift's `ImageFrame.data` is channel-interleaved `[UInt8]`,
/// row-major, 16-bit samples little-endian — matching DICOM little-endian
/// storage. JXLSwift handles only unsigned samples, so signed frames are
/// rejected here rather than silently mis-encoded.
public struct JXLCodec: Sendable {
    public init() {}

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
        do {
            let frame = try JXLDecoder().decode(frameData)
            return dicomFrameBytes(fromInterleaved: frame.data, descriptor: descriptor)
        } catch {
            throw DICOMError.parsingFailed("JXLSwift decode failed: \(error)")
        }
    }
}
