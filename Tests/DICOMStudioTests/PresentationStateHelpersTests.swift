// PresentationStateHelpersTests.swift
// DICOMStudioTests
//
// Tests for PresentationStateHelpers

import Testing
@testable import DICOMStudio
import Foundation

@Suite("PresentationStateHelpers VOI LUT Tests")
struct PresentationStateVOITests {

    @Test("Linear VOI - below window")
    func testLinearBelow() {
        let result = PresentationStateHelpers.applyLinearVOI(pixelValue: 0, center: 40, width: 80)
        #expect(result == 0.0)
    }

    @Test("Linear VOI - above window")
    func testLinearAbove() {
        let result = PresentationStateHelpers.applyLinearVOI(pixelValue: 100, center: 40, width: 80)
        #expect(result == 1.0)
    }

    @Test("Linear VOI - at center")
    func testLinearCenter() {
        let result = PresentationStateHelpers.applyLinearVOI(pixelValue: 40, center: 40, width: 80)
        #expect(result > 0.4)
        #expect(result < 0.6)
    }

    @Test("Linear VOI - zero width returns 0")
    func testLinearZeroWidth() {
        let result = PresentationStateHelpers.applyLinearVOI(pixelValue: 100, center: 40, width: 0)
        #expect(result == 0.0)
    }

    @Test("Sigmoid VOI - at center")
    func testSigmoidCenter() {
        let result = PresentationStateHelpers.applySigmoidVOI(pixelValue: 128, center: 128, width: 256)
        #expect(abs(result - 0.5) < 0.01)
    }

    @Test("Sigmoid VOI - far above center")
    func testSigmoidHigh() {
        let result = PresentationStateHelpers.applySigmoidVOI(pixelValue: 1000, center: 128, width: 256)
        #expect(result > 0.9)
    }

    @Test("Sigmoid VOI - zero width returns 0")
    func testSigmoidZeroWidth() {
        let result = PresentationStateHelpers.applySigmoidVOI(pixelValue: 100, center: 40, width: 0)
        #expect(result == 0.0)
    }

    @Test("Linear exact VOI - at center")
    func testLinearExactCenter() {
        let result = PresentationStateHelpers.applyLinearExactVOI(pixelValue: 40, center: 40, width: 80)
        #expect(abs(result - 0.5) < 0.01)
    }

    @Test("Apply VOI LUT dispatches to correct function")
    func testApplyVOIDispatch() {
        let linearResult = PresentationStateHelpers.applyVOILUT(
            pixelValue: 40,
            transform: VOILUTTransform(windowCenter: 40, windowWidth: 80, function: "LINEAR")
        )
        #expect(linearResult > 0.0)

        let sigmoidResult = PresentationStateHelpers.applyVOILUT(
            pixelValue: 128,
            transform: VOILUTTransform(windowCenter: 128, windowWidth: 256, function: "SIGMOID")
        )
        #expect(abs(sigmoidResult - 0.5) < 0.01)
    }
}

@Suite("PresentationStateHelpers Modality LUT Tests")
struct PresentationStateModalityTests {

    @Test("Identity modality LUT")
    func testIdentity() {
        let result = PresentationStateHelpers.applyModalityLUT(
            storedValue: 1000,
            transform: ModalityLUTTransform()
        )
        #expect(result == 1000.0)
    }

    @Test("CT Hounsfield units")
    func testHounsfieldUnits() {
        let result = PresentationStateHelpers.applyModalityLUT(
            storedValue: 1024,
            transform: ModalityLUTTransform(rescaleSlope: 1.0, rescaleIntercept: -1024.0)
        )
        #expect(result == 0.0)
    }
}

@Suite("PresentationStateHelpers Presentation LUT Tests")
struct PresentationStatePLUTTests {

    @Test("Identity LUT")
    func testIdentity() {
        let result = PresentationStateHelpers.applyPresentationLUT(value: 0.7, shape: .identity)
        #expect(result == 0.7)
    }

    @Test("Inverse LUT")
    func testInverse() {
        let result = PresentationStateHelpers.applyPresentationLUT(value: 0.7, shape: .inverse)
        #expect(abs(result - 0.3) < 0.001)
    }
}

@Suite("PresentationStateHelpers Spatial Transform Tests")
struct PresentationStateSpatialTests {

    @Test("No rotation angle")
    func testNoRotation() {
        #expect(PresentationStateHelpers.rotationAngle(for: .none) == 0.0)
    }

