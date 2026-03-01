// GestureHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent gesture calculation helpers

import Foundation

/// Platform-independent helpers for image viewer gesture calculations.
///
/// Provides zoom, pan, and rotation math without SwiftUI dependencies.
public enum GestureHelpers: Sendable {

    // MARK: - Zoom

    /// Minimum zoom scale.
    public static let minZoom: Double = 0.1

    /// Maximum zoom scale.
    public static let maxZoom: Double = 20.0

    /// Default zoom scale (fit to view).
    public static let defaultZoom: Double = 1.0

    /// Clamps a zoom value to the valid range.
    ///
    /// - Parameter zoom: Desired zoom level.
    /// - Returns: Clamped zoom level.
    public static func clampZoom(_ zoom: Double) -> Double {
        max(minZoom, min(maxZoom, zoom))
    }

    /// Calculates the new zoom level from a magnification gesture.
    ///
    /// - Parameters:
    ///   - currentZoom: Current zoom level.
    ///   - magnification: Magnification delta from the gesture.
    /// - Returns: New clamped zoom level.
    public static func zoomFromMagnification(
        currentZoom: Double,
        magnification: Double
    ) -> Double {
        clampZoom(currentZoom * magnification)
    }

    /// Calculates the zoom level for a scroll wheel delta.
    ///
    /// - Parameters:
    ///   - currentZoom: Current zoom level.
    ///   - scrollDelta: Scroll wheel delta (positive = zoom in).
    ///   - sensitivity: Sensitivity multiplier (default 0.01).
    /// - Returns: New clamped zoom level.
    public static func zoomFromScrollDelta(
        currentZoom: Double,
        scrollDelta: Double,
        sensitivity: Double = 0.01
    ) -> Double {
        let factor = 1.0 + scrollDelta * sensitivity
        return clampZoom(currentZoom * factor)
    }

    /// Calculates the fit-to-view zoom scale.
    ///
    /// - Parameters:
    ///   - imageWidth: Image width in pixels.
    ///   - imageHeight: Image height in pixels.
    ///   - viewWidth: Available view width.
    ///   - viewHeight: Available view height.
    /// - Returns: Zoom scale that fits the image within the view.
    public static func fitZoom(
        imageWidth: Double,
        imageHeight: Double,
        viewWidth: Double,
        viewHeight: Double
    ) -> Double {
        guard imageWidth > 0, imageHeight > 0,
              viewWidth > 0, viewHeight > 0 else {
            return defaultZoom
        }
        let scaleX = viewWidth / imageWidth
        let scaleY = viewHeight / imageHeight
        return clampZoom(min(scaleX, scaleY))
    }

    // MARK: - Pan

    /// Clamps pan offset to prevent the image from leaving the viewport entirely.
    ///
    /// - Parameters:
    ///   - offset: Desired pan offset (x, y).
    ///   - imageWidth: Image width in pixels.
    ///   - imageHeight: Image height in pixels.
    ///   - viewWidth: View width.
    ///   - viewHeight: View height.
    ///   - zoom: Current zoom level.
    /// - Returns: Clamped offset (x, y).
    public static func clampOffset(
        x: Double,
        y: Double,
        imageWidth: Double,
        imageHeight: Double,
        viewWidth: Double,
        viewHeight: Double,
        zoom: Double
    ) -> (x: Double, y: Double) {
        let scaledWidth = imageWidth * zoom
        let scaledHeight = imageHeight * zoom
        let maxX = max(0, (scaledWidth - viewWidth) / 2 + viewWidth * 0.25)
        let maxY = max(0, (scaledHeight - viewHeight) / 2 + viewHeight * 0.25)
        return (
            x: max(-maxX, min(maxX, x)),
            y: max(-maxY, min(maxY, y))
        )
    }

    // MARK: - Rotation

    /// Valid rotation angles (multiples of 90°).
    public static let rotationAngles: [Double] = [0, 90, 180, 270]

    /// Snaps a rotation angle to the nearest 90° increment.
    ///
    /// - Parameter degrees: Rotation in degrees.
    /// - Returns: Snapped angle in [0, 90, 180, 270].
    public static func snapRotation(_ degrees: Double) -> Double {
        let normalized = degrees.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        let snapped = (positive / 90.0).rounded() * 90
        return snapped.truncatingRemainder(dividingBy: 360)
    }

    /// Rotates 90° clockwise from the current angle.
    ///
    /// - Parameter currentAngle: Current rotation in degrees.
    /// - Returns: New rotation angle.
    public static func rotateClockwise(from currentAngle: Double) -> Double {
        snapRotation(currentAngle + 90)
    }

    /// Rotates 90° counter-clockwise from the current angle.
    ///
    /// - Parameter currentAngle: Current rotation in degrees.
    /// - Returns: New rotation angle.
    public static func rotateCounterClockwise(from currentAngle: Double) -> Double {
        snapRotation(currentAngle - 90)
    }

    // MARK: - Window/Level Drag

    /// Calculates window/level adjustment from a drag gesture delta.
    ///
    /// Horizontal drag adjusts width, vertical drag adjusts center.
    ///
    /// - Parameters:
    ///   - currentCenter: Current window center.
    ///   - currentWidth: Current window width.
    ///   - deltaX: Horizontal drag distance in points.
    ///   - deltaY: Vertical drag distance in points.
    ///   - sensitivity: Sensitivity multiplier (default 1.0).
    /// - Returns: Tuple of (newCenter, newWidth).
    public static func windowLevelFromDrag(
        currentCenter: Double,
        currentWidth: Double,
        deltaX: Double,
        deltaY: Double,
        sensitivity: Double = 1.0
    ) -> (center: Double, width: Double) {
        let newWidth = max(1.0, currentWidth + deltaX * sensitivity)
        let newCenter = currentCenter - deltaY * sensitivity
        return (center: newCenter, width: newWidth)
    }
}
