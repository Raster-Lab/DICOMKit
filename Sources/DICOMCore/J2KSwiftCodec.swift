import Foundation

#if canImport(J2KCore) && canImport(J2KCodec)
import J2KCore
import J2KCodec
#endif

#if canImport(Accelerate)
import Accelerate
#endif

/// Selects which J2KSwift decode API the J2K Compare panel exercises.
/// The viewer's production decode path is unaffected — it always uses the
/// runtime size router via `J2KSwiftCodec.decodeFrame`.
public enum J2KSwiftDecodeMode: String, Sendable, CaseIterable, Identifiable {
    /// `J2KDecoder.decode(...)` — pure-CPU path. Matches the methodology of
    /// J2KSwift's `CROSS_HOST_*_inproc.md` benchmark reports.
    case cpu
    /// `J2KDecoder.decodeGPU(...)` — CPU HT entropy + GPU IDWT.
    case decodeGPU
    /// `J2KDecoder.decodeWithGPUHT(...)` — full GPU pipeline (HT entropy on GPU).
    case decodeWithGPUHT

    public var id: String { rawValue }

    /// Short label suitable for a Picker / row tag.
    public var label: String {
        switch self {
        case .cpu:              return "CPU `decode`"
        case .decodeGPU:        return "`decodeGPU`"
        case .decodeWithGPUHT:  return "`decodeWithGPUHT`"
        }
    }
}

/// Selects which J2KSwift encode API the J2K Compare panel exercises.
/// J2KSwift exposes no `recommendedEncodeAPI` router, so the choice is binary.
public enum J2KSwiftEncodeMode: String, Sendable, CaseIterable, Identifiable {
    /// `J2KEncoder.encode(...)` — CPU path. Matches the published bench.
    case cpu
    /// `J2KEncoder.encodeGPU(...)` — GPU-accelerated encode.
    case gpu

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .cpu: return "CPU `encode`"
        case .gpu: return "`encodeGPU`"
        }
    }
}

