//
// RTPlanTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class RTPlanTests: XCTestCase {
    
    // MARK: - RTPlan Tests
    
    func test_rtPlan_initialization() {
        let plan = RTPlan(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.481.5",
            label: "Test Plan",
            name: "Prostate IMRT"
        )
        
        XCTAssertEqual(plan.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(plan.sopClassUID, "1.2.840.10008.5.1.4.1.1.481.5")
        XCTAssertEqual(plan.label, "Test Plan")
        XCTAssertEqual(plan.name, "Prostate IMRT")
        XCTAssertEqual(plan.doseReferences.count, 0)
        XCTAssertEqual(plan.fractionGroups.count, 0)
        XCTAssertEqual(plan.beams.count, 0)
        XCTAssertEqual(plan.brachyApplicationSetups.count, 0)
    }
    
    func test_rtPlan_withDoseReferences() {
        let doseRef1 = DoseReference(
            number: 1,
            structureType: "VOLUME",
            type: "TARGET",
            targetPrescriptionDose: 78.0
        )
        let doseRef2 = DoseReference(
            number: 2,
            structureType: "VOLUME",
            type: "ORGAN_AT_RISK",
            organAtRiskMaximumDose: 45.0
        )
        
        let plan = RTPlan(
            sopInstanceUID: "1.2.3.4.5",
            doseReferences: [doseRef1, doseRef2]
        )
        
        XCTAssertEqual(plan.doseReferences.count, 2)
        XCTAssertEqual(plan.doseReferences[0].number, 1)
        XCTAssertEqual(plan.doseReferences[0].targetPrescriptionDose, 78.0)
        XCTAssertEqual(plan.doseReferences[1].number, 2)
        XCTAssertEqual(plan.doseReferences[1].organAtRiskMaximumDose, 45.0)
    }
    
    func test_rtPlan_withFractionGroups() {
        let fractionGroup = FractionGroup(
            number: 1,
            description: "Initial treatment",
            numberOfFractionsPlanned: 39,
            numberOfFractionsPerDay: 1,
            referencedBeamNumbers: [1, 2, 3]
        )
        
        let plan = RTPlan(
            sopInstanceUID: "1.2.3.4.5",
            fractionGroups: [fractionGroup]
        )
        
        XCTAssertEqual(plan.numberOfFractionGroups, 1)
        XCTAssertEqual(plan.fractionGroups[0].numberOfFractionsPlanned, 39)
        XCTAssertEqual(plan.fractionGroups[0].referencedBeamNumbers, [1, 2, 3])
    }
    
    func test_rtPlan_withBeams() {
        let beam1 = RTBeam(
            number: 1,
            name: "AP Beam",
            type: "STATIC",
            radiationType: "PHOTON"
        )
        let beam2 = RTBeam(
            number: 2,
            name: "PA Beam",
            type: "STATIC",
            radiationType: "PHOTON"
        )
        
        let plan = RTPlan(
            sopInstanceUID: "1.2.3.4.5",
            beams: [beam1, beam2]
        )
        
        XCTAssertEqual(plan.numberOfBeams, 2)
        XCTAssertEqual(plan.beams[0].name, "AP Beam")
        XCTAssertEqual(plan.beams[1].name, "PA Beam")
    }
    
    // MARK: - DoseReference Tests
    
    func test_doseReference_initialization() {
        let doseRef = DoseReference(
            number: 1,
            uid: "1.2.3.4.5.6",
            structureType: "VOLUME",
            description: "PTV prescription",
            type: "TARGET",
            targetPrescriptionDose: 78.0,
            targetMaximumDose: 82.0,
            targetMinimumDose: 74.0,
            referencedROINumber: 1
        )
        
        XCTAssertEqual(doseRef.number, 1)
        XCTAssertEqual(doseRef.uid, "1.2.3.4.5.6")
        XCTAssertEqual(doseRef.structureType, "VOLUME")
        XCTAssertEqual(doseRef.description, "PTV prescription")
        XCTAssertEqual(doseRef.type, "TARGET")
        XCTAssertEqual(doseRef.targetPrescriptionDose, 78.0)
        XCTAssertEqual(doseRef.targetMaximumDose, 82.0)
        XCTAssertEqual(doseRef.targetMinimumDose, 74.0)
        XCTAssertEqual(doseRef.referencedROINumber, 1)
    }
    
    func test_doseReference_identifiable() {
        let doseRef = DoseReference(number: 42, type: "TARGET")
        XCTAssertEqual(doseRef.id, 42)
    }
    
    // MARK: - FractionGroup Tests
    
    func test_fractionGroup_initialization() {
        let fractionGroup = FractionGroup(
            number: 1,
            description: "Treatment phase 1",
            numberOfFractionsPlanned: 30,
            numberOfFractionsPerDay: 1,
            repeatFractionCycleLength: 5,
            fractionPattern: "11111",
            numberOfBeams: 5,
            referencedBeamNumbers: [1, 2, 3, 4, 5],
            numberOfBrachyApplicationSetups: 0,
            referencedBrachyApplicationSetupNumbers: []
        )
        
        XCTAssertEqual(fractionGroup.number, 1)
        XCTAssertEqual(fractionGroup.description, "Treatment phase 1")
        XCTAssertEqual(fractionGroup.numberOfFractionsPlanned, 30)
        XCTAssertEqual(fractionGroup.numberOfFractionsPerDay, 1)
        XCTAssertEqual(fractionGroup.repeatFractionCycleLength, 5)
        XCTAssertEqual(fractionGroup.fractionPattern, "11111")
        XCTAssertEqual(fractionGroup.numberOfBeams, 5)
        XCTAssertEqual(fractionGroup.referencedBeamNumbers.count, 5)
    }
    
    func test_fractionGroup_identifiable() {
        let fractionGroup = FractionGroup(number: 2)
        XCTAssertEqual(fractionGroup.id, 2)
    }
    
    // MARK: - BrachyApplicationSetup Tests
    
    func test_brachyApplicationSetup_initialization() {
        let channel1 = BrachyChannel(
            number: 1,
            length: 150.0,
            totalTime: 300.0,
            sourceIsotopeName: "Ir-192"
        )
        
        let setup = BrachyApplicationSetup(
            number: 1,
            type: "HDR",
            name: "Prostate HDR",
            manufacturer: "Varian",
            templateName: "Standard Prostate Template",
            templateType: "STANDARD",
            totalReferenceAirKerma: 1.5,
            channels: [channel1]
        )
        
        XCTAssertEqual(setup.number, 1)
        XCTAssertEqual(setup.type, "HDR")
        XCTAssertEqual(setup.name, "Prostate HDR")
        XCTAssertEqual(setup.manufacturer, "Varian")
        XCTAssertEqual(setup.templateName, "Standard Prostate Template")
        XCTAssertEqual(setup.templateType, "STANDARD")
        XCTAssertEqual(setup.totalReferenceAirKerma, 1.5)
        XCTAssertEqual(setup.channels.count, 1)
    }
    
    func test_brachyApplicationSetup_identifiable() {
        let setup = BrachyApplicationSetup(number: 3, type: "LDR")
        XCTAssertEqual(setup.id, 3)
    }
    
    // MARK: - BrachyChannel Tests
    
    func test_brachyChannel_initialization() {
        let controlPoint1 = BrachyControlPoint(
            index: 0,
            relativePosition: 0.0,
            cumulativeTimeWeight: 0.0
        )
        let controlPoint2 = BrachyControlPoint(
            index: 1,
            relativePosition: 10.0,
            cumulativeTimeWeight: 0.5
        )
        
        let channel = BrachyChannel(
            number: 1,
            length: 150.0,
            totalTime: 600.0,
            sourceIsotopeName: "Ir-192",
            sourceIsotopeHalfLife: 73.83,
            referenceAirKermaRate: 40800.0,
            controlPoints: [controlPoint1, controlPoint2]
        )
        
        XCTAssertEqual(channel.number, 1)
        XCTAssertEqual(channel.length, 150.0)
        XCTAssertEqual(channel.totalTime, 600.0)
        XCTAssertEqual(channel.sourceIsotopeName, "Ir-192")
        XCTAssertEqual(channel.sourceIsotopeHalfLife, 73.83)
        XCTAssertEqual(channel.referenceAirKermaRate, 40800.0)
        XCTAssertEqual(channel.controlPoints.count, 2)
    }
    
    // MARK: - BrachyControlPoint Tests
    
    func test_brachyControlPoint_initialization() {
        let position = Point3D(x: 10.0, y: 20.0, z: 30.0)
        let controlPoint = BrachyControlPoint(
            index: 5,
            relativePosition: 25.5,
            position3D: position,
            cumulativeTimeWeight: 0.75
        )
        
        XCTAssertEqual(controlPoint.index, 5)
        XCTAssertEqual(controlPoint.relativePosition, 25.5)
        XCTAssertEqual(controlPoint.position3D?.x, 10.0)
        XCTAssertEqual(controlPoint.position3D?.y, 20.0)
        XCTAssertEqual(controlPoint.position3D?.z, 30.0)
        XCTAssertEqual(controlPoint.cumulativeTimeWeight, 0.75)
    }
}
