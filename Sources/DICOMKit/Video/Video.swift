//
// Video.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Represents a DICOM Video IOD
///
/// Video objects store multi-frame image sequences captured from endoscopic, microscopic,
/// or photographic equipment. Each video contains encapsulated pixel data compressed
/// using MPEG2, H.264/AVC, or H.265/HEVC video codecs.
///
/// Supported SOP Classes:
/// - Video Endoscopic Image Storage (1.2.840.10008.5.1.4.1.1.77.1.1.1)
/// - Video Microscopic Image Storage (1.2.840.10008.5.1.4.1.1.77.1.2.1)
/// - Video Photographic Image Storage (1.2.840.10008.5.1.4.1.1.77.1.4.1)
///
/// Reference: PS3.3 A.32.5 - Video Endoscopic Image IOD
/// Reference: PS3.3 A.32.6 - Video Microscopic Image IOD
/// Reference: PS3.3 A.32.7 - Video Photographic Image IOD
public struct Video: Sendable {

    // MARK: - SOP Class UIDs

    /// Video Endoscopic Image Storage SOP Class UID
    public static let videoEndoscopicImageStorageUID = "1.2.840.10008.5.1.4.1.1.77.1.1.1"

    /// Video Microscopic Image Storage SOP Class UID
    public static let videoMicroscopicImageStorageUID = "1.2.840.10008.5.1.4.1.1.77.1.2.1"

    /// Video Photographic Image Storage SOP Class UID
    public static let videoPhotographicImageStorageUID = "1.2.840.10008.5.1.4.1.1.77.1.4.1"

    // MARK: - Standard-Mandated Defaults

    /// Photometric Interpretation required of every DICOM video transfer syntax.
    ///
    /// PS3.5 Sections 8.2.7, 8.2.10 and 8.2.11 each state "Photometric Interpretation
    /// (0028,0004) shall be YBR_PARTIAL_420". Note that `YBR_PARTIAL_422` is retired
    /// (PS3.3 C.7.6.3) and `YBR_FULL_422` describes a different subsampling entirely.
    public static let defaultPhotometricInterpretation = "YBR_PARTIAL_420"

    /// Default Image Type (0008,0008) for camera-captured video.
    ///
    /// `ImageType` is Type 1 in the VL Image Module (PS3.3 C.8.12).
    public static let defaultImageType = ["ORIGINAL", "PRIMARY"]

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

    /// Modality (typically "ES" for endoscopy, "GM" for microscopy, "XC" for photography)
    public let modality: String?

    /// Series Description
    public let seriesDescription: String?

    /// Series Number
    public let seriesNumber: Int?

    // MARK: - Image Information

    /// Number of rows (height) in pixels
    public let rows: Int

    /// Number of columns (width) in pixels
    public let columns: Int

    /// Number of frames in the video
    public let numberOfFrames: Int

    /// Samples per pixel (typically 3 for RGB/YBR)
    public let samplesPerPixel: Int

    /// Photometric Interpretation (e.g., "YBR_FULL_422", "YBR_PARTIAL_420", "RGB")
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

    // MARK: - Cine Module

    /// Frame time in milliseconds between frames
    public let frameTime: Double?

    /// Cine Rate (frames/second at acquisition)
    public let cineRate: Int?

    /// Recommended Display Frame Rate (frames/second for display)
    public let recommendedDisplayFrameRate: Int?

    /// Frame Delay in milliseconds
    public let frameDelay: Double?

    /// Actual Frame Duration in milliseconds
    public let actualFrameDuration: Int?

    /// Start Trim frame number
    public let startTrim: Int?

    /// Stop Trim frame number
    public let stopTrim: Int?

    // MARK: - Content Date/Time

    /// Content Date
    public let contentDate: DICOMDate?

    /// Content Time
    public let contentTime: DICOMTime?

    // MARK: - Compression Information

    /// Lossy Image Compression ("00" = no, "01" = yes)
    public let lossyImageCompression: String?

    /// Lossy Image Compression Ratio
    public let lossyImageCompressionRatio: Double?

    /// Lossy Image Compression Method (e.g., "ISO_14496_10" for H.264)
    public let lossyImageCompressionMethod: String?

    // MARK: - VL Image Module (PS3.3 C.8.12)

    /// Image Type (0008,0008) — Type 1 in the VL Image Module.
    ///
    /// Defaults to `ORIGINAL\PRIMARY` for camera-captured video.
    public let imageType: [String]

    // MARK: - General Equipment Module (PS3.3 C.7.5.1)

    /// Manufacturer (0008,0070) — Type 2; emitted zero-length when nil.
    public let manufacturer: String?

    /// Manufacturer's Model Name (0008,1090) — Type 3.
    public let manufacturerModelName: String?

    /// Device Serial Number (0018,1000) — Type 3.
    public let deviceSerialNumber: String?

    /// Software Versions (0018,1020) — Type 3.
    public let softwareVersions: String?

    /// Institution Name (0008,0080) — Type 3.
    public let institutionName: String?

    // MARK: - General Acquisition Module (PS3.3 C.7.10.1)

