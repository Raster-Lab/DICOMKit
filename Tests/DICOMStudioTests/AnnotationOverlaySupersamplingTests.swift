// AnnotationOverlaySupersamplingTests.swift
// DICOMStudioTests
//
// The resolution the viewer's GPU annotation overlay is rasterized at.
//
// The overlay is addressed in the same 0...1 texture coordinates as the frame,
// so its canvas may be any multiple of the frame's pixel grid — and it must be
// a multiple larger than 1 for small frames, because a 512-pixel CT fills a
// Retina viewport at several display pixels per frame pixel and type drawn at
// frame resolution arrives on screen visibly magnified. The cap is what keeps
// that from turning into a quadratic allocation on a frame that never needed
// it.

import Testing
@testable import DICOMStudio

#if canImport(Metal)
@Suite("Annotation Overlay Supersampling Tests")
struct AnnotationOverlaySupersamplingTests {

    @Test("A small frame is rasterized above its own resolution")
    func smallFrameIsSupersampled() {
        // The case that motivated this: type on a 512² CT was magnified
        // several-fold before it reached the screen.
        #expect(AnnotationTextureBuilder.supersamplingFactor(width: 512, height: 512) > 1)
        #expect(AnnotationTextureBuilder.supersamplingFactor(width: 256, height: 256) > 1)
    }

    @Test("The canvas never exceeds the dimension cap")
    func canvasStaysWithinCap() {
        for size in [64, 256, 512, 1024, 1400, 2048, 3000, 4096, 8192] {
            let factor = AnnotationTextureBuilder.supersamplingFactor(
                width: size, height: size)
            #expect(factor >= 1)
            // 4096 is the conservative floor for MTLDevice's 2D texture limit;
            // a canvas past it would fail to allocate rather than look worse.
            #expect(size * factor <= 4096 || factor == 1)
        }
    }

    @Test("A frame that already out-resolves the display is left alone")
    func largeFrameIsNotSupersampled() {
        // Magnification is not what a 3000-pixel frame suffers from, and
        // supersampling it would cost tens of megabytes for nothing.
        #expect(AnnotationTextureBuilder.supersamplingFactor(width: 3000, height: 3000) == 1)
    }

    @Test("The factor honours the longer side, not the area")
    func factorUsesLongerSide() {
        // A wide, short frame is capped by its width: keying off height alone
        // would allocate a canvas past the texture limit on one axis.
        let factor = AnnotationTextureBuilder.supersamplingFactor(width: 4000, height: 128)
        #expect(4000 * factor <= 4096 || factor == 1)
    }

    @Test("A degenerate frame asks for no scaling")
    func degenerateFrameIsUnscaled() {
        #expect(AnnotationTextureBuilder.supersamplingFactor(width: 0, height: 0) == 1)
        #expect(AnnotationTextureBuilder.supersamplingFactor(width: -10, height: 10) == 1)
    }
}
#endif
