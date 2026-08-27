// ViewerHoverGeometry.swift
// DICOMStudio
//
// DICOM Studio — where the cursor is, in the image's own terms.
//
// The viewport shows the image fitted, zoomed, panned, turned and mirrored; the
// reader points at a piece of anatomy and wants to know which pixel that is,
// what it is worth, and where in the patient it sits. That is three separate
// jobs and this file holds the geometry for all three, without a view in sight
// so each can be checked against arithmetic rather than against a screenshot.
//
// A wrong readout is worse than no readout — "Value: 41 HU" over a lesion is a
// number someone may act on — so everything here answers `nil` rather than
// guessing: outside the picture, no pixel; no Image Position (Patient), no
// millimetres.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import DICOMCore
import DICOMKit

/// The order a display path composes the viewer's transforms in.
///
/// The two paths this viewer draws with do not agree, and the mapping has to
/// follow whichever one is actually on screen or the readout is a lie:
///
/// - The CPU path (SwiftUI modifiers) and the print path pan *before* rotating,
///   so a drag moves the picture through its own turned frame.
/// - The display shader pans *after* rotating, so a drag moves the picture
///   across the screen whichever way it has been turned.
///
/// They differ only when a picture is both rotated and panned.
public enum ViewerTransformOrder: Sendable, Equatable {
    /// Fit → zoom → pan → rotate → flip. The CPU and print composition.
    case panBeforeRotation
    /// Fit → flip → zoom → rotate → pan. The display shader's composition.
    case panAfterRotation
}

/// Turns a point in a viewport into a pixel of the image drawn there.
public enum ViewerHoverGeometry {

    /// The image pixel under a view point, or `nil` when the point is off the
    /// picture — over the black margin an aspect-fitted image leaves, say.
    ///
    /// - Parameters:
    ///   - viewPoint: cursor position in the viewport, origin at its top left.
    ///   - viewSize: the viewport, in points.
    public static func imagePixel(
        atViewPoint viewPoint: CGPoint,
        viewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int,
        zoom: Double,
        panX: Double,
        panY: Double,
        rotationDegrees: Double,
        flipHorizontal: Bool,
        flipVertical: Bool,
        order: ViewerTransformOrder
    ) -> (column: Int, row: Int)? {
        guard imageWidth > 0, imageHeight > 0,
              viewSize.width > 0, viewSize.height > 0,
              zoom.isFinite, zoom > 0,
              panX.isFinite, panY.isFinite else { return nil }

        // Fit-to-view: the same scale on both axes, so nothing is stretched.
        let fitScale = min(viewSize.width / Double(imageWidth),
                           viewSize.height / Double(imageHeight))
        guard fitScale > 0 else { return nil }

        // Everything below works from the viewport's centre, which is the anchor
        // every one of the viewer's transforms turns and scales about.
        var x = Double(viewPoint.x) - Double(viewSize.width) / 2
        var y = Double(viewPoint.y) - Double(viewSize.height) / 2

        switch order {
        case .panBeforeRotation:
            // Undo, outermost first: flip, rotate, pan, zoom.
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x -= panX
            y -= panY
            x /= zoom
            y /= zoom

        case .panAfterRotation:
            x -= panX
            y -= panY
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x /= zoom
            y /= zoom
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
        }

        // Now in fitted view points about the image's centre; back to pixels.
        let column = x / fitScale + Double(imageWidth) / 2
        let row = y / fitScale + Double(imageHeight) / 2

        // `floor`, not `round`: a pixel covers the square between its edges, and
        // rounding would report the neighbour for the outer half of every one.
        let columnIndex = Int(column.rounded(.down))
        let rowIndex = Int(row.rounded(.down))
        guard columnIndex >= 0, columnIndex < imageWidth,
              rowIndex >= 0, rowIndex < imageHeight else { return nil }

        return (columnIndex, rowIndex)
    }

    // MARK: - Continuous mapping, for the drawn-annotation overlay

