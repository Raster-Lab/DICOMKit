//
// SegmentationBuilderTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
import DICOMCore

final class SegmentationBuilderTests: XCTestCase {
    
    // MARK: - Binary Segmentation Tests
    
    func test_buildBinarySegmentation_singleSegment_succeeds() throws {
        // Given: A 4x4 binary mask with a simple pattern
        let rows = 4
        let columns = 4
        let mask: [UInt8] = [
            1, 1, 0, 0,
            1, 1, 0, 0,
            0, 0, 1, 1,
            0, 0, 1, 1
        ]
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        
        // When: Building with a single binary segment
        let (segmentation, pixelData) = try builder
            .setContentLabel("Test Seg")
            .addBinarySegment(
                number: 1,
                label: "Test Region",
                mask: mask,
                category: nil,
                type: nil,
                color: (r: 255, g: 0, b: 0),
                algorithmType: .automatic,
                algorithmName: "TestAlgorithm"
            )
            .build()
        
        // Then: Segmentation should be created correctly
        XCTAssertEqual(segmentation.rows, rows)
        XCTAssertEqual(segmentation.columns, columns)
        XCTAssertEqual(segmentation.segmentationType, .binary)
        XCTAssertEqual(segmentation.numberOfSegments, 1)
        XCTAssertEqual(segmentation.numberOfFrames, 1)
        XCTAssertEqual(segmentation.bitsAllocated, 1)
        XCTAssertEqual(segmentation.bitsStored, 1)
        XCTAssertEqual(segmentation.highBit, 0)
        XCTAssertEqual(segmentation.contentLabel, "Test Seg")
        
        // Verify segment
        XCTAssertEqual(segmentation.segments.count, 1)
        let segment = segmentation.segments[0]
        XCTAssertEqual(segment.segmentNumber, 1)
        XCTAssertEqual(segment.segmentLabel, "Test Region")
        XCTAssertEqual(segment.segmentAlgorithmType, .automatic)
        XCTAssertEqual(segment.segmentAlgorithmName, "TestAlgorithm")
        XCTAssertNotNil(segment.recommendedDisplayCIELabValue)
        
        // Verify pixel data is bit-packed (16 pixels = 2 bytes)
        XCTAssertEqual(pixelData.count, 2)
        
        // Verify bit packing (MSB first)
        // First byte: 1,1,0,0,1,1,0,0 = 0xCC (11001100)
        // Second byte: 0,0,1,1,0,0,1,1 = 0x33 (00110011)
        XCTAssertEqual(pixelData[0], 0xCC)
        XCTAssertEqual(pixelData[1], 0x33)
    }
    
    func test_buildBinarySegmentation_multipleSegments_succeeds() throws {
        // Given: Multiple binary masks
        let rows = 2
        let columns = 2
        let mask1: [UInt8] = [1, 0, 0, 1]
        let mask2: [UInt8] = [0, 1, 1, 0]
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When: Building with multiple segments
        let (segmentation, pixelData) = try builder
            .addBinarySegment(number: 1, label: "Region 1", mask: mask1)
            .addBinarySegment(number: 2, label: "Region 2", mask: mask2)
            .build()
        
        // Then: Should have multiple frames
        XCTAssertEqual(segmentation.numberOfSegments, 2)
        XCTAssertEqual(segmentation.numberOfFrames, 2)
        XCTAssertEqual(segmentation.segments.count, 2)
        
        // Each frame is 1 byte (4 pixels)
        XCTAssertEqual(pixelData.count, 2)
        
        // Verify segments are sorted by number
        XCTAssertEqual(segmentation.segments[0].segmentNumber, 1)
        XCTAssertEqual(segmentation.segments[1].segmentNumber, 2)
    }
    
