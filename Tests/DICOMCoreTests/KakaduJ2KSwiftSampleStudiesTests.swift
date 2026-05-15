import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

#if os(macOS)
@Suite("Kakadu vs J2KSwift SampleStudies Cross Codec", .serialized)
struct KakaduJ2KSwiftSampleStudiesTests {
    private struct SampleCase {
        let relativePath: String
        let label: String
        /// Decode mode for the J2KSwift row. Default `.cpu` matches the
        /// methodology of J2KSwift's published `CROSS_HOST_*_inproc.md`
        /// benchmark reports. Specific fixtures may pin GPU modes to
        /// measure those code paths explicitly.
        let decodeMode: J2KSwiftDecodeMode

        init(relativePath: String, label: String, decodeMode: J2KSwiftDecodeMode = .cpu) {
            self.relativePath = relativePath
            self.label = label
            self.decodeMode = decodeMode
        }
    }

    private let samples: [SampleCase] = [
        // Small fixtures — CPU `decode` is the natural pick.
        .init(relativePath: "ct/study_001/instance_000001.dcm", label: "CT-001"),
        .init(relativePath: "ct/study_001/instance_000002.dcm", label: "CT-002"),
        .init(relativePath: "ct/study_001/instance_000003.dcm", label: "CT-003"),
        .init(relativePath: "ct/study_001/instance_000004.dcm", label: "CT-004"),
        .init(relativePath: "ct/study_001/instance_000005.dcm", label: "CT-005"),
        .init(relativePath: "ct/study_001/instance_000006.dcm", label: "CT-006"),
        .init(relativePath: "ct/study_001/instance_000007.dcm", label: "CT-007"),
        .init(relativePath: "ct/study_001/instance_000008.dcm", label: "CT-008"),
        .init(relativePath: "ct/study_001/instance_000009.dcm", label: "CT-009"),
        .init(relativePath: "ct/study_001/instance_000010.dcm", label: "CT-010"),
        .init(relativePath: "mr/study_003/instance_000001.dcm", label: "MR-001"),
        .init(relativePath: "mr/study_003/instance_000002.dcm", label: "MR-002"),
        .init(relativePath: "mr/study_003/instance_000003.dcm", label: "MR-003"),
        .init(relativePath: "mr/study_003/instance_000004.dcm", label: "MR-004"),
        .init(relativePath: "mr/study_003/instance_000005.dcm", label: "MR-005"),
        // Mid-band fixtures — exercise `decodeGPU` (CPU HT entropy + GPU IDWT).
        .init(relativePath: "xa/study_001/instance_000001.dcm", label: "XA-001", decodeMode: .decodeGPU),
        .init(relativePath: "xa/study_001/instance_000002.dcm", label: "XA-002", decodeMode: .decodeGPU),
        .init(relativePath: "px/study_003/instance_000001.dcm", label: "PX-001", decodeMode: .decodeGPU),
        .init(relativePath: "dx/study_001/instance_000001.dcm", label: "DX-001", decodeMode: .decodeGPU),
        .init(relativePath: "dx/study_001/instance_000002.dcm", label: "DX-002", decodeMode: .decodeGPU),
        // Large-fixture GPU path — both `decodeGPU` and full `decodeWithGPUHT`
        // to surface the difference between the two GPU pipelines on MG sizes.
        .init(relativePath: "mg/study_001/instance_000001.dcm", label: "MG-001", decodeMode: .decodeGPU),
        .init(relativePath: "mg/study_001/instance_000002.dcm", label: "MG-002", decodeMode: .decodeGPU),
        .init(relativePath: "dx/study_001/instance_000001.dcm", label: "DX-001-HT", decodeMode: .decodeWithGPUHT),
        .init(relativePath: "dx/study_001/instance_000002.dcm", label: "DX-002-HT", decodeMode: .decodeWithGPUHT),
        .init(relativePath: "mg/study_001/instance_000001.dcm", label: "MG-001-HT", decodeMode: .decodeWithGPUHT),
        .init(relativePath: "mg/study_001/instance_000002.dcm", label: "MG-002-HT", decodeMode: .decodeWithGPUHT)
    ]