    /// A point in the image, as fractions of its width and height, under a view
    /// point — `nil` only for degenerate input (no image, no viewport, a zoom
    /// of zero).
    ///
    /// The continuous twin of ``imagePixel(atViewPoint:...)``: annotations are
    /// stored as fractions of the image (see `PrintOverlayAnnotation`), so the
    /// overlay that edits them needs the fraction itself, not the pixel it
    /// rounds to. Unlike the pixel mapping this does *not* refuse points off
    /// the picture — dragging an arrow's head, the pointer legitimately strays
    /// past the edge and the fraction is clamped by the caller — so a caller
    /// that means "on the picture only" checks 0…1 itself.
    public static func normalizedImagePoint(
        atViewPoint viewPoint: CGPoint,
        viewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int,
        zoom: Double,
        panX: Double,
        panY: Double,
        rotationDegrees: Double,
        flipHorizontal: Bool,
        flipVertical: Bool,
        order: ViewerTransformOrder
    ) -> (x: Double, y: Double)? {
        guard imageWidth > 0, imageHeight > 0,
              viewSize.width > 0, viewSize.height > 0,
              zoom.isFinite, zoom > 0,
              panX.isFinite, panY.isFinite else { return nil }

        let fitScale = min(viewSize.width / Double(imageWidth),
                           viewSize.height / Double(imageHeight))
        guard fitScale > 0 else { return nil }

        var x = Double(viewPoint.x) - Double(viewSize.width) / 2
        var y = Double(viewPoint.y) - Double(viewSize.height) / 2

        switch order {
        case .panBeforeRotation:
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x -= panX
            y -= panY
            x /= zoom
            y /= zoom
        case .panAfterRotation:
            x -= panX
            y -= panY
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x /= zoom
            y /= zoom
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
        }

        let nx = x / (fitScale * Double(imageWidth)) + 0.5
        let ny = y / (fitScale * Double(imageHeight)) + 0.5
        return (nx, ny)
    }

    /// Where a point of the image lands in the view — the forward mapping the
    /// two inverses above undo. `x`/`y` are fractions of the image.
    public static func viewPoint(
        forNormalizedX nx: Double,
        y ny: Double,
        viewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int,
        zoom: Double,
        panX: Double,
        panY: Double,
        rotationDegrees: Double,
        flipHorizontal: Bool,
        flipVertical: Bool,
        order: ViewerTransformOrder
    ) -> CGPoint {
        let fitScale = min(viewSize.width / Double(max(1, imageWidth)),
                           viewSize.height / Double(max(1, imageHeight)))
        var x = (nx - 0.5) * Double(imageWidth) * fitScale
        var y = (ny - 0.5) * Double(imageHeight) * fitScale

        switch order {
        case .panBeforeRotation:
            // Fit → zoom → pan → rotate → flip, applied forwards.
            x *= zoom
            y *= zoom
            x += panX
            y += panY
            (x, y) = rotate(x: x, y: y, degrees: rotationDegrees)
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
        case .panAfterRotation:
            // Fit → flip → zoom → rotate → pan, applied forwards.
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
            x *= zoom
            y *= zoom
            (x, y) = rotate(x: x, y: y, degrees: rotationDegrees)
            x += panX
            y += panY
        }

        return CGPoint(x: x + Double(viewSize.width) / 2,
                       y: y + Double(viewSize.height) / 2)
    }

    /// A view-space drag, as the normalized image delta it moves something by.
    ///
    /// The linear part of the inverse only — pan and centring cancel out of a
    /// difference, but rotation, flips and scale do not, and skipping them
    /// would move an annotation sideways on a turned image.
    public static func normalizedDelta(
        forViewDelta delta: CGSize,
        viewSize: CGSize,
        imageWidth: Int,
        imageHeight: Int,
        zoom: Double,
        rotationDegrees: Double,
        flipHorizontal: Bool,
        flipVertical: Bool,
        order: ViewerTransformOrder
    ) -> (dx: Double, dy: Double) {
        guard imageWidth > 0, imageHeight > 0,
              viewSize.width > 0, viewSize.height > 0,
              zoom.isFinite, zoom > 0 else { return (0, 0) }
        let fitScale = min(viewSize.width / Double(imageWidth),
                           viewSize.height / Double(imageHeight))
        guard fitScale > 0 else { return (0, 0) }

        var x = Double(delta.width)
        var y = Double(delta.height)
        switch order {
        case .panBeforeRotation:
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x /= zoom
            y /= zoom
        case .panAfterRotation:
            (x, y) = rotate(x: x, y: y, degrees: -rotationDegrees)
            x /= zoom
            y /= zoom
            if flipHorizontal { x = -x }
            if flipVertical { y = -y }
        }
        return (x / (fitScale * Double(imageWidth)),
                y / (fitScale * Double(imageHeight)))
    }

