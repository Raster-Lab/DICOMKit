//
// ViewerPresentationStateBridgeTests.swift
// DICOMPrintKit
//
// The bridge's contract is that a reader who saves a view and restores it is
// looking at the same picture. These are mostly capture→restore round trips
// rather than attribute checks: a Displayed Area that is written correctly but
// restores to the wrong zoom is still a bug the reader would see.
//

import XCTest
import DICOMCore
import DICOMKit
@testable import DICOMPrintKit

final class ViewerPresentationStateBridgeTests: XCTestCase {

    // MARK: - Fixtures

    private let imageWidth = 512
    private let imageHeight = 512
    private let viewportWidth: Double = 800
    private let viewportHeight: Double = 600

    private func captured(
        _ presentation: ViewerPresentation,
        windowCenter: Double? = 40,
        windowWidth: Double? = 400
    ) -> ViewerPresentationStateBridge.CapturedDisplay {
        ViewerPresentationStateBridge.capture(
            presentation: presentation,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            imageWidth: imageWidth,
            imageHeight: imageHeight)
    }

    /// Wraps captured display parameters into a state, as the save path does.
    private func state(
        from captured: ViewerPresentationStateBridge.CapturedDisplay
    ) -> GrayscalePresentationState {
        GrayscalePresentationState(
            sopInstanceUID: "1.2.3.99.1",
            presentationLabel: "Test",
            referencedSeries: [
                ReferencedSeries(
                    seriesInstanceUID: "1.2.3.6",
                    referencedImages: [
                        ReferencedImage(
                            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                            sopInstanceUID: "1.2.3.6.1")
                    ])
            ],
            voiLUT: captured.voiLUT,
            presentationLUT: captured.presentationLUT,
            spatialTransformation: captured.spatialTransformation,
            displayedArea: captured.displayedArea)
    }

    private func restored(
        _ presentation: ViewerPresentation
    ) -> ViewerPresentationStateBridge.RestoredDisplay {
        ViewerPresentationStateBridge.restore(
            state(from: captured(presentation)),
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight)
    }

    // MARK: - Window

    func test_capture_recordsWindow() {
        let result = captured(ViewerPresentation())

        guard case .window(let center, let width, _, _)? = result.voiLUT else {
            return XCTFail("expected a window VOI LUT")
        }
        XCTAssertEqual(center, 40)
        XCTAssertEqual(width, 400)
    }

    /// A viewport with no window applied falls back to the file's, so there is
    /// nothing of the reader's to record.
    func test_capture_omitsWindowWhenNoneApplied() {
        let result = captured(ViewerPresentation(), windowCenter: nil, windowWidth: nil)
        XCTAssertNil(result.voiLUT)
    }

    func test_capture_omitsWindowWhenWidthIsZero() {
        let result = captured(ViewerPresentation(), windowCenter: 40, windowWidth: 0)
        XCTAssertNil(result.voiLUT)
    }

    func test_roundTrip_preservesWindow() {
        let result = restored(ViewerPresentation())
        XCTAssertEqual(result.windowCenter, 40)
        XCTAssertEqual(result.windowWidth, 400)
    }

    // MARK: - Spatial transformation

    /// An untouched view states its orientation rather than omitting it.
    ///
    /// Changed deliberately from omitting it: a saved view has to be able to
    /// say "upright", because applying it to an image the reader has since
    /// turned must put that image back. Silence could not say that — see
    /// ``test_capture_statesAnUprightOrientationExplicitly``.
    func test_capture_statesIdentityTransformationForUntouchedView() {
        let result = captured(ViewerPresentation())
        XCTAssertEqual(result.spatialTransformation?.rotation, 0)
        XCTAssertEqual(result.spatialTransformation?.horizontalFlip, false)
    }

    func test_capture_recordsQuarterTurn() {
        let result = captured(ViewerPresentation(rotationDegrees: 90))
        XCTAssertEqual(result.spatialTransformation?.rotation, 90)
        XCTAssertEqual(result.spatialTransformation?.horizontalFlip, false)
    }

    func test_capture_recordsHorizontalFlip() {
        let result = captured(ViewerPresentation(flipHorizontal: true))
        XCTAssertEqual(result.spatialTransformation?.horizontalFlip, true)
        XCTAssertEqual(result.spatialTransformation?.rotation, 0)
    }

    /// GSPS has no vertical-flip attribute. Mirroring vertically is the same
    /// picture as mirroring horizontally and turning half a circle, and that is
    /// what has to be written.
    func test_capture_expressesVerticalFlipAsHorizontalPlusHalfTurn() {
        let result = captured(ViewerPresentation(flipVertical: true))
        XCTAssertEqual(result.spatialTransformation?.rotation, 180)
        XCTAssertEqual(result.spatialTransformation?.horizontalFlip, true)
    }

    /// Both flips together are a half turn with no mirroring left over.
    func test_capture_foldsBothFlipsIntoHalfTurn() {
        let result = captured(
            ViewerPresentation(flipHorizontal: true, flipVertical: true))
        XCTAssertEqual(result.spatialTransformation?.rotation, 180)
        XCTAssertEqual(result.spatialTransformation?.horizontalFlip, false)
    }

    func test_roundTrip_preservesRotation() {
        let result = restored(ViewerPresentation(rotationDegrees: 270))
        XCTAssertEqual(result.rotationDegrees, 270)
    }

