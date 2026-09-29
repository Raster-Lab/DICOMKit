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
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.name, "Minimal Protocol")
        XCTAssertEqual(hangingProtocol.level, .user, "Should default to user level")
        XCTAssertEqual(hangingProtocol.numberOfScreens, 1, "Should default to 1 screen")
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
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.name, "Complete Protocol")
        XCTAssertEqual(hangingProtocol.description, "Test description")
        XCTAssertEqual(hangingProtocol.level, .site)
        XCTAssertEqual(hangingProtocol.creator, "Dr. Smith")
        XCTAssertEqual(hangingProtocol.numberOfPriorsReferenced, 2)
        XCTAssertEqual(hangingProtocol.numberOfScreens, 2)
    }
    
    func test_parse_protocolLevel_site() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "SITE")
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.level, .site)
    }
    
    func test_parse_protocolLevel_group() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "USER_GROUP")
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.level, .group)
    }
    
    func test_parse_protocolLevel_user() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolLevel] = DataElement.string(tag: .hangingProtocolLevel, vr: .CS, value: "USER")
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.level, .user)
    }
    
    // MARK: - Environment Parsing Tests
    
    func test_parse_environments_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.environments.count, 0, "Should have no environments")
    }
    
    func test_parse_environments_single() throws {
        var dataSet = createMinimalDataSet()
        
        var envItem = DataSet()
        envItem[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "CT")
        
        dataSet.setSequence([SequenceItem(elements: envItem.allElements)], for: .hangingProtocolDefinitionSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.environments.count, 1)
        XCTAssertEqual(hangingProtocol.environments[0].modality, "CT")
    }
    
    func test_parse_environments_multiple() throws {
        var dataSet = createMinimalDataSet()
        
        var env1 = DataSet()
        env1[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "CT")
        
        var env2 = DataSet()
        env2[.modality] = DataElement.string(tag: .modality, vr: .CS, value: "MR")
        env2[.laterality] = DataElement.string(tag: .laterality, vr: .CS, value: "L")
        
        dataSet.setSequence([
            SequenceItem(elements: env1.allElements),
            SequenceItem(elements: env2.allElements)
        ], for: .hangingProtocolDefinitionSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.environments.count, 2)
        XCTAssertEqual(hangingProtocol.environments[0].modality, "CT")
        XCTAssertEqual(hangingProtocol.environments[1].modality, "MR")
        XCTAssertEqual(hangingProtocol.environments[1].laterality, "L")
    }
    
    // MARK: - User Group Parsing Tests
    
    func test_parse_userGroups_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.userGroups.count, 0)
    }
    
    func test_parse_userGroups_single() throws {
        var dataSet = createMinimalDataSet()
        dataSet[.hangingProtocolUserGroupName] = DataElement.string(
            tag: .hangingProtocolUserGroupName,
            vr: .LO,
            value: "Radiology"
        )
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.userGroups.count, 1)
        XCTAssertEqual(hangingProtocol.userGroups[0], "Radiology")
    }
    
    // MARK: - Screen Definition Parsing Tests
    
    func test_parse_screenDefinitions_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.screenDefinitions.count, 0)
    }
    
    func test_parse_screenDefinitions_single() throws {
        var dataSet = createMinimalDataSet()
        
        var screenItem = DataSet()
        screenItem[.numberOfVerticalPixels] = DataElement.string(
            tag: .numberOfVerticalPixels,
            vr: .IS,
            value: "1080"
        )
        screenItem[.numberOfHorizontalPixels] = DataElement.string(
            tag: .numberOfHorizontalPixels,
            vr: .IS,
            value: "1920"
        )
        
        dataSet.setSequence([SequenceItem(elements: screenItem.allElements)], for: .nominalScreenDefinitionSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.screenDefinitions.count, 1)
        XCTAssertEqual(hangingProtocol.screenDefinitions[0].verticalPixels, 1080)
        XCTAssertEqual(hangingProtocol.screenDefinitions[0].horizontalPixels, 1920)
    }
    
    // MARK: - Image Set Parsing Tests
    
    func test_parse_imageSets_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.imageSets.count, 0)
    }
    
    func test_parse_imageSets_single() throws {
        var dataSet = createMinimalDataSet()
        
        var imageSetItem = DataSet()
        imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
        imageSetItem[.imageSetLabel] = DataElement.string(tag: .imageSetLabel, vr: .LO, value: "Primary")
        
        dataSet.setSequence([SequenceItem(elements: imageSetItem.allElements)], for: .imageSetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.imageSets.count, 1)
        XCTAssertEqual(hangingProtocol.imageSets[0].number, 1)
        XCTAssertEqual(hangingProtocol.imageSets[0].label, "Primary")
    }
    
    func test_parse_imageSetSelector_basic() throws {
        var dataSet = createMinimalDataSet()
        
        var selectorItem = DataSet()
        // Create attribute tag data element manually (AT VR)
        let writer = DICOMWriter()
        let attrTagData = writer.serializeTag(.modality)
        selectorItem[.selectorAttribute] = DataElement(tag: .selectorAttribute, vr: .AT, length: 4, valueData: attrTagData)
        selectorItem[.selectorValueNumber] = DataElement.uint16(tag: .selectorValueNumber, value: 1)
        selectorItem[.selectorAttributeVR] = DataElement.string(tag: .selectorAttributeVR, vr: .CS, value: "CS")
        selectorItem[.selectorCSValue] = DataElement.strings(tag: .selectorCSValue, vr: .CS, values: ["CT", "MR"])
        selectorItem[.imageSetSelectorUsageFlag] = DataElement.string(tag: .imageSetSelectorUsageFlag, vr: .CS, value: "NO_MATCH")
        
        var imageSetItem = DataSet()
        imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
        imageSetItem.setSequence([SequenceItem(elements: selectorItem.allElements)], for: .imageSetSelectorSequence)
        
        dataSet.setSequence([SequenceItem(elements: imageSetItem.allElements)], for: .imageSetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.imageSets.count, 1)
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors.count, 1)
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors[0].attribute, .modality)
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors[0].valueNumber, 1)
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors[0].attributeVR, .CS)
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors[0].values, ["CT", "MR"])
        XCTAssertEqual(hangingProtocol.imageSets[0].selectors[0].usageFlag, .noMatch)
    }
    
    /// Selector items written by earlier DICOMKit versions with EQUAL / NOT_EQUAL / CONTAINS /
    /// PRESENT / NOT_PRESENT in Filter-by Operator (0072,0406) still read, mapped to the
    /// PS3.3 2026a Table C.23.3-1 terms
    func test_parse_imageSetSelector_oldOperatorSpellings() throws {
        func parse(operator raw: String) throws -> ImageSetSelector? {
            var dataSet = createMinimalDataSet()
            var selectorItem = DataSet()
            let writer = DICOMWriter()
            selectorItem[.selectorAttribute] = DataElement(tag: .selectorAttribute, vr: .AT, length: 4, valueData: writer.serializeTag(.modality))
            selectorItem[.filterByOperator] = DataElement.string(tag: .filterByOperator, vr: .CS, value: raw)
            selectorItem[.imageSetSelectorUsageFlag] = DataElement.string(tag: .imageSetSelectorUsageFlag, vr: .CS, value: "MATCH")
            var imageSetItem = DataSet()
            imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
            imageSetItem.setSequence([SequenceItem(elements: selectorItem.allElements)], for: .imageSetSelectorSequence)
            dataSet.setSequence([SequenceItem(elements: imageSetItem.allElements)], for: .imageSetsSequence)
            return try parser.parse(from: dataSet).imageSets.first?.selectors.first
        }

        XCTAssertEqual(try parse(operator: "EQUAL")?.operator, .memberOf)
        XCTAssertEqual(try parse(operator: "NOT_EQUAL")?.operator, .notMemberOf)
        XCTAssertEqual(try parse(operator: "CONTAINS")?.operator, .memberOf)
        XCTAssertEqual(try parse(operator: "RANGE_INCL")?.operator, .rangeInclusive)

        let present = try parse(operator: "PRESENT")
        XCTAssertNil(present?.operator)
        XCTAssertEqual(present?.attributePresence, .present)
        let notPresent = try parse(operator: "NOT_PRESENT")
        XCTAssertNil(notPresent?.operator)
        XCTAssertEqual(notPresent?.attributePresence, .notPresent)
    }

    /// Old DICOMKit spellings of Sort-by Category (0072,0602) map to a Defined Term or to
    /// the attribute they named
    func test_parse_sortOperations_oldCategorySpellings() throws {
        func parse(category raw: String) throws -> SortOperation? {
            var dataSet = createMinimalDataSet()
            var sortItem = DataSet()
            sortItem[.sortByCategory] = DataElement.string(tag: .sortByCategory, vr: .CS, value: raw)
            sortItem[.sortingDirection] = DataElement.string(tag: .sortingDirection, vr: .CS, value: "INCREASING")
            var imageSetItem = DataSet()
            imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
            imageSetItem.setSequence([SequenceItem(elements: sortItem.allElements)], for: .sortingOperationsSequence)
            dataSet.setSequence([SequenceItem(elements: imageSetItem.allElements)], for: .imageSetsSequence)
            return try parser.parse(from: dataSet).imageSets.first?.sortOperations.first
        }

        XCTAssertEqual(try parse(category: "ALONG_AXIS")?.sortByCategory, .alongAxis)
        XCTAssertEqual(try parse(category: "BY_ACQ_TIME")?.sortByCategory, .byAcquisitionTime)
        XCTAssertEqual(try parse(category: "ACQUISITION_TIME")?.sortByCategory, .byAcquisitionTime)
        XCTAssertEqual(try parse(category: "IMAGE_POSITION")?.sortByCategory, .alongAxis)

        let inst = try parse(category: "INSTANCE_NUMBER")
        XCTAssertNil(inst?.sortByCategory)
        XCTAssertEqual(inst?.attribute, .instanceNumber)
        let slice = try parse(category: "SLICE_LOCATION")
        XCTAssertNil(slice?.sortByCategory)
        XCTAssertEqual(slice?.attribute, .sliceLocation)
        XCTAssertNil(try parse(category: "ATTRIBUTE"), "ATTRIBUTE without a Selector Attribute names nothing")
        XCTAssertNil(try parse(category: "INVALID"))
    }

    /// Abstract Prior Value (0072,003C) reads as SS VM 2; the SH text an earlier DICOMKit
    /// version wrote maps to 1\1 (MOST_RECENT) / -1\-1 (OLDEST); a single Relative Time
    /// value reads as n\n
    func test_parse_timeSelection_abstractPriorValue() throws {
        func parse(_ element: DataElement, relative: DataElement? = nil) throws -> TimeBasedSelection? {
            var dataSet = createMinimalDataSet()
            var imageSetItem = DataSet()
            imageSetItem[.imageSetNumber] = DataElement.uint16(tag: .imageSetNumber, value: 1)
            imageSetItem[element.tag] = element
            if let relative { imageSetItem[relative.tag] = relative }
            dataSet.setSequence([SequenceItem(elements: imageSetItem.allElements)], for: .imageSetsSequence)
            return try parser.parse(from: dataSet).imageSets.first?.timeSelection
        }

        let ss = try parse(DataElement.int16s(tag: .abstractPriorValue, values: [1, -1]),
                           relative: DataElement.uint16(tag: .relativeTime, value: 30))
        XCTAssertEqual(ss?.abstractPriorRange, [1, -1])
        XCTAssertEqual(ss?.relativeTimeRange, [30, 30])

        XCTAssertEqual(try parse(DataElement.string(tag: .abstractPriorValue, vr: .SH, value: "MOST_RECENT"))?.abstractPriorRange, [1, 1])
        XCTAssertEqual(try parse(DataElement.string(tag: .abstractPriorValue, vr: .SH, value: "OLDEST"))?.abstractPriorRange, [-1, -1])
        XCTAssertEqual(try parse(DataElement.string(tag: .abstractPriorValue, vr: .SH, value: "2"))?.abstractPriorRange, [2, 2])
        XCTAssertNil(try parse(DataElement.string(tag: .abstractPriorValue, vr: .SH, value: "SOMETHING")))
    }

    /// Partial Data Display Handling (0072,0208) written inside a Display Sets Sequence item
    /// by an earlier DICOMKit version is read into the top-level property
    func test_parse_partialDataDisplayHandling_legacyPlacement() throws {
        var dataSet = createMinimalDataSet()
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem[.partialDataDisplayHandling] = DataElement.string(tag: .partialDataDisplayHandling, vr: .CS, value: "MAINTAIN_LAYOUT")
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)

        XCTAssertEqual(try parser.parse(from: dataSet).partialDataDisplayHandling, .maintainLayout)

        dataSet[.partialDataDisplayHandling] = DataElement.string(tag: .partialDataDisplayHandling, vr: .CS, value: "ADAPT_LAYOUT")
        XCTAssertEqual(try parser.parse(from: dataSet).partialDataDisplayHandling, .adaptLayout, "the top-level value wins")
    }

    /// Old DICOMKit spellings inside an Image Boxes Sequence item
    func test_parse_imageBox_oldSpellings() throws {
        var dataSet = createMinimalDataSet()
        var imageBoxItem = DataSet()
        imageBoxItem[.imageBoxNumber] = DataElement.uint16(tag: .imageBoxNumber, value: 1)
        imageBoxItem[.imageBoxLayoutType] = DataElement.string(tag: .imageBoxLayoutType, vr: .CS, value: "TILED_ALL")
        imageBoxItem[.imageBoxSmallScrollType] = DataElement.string(tag: .imageBoxSmallScrollType, vr: .CS, value: "FRACTION")
        imageBoxItem[.reformattingOperationType] = DataElement.string(tag: .reformattingOperationType, vr: .CS, value: "MinIP")
        imageBoxItem[.reformattingOperationInitialViewDirection] = DataElement.string(tag: .reformattingOperationInitialViewDirection, vr: .CS, value: "AXIAL")
        imageBoxItem[.threeDRenderingType] = DataElement.strings(tag: .threeDRenderingType, vr: .CS, values: ["VOLUME", "MINIP"])
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem.setSequence([SequenceItem(elements: imageBoxItem.allElements)], for: .imageBoxesSequence)
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)

        let box = try parser.parse(from: dataSet).displaySets[0].imageBoxes[0]
        XCTAssertEqual(box.layoutType, .tiled)
        XCTAssertEqual(box.smallScrollType, .page)
        XCTAssertEqual(box.reformattingOperation?.type, .threeDRendering)
        XCTAssertEqual(box.reformattingOperation?.initialViewPlane, .transverse)
        XCTAssertEqual(box.threeDRenderingType, .volumeRendering)
        XCTAssertEqual(box.threeDRenderingSubtypes, ["MINIP"])
    }

    // MARK: - Display Set Parsing Tests

    func test_parse_displaySets_empty() throws {
        let dataSet = createMinimalDataSet()
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.displaySets.count, 0)
    }
    
    func test_parse_displaySets_single() throws {
        var dataSet = createMinimalDataSet()
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem[.displaySetLabel] = DataElement.string(tag: .displaySetLabel, vr: .LO, value: "Main View")
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.displaySets.count, 1)
        XCTAssertEqual(hangingProtocol.displaySets[0].number, 1)
        XCTAssertEqual(hangingProtocol.displaySets[0].label, "Main View")
    }
    
    func test_parse_imageBox_stack() throws {
        var dataSet = createMinimalDataSet()
        
        var imageBoxItem = DataSet()
        imageBoxItem[.imageBoxNumber] = DataElement.uint16(tag: .imageBoxNumber, value: 1)
        imageBoxItem[.imageBoxLayoutType] = DataElement.string(tag: .imageBoxLayoutType, vr: .CS, value: "STACK")
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem.setSequence([SequenceItem(elements: imageBoxItem.allElements)], for: .imageBoxesSequence)
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        XCTAssertEqual(hangingProtocol.displaySets.count, 1)
        XCTAssertEqual(hangingProtocol.displaySets[0].imageBoxes.count, 1)
        XCTAssertEqual(hangingProtocol.displaySets[0].imageBoxes[0].layoutType, .stack)
    }
    
    func test_parse_imageBox_tiled() throws {
        var dataSet = createMinimalDataSet()
        
        var imageBoxItem = DataSet()
        imageBoxItem[.imageBoxNumber] = DataElement.string(tag: .imageBoxNumber, vr: .IS, value: "1")
        imageBoxItem[.imageBoxLayoutType] = DataElement.string(tag: .imageBoxLayoutType, vr: .CS, value: "TILED")
        imageBoxItem[.imageBoxTileHorizontalDimension] = DataElement.string(tag: .imageBoxTileHorizontalDimension, vr: .IS, value: "2")
        imageBoxItem[.imageBoxTileVerticalDimension] = DataElement.string(tag: .imageBoxTileVerticalDimension, vr: .IS, value: "2")
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.string(tag: .displaySetNumber, vr: .IS, value: "1")
        displaySetItem.setSequence([SequenceItem(elements: imageBoxItem.allElements)], for: .imageBoxesSequence)
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        let imageBox = hangingProtocol.displaySets[0].imageBoxes[0]
        XCTAssertEqual(imageBox.layoutType, .tiled)
        XCTAssertEqual(imageBox.tileHorizontalDimension, 2)
        XCTAssertEqual(imageBox.tileVerticalDimension, 2)
    }
    
    func test_parse_displayOptions() throws {
        var dataSet = createMinimalDataSet()
        
        var displaySetItem = DataSet()
        displaySetItem[.displaySetNumber] = DataElement.uint16(tag: .displaySetNumber, value: 1)
        displaySetItem[.displaySetPatientOrientation] = DataElement.string(tag: .displaySetPatientOrientation, vr: .CS, value: "L\\P")
        displaySetItem[.showGrayscaleInverted] = DataElement.string(tag: .showGrayscaleInverted, vr: .CS, value: "YES")
        // "Y" is what DICOMKit wrote before the Table C.23.3-1 check; it is still read
        displaySetItem[.showImageTrueSizeFlag] = DataElement.string(tag: .showImageTrueSizeFlag, vr: .CS, value: "Y")
        
        dataSet.setSequence([SequenceItem(elements: displaySetItem.allElements)], for: .displaySetsSequence)
        
        let hangingProtocol = try parser.parse(from: dataSet)
        
        let options = hangingProtocol.displaySets[0].displayOptions
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
