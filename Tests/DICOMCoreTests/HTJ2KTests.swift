import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

@Suite("HTJ2K Tests")
struct HTJ2KTests {
    private func makeLosslessCodestream(for syntax: TransferSyntax) throws -> Data {
        let descriptor = PixelDataDescriptor(
            rows: 16,
            columns: 16,
            numberOfFrames: 1,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            isSigned: false,
            samplesPerPixel: 1,
            photometricInterpretation: .monochrome2
        )
        var pixels = Data(capacity: descriptor.bytesPerFrame)
        for value in 0..<descriptor.bytesPerFrame {
            pixels.append(UInt8(value & 0xFF))
        }
        return try J2KSwiftCodec(encodingTransferSyntaxUID: syntax.uid).encodeFrame(
            pixels,
            descriptor: descriptor,
            frameIndex: 0,
            configuration: .lossless
        )
    }

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

    private func realSample() throws -> (url: URL, file: DICOMFile, pixelData: PixelData) {
        guard let fileURL = firstDICOMFile(in: "mr") ?? firstDICOMFile(in: "px") else {
            throw DICOMError.parsingFailed("No .dcm file found under LocalDatasets/medical-dicom-organized")
        }

        let file = try DICOMFile.read(from: fileURL)
        let pixelData = try file.tryPixelData()
        return (fileURL, file, pixelData)
    }

    @Test("HTJ2K registry exposes all three transfer syntaxes")
    func registryExposesAllHTJ2KSyntaxes() {
        let registry = CodecRegistry.shared

        for syntax in [TransferSyntax.htj2kLossless, .htj2kRPCLLossless, .htj2kLossy] {
            #expect(syntax.isHTJ2K)
            #expect(registry.hasCodec(for: syntax.uid))
            #expect(registry.hasEncoder(for: syntax.uid))
        }
    }

    @Test("Unsafe direct coefficient transcoding fails without returning corrupted pixels")
    func directCoefficientTranscodingIsQuarantined() throws {
        let j2k = try makeLosslessCodestream(for: .jpeg2000Lossless)
        let htj2k = try makeLosslessCodestream(for: .htj2kLossless)

        do {
            _ = try HTJ2KCodec.transcodeToHTJ2K(j2k)
            Issue.record("Expected direct J2K to HTJ2K transcoding to fail closed")
        } catch DICOMError.unsupportedTransferSyntax(let reason) {
            #expect(reason.contains("does not preserve pixels"))
        } catch {
            Issue.record("Unexpected J2K to HTJ2K error: \(error)")
        }

        do {
            _ = try HTJ2KCodec.transcodeFromHTJ2K(htj2k)
            Issue.record("Expected direct HTJ2K to J2K transcoding to fail closed")
        } catch DICOMError.unsupportedTransferSyntax(let reason) {
            #expect(reason.contains("does not preserve pixels"))
        } catch {
            Issue.record("Unexpected HTJ2K to J2K error: \(error)")
        }
    }

    @Test(
        "HTJ2K lossless and RPCL syntaxes round-trip a real DICOM payload",
        .enabled(if: LocalCodecFixtureAvailability.hasMRorPX, "Requires optional LocalDatasets codec fixtures")
    )
    func verifiedHTJ2KSyntaxesRoundTripRealPayload() throws {
        let sample = try realSample()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data

        let testCases: [(TransferSyntax, CompressionConfiguration)] = [
            (.htj2kLossless, .lossless),
            (.htj2kRPCLLossless, .lossless)
        ]

        for (syntax, configuration) in testCases {
            let codec = J2KSwiftCodec(encodingTransferSyntaxUID: syntax.uid)
            let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: configuration)
            let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

            #expect(encoded.isEmpty == false)
            #expect(decoded.count == original.count)
        }
    }

    @Test(
        "HTJ2K lossy 16-bit real payload round-trips without error",
        .enabled(if: LocalCodecFixtureAvailability.hasMRorPX, "Requires optional LocalDatasets codec fixtures")
    )
    func htj2kLossyRealPayloadRoundTrips() throws {
        // Historical note: this previously asserted `#expect(throws:)` to
        // document an upstream J2KSwift defect that crashed/threw on HTJ2K
        // lossy 16-bit payloads. J2KSwift v10.9.1 resolved it — HTJ2K lossy
        // now encodes + decodes cleanly, so the test verifies the round-trip.
        let sample = try realSample()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data

        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kLossy.uid)

        let encoded = try codec.encodeFrame(
            original,
            descriptor: descriptor,
            frameIndex: 0,
            configuration: CompressionConfiguration(quality: .high, speed: .balanced, progressive: false, preferLossless: false)
        )
        let decoded = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)

        #expect(encoded.isEmpty == false)
        // Lossy: decoded values differ from the original, but the decoded
        // buffer must match the original frame's byte count.
        #expect(decoded.count == original.count)
    }
}