    /// Every quarter turn, not just the ones that happen to be non-zero.
    ///
    /// A full turn normalises to 0°, which is the same orientation the image
    /// started in — so it has to round-trip as 0°, not as "no rotation stated".
    func test_roundTrip_preservesEveryQuarterTurn() {
        for degrees in [0.0, 90, 180, 270, 360] {
            let result = restored(ViewerPresentation(rotationDegrees: degrees))
            let expected = ViewerPresentation.normalized(degrees)
            XCTAssertEqual(
                result.rotationDegrees, expected,
                "\(degrees)° must come back as \(expected)°")
        }
    }

    /// An upright view is a statement, not an absence of one.
    ///
    /// This is what a saved view of an unrotated image has to do to an image
    /// the reader has since turned: put it back upright. A capture that writes
    /// no Spatial Transformation cannot say that.
    func test_capture_statesAnUprightOrientationExplicitly() {
        let result = captured(ViewerPresentation(rotationDegrees: 360))
        XCTAssertEqual(
            result.spatialTransformation?.rotation, 0,
            "a full turn is upright, and upright is a rotation worth stating")
    }

    // MARK: - Inversion

    func test_capture_recordsInversionAsInversePresentationLUT() {
        XCTAssertEqual(captured(ViewerPresentation(invert: true)).presentationLUT, .inverse)
        XCTAssertEqual(captured(ViewerPresentation()).presentationLUT, .identity)
    }

    func test_roundTrip_preservesInversion() {
        XCTAssertTrue(restored(ViewerPresentation(invert: true)).invert)
        XCTAssertFalse(restored(ViewerPresentation()).invert)
    }

    // MARK: - Displayed area

    /// A view showing the whole image has no displayed area worth storing — its
    /// absence restores as "fit the image", which is the default view.
    func test_capture_omitsDisplayedAreaForWholeImage() {
        let presentation = ViewerPresentation(
            zoom: 1, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        XCTAssertNil(captured(presentation).displayedArea)
    }

    func test_capture_recordsDisplayedAreaWhenZoomedIn() {
        let presentation = ViewerPresentation(
            zoom: 3, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let area = captured(presentation).displayedArea

        XCTAssertNotNil(area)
        // Zoomed 3× into a 512-pixel image, the visible strip is a fraction of it.
        XCTAssertLessThan(area?.width ?? .max, imageWidth)
    }

    /// Displayed Area is 1-based (PS3.3 C.10.4); the viewer's regions are not.
    func test_capture_writesOneBasedCoordinates() {
        let presentation = ViewerPresentation(
            zoom: 3, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let area = captured(presentation).displayedArea

        XCTAssertGreaterThanOrEqual(area?.topLeft.column ?? 0, 1)
        XCTAssertGreaterThanOrEqual(area?.topLeft.row ?? 0, 1)
    }

    func test_roundTrip_preservesZoom() {
        let presentation = ViewerPresentation(
            zoom: 3, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let result = restored(presentation)

        // Rounding through a pixel rectangle costs a little precision; the
        // reader must not be able to see it.
        XCTAssertEqual(result.zoom, 3, accuracy: 0.05)
    }

    func test_roundTrip_preservesZoomAndPanTogether() {
        let presentation = ViewerPresentation(
            zoom: 2.5, panX: 40, panY: -30,
            viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let result = restored(presentation)

        XCTAssertEqual(result.zoom, 2.5, accuracy: 0.05)
        XCTAssertEqual(result.panX, 40, accuracy: 2)
        XCTAssertEqual(result.panY, -30, accuracy: 2)
    }

    /// The point of storing a pixel rectangle rather than a zoom factor: the
    /// same state restores correctly into a viewport of a different size.
    func test_restore_adaptsZoomToADifferentViewport() {
        let presentation = ViewerPresentation(
            zoom: 2, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let saved = state(from: captured(presentation))

        let sameSize = ViewerPresentationStateBridge.restore(
            saved, imageWidth: imageWidth, imageHeight: imageHeight,
            viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let halfSize = ViewerPresentationStateBridge.restore(
            saved, imageWidth: imageWidth, imageHeight: imageHeight,
            viewportWidth: viewportWidth / 2, viewportHeight: viewportHeight / 2)

        // The same region of anatomy fills each viewport, so the zoom *factor*
        // stays the same while the pixels-per-point differ.
        XCTAssertEqual(sameSize.zoom, halfSize.zoom, accuracy: 0.05)
    }

    // MARK: - Degenerate input

    func test_restore_survivesEmptyState() {
        let empty = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.99.2",
            referencedSeries: [])
        let result = ViewerPresentationStateBridge.restore(
            empty, imageWidth: imageWidth, imageHeight: imageHeight,
            viewportWidth: viewportWidth, viewportHeight: viewportHeight)

        XCTAssertEqual(result.zoom, 1)
        XCTAssertEqual(result.panX, 0)
        XCTAssertEqual(result.rotationDegrees, 0)
        XCTAssertNil(result.windowCenter)
        XCTAssertFalse(result.invert)
    }

    func test_restore_survivesZeroSizedViewport() {
        let presentation = ViewerPresentation(
            zoom: 3, viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let result = ViewerPresentationStateBridge.restore(
            state(from: captured(presentation)),
            imageWidth: imageWidth, imageHeight: imageHeight,
            viewportWidth: 0, viewportHeight: 0)

        XCTAssertEqual(result.zoom, 1)
    }
}
