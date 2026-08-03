// ViewerPresentation.swift
// DICOMPrintKit
//
// DICOM Print — the viewer's presentation state, carried to film.
//
// What the user prints is what they arranged on screen: the window they set,
// the region they zoomed and panned to, and the orientation they rotated or
// flipped into. This type captures that arrangement, and — crucially — captures
// it as *geometry over the source image*, not as a screenshot. Film pixels are
// produced by cropping and permuting the full-resolution decoded frame, so a
// zoomed print carries the modality's real detail rather than the handful of
// screen pixels the monitor happened to show.

import Foundation

// MARK: - Pixel Region

/// An integer, half-open rectangle of source pixels: `x ..< x + width`.
public struct PixelRegion: Sendable, Equatable, Hashable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Whether this region covers the whole of an image of the given size.
    public func covers(width imageWidth: Int, height imageHeight: Int) -> Bool {
        x == 0 && y == 0 && width == imageWidth && height == imageHeight
    }
}

// MARK: - Presentation

/// The viewer's on-screen arrangement of one frame.
///
/// Angles are stored as quarter turns because the viewer only rotates in 90°
/// steps; an arbitrary angle would force a resampling rotation, which would
/// blur film pixels for no clinical gain.
public struct ViewerPresentation: Sendable, Equatable, Hashable {

    /// Display zoom multiplier applied on top of fit-to-view. 1.0 = fitted.
    public var zoom: Double

    /// Pan offset in view points, as applied by the viewer (positive x moves the
    /// image right, revealing pixels to its left).
    public var panX: Double
    public var panY: Double

    /// Size of the viewport the image was displayed in, in view points.
    ///
    /// Required to know how much of the image was actually visible; without it
    /// (a mark made before the viewer laid out) no crop is applied.
    public var viewportWidth: Double
    public var viewportHeight: Double

    /// Clockwise quarter turns, 0–3.
    public var quarterTurns: Int

    /// Mirror across the vertical axis, applied after rotation (as on screen).
    public var flipHorizontal: Bool

    /// Mirror across the horizontal axis, applied after rotation.
    public var flipVertical: Bool

    /// Whether the viewer was showing the frame inverted.
    public var invert: Bool

    public init(
        zoom: Double = 1.0,
        panX: Double = 0,
        panY: Double = 0,
        viewportWidth: Double = 0,
        viewportHeight: Double = 0,
        rotationDegrees: Double = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        invert: Bool = false
    ) {
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.quarterTurns = Self.quarterTurns(fromDegrees: rotationDegrees)
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.invert = invert
    }

    /// Normalizes any angle to 0–3 clockwise quarter turns.
    public static func quarterTurns(fromDegrees degrees: Double) -> Int {
        guard degrees.isFinite else { return 0 }
        let turns = Int((degrees / 90).rounded()) % 4
        return turns < 0 ? turns + 4 : turns
    }

    /// Whether this presentation leaves pixels untouched.
    public var isIdentity: Bool {
        quarterTurns == 0 && !flipHorizontal && !flipVertical && !invert && !cropsAnything
    }

    /// Whether the zoom/pan combination could hide any of the image.
    private var cropsAnything: Bool {
        zoom > 1.0 || panX != 0 || panY != 0
    }

    // MARK: - Visible region

    /// The source-pixel rectangle the viewport was showing.
    ///
    /// Returns `nil` when the whole image was visible, or when the viewport size
    /// is unknown — in both cases the full frame is printed.
    ///
    /// ## Derivation
    ///
    /// The viewer composes, from the inside out: fit-to-view scale, zoom, pan,
    /// rotation, then flip — each about the viewport centre. A source point `p`
    /// (relative to the image centre, in view points after fitting) lands at
    /// `q = F · R · (zoom · p + t)`. It is visible when `q` is inside the
    /// viewport rect `V`, so the visible set is `(R⁻¹ · F⁻¹ · V − t) / zoom`.
    ///
    /// `F⁻¹ · V = V`: mirroring a centred rectangle about its own centre gives
    /// the same rectangle, which is why flips never change *which* pixels are
    /// visible, only where they end up. `R⁻¹ · V` swaps width and height on odd
    /// quarter turns.
    public func visibleRegion(imageWidth: Int, imageHeight: Int) -> PixelRegion? {
        guard imageWidth > 0, imageHeight > 0,
              viewportWidth > 0, viewportHeight > 0,
              zoom.isFinite, zoom > 0,
              panX.isFinite, panY.isFinite else { return nil }

        // Fit-to-view: the image is aspect-fitted before zoom is applied.
        let fitScale = min(viewportWidth / Double(imageWidth),
                           viewportHeight / Double(imageHeight))
        guard fitScale > 0 else { return nil }

        let scale = fitScale * zoom
        guard scale > 0 else { return nil }

        // The viewport as the image sees it, in source pixels.
        let odd = quarterTurns % 2 == 1
        let visibleWidth = (odd ? viewportHeight : viewportWidth) / scale
        let visibleHeight = (odd ? viewportWidth : viewportHeight) / scale

        // Pan moves the image, so the viewport moves the opposite way over it.
        // Un-rotate the pan vector: it is applied before the rotation on screen.
        let (unrotatedPanX, unrotatedPanY) = unrotate(x: panX, y: panY)
        let centerX = Double(imageWidth) / 2 - unrotatedPanX / scale
        let centerY = Double(imageHeight) / 2 - unrotatedPanY / scale

        let minX = centerX - visibleWidth / 2
        let minY = centerY - visibleHeight / 2

        // Clamp to the image: the parts of the viewport showing background
        // contribute no pixels, and film has no notion of "outside the image".
        let x0 = max(0, Int(minX.rounded(.down)))
        let y0 = max(0, Int(minY.rounded(.down)))
        let x1 = min(imageWidth, Int((minX + visibleWidth).rounded(.up)))
        let y1 = min(imageHeight, Int((minY + visibleHeight).rounded(.up)))

        guard x1 > x0, y1 > y0 else { return nil }

        let region = PixelRegion(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        return region.covers(width: imageWidth, height: imageHeight) ? nil : region
    }

    /// Rotates a view-space vector back into image space.
    private func unrotate(x: Double, y: Double) -> (Double, Double) {
        switch quarterTurns {
        case 1:  return (y, -x)      // undo 90° clockwise
        case 2:  return (-x, -y)
        case 3:  return (-y, x)
        default: return (x, y)
        }
    }
}
