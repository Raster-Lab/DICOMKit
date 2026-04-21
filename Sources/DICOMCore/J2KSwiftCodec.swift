import Foundation

#if canImport(J2KCore) && canImport(J2KCodec)
import J2KCore
import J2KCodec
#endif

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
        let useRPCL = transferSyntaxUID == TransferSyntax.htj2kRPCLLossless.uid

        // Part 2 uses the same encoding pipeline as Part 1. The built-in RCT/ICT
        // transforms apply automatically for multi-component images. Explicit
        // array-based MCT or arbitrary wavelet kernels can be exposed later when
        // per-image decorrelation matrices are needed.

        return J2KEncodingConfiguration(
            quality: isLossless ? 1.0 : configuration.quality.value,
            lossless: isLossless,
            decompositionLevels: 0,
            qualityLayers: 1,
            progressionOrder: useRPCL ? .rpcl : .lrcp,
            useHTJ2K: useHTJ2K,
            useReversibleFilter: isLossless
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
        let image: J2KImage
        do {
            image = try Self.awaitJ2KResult {
                try await J2KDecoder().decodeGPU(frameData)
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
        let input = Data(frameData.prefix(expectedBytes))
        let bytesPerSample = descriptor.bytesPerSample
        let componentPixelCount = descriptor.rows * descriptor.columns
        let componentByteCount = componentPixelCount * bytesPerSample

        let colorSpace: J2KColorSpace = descriptor.samplesPerPixel == 1 ? .grayscale : .sRGB
        let components: [J2KComponent]

        switch descriptor.samplesPerPixel {
        case 1:
            let componentData = normalizeEndianForJ2K(input, bytesPerSample: bytesPerSample)
            components = [
                J2KComponent(
                    index: 0,
                    bitDepth: descriptor.bitsStored,
                    signed: descriptor.isSigned,
                    width: descriptor.columns,
                    height: descriptor.rows,
                    data: componentData
                )
            ]

        case 3:
            var planes = [Data(), Data(), Data()]
            planes = planes.map { _ in Data(capacity: componentByteCount) }

            if descriptor.planarConfiguration == 0 {
                let bytesPerPixel = bytesPerSample * 3
                for offset in stride(from: 0, to: min(input.count, componentPixelCount * bytesPerPixel), by: bytesPerPixel) {
                    for componentIndex in 0..<3 {
                        let start = offset + componentIndex * bytesPerSample
                        let end = start + bytesPerSample
                        guard end <= input.count else {
                            throw DICOMError.parsingFailed("RGB frame data ended unexpectedly while building J2K components")
                        }
                        planes[componentIndex].append(contentsOf: normalizeEndianForJ2K(input[start..<end], bytesPerSample: bytesPerSample))
                    }
                }
            } else {
                guard input.count >= componentByteCount * 3 else {
                    throw DICOMError.parsingFailed("Planar RGB frame data too short for JPEG 2000 encoding")
                }

                for componentIndex in 0..<3 {
                    let start = componentIndex * componentByteCount
                    let end = start + componentByteCount
                    planes[componentIndex] = normalizeEndianForJ2K(input[start..<end], bytesPerSample: bytesPerSample)
                }
            }

            components = (0..<3).map { componentIndex in
                J2KComponent(
                    index: componentIndex,
                    bitDepth: descriptor.bitsStored,
                    signed: descriptor.isSigned,
                    width: descriptor.columns,
                    height: descriptor.rows,
                    data: planes[componentIndex]
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

    static func packPixels(from image: J2KImage, descriptor: PixelDataDescriptor) throws -> Data {
        let bytesPerSample = descriptor.bytesPerSample
        let expectedComponentByteCount = descriptor.rows * descriptor.columns * bytesPerSample

        if descriptor.samplesPerPixel == 1 {
            guard let component = image.components.first else {
                throw DICOMError.parsingFailed("Decoded JPEG 2000 image contains no components")
            }

            let normalized = normalizeEndianForDICOM(component.data, bytesPerSample: bytesPerSample)
            guard normalized.count >= expectedComponentByteCount else {
                throw DICOMError.parsingFailed(
                    "Decoded component data too short: expected \(expectedComponentByteCount) bytes, got \(normalized.count)"
                )
            }
            return Data(normalized.prefix(expectedComponentByteCount))
        }

        guard image.components.count == descriptor.samplesPerPixel else {
            throw DICOMError.parsingFailed(
                "Decoded component count \(image.components.count) does not match samples per pixel \(descriptor.samplesPerPixel)"
            )
        }

        let components = try image.components.prefix(descriptor.samplesPerPixel).map { component in
            let normalized = normalizeEndianForDICOM(component.data, bytesPerSample: bytesPerSample)
            guard normalized.count >= expectedComponentByteCount else {
                throw DICOMError.parsingFailed(
                    "Decoded RGB component data too short: expected \(expectedComponentByteCount) bytes, got \(normalized.count)"
                )
            }
            return Data(normalized.prefix(expectedComponentByteCount))
        }

        if descriptor.planarConfiguration == 1 {
            return components.reduce(into: Data(capacity: expectedComponentByteCount * descriptor.samplesPerPixel)) { result, plane in
                result.append(plane)
            }
        }

        var packed = Data(capacity: expectedComponentByteCount * descriptor.samplesPerPixel)
        let pixelCount = descriptor.rows * descriptor.columns
        for pixelIndex in 0..<pixelCount {
            let byteOffset = pixelIndex * bytesPerSample
            for componentData in components {
                let end = byteOffset + bytesPerSample
                packed.append(componentData.subdata(in: byteOffset..<end))
            }
        }
        return packed
    }
    #endif

    static func normalizeEndianForJ2K<S: DataProtocol>(_ bytes: S, bytesPerSample: Int) -> Data {
        guard bytesPerSample == 2 else {
            return Data(bytes)
        }

        var normalized = Data(capacity: bytes.count)
        var iterator = bytes.makeIterator()
        while let low = iterator.next() {
            guard let high = iterator.next() else {
                break
            }
            normalized.append(high)
            normalized.append(low)
        }
        return normalized
    }

    static func normalizeEndianForDICOM(_ data: Data, bytesPerSample: Int) -> Data {
        normalizeEndianForJ2K(data, bytesPerSample: bytesPerSample)
    }
}
