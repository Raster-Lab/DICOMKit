//
// HangingProtocol.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Hanging Protocol Information Object Definition (IOD)
///
/// Hanging Protocols define how studies should be displayed on viewing workstations,
/// including layout, image selection, and display parameters.
///
/// Reference: PS3.3 Section A.38 - Hanging Protocol IOD
/// Reference: PS3.3 Section C.23 - Hanging Protocol Modules
public struct HangingProtocol: Sendable {
    // MARK: - Identification
    
    /// Unique name for the hanging protocol
    public let name: String
    
    /// Human-readable description of the protocol
    public let description: String?
    
    /// Protocol level (SITE, GROUP, USER)
    public let level: HangingProtocolLevel
    
    /// Creator of the protocol
    public let creator: String?
    
    /// Creation date and time
    public let creationDateTime: DICOMDateTime?
    
    /// Number of prior studies referenced
    public let numberOfPriorsReferenced: Int?
    
    // MARK: - Environment
    
    /// Environments (modality, laterality combinations) where this protocol applies
    public let environments: [HangingProtocolEnvironment]
    
    // MARK: - User Identification
    
    /// User groups or individuals this protocol applies to
    public let userGroups: [String]
    
    // MARK: - Image Sets
    
    /// Image sets defined by this protocol
    public let imageSets: [ImageSetDefinition]
    
    // MARK: - Display Specification
    
    /// Number of screens used
    public let numberOfScreens: Int
    
    /// Screen definitions for nominal display configuration
    public let screenDefinitions: [ScreenDefinition]
    
    /// Display sets specifying how images should be arranged
    public let displaySets: [DisplaySet]
    
    // MARK: - Initialization
    
    public init(
        name: String,
        description: String? = nil,
        level: HangingProtocolLevel = .user,
        creator: String? = nil,
        creationDateTime: DICOMDateTime? = nil,
        numberOfPriorsReferenced: Int? = nil,
        environments: [HangingProtocolEnvironment] = [],
        userGroups: [String] = [],
        imageSets: [ImageSetDefinition] = [],
        numberOfScreens: Int = 1,
        screenDefinitions: [ScreenDefinition] = [],
        displaySets: [DisplaySet] = []
    ) {
        self.name = name
        self.description = description
        self.level = level
        self.creator = creator
        self.creationDateTime = creationDateTime
        self.numberOfPriorsReferenced = numberOfPriorsReferenced
        self.environments = environments
        self.userGroups = userGroups
        self.imageSets = imageSets
        self.numberOfScreens = numberOfScreens
        self.screenDefinitions = screenDefinitions
        self.displaySets = displaySets
    }
}

// MARK: - Hanging Protocol Level

/// Level at which a hanging protocol is defined
public enum HangingProtocolLevel: String, Sendable, Codable {
    /// Site-level protocol (applies to entire institution)
    case site = "SITE"
    
    /// Group-level protocol (applies to department or group)
    case group = "GROUP"
    
    /// User-level protocol (applies to individual user)
    case user = "USER"
}

// MARK: - Hanging Protocol Environment

/// Environment specification for protocol matching
///
/// Defines the clinical context where a hanging protocol should be applied,
/// such as modality and anatomic laterality.
public struct HangingProtocolEnvironment: Sendable {
    /// Modality (e.g., "CT", "MR", "CR", "DX")
    public let modality: String?
    
    /// Anatomic laterality (e.g., "L", "R")
    public let laterality: String?
    
    public init(modality: String? = nil, laterality: String? = nil) {
        self.modality = modality
        self.laterality = laterality
    }
}

// MARK: - Screen Definition

/// Nominal screen definition for multi-monitor configurations
public struct ScreenDefinition: Sendable {
    /// Number of vertical pixels
    public let verticalPixels: Int
    
    /// Number of horizontal pixels
    public let horizontalPixels: Int
    
    /// Spatial position in multi-monitor setup (1-based)
    public let spatialPosition: [Double]?
    
    /// Minimum grayscale bit depth
    public let minimumGrayscaleBitDepth: Int?
    
    /// Minimum color bit depth
    public let minimumColorBitDepth: Int?
    
    /// Maximum application repaint time in milliseconds
    public let maximumRepaintTime: Int?
    
    public init(
        verticalPixels: Int,
        horizontalPixels: Int,
        spatialPosition: [Double]? = nil,
        minimumGrayscaleBitDepth: Int? = nil,
        minimumColorBitDepth: Int? = nil,
        maximumRepaintTime: Int? = nil
    ) {
        self.verticalPixels = verticalPixels
        self.horizontalPixels = horizontalPixels
        self.spatialPosition = spatialPosition
        self.minimumGrayscaleBitDepth = minimumGrayscaleBitDepth
        self.minimumColorBitDepth = minimumColorBitDepth
        self.maximumRepaintTime = maximumRepaintTime
    }
}
