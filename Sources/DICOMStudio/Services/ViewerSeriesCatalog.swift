// ViewerSeriesCatalog.swift
// DICOMStudio
//
// DICOM Studio — building the viewer's series pane from the library.
//
// Entries are built from library metadata alone, so opening a study never waits
// on disk. Orientation is the one thing the library does not index; it is read
// from one file per series afterwards and folded in, which is why a card can
// briefly say "Orientation Unavailable" and then settle.

import Foundation
import DICOMCore
import DICOMKit

public enum ViewerSeriesCatalog {

    /// The series of a study, in series-number order, ready for the pane.
    public static func entries(
        forStudy studyUID: String,
        in library: LibraryModel
    ) -> [ViewerSeriesEntry] {
        library.seriesForStudy(studyUID).map { series in
            entry(for: series, in: library)
        }
        .sorted(by: isOrderedBefore)
    }

    /// Series-number order: ascending, unnumbered series last.
    ///
    /// The library's own ordering treats a missing Series Number as 0, which
    /// files unnumbered series *ahead* of series 1. Ties and missing numbers
    /// fall back to title then UID so the pane cannot reshuffle between two
    /// reads of the same study.
    static func isOrderedBefore(_ lhs: ViewerSeriesEntry, _ rhs: ViewerSeriesEntry) -> Bool {
        switch (lhs.seriesNumber, rhs.seriesNumber) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            break
        }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.seriesInstanceUID < rhs.seriesInstanceUID
    }

    private static func entry(
        for series: SeriesModel,
        in library: LibraryModel
    ) -> ViewerSeriesEntry {
        let instances = library.instancesForSeries(series.seriesInstanceUID)
        return ViewerSeriesEntry(
            seriesInstanceUID: series.seriesInstanceUID,
            title: title(for: series),
            seriesNumber: series.seriesNumber,
            modality: series.modality,
            orientation: nil,
            filePaths: instances.map(\.filePath),
            // A multi-frame series has more frames than objects; the pane
            // states both because a 1-object, 358-frame cine and a
            // 358-object stack read very differently.
            frameCount: instances.reduce(0) { $0 + ($1.numberOfFrames ?? 1) },
            // The first instance decides: a series is one SOP Class in
            // practice, and reading every instance to confirm it would make
            // opening a study proportional to its object count.
            contentKind: ViewerContentKind.kind(forSOPClassUID: instances.first?.sopClassUID)
        )
    }

    /// The study a file belongs to, so the viewer can find its own pane contents.
    public static func studyUID(containing filePath: String, in library: LibraryModel) -> String? {
        guard let instance = library.instances.values.first(where: { $0.filePath == filePath })
        else { return nil }
        return library.series[instance.seriesInstanceUID]?.studyInstanceUID
    }

    /// Re-reads orientation for each entry, one file per series.
    ///
    /// Off the main actor and after the pane is already on screen: orientation
    /// is a nicety, and blocking a study open on N file reads is not.
    public static func resolvingOrientations(
        _ entries: [ViewerSeriesEntry]
    ) async -> [ViewerSeriesEntry] {
        await Task.detached(priority: .utility) { () -> [ViewerSeriesEntry] in
            entries.map { entry in
                guard let path = entry.firstFilePath,
                      let orientation = readOrientation(atPath: path) else { return entry }
                return ViewerSeriesEntry(
                    seriesInstanceUID: entry.seriesInstanceUID,
                    title: entry.title,
                    seriesNumber: entry.seriesNumber,
                    modality: entry.modality,
                    orientation: orientation,
                    filePaths: entry.filePaths,
                    frameCount: entry.frameCount)
            }
        }.value
    }

    // MARK: - Helpers

    /// Series Description, falling back to something a reader can still use.
    private static func title(for series: SeriesModel) -> String {
        let description = series.seriesDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !description.isEmpty { return description }
        if let number = series.seriesNumber {
            return "\(series.modality) series \(number)"
        }
        return series.modality
    }

    /// "Axial", "Coronal" or "Sagittal" from Image Orientation (Patient).
    ///
    /// Returns `nil` for oblique acquisitions rather than rounding them to the
    /// nearest plane — calling an oblique series "Axial" would be a clinical
    /// falsehood, and no label is better than a wrong one.
    static func readOrientation(atPath path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let file = try? DICOMFile.read(from: data, force: true),
              let raw = file.dataSet.string(for: .imageOrientationPatient) else { return nil }

        let values = raw.split(separator: "\\").compactMap { Double($0) }
        guard values.count == 6 else { return nil }

        // The slice normal is the cross product of the row and column cosines;
        // the dominant axis names the plane.
        let row = Array(values[0..<3])
        let column = Array(values[3..<6])
        let normal = [
            row[1] * column[2] - row[2] * column[1],
            row[2] * column[0] - row[0] * column[2],
            row[0] * column[1] - row[1] * column[0]
        ]

        let magnitudes = normal.map { abs($0) }
        guard let maximum = magnitudes.max(), maximum > 0 else { return nil }
        // Anything meaningfully off-axis is oblique, not one of the three planes.
        guard maximum > 0.85 else { return nil }

        switch magnitudes.firstIndex(of: maximum) {
        case 0:  return "Sagittal"
        case 1:  return "Coronal"
        case 2:  return "Axial"
        default: return nil
        }
    }
}
