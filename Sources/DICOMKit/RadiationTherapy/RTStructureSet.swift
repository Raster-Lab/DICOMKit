//
// RTStructureSet.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// DICOM RT Structure Set IOD
///
/// An RT Structure Set defines regions of interest (ROIs) used in radiation therapy planning.
/// Each ROI consists of one or more contours that define anatomical or planning structures
/// such as target volumes, organs at risk, and external body contours.
///
/// Reference: PS3.3 A.19 - RT Structure Set IOD
/// Reference: PS3.3 C.8.8.5 - Structure Set Module
/// Reference: PS3.3 C.8.8.6 - ROI Contour Module
/// Reference: PS3.3 C.8.8.8 - RT ROI Observations Module
public struct RTStructureSet: Sendable {
    
    // MARK: - Structure Set Identification
    
    /// SOP Instance UID
    public let sopInstanceUID: String
    
    /// SOP Class UID (should be RT Structure Set Storage: 1.2.840.10008.5.1.4.1.1.481.3)
    public let sopClassUID: String
    
    /// Structure Set Label
    public let label: String?
    
    /// Structure Set Name
    public let name: String?
    
    /// Structure Set Description
    public let description: String?
    
    /// Structure Set Date
    public let date: DICOMDate?
    
    /// Structure Set Time
    public let time: DICOMTime?
    
    // MARK: - Referenced Frame of Reference
    
    /// Frame of Reference UID
    public let frameOfReferenceUID: String?
    
    /// Referenced Study Instance UID
    public let referencedStudyInstanceUID: String?
    
    /// Referenced Series Instance UIDs
    public let referencedSeriesInstanceUIDs: [String]
    
    // MARK: - Regions of Interest
    
    /// Structure Set ROIs (regions of interest)
    public let rois: [RTRegionOfInterest]
    
    /// ROI contours (geometric definitions)
    public let roiContours: [ROIContour]
    
    /// ROI observations (clinical interpretations)
    public let roiObservations: [RTROIObservation]
    
    // MARK: - Initialization
    
    /// Initialize an RT Structure Set
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.481.3",
        label: String? = nil,
        name: String? = nil,
        description: String? = nil,
        date: DICOMDate? = nil,
        time: DICOMTime? = nil,
        frameOfReferenceUID: String? = nil,
        referencedStudyInstanceUID: String? = nil,
        referencedSeriesInstanceUIDs: [String] = [],
        rois: [RTRegionOfInterest] = [],
        roiContours: [ROIContour] = [],
        roiObservations: [RTROIObservation] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.label = label
        self.name = name
        self.description = description
        self.date = date
        self.time = time
        self.frameOfReferenceUID = frameOfReferenceUID
        self.referencedStudyInstanceUID = referencedStudyInstanceUID
        self.referencedSeriesInstanceUIDs = referencedSeriesInstanceUIDs
        self.rois = rois
        self.roiContours = roiContours
        self.roiObservations = roiObservations
    }
}

// MARK: - RTRegionOfInterest

/// RT Region of Interest (ROI)
///
/// Represents a structure defined in a radiation therapy plan, such as a tumor volume,
/// organ at risk, or external body contour.
///
/// Reference: PS3.3 C.8.8.5 - Structure Set Module
public struct RTRegionOfInterest: Sendable, Hashable, Identifiable {
    
    /// ROI number (unique within the structure set)
    public let number: Int
    
    /// ROI name
    public let name: String
    
    /// ROI description
    public let description: String?
    
    /// Frame of Reference UID for this ROI
    public let frameOfReferenceUID: String?
    
    /// ROI generation algorithm
    public let generationAlgorithm: String?
    
    /// ROI generation description
    public let generationDescription: String?
    
    /// Identifiable conformance
    public var id: Int { number }
    
    /// Initialize an RT Region of Interest
    public init(
        number: Int,
        name: String,
        description: String? = nil,
        frameOfReferenceUID: String? = nil,
        generationAlgorithm: String? = nil,
        generationDescription: String? = nil
    ) {
        self.number = number
        self.name = name
        self.description = description
        self.frameOfReferenceUID = frameOfReferenceUID
        self.generationAlgorithm = generationAlgorithm
        self.generationDescription = generationDescription
    }
}

// MARK: - ROIContour

/// ROI Contour
///
/// Contains the geometric definition of an ROI as a sequence of contours.
/// Each contour defines a closed planar curve on a specific image slice.
///
/// Reference: PS3.3 C.8.8.6 - ROI Contour Module
public struct ROIContour: Sendable {
    
    /// Referenced ROI number
    public let roiNumber: Int
    
    /// ROI display color (RGB, 0-255)
    public let displayColor: DisplayColor?
    
    /// Contours that define this ROI
    public let contours: [Contour]
    
    /// Initialize an ROI Contour
    public init(
        roiNumber: Int,
        displayColor: DisplayColor? = nil,
        contours: [Contour] = []
    ) {
        self.roiNumber = roiNumber
        self.displayColor = displayColor
        self.contours = contours
    }
}

// MARK: - DisplayColor

/// RGB color for ROI display
public struct DisplayColor: Sendable, Hashable {
    /// Red component (0-255)
    public let red: Int
    
    /// Green component (0-255)
    public let green: Int
    
    /// Blue component (0-255)
    public let blue: Int
    
    /// Initialize a display color
    public init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

// MARK: - Contour

/// Contour
///
/// A single contour defining a closed planar curve in 3D patient space.
/// Contour points are specified in millimeters in the patient coordinate system.
///
/// Reference: PS3.3 C.8.8.6 - ROI Contour Module
public struct Contour: Sendable {
    
    /// Geometric type of the contour
    public let geometricType: ContourGeometricType
    
