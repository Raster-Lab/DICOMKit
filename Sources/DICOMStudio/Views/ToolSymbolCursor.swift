// ToolSymbolCursor.swift
// DICOMStudio
//
// DICOM Studio — drawing a tool's own icon as the mouse pointer.
//
// The toolbar tells the reader which tool is armed, but the toolbar is at the top
// of the window and the pointer is on the image. A generic system cursor — the
// crosshair stood for both windowing and rotate — says "a tool is armed" without
// saying which, and the cost of guessing wrong is a drag that has already
// windowed an image the reader meant to turn. Rendering the *same SF Symbol the
// toolbar button carries* into the pointer makes the two say one thing, and it
// cannot drift: both read `ImageViewerDragTool.symbolName`.

#if os(macOS)
import AppKit

/// Builds mouse pointers out of SF Symbols, and keeps them.
///
/// Cursors are cached because a pointer shape is asked for on every boundary
/// crossing — `cursorUpdate` can fire many times a second as the mouse moves
/// across a tiled viewer — and rasterising a symbol into a fresh `NSImage` each
/// time would put an allocation and a draw on that path. The set of tools is
/// small, fixed, and known at compile time, so the whole cache is a handful of
/// images that are built once and live for the process.
@MainActor
enum ToolSymbolCursor {

    /// The pointer's drawn size, in points.
    ///
    /// Larger than the 16pt system cursors on purpose: this glyph has to be
    /// *identified*, not merely noticed, and a windowing circle at 16pt reads as
    /// a smudge. Larger still starts to cover the anatomy the reader is aiming
    /// at, which is the thing a pointer must never do.
    private static let size: CGFloat = 22

    /// The badge's stroke width, and the inset it needs to stay inside the image.
    ///
    /// One point, not more: the rim only has to separate the glyph from the
    /// pixels behind it, and every extra fraction reads as boldness rather
    /// than as edge — at 1.5 the W/L sun and the magnifier looked heavier as
    /// pointers than they do on their toolbar buttons.
    private static let outlineWidth: CGFloat = 1.0

    /// Main-actor confined, so a plain dictionary is enough — a pointer shape is
    /// only ever asked for while drawing.
    private static var cache: [String: NSCursor] = [:]

    /// A pointer showing `symbolName`, hot spot at its centre.
    ///
    /// - Parameters:
    ///   - symbolName: an SF Symbol name — the tool's own, so the pointer and the
    ///     toolbar button cannot disagree.
    ///   - fallback: used when the symbol will not render, which is what keeps a
    ///     missing or renamed glyph from leaving the reader with an invisible
    ///     pointer. A cursor is not a place to fail loudly.
    /// - Returns: The cursor, cached under the symbol name.
    static func cursor(symbolName: String, fallback: NSCursor) -> NSCursor {
        if let cached = cache[symbolName] { return cached }
        guard let image = image(symbolName: symbolName) else { return fallback }
        // Centred: these tools all act about the point under the pointer — the
        // pixel being windowed, the centre a rotation is measured from — so the
        // glyph's middle is the part the reader aims with.
        let cursor = NSCursor(
            image: image,
            hotSpot: NSPoint(x: image.size.width / 2, y: image.size.height / 2))
        cache[symbolName] = cursor
        return cursor
    }

    /// The symbol drawn as a pointer-sized image: white glyph, black outline.
    ///
    /// Two-tone because a pointer crosses everything the viewer can show. A
    /// black glyph vanishes over the air around a chest, a white one vanishes
    /// over the lung fields of an inverted study, and a DICOM viewer shows both
    /// within one drag. Drawing the glyph white over a black-stroked copy of
    /// itself is what the system cursors do, and it keeps the shape readable
    /// against any grey it happens to land on.
    private static func image(symbolName: String) -> NSImage? {
        // Medium, not semibold — the outline already thickens every stroke by
        // its own width on both sides, so the glyph must start a step lighter
        // than it would on a button to end up reading the same.
        let configuration = NSImage.SymbolConfiguration(
            pointSize: size - outlineWidth * 2, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }

        let glyphSize = symbol.size
        let canvas = NSSize(width: glyphSize.width + outlineWidth * 2,
                            height: glyphSize.height + outlineWidth * 2)
        let target = NSRect(origin: NSPoint(x: outlineWidth, y: outlineWidth),
                            size: glyphSize)

        // Each layer is tinted *before* being composited, not after. Tinting in
        // place with `.sourceAtop` over the whole canvas repaints every pixel
        // already drawn — the white glyph laid over the black rim recoloured the
        // rim as well, and the pointer came out a solid white shape that
        // disappeared over bright anatomy. Building each colour as its own image
        // keeps the two layers separate.
        let outline = tinted(symbol, with: .black)
        let glyph = tinted(symbol, with: .white)

        let image = NSImage(size: canvas)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        // The outline: the black copy stamped in eight directions, so the white
        // glyph on top lands inside a dark rim. Cheaper and more reliable than
        // asking Core Graphics to stroke a symbol's own path, which template
        // images do not expose.
        let offsets: [(CGFloat, CGFloat)] = [
            (-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)
        ]
        for (dx, dy) in offsets {
            outline.draw(in: target.offsetBy(dx: dx * outlineWidth, dy: dy * outlineWidth),
                         from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        glyph.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)

        return image
    }

    /// A copy of `symbol` painted in one flat colour, alpha preserved.
    ///
    /// The tint is confined to this image, which is what lets the outline and the
    /// glyph be composited as two independent layers.
    private static func tinted(_ symbol: NSImage, with colour: NSColor) -> NSImage {
        let copy = NSImage(size: symbol.size)
        copy.lockFocus()
        defer { copy.unlockFocus() }
        let bounds = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
        colour.set()
        bounds.fill(using: .sourceAtop)
        return copy
    }
}
#endif
