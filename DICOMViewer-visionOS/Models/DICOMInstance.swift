// DICOMInstance.swift
// DICOMViewer visionOS - Instance Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Instance Model for visionOS
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
    var transferSyntaxUID: String
    
    // MARK: - Spatial Information (for 3D reconstruction)
    
    /// Image position (patient) - (x, y, z) in mm
    var imagePosition: [Double]?
    
    /// Image orientation (patient) - 6 values
    var imageOrientation: [Double]?
    
    /// Slice location in mm
    var sliceLocation: Double?
    
    /// Pixel spacing in mm (row spacing, column spacing)
    var pixelSpacing: [Double]?
    
    // MARK: - File Information
    
    /// Local file URL
    var fileURL: URL?
    
    /// File size in bytes
    var fileSize: Int64
    
    // MARK: - Relationships
    
    /// Parent series
    var series: DICOMSeries?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        sopInstanceUID: String,
        sopClassUID: String,
        instanceNumber: Int? = nil,
        numberOfFrames: Int = 1,
        contentDate: Date? = nil,
        contentTime: Date? = nil,
        imageRows: Int,
        imageColumns: Int,
        bitsAllocated: Int = 16,
        bitsStored: Int = 12,
        photometricInterpretation: String = "MONOCHROME2",
        transferSyntaxUID: String = "1.2.840.10008.1.2.1",
        imagePosition: [Double]? = nil,
        imageOrientation: [Double]? = nil,
        sliceLocation: Double? = nil,
        pixelSpacing: [Double]? = nil,
        fileURL: URL? = nil,
        fileSize: Int64 = 0,
        series: DICOMSeries? = nil
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
        self.imagePosition = imagePosition
        self.imageOrientation = imageOrientation
        self.sliceLocation = sliceLocation
        self.pixelSpacing = pixelSpacing
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.series = series
    }
}

// MARK: - Computed Properties

extension DICOMInstance {
    /// Image dimensions as string
    var imageDimensions: String {
        "\(imageColumns)×\(imageRows)"
    }
    
    /// Whether this is a multi-frame instance
    var isMultiFrame: Bool {
        numberOfFrames > 1
    }
}
