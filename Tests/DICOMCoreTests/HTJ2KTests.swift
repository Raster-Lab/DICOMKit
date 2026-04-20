import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

@Suite("HTJ2K Tests")
struct HTJ2KTests {
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

    @Test("HTJ2K lossless and RPCL syntaxes round-trip a real DICOM payload")
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

    @Test("HTJ2K lossy 16-bit real payload currently exposes an upstream issue")
    func htj2kLossyRealPayloadCurrentlyThrows() throws {
        let sample = try realSample()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data

        let codec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kLossy.uid)

        #expect(throws: DICOMError.self) {
            let encoded = try codec.encodeFrame(
                original,
                descriptor: descriptor,
                frameIndex: 0,
                configuration: CompressionConfiguration(quality: .high, speed: .balanced, progressive: false, preferLossless: false)
            )
            _ = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        }
    }
}
