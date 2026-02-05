//
// Tag+HangingProtocol.swift
// DICOMCore
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation

/// DICOM tags for Hanging Protocol Information Object Definition
///
/// Reference: PS3.3 Part 3 Section A.38 - Hanging Protocol IOD
/// Reference: PS3.3 Part 3 Section C.23 - Hanging Protocol Module
extension Tag {
    // MARK: - Hanging Protocol Definition Module (C.23.1)
    
    /// Hanging Protocol Name (0072,0002)
    public static let hangingProtocolName = Tag(group: 0x0072, element: 0x0002)
    
    /// Hanging Protocol Description (0072,0004)
    public static let hangingProtocolDescription = Tag(group: 0x0072, element: 0x0004)
    
    /// Hanging Protocol Level (0072,0006)
    public static let hangingProtocolLevel = Tag(group: 0x0072, element: 0x0006)
    
    /// Hanging Protocol Creator (0072,0008)
    public static let hangingProtocolCreator = Tag(group: 0x0072, element: 0x0008)
    
    /// Hanging Protocol Creation DateTime (0072,000A)
    public static let hangingProtocolCreationDateTime = Tag(group: 0x0072, element: 0x000A)
    
    /// Hanging Protocol Definition Sequence (0072,000C)
    public static let hangingProtocolDefinitionSequence = Tag(group: 0x0072, element: 0x000C)
    
    /// Number of Priors Referenced (0072,000E)
    public static let numberOfPriorsReferenced = Tag(group: 0x0072, element: 0x000E)
    
    // MARK: - Hanging Protocol Environment Module (C.23.2)
    
    /// Hanging Protocol Environment Sequence (0072,0010)
    public static let hangingProtocolEnvironmentSequence = Tag(group: 0x0072, element: 0x0010)
    
    /// Modality (0008,0060) - already defined in Tag.swift
    
    /// Laterality (0020,0060) - already defined in Tag.swift
    
    // MARK: - Hanging Protocol User Identification Module (C.23.3)
    
    /// Hanging Protocol User Identification Code Sequence (0072,0014)
    public static let hangingProtocolUserIdentificationCodeSequence = Tag(group: 0x0072, element: 0x0014)
    
    /// Hanging Protocol User Group Name (0072,0016)
    public static let hangingProtocolUserGroupName = Tag(group: 0x0072, element: 0x0016)
    
    // MARK: - Image Set Selector Module (C.23.4)
    
    /// Image Sets Sequence (0072,0020)
    public static let imageSetsSequence = Tag(group: 0x0072, element: 0x0020)
    
    /// Image Set Selector Usage Flag (0072,0022)
    public static let imageSetSelectorUsageFlag = Tag(group: 0x0072, element: 0x0022)
    
    /// Selector Attribute (0072,0024)
    public static let selectorAttribute = Tag(group: 0x0072, element: 0x0024)
    
    /// Selector Value Number (0072,0026)
    public static let selectorValueNumber = Tag(group: 0x0072, element: 0x0026)
    
    /// Time Based Image Sets Sequence (0072,0030)
    public static let timeBasedImageSetsSequence = Tag(group: 0x0072, element: 0x0030)
    
    /// Image Set Number (0072,0032)
    public static let imageSetNumber = Tag(group: 0x0072, element: 0x0032)
    
    /// Image Set Selector Category (0072,0034)
    public static let imageSetSelectorCategory = Tag(group: 0x0072, element: 0x0034)
    
    /// Relative Time (0072,0038)
    public static let relativeTime = Tag(group: 0x0072, element: 0x0038)
    
    /// Relative Time Units (0072,003A)
    public static let relativeTimeUnits = Tag(group: 0x0072, element: 0x003A)
    
    /// Abstract Prior Value (0072,003C)
    public static let abstractPriorValue = Tag(group: 0x0072, element: 0x003C)
    
    /// Abstract Prior Code Sequence (0072,003E)
    public static let abstractPriorCodeSequence = Tag(group: 0x0072, element: 0x003E)
    
    /// Image Set Label (0072,0040)
    public static let imageSetLabel = Tag(group: 0x0072, element: 0x0040)
    
    // MARK: - Display Set Presentation Module (C.23.5)
    
    /// Selector Sequence (0072,0050)
    public static let selectorSequence = Tag(group: 0x0072, element: 0x0050)
    
    /// Selector Code Sequence Value (0072,0052)
    public static let selectorCodeSequenceValue = Tag(group: 0x0072, element: 0x0052)
    
    /// Number of Screens (0072,0100)
    public static let numberOfScreens = Tag(group: 0x0072, element: 0x0100)
    
    /// Nominal Screen Definition Sequence (0072,0102)
    public static let nominalScreenDefinitionSequence = Tag(group: 0x0072, element: 0x0102)
    
    /// Number of Vertical Pixels (0072,0104)
    public static let numberOfVerticalPixels = Tag(group: 0x0072, element: 0x0104)
    
