// AnnotationTextureBuilder.swift
// DICOMStudio
//
// DICOM Studio — bridges a reader's drawn annotations (`DICOMPrintKit`) to
// the GPU texture the main viewer's Metal pipeline composites over a frame
// (`DICOMRenderKit`). Sibling to `PrintCellTextureCache`, which does the same
// kind of bridging for the frame texture itself: `DICOMRenderKit` and
// `DICOMPrintKit` do not depend on each other, so this lives in `DICOMStudio`,
// the one target that already depends on both.
//
// The actual drawing — halo, arrowhead geometry, text anchor — is
// `ImageAnnotationBurner`'s: this only turns its rasterized bytes into an
// `MTLTexture`. Keeping the drawing in one place is what makes the viewer's
// overlay a promise the print path can't quietly stop keeping.

import Foundation
import DICOMPrintKit
import DICOMRenderKit

#if canImport(Metal)
import Metal

public enum AnnotationTextureBuilder {

    /// Builds a texture of a mark's drawn annotations, the same pixel
    /// dimensions as the frame they overlay — so `PrintOverlayPoint`'s
    /// 0...1 image-normalized coordinates map onto it with no separate
    /// scale step at draw time.
    ///
    /// Never `nil` merely because `overlays` is empty or entirely blank: an
    /// all-transparent texture is still returned, so a caller does not need
    /// a separate "nothing to draw" branch before binding it to the shader.
    /// `nil` only on a genuine failure to allocate or rasterize.
    public static func build(
        overlays: [PrintOverlayAnnotation],
        width: Int,
        height: Int,
        device: MTLDevice
    ) -> AnnotationOverlayTexture? {
        guard let (bytes, bytesPerRow) = ImageAnnotationBurner.rasterizing(
            overlays: overlays, width: width, height: height) else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: bytes, bytesPerRow: bytesPerRow)
        return AnnotationOverlayTexture(texture: texture)
    }
}
#endif
