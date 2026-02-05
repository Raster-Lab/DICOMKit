//
// RTDoseTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class RTDoseTests: XCTestCase {
    
    // MARK: - RTDose Tests
    
    func test_rtDose_initialization() {
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.481.2",
            comment: "Test dose distribution",
            summationType: "PLAN",
            type: "PHYSICAL",
            units: "GY",
            rows: 100,
            columns: 100,
            numberOfFrames: 50,
            doseGridScaling: 0.001
        )
        
        XCTAssertEqual(dose.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(dose.sopClassUID, "1.2.840.10008.5.1.4.1.1.481.2")
        XCTAssertEqual(dose.comment, "Test dose distribution")
        XCTAssertEqual(dose.summationType, "PLAN")
        XCTAssertEqual(dose.type, "PHYSICAL")
        XCTAssertEqual(dose.units, "GY")
        XCTAssertEqual(dose.rows, 100)
        XCTAssertEqual(dose.columns, 100)
        XCTAssertEqual(dose.numberOfFrames, 50)
        XCTAssertEqual(dose.doseGridScaling, 0.001)
    }
    
    func test_rtDose_withReferencedObjects() {
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            referencedRTPlanUID: "1.2.3.4.6",
            referencedStructureSetUID: "1.2.3.4.7",
            referencedFractionGroupNumber: 1,
            referencedBeamNumber: 2,
            rows: 100,
            columns: 100,
            numberOfFrames: 50,
            doseGridScaling: 0.001
        )
        
        XCTAssertEqual(dose.referencedRTPlanUID, "1.2.3.4.6")
        XCTAssertEqual(dose.referencedStructureSetUID, "1.2.3.4.7")
        XCTAssertEqual(dose.referencedFractionGroupNumber, 1)
        XCTAssertEqual(dose.referencedBeamNumber, 2)
    }
    
    func test_rtDose_withGeometry() {
        let imagePos = Point3D(x: -200.0, y: -200.0, z: -100.0)
        let pixelSpacing = (row: 2.0, column: 2.0)
        let gridOffsets = Array(stride(from: 0.0, to: 100.0, by: 2.0))
        
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            frameOfReferenceUID: "1.2.3.4.8",
            imagePosition: imagePos,
            imageOrientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            gridFrameOffsetVector: gridOffsets,
            pixelSpacing: pixelSpacing,
            sliceThickness: 2.0,
            rows: 200,
            columns: 200,
            numberOfFrames: 50,
            doseGridScaling: 0.001
        )
        
        XCTAssertEqual(dose.frameOfReferenceUID, "1.2.3.4.8")
        XCTAssertEqual(dose.imagePosition?.x, -200.0)
        XCTAssertEqual(dose.imagePosition?.y, -200.0)
        XCTAssertEqual(dose.imagePosition?.z, -100.0)
        XCTAssertEqual(dose.pixelSpacing?.row, 2.0)
        XCTAssertEqual(dose.pixelSpacing?.column, 2.0)
        XCTAssertEqual(dose.sliceThickness, 2.0)
        XCTAssertEqual(dose.gridFrameOffsetVector?.count, 50)
    }
    
    func test_rtDose_withStatistics() {
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            units: "GY",
            rows: 100,
            columns: 100,
            numberOfFrames: 50,
            doseGridScaling: 0.001,
            maximumDose: 82.5,
            minimumDose: 0.1,
            meanDose: 45.3
        )
        
        XCTAssertEqual(dose.maximumDose, 82.5)
        XCTAssertEqual(dose.minimumDose, 0.1)
        XCTAssertEqual(dose.meanDose, 45.3)
    }
    
    func test_rtDose_doseValueAccess_nil_withoutPixelData() {
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            rows: 100,
            columns: 100,
            numberOfFrames: 50,
            doseGridScaling: 0.001
        )
        
        // Without pixel data, should return nil
        XCTAssertNil(dose.doseValue(frame: 0, row: 0, column: 0))
        XCTAssertNil(dose.doseValue(frame: 25, row: 50, column: 50))
    }
    
    func test_rtDose_doseValueAccess_16bit() {
        // Create simple 2x2x2 dose grid
        let frame1 = [
            [UInt16(1000), UInt16(2000)],
            [UInt16(3000), UInt16(4000)]
        ]
        let frame2 = [
            [UInt16(5000), UInt16(6000)],
            [UInt16(7000), UInt16(8000)]
        ]
        let pixelData = [frame1, frame2]
        
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            rows: 2,
            columns: 2,
            numberOfFrames: 2,
            doseGridScaling: 0.001,
            pixelData: pixelData
        )
        
        // Test dose value access with scaling
        XCTAssertEqual(dose.doseValue(frame: 0, row: 0, column: 0) ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 0, column: 1) ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 1, column: 0) ?? 0, 3.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 1, column: 1) ?? 0, 4.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 1, row: 0, column: 0) ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 1, row: 1, column: 1) ?? 0, 8.0, accuracy: 0.001)
    }
    
    func test_rtDose_doseValueAccess_32bit() {
        // Create simple 2x2x1 dose grid with 32-bit data
        let frame1 = [
            [UInt32(100000), UInt32(200000)],
            [UInt32(300000), UInt32(400000)]
        ]
        let pixelData32 = [frame1]
        
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            rows: 2,
            columns: 2,
            numberOfFrames: 1,
            bitsAllocated: 32,
            bitsStored: 32,
            highBit: 31,
            doseGridScaling: 0.0001,
            pixelData32: pixelData32
        )
        
        // Test dose value access with scaling
        XCTAssertEqual(dose.doseValue(frame: 0, row: 0, column: 0) ?? 0, 10.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 0, column: 1) ?? 0, 20.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 1, column: 0) ?? 0, 30.0, accuracy: 0.001)
        XCTAssertEqual(dose.doseValue(frame: 0, row: 1, column: 1) ?? 0, 40.0, accuracy: 0.001)
    }
    
    func test_rtDose_doseValueAccess_outOfBounds() {
        let frame1 = [
            [UInt16(1000), UInt16(2000)],
            [UInt16(3000), UInt16(4000)]
        ]
        let pixelData = [frame1]
        
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            rows: 2,
            columns: 2,
            numberOfFrames: 1,
            doseGridScaling: 0.001,
            pixelData: pixelData
        )
        
        // Test out-of-bounds access
        XCTAssertNil(dose.doseValue(frame: -1, row: 0, column: 0))
        XCTAssertNil(dose.doseValue(frame: 1, row: 0, column: 0))
        XCTAssertNil(dose.doseValue(frame: 0, row: 2, column: 0))
        XCTAssertNil(dose.doseValue(frame: 0, row: 0, column: 2))
    }
    
    // MARK: - DVHData Tests
    
    func test_dvhData_initialization() {
        let dvhPairs = [
            (dose: 0.0, volume: 100.0),
            (dose: 10.0, volume: 95.0),
            (dose: 20.0, volume: 85.0),
            (dose: 30.0, volume: 70.0),
            (dose: 40.0, volume: 50.0),
            (dose: 50.0, volume: 30.0),
            (dose: 60.0, volume: 10.0),
            (dose: 70.0, volume: 0.0)
        ]
        
        let dvh = DVHData(
            type: "CUMULATIVE",
            doseUnits: "GY",
            doseType: "PHYSICAL",
            volumeUnits: "PERCENT",
            referencedROINumber: 1,
            minimumDose: 0.0,
            maximumDose: 78.5,
            meanDose: 45.2,
            data: dvhPairs
        )
        
        XCTAssertEqual(dvh.type, "CUMULATIVE")
        XCTAssertEqual(dvh.doseUnits, "GY")
        XCTAssertEqual(dvh.doseType, "PHYSICAL")
        XCTAssertEqual(dvh.volumeUnits, "PERCENT")
        XCTAssertEqual(dvh.referencedROINumber, 1)
        XCTAssertEqual(dvh.minimumDose, 0.0)
        XCTAssertEqual(dvh.maximumDose, 78.5)
        XCTAssertEqual(dvh.meanDose, 45.2)
        XCTAssertEqual(dvh.data.count, 8)
        XCTAssertEqual(dvh.data[4].dose, 40.0)
        XCTAssertEqual(dvh.data[4].volume, 50.0)
    }
    
    func test_dvhData_withNormalization() {
        let normPoint = Point3D(x: 0.0, y: 0.0, z: 0.0)
        
        let dvh = DVHData(
            type: "CUMULATIVE",
            doseUnits: "GY",
            referencedROINumber: 1,
            normalizationPoint: normPoint,
            normalizationDoseValue: 78.0,
            data: []
        )
        
        XCTAssertEqual(dvh.normalizationPoint?.x, 0.0)
        XCTAssertEqual(dvh.normalizationDoseValue, 78.0)
    }
    
    // MARK: - Integration Tests
    
    func test_rtDose_withDVHData() {
        let dvh1 = DVHData(
            type: "CUMULATIVE",
            doseUnits: "GY",
            volumeUnits: "CM3",
            referencedROINumber: 1,
            meanDose: 78.0,
            data: [(dose: 0.0, volume: 100.0), (dose: 78.0, volume: 95.0)]
        )
        
        let dvh2 = DVHData(
            type: "CUMULATIVE",
            doseUnits: "GY",
            volumeUnits: "CM3",
            referencedROINumber: 2,
            meanDose: 45.0,
            data: [(dose: 0.0, volume: 50.0), (dose: 45.0, volume: 40.0)]
        )
        
        let dose = RTDose(
            sopInstanceUID: "1.2.3.4.5",
            summationType: "PLAN",
            units: "GY",
            rows: 100,
            columns: 100,
            numberOfFrames: 50,
            doseGridScaling: 0.001,
            dvhData: [dvh1, dvh2]
        )
        
        XCTAssertEqual(dose.dvhData.count, 2)
        XCTAssertEqual(dose.dvhData[0].referencedROINumber, 1)
        XCTAssertEqual(dose.dvhData[0].meanDose, 78.0)
        XCTAssertEqual(dose.dvhData[1].referencedROINumber, 2)
        XCTAssertEqual(dose.dvhData[1].meanDose, 45.0)
    }
}
