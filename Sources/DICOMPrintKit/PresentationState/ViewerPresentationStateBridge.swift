// ViewerPresentationStateBridge.swift
// DICOMPrintKit
//
// Turns what a reader was looking at into a presentation state, and back.
//
// The viewer holds its state as window/level plus zoom, pan, rotation, flips
// and inversion. GSPS holds the same facts in the standard's vocabulary: a VOI
// LUT, a Displayed Area, a Spatial Transformation and a Presentation LUT shape.
// This file is the only place that translation lives, so a state saved by the
// viewer and one restored into it cannot drift apart.
//
// Two mismatches between the two vocabularies are worth stating, because they
// decide what a restored view can promise:
//
//   * GSPS rotation is one of 0/90/180/270 and its flip is *horizontal only*
//     (PS3.3 C.10.10). The viewer allows a free angle and both flips, so a
//     vertical flip is written as a 180° rotation plus a horizontal one, which
//     is the same picture.
//   * Displayed Area is a rectangle of source pixels, not a zoom factor. It is
//     therefore independent of the viewport it was saved from — the same state
//     restores correctly into a different window size, which is the behaviour
//     that makes a saved state portable.

import Foundation
import DICOMCore
import DICOMKit

/// Translates between a viewer's live display state and a GSPS.
public enum ViewerPresentationStateBridge {

    // MARK: - Capture

    /// The display parameters of a saved view, in the standard's terms.
    ///
    /// Kept separate from ``GrayscalePresentationState`` so a caller can compose
    /// one without yet knowing the UIDs it will be stored under.
    public struct CapturedDisplay: Sendable, Equatable {
        public var voiLUT: VOILUT?
        public var spatialTransformation: SpatialTransformation?
        public var displayedArea: DisplayedArea?
        public var presentationLUT: PresentationLUT

        public init(
            voiLUT: VOILUT? = nil,
            spatialTransformation: SpatialTransformation? = nil,
            displayedArea: DisplayedArea? = nil,
            presentationLUT: PresentationLUT = .identity
        ) {
            self.voiLUT = voiLUT
            self.spatialTransformation = spatialTransformation
            self.displayedArea = displayedArea
            self.presentationLUT = presentationLUT
        }

        /// `DisplayedArea` holds tuples, which blocks synthesized equality.
        public static func == (lhs: CapturedDisplay, rhs: CapturedDisplay) -> Bool {
            lhs.voiLUT == rhs.voiLUT
                && lhs.spatialTransformation == rhs.spatialTransformation
                && lhs.presentationLUT == rhs.presentationLUT
                && lhs.displayedArea?.topLeft.column == rhs.displayedArea?.topLeft.column
                && lhs.displayedArea?.topLeft.row == rhs.displayedArea?.topLeft.row
                && lhs.displayedArea?.bottomRight.column == rhs.displayedArea?.bottomRight.column
                && lhs.displayedArea?.bottomRight.row == rhs.displayedArea?.bottomRight.row
                && lhs.displayedArea?.sizeMode == rhs.displayedArea?.sizeMode
        }
    }

    /// Reads a viewer's state into the display parameters a GSPS carries.
    ///
    /// - Parameters:
    ///   - presentation: Zoom, pan, rotation, flips and inversion as the viewer
    ///     holds them.
    ///   - windowCenter: The window actually applied, if the reader set one.
    ///   - windowWidth: Ditto.
    ///   - windowExplanation: The preset's name, when the window came from one.
    ///   - imageWidth: Source frame size, needed to turn zoom and pan into the
    ///     pixel rectangle Displayed Area is defined as.
    ///   - imageHeight: Ditto.
    ///   - covers: Whether the picture is drawn covering the viewport.
    public static func capture(
        presentation: ViewerPresentation,
        windowCenter: Double?,
        windowWidth: Double?,
        windowExplanation: String? = nil,
        imageWidth: Int,
        imageHeight: Int,
        covers: Bool = false
    ) -> CapturedDisplay {
        var captured = CapturedDisplay()

        if let windowCenter, let windowWidth, windowWidth > 0 {
            captured.voiLUT = .window(
                center: windowCenter, width: windowWidth,
                explanation: windowExplanation, function: .linear)
        }

        captured.spatialTransformation = spatialTransformation(from: presentation)

        // A view that shows the whole image has no Displayed Area worth storing:
        // `visibleRegion` returns nil for it, and the absence restores as "fit
        // the image", which is what the default view does anyway.
        if let region = presentation.visibleRegion(
            imageWidth: imageWidth, imageHeight: imageHeight, covers: covers) {
            captured.displayedArea = DisplayedArea(
                // DICOM pixel coordinates are 1-based (PS3.3 C.10.4); the
                // viewer's regions are 0-based.
                topLeft: (column: region.x + 1, row: region.y + 1),
                bottomRight: (column: region.x + region.width,
                              row: region.y + region.height),
                sizeMode: .scaleToFit)
        }

        captured.presentationLUT = presentation.invert ? .inverse : .identity

        return captured
    }