    /// 2 untimed warmups + 7 timed runs; returns the median of the 7.
    private func benchKakadu(_ codestream: Data, descriptor: PixelDataDescriptor,
                             decoder: KakaduCLICodec) throws -> Double {
        for _ in 0..<2 { _ = try decoder.decodeFrame(codestream, descriptor: descriptor) }
        var samples: [Double] = []
        samples.reserveCapacity(7)
        for _ in 0..<7 {
            let t0 = DispatchTime.now()
            _ = try decoder.decodeFrame(codestream, descriptor: descriptor)
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000.0)
        }
        samples.sort()
        return samples[3]
    }

    private func median(_ samples: [Double]) -> Double {
        let sorted = samples.sorted()
        return sorted[sorted.count / 2]
    }

    private func sampleStudiesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SampleStudies", isDirectory: true)
    }

    private func loadSample(_ sample: SampleCase) throws -> (url: URL, pixelData: PixelData, frame: Data) {
        let url = sampleStudiesRoot().appendingPathComponent(sample.relativePath)
        let file = try DICOMFile.read(from: url)
        let pixelData = try file.tryPixelData()
        guard let frame = pixelData.frameData(at: 0) else {
            throw DICOMError.parsingFailed("SampleStudies frame 0 unavailable for \(sample.relativePath)")
        }
        return (url, pixelData, frame)
    }

    private func firstMismatchOffset(_ lhs: Data, _ rhs: Data) -> Int? {
        let count = min(lhs.count, rhs.count)
        for offset in 0..<count where lhs[lhs.startIndex + offset] != rhs[rhs.startIndex + offset] {
            return offset
        }
        return lhs.count == rhs.count ? nil : count
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let value = Double(bytes)
        if value >= mb { return String(format: "%.2f MB", value / mb) }
        if value >= kb { return String(format: "%.1f KB", value / kb) }
        return "\(bytes) B"
    }

    private func pad(_ value: String, _ width: Int) -> String {
        value.count >= width ? value : value + String(repeating: " ", count: width - value.count)
    }

    private func formatMS(_ ms: Double) -> String {
        String(format: "%.2f ms", ms)
    }

    private func formatThroughput(bytes: Int, milliseconds: Double) -> String {
        guard milliseconds > 0 else { return "n/a" }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        let seconds = milliseconds / 1000.0
        return String(format: "%.1f MB/s", mb / seconds)
    }

    private func timed<T>(_ operation: () throws -> T) rethrows -> (value: T, milliseconds: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        let value = try operation()
        return (value, (CFAbsoluteTimeGetCurrent() - start) * 1000.0)
    }

    @Test("Kakadu decodes J2KSwift lossless codestreams from SampleStudies exactly")
    func kakaduMatchesJ2KSwiftOnRealSampleStudiesFrames() throws {
        guard KakaduCLICodec.binaryPath != nil else {
            print("SKIP: kdu_expand not found on PATH or standard install locations")
            return
        }
        guard FileManager.default.fileExists(atPath: sampleStudiesRoot().path) else {
            print("SKIP: SampleStudies/ not present in repo (developer-only fixtures); skipping cross-codec lane.")
            return
        }

        let kakaduDecoder = KakaduCLICodec()

        struct ResultRow {
            let label: String
            let file: String
            let dimensions: String
            let bits: Int
            let route: String
            let rawBytes: Int
            let codestreamBytes: Int
            let encodeMS: Double
            let j2kSwiftDecodeMS: Double
            let kakaduDecodeMS: Double
        }

        var rows: [ResultRow] = []
        var totalRawBytes = 0
        var totalCodestreamBytes = 0
        var totalEncodeMS = 0.0
        var totalJ2KSwiftDecodeMS = 0.0
        var totalKakaduDecodeMS = 0.0

        for sample in samples {
            let loaded = try loadSample(sample)
            let descriptor = loaded.pixelData.descriptor
            let original = loaded.frame

            #expect(descriptor.samplesPerPixel == 1, "\(sample.relativePath) must be grayscale for KakaduCLICodec")
            #expect(descriptor.bitsAllocated == 8 || descriptor.bitsAllocated == 16,
                    "\(sample.relativePath) must use 8- or 16-bit samples")

            // Encode: 2 warmups + 7 timed, median of 7. Reuses one J2KEncoder
            // across all iterations (matches InProcBench.swift / J2K Compare panel).
            let encodeResult = J2KSwiftCodec.benchEncode(
                original,
                descriptor: descriptor,
                transferSyntaxUID: TransferSyntax.jpeg2000Lossless.uid,
                configuration: .lossless,
                mode: .cpu,
                warmups: 2, runs: 7
            )
            guard let codestream = encodeResult.data, !encodeResult.samples.isEmpty else {
                Issue.record("\(sample.label) encode failed: \(encodeResult.error ?? "no samples")")
                continue
            }
            let encodeMS = median(encodeResult.samples)

            // J2KSwift decode: same methodology, mode pinned per fixture
            // (CPU for small images; decodeGPU / decodeWithGPUHT for mid/large).
            let j2kDecodeResult = J2KSwiftCodec.benchDecode(
                codestream,
                descriptor: descriptor,
                mode: sample.decodeMode,
                warmups: 2, runs: 7
            )
            guard let j2kSwiftDecoded = j2kDecodeResult.data, !j2kDecodeResult.samples.isEmpty else {
                Issue.record("\(sample.label) J2KSwift decode failed: \(j2kDecodeResult.error ?? "no samples")")
                continue
            }
            let j2kSwiftDecodeMS = median(j2kDecodeResult.samples)

            // Kakadu decode: same methodology. Each call spawns a process so
            // "warmup" amortises page-cache + dyld loader, but not much else.
            let kakaduDecodeMS = try benchKakadu(codestream, descriptor: descriptor, decoder: kakaduDecoder)
            let kakaduDecoded = try kakaduDecoder.decodeFrame(codestream, descriptor: descriptor)

            let j2kMismatch = firstMismatchOffset(j2kSwiftDecoded, original)
            let kakaduMismatch = firstMismatchOffset(kakaduDecoded, original)
            let crossMismatch = firstMismatchOffset(kakaduDecoded, j2kSwiftDecoded)

            #expect(codestream.isEmpty == false)
            #expect(j2kSwiftDecoded == original,
                    "J2KSwift decoded bytes differ from source at offset \(j2kMismatch.map(String.init) ?? "none")")
            #expect(kakaduDecoded == original,
                    "Kakadu decoded bytes differ from source at offset \(kakaduMismatch.map(String.init) ?? "none")")
            #expect(kakaduDecoded == j2kSwiftDecoded,
                    "Kakadu and J2KSwift decoded bytes differ at offset \(crossMismatch.map(String.init) ?? "none")")

            // Route label: short string showing the API the J2KSwift row used.
            let routeLabel: String = {
                switch sample.decodeMode {
                case .cpu:              return "CPU"
                case .decodeGPU:        return "decodeGPU"
                case .decodeWithGPUHT:  return "decodeWithGPUHT"
                }
            }()
            rows.append(ResultRow(
                label: sample.label,
                file: loaded.url.lastPathComponent,
                dimensions: "\(descriptor.columns)x\(descriptor.rows)",
                bits: descriptor.bitsStored,
                route: routeLabel,
                rawBytes: original.count,
                codestreamBytes: codestream.count,
                encodeMS: encodeMS,
                j2kSwiftDecodeMS: j2kSwiftDecodeMS,
                kakaduDecodeMS: kakaduDecodeMS
            ))
            totalRawBytes += original.count
            totalCodestreamBytes += codestream.count
            totalEncodeMS += encodeMS
            totalJ2KSwiftDecodeMS += j2kSwiftDecodeMS
            totalKakaduDecodeMS += kakaduDecodeMS
        }

        let ratio = Double(totalRawBytes) / Double(max(totalCodestreamBytes, 1))
        let decodeSpeedup = totalJ2KSwiftDecodeMS / max(totalKakaduDecodeMS, 0.001)
        let separator = String(repeating: "-", count: 170)
        let table = rows.map { row in
            pad(row.label, 8)
                + " "
                + pad(row.file, 22)
                + " "
                + pad(row.dimensions, 10)
                + " "
                + pad("\(row.bits)-bit", 8)
                + " "
                + pad(row.route, 24)
                + " "
                + pad(formatBytes(row.rawBytes), 12)
                + " "
                + pad(formatBytes(row.codestreamBytes), 12)
                + " "
                + pad(String(format: "%.2fx", Double(row.rawBytes) / Double(max(row.codestreamBytes, 1))), 7)
                + " "
                + pad(formatMS(row.encodeMS), 11)
                + " "
                + pad(formatThroughput(bytes: row.rawBytes, milliseconds: row.encodeMS), 11)
                + " "
                + pad(formatMS(row.j2kSwiftDecodeMS), 12)
                + " "
                + pad(formatMS(row.kakaduDecodeMS), 12)
                + " "
                + String(format: "%.2fx", row.j2kSwiftDecodeMS / max(row.kakaduDecodeMS, 0.001))
        }.joined(separator: "\n")

        let routeCounts = Dictionary(grouping: rows, by: \.route)
            .map { "\($0.value.count)×\($0.key)" }
            .sorted()
            .joined(separator: ", ")

        let report = """

        Kakadu vs J2KSwift SampleStudies cross-codec check
          Kakadu: \(KakaduCLICodec.version)
          J2KSwift: per `Package.resolved` (URL dep, `from: 5.21.0`)
          Samples: \(rows.count)
          Methodology: 2 untimed warmups + 7 timed runs, median of 7 (DispatchTime ns clock)
          J2KSwift encode mode: CPU (single reused J2KEncoder per fixture)
          J2KSwift decode mode: per-sample (explicit); routes exercised: \(routeCounts)
        \(separator)
        \(pad("Label", 8)) \(pad("File", 22)) \(pad("Dim", 10)) \(pad("Bits", 8)) \(pad("Route", 24)) \(pad("Raw", 12)) \(pad("J2K", 12)) \(pad("Ratio", 7)) \(pad("Enc", 11)) \(pad("Enc MB/s", 11)) \(pad("J2K Dec", 12)) \(pad("Kak Dec", 12)) Kak/J2K
        \(separator)
        \(table)
        \(separator)
        \(pad("Total", 8)) \(pad("", 22)) \(pad("", 10)) \(pad("", 8)) \(pad("", 24)) \(pad(formatBytes(totalRawBytes), 12)) \(pad(formatBytes(totalCodestreamBytes), 12)) \(pad(String(format: "%.2fx", ratio), 7)) \(pad(formatMS(totalEncodeMS), 11)) \(pad(formatThroughput(bytes: totalRawBytes, milliseconds: totalEncodeMS), 11)) \(pad(formatMS(totalJ2KSwiftDecodeMS), 12)) \(pad(formatMS(totalKakaduDecodeMS), 12)) \(String(format: "%.2fx", decodeSpeedup))
        """
        print(report)

        #expect(rows.count >= 26)
        #expect(rows.count == samples.count)
        // Sanity: corpus must span all three explicit decode paths.
        let distinctRoutes = Set(rows.map(\.route))
        #expect(distinctRoutes.contains("CPU"))
        #expect(distinctRoutes.contains("decodeGPU"))
        #expect(distinctRoutes.contains("decodeWithGPUHT"))
    }
}
#endif