    /// How many view points one image pixel spans on screen right now — the
    /// fitted scale times the zoom. What sizes overlay chrome so it tracks the
    /// picture: a font that is 4% of the image's rows must grow as they do.
    public static func displayScale(
        viewSize: CGSize, imageWidth: Int, imageHeight: Int, zoom: Double
    ) -> Double {
        guard imageWidth > 0, imageHeight > 0,
              viewSize.width > 0, viewSize.height > 0 else { return 1 }
        let fitScale = min(viewSize.width / Double(imageWidth),
                           viewSize.height / Double(imageHeight))
        guard fitScale > 0, zoom.isFinite, zoom > 0 else { return 1 }
        return fitScale * zoom
    }

    /// Rotates a view-space vector. Positive degrees turn clockwise on screen,
    /// which in this y-down space is the ordinary rotation matrix.
    private static func rotate(x: Double, y: Double, degrees: Double) -> (Double, Double) {
        guard degrees != 0 else { return (x, y) }
        let radians = degrees * .pi / 180
        let c = cos(radians), s = sin(radians)
        return (x * c - y * s, x * s + y * c)
    }
}

/// Where an image sits in the patient — its corner, its two directions and how
/// far apart its samples are.
///
/// Enough to answer "where is this pixel", and nothing more: the plane is what
/// the file states, so a file that states none produces no millimetres rather
/// than millimetres measured from an assumed origin.
public struct ViewerImagePlane: Sendable, Equatable, Hashable {

    /// Image Position (Patient) — the centre of the top-left pixel, in mm.
    public let origin: [Double]

    /// Unit vector along a row, i.e. towards increasing column index.
    public let rowDirection: [Double]

    /// Unit vector down a column, i.e. towards increasing row index.
    public let columnDirection: [Double]

    /// Spacing between adjacent rows, in mm — a step along ``columnDirection``.
    public let rowSpacing: Double

    /// Spacing between adjacent columns, in mm — a step along ``rowDirection``.
    public let columnSpacing: Double

    public init(
        origin: [Double],
        rowDirection: [Double],
        columnDirection: [Double],
        rowSpacing: Double,
        columnSpacing: Double
    ) {
        self.origin = origin
        self.rowDirection = rowDirection
        self.columnDirection = columnDirection
        self.rowSpacing = rowSpacing
        self.columnSpacing = columnSpacing
    }

    /// The patient coordinates of a pixel, in mm — PS3.3 C.7.6.2.1.1.
    public func patientCoordinate(column: Int, row: Int) -> (x: Double, y: Double, z: Double) {
        let alongRow = Double(column) * columnSpacing
        let downColumn = Double(row) * rowSpacing
        let point = (0..<3).map { axis in
            origin[axis] + rowDirection[axis] * alongRow + columnDirection[axis] * downColumn
        }
        return (point[0], point[1], point[2])
    }

    /// Reads the plane from a data set, or `nil` when the file does not place
    /// its pixels in the patient.
    public static func make(from dataSet: DataSet) -> ViewerImagePlane? {
        func numbers(_ tag: Tag) -> [Double]? {
            guard let raw = dataSet.string(for: tag) else { return nil }
            return raw.split(separator: "\\")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        }

        guard let position = numbers(.imagePositionPatient), position.count == 3,
              let orientation = numbers(.imageOrientationPatient), orientation.count == 6,
              // Pixel Spacing is [between rows, between columns] — PS3.3 C.7.6.3.1.1.
              let spacing = numbers(.pixelSpacing), spacing.count == 2,
              spacing[0] > 0, spacing[1] > 0 else { return nil }

        return ViewerImagePlane(
            origin: position,
            rowDirection: Array(orientation[0..<3]),
            columnDirection: Array(orientation[3..<6]),
            rowSpacing: spacing[0],
            columnSpacing: spacing[1])
    }
}

/// What the viewport says about the pixel under the cursor.
public struct ViewerCursorReadout: Sendable, Equatable {

    /// The pixel, in image coordinates.
    public let column: Int
    public let row: Int

    /// The value there, already rescaled to the units the file records it in —
    /// "Value: 41 HU", "RGB: 120 118 96" — or empty when it cannot be read.
    public let valueText: String

    /// "X: 169.58 mm  Y: 58.73 mm  Z: -430.01 mm", or empty when the file does
    /// not place its pixels in the patient.
    public let patientText: String

    public init(column: Int, row: Int, valueText: String = "", patientText: String = "") {
        self.column = column
        self.row = row
        self.valueText = valueText
        self.patientText = patientText
    }

    /// "X: 389 px  Y: 128 px  Value: 41 HU".
    ///
    /// The pixel address and its value read as one fact — which sample, and what
    /// it is worth — so they share a line.
    public var pixelText: String {
        let position = "X: \(column) px  Y: \(row) px"
        return valueText.isEmpty ? position : position + "  " + valueText
    }
}
