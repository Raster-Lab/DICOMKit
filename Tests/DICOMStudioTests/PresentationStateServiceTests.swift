// PresentationStateServiceTests.swift
// DICOMStudioTests
//
// Tests for PresentationStateService

import Testing
@testable import DICOMStudio
import Foundation

@Suite("PresentationStateService GSPS Tests")
struct PresentationStateServiceGSPSTests {

    @Test("Apply GSPS window level override")
    func testApplyGSPSWindowLevel() {
        let service = PresentationStateService()
        let voi = VOILUTTransform(windowCenter: 40, windowWidth: 80)
        let gsps = GSPSModel(voiLUT: voi)

        let result = service.applyGSPSWindowLevel(gsps: gsps, currentCenter: 128, currentWidth: 256)
        #expect(result.center == 40)
        #expect(result.width == 80)
    }

    @Test("Apply GSPS with no VOI returns defaults")
    func testNoVOI() {
        let service = PresentationStateService()
        let gsps = GSPSModel()

        let result = service.applyGSPSWindowLevel(gsps: gsps, currentCenter: 128, currentWidth: 256)
        #expect(result.center == 128)
        #expect(result.width == 256)
    }

    @Test("GSPS references check")
    func testReferences() {
        let service = PresentationStateService()
        let ref = ReferencedImage(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let gsps = GSPSModel(referencedImages: [ref])

        #expect(service.gspsReferences(gsps: gsps, sopInstanceUID: "4.5.6"))
        #expect(!service.gspsReferences(gsps: gsps, sopInstanceUID: "7.8.9"))
    }

    @Test("Filter GSPS for image")
    func testFilterForImage() {
        let service = PresentationStateService()
        let ref1 = ReferencedImage(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let ref2 = ReferencedImage(sopClassUID: "1.2.3", sopInstanceUID: "7.8.9")

        let gsps1 = GSPSModel(referencedImages: [ref1])
        let gsps2 = GSPSModel(referencedImages: [ref2])
        let gsps3 = GSPSModel(referencedImages: [ref1, ref2])

        let result = service.gspsForImage(allStates: [gsps1, gsps2, gsps3], sopInstanceUID: "4.5.6")
        #expect(result.count == 2) // gsps1 and gsps3
    }
}

@Suite("PresentationStateService Creation Tests")
struct PresentationStateServiceCreationTests {

    @Test("Create GSPS with annotations")
    func testCreateGSPS() {
        let service = PresentationStateService()
        let annotation = GraphicAnnotation(graphicType: .point, points: [AnnotationPoint(x: 100, y: 100)])

        let gsps = service.createGSPS(
            referencingSOP: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            windowCenter: 40,
            windowWidth: 400,
            annotations: [annotation],
            label: "My GSPS"
        )

        #expect(gsps.referencedImages.count == 1)
        #expect(gsps.referencedImages[0].sopInstanceUID == "1.2.3.4.5")
        #expect(gsps.voiLUT?.windowCenter == 40)
        #expect(gsps.voiLUT?.windowWidth == 400)
        #expect(gsps.graphicAnnotations.count == 1)
        #expect(gsps.label == "My GSPS")
        #expect(gsps.creationDate != nil)
    }
}

@Suite("PresentationStateService Spatial Tests")
struct PresentationStateServiceSpatialTests {

    @Test("Effective rotation for GSPS")
    func testEffectiveRotation() {
        let service = PresentationStateService()
        let gsps = GSPSModel(spatialTransformation: .rotate90)
        #expect(service.effectiveRotation(gsps: gsps) == 90.0)
    }

    @Test("Effective flip H for GSPS")
    func testEffectiveFlipH() {
        let service = PresentationStateService()
        let gsps = GSPSModel(spatialTransformation: .flipHorizontal)
        #expect(service.effectiveFlipH(gsps: gsps))
    }

    @Test("No flip for default GSPS")
    func testNoFlip() {
        let service = PresentationStateService()
        let gsps = GSPSModel()
        #expect(!service.effectiveFlipH(gsps: gsps))
        #expect(!service.effectiveFlipV(gsps: gsps))
    }
}

@Suite("PresentationStateService PseudoColor Tests")
struct PresentationStateServiceColorTests {

    @Test("Color LUT for built-in palette")
    func testBuiltInPalette() {
        let service = PresentationStateService()
        let state = PseudoColorPresentationStateModel(palette: .hotIron)
        let lut = service.colorLUT(for: state)
        #expect(lut.count == 256)
    }

    @Test("Color LUT for custom palette")
    func testCustomPalette() {
        let service = PresentationStateService()
        let customLUT = [ColorEntry(red: 255, green: 0, blue: 0)]
        let state = PseudoColorPresentationStateModel(palette: .custom, customLUT: customLUT)
        let lut = service.colorLUT(for: state)
        #expect(lut.count == 1)
        #expect(lut[0].red == 255)
    }
}

@Suite("PresentationStateService Blending Tests")
struct PresentationStateServiceBlendingTests {

    @Test("Blending parameters with palette")
    func testBlendingParams() {
        let service = PresentationStateService()
        let state = BlendingPresentationStateModel(blendingOpacity: 0.7, overlayPalette: .pet)
        let params = service.blendingParameters(for: state)
        #expect(abs(params.opacity - 0.7) < 0.001)
        #expect(params.palette.count == 256)
    }

    @Test("Blending parameters without palette defaults to grayscale")
    func testBlendingDefaultPalette() {
        let service = PresentationStateService()
        let state = BlendingPresentationStateModel(blendingOpacity: 0.5)
        let params = service.blendingParameters(for: state)
        // Grayscale palette - all entries have r==g==b
        #expect(params.palette[128].red == params.palette[128].green)
    }
}
