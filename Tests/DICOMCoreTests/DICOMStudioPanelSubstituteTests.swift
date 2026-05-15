import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

#if os(macOS)
/// Driver that calls the same public DICOMCore primitives the DICOM Studio J2K
/// Compare panel uses (`J2KSwiftCodec.benchEncode` / `benchDecode` +
/// `KakaduCLICodec.decodeFrame`) with identical warmup=2 / runs=7 median-of-7
/// methodology, but without launching the SwiftUI app. The output is the
/// "DICOM Studio business-logic substitute" lane referenced in
/// J2KSwift/Documentation/Benchmarks/J2KSWIFT_OPTIMAL_VS_KAKADU.md.
@Suite("DICOM Studio panel substitute — multi-mode Lane B driver", .serialized)
struct DICOMStudioPanelSubstituteTests {

    private struct ModalityCase {
        let modality: String
        let relativePath: String
    }

    private let cases: [ModalityCase] = [
        .init(modality: "CT", relativePath: "ct/study_001/instance_000001.dcm"),
        .init(modality: "DX", relativePath: "dx/study_001/instance_000001.dcm"),
        .init(modality: "MG", relativePath: "mg/study_001/instance_000001.dcm"),
        .init(modality: "MR", relativePath: "mr/study_003/instance_000001.dcm"),
        .init(modality: "PX", relativePath: "px/study_003/instance_000001.dcm"),
        .init(modality: "XA", relativePath: "xa/study_001/instance_000001.dcm")
    ]

    private let decodeModes: [J2KSwiftDecodeMode] = [.cpu, .decodeGPU, .decodeWithGPUHT]

