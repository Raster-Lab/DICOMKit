// ViewerSeriesEntry.swift
// DICOMStudio
//
// DICOM Studio — a series as the viewer's series pane shows it.
//
// Flattened from the library's study/series/instance models so the viewer never
// reaches back into the library while rendering: one entry carries everything a
// card needs to draw and everything a tile needs to load.

import Foundation

/// One series of the open study, ready to hang in a tile.
public struct ViewerSeriesEntry: Identifiable, Hashable, Sendable {

    /// Series Instance UID (0020,000E). Also the drag payload.
    public let seriesInstanceUID: String

    public var id: String { seriesInstanceUID }

    /// Series Description (0008,103E), or a fallback built from the modality.
    public let title: String

    /// Series Number (0020,0011), for ordering and display.
    public let seriesNumber: Int?

    /// Modality (0008,0060).
    public let modality: String

    /// Image Orientation, resolved to "Axial"/"Coronal"/"Sagittal" when the
    /// series' direction cosines are axis-aligned.
    public let orientation: String?

    /// The series' files, in instance order — the tile's navigation list.
    public let filePaths: [String]

    /// Total frames across the series, which is what a cine tile steps through.
    public let frameCount: Int

    public init(
        seriesInstanceUID: String,
        title: String,
        seriesNumber: Int? = nil,
        modality: String = "OT",
        orientation: String? = nil,
        filePaths: [String],
        frameCount: Int
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.title = title
        self.seriesNumber = seriesNumber
        self.modality = modality
        self.orientation = orientation
        self.filePaths = filePaths
        self.frameCount = frameCount
    }

    /// Objects in the series.
    public var objectCount: Int { filePaths.count }

    /// "715 objects, 715 frames" — the counts line on a card.
    public var countsLabel: String {
        let objects = "\(objectCount) object\(objectCount == 1 ? "" : "s")"
        let frames = "\(frameCount) frame\(frameCount == 1 ? "" : "s")"
        return "\(objects), \(frames)"
    }

    /// The orientation line, which is worth stating even when unknown — an
    /// unlabelled card reads as though the series has no orientation at all.
    public var orientationLabel: String {
        orientation ?? "Orientation Unavailable"
    }

    /// Series Number as shown on the card badge, e.g. "4".
    ///
    /// `nil` when the series carries no number: an invented one would imply an
    /// ordering the study does not actually assert.
    public var seriesNumberLabel: String? {
        seriesNumber.map { String($0) }
    }

    /// How the pane announces this series, number first — the number is how a
    /// reader refers to a series aloud and in a report.
    public var spokenLabel: String {
        seriesNumber.map { "Series \($0), \(title)" } ?? title
    }

    /// The file a tile shows when this series is first hung.
    public var firstFilePath: String? { filePaths.first }
}
