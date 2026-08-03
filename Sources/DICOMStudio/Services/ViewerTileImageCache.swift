// ViewerTileImageCache.swift
// DICOMStudio
//
// DICOM Studio — rendered images for the viewer's unfocused tiles.
//
// The focused tile is the live view model and renders itself. The others are
// static: each shows its own file, frame, window and arrangement, re-rendered
// only when that state actually changes. Keying on the tile's full state means
// panning tile 2 does not re-decode tiles 1, 3 and 4.

import Foundation
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class ViewerTileImageCache {

    /// Longest edge of a tile image.
    ///
    /// Tiles are far larger than film thumbnails but still bounded: a 4×4 grid
    /// of full-resolution CT frames would be pointless work for a few hundred
    /// points of screen each.
    private static let maxDimension = 1024

    private let store = FrameImageStore(maxDimension: maxDimension)

    public init() {}

    /// The rendered image for a tile, or `nil` while it loads or if it failed.
    public func image(for cell: ViewerCellState) -> CGImage? {
        guard let request = Self.request(for: cell) else { return nil }
        return store.image(forKey: request.key)
    }

    /// Whether this tile's content could not be rendered.
    public func didFail(_ cell: ViewerCellState) -> Bool {
        guard let request = Self.request(for: cell) else { return false }
        return store.didFail(request.key)
    }

    /// Renders anything the given tiles still need, and forgets the rest.
    public func refresh(for cells: [ViewerCellState]) {
        store.refresh(cells.compactMap { Self.request(for: $0) })
    }

    /// A tile's render request, or `nil` for an empty tile.
    ///
    /// The same request the film preview builds, so a tile and its film cell can
    /// never disagree about what a given arrangement looks like.
    private static func request(for cell: ViewerCellState) -> FrameImageStore.Request? {
        guard let path = cell.filePath else { return nil }
        return FrameImageStore.Request(
            path: path,
            frameIndex: cell.frameIndex,
            windowCenter: cell.windowCenter,
            windowWidth: cell.windowWidth,
            presentation: cell.presentation)
    }
}
#endif