    private func sampleStudiesRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SampleStudies", isDirectory: true)
    }

    private func fmt(_ ms: Double?) -> String {
        guard let ms else { return "fail" }
        return String(format: "%.2f", ms)
    }

    private func fmtRatio(_ j2k: Double?, kak: Double) -> String {
        guard let j2k, kak > 0 else { return "n/a" }
        return String(format: "%.2fx", j2k / kak)
    }

    private func kakaduTimed(
        _ codestream: Data,
        descriptor: PixelDataDescriptor,
        warmups: Int = 2,
        runs: Int = 7
    ) -> Double? {
        let kak = KakaduCLICodec()
        do {
            for _ in 0..<warmups { _ = try kak.decodeFrame(codestream, descriptor: descriptor) }
            var samples: [Double] = []
            samples.reserveCapacity(runs)
            for _ in 0..<runs {
                let t0 = DispatchTime.now()
                _ = try kak.decodeFrame(codestream, descriptor: descriptor)
                samples.append(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000.0)
            }
            samples.sort()
            return samples[samples.count / 2]
        } catch {
            return nil
        }
    }

    @Test("DICOM Studio Lane-B substitute: 6 modalities x 4 decode modes")
    func runStudioSubstitute() throws {
        guard KakaduCLICodec.binaryPath != nil else {
            print("SKIP: kdu_expand not found on PATH")
            return
        }
        guard FileManager.default.fileExists(atPath: sampleStudiesRoot().path) else {
            print("SKIP: SampleStudies/ not present in repo (developer-only fixtures); skipping multi-mode driver.")
            return
        }

        struct ResultRow {
            let modality: String
            let file: String
            let dim: String
            let bits: Int
            let codestreamBytes: Int
            let encodeMs: Double?
            let decodeMs: [J2KSwiftDecodeMode: Double?]
            let autoRoute: String
            let kakaduMs: Double?
        }

        var rows: [ResultRow] = []

        for c in cases {
            let url = sampleStudiesRoot().appendingPathComponent(c.relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("MISSING: \(c.relativePath)")
                continue
            }
            let file = try DICOMFile.read(from: url)
            let pixelData = try file.tryPixelData()
            guard let frame0 = pixelData.frameData(at: 0) else {
                print("MISSING frame0: \(c.relativePath)")
                continue
            }
            let descriptor = pixelData.descriptor

            let encConfig = CompressionConfiguration(
                quality: .maximum,
                speed: .balanced,
                progressive: false,
                preferLossless: true
            )
            let encResult = J2KSwiftCodec.benchEncode(
                frame0,
                descriptor: descriptor,
                transferSyntaxUID: TransferSyntax.htj2kLossless.uid,
                configuration: encConfig,
                mode: .cpu,
                warmups: 2,
                runs: 7
            )
            guard let codestream = encResult.data, !encResult.samples.isEmpty else {
                print("ENCODE FAIL \(c.modality): \(encResult.error ?? "unknown")")
                continue
            }
            let sortedEnc = encResult.samples.sorted()
            let encodeMs = sortedEnc[sortedEnc.count / 2]

            var decode: [J2KSwiftDecodeMode: Double?] = [:]
            for mode in decodeModes {
                let r = J2KSwiftCodec.benchDecode(
                    codestream,
                    descriptor: descriptor,
                    mode: mode,
                    warmups: 2,
                    runs: 7
                )
                if r.data != nil, !r.samples.isEmpty {
                    let s = r.samples.sorted()
                    decode[mode] = s[s.count / 2]
                } else {
                    decode[mode] = nil
                }
            }

            // The viewer's production decode path is plain CPU `decode` in
            // this PR; per-mode timings above show what each explicit API costs.
            let autoRoute = "CPU"

            let kakaduMs = kakaduTimed(codestream, descriptor: descriptor)

            rows.append(ResultRow(
                modality: c.modality,
                file: url.lastPathComponent,
                dim: "\(descriptor.columns)x\(descriptor.rows)",
                bits: descriptor.bitsStored,
                codestreamBytes: codestream.count,
                encodeMs: encodeMs,
                decodeMs: decode,
                autoRoute: autoRoute,
                kakaduMs: kakaduMs
            ))
        }

        print("")
        print("=== DICOM-STUDIO-LANE-B-SUBSTITUTE BEGIN ===")
        print("Transfer syntax: 1.2.840.10008.1.2.4.201 (HT-J2K Lossless)")
        print("Encode: J2KSwiftEncodeMode.cpu, warmups=2 runs=7 (median of 7)")
        print("Decode J2KSwift: same warmups=2 runs=7 per mode (median of 7)")
        print("Decode Kakadu: kdu_expand subprocess, warmups=2 runs=7 (median of 7)")
        print("Kakadu version: \(KakaduCLICodec.version)")
        print("")

        let header = "| Modality | File | Dim | Bits | Codestream | Encode ms | Viewer-route | dec .cpu | dec .decodeGPU | dec .decodeWithGPUHT | Kakadu dec | .cpu/Kak | .decGPU/Kak | .decGPUHT/Kak |"
        let sep    = "|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        print(header)
        print(sep)
        for row in rows {
            let cs = String(format: "%.1f KB", Double(row.codestreamBytes) / 1024.0)
            let kak = row.kakaduMs ?? 0
            let line = "| \(row.modality) | \(row.file) | \(row.dim) | \(row.bits) | \(cs) | \(fmt(row.encodeMs)) | \(row.autoRoute) | \(fmt(row.decodeMs[.cpu] ?? nil)) | \(fmt(row.decodeMs[.decodeGPU] ?? nil)) | \(fmt(row.decodeMs[.decodeWithGPUHT] ?? nil)) | \(fmt(row.kakaduMs)) | \(fmtRatio(row.decodeMs[.cpu] ?? nil, kak: kak)) | \(fmtRatio(row.decodeMs[.decodeGPU] ?? nil, kak: kak)) | \(fmtRatio(row.decodeMs[.decodeWithGPUHT] ?? nil, kak: kak)) |"
            print(line)
        }
        print("=== DICOM-STUDIO-LANE-B-SUBSTITUTE END ===")
        print("")

        #expect(rows.count >= 1)
    }
}
#endif
