// ImageViewerViewModel+Annotations.swift
// DICOMStudio
//
// DICOM Studio — the corner annotations, for the viewport the view model is.
//
// The view model owns the live image, so it is where the annotations of the
// focused viewport come from; every other tile reads its own file through
// ``ViewerAnnotationTextCache``. Both end up in the same ``ViewerAnnotationText``
// so a tile does not change what it says on gaining focus.

import Foundation
import DICOMCore
import DICOMKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    /// What the live viewport is currently doing with that file.
    ///
    /// - Parameters:
    ///   - viewSize: the size the image area is drawn at, which only the view
    ///     knows.
    ///   - cursor: the pixel under the pointer, while it is over the picture.
    public func annotationViewportState(
        viewSize: CGSize,
        cursor: ViewerCursorReadout? = nil
    ) -> ViewerAnnotationViewportState {
        // A multi-frame file is stepped frame by frame, a series file by file;
        // "Im:" names whichever of the two this viewport actually walks, because
        // that is the number the reader is about to change.
        let position = isMultiFrame ? currentFrameIndex + 1 : currentFileIndex + 1
        let count = isMultiFrame ? numberOfFrames : max(seriesFiles.count, 1)

        return ViewerAnnotationViewportState(
            viewSize: viewSize,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            zoom: zoomLevel,
            rotationDegrees: rotationAngle,
            flipHorizontal: isFlippedHorizontal,
            flipVertical: isFlippedVertical,
            imagePosition: position,
            imageCount: count,
            cursor: cursor)
    }

    // MARK: - The pixel under the cursor

    /// The readout for a point in the live viewport, or `nil` when the cursor is
    /// not over the picture.
    ///
    /// The in-flight gesture is passed in rather than read from here: a drag
    /// changes the arrangement continuously and only commits it on release, so
    /// reading the committed values would report the pixel the cursor was over
    /// before the drag started.
    ///
    /// - Parameters:
    ///   - point: cursor position in the viewport, origin at its top left.
    ///   - viewSize: the viewport, in points.
    ///   - zoom: the zoom actually on screen, gesture included.
    ///   - panX: the pan actually on screen, gesture included.
    ///   - panY: the pan actually on screen, gesture included.
    public func cursorReadout(
        atViewPoint point: CGPoint,
        viewSize: CGSize,
        zoom: Double,
        panX: Double,
        panY: Double
    ) -> ViewerCursorReadout? {
        guard hasImage, !isWaveform, !isNonImageContent,
              imageColumns > 0, imageRows > 0 else { return nil }

        guard let pixel = ViewerHoverGeometry.imagePixel(
            atViewPoint: point,
            viewSize: viewSize,
            imageWidth: imageColumns,
            imageHeight: imageRows,
            zoom: zoom,
            panX: panX,
            panY: panY,
            rotationDegrees: rotationAngle,
            flipHorizontal: isFlippedHorizontal,
            flipVertical: isFlippedVertical,
            order: displayTransformOrder) else { return nil }

        return ViewerCursorReadout(
            column: pixel.column,
            row: pixel.row,
            valueText: cursorValueText(column: pixel.column, row: pixel.row),
            patientText: cursorPatientText(column: pixel.column, row: pixel.row))
    }

    /// Which composition the viewport is currently drawn with.
    ///
    /// The two display paths do not agree about whether pan happens before or
    /// after rotation (see ``ViewerTransformOrder``), so the readout has to
    /// follow whichever one is on screen rather than pick one and hope.
    var displayTransformOrder: ViewerTransformOrder {
        #if canImport(Metal)
        return displayTexture != nil ? .panAfterRotation : .panBeforeRotation
        #else
        return .panBeforeRotation
        #endif
    }

    /// "Value: 41 HU", "RGB: 120 118 96", or nothing when the pixels cannot be
    /// read — a value of zero would be a claim about the anatomy.
    private func cursorValueText(column: Int, row: Int) -> String {
        let sample = storedPixelValue(column: column, row: row)

        if let rgb = sample.rgb {
            return "RGB: \(rgb.0) \(rgb.1) \(rgb.2)"
        }
        guard let stored = sample.gray else { return "" }

        // Rescaled, because the stored number is an encoding and the rescaled
        // one is the measurement: CT reads in Hounsfield units, and a reader
        // acting on "1065" instead of "41 HU" is acting on the wrong number.
        let value = Double(stored) * rescaleSlope + rescaleIntercept
        let units = modalityUnitsSuffix
        let formatted = value == value.rounded() && abs(value) < 1e9
            ? String(Int(value.rounded()))
            : String(format: "%.2f", value)
        return "Value: \(formatted)\(units)"
    }

    /// " HU" for CT, and nothing for modalities whose values are not in units a
    /// reader can name.
    private var modalityUnitsSuffix: String {
        let modality = dicomFile?.dataSet.string(for: .modality)?
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        return modality == "CT" ? " HU" : ""
    }

    /// "X: 169.58 mm  Y: 58.73 mm  Z: -430.01 mm", or nothing when the file does
    /// not say where in the patient its pixels are.
    private func cursorPatientText(column: Int, row: Int) -> String {
        guard let plane = annotationText.plane else { return "" }
        let point = plane.patientCoordinate(column: column, row: row)
        return String(format: "X: %.2f mm  Y: %.2f mm  Z: %.2f mm", point.x, point.y, point.z)
    }

    /// What one tile of the grid is doing with its file.
    ///
    /// The window is left `nil` when the tile has none of its own: the annotation
    /// then states the window the file itself asks for, which is the window the
    /// tile is actually being shown under.
    public func annotationViewportState(
        for cell: ViewerCellState,
        cursor: ViewerCursorReadout? = nil
    ) -> ViewerAnnotationViewportState {
        let isMultiFrame = cell.frameCount > 1
        let position = isMultiFrame ? cell.frameIndex + 1 : cell.fileIndex + 1
        let count = isMultiFrame ? cell.frameCount : max(cell.seriesFiles.count, 1)

        return ViewerAnnotationViewportState(
            viewSize: CGSize(width: cell.viewportWidth, height: cell.viewportHeight),
            windowCenter: cell.windowCenter,
            windowWidth: cell.windowWidth,
            zoom: cell.zoom,
            rotationDegrees: cell.rotationAngle,
            flipHorizontal: cell.isFlippedHorizontal,
            flipVertical: cell.isFlippedVertical,
            imagePosition: position,
            imageCount: count,
            cursor: cursor)
    }
}
