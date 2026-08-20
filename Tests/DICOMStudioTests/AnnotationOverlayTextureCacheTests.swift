// AnnotationOverlayTextureCacheTests.swift
// DICOMStudioTests
//
// The main viewer's annotation overlay must regenerate on an edit, not on
// every pan/zoom-driven redraw. `AnnotationOverlayTextureCache` is what
// enforces that — these tests hold it to "same key, same overlays" meaning
// "the same texture object, not rebuilt", and any real difference meaning a
// rebuild.

import XCTest
import DICOMPrintKit
import DICOMRenderKit
@testable import DICOMStudio

#if canImport(Metal)
import Metal

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
final class AnnotationOverlayTextureCacheTests: XCTestCase {

    private func requireDevice() throws -> MTLDevice {
        guard let device = MetalRenderDevice.shared?.device else {
            throw XCTSkip("No Metal device on this machine")
        }
        return device
    }

    func testUnchangedOverlaysReturnTheSameCachedTexture() throws {
        let device = try requireDevice()
        let cache = AnnotationOverlayTextureCache()
        let key = ImageAnnotationKey(filePath: "/a.dcm", frameIndex: 0)
        let overlays = [PrintOverlayAnnotation(
            kind: .arrow, start: PrintOverlayPoint(x: 0.1, y: 0.1), end: PrintOverlayPoint(x: 0.9, y: 0.9))]

        let first = try XCTUnwrap(cache.texture(
            for: key, overlays: overlays, width: 32, height: 32, device: device))

        // Read again — simulating a pan/zoom-driven body re-evaluation that
        // touches the cache but changes nothing about the annotations.
        let second = try XCTUnwrap(cache.texture(
            for: key, overlays: overlays, width: 32, height: 32, device: device))

        XCTAssertTrue(first.texture === second.texture,
                      "an unchanged read must return the exact cached texture, not rebuild it")
    }

    func testAnEditProducesANewTexture() throws {
        let device = try requireDevice()
        let cache = AnnotationOverlayTextureCache()
        let key = ImageAnnotationKey(filePath: "/a.dcm", frameIndex: 0)
        let before = [PrintOverlayAnnotation(
            kind: .arrow, start: PrintOverlayPoint(x: 0.1, y: 0.1), end: PrintOverlayPoint(x: 0.9, y: 0.9))]
        let after = before + [PrintOverlayAnnotation(
            kind: .text, start: PrintOverlayPoint(x: 0.5, y: 0.5), text: "lesion")]

        let first = try XCTUnwrap(cache.texture(
            for: key, overlays: before, width: 32, height: 32, device: device))
        let second = try XCTUnwrap(cache.texture(
            for: key, overlays: after, width: 32, height: 32, device: device))

        XCTAssertFalse(first.texture === second.texture,
                       "a real change to the overlays must produce a rebuilt texture")
    }

    func testADifferentImageProducesANewTexture() throws {
        let device = try requireDevice()
        let cache = AnnotationOverlayTextureCache()
        let overlays = [PrintOverlayAnnotation(
            kind: .arrow, start: PrintOverlayPoint(x: 0.1, y: 0.1), end: PrintOverlayPoint(x: 0.9, y: 0.9))]

        let first = try XCTUnwrap(cache.texture(
            for: ImageAnnotationKey(filePath: "/a.dcm", frameIndex: 0),
            overlays: overlays, width: 32, height: 32, device: device))
        let second = try XCTUnwrap(cache.texture(
            for: ImageAnnotationKey(filePath: "/b.dcm", frameIndex: 0),
            overlays: overlays, width: 32, height: 32, device: device))

        XCTAssertFalse(first.texture === second.texture,
                       "navigating to a different image must not reuse the previous one's texture")
    }
}
#endif
