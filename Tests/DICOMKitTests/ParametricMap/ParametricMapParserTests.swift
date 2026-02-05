//
// ParametricMapParserTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class ParametricMapParserTests: XCTestCase {
    
    // MARK: - Parser Tests - Basic Parsing
    
    func test_parseParametricMap_withMinimalDataSet_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.sopClassUID, "1.2.840.10008.5.1.4.1.1.30")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        // Add minimal RWV mapping
        var rwvSequence = DataSet()
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "ms")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "millisecond")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        rwvSequence.append(.realWorldValueSlope, 1.0 as Double)
        rwvSequence.append(.realWorldValueIntercept, 0.0 as Double)
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(parametricMap.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(parametricMap.studyInstanceUID, "1.2.3")
        XCTAssertEqual(parametricMap.numberOfFrames, 1)
        XCTAssertEqual(parametricMap.rows, 256)
        XCTAssertEqual(parametricMap.columns, 256)
        XCTAssertEqual(parametricMap.bitsAllocated, 16)
        XCTAssertEqual(parametricMap.realWorldValueMappings.count, 1)
    }
    
    func test_parseParametricMap_withContentMetadata_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        // Add content metadata
        dataSet.append(.contentLabel, "ADC Map")
        dataSet.append(.contentDescription, "Diffusion ADC")
        dataSet.append(.contentCreatorName, "Doe^John")
        dataSet.append(.contentDate, DICOMDate(year: 2024, month: 2, day: 5))
        dataSet.append(.contentTime, DICOMTime(hour: 14, minute: 30, second: 0))
        dataSet.append(.instanceNumber, 42)
        
        // Add RWV mapping
        var rwvSequence = DataSet()
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "mm2/s")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "square millimeter per second")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        rwvSequence.append(.realWorldValueSlope, 0.001 as Double)
        rwvSequence.append(.realWorldValueIntercept, 0.0 as Double)
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.contentLabel, "ADC Map")
        XCTAssertEqual(parametricMap.contentDescription, "Diffusion ADC")
        XCTAssertNotNil(parametricMap.contentCreatorName)
        XCTAssertEqual(parametricMap.instanceNumber, 42)
    }
    
    func test_parseParametricMap_withDerivationInfo_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        // Add derivation info
        dataSet.append(.derivationDescription, "Calculated from DWI")
        
        var derivationCode = DataSet()
        derivationCode.append(.codeValue, "113076")
        derivationCode.append(.codingSchemeDesignator, "DCM")
        derivationCode.append(.codeMeaning, "ADC calculation")
        dataSet.appendSequence(.derivationCodeSequence, [derivationCode])
        
        // Add RWV mapping
        var rwvSequence = DataSet()
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "mm2/s")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "square millimeter per second")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        rwvSequence.append(.realWorldValueSlope, 1.0 as Double)
        rwvSequence.append(.realWorldValueIntercept, 0.0 as Double)
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.derivationDescription, "Calculated from DWI")
        XCTAssertEqual(parametricMap.derivationCodeSequence.count, 1)
        XCTAssertEqual(parametricMap.derivationCodeSequence[0].codeValue, "113076")
    }
    
    // MARK: - Real World Value Mapping Parsing Tests
    
    func test_parseRWVMapping_linearTransformation_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        var rwvSequence = DataSet()
        rwvSequence.append(.lutLabel, "T1 Mapping")
        rwvSequence.append(.lutExplanation, "T1 relaxation time")
        
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "ms")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "millisecond")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        
        var quantitySequence = DataSet()
        quantitySequence.append(.codeValue, "113054")
        quantitySequence.append(.codingSchemeDesignator, "DCM")
        quantitySequence.append(.codeMeaning, "T1")
        rwvSequence.appendSequence(.quantityDefinitionSequence, [quantitySequence])
        
        rwvSequence.append(.realWorldValueSlope, 1.5 as Double)
        rwvSequence.append(.realWorldValueIntercept, 100.0 as Double)
        
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.realWorldValueMappings.count, 1)
        let mapping = parametricMap.realWorldValueMappings[0]
        XCTAssertEqual(mapping.label, "T1 Mapping")
        XCTAssertEqual(mapping.explanation, "T1 relaxation time")
        XCTAssertEqual(mapping.measurementUnits.codeValue, "ms")
        XCTAssertEqual(mapping.quantityDefinition?.codeValue, "113054")
        
        if case .linear(let slope, let intercept) = mapping.mapping {
            XCTAssertEqual(slope, 1.5)
            XCTAssertEqual(intercept, 100.0)
        } else {
            XCTFail("Expected linear mapping")
        }
    }
    
    func test_parseRWVMapping_withoutQuantityDefinition_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        var rwvSequence = DataSet()
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "1")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "no units")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        rwvSequence.append(.realWorldValueSlope, 1.0 as Double)
        rwvSequence.append(.realWorldValueIntercept, 0.0 as Double)
        
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.realWorldValueMappings.count, 1)
        XCTAssertNil(parametricMap.realWorldValueMappings[0].quantityDefinition)
    }
    
    // MARK: - Referenced Series Parsing Tests
    
    func test_parseReferencedSeries_succeeds() throws {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.numberOfFrames, 1)
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        dataSet.append(.bitsAllocated, UInt16(16))
        dataSet.append(.bitsStored, UInt16(16))
        dataSet.append(.highBit, UInt16(15))
        
        // Add referenced series
        var seriesSequence = DataSet()
        seriesSequence.append(.seriesInstanceUID, "1.2.3.4.5")
        
        var instance1 = DataSet()
        instance1.append(.referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.4")
        instance1.append(.referencedSOPInstanceUID, "1.2.3.4.5.6")
        
        var instance2 = DataSet()
        instance2.append(.referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.4")
        instance2.append(.referencedSOPInstanceUID, "1.2.3.4.5.7")
        instance2.append(.referencedFrameNumber, [1, 2, 3])
        
        seriesSequence.appendSequence(.referencedInstanceSequence, [instance1, instance2])
        dataSet.appendSequence(.referencedSeriesSequence, [seriesSequence])
        
        // Add RWV mapping
        var rwvSequence = DataSet()
        var unitsSequence = DataSet()
        unitsSequence.append(.codeValue, "ms")
        unitsSequence.append(.codingSchemeDesignator, "UCUM")
        unitsSequence.append(.codeMeaning, "millisecond")
        rwvSequence.appendSequence(.measurementUnitsCodeSequence, [unitsSequence])
        rwvSequence.append(.realWorldValueSlope, 1.0 as Double)
        rwvSequence.append(.realWorldValueIntercept, 0.0 as Double)
        dataSet.appendSequence(.realWorldValueMappingSequence, [rwvSequence])
        
        let parametricMap = try ParametricMapParser.parse(from: dataSet)
        
        XCTAssertEqual(parametricMap.referencedSeries.count, 1)
        XCTAssertEqual(parametricMap.referencedSeries[0].seriesInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(parametricMap.referencedSeries[0].referencedInstances.count, 2)
        XCTAssertEqual(parametricMap.referencedSeries[0].referencedInstances[1].referencedFrameNumbers, [1, 2, 3])
    }
    
    // MARK: - Error Cases
    
    func test_parseParametricMap_missingSopInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        
        XCTAssertThrowsError(try ParametricMapParser.parse(from: dataSet)) { error in
            if case DICOMError.parsingFailed(let message) = error {
                XCTAssertTrue(message.contains("SOP Instance UID"))
            } else {
                XCTFail("Expected parsingFailed error")
            }
        }
    }
    
    func test_parseParametricMap_missingSeriesUID_throws() {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.studyInstanceUID, "1.2.3")
        
        XCTAssertThrowsError(try ParametricMapParser.parse(from: dataSet)) { error in
            if case DICOMError.parsingFailed(let message) = error {
                XCTAssertTrue(message.contains("Series Instance UID"))
            } else {
                XCTFail("Expected parsingFailed error")
            }
        }
    }
    
    func test_parseParametricMap_missingNumberOfFrames_throws() {
        var dataSet = DataSet()
        dataSet.append(.sopInstanceUID, "1.2.3.4.5")
        dataSet.append(.seriesInstanceUID, "1.2.3.4")
        dataSet.append(.studyInstanceUID, "1.2.3")
        dataSet.append(.rows, UInt16(256))
        dataSet.append(.columns, UInt16(256))
        
        XCTAssertThrowsError(try ParametricMapParser.parse(from: dataSet)) { error in
            if case DICOMError.parsingFailed(let message) = error {
                XCTAssertTrue(message.contains("Number of Frames"))
            } else {
                XCTFail("Expected parsingFailed error")
            }
        }
    }
}
