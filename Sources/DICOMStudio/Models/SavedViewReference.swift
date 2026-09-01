// SavedViewReference.swift
// DICOMStudio
//
// DICOM Studio — one presentation-state object, as the series pane lists it.
//
// A saved view is a set of PR objects, one per image it covers. The pane lists
// them per image so a reader can see, without opening anything, which slices of
// a series carry a presentation state and which object each one is.

import Foundation

/// One presentation-state object and the image it describes.
public struct SavedViewReference: Identifiable, Hashable, Sendable {

    /// SOP Instance UID of the presentation-state object itself.
    public let sopInstanceUID: String

    public var id: String { sopInstanceUID }

    /// The view's name, as the reader typed it.
    public let label: String

    /// Series Instance UID of the *image* this state describes — the series
    /// whose card lists it, read from Referenced Series Sequence.
    public let imageSeriesInstanceUID: String

    /// SOP Instance UID of the image this state describes.
    public let imageSOPInstanceUID: String

    /// Instance Number (0020,0013) of the image, when the study indexes it.
    ///
    /// The image's number, not the state's: "the PR on image 42" is how a
    /// reader locates the slice, and the state's own numbering runs 1…n across
    /// whatever images the view happened to cover.
    public let imageInstanceNumber: Int?

    /// Series Number (0020,0011) of the image series.
    public let imageSeriesNumber: Int?

    /// Series Number of the presentation-state series the object lives in.
    ///
    /// Distinct from ``imageSeriesNumber`` by construction: a presentation
    /// state is its own series, pointing at the image series rather than
    /// joining it, which is why the pane states both.
    public let stateSeriesNumber: Int?

    /// Instance Number of the presentation-state object within its own series.
    public let stateInstanceNumber: Int?

    /// Whether the object carries a colour palette (a Pseudo-Color state).
    public let isColour: Bool

    /// The frames of a multi-frame image the state's drawings are on, as the
    /// viewer displays them — one-based, read from the Graphic Annotation
    /// Sequence's Referenced Frame Numbers (0008,1160).
    ///
    /// Empty for a single-frame image, and for a state with no drawings: the
    /// window and zoom are statements about the whole object and name no frame.
    /// Instance Number cannot say which frame carries the text — a cine loop is
    /// one instance — so this is the only number a reader can check against the
    /// corner overlay's frame counter.
    public let annotatedFrameNumbers: [Int]

    public init(
        sopInstanceUID: String,
        label: String,
        imageSeriesInstanceUID: String,
        imageSOPInstanceUID: String,
        imageInstanceNumber: Int? = nil,
        imageSeriesNumber: Int? = nil,
        stateSeriesNumber: Int? = nil,
        stateInstanceNumber: Int? = nil,
        isColour: Bool = false,
        annotatedFrameNumbers: [Int] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.label = label
        self.imageSeriesInstanceUID = imageSeriesInstanceUID
        self.imageSOPInstanceUID = imageSOPInstanceUID
        self.imageInstanceNumber = imageInstanceNumber
        self.imageSeriesNumber = imageSeriesNumber
        self.stateSeriesNumber = stateSeriesNumber
        self.stateInstanceNumber = stateInstanceNumber
        self.isColour = isColour
        self.annotatedFrameNumbers = annotatedFrameNumbers
    }

    /// "Series 2, image 42" — where the *image* is, which is what a reader
    /// navigates by.
    ///
    /// Stated as far as it is known: an image the study does not index by
    /// number gets its series alone rather than an invented position.
    public var imageLocationLabel: String {
        let location: String
        switch (imageSeriesNumber, imageInstanceNumber) {
        case let (series?, image?): location = "Series \(series), image \(image)"
        case let (series?, nil): location = "Series \(series)"
        case let (nil, image?): location = "Image \(image)"
        case (nil, nil): location = "Image"
        }
        guard let frames = frameLabel else { return location }
        return "\(location), \(frames)"
    }

