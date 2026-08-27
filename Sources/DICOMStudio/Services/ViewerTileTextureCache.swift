// ViewerTileTextureCache.swift
// DICOMStudio
//
// DICOM Studio — GPU textures for the viewer's unfocused tiles.
//
// The GPU counterpart to `ViewerTileImageCache`. Where that cache keys on a
// tile's *full* state — arrangement included, because the CPU bakes zoom, pan and
// rotation into pixels — this one keys only on what the shader cannot change:
// the file, the frame and the window. Everything else is the display shader's
// transform, so moving a tool re-draws a quad and re-renders nothing.
//
// That is the whole point of putting tiles on the GPU: a synchronised zoom or
// window drag across a grid costs one redraw per tile instead of one decode.

import Foundation
import DICOMPrintKit
import DICOMRenderKit

#if canImport(Metal)
import Metal

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class ViewerTileTextureCache {

    /// Textures in hand, by the state that produced them.
    private var textures: [String: DisplayFrameTexture] = [:]

    /// Tiles that could not be put on the GPU — overlay planes, an unresolvable
    /// window, no Metal device. Remembered so the tile falls to the CPU path once
    /// and stays there rather than re-attempting on every refresh.
    private var unavailable: Set<String> = []

    /// Renders in flight, so a tile is not rendered twice while it loads.
    private var inFlight: Set<String> = []

    /// The tiles the grid is currently showing. A render that finishes after its
    /// tile has gone is discarded against this rather than retained.
    private var live: Set<String> = []

    public init() {}

    /// Whether the GPU tile path can run at all on this machine.
    ///
    /// False on a device with no Metal support, where the grid keeps the CPU
    /// images it has always used.
    public static var isAvailable: Bool {
        FrameRenderService.shared.displayRenderer != nil
    }

    /// The texture for a tile, or `nil` while it loads or if it cannot be shown
    /// on the GPU. A `nil` is the caller's cue to draw the CPU image instead.
    public func texture(for cell: ViewerCellState) -> DisplayFrameTexture? {
        guard let key = Self.key(for: cell) else { return nil }
        return textures[key]
    }

    /// Whether this tile is known not to work on the GPU, so the caller can stop
    /// waiting and show its CPU image rather than a spinner.
    public func isUnavailable(for cell: ViewerCellState) -> Bool {
        guard let key = Self.key(for: cell) else { return true }
        return unavailable.contains(key)
    }

    /// Renders textures the given tiles still need, and releases the rest.
    ///
    /// Eviction matters more here than in the image cache: a texture is a
    /// full-resolution GPU allocation, and a grid that never let go of the frames
    /// it used to be showing would grow without bound as the user scrolls a
    /// series. Anything not in this call's tile set is dropped.
    public func refresh(for cells: [ViewerCellState]) {
        live = Set(cells.compactMap { Self.key(for: $0) })

        textures = textures.filter { live.contains($0.key) }
        unavailable.formIntersection(live)
        inFlight.formIntersection(live)

        for cell in cells {
            guard let key = Self.key(for: cell), let path = cell.filePath else { continue }
            guard textures[key] == nil,
                  !unavailable.contains(key),
                  !inFlight.contains(key) else { continue }

            inFlight.insert(key)
            Task { [weak self] in
                let rendered = await FrameRenderer.renderDisplayTexture(
                    path: path,
                    frameIndex: cell.frameIndex,
                    windowCenter: cell.windowCenter,
                    windowWidth: cell.windowWidth,
                    palette: cell.palette)
                guard let self else { return }
                self.inFlight.remove(key)
                // The grid may have moved on while this rendered; a texture for a
                // tile nobody is showing any more is dropped rather than retained.
                guard self.live.contains(key) else { return }
                if let rendered {
                    self.textures[key] = rendered
                } else {
                    self.unavailable.insert(key)
                }
            }
        }
    }

    /// Everything about a tile that changes its *pixels*.
    ///
    /// Deliberately not the arrangement. Zoom, pan, rotation, flip and inversion
    /// are the display shader's transform on this path, so including them would
    /// re-render a texture that did not need to change — the exact cost this path
    /// exists to remove.
    ///
    /// The palette *is* here, and is the one display choice that is: the shader
    /// can turn and crop a tile but it cannot colour one, so a palette is decided
    /// in the render. A key without it would hand back the previous colour's
    /// texture and leave the tile grey after the reader chose a ramp — the same
    /// bug `PrintCellTextureCache` records on the film side.
    private static func key(for cell: ViewerCellState) -> String? {
        guard let path = cell.filePath else { return nil }
        let centre = cell.windowCenter.map { String($0) } ?? "-"
        let width = cell.windowWidth.map { String($0) } ?? "-"
        let palette = cell.palette?.rawValue ?? "-"
        return "\(path)|\(cell.frameIndex)|\(centre)|\(width)|\(palette)"
    }
}
#endif
