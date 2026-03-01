// PresentationStateModel.swift
// DICOMStudio
//
// DICOM Studio — Presentation State models per DICOM PS3.3 C.11

import Foundation

/// Presentation LUT shape per DICOM PS3.3 C.11.6.
public enum PresentationLUTShape: String, Sendable, Equatable, Hashable, CaseIterable {
    case identity = "IDENTITY"
    case inverse = "INVERSE"
}

/// Spatial transformation type per DICOM PS3.3 C.10.6.
public enum SpatialTransformationType: String, Sendable, Equatable, Hashable, CaseIterable {
    case none = "NONE"
    case rotate90 = "ROTATE_90"
    case rotate180 = "ROTATE_180"
    case rotate270 = "ROTATE_270"
    case flipHorizontal = "FLIP_H"
    case flipVertical = "FLIP_V"
    case rotate90FlipH = "ROTATE_90_FLIP_H"
    case rotate270FlipH = "ROTATE_270_FLIP_H"
}

/// Presentation state type classification.
public enum PresentationStateType: String, Sendable, Equatable, Hashable, CaseIterable {
    /// Grayscale Softcopy Presentation State (GSPS).
    case grayscale = "GSPS"
    /// Color Softcopy Presentation State.
    case color = "COLOR"
    /// Pseudo-Color Softcopy Presentation State.
    case pseudoColor = "PSEUDO_COLOR"
    /// Blending Softcopy Presentation State.
    case blending = "BLENDING"
}

/// VOI LUT transformation parameters.
///
/// Corresponds to DICOM PS3.3 C.11.2.1 VOI LUT Module.
public struct VOILUTTransform: Sendable, Equatable, Hashable {
    /// Window center value.
    public let windowCenter: Double

    /// Window width value.
    public let windowWidth: Double

    /// VOI LUT function (LINEAR, LINEAR_EXACT, SIGMOID).
    public let function: String

    /// Creates a new VOI LUT transform.
    public init(windowCenter: Double, windowWidth: Double, function: String = "LINEAR") {
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.function = function
    }
}

/// Modality LUT transformation parameters.
///
/// Corresponds to DICOM PS3.3 C.11.1.1 Modality LUT Module.
public struct ModalityLUTTransform: Sendable, Equatable, Hashable {
    /// Rescale slope.
    public let rescaleSlope: Double

    /// Rescale intercept.
    public let rescaleIntercept: Double

    /// Rescale type.
    public let rescaleType: String

    /// Creates a new modality LUT transform.
    public init(rescaleSlope: Double = 1.0, rescaleIntercept: Double = 0.0, rescaleType: String = "HU") {
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
        self.rescaleType = rescaleType
    }
}

/// Displayed area selection parameters.
///
/// Corresponds to DICOM PS3.3 C.10.4 Displayed Area Module.
public struct DisplayedArea: Sendable, Equatable, Hashable {
    /// Top-left corner of the display area (image coordinates).
    public let topLeft: AnnotationPoint

    /// Bottom-right corner of the display area (image coordinates).
    public let bottomRight: AnnotationPoint

    /// Presentation size mode.
    public let presentationSizeMode: String

    /// Presentation pixel spacing (mm).
    public let pixelSpacing: Double?

    /// Creates a new displayed area.
    public init(
        topLeft: AnnotationPoint,
        bottomRight: AnnotationPoint,
        presentationSizeMode: String = "SCALE TO FIT",
        pixelSpacing: Double? = nil
    ) {
        self.topLeft = topLeft
        self.bottomRight = bottomRight
        self.presentationSizeMode = presentationSizeMode
        self.pixelSpacing = pixelSpacing
    }
}

/// A DICOM SOP Instance reference within a Presentation State.
public struct ReferencedImage: Sendable, Equatable, Hashable {
    /// Referenced SOP Class UID.
    public let sopClassUID: String

    /// Referenced SOP Instance UID.
    public let sopInstanceUID: String

    /// Referenced frame numbers (empty = all frames).
    public let frameNumbers: [Int]