    /// "frame 11", "frames 3, 8" or "12 frames" — where on a multi-frame image
    /// the drawings are, stated so a reader can check it against the corner
    /// overlay's frame counter. Nil when the state names no frame.
    ///
    /// A handful of frames are named outright; more than three would run the
    /// row off its line, so a heavily annotated loop states its count instead.
    private var frameLabel: String? {
        guard !annotatedFrameNumbers.isEmpty else { return nil }
        if annotatedFrameNumbers.count == 1 {
            return "frame \(annotatedFrameNumbers[0])"
        }
        if annotatedFrameNumbers.count <= 3 {
            let list = annotatedFrameNumbers.map(String.init).joined(separator: ", ")
            return "frames \(list)"
        }
        return "\(annotatedFrameNumbers.count) frames"
    }

    /// "PR 9001 · 3" — the presentation state's own series and instance number.
    public var stateLocationLabel: String {
        switch (stateSeriesNumber, stateInstanceNumber) {
        case let (series?, instance?): return "PR \(series) · \(instance)"
        case let (series?, nil): return "PR \(series)"
        case let (nil, instance?): return "PR · \(instance)"
        case (nil, nil): return "PR"
        }
    }
}

// MARK: - Grouping for the series list

/// One saved view's presentation states within a single series.
///
/// A saved view written for a whole series is one decision the reader made
/// once, stored as one PR object per slice. Listing those objects per slice —
/// which is what the series pane's list did — turns that one decision into as
/// many identical rows as the series has images, and buries the view that is
/// genuinely on a single image among them. So the list groups by view first,
/// and a view that reaches the whole series says so in one line.
///
/// A value type rather than logic inside the list view, because the collapse
/// rule is the substance of what the list says: "these thirty-three objects are
/// one reading" is a claim about the study, and a claim worth testing.
public struct SavedViewGroup: Identifiable, Hashable, Sendable {

    /// The view's name — what the reader saved it under, and what identifies it
    /// across the slices it covers.
    public let label: String

    public var id: String { label }

    /// Its states, in the order they were handed over — image order.
    public let references: [SavedViewReference]

    public init(label: String, references: [SavedViewReference]) {
        self.label = label
        self.references = references
    }

    /// Whether it carries a colour palette.
    ///
    /// Read off the first state: a view is saved with one palette across every
    /// image it covers.
    public var isColour: Bool { references.first?.isColour ?? false }

    /// How many of the series' images it is on.
    ///
    /// Counted over distinct images rather than over states: a multi-frame
    /// image can carry more than one state, and counting objects would claim
    /// the view reaches further through the stack than it does.
    public var imageCount: Int {
        Set(references.map(\.imageSOPInstanceUID)).count
    }

    /// The presentation-state series its objects live in, when they share one.
    ///
    /// A view saved in a single pass has all its objects in one PR series. A
    /// view re-saved later has them in two, and gets nothing rather than one of
    /// the two standing for both.
    public var commonStateSeriesNumber: Int? {
        let numbers = Set(references.compactMap(\.stateSeriesNumber))
        return numbers.count == 1 ? numbers.first : nil
    }

    /// Whether this view covers every image of a series holding `imageCount`
    /// images.
    ///
    /// Compared against the series' own object count rather than against the
    /// widest group present: two views could each cover the same half of a
    /// series, and calling both "the whole series" would misstate where they
    /// are. A series whose count is unknown — zero — never collapses, so the
    /// list falls back to naming the images it does know.
    public func coversWholeSeries(ofImageCount seriesImageCount: Int) -> Bool {
        seriesImageCount > 0 && imageCount >= seriesImageCount
    }

    /// Groups a series' references by the view each belongs to, keeping the
    /// order in which each view's first state arrived.
    ///
    /// Keyed by label rather than by the state's own SOP UID: a series view is
    /// a separate object per slice, and keying by object would put every slice
    /// in a group of its own — the flattening this exists to undo.
    public static func grouped(_ references: [SavedViewReference]) -> [SavedViewGroup] {
        var order: [String] = []
        var byLabel: [String: [SavedViewReference]] = [:]
        for reference in references {
            if byLabel[reference.label] == nil {
                order.append(reference.label)
            }
            byLabel[reference.label, default: []].append(reference)
        }
        return order.map { SavedViewGroup(label: $0, references: byLabel[$0] ?? []) }
    }
}
