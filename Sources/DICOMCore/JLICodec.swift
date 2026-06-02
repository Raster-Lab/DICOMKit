import Foundation
import JLISwift

/// Bench adapter for the JLISwift native-Swift JPEG codec.
///
/// Encodes **lossless** JPEG (ITU-T T.81 SOF3 predictive lossless) and decodes
/// it back, so the DICOMStudio codec bench can compare JLISwift against other
/// JPEG implementations (e.g. libjpeg-turbo `djpeg`) the way it compares
/// J2KSwift against Kakadu/Grok. Lossless-only by design — the bench's axis is
/// bit-exact round-trip + peer decode.
///
/// Pixel bridging: JLISwift's `JLIImage.data` is channel-interleaved `[UInt8]`,
/// row-major, 16-bit samples little-endian — matching DICOM little-endian
/// storage, so only planar→interleaved reshuffling (handled upstream) is needed.
public struct JLICodec: Sendable {
    public init() {}

    // MARK: - Encoding

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
            // Lossless preset: SOF3 predictor 1, point-transform 0, 4:4:4, no
            // perceptual/adaptive paths. For >8-bit, precision must be set to the
            // stored depth or JLISwift derives 12-bit and drops the top bits.
            var cfg = JLIEncoderConfiguration.diagnosticLossless
            if pixelFormat == .uint16 {
                cfg.losslessPrecision = min(16, max(2, descriptor.bitsStored))
            }
            return Data(try JLIEncoder().encode(image, configuration: cfg))
        } catch {
            throw DICOMError.parsingFailed("JLISwift encode failed: \(error)")
        }
    }

    // MARK: - Decoding

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
}
