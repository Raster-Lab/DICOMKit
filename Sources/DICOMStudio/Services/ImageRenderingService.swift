// ImageRenderingService.swift
// DICOMStudio
//
// DICOM Studio — Image rendering service wrapping DICOMKit APIs

import Foundation
import DICOMKit
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Service for rendering DICOM images from files.
///
/// Wraps DICOMKit rendering APIs providing a clean interface for the ViewModel layer.
/// Handles pixel data extraction, window/level application, and frame rendering.
public final class ImageRenderingService: Sendable {

    public init() {}

    #if canImport(CoreGraphics)

    /// Renders a specific frame from a DICOM file.
    ///
    /// - Parameters:
    ///   - filePath: Path to the DICOM file.
    ///   - frameIndex: Frame index (0-based).
    ///   - windowCenter: Optional window center override.
    ///   - windowWidth: Optional window width override.
    /// - Returns: Rendered CGImage, or nil if rendering fails.
    /// - Throws: Error if the file cannot be read.
    public func renderFrame(
        filePath: String,
        frameIndex: Int = 0,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil
    ) throws -> CGImage? {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)
        let file = try DICOMFile.read(from: data)

        if let center = windowCenter, let width = windowWidth {
            let window = WindowSettings(center: center, width: width)
            return file.renderFrame(frameIndex, window: window)
        }

        return file.renderFrameWithStoredWindow(frameIndex)
    }

    /// Renders a frame using a DICOMFile that has already been parsed.
    ///
    /// - Parameters:
    ///   - file: The parsed DICOMFile.
    ///   - frameIndex: Frame index (0-based).
    ///   - windowCenter: Optional window center override.
    ///   - windowWidth: Optional window width override.
    /// - Returns: Rendered CGImage, or nil if rendering fails.
    public func renderFrame(
        from file: DICOMFile,
        frameIndex: Int = 0,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil
    ) -> CGImage? {
        if let center = windowCenter, let width = windowWidth {
            let window = WindowSettings(center: center, width: width)
            return file.renderFrame(frameIndex, window: window)
        }

        return file.renderFrameWithStoredWindow(frameIndex)
    }

    #endif

    /// Extracts pixel data descriptor from a DICOM file.
    ///
    /// - Parameter filePath: Path to the DICOM file.
    /// - Returns: PixelDataDescriptor, or nil if not available.
    /// - Throws: Error if the file cannot be read.
    public func pixelDataDescriptor(filePath: String) throws -> PixelDataDescriptor? {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)
        let file = try DICOMFile.read(from: data)
        return file.pixelDataDescriptor()
    }

    /// Extracts window settings from a DICOM file.
    ///
    /// - Parameter filePath: Path to the DICOM file.
    /// - Returns: Array of window settings from the file header.
    /// - Throws: Error if the file cannot be read.
    public func windowSettings(filePath: String) throws -> [WindowSettings] {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)
        let file = try DICOMFile.read(from: data)
        return file.allWindowSettings()
    }
}
