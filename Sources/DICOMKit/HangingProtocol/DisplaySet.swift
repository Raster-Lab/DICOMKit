//
// DisplaySet.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Display Set specification for Hanging Protocol
///
/// Defines how images from image sets should be arranged and displayed.
///
/// Reference: PS3.3 Section C.23.6 - Display Set Specification Module
public struct DisplaySet: Sendable {
    /// Display set number (1-based)
    public let number: Int
    
    /// Optional label for the display set
    public let label: String?
    
    /// Presentation group identifier
    public let presentationGroup: Int?
    
    /// Description of presentation group
    public let presentationGroupDescription: String?
    
    /// How to handle partial data (NO_DISPLAY, DISPLAY, etc.)
    public let partialDataHandling: String?
    
    /// Scrolling group identifier for synchronized scrolling
    public let scrollingGroup: Int?
    
    /// Image boxes defining the layout
    public let imageBoxes: [ImageBox]
    
    /// Display options
    public let displayOptions: DisplayOptions
    
    public init(
        number: Int,
        label: String? = nil,
        presentationGroup: Int? = nil,
        presentationGroupDescription: String? = nil,
        partialDataHandling: String? = nil,
        scrollingGroup: Int? = nil,
        imageBoxes: [ImageBox] = [],
        displayOptions: DisplayOptions = DisplayOptions()
    ) {
        self.number = number
        self.label = label
        self.presentationGroup = presentationGroup
        self.presentationGroupDescription = presentationGroupDescription
        self.partialDataHandling = partialDataHandling
        self.scrollingGroup = scrollingGroup
        self.imageBoxes = imageBoxes
        self.displayOptions = displayOptions
    }
}

// MARK: - Image Box

/// Image box within a display set
///
/// Defines a viewport/panel where images will be displayed.
public struct ImageBox: Sendable {
    /// Image box number (1-based)
    public let number: Int
    
    /// Layout type (TILED, STACK, etc.)
    public let layoutType: ImageBoxLayoutType
    
    /// References to image sets to display in this box
    public let imageSetNumbers: [Int]
    
    /// Tile dimensions for TILED layout
    public let tileHorizontalDimension: Int?
    public let tileVerticalDimension: Int?
    
    /// Scroll settings
    public let scrollDirection: ScrollDirection?
    public let smallScrollType: ScrollType?
    public let smallScrollAmount: Int?
    public let largeScrollType: ScrollType?
    public let largeScrollAmount: Int?
    
    /// Overlap priority for multi-box layouts
    public let overlapPriority: Int?
    
    /// Cine playback relative to real-time
    public let cineRelativeToRealTime: Double?
    
    /// Synchronization settings
    public let synchronizationGroup: Int?
    
    /// Reformatting operation for MPR
    public let reformattingOperation: ReformattingOperation?
    
    /// 3D rendering type
    public let threeDRenderingType: ThreeDRenderingType?
    
    public init(
        number: Int,
        layoutType: ImageBoxLayoutType = .stack,
        imageSetNumbers: [Int] = [],
        tileHorizontalDimension: Int? = nil,
        tileVerticalDimension: Int? = nil,
        scrollDirection: ScrollDirection? = nil,
        smallScrollType: ScrollType? = nil,
        smallScrollAmount: Int? = nil,
        largeScrollType: ScrollType? = nil,
        largeScrollAmount: Int? = nil,
        overlapPriority: Int? = nil,
        cineRelativeToRealTime: Double? = nil,
        synchronizationGroup: Int? = nil,
        reformattingOperation: ReformattingOperation? = nil,
        threeDRenderingType: ThreeDRenderingType? = nil
    ) {
        self.number = number
        self.layoutType = layoutType
        self.imageSetNumbers = imageSetNumbers
        self.tileHorizontalDimension = tileHorizontalDimension
        self.tileVerticalDimension = tileVerticalDimension
        self.scrollDirection = scrollDirection
        self.smallScrollType = smallScrollType
        self.smallScrollAmount = smallScrollAmount
        self.largeScrollType = largeScrollType
        self.largeScrollAmount = largeScrollAmount
        self.overlapPriority = overlapPriority
        self.cineRelativeToRealTime = cineRelativeToRealTime
        self.synchronizationGroup = synchronizationGroup
        self.reformattingOperation = reformattingOperation
        self.threeDRenderingType = threeDRenderingType
    }
}

