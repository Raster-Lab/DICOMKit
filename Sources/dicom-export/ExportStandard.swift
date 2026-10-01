// NEMA-verified: 2026a, checked 2026-10-01 — the DICOM inputs dicom-export reads: the cine rate attributes of the Cine Module, PS3.3 2026a Table C.7-13 (Recommended Display Frame Rate (0008,2144), Cine Rate (0018,0040), Frame Time (0018,1063) in msec, C.7.6.5.1.1; 3 rows, names and tags match PS3.6 Table 6-1), Burned In Annotation (0028,0301) Enumerated Values YES / NO of PS3.3 Table C.7-9 / C.7.6.1; the frame render goes through DICOMImageExporter.renderFrameForExport (PS3.4 N.2 chain, verified in DICOMKit)
import Foundation
import DICOMCore
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The frame rate of an `animate` export.
///
/// Without `--fps` the rate comes from the file's Cine Module (PS3.3 Table C.7-13):
/// Recommended Display Frame Rate (0008,2144) — "Recommended rate at which the Frames
/// of a Multi-frame Image should be displayed in Frames/second" — first,
/// then Cine Rate (0018,0040) — "Number of Frames per second" — then Frame Time (0018,1063),
/// the nominal time in msec between Frames (C.7.6.5.1.1), as 1000 / Frame Time.
/// A file with none of them is exported at ``fallbackFPS``. Frame Time Vector
/// (0018,1065) (variable frame timing) is not used.
struct CineFrameRate: Equatable {
    /// The rate used when neither `--fps` nor the file gives one.
    static let fallbackFPS: Double = 10

    enum Source: Equatable {
        case option
        case recommendedDisplayFrameRate
        case cineRate
        case frameTime
        case fallback

        /// The PS3.6 name and tag of the attribute the rate came from.
        var label: String {
            switch self {
            case .option: return "--fps"
            case .recommendedDisplayFrameRate: return "Recommended Display Frame Rate (0008,2144)"
            case .cineRate: return "Cine Rate (0018,0040)"
            case .frameTime: return "Frame Time (0018,1063)"
            case .fallback: return "default"
            }
        }
    }

    let fps: Double
    let source: Source

    static func resolve(explicit: Double?, dataSet: DataSet) -> CineFrameRate {
        if let explicit { return CineFrameRate(fps: explicit, source: .option) }
        if let rate = positiveNumber(dataSet.string(for: .recommendedDisplayFrameRate)) {
            return CineFrameRate(fps: rate, source: .recommendedDisplayFrameRate)
        }
        if let rate = positiveNumber(dataSet.string(for: .cineRate)) {
            return CineFrameRate(fps: rate, source: .cineRate)
        }
        if let msec = positiveNumber(dataSet.string(for: .frameTime)) {
            return CineFrameRate(fps: 1000.0 / msec, source: .frameTime)
        }
        return CineFrameRate(fps: fallbackFPS, source: .fallback)
    }

    private static func positiveNumber(_ raw: String?) -> Double? {
        guard let raw, let value = Double(raw.trimmingCharacters(in: .whitespaces)),
              value.isFinite, value > 0 else { return nil }
        return value
    }
}

/// Burned In Annotation (0028,0301), PS3.3 Table C.7-9: "Indicates whether or not image
/// contains sufficient burned in annotation to identify the patient and date the image
/// was acquired." Enumerated Values YES, NO; absent means it may or may not.
/// A rendered PNG/JPEG/TIFF/GIF keeps that text in its pixels, so the export warns.
enum BurnedInAnnotation {
    static func isYes(_ dataSet: DataSet) -> Bool {
        dataSet.string(for: .burnedInAnnotation)?
            .trimmingCharacters(in: .whitespaces).uppercased() == "YES"
    }

    static func warning(for path: String) -> String {
        "warning: \(path): Burned In Annotation (0028,0301) is YES — the exported image "
            + "contains burned-in text that identifies the patient"
    }

    static func summaryWarning(count: Int) -> String {
        "warning: \(count) exported image(s) have Burned In Annotation (0028,0301) YES — "
            + "burned-in text that identifies the patient"
    }

    static func printWarning(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}

#if canImport(CoreGraphics)
/// The one frame-render decision for every `dicom-export` subcommand: the shared
/// DICOMImageExporter.renderFrameForExport (the PS3.4 N.2 grayscale chain — Modality
/// LUT or rescale, then the VOI in modality units, then INVERSE for MONOCHROME1).
/// `contact-sheet` and `animate` used other DICOMFile render paths before.
enum ExportFrames {
    static func render(
        file: DICOMFile, pixelData: PixelData? = nil, frameIndex: Int,
        applyWindow: Bool, windowCenter: Double?, windowWidth: Double?
    ) throws -> CGImage {
        guard let pixelData = pixelData ?? file.pixelData() else { throw ExportError.noPixelData }
        return try DICOMImageExporter.renderFrameForExport(
            file: file, pixelData: pixelData, frameIndex: frameIndex,
            applyWindow: applyWindow, windowCenter: windowCenter, windowWidth: windowWidth)
    }
}
#endif
