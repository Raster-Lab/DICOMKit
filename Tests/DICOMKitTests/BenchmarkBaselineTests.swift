import XCTest
import Foundation
@testable import DICOMKit
import DICOMCore

/// M1 benchmark baseline runner (RESEARCH_ADOPTION_PLAN.md M1; instructions §18).
///
/// Skipped unless `DICOM_BENCHMARK_BASELINE=1` — it is a measurement harness, not
/// a pass/fail test. Run in RELEASE:
///
///     DICOM_BENCHMARK_BASELINE=1 swift test -c release --filter BenchmarkBaselineTests
///
/// Results (per-iteration samples, median/P90/P95, true high-water resident
/// memory, cold start) are written to `Tests/Benchmarks/Artifacts/` as JSON with
/// an environment manifest. Synthetic instances are deterministic (seeded), so
/// runs are comparable across commits on the same host. Corpus files
/// (`Tests/DICOMRoundTripTest/Corpus/*.dcm`), when present locally, are measured
/// too but never committed.
final class BenchmarkBaselineTests: XCTestCase {

    // MARK: - Synthetic instance builders (deterministic)

    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func el(_ tag: Tag, _ vr: VR, _ value: Data) -> DataElement {
        var v = value
        if v.count % 2 != 0 { v.append(vr == .UI ? 0x00 : 0x20) }
        return DataElement(tag: tag, vr: vr, length: UInt32(v.count), valueData: v, byteOrder: .littleEndian)
    }

