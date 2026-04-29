// OpenJPEGCodec.swift
// DICOMCore
//
// JPEG 2000 codec backed by OpenJPEG 2.x (https://www.openjpeg.org).
// Used by the dicom-convert `--openjpeg` backend selector and the J2KSwift
// comparison panel. NOT registered in CodecRegistry — the converter calls it
// directly when JPEG2000Backend is `.openJPEG`.
//
// Requires: brew install openjpeg

#if canImport(COpenJPEG) && os(macOS)
import COpenJPEG
import Foundation

// MARK: - OpenJPEGCodec

/// JPEG 2000 codec wrapping the OpenJPEG 2.x C library.
///
/// Supports J2K codestreams (bare codestream, not JP2 container) for both
/// decoding and encoding. Does **not** support HTJ2K (ISO/IEC 15444-15).
///
/// Output / input pixel format matches J2KSwiftCodec:
/// little-endian, interleaved samples.
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

    // MARK: - Encode

    /// Encodes a single frame to a bare J2K codestream.
    ///
    /// - Parameters:
    ///   - frameData: Uncompressed pixel bytes (little-endian, interleaved samples).
    ///   - descriptor: DICOM pixel descriptor (rows, columns, bitsAllocated, bitsStored,
    ///     samplesPerPixel, isSigned, photometricInterpretation).
    ///   - configuration: Compression configuration. `preferLossless` or
    ///     `quality.isLossless` selects the reversible 5/3 transform; otherwise
    ///     the irreversible 9/7 transform is used and `quality.value` is mapped
    ///     to a target compression ratio.
    /// - Returns: Bare J2K codestream bytes (starts with SOC marker `FF 4F`).
    /// - Throws: ``OpenJPEGError`` on any libopenjpeg failure.
    ///
    /// - Important: Does NOT support HTJ2K transfer syntaxes — call sites must
    ///   route those to ``J2KSwiftCodec`` instead.
    public func encodeFrame(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        configuration: CompressionConfiguration
    ) throws -> Data {
        guard descriptor.rows > 0, descriptor.columns > 0 else {
            throw OpenJPEGError.invalidDimensions
        }
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            throw OpenJPEGError.unsupportedBitDepth(descriptor.bitsAllocated)
        }
        let expectedBytes = descriptor.bytesPerFrame
        guard frameData.count >= expectedBytes else {
            throw OpenJPEGError.frameTooShort(expected: expectedBytes, got: frameData.count)
        }

        let isLossless = configuration.preferLossless || configuration.quality.isLossless

        // Build component parameters.
        let numComps = max(1, UInt32(descriptor.samplesPerPixel))
        var cmptparms = [opj_image_cmptparm_t](
            repeating: opj_image_cmptparm_t(),
            count: Int(numComps)
        )
        for i in 0..<Int(numComps) {
            cmptparms[i].dx = 1
            cmptparms[i].dy = 1
            cmptparms[i].w = UInt32(descriptor.columns)
            cmptparms[i].h = UInt32(descriptor.rows)
            cmptparms[i].x0 = 0
            cmptparms[i].y0 = 0
            cmptparms[i].prec = UInt32(descriptor.bitsStored > 0 ? descriptor.bitsStored : descriptor.bitsAllocated)
            cmptparms[i].sgnd = descriptor.isSigned ? 1 : 0
        }

        let colorSpace: COLOR_SPACE = numComps >= 3 ? OPJ_CLRSPC_SRGB : OPJ_CLRSPC_GRAY

        guard let image = cmptparms.withUnsafeMutableBufferPointer({ ptr -> UnsafeMutablePointer<opj_image_t>? in
            opj_image_create(numComps, ptr.baseAddress, colorSpace)
        }) else {
            throw OpenJPEGError.imageCreationFailed
        }
        defer { opj_image_destroy(image) }

        // Set logical extent on the image as well (required by libopenjpeg).
        image.pointee.x0 = 0
        image.pointee.y0 = 0
        image.pointee.x1 = UInt32(descriptor.columns)
        image.pointee.y1 = UInt32(descriptor.rows)

        // Unpack frame bytes into per-component OPJ_INT32 planes.
        try unpackPixels(
            frameData: frameData,
            into: image,
            descriptor: descriptor,
            numComps: Int(numComps)
        )

        // Configure encoder parameters.
        var params = opj_cparameters_t()
        opj_set_default_encoder_parameters(&params)
        params.cod_format = 0           // 0 = J2K codestream (we strip JP2 container anyway)
        params.tcp_numlayers = 1
        params.cp_disto_alloc = 1
        if isLossless {
            params.irreversible = 0     // 5/3 reversible DWT
            params.tcp_rates.0 = 0      // 0 ⇒ lossless rate
        } else {
            params.irreversible = 1     // 9/7 irreversible DWT
            // Map quality.value (0…1) to a compression ratio. quality 1.0 ⇒ ~2:1,
            // quality 0.5 ⇒ ~20:1, quality 0.1 ⇒ ~100:1. The OpenJPEG `tcp_rates[0]`
            // is the inverse compression ratio (rate 1.0 = lossless, larger = lossier).
            let q = max(0.05, min(1.0, configuration.quality.value))
            let rate = max(2.0, Float(2.0 + (1.0 - q) * 98.0))   // 2.0 … 100.0
            params.tcp_rates.0 = rate
        }
        params.numresolution = 5        // matches J2KSwift CLI default
        params.prog_order = OPJ_LRCP

        // Multi-component transform (RGB → YCbCr) when the source is interleaved RGB.
        if numComps == 3, descriptor.photometricInterpretation == .rgb {
            params.tcp_mct = 1
        }

        guard let codec = opj_create_compress(OPJ_CODEC_J2K) else {
            throw OpenJPEGError.codecCreationFailed
        }
        defer { opj_destroy_codec(codec) }

        // Suppress libopenjpeg log output.
        let noop: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { _, _ in }
        opj_set_info_handler(codec, noop, nil)
        opj_set_warning_handler(codec, noop, nil)
        opj_set_error_handler(codec, noop, nil)

        guard opj_setup_encoder(codec, &params, image) == OPJ_TRUE else {
            throw OpenJPEGError.setupFailed
        }

        // In-memory write stream.
        guard let stream = opj_stream_create(1024 * 1024, OPJ_FALSE) else {
            throw OpenJPEGError.streamCreationFailed
        }
        defer { opj_stream_destroy(stream) }

        let writeCtx = OPJWriteContext()
        opj_stream_set_user_data(stream, Unmanaged.passRetained(writeCtx).toOpaque(), opjFreeWriteContext)
        opj_stream_set_user_data_length(stream, 0)
        opj_stream_set_write_function(stream, opjWrite)
        opj_stream_set_skip_function(stream, opjWriteSkip)
        opj_stream_set_seek_function(stream, opjWriteSeek)

        guard opj_start_compress(codec, image, stream) == OPJ_TRUE else {
            throw OpenJPEGError.encodeFailed
        }
        guard opj_encode(codec, stream) == OPJ_TRUE else {
            throw OpenJPEGError.encodeFailed
        }
        guard opj_end_compress(codec, stream) == OPJ_TRUE else {
            throw OpenJPEGError.encodeFailed
        }

        return writeCtx.buffer
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

