//
// ColorManagement.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - ICC Profile

/// ICC Profile for device-independent color management
///
/// ICC profiles define color transformations to ensure consistent color reproduction
/// across different devices (monitors, printers, etc.).
///
/// Reference: PS3.3 Section C.11.15 - ICC Profile Module
public struct ICCProfile: Sendable, Hashable {
    /// ICC profile data (binary blob)
    public let profileData: Data
    
    /// Color space name (e.g., "sRGB", "Adobe RGB", "Display P3")
    public let colorSpace: ColorSpace
    
    /// Profile description/name
    public let description: String?
    
    /// Parsed profile information (lazy parsing)
    private var parsedProfile: ParsedICCProfile?
    
    /// Initialize an ICC profile
    public init(
        profileData: Data,
        colorSpace: ColorSpace,
        description: String? = nil
    ) {
        self.profileData = profileData
        self.colorSpace = colorSpace
        self.description = description
        self.parsedProfile = nil
    }
    
    /// Initialize from parsed ICC profile
    public init(parsed: ParsedICCProfile, profileData: Data) {
        self.profileData = profileData
        self.parsedProfile = parsed
        
        // Infer color space from profile class and description
        if let desc = parsed.description.lowercased() as String? {
            if desc.contains("srgb") {
                self.colorSpace = .sRGB
            } else if desc.contains("adobe rgb") {
                self.colorSpace = .adobeRGB
            } else if desc.contains("display p3") || desc.contains("p3") {
                self.colorSpace = .displayP3
            } else if desc.contains("prophoto") {
                self.colorSpace = .proPhotoRGB
            } else {
                self.colorSpace = .custom
            }
        } else {
            self.colorSpace = .custom
        }
        
        self.description = parsed.description
    }
    
    /// Parse the ICC profile data
    ///
    /// - Returns: Parsed ICC profile information
    /// - Throws: ICCProfileParser.ParseError if parsing fails
    public func parse() throws -> ParsedICCProfile {
        if let parsed = parsedProfile {
            return parsed
        }
        return try ICCProfileParser.parse(profileData)
    }
    
    #if canImport(CoreGraphics)
    /// Create a CGColorSpace from this ICC profile (Apple platforms only)
    public func createCGColorSpace() -> CGColorSpace? {
        return CGColorSpace(iccData: profileData as CFData)
    }
    #endif
    
    /// Extract ICC Profile from DICOM DataSet
    ///
    /// Reads ICC Profile from the ICC Profile Module (0028,2000)
    ///
    /// - Parameter dataSet: DICOM DataSet to extract from
    /// - Returns: ICC Profile if present, nil otherwise
    public static func extract(from dataSet: [Tag: DataElement]) -> ICCProfile? {
        // ICC Profile tag (0028,2000)
        let tag = Tag(group: 0x0028, element: 0x2000)
        guard let element = dataSet[tag] else {
            return nil
        }
        
        let profileData = element.valueData
        
        // Try to parse the profile to get description
        if let parsed = try? ICCProfileParser.parse(profileData) {
            return ICCProfile(parsed: parsed, profileData: profileData)
        }
        
        // Fallback: create with unknown color space
        return ICCProfile(profileData: profileData, colorSpace: .custom)
    }
}

// MARK: - Color Space

/// Supported color spaces for presentation states
public enum ColorSpace: String, Sendable, Hashable, CaseIterable {
    /// sRGB (standard RGB) - most common for displays
    case sRGB
    
    /// Adobe RGB (1998) - wider gamut than sRGB
    case adobeRGB = "Adobe RGB"
    
    /// Display P3 - Apple's wide color gamut space
    case displayP3 = "Display P3"
    
    /// ProPhoto RGB - very wide gamut
    case proPhotoRGB = "ProPhoto RGB"
    
    /// Generic RGB
    case genericRGB = "Generic RGB"
    
    /// Custom color space (requires ICC profile)
    case custom
    
    #if canImport(CoreGraphics)
    /// Create a CGColorSpace for this color space (Apple platforms only)
    public func createCGColorSpace() -> CGColorSpace? {
        switch self {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case .adobeRGB:
            return CGColorSpace(name: CGColorSpace.adobeRGB1998)
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)
        case .proPhotoRGB:
            return CGColorSpace(name: CGColorSpace.rommrgb)
        case .genericRGB:
            return CGColorSpace(name: CGColorSpace.genericRGBLinear)
        case .custom:
            return nil // Requires ICC profile data
        }
    }
    #endif
}

// MARK: - Palette Color LUT Extensions

// Note: PaletteColorLUT is defined in DICOMCore
// This extension adds helper methods for pseudo-color presentation states

extension PaletteColorLUT {
    /// Apply the palette color LUT to a pixel value
    ///
    /// - Parameter value: Input grayscale pixel value
    /// - Returns: RGB color components (each in 0.0-1.0 range)
    public func applyNormalized(to value: Int) -> (red: Double, green: Double, blue: Double) {
        let (r, g, b) = lookup(value)
        return (
            Double(r) / 255.0,
            Double(g) / 255.0,
            Double(b) / 255.0
        )
    }
    
    /// Common preset color maps
    public static func preset(_ type: ColorMapPreset) -> PaletteColorLUT {
        return type.createLUT()
    }
}

// MARK: - Color Map Presets

/// Predefined color map types for pseudo-color display
public enum ColorMapPreset: String, Sendable, CaseIterable {
    /// Grayscale (linear mapping)
    case grayscale
    
