//
// RTPlan.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// DICOM RT Plan IOD
///
/// An RT Plan defines the treatment parameters for radiation therapy, including beam
/// configurations, control points, and dose prescriptions. RT Plans are used to guide
/// radiation delivery systems during patient treatment.
///
/// Reference: PS3.3 A.20 - RT Plan IOD
/// Reference: PS3.3 C.8.8.14 - RT General Plan Module
/// Reference: PS3.3 C.8.8.15 - RT Prescription Module
/// Reference: PS3.3 C.8.8.16 - RT Fraction Scheme Module
public struct RTPlan: Sendable {
    
    // MARK: - Plan Identification
    
    /// SOP Instance UID
    public let sopInstanceUID: String
    
    /// SOP Class UID (should be RT Plan Storage: 1.2.840.10008.5.1.4.1.1.481.5)
    public let sopClassUID: String
    
    /// RT Plan Label
    public let label: String?
    
    /// RT Plan Name
    public let name: String?
    
    /// RT Plan Description
    public let description: String?
    
    /// RT Plan Date
    public let date: DICOMDate?
    
    /// RT Plan Time
    public let time: DICOMTime?
    
    /// RT Plan Geometry (PATIENT or TREATMENT_DEVICE)
    public let geometry: String?
    
    // MARK: - Referenced Structure Set
    
    /// Referenced Structure Set SOP Instance UID
    public let referencedStructureSetUID: String?
    
    /// Referenced Dose SOP Instance UID
    public let referencedDoseUID: String?
    
    // MARK: - Prescription
    
    /// Prescription Description
    public let prescriptionDescription: String?
    
    /// Dose Reference Sequence
    public let doseReferences: [DoseReference]
    
    // MARK: - Fraction Groups
    
    /// Fraction Groups
    public let fractionGroups: [FractionGroup]
    
    /// Number of Fraction Groups
    public var numberOfFractionGroups: Int {
        fractionGroups.count
    }
    
    // MARK: - Beams
    
    /// Beams (external beam radiation)
    public let beams: [RTBeam]
    
    /// Number of Beams
    public var numberOfBeams: Int {
        beams.count
    }
    
    // MARK: - Brachytherapy
    
    /// Brachy Application Setups (brachytherapy)
    public let brachyApplicationSetups: [BrachyApplicationSetup]
    
    /// Number of Brachy Application Setups
    public var numberOfBrachyApplicationSetups: Int {
        brachyApplicationSetups.count
    }
    
    // MARK: - Initialization
    
    /// Initialize an RT Plan
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.481.5",
        label: String? = nil,
        name: String? = nil,
        description: String? = nil,
        date: DICOMDate? = nil,
        time: DICOMTime? = nil,
        geometry: String? = nil,
        referencedStructureSetUID: String? = nil,
        referencedDoseUID: String? = nil,
        prescriptionDescription: String? = nil,
        doseReferences: [DoseReference] = [],
        fractionGroups: [FractionGroup] = [],
        beams: [RTBeam] = [],
        brachyApplicationSetups: [BrachyApplicationSetup] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.label = label
        self.name = name
        self.description = description
        self.date = date
        self.time = time
        self.geometry = geometry
        self.referencedStructureSetUID = referencedStructureSetUID
        self.referencedDoseUID = referencedDoseUID
        self.prescriptionDescription = prescriptionDescription
        self.doseReferences = doseReferences
        self.fractionGroups = fractionGroups
        self.beams = beams
        self.brachyApplicationSetups = brachyApplicationSetups
    }
}

// MARK: - DoseReference

/// Dose Reference
///
/// Specifies a dose reference point or volume used for prescription and planning.
///
/// Reference: PS3.3 C.8.8.15 - RT Prescription Module
public struct DoseReference: Sendable, Identifiable {
    
    /// Dose Reference Number (unique within plan)
    public let number: Int
    
    /// Dose Reference UID
    public let uid: String?
    
    /// Dose Reference Structure Type (POINT, VOLUME, COORDINATES, SITE)
    public let structureType: String?
    
    /// Dose Reference Description
    public let description: String?
    
