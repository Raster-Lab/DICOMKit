import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

#if canImport(Darwin)
@preconcurrency import Darwin
#endif

@Suite("J2KSwiftCodec Benchmark Tests", .serialized)
struct J2KSwiftCodecBenchmarkTests {
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

    private func realSampleForBenchmark() throws -> (url: URL, file: DICOMFile, pixelData: PixelData) {
        guard let fileURL = firstDICOMFile(in: "mr") ?? firstDICOMFile(in: "px") else {
            throw DICOMError.parsingFailed("No .dcm file found under LocalDatasets/medical-dicom-organized")
        }

        let file = try DICOMFile.read(from: fileURL)
        let pixelData = try file.tryPixelData()
        return (fileURL, file, pixelData)
    }

    private func grayscale8Descriptor(rows: Int = 512, columns: Int = 512) -> PixelDataDescriptor {
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

    private func grayscale16Descriptor(rows: Int = 512, columns: Int = 512) -> PixelDataDescriptor {
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

    private func measure(iterations: Int, operation: () throws -> Void) rethrows -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            try operation()
        }
        let end = CFAbsoluteTimeGetCurrent()
        return ((end - start) * 1000.0) / Double(iterations)
    }

    private func currentMemoryUsageBytes() -> Int64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
        #else
        return 0
        #endif
    }

    @Test("Benchmark J2KSwift decode against NativeJPEG2000Codec")
    func benchmarkDecodeComparison() throws {
        #if canImport(ImageIO)
        let sample = try realSampleForBenchmark()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data
        let codec = J2KSwiftCodec()
        let nativeCodec = NativeJPEG2000Codec()

        let j2kEncoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        _ = try codec.decodeFrame(j2kEncoded, descriptor: descriptor, frameIndex: 0)

        let j2kDecodeMs = try measure(iterations: 10) {
            _ = try codec.decodeFrame(j2kEncoded, descriptor: descriptor, frameIndex: 0)
        }
        let j2kDecodeString = String(format: "%.3f", j2kDecodeMs)

        do {
            let nativeEncoded = try nativeCodec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
            _ = try nativeCodec.decodeFrame(nativeEncoded, descriptor: descriptor, frameIndex: 0)

            let nativeDecodeMs = try measure(iterations: 10) {
                _ = try nativeCodec.decodeFrame(nativeEncoded, descriptor: descriptor, frameIndex: 0)
            }
            let nativeDecodeString = String(format: "%.3f", nativeDecodeMs)
            print("J2K real-file decode benchmark: sample=\(sample.url.lastPathComponent), J2KSwift=\(j2kDecodeString) ms, ImageIO=\(nativeDecodeString) ms")
            #expect(nativeDecodeMs > 0)
        } catch {
            print("J2K real-file decode benchmark: sample=\(sample.url.lastPathComponent), J2KSwift=\(j2kDecodeString) ms; ImageIO comparison unavailable: \(error)")
        }

        #expect(j2kDecodeMs > 0)
        #endif
    }

    @Test("Benchmark HTJ2K against legacy J2K on a real DICOM sample")
    func benchmarkHTJ2KVersusLegacyJ2K() throws {
        let sample = try realSampleForBenchmark()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data

        let legacyCodec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.jpeg2000Lossless.uid)
        let htj2kCodec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kLossless.uid)

        let legacyEncoded = try legacyCodec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let htEncoded = try htj2kCodec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)

        let legacyDecodeMs = try measure(iterations: 3) {
            _ = try legacyCodec.decodeFrame(legacyEncoded, descriptor: descriptor, frameIndex: 0)
        }
        let htDecodeMs = try measure(iterations: 3) {
            _ = try htj2kCodec.decodeFrame(htEncoded, descriptor: descriptor, frameIndex: 0)
        }

        let legacyString = String(format: "%.3f", legacyDecodeMs)
        let htString = String(format: "%.3f", htDecodeMs)
        let speedupString = String(format: "%.3f", legacyDecodeMs / max(htDecodeMs, 0.001))
        print("HTJ2K benchmark: sample=\(sample.url.lastPathComponent), legacy=\(legacyString) ms, htj2k=\(htString) ms, speedup=\(speedupString)x")

        #expect(legacyDecodeMs > 0)
        #expect(htDecodeMs > 0)
    }

    @Test("Benchmark J2KSwift large-frame memory usage")
    func benchmarkMemoryUsage() throws {
        let sample = try realSampleForBenchmark()
        let descriptor = sample.pixelData.descriptor
        let original = sample.pixelData.data
        let codec = J2KSwiftCodec()

        let baselineMemory = currentMemoryUsageBytes()
        let averageEncodeMs = try measure(iterations: 3) {
            _ = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        }
        let encoded = try codec.encodeFrame(original, descriptor: descriptor, frameIndex: 0, configuration: .lossless)
        let averageDecodeMs = try measure(iterations: 3) {
            _ = try codec.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
        }
        let finalMemory = currentMemoryUsageBytes()
        let memoryDeltaMB = Double(max(0, finalMemory - baselineMemory)) / (1024.0 * 1024.0)

        let encodeString = String(format: "%.3f", averageEncodeMs)
        let decodeString = String(format: "%.3f", averageDecodeMs)
        let memoryString = String(format: "%.3f", memoryDeltaMB)
        print("J2K real-file memory benchmark: sample=\(sample.url.lastPathComponent), encode=\(encodeString) ms, decode=\(decodeString) ms, RSS delta=\(memoryString) MB")

        #expect(averageEncodeMs > 0)
        #expect(averageDecodeMs > 0)
        #expect(memoryDeltaMB >= 0)
    }
}
