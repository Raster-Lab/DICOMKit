//
// SecondaryCaptureImage.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Represents a DICOM Secondary Capture Image IOD
///
/// Secondary Capture images are created by capturing images from non-DICOM
/// sources such as cameras, scanners, screen captures, or digitized film.
/// They support single-frame and multi-frame variants with various bit depths.
///
/// Supported SOP Classes:
/// - Secondary Capture Image Storage (1.2.840.10008.5.1.4.1.1.7)
/// - Multi-frame Single Bit SC Image Storage (1.2.840.10008.5.1.4.1.1.7.1)
/// - Multi-frame Grayscale Byte SC Image Storage (1.2.840.10008.5.1.4.1.1.7.2)
/// - Multi-frame Grayscale Word SC Image Storage (1.2.840.10008.5.1.4.1.1.7.3)
/// - Multi-frame True Color SC Image Storage (1.2.840.10008.5.1.4.1.1.7.4)
///
/// Reference: PS3.3 A.8 - Secondary Capture Image IOD
/// Reference: PS3.3 A.8.1 - Multi-frame SC Image IODs
public struct SecondaryCaptureImage: Sendable {

    // MARK: - SOP Class UIDs

    /// Secondary Capture Image Storage SOP Class UID
    public static let secondaryCaptureImageStorageUID = "1.2.840.10008.5.1.4.1.1.7"

    /// Multi-frame Single Bit Secondary Capture Image Storage SOP Class UID
    public static let multiframeSingleBitSCImageStorageUID = "1.2.840.10008.5.1.4.1.1.7.1"

    /// Multi-frame Grayscale Byte Secondary Capture Image Storage SOP Class UID
    public static let multiframeGrayscaleByteSCImageStorageUID = "1.2.840.10008.5.1.4.1.1.7.2"

    /// Multi-frame Grayscale Word Secondary Capture Image Storage SOP Class UID
    public static let multiframeGrayscaleWordSCImageStorageUID = "1.2.840.10008.5.1.4.1.1.7.3"

    /// Multi-frame True Color Secondary Capture Image Storage SOP Class UID
    public static let multiframeTrueColorSCImageStorageUID = "1.2.840.10008.5.1.4.1.1.7.4"

    // MARK: - Identification

    /// SOP Instance UID
    public let sopInstanceUID: String

    /// SOP Class UID
    public let sopClassUID: String

    /// Study Instance UID
    public let studyInstanceUID: String

    /// Series Instance UID
    public let seriesInstanceUID: String

    /// Instance Number
    public let instanceNumber: Int?

    // MARK: - Patient Information

    /// Patient Name
    public let patientName: String?

    /// Patient ID
    public let patientID: String?

    // MARK: - Series Information

    /// Modality (typically "OT" for Secondary Capture)
    public let modality: String?

    /// Series Description
    public let seriesDescription: String?

    /// Series Number
    public let seriesNumber: Int?

    // MARK: - SC Equipment Module

    /// Conversion Type describing how the image was captured
    public let conversionType: ConversionType

    // MARK: - SC Image Module

    /// Date of Secondary Capture
    public let dateOfSecondaryCapture: DICOMDate?

    /// Time of Secondary Capture
    public let timeOfSecondaryCapture: DICOMTime?

    // MARK: - Image Pixel Module

    /// Number of rows (height) in pixels
    public let rows: Int

    /// Number of columns (width) in pixels
    public let columns: Int

    /// Number of frames (1 for single-frame SC)
    public let numberOfFrames: Int

    /// Samples per pixel (1 for monochrome, 3 for color)
    public let samplesPerPixel: Int

    /// Photometric Interpretation (e.g., "MONOCHROME2", "RGB")
    public let photometricInterpretation: String

    /// Bits allocated per sample
    public let bitsAllocated: Int

    /// Bits stored per sample
    public let bitsStored: Int

    /// High bit position
    public let highBit: Int

    /// Pixel representation (0 = unsigned, 1 = signed)
    public let pixelRepresentation: Int

    /// Planar configuration (0 = interleaved, 1 = separate planes)
    public let planarConfiguration: Int?

    // MARK: - General Image Module

    /// Image Type values (e.g., ["DERIVED", "SECONDARY"])
    public let imageType: [String]?

