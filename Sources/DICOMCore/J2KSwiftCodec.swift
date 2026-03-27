import Foundation
import J2KCore
import J2KCodec

/// JPEG 2000 codec backed by J2KSwift (pure-Swift, cross-platform).
///
/// Replaces the Apple ImageIO-based `NativeJPEG2000Codec` with a portable
/// implementation that works on macOS, iOS, visionOS, and Linux.
///
/// Supports JPEG 2000 lossless (1.2.840.10008.1.2.4.90) and lossy
/// (1.2.840.10008.1.2.4.91) transfer syntaxes.
///
/// Reference: DICOM PS3.5 Section A.4.4
public struct J2KSwiftCodec: ImageCodec, ImageEncoder, Sendable {

    // MARK: - Supported Transfer Syntaxes

    /// Supported JPEG 2000 transfer syntaxes for decoding
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.jpeg2000Lossless.uid,  // 1.2.840.10008.1.2.4.90
        TransferSyntax.jpeg2000.uid           // 1.2.840.10008.1.2.4.91
    ]

    /// Supported JPEG 2000 transfer syntaxes for encoding
    public static let supportedEncodingTransferSyntaxes: [String] = [
        TransferSyntax.jpeg2000Lossless.uid,  // 1.2.840.10008.1.2.4.90
        TransferSyntax.jpeg2000.uid           // 1.2.840.10008.1.2.4.91
    ]

    public init() {}

    // MARK: - Decoding

    /// Decodes a JPEG 2000–compressed frame using J2KSwift.
    ///
    /// - Parameters:
    ///   - frameData: JPEG 2000 compressed data (J2K codestream or JP2).
    ///   - descriptor: Pixel data descriptor for the DICOM image.
    ///   - frameIndex: Frame index (unused for single-frame decode).
    /// - Returns: Uncompressed pixel data in DICOM native byte layout.
    /// - Throws: ``DICOMError`` if decoding fails.
    public func decodeFrame(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        frameIndex: Int
    ) throws -> Data {
        guard !frameData.isEmpty else {
            throw DICOMError.parsingFailed("Empty JPEG 2000 data")
        }

        let decoder = J2KDecoder()
        let j2kImage: J2KImage
        do {
            j2kImage = try decoder.decode(frameData)
        } catch {
            throw DICOMError.parsingFailed("J2KSwift decoding failed: \(error)")
        }

        return try extractPixelData(from: j2kImage, descriptor: descriptor)
    }

    // MARK: - Encoding

    /// Whether this encoder supports the given configuration and descriptor.
    public func canEncode(
        with configuration: CompressionConfiguration,
        descriptor: PixelDataDescriptor
    ) -> Bool {
        // Support 8-bit and 16-bit samples
        guard descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16 else {
            return false
        }
        // Support grayscale (1) and RGB (3)
        guard descriptor.samplesPerPixel == 1 || descriptor.samplesPerPixel == 3 else {
            return false
        }
        return true
    }

    /// Encodes a single frame to JPEG 2000 format using J2KSwift.
    ///
    /// - Parameters:
    ///   - frameData: Uncompressed frame data.
    ///   - descriptor: Pixel data descriptor.
    ///   - frameIndex: Zero-based frame index.
    ///   - configuration: Compression configuration.
    /// - Returns: JPEG 2000 compressed frame data.
    /// - Throws: ``DICOMError`` if encoding fails.
    public func encodeFrame(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        frameIndex: Int,
        configuration: CompressionConfiguration
    ) throws -> Data {
        let j2kImage = try buildJ2KImage(from: frameData, descriptor: descriptor)
        let encodingConfig = mapConfiguration(configuration, descriptor: descriptor)
        let encoder = J2KEncoder(encodingConfiguration: encodingConfig)

        do {
            return try encoder.encode(j2kImage)
        } catch {
            throw DICOMError.parsingFailed("J2KSwift encoding failed: \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Extracts raw pixel data from a decoded ``J2KImage`` into DICOM byte layout.
    private func extractPixelData(
        from image: J2KImage,
        descriptor: PixelDataDescriptor
    ) throws -> Data {
        let samplesPerPixel = descriptor.samplesPerPixel
        let expectedComponents = samplesPerPixel

        guard image.components.count >= expectedComponents else {
            throw DICOMError.parsingFailed(
                "Decoded image has \(image.components.count) components, expected \(expectedComponents)"
            )
        }

        let width = descriptor.columns
        let height = descriptor.rows
        let bytesPerSample = descriptor.bytesPerSample
        let pixelCount = width * height

        if samplesPerPixel == 1 {
            // Grayscale: single component
            return extractComponentData(
                image.components[0],
                width: width,
                height: height,
                bytesPerSample: bytesPerSample,
                isSigned: descriptor.isSigned
            )
        } else {
            // Interleaved color (RGB): pixel-by-pixel R1G1B1R2G2B2...
            let totalBytes = pixelCount * samplesPerPixel * bytesPerSample
            var output = Data(count: totalBytes)

            let components = (0..<samplesPerPixel).map { image.components[$0] }

            output.withUnsafeMutableBytes { outPtr in
                guard let base = outPtr.baseAddress else { return }
                for pixelIndex in 0..<pixelCount {
                    for sampleIndex in 0..<samplesPerPixel {
                        let value = readComponentPixel(
                            components[sampleIndex],
                            at: pixelIndex,
                            bytesPerSample: bytesPerSample
                        )
                        let offset = (pixelIndex * samplesPerPixel + sampleIndex) * bytesPerSample
                        writePixelValue(value, to: base + offset, bytesPerSample: bytesPerSample)
                    }
                }
            }
            return output
        }
    }

    /// Extracts a single component's data into a contiguous byte buffer.
    private func extractComponentData(
        _ component: J2KComponent,
        width: Int,
        height: Int,
        bytesPerSample: Int,
        isSigned: Bool
    ) -> Data {
        let pixelCount = width * height
        let totalBytes = pixelCount * bytesPerSample
        var output = Data(count: totalBytes)

        output.withUnsafeMutableBytes { outPtr in
            guard let base = outPtr.baseAddress else { return }
            for i in 0..<pixelCount {
                let value = readComponentPixel(component, at: i, bytesPerSample: bytesPerSample)
                writePixelValue(value, to: base + i * bytesPerSample, bytesPerSample: bytesPerSample)
            }
        }
        return output
    }

    /// Reads a single pixel value from a ``J2KComponent`` at the given flat index.
    private func readComponentPixel(
        _ component: J2KComponent,
        at index: Int,
        bytesPerSample: Int
    ) -> Int {
        let componentData = component.data
        let offset = index * bytesPerSample
        guard offset + bytesPerSample <= componentData.count else { return 0 }

        if bytesPerSample == 1 {
            return Int(componentData[componentData.startIndex + offset])
        } else {
            // Little-endian 16-bit
            let low = Int(componentData[componentData.startIndex + offset])
            let high = Int(componentData[componentData.startIndex + offset + 1])
            return low | (high << 8)
        }
    }

    /// Writes a pixel value into a raw buffer at the given pointer.
    private func writePixelValue(_ value: Int, to pointer: UnsafeMutableRawPointer, bytesPerSample: Int) {
        if bytesPerSample == 1 {
            pointer.storeBytes(of: UInt8(truncatingIfNeeded: value), as: UInt8.self)
        } else {
            // Little-endian 16-bit
            pointer.storeBytes(of: UInt16(truncatingIfNeeded: value), as: UInt16.self)
        }
    }

    /// Constructs a ``J2KImage`` from raw DICOM pixel data.
    private func buildJ2KImage(
        from data: Data,
        descriptor: PixelDataDescriptor
    ) throws -> J2KImage {
        let width = descriptor.columns
        let height = descriptor.rows
        let samplesPerPixel = descriptor.samplesPerPixel
        let bytesPerSample = descriptor.bytesPerSample
        let bitDepth = descriptor.bitsStored
        let isSigned = descriptor.isSigned
        let pixelCount = width * height

        let expectedBytes = pixelCount * samplesPerPixel * bytesPerSample
        guard data.count >= expectedBytes else {
            throw DICOMError.parsingFailed(
                "Pixel data too short: got \(data.count) bytes, expected \(expectedBytes)"
            )
        }

        // Build per-component data
        var components: [J2KComponent] = []
        for sampleIndex in 0..<samplesPerPixel {
            var componentData = Data(count: pixelCount * bytesPerSample)
            componentData.withUnsafeMutableBytes { outPtr in
                guard let outBase = outPtr.baseAddress else { return }
                data.withUnsafeBytes { inPtr in
                    guard let inBase = inPtr.baseAddress else { return }
                    for pixelIndex in 0..<pixelCount {
                        let srcOffset = (pixelIndex * samplesPerPixel + sampleIndex) * bytesPerSample
                        let dstOffset = pixelIndex * bytesPerSample
                        (outBase + dstOffset).copyMemory(
                            from: inBase + srcOffset,
                            byteCount: bytesPerSample
                        )
                    }
                }
            }

            components.append(J2KComponent(
                index: sampleIndex,
                bitDepth: bitDepth,
                signed: isSigned,
                width: width,
                height: height,
                data: componentData
            ))
        }

        let colorSpace: J2KColorSpace = samplesPerPixel == 1 ? .grayscale : .sRGB

        return J2KImage(
            width: width,
            height: height,
            components: components,
            colorSpace: colorSpace
        )
    }

    /// Maps DICOMKit's ``CompressionConfiguration`` to J2KSwift's ``J2KEncodingConfiguration``.
    private func mapConfiguration(
        _ config: CompressionConfiguration,
        descriptor: PixelDataDescriptor
    ) -> J2KEncodingConfiguration {
        let isLossless = config.preferLossless || config.quality.isLossless
        let quality = isLossless ? 1.0 : config.quality.value

        // Map speed preset to encoding preset behavior
        let decompositionLevels: Int
        let codeBlockSize: (width: Int, height: Int)
        let qualityLayers: Int

        switch config.speed {
        case .fast:
            decompositionLevels = 3
            codeBlockSize = (width: 64, height: 64)
            qualityLayers = 3
        case .balanced:
            decompositionLevels = 5
            codeBlockSize = (width: 32, height: 32)
            qualityLayers = 5
        case .optimal:
            decompositionLevels = 6
            codeBlockSize = (width: 32, height: 32)
            qualityLayers = 10
        }

        return J2KEncodingConfiguration(
            quality: quality,
            lossless: isLossless,
            decompositionLevels: decompositionLevels,
            codeBlockSize: codeBlockSize,
            qualityLayers: qualityLayers,
            progressionOrder: config.progressive ? .rpcl : .lrcp,
            enableVisualWeighting: !isLossless
        )
    }
}
