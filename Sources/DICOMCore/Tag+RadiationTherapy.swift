//
// Tag+RadiationTherapy.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// DICOM tags for Radiation Therapy (RT) related modules
///
/// Reference: PS3.6 Section 6 - Registry of DICOM Data Elements
/// RT tags are in group 0x3006
extension Tag {
    
    // MARK: - Structure Set Module (PS3.3 C.8.8.5)
    
    /// Structure Set Label (3006,0002)
    public static let structureSetLabel = Tag(group: 0x3006, element: 0x0002)
    
    /// Structure Set Name (3006,0004)
    public static let structureSetName = Tag(group: 0x3006, element: 0x0004)
    
    /// Structure Set Description (3006,0006)
    public static let structureSetDescription = Tag(group: 0x3006, element: 0x0006)
    
    /// Structure Set Date (3006,0008)
    public static let structureSetDate = Tag(group: 0x3006, element: 0x0008)
    
    /// Structure Set Time (3006,0009)
    public static let structureSetTime = Tag(group: 0x3006, element: 0x0009)
    
    /// Referenced Frame of Reference Sequence (3006,0010)
    public static let referencedFrameOfReferenceSequence = Tag(group: 0x3006, element: 0x0010)
    
    /// Structure Set ROI Sequence (3006,0020)
    public static let structureSetROISequence = Tag(group: 0x3006, element: 0x0020)
    
    // MARK: - Structure Set ROI Sequence Item Attributes
    
    /// ROI Number (3006,0022)
    public static let roiNumber = Tag(group: 0x3006, element: 0x0022)
    
    /// Referenced Frame of Reference UID (3006,0024)
    public static let referencedFrameOfReferenceUID = Tag(group: 0x3006, element: 0x0024)
    
    /// ROI Name (3006,0026)
    public static let roiName = Tag(group: 0x3006, element: 0x0026)
    
    /// ROI Description (3006,0028)
    public static let roiDescription = Tag(group: 0x3006, element: 0x0028)
    
    /// ROI Generation Algorithm (3006,0036)
    public static let roiGenerationAlgorithm = Tag(group: 0x3006, element: 0x0036)
    
    /// ROI Generation Description (3006,0038)
    public static let roiGenerationDescription = Tag(group: 0x3006, element: 0x0038)
    
    // MARK: - ROI Contour Module (PS3.3 C.8.8.6)
    
    /// ROI Contour Sequence (3006,0039)
    public static let roiContourSequence = Tag(group: 0x3006, element: 0x0039)
    
    /// Contour Sequence (3006,0040)
    public static let contourSequence = Tag(group: 0x3006, element: 0x0040)
    
    /// Contour Geometric Type (3006,0042)
    public static let contourGeometricType = Tag(group: 0x3006, element: 0x0042)
    
    /// Contour Slab Thickness (3006,0044)
    public static let contourSlabThickness = Tag(group: 0x3006, element: 0x0044)
    
    /// Contour Offset Vector (3006,0045)
    public static let contourOffsetVector = Tag(group: 0x3006, element: 0x0045)
    
    /// Number of Contour Points (3006,0046)
    public static let numberOfContourPoints = Tag(group: 0x3006, element: 0x0046)
    
    /// Contour Data (3006,0050)
    public static let contourData = Tag(group: 0x3006, element: 0x0050)
    
    /// ROI Display Color (3006,002A)
    public static let roiDisplayColor = Tag(group: 0x3006, element: 0x002A)
    
    // MARK: - Contour Image Sequence Attributes
    
    /// Contour Image Sequence (3006,0016)
    public static let contourImageSequence = Tag(group: 0x3006, element: 0x0016)
    
    // MARK: - RT ROI Observations Module (PS3.3 C.8.8.8)
    
    /// RT ROI Observations Sequence (3006,0080)
    public static let rtROIObservationsSequence = Tag(group: 0x3006, element: 0x0080)
    
    /// Observation Number (3006,0082)
    public static let observationNumber = Tag(group: 0x3006, element: 0x0082)
    
    /// Referenced ROI Number (3006,0084)
    public static let referencedROINumber = Tag(group: 0x3006, element: 0x0084)
    
    /// RT ROI Interpreted Type (3006,00A4)
    public static let rtROIInterpretedType = Tag(group: 0x3006, element: 0x00A4)
    
    /// ROI Interpreter (3006,00A6)
    public static let roiInterpreter = Tag(group: 0x3006, element: 0x00A6)
    
    /// ROI Physical Properties Sequence (3006,00B0)
    public static let roiPhysicalPropertiesSequence = Tag(group: 0x3006, element: 0x00B0)
    
    /// ROI Physical Property (3006,00B2)
    public static let roiPhysicalProperty = Tag(group: 0x3006, element: 0x00B2)
    
    /// ROI Physical Property Value (3006,00B4)
    public static let roiPhysicalPropertyValue = Tag(group: 0x3006, element: 0x00B4)
    
    /// ROI Elemental Composition Sequence (3006,00B7)
    public static let roiElementalCompositionSequence = Tag(group: 0x3006, element: 0x00B7)
    
    // MARK: - RT Series Module (PS3.3 C.8.8.1)
    
    /// Modality (0008,0060) - typically "RTSTRUCT"
    /// Already defined in Tag+ImageInformation
    
    /// Series Description (0008,103E)
    /// Already defined in Tag+SeriesInformation
    
    // MARK: - Referenced Study and Series
    
    /// RT Referenced Study Sequence (3006,0012)
    public static let rtReferencedStudySequence = Tag(group: 0x3006, element: 0x0012)
    
    /// RT Referenced Series Sequence (3006,0014)
    public static let rtReferencedSeriesSequence = Tag(group: 0x3006, element: 0x0014)
}
