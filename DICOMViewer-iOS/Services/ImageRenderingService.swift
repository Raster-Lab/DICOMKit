// ImageRenderingService.swift
// DICOMViewer iOS - Image Rendering Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import DICOMKit
import DICOMCore
import CoreGraphics

/// Service for rendering DICOM images with window/level and other display settings
actor ImageRenderingService {
    /// Shared instance
    static let shared = ImageRenderingService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Rendering
    
    /// Renders a DICOM frame to a CGImage
    /// - Parameters:
    ///   - dicomFile: The DICOM file to render
    ///   - frameIndex: Frame index (default 0)
    ///   - windowCenter: Custom window center (nil for auto)
    ///   - windowWidth: Custom window width (nil for auto)
    ///   - invert: Invert grayscale (default false)
    /// - Returns: Rendered CGImage
    func renderFrame(
        from dicomFile: DICOMFile,
        frameIndex: Int = 0,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        invert: Bool = false
    ) throws -> CGImage? {
        // Get pixel data
        guard let pixelData = dicomFile.dataSet.pixelData() else {
            throw ImageRenderingError.noPixelData
        }
        
        let descriptor = pixelData.descriptor
        let paletteColorLUT = dicomFile.dataSet.paletteColorLUT()
        let renderer = PixelDataRenderer(pixelData: pixelData, paletteColorLUT: paletteColorLUT)
        
        // For monochrome images, apply custom window settings
        if descriptor.photometricInterpretation.isMonochrome {
            let window = getWindowSettings(
                for: dicomFile,
                frameIndex: frameIndex,
                customCenter: windowCenter,
                customWidth: windowWidth,
                invert: invert,
                pixelData: pixelData
            )
            
            return renderer.renderMonochromeFrame(frameIndex, window: window)
        } else if descriptor.photometricInterpretation.isPaletteColor {
            return renderer.renderPaletteColorFrame(frameIndex)
        } else {
            return renderer.renderColorFrame(frameIndex)
        }
    }
    
    /// Gets the window settings for rendering
    private func getWindowSettings(
        for dicomFile: DICOMFile,
        frameIndex: Int,
        customCenter: Double?,
        customWidth: Double?,
        invert: Bool,
        pixelData: PixelData
    ) -> WindowSettings {
        var center: Double
        var width: Double
        
        // Use custom values if provided, otherwise get from DICOM or auto-calculate
        if let customC = customCenter, let customW = customWidth {
            center = customC
            width = customW
        } else if let dicomSettings = dicomFile.dataSet.windowSettings() {
            center = customCenter ?? dicomSettings.center
            width = customWidth ?? dicomSettings.width
        } else {
            // Auto-calculate from pixel data
            if let range = pixelData.pixelRange(forFrame: frameIndex) {
                center = Double(range.min + range.max) / 2.0
                width = Double(range.max - range.min)
            } else {
                center = 128.0
                width = 256.0
            }
        }
        
        return WindowSettings(center: center, width: max(1.0, width), invert: invert)
    }
    
    /// Gets the number of frames in a DICOM file
    func frameCount(for dicomFile: DICOMFile) -> Int {
        if let frameStr = dicomFile.dataSet.string(for: .numberOfFrames),
           let frames = Int(frameStr.trimmingCharacters(in: .whitespaces)) {
            return frames
        }
        return 1
    }
    
    /// Gets the default window settings from DICOM metadata
    func defaultWindowSettings(for dicomFile: DICOMFile) -> WindowSettings? {
        dicomFile.dataSet.windowSettings()
    }
    
    /// Gets all available window presets from DICOM metadata
    func allWindowPresets(for dicomFile: DICOMFile) -> [WindowSettings] {
        dicomFile.dataSet.allWindowSettings()
    }
    
    /// Gets pixel spacing from DICOM metadata
    func pixelSpacing(for dicomFile: DICOMFile) -> (row: Double, column: Double)? {
        if let spacing = dicomFile.dataSet.decimalStrings(for: .pixelSpacing),
           spacing.count >= 2 {
            return (row: spacing[0].value, column: spacing[1].value)
        }
        return nil
    }
    
    /// Gets image dimensions from DICOM metadata
    func imageDimensions(for dicomFile: DICOMFile) -> (rows: Int, columns: Int)? {
        guard let rows = dicomFile.dataSet.uint16(for: .rows),
              let columns = dicomFile.dataSet.uint16(for: .columns) else {
            return nil
        }
        return (rows: Int(rows), columns: Int(columns))
    }
}

/// Errors that can occur during image rendering
enum ImageRenderingError: Error, LocalizedError {
    case noPixelData
    case invalidFrameIndex
    case renderingFailed
    
    var errorDescription: String? {
        switch self {
        case .noPixelData:
            return "No pixel data found in DICOM file"
        case .invalidFrameIndex:
            return "Invalid frame index"
        case .renderingFailed:
            return "Failed to render image"
        }
    }
}
