import Foundation
import Testing
@testable import DICOMCore
@testable import DICOMKit

/// Reproduces the J2KSwift compression report on the same 10 representative
/// DICOM files used for the J2KSwift Lossless table, but adds a side-by-side
/// HTJ2K (Part-15) lossless column. Both columns are produced by the same
/// `J2KSwiftCodec`, varying only the encoding transfer syntax UID.
@Suite("J2K vs HTJ2K Lossless Compression Report", .serialized)
struct J2KvsHTJ2KCompressionReportTests {

    private struct SampleSpec {
        let modality: String
        let study: String
        let instanceFile: String
        var label: String {
            let trimmed = instanceFile
                .replacingOccurrences(of: "instance_000", with: "instance_")
                .replacingOccurrences(of: ".dcm", with: "")
            return "\(modality)/\(study)/\(trimmed)"
        }
    }

    private let samples: [SampleSpec] = [
        .init(modality: "ct", study: "study_001", instanceFile: "instance_000001.dcm"),
        .init(modality: "ct", study: "study_003", instanceFile: "instance_000050.dcm"),
        .init(modality: "dx", study: "study_001", instanceFile: "instance_000001.dcm"),
        .init(modality: "dx", study: "study_002", instanceFile: "instance_000001.dcm"),
        .init(modality: "mg", study: "study_001", instanceFile: "instance_000001.dcm"),
        .init(modality: "mg", study: "study_002", instanceFile: "instance_000001.dcm"),
        .init(modality: "mr", study: "study_001", instanceFile: "instance_000001.dcm"),
        .init(modality: "mr", study: "study_002", instanceFile: "instance_000100.dcm"),
        .init(modality: "px", study: "study_001", instanceFile: "instance_000001.dcm"),
        .init(modality: "xa", study: "study_001", instanceFile: "instance_000001.dcm")
    ]

    private func localDatasetsRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("LocalDatasets/medical-dicom-organized", isDirectory: true)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = 1024.0
        let mb = kb * 1024.0
        let b = Double(bytes)
        if b >= mb { return String(format: "%.2f MB", b / mb) }
        if b >= kb { return String(format: "%.1f KB", b / kb) }
        return "\(bytes) B"
    }

    private func pad(_ s: String, _ width: Int) -> String {
        if s.count >= width { return s }
        return s + String(repeating: " ", count: width - s.count)
    }

    @Test("Report J2K vs HTJ2K Lossless sizes on the 10 reference DICOM files")
    func reportJ2KvsHTJ2KOnReferenceSet() throws {
        let j2kCodec   = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.jpeg2000Lossless.uid)
        let htj2kCodec = J2KSwiftCodec(encodingTransferSyntaxUID: TransferSyntax.htj2kLossless.uid)

        struct Row {
            let idx: Int
            let label: String
            let modality: String
            let dim: String
            let dicomBytes: Int
            let j2kBytes: Int
            let htj2kBytes: Int
        }

        var rows: [Row] = []
        var totalDICOM = 0, totalJ2K = 0, totalHTJ2K = 0

        for (i, spec) in samples.enumerated() {
            let url = localDatasetsRoot()
                .appendingPathComponent(spec.modality)
                .appendingPathComponent(spec.study)
                .appendingPathComponent(spec.instanceFile)

            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let dicomBytes = (attrs[.size] as? NSNumber)?.intValue ?? 0

            let file = try DICOMFile.read(from: url)
            let pixelData = try file.tryPixelData()
            let descriptor = pixelData.descriptor
            let original = pixelData.data

            let j2kEncoded   = try j2kCodec.encodeFrame(original, descriptor: descriptor,
                                                       frameIndex: 0, configuration: .lossless)
            let htj2kEncoded = try htj2kCodec.encodeFrame(original, descriptor: descriptor,
                                                          frameIndex: 0, configuration: .lossless)

            let dim = "\(descriptor.columns)×\(descriptor.rows)"
            rows.append(Row(idx: i + 1, label: spec.label, modality: spec.modality.uppercased(),
                            dim: dim, dicomBytes: dicomBytes,
                            j2kBytes: j2kEncoded.count, htj2kBytes: htj2kEncoded.count))
            totalDICOM += dicomBytes
            totalJ2K   += j2kEncoded.count
            totalHTJ2K += htj2kEncoded.count
        }

        let wIdx = 3, wFile = 32, wMod = 9, wDim = 12, wSize = 14
        var output = "\n"
        output += "J2K vs HTJ2K Lossless Compression Report (J2KSwift)\n"
        let separator = String(repeating: "-",
                               count: wIdx + wFile + wMod + wDim + wSize * 3 + 6)
        output += separator + "\n"
        output += pad("#", wIdx) + " "
              + pad("File", wFile) + " "
              + pad("Modality", wMod) + " "
              + pad("Dim", wDim) + " "
              + pad("DICOM (in)", wSize) + " "
              + pad("J2K Lossless", wSize) + " "
              + pad("HTJ2K Lossless", wSize) + "\n"
        output += separator + "\n"
        for r in rows {
            output += pad("\(r.idx)", wIdx) + " "
                  + pad(r.label, wFile) + " "
                  + pad(r.modality, wMod) + " "
                  + pad(r.dim, wDim) + " "
                  + pad(formatBytes(r.dicomBytes), wSize) + " "
                  + pad(formatBytes(r.j2kBytes), wSize) + " "
                  + pad(formatBytes(r.htj2kBytes), wSize) + "\n"
        }
        output += separator + "\n"
        output += pad("", wIdx) + " "
              + pad("Total", wFile) + " "
              + pad("", wMod) + " "
              + pad("", wDim) + " "
              + pad(formatBytes(totalDICOM), wSize) + " "
              + pad(formatBytes(totalJ2K), wSize) + " "
              + pad(formatBytes(totalHTJ2K), wSize) + "\n"
        let j2kRatio   = Double(totalDICOM) / Double(max(totalJ2K, 1))
        let htj2kRatio = Double(totalDICOM) / Double(max(totalHTJ2K, 1))
        output += String(format: "Aggregate ratio (DICOM ÷ encoded):  J2K = %.2fx,  HTJ2K = %.2fx\n",
                         j2kRatio, htj2kRatio)
        output += String(format: "HTJ2K vs J2K size delta:            %+.2f%% (negative = HTJ2K smaller)\n",
                         (Double(totalHTJ2K) - Double(totalJ2K)) / Double(totalJ2K) * 100.0)
        print(output)

        #expect(rows.count == samples.count)
        #expect(totalJ2K > 0)
        #expect(totalHTJ2K > 0)
    }
}
