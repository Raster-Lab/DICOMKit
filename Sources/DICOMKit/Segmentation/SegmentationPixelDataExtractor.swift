//
// SegmentationPixelDataExtractor.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-05.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Extracts segmentation masks from DICOM segmentation pixel data
///
/// Supports both binary (1-bit packed) and fractional (8 or 16-bit) segmentation types.
/// Handles frame-to-segment mapping using Per-Frame Functional Groups.
///
/// Reference: PS3.3 C.8.20.2 - Segmentation Image Module
public struct SegmentationPixelDataExtractor: Sendable {
    
    // MARK: - Binary Segmentation Extraction
    
    /// Extract a single binary segmentation frame from packed binary data
    ///
    /// Binary segmentations use 1 bit per pixel, packed into bytes (8 pixels per byte).
    /// Each bit represents presence (1) or absence (0) of the segment at that pixel location.
    /// Bits are packed with the most significant bit first.
    ///
    /// Reference: PS3.3 C.8.20.2 - Binary segmentation encoding
    ///
    /// - Parameters:
    ///   - pixelData: The raw pixel data containing packed binary values
    ///   - frameIndex: The frame index to extract (0-based)
    ///   - rows: Number of rows in the frame
    ///   - columns: Number of columns in the frame
    /// - Returns: Array of UInt8 values (0 or 1) representing the binary mask, or nil if invalid parameters
    public static func extractBinaryFrame(
        from pixelData: Data,
        frameIndex: Int,
        rows: Int,
        columns: Int
    ) -> [UInt8]? {
        guard frameIndex >= 0, rows > 0, columns > 0 else {
            return nil
        }
        
        let totalPixels = rows * columns
        
        // Binary segmentation: 1 bit per pixel, packed into bytes
        // Each frame requires ceil(totalPixels / 8) bytes
        let bitsPerFrame = totalPixels
        let bytesPerFrame = (bitsPerFrame + 7) / 8  // Round up to nearest byte
        
        let frameOffset = frameIndex * bytesPerFrame
        
        guard frameOffset + bytesPerFrame <= pixelData.count else {
            return nil
        }
        
        // Extract the packed frame data
        let frameData = pixelData.subdata(in: frameOffset..<(frameOffset + bytesPerFrame))
        
        // Unpack the bits into individual pixel values
        var mask = [UInt8](repeating: 0, count: totalPixels)
        
        for pixelIndex in 0..<totalPixels {
            let byteIndex = pixelIndex / 8
            let bitIndex = 7 - (pixelIndex % 8)  // MSB first
            
            if byteIndex < frameData.count {
                let byte = frameData[byteIndex]
                let bitValue = (byte >> bitIndex) & 0x01
                mask[pixelIndex] = bitValue
            }
        }
        
        return mask
    }
    
    // MARK: - Fractional Segmentation Extraction
    
    /// Extract a single fractional segmentation frame from 8 or 16-bit pixel data
    ///
    /// Fractional segmentations use 8 or 16-bit unsigned integers to represent
    /// probability or occupancy values. Values are scaled based on maxFractionalValue.
    ///
    /// Reference: PS3.3 C.8.20.2 - Fractional segmentation encoding
    ///
    /// - Parameters:
    ///   - pixelData: The raw pixel data containing fractional values
    ///   - frameIndex: The frame index to extract (0-based)
    ///   - rows: Number of rows in the frame
    ///   - columns: Number of columns in the frame
    ///   - bitsAllocated: Bits allocated per pixel (8 or 16)
    ///   - maxValue: Maximum fractional value (used for normalization)
    /// - Returns: Array of UInt8 values (0-255) normalized for rendering, or nil if invalid parameters
    public static func extractFractionalFrame(
        from pixelData: Data,
        frameIndex: Int,
        rows: Int,
        columns: Int,
        bitsAllocated: Int,
        maxValue: Int
    ) -> [UInt8]? {
        guard frameIndex >= 0, rows > 0, columns > 0 else {
            return nil
        }
        
        guard bitsAllocated == 8 || bitsAllocated == 16 else {
            return nil
        }
        
        guard maxValue > 0 else {
            return nil
        }
        
        let totalPixels = rows * columns
        let bytesPerPixel = bitsAllocated / 8
        let bytesPerFrame = totalPixels * bytesPerPixel
        
        let frameOffset = frameIndex * bytesPerFrame
        
        guard frameOffset + bytesPerFrame <= pixelData.count else {
            return nil
        }
        
        // Extract the frame data
        let frameData = pixelData.subdata(in: frameOffset..<(frameOffset + bytesPerFrame))
        
        // Extract and normalize pixel values
        var mask = [UInt8](repeating: 0, count: totalPixels)
        let scale = 255.0 / Double(maxValue)
        
        for pixelIndex in 0..<totalPixels {
            let offset = pixelIndex * bytesPerPixel
            
            let rawValue: Int
            if bitsAllocated == 8 {
                rawValue = Int(frameData[offset])
            } else {
                // 16-bit little-endian
                let low = Int(frameData[offset])
                let high = Int(frameData[offset + 1])
                rawValue = low | (high << 8)
            }
            
            // Normalize to 0-255 range
            let normalized = min(Double(rawValue), Double(maxValue)) * scale
            mask[pixelIndex] = UInt8(max(0, min(255, normalized)))
        }
        
        return mask
    }
    