    /// Derivation Description
    public let derivationDescription: String?

    /// Burned In Annotation ("YES" or "NO")
    public let burnedInAnnotation: String?

    // MARK: - Content Date/Time

    /// Content Date
    public let contentDate: DICOMDate?

    /// Content Time
    public let contentTime: DICOMTime?

    // MARK: - Pixel Data

    /// The pixel data
    public let pixelData: Data?

    // MARK: - Initialization

    /// Creates a SecondaryCaptureImage instance
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        instanceNumber: Int? = nil,
        patientName: String? = nil,
        patientID: String? = nil,
        modality: String? = nil,
        seriesDescription: String? = nil,
        seriesNumber: Int? = nil,
        conversionType: ConversionType = .digitizedFilm,
        dateOfSecondaryCapture: DICOMDate? = nil,
        timeOfSecondaryCapture: DICOMTime? = nil,
        rows: Int,
        columns: Int,
        numberOfFrames: Int = 1,
        samplesPerPixel: Int = 1,
        photometricInterpretation: String = "MONOCHROME2",
        bitsAllocated: Int = 8,
        bitsStored: Int = 8,
        highBit: Int = 7,
        pixelRepresentation: Int = 0,
        planarConfiguration: Int? = nil,
        imageType: [String]? = nil,
        derivationDescription: String? = nil,
        burnedInAnnotation: String? = nil,
        contentDate: DICOMDate? = nil,
        contentTime: DICOMTime? = nil,
        pixelData: Data? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.instanceNumber = instanceNumber
        self.patientName = patientName
        self.patientID = patientID
        self.modality = modality
        self.seriesDescription = seriesDescription
        self.seriesNumber = seriesNumber
        self.conversionType = conversionType
        self.dateOfSecondaryCapture = dateOfSecondaryCapture
        self.timeOfSecondaryCapture = timeOfSecondaryCapture
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = numberOfFrames
        self.samplesPerPixel = samplesPerPixel
        self.photometricInterpretation = photometricInterpretation
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
        self.pixelRepresentation = pixelRepresentation
        self.planarConfiguration = planarConfiguration
        self.imageType = imageType
        self.derivationDescription = derivationDescription
        self.burnedInAnnotation = burnedInAnnotation
        self.contentDate = contentDate
        self.contentTime = contentTime
        self.pixelData = pixelData
    }

    /// The secondary capture type inferred from the SOP Class UID
    public var secondaryCaptureType: SecondaryCaptureType {
        return SecondaryCaptureType(sopClassUID: sopClassUID)
    }

    /// Whether this is a single-frame Secondary Capture image
    public var isSingleFrame: Bool {
        return sopClassUID == Self.secondaryCaptureImageStorageUID
    }

    /// Whether this is a multi-frame Secondary Capture image
    public var isMultiFrame: Bool {
        return !isSingleFrame
    }

    /// The image resolution as a string (e.g., "1920x1080")
    public var resolution: String {
        return "\(columns)x\(rows)"
    }

    /// Whether the image is monochrome
    public var isMonochrome: Bool {
        return photometricInterpretation.hasPrefix("MONOCHROME")
    }

    /// Whether the image is color
    public var isColor: Bool {
        return samplesPerPixel == 3
    }
}

// MARK: - Secondary Capture Type

/// Type of Secondary Capture based on SOP Class UID
public enum SecondaryCaptureType: String, Sendable {
    /// Standard single-frame Secondary Capture
    case singleFrame

    /// Multi-frame single bit (binary) Secondary Capture
    case multiframeSingleBit

    /// Multi-frame grayscale byte (8-bit) Secondary Capture
    case multiframeGrayscaleByte

    /// Multi-frame grayscale word (16-bit) Secondary Capture
    case multiframeGrayscaleWord

    /// Multi-frame true color (RGB) Secondary Capture
    case multiframeTrueColor

    /// Unknown or unrecognized type
    case unknown