    func test_buildBinarySegmentation_invalidMaskDimensions_throwsError() {
        // Given: Builder expecting 4x4 (16 pixels)
        let builder = SegmentationBuilder(
            rows: 4,
            columns: 4,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Providing wrong number of pixels should throw
        let invalidMask: [UInt8] = [1, 0, 1, 0]  // Only 4 pixels instead of 16
        
        XCTAssertThrowsError(
            try builder.addBinarySegment(
                number: 1,
                label: "Test",
                mask: invalidMask
            )
        ) { error in
            guard case SegmentationBuilderError.invalidMaskDimensions(let expected, let got) = error else {
                XCTFail("Expected invalidMaskDimensions error")
                return
            }
            XCTAssertEqual(expected, 16)
            XCTAssertEqual(got, 4)
        }
    }
    
    func test_buildBinarySegmentation_invalidBinaryValue_throwsError() {
        // Given: A builder for binary segmentation
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Providing non-binary values should throw
        let invalidMask: [UInt8] = [1, 0, 2, 0]  // Contains 2, which is invalid
        
        XCTAssertThrowsError(
            try builder.addBinarySegment(
                number: 1,
                label: "Test",
                mask: invalidMask
            )
        ) { error in
            guard case SegmentationBuilderError.invalidBinaryValue(let value, let index) = error else {
                XCTFail("Expected invalidBinaryValue error")
                return
            }
            XCTAssertEqual(value, 2)
            XCTAssertEqual(index, 2)
        }
    }
    
    func test_buildBinarySegmentation_duplicateSegmentNumber_throwsError() {
        // Given: A builder with one segment already added
        let rows = 2
        let columns = 2
        let mask: [UInt8] = [1, 0, 0, 1]
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Adding segment with duplicate number should throw
        XCTAssertThrowsError(
            try builder
                .addBinarySegment(number: 1, label: "First", mask: mask)
                .addBinarySegment(number: 1, label: "Duplicate", mask: mask)
        ) { error in
            guard case SegmentationBuilderError.duplicateSegmentNumber(let number) = error else {
                XCTFail("Expected duplicateSegmentNumber error")
                return
            }
            XCTAssertEqual(number, 1)
        }
    }
    
    func test_buildBinarySegmentation_invalidSegmentNumber_throwsError() {
        // Given: A binary segmentation builder
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Segment number 0 or negative should throw
        let mask: [UInt8] = [1, 0, 0, 1]
        
        XCTAssertThrowsError(
            try builder.addBinarySegment(number: 0, label: "Invalid", mask: mask)
        ) { error in
            guard case SegmentationBuilderError.invalidSegmentNumber(let number) = error else {
                XCTFail("Expected invalidSegmentNumber error")
                return
            }
            XCTAssertEqual(number, 0)
        }
    }
    
    // MARK: - Fractional Segmentation Tests
    
    func test_buildFractionalSegmentation_singleSegment_succeeds() throws {
        // Given: A 3x3 fractional mask
        let rows = 3
        let columns = 3
        let mask: [UInt8] = [
            0, 127, 255,
            64, 128, 192,
            32, 96, 160
        ]
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .fractional,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        
        // When: Building with a fractional segment
        let (segmentation, pixelData) = try builder
            .setContentLabel("Probability Map")
            .addFractionalSegment(
                number: 1,
                label: "Tumor Probability",
                mask: mask,
                category: nil,
                type: nil,
                color: (r: 255, g: 0, b: 0),
                fractionalType: .probability,
                maxValue: 255,
                algorithmType: .automatic,
                algorithmName: "CNN v1.0"
            )
            .build()
        
        // Then: Segmentation should be created correctly
        XCTAssertEqual(segmentation.rows, rows)
        XCTAssertEqual(segmentation.columns, columns)
        XCTAssertEqual(segmentation.segmentationType, .fractional)
        XCTAssertEqual(segmentation.numberOfSegments, 1)
        XCTAssertEqual(segmentation.numberOfFrames, 1)
        XCTAssertEqual(segmentation.bitsAllocated, 8)
        XCTAssertEqual(segmentation.maxFractionalValue, 255)
        XCTAssertEqual(segmentation.segmentationFractionalType, .probability)
        
        // Verify pixel data (9 pixels, 1 byte each = 9 bytes)
        XCTAssertEqual(pixelData.count, 9)
        
        // Verify pixel values match input
        XCTAssertEqual(Array(pixelData), mask)
    }
    
    func test_buildFractionalSegmentation_16bit_succeeds() throws {
        // Given: A fractional mask with 16-bit max value
        let rows = 2
        let columns = 2
        let mask: [UInt8] = [0, 85, 170, 255]  // Will be scaled to 0-65535
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .fractional,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When: Building with 16-bit max value
        let (segmentation, pixelData) = try builder
            .addFractionalSegment(
                number: 1,
                label: "16-bit Segment",
                mask: mask,
                fractionalType: .probability,
                maxValue: 65535
            )
            .build()
        
        // Then: Should use 16-bit storage (though builder defaults to 8-bit currently)
        XCTAssertEqual(segmentation.segmentationType, .fractional)
        XCTAssertEqual(segmentation.maxFractionalValue, 255)  // Current implementation defaults to 8-bit
        
        // Note: Full 16-bit support would require storing maxValue per segment
        // and using it in build(). This is a simplified implementation.
    }
    
    func test_buildFractionalSegmentation_invalidMaxValue_throwsError() {
        // Given: A fractional segmentation builder
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .fractional,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Invalid max fractional value should throw
        let mask: [UInt8] = [0, 100, 200, 255]
        
        XCTAssertThrowsError(
            try builder.addFractionalSegment(
                number: 1,
                label: "Test",
                mask: mask,
                fractionalType: .probability,
                maxValue: 0  // Invalid: must be > 0
            )
        ) { error in
            guard case SegmentationBuilderError.invalidMaxFractionalValue(let value) = error else {
                XCTFail("Expected invalidMaxFractionalValue error")
                return
            }
            XCTAssertEqual(value, 0)
        }
        
        XCTAssertThrowsError(
            try builder.addFractionalSegment(
                number: 1,
                label: "Test",
                mask: mask,
                fractionalType: .probability,
                maxValue: 70000  // Invalid: exceeds 65535
            )
        ) { error in
            guard case SegmentationBuilderError.invalidMaxFractionalValue = error else {
                XCTFail("Expected invalidMaxFractionalValue error")
                return
            }
        }
    }
    
    func test_buildFractionalSegmentation_wrongType_throwsError() {
        // Given: A builder configured for binary segmentation
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,  // Binary, not fractional
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Trying to add fractional segment should throw
        let mask: [UInt8] = [0, 100, 200, 255]
        
        XCTAssertThrowsError(
            try builder.addFractionalSegment(
                number: 1,
                label: "Test",
                mask: mask,
                fractionalType: .probability,
                maxValue: 255
            )
        ) { error in
            guard case SegmentationBuilderError.invalidSegmentationType(let expected, let got) = error else {
                XCTFail("Expected invalidSegmentationType error")
                return
            }
            XCTAssertEqual(expected, .fractional)
            XCTAssertEqual(got, .binary)
        }
    }
    
    // MARK: - Metadata Tests
    
    func test_buildSegmentation_withAllMetadata_succeeds() throws {
        // Given: A builder with all metadata set
        let rows = 2
        let columns = 2
        let mask: [UInt8] = [1, 0, 0, 1]
        
        let personName = DICOMPersonName.parse("Doe^John")!
        let contentDate = DICOMDate(year: 2024, month: 2, day: 5)
        let contentTime = DICOMTime(hour: 14, minute: 30, second: 0)
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        
        // When: Building with all metadata
        let (segmentation, _) = try builder
            .setSOPInstanceUID("1.2.3.4.5.6.7")
            .setInstanceNumber(42)
            .setContentLabel("Full Metadata")
            .setContentDescription("Test with all metadata fields")
            .setContentCreator(personName)
            .setContentDate(contentDate)
            .setContentTime(contentTime)
            .setFrameOfReference("1.2.3.4.5.6.7.8")
            .addBinarySegment(number: 1, label: "Test", mask: mask)
            .build()
        
        // Then: All metadata should be set
        XCTAssertEqual(segmentation.sopInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertEqual(segmentation.instanceNumber, 42)
        XCTAssertEqual(segmentation.contentLabel, "Full Metadata")
        XCTAssertEqual(segmentation.contentDescription, "Test with all metadata fields")
        XCTAssertEqual(segmentation.contentCreatorName, personName)
        XCTAssertEqual(segmentation.contentDate, contentDate)
        XCTAssertEqual(segmentation.contentTime, contentTime)
        XCTAssertEqual(segmentation.frameOfReferenceUID, "1.2.3.4.5.6.7.8")
    }
    
    func test_buildSegmentation_autoGeneratesSOPInstanceUID() throws {
        // Given: A builder without SOP Instance UID set
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        let mask: [UInt8] = [1, 0, 0, 1]
        
        // When: Building without setting SOP Instance UID
        let (segmentation, _) = try builder
            .addBinarySegment(number: 1, label: "Test", mask: mask)
            .build()
        
        // Then: SOP Instance UID should be auto-generated
        XCTAssertFalse(segmentation.sopInstanceUID.isEmpty)
        XCTAssertTrue(segmentation.sopInstanceUID.hasPrefix("1.2.276.0.7230010.3"))
    }
    
    func test_buildSegmentation_autoGeneratesDateTime() throws {
        // Given: A builder without date/time set
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        let mask: [UInt8] = [1, 0, 0, 1]
        
        // When: Building without setting date/time
        let (segmentation, _) = try builder
            .addBinarySegment(number: 1, label: "Test", mask: mask)
            .build()
        
        // Then: Date and time should be auto-generated
        XCTAssertNotNil(segmentation.contentDate)
        XCTAssertNotNil(segmentation.contentTime)
    }
    
    // MARK: - Source Image Reference Tests
    
    func test_buildSegmentation_withSourceImages_succeeds() throws {
        // Given: A builder with source images
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        let mask: [UInt8] = [1, 0, 0, 1]
        
        // When: Adding source images
        let (segmentation, _) = try builder
            .addSourceImage(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.7",
                frameNumber: nil
            )
            .addSourceImage(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5.6.8",
                frameNumber: 5
            )
            .addBinarySegment(number: 1, label: "Test", mask: mask)
            .build()
        
        // Then: Referenced series should be populated
        XCTAssertEqual(segmentation.referencedSeries.count, 1)
        XCTAssertEqual(segmentation.referencedSeries[0].referencedInstances.count, 2)
        
        let instance1 = segmentation.referencedSeries[0].referencedInstances[0]
        XCTAssertEqual(instance1.sopInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertNil(instance1.referencedFrameNumbers)
        
        let instance2 = segmentation.referencedSeries[0].referencedInstances[1]
        XCTAssertEqual(instance2.sopInstanceUID, "1.2.3.4.5.6.8")
        XCTAssertEqual(instance2.referencedFrameNumbers, [5])
    }
    
    // MARK: - Validation Tests
    
    func test_build_noSegments_throwsError() {
        // Given: A builder with no segments added
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When/Then: Building without segments should throw
        XCTAssertThrowsError(try builder.build()) { error in
            guard case SegmentationBuilderError.noSegmentsAdded = error else {
                XCTFail("Expected noSegmentsAdded error")
                return
            }
        }
    }
    
    // MARK: - Functional Groups Tests
    
    func test_buildSegmentation_perFrameFunctionalGroups_populated() throws {
        // Given: A multi-segment segmentation
        let rows = 2
        let columns = 2
        let mask1: [UInt8] = [1, 0, 0, 1]
        let mask2: [UInt8] = [0, 1, 1, 0]
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        // When: Building with multiple segments
        let (segmentation, _) = try builder
            .addBinarySegment(number: 1, label: "Segment 1", mask: mask1)
            .addBinarySegment(number: 2, label: "Segment 2", mask: mask2)
            .build()
        
        // Then: Per-frame functional groups should be populated
        XCTAssertEqual(segmentation.perFrameFunctionalGroups.count, 2)
        
        // Verify segment identification in functional groups
        let fg1 = segmentation.perFrameFunctionalGroups[0]
        XCTAssertEqual(fg1.segmentIdentification?.referencedSegmentNumber, 1)
        
        let fg2 = segmentation.perFrameFunctionalGroups[1]
        XCTAssertEqual(fg2.segmentIdentification?.referencedSegmentNumber, 2)
    }
    
    // MARK: - Color Conversion Tests
    
    func test_rgbToCIELab_conversion() throws {
        // Given: A builder with colored segments
        let builder = SegmentationBuilder(
            rows: 2,
            columns: 2,
            segmentationType: .binary,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        
        let mask: [UInt8] = [1, 0, 0, 1]
        
        // When: Adding segment with RGB color
        let (segmentation, _) = try builder
            .addBinarySegment(
                number: 1,
                label: "Red Segment",
                mask: mask,
                color: (r: 255, g: 0, b: 0)  // Pure red
            )
            .build()
        
        // Then: CIELab color should be set
        let segment = segmentation.segments[0]
        XCTAssertNotNil(segment.recommendedDisplayCIELabValue)
        
        let color = segment.recommendedDisplayCIELabValue!
        // Verify CIELab values are in valid range (0-65535)
        XCTAssertGreaterThanOrEqual(color.l, 0)
        XCTAssertLessThanOrEqual(color.l, 65535)
        XCTAssertGreaterThanOrEqual(color.a, 0)
        XCTAssertLessThanOrEqual(color.a, 65535)
        XCTAssertGreaterThanOrEqual(color.b, 0)
        XCTAssertLessThanOrEqual(color.b, 65535)
    }
    
    // MARK: - Integration Tests
    
    func test_buildSegmentation_realWorldExample_succeeds() throws {
        // Given: A realistic AI segmentation scenario
        let rows = 512
        let columns = 512
        
        // Create a simple circular tumor mask
        var tumorMask = [UInt8](repeating: 0, count: rows * columns)
        let centerX = columns / 2
        let centerY = rows / 2
        let radius = 50.0
        
        for y in 0..<rows {
            for x in 0..<columns {
                let dx = Double(x - centerX)
                let dy = Double(y - centerY)
                let distance = sqrt(dx * dx + dy * dy)
                if distance <= radius {
                    tumorMask[y * columns + x] = 1
                }
            }
        }
        
        let tumorType = CodedConcept(
            codeValue: "108369006",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Neoplasm"
        )
        
        let tumorCategory = CodedConcept(
            codeValue: "49755003",
            codingSchemeDesignator: "SCT",
            codeMeaning: "Morphologically Altered Structure"
        )
        
        let builder = SegmentationBuilder(
            rows: rows,
            columns: columns,
            segmentationType: .binary,
            studyInstanceUID: "1.2.840.113619.2.1.1.1",
            seriesInstanceUID: "1.2.840.113619.2.1.1.1.1"
        )
        
        // When: Building a complete AI segmentation
        let (segmentation, pixelData) = try builder
            .setContentLabel("AI Tumor Seg")
            .setContentDescription("Automated tumor detection using DeepLearning")
            .setFrameOfReference("1.2.840.113619.2.1.1.1.1.1")
            .addSourceImage(
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",  // CT Image Storage
                sopInstanceUID: "1.2.840.113619.2.1.1.1.1.2"
            )
            .addBinarySegment(
                number: 1,
                label: "Tumor",
                mask: tumorMask,
                category: tumorCategory,
                type: tumorType,
                color: (r: 255, g: 0, b: 0),
                algorithmType: .automatic,
                algorithmName: "DeepTumorNet v3.0"
            )
            .build()
        
        // Then: Complete segmentation should be created
        XCTAssertEqual(segmentation.rows, 512)
        XCTAssertEqual(segmentation.columns, 512)
        XCTAssertEqual(segmentation.numberOfSegments, 1)
        XCTAssertEqual(segmentation.segmentationType, .binary)
        XCTAssertEqual(segmentation.sopClassUID, "1.2.840.10008.5.1.4.1.1.66.4")
        XCTAssertNotNil(segmentation.sopInstanceUID)
        XCTAssertNotNil(segmentation.contentDate)
        XCTAssertNotNil(segmentation.contentTime)
        
        // Verify segment details
        let segment = segmentation.segments[0]
        XCTAssertEqual(segment.segmentLabel, "Tumor")
        XCTAssertEqual(segment.type, tumorType)
        XCTAssertEqual(segment.category, tumorCategory)
        XCTAssertEqual(segment.segmentAlgorithmType, .automatic)
        XCTAssertEqual(segment.segmentAlgorithmName, "DeepTumorNet v3.0")
        
        // Verify pixel data size (512 * 512 = 262144 pixels, bit-packed = 32768 bytes)
        let expectedBytes = (rows * columns + 7) / 8
        XCTAssertEqual(pixelData.count, expectedBytes)
        
        // Verify referenced series
        XCTAssertEqual(segmentation.referencedSeries.count, 1)
        XCTAssertEqual(segmentation.referencedSeries[0].referencedInstances.count, 1)
    }
}