// MARK: - Pixel Packing (Encode)

/// Reads `frameData` (DICOM little-endian, interleaved samples) and writes the
/// per-component `OPJ_INT32` planes into `image.comps[c].data`.
private func unpackPixels(
    frameData: Data,
    into image: UnsafeMutablePointer<opj_image_t>,
    descriptor: PixelDataDescriptor,
    numComps: Int
) throws {
    let pixelCount = descriptor.rows * descriptor.columns
    let bytesPerSample = descriptor.bitsAllocated <= 8 ? 1 : 2
    let isSigned = descriptor.isSigned

    // Validate that each component has its data buffer allocated.
    for c in 0..<numComps {
        guard image.pointee.comps.advanced(by: c).pointee.data != nil else {
            throw OpenJPEGError.imageCreationFailed
        }
    }

    frameData.withUnsafeBytes { rawBuf in
        guard let base = rawBuf.baseAddress else { return }
        for i in 0..<pixelCount {
            for c in 0..<numComps {
                let offset = (i * numComps + c) * bytesPerSample
                let value: Int32
                if bytesPerSample == 1 {
                    let b = base.load(fromByteOffset: offset, as: UInt8.self)
                    value = isSigned
                        ? Int32(Int8(bitPattern: b))
                        : Int32(b)
                } else {
                    // Little-endian 16-bit.
                    let lo = base.load(fromByteOffset: offset, as: UInt8.self)
                    let hi = base.load(fromByteOffset: offset + 1, as: UInt8.self)
                    let u16 = UInt16(lo) | (UInt16(hi) << 8)
                    value = isSigned
                        ? Int32(Int16(bitPattern: u16))
                        : Int32(u16)
                }
                image.pointee.comps.advanced(by: c).pointee.data[i] = value
            }
        }
    }
}