    /// Number of contour points
    public let numberOfPoints: Int
    
    /// Contour data points (x, y, z coordinates in mm)
    /// Array of 3D points where each point is (x, y, z)
    public let points: [Point3D]
    
    /// Referenced SOP Instance UID (the image this contour is drawn on)
    public let referencedSOPInstanceUID: String?
    
    /// Contour slab thickness (mm)
    public let slabThickness: Double?
    
    /// Contour offset vector
    public let offsetVector: Vector3D?
    
    /// Initialize a Contour
    public init(
        geometricType: ContourGeometricType,
        numberOfPoints: Int,
        points: [Point3D],
        referencedSOPInstanceUID: String? = nil,
        slabThickness: Double? = nil,
        offsetVector: Vector3D? = nil
    ) {
        self.geometricType = geometricType
        self.numberOfPoints = numberOfPoints
        self.points = points
        self.referencedSOPInstanceUID = referencedSOPInstanceUID
        self.slabThickness = slabThickness
        self.offsetVector = offsetVector
    }
}

// MARK: - Vector3D

/// 3D vector in patient coordinate system
public struct Vector3D: Sendable, Hashable {
    /// X component
    public let x: Double
    
    /// Y component
    public let y: Double
    
    /// Z component
    public let z: Double
    
    /// Initialize a 3D vector
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Point3D

/// 3D point in patient coordinate system
public struct Point3D: Sendable, Hashable {
    /// X coordinate (mm)
    public let x: Double
    
    /// Y coordinate (mm)
    public let y: Double
    
    /// Z coordinate (mm)
    public let z: Double
    
    /// Initialize a 3D point
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - ContourGeometricType

/// Contour geometric type
///
/// Reference: PS3.3 C.8.8.6 - ROI Contour Module
public enum ContourGeometricType: String, Sendable, Hashable {
    /// Single point
    case point = "POINT"
    
    /// Open planar curve (polyline)
    case openPlanar = "OPEN_PLANAR"
    
    /// Closed planar curve (polygon)
    case closedPlanar = "CLOSED_PLANAR"
    
    /// Open non-planar curve
    case openNonplanar = "OPEN_NONPLANAR"
    
    /// Closed non-planar curve
    case closedNonplanar = "CLOSED_NONPLANAR"
}

// MARK: - RTROIObservation

/// RT ROI Observation
///
/// Clinical interpretation and metadata for an ROI, including the interpreted type
/// (e.g., PTV, GTV, organ at risk) and optional physical properties.
///
/// Reference: PS3.3 C.8.8.8 - RT ROI Observations Module
public struct RTROIObservation: Sendable, Hashable {
    
    /// Observation number (unique within structure set)
    public let observationNumber: Int
    
    /// Referenced ROI number
    public let referencedROINumber: Int
    
    /// RT ROI interpreted type (e.g., PTV, CTV, ORGAN)
    public let interpretedType: RTROIInterpretedType?
    
    /// ROI interpreter (person or algorithm)
    public let interpreter: String?
    
    /// ROI physical properties
    public let physicalProperties: [ROIPhysicalProperty]
    
    /// Initialize an RT ROI Observation
    public init(
        observationNumber: Int,
        referencedROINumber: Int,
        interpretedType: RTROIInterpretedType? = nil,
        interpreter: String? = nil,
        physicalProperties: [ROIPhysicalProperty] = []
    ) {
        self.observationNumber = observationNumber
        self.referencedROINumber = referencedROINumber
        self.interpretedType = interpretedType
        self.interpreter = interpreter
        self.physicalProperties = physicalProperties
    }
}

// MARK: - RTROIInterpretedType

/// RT ROI Interpreted Type
///
/// Standard clinical interpretations for radiation therapy ROIs.
///
/// Reference: PS3.3 C.8.8.8 - RT ROI Observations Module
public enum RTROIInterpretedType: String, Sendable, Hashable {
    /// Planning Target Volume
    case ptv = "PTV"
    
    /// Clinical Target Volume
    case ctv = "CTV"
    
    /// Gross Tumor Volume
    case gtv = "GTV"
    
    /// Treated Volume
    case treatedVolume = "TREATED_VOLUME"
    
    /// Irradiated Volume
    case irradiatedVolume = "IRRADIATED_VOLUME"
    
    /// Organ at Risk
    case organ = "ORGAN"
    
    /// External body contour
    case external = "EXTERNAL"
    
    /// Avoidance structure
    case avoidance = "AVOIDANCE"
    
    /// Cavity
    case cavity = "CAVITY"
    
    /// Contrast Agent
    case contrastAgent = "CONTRAST_AGENT"
    
    /// Bolus
    case bolus = "BOLUS"
    
    /// Marker/Fiducial
    case marker = "MARKER"
    
    /// Registration structure
    case registration = "REGISTRATION"
    
    /// ISOCENTER
    case isocenter = "ISOCENTER"
    
    /// Control point
    case controlPoint = "CONTROL"
    
    /// Dose region
    case doseRegion = "DOSE_REGION"
    
    /// Support structure
    case support = "SUPPORT"
    
    /// Fixation device
    case fixationDevice = "FIXATION_DEVICE"
}

// MARK: - ROIPhysicalProperty

/// ROI Physical Property
///
/// Physical properties of an ROI such as density or elemental composition.
///
/// Reference: PS3.3 C.8.8.8 - RT ROI Observations Module
public struct ROIPhysicalProperty: Sendable, Hashable {
    
    /// Physical property type (e.g., "REL_ELEC_DENSITY", "REL_MASS_DENSITY")
    public let property: String
    
    /// Physical property value
    public let value: Double
    
    /// Initialize an ROI Physical Property
    public init(property: String, value: Double) {
        self.property = property
        self.value = value
    }
}