/// JPEG 2000 codec adapter backed directly by J2KSwift.
///
/// This provides the Phase 1 pure-Swift JPEG 2000 path for DICOMKit and establishes
/// the foundation for HTJ2K and Part 2 expansion without masking upstream codec issues.
public struct J2KSwiftCodec: ImageCodec, ImageEncoder, Sendable {
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpeg2000Lossless.uid,
        TransferSyntax.jpeg2000.uid,
        TransferSyntax.jpeg2000Part2Lossless.uid,
        TransferSyntax.jpeg2000Part2.uid,
        TransferSyntax.htj2kLossless.uid,
        TransferSyntax.htj2kRPCLLossless.uid,
        TransferSyntax.htj2kLossy.uid
    ]

    public static let supportedEncodingTransferSyntaxes: [String] = supportedTransferSyntaxes

    private let encodingTransferSyntaxUID: String?

    public init(encodingTransferSyntaxUID: String? = nil) {
        self.encodingTransferSyntaxUID = encodingTransferSyntaxUID
    }

    /// Explicit J2KSwift decode entry point selectable by mode. Bypasses the
    /// size-based router used by `decodeFrame`. Used by the J2K Compare panel
    /// to switch between the CPU `decode(...)`, `decodeGPU(...)`, and
    /// `decodeWithGPUHT(...)` APIs, or to fall back to the runtime auto-router.
    /// Production decode in the viewer should continue using `decodeFrame`.
    public static func decode(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        mode: J2KSwiftDecodeMode
    ) throws -> Data {
        #if canImport(J2KCore) && canImport(J2KCodec)
        let decoder = J2KDecoder()
        let image: J2KImage
        do {
            image = try Self.awaitJ2KResult {
                switch mode {
                case .cpu:             return try await decoder.decode(frameData)
                case .decodeGPU:       return try await decoder.decodeGPU(frameData)
                case .decodeWithGPUHT: return try await decoder.decodeWithGPUHT(frameData)
                }
            }
        } catch {
            throw DICOMError.parsingFailed("J2KSwift decode failed: \(error)")
        }
        guard image.width == descriptor.columns, image.height == descriptor.rows else {
            throw DICOMError.parsingFailed(
                "Decoded image dimensions (\(image.width)x\(image.height)) do not match expected (\(descriptor.columns)x\(descriptor.rows))"
            )
        }
        return try packPixels(from: image, descriptor: descriptor)
        #else
        throw DICOMError.unsupportedTransferSyntax("JPEG 2000 requires J2KSwift support in this build")
        #endif
    }

    /// Explicit J2KSwift encode entry point selectable by mode. Mirrors the
    /// `J2KEncoder.encode(...)` (CPU) and `J2KEncoder.encodeGPU(...)` APIs.
    /// Used by the J2K Compare panel; production encode in DICOMKit still goes
    /// through `encodeFrame` on a `J2KSwiftCodec` instance.
    public static func encode(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        transferSyntaxUID: String,
        configuration: CompressionConfiguration,
        mode: J2KSwiftEncodeMode
    ) throws -> Data {
        #if canImport(J2KCore) && canImport(J2KCodec)
        let image = try Self.makeJ2KImage(from: frameData, descriptor: descriptor)
        let encoder = J2KEncoder(
            encodingConfiguration: Self.makeEncodingConfiguration(
                from: configuration,
                transferSyntaxUID: transferSyntaxUID
            )
        )
        return try Self.awaitJ2KResult {
            switch mode {
            case .cpu: return try await encoder.encode(image)
            case .gpu: return try await encoder.encodeGPU(image)
            }
        }
        #else
        throw DICOMError.unsupportedTransferSyntax("JPEG 2000 encoding requires J2KSwift support in this build")
        #endif
    }

    /// Benchmark-style encode: holds **one** `J2KEncoder` and image across all
    /// warmups + timed iterations, mirroring `J2KSwift/Sources/J2KCLI/InProcBench.swift`.
    /// Creating a fresh encoder per iteration can race against
    /// `HTBlockEncoderConformant.useNEONHotPath`'s `dispatch_once` init under
    /// HT-J2K configs and crash inside `applyEntropyCodingHTJ2KFused`.
    ///
    /// Returns the encoded payload (last iteration), all timed-sample ms, and
    /// an optional error string. `samples` has `runs` entries on success.
    public static func benchEncode(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        transferSyntaxUID: String,
        configuration: CompressionConfiguration,
        mode: J2KSwiftEncodeMode,
        warmups: Int,
        runs: Int
    ) -> (data: Data?, samples: [Double], error: String?) {
        #if canImport(J2KCore) && canImport(J2KCodec)
        let image: J2KImage
        do {
            image = try Self.makeJ2KImage(from: frameData, descriptor: descriptor)
        } catch {
            return (nil, [], error.localizedDescription)
        }
        let encoder = J2KEncoder(
            encodingConfiguration: Self.makeEncodingConfiguration(
                from: configuration,
                transferSyntaxUID: transferSyntaxUID
            )
        )
        do {
            let output = try Self.awaitJ2KResult { () -> (Data?, [Double]) in
                var lastOut: Data? = nil
                var samples: [Double] = []
                samples.reserveCapacity(runs)
                for _ in 0..<warmups {
                    switch mode {
                    case .cpu: lastOut = try await encoder.encode(image)
                    case .gpu: lastOut = try await encoder.encodeGPU(image)
                    }
                }
                for _ in 0..<runs {
                    let t0 = DispatchTime.now()
                    switch mode {
                    case .cpu: lastOut = try await encoder.encode(image)
                    case .gpu: lastOut = try await encoder.encodeGPU(image)
                    }
                    samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000.0)
                }
                return (lastOut, samples)
            }
            return (output.0, output.1, nil)
        } catch {
            return (nil, [], error.localizedDescription)
        }
        #else
        return (nil, [], "JPEG 2000 encoding requires J2KSwift support in this build")
        #endif
    }

    /// Benchmark-style decode: holds **one** `J2KDecoder` across all warmups
    /// + timed iterations. `mode` selects the decode API explicitly.
    public static func benchDecode(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        mode: J2KSwiftDecodeMode,
        warmups: Int,
        runs: Int
    ) -> (data: Data?, samples: [Double], error: String?) {
        #if canImport(J2KCore) && canImport(J2KCodec)
        let decoder = J2KDecoder()
        let output: (J2KImage?, [Double])
        do {
            output = try Self.awaitJ2KResult { () -> (J2KImage?, [Double]) in
                @inline(__always) func runOne() async throws -> J2KImage {
                    switch mode {
                    case .cpu:             return try await decoder.decode(frameData)
                    case .decodeGPU:       return try await decoder.decodeGPU(frameData)
                    case .decodeWithGPUHT: return try await decoder.decodeWithGPUHT(frameData)
                    }
                }
                var lastImage: J2KImage? = nil
                var samples: [Double] = []
                samples.reserveCapacity(runs)
                for _ in 0..<warmups { lastImage = try await runOne() }
                for _ in 0..<runs {
                    let t0 = DispatchTime.now()
                    lastImage = try await runOne()
                    samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000.0)
                }
                return (lastImage, samples)
            }
        } catch {
            return (nil, [], error.localizedDescription)
        }
        guard let image = output.0 else { return (nil, [], "no decode produced") }
        guard image.width == descriptor.columns, image.height == descriptor.rows else {
            return (nil, [], "decoded \(image.width)x\(image.height) ≠ expected \(descriptor.columns)x\(descriptor.rows)")
        }
        do {
            return (try Self.packPixels(from: image, descriptor: descriptor), output.1, nil)
        } catch {
            return (nil, [], error.localizedDescription)
        }
        #else
        return (nil, [], "JPEG 2000 requires J2KSwift support in this build")
        #endif
    }

    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG 2000 data")
        }

        #if canImport(J2KCore) && canImport(J2KCodec)
        return try Self.decodeWithJ2KSwift(frameData, descriptor: descriptor)
        #else
        throw DICOMError.unsupportedTransferSyntax("JPEG 2000 requires J2KSwift support in this build")
        #endif
    }

    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }

        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }

        return true
    }

    public func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int, configuration: CompressionConfiguration) throws -> Data {
        guard canEncode(with: configuration, descriptor: descriptor) else {
            throw DICOMError.parsingFailed(
                "Unsupported JPEG 2000 encoding layout: bitsAllocated=\(descriptor.bitsAllocated), samplesPerPixel=\(descriptor.samplesPerPixel)"
            )
        }

        guard frameData.count >= descriptor.bytesPerFrame else {
            throw DICOMError.parsingFailed(
                "Frame data too short for JPEG 2000 encoding: expected at least \(descriptor.bytesPerFrame) bytes, got \(frameData.count)"
            )
        }

        #if canImport(J2KCore) && canImport(J2KCodec)
        let image = try Self.makeJ2KImage(from: frameData, descriptor: descriptor)
        let encoder = J2KEncoder(
            encodingConfiguration: Self.makeEncodingConfiguration(
                from: configuration,
                transferSyntaxUID: encodingTransferSyntaxUID
            )
        )
        let encoded = try Self.awaitJ2KResult {
            try await encoder.encode(image)
        }
        try Self.verifyEncodedRoundTrip(encoded, original: frameData, descriptor: descriptor, configuration: configuration)
        return encoded
        #else
        throw DICOMError.unsupportedTransferSyntax("JPEG 2000 encoding requires J2KSwift support in this build")
        #endif
    }
}

