// DICOMInstance.swift
// DICOMViewer iOS - Instance Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Instance Model
///
/// Represents a single DICOM SOP Instance (image or other object).
/// Reference: DICOM PS3.3 C.12 - SOP Common Module
@Model
final class DICOMInstance: Identifiable {
    // MARK: - Unique Identifier
    
    /// Unique identifier for the instance in the app database
    var id: UUID
    
    // MARK: - DICOM UIDs
    
    /// SOP Instance UID (0008,0018)
    @Attribute(.unique) var sopInstanceUID: String
    
    /// SOP Class UID (0008,0016)
    var sopClassUID: String
    
    // MARK: - Instance Information
    
    /// Instance Number (0020,0013)
    var instanceNumber: Int?
    
    /// Number of frames in this instance
    var numberOfFrames: Int
    
    /// Content Date (0008,0023)
    var contentDate: Date?
    
    /// Content Time (0008,0033)
    var contentTime: Date?
    
    // MARK: - Image Attributes
    
    /// Image rows (height in pixels)
    var imageRows: Int
    
    /// Image columns (width in pixels)
    var imageColumns: Int
    
    /// Bits allocated per pixel
    var bitsAllocated: Int
    
    /// Bits stored per pixel
    var bitsStored: Int
    
    /// Photometric interpretation (e.g., MONOCHROME2, RGB)
    var photometricInterpretation: String
    
    /// Transfer syntax UID
    var transferSyntaxUID: String?
    
    // MARK: - Window/Level Defaults
    
    /// Default window center
    var windowCenter: Double?
    
    /// Default window width
    var windowWidth: Double?
    
    // MARK: - Spatial Information
    
    /// Pixel spacing in mm [row spacing, column spacing]
    var pixelSpacing: [Double]?
    
    /// Slice location
    var sliceLocation: Double?
    
    /// Image position patient [x, y, z]
    var imagePositionPatient: [Double]?
    
    /// Image orientation patient [row cosines..., column cosines...]
    var imageOrientationPatient: [Double]?
    
    // MARK: - Storage Information
    
    /// Full path to the DICOM file
    var filePath: String
    
    /// File size in bytes
    var fileSize: Int64
    
    // MARK: - Relationships
    
    /// Parent series
    var series: DICOMSeries?
    
    // MARK: - Initialization
    
    /// Creates a new DICOM Instance
    init(
        id: UUID = UUID(),
        sopInstanceUID: String,
        sopClassUID: String,
        instanceNumber: Int? = nil,
        numberOfFrames: Int = 1,
        contentDate: Date? = nil,
        contentTime: Date? = nil,
        imageRows: Int = 0,
        imageColumns: Int = 0,
        bitsAllocated: Int = 16,
        bitsStored: Int = 12,
        photometricInterpretation: String = "MONOCHROME2",
        transferSyntaxUID: String? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        pixelSpacing: [Double]? = nil,
        sliceLocation: Double? = nil,
        imagePositionPatient: [Double]? = nil,
        imageOrientationPatient: [Double]? = nil,
        filePath: String,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.numberOfFrames = numberOfFrames
        self.contentDate = contentDate
        self.contentTime = contentTime
        self.imageRows = imageRows
        self.imageColumns = imageColumns
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.photometricInterpretation = photometricInterpretation
        self.transferSyntaxUID = transferSyntaxUID
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.pixelSpacing = pixelSpacing
        self.sliceLocation = sliceLocation
        self.imagePositionPatient = imagePositionPatient
        self.imageOrientationPatient = imageOrientationPatient
        self.filePath = filePath
        self.fileSize = fileSize
    }
}

// MARK: - Display Helpers

extension DICOMInstance {
    /// Formatted image dimensions
    var imageDimensions: String {
        "\(imageColumns) × \(imageRows)"
    }
    
    /// Formatted file size
    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Check if this is a multi-frame instance
    var isMultiFrame: Bool {
        numberOfFrames > 1
    }
    
    /// Formatted frame count string
    var frameCountString: String {
        isMultiFrame ? "\(numberOfFrames) frames" : "Single frame"
    }
}
