//
// RTBeam.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// RT Beam
///
/// Defines an external beam radiation therapy beam with control points that
/// specify the beam state at different positions during treatment delivery.
///
/// Reference: PS3.3 C.8.8.14 - RT General Plan Module
/// Reference: PS3.3 C.8.8.25 - RT Beams Module
public struct RTBeam: Sendable, Identifiable {
    
    // MARK: - Beam Identification
    
    /// Beam Number (unique within plan)
    public let number: Int
    
    /// Beam Name
    public let name: String?
    
    /// Beam Description
    public let description: String?
    
    /// Beam Type (STATIC, DYNAMIC, MODULATED, CONFORMAL)
    public let type: String?
    
    /// Radiation Type (PHOTON, ELECTRON, PROTON, NEUTRON, CARBON, etc.)
    public let radiationType: String?
    
    // MARK: - Machine Parameters
    
    /// Treatment Machine Name
    public let treatmentMachineName: String?
    
    /// Manufacturer
    public let manufacturer: String?
    
    /// Institution Name
    public let institutionName: String?
    
    /// Primary Dosimeter Unit (MU, MINUTES, DEGREE, etc.)
    public let primaryDosimeterUnit: String?
    
    /// Source-Axis Distance (SAD) in mm
    public let sourceAxisDistance: Double?
    
    // MARK: - Beam Delivery
    
    /// Number of Control Points
    public var numberOfControlPoints: Int {
        controlPoints.count
    }
    
    /// Control Points defining beam state at different positions
    public let controlPoints: [BeamControlPoint]
    
    /// Final Cumulative Meterset Weight (typically 1.0)
    public let finalCumulativeMetersetWeight: Double?
    
    /// Number of Wedges
    public let numberOfWedges: Int?
    
    /// Number of Compensators
    public let numberOfCompensators: Int?
    
    /// Number of Boli
    public let numberOfBoli: Int?
    
    /// Number of Blocks
    public let numberOfBlocks: Int?
    
    // MARK: - Treatment Delivery
    
    /// Treatment Delivery Type (TREATMENT, OPEN_PORTFILM, TRMT_PORTFILM, etc.)
    public let treatmentDeliveryType: String?
    
    /// High-Dose Technique Type (3D, IMRT, ARC, VMAT, SBRT, SRS)
    public let highDoseTechniqueType: String?
    
    /// Referenced Patient Setup Number
    public let referencedPatientSetupNumber: Int?
    
    /// Referenced Tolerance Table Number
    public let referencedToleranceTableNumber: Int?
    
    // MARK: - Identifiable Conformance
    
    public var id: Int { number }
    
    // MARK: - Initialization
    
    /// Initialize an RT Beam
    public init(
        number: Int,
        name: String? = nil,
        description: String? = nil,
        type: String? = nil,
        radiationType: String? = nil,
        treatmentMachineName: String? = nil,
        manufacturer: String? = nil,
        institutionName: String? = nil,
        primaryDosimeterUnit: String? = nil,
        sourceAxisDistance: Double? = nil,
        controlPoints: [BeamControlPoint] = [],
        finalCumulativeMetersetWeight: Double? = nil,
        numberOfWedges: Int? = nil,
        numberOfCompensators: Int? = nil,
        numberOfBoli: Int? = nil,
        numberOfBlocks: Int? = nil,
        treatmentDeliveryType: String? = nil,
        highDoseTechniqueType: String? = nil,
        referencedPatientSetupNumber: Int? = nil,
        referencedToleranceTableNumber: Int? = nil
    ) {
        self.number = number
        self.name = name
        self.description = description
        self.type = type
        self.radiationType = radiationType
        self.treatmentMachineName = treatmentMachineName
        self.manufacturer = manufacturer
        self.institutionName = institutionName
        self.primaryDosimeterUnit = primaryDosimeterUnit
        self.sourceAxisDistance = sourceAxisDistance
        self.controlPoints = controlPoints
        self.finalCumulativeMetersetWeight = finalCumulativeMetersetWeight
        self.numberOfWedges = numberOfWedges
        self.numberOfCompensators = numberOfCompensators
        self.numberOfBoli = numberOfBoli
        self.numberOfBlocks = numberOfBlocks
        self.treatmentDeliveryType = treatmentDeliveryType
        self.highDoseTechniqueType = highDoseTechniqueType
        self.referencedPatientSetupNumber = referencedPatientSetupNumber
        self.referencedToleranceTableNumber = referencedToleranceTableNumber
    }
}