    /// Hot (black → red → yellow → white)
    case hot
    
    /// Cool (cyan → blue → magenta)
    case cool
    
    /// Jet (rainbow: blue → cyan → yellow → red)
    case jet
    
    /// Bone (grayscale with blue tint)
    case bone
    
    /// Copper (black → copper → yellow)
    case copper
    
    /// Create a palette color LUT for this preset
    func createLUT() -> PaletteColorLUT {
        let numberOfEntries = 256
        let bitsPerEntry = 16
        let maxValue = UInt16((1 << 16) - 1)
        
        var redData: [UInt16] = []
        var greenData: [UInt16] = []
        var blueData: [UInt16] = []
        
        redData.reserveCapacity(numberOfEntries)
        greenData.reserveCapacity(numberOfEntries)
        blueData.reserveCapacity(numberOfEntries)
        
        for i in 0..<numberOfEntries {
            let t = Double(i) / Double(numberOfEntries - 1)
            let (r, g, b) = colorForValue(t)
            
            // Convert 0.0-1.0 to 16-bit values (stored in high byte per DICOM convention)
            redData.append(UInt16(r * Double(maxValue)))
            greenData.append(UInt16(g * Double(maxValue)))
            blueData.append(UInt16(b * Double(maxValue)))
        }
        
        let descriptor = PaletteColorLUT.Descriptor(
            numberOfEntries: numberOfEntries,
            firstMappedValue: 0,
            bitsPerEntry: bitsPerEntry
        )
        
        return PaletteColorLUT(
            redDescriptor: descriptor,
            greenDescriptor: descriptor,
            blueDescriptor: descriptor,
            redLUT: redData,
            greenLUT: greenData,
            blueLUT: blueData
        )
    }
    
    /// Get RGB color for normalized value (0.0-1.0)
    private func colorForValue(_ t: Double) -> (Double, Double, Double) {
        switch self {
        case .grayscale:
            return (t, t, t)
            
        case .hot:
            // Black → Red → Yellow → White
            if t < 0.33 {
                return (t * 3.0, 0, 0)
            } else if t < 0.67 {
                return (1.0, (t - 0.33) * 3.0, 0)
            } else {
                return (1.0, 1.0, (t - 0.67) * 3.0)
            }
            
        case .cool:
            // Cyan → Blue → Magenta
            return (t, 1.0 - t, 1.0)
            
        case .jet:
            // Blue → Cyan → Yellow → Red
            if t < 0.25 {
                return (0, 0, 0.5 + t * 2.0)
            } else if t < 0.5 {
                return (0, (t - 0.25) * 4.0, 1.0)
            } else if t < 0.75 {
                return ((t - 0.5) * 4.0, 1.0, 1.0 - (t - 0.5) * 4.0)
            } else {
                return (1.0, 1.0 - (t - 0.75) * 4.0, 0)
            }
            
        case .bone:
            // Grayscale with blue tint
            if t < 0.75 {
                return (t * 0.875, t * 0.875, t * 1.125)
            } else {
                return (t * 0.875 + 0.125, t * 0.875 + 0.125, 1.0)
            }
            
        case .copper:
            // Black → Copper → Yellow
            let r = min(1.0, t * 1.25)
            let g = min(1.0, t * 0.78)
            let b = min(1.0, t * 0.5)
            return (r, g, b)
        }
    }
}

// MARK: - Blending Configuration

/// Blending display set configuration
///
/// Defines how multiple images are blended together for multi-modality fusion.
///
/// Reference: PS3.3 Section C.11.13 - Blending Display Module
public struct BlendingDisplaySet: Sendable, Hashable {
    /// Display set number
    public let displaySetNumber: Int
    
    /// Referenced images to blend
    public let referencedImages: [ReferencedImageForBlending]
    
    /// Blending mode
    public let blendingMode: BlendingMode
    
    /// Relative opacity (0.0-1.0) for each image in the blend
    public let relativeOpacities: [Double]
    
    /// Initialize a blending display set
    public init(
        displaySetNumber: Int,
        referencedImages: [ReferencedImageForBlending],
        blendingMode: BlendingMode = .alpha,
        relativeOpacities: [Double]
    ) {
        self.displaySetNumber = displaySetNumber
        self.referencedImages = referencedImages
        self.blendingMode = blendingMode
        self.relativeOpacities = relativeOpacities
    }
}

/// Referenced image with blending-specific information
public struct ReferencedImageForBlending: Sendable, Hashable {
    /// Referenced SOP Instance UID
    public let sopInstanceUID: String
    
    /// Referenced frame number (for multi-frame images)
    public let frameNumber: Int?
    
    /// Presentation state to apply before blending
    public let presentationStateUID: String?
    
    /// Initialize a referenced image for blending
    public init(
        sopInstanceUID: String,
        frameNumber: Int? = nil,
        presentationStateUID: String? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.frameNumber = frameNumber
        self.presentationStateUID = presentationStateUID
    }
}

/// Blending mode for combining images
public enum BlendingMode: String, Sendable, Hashable, CaseIterable {
    /// Alpha blending (weighted average)
    case alpha = "ALPHA"
    
    /// Maximum intensity projection
    case maximumIntensity = "MIP"
    
    /// Minimum intensity projection
    case minimumIntensity = "MinIP"
    
    /// Average intensity
    case average = "AVERAGE"
    
    /// Additive blending
    case additive = "ADD"
    
    /// Subtractive blending
    case subtractive = "SUBTRACT"
}
