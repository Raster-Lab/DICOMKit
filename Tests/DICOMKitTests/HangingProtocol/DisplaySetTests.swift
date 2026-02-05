//
// DisplaySetTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class DisplaySetTests: XCTestCase {
    
    // MARK: - DisplaySet Tests
    
    func test_displaySet_initialization_withRequiredParameters() {
        let displaySet = DisplaySet(number: 1)
        
        XCTAssertEqual(displaySet.number, 1)
        XCTAssertNil(displaySet.label)
        XCTAssertNil(displaySet.presentationGroup)
        XCTAssertNil(displaySet.presentationGroupDescription)
        XCTAssertNil(displaySet.partialDataHandling)
        XCTAssertNil(displaySet.scrollingGroup)
        XCTAssertEqual(displaySet.imageBoxes.count, 0)
    }
    
    func test_displaySet_initialization_withAllParameters() {
        let imageBox = ImageBox(number: 1, layoutType: .tiled, imageSetNumbers: [1, 2])
        let options = DisplayOptions(showGraphicAnnotations: true)
        
        let displaySet = DisplaySet(
            number: 1,
            label: "Main Display",
            presentationGroup: 1,
            presentationGroupDescription: "Primary View",
            partialDataHandling: "DISPLAY",
            scrollingGroup: 1,
            imageBoxes: [imageBox],
            displayOptions: options
        )
        
        XCTAssertEqual(displaySet.number, 1)
        XCTAssertEqual(displaySet.label, "Main Display")
        XCTAssertEqual(displaySet.presentationGroup, 1)
        XCTAssertEqual(displaySet.presentationGroupDescription, "Primary View")
        XCTAssertEqual(displaySet.partialDataHandling, "DISPLAY")
        XCTAssertEqual(displaySet.scrollingGroup, 1)
        XCTAssertEqual(displaySet.imageBoxes.count, 1)
    }
    
    func test_displaySet_multipleImageBoxes() {
        let box1 = ImageBox(number: 1, layoutType: .stack)
        let box2 = ImageBox(number: 2, layoutType: .tiled)
        
        let displaySet = DisplaySet(number: 1, imageBoxes: [box1, box2])
        
        XCTAssertEqual(displaySet.imageBoxes.count, 2)
        XCTAssertEqual(displaySet.imageBoxes[0].number, 1)
        XCTAssertEqual(displaySet.imageBoxes[1].number, 2)
    }
    
    // MARK: - ImageBox Tests
    
    func test_imageBox_initialization_withRequiredParameters() {
        let imageBox = ImageBox(number: 1)
        
        XCTAssertEqual(imageBox.number, 1)
        XCTAssertEqual(imageBox.layoutType, .stack)
        XCTAssertEqual(imageBox.imageSetNumbers.count, 0)
        XCTAssertNil(imageBox.tileHorizontalDimension)
        XCTAssertNil(imageBox.tileVerticalDimension)
        XCTAssertNil(imageBox.scrollDirection)
        XCTAssertNil(imageBox.smallScrollType)
        XCTAssertNil(imageBox.smallScrollAmount)
        XCTAssertNil(imageBox.largeScrollType)
        XCTAssertNil(imageBox.largeScrollAmount)
        XCTAssertNil(imageBox.overlapPriority)
        XCTAssertNil(imageBox.cineRelativeToRealTime)
        XCTAssertNil(imageBox.synchronizationGroup)
        XCTAssertNil(imageBox.reformattingOperation)
        XCTAssertNil(imageBox.threeDRenderingType)
    }
    
    func test_imageBox_stackLayout() {
        let imageBox = ImageBox(number: 1, layoutType: .stack, imageSetNumbers: [1])
        
        XCTAssertEqual(imageBox.layoutType, .stack)
        XCTAssertEqual(imageBox.imageSetNumbers, [1])
    }
    
    func test_imageBox_tiledLayout() {
        let imageBox = ImageBox(
            number: 1,
            layoutType: .tiled,
            imageSetNumbers: [1, 2, 3, 4],
            tileHorizontalDimension: 2,
            tileVerticalDimension: 2
        )
        
        XCTAssertEqual(imageBox.layoutType, .tiled)
        XCTAssertEqual(imageBox.tileHorizontalDimension, 2)
        XCTAssertEqual(imageBox.tileVerticalDimension, 2)
        XCTAssertEqual(imageBox.imageSetNumbers.count, 4)
    }
    
    func test_imageBox_tiledAllLayout() {
        let imageBox = ImageBox(number: 1, layoutType: .tiledAll)
        
        XCTAssertEqual(imageBox.layoutType, .tiledAll)
    }
    
    func test_imageBox_scrollSettings() {
        let imageBox = ImageBox(
            number: 1,
            scrollDirection: .vertical,
            smallScrollType: .image,
            smallScrollAmount: 1,
            largeScrollType: .page,
            largeScrollAmount: 10
        )
        
        XCTAssertEqual(imageBox.scrollDirection, .vertical)
        XCTAssertEqual(imageBox.smallScrollType, .image)
        XCTAssertEqual(imageBox.smallScrollAmount, 1)
        XCTAssertEqual(imageBox.largeScrollType, .page)
        XCTAssertEqual(imageBox.largeScrollAmount, 10)
    }
    
    func test_imageBox_synchronization() {
        let imageBox = ImageBox(number: 1, synchronizationGroup: 1)
        
        XCTAssertEqual(imageBox.synchronizationGroup, 1, "Should support synchronization")
    }
    
    func test_imageBox_cinePlayback() {
        let imageBox = ImageBox(number: 1, cineRelativeToRealTime: 1.5)
        
        XCTAssertEqual(imageBox.cineRelativeToRealTime, 1.5, "Should support cine playback speed")
    }
    
    // MARK: - ImageBoxLayoutType Tests
    
    func test_imageBoxLayoutType_rawValues() {
        XCTAssertEqual(ImageBoxLayoutType.stack.rawValue, "STACK")
        XCTAssertEqual(ImageBoxLayoutType.tiled.rawValue, "TILED")
        XCTAssertEqual(ImageBoxLayoutType.tiledAll.rawValue, "TILED_ALL")
    }
    
    func test_imageBoxLayoutType_fromString() {
        XCTAssertEqual(ImageBoxLayoutType(rawValue: "STACK"), .stack)
        XCTAssertEqual(ImageBoxLayoutType(rawValue: "TILED"), .tiled)
        XCTAssertEqual(ImageBoxLayoutType(rawValue: "TILED_ALL"), .tiledAll)
        XCTAssertNil(ImageBoxLayoutType(rawValue: "INVALID"))
    }
    
    // MARK: - ScrollDirection Tests
    
    func test_scrollDirection_rawValues() {
        XCTAssertEqual(ScrollDirection.horizontal.rawValue, "HORIZONTAL")
        XCTAssertEqual(ScrollDirection.vertical.rawValue, "VERTICAL")
    }
    
    // MARK: - ScrollType Tests
    
    func test_scrollType_rawValues() {
        XCTAssertEqual(ScrollType.image.rawValue, "IMAGE")
        XCTAssertEqual(ScrollType.fraction.rawValue, "FRACTION")
        XCTAssertEqual(ScrollType.page.rawValue, "PAGE")
    }
    
    func test_scrollType_fromString() {
        XCTAssertEqual(ScrollType(rawValue: "IMAGE"), .image)
        XCTAssertEqual(ScrollType(rawValue: "FRACTION"), .fraction)
        XCTAssertEqual(ScrollType(rawValue: "PAGE"), .page)
        XCTAssertNil(ScrollType(rawValue: "INVALID"))
    }
    
    // MARK: - ReformattingOperation Tests
    
    func test_reformattingOperation_mpr() {
        let operation = ReformattingOperation(
            type: .mpr,
            thickness: 5.0,
            interval: 2.5,
            initialViewDirection: "AXIAL"
        )
        
        XCTAssertEqual(operation.type, .mpr)
        XCTAssertEqual(operation.thickness, 5.0)
        XCTAssertEqual(operation.interval, 2.5)
        XCTAssertEqual(operation.initialViewDirection, "AXIAL")
    }
    
    func test_reformattingOperation_mip() {
        let operation = ReformattingOperation(type: .mip, thickness: 10.0)
        
        XCTAssertEqual(operation.type, .mip)
        XCTAssertEqual(operation.thickness, 10.0)
    }
    
    func test_reformattingOperation_cpr() {
        let operation = ReformattingOperation(type: .cpr)
        
        XCTAssertEqual(operation.type, .cpr)
        XCTAssertNil(operation.thickness)
    }
    
    // MARK: - ReformattingType Tests
    
    func test_reformattingType_allValues() {
        XCTAssertEqual(ReformattingType.mpr.rawValue, "MPR")
        XCTAssertEqual(ReformattingType.cpr.rawValue, "CPR")
        XCTAssertEqual(ReformattingType.mip.rawValue, "MIP")
        XCTAssertEqual(ReformattingType.minIP.rawValue, "MinIP")
        XCTAssertEqual(ReformattingType.avgIP.rawValue, "AvgIP")
    }
    
    func test_reformattingType_fromString() {
        XCTAssertEqual(ReformattingType(rawValue: "MPR"), .mpr)
        XCTAssertEqual(ReformattingType(rawValue: "MIP"), .mip)
        XCTAssertEqual(ReformattingType(rawValue: "MinIP"), .minIP)
        XCTAssertNil(ReformattingType(rawValue: "INVALID"))
    }
    
    // MARK: - ThreeDRenderingType Tests
    
    func test_threeDRenderingType_allValues() {
        XCTAssertEqual(ThreeDRenderingType.volumeRendering.rawValue, "VOLUME_RENDERING")
        XCTAssertEqual(ThreeDRenderingType.surfaceRendering.rawValue, "SURFACE_RENDERING")
        XCTAssertEqual(ThreeDRenderingType.mip.rawValue, "MIP")
    }
    
    func test_threeDRenderingType_fromString() {
        XCTAssertEqual(ThreeDRenderingType(rawValue: "VOLUME_RENDERING"), .volumeRendering)
        XCTAssertEqual(ThreeDRenderingType(rawValue: "SURFACE_RENDERING"), .surfaceRendering)
        XCTAssertEqual(ThreeDRenderingType(rawValue: "MIP"), .mip)
        XCTAssertNil(ThreeDRenderingType(rawValue: "INVALID"))
    }
    
    // MARK: - DisplayOptions Tests
    
    func test_displayOptions_initialization_defaults() {
        let options = DisplayOptions()
        
        XCTAssertNil(options.patientOrientation)
        XCTAssertNil(options.voiType)
        XCTAssertNil(options.pseudoColorType)
        XCTAssertFalse(options.showGrayscaleInverted)
        XCTAssertFalse(options.showImageTrueSize)
        XCTAssertTrue(options.showGraphicAnnotations)
        XCTAssertTrue(options.showPatientDemographics)
        XCTAssertTrue(options.showAcquisitionTechniques)
        XCTAssertNil(options.horizontalJustification)
        XCTAssertNil(options.verticalJustification)
    }
    
    func test_displayOptions_initialization_allParameters() {
        let options = DisplayOptions(
            patientOrientation: "L\\P",
            voiType: "LINEAR",
            pseudoColorType: "HOT_METAL",
            showGrayscaleInverted: true,
            showImageTrueSize: true,
            showGraphicAnnotations: false,
            showPatientDemographics: false,
            showAcquisitionTechniques: false,
            horizontalJustification: .center,
            verticalJustification: .top
        )
        
        XCTAssertEqual(options.patientOrientation, "L\\P")
        XCTAssertEqual(options.voiType, "LINEAR")
        XCTAssertEqual(options.pseudoColorType, "HOT_METAL")
        XCTAssertTrue(options.showGrayscaleInverted)
        XCTAssertTrue(options.showImageTrueSize)
        XCTAssertFalse(options.showGraphicAnnotations)
        XCTAssertFalse(options.showPatientDemographics)
        XCTAssertFalse(options.showAcquisitionTechniques)
        XCTAssertEqual(options.horizontalJustification, .center)
        XCTAssertEqual(options.verticalJustification, .top)
    }
    
    // MARK: - Justification Tests
    
    func test_justification_horizontalValues() {
        XCTAssertEqual(Justification.left.rawValue, "LEFT")
        XCTAssertEqual(Justification.center.rawValue, "CENTER")
        XCTAssertEqual(Justification.right.rawValue, "RIGHT")
    }
    
    func test_justification_verticalValues() {
        XCTAssertEqual(Justification.top.rawValue, "TOP")
        XCTAssertEqual(Justification.center.rawValue, "CENTER")
        XCTAssertEqual(Justification.bottom.rawValue, "BOTTOM")
    }
    
    func test_justification_fromString() {
        XCTAssertEqual(Justification(rawValue: "LEFT"), .left)
        XCTAssertEqual(Justification(rawValue: "CENTER"), .center)
        XCTAssertEqual(Justification(rawValue: "RIGHT"), .right)
        XCTAssertNil(Justification(rawValue: "INVALID"))
    }
}