private extension J2KSwiftCodec {
    final class AsyncResultBox<T>: @unchecked Sendable {
        var result: Result<T, Error>?
    }

    #if canImport(J2KCore) && canImport(J2KCodec)
    static func awaitJ2KResult<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = AsyncResultBox<T>()

        Task.detached(priority: .userInitiated) {
            do {
                box.result = .success(try await operation())
            } catch {
                box.result = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = box.result else {
            throw DICOMError.parsingFailed("J2KSwift async bridge returned no result")
        }

        return try result.get()
    }

    static func makeEncodingConfiguration(
        from configuration: CompressionConfiguration,
        transferSyntaxUID: String?
    ) -> J2KEncodingConfiguration {
        let targetSyntax = transferSyntaxUID.flatMap(TransferSyntax.from(uid:))
        let isLossless = targetSyntax?.isLossless ?? (configuration.preferLossless || configuration.quality.isLossless)
        let useHTJ2K = targetSyntax?.isHTJ2K ?? false

        // DICOM HTJ2K transfer syntaxes (PS3.5 A.4.6) reference ISO/IEC 15444-15;
        // emit the Part-15 conformant block layout so codestreams interoperate with
        // OpenJPH and other Part-15 PACS decoders.
        let htj2kBlockFormat: HTBlockFormat = useHTJ2K ? .conformant : .custom

        // Match J2KSwift library / CLI lossless defaults: 5 decomposition levels,
        // 5 quality layers, RPCL progression. The previous (0, 1, .lrcp) tuple
        // crippled compression — single-resolution wavelet means no multi-band
        // refinement, and HTJ2K in particular collapsed to ~1.24× ratios on
        // 16-bit MG mammograms vs ~6× from the same library via its CLI. RPCL
        // is required for `htj2kRPCLLossless` (PS3.5 §A.4.6) and is what
        // J2KSwift's CLI uses everywhere else.
        return J2KEncodingConfiguration(
            quality: isLossless ? 1.0 : configuration.quality.value,
            lossless: isLossless,
            progressionOrder: .rpcl,
            useHTJ2K: useHTJ2K,
            useReversibleFilter: isLossless,
            htj2kBlockFormat: htj2kBlockFormat
        )
    }

    static func verifyEncodedRoundTrip(
        _ encoded: Data,
        original: Data,
        descriptor: PixelDataDescriptor,
        configuration: CompressionConfiguration
    ) throws {
        let decoded = try decodeWithJ2KSwift(encoded, descriptor: descriptor)
        guard decoded.count == descriptor.bytesPerFrame else {
            throw DICOMError.parsingFailed(
                "Decoded byte count \(decoded.count) does not match expected \(descriptor.bytesPerFrame)"
            )
        }

        if configuration.preferLossless || configuration.quality.isLossless {
            guard decoded == original else {
                throw DICOMError.parsingFailed("J2KSwift lossless round-trip validation failed")
            }
        }
    }

    static func decodeWithJ2KSwift(_ frameData: Data, descriptor: PixelDataDescriptor) throws -> Data {
        // Viewer path: CPU `J2KDecoder.decode(...)`. The J2K Compare panel
        // overrides per-call via `J2KSwiftCodec.decode(...,mode:)` to pin the
        // GPU paths for benchmarking.
        let image: J2KImage
        do {
            image = try Self.awaitJ2KResult {
                try await J2KDecoder().decode(frameData)
            }
        } catch {
            throw DICOMError.parsingFailed("J2KSwift decode failed: \(error)")
        }

        guard image.width == descriptor.columns, image.height == descriptor.rows else {
            throw DICOMError.parsingFailed(
                "Decoded image dimensions (\(image.width)x\(image.height)) do not match expected (\(descriptor.columns)x\(descriptor.rows))"
            )
        }

        return try packPixels(from: image, descriptor: descriptor)
    }

    static func makeJ2KImage(from frameData: Data, descriptor: PixelDataDescriptor) throws -> J2KImage {
        let expectedBytes = descriptor.bytesPerFrame
        let bytesPerSample = descriptor.bytesPerSample
        let componentPixelCount = descriptor.rows * descriptor.columns
        let componentByteCount = componentPixelCount * bytesPerSample

        guard frameData.count >= expectedBytes else {
            throw DICOMError.parsingFailed("Frame data too short for JPEG 2000 encoding")
        }

        // DICOM Explicit VR LE pixel data is already little-endian. Pass it to
        // J2KSwift verbatim and signal the byte order so the encoder does not
        // run its statistical inference — this also saves us the O(N) manual
        // swap we used to do before v4.0's `sampleByteOrder` hint existed.
        let byteOrderHint: J2KComponent.ByteOrder? = (bytesPerSample == 2) ? .littleEndian : nil

        let colorSpace: J2KColorSpace = descriptor.samplesPerPixel == 1 ? .grayscale : .sRGB
        let components: [J2KComponent]

        switch descriptor.samplesPerPixel {
        case 1:
            let componentData: Data
            if frameData.count == expectedBytes {
                componentData = frameData
            } else {
                componentData = frameData.subdata(in: frameData.startIndex..<frameData.startIndex + expectedBytes)
            }
            components = [
                J2KComponent(
                    index: 0,
                    bitDepth: descriptor.bitsStored,
                    signed: descriptor.isSigned,
                    width: descriptor.columns,
                    height: descriptor.rows,
                    data: componentData,
                    sampleByteOrder: byteOrderHint
                )
            ]

        case 3:
            let planes: [Data]
            if descriptor.planarConfiguration == 1 {
                guard frameData.count >= componentByteCount * 3 else {
                    throw DICOMError.parsingFailed("Planar RGB frame data too short for JPEG 2000 encoding")
                }
                planes = (0..<3).map { componentIndex in
                    let start = frameData.startIndex + componentIndex * componentByteCount
                    let end = start + componentByteCount
                    return frameData.subdata(in: start..<end)
                }
            } else {
                planes = try deinterleaveRGB(
                    frameData: frameData,
                    bytesPerSample: bytesPerSample,
                    componentPixelCount: componentPixelCount,
                    componentByteCount: componentByteCount
                )
            }

            components = (0..<3).map { componentIndex in
                J2KComponent(
                    index: componentIndex,
                    bitDepth: descriptor.bitsStored,
                    signed: descriptor.isSigned,
                    width: descriptor.columns,
                    height: descriptor.rows,
                    data: planes[componentIndex],
                    sampleByteOrder: byteOrderHint
                )
            }

        default:
            throw DICOMError.parsingFailed("Unsupported samples per pixel for JPEG 2000 encoding: \(descriptor.samplesPerPixel)")
        }

        return J2KImage(
            width: descriptor.columns,
            height: descriptor.rows,
            components: components,
            colorSpace: colorSpace
        )
    }

    /// De-interleaves a chunky RGB buffer into three planar Data components.
    /// Faster than the previous iterator-based build because it preallocates
    /// each plane and writes bytes via UnsafeMutableBufferPointer.
    static func deinterleaveRGB(
        frameData: Data,
        bytesPerSample: Int,
        componentPixelCount: Int,
        componentByteCount: Int
    ) throws -> [Data] {
        let bytesPerPixel = bytesPerSample * 3
        guard frameData.count >= componentPixelCount * bytesPerPixel else {
            throw DICOMError.parsingFailed("RGB frame data ended unexpectedly while building J2K components")
        }
        var r = Data(count: componentByteCount)
        var g = Data(count: componentByteCount)
        var b = Data(count: componentByteCount)
        frameData.withUnsafeBytes { src in
            let srcBase = src.baseAddress!.assumingMemoryBound(to: UInt8.self)
            r.withUnsafeMutableBytes { rBuf in
                g.withUnsafeMutableBytes { gBuf in
                    b.withUnsafeMutableBytes { bBuf in
                        let rp = rBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        let gp = gBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        let bp = bBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        var srcOff = 0
                        var dstOff = 0
                        for _ in 0..<componentPixelCount {
                            for k in 0..<bytesPerSample {
                                rp[dstOff + k] = srcBase[srcOff + k]
                                gp[dstOff + k] = srcBase[srcOff + bytesPerSample + k]
                                bp[dstOff + k] = srcBase[srcOff + 2 * bytesPerSample + k]
                            }
                            srcOff += bytesPerPixel
                            dstOff += bytesPerSample
                        }
                    }
                }
            }
        }
        return [r, g, b]
    }

    static func packPixels(from image: J2KImage, descriptor: PixelDataDescriptor) throws -> Data {
        let bytesPerSample = descriptor.bytesPerSample
        let expectedComponentByteCount = descriptor.rows * descriptor.columns * bytesPerSample

        if descriptor.samplesPerPixel == 1 {
            guard let component = image.components.first else {
                throw DICOMError.parsingFailed("Decoded JPEG 2000 image contains no components")
            }
            guard component.data.count >= expectedComponentByteCount else {
                throw DICOMError.parsingFailed(
                    "Decoded component data too short: expected \(expectedComponentByteCount) bytes, got \(component.data.count)"
                )
            }
            var output = component.data.count == expectedComponentByteCount
                ? component.data
                : component.data.subdata(in: component.data.startIndex..<component.data.startIndex + expectedComponentByteCount)
            swapBytesInPlaceIfNeeded(&output, bytesPerSample: bytesPerSample)
            return output
        }

        guard image.components.count == descriptor.samplesPerPixel else {
            throw DICOMError.parsingFailed(
                "Decoded component count \(image.components.count) does not match samples per pixel \(descriptor.samplesPerPixel)"
            )
        }

        var components: [Data] = []
        components.reserveCapacity(descriptor.samplesPerPixel)
        for component in image.components.prefix(descriptor.samplesPerPixel) {
            guard component.data.count >= expectedComponentByteCount else {
                throw DICOMError.parsingFailed(
                    "Decoded RGB component data too short: expected \(expectedComponentByteCount) bytes, got \(component.data.count)"
                )
            }
            var plane = component.data.count == expectedComponentByteCount
                ? component.data
                : component.data.subdata(in: component.data.startIndex..<component.data.startIndex + expectedComponentByteCount)
            swapBytesInPlaceIfNeeded(&plane, bytesPerSample: bytesPerSample)
            components.append(plane)
        }

        if descriptor.planarConfiguration == 1 {
            var packed = Data(capacity: expectedComponentByteCount * descriptor.samplesPerPixel)
            for plane in components { packed.append(plane) }
            return packed
        }

        return interleaveRGB(
            planes: components,
            bytesPerSample: bytesPerSample,
            pixelCount: descriptor.rows * descriptor.columns
        )
    }

    /// Interleaves R/G/B planar buffers back into chunky RGB layout.
    static func interleaveRGB(planes: [Data], bytesPerSample: Int, pixelCount: Int) -> Data {
        let totalBytes = pixelCount * bytesPerSample * 3
        var packed = Data(count: totalBytes)
        packed.withUnsafeMutableBytes { dst in
            let dstBase = dst.baseAddress!.assumingMemoryBound(to: UInt8.self)
            planes[0].withUnsafeBytes { r in
                planes[1].withUnsafeBytes { g in
                    planes[2].withUnsafeBytes { b in
                        let rp = r.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        let gp = g.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        let bp = b.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        var srcOff = 0
                        var dstOff = 0
                        for _ in 0..<pixelCount {
                            for k in 0..<bytesPerSample {
                                dstBase[dstOff + k] = rp[srcOff + k]
                                dstBase[dstOff + bytesPerSample + k] = gp[srcOff + k]
                                dstBase[dstOff + 2 * bytesPerSample + k] = bp[srcOff + k]
                            }
                            srcOff += bytesPerSample
                            dstOff += bytesPerSample * 3
                        }
                    }
                }
            }
        }
        return packed
    }
    #endif

    /// In-place 16-bit byte swap using Accelerate's vImage (NEON on Apple Silicon,
    /// SSE on x86). Falls back to a UInt16 `.byteSwapped` loop when Accelerate is
    /// unavailable; that loop autovectorizes with the ARM REV16 instruction at -O.
    /// No-op for bytesPerSample != 2.
    @inline(__always)
    static func swapBytesInPlaceIfNeeded(_ data: inout Data, bytesPerSample: Int) {
        guard bytesPerSample == 2 else { return }
        let byteCount = data.count
        guard byteCount >= 2, byteCount % 2 == 0 else { return }
        data.withUnsafeMutableBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            #if canImport(Accelerate)
            var src = vImage_Buffer(
                data: base,
                height: 1,
                width: vImagePixelCount(byteCount / 2),
                rowBytes: byteCount
            )
            var dst = src  // in-place
            _ = vImageByteSwap_Planar16U(&src, &dst, vImage_Flags(kvImageNoFlags))
            #else
            let ptr = base.assumingMemoryBound(to: UInt16.self)
            let count = byteCount / 2
            for i in 0..<count { ptr[i] = ptr[i].byteSwapped }
            #endif
        }
    }
}
