// PrintCellTextureCache.swift
// DICOMStudio
//
// DICOM Studio — GPU textures for the film preview's cells.
//
// The film preview is where a cell is *worked on*: window/level, zoom, pan,
// rotate and invert all run as drags over the picture, and every one of them used
// to re-render the cell on the CPU — decode-free but still a full windowing pass,
// an arrangement pass and a downscale per mouse delta. The GPU tile path exists
// precisely to remove that, and a preview being dragged has more claim on it than
// a tile sitting still.
//
// So this is `ViewerTileTextureCache`'s sibling, keyed for a print mark. It keys
// on what the shader cannot change — the file, the frame and the window — and
// nothing else: the arrangement is the display transform, so a zoom or a rotation
// re-draws a quad and re-renders nothing. Only a window change costs a render, and
// that one is a GPU dispatch rather than a pass over every pixel on the CPU.
//
// Textures are full-resolution GPU allocations, so only the film on screen holds
// them; paging to another film releases the last one's.

import Foundation
import DICOMPrintKit
import DICOMRenderKit

#if canImport(Metal)
import Metal

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintCellTextureCache {

    /// Textures in hand, by the mark state that produced them.
    private var textures: [String: DisplayFrameTexture] = [:]

    /// The last texture rendered for each mark, by identity rather than by state.
    ///
    /// A window/level drag changes the key on every delta, and the new texture
    /// takes a dispatch to arrive. Without a stand-in the cell would fall back to
    /// its CPU thumbnail for that moment — which is not merely a flicker: the
    /// thumbnail for the new window does not exist either, so a drag would kick off
    /// a CPU render per delta, the exact cost this path removes. The previous
    /// picture stands in instead, and is replaced the instant the new one lands.
    private var standIns: [String: DisplayFrameTexture] = [:]

    /// Marks that cannot be put on the GPU — a burned overlay plane, a window that
    /// only the CPU's auto-windowing can resolve, YBR pixels, no Metal device.
    /// Remembered so a cell falls to the CPU path once and stays there instead of
    /// re-attempting on every refresh.
    private var unavailable: Set<String> = []

    /// Renders in flight, so a cell is not rendered twice while it loads.
    private var inFlight: Set<String> = []

    /// The cells the preview is currently showing. A render that finishes after
    /// its film has been paged away is discarded rather than retained.
    private var live: Set<String> = []

    /// The marks the preview is currently showing, by identity.
    ///
    /// Separate from ``live`` because the two answer different questions. A
    /// window/level drag gives the cell a new key on every mouse event, so by
    /// the time a render lands its key is usually no longer live — but the
    /// *mark* still is, and its picture is still wanted. Judging those renders
    /// by key alone threw every one of them away and left the cell being dragged
    /// frozen on the picture it started from, while the cells beside it — whose
    /// windows move in rounded steps and so keep a key long enough — updated
    /// normally.
    private var liveIdentities: Set<String> = []

    public init() {}

    /// Whether the GPU cell path can run at all on this machine.
    public static var isAvailable: Bool {
        FrameRenderService.shared.displayRenderer != nil
    }

    /// The texture for a mark, or `nil` if it has never been rendered or cannot be
    /// shown on the GPU. A `nil` is the caller's cue to draw the CPU thumbnail.
    ///
    /// While a mark is being re-windowed the previous texture stands in, so the
    /// cell keeps showing the picture through the gesture.
    public func texture(for item: PrintSelectionItem) -> DisplayFrameTexture? {
        textures[Self.key(for: item)] ?? standIns[item.id]
    }

    /// The texture rendered for this exact state, with no stand-in.
    ///
    /// The stand-in exists so a cell does not blink during a drag; anything asking
    /// "has *this* window been rendered yet?" — a test, or a caller waiting for the
    /// picture to settle — must not be answered with the previous one.
    public func renderedTexture(for item: PrintSelectionItem) -> DisplayFrameTexture? {
        textures[Self.key(for: item)]
    }

    /// Whether this mark is known not to work on the GPU, so the caller can stop
    /// waiting and show its CPU thumbnail rather than a spinner.
    public func isUnavailable(_ item: PrintSelectionItem) -> Bool {
        unavailable.contains(Self.key(for: item))
    }

    /// Renders textures the given marks still need, and releases the rest.
    ///
    /// Pass only the marks on the film being shown. A hundred-image selection is
    /// a hundred full-resolution textures if this is handed the whole thing, and
    /// the preview draws one film at a time.
    public func refresh(for items: [PrintSelectionItem]) {
        live = Set(items.map { Self.key(for: $0) })
        liveIdentities = Set(items.map(\.id))

        textures = textures.filter { live.contains($0.key) }
        standIns = standIns.filter { liveIdentities.contains($0.key) }
        unavailable.formIntersection(live)
        inFlight.formIntersection(live)

        for item in items {
            let key = Self.key(for: item)
            guard textures[key] == nil,
                  !unavailable.contains(key),
                  !inFlight.contains(key) else { continue }

            inFlight.insert(key)
            Task { [weak self] in
                let rendered = await FrameRenderer.renderDisplayTexture(
                    path: item.filePath,
                    frameIndex: item.frameIndex,
                    windowCenter: item.windowCenter,
                    windowWidth: item.windowWidth,
                    windowSpace: item.windowSpace)
                guard let self else { return }
                self.inFlight.remove(key)
                // The film this cell was on may have been paged away, or the
                // mark taken off the film entirely, while it rendered.
                guard self.liveIdentities.contains(item.id) else { return }
                if let rendered {
                    // Only the state still on screen is worth the GPU
                    // allocation; a superseded window is not kept as a texture.
                    if self.live.contains(key) {
                        self.textures[key] = rendered
                    }
                    // It is still the best stand-in there is, though — one
                    // mouse event behind the drag rather than frozen at the
                    // window the drag began from.
                    self.standIns[item.id] = rendered
                } else if self.live.contains(key) {
                    self.unavailable.insert(key)
                    // Nothing to stand in for a cell the GPU will not take: it
                    // draws the CPU thumbnail, and a stale texture over that would
                    // be a picture of the wrong window.
                    self.standIns[item.id] = nil
                }
            }
        }
    }

    /// Forgets everything, e.g. when the preview closes.
    public func clear() {
        textures = [:]
        standIns = [:]
        unavailable = []
        inFlight = []
        liveIdentities = []
        live = []
    }

    /// Everything about a mark that changes its *pixels*.
    ///
    /// Deliberately not the arrangement. Zoom, pan, rotation, flip and inversion
    /// are the display shader's transform here, so including them would re-render
    /// a texture that did not need to change — the exact cost this path exists to
    /// remove. The window *space* is in the key because the same two numbers are
    /// two different pictures in stored values and in output units.
    static func key(for item: PrintSelectionItem) -> String {
        let centre = item.windowCenter.map { String($0) } ?? "-"
        let width = item.windowWidth.map { String($0) } ?? "-"
        let space = item.windowCenter == nil ? "-" : item.windowSpace.rawValue
        return "\(item.filePath)|\(item.frameIndex)|\(centre)|\(width)|\(space)"
    }
}

