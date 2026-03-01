// PresentationStateViewModelTests.swift
// DICOMStudioTests
//
// Tests for PresentationStateViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("PresentationStateViewModel Tests")
struct PresentationStateViewModelTests {

    @Test("Initial state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialState() {
        let vm = PresentationStateViewModel()
        #expect(vm.availableGSPS.isEmpty)
        #expect(vm.activeGSPS == nil)
        #expect(vm.activeStateType == nil)
        #expect(!vm.isGSPSActive)
        #expect(!vm.isShutterActive)
        #expect(!vm.isEditingAnnotations)
        #expect(vm.annotationCount == 0)
    }

    @Test("Apply GSPS")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyGSPS() {
        let vm = PresentationStateViewModel()
        let annotation = GraphicAnnotation(graphicType: .point, points: [AnnotationPoint(x: 100, y: 100)])
        let gsps = GSPSModel(
            voiLUT: VOILUTTransform(windowCenter: 40, windowWidth: 80),
            graphicAnnotations: [annotation]
        )

        vm.applyGSPS(gsps)
        #expect(vm.isGSPSActive)
        #expect(vm.activeStateType == .grayscale)
        #expect(vm.editingAnnotations.count == 1)
    }

    @Test("Remove GSPS")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveGSPS() {
        let vm = PresentationStateViewModel()
        let gsps = GSPSModel()
        vm.applyGSPS(gsps)
        vm.removeGSPS()
        #expect(!vm.isGSPSActive)
        #expect(vm.activeStateType == nil)
        #expect(vm.editingAnnotations.isEmpty)
    }

    @Test("Effective window level from GSPS")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEffectiveWindowLevel() {
        let vm = PresentationStateViewModel()
        let gsps = GSPSModel(voiLUT: VOILUTTransform(windowCenter: 40, windowWidth: 80))
        vm.applyGSPS(gsps)

        let result = vm.effectiveWindowLevel(defaultCenter: 128, defaultWidth: 256)
        #expect(result.center == 40)
        #expect(result.width == 80)
    }

    @Test("Effective window level without GSPS returns defaults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultWindowLevel() {
        let vm = PresentationStateViewModel()
        let result = vm.effectiveWindowLevel(defaultCenter: 128, defaultWidth: 256)
        #expect(result.center == 128)
        #expect(result.width == 256)
    }

    @Test("Effective rotation")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEffectiveRotation() {
        let vm = PresentationStateViewModel()
        let gsps = GSPSModel(spatialTransformation: .rotate90)
        vm.applyGSPS(gsps)
        #expect(vm.effectiveRotation == 90.0)
    }

    @Test("Effective flip H")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEffectiveFlipH() {
        let vm = PresentationStateViewModel()
        let gsps = GSPSModel(spatialTransformation: .flipHorizontal)
        vm.applyGSPS(gsps)
        #expect(vm.effectiveFlipH)
    }

    @Test("Apply shutter")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyShutter() {
        let vm = PresentationStateViewModel()
        let shutter = ShutterModel(
            shapes: [.rectangular],
            rectangular: RectangularShutter(top: 50, bottom: 450, left: 50, right: 450)
        )
        vm.applyShutter(shutter)
        #expect(vm.isShutterActive)
    }

    @Test("Remove shutter")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveShutter() {
        let vm = PresentationStateViewModel()
        let shutter = ShutterModel(shapes: [.rectangular], rectangular: RectangularShutter(top: 50, bottom: 450, left: 50, right: 450))
        vm.applyShutter(shutter)
        vm.removeShutter()
        #expect(!vm.isShutterActive)
    }

    @Test("Set palette")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetPalette() {
        let vm = PresentationStateViewModel()
        vm.setPalette(.rainbow)
        #expect(vm.activePalette == .rainbow)
        #expect(vm.activeStateType == .pseudoColor)
    }

    @Test("Set blending opacity")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetBlendingOpacity() {
        let vm = PresentationStateViewModel()
        vm.setBlendingOpacity(0.7)
        #expect(abs(vm.blendingOpacity - 0.7) < 0.001)
        #expect(vm.activeStateType == .blending)
    }

    @Test("Annotation editing")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAnnotationEditing() {
        let vm = PresentationStateViewModel()
        vm.startAnnotationEditing()
        #expect(vm.isEditingAnnotations)

        let annotation = GraphicAnnotation(graphicType: .circle, points: [
            AnnotationPoint(x: 256, y: 256),
            AnnotationPoint(x: 356, y: 256)
        ])
        vm.addAnnotation(annotation)
        #expect(vm.editingAnnotations.count == 1)

        vm.selectAnnotation(annotation.id)
        #expect(vm.selectedAnnotationID == annotation.id)

        vm.removeAnnotation(annotation.id)
        #expect(vm.editingAnnotations.isEmpty)
        #expect(vm.selectedAnnotationID == nil)

        vm.stopAnnotationEditing()
        #expect(!vm.isEditingAnnotations)
    }

    @Test("Text annotation management")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTextAnnotations() {
        let vm = PresentationStateViewModel()
        let text = TextAnnotation(text: "Finding")
        vm.addTextAnnotation(text)
        #expect(vm.editingTextAnnotations.count == 1)
        #expect(vm.annotationCount == 1)

        vm.removeTextAnnotation(text.id)
        #expect(vm.editingTextAnnotations.isEmpty)
    }

    @Test("Display labels")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDisplayLabels() {
        let vm = PresentationStateViewModel()
        #expect(vm.activeStateLabel == "None")

        vm.setPalette(.hotIron)
        #expect(vm.activeStateLabel == "Pseudo-Color")
        #expect(vm.paletteLabel == "Hot Iron")
    }

    @Test("Blending opacity label")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testBlendingOpacityLabel() {
        let vm = PresentationStateViewModel()
        vm.setBlendingOpacity(0.75)
        #expect(vm.blendingOpacityLabel == "75%")
    }

    @Test("Load GSPS for image")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadGSPSForImage() {
        let vm = PresentationStateViewModel()
        let ref = ReferencedImage(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")
        let gsps1 = GSPSModel(referencedImages: [ref])
        let gsps2 = GSPSModel(referencedImages: [ReferencedImage(sopClassUID: "1.2.3", sopInstanceUID: "7.8.9")])

        vm.loadGSPS(allStates: [gsps1, gsps2], forImage: "4.5.6")
        #expect(vm.availableGSPS.count == 1)
    }

    @Test("Service injection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testServiceInjection() {
        let service = PresentationStateService()
        let vm = PresentationStateViewModel(presentationStateService: service)
        #expect(vm.presentationStateService === service)
    }
}
