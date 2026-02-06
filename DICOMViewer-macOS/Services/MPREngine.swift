//
//  MPREngine.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import AppKit
import DICOMKit
import DICOMCore

/// Errors that can occur during MPR operations
enum MPREngineError: LocalizedError {
    case insufficientSlices
    case inconsistentDimensions
    case missingPixelData
    case invalidSliceIndex
    case volumeBuildFailed(String)

    var errorDescription: String? {
        switch self {
        case .insufficientSlices:
            return "At least 2 slices are required to build a volume"
        case .inconsistentDimensions:
            return "All slices must have the same image dimensions"
        case .missingPixelData:
            return "Unable to extract pixel data from DICOM file"
        case .invalidSliceIndex:
            return "Slice index is out of range"
        case .volumeBuildFailed(let reason):
            return "Failed to build volume: \(reason)"
        }
    }
}

/// Service for Multi-Planar Reconstruction computations
@MainActor
final class MPREngine {

    // MARK: - Volume Construction

    /// Build a Volume from a sorted list of DicomInstance objects
    func buildVolume(from instances: [DicomInstance]) async throws -> Volume {
        guard instances.count >= 2 else {
            throw MPREngineError.insufficientSlices
        }

        // Sort by z-position (imagePositionZ preferred, fall back to sliceLocation)
        let sorted = instances.sorted { a, b in
            let zA = a.imagePositionZ ?? a.sliceLocation ?? 0
            let zB = b.imagePositionZ ?? b.sliceLocation ?? 0
            return zA < zB
        }

        // Validate uniform dimensions
        guard let firstRows = sorted.first?.rows, let firstCols = sorted.first?.columns else {
            throw MPREngineError.volumeBuildFailed("Missing image dimensions on first instance")
        }

        for instance in sorted {
            guard instance.rows == firstRows, instance.columns == firstCols else {
                throw MPREngineError.inconsistentDimensions
            }
        }

        let sliceWidth = firstCols
        let sliceHeight = firstRows
        let sliceCount = sorted.count
        let sliceSize = sliceWidth * sliceHeight

        var volumeData = [Float](repeating: 0, count: sliceSize * sliceCount)

        // Default rescale values
        var rescaleSlope: Double = 1.0
        var rescaleIntercept: Double = 0.0
        var windowCenter: Double = 40.0
        var windowWidth: Double = 400.0
        var pixelSpacingRow: Double = 1.0
        var pixelSpacingCol: Double = 1.0

        for (sliceIndex, instance) in sorted.enumerated() {
            let fileURL = URL(fileURLWithPath: instance.filePath)
            let fileData = try Data(contentsOf: fileURL)
            let dicomFile = try DICOMFile.read(from: fileData)
            let dataset = dicomFile.dataset

            // Capture rescale and W/L from first slice
            if sliceIndex == 0 {
                rescaleSlope = dataset.double(for: .rescaleSlope) ?? 1.0
                rescaleIntercept = dataset.double(for: .rescaleIntercept) ?? 0.0
                windowCenter = dataset.double(for: .windowCenter) ?? 40.0
                windowWidth = dataset.double(for: .windowWidth) ?? 400.0

                if let spacingStr = dataset.string(for: .pixelSpacing) {
                    let components = spacingStr.split(separator: "\\")
                    if components.count >= 2 {
                        pixelSpacingRow = Double(components[0]) ?? 1.0
                        pixelSpacingCol = Double(components[1]) ?? 1.0
                    }
                }
            }

            guard let pixelData = try? dicomFile.pixelData() else {
                throw MPREngineError.missingPixelData
            }

            // Extract raw pixel values and apply rescale to get HU values
            let offset = sliceIndex * sliceSize
            for y in 0..<sliceHeight {
                for x in 0..<sliceWidth {
                    let pixelIndex = y * sliceWidth + x
                    let rawValue = pixelData.pixelValue(x: x, y: y, frame: 0) ?? 0
                    let huValue = Float(Double(rawValue) * rescaleSlope + rescaleIntercept)
                    volumeData[offset + pixelIndex] = huValue
                }
            }
        }

        // Compute slice spacing from positions
        let sliceSpacing: Double
        let firstZ = sorted[0].imagePositionZ ?? sorted[0].sliceLocation ?? 0
        let lastZ = sorted[sliceCount - 1].imagePositionZ ?? sorted[sliceCount - 1].sliceLocation ?? 0
        if sliceCount > 1 {
            sliceSpacing = abs(lastZ - firstZ) / Double(sliceCount - 1)
        } else {
            sliceSpacing = 1.0
        }

        let originX = sorted[0].imagePositionX ?? 0
        let originY = sorted[0].imagePositionY ?? 0
        let originZ = firstZ

        return Volume(
            data: volumeData,
            width: sliceWidth,
            height: sliceHeight,
            depth: sliceCount,
            spacingX: pixelSpacingCol,
            spacingY: pixelSpacingRow,
            spacingZ: max(sliceSpacing, 0.001),
            origin: (originX, originY, originZ),
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
    }

    // MARK: - Slice Extraction

    /// Extract an axial slice at given z index (width × height)
    func extractAxialSlice(from volume: Volume, at index: Int) -> MPRSlice? {
        guard index >= 0, index < volume.depth else { return nil }

        let w = volume.width
        let h = volume.height
        var pixelData = [Float](repeating: 0, count: w * h)

        let offset = index * w * h
        for y in 0..<h {
            for x in 0..<w {
                pixelData[y * w + x] = volume.data[offset + y * w + x]
            }
        }

        return MPRSlice(
            plane: .axial,
            index: index,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingX,
            pixelSpacingY: volume.spacingY
        )
    }

    /// Extract a sagittal slice at given x index (depth × height)
    func extractSagittalSlice(from volume: Volume, at index: Int) -> MPRSlice? {
        guard index >= 0, index < volume.width else { return nil }

        let w = volume.depth
        let h = volume.height
        var pixelData = [Float](repeating: 0, count: w * h)

        for z in 0..<volume.depth {
            for y in 0..<volume.height {
                pixelData[y * w + z] = volume.data[z * volume.width * volume.height + y * volume.width + index]
            }
        }

        return MPRSlice(
            plane: .sagittal,
            index: index,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingZ,
            pixelSpacingY: volume.spacingY
        )
    }

    /// Extract a coronal slice at given y index (width × depth)
    func extractCoronalSlice(from volume: Volume, at index: Int) -> MPRSlice? {
        guard index >= 0, index < volume.height else { return nil }

        let w = volume.width
        let h = volume.depth
        var pixelData = [Float](repeating: 0, count: w * h)

        for z in 0..<volume.depth {
            for x in 0..<volume.width {
                pixelData[z * w + x] = volume.data[z * volume.width * volume.height + index * volume.width + x]
            }
        }

        return MPRSlice(
            plane: .coronal,
            index: index,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingX,
            pixelSpacingY: volume.spacingZ
        )
    }

    /// Extract a slice for any plane at the given index
    func extractSlice(from volume: Volume, plane: MPRPlane, at index: Int) -> MPRSlice? {
        switch plane {
        case .axial: return extractAxialSlice(from: volume, at: index)
        case .sagittal: return extractSagittalSlice(from: volume, at: index)
        case .coronal: return extractCoronalSlice(from: volume, at: index)
        }
    }

    /// Maximum valid slice index for a given plane
    func maxSliceIndex(for plane: MPRPlane, in volume: Volume) -> Int {
        switch plane {
        case .axial: return volume.depth - 1
        case .sagittal: return volume.width - 1
        case .coronal: return volume.height - 1
        }
    }

    // MARK: - Projection Rendering

    /// Generate Maximum Intensity Projection along the specified plane axis
    func generateMIP(from volume: Volume, along plane: MPRPlane, slabThickness: Int? = nil) -> MPRSlice? {
        return generateProjection(from: volume, along: plane, mode: .max, slabThickness: slabThickness)
    }

    /// Generate Minimum Intensity Projection along the specified plane axis
    func generateMinIP(from volume: Volume, along plane: MPRPlane) -> MPRSlice? {
        return generateProjection(from: volume, along: plane, mode: .min)
    }

    /// Generate Average Intensity Projection along the specified plane axis
    func generateAverageIP(from volume: Volume, along plane: MPRPlane) -> MPRSlice? {
        return generateProjection(from: volume, along: plane, mode: .average)
    }

    // MARK: - Image Rendering

    /// Convert an MPRSlice to an NSImage by applying window/level
    func renderSlice(_ slice: MPRSlice, windowCenter: Double, windowWidth: Double) -> NSImage? {
        let w = slice.width
        let h = slice.height
        guard w > 0, h > 0, slice.pixelData.count == w * h else { return nil }

        let lower = windowCenter - windowWidth / 2.0
        let upper = windowCenter + windowWidth / 2.0
        let range = upper - lower

        var grayscaleBytes = [UInt8](repeating: 0, count: w * h)

        for i in 0..<slice.pixelData.count {
            let value = Double(slice.pixelData[i])
            let clamped: Double
            if value <= lower {
                clamped = 0
            } else if value >= upper {
                clamped = 255
            } else {
                clamped = ((value - lower) / range) * 255.0
            }
            grayscaleBytes[i] = UInt8(clamped)
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &grayscaleBytes,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        guard let cgImage = context.makeImage() else { return nil }

        let size = NSSize(width: w, height: h)
        return NSImage(cgImage: cgImage, size: size)
    }

    // MARK: - Private Helpers

    private enum ProjectionMode {
        case max, min, average
    }

    private func generateProjection(
        from volume: Volume,
        along plane: MPRPlane,
        mode: ProjectionMode,
        slabThickness: Int? = nil
    ) -> MPRSlice? {
        switch plane {
        case .axial:
            return projectAlongZ(volume: volume, mode: mode, slabThickness: slabThickness)
        case .sagittal:
            return projectAlongX(volume: volume, mode: mode, slabThickness: slabThickness)
        case .coronal:
            return projectAlongY(volume: volume, mode: mode, slabThickness: slabThickness)
        }
    }

    /// Project along Z axis → output is width × height
    private func projectAlongZ(volume: Volume, mode: ProjectionMode, slabThickness: Int?) -> MPRSlice {
        let w = volume.width
        let h = volume.height
        let maxZ = volume.depth
        let startZ = 0
        let endZ = slabThickness.map { min($0, maxZ) } ?? maxZ
        var pixelData = [Float](repeating: 0, count: w * h)

        for y in 0..<h {
            for x in 0..<w {
                var result = volume.data[startZ * w * h + y * w + x]
                var sum = result
                for z in (startZ + 1)..<endZ {
                    let val = volume.data[z * w * h + y * w + x]
                    switch mode {
                    case .max: result = Swift.max(result, val)
                    case .min: result = Swift.min(result, val)
                    case .average: sum += val
                    }
                }
                if mode == .average {
                    pixelData[y * w + x] = sum / Float(endZ - startZ)
                } else {
                    pixelData[y * w + x] = result
                }
            }
        }

        return MPRSlice(
            plane: .axial,
            index: 0,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingX,
            pixelSpacingY: volume.spacingY
        )
    }

    /// Project along X axis → output is depth × height
    private func projectAlongX(volume: Volume, mode: ProjectionMode, slabThickness: Int?) -> MPRSlice {
        let w = volume.depth
        let h = volume.height
        let maxX = volume.width
        let startX = 0
        let endX = slabThickness.map { min($0, maxX) } ?? maxX
        var pixelData = [Float](repeating: 0, count: w * h)

        for y in 0..<h {
            for z in 0..<volume.depth {
                var result = volume.data[z * volume.width * volume.height + y * volume.width + startX]
                var sum = result
                for x in (startX + 1)..<endX {
                    let val = volume.data[z * volume.width * volume.height + y * volume.width + x]
                    switch mode {
                    case .max: result = Swift.max(result, val)
                    case .min: result = Swift.min(result, val)
                    case .average: sum += val
                    }
                }
                if mode == .average {
                    pixelData[y * w + z] = sum / Float(endX - startX)
                } else {
                    pixelData[y * w + z] = result
                }
            }
        }

        return MPRSlice(
            plane: .sagittal,
            index: 0,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingZ,
            pixelSpacingY: volume.spacingY
        )
    }

    /// Project along Y axis → output is width × depth
    private func projectAlongY(volume: Volume, mode: ProjectionMode, slabThickness: Int?) -> MPRSlice {
        let w = volume.width
        let h = volume.depth
        let maxY = volume.height
        let startY = 0
        let endY = slabThickness.map { min($0, maxY) } ?? maxY
        var pixelData = [Float](repeating: 0, count: w * h)

        for z in 0..<volume.depth {
            for x in 0..<volume.width {
                var result = volume.data[z * volume.width * volume.height + startY * volume.width + x]
                var sum = result
                for y in (startY + 1)..<endY {
                    let val = volume.data[z * volume.width * volume.height + y * volume.width + x]
                    switch mode {
                    case .max: result = Swift.max(result, val)
                    case .min: result = Swift.min(result, val)
                    case .average: sum += val
                    }
                }
                if mode == .average {
                    pixelData[z * w + x] = sum / Float(endY - startY)
                } else {
                    pixelData[z * w + x] = result
                }
            }
        }

        return MPRSlice(
            plane: .coronal,
            index: 0,
            width: w,
            height: h,
            pixelData: pixelData,
            pixelSpacingX: volume.spacingX,
            pixelSpacingY: volume.spacingZ
        )
    }
}
