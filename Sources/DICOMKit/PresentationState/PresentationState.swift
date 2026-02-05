//
// PresentationState.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-04.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Base protocol for DICOM Presentation State objects
///
/// Presentation States define how to display medical images with specific
/// window/level settings, annotations, shutters, and other display parameters.
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
public protocol PresentationState {
    /// SOP Instance UID of the presentation state
    var sopInstanceUID: String { get }
    
    /// SOP Class UID of the presentation state
    var sopClassUID: String { get }
    
    /// Instance number
    var instanceNumber: Int? { get }
    
    /// Presentation label - human-readable name
    var presentationLabel: String? { get }
    
    /// Presentation description
    var presentationDescription: String? { get }
    
    /// Creation date of the presentation state
    var presentationCreationDate: DICOMDate? { get }
    
    /// Creation time of the presentation state
    var presentationCreationTime: DICOMTime? { get }
    
    /// Name of the person who created the presentation state
    var presentationCreatorsName: DICOMPersonName? { get }
    
    /// Referenced series that this presentation state applies to
    var referencedSeries: [ReferencedSeries] { get }
}

/// Referenced series in a presentation state
public struct ReferencedSeries: Sendable, Hashable {
    /// Series Instance UID
    public let seriesInstanceUID: String
    
    /// Referenced images in this series
    public let referencedImages: [ReferencedImage]
    
    /// Initialize a referenced series
    public init(seriesInstanceUID: String, referencedImages: [ReferencedImage]) {
        self.seriesInstanceUID = seriesInstanceUID
        self.referencedImages = referencedImages
    }
}

/// Referenced image in a presentation state
public struct ReferencedImage: Sendable, Hashable {
    /// Referenced SOP Class UID
    public let sopClassUID: String
    
    /// Referenced SOP Instance UID
    public let sopInstanceUID: String
    
    /// Referenced frame numbers (for multi-frame images)
    public let referencedFrameNumbers: [Int]?
    
    /// Initialize a referenced image
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        referencedFrameNumbers: [Int]? = nil
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.referencedFrameNumbers = referencedFrameNumbers
    }
}

/// Grayscale Softcopy Presentation State
///
/// This IOD defines a presentation state for grayscale images with window/level settings,
/// graphic annotations, shutters, and spatial transformations.
///
/// Reference: PS3.3 Part 3 Section A.33 - Grayscale Softcopy Presentation State IOD
public struct GrayscalePresentationState: PresentationState, Sendable {
    // MARK: - Presentation State Identification
    
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let instanceNumber: Int?
    public let presentationLabel: String?
    public let presentationDescription: String?
    public let presentationCreationDate: DICOMDate?
    public let presentationCreationTime: DICOMTime?
    public let presentationCreatorsName: DICOMPersonName?
    
    // MARK: - Presentation State Relationship
    
    public let referencedSeries: [ReferencedSeries]
    
    // MARK: - Display Transformations
    
    /// Modality LUT transformation (rescale slope/intercept or LUT)
    public let modalityLUT: ModalityLUT?
    
    /// VOI LUT transformation (window/level or LUT)
    public let voiLUT: VOILUT?
    
    /// Presentation LUT transformation (IDENTITY or INVERSE)
    public let presentationLUT: PresentationLUT?
    
    // MARK: - Spatial Transformations
    
    /// Spatial transformation (rotation and flip)
    public let spatialTransformation: SpatialTransformation?
    
    /// Displayed area selection (zoom and pan)
    public let displayedArea: DisplayedArea?
    
    // MARK: - Annotations
    
    /// Graphic layers for organizing annotations
    public let graphicLayers: [GraphicLayer]
    
    /// Graphic annotations on the image
    public let graphicAnnotations: [GraphicAnnotation]
    
    // MARK: - Display Shutters
    
    /// Display shutters for masking regions
    public let shutters: [DisplayShutter]
    
    /// Initialize a grayscale presentation state
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.11.1", // Grayscale Softcopy Presentation State
        instanceNumber: Int? = nil,
        presentationLabel: String? = nil,
        presentationDescription: String? = nil,
        presentationCreationDate: DICOMDate? = nil,
        presentationCreationTime: DICOMTime? = nil,
        presentationCreatorsName: DICOMPersonName? = nil,
        referencedSeries: [ReferencedSeries],
        modalityLUT: ModalityLUT? = nil,
        voiLUT: VOILUT? = nil,
        presentationLUT: PresentationLUT? = nil,
        spatialTransformation: SpatialTransformation? = nil,
        displayedArea: DisplayedArea? = nil,
        graphicLayers: [GraphicLayer] = [],
        graphicAnnotations: [GraphicAnnotation] = [],
        shutters: [DisplayShutter] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.presentationLabel = presentationLabel
        self.presentationDescription = presentationDescription
        self.presentationCreationDate = presentationCreationDate
        self.presentationCreationTime = presentationCreationTime
        self.presentationCreatorsName = presentationCreatorsName
        self.referencedSeries = referencedSeries
        self.modalityLUT = modalityLUT
        self.voiLUT = voiLUT
        self.presentationLUT = presentationLUT
        self.spatialTransformation = spatialTransformation
        self.displayedArea = displayedArea
        self.graphicLayers = graphicLayers
        self.graphicAnnotations = graphicAnnotations
        self.shutters = shutters
    }
}