    /// Folds the viewer's free rotation and two flips into what GSPS can say.
    ///
    /// A vertical flip has no GSPS attribute of its own; mirroring vertically is
    /// the same picture as mirroring horizontally and turning half a circle, so
    /// that is what gets written.
    static func spatialTransformation(
        from presentation: ViewerPresentation
    ) -> SpatialTransformation? {
        var quarterTurns = presentation.quarterTurns
        var horizontalFlip = presentation.flipHorizontal

        if presentation.flipVertical {
            horizontalFlip.toggle()
            quarterTurns = (quarterTurns + 2) % 4
        }

        let rotation = quarterTurns * 90
        guard rotation != 0 || horizontalFlip else { return nil }
        return SpatialTransformation(rotation: rotation, horizontalFlip: horizontalFlip)
    }

    // MARK: - Restore

    /// What a restored state asks the viewer to do.
    ///
    /// Zoom and pan are returned for a *specific* viewport, because Displayed
    /// Area is a pixel rectangle: the same state yields different zoom values in
    /// different window sizes, and that is the point.
    public struct RestoredDisplay: Sendable, Equatable {
        public var windowCenter: Double?
        public var windowWidth: Double?
        public var zoom: Double
        public var panX: Double
        public var panY: Double
        public var rotationDegrees: Double
        public var flipHorizontal: Bool
        public var invert: Bool

        public init(
            windowCenter: Double? = nil,
            windowWidth: Double? = nil,
            zoom: Double = 1,
            panX: Double = 0,
            panY: Double = 0,
            rotationDegrees: Double = 0,
            flipHorizontal: Bool = false,
            invert: Bool = false
        ) {
            self.windowCenter = windowCenter
            self.windowWidth = windowWidth
            self.zoom = zoom
            self.panX = panX
            self.panY = panY
            self.rotationDegrees = rotationDegrees
            self.flipHorizontal = flipHorizontal
            self.invert = invert
        }
    }

    /// Turns a parsed presentation state back into viewer settings.
    ///
    /// - Parameters:
    ///   - state: The state to apply.
    ///   - imageWidth: Source frame size.
    ///   - imageHeight: Ditto.
    ///   - viewportWidth: The viewport the state is being restored into — which
    ///     need not be the one it was saved from.
    ///   - viewportHeight: Ditto.
    ///   - covers: Whether the picture is drawn covering the viewport.
    public static func restore(
        _ state: GrayscalePresentationState,
        imageWidth: Int,
        imageHeight: Int,
        viewportWidth: Double,
        viewportHeight: Double,
        covers: Bool = false
    ) -> RestoredDisplay {
        var restored = RestoredDisplay()

        if case .window(let center, let width, _, _)? = state.voiLUT {
            restored.windowCenter = center
            restored.windowWidth = width
        }

        if let spatial = state.spatialTransformation {
            restored.rotationDegrees = Double(spatial.rotation)
            restored.flipHorizontal = spatial.horizontalFlip
        }

        if case .inverse? = state.presentationLUT {
            restored.invert = true
        }

        if let area = state.displayedArea {
            let (zoom, panX, panY) = zoomAndPan(
                for: area,
                imageWidth: imageWidth, imageHeight: imageHeight,
                viewportWidth: viewportWidth, viewportHeight: viewportHeight,
                rotationDegrees: restored.rotationDegrees,
                covers: covers)
            restored.zoom = zoom
            restored.panX = panX
            restored.panY = panY
        }

        return restored
    }

    /// Inverts ``ViewerPresentation/visibleRegion(imageWidth:imageHeight:covers:)``:
    /// given the rectangle that was visible, work out the zoom and pan that
    /// bring it back into the viewport.
    static func zoomAndPan(
        for area: DisplayedArea,
        imageWidth: Int,
        imageHeight: Int,
        viewportWidth: Double,
        viewportHeight: Double,
        rotationDegrees: Double,
        covers: Bool
    ) -> (zoom: Double, panX: Double, panY: Double) {
        guard imageWidth > 0, imageHeight > 0,
              viewportWidth > 0, viewportHeight > 0,
              area.width > 0, area.height > 0 else { return (1, 0, 0) }

        let baseScale = covers
            ? max(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
            : min(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
        guard baseScale > 0 else { return (1, 0, 0) }

        // The region is stated in image pixels; a quarter turn means the
        // viewport's width is spent on the region's height.
        let turns = ViewerPresentation.quarterTurns(fromDegrees: rotationDegrees)
        let quarterTurned = turns % 2 == 1
        let spanAcross = quarterTurned ? Double(area.height) : Double(area.width)
        let spanDown = quarterTurned ? Double(area.width) : Double(area.height)

        // Fit the whole region in: the smaller of the two scales is the one that
        // leaves nothing outside.
        let scale = min(viewportWidth / spanAcross, viewportHeight / spanDown)
        let zoom = scale / baseScale

        // Undo the centring `visibleRegion` applies. Back to 0-based pixels
        // first — Displayed Area is 1-based.
        let centerX = (Double(area.topLeft.column - 1) + Double(area.bottomRight.column)) / 2
        let centerY = (Double(area.topLeft.row - 1) + Double(area.bottomRight.row)) / 2
        let offsetX = (Double(imageWidth) / 2 - centerX) * scale
        let offsetY = (Double(imageHeight) / 2 - centerY) * scale

        // `visibleRegion` reads the pan in view space and un-rotates it, so the
        // inverse has to rotate back into view space.
        let presentation = ViewerPresentation(rotationDegrees: rotationDegrees)
        let (panX, panY) = presentation.imageToView(x: offsetX, y: offsetY)

        return (zoom.isFinite && zoom > 0 ? zoom : 1, panX, panY)
    }
}
