//
// HangingProtocolSerializerTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class HangingProtocolSerializerTests: XCTestCase {
    
    var serializer: HangingProtocolSerializer!
    
    override func setUp() {
        super.setUp()
        serializer = HangingProtocolSerializer()
    }
    
    // MARK: - Basic Serialization Tests
    
    func test_serialize_minimalProtocol() throws {
        let hangingProtocol = HangingProtocol(name: "Test Protocol")
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolName), "Test Protocol")
        XCTAssertEqual(dataSet.string(for: .hangingProtocolLevel), "USER")
        XCTAssertEqual(dataSet.uint16(for: .numberOfScreens), 1)
    }
    
    func test_serialize_completeProtocol() throws {
        let dateTime = DICOMDateTime(year: 2024, month: 1, day: 15)
        
        let hangingProtocol = HangingProtocol(
            name: "Complete Protocol",
            description: "Test description",
            level: .site,
            creator: "Dr. Smith",
            creationDateTime: dateTime,
            numberOfPriorsReferenced: 2,
            numberOfScreens: 2
        )
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolName), "Complete Protocol")
        XCTAssertEqual(dataSet.string(for: .hangingProtocolDescription), "Test description")
        XCTAssertEqual(dataSet.string(for: .hangingProtocolLevel), "SITE")
        XCTAssertEqual(dataSet.string(for: .hangingProtocolCreator), "Dr. Smith")
        XCTAssertNotNil(dataSet.string(for: .hangingProtocolCreationDateTime))
        XCTAssertEqual(dataSet.uint16(for: .numberOfPriorsReferenced), 2)
        XCTAssertEqual(dataSet.uint16(for: .numberOfScreens), 2)
    }
    
    func test_serialize_protocolLevel_site() throws {
        let hangingProtocol = HangingProtocol(name: "Test", level: .site)
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolLevel), "SITE")
    }
    
    func test_serialize_protocolLevel_group() throws {
        let hangingProtocol = HangingProtocol(name: "Test", level: .group)
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolLevel), "GROUP")
    }
    
    func test_serialize_protocolLevel_user() throws {
        let hangingProtocol = HangingProtocol(name: "Test", level: .user)
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolLevel), "USER")
    }
    
    // MARK: - Environment Serialization Tests
    
    func test_serialize_environments_empty() throws {
        let hangingProtocol = HangingProtocol(name: "Test", environments: [])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertNil(dataSet.sequence(for: .hangingProtocolEnvironmentSequence),
                     "Should not include empty environment sequence")
    }
    
    func test_serialize_environments_single() throws {
        let environment = HangingProtocolEnvironment(modality: "CT")
        let hangingProtocol = HangingProtocol(name: "Test", environments: [environment])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let envSequence = dataSet.sequence(for: .hangingProtocolEnvironmentSequence)
        XCTAssertNotNil(envSequence)
        XCTAssertEqual(envSequence?.count, 1)
        
        let envItem = envSequence?[0]
        XCTAssertEqual(envItem?.string(for: .modality), "CT")
    }
    
    func test_serialize_environments_multiple() throws {
        let env1 = HangingProtocolEnvironment(modality: "CT", laterality: nil)
        let env2 = HangingProtocolEnvironment(modality: "MR", laterality: "L")
        let hangingProtocol = HangingProtocol(name: "Test", environments: [env1, env2])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let envSequence = dataSet.sequence(for: .hangingProtocolEnvironmentSequence)
        XCTAssertEqual(envSequence?.count, 2)
        
        XCTAssertEqual(envSequence?[0].string(for: .modality), "CT")
        XCTAssertEqual(envSequence?[1].string(for: .modality), "MR")
        XCTAssertEqual(envSequence?[1].string(for: .laterality), "L")
    }
    
    // MARK: - User Group Serialization Tests
    
    func test_serialize_userGroups_empty() throws {
        let hangingProtocol = HangingProtocol(name: "Test", userGroups: [])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertNil(dataSet.string(for: .hangingProtocolUserGroupName))
    }
    
    func test_serialize_userGroups_single() throws {
        let hangingProtocol = HangingProtocol(name: "Test", userGroups: ["Radiology"])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertEqual(dataSet.string(for: .hangingProtocolUserGroupName), "Radiology")
    }
    
    // MARK: - Screen Definition Serialization Tests
    
    func test_serialize_screenDefinitions_empty() throws {
        let hangingProtocol = HangingProtocol(name: "Test", screenDefinitions: [])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertNil(dataSet.sequence(for: .nominalScreenDefinitionSequence))
    }
    
    func test_serialize_screenDefinitions_single() throws {
        let screen = ScreenDefinition(
            verticalPixels: 1080,
            horizontalPixels: 1920,
            minimumGrayscaleBitDepth: 8
        )
        let hangingProtocol = HangingProtocol(name: "Test", screenDefinitions: [screen])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let screenSequence = dataSet.sequence(for: .nominalScreenDefinitionSequence)
        XCTAssertNotNil(screenSequence)
        XCTAssertEqual(screenSequence?.count, 1)
        
        let screenItem = screenSequence?[0]
        XCTAssertEqual(screenItem?[.numberOfVerticalPixels]?.uint16Value, 1080)
        XCTAssertEqual(screenItem?[.numberOfHorizontalPixels]?.uint16Value, 1920)
    }
    
    // MARK: - Image Set Serialization Tests
    
    func test_serialize_imageSets_empty() throws {
        let hangingProtocol = HangingProtocol(name: "Test", imageSets: [])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertNil(dataSet.sequence(for: .imageSetsSequence))
    }
    
    func test_serialize_imageSets_single() throws {
        let imageSet = ImageSetDefinition(number: 1, label: "Primary")
        let hangingProtocol = HangingProtocol(name: "Test", imageSets: [imageSet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let imageSetSequence = dataSet.sequence(for: .imageSetsSequence)
        XCTAssertNotNil(imageSetSequence)
        XCTAssertEqual(imageSetSequence?.count, 1)
        
        let imageSetItem = imageSetSequence?[0]
        XCTAssertEqual(imageSetItem?[.imageSetNumber]?.uint16Value, 1)
        XCTAssertEqual(imageSetItem?.string(for: .imageSetLabel), "Primary")
    }
    
    func test_serialize_imageSetSelector() throws {
        let selector = ImageSetSelector(
            attribute: .modality,
            valueNumber: 1,
            operator: .equal,
            values: ["CT"],
            usageFlag: .match
        )
        let imageSet = ImageSetDefinition(number: 1, selectors: [selector])
        let hangingProtocol = HangingProtocol(name: "Test", imageSets: [imageSet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let imageSetSequence = dataSet.sequence(for: .imageSetsSequence)
        let imageSetItem = imageSetSequence?[0]
        let selectorSequence = imageSetItem?[.selectorSequence]?.sequenceItems
        
        XCTAssertNotNil(selectorSequence)
        XCTAssertEqual(selectorSequence?.count, 1)
    }
    
    // MARK: - Display Set Serialization Tests
    
    func test_serialize_displaySets_empty() throws {
        let hangingProtocol = HangingProtocol(name: "Test", displaySets: [])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        XCTAssertNil(dataSet.sequence(for: .displaySetsSequence))
    }
    
    func test_serialize_displaySets_single() throws {
        let displaySet = DisplaySet(number: 1, label: "Main View")
        let hangingProtocol = HangingProtocol(name: "Test", displaySets: [displaySet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let displaySetSequence = dataSet.sequence(for: .displaySetsSequence)
        XCTAssertNotNil(displaySetSequence)
        XCTAssertEqual(displaySetSequence?.count, 1)
        
        let displaySetItem = displaySetSequence?[0]
        XCTAssertEqual(displaySetItem?[.displaySetNumber]?.uint16Value, 1)
        XCTAssertEqual(displaySetItem?.string(for: .displaySetLabel), "Main View")
    }
    
    func test_serialize_imageBox_stack() throws {
        let imageBox = ImageBox(number: 1, layoutType: .stack, imageSetNumbers: [1])
        let displaySet = DisplaySet(number: 1, imageBoxes: [imageBox])
        let hangingProtocol = HangingProtocol(name: "Test", displaySets: [displaySet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let displaySetSequence = dataSet.sequence(for: .displaySetsSequence)
        let displaySetItem = displaySetSequence?[0]
        let imageBoxSequence = displaySetItem?[.imageBoxesSequence]?.sequenceItems
        
        XCTAssertNotNil(imageBoxSequence)
        XCTAssertEqual(imageBoxSequence?.count, 1)
        
        let imageBoxItem = imageBoxSequence?[0]
        XCTAssertEqual(imageBoxItem?[.imageBoxNumber]?.uint16Value, 1)
        XCTAssertEqual(imageBoxItem?.string(for: .imageBoxLayoutType), "STACK")
    }
    
    func test_serialize_imageBox_tiled() throws {
        let imageBox = ImageBox(
            number: 1,
            layoutType: .tiled,
            imageSetNumbers: [1, 2, 3, 4],
            tileHorizontalDimension: 2,
            tileVerticalDimension: 2
        )
        let displaySet = DisplaySet(number: 1, imageBoxes: [imageBox])
        let hangingProtocol = HangingProtocol(name: "Test", displaySets: [displaySet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let displaySetSequence = dataSet.sequence(for: .displaySetsSequence)
        let displaySetItem = displaySetSequence?[0]
        let imageBoxSequence = displaySetItem?[.imageBoxesSequence]?.sequenceItems
        let imageBoxItem = imageBoxSequence?[0]
        
        XCTAssertEqual(imageBoxItem?.string(for: .imageBoxLayoutType), "TILED")
        XCTAssertEqual(imageBoxItem?[.imageBoxTileHorizontalDimension]?.uint16Value, 2)
        XCTAssertEqual(imageBoxItem?[.imageBoxTileVerticalDimension]?.uint16Value, 2)
    }
    
    func test_serialize_displayOptions() throws {
        let options = DisplayOptions(
            patientOrientation: "L\\P",
            showGrayscaleInverted: true,
            showImageTrueSize: true,
            showGraphicAnnotations: false
        )
        let displaySet = DisplaySet(number: 1, displayOptions: options)
        let hangingProtocol = HangingProtocol(name: "Test", displaySets: [displaySet])
        
        let dataSet = try serializer.serialize(protocol: hangingProtocol)
        
        let displaySetSequence = dataSet.sequence(for: .displaySetsSequence)
        let displaySetItem = displaySetSequence?[0]
        
        XCTAssertEqual(displaySetItem?.string(for: .displaySetPatientOrientation), "L\\P")
        XCTAssertEqual(displaySetItem?.string(for: .showGrayscaleInverted), "Y")
        XCTAssertEqual(displaySetItem?.string(for: .showImageTrueSizeFlag), "Y")
        XCTAssertEqual(displaySetItem?.string(for: .showGraphicAnnotationFlag), "N")
    }
    
    // MARK: - Round-Trip Tests
    
    func test_roundTrip_minimalProtocol() throws {
        let originalProtocol = HangingProtocol(name: "Round Trip Test")
        
        let dataSet = try serializer.serialize(protocol: originalProtocol)
        let parser = HangingProtocolParser()
        let parsedProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(parsedProtocol.name, originalProtocol.name)
        XCTAssertEqual(parsedProtocol.level, originalProtocol.level)
        XCTAssertEqual(parsedProtocol.numberOfScreens, originalProtocol.numberOfScreens)
    }
    
    func test_roundTrip_completeProtocol() throws {
        let env = HangingProtocolEnvironment(modality: "CT", laterality: "L")
        let imageSet = ImageSetDefinition(number: 1, label: "Primary")
        let screen = ScreenDefinition(verticalPixels: 1080, horizontalPixels: 1920)
        let displaySet = DisplaySet(number: 1, label: "Main View")
        
        let originalProtocol = HangingProtocol(
            name: "Complete Protocol",
            description: "Full test",
            level: .site,
            creator: "Dr. Smith",
            environments: [env],
            userGroups: ["Radiology"],
            imageSets: [imageSet],
            numberOfScreens: 2,
            screenDefinitions: [screen],
            displaySets: [displaySet]
        )
        
        let dataSet = try serializer.serialize(protocol: originalProtocol)
        let parser = HangingProtocolParser()
        let parsedProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(parsedProtocol.name, originalProtocol.name)
        XCTAssertEqual(parsedProtocol.description, originalProtocol.description)
        XCTAssertEqual(parsedProtocol.level, originalProtocol.level)
        XCTAssertEqual(parsedProtocol.creator, originalProtocol.creator)
        XCTAssertEqual(parsedProtocol.environments.count, originalProtocol.environments.count)
        XCTAssertEqual(parsedProtocol.userGroups.count, originalProtocol.userGroups.count)
        XCTAssertEqual(parsedProtocol.imageSets.count, originalProtocol.imageSets.count)
        XCTAssertEqual(parsedProtocol.numberOfScreens, originalProtocol.numberOfScreens)
        XCTAssertEqual(parsedProtocol.screenDefinitions.count, originalProtocol.screenDefinitions.count)
        XCTAssertEqual(parsedProtocol.displaySets.count, originalProtocol.displaySets.count)
    }
    
    func test_roundTrip_environments() throws {
        let env1 = HangingProtocolEnvironment(modality: "CT")
        let env2 = HangingProtocolEnvironment(modality: "MR", laterality: "L")
        let originalProtocol = HangingProtocol(name: "Test", environments: [env1, env2])
        
        let dataSet = try serializer.serialize(protocol: originalProtocol)
        let parser = HangingProtocolParser()
        let parsedProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(parsedProtocol.environments.count, 2)
        XCTAssertEqual(parsedProtocol.environments[0].modality, "CT")
        XCTAssertEqual(parsedProtocol.environments[1].modality, "MR")
        XCTAssertEqual(parsedProtocol.environments[1].laterality, "L")
    }
    
    func test_roundTrip_displaySet_withImageBox() throws {
        let imageBox = ImageBox(
            number: 1,
            layoutType: .tiled,
            imageSetNumbers: [1, 2],
            tileHorizontalDimension: 2,
            tileVerticalDimension: 1
        )
        let displaySet = DisplaySet(number: 1, imageBoxes: [imageBox])
        let originalProtocol = HangingProtocol(name: "Test", displaySets: [displaySet])
        
        let dataSet = try serializer.serialize(protocol: originalProtocol)
        let parser = HangingProtocolParser()
        let parsedProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(parsedProtocol.displaySets.count, 1)
        XCTAssertEqual(parsedProtocol.displaySets[0].imageBoxes.count, 1)
        
        let parsedBox = parsedProtocol.displaySets[0].imageBoxes[0]
        XCTAssertEqual(parsedBox.number, 1)
        XCTAssertEqual(parsedBox.layoutType, .tiled)
        XCTAssertEqual(parsedBox.tileHorizontalDimension, 2)
        XCTAssertEqual(parsedBox.tileVerticalDimension, 1)
    }
}
