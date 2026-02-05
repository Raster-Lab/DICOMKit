//
// HangingProtocolParserTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class HangingProtocolParserTests: XCTestCase {
    
    var parser: HangingProtocolParser!
    
    override func setUp() {
        super.setUp()
        parser = HangingProtocolParser()
    }
    
    // MARK: - Basic Parsing Tests
    
    func test_parse_minimalProtocol() throws {
        var dataSet = DataSet()
        dataSet[.hangingProtocolName] = DataElement.string(
            tag: .hangingProtocolName,
            vr: .LO,
            value: "Minimal Protocol"
        )
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.name, "Minimal Protocol")
        XCTAssertEqual(`protocol`.level, .user, "Should default to user level")
        XCTAssertEqual(`protocol`.numberOfScreens, 1, "Should default to 1 screen")
    }
    
    func test_parse_missingName_throwsError() {
        let dataSet = DataSet()
        
        XCTAssertThrowsError(try parser.parse(from: dataSet)) { error in
            guard let hpError = error as? HangingProtocolError else {
                XCTFail("Expected HangingProtocolError")
                return
            }
            
            if case .missingRequiredAttribute(let attr) = hpError {
                XCTAssertTrue(attr.contains("Name"), "Error should mention missing name")
            } else {
                XCTFail("Expected missingRequiredAttribute error")
            }
        }
    }
    
    func test_parse_completeProtocol() throws {
        var dataSet = DataSet()
        
        // Required attributes
        dataSet[.hangingProtocolName] = DataElement.string(tag: .hangingProtocolName, vr: .LO, value: "Complete Protocol")
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "SITE")
        
        // Optional attributes
        dataSet[.hangingProtocolDescription] = DataElement.string(tag: .hangingProtocolDescription, vr: .ST, value: "Test description")
        dataSet[.hangingProtocolCreator] = DataElement.string(tag: .hangingProtocolCreator, vr: .LO, value: "Dr. Smith")
        dataSet[.numberOfPriorsReferenced] = DataElement.uint16(tag: .numberOfPriorsReferenced, value: 2)
        dataSet[.numberOfScreens] = DataElement.uint16(tag: .numberOfScreens, value: 2)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.name, "Complete Protocol")
        XCTAssertEqual(`protocol`.description, "Test description")
        XCTAssertEqual(`protocol`.level, .site)
        XCTAssertEqual(`protocol`.creator, "Dr. Smith")
        XCTAssertEqual(`protocol`.numberOfPriorsReferenced, 2)
        XCTAssertEqual(`protocol`.numberOfScreens, 2)
    }
    
    func test_parse_protocolLevel_site() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "SITE")
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.level, .site)
    }
    
    func test_parse_protocolLevel_group() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "GROUP")
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.level, .group)
    }
    
    func test_parse_protocolLevel_user() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "USER")
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.level, .user)
    }
    
    // MARK: - Environment Parsing Tests
    
    func test_parse_environments_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.environments.count, 0, "Should have no environments")
    }
    
    func test_parse_environments_single() throws {
        var dataSet = createMinimalDataSet()
        
        var envItem = DataSet()
        envItem[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "CT")
        
        dataSet.setSequence([SequenceItem(elements: envItem.elements.map { $0.value })], for: .hangingProtocolEnvironmentSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.environments.count, 1)
        XCTAssertEqual(`protocol`.environments[0].modality, "CT")
    }
    
    func test_parse_environments_multiple() throws {
        var dataSet = createMinimalDataSet()
        
        var env1 = DataSet()
        env1[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "CT")
        
        var env2 = DataSet()
        env2[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "MR")
        env2[.laterality] = DataElement.string(tag: .laterality, vr: .CS, value: "L")
        
        dataSet.setSequence([
            SequenceItem(elements: env1.elements.map { $0.value }),
            SequenceItem(elements: env2.elements.map { $0.value })
        ], for: .hangingProtocolEnvironmentSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.environments.count, 2)
        XCTAssertEqual(`protocol`.environments[0].modality, "CT")
        XCTAssertEqual(`protocol`.environments[1].modality, "MR")
        XCTAssertEqual(`protocol`.environments[1].laterality, "L")
    }
    
    // MARK: - User Group Parsing Tests
    
    func test_parse_userGroups_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.userGroups.count, 0)
    }
    
    func test_parse_userGroups_single() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolUserGroupName] = DataElement.string(
            tag: .hangingProtocolUserGroupName,
            vr: .LO,
            value: "Radiology"
        )
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.userGroups.count, 1)
        XCTAssertEqual(`protocol`.userGroups[0], "Radiology")
    }
    
    // MARK: - Screen Definition Parsing Tests
    
    func test_parse_screenDefinitions_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.screenDefinitions.count, 0)
    }
    
    func test_parse_screenDefinitions_single() throws {
        var dataSet = createMinimalDataSet()
        
        var screenItem = DataSet()
        screenItem[.nominalScreenDefinitionVerticalPixels] = DataElement.uint16(
            tag: .nominalScreenDefinitionVerticalPixels,
            value: 1080
        )
        screenItem[.nominalScreenDefinitionHorizontalPixels] = DataElement.uint16(
            tag: .nominalScreenDefinitionHorizontalPixels,
            value: 1920
        )
        
        dataSet.setSequence([SequenceItem(elements: screenItem.elements.map { $0.value })], for: .nominalScreenDefinitionSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.screenDefinitions.count, 1)
        XCTAssertEqual(`protocol`.screenDefinitions[0].verticalPixels, 1080)
        XCTAssertEqual(`protocol`.screenDefinitions[0].horizontalPixels, 1920)
    }
    
    // MARK: - Image Set Parsing Tests
    
    func test_parse_imageSets_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.imageSets.count, 0)
    }
    
    func test_parse_imageSets_single() throws {
        var dataSet = createMinimalDataSet()
        
        var imageSetItem = DataSet()
        imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
        imageSetItem[.imageSetLabel] = DataElement.string(tag: .imageSetLabel, vr: .LO, value: "Primary")
        
        dataSet.setSequence([SequenceItem(elements: imageSetItem.elements.map { $0.value })], for: .imageSetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.imageSets.count, 1)
        XCTAssertEqual(`protocol`.imageSets[0].number, 1)
        XCTAssertEqual(`protocol`.imageSets[0].label, "Primary")
    }
    
    func test_parse_imageSetSelector_basic() throws {
        var dataSet = createMinimalDataSet()
        
        var selectorItem = DataSet()
        selectorItem[.selectorAttribute] = DataElement.attributeTag(tag: .selectorAttribute, value: .modality)
        selectorItem[.selectorValueNumber] = DataElement.uint16(tag: .selectorValueNumber, value: 1)
        
        var imageSetItem = DataSet()
        imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
        imageSetItem.setSequence([SequenceItem(elements: selectorItem.elements.map { $0.value })], for: .selectorSequence)
        
        dataSet.setSequence([SequenceItem(elements: imageSetItem.elements.map { $0.value })], for: .imageSetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.imageSets.count, 1)
        XCTAssertEqual(`protocol`.imageSets[0].selectors.count, 1)
        XCTAssertEqual(`protocol`.imageSets[0].selectors[0].attribute, .modality)
    }
    
    // MARK: - Display Set Parsing Tests
    
    func test_parse_displaySets_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.displaySets.count, 0)
    }
    
    func test_parse_displaySets_single() throws {
        var dataSet = createMinimalDataSet()
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem[.displaySetLabel] = DataElement.string(tag: .displaySetLabel, vr: .LO, value: "Main View")
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.elements.map { $0.value })], for: .displaySetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.displaySets.count, 1)
        XCTAssertEqual(`protocol`.displaySets[0].number, 1)
        XCTAssertEqual(`protocol`.displaySets[0].label, "Main View")
    }
    
    func test_parse_imageBox_stack() throws {
        var dataSet = createMinimalDataSet()
        
        var imageBoxItem = DataSet()
        imageBoxItem[.imageBoxNumber] = DataElement.uint16(tag: .imageBoxNumber, value: 1)
        imageBoxItem[.imageBoxLayoutType] = DataElement.string(tag: .imageBoxLayoutType, vr: .CS, value: "STACK")
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem.setSequence([SequenceItem(elements: imageBoxItem.elements.map { $0.value })], for: .imageBoxesSequence)
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.elements.map { $0.value })], for: .displaySetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        XCTAssertEqual(`protocol`.displaySets.count, 1)
        XCTAssertEqual(`protocol`.displaySets[0].imageBoxes.count, 1)
        XCTAssertEqual(`protocol`.displaySets[0].imageBoxes[0].layoutType, .stack)
    }
    
    func test_parse_imageBox_tiled() throws {
        var dataSet = createMinimalDataSet()
        
        var imageBoxItem = DataSet()
        imageBoxItem[.imageBoxNumber] = DataElement.uint16(tag: .imageBoxNumber, value: 1)
        imageBoxItem[.imageBoxLayoutType] = DataElement.string(tag: .imageBoxLayoutType, vr: .CS, value: "TILED")
        imageBoxItem[.imageBoxTileHorizontalDimension] = DataElement.uint16(tag: .imageBoxTileHorizontalDimension, value: 2)
        imageBoxItem[.imageBoxTileVerticalDimension] = DataElement.uint16(tag: .imageBoxTileVerticalDimension, value: 2)
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem.setSequence([SequenceItem(elements: imageBoxItem.elements.map { $0.value })], for: .imageBoxesSequence)
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.elements.map { $0.value })], for: .displaySetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        let imageBox = `protocol`.displaySets[0].imageBoxes[0]
        XCTAssertEqual(imageBox.layoutType, .tiled)
        XCTAssertEqual(imageBox.tileHorizontalDimension, 2)
        XCTAssertEqual(imageBox.tileVerticalDimension, 2)
    }
    
    func test_parse_displayOptions() throws {
        var dataSet = createMinimalDataSet()
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem[.displaySetPatientOrientation] = DataElement.string(tag: .displaySetPatientOrientation, vr: .CS, value: "L\\P")
        displaySetItem[.showGrayscaleInverted] = DataElement.string(tag: .showGrayscaleInverted, vr: .CS, value: "Y")
        displaySetItem[.showImageTrueSizeFlag] = DataElement.string(tag: .showImageTrueSizeFlag, vr: .CS, value: "Y")
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.elements.map { $0.value })], for: .displaySetsSequence)
        
        let `protocol` = try parser.parse(from: dataSet)
        
        let options = `protocol`.displaySets[0].displayOptions
        XCTAssertEqual(options.patientOrientation, "L\\P")
        XCTAssertTrue(options.showGrayscaleInverted)
        XCTAssertTrue(options.showImageTrueSize)
    }
    
    // MARK: - Error Tests
    
    func test_hangingProtocolError_missingRequiredAttribute() {
        let error = HangingProtocolError.missingRequiredAttribute("TestAttribute")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TestAttribute") ?? false)
    }
    
    func test_hangingProtocolError_invalidAttributeValue() {
        let error = HangingProtocolError.invalidAttributeValue("TestValue")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TestValue") ?? false)
    }
    
    func test_hangingProtocolError_parsingFailed() {
        let error = HangingProtocolError.parsingFailed("TestReason")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("TestReason") ?? false)
    }
    
    // MARK: - Helper Methods
    
    private func createMinimalDataSet() -> DataSet {
        var dataSet = DataSet()
        dataSet[.hangingProtocolName] = DataElement.string(
            tag: .hangingProtocolName,
            vr: .LO,
            value: "Test Protocol"
        )
        return dataSet
    }
}
