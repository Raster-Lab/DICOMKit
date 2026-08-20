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
        device: MTLDevice
    ) -> AnnotationOverlayTexture? {
        if lastKey == key, lastOverlays == overlays, let lastTexture {
            return lastTexture
        }
        let built = AnnotationTextureBuilder.build(
            overlays: overlays, width: width, height: height, device: device)
        lastKey = key
        lastOverlays = overlays
        lastTexture = built
        return built
    }
}
#endif