    /// Number of Horizontal Pixels (0072,0106)
    public static let numberOfHorizontalPixels = Tag(group: 0x0072, element: 0x0106)
    
    /// Display Environment Spatial Position (0072,0108)
    public static let displayEnvironmentSpatialPosition = Tag(group: 0x0072, element: 0x0108)
    
    /// Screen Minimum Grayscale Bit Depth (0072,010A)
    public static let screenMinimumGrayscaleBitDepth = Tag(group: 0x0072, element: 0x010A)
    
    /// Screen Minimum Color Bit Depth (0072,010C)
    public static let screenMinimumColorBitDepth = Tag(group: 0x0072, element: 0x010C)
    
    /// Application Maximum Repaint Time (0072,010E)
    public static let applicationMaximumRepaintTime = Tag(group: 0x0072, element: 0x010E)
    
    // MARK: - Display Set Specification Module (C.23.6)
    
    /// Display Sets Sequence (0072,0200)
    public static let displaySetsSequence = Tag(group: 0x0072, element: 0x0200)
    
    /// Display Set Number (0072,0202)
    public static let displaySetNumber = Tag(group: 0x0072, element: 0x0202)
    
    /// Display Set Label (0072,0203)
    public static let displaySetLabel = Tag(group: 0x0072, element: 0x0203)
    
    /// Display Set Presentation Group (0072,0204)
    public static let displaySetPresentationGroup = Tag(group: 0x0072, element: 0x0204)
    
    /// Display Set Presentation Group Description (0072,0206)
    public static let displaySetPresentationGroupDescription = Tag(group: 0x0072, element: 0x0206)
    
    /// Partial Data Display Handling (0072,0208)
    public static let partialDataDisplayHandling = Tag(group: 0x0072, element: 0x0208)
    
    /// Synchronized Scrolling Sequence (0072,0210)
    public static let synchronizedScrollingSequence = Tag(group: 0x0072, element: 0x0210)
    
    /// Display Set Scrolling Group (0072,0212)
    public static let displaySetScrollingGroup = Tag(group: 0x0072, element: 0x0212)
    
    /// Navigation Indicator Sequence (0072,0214)
    public static let navigationIndicatorSequence = Tag(group: 0x0072, element: 0x0214)
    
    /// Navigation Display Set (0072,0216)
    public static let navigationDisplaySet = Tag(group: 0x0072, element: 0x0216)
    
    /// Reference Display Sets (0072,0218)
    public static let referenceDisplaySets = Tag(group: 0x0072, element: 0x0218)
    
    /// Image Boxes Sequence (0072,0300)
    public static let imageBoxesSequence = Tag(group: 0x0072, element: 0x0300)
    
    /// Image Box Number (0072,0302)
    public static let imageBoxNumber = Tag(group: 0x0072, element: 0x0302)
    
    /// Image Box Layout Type (0072,0304)
    public static let imageBoxLayoutType = Tag(group: 0x0072, element: 0x0304)
    
    /// Image Box Tile Horizontal Dimension (0072,0306)
    public static let imageBoxTileHorizontalDimension = Tag(group: 0x0072, element: 0x0306)
    
    /// Image Box Tile Vertical Dimension (0072,0308)
    public static let imageBoxTileVerticalDimension = Tag(group: 0x0072, element: 0x0308)
    
    /// Image Box Scroll Direction (0072,0310)
    public static let imageBoxScrollDirection = Tag(group: 0x0072, element: 0x0310)
    
    /// Image Box Small Scroll Type (0072,0312)
    public static let imageBoxSmallScrollType = Tag(group: 0x0072, element: 0x0312)
    
    /// Image Box Small Scroll Amount (0072,0314)
    public static let imageBoxSmallScrollAmount = Tag(group: 0x0072, element: 0x0314)
    
    /// Image Box Large Scroll Type (0072,0316)
    public static let imageBoxLargeScrollType = Tag(group: 0x0072, element: 0x0316)
    
    /// Image Box Large Scroll Amount (0072,0318)
    public static let imageBoxLargeScrollAmount = Tag(group: 0x0072, element: 0x0318)
    
    /// Image Box Overlap Priority (0072,0320)
    public static let imageBoxOverlapPriority = Tag(group: 0x0072, element: 0x0320)
    
    /// Cine Relative to Real-Time (0072,0330)
    public static let cineRelativeToRealTime = Tag(group: 0x0072, element: 0x0330)
    
    /// Image Box Synchronization Sequence (0072,0340)
    public static let imageBoxSynchronizationSequence = Tag(group: 0x0072, element: 0x0340)
    
    /// Synchronized Image Box List (0072,0342)
    public static let synchronizedImageBoxList = Tag(group: 0x0072, element: 0x0342)
    
    /// Type of Synchronization (0072,0344)
    public static let typeOfSynchronization = Tag(group: 0x0072, element: 0x0344)
    
    /// Blending Operation Type (0072,0500)
    public static let blendingOperationType = Tag(group: 0x0072, element: 0x0500)
    
