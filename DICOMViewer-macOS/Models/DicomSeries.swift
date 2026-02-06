//
//  DicomSeries.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftData

/// Represents a DICOM series in the local database
@Model
final class DicomSeries {
    /// Unique series identifier (Series Instance UID)
    @Attribute(.unique) var seriesInstanceUID: String
    
    /// Series number
    var seriesNumber: Int?
    
    /// Series description
    var seriesDescription: String?
    
    /// Modality (e.g., "CT", "MR", "US")
    var modality: String
    
    /// Number of instances in series
    var numberOfInstances: Int
    
    /// Series date and time
    var seriesDate: Date?
    
    /// Body part examined
    var bodyPartExamined: String?
    
    /// Protocol name
    var protocolName: String?
    
    /// Study this series belongs to
    var study: DicomStudy?
    
    /// Instances belonging to this series
    @Relationship(deleteRule: .cascade, inverse: \DicomInstance.series)
    var instances: [DicomInstance]
    
    /// Whether this is a multi-frame series
    var isMultiFrame: Bool
    
    /// Frame rate for cine playback (fps)
    var frameRate: Double?
    
    init(
        seriesInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String? = nil,
        modality: String,
        numberOfInstances: Int = 0,
        seriesDate: Date? = nil,
        bodyPartExamined: String? = nil,
        protocolName: String? = nil,
        isMultiFrame: Bool = false,
        frameRate: Double? = nil
    ) {
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.numberOfInstances = numberOfInstances
        self.seriesDate = seriesDate
        self.bodyPartExamined = bodyPartExamined
        self.protocolName = protocolName
        self.instances = []
        self.isMultiFrame = isMultiFrame
        self.frameRate = frameRate
    }
    
    /// Display name for the series
    var displayName: String {
        var parts: [String] = []
        
        if let number = seriesNumber {
            parts.append("#\(number)")
        }
        
        parts.append(modality)
        
        if let description = seriesDescription, !description.isEmpty {
            parts.append(description)
        }
        
        return parts.joined(separator: " - ")
    }
    
    /// Formatted series date
    var formattedDate: String {
        guard let date = seriesDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension DicomSeries: Identifiable {
    var id: String { seriesInstanceUID }
}
