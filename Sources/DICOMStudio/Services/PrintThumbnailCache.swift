// PrintThumbnailCache.swift
// DICOMStudio
//
// DICOM Studio — thumbnails of the marked images, for the film preview.
//
// The preview is meant to answer "is this the right film?", which numbered grey
// boxes cannot do. Each cell shows the frame as it will print: the mark's
// window, zoom/pan crop and orientation, rendered by the same `FrameRenderer`
// the viewer's tiles use.

import Foundation
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics

/// Renders and caches one thumbnail per marked frame.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintThumbnailCache {

    /// Longest edge of a cached thumbnail, in pixels.
    ///
    /// Holding full-size frames for a 100-image selection would cost hundreds of
    /// megabytes, but the cells are now where windowing is judged and adjusted —
    /// at 256 the grey levels a user is tuning are half-lost to downscaling — so
    /// the cap sits above a full-sheet cell rather than at a thumbnail's size.
    private static let maxDimension = 512

    private let store = FrameImageStore(maxDimension: maxDimension)

    public init() {}

    /// The thumbnail for a mark, or `nil` while it loads or if it failed.
    ///
    /// While a mark is being re-windowed or re-arranged the previous rendering
    /// stands in, so the cell keeps showing the image through the gesture rather
    /// than flickering to a spinner on every delta.
    public func image(for item: PrintSelectionItem) -> CGImage? {
        let request = Self.request(for: item)
        return store.image(forKey: request.key, identity: request.identity)
    }

    /// The thumbnail rendered for this exact arrangement, with no stand-in.
    ///
    /// The stand-in exists so a cell does not blink during a gesture; anything
    /// asking "has *this* arrangement been rendered yet?" — a test, or a caller
    /// waiting for the picture to settle — must not be answered with the
    /// previous one.
    public func renderedImage(for item: PrintSelectionItem) -> CGImage? {
        store.image(forKey: Self.request(for: item).key)
    }

    /// Whether this mark has been tried and could not be rendered.
    public func didFail(_ item: PrintSelectionItem) -> Bool {
        store.didFail(Self.request(for: item).key)
    }

    /// Renders any thumbnails the given marks still need, and drops thumbnails
    /// for marks that are no longer selected.
    public func refresh(for items: [PrintSelectionItem]) {
        store.refresh(items.map { Self.request(for: $0) })
    }

    /// Forgets everything, e.g. when the selection is cleared.
    public func clear() {
        store.clear()
    }

    /// A mark's render request.
    ///
    /// Keyed on the arrangement as well as the frame: two marks of the same
    /// frame at different zooms are different pictures, and keying on
    /// ``PrintSelectionItem/id`` alone would serve the first for both — which is
    /// exactly how a film preview ends up disagreeing with the viewer.
    private static func request(for item: PrintSelectionItem) -> FrameImageStore.Request {
        FrameImageStore.Request(
            path: item.filePath,
            frameIndex: item.frameIndex,
            windowCenter: item.windowCenter,
            windowWidth: item.windowWidth,
            windowSpace: item.windowSpace,
            presentation: item.presentation,
            identity: item.id)
    }
}
#endif
