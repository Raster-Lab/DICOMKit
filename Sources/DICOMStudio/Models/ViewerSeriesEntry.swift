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

    /// Instance Number of each image, keyed by SOP Instance UID.
    ///
    /// Carried on the entry because presentation states name their images by
    /// UID, as the IOD requires, and the pane has to say *which slice* a saved
    /// view is on. The library indexes the number at import; recovering it any
    /// other way would mean reading the series' files back.
    ///
    /// An image the study does not number is simply absent, which the PR list
    /// reports as a series without a slice rather than an invented position.
    public let instanceNumbersBySOPUID: [String: Int]

    /// Total frames across the series, which is what a cine tile steps through.
    public let frameCount: Int

    /// Frames per object, keyed by file path.
    ///
    /// What lets the card show one preview per cine: an echo series is
    /// routinely several separate multi-frame objects — two loops of 76 and 92
    /// frames are two recordings, not one — and a single thumbnail of the
    /// first file claims the series is one picture. An object the library did
    /// not count is read as single-frame.
    public let frameCountsByFilePath: [String: Int]

    /// What the series holds: images, a report, a document, and so on.
    ///
    /// Read from the instances' SOP Class rather than guessed from the
    /// modality: "OT" is used for both a scanned image and an encapsulated PDF,
    /// and the pane has to tell them apart to know whether a thumbnail is even
    /// possible.
    public let contentKind: ViewerContentKind

    public init(
        seriesInstanceUID: String,
        title: String,
        seriesNumber: Int? = nil,
        modality: String = "OT",
        orientation: String? = nil,
        filePaths: [String],
        frameCount: Int,
        contentKind: ViewerContentKind = .image,
        instanceNumbersBySOPUID: [String: Int] = [:],
        frameCountsByFilePath: [String: Int] = [:]
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.title = title
        self.seriesNumber = seriesNumber
        self.modality = modality
        self.orientation = orientation
        self.filePaths = filePaths
        self.frameCount = frameCount
        self.contentKind = contentKind
        self.instanceNumbersBySOPUID = instanceNumbersBySOPUID
        self.frameCountsByFilePath = frameCountsByFilePath
    }

    /// Objects in the series.
    public var objectCount: Int { filePaths.count }

    /// "715 images", "1 image, 358 frames" — the counts line on a card.
    ///
    /// Objects first, because "how many pictures is this series" is what a
    /// reader is asking, and DICOM answers it with the object count: a
    /// 715-slice CT is 715 images, not one 715-frame recording. Frames are the
    /// second dimension — how many pictures live *inside* those objects — so
    /// the frame half is stated only when the series actually has more frames
    /// than objects, which is exactly when it is a cine. Saying "715 objects,
    /// 715 frames" on a plain stack invites the reader to wonder which of the
    /// two numbers is the one they wanted.
    ///
    /// Non-image series are counted in their own noun: a report is a report,
    /// and calling it an image is wrong before the count even matters.
    public var countsLabel: String {
        let objects = "\(objectCount) \(objectNoun)\(objectCount == 1 ? "" : "s")"
        guard frameCount > objectCount else { return objects }
        let frames = "\(frameCount) frame\(frameCount == 1 ? "" : "s")"
        return "\(objects), \(frames)"
    }

    /// What one object of this series is called: an image, a report, a
    /// document. Singular — `countsLabel` pluralises it.
    private var objectNoun: String {
        switch contentKind {
        case .image:              return "image"
        case .waveform:           return "waveform"
        case .report:             return "report"
        case .keyObjectSelection: return "key object selection"
        case .document:           return "document"
        case .presentationState:  return "presentation state"
        case .rawData:            return "raw data object"
        case .other:              return "object"
        }
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

    /// Whether this series is shown as pixels.
    public var isImageSeries: Bool { contentKind.isImage }

    // MARK: - Per-object previews

    /// The card's previews when the series is several cines: one per
    /// multi-frame object, in instance order.
    ///
    /// Empty everywhere else — a single object needs no strip, and a stack of
    /// single-frame slices (a 715-object CT) is one acquisition that would be
    /// misrepresented, and the pane buried, by 715 previews. The rule is
    /// "more than one object AND at least one of them is a cine": that is the
    /// series whose single thumbnail hides whole recordings, and it is the
    /// case Horos answers with one preview per object.
    public var objectPreviews: [SeriesObjectPreview] {
        guard isImageSeries, filePaths.count > 1 else { return [] }
        let previews = filePaths.map {
            SeriesObjectPreview(filePath: $0, frameCount: frameCountsByFilePath[$0] ?? 1)
        }
        guard previews.contains(where: { $0.frameCount > 1 }) else { return [] }
        return previews
    }
}

/// One object of a multi-cine series, as the card previews it.
public struct SeriesObjectPreview: Identifiable, Hashable, Sendable {

    /// The object's file — the preview's picture, and what clicking it opens.
    public let filePath: String

    /// Its frames, so the caption can tell a 76-frame loop from a 92-frame one.
    public let frameCount: Int

    public var id: String { filePath }

    /// "92 frames" — the caption under the preview.
    public var frameCountLabel: String {
        "\(frameCount) frame\(frameCount == 1 ? "" : "s")"
    }
}