    // MARK: - Segment Mask Extraction
    
    /// Extract a specific segment mask from a segmentation object
    ///
    /// Maps frames to the requested segment number using Per-Frame Functional Groups.
    /// For binary segmentations, each frame represents a single segment.
    /// For fractional segmentations, frames may represent different segments.
    ///
    /// - Parameters:
    ///   - segmentation: The segmentation object containing metadata
    ///   - segmentNumber: The segment number to extract (1-based, as per DICOM standard)
    ///   - pixelData: The raw pixel data
    /// - Returns: Array of UInt8 values representing the segment mask (0-255), or nil if segment not found
    public static func extractSegmentMask(
        from segmentation: Segmentation,
        segmentNumber: Int,
        pixelData: Data
    ) -> [UInt8]? {
        guard segmentNumber > 0 && segmentNumber <= segmentation.numberOfSegments else {
            return nil
        }
        
        // Find all frames that belong to this segment
        var segmentFrames: [Int] = []
        
        for (frameIndex, functionalGroup) in segmentation.perFrameFunctionalGroups.enumerated() {
            if let segmentID = functionalGroup.segmentIdentification?.referencedSegmentNumber,
               segmentID == segmentNumber {
                segmentFrames.append(frameIndex)
            }
        }
        
        guard !segmentFrames.isEmpty else {
            return nil
        }
        
        // For now, extract the first frame belonging to this segment
        // In multi-frame scenarios, this would need more sophisticated handling
        let frameIndex = segmentFrames[0]
        
        switch segmentation.segmentationType {
        case .binary:
            return extractBinaryFrame(
                from: pixelData,
                frameIndex: frameIndex,
                rows: segmentation.rows,
                columns: segmentation.columns
            )
            
        case .fractional:
            guard let maxValue = segmentation.maxFractionalValue else {
                return nil
            }
            
            return extractFractionalFrame(
                from: pixelData,
                frameIndex: frameIndex,
                rows: segmentation.rows,
                columns: segmentation.columns,
                bitsAllocated: segmentation.bitsAllocated,
                maxValue: maxValue
            )
        }
    }
    
    // MARK: - All Segments Extraction
    
    /// Extract all segment masks from a segmentation object
    ///
    /// Returns a dictionary mapping segment numbers to their corresponding masks.
    /// Each mask is normalized to 0-255 for rendering purposes.
    ///
    /// - Parameters:
    ///   - segmentation: The segmentation object containing metadata
    ///   - pixelData: The raw pixel data
    /// - Returns: Dictionary mapping segment number to mask array, empty if extraction fails
    public static func extractAllSegmentMasks(
        from segmentation: Segmentation,
        pixelData: Data
    ) -> [Int: [UInt8]] {
        var masks: [Int: [UInt8]] = [:]
        
        // Build frame-to-segment mapping
        var segmentToFrames: [Int: [Int]] = [:]
        
        for (frameIndex, functionalGroup) in segmentation.perFrameFunctionalGroups.enumerated() {
            if let segmentID = functionalGroup.segmentIdentification?.referencedSegmentNumber {
                segmentToFrames[segmentID, default: []].append(frameIndex)
            }
        }
        
        // Extract mask for each segment
        for segment in segmentation.segments {
            guard let frames = segmentToFrames[segment.segmentNumber],
                  let firstFrame = frames.first else {
                continue
            }
            
            let mask: [UInt8]?
            
            switch segmentation.segmentationType {
            case .binary:
                mask = extractBinaryFrame(
                    from: pixelData,
                    frameIndex: firstFrame,
                    rows: segmentation.rows,
                    columns: segmentation.columns
                )
                
            case .fractional:
                guard let maxValue = segmentation.maxFractionalValue else {
                    continue
                }
                
                mask = extractFractionalFrame(
                    from: pixelData,
                    frameIndex: firstFrame,
                    rows: segmentation.rows,
                    columns: segmentation.columns,
                    bitsAllocated: segmentation.bitsAllocated,
                    maxValue: maxValue
                )
            }
            
            if let mask = mask {
                masks[segment.segmentNumber] = mask
            }
        }
        
        return masks
    }
}
