//
//  DicomInstance.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftData

/// Represents a DICOM instance (single image/file) in the local database
@Model
final class DicomInstance {
    /// Unique instance identifier (SOP Instance UID)
    @Attribute(.unique) var sopInstanceUID: String
    
    /// SOP Class UID
    var sopClassUID: String
    
    /// Instance number
    var instanceNumber: Int?
    
    /// File path where the DICOM file is stored
    var filePath: String
    
    /// File size in bytes
    var fileSize: Int64
    
    /// Acquisition date and time
    var acquisitionDate: Date?
    
    /// Image dimensions (rows × columns)
    var rows: Int?
    var columns: Int?
    
    /// Number of frames (for multi-frame instances)
    var numberOfFrames: Int?
    
    /// Transfer syntax UID
    var transferSyntaxUID: String?
    
    /// Whether pixel data is compressed
    var isCompressed: Bool
    
    /// Series this instance belongs to
    var series: DicomSeries?
    
    /// Thumbnail image data (optional, for performance)
    var thumbnailData: Data?
    
    /// Slice location (for CT/MR)
    var sliceLocation: Double?
    
    /// Image position patient (for spatial reconstruction)
    var imagePositionX: Double?
    var imagePositionY: Double?
    var imagePositionZ: Double?
    
    /// Image orientation patient (direction cosines)
    var orientationRow1: Double?
    var orientationRow2: Double?
    var orientationRow3: Double?
    var orientationCol1: Double?
    var orientationCol2: Double?
    var orientationCol3: Double?
    
    init(
        sopInstanceUID: String,
        sopClassUID: String,
        instanceNumber: Int? = nil,
        filePath: String,
        fileSize: Int64 = 0,
        acquisitionDate: Date? = nil,
        rows: Int? = nil,
        columns: Int? = nil,
        numberOfFrames: Int? = nil,
        transferSyntaxUID: String? = nil,
        isCompressed: Bool = false,
        thumbnailData: Data? = nil,
        sliceLocation: Double? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.instanceNumber = instanceNumber
        self.filePath = filePath
        self.fileSize = fileSize
        self.acquisitionDate = acquisitionDate
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = numberOfFrames
        self.transferSyntaxUID = transferSyntaxUID
        self.isCompressed = isCompressed
        self.thumbnailData = thumbnailData
        self.sliceLocation = sliceLocation
    }
    
    /// Display name for the instance
    var displayName: String {
        if let number = instanceNumber {
            return "Image #\(number)"
        }
        return "Image"
    }
    
    /// Formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Image dimensions as string
    var dimensionsString: String? {
        guard let rows = rows, let columns = columns else { return nil }
        return "\(columns)×\(rows)"
    }
    
    /// Whether this is a multi-frame instance
    var isMultiFrame: Bool {
        guard let frames = numberOfFrames else { return false }
        return frames > 1
    }
    
    /// Image position as array (for MPR reconstruction)
    var imagePosition: [Double]? {
        guard let x = imagePositionX,
              let y = imagePositionY,
              let z = imagePositionZ else {
            return nil
        }
        return [x, y, z]
    }
    
    /// Image orientation as 2D array (row and column direction cosines)
    var imageOrientation: [[Double]]? {
        guard let row1 = orientationRow1,
              let row2 = orientationRow2,
              let row3 = orientationRow3,
              let col1 = orientationCol1,
              let col2 = orientationCol2,
              let col3 = orientationCol3 else {
            return nil
        }
        return [
            [row1, row2, row3],
            [col1, col2, col3]
        ]
    }
}

extension DicomInstance: Identifiable {
    var id: String { sopInstanceUID }
}
