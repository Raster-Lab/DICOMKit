import XCTest
@testable import DICOMRenderKit
import DICOMCore

#if canImport(Metal)
import Metal
#endif
#if canImport(MetalKit)
import MetalKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Milestone M5 of `GPU_RENDERING_PLAN.md`: the frame stays on the GPU and the tool
/// actions — zoom, pan, rotate, flip, invert — are applied by the display shader.
///
/// The plan's stated caution for this milestone is a real prior incident, not a
/// hypothetical: a `Canvas`-based viewer in this app blanked **every**
/// progressively-decoded J2K file because the canvas resolved to zero size under
/// `.aspectRatio`. The decode was correct; the view drew nothing, silently. An
/// `MTKView` has the same hazard class, so a zero-sized drawable is tested for
/// explicitly here rather than trusted not to happen.
final class MetalDisplayPathTests: XCTestCase {

    #if canImport(Metal) && canImport(CoreGraphics)

    private func requireRenderer() throws -> MetalFrameRenderer {
        guard let renderer = MetalFrameRenderer(minimumPixelCount: 0) else {
            throw XCTSkip("No Metal device on this machine")
        }
        return renderer
    }

    private func monochromeRequest(
        rows: Int = 64, columns: Int = 64, value: UInt16 = 30_000
    ) -> FrameRenderRequest {
        let descriptor = PixelDataDescriptor(
            rows: rows, columns: columns,
            bitsAllocated: 16, bitsStored: 16, highBit: 15, isSigned: false,
            samplesPerPixel: 1, photometricInterpretation: .monochrome2)
        var bytes = Data(count: descriptor.bytesPerFrame)
        bytes.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: UInt16.self)
            for i in 0..<(rows * columns) { out[i] = value &+ UInt16(i % 1000) }
        }
        return FrameRenderRequest(
            pixelData: PixelData(data: bytes, descriptor: descriptor).pageAligned(),
            frameIndex: 0,
            window: WindowSettings(center: 32_768, width: 65_536))
    }

    // MARK: - Texture production

    func testDisplayTextureMatchesFrameDimensions() throws {
        let renderer = try requireRenderer()
        let texture = try XCTUnwrap(
            renderer.renderDisplayTexture(monochromeRequest(rows: 37, columns: 23)))
        XCTAssertEqual(texture.width, 23)
        XCTAssertEqual(texture.height, 37)
        XCTAssertTrue(texture.isGrayscale)
        XCTAssertEqual(texture.texture.pixelFormat, .r8Unorm)
    }

    /// The display texture is a *view* onto the compute output — the same bytes the
    /// `CGImage` path would return, at a padded row stride. Padding is why this
    /// compares row by row instead of whole buffers: the pad bytes are not pixels.
    func testDisplayTextureHoldsTheSamePixelsAsTheCGImagePath() throws {
        let renderer = try requireRenderer()
        let request = monochromeRequest(rows: 37, columns: 23)

        let image = try XCTUnwrap(renderer.renderFrame(request))
        let imageBytes = [UInt8](try XCTUnwrap(image.dataProvider?.data as Data?))

        let display = try XCTUnwrap(renderer.renderDisplayTexture(request))
        var textureBytes = [UInt8](repeating: 0, count: display.width * display.height)
        textureBytes.withUnsafeMutableBytes { raw in
            display.texture.getBytes(
                raw.baseAddress!, bytesPerRow: display.width,
                from: MTLRegionMake2D(0, 0, display.width, display.height), mipmapLevel: 0)
        }

        XCTAssertEqual(imageBytes.count, textureBytes.count)
        XCTAssertEqual(imageBytes, textureBytes,
                       "the display texture must carry exactly the CGImage path's pixels")
    }

    /// Colour frames become an RGBA texture, not a grey one.
    func testColorDisplayTextureIsRGBA() throws {
        let renderer = try requireRenderer()
        let descriptor = PixelDataDescriptor(
            rows: 16, columns: 16, bitsAllocated: 8, bitsStored: 8, highBit: 7,
            isSigned: false, samplesPerPixel: 3,
            photometricInterpretation: .rgb, planarConfiguration: 0)
        let bytes = Data((0..<descriptor.bytesPerFrame).map { UInt8($0 % 256) })
        let request = FrameRenderRequest(
            pixelData: PixelData(data: bytes, descriptor: descriptor).pageAligned())

        let texture = try XCTUnwrap(renderer.renderDisplayTexture(request))
        XCTAssertFalse(texture.isGrayscale)
        XCTAssertEqual(texture.texture.pixelFormat, .rgba8Unorm)
    }

    /// The display path must not inherit the CPU-wins size threshold: a frame headed
    /// for a GPU texture has no cheaper route, whatever its size.
    func testDisplayTextureIgnoresTheSizeThreshold() throws {
        guard let production = MetalFrameRenderer() else {
            throw XCTSkip("No Metal device on this machine")
        }
        let request = monochromeRequest(rows: 64, columns: 64)   // far under 1 MP
        XCTAssertNil(production.renderFrame(request), "the CGImage path applies the threshold")
        XCTAssertNotNil(production.renderDisplayTexture(request),
                        "the display path must not apply it")
    }

    // MARK: - The zero-drawable hazard

    /// A zero-sized drawable must be reported, not silently drawn into.
    ///
    /// This is the `Canvas` blanking bug's shape, transplanted to `MTKView`.
    func testZeroSizedDrawableIsRefusedAndFlagged() throws {
        guard let renderer = MetalImageRenderer() else {
            throw XCTSkip("No Metal device on this machine")
        }
        renderer.frame = try requireRenderer().renderDisplayTexture(monochromeRequest())

        let drew = renderer.render(size: .zero, descriptor: MTLRenderPassDescriptor(),
                                   drawable: nil)
        XCTAssertFalse(drew)
        XCTAssertTrue(renderer.lastDrawHadZeroSizedDrawable)
        XCTAssertEqual(renderer.drawCount, 0)
    }

    /// …and the same renderer must draw once the drawable has a size. Without this
    /// half, a renderer that never drew anything would pass the test above.
    func testNonZeroDrawableDraws() throws {
        guard let renderer = MetalImageRenderer(),
              let device = MetalRenderDevice.shared else {
            throw XCTSkip("No Metal device on this machine")
        }
        renderer.frame = try requireRenderer().renderDisplayTexture(monochromeRequest())

        let descriptor = MTLRenderPassDescriptor()
        let target = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: MetalImageRenderer.colorPixelFormat,
            width: 128, height: 128, mipmapped: false)
        target.usage = [.renderTarget, .shaderRead]
        descriptor.colorAttachments[0].texture =
            try XCTUnwrap(device.device.makeTexture(descriptor: target))
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store

        let drew = renderer.render(size: CGSize(width: 128, height: 128),
                                   descriptor: descriptor, drawable: nil)
        XCTAssertTrue(drew, "a sized drawable must produce a draw")
        XCTAssertFalse(renderer.lastDrawHadZeroSizedDrawable)
        XCTAssertEqual(renderer.drawCount, 1)
    }

    /// A renderer with no frame must not draw — and must not claim the drawable was
    /// the problem, or the zero-size flag would be useless for diagnosis.
    func testMissingFrameDoesNotDrawAndDoesNotBlameTheDrawable() throws {
        guard let renderer = MetalImageRenderer() else {
            throw XCTSkip("No Metal device on this machine")
        }
        renderer.frame = nil
        XCTAssertFalse(renderer.render(size: CGSize(width: 64, height: 64),
                                       descriptor: MTLRenderPassDescriptor(), drawable: nil))
        XCTAssertFalse(renderer.lastDrawHadZeroSizedDrawable)
    }

    #endif

    // MARK: - Presentation geometry
    //
    // Pure maths, no GPU — runs everywhere, including CI without a device.

    #if canImport(Metal)
    private func transform(
        _ presentation: DisplayPresentation,
        image: (Int, Int) = (100, 100), view: (Double, Double) = (200, 200)
    ) -> simd_float4x4? {
        presentation.transform(imageWidth: image.0, imageHeight: image.1,
                               viewWidth: view.0, viewHeight: view.1)
    }

    /// Degenerate inputs must return nil rather than divide by zero — the guard that
    /// makes the blanking case detectable.
    func testDegenerateGeometryReturnsNil() {
        XCTAssertNil(transform(.identity, image: (0, 100)))
        XCTAssertNil(transform(.identity, image: (100, 0)))
        XCTAssertNil(transform(.identity, view: (0, 200)))
        XCTAssertNil(transform(.identity, view: (200, 0)))
        XCTAssertNil(transform(DisplayPresentation(zoom: 0)))
    }

    /// A square image in a square view at zoom 1 fills it exactly.
    func testSquareImageFitsSquareView() throws {
        let matrix = try XCTUnwrap(transform(.identity))
        XCTAssertEqual(matrix.columns.0.x, 1, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.y, 1, accuracy: 1e-6)
    }

    /// A wide image in a square view is width-limited: full width, letterboxed.
    func testWideImageIsLetterboxed() throws {
        let matrix = try XCTUnwrap(transform(.identity, image: (200, 100)))
        XCTAssertEqual(matrix.columns.0.x, 1, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.y, 0.5, accuracy: 1e-6)
    }

    /// A tall image in a square view is height-limited: full height, pillarboxed.
    func testTallImageIsPillarboxed() throws {
        let matrix = try XCTUnwrap(transform(.identity, image: (100, 200)))
        XCTAssertEqual(matrix.columns.0.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.y, 1, accuracy: 1e-6)
    }

    func testZoomScalesBothAxes() throws {
        let matrix = try XCTUnwrap(transform(DisplayPresentation(zoom: 2)))
        XCTAssertEqual(matrix.columns.0.x, 2, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.y, 2, accuracy: 1e-6)
    }

    func testFlipsNegateTheCorrespondingAxis() throws {
        let horizontal = try XCTUnwrap(transform(DisplayPresentation(flipHorizontal: true)))
        XCTAssertEqual(horizontal.columns.0.x, -1, accuracy: 1e-6)
        XCTAssertEqual(horizontal.columns.1.y, 1, accuracy: 1e-6)

        let vertical = try XCTUnwrap(transform(DisplayPresentation(flipVertical: true)))
        XCTAssertEqual(vertical.columns.0.x, 1, accuracy: 1e-6)
        XCTAssertEqual(vertical.columns.1.y, -1, accuracy: 1e-6)
    }

    /// A quarter turn swaps the axes. Sign matters: it fixes the rotation direction,
    /// and a viewer that turned images the wrong way would be a visible bug.
    func testQuarterTurnSwapsAxes() throws {
        let matrix = try XCTUnwrap(transform(DisplayPresentation(rotationDegrees: 90)))
        XCTAssertEqual(matrix.columns.0.x, 0, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.y, 0, accuracy: 1e-6)
        // Clockwise on screen, with NDC y running upward.
        XCTAssertEqual(matrix.columns.0.y, -1, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.1.x, 1, accuracy: 1e-6)
    }

    /// Four quarter turns return to the identity — cheap proof the rotation composes.
    func testFullTurnIsIdentity() throws {
        let matrix = try XCTUnwrap(transform(DisplayPresentation(rotationDegrees: 360)))
        XCTAssertEqual(matrix.columns.0.x, 1, accuracy: 1e-5)
        XCTAssertEqual(matrix.columns.1.y, 1, accuracy: 1e-5)
        XCTAssertEqual(matrix.columns.0.y, 0, accuracy: 1e-5)
    }

    /// Pan is in view points and must land in NDC, where the view spans 2 units.
    /// Screen y grows downward while NDC y grows upward, so the sign flips.
    func testPanTranslatesInNormalisedDeviceCoordinates() throws {
        let matrix = try XCTUnwrap(
            transform(DisplayPresentation(panX: 50, panY: 50), view: (200, 200)))
        XCTAssertEqual(matrix.columns.3.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.3.y, -0.5, accuracy: 1e-6)
    }

    /// Panning must move the picture across the screen, not through its own rotated
    /// frame — a hand tool that dragged sideways when the image was turned 90° would
    /// feel broken.
    func testPanIsAppliedInScreenSpaceAfterRotation() throws {
        let matrix = try XCTUnwrap(
            transform(DisplayPresentation(panX: 50, rotationDegrees: 90), view: (200, 200)))
        XCTAssertEqual(matrix.columns.3.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(matrix.columns.3.y, 0, accuracy: 1e-6)
    }

    /// Invert is not geometry and must leave the matrix alone — it is a fragment-stage
    /// operation.
    func testInvertDoesNotAffectGeometry() throws {
        let plain = try XCTUnwrap(transform(.identity))
        let inverted = try XCTUnwrap(transform(DisplayPresentation(invert: true)))
        XCTAssertEqual(plain, inverted)
    }
    #endif
}