// MARK: - In-Memory Write Stream Context

private final class OPJWriteContext {
    var buffer: Data = Data()
    var offset: Int = 0
    init() {}
}

private func opjWrite(
    buf: UnsafeMutableRawPointer?,
    nb: OPJ_SIZE_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_SIZE_T {
    guard let buf, let userData, nb > 0 else { return OPJ_SIZE_T.max }
    let ctx = Unmanaged<OPJWriteContext>.fromOpaque(userData).takeUnretainedValue()
    let count = Int(nb)
    let endOffset = ctx.offset + count
    if ctx.buffer.count < endOffset {
        ctx.buffer.append(Data(count: endOffset - ctx.buffer.count))
    }
    ctx.buffer.withUnsafeMutableBytes { dst in
        guard let dstBase = dst.baseAddress else { return }
        memcpy(dstBase.advanced(by: ctx.offset), buf, count)
    }
    ctx.offset = endOffset
    return OPJ_SIZE_T(count)
}

private func opjWriteSkip(
    nb: OPJ_OFF_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_OFF_T {
    guard let userData, nb >= 0 else { return -1 }
    let ctx = Unmanaged<OPJWriteContext>.fromOpaque(userData).takeUnretainedValue()
    let target = ctx.offset + Int(nb)
    if ctx.buffer.count < target {
        ctx.buffer.append(Data(count: target - ctx.buffer.count))
    }
    ctx.offset = target
    return nb
}

private func opjWriteSeek(
    pos: OPJ_OFF_T,
    userData: UnsafeMutableRawPointer?
) -> OPJ_BOOL {
    guard let userData, pos >= 0 else { return OPJ_FALSE }
    let ctx = Unmanaged<OPJWriteContext>.fromOpaque(userData).takeUnretainedValue()
    let target = Int(pos)
    if ctx.buffer.count < target {
        ctx.buffer.append(Data(count: target - ctx.buffer.count))
    }
    ctx.offset = target
    return OPJ_TRUE
}

private func opjFreeWriteContext(userData: UnsafeMutableRawPointer?) {
    guard let userData else { return }
    Unmanaged<OPJWriteContext>.fromOpaque(userData).release()
}

// MARK: - Errors

public enum OpenJPEGError: Error, LocalizedError {
    case codecCreationFailed, setupFailed, streamCreationFailed
    case readHeaderFailed, decodeFailed, encodeFailed
    case imageCreationFailed
    case invalidDimensions
    case unsupportedBitDepth(Int)
    case frameTooShort(expected: Int, got: Int)

    public var errorDescription: String? {
        switch self {
        case .codecCreationFailed:   return "OpenJPEG: failed to create codec"
        case .setupFailed:           return "OpenJPEG: failed to set up codec parameters"
        case .streamCreationFailed:  return "OpenJPEG: failed to create memory stream"
        case .readHeaderFailed:      return "OpenJPEG: failed to read J2K header"
        case .decodeFailed:          return "OpenJPEG: decoding failed"
        case .encodeFailed:          return "OpenJPEG: encoding failed"
        case .imageCreationFailed:   return "OpenJPEG: failed to create opj_image_t"
        case .invalidDimensions:     return "OpenJPEG: image has invalid dimensions"
        case .unsupportedBitDepth(let bits):
            return "OpenJPEG: unsupported bitsAllocated \(bits) (only 8 or 16 supported)"
        case .frameTooShort(let expected, let got):
            return "OpenJPEG: frame data too short — expected \(expected) bytes, got \(got)"
        }
    }
}

#endif // canImport(COpenJPEG) && os(macOS)
