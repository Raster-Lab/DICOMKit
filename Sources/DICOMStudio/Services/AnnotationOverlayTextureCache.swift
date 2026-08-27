// AnnotationOverlayTextureCache.swift
// DICOMStudio
//
// DICOM Studio — memoizes the main viewer's annotation overlay texture so it
// is rebuilt only on an actual edit, not on every SwiftUI body re-evaluation
// a pan or zoom drag triggers.

import Foundation
import DICOMPrintKit
import DICOMRenderKit

#if canImport(Metal)
import Metal

/// Deliberately not `@Observable`: it is read and written from inside a
/// computed property a view's `body` evaluates (`ImageViewerView
/// .annotationOverlayTexture`), and a write there to an `@Observable`
/// property could retrigger the very observation that produced the read,
/// which is not a cache, it is a re-render loop. A bare reference type has
/// no such hazard — SwiftUI never observes it, so touching it here cannot by
/// itself cause a re-render.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class AnnotationOverlayTextureCache {
    private var lastKey: ImageAnnotationKey?
    private var lastOverlays: [PrintOverlayAnnotation]?
    /// Part of the key, not a detail: the arrangement decides which way up the
    /// lettering is rasterized, so a texture built for an unturned picture is
    /// the wrong texture once the picture is turned. Left out, a rotation left
    /// the old, now-sideways words on screen until the annotations themselves
    /// were edited.
    private var lastOrientation: PrintOverlayOrientation?
    private var lastTexture: AnnotationOverlayTexture?

    /// The overlay for `key`'s `overlays`, rebuilding only when either has
    /// changed since the last call.
    ///
    /// `PrintOverlayAnnotation` is `Equatable`, so array equality is a
    /// cheap, correct "did anything actually change" check — this is what
    /// turns "recomputed on every read" into "regenerated on edit": a
    /// pan/zoom drag re-evaluates the view body and re-reads this, but
    /// `overlays` is unchanged on those reads, so the cached texture is
    /// returned as-is.
    func texture(
        for key: ImageAnnotationKey,
        overlays: [PrintOverlayAnnotation],
        width: Int,
        height: Int,
        device: MTLDevice,
        orientation: PrintOverlayOrientation? = nil
    ) -> AnnotationOverlayTexture? {
        if lastKey == key, lastOverlays == overlays,
           lastOrientation == orientation, let lastTexture {
            return lastTexture
        }
        let built = AnnotationTextureBuilder.build(
            overlays: overlays, width: width, height: height, device: device,
            orientation: orientation)
        lastKey = key
        lastOverlays = overlays
        lastOrientation = orientation
        lastTexture = built
        return built
    }
}

/// The grid's counterpart: one texture per tile image, so a 4×4 layout showing
/// several annotated images does not thrash a single memo slot.
///
/// Same non-`@Observable` rationale as above — read and written while tile
/// bodies evaluate. Entries for images no longer on any tile are pruned by
/// the caller's refresh, keyed the same way the tiles are.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class ViewerTileAnnotationTextureCache {

    private struct Entry {
        let overlays: [PrintOverlayAnnotation]
        let width: Int
        let height: Int
        /// Keyed on for the same reason the focused viewer's memo is: a tile
        /// that is turned needs its lettering re-rasterized level.
        let orientation: PrintOverlayOrientation?
        let texture: AnnotationOverlayTexture
    }

    private var entries: [ImageAnnotationKey: Entry] = [:]

    /// The overlay texture for one tile's image, or `nil` when nothing is
    /// drawn on it — the view then binds nothing and the shader's transparent
    /// placeholder stands in, costing no build at all for the common,
    /// unannotated tile.
    func texture(
        for key: ImageAnnotationKey,
        overlays: [PrintOverlayAnnotation],
        width: Int,
        height: Int,
        device: MTLDevice,
        orientation: PrintOverlayOrientation? = nil
    ) -> AnnotationOverlayTexture? {
        guard !overlays.isEmpty else {
            entries[key] = nil
            return nil
        }
        if let entry = entries[key], entry.overlays == overlays,
           entry.width == width, entry.height == height,
           entry.orientation == orientation {
            return entry.texture
        }
        guard let built = AnnotationTextureBuilder.build(
            overlays: overlays, width: width, height: height, device: device,
            orientation: orientation)
        else { return nil }
        entries[key] = Entry(
            overlays: overlays, width: width, height: height,
            orientation: orientation, texture: built)
        return built
    }

    /// Drops entries for images no longer shown, so a long session's grid
    /// changes do not accumulate textures.
    func prune(keeping keys: Set<ImageAnnotationKey>) {
        entries = entries.filter { keys.contains($0.key) }
    }
}
#endif