// MARK: - Geometry

/// Where a mark's picture lands in its cell, on the GPU path.
///
/// The film preview's promise is that a cell which looks right prints that way, so
/// the shader is given the *film's* geometry and not the viewer's. The region is
/// resolved by ``ViewerPresentation/visibleRegion(imageWidth:imageHeight:)`` — the
/// single place that decision is made, and the same call the print path makes —
/// and handed to the display transform, which fits and centres it exactly as the
/// printer fits it into an image box.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public enum PrintCellDisplay {

    /// The shader geometry for a mark over a frame of the given size.
    public static func presentation(
        for item: PrintSelectionItem, imageWidth: Int, imageHeight: Int
    ) -> DisplayPresentation {
        let arrangement = item.presentation
        let region = arrangement?.visibleRegion(imageWidth: imageWidth, imageHeight: imageHeight)
        return DisplayPresentation(
            // The angle itself, not the nearest quarter turn: the viewer's
            // rotate tool turns freely and the film now follows it.
            rotationDegrees: arrangement?.rotationDegrees ?? 0,
            flipHorizontal: arrangement?.flipHorizontal ?? false,
            flipVertical: arrangement?.flipVertical ?? false,
            invert: arrangement?.invert ?? false,
            // No region means the whole frame is on the film — which the transform
            // states as the frame's own rectangle rather than as a special case.
            sourceRegion: DisplayPresentation.SourceRegion(
                x: Double(region?.x ?? 0),
                y: Double(region?.y ?? 0),
                width: Double(region?.width ?? imageWidth),
                height: Double(region?.height ?? imageHeight))
        )
    }

    /// The size, in source pixels, of the picture this cell actually prints:
    /// the visible region, with its axes swapped on a quarter turn.
    ///
    /// This is what decides the picture's shape inside the cell, and so where the
    /// reader's annotations anchor — the margin either side of a fitted picture is
    /// not part of the image and the printer has no pixels there.
    public static func arrangedPixelSize(
        for item: PrintSelectionItem, imageWidth: Int, imageHeight: Int
    ) -> (width: Int, height: Int) {
        let arrangement = item.presentation
        let region = arrangement?.visibleRegion(imageWidth: imageWidth, imageHeight: imageHeight)
        let width = region?.width ?? imageWidth
        let height = region?.height ?? imageHeight
        guard let arrangement else { return (width, height) }
        // The turned box, so a freely rotated cell reports the shape the film
        // actually carries — corners of background included.
        let turned = arrangement.turnedSize(width: Double(width), height: Double(height))
        return (max(1, Int(turned.width.rounded())), max(1, Int(turned.height.rounded())))
    }
}
#endif