// MARK: - BeamControlPoint

/// Beam Control Point
///
/// Defines the beam state at a specific position during treatment delivery.
/// Control points specify gantry angle, collimator angle, jaw positions, MLC positions, etc.
///
/// Reference: PS3.3 C.8.8.25 - RT Beams Module
public struct BeamControlPoint: Sendable {
    
    /// Control Point Index
    public let index: Int
    
    /// Cumulative Meterset Weight (0.0 to 1.0)
    public let cumulativeMetersetWeight: Double?
    
    // MARK: - Geometric Parameters
    
    /// Gantry Angle (degrees, 0-360)
    public let gantryAngle: Double?
    
    /// Gantry Rotation Direction (CW, CC, NONE)
    public let gantryRotationDirection: String?
    
    /// Beam Limiting Device Angle (collimator angle, degrees)
    public let beamLimitingDeviceAngle: Double?
    
    /// Beam Limiting Device Rotation Direction (CW, CC, NONE)
    public let beamLimitingDeviceRotationDirection: String?
    
    /// Patient Support Angle (couch angle, degrees)
    public let patientSupportAngle: Double?
    
    /// Patient Support Rotation Direction (CW, CC, NONE)
    public let patientSupportRotationDirection: String?
    
    /// Table Top Vertical Position (mm)
    public let tableTopVerticalPosition: Double?
    
    /// Table Top Longitudinal Position (mm)
    public let tableTopLongitudinalPosition: Double?
    
    /// Table Top Lateral Position (mm)
    public let tableTopLateralPosition: Double?
    
    // MARK: - Isocenter Position
    
    /// Isocenter Position (x, y, z in mm)
    public let isocenterPosition: Point3D?
    
    /// Surface Entry Point (x, y, z in mm)
    public let surfaceEntryPoint: Point3D?
    
    // MARK: - Source Position
    
    /// Source to Surface Distance (SSD, mm)
    public let sourceToSurfaceDistance: Double?
    
    /// Source to External Contour Distance (mm)
    public let sourceToExternalContourDistance: Double?
    
    // MARK: - Beam Limiting Devices
    
    /// Beam Limiting Device Positions (jaws, MLC leaves)
    public let beamLimitingDevicePositions: [BeamLimitingDevicePosition]
    
    // MARK: - Dose Parameters
    
    /// Nominal Beam Energy (MeV)
    public let nominalBeamEnergy: Double?
    
    /// Dose Rate Set (MU/min or Gy/min)
    public let doseRateSet: Double?
    
    // MARK: - Wedge and Compensator
    
    /// Wedge Position Sequence
    public let wedgePositions: [WedgePosition]
    
    // MARK: - Scanning Spot Parameters (for proton/particle therapy)
    
    /// Scan Spot Meterset Weights
    public let scanSpotMetersetWeights: [Double]
    
    /// Scan Spot Position Map (x, y positions)
    public let scanSpotPositionMap: [(x: Float, y: Float)]
    
    /// Scan Spot Tune ID
    public let scanSpotTuneID: String?
    
    // MARK: - Initialization
    
