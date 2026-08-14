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
/// The angle is kept as the angle. The viewer's rotate tool turns the picture
/// freely, so storing quarter turns would silently print a 30° arrangement
/// upright — the film has to be able to say what the screen said. A whole
/// quarter turn is still taken exactly, by permuting pixels; anything else is
/// resampled once, at print time, and the turned picture is fitted into the
/// image box with its corners falling outside the film's rectangle.
public struct ViewerPresentation: Sendable, Equatable, Hashable, Codable {

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

    /// Clockwise rotation in degrees, normalised to [0, 360).
    public var rotationDegrees: Double {
        didSet { rotationDegrees = Self.normalized(rotationDegrees) }
    }

    /// The rotation as whole clockwise quarter turns, 0–3.
    ///
    /// The nearest quarter turn when the angle is not one — this is what the
    /// exact, permute-only pixel paths can take. Ask ``isQuarterTurn`` before
    /// trusting it to be the whole story.
    public var quarterTurns: Int {
        get { Self.quarterTurns(fromDegrees: rotationDegrees) }
        set { rotationDegrees = Double(((newValue % 4) + 4) % 4) * 90 }
    }

    /// Whether the rotation is a whole quarter turn, which pixels take exactly.
    public var isQuarterTurn: Bool {
        abs(rotationDegrees - Double(quarterTurns) * 90) <= Self.angleEpsilon
    }

    /// Angles within this of a quarter turn are that quarter turn: the rotate
    /// tool emits a float per mouse event, and a millionth of a degree off 90°
    /// must not cost the picture its exact rotation.
    static let angleEpsilon: Double = 1e-6

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
        self.rotationDegrees = Self.normalized(rotationDegrees)
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

    /// Wraps any angle into [0, 360), keeping the angle itself.
    public static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Whether this presentation leaves pixels untouched.
    public var isIdentity: Bool {
        rotationDegrees == 0 && !flipHorizontal && !flipVertical && !invert && !cropsAnything
    }

    // MARK: - Rotation geometry

    /// The rotation's cosine and sine, snapped at the quarter turns.
    ///
    /// `cos(90°)` is 6e-17 rather than zero in binary floating point, and that
    /// is the difference between a quarter turn's crop being exact and being a
    /// pixel out — so the four exact answers are given exactly.
    var rotationComponents: (cos: Double, sin: Double) {
        if isQuarterTurn {
            switch quarterTurns {
            case 1:  return (0, 1)
            case 2:  return (-1, 0)
            case 3:  return (0, -1)
            default: return (1, 0)
            }
        }
        let radians = rotationDegrees * .pi / 180
        return (cos(radians), sin(radians))
    }

