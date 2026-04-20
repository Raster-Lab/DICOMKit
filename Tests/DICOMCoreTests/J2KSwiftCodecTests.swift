import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

@Suite("J2KSwiftCodec Tests")
struct J2KSwiftCodecTests {
    private func localDatasetsRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LocalDatasets/medical-dicom-organized", isDirectory: true)
    }

    private func firstDICOMFile(in relativeDirectory: String) -> URL? {
        let directory = localDatasetsRoot().appendingPathComponent(relativeDirectory, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "dcm" {
            return fileURL
        }

        return nil
    }

    private func loadRealPixelSample(from relativeDirectory: String) throws -> (url: URL, file: DICOMFile, pixelData: PixelData) {
        guard let fileURL = firstDICOMFile(in: relativeDirectory) else {
            throw DICOMError.parsingFailed("No .dcm file found in LocalDatasets/medical-dicom-organized/\(relativeDirectory)")
        }

        let file = try DICOMFile.read(from: fileURL)
        let pixelData = try file.tryPixelData()
        return (fileURL, file, pixelData)
    }
    private func grayscale8Descriptor(rows: Int = 32, columns: Int = 32) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
    }

    private func grayscale16Descriptor(rows: Int = 32, columns: Int = 32) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: 16,
            bitsStored: 16,
            highBit: 15,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
    }

    private func twelveBitDescriptor(rows: Int = 32, columns: Int = 32) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: 16,
            bitsStored: 12,
            highBit: 11,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
    }

    private func rgbDescriptor(rows: Int = 16, columns: Int = 16) -> PixelDataDescriptor {
        PixelDataDescriptor(
            rows: rows,
            columns: columns,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 3,
            photometricInterpretation: .rgb,
            planarConfiguration: 0
        )
    }

    @Test("Supports JPEG 2000 and HTJ2K transfer syntaxes")
    func supportedTransferSyntaxes() {
        #expect(J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid))
        #expect(J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid))
        #expect(J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.htj2kLossless.uid))
        #expect(J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.htj2kRPCLLossless.uid))
        #expect(J2KSwiftCodec.supportedTransferSyntaxes.contains(TransferSyntax.htj2kLossy.uid))
        #expect(J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000Lossless.uid))
        #expect(J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.jpeg2000.uid))
        #expect(J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.htj2kLossless.uid))
        #expect(J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.htj2kRPCLLossless.uid))
        #expect(J2KSwiftCodec.supportedEncodingTransferSyntaxes.contains(TransferSyntax.htj2kLossy.uid))
    }

    @Test("canEncode accepts supported descriptor layouts")
    func canEncodeSupportedLayouts() {
        let codec = J2KSwiftCodec()
        #expect(codec.canEncode(with: .lossless, descriptor: grayscale8Descriptor()))
        #expect(codec.canEncode(with: .lossless, descriptor: grayscale16Descriptor()))
        #expect(codec.canEncode(with: .default, descriptor: rgbDescriptor()))
    }

    @Test("canEncode rejects unsupported descriptor layouts")
    func canEncodeRejectsUnsupportedLayouts() {
        let codec = J2KSwiftCodec()

        let badBitDepth = PixelDataDescriptor(
            rows: 8,
            columns: 8,
            bitsAllocated: 32,
            bitsStored: 32,
            highBit: 31,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )

        let badSamplesPerPixel = PixelDataDescriptor(
            rows: 8,
            columns: 8,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 4,
            photometricInterpretation: .rgb,
            planarConfiguration: 0
        )

        #expect(codec.canEncode(with: .lossless, descriptor: badBitDepth) == false)
        #expect(codec.canEncode(with: .lossless, descriptor: badSamplesPerPixel) == false)
    }

    @Test("CodecRegistry exposes a JPEG 2000 codec and encoder")
    func registryResolvesCodec() {
        let registry = CodecRegistry.shared
        #expect(registry.hasCodec(for: TransferSyntax.jpeg2000Lossless.uid))
        #expect(registry.hasCodec(for: TransferSyntax.jpeg2000.uid))
        #expect(registry.hasEncoder(for: TransferSyntax.jpeg2000Lossless.uid))
        #expect(registry.hasEncoder(for: TransferSyntax.jpeg2000.uid))
    }

    @Test("TransferSyntax helpers recognize Part 2 and HTJ2K families")
    func transferSyntaxHelpersRecognizeExtendedFamilies() {
        #expect(TransferSyntax.jpeg2000Part2Lossless.isJPEG2000)
        #expect(TransferSyntax.jpeg2000Part2Lossless.isJPEG2000Part2)
        #expect(TransferSyntax.htj2kLossless.isJPEG2000)
        #expect(TransferSyntax.htj2kLossless.isHTJ2K)
        #expect(TransferSyntax.htj2kRPCLLossless.isHTJ2K)
        #expect(TransferSyntax.htj2kLossless.isLossless)
        #expect(TransferSyntax.htj2kLossy.isLossless == false)
    }

    @Test("Lossless 8-bit grayscale round-trip preserves payload")
    func lossless8BitRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = grayscale8Descriptor()
        let original = Data((0..<(descriptor.rows * descriptor.columns)).map { UInt8($0 % 251) })

        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
        #if canImport(ImageIO)
        #expect(decoded == original)
        #endif
    }

    @Test("Lossless 16-bit grayscale round-trip preserves payload")
    func lossless16BitRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = grayscale16Descriptor()

        var original = Data(capacity: descriptor.bytesPerFrame)
        for index in 0..<(descriptor.rows * descriptor.columns) {
            let value = UInt16((index * 31) % 4096)
            original.append(UInt8(value & 0x00FF))
            original.append(UInt8((value >> 8) & 0x00FF))
        }

        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
        #if canImport(ImageIO)
        #expect(decoded == original)
        #endif
    }

    @Test("12-bit grayscale in 16-bit container round-trip preserves payload size")
    func twelveBitRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = twelveBitDescriptor()

        var original = Data(capacity: descriptor.bytesPerFrame)
        for index in 0..<(descriptor.rows * descriptor.columns) {
            let value = UInt16((index * 17) % 4096)
            original.append(UInt8(value & 0x00FF))
            original.append(UInt8((value >> 8) & 0x00FF))
        }

        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
    }

    @Test("Lossy grayscale round-trip preserves dimensions")
    func lossyGrayscaleRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = grayscale8Descriptor()
        let original = Data((0..<(descriptor.rows * descriptor.columns)).map { UInt8(($0 * 9) % 251) })

        let config = CompressionConfiguration(quality: .medium, speed: .balanced, progressive: false, preferLossless: false)
        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: config)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
    }

    @Test("Lossless RGB round-trip preserves dimensions")
    func losslessRGBRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = rgbDescriptor()

        var original = Data(capacity: descriptor.bytesPerFrame)
        for y in 0..<descriptor.rows {
            for x in 0..<descriptor.columns {
                original.append(UInt8((x * 13) % 255))
                original.append(UInt8((y * 17) % 255))
                original.append(UInt8(((x + y) * 7) % 255))
            }
        }

        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == original.count)
    }

    @Test("Multi-frame lossless encode returns one fragment per frame")
    func multiFrameLosslessEncodeDecode() throws {
        let codec = J2KSwiftCodec()
        let descriptor = PixelDataDescriptor(
            rows: 16,
            columns: 16,
            numberOfFrames: 3,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )

        var original = Data(capacity: descriptor.bytesPerFrame * descriptor.numberOfFrames)
        for frameIndex in 0..<descriptor.numberOfFrames {
            for pixelIndex in 0..<(descriptor.rows * descriptor.columns) {
                original.append(UInt8((pixelIndex + frameIndex * 23) % 251))
            }
        }

        let frames = try codec.encode(original, descriptor: descriptor, configuration: .lossless)
        #expect(frames.count == descriptor.numberOfFrames)

        for frameIndex in 0..<frames.count {
            let decoded = try codec.decodeFrame(frames[frameIndex], descriptor: descriptor, frameIndex: frameIndex)
            let start = frameIndex * descriptor.bytesPerFrame
            let end = start + descriptor.bytesPerFrame
            #expect(decoded == original.subdata(in: start..<end))
        }
    }

    @Test("Lossy encode works across quality levels")
    func lossyQualityLevelsRoundTrip() throws {
        let codec = J2KSwiftCodec()
        let descriptor = grayscale8Descriptor(rows: 64, columns: 64)
        let original = Data((0..<(descriptor.rows * descriptor.columns)).map { UInt8(($0 * 5) % 251) })

        for quality in [0.25, 0.50, 0.75, 0.95] {
            let configuration = CompressionConfiguration(
                quality: .custom(quality),
                speed: .balanced,
                progressive: false,
                preferLossless: false
            )
            let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: configuration)
            let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

            #expect(encoded.isEmpty == false)
            #expect(decoded.count == original.count)
        }
    }

    @Test("Real LocalDatasets DICOM files parse and expose pixel data")
    func realDatasetFilesParseAndExposePixelData() throws {
        for relativeDirectory in ["mr", "px"] {
            let sample = try loadRealPixelSample(from: relativeDirectory)

            #expect(sample.url.pathExtension.lowercased() == "dcm")
            #expect(sample.file.transferSyntaxUID?.isEmpty == false)
            #expect(sample.pixelData.descriptor.rows > 0)
            #expect(sample.pixelData.descriptor.columns > 0)
            #expect(sample.pixelData.data.isEmpty == false)
        }
    }

    @Test("Real LocalDatasets DICOM pixel data round-trips through J2KSwift")
    func realDatasetRoundTripThroughJ2KSwift() throws {
        let codec = J2KSwiftCodec()
        let sample = try loadRealPixelSample(from: "mr")
        let descriptor = sample.pixelData.descriptor

        #expect(codec.canEncode(with: .lossless, descriptor: descriptor))

        let encoded = try codec.encodeFrame(sample.pixelData.data, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        #expect(decoded.count == sample.pixelData.data.count)
    }

    @Test("HTJ2K lossless and RPCL round-trip preserve payload size")
    func htj2kRoundTripPreservesPayloadSize() throws {
        let sample = try loadRealPixelSample(from: "mr")
        let descriptor = sample.pixelData.descriptor

        let htLosslessCodec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kLossless.uid)
        let htRPCLCodec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kRPCLLossless.uid)

        let htLosslessEncoded = try htLosslessCodec.encodeFrame(sample.pixelData.data, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let htLosslessDecoded = try htLosslessCodec.decodeFrame(htLosslessEncoded, descriptor: descriptor, frameIndex: 0)

        let htRPCLEncoded = try htRPCLCodec.encodeFrame(sample.pixelData.data, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let htRPCLDecoded = try htRPCLCodec.decodeFrame(htRPCLEncoded, descriptor: descriptor, frameIndex: 0)

        #expect(htLosslessEncoded.isEmpty == false)
        #expect(htRPCLEncoded.isEmpty == false)
        #expect(htLosslessDecoded.count == sample.pixelData.data.count)
        #expect(htRPCLDecoded.count == sample.pixelData.data.count)
    }

    @Test("Decoding empty data throws")
    func decodingEmptyDataThrows() {
        let codec = J2KSwiftCodec()
        #expect(throws: DICOMError.self) {
            try codec.decodeFrame(Data(), descriptor: grayscale8Descriptor(), frameIndex: 0)
        }
    }
}
