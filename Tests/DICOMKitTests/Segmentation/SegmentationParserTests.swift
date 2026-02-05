//
// SegmentationParserTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class SegmentationParserTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    /// Create a minimal binary segmentation data set
    private func createMinimalBinarySegmentation() -> DataSet {
        var elementList: [DataElement] = []
        
        // SOP Instance UID
        elementList.append(DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: 15,
            valueData: "1.2.3.4.5.6.7.8".data(using: .utf8)!
        ))
        
        // SOP Class UID
        elementList.append(DataElement(
            tag: .sopClassUID,
            vr: .UI,
            length: 27,
            valueData: "1.2.840.10008.5.1.4.1.1.66.4".data(using: .utf8)!
        ))
        
        // Series Instance UID
        elementList.append(DataElement(
            tag: .seriesInstanceUID,
            vr: .UI,
            length: 10,
            valueData: "1.2.3.4.5".data(using: .utf8)!
        ))
        
        // Study Instance UID
        elementList.append(DataElement(
            tag: .studyInstanceUID,
            vr: .UI,
            length: 6,
            valueData: "1.2.3".data(using: .utf8)!
        ))
        
        // Segmentation Type
        elementList.append(DataElement(
            tag: .segmentationType,
            vr: .CS,
            length: 6,
            valueData: "BINARY".data(using: .ascii)!
        ))
        
        // Number of Frames
        elementList.append(DataElement(
            tag: .numberOfFrames,
            vr: .IS,
            length: 1,
            valueData: "1".data(using: .ascii)!
        ))
        
        // Rows
        var rowsValue: UInt16 = 512
        elementList.append(DataElement(
            tag: .rows,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &rowsValue, count: 2)
        ))
        
        // Columns
        var columnsValue: UInt16 = 512
        elementList.append(DataElement(
            tag: .columns,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &columnsValue, count: 2)
        ))
        
        // Bits Allocated
        var bitsAllocated: UInt16 = 1
        elementList.append(DataElement(
            tag: .bitsAllocated,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &bitsAllocated, count: 2)
        ))
        
        // Bits Stored
        var bitsStored: UInt16 = 1
        elementList.append(DataElement(
            tag: .bitsStored,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &bitsStored, count: 2)
        ))
        
        // High Bit
        var highBit: UInt16 = 0
        elementList.append(DataElement(
            tag: .highBit,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &highBit, count: 2)
        ))
        
        return DataSet(elements: elementList)
    }
    
    /// Create a segment item for testing
    private func createSegmentItem(number: Int, label: String) -> SequenceItem {
        var elements: [Tag: DataElement] = [:]
        
        // Segment Number
        var segmentNumber = UInt16(number)
        elements[.segmentNumber] = DataElement(
            tag: .segmentNumber,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &segmentNumber, count: 2)
        )
        
        // Segment Label
        elements[.segmentLabel] = DataElement(
            tag: .segmentLabel,
            vr: .LO,
            length: UInt32(label.count),
            valueData: label.data(using: .utf8)!
        )
        
        return SequenceItem(elements: elements)
    }
    
    // MARK: - Basic Parsing Tests
    
    func test_parse_minimalBinarySegmentation_succeeds() throws {
        let dataSet = createMinimalBinarySegmentation()
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        XCTAssertEqual(segmentation.sopInstanceUID, "1.2.3.4.5.6.7.8")
        XCTAssertEqual(segmentation.sopClassUID, "1.2.840.10008.5.1.4.1.1.66.4")
        XCTAssertEqual(segmentation.seriesInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(segmentation.studyInstanceUID, "1.2.3")
        XCTAssertEqual(segmentation.segmentationType, .binary)
        XCTAssertEqual(segmentation.numberOfFrames, 1)
        XCTAssertEqual(segmentation.rows, 512)
        XCTAssertEqual(segmentation.columns, 512)
        XCTAssertEqual(segmentation.bitsAllocated, 1)
        XCTAssertEqual(segmentation.bitsStored, 1)
        XCTAssertEqual(segmentation.highBit, 0)
    }
    
    func test_parse_missingSOPInstanceUID_throwsError() throws {
        var dataSet = DataSet()
        
        // Add only series and study UIDs
        dataSet[.seriesInstanceUID] = DataElement(
            tag: .seriesInstanceUID,
            vr: .UI,
            length: 10,
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        dataSet[.studyInstanceUID] = DataElement(
            tag: .studyInstanceUID,
            vr: .UI,
            length: 6,
            valueData: "1.2.3".data(using: .utf8)!
        )
        
        XCTAssertThrowsError(try SegmentationParser.parse(from: dataSet)) { error in
            guard case DICOMError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("SOP Instance UID"))
        }
    }
    
    func test_parse_missingSeriesInstanceUID_throwsError() throws {
        var dataSet = DataSet()
        
        // Add only SOP and study UIDs
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: 15,
            valueData: "1.2.3.4.5.6.7.8".data(using: .utf8)!
        )
        dataSet[.studyInstanceUID] = DataElement(
            tag: .studyInstanceUID,
            vr: .UI,
            length: 6,
            valueData: "1.2.3".data(using: .utf8)!
        )
        
        XCTAssertThrowsError(try SegmentationParser.parse(from: dataSet)) { error in
            guard case DICOMError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("Series Instance UID"))
        }
    }
    
    func test_parse_missingStudyInstanceUID_throwsError() throws {
        var dataSet = DataSet()
        
        // Add only SOP and series UIDs
        dataSet[.sopInstanceUID] = DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: 15,
            valueData: "1.2.3.4.5.6.7.8".data(using: .utf8)!
        )
        dataSet[.seriesInstanceUID] = DataElement(
            tag: .seriesInstanceUID,
            vr: .UI,
            length: 10,
            valueData: "1.2.3.4.5".data(using: .utf8)!
        )
        
        XCTAssertThrowsError(try SegmentationParser.parse(from: dataSet)) { error in
            guard case DICOMError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("Study Instance UID"))
        }
    }
    
    func test_parse_missingSegmentationType_throwsError() throws {
        var elementList: [DataElement] = []
        
        // Add UIDs but not segmentation type
        elementList.append(DataElement(
            tag: .sopInstanceUID,
            vr: .UI,
            length: 15,
            valueData: "1.2.3.4.5.6.7.8".data(using: .utf8)!
        ))
        elementList.append(DataElement(
            tag: .seriesInstanceUID,
            vr: .UI,
            length: 10,
            valueData: "1.2.3.4.5".data(using: .utf8)!
        ))
        elementList.append(DataElement(
            tag: .studyInstanceUID,
            vr: .UI,
            length: 6,
            valueData: "1.2.3".data(using: .utf8)!
        ))
        
        let dataSet = DataSet(elements: elementList)
        
        XCTAssertThrowsError(try SegmentationParser.parse(from: dataSet)) { error in
            guard case DICOMError.parsingFailed(let message) = error else {
                XCTFail("Expected parsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("Segmentation Type"))
        }
    }
    
    func test_parse_withoutOptionalFields_succeeds() throws {
        let dataSet = createMinimalBinarySegmentation()
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        // Optional fields should be nil
        XCTAssertNil(segmentation.instanceNumber)
        XCTAssertNil(segmentation.contentLabel)
        XCTAssertNil(segmentation.contentDescription)
        XCTAssertNil(segmentation.contentCreatorName)
        XCTAssertNil(segmentation.contentDate)
        XCTAssertNil(segmentation.contentTime)
        XCTAssertNil(segmentation.segmentationFractionalType)
        XCTAssertNil(segmentation.maxFractionalValue)
        XCTAssertNil(segmentation.frameOfReferenceUID)
        XCTAssertNil(segmentation.dimensionOrganizationUID)
        XCTAssertEqual(segmentation.segments.count, 0)
        XCTAssertEqual(segmentation.referencedSeries.count, 0)
        XCTAssertNil(segmentation.sharedFunctionalGroups)
        XCTAssertEqual(segmentation.perFrameFunctionalGroups.count, 0)
    }
    
    func test_parse_withDefaultValues_succeeds() throws {
        let dataSet = createMinimalBinarySegmentation()
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        // Should use default values
        XCTAssertEqual(segmentation.samplesPerPixel, 1)
        XCTAssertEqual(segmentation.photometricInterpretation, "MONOCHROME2")
        XCTAssertEqual(segmentation.pixelRepresentation, 0)
    }
    
    // MARK: - Segment Parsing Tests
    
    func test_parse_segmentSequence_singleSegment_succeeds() throws {
        var dataSet = createMinimalBinarySegmentation()
        
        let segmentItem = createSegmentItem(number: 1, label: "Liver")
        
        dataSet[.segmentSequence] = DataElement(
            tag: .segmentSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [segmentItem]
        )
        
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        XCTAssertEqual(segmentation.numberOfSegments, 1)
        XCTAssertEqual(segmentation.segments.count, 1)
        XCTAssertEqual(segmentation.segments[0].segmentNumber, 1)
        XCTAssertEqual(segmentation.segments[0].segmentLabel, "Liver")
    }
    
    func test_parse_segmentSequence_multipleSegments_succeeds() throws {
        var dataSet = createMinimalBinarySegmentation()
        
        let segment1 = createSegmentItem(number: 1, label: "Liver")
        let segment2 = createSegmentItem(number: 2, label: "Kidney")
        let segment3 = createSegmentItem(number: 3, label: "Spleen")
        
        dataSet[.segmentSequence] = DataElement(
            tag: .segmentSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [segment1, segment2, segment3]
        )
        
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        XCTAssertEqual(segmentation.numberOfSegments, 3)
        XCTAssertEqual(segmentation.segments.count, 3)
        XCTAssertEqual(segmentation.segments[0].segmentNumber, 1)
        XCTAssertEqual(segmentation.segments[1].segmentNumber, 2)
        XCTAssertEqual(segmentation.segments[2].segmentNumber, 3)
    }
    
    // MARK: - Functional Groups Tests
    
    func test_parse_perFrameFunctionalGroups_succeeds() throws {
        var dataSet = createMinimalBinarySegmentation()
        
        // Create per-frame functional group with segment identification
        var fgElements: [Tag: DataElement] = [:]
        
        var segIDElements: [Tag: DataElement] = [:]
        var segNumber: UInt16 = 1
        segIDElements[.referencedSegmentNumber] = DataElement(
            tag: .referencedSegmentNumber,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &segNumber, count: 2)
        )
        
        let segIDItem = SequenceItem(elements: segIDElements)
        fgElements[.segmentIdentificationSequence] = DataElement(
            tag: .segmentIdentificationSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [segIDItem]
        )
        
        let fgItem = SequenceItem(elements: fgElements)
        
        dataSet[.perFrameFunctionalGroupsSequence] = DataElement(
            tag: .perFrameFunctionalGroupsSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [fgItem]
        )
        
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        XCTAssertEqual(segmentation.perFrameFunctionalGroups.count, 1)
        XCTAssertNotNil(segmentation.perFrameFunctionalGroups[0].segmentIdentification)
        XCTAssertEqual(segmentation.perFrameFunctionalGroups[0].segmentIdentification?.referencedSegmentNumber, 1)
    }
    
    func test_parse_sharedFunctionalGroups_succeeds() throws {
        var dataSet = createMinimalBinarySegmentation()
        
        // Create shared functional group with plane position
        var fgElements: [Tag: DataElement] = [:]
        
        var planeElements: [Tag: DataElement] = [:]
        planeElements[.imagePositionPatient] = DataElement(
            tag: .imagePositionPatient,
            vr: .DS,
            length: 15,
            valueData: "0.0\\0.0\\10.0".data(using: .ascii)!
        )
        
        let planeItem = SequenceItem(elements: planeElements)
        fgElements[.planePositionSequence] = DataElement(
            tag: .planePositionSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [planeItem]
        )
        
        let fgItem = SequenceItem(elements: fgElements)
        
        dataSet[.sharedFunctionalGroupsSequence] = DataElement(
            tag: .sharedFunctionalGroupsSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [fgItem]
        )
        
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        XCTAssertNotNil(segmentation.sharedFunctionalGroups)
        XCTAssertNotNil(segmentation.sharedFunctionalGroups?.planePosition)
        XCTAssertEqual(segmentation.sharedFunctionalGroups?.planePosition?.imagePositionPatient.count, 3)
    }
    
    // MARK: - Integration Tests
    
    func test_parse_completeSegmentation_succeeds() throws {
        var dataSet = createMinimalBinarySegmentation()
        
        // Add content label
        dataSet[.contentLabel] = DataElement(
            tag: .contentLabel,
            vr: .CS,
            length: 7,
            valueData: "AI_SEG".data(using: .ascii)!
        )
        
        // Add segment
        let segmentItem = createSegmentItem(number: 1, label: "Liver")
        dataSet[.segmentSequence] = DataElement(
            tag: .segmentSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [segmentItem]
        )
        
        // Add per-frame functional group
        var fgElements: [Tag: DataElement] = [:]
        var segIDElements: [Tag: DataElement] = [:]
        var segNumber: UInt16 = 1
        segIDElements[.referencedSegmentNumber] = DataElement(
            tag: .referencedSegmentNumber,
            vr: .US,
            length: 2,
            valueData: Data(bytes: &segNumber, count: 2)
        )
        let segIDItem = SequenceItem(elements: segIDElements)
        fgElements[.segmentIdentificationSequence] = DataElement(
            tag: .segmentIdentificationSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [segIDItem]
        )
        let fgItem = SequenceItem(elements: fgElements)
        dataSet[.perFrameFunctionalGroupsSequence] = DataElement(
            tag: .perFrameFunctionalGroupsSequence,
            vr: .SQ,
            length: 0, valueData: Data(),
            sequenceItems: [fgItem]
        )
        
        let segmentation = try SegmentationParser.parse(from: dataSet)
        
        // Verify complete parsing
        XCTAssertEqual(segmentation.contentLabel, "AI_SEG")
        XCTAssertEqual(segmentation.numberOfSegments, 1)
        XCTAssertEqual(segmentation.segments[0].segmentLabel, "Liver")
        XCTAssertEqual(segmentation.perFrameFunctionalGroups.count, 1)
        XCTAssertNotNil(segmentation.perFrameFunctionalGroups[0].segmentIdentification)
    }
}
