// OpenJPEGCodec.swift
// DICOMCore
//
// Decode-only JPEG 2000 codec backed by OpenJPEG 2.x (https://www.openjpeg.org).
// Used exclusively in the J2KSwift comparison panel — not registered in CodecRegistry.
//
// Requires: brew install openjpeg

#if canImport(COpenJPEG) && os(macOS)
import COpenJPEG
import Foundation

// MARK: - OpenJPEGCodec

/// Decode-only JPEG 2000 codec wrapping the OpenJPEG 2.x C library.
///
/// Supports J2K codestreams (bare codestream, not JP2 container).
/// Output format mirrors J2KSwiftCodec: little-endian, interleaved samples.
public struct OpenJPEGCodec: Sendable {

    public static let version: String = String(cString: opj_version())

    public init() {}

    // MARK: - Decode

    /// Decodes a single JPEG 2000 frame and returns raw pixel bytes.
    ///
    /// - Parameters:
    ///   - frameData: Compressed J2K codestream bytes.
    ///   - descriptor: DICOM pixel descriptor (rows, columns, bitsAllocated, samplesPerPixel, isSigned).
    /// - Returns: Uncompressed pixel bytes (little-endian, interleaved).
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor) throws -> Data {
        // Detect format from magic bytes: J2K starts with 0xFF 0x4F, JP2 with box header
        let format: OPJ_CODEC_FORMAT = frameData.count >= 2
            && frameData[frameData.startIndex] == 0xFF
            && frameData[frameData.startIndex + 1] == 0x4F
            ? OPJ_CODEC_J2K : OPJ_CODEC_JP2

        guard let codec = opj_create_decompress(format) else {
            throw OpenJPEGError.codecCreationFailed
        }
        defer { opj_destroy_codec(codec) }

        // Suppress all stdout/stderr from OpenJPEG
        let noop: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { _, _ in }
        opj_set_info_handler(codec, noop, nil)
        opj_set_warning_handler(codec, noop, nil)
        opj_set_error_handler(codec, noop, nil)

        var params = opj_dparameters_t()
        opj_set_default_decoder_parameters(&params)
        guard opj_setup_decoder(codec, &params) == OPJ_TRUE else {
            throw OpenJPEGError.setupFailed
        }

        // Build in-memory stream — retain ctx; free callback releases it on stream destroy
        let ctx = OPJMemoryContext(frameData)
        guard let stream = opj_stream_create(OPJ_SIZE_T(frameData.count), OPJ_TRUE) else {
            throw OpenJPEGError.streamCreationFailed
        }
        defer { opj_stream_destroy(stream) }

        opj_stream_set_user_data(stream, Unmanaged.passRetained(ctx).toOpaque(), opjFreeContext)
        opj_stream_set_user_data_length(stream, OPJ_UINT64(frameData.count))
        opj_stream_set_read_function(stream, opjRead)
        opj_stream_set_skip_function(stream, opjSkip)
        opj_stream_set_seek_function(stream, opjSeek)

        var image: UnsafeMutablePointer<opj_image_t>? = nil
        guard opj_read_header(stream, codec, &image) == OPJ_TRUE, let imgPtr = image else {
            throw OpenJPEGError.readHeaderFailed
        }
        defer { opj_image_destroy(imgPtr) }

        guard opj_decode(codec, stream, imgPtr) == OPJ_TRUE else {
            throw OpenJPEGError.decodeFailed
        }
        _ = opj_end_decompress(codec, stream)

        return try extractPixels(from: imgPtr, descriptor: descriptor)
    }
}

// MARK: - Pixel Extraction

private func extractPixels(
    from imgPtr: UnsafeMutablePointer<opj_image_t>,
    descriptor: PixelDataDescriptor
) throws -> Data {
    let img = imgPtr.pointee
    let w = Int(img.x1 - img.x0)
    let h = Int(img.y1 - img.y0)
    let numComps = Int(img.numcomps)
    guard w > 0, h > 0, numComps > 0 else { throw OpenJPEGError.invalidDimensions }

    let pixelCount = w * h
    let bytesPerSample = descriptor.bitsAllocated <= 8 ? 1 : 2
    var out = Data(capacity: pixelCount * numComps * bytesPerSample)

    for i in 0..<pixelCount {
        for c in 0..<numComps {
            let comp = img.comps.advanced(by: c).pointee
            let raw = comp.data[i]   // OPJ_INT32
            if bytesPerSample == 1 {
                out.append(UInt8(clamping: Int(raw)))
            } else if comp.sgnd != 0 {
                let v = UInt16(bitPattern: Int16(clamping: Int(raw)))
                out.append(UInt8(v & 0xFF))
                out.append(UInt8(v >> 8))
            } else {
                let v = UInt16(clamping: UInt32(bitPattern: raw))
                out.append(UInt8(v & 0xFF))
                out.append(UInt8(v >> 8))
            }
        }
    }
    return out
}

// MARK: - In-Memory Stream Context

private final class OPJMemoryContext {
    let data: Data
    var offset: Int = 0
    var remaining: Int { data.count - offset }
    init(_ data: Data) { self.data = data }
}

// MARK: - C Callbacks (global functions — no captures, usable as @convention(c) pointers)

private func opjRead(
    buf: UnsafeMutableRawPointer?,
    nb: OPJ_SIZE_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_SIZE_T {
    guard let buf, let userData else { return OPJ_SIZE_T.max }
    let ctx = Unmanaged<OPJMemoryContext>.fromOpaque(userData).takeUnretainedValue()
    let toRead = min(Int(nb), ctx.remaining)
    guard toRead > 0 else { return OPJ_SIZE_T.max }
    ctx.data.withUnsafeBytes { src in
        buf.copyMemory(from: src.baseAddress!.advanced(by: ctx.offset), byteCount: toRead)
    }
    ctx.offset += toRead
    return OPJ_SIZE_T(toRead)
}

private func opjSkip(
    nb: OPJ_OFF_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_OFF_T {
    guard let userData else { return -1 }
    let ctx = Unmanaged<OPJMemoryContext>.fromOpaque(userData).takeUnretainedValue()
    let toSkip = min(Int(nb), ctx.remaining)
    ctx.offset += toSkip
    return OPJ_OFF_T(toSkip)
}

private func opjSeek(
    pos: OPJ_OFF_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_BOOL {
    guard let userData, pos >= 0 else { return OPJ_FALSE }
    let ctx = Unmanaged<OPJMemoryContext>.fromOpaque(userData).takeUnretainedValue()
    guard Int(pos) <= ctx.data.count else { return OPJ_FALSE }
    ctx.offset = Int(pos)
    return OPJ_TRUE
}

private func opjFreeContext(userData: UnsafeMutableRawPointer?) {
    guard let userData else { return }
    Unmanaged<OPJMemoryContext>.fromOpaque(userData).release()
}

// MARK: - Errors

public enum OpenJPEGError: Error, LocalizedError {
    case codecCreationFailed, setupFailed, streamCreationFailed
    case readHeaderFailed, decodeFailed, invalidDimensions

    public var errorDescription: String? {
        switch self {
        case .codecCreationFailed:   return "OpenJPEG: failed to create decoder"
        case .setupFailed:           return "OpenJPEG: failed to set up decoder parameters"
        case .streamCreationFailed:  return "OpenJPEG: failed to create memory stream"
        case .readHeaderFailed:      return "OpenJPEG: failed to read J2K header"
        case .decodeFailed:          return "OpenJPEG: decoding failed"
        case .invalidDimensions:     return "OpenJPEG: decoded image has invalid dimensions"
        }
    }
}

#endif // canImport(COpenJPEG) && os(macOS)