/// Color Softcopy Presentation State
///
/// This IOD defines a presentation state for color images with ICC profile-based
/// color management, spatial transformations, and annotations.
///
/// Reference: PS3.3 Part 3 Section A.34 - Color Softcopy Presentation State IOD
public struct ColorPresentationState: PresentationState, Sendable {
    // MARK: - Presentation State Identification
    
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let instanceNumber: Int?
    public let presentationLabel: String?
    public let presentationDescription: String?
    public let presentationCreationDate: DICOMDate?
    public let presentationCreationTime: DICOMTime?
    public let presentationCreatorsName: DICOMPersonName?
    
    // MARK: - Presentation State Relationship
    
    public let referencedSeries: [ReferencedSeries]
    
    // MARK: - Color Management
    
    /// ICC Profile for device-independent color management
    public let iccProfile: ICCProfile?
    
    // MARK: - Spatial Transformations
    
    /// Spatial transformation (rotation and flip)
    public let spatialTransformation: SpatialTransformation?
    
    /// Displayed area selection (zoom and pan)
    public let displayedArea: DisplayedArea?
    
    // MARK: - Annotations
    
    /// Graphic layers for organizing annotations
    public let graphicLayers: [GraphicLayer]
    
    /// Graphic annotations on the image
    public let graphicAnnotations: [GraphicAnnotation]
    
    // MARK: - Display Shutters
    
    /// Display shutters for masking regions
    public let shutters: [DisplayShutter]
    
    /// Initialize a color presentation state
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.11.2", // Color Softcopy Presentation State
        instanceNumber: Int? = nil,
        presentationLabel: String? = nil,
        presentationDescription: String? = nil,
        presentationCreationDate: DICOMDate? = nil,
        presentationCreationTime: DICOMTime? = nil,
        presentationCreatorsName: DICOMPersonName? = nil,
        referencedSeries: [ReferencedSeries],
        iccProfile: ICCProfile? = nil,
        spatialTransformation: SpatialTransformation? = nil,
        displayedArea: DisplayedArea? = nil,
        graphicLayers: [GraphicLayer] = [],
        graphicAnnotations: [GraphicAnnotation] = [],
        shutters: [DisplayShutter] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.presentationLabel = presentationLabel
        self.presentationDescription = presentationDescription
        self.presentationCreationDate = presentationCreationDate
        self.presentationCreationTime = presentationCreationTime
        self.presentationCreatorsName = presentationCreatorsName
        self.referencedSeries = referencedSeries
        self.iccProfile = iccProfile
        self.spatialTransformation = spatialTransformation
        self.displayedArea = displayedArea
        self.graphicLayers = graphicLayers
        self.graphicAnnotations = graphicAnnotations
        self.shutters = shutters
    }
}

/// Pseudo-Color Softcopy Presentation State
///
/// This IOD defines a presentation state for grayscale images displayed with
/// pseudo-color (false color) mapping using RGB lookup tables.
///
/// Reference: PS3.3 Part 3 Section A.35 - Pseudo-Color Softcopy Presentation State IOD
public struct PseudoColorPresentationState: PresentationState, Sendable {
    // MARK: - Presentation State Identification
    
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let instanceNumber: Int?
    public let presentationLabel: String?
    public let presentationDescription: String?
    public let presentationCreationDate: DICOMDate?
    public let presentationCreationTime: DICOMTime?
    public let presentationCreatorsName: DICOMPersonName?
    
    // MARK: - Presentation State Relationship
    
    public let referencedSeries: [ReferencedSeries]
    
    // MARK: - Display Transformations
    
    /// Modality LUT transformation (rescale slope/intercept or LUT)
    public let modalityLUT: ModalityLUT?
    
    /// VOI LUT transformation (window/level or LUT)
    public let voiLUT: VOILUT?
    
    /// Palette Color LUT for pseudo-color mapping
    public let paletteColorLUT: PaletteColorLUT
    
    // MARK: - Spatial Transformations
    
    /// Spatial transformation (rotation and flip)
    public let spatialTransformation: SpatialTransformation?
    
    /// Displayed area selection (zoom and pan)
    public let displayedArea: DisplayedArea?
    
    // MARK: - Annotations
    
    /// Graphic layers for organizing annotations
    public let graphicLayers: [GraphicLayer]
    
    /// Graphic annotations on the image
    public let graphicAnnotations: [GraphicAnnotation]
    
    // MARK: - Display Shutters
    
    /// Display shutters for masking regions
    public let shutters: [DisplayShutter]
    