    @Test("90 degree rotation")
    func testRotate90() {
        #expect(PresentationStateHelpers.rotationAngle(for: .rotate90) == 90.0)
    }

    @Test("180 degree rotation")
    func testRotate180() {
        #expect(PresentationStateHelpers.rotationAngle(for: .rotate180) == 180.0)
    }

    @Test("270 degree rotation")
    func testRotate270() {
        #expect(PresentationStateHelpers.rotationAngle(for: .rotate270) == 270.0)
    }

    @Test("Horizontal flip detection")
    func testFlipH() {
        #expect(PresentationStateHelpers.isFlippedHorizontally(.flipHorizontal))
        #expect(PresentationStateHelpers.isFlippedHorizontally(.rotate90FlipH))
        #expect(!PresentationStateHelpers.isFlippedHorizontally(.none))
        #expect(!PresentationStateHelpers.isFlippedHorizontally(.rotate180))
    }

    @Test("Vertical flip detection")
    func testFlipV() {
        #expect(PresentationStateHelpers.isFlippedVertically(.flipVertical))
        #expect(!PresentationStateHelpers.isFlippedVertically(.none))
    }

    @Test("Point transformation - no transform")
    func testPointNoTransform() {
        let point = AnnotationPoint(x: 100, y: 200)
        let result = PresentationStateHelpers.transformPoint(
            point, transformation: .none, imageWidth: 512, imageHeight: 512
        )
        #expect(result.x == 100)
        #expect(result.y == 200)
    }

    @Test("Point transformation - flip horizontal")
    func testPointFlipH() {
        let point = AnnotationPoint(x: 100, y: 200)
        let result = PresentationStateHelpers.transformPoint(
            point, transformation: .flipHorizontal, imageWidth: 512, imageHeight: 512
        )
        #expect(result.x == 412) // 512 - 100
        #expect(result.y == 200)
    }
}

@Suite("PresentationStateHelpers Pipeline Tests")
struct PresentationStatePipelineTests {

    @Test("Full GSPS pipeline")
    func testFullPipeline() {
        let result = PresentationStateHelpers.applyGSPSPipeline(
            storedValue: 1064,
            modalityLUT: ModalityLUTTransform(rescaleSlope: 1.0, rescaleIntercept: -1024.0),
            voiLUT: VOILUTTransform(windowCenter: 40, windowWidth: 400),
            presentationLUTShape: .identity
        )
        // After modality LUT: 1064 - 1024 = 40 (center of window)
        #expect(result > 0.4)
        #expect(result < 0.6)
    }

    @Test("Pipeline with inverse LUT")
    func testPipelineInverse() {
        let identity = PresentationStateHelpers.applyGSPSPipeline(
            storedValue: 2048,
            modalityLUT: nil,
            voiLUT: VOILUTTransform(windowCenter: 2048, windowWidth: 4096),
            presentationLUTShape: .identity
        )
        let inverse = PresentationStateHelpers.applyGSPSPipeline(
            storedValue: 2048,
            modalityLUT: nil,
            voiLUT: VOILUTTransform(windowCenter: 2048, windowWidth: 4096),
            presentationLUTShape: .inverse
        )
        #expect(abs(identity + inverse - 1.0) < 0.01)
    }
}

@Suite("PresentationStateHelpers Display Text Tests")
struct PresentationStateDisplayTests {

    @Test("Type labels")
    func testTypeLabels() {
        #expect(PresentationStateHelpers.typeLabel(for: .grayscale) == "Grayscale (GSPS)")
        #expect(PresentationStateHelpers.typeLabel(for: .color) == "Color")
        #expect(PresentationStateHelpers.typeLabel(for: .pseudoColor) == "Pseudo-Color")
        #expect(PresentationStateHelpers.typeLabel(for: .blending) == "Blending")
    }

    @Test("Transform labels")
    func testTransformLabels() {
        #expect(PresentationStateHelpers.transformLabel(for: .none) == "None")
        #expect(PresentationStateHelpers.transformLabel(for: .rotate90) == "Rotate 90°")
    }

    @Test("LUT shape labels")
    func testLUTShapeLabels() {
        #expect(PresentationStateHelpers.lutShapeLabel(for: .identity) == "Identity")
        #expect(PresentationStateHelpers.lutShapeLabel(for: .inverse) == "Inverse")
    }
}