    /// Reformatting Operation Type (0072,0510)
    public static let reformattingOperationType = Tag(group: 0x0072, element: 0x0510)
    
    /// Reformatting Thickness (0072,0512)
    public static let reformattingThickness = Tag(group: 0x0072, element: 0x0512)
    
    /// Reformatting Interval (0072,0514)
    public static let reformattingInterval = Tag(group: 0x0072, element: 0x0514)
    
    /// Reformatting Operation Initial View Direction (0072,0516)
    public static let reformattingOperationInitialViewDirection = Tag(group: 0x0072, element: 0x0516)
    
    /// 3D Rendering Type (0072,0520)
    public static let threeDRenderingType = Tag(group: 0x0072, element: 0x0520)
    
    /// Sorting Operations Sequence (0072,0600)
    public static let sortingOperationsSequence = Tag(group: 0x0072, element: 0x0600)
    
    /// Sort-by Category (0072,0602)
    public static let sortByCategory = Tag(group: 0x0072, element: 0x0602)
    
    /// Sorting Direction (0072,0604)
    public static let sortingDirection = Tag(group: 0x0072, element: 0x0604)
    
    /// Display Set Patient Orientation (0072,0700)
    public static let displaySetPatientOrientation = Tag(group: 0x0072, element: 0x0700)
    
    /// VOI Type (0072,0702)
    public static let voiType = Tag(group: 0x0072, element: 0x0702)
    
    /// Pseudo-Color Type (0072,0704)
    public static let pseudoColorType = Tag(group: 0x0072, element: 0x0704)
    
    /// Pseudo-Color Palette Instance Reference Sequence (0072,0705)
    public static let pseudoColorPaletteInstanceReferenceSequence = Tag(group: 0x0072, element: 0x0705)
    
    /// Show Grayscale Inverted (0072,0706)
    public static let showGrayscaleInverted = Tag(group: 0x0072, element: 0x0706)
    
    /// Show Image True Size Flag (0072,0710)
    public static let showImageTrueSizeFlag = Tag(group: 0x0072, element: 0x0710)
    
    /// Show Graphic Annotation Flag (0072,0712)
    public static let showGraphicAnnotationFlag = Tag(group: 0x0072, element: 0x0712)
    
    /// Show Patient Demographics Flag (0072,0714)
    public static let showPatientDemographicsFlag = Tag(group: 0x0072, element: 0x0714)
    
    /// Show Acquisition Techniques Flag (0072,0716)
    public static let showAcquisitionTechniquesFlag = Tag(group: 0x0072, element: 0x0716)
    
    /// Display Set Horizontal Justification (0072,0717)
    public static let displaySetHorizontalJustification = Tag(group: 0x0072, element: 0x0717)
    
    /// Display Set Vertical Justification (0072,0718)
    public static let displaySetVerticalJustification = Tag(group: 0x0072, element: 0x0718)
    
    // MARK: - Filter Operations Module (C.23.7)
    
    /// Filter Operations Sequence (0072,0400)
    public static let filterOperationsSequence = Tag(group: 0x0072, element: 0x0400)
    
    /// Filter-by Category (0072,0402)
    public static let filterByCategory = Tag(group: 0x0072, element: 0x0402)
    
    /// Filter-by Attribute Presence (0072,0404)
    public static let filterByAttributePresence = Tag(group: 0x0072, element: 0x0404)
    
    /// Filter-by Operator (0072,0406)
    public static let filterByOperator = Tag(group: 0x0072, element: 0x0406)
    
    /// Structured Display Background CIELab Value (0072,0420)
    public static let structuredDisplayBackgroundCIELabValue = Tag(group: 0x0072, element: 0x0420)
    
    /// Empty Image Box CIELab Value (0072,0421)
    public static let emptyImageBoxCIELabValue = Tag(group: 0x0072, element: 0x0421)
    
    /// Structured Display Image Box Sequence (0072,0422)
    public static let structuredDisplayImageBoxSequence = Tag(group: 0x0072, element: 0x0422)
    
    /// Structured Display Text Box Sequence (0072,0424)
    public static let structuredDisplayTextBoxSequence = Tag(group: 0x0072, element: 0x0424)
    
    /// Referenced First Frame Sequence (0072,0427)
    public static let referencedFirstFrameSequence = Tag(group: 0x0072, element: 0x0427)
    
    /// Image Box Synchronization Sequence Pointer (0072,0430)
    public static let imageBoxSynchronizationSequencePointer = Tag(group: 0x0072, element: 0x0430)
    
    /// Text Box Sequence Pointer (0072,0432)
    public static let textBoxSequencePointer = Tag(group: 0x0072, element: 0x0432)
    
    /// Image Box Synchronization Sequence Item Number (0072,0434)
    public static let imageBoxSynchronizationSequenceItemNumber = Tag(group: 0x0072, element: 0x0434)
    
    /// Text Box Sequence Item Number (0072,0436)
    public static let textBoxSequenceItemNumber = Tag(group: 0x0072, element: 0x0436)
}