    /// Acquisition Date (0008,0022) — Type 3.
    public let acquisitionDate: DICOMDate?

    /// Acquisition Time (0008,0032) — Type 3.
    public let acquisitionTime: DICOMTime?

    // MARK: - General Image Module (PS3.3 C.7.6.1)

    /// Patient Orientation (0020,0020) — Type 2C; emitted zero-length when nil.
    public let patientOrientation: String?

    // MARK: - General Study Module (PS3.3 C.7.2.1)

    /// Study Date (0008,0020) — Type 2; emitted zero-length when nil.
    public let studyDate: DICOMDate?

    /// Study Time (0008,0030) — Type 2; emitted zero-length when nil.
    public let studyTime: DICOMTime?

    /// Referring Physician's Name (0008,0090) — Type 2; emitted zero-length when nil.
    public let referringPhysicianName: String?

    /// Study ID (0020,0010) — Type 2; emitted zero-length when nil.
    public let studyID: String?

    /// Accession Number (0008,0050) — Type 2; emitted zero-length when nil.
    public let accessionNumber: String?

    // MARK: - Patient Module (PS3.3 C.7.1.1)

    /// Patient's Birth Date (0010,0030) — Type 2; emitted zero-length when nil.
    public let patientBirthDate: DICOMDate?

    /// Patient's Sex (0010,0040) — Type 2; emitted zero-length when nil.
    public let patientSex: String?

    // MARK: - Pixel Data

    /// The encapsulated video pixel data
    public let pixelData: Data?

    // MARK: - Initialization

    /// Creates a Video instance
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
        rows: Int,
        columns: Int,
        numberOfFrames: Int,
        samplesPerPixel: Int = 3,
        photometricInterpretation: String = Video.defaultPhotometricInterpretation,
        bitsAllocated: Int = 8,
        bitsStored: Int = 8,
        highBit: Int = 7,
        pixelRepresentation: Int = 0,
        planarConfiguration: Int? = nil,
        frameTime: Double? = nil,
        cineRate: Int? = nil,
        recommendedDisplayFrameRate: Int? = nil,
        frameDelay: Double? = nil,
        actualFrameDuration: Int? = nil,
        startTrim: Int? = nil,
        stopTrim: Int? = nil,
        contentDate: DICOMDate? = nil,
        contentTime: DICOMTime? = nil,
        lossyImageCompression: String? = nil,
        lossyImageCompressionRatio: Double? = nil,
        lossyImageCompressionMethod: String? = nil,
        imageType: [String] = Video.defaultImageType,
        manufacturer: String? = nil,
        manufacturerModelName: String? = nil,
        deviceSerialNumber: String? = nil,
        softwareVersions: String? = nil,
        institutionName: String? = nil,
        acquisitionDate: DICOMDate? = nil,
        acquisitionTime: DICOMTime? = nil,
        patientOrientation: String? = nil,
        studyDate: DICOMDate? = nil,
        studyTime: DICOMTime? = nil,
        referringPhysicianName: String? = nil,
        studyID: String? = nil,
        accessionNumber: String? = nil,
        patientBirthDate: DICOMDate? = nil,
        patientSex: String? = nil,
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
        self.frameTime = frameTime
        self.cineRate = cineRate
        self.recommendedDisplayFrameRate = recommendedDisplayFrameRate
        self.frameDelay = frameDelay
        self.actualFrameDuration = actualFrameDuration
        self.startTrim = startTrim
        self.stopTrim = stopTrim
        self.contentDate = contentDate
        self.contentTime = contentTime
        self.lossyImageCompression = lossyImageCompression
        self.lossyImageCompressionRatio = lossyImageCompressionRatio
        self.lossyImageCompressionMethod = lossyImageCompressionMethod
        self.imageType = imageType
        self.manufacturer = manufacturer
        self.manufacturerModelName = manufacturerModelName
        self.deviceSerialNumber = deviceSerialNumber
        self.softwareVersions = softwareVersions
        self.institutionName = institutionName
        self.acquisitionDate = acquisitionDate
        self.acquisitionTime = acquisitionTime
        self.patientOrientation = patientOrientation
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.referringPhysicianName = referringPhysicianName
        self.studyID = studyID
        self.accessionNumber = accessionNumber
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.pixelData = pixelData
    }

    /// The video type inferred from the SOP Class UID
    public var videoType: VideoType {
        return VideoType(sopClassUID: sopClassUID)
    }

    /// The effective frame rate in frames/second
    ///
    /// Returns the recommended display frame rate if available, then cine rate,
    /// then computes from frame time. Defaults to 30 fps.
    public var effectiveFrameRate: Double {
        if let rate = recommendedDisplayFrameRate {
            return Double(rate)
        }
        if let rate = cineRate {
            return Double(rate)
        }
        if let ft = frameTime, ft > 0 {
            return 1000.0 / ft
        }
        return 30.0
    }

    /// The total duration of the video in seconds
    public var duration: Double {
        return Double(numberOfFrames) / effectiveFrameRate
    }

    /// The video resolution as a string (e.g., "1920x1080")
    public var resolution: String {
        return "\(columns)x\(rows)"
    }

    /// Whether this is an endoscopic video
    public var isEndoscopic: Bool {
        return sopClassUID == Self.videoEndoscopicImageStorageUID
    }

    /// Whether this is a microscopic video
    public var isMicroscopic: Bool {
        return sopClassUID == Self.videoMicroscopicImageStorageUID
    }

    /// Whether this is a photographic video
    public var isPhotographic: Bool {
        return sopClassUID == Self.videoPhotographicImageStorageUID
    }
}