    /// Creates a new referenced image.
    public init(sopClassUID: String, sopInstanceUID: String, frameNumbers: [Int] = []) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.frameNumbers = frameNumbers
    }
}

/// Grayscale Softcopy Presentation State (GSPS).
///
/// Corresponds to DICOM PS3.3 C.11.1 (SOP Class 1.2.840.10008.5.1.4.1.1.11.1).
public struct GSPSModel: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// SOP Instance UID of this presentation state.
    public let sopInstanceUID: String

    /// Referenced images.
    public let referencedImages: [ReferencedImage]

    /// VOI LUT override (window/level).
    public let voiLUT: VOILUTTransform?

    /// Modality LUT override.
    public let modalityLUT: ModalityLUTTransform?

    /// Presentation LUT shape.
    public let presentationLUTShape: PresentationLUTShape

    /// Spatial transformation.
    public let spatialTransformation: SpatialTransformationType

    /// Graphic annotations (shapes).
    public let graphicAnnotations: [GraphicAnnotation]

    /// Text annotations.
    public let textAnnotations: [TextAnnotation]

    /// Graphic layers.
    public let graphicLayers: [GraphicLayer]

    /// Displayed area selection.
    public let displayedArea: DisplayedArea?

    /// Presentation state label.
    public let label: String

    /// Presentation state description.
    public let stateDescription: String?

    /// Creation date.
    public let creationDate: Date?

    /// Creates a new GSPS model.
    public init(
        id: UUID = UUID(),
        sopInstanceUID: String = "",
        referencedImages: [ReferencedImage] = [],
        voiLUT: VOILUTTransform? = nil,
        modalityLUT: ModalityLUTTransform? = nil,
        presentationLUTShape: PresentationLUTShape = .identity,
        spatialTransformation: SpatialTransformationType = .none,
        graphicAnnotations: [GraphicAnnotation] = [],
        textAnnotations: [TextAnnotation] = [],
        graphicLayers: [GraphicLayer] = [],
        displayedArea: DisplayedArea? = nil,
        label: String = "Untitled",
        stateDescription: String? = nil,
        creationDate: Date? = nil
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.referencedImages = referencedImages
        self.voiLUT = voiLUT
        self.modalityLUT = modalityLUT
        self.presentationLUTShape = presentationLUTShape
        self.spatialTransformation = spatialTransformation
        self.graphicAnnotations = graphicAnnotations
        self.textAnnotations = textAnnotations
        self.graphicLayers = graphicLayers
        self.displayedArea = displayedArea
        self.label = label
        self.stateDescription = stateDescription
        self.creationDate = creationDate
    }
}

/// Color Softcopy Presentation State model.
///
/// Corresponds to DICOM PS3.3 C.11.9.
public struct ColorPresentationStateModel: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// SOP Instance UID.
    public let sopInstanceUID: String

    /// Referenced images.
    public let referencedImages: [ReferencedImage]

    /// ICC Profile data (raw bytes).
    public let iccProfile: Data?

    /// Graphic annotations.
    public let graphicAnnotations: [GraphicAnnotation]

    /// Text annotations.
    public let textAnnotations: [TextAnnotation]

    /// Graphic layers.
    public let graphicLayers: [GraphicLayer]

    /// Spatial transformation.
    public let spatialTransformation: SpatialTransformationType

    /// Displayed area selection.
    public let displayedArea: DisplayedArea?

    /// Presentation state label.
    public let label: String

    /// Creates a new Color Presentation State model.
    public init(
        id: UUID = UUID(),
        sopInstanceUID: String = "",
        referencedImages: [ReferencedImage] = [],
        iccProfile: Data? = nil,
        graphicAnnotations: [GraphicAnnotation] = [],
        textAnnotations: [TextAnnotation] = [],
        graphicLayers: [GraphicLayer] = [],
        spatialTransformation: SpatialTransformationType = .none,
        displayedArea: DisplayedArea? = nil,
        label: String = "Untitled"
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.referencedImages = referencedImages
        self.iccProfile = iccProfile
        self.graphicAnnotations = graphicAnnotations
        self.textAnnotations = textAnnotations
        self.graphicLayers = graphicLayers
        self.spatialTransformation = spatialTransformation
        self.displayedArea = displayedArea
        self.label = label
    }
}

