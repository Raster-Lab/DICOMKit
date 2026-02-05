//
// PseudoColorPresentationStateTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class PseudoColorPresentationStateTests: XCTestCase {
    
    // MARK: - ColorMapPreset Tests
    
    func test_colorMapPreset_grayscale() {
        let preset = ColorMapPreset.grayscale
        XCTAssertEqual(preset.rawValue, "grayscale")
    }
    
    func test_colorMapPreset_hot() {
        let preset = ColorMapPreset.hot
        XCTAssertEqual(preset.rawValue, "hot")
    }
    
    func test_colorMapPreset_cool() {
        let preset = ColorMapPreset.cool
        XCTAssertEqual(preset.rawValue, "cool")
    }
    
    func test_colorMapPreset_jet() {
        let preset = ColorMapPreset.jet
        XCTAssertEqual(preset.rawValue, "jet")
    }
    
    func test_colorMapPreset_bone() {
        let preset = ColorMapPreset.bone
        XCTAssertEqual(preset.rawValue, "bone")
    }
    
    func test_colorMapPreset_copper() {
        let preset = ColorMapPreset.copper
        XCTAssertEqual(preset.rawValue, "copper")
    }
    
    func test_colorMapPreset_allCases() {
        let allCases = ColorMapPreset.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.grayscale))
        XCTAssertTrue(allCases.contains(.hot))
        XCTAssertTrue(allCases.contains(.cool))
        XCTAssertTrue(allCases.contains(.jet))
        XCTAssertTrue(allCases.contains(.bone))
        XCTAssertTrue(allCases.contains(.copper))
    }
    
    func test_colorMapPreset_createLUT_grayscale() {
        let lut = ColorMapPreset.grayscale.createLUT()
        
        XCTAssertEqual(lut.redDescriptor.numberOfEntries, 256)
        XCTAssertEqual(lut.greenDescriptor.numberOfEntries, 256)
        XCTAssertEqual(lut.blueDescriptor.numberOfEntries, 256)
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertEqual(lut.greenLUT.count, 256)
        XCTAssertEqual(lut.blueLUT.count, 256)
    }
    
    func test_colorMapPreset_createLUT_hot() {
        let lut = ColorMapPreset.hot.createLUT()
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertGreaterThan(lut.redLUT.last ?? 0, 0)
        XCTAssertGreaterThan(lut.greenLUT.last ?? 0, 0)
    }
    
    func test_colorMapPreset_createLUT_cool() {
        let lut = ColorMapPreset.cool.createLUT()
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertGreaterThan(lut.blueLUT.last ?? 0, 0)
    }
    
    func test_colorMapPreset_createLUT_jet() {
        let lut = ColorMapPreset.jet.createLUT()
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertGreaterThan(lut.redLUT.last ?? 0, 0)
    }
    
    func test_colorMapPreset_createLUT_bone() {
        let lut = ColorMapPreset.bone.createLUT()
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertEqual(lut.greenLUT.count, 256)
        XCTAssertEqual(lut.blueLUT.count, 256)
    }
    
    func test_colorMapPreset_createLUT_copper() {
        let lut = ColorMapPreset.copper.createLUT()
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertGreaterThan(lut.greenLUT[128] ?? 0, 0)
    }
    
    // MARK: - PaletteColorLUT Extension Tests
    
    func test_paletteColorLUT_applyNormalized() {
        let lut = ColorMapPreset.grayscale.createLUT()
        let (r, g, b) = lut.applyNormalized(to: 128)
        
        XCTAssertGreaterThanOrEqual(r, 0.0)
        XCTAssertLessThanOrEqual(r, 1.0)
        XCTAssertGreaterThanOrEqual(g, 0.0)
        XCTAssertLessThanOrEqual(g, 1.0)
        XCTAssertGreaterThanOrEqual(b, 0.0)
        XCTAssertLessThanOrEqual(b, 1.0)
    }
    
    func test_paletteColorLUT_applyNormalized_grayscale() {
        let lut = ColorMapPreset.grayscale.createLUT()
        let (r, g, b) = lut.applyNormalized(to: 0)
        
        // Grayscale should have equal RGB components
        XCTAssertEqual(abs(r - g), 0, accuracy: 0.01)
        XCTAssertEqual(abs(g - b), 0, accuracy: 0.01)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
    }
    
    func test_paletteColorLUT_applyNormalized_grayscale_mid() {
        let lut = ColorMapPreset.grayscale.createLUT()
        let (r, g, b) = lut.applyNormalized(to: 128)
        
        // Grayscale mid-range should be approximately 0.5
        XCTAssertEqual(r, 0.5, accuracy: 0.1)
        XCTAssertEqual(g, 0.5, accuracy: 0.1)
        XCTAssertEqual(b, 0.5, accuracy: 0.1)
    }
    
    func test_paletteColorLUT_applyNormalized_grayscale_max() {
        let lut = ColorMapPreset.grayscale.createLUT()
        let (r, g, b) = lut.applyNormalized(to: 255)
        
        // Grayscale max should be white
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }
    
    func test_paletteColorLUT_preset_static_method() {
        let lut = PaletteColorLUT.preset(.hot)
        
        XCTAssertEqual(lut.redLUT.count, 256)
        XCTAssertEqual(lut.greenLUT.count, 256)
        XCTAssertEqual(lut.blueLUT.count, 256)
    }
    
    // MARK: - PseudoColorPresentationState Tests
    
    func test_pseudoColorPresentationState_minimal() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let lut = ColorMapPreset.grayscale.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut
        )
        
        XCTAssertEqual(ps.sopInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(ps.sopClassUID, "1.2.840.10008.5.1.4.1.1.11.3")
        XCTAssertEqual(ps.referencedSeries.count, 1)
        XCTAssertNil(ps.modalityLUT)
        XCTAssertNil(ps.voiLUT)
        XCTAssertNil(ps.spatialTransformation)
        XCTAssertNil(ps.displayedArea)
        XCTAssertTrue(ps.graphicLayers.isEmpty)
        XCTAssertTrue(ps.graphicAnnotations.isEmpty)
        XCTAssertTrue(ps.shutters.isEmpty)
    }
    
    func test_pseudoColorPresentationState_withHotColorMap() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let lut = ColorMapPreset.hot.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut
        )
        
        XCTAssertEqual(ps.paletteColorLUT.redLUT.count, 256)
    }
    
    func test_pseudoColorPresentationState_withJetColorMap() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let lut = ColorMapPreset.jet.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut
        )
        
        XCTAssertEqual(ps.paletteColorLUT.redLUT.count, 256)
    }
    
    func test_pseudoColorPresentationState_withIdentificationInfo() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let lut = ColorMapPreset.hot.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 2,
            presentationLabel: "Thermal Map",
            presentationDescription: "Heat map visualization",
            referencedSeries: [series],
            paletteColorLUT: lut
        )
        
        XCTAssertEqual(ps.instanceNumber, 2)
        XCTAssertEqual(ps.presentationLabel, "Thermal Map")
        XCTAssertEqual(ps.presentationDescription, "Heat map visualization")
    }
    
    func test_pseudoColorPresentationState_withModalityLUT() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let modalityLUT = ModalityLUT.rescale(slope: 1.0, intercept: 0.0, type: "US")
        let lut = ColorMapPreset.grayscale.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            modalityLUT: modalityLUT,
            paletteColorLUT: lut
        )
        
        XCTAssertNotNil(ps.modalityLUT)
    }
    
    func test_pseudoColorPresentationState_withVOILUT() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let voiLUT = VOILUT.window(
            center: 40.0,
            width: 100.0,
            explanation: "Window/Level",
            function: .linear
        )
        let lut = ColorMapPreset.hot.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            voiLUT: voiLUT,
            paletteColorLUT: lut
        )
        
        XCTAssertNotNil(ps.voiLUT)
    }
    
    func test_pseudoColorPresentationState_withModalityAndVOILUT() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let modalityLUT = ModalityLUT.rescale(slope: 0.5, intercept: -32768.0, type: "CT")
        let voiLUT = VOILUT.window(
            center: 50.0,
            width: 400.0,
            explanation: "CT Window",
            function: .linear
        )
        let lut = ColorMapPreset.cool.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            modalityLUT: modalityLUT,
            voiLUT: voiLUT,
            paletteColorLUT: lut
        )
        
        XCTAssertNotNil(ps.modalityLUT)
        XCTAssertNotNil(ps.voiLUT)
    }
    
    func test_pseudoColorPresentationState_withSpatialTransformation() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let transform = SpatialTransformation(rotation: 270)
        let lut = ColorMapPreset.bone.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut,
            spatialTransformation: transform
        )
        
        XCTAssertNotNil(ps.spatialTransformation)
        XCTAssertEqual(ps.spatialTransformation?.rotation, 270)
    }
    
    func test_pseudoColorPresentationState_withGraphicLayers() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let layer = GraphicLayer(
            name: "Findings",
            order: 1,
            description: "Radiologist findings",
            recommendedRGBValue: (red: 255, green: 0, blue: 0)
        )
        let lut = ColorMapPreset.copper.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut,
            graphicLayers: [layer]
        )
        
        XCTAssertEqual(ps.graphicLayers.count, 1)
        XCTAssertEqual(ps.graphicLayers[0].name, "Findings")
        XCTAssertEqual(ps.graphicLayers[0].recommendedRGBValue?.red, 255)
    }
    
    func test_pseudoColorPresentationState_withGraphicAnnotations() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let graphic = GraphicObject(
            type: .point,
            data: [256.0, 256.0]
        )
        let annotation = GraphicAnnotation(
            layer: "Findings",
            referencedImages: [image],
            graphicObjects: [graphic]
        )
        let lut = ColorMapPreset.jet.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut,
            graphicAnnotations: [annotation]
        )
        
        XCTAssertEqual(ps.graphicAnnotations.count, 1)
        XCTAssertEqual(ps.graphicAnnotations[0].graphicObjects.count, 1)
    }
    
    func test_pseudoColorPresentationState_withShutters() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let shutter = DisplayShutter.polygonal(
            vertices: [
                (column: 100, row: 100),
                (column: 200, row: 100),
                (column: 200, row: 200),
                (column: 100, row: 200)
            ],
            presentationValue: 0
        )
        let lut = ColorMapPreset.hot.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut,
            shutters: [shutter]
        )
        
        XCTAssertEqual(ps.shutters.count, 1)
    }
    
    func test_pseudoColorPresentationState_multipleReferencedSeries() {
        let image1 = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let image2 = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.6"
        )
        let series1 = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image1]
        )
        let series2 = ReferencedSeries(
            seriesInstanceUID: "1.2.3.5",
            referencedImages: [image2]
        )
        let lut = ColorMapPreset.cool.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series1, series2],
            paletteColorLUT: lut
        )
        
        XCTAssertEqual(ps.referencedSeries.count, 2)
    }
    
    func test_pseudoColorPresentationState_withAllComponents() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let modalityLUT = ModalityLUT.rescale(slope: 1.0, intercept: 0.0, type: nil)
        let voiLUT = VOILUT.window(
            center: 128.0,
            width: 256.0,
            explanation: "Window",
            function: .linear
        )
        let transform = SpatialTransformation(rotation: 90)
        let layer = GraphicLayer(name: "Annotations", order: 1)
        let annotation = GraphicAnnotation(layer: "Annotations", referencedImages: [image])
        let shutter = DisplayShutter.circular(
            centerColumn: 256, centerRow: 256, radius: 150,
            presentationValue: 0
        )
        let lut = ColorMapPreset.hot.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 1,
            presentationLabel: "Full Pseudo-Color",
            presentationDescription: "Complete pseudo-color state",
            referencedSeries: [series],
            modalityLUT: modalityLUT,
            voiLUT: voiLUT,
            paletteColorLUT: lut,
            spatialTransformation: transform,
            graphicLayers: [layer],
            graphicAnnotations: [annotation],
            shutters: [shutter]
        )
        
        XCTAssertNotNil(ps.modalityLUT)
        XCTAssertNotNil(ps.voiLUT)
        XCTAssertNotNil(ps.spatialTransformation)
        XCTAssertEqual(ps.graphicLayers.count, 1)
        XCTAssertEqual(ps.graphicAnnotations.count, 1)
        XCTAssertEqual(ps.shutters.count, 1)
        XCTAssertEqual(ps.instanceNumber, 1)
        XCTAssertEqual(ps.presentationLabel, "Full Pseudo-Color")
    }
    
    func test_pseudoColorPresentationState_colorMapComparison() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        
        let grayscaleLUT = ColorMapPreset.grayscale.createLUT()
        let hotLUT = ColorMapPreset.hot.createLUT()
        
        let ps1 = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: grayscaleLUT
        )
        
        let ps2 = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.7",
            referencedSeries: [series],
            paletteColorLUT: hotLUT
        )
        
        XCTAssertNotEqual(ps1.sopInstanceUID, ps2.sopInstanceUID)
    }
    
    func test_pseudoColorPresentationState_sendable() {
        let image = ReferencedImage(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        let series = ReferencedSeries(
            seriesInstanceUID: "1.2.3.4",
            referencedImages: [image]
        )
        let lut = ColorMapPreset.grayscale.createLUT()
        
        let ps = PseudoColorPresentationState(
            sopInstanceUID: "1.2.3.4.5.6",
            referencedSeries: [series],
            paletteColorLUT: lut
        )
        
        // Verify that it's Sendable by using it in a concurrent context
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        queue.async {
            _ = ps.sopInstanceUID
            _ = ps.sopClassUID
        }
        
        queue.sync { }
    }
}
