// DICOMSeries.swift
// DICOMViewer iOS - Series Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Series Model
///
/// Represents a DICOM series containing images from a single acquisition.
/// Reference: DICOM PS3.3 C.7.3 - General Series Module
@Model
final class DICOMSeries: Identifiable {
    // MARK: - Unique Identifier
    
    /// Unique identifier for the series in the app database
    var id: UUID
    
    // MARK: - DICOM UIDs
    
    /// Series Instance UID (0020,000E)
    @Attribute(.unique) var seriesInstanceUID: String
    
    // MARK: - Series Information
    
    /// Series Number (0020,0011)
    var seriesNumber: Int?
    
    /// Series Description (0008,103E)
    var seriesDescription: String?
    
    /// Modality (0008,0060)
    var modality: String
    
    /// Body Part Examined (0018,0015)
    var bodyPartExamined: String?
    
    /// Series Date (0008,0021)
    var seriesDate: Date?
    
    /// Series Time (0008,0031)
    var seriesTime: Date?
    
    // MARK: - Instance Information
    
    /// Number of instances in this series
    var instanceCount: Int
    
    /// Number of frames (for multi-frame series)
    var frameCount: Int
    
    // MARK: - Image Attributes
    
    /// Image rows (height in pixels)
    var imageRows: Int?
    
    /// Image columns (width in pixels)
    var imageColumns: Int?
    
    /// Slice thickness in mm
    var sliceThickness: Double?
    
    /// Pixel spacing in mm (row spacing, column spacing)
    var pixelSpacing: [Double]?
    
    // MARK: - Storage Information
    
    /// Path to the series's storage directory
    var storagePath: String
    
    /// Path to the series's thumbnail image
    var thumbnailPath: String?
    
    /// Total storage size in bytes
    var storageSize: Int64
    
    // MARK: - Relationships
    
    /// Parent study
    var study: DICOMStudy?
    
    /// Instances belonging to this series
    @Relationship(deleteRule: .cascade, inverse: \DICOMInstance.series)
    var instances: [DICOMInstance]?
    
    // MARK: - Initialization
    
    /// Creates a new DICOM Series
    init(
        id: UUID = UUID(),
        seriesInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String? = nil,
        modality: String = "OT",
        bodyPartExamined: String? = nil,
        seriesDate: Date? = nil,
        seriesTime: Date? = nil,
        instanceCount: Int = 0,
        frameCount: Int = 1,
        imageRows: Int? = nil,
        imageColumns: Int? = nil,
        sliceThickness: Double? = nil,
        pixelSpacing: [Double]? = nil,
        storagePath: String,
        thumbnailPath: String? = nil,
        storageSize: Int64 = 0
    ) {
        self.id = id
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.bodyPartExamined = bodyPartExamined
        self.seriesDate = seriesDate
        self.seriesTime = seriesTime
        self.instanceCount = instanceCount
        self.frameCount = frameCount
        self.imageRows = imageRows
        self.imageColumns = imageColumns
        self.sliceThickness = sliceThickness
        self.pixelSpacing = pixelSpacing
        self.storagePath = storagePath
        self.thumbnailPath = thumbnailPath
        self.storageSize = storageSize
    }
}

// MARK: - Display Helpers

extension DICOMSeries {
    /// Formatted series description for display
    var displayDescription: String {
        if let desc = seriesDescription, !desc.isEmpty {
            return desc
        }
        if let number = seriesNumber {
            return "Series \(number)"
        }
        return "Unknown Series"
    }
    
    /// Formatted instance count string
    var instanceCountString: String {
        if frameCount > 1 {
            return "\(frameCount) frames"
        }
        return "\(instanceCount) image\(instanceCount == 1 ? "" : "s")"
    }
    
    /// Formatted image dimensions
    var imageDimensions: String? {
        guard let rows = imageRows, let cols = imageColumns else { return nil }
        return "\(cols) × \(rows)"
    }
}
