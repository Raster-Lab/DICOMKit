//
// Tag+PresentationState.swift
// DICOMCore
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// DICOM tags for Grayscale Softcopy Presentation State
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
extension Tag {
    // MARK: - Presentation State Identification Module (C.11.10)
    
    /// Instance Number (0020,0013)
    public static let presentationInstanceNumber = Tag(group: 0x0020, element: 0x0013)
    
    /// Presentation Label (0070,0080)
    public static let presentationLabel = Tag(group: 0x0070, element: 0x0080)
    
    /// Presentation Description (0070,0081)
    public static let presentationDescription = Tag(group: 0x0070, element: 0x0081)
    
    /// Presentation Creation Date (0070,0082)
    public static let presentationCreationDate = Tag(group: 0x0070, element: 0x0082)
    
    /// Presentation Creation Time (0070,0083)
    public static let presentationCreationTime = Tag(group: 0x0070, element: 0x0083)
    
    /// Presentation Creator's Name (0070,0084)
    public static let presentationCreatorsName = Tag(group: 0x0070, element: 0x0084)
    
    // MARK: - Presentation State Relationship Module (C.11.11)
    
    /// Referenced Series Sequence (0008,1115)
    public static let referencedSeriesSequence = Tag(group: 0x0008, element: 0x1115)
    
    /// Referenced Image Sequence (0008,1140)
    public static let referencedImageSequence = Tag(group: 0x0008, element: 0x1140)
    
    // MARK: - Graphic Annotation Module (C.10.5)
    
    /// Graphic Annotation Sequence (0070,0001)
    public static let graphicAnnotationSequence = Tag(group: 0x0070, element: 0x0001)
    
    /// Graphic Layer (0070,0002)
    public static let graphicLayer = Tag(group: 0x0070, element: 0x0002)
    
    /// Text Object Sequence (0070,0008)
    public static let textObjectSequence = Tag(group: 0x0070, element: 0x0008)
    
    /// Graphic Object Sequence (0070,0009)
    public static let graphicObjectSequence = Tag(group: 0x0070, element: 0x0009)
    
    /// Bounding Box Annotation Units (0070,0003)
    public static let boundingBoxAnnotationUnits = Tag(group: 0x0070, element: 0x0003)
    
    /// Anchor Point Annotation Units (0070,0004)
    public static let anchorPointAnnotationUnits = Tag(group: 0x0070, element: 0x0004)
    
    // Note: Unformatted Text Value (0070,0006) is defined in Tag+Waveforms.swift as (0040,A160)
    // For text annotations in GSPS, use that same tag
    
    /// Bounding Box Top Left Hand Corner (0070,0010)
    public static let boundingBoxTopLeftHandCorner = Tag(group: 0x0070, element: 0x0010)
    
    /// Bounding Box Bottom Right Hand Corner (0070,0011)
    public static let boundingBoxBottomRightHandCorner = Tag(group: 0x0070, element: 0x0011)
    
    /// Anchor Point (0070,0014)
    public static let anchorPoint = Tag(group: 0x0070, element: 0x0014)
    
    /// Anchor Point Visibility (0070,0015)
    public static let anchorPointVisibility = Tag(group: 0x0070, element: 0x0015)
    
    /// Graphic Data (0070,0022)
    public static let graphicData = Tag(group: 0x0070, element: 0x0022)
    
    /// Graphic Type (0070,0023)
    public static let graphicType = Tag(group: 0x0070, element: 0x0023)
    
    /// Graphic Filled (0070,0024)
    public static let graphicFilled = Tag(group: 0x0070, element: 0x0024)
    
    // MARK: - Graphic Layer Module (C.10.7)
    
    /// Graphic Layer Sequence (0070,0060)
    public static let graphicLayerSequence = Tag(group: 0x0070, element: 0x0060)
    
    /// Graphic Layer Order (0070,0062)
    public static let graphicLayerOrder = Tag(group: 0x0070, element: 0x0062)
    
    /// Graphic Layer Recommended Display Grayscale Value (0070,0066)
    public static let graphicLayerRecommendedDisplayGrayscaleValue = Tag(group: 0x0070, element: 0x0066)
    
    /// Graphic Layer Recommended Display RGB Value (0070,0067)
    public static let graphicLayerRecommendedDisplayRGBValue = Tag(group: 0x0070, element: 0x0067)
    
    /// Graphic Layer Description (0070,0068)
    public static let graphicLayerDescription = Tag(group: 0x0070, element: 0x0068)
    