    private func us(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8(v >> 8)]) }

    /// Deterministic 16-bit pixels: smooth gradient + noise (realistic entropy).
    private func syntheticPixels(rows: Int, cols: Int, frames: Int, seed: UInt64) -> Data {
        var rng = SplitMix64(state: seed)
        var out = Data(capacity: rows * cols * frames * 2)
        for f in 0..<frames {
            for r in 0..<rows {
                for c in 0..<cols {
                    let base = UInt16((r + c + f * 7) & 0x0FFF)
                    let noise = UInt16(truncatingIfNeeded: rng.next()) & 0x00FF
                    let value = base &+ noise
                    out.append(UInt8(value & 0xFF))
                    out.append(UInt8(value >> 8))
                }
            }
        }
        return out
    }

    /// Builds a Part 10 Explicit VR LE file with the given geometry.
    private func syntheticFile(rows: Int, cols: Int, frames: Int, seed: UInt64) -> Data {
        var elements: [DataElement] = [
            el(Tag(group: 0x0008, element: 0x0016), .UI, Data("1.2.840.10008.5.1.4.1.1.2".utf8)),
            el(Tag(group: 0x0008, element: 0x0018), .UI, Data("1.2.826.0.1.3680043.9.7433.1.\(seed)".utf8)),
            el(Tag(group: 0x0008, element: 0x0060), .CS, Data("CT".utf8)),
            el(Tag(group: 0x0010, element: 0x0010), .PN, Data("Benchmark^Baseline".utf8)),
            el(Tag(group: 0x0020, element: 0x000D), .UI, Data("1.2.826.0.1.3680043.9.7433.2.\(seed)".utf8)),
            el(Tag(group: 0x0020, element: 0x000E), .UI, Data("1.2.826.0.1.3680043.9.7433.3.\(seed)".utf8)),
            el(Tag(group: 0x0028, element: 0x0002), .US, us(1)),
            el(Tag(group: 0x0028, element: 0x0004), .CS, Data("MONOCHROME2".utf8)),
        ]
        if frames > 1 {
            elements.append(el(Tag(group: 0x0028, element: 0x0008), .IS, Data("\(frames)".utf8)))
        }
        elements.append(contentsOf: [
            el(Tag(group: 0x0028, element: 0x0010), .US, us(UInt16(rows))),
            el(Tag(group: 0x0028, element: 0x0011), .US, us(UInt16(cols))),
            el(Tag(group: 0x0028, element: 0x0100), .US, us(16)),
            el(Tag(group: 0x0028, element: 0x0101), .US, us(16)),
            el(Tag(group: 0x0028, element: 0x0102), .US, us(15)),
            el(Tag(group: 0x0028, element: 0x0103), .US, us(0)),
        ])
        let pixels = syntheticPixels(rows: rows, cols: cols, frames: frames, seed: seed)
        elements.append(el(Tag(group: 0x7FE0, element: 0x0010), .OW, pixels))

        let meta = DataSet(elements: [
            el(Tag(group: 0x0002, element: 0x0010), .UI, Data("1.2.840.10008.1.2.1".utf8)),
        ])
        let file = DICOMFile(fileMetaInformation: meta, dataSet: DataSet(elements: elements))
        return try! file.write()
    }

    // MARK: - Artifact model

    private struct Stats: Codable {
        let iterations: Int
        let coldMs: Double?
        let medianMs: Double
        let p90Ms: Double
        let p95Ms: Double
        let minMs: Double
        let maxMs: Double
        let meanMs: Double
        let stddevMs: Double?
        let baselineResidentMB: Double?
        let peakResidentMB: Double?
        let samplesMs: [Double]

        init(_ r: BenchmarkResult) {
            iterations = r.iterations
            coldMs = r.coldDuration.map { $0 * 1000 }
            medianMs = (r.medianDuration ?? 0) * 1000
            p90Ms = (r.percentile(90) ?? 0) * 1000
            p95Ms = (r.percentile(95) ?? 0) * 1000
            minMs = (r.minDuration ?? 0) * 1000
            maxMs = (r.maxDuration ?? 0) * 1000
            meanMs = r.averageDuration * 1000
            stddevMs = r.standardDeviation.map { $0 * 1000 }
            baselineResidentMB = r.baselineResidentBytes.map { Double($0) / 1048576 }
            peakResidentMB = r.peakResidentBytes.map { Double($0) / 1048576 }
            samplesMs = r.samples.map { $0 * 1000 }
        }
    }

    private struct Artifact: Codable {
        struct Environment: Codable {
            let date: String
            let os: String
            let hardwareModel: String
            let cpuCores: Int
            let buildConfiguration: String
            let gitCommit: String
            let note: String
        }
        let schema: String
        let environment: Environment
        var instances: [String: [String: String]]
        var results: [String: Stats]
    }

    private func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    // MARK: - Runner

    func testRecordBenchmarkBaseline() throws {
        guard ProcessInfo.processInfo.environment["DICOM_BENCHMARK_BASELINE"] == "1" else {
            throw XCTSkip("Set DICOM_BENCHMARK_BASELINE=1 (release build) to record a baseline")
        }

        #if DEBUG
        let configuration = "debug (NOT valid for baseline claims)"
        #else
        let configuration = "release"
        #endif

        // --- Instances ---------------------------------------------------
        let ctData = syntheticFile(rows: 512, cols: 512, frames: 1, seed: 0xC7)
        let multiData = syntheticFile(rows: 256, cols: 256, frames: 40, seed: 0x40)
        let rleData = try CompressionManager().compressData(multiData, codec: "rle", quality: nil)

        var instances: [String: [String: String]] = [
            "ct-synthetic": ["description": "512x512x1 16-bit MONOCHROME2 Explicit VR LE (seed 0xC7)",
                             "bytes": "\(ctData.count)"],
            "multiframe-rle-synthetic": ["description": "256x256x40 16-bit RLE encapsulated (seed 0x40, C09-class)",
                                         "bytes": "\(rleData.count)",
                                         "uncompressedBytes": "\(multiData.count)"],
        ]

        var results: [String: Stats] = [:]
        func record(_ key: String, _ result: BenchmarkResult) {
            results[key] = Stats(result)
            let median = String(format: "%.3f", (result.medianDuration ?? 0) * 1000)
            let p95 = String(format: "%.3f", (result.percentile(95) ?? 0) * 1000)
            print("BASELINE \(key): median \(median) ms, p95 \(p95) ms")
        }

        // --- §18.1 Parsing ------------------------------------------------
        record("ct.parse.full", DICOMBenchmark.measureDetailed(
            name: "ct.parse.full", iterations: 20, warmup: 3, recordCold: true) {
            try! DICOMFile.read(from: ctData)
        })
        record("ct.parse.metadataOnly", DICOMBenchmark.measureDetailed(
            name: "ct.parse.metadataOnly", iterations: 20, warmup: 3) {
            try! DICOMFile.read(from: ctData, options: .metadataOnly)
        })
        record("ct.parse.stopAfterPatientName", DICOMBenchmark.measureDetailed(
            name: "ct.parse.stopAfterPatientName", iterations: 20, warmup: 3) {
            try! DICOMFile.read(from: ctData,
                                options: ParsingOptions(stopAfterTag: Tag(group: 0x0010, element: 0x0010)))
        })
        let parsedCT = try DICOMFile.read(from: ctData)
        record("ct.access.selectedValues-100x", DICOMBenchmark.measureDetailed(
            name: "ct.access.selectedValues-100x", iterations: 20, warmup: 3, trackMemory: false) {
            for _ in 0..<100 {
                _ = parsedCT.dataSet.string(for: Tag(group: 0x0010, element: 0x0010))
                _ = parsedCT.dataSet.string(for: Tag(group: 0x0008, element: 0x0060))
            }
        })
        record("multiframe-rle.parse.full", DICOMBenchmark.measureDetailed(
            name: "multiframe-rle.parse.full", iterations: 15, warmup: 3, recordCold: true) {
            try! DICOMFile.read(from: rleData)
        })

        // --- §18.2 Pixel access -------------------------------------------
        record("ct.pixel.decodeAll", DICOMBenchmark.measureDetailed(
            name: "ct.pixel.decodeAll", iterations: 15, warmup: 2) {
            _ = try! parsedCT.pixelData()
        })
        let parsedMulti = try DICOMFile.read(from: rleData)
        record("multiframe-rle.pixel.decodeAll", DICOMBenchmark.measureDetailed(
            name: "multiframe-rle.pixel.decodeAll", iterations: 8, warmup: 1) {
            _ = try! parsedMulti.pixelData()
        })
        // Today's selected-frame cost: the API decodes ALL frames, then slices
        // one. This is the number M2's pixelData(frame:) must beat.
        record("multiframe-rle.pixel.selectedFrame20-currentPath", DICOMBenchmark.measureDetailed(
            name: "multiframe-rle.pixel.selectedFrame20-currentPath", iterations: 8, warmup: 1) {
            let pd = try! parsedMulti.pixelData()!
            _ = try! pd.frameData(at: 20)
        })
        // M2 selected-frame API: decodes only frame 20's fragments.
        record("multiframe-rle.pixel.selectedFrame20-newPath", DICOMBenchmark.measureDetailed(
            name: "multiframe-rle.pixel.selectedFrame20-newPath", iterations: 20, warmup: 2) {
            _ = try! parsedMulti.pixelData(frame: 20)
        })
        // M4 bounded-parallel decode of all frames (byte-budgeted task window).
        var parallelSamples: [TimeInterval] = []
        for _ in 0..<10 {
            let start = DispatchTime.now().uptimeNanoseconds
            let exp = expectation(description: "parallel")
            Task {
                _ = try! await parsedMulti.pixelDataParallel()
                exp.fulfill()
            }
            wait(for: [exp], timeout: 60)
            parallelSamples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
        }
        record("multiframe-rle.pixel.decodeAll-parallel", BenchmarkResult(
            name: "multiframe-rle.pixel.decodeAll-parallel",
            duration: parallelSamples.reduce(0, +),
            iterations: parallelSamples.count,
            samples: parallelSamples))
        // M3 caller-owned + page-aligned: GPU-ready output, no realign copy.
        record("multiframe-rle.pixel.selectedFrame20-aligned", DICOMBenchmark.measureDetailed(
            name: "multiframe-rle.pixel.selectedFrame20-aligned", iterations: 20, warmup: 2) {
            _ = try! parsedMulti.alignedPixelData(frame: 20)
        })

        // --- Optional local corpus files ----------------------------------
        let corpusDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("DICOMRoundTripTest/Corpus")
        for name in ["CT.dcm", "MR.dcm", "US.dcm", "j2klossless.dcm", "CT_Multiframe"] {
            let url = corpusDir.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else { continue }
            instances["corpus-\(name)"] = ["description": "local corpus file (uncommitted)",
                                           "bytes": "\(data.count)"]
            record("corpus-\(name).parse.full", DICOMBenchmark.measureDetailed(
                name: "corpus-\(name).parse.full", iterations: 10, warmup: 2, recordCold: true) {
                try? DICOMFile.read(from: data)
            })
            if let parsed = try? DICOMFile.read(from: data) {
                record("corpus-\(name).pixel.decodeAll", DICOMBenchmark.measureDetailed(
                    name: "corpus-\(name).pixel.decodeAll", iterations: 5, warmup: 1) {
                    _ = try? parsed.pixelData()
                })
            }
        }

        // --- Artifact ------------------------------------------------------
        let iso = ISO8601DateFormatter().string(from: Date())
        let artifact = Artifact(
            schema: "dicomkit-benchmark-baseline/1",
            environment: .init(
                date: iso,
                os: ProcessInfo.processInfo.operatingSystemVersionString,
                hardwareModel: hardwareModel(),
                cpuCores: ProcessInfo.processInfo.activeProcessorCount,
                buildConfiguration: configuration,
                gitCommit: ProcessInfo.processInfo.environment["DICOM_BENCHMARK_COMMIT"] ?? "unspecified",
                note: "Synthetic instances are deterministic (seeded); corpus entries are local-only files."
            ),
            instances: instances,
            results: results
        )

        let artifactsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Benchmarks/Artifacts")
        try FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(artifact)
        let stamp = iso.replacingOccurrences(of: ":", with: "-")
        let out = artifactsDir.appendingPathComponent("baseline-\(stamp).json")
        try json.write(to: out)
        try json.write(to: artifactsDir.appendingPathComponent("baseline-latest.json"))
        print("BASELINE artifact written: \(out.path)")
    }
}