    /// Initialize a Beam Control Point
    public init(
        index: Int,
        cumulativeMetersetWeight: Double? = nil,
        gantryAngle: Double? = nil,
        gantryRotationDirection: String? = nil,
        beamLimitingDeviceAngle: Double? = nil,
        beamLimitingDeviceRotationDirection: String? = nil,
        patientSupportAngle: Double? = nil,
        patientSupportRotationDirection: String? = nil,
        tableTopVerticalPosition: Double? = nil,
        tableTopLongitudinalPosition: Double? = nil,
        tableTopLateralPosition: Double? = nil,
        isocenterPosition: Point3D? = nil,
        surfaceEntryPoint: Point3D? = nil,
        sourceToSurfaceDistance: Double? = nil,
        sourceToExternalContourDistance: Double? = nil,
        beamLimitingDevicePositions: [BeamLimitingDevicePosition] = [],
        nominalBeamEnergy: Double? = nil,
        doseRateSet: Double? = nil,
        wedgePositions: [WedgePosition] = [],
        scanSpotMetersetWeights: [Double] = [],
        scanSpotPositionMap: [(x: Float, y: Float)] = [],
        scanSpotTuneID: String? = nil
    ) {
        self.index = index
        self.cumulativeMetersetWeight = cumulativeMetersetWeight
        self.gantryAngle = gantryAngle
        self.gantryRotationDirection = gantryRotationDirection
        self.beamLimitingDeviceAngle = beamLimitingDeviceAngle
        self.beamLimitingDeviceRotationDirection = beamLimitingDeviceRotationDirection
        self.patientSupportAngle = patientSupportAngle
        self.patientSupportRotationDirection = patientSupportRotationDirection
        self.tableTopVerticalPosition = tableTopVerticalPosition
        self.tableTopLongitudinalPosition = tableTopLongitudinalPosition
        self.tableTopLateralPosition = tableTopLateralPosition
        self.isocenterPosition = isocenterPosition
        self.surfaceEntryPoint = surfaceEntryPoint
        self.sourceToSurfaceDistance = sourceToSurfaceDistance
        self.sourceToExternalContourDistance = sourceToExternalContourDistance
        self.beamLimitingDevicePositions = beamLimitingDevicePositions
        self.nominalBeamEnergy = nominalBeamEnergy
        self.doseRateSet = doseRateSet
        self.wedgePositions = wedgePositions
        self.scanSpotMetersetWeights = scanSpotMetersetWeights
        self.scanSpotPositionMap = scanSpotPositionMap
        self.scanSpotTuneID = scanSpotTuneID
    }
}

// MARK: - BeamLimitingDevicePosition

/// Beam Limiting Device Position
///
/// Defines jaw or MLC (Multi-Leaf Collimator) positions for beam shaping.
///
/// Reference: PS3.3 C.8.8.25 - RT Beams Module
public struct BeamLimitingDevicePosition: Sendable {
    
    /// RT Beam Limiting Device Type (ASYMX, ASYMY, X, Y, MLCX, MLCY)
    public let type: String
    
    /// Number of Leaf/Jaw Pairs
    public let numberOfLeafJawPairs: Int?
    
    /// Leaf/Jaw Positions (mm, boundary pairs)
    /// For jaws: [X1, X2] or [Y1, Y2]
    /// For MLC: [A1, B1, A2, B2, ...] for each leaf pair
    public let positions: [Double]
    
    /// Initialize a Beam Limiting Device Position
    public init(
        type: String,
        numberOfLeafJawPairs: Int? = nil,
        positions: [Double]
    ) {
        self.type = type
        self.numberOfLeafJawPairs = numberOfLeafJawPairs
        self.positions = positions
    }
}

// MARK: - WedgePosition

/// Wedge Position
///
/// Defines wedge orientation and position in the beam.
///
/// Reference: PS3.3 C.8.8.25 - RT Beams Module
public struct WedgePosition: Sendable {
    
    /// Wedge Number
    public let number: Int
    
    /// Wedge Type (STANDARD, DYNAMIC, MOTORIZED)
    public let type: String?
    
    /// Wedge ID
    public let id: String?
    
    /// Wedge Angle (degrees)
    public let angle: Double?
    
    /// Wedge Factor
    public let factor: Double?
    
    /// Wedge Orientation (degrees from positive Y axis)
    public let orientation: Double?
    
    /// Wedge Position
    public let position: String?
    
    /// Initialize a Wedge Position
    public init(
        number: Int,
        type: String? = nil,
        id: String? = nil,
        angle: Double? = nil,
        factor: Double? = nil,
        orientation: Double? = nil,
        position: String? = nil
    ) {
        self.number = number
        self.type = type
        self.id = id
        self.angle = angle
        self.factor = factor
        self.orientation = orientation
        self.position = position
    }
}