// MARK: - Video Type

/// Type of video based on SOP Class UID
public enum VideoType: String, Sendable {
    /// Video from endoscopic procedures
    case endoscopic

    /// Video from microscopic imaging
    case microscopic

    /// Video from photographic equipment
    case photographic

    /// Unknown or unrecognized video type
    case unknown

    /// Creates a video type from a SOP Class UID
    public init(sopClassUID: String) {
        switch sopClassUID {
        case Video.videoEndoscopicImageStorageUID:
            self = .endoscopic
        case Video.videoMicroscopicImageStorageUID:
            self = .microscopic
        case Video.videoPhotographicImageStorageUID:
            self = .photographic
        default:
            self = .unknown
        }
    }

    /// The SOP Class UID for this video type
    public var sopClassUID: String {
        switch self {
        case .endoscopic: return Video.videoEndoscopicImageStorageUID
        case .microscopic: return Video.videoMicroscopicImageStorageUID
        case .photographic: return Video.videoPhotographicImageStorageUID
        case .unknown: return ""
        }
    }

    /// The default modality for this video type
    public var defaultModality: String {
        switch self {
        case .endoscopic: return Modality.es.rawValue
        case .microscopic: return Modality.gm.rawValue
        case .photographic: return Modality.xc.rawValue
        case .unknown: return Modality.ot.rawValue
        }
    }

    /// Human-readable description of the video type
    public var displayName: String {
        switch self {
        case .endoscopic: return "Video Endoscopic"
        case .microscopic: return "Video Microscopic"
        case .photographic: return "Video Photographic"
        case .unknown: return "Unknown Video"
        }
    }
}

// MARK: - Video Codec

/// Video compression codec type
public enum VideoCodec: String, Sendable {
    /// MPEG-2 video compression
    case mpeg2

    /// H.264/AVC video compression
    case h264

    /// H.265/HEVC video compression
    case h265

    /// Unknown or unrecognized codec
    case unknown

    /// Creates a video codec from a transfer syntax UID
    ///
    /// Recognizes all 20 registered video transfer syntaxes, including the
    /// H.264 Level 4.2 UIDs and every fragmentable "….1" variant.
    public init(transferSyntaxUID: String) {
        guard let ts = TransferSyntax.from(uid: transferSyntaxUID) else {
            self = .unknown
            return
        }
        if ts.isMPEG2 {
            self = .mpeg2
        } else if ts.isH264 {
            self = .h264
        } else if ts.isH265 {
            self = .h265
        } else {
            self = .unknown
        }
    }

    /// The DICOM Lossy Image Compression Method identifier
    public var compressionMethod: String {
        switch self {
        case .mpeg2: return "ISO_13818_2"
        case .h264: return "ISO_14496_10"
        case .h265: return "ISO_23008_2"
        case .unknown: return ""
        }
    }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .mpeg2: return "MPEG-2"
        case .h264: return "H.264/AVC"
        case .h265: return "H.265/HEVC"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Bit Depth

/// The DICOM bit-depth triple for a coded video profile.
///
/// DICOM allocates pixel storage on byte boundaries, so a 10-bit stream is
/// `BitsAllocated` 16 rather than 10.
///
/// Reference: PS3.5 Sections 8.2.7, 8.2.10, 8.2.11
public struct VideoBitDepth: Sendable, Hashable {
    /// Bits Allocated (0028,0100)
    public let bitsAllocated: Int
    /// Bits Stored (0028,0101)
    public let bitsStored: Int
    /// High Bit (0028,0102)
    public let highBit: Int

    public init(bitsAllocated: Int, bitsStored: Int, highBit: Int) {
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
    }

    /// 8-bit video: MPEG-2, H.264 High Profile, and HEVC Main.
    public static let eightBit = VideoBitDepth(bitsAllocated: 8, bitsStored: 8, highBit: 7)

    /// 10-bit video: HEVC Main 10. Allocated on a 16-bit boundary per PS3.5 8.2.11.
    public static let tenBit = VideoBitDepth(bitsAllocated: 16, bitsStored: 10, highBit: 9)

    /// The DICOM bit depth for a coded luma bit depth.
    ///
    /// Only 8-bit and 10-bit are representable by the DICOM video transfer syntaxes;
    /// any other depth returns nil so callers reject rather than silently mislabel.
    public static func forLumaBitDepth(_ bitDepth: Int) -> VideoBitDepth? {
        switch bitDepth {
        case 8: return .eightBit
        case 10: return .tenBit
        default: return nil
        }
    }
}
