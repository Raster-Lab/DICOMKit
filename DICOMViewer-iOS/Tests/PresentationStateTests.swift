// PresentationStateTests.swift
// DICOMViewer iOS - Presentation State Tests
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import XCTest
@testable import DICOMKit
@testable import DICOMCore

/// Tests for Presentation State functionality in the iOS Viewer
final class PresentationStateTests: XCTestCase {
    
    // MARK: - PresentationStateInfo Tests
    
    func testPresentationStateInfoCreation() {
        // Create a minimal GSPS for testing
        let gsps = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: .grayscaleSoftcopyPresentationStateStorage,
            instanceNumber: 1,
            presentationLabel: "Test Presentation State",
            presentationDescription: "A test presentation state",
            presentationCreationDate: DICOMDate(year: 2024, month: 6, day: 15),
            presentationCreationTime: nil,
            presentationCreatorsName: nil,
            referencedSeries: []
        )
        
        let info = PresentationStateInfo(from: gsps)
        
        XCTAssertEqual(info.id, "1.2.3.4.5")
        XCTAssertEqual(info.label, "Test Presentation State")
        XCTAssertEqual(info.description, "A test presentation state")
        XCTAssertNotNil(info.creationDate)
    }
    
    func testPresentationStateInfoWithNilLabel() {
        let gsps = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: .grayscaleSoftcopyPresentationStateStorage,
            instanceNumber: nil,
            presentationLabel: nil,
            presentationDescription: nil,
            presentationCreationDate: nil,
            presentationCreationTime: nil,
            presentationCreatorsName: nil,
            referencedSeries: []
        )
        
        let info = PresentationStateInfo(from: gsps)
        
        XCTAssertEqual(info.id, "1.2.3.4.5")
        XCTAssertEqual(info.label, "Presentation State") // Default label
        XCTAssertNil(info.description)
        XCTAssertNil(info.creationDate)
    }
    
    // MARK: - Display Shutter Tests
    
    func testRectangularShutterContains() {
        let shutter = DisplayShutter.rectangular(
            left: 10, right: 100, top: 20, bottom: 80,
            presentationValue: nil
        )
        
        // Inside the shutter
        XCTAssertTrue(shutter.contains(column: 50, row: 50))
        XCTAssertTrue(shutter.contains(column: 10, row: 20)) // Edge
        XCTAssertTrue(shutter.contains(column: 100, row: 80)) // Edge
        
        // Outside the shutter
        XCTAssertFalse(shutter.contains(column: 5, row: 50))
        XCTAssertFalse(shutter.contains(column: 105, row: 50))
        XCTAssertFalse(shutter.contains(column: 50, row: 15))
        XCTAssertFalse(shutter.contains(column: 50, row: 85))
    }
    
    func testCircularShutterContains() {
        let shutter = DisplayShutter.circular(
            centerColumn: 100, centerRow: 100, radius: 50,
            presentationValue: nil
        )
        
        // Inside the circle
        XCTAssertTrue(shutter.contains(column: 100, row: 100)) // Center
        XCTAssertTrue(shutter.contains(column: 100, row: 150)) // Edge
        XCTAssertTrue(shutter.contains(column: 130, row: 130)) // Inside
        
        // Outside the circle
        XCTAssertFalse(shutter.contains(column: 0, row: 0))
        XCTAssertFalse(shutter.contains(column: 100, row: 200))
        XCTAssertFalse(shutter.contains(column: 200, row: 100))
    }
    
    func testPolygonalShutterContains() {
        // Triangle shutter
        let vertices: [(column: Int, row: Int)] = [
            (column: 0, row: 0),
            (column: 100, row: 0),
            (column: 50, row: 100)
        ]
        let shutter = DisplayShutter.polygonal(vertices: vertices, presentationValue: nil)
        
        // Inside the triangle
        XCTAssertTrue(shutter.contains(column: 50, row: 30))
        
        // Outside the triangle
        XCTAssertFalse(shutter.contains(column: 0, row: 100))
        XCTAssertFalse(shutter.contains(column: 100, row: 100))
    }
    
    func testShutterPresentationValue() {
        let shutter = DisplayShutter.rectangular(
            left: 0, right: 100, top: 0, bottom: 100,
            presentationValue: 128
        )
        
        XCTAssertEqual(shutter.presentationValue, 128)
    }
    
    // MARK: - Graphic Object Tests
    
    func testGraphicObjectPointAccess() {
        let graphic = GraphicObject(
            type: .polyline,
            data: [10.0, 20.0, 30.0, 40.0, 50.0, 60.0],
            filled: false,
            units: .pixel
        )
        
        XCTAssertEqual(graphic.pointCount, 3)
        
        let point0 = graphic.point(at: 0)
        XCTAssertEqual(point0?.column, 10.0)
        XCTAssertEqual(point0?.row, 20.0)
        
        let point1 = graphic.point(at: 1)
        XCTAssertEqual(point1?.column, 30.0)
        XCTAssertEqual(point1?.row, 40.0)
        
        let point2 = graphic.point(at: 2)
        XCTAssertEqual(point2?.column, 50.0)
        XCTAssertEqual(point2?.row, 60.0)
        
        // Invalid index
        XCTAssertNil(graphic.point(at: 3))
        XCTAssertNil(graphic.point(at: -1))
    }
    
    func testGraphicObjectTypes() {
        XCTAssertEqual(PresentationGraphicType.point.rawValue, "POINT")
        XCTAssertEqual(PresentationGraphicType.polyline.rawValue, "POLYLINE")
        XCTAssertEqual(PresentationGraphicType.interpolated.rawValue, "INTERPOLATED")
        XCTAssertEqual(PresentationGraphicType.circle.rawValue, "CIRCLE")
        XCTAssertEqual(PresentationGraphicType.ellipse.rawValue, "ELLIPSE")
    }
    
    // MARK: - Graphic Layer Tests
    
    func testGraphicLayerCreation() {
        let layer = GraphicLayer(
            name: "ANNOTATIONS",
            order: 1,
            description: "Annotation layer",
            recommendedGrayscaleValue: 65535,
            recommendedRGBValue: (red: 65535, green: 0, blue: 0)
        )
        
        XCTAssertEqual(layer.name, "ANNOTATIONS")
        XCTAssertEqual(layer.order, 1)
        XCTAssertEqual(layer.description, "Annotation layer")
        XCTAssertEqual(layer.recommendedGrayscaleValue, 65535)
        XCTAssertEqual(layer.recommendedRGBValue?.red, 65535)
        XCTAssertEqual(layer.recommendedRGBValue?.green, 0)
        XCTAssertEqual(layer.recommendedRGBValue?.blue, 0)
    }
    
    func testGraphicLayerEquality() {
        let layer1 = GraphicLayer(name: "LAYER1", order: 1)
        let layer2 = GraphicLayer(name: "LAYER1", order: 1)
        let layer3 = GraphicLayer(name: "LAYER2", order: 2)
        
        XCTAssertEqual(layer1, layer2)
        XCTAssertNotEqual(layer1, layer3)
    }
    
    // MARK: - Text Object Tests
    
    func testTextObjectCreation() {
        let textObj = TextObject(
            text: "Sample annotation text",
            boundingBoxTopLeft: (column: 10.0, row: 20.0),
            boundingBoxBottomRight: (column: 200.0, row: 50.0),
            anchorPoint: (column: 5.0, row: 35.0),
            anchorPointVisible: true,
            boundingBoxUnits: .pixel,
            anchorPointUnits: .pixel
        )
        
        XCTAssertEqual(textObj.text, "Sample annotation text")
        XCTAssertEqual(textObj.boundingBoxTopLeft.column, 10.0)
        XCTAssertEqual(textObj.boundingBoxTopLeft.row, 20.0)
        XCTAssertEqual(textObj.boundingBoxBottomRight.column, 200.0)
        XCTAssertEqual(textObj.boundingBoxBottomRight.row, 50.0)
        XCTAssertEqual(textObj.anchorPoint?.column, 5.0)
        XCTAssertEqual(textObj.anchorPoint?.row, 35.0)
        XCTAssertTrue(textObj.anchorPointVisible)
    }
    
    // MARK: - Annotation Units Tests
    
    func testAnnotationUnits() {
        XCTAssertEqual(AnnotationUnits.pixel.rawValue, "PIXEL")
        XCTAssertEqual(AnnotationUnits.display.rawValue, "DISPLAY")
    }
    
    // MARK: - Spatial Transformation Tests
    
    func testSpatialTransformationHasTransformation() {
        let noTransform = SpatialTransformation(rotation: 0, horizontalFlip: false)
        XCTAssertFalse(noTransform.hasTransformation)
        
        let rotated = SpatialTransformation(rotation: 90, horizontalFlip: false)
        XCTAssertTrue(rotated.hasTransformation)
        
        let flipped = SpatialTransformation(rotation: 0, horizontalFlip: true)
        XCTAssertTrue(flipped.hasTransformation)
        
        let both = SpatialTransformation(rotation: 180, horizontalFlip: true)
        XCTAssertTrue(both.hasTransformation)
    }
    
    func testSpatialTransformationProperties() {
        let transform = SpatialTransformation(rotation: 90, horizontalFlip: true)
        
        XCTAssertEqual(transform.rotation, 90)
        XCTAssertTrue(transform.isFlipped)
        XCTAssertTrue(transform.isRotated)
    }
    
    // MARK: - GSPS Full Structure Tests
    
    func testGSPSWithAllModules() {
        let voiLUT = VOILUT.window(center: 128, width: 256, explanation: "Default", function: .linear)
        let presentationLUT = PresentationLUT.identity
        let spatialTransform = SpatialTransformation(rotation: 90, horizontalFlip: false)
        
        let graphicLayer = GraphicLayer(name: "LAYER1", order: 1)
        let graphicObject = GraphicObject(
            type: .polyline,
            data: [0, 0, 100, 100],
            filled: false,
            units: .pixel
        )
        let graphicAnnotation = GraphicAnnotation(
            layer: "LAYER1",
            referencedImages: [],
            graphicObjects: [graphicObject],
            textObjects: []
        )
        
        let shutter = DisplayShutter.rectangular(
            left: 10, right: 500, top: 10, bottom: 500,
            presentationValue: 0
        )
        
        let gsps = GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.6.7.8.9",
            sopClassUID: .grayscaleSoftcopyPresentationStateStorage,
            instanceNumber: 1,
            presentationLabel: "Full GSPS",
            presentationDescription: "Complete presentation state",
            presentationCreationDate: DICOMDate(year: 2024, month: 12, day: 25),
            presentationCreationTime: DICOMTime(hour: 12, minute: 30, second: 0, millisecond: 0),
            presentationCreatorsName: DICOMPersonName(familyName: "Doe", givenName: "John"),
            referencedSeries: [],
            modalityLUT: nil,
            voiLUT: voiLUT,
            presentationLUT: presentationLUT,
            spatialTransformation: spatialTransform,
            displayedArea: nil,
            graphicLayers: [graphicLayer],
            graphicAnnotations: [graphicAnnotation],
            shutters: [shutter]
        )
        
        XCTAssertEqual(gsps.sopInstanceUID, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(gsps.presentationLabel, "Full GSPS")
        XCTAssertNotNil(gsps.voiLUT)
        XCTAssertNotNil(gsps.presentationLUT)
        XCTAssertNotNil(gsps.spatialTransformation)
        XCTAssertEqual(gsps.graphicLayers.count, 1)
        XCTAssertEqual(gsps.graphicAnnotations.count, 1)
        XCTAssertEqual(gsps.shutters.count, 1)
    }
    
    // MARK: - VOI LUT Tests
    
    func testVOILUTWindow() {
        let voiLUT = VOILUT.window(center: 40, width: 400, explanation: "Abdomen", function: .linear)
        
        // Test window application
        let lowerBound = voiLUT.apply(to: 40 - 200) // Below window
        let center = voiLUT.apply(to: 40)           // At center
        let upperBound = voiLUT.apply(to: 40 + 200) // Above window
        
        XCTAssertEqual(lowerBound, 0.0, accuracy: 0.01)
        XCTAssertEqual(center, 0.5, accuracy: 0.01)
        XCTAssertEqual(upperBound, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Presentation LUT Tests
    
    func testPresentationLUTIdentity() {
        let lut = PresentationLUT.identity
        
        XCTAssertEqual(lut.apply(to: 0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(lut.apply(to: 0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(lut.apply(to: 1.0), 1.0, accuracy: 0.001)
    }
    
    func testPresentationLUTInverse() {
        let lut = PresentationLUT.inverse
        
        XCTAssertEqual(lut.apply(to: 0.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(lut.apply(to: 0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(lut.apply(to: 1.0), 0.0, accuracy: 0.001)
    }
    
    // MARK: - DICOMDate Formatting Tests
    
    func testDICOMDateFormatted() {
        let date = DICOMDate(year: 2024, month: 6, day: 15)
        let formatted = date.formatted()
        
        // The formatted string should contain the date info
        XCTAssertFalse(formatted.isEmpty)
    }
}