// MARK: - Image Box Layout Type

/// Layout type for image box
public enum ImageBoxLayoutType: String, Sendable, Codable {
    /// Images stacked (one at a time, scrollable)
    case stack = "STACK"
    
    /// Images tiled in a grid
    case tiled = "TILED"
    
    /// Tiled with all images visible
    case tiledAll = "TILED_ALL"
}

// MARK: - Scroll Direction

/// Scroll direction for image navigation
public enum ScrollDirection: String, Sendable, Codable {
    case horizontal = "HORIZONTAL"
    case vertical = "VERTICAL"
}

// MARK: - Scroll Type

/// Type of scroll increment
public enum ScrollType: String, Sendable, Codable {
    /// Scroll by number of images
    case image = "IMAGE"
    
    /// Scroll by fraction of total
    case fraction = "FRACTION"
    
    /// Scroll by page
    case page = "PAGE"
}

// MARK: - Reformatting Operation

/// MPR reformatting operation specification
public struct ReformattingOperation: Sendable {
    /// Type of reformatting
    public let type: ReformattingType
    
    /// Thickness in mm
    public let thickness: Double?
    
    /// Interval between slices in mm
    public let interval: Double?
    
    /// Initial view direction
    public let initialViewDirection: String?
    
    public init(
        type: ReformattingType,
        thickness: Double? = nil,
        interval: Double? = nil,
        initialViewDirection: String? = nil
    ) {
        self.type = type
        self.thickness = thickness
        self.interval = interval
        self.initialViewDirection = initialViewDirection
    }
}

/// Type of reformatting operation
public enum ReformattingType: String, Sendable, Codable {
    /// Multiplanar reformatting
    case mpr = "MPR"
    
    /// Curved planar reformatting
    case cpr = "CPR"
    
    /// Maximum intensity projection
    case mip = "MIP"
    
    /// Minimum intensity projection
    case minIP = "MinIP"
    
    /// Average intensity projection
    case avgIP = "AvgIP"
}

/// 3D rendering type
public enum ThreeDRenderingType: String, Sendable, Codable {
    /// Volume rendering
    case volumeRendering = "VOLUME_RENDERING"
    
    /// Surface rendering
    case surfaceRendering = "SURFACE_RENDERING"
    
    /// Maximum intensity projection (3D)
    case mip = "MIP"
}

// MARK: - Display Options

/// Display options for a display set
public struct DisplayOptions: Sendable {
    /// Patient orientation for display
    public let patientOrientation: String?
    
    /// VOI (window/level) type
    public let voiType: String?
    
    /// Pseudo-color type
    public let pseudoColorType: String?
    
    /// Show grayscale inverted
    public let showGrayscaleInverted: Bool
    
    /// Show image at true size
    public let showImageTrueSize: Bool
    
    /// Show graphic annotations
    public let showGraphicAnnotations: Bool
    
    /// Show patient demographics
    public let showPatientDemographics: Bool
    
    /// Show acquisition techniques
    public let showAcquisitionTechniques: Bool
    
    /// Horizontal justification
    public let horizontalJustification: Justification?
    
    /// Vertical justification
    public let verticalJustification: Justification?
    
    public init(
        patientOrientation: String? = nil,
        voiType: String? = nil,
        pseudoColorType: String? = nil,
        showGrayscaleInverted: Bool = false,
        showImageTrueSize: Bool = false,
        showGraphicAnnotations: Bool = true,
        showPatientDemographics: Bool = true,
        showAcquisitionTechniques: Bool = true,
        horizontalJustification: Justification? = nil,
        verticalJustification: Justification? = nil
    ) {
        self.patientOrientation = patientOrientation
        self.voiType = voiType
        self.pseudoColorType = pseudoColorType
        self.showGrayscaleInverted = showGrayscaleInverted
        self.showImageTrueSize = showImageTrueSize
        self.showGraphicAnnotations = showGraphicAnnotations
        self.showPatientDemographics = showPatientDemographics
        self.showAcquisitionTechniques = showAcquisitionTechniques
        self.horizontalJustification = horizontalJustification
        self.verticalJustification = verticalJustification
    }
}

/// Justification for display layout
public enum Justification: String, Sendable, Codable {
    case left = "LEFT"
    case center = "CENTER"
    case right = "RIGHT"
    case top = "TOP"
    case bottom = "BOTTOM"
}