/// Pseudo-Color palette type.
public enum PseudoColorPalette: String, Sendable, Equatable, Hashable, CaseIterable {
    case hotIron = "HOT_IRON"
    case rainbow = "RAINBOW"
    case hotMetal = "HOT_METAL"
    case pet = "PET"
    case petTwentyStep = "PET_20_STEP"
    case grayscale = "GRAYSCALE"
    case custom = "CUSTOM"
}

/// Pseudo-Color Softcopy Presentation State model.
///
/// Corresponds to DICOM PS3.3 C.11.10.
public struct PseudoColorPresentationStateModel: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// SOP Instance UID.
    public let sopInstanceUID: String

    /// Referenced images.
    public let referencedImages: [ReferencedImage]

    /// Selected pseudo-color palette.
    public let palette: PseudoColorPalette

    /// Custom color lookup table (256 entries of RGB triplets).
    public let customLUT: [ColorEntry]?

    /// VOI LUT override.
    public let voiLUT: VOILUTTransform?

    /// Graphic annotations.
    public let graphicAnnotations: [GraphicAnnotation]

    /// Text annotations.
    public let textAnnotations: [TextAnnotation]

    /// Presentation state label.
    public let label: String

    /// Creates a new Pseudo-Color Presentation State model.
    public init(
        id: UUID = UUID(),
        sopInstanceUID: String = "",
        referencedImages: [ReferencedImage] = [],
        palette: PseudoColorPalette = .hotIron,
        customLUT: [ColorEntry]? = nil,
        voiLUT: VOILUTTransform? = nil,
        graphicAnnotations: [GraphicAnnotation] = [],
        textAnnotations: [TextAnnotation] = [],
        label: String = "Untitled"
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.referencedImages = referencedImages
        self.palette = palette
        self.customLUT = customLUT
        self.voiLUT = voiLUT
        self.graphicAnnotations = graphicAnnotations
        self.textAnnotations = textAnnotations
        self.label = label
    }
}

/// An RGB color entry for color lookup tables.
public struct ColorEntry: Sendable, Equatable, Hashable {
    /// Red component (0-255).
    public let red: UInt8

    /// Green component (0-255).
    public let green: UInt8

    /// Blue component (0-255).
    public let blue: UInt8

    /// Creates a new color entry.
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Blending Softcopy Presentation State model.
///
/// Corresponds to DICOM PS3.3 C.11.11.
public struct BlendingPresentationStateModel: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier.
    public let id: UUID

    /// SOP Instance UID.
    public let sopInstanceUID: String

    /// Primary (underlay) referenced images.
    public let underlayImages: [ReferencedImage]

    /// Secondary (overlay) referenced images.
    public let overlayImages: [ReferencedImage]

    /// Blending opacity for the overlay (0.0-1.0).
    public let blendingOpacity: Double

    /// Overlay pseudo-color palette.
    public let overlayPalette: PseudoColorPalette?

    /// Underlay VOI LUT.
    public let underlayVOILUT: VOILUTTransform?

    /// Overlay VOI LUT.
    public let overlayVOILUT: VOILUTTransform?

    /// Presentation state label.
    public let label: String

    /// Creates a new Blending Presentation State model.
    public init(
        id: UUID = UUID(),
        sopInstanceUID: String = "",
        underlayImages: [ReferencedImage] = [],
        overlayImages: [ReferencedImage] = [],
        blendingOpacity: Double = 0.5,
        overlayPalette: PseudoColorPalette? = nil,
        underlayVOILUT: VOILUTTransform? = nil,
        overlayVOILUT: VOILUTTransform? = nil,
        label: String = "Untitled"
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.underlayImages = underlayImages
        self.overlayImages = overlayImages
        self.blendingOpacity = max(0.0, min(1.0, blendingOpacity))
        self.overlayPalette = overlayPalette
        self.underlayVOILUT = underlayVOILUT
        self.overlayVOILUT = overlayVOILUT
        self.label = label
    }
}
