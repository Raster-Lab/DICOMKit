//
// RTDose.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// DICOM RT Dose IOD
///
/// An RT Dose object contains a 3D dose grid representing the calculated or measured
/// radiation dose distribution in a patient. Dose values are stored as 16-bit or 32-bit
/// unsigned integers and must be scaled by the Dose Grid Scaling factor.
///
/// Reference: PS3.3 A.18 - RT Dose IOD
/// Reference: PS3.3 C.8.8.3 - RT Dose Module
public struct RTDose: Sendable {
    
    // MARK: - Dose Identification
    
    /// SOP Instance UID
    public let sopInstanceUID: String
    
    /// SOP Class UID (should be RT Dose Storage: 1.2.840.10008.5.1.4.1.1.481.2)
    public let sopClassUID: String
    
    /// Dose Comment
    public let comment: String?
    
    /// Dose Summation Type (PLAN, MULTI_PLAN, FRACTION, BEAM, BRACHY, etc.)
    public let summationType: String?
    
    /// Dose Type (PHYSICAL, EFFECTIVE, BIOLOGICAL)
    public let type: String?
    
    /// Dose Units (GY, RELATIVE)
    public let units: String?
    
    // MARK: - Referenced Objects
    
    /// Referenced RT Plan SOP Instance UID
    public let referencedRTPlanUID: String?
    
    /// Referenced Structure Set SOP Instance UID
    public let referencedStructureSetUID: String?
    
    /// Referenced Fraction Group Number
    public let referencedFractionGroupNumber: Int?
    
    /// Referenced Beam Number
    public let referencedBeamNumber: Int?
    
    // MARK: - Dose Grid Geometry
    
    /// Frame of Reference UID
    public let frameOfReferenceUID: String?
    
    /// Image Position (Patient) - origin of dose grid (x, y, z in mm)
    public let imagePosition: Point3D?
    
    /// Image Orientation (Patient) - direction cosines
    public let imageOrientation: [Double]?
    
    /// Grid Frame Offset Vector (mm) - z-positions of slices
    public let gridFrameOffsetVector: [Double]?
    
    /// Pixel Spacing (mm) - [row spacing, column spacing]
    public let pixelSpacing: (row: Double, column: Double)?
    
    /// Slice Thickness (mm)
    public let sliceThickness: Double?
    
    // MARK: - Dose Grid Dimensions
    
    /// Number of Rows in dose grid
    public let rows: Int
    
    /// Number of Columns in dose grid
    public let columns: Int
    
    /// Number of Frames (slices)
    public let numberOfFrames: Int
    
    /// Bits Allocated (16 or 32)
    public let bitsAllocated: Int
    
    /// Bits Stored
    public let bitsStored: Int
    
    /// High Bit
    public let highBit: Int
    
    // MARK: - Dose Scaling
    
    /// Dose Grid Scaling
    /// Multiply raw pixel values by this factor to get dose in units specified by Dose Units
    public let doseGridScaling: Double
    
    /// Tissue Heterogeneity Correction (YES, NO)
    public let tissueHeterogeneityCorrection: String?
    
    // MARK: - Dose Statistics
    
    /// Maximum Dose (in dose units, after scaling)
    public let maximumDose: Double?
    
    /// Minimum Dose (in dose units, after scaling)
    public let minimumDose: Double?
    
    /// Mean Dose (in dose units, after scaling)
    public let meanDose: Double?
    
    // MARK: - DVH Data
    
    /// DVH (Dose Volume Histogram) data
    public let dvhData: [DVHData]
    
    // MARK: - Dose Grid Data
    
    /// Raw dose grid pixel data (before scaling)
    /// 3D array: [frame][row][column]
    /// Values must be multiplied by doseGridScaling to get actual dose
    public let pixelData: [[[UInt16]]]?
    
    /// Raw dose grid pixel data (32-bit, before scaling)
    /// 3D array: [frame][row][column]
    /// Values must be multiplied by doseGridScaling to get actual dose
    public let pixelData32: [[[UInt32]]]?
    
    // MARK: - Initialization
    
    /// Initialize an RT Dose
    public init(
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.481.2",
        comment: String? = nil,
        summationType: String? = nil,
        type: String? = nil,
        units: String? = nil,
        referencedRTPlanUID: String? = nil,
        referencedStructureSetUID: String? = nil,
        referencedFractionGroupNumber: Int? = nil,
        referencedBeamNumber: Int? = nil,
        frameOfReferenceUID: String? = nil,
        imagePosition: Point3D? = nil,
        imageOrientation: [Double]? = nil,
        gridFrameOffsetVector: [Double]? = nil,
        pixelSpacing: (row: Double, column: Double)? = nil,
        sliceThickness: Double? = nil,
        rows: Int,
        columns: Int,
        numberOfFrames: Int,
        bitsAllocated: Int = 16,
        bitsStored: Int = 16,
        highBit: Int = 15,
        doseGridScaling: Double,
        tissueHeterogeneityCorrection: String? = nil,
        maximumDose: Double? = nil,
        minimumDose: Double? = nil,
        meanDose: Double? = nil,
        dvhData: [DVHData] = [],
        pixelData: [[[UInt16]]]? = nil,
        pixelData32: [[[UInt32]]]? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.comment = comment
        self.summationType = summationType
        self.type = type
        self.units = units
        self.referencedRTPlanUID = referencedRTPlanUID
        self.referencedStructureSetUID = referencedStructureSetUID
        self.referencedFractionGroupNumber = referencedFractionGroupNumber
        self.referencedBeamNumber = referencedBeamNumber
        self.frameOfReferenceUID = frameOfReferenceUID
        self.imagePosition = imagePosition
        self.imageOrientation = imageOrientation
        self.gridFrameOffsetVector = gridFrameOffsetVector
        self.pixelSpacing = pixelSpacing
        self.sliceThickness = sliceThickness
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = numberOfFrames
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
        self.doseGridScaling = doseGridScaling
        self.tissueHeterogeneityCorrection = tissueHeterogeneityCorrection
        self.maximumDose = maximumDose
        self.minimumDose = minimumDose
        self.meanDose = meanDose
        self.dvhData = dvhData
        self.pixelData = pixelData
        self.pixelData32 = pixelData32
    }
    
