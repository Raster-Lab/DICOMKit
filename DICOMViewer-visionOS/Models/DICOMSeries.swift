// DICOMSeries.swift
// DICOMViewer visionOS - Series Data Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// DICOM Series Model for visionOS
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
    
    /// Pixel spacing in mm (row spacing, column spacing)
    var pixelSpacing: [Double]?
    
    /// Slice thickness in mm
    var sliceThickness: Double?
    
    /// Slice spacing in mm (for 3D volumes)
    var sliceSpacing: Double?
    
    // MARK: - Volume Information (for 3D reconstruction)
    
    /// Whether this series is suitable for 3D volume rendering
    var isVolumetric: Bool
    
    /// Image orientation (patient) for spatial reconstruction
    var imageOrientation: [Double]?
    
    /// Image position (patient) for first slice
    var imagePosition: [Double]?
    
    // MARK: - Relationships
    
    /// Parent study
    var study: DICOMStudy?
    
    /// Instances in this series
    @Relationship(deleteRule: .cascade, inverse: \DICOMInstance.series)
    var instances: [DICOMInstance]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        seriesInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String? = nil,
        modality: String,
        bodyPartExamined: String? = nil,
        seriesDate: Date? = nil,
        seriesTime: Date? = nil,
        instanceCount: Int = 0,
        frameCount: Int = 0,
        imageRows: Int? = nil,
        imageColumns: Int? = nil,
        pixelSpacing: [Double]? = nil,
        sliceThickness: Double? = nil,
        sliceSpacing: Double? = nil,
        isVolumetric: Bool = false,
        imageOrientation: [Double]? = nil,
        imagePosition: [Double]? = nil,
        study: DICOMStudy? = nil,
        instances: [DICOMInstance] = []
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
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        self.sliceSpacing = sliceSpacing
        self.isVolumetric = isVolumetric
        self.imageOrientation = imageOrientation
        self.imagePosition = imagePosition
        self.study = study
        self.instances = instances
    }
}

// MARK: - Computed Properties

extension DICOMSeries {
    /// Display name for the series
    var displayName: String {
        if let description = seriesDescription, !description.isEmpty {
            return description
        }
        if let number = seriesNumber {
            return "\(modality) Series \(number)"
        }
        return modality
    }
    
    /// Whether this series can be rendered as 3D volume
    var canRender3D: Bool {
        isVolumetric && 
        (modality == "CT" || modality == "MR" || modality == "PT") &&
        instanceCount > 10
    }
}