    /// Creates a Secondary Capture type from a SOP Class UID
    public init(sopClassUID: String) {
        switch sopClassUID {
        case SecondaryCaptureImage.secondaryCaptureImageStorageUID:
            self = .singleFrame
        case SecondaryCaptureImage.multiframeSingleBitSCImageStorageUID:
            self = .multiframeSingleBit
        case SecondaryCaptureImage.multiframeGrayscaleByteSCImageStorageUID:
            self = .multiframeGrayscaleByte
        case SecondaryCaptureImage.multiframeGrayscaleWordSCImageStorageUID:
            self = .multiframeGrayscaleWord
        case SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID:
            self = .multiframeTrueColor
        default:
            self = .unknown
        }
    }

    /// The SOP Class UID for this Secondary Capture type
    public var sopClassUID: String {
        switch self {
        case .singleFrame: return SecondaryCaptureImage.secondaryCaptureImageStorageUID
        case .multiframeSingleBit: return SecondaryCaptureImage.multiframeSingleBitSCImageStorageUID
        case .multiframeGrayscaleByte: return SecondaryCaptureImage.multiframeGrayscaleByteSCImageStorageUID
        case .multiframeGrayscaleWord: return SecondaryCaptureImage.multiframeGrayscaleWordSCImageStorageUID
        case .multiframeTrueColor: return SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID
        case .unknown: return ""
        }
    }

    /// The default modality for Secondary Capture
    public var defaultModality: String {
        return "OT"
    }

    /// Default pixel characteristics for this type
    public var defaultPixelCharacteristics: (samplesPerPixel: Int, bitsAllocated: Int, bitsStored: Int, highBit: Int, photometricInterpretation: String) {
        switch self {
        case .singleFrame:
            return (1, 8, 8, 7, "MONOCHROME2")
        case .multiframeSingleBit:
            return (1, 1, 1, 0, "MONOCHROME2")
        case .multiframeGrayscaleByte:
            return (1, 8, 8, 7, "MONOCHROME2")
        case .multiframeGrayscaleWord:
            return (1, 16, 16, 15, "MONOCHROME2")
        case .multiframeTrueColor:
            return (3, 8, 8, 7, "RGB")
        case .unknown:
            return (1, 8, 8, 7, "MONOCHROME2")
        }
    }

    /// Human-readable description of the type
    public var displayName: String {
        switch self {
        case .singleFrame: return "Secondary Capture"
        case .multiframeSingleBit: return "Multi-frame Single Bit SC"
        case .multiframeGrayscaleByte: return "Multi-frame Grayscale Byte SC"
        case .multiframeGrayscaleWord: return "Multi-frame Grayscale Word SC"
        case .multiframeTrueColor: return "Multi-frame True Color SC"
        case .unknown: return "Unknown SC"
        }
    }
}

// MARK: - Conversion Type

/// Describes the kind of image conversion that was performed
///
/// Reference: PS3.3 C.8.6.1 - SC Equipment Module
public enum ConversionType: String, Sendable {
    /// Digitized Video - image captured from a video source
    case digitizedVideo = "DV"

    /// Digital Interface - image captured via a digital interface
    case digitalInterface = "DI"

    /// Digitized Film - image captured by scanning a film
    case digitizedFilm = "DF"

    /// Workstation - image captured from a workstation display
    case workstation = "WSD"

    /// Scanned Document - image captured by scanning a document
    case scannedDocument = "SD"

    /// Scanned Image - image captured by scanning an image
    case scannedImage = "SI"

    /// Synthesized Image - image computed from other data
    case synthesized = "SYN"

    /// Unknown conversion type
    case unknown = ""

    /// Creates a ConversionType from its DICOM string value
    public init(dicomValue: String) {
        switch dicomValue.trimmingCharacters(in: .whitespaces) {
        case "DV": self = .digitizedVideo
        case "DI": self = .digitalInterface
        case "DF": self = .digitizedFilm
        case "WSD": self = .workstation
        case "SD": self = .scannedDocument
        case "SI": self = .scannedImage
        case "SYN": self = .synthesized
        default: self = .unknown
        }
    }

    /// Human-readable description
    public var displayName: String {
        switch self {
        case .digitizedVideo: return "Digitized Video"
        case .digitalInterface: return "Digital Interface"
        case .digitizedFilm: return "Digitized Film"
        case .workstation: return "Workstation"
        case .scannedDocument: return "Scanned Document"
        case .scannedImage: return "Scanned Image"
        case .synthesized: return "Synthesized Image"
        case .unknown: return "Unknown"
        }
    }
}