    /// Dose Reference Type (TARGET, ORGAN_AT_RISK)
    public let type: String?
    
    /// Target Prescription Dose (Gy)
    public let targetPrescriptionDose: Double?
    
    /// Target Maximum Dose (Gy)
    public let targetMaximumDose: Double?
    
    /// Target Minimum Dose (Gy)
    public let targetMinimumDose: Double?
    
    /// Organ at Risk Full-Volume Dose (Gy)
    public let organAtRiskFullVolumeDose: Double?
    
    /// Organ at Risk Maximum Dose (Gy)
    public let organAtRiskMaximumDose: Double?
    
    /// Referenced ROI Number
    public let referencedROINumber: Int?
    
    /// Identifiable conformance
    public var id: Int { number }
    
    /// Initialize a Dose Reference
    public init(
        number: Int,
        uid: String? = nil,
        structureType: String? = nil,
        description: String? = nil,
        type: String? = nil,
        targetPrescriptionDose: Double? = nil,
        targetMaximumDose: Double? = nil,
        targetMinimumDose: Double? = nil,
        organAtRiskFullVolumeDose: Double? = nil,
        organAtRiskMaximumDose: Double? = nil,
        referencedROINumber: Int? = nil
    ) {
        self.number = number
        self.uid = uid
        self.structureType = structureType
        self.description = description
        self.type = type
        self.targetPrescriptionDose = targetPrescriptionDose
        self.targetMaximumDose = targetMaximumDose
        self.targetMinimumDose = targetMinimumDose
        self.organAtRiskFullVolumeDose = organAtRiskFullVolumeDose
        self.organAtRiskMaximumDose = organAtRiskMaximumDose
        self.referencedROINumber = referencedROINumber
    }
}

// MARK: - FractionGroup

/// Fraction Group
///
/// Defines a group of treatment fractions with the same beam configuration.
///
/// Reference: PS3.3 C.8.8.16 - RT Fraction Scheme Module
public struct FractionGroup: Sendable, Identifiable {
    
    /// Fraction Group Number
    public let number: Int
    
    /// Fraction Group Description
    public let description: String?
    
    /// Number of Fractions Planned
    public let numberOfFractionsPlanned: Int?
    
    /// Number of Fractions Per Day
    public let numberOfFractionsPerDay: Int?
    
    /// Repeat Fraction Cycle Length (days)
    public let repeatFractionCycleLength: Int?
    
    /// Fraction Pattern
    public let fractionPattern: String?
    
    /// Number of Beams
    public let numberOfBeams: Int?
    
    /// Referenced Beam Numbers
    public let referencedBeamNumbers: [Int]
    
    /// Number of Brachy Application Setups
    public let numberOfBrachyApplicationSetups: Int?
    
    /// Referenced Brachy Application Setup Numbers
    public let referencedBrachyApplicationSetupNumbers: [Int]
    
    /// Identifiable conformance
    public var id: Int { number }
    
    /// Initialize a Fraction Group
    public init(
        number: Int,
        description: String? = nil,
        numberOfFractionsPlanned: Int? = nil,
        numberOfFractionsPerDay: Int? = nil,
        repeatFractionCycleLength: Int? = nil,
        fractionPattern: String? = nil,
        numberOfBeams: Int? = nil,
        referencedBeamNumbers: [Int] = [],
        numberOfBrachyApplicationSetups: Int? = nil,
        referencedBrachyApplicationSetupNumbers: [Int] = []
    ) {
        self.number = number
        self.description = description
        self.numberOfFractionsPlanned = numberOfFractionsPlanned
        self.numberOfFractionsPerDay = numberOfFractionsPerDay
        self.repeatFractionCycleLength = repeatFractionCycleLength
        self.fractionPattern = fractionPattern
        self.numberOfBeams = numberOfBeams
        self.referencedBeamNumbers = referencedBeamNumbers
        self.numberOfBrachyApplicationSetups = numberOfBrachyApplicationSetups
        self.referencedBrachyApplicationSetupNumbers = referencedBrachyApplicationSetupNumbers
    }
}