    // MARK: - Spatial Transformation Module (C.10.6)
    
    /// Image Rotation (0070,0042)
    public static let imageRotation = Tag(group: 0x0070, element: 0x0042)
    
    /// Image Horizontal Flip (0070,0041)
    public static let imageHorizontalFlip = Tag(group: 0x0070, element: 0x0041)
    
    // MARK: - Display Shutter Module (C.7.6.11)
    
    /// Shutter Shape (0018,1600)
    public static let shutterShape = Tag(group: 0x0018, element: 0x1600)
    
    /// Shutter Left Vertical Edge (0018,1602)
    public static let shutterLeftVerticalEdge = Tag(group: 0x0018, element: 0x1602)
    
    /// Shutter Right Vertical Edge (0018,1604)
    public static let shutterRightVerticalEdge = Tag(group: 0x0018, element: 0x1604)
    
    /// Shutter Upper Horizontal Edge (0018,1606)
    public static let shutterUpperHorizontalEdge = Tag(group: 0x0018, element: 0x1606)
    
    /// Shutter Lower Horizontal Edge (0018,1608)
    public static let shutterLowerHorizontalEdge = Tag(group: 0x0018, element: 0x1608)
    
    /// Center of Circular Shutter (0018,1610)
    public static let centerOfCircularShutter = Tag(group: 0x0018, element: 0x1610)
    
    /// Radius of Circular Shutter (0018,1612)
    public static let radiusOfCircularShutter = Tag(group: 0x0018, element: 0x1612)
    
    /// Vertices of the Polygonal Shutter (0018,1620)
    public static let verticesOfPolygonalShutter = Tag(group: 0x0018, element: 0x1620)
    
    /// Shutter Presentation Value (0018,1622)
    public static let shutterPresentationValue = Tag(group: 0x0018, element: 0x1622)
    
    /// Shutter Overlay Group (0018,1623)
    public static let shutterOverlayGroup = Tag(group: 0x0018, element: 0x1623)
    
    // MARK: - Displayed Area Module (C.10.4)
    
    /// Displayed Area Selection Sequence (0070,005A)
    public static let displayedAreaSelectionSequence = Tag(group: 0x0070, element: 0x005A)
    
    /// Displayed Area Top Left Hand Corner (0070,0052)
    public static let displayedAreaTopLeftHandCorner = Tag(group: 0x0070, element: 0x0052)
    
    /// Displayed Area Bottom Right Hand Corner (0070,0053)
    public static let displayedAreaBottomRightHandCorner = Tag(group: 0x0070, element: 0x0053)
    
    /// Presentation Size Mode (0070,0100)
    public static let presentationSizeMode = Tag(group: 0x0070, element: 0x0100)
    
    /// Presentation Pixel Spacing (0070,0101)
    public static let presentationPixelSpacing = Tag(group: 0x0070, element: 0x0101)
    
    /// Presentation Pixel Aspect Ratio (0070,0102)
    public static let presentationPixelAspectRatio = Tag(group: 0x0070, element: 0x0102)
    
    /// Presentation Pixel Magnification Ratio (0070,0103)
    public static let presentationPixelMagnificationRatio = Tag(group: 0x0070, element: 0x0103)
    
    // MARK: - Modality LUT Module (C.11.1)
    // Note: Modality LUT tags are defined in Tag+PixelData.swift
    // - modalityLUTSequence (0028,3000)
    // - rescaleIntercept (0028,1052)
    // - rescaleSlope (0028,1053)
    // - rescaleType (0028,1054)
    
    // MARK: - VOI LUT Module (C.11.2)
    // Note: VOI LUT tags are defined in Tag+PixelData.swift
    // - voiLUTSequence (0028,3010)
    // - windowCenter (0028,1050)
    // - windowWidth (0028,1051)
    // - windowCenterWidthExplanation (0028,1055)
    // - voiLUTFunction (0028,1056)
    
    // MARK: - Presentation LUT Module (C.11.6)
    // Note: Presentation LUT tags are defined in Tag+PixelData.swift
    // - presentationLUTSequence (2050,0010)
    // - presentationLUTShape (2050,0020)
    
    // MARK: - LUT Common Attributes
    // Note: LUT common tags are defined in Tag+PixelData.swift
    // - lutDescriptor (0028,3002)
    // - lutData (0028,3006)
    // - lutExplanation (0028,3003)
}
