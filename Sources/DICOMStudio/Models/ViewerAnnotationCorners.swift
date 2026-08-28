// ViewerAnnotationCorners.swift
// DICOMStudio
//
// DICOM Studio — what each corner of a viewport says.
//
// The arrangement is the one a reading room has read for decades, and it is
// worth stating why the four corners hold what they do:
//
//   top left      how the picture is being shown — its size, the view's size,
//                 the window it is under. The values a reader changes.
//   top right     who and what — patient and study. The values a reader
//                 must never get wrong.
//   bottom left   where in the series this is, and how it is arranged.
//   bottom right  when it was acquired.
//
// Composed here rather than in the view so the text can be tested without a
// window, and so the tiles and the 1×1 viewer cannot drift apart.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The part of the annotations that changes as the user works: the viewport's
/// size, its window, its zoom and where it sits in the series.
public struct ViewerAnnotationViewportState: Sendable, Equatable {

    /// Size of the viewport on screen, in points.
    public var viewSize: CGSize

    /// The window actually being applied, or `nil` to fall back to the file's.
    public var windowCenter: Double?
    public var windowWidth: Double?

    public var zoom: Double
    public var rotationDegrees: Double
    public var flipHorizontal: Bool
    public var flipVertical: Bool

    /// 1-based position in whatever the viewport steps through, and its length.
    public var imagePosition: Int?
    public var imageCount: Int?

    /// The pixel under the cursor, while it is over the picture.
    ///
    /// Only the viewport the mouse is actually in has one — a grid's other tiles
    /// have no cursor in them, and inventing a readout for them would be a
    /// number pointing at nothing.
    public var cursor: ViewerCursorReadout?

    public init(
        viewSize: CGSize = .zero,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        zoom: Double = 1,
        rotationDegrees: Double = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        imagePosition: Int? = nil,
        imageCount: Int? = nil,
        cursor: ViewerCursorReadout? = nil
    ) {
        self.viewSize = viewSize
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.zoom = zoom
        self.rotationDegrees = rotationDegrees
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.imagePosition = imagePosition
        self.imageCount = imageCount
        self.cursor = cursor
    }
}

/// The finished lines of text for a viewport's four corners.
public struct ViewerAnnotationCorners: Sendable, Equatable {
    public let topLeft: [String]
    public let topRight: [String]
    public let bottomLeft: [String]
    public let bottomRight: [String]

    /// Edge letters, already turned to match the viewport's rotation and flips.
    public let orientation: ViewerOrientationLabels?

    public init(
        topLeft: [String] = [],
        topRight: [String] = [],
        bottomLeft: [String] = [],
        bottomRight: [String] = [],
        orientation: ViewerOrientationLabels? = nil
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.orientation = orientation
    }

    /// How much of the annotation a viewport has room for.
    ///
    /// A 4×4 tile is a few hundred points across; setting the full block in type
    /// small enough to fit would leave text no one can read covering anatomy
    /// someone has to. So the small sizes keep the lines that answer "who is
    /// this and where am I" and drop the rest, rather than shrinking everything.
    public enum Detail: Sendable, Equatable {
        /// Every line.
        case full
        /// Identification, window, position — the reading minimum.
        case reduced
        /// Identification and position only.
        case minimal

        /// The detail a viewport of this size can carry.
        public static func forViewport(_ size: CGSize) -> Detail {
            let shortest = min(size.width, size.height)
            if shortest >= 340 { return .full }
            if shortest >= 190 { return .reduced }
            return .minimal
        }
    }

    /// Composes the corners for a file shown under a given viewport state.
    public static func make(
        text: ViewerAnnotationText,
        state: ViewerAnnotationViewportState,
        detail: Detail
    ) -> ViewerAnnotationCorners {
        let center = state.windowCenter ?? text.fileWindowCenter
        let width = state.windowWidth ?? text.fileWindowWidth
        let windowLine = windowText(center: center, width: width)

        let positionLine = imagePositionText(
            position: state.imagePosition, count: state.imageCount)

        var topLeft: [String] = []
        var topRight: [String] = []
        var bottomLeft: [String] = []
        var bottomRight: [String] = []

        // Under the window, because that is the line a reader's eye is already
        // on when they put the cursor somewhere to ask "and what is that worth".
        // Absent entirely when the cursor is not over the picture: two blank
        // lines that appear and vanish are worse than lines that simply arrive.
        let cursorLines = [
            state.cursor?.pixelText ?? "",
            state.cursor?.patientText ?? ""
        ]

        switch detail {
        case .full:
            topLeft = [text.imageSizeLine, viewSizeText(state.viewSize), windowLine] + cursorLines
            topRight = [text.patientLine, text.studyLine, text.seriesNumberLine]
            bottomLeft = [
                zoomText(zoom: state.zoom, rotationDegrees: state.rotationDegrees),
                positionLine,
                text.compressionLine,
                text.geometryLine
            ]
            bottomRight = [text.dateTimeLine]

        case .reduced:
            // The value under the cursor survives the cut; the millimetres do
            // not — at this size the reader is orienting, not measuring.
            topLeft = [windowLine, state.cursor?.pixelText ?? ""]
            topRight = [text.patientLine, text.studyLine]
            bottomLeft = [
                zoomText(zoom: state.zoom, rotationDegrees: state.rotationDegrees),
                positionLine
            ]
            bottomRight = [text.geometryLine]

        case .minimal:
            topRight = [text.patientLine]
            bottomLeft = [positionLine]
        }

        return ViewerAnnotationCorners(
            topLeft: topLeft.filter { !$0.isEmpty },
            topRight: topRight.filter { !$0.isEmpty },
            bottomLeft: bottomLeft.filter { !$0.isEmpty },
            bottomRight: bottomRight.filter { !$0.isEmpty },
            orientation: text.orientation?.transformed(
                rotationDegrees: state.rotationDegrees,
                flipHorizontal: state.flipHorizontal,
                flipVertical: state.flipVertical))
    }

    /// Whether there is anything to draw at all.
    public var isEmpty: Bool {
        topLeft.isEmpty && topRight.isEmpty && bottomLeft.isEmpty && bottomRight.isEmpty
            && (orientation?.isEmpty ?? true)
    }

    // MARK: - Lines built from viewport state

    /// "WL: 476  WW: 1036" — centre before width, as every station states it.
    static func windowText(center: Double?, width: Double?) -> String {
        guard let center, let width else { return "" }
        return "WL: \(ViewerAnnotationText.trimmed(center))  WW: \(ViewerAnnotationText.trimmed(width))"
    }

    static func viewSizeText(_ size: CGSize) -> String {
        guard size.width >= 1, size.height >= 1 else { return "" }
        return "View size: \(Int(size.width.rounded())) x \(Int(size.height.rounded()))"
    }

    /// "Zoom: 106%  Angle: 0".
    ///
    /// The angle is stated even at zero: a reader checking whether a picture has
    /// been turned needs an answer, and a missing line is not one.
    static func zoomText(zoom: Double, rotationDegrees: Double) -> String {
        let percent = Int((zoom * 100).rounded())
        let angle = Int(rotationDegrees.rounded()) % 360
        return "Zoom: \(percent)%  Angle: \(angle < 0 ? angle + 360 : angle)"
    }

    /// "Im: 3/17".
    static func imagePositionText(position: Int?, count: Int?) -> String {
        guard let position, position > 0 else { return "" }
        guard let count, count > 0 else { return "Im: \(position)" }
        return "Im: \(position)/\(count)"
    }
}