// MARK: - BrachyApplicationSetup

/// Brachytherapy Application Setup
///
/// Defines a brachytherapy applicator setup with source positions and dwell times.
///
/// Reference: PS3.3 C.8.8.23 - RT Brachy Application Setups Module
public struct BrachyApplicationSetup: Sendable, Identifiable {
    
    /// Application Setup Number
    public let number: Int
    
    /// Application Setup Type (MANUAL, HDR, LDR, PDR)
    public let type: String?
    
    /// Application Setup Name
    public let name: String?
    
    /// Application Setup Manufacturer
    public let manufacturer: String?
    
    /// Template Name
    public let templateName: String?
    
    /// Template Type (CUSTOM, STANDARD)
    public let templateType: String?
    
    /// Total Reference Air Kerma (Gy)
    public let totalReferenceAirKerma: Double?
    
    /// Channel Sequence (source channels)
    public let channels: [BrachyChannel]
    
    /// Identifiable conformance
    public var id: Int { number }
    
    /// Initialize a Brachytherapy Application Setup
    public init(
        number: Int,
        type: String? = nil,
        name: String? = nil,
        manufacturer: String? = nil,
        templateName: String? = nil,
        templateType: String? = nil,
        totalReferenceAirKerma: Double? = nil,
        channels: [BrachyChannel] = []
    ) {
        self.number = number
        self.type = type
        self.name = name
        self.manufacturer = manufacturer
        self.templateName = templateName
        self.templateType = templateType
        self.totalReferenceAirKerma = totalReferenceAirKerma
        self.channels = channels
    }
}

// MARK: - BrachyChannel

/// Brachytherapy Channel
///
/// Defines a single source channel with control points.
///
/// Reference: PS3.3 C.8.8.23 - RT Brachy Application Setups Module
public struct BrachyChannel: Sendable {
    
    /// Channel Number
    public let number: Int
    
    /// Channel Length (mm)
    public let length: Double?
    
    /// Channel Total Time (seconds)
    public let totalTime: Double?
    
    /// Source Isotope Name
    public let sourceIsotopeName: String?
    
    /// Source Isotope Half Life (days)
    public let sourceIsotopeHalfLife: Double?
    
    /// Reference Air Kerma Rate (μGy h⁻¹ at 1m)
    public let referenceAirKermaRate: Double?
    
    /// Control Points
    public let controlPoints: [BrachyControlPoint]
    
    /// Initialize a Brachytherapy Channel
    public init(
        number: Int,
        length: Double? = nil,
        totalTime: Double? = nil,
        sourceIsotopeName: String? = nil,
        sourceIsotopeHalfLife: Double? = nil,
        referenceAirKermaRate: Double? = nil,
        controlPoints: [BrachyControlPoint] = []
    ) {
        self.number = number
        self.length = length
        self.totalTime = totalTime
        self.sourceIsotopeName = sourceIsotopeName
        self.sourceIsotopeHalfLife = sourceIsotopeHalfLife
        self.referenceAirKermaRate = referenceAirKermaRate
        self.controlPoints = controlPoints
    }
}

// MARK: - BrachyControlPoint

/// Brachytherapy Control Point
///
/// Defines source position and dwell time at a specific location.
///
/// Reference: PS3.3 C.8.8.23 - RT Brachy Application Setups Module
public struct BrachyControlPoint: Sendable {
    
    /// Control Point Index
    public let index: Int
    
    /// Control Point Relative Position (mm from channel origin)
    public let relativePosition: Double?
    
    /// Control Point 3D Position (x, y, z in mm)
    public let position3D: Point3D?
    
    /// Cumulative Time Weight
    public let cumulativeTimeWeight: Double?
    
    /// Initialize a Brachytherapy Control Point
    public init(
        index: Int,
        relativePosition: Double? = nil,
        position3D: Point3D? = nil,
        cumulativeTimeWeight: Double? = nil
    ) {
        self.index = index
        self.relativePosition = relativePosition
        self.position3D = position3D
        self.cumulativeTimeWeight = cumulativeTimeWeight
    }
}