    // MARK: - Dose Value Access
    
    /// Get the scaled dose value at a specific grid position
    /// - Parameters:
    ///   - frame: Frame (slice) index
    ///   - row: Row index
    ///   - column: Column index
    /// - Returns: Dose value in units specified by Dose Units, or nil if position is invalid
    public func doseValue(frame: Int, row: Int, column: Int) -> Double? {
        guard frame >= 0 && frame < numberOfFrames,
              row >= 0 && row < rows,
              column >= 0 && column < columns else {
            return nil
        }
        
        if let pixelData = pixelData {
            return Double(pixelData[frame][row][column]) * doseGridScaling
        } else if let pixelData32 = pixelData32 {
            return Double(pixelData32[frame][row][column]) * doseGridScaling
        }
        
        return nil
    }
    
    /// Get the dose value at a physical position in patient coordinate system
    /// - Parameter position: 3D position in patient coordinates (mm)
    /// - Returns: Interpolated dose value, or nil if position is outside grid
    public func doseValue(at position: Point3D) -> Double? {
        guard let imagePosition = imagePosition,
              let pixelSpacing = pixelSpacing,
              let gridFrameOffsetVector = gridFrameOffsetVector else {
            return nil
        }
        
        // Convert physical position to grid indices
        // This is a simplified version - proper implementation would use image orientation
        let colIndex = (position.x - imagePosition.x) / pixelSpacing.column
        let rowIndex = (position.y - imagePosition.y) / pixelSpacing.row
        
        // Find frame index based on z position
        var frameIndex = 0
        for (index, offset) in gridFrameOffsetVector.enumerated() {
            let frameZ = imagePosition.z + offset
            if abs(position.z - frameZ) < abs(position.z - (imagePosition.z + (frameIndex < gridFrameOffsetVector.count ? gridFrameOffsetVector[frameIndex] : 0))) {
                frameIndex = index
            }
        }
        
        // Check bounds and get nearest voxel value
        let col = Int(round(colIndex))
        let row = Int(round(rowIndex))
        
        return doseValue(frame: frameIndex, row: row, column: col)
    }
}

// MARK: - DVHData

/// DVH (Dose Volume Histogram) Data
///
/// Represents a dose-volume histogram for a specific structure.
///
/// Reference: PS3.3 C.8.8.3 - RT Dose Module
public struct DVHData: Sendable {
    
    /// DVH Type (CUMULATIVE, DIFFERENTIAL)
    public let type: String?
    
    /// Dose Units (GY, RELATIVE, etc.)
    public let doseUnits: String?
    
    /// Dose Type (PHYSICAL, EFFECTIVE, etc.)
    public let doseType: String?
    
    /// Volume Units (CM3, PERCENT)
    public let volumeUnits: String?
    
    /// Referenced ROI Number
    public let referencedROINumber: Int?
    
    /// DVH Normalization Point (x, y, z in mm)
    public let normalizationPoint: Point3D?
    
    /// DVH Normalization Dose Value
    public let normalizationDoseValue: Double?
    
    /// DVH Minimum Dose
    public let minimumDose: Double?
    
    /// DVH Maximum Dose
    public let maximumDose: Double?
    
    /// DVH Mean Dose
    public let meanDose: Double?
    
    /// DVH Data array (dose-volume pairs)
    /// Each element represents [dose, volume] pair
    public let data: [(dose: Double, volume: Double)]
    
    /// Initialize DVH Data
    public init(
        type: String? = nil,
        doseUnits: String? = nil,
        doseType: String? = nil,
        volumeUnits: String? = nil,
        referencedROINumber: Int? = nil,
        normalizationPoint: Point3D? = nil,
        normalizationDoseValue: Double? = nil,
        minimumDose: Double? = nil,
        maximumDose: Double? = nil,
        meanDose: Double? = nil,
        data: [(dose: Double, volume: Double)] = []
    ) {
        self.type = type
        self.doseUnits = doseUnits
        self.doseType = doseType
        self.volumeUnits = volumeUnits
        self.referencedROINumber = referencedROINumber
        self.normalizationPoint = normalizationPoint
        self.normalizationDoseValue = normalizationDoseValue
        self.minimumDose = minimumDose
        self.maximumDose = maximumDose
        self.meanDose = meanDose
        self.data = data
    }
}