    /// Initialize a pseudo-color presentation state
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.11.3", // Pseudo-Color Softcopy Presentation State
        instanceNumber: Int? = nil,
        presentationLabel: String? = nil,
        presentationDescription: String? = nil,
        presentationCreationDate: DICOMDate? = nil,
        presentationCreationTime: DICOMTime? = nil,
        presentationCreatorsName: DICOMPersonName? = nil,
        referencedSeries: [ReferencedSeries],
        modalityLUT: ModalityLUT? = nil,
        voiLUT: VOILUT? = nil,
        paletteColorLUT: PaletteColorLUT,
        spatialTransformation: SpatialTransformation? = nil,
        displayedArea: DisplayedArea? = nil,
        graphicLayers: [GraphicLayer] = [],
        graphicAnnotations: [GraphicAnnotation] = [],
        shutters: [DisplayShutter] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.presentationLabel = presentationLabel
        self.presentationDescription = presentationDescription
        self.presentationCreationDate = presentationCreationDate
        self.presentationCreationTime = presentationCreationTime
        self.presentationCreatorsName = presentationCreatorsName
        self.referencedSeries = referencedSeries
        self.modalityLUT = modalityLUT
        self.voiLUT = voiLUT
        self.paletteColorLUT = paletteColorLUT
        self.spatialTransformation = spatialTransformation
        self.displayedArea = displayedArea
        self.graphicLayers = graphicLayers
        self.graphicAnnotations = graphicAnnotations
        self.shutters = shutters
    }
}

/// Blending Softcopy Presentation State
///
/// This IOD defines a presentation state for blending multiple images together,
/// typically used for multi-modality fusion (e.g., PET/CT, PET/MR).
///
/// Reference: PS3.3 Part 3 Section A.36 - Blending Softcopy Presentation State IOD
public struct BlendingPresentationState: PresentationState, Sendable {
    // MARK: - Presentation State Identification
    
    public let sopInstanceUID: String
    public let sopClassUID: String
    public let instanceNumber: Int?
    public let presentationLabel: String?
    public let presentationDescription: String?
    public let presentationCreationDate: DICOMDate?
    public let presentationCreationTime: DICOMTime?
    public let presentationCreatorsName: DICOMPersonName?
    
    // MARK: - Presentation State Relationship
    
    public let referencedSeries: [ReferencedSeries]
    
    // MARK: - Blending Configuration
    
    /// Blending display sets defining how images are blended
    public let blendingDisplaySets: [BlendingDisplaySet]
    
    // MARK: - Spatial Transformations
    
    /// Spatial transformation (rotation and flip)
    public let spatialTransformation: SpatialTransformation?
    
    /// Displayed area selection (zoom and pan)
    public let displayedArea: DisplayedArea?
    
    // MARK: - Annotations
    
    /// Graphic layers for organizing annotations
    public let graphicLayers: [GraphicLayer]
    
    /// Graphic annotations on the image
    public let graphicAnnotations: [GraphicAnnotation]
    
    // MARK: - Display Shutters
    
    /// Display shutters for masking regions
    public let shutters: [DisplayShutter]
    
    /// Initialize a blending presentation state
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.11.4", // Blending Softcopy Presentation State
        instanceNumber: Int? = nil,
        presentationLabel: String? = nil,
        presentationDescription: String? = nil,
        presentationCreationDate: DICOMDate? = nil,
        presentationCreationTime: DICOMTime? = nil,
        presentationCreatorsName: DICOMPersonName? = nil,
        referencedSeries: [ReferencedSeries],
        blendingDisplaySets: [BlendingDisplaySet],
        spatialTransformation: SpatialTransformation? = nil,
        displayedArea: DisplayedArea? = nil,
        graphicLayers: [GraphicLayer] = [],
        graphicAnnotations: [GraphicAnnotation] = [],
        shutters: [DisplayShutter] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.presentationLabel = presentationLabel
        self.presentationDescription = presentationDescription
        self.presentationCreationDate = presentationCreationDate
        self.presentationCreationTime = presentationCreationTime
        self.presentationCreatorsName = presentationCreatorsName
        self.referencedSeries = referencedSeries
        self.blendingDisplaySets = blendingDisplaySets
        self.spatialTransformation = spatialTransformation
        self.displayedArea = displayedArea
        self.graphicLayers = graphicLayers
        self.graphicAnnotations = graphicAnnotations
        self.shutters = shutters
    }
}

/// SOP Class UIDs for Presentation State IODs
public extension String {
    /// Grayscale Softcopy Presentation State Storage SOP Class UID
    static let grayscaleSoftcopyPresentationStateStorage = "1.2.840.10008.5.1.4.1.1.11.1"
    
    /// Color Softcopy Presentation State Storage SOP Class UID
    static let colorSoftcopyPresentationStateStorage = "1.2.840.10008.5.1.4.1.1.11.2"
    
    /// Pseudo-Color Softcopy Presentation State Storage SOP Class UID
    static let pseudoColorSoftcopyPresentationStateStorage = "1.2.840.10008.5.1.4.1.1.11.3"
    
    /// Blending Softcopy Presentation State Storage SOP Class UID
    static let blendingSoftcopyPresentationStateStorage = "1.2.840.10008.5.1.4.1.1.11.4"
}