    /// The bounding box a rectangle occupies once this rotation has turned it.
    ///
    /// A quarter turn simply swaps the sides; every other angle needs a bigger
    /// box than either side, and the corners of that box are outside the
    /// picture — background, on screen and on film alike.
    public func turnedSize(width: Double, height: Double) -> (width: Double, height: Double) {
        let (cosine, sine) = rotationComponents
        let c = abs(cosine), s = abs(sine)
        return (width * c + height * s, width * s + height * c)
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
    /// - Parameter covers: whether the picture is laid in covering the whole
    ///   viewport — fill-to-film — rather than fitted inside it. A covering
    ///   picture is cropped by the viewport on its long axis at every zoom, so
    ///   the region is smaller than the image even at zoom 1 and a pan slides
    ///   it; computed as fitted, that same call answered "the whole image" and
    ///   the pan a filled cell stored never reached the pixels anyone saw.
    public func visibleRegion(
        imageWidth: Int, imageHeight: Int, covers: Bool = false
    ) -> PixelRegion? {
        guard imageWidth > 0, imageHeight > 0,
              viewportWidth > 0, viewportHeight > 0,
              zoom.isFinite, zoom > 0,
              panX.isFinite, panY.isFinite else { return nil }

        // How the image is laid into the viewport before zoom: fitted touches
        // its inside, covering is cropped by it.
        let baseScale = covers
            ? max(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
            : min(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
        guard baseScale > 0 else { return nil }

        let scale = baseScale * zoom
        guard scale > 0 else { return nil }

        // The viewport as the image sees it, in source pixels: the box the
        // un-rotated viewport rectangle needs. A quarter turn swaps the sides;
        // an angle in between needs both of them.
        let (visibleWidth, visibleHeight) = turnedSize(
            width: viewportWidth / scale, height: viewportHeight / scale)

        // Pan moves the image, so the viewport moves the opposite way over it.
        // Held inside the image first: a pan that runs off the edge would
        // otherwise be answered with a *smaller* rectangle — the printer refits
        // that into the whole image box, and the cell comes out enlarged, which
        // is not what panning an image means. Clamped, the region is always a
        // full viewport's worth of pixels, so the cell's picture is the same
        // size however far the drag went, and a fitted image cannot be cropped
        // by a pan at all. See ``clampedPan(x:y:imageWidth:imageHeight:)``.
        let (heldPanX, heldPanY) = clampedPan(
            x: panX, y: panY, imageWidth: imageWidth, imageHeight: imageHeight,
            covers: covers)

        // Un-rotate the pan vector: it is applied before the rotation on screen.
        let (unrotatedPanX, unrotatedPanY) = unrotate(x: heldPanX, y: heldPanY)
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

    // MARK: - Pan limits

    /// A pan held to what the image can actually cover.
    ///
    /// Film has no notion of "outside the image": pan past the edge and
    /// ``visibleRegion(imageWidth:imageHeight:)`` clamps the region, so the cell
    /// is refitted around a smaller crop — the picture appears to shrink and
    /// stretch rather than slide, which is not what a pan tool is for. Holding
    /// the pan to the region the image still fully covers makes the drag slide
    /// the picture and stop at the edge.
    ///
    /// Whether there is anything to slide depends on how the picture was laid
    /// into the cell, which is why `covers` is not optional in practice. A
    /// *fitted* picture at zoom 1 is entirely inside its cell, so the pan is a
    /// no-op and should be: there is nothing hidden to bring into view. A
    /// *filled* one is cropped by the cell on its long axis at every zoom, so
    /// the same drag has real travel. Assuming fitted for both is what made the
    /// pan tool appear dead on a fill-scaled film.
    ///
    /// - Parameters:
    ///   - x: Desired pan in view points.
    ///   - y: Desired pan in view points.
    ///   - imageWidth: Source frame width in pixels.
    ///   - imageHeight: Source frame height in pixels.
    ///   - covers: Whether the picture is drawn covering the whole viewport —
    ///     the cropping scaling modes, fill and stretch. Fitted is the default
    ///     because it is what the film does unless told otherwise.
    /// - Returns: The pan, clamped on each axis.
    public func clampedPan(
        x: Double, y: Double, imageWidth: Int, imageHeight: Int,
        covers: Bool = false
    ) -> (x: Double, y: Double) {
        guard x.isFinite, y.isFinite,
              imageWidth > 0, imageHeight > 0,
              viewportWidth > 0, viewportHeight > 0,
              zoom.isFinite, zoom > 0 else { return (x, y) }

        // How the picture is laid into the viewport before the zoom: fitted
        // touches the inside of it, filled covers it. A covering picture is
        // cropped by the viewport on its long axis, so there is image outside
        // the cell to bring into view even at zoom 1 — which is exactly what
        // the pan tool is for, and what taking the fit scale here denied it.
        let baseScale = covers
            ? max(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
            : min(viewportWidth / Double(imageWidth),
                  viewportHeight / Double(imageHeight))
        let scale = baseScale * zoom
        guard scale > 0 else { return (x, y) }

        // The viewport as the image sees it: turned, so a quarter turn swaps its
        // sides exactly as `visibleRegion` does.
        let (acrossX, acrossY) = turnedSize(width: viewportWidth, height: viewportHeight)

        // How far the image can travel before its edge comes inside the
        // viewport, along each of the *image's* axes.
        let limitX = max(0, (Double(imageWidth) * scale - acrossX) / 2)
        let limitY = max(0, (Double(imageHeight) * scale - acrossY) / 2)

        // Pan is stated in view points and the limits in the image's axes, so
        // the vector is taken into image space, held there, and turned back.
        let (unrotatedX, unrotatedY) = unrotate(x: x, y: y)
        let heldX = max(-limitX, min(limitX, unrotatedX))
        let heldY = max(-limitY, min(limitY, unrotatedY))
        let (cosine, sine) = rotationComponents
        return (heldX * cosine - heldY * sine, heldX * sine + heldY * cosine)
    }

    /// Rotates a view-space vector back into image space.
    ///
    /// The inverse of a clockwise turn in screen coordinates, which for the four
    /// quarter turns is the exact swap it always was: 90° gives `(y, -x)`.
    private func unrotate(x: Double, y: Double) -> (Double, Double) {
        let (cosine, sine) = rotationComponents
        return (x * cosine + y * sine, -x * sine + y * cosine)
    }
}
