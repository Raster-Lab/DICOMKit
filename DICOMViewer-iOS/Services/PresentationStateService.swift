// PresentationStateService.swift
// DICOMViewer iOS - Presentation State Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import DICOMKit
import DICOMCore
import CoreGraphics

/// Service for managing DICOM Presentation State objects
actor PresentationStateService {
    /// Shared instance
    static let shared = PresentationStateService()
    
    /// Parser for GSPS objects
    private let parser = GrayscalePresentationStateParser()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Loading
    
    /// Loads a Grayscale Presentation State from a DICOM file
    /// - Parameter url: URL to the GSPS DICOM file
    /// - Returns: Parsed GrayscalePresentationState
    func loadGSPS(from url: URL) throws -> GrayscalePresentationState {
        let data = try Data(contentsOf: url)
        let file = try DICOMFile.read(from: data, force: true)
        return try parser.parse(dataSet: file.dataSet)
    }
    
    /// Loads a Grayscale Presentation State from DICOM data
    /// - Parameter data: DICOM file data
    /// - Returns: Parsed GrayscalePresentationState
    func loadGSPS(from data: Data) throws -> GrayscalePresentationState {
        let file = try DICOMFile.read(from: data, force: true)
        return try parser.parse(dataSet: file.dataSet)
    }
    
    /// Checks if a DICOM file is a Grayscale Presentation State
    /// - Parameter file: DICOM file to check
    /// - Returns: true if the file is a GSPS
    func isGSPS(_ file: DICOMFile) -> Bool {
        guard let sopClassUID = file.dataSet.string(for: .sopClassUID) else {
            return false
        }
        return sopClassUID == .grayscaleSoftcopyPresentationStateStorage
    }
    
    /// Finds applicable presentation states for an image
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID of the image
    ///   - seriesInstanceUID: Series Instance UID of the image
    ///   - presentationStates: Available presentation states to search
    /// - Returns: Array of applicable presentation states
    func findApplicablePresentationStates(
        for sopInstanceUID: String,
        seriesInstanceUID: String,
        from presentationStates: [GrayscalePresentationState]
    ) -> [GrayscalePresentationState] {
        presentationStates.filter { ps in
            ps.referencedSeries.contains { series in
                series.seriesInstanceUID == seriesInstanceUID &&
                series.referencedImages.contains { image in
                    image.sopInstanceUID == sopInstanceUID
                }
            }
        }
    }
    
    // MARK: - Rendering
    
    /// Applies a presentation state to pixel data and renders to CGImage
    /// - Parameters:
    ///   - presentationState: The GSPS to apply
    ///   - pixelData: Source pixel data
    ///   - frameIndex: Frame index (default 0)
    /// - Returns: Rendered CGImage with presentation state applied
    func applyPresentationState(
        _ presentationState: GrayscalePresentationState,
        to pixelData: PixelData,
        frameIndex: Int = 0
    ) -> CGImage? {
        let applicator = PresentationStateApplicator(presentationState: presentationState)
        return applicator.apply(to: pixelData, frameIndex: frameIndex)
    }
    
    /// Gets shutter mask for rendering as overlay
    /// - Parameters:
    ///   - shutters: Array of display shutters
    ///   - width: Image width
    ///   - height: Image height
    /// - Returns: Shutter mask as CGImage (white = visible, black = shuttered)
    func createShutterMask(
        from shutters: [DisplayShutter],
        width: Int,
        height: Int
    ) -> CGImage? {
        guard !shutters.isEmpty, width > 0, height > 0 else {
            return nil
        }
        
        var bytes = [UInt8](repeating: 255, count: width * height) // White = visible
        
        for row in 0..<height {
            for col in 0..<width {
                let isShuttered = shutters.contains { shutter in
                    shutter.contains(column: col, row: row)
                }
                
                if isShuttered {
                    let index = row * width + col
                    bytes[index] = 0 // Black = shuttered
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else {
            return nil
        }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

/// Model for presentation state info displayed in UI
public struct PresentationStateInfo: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let description: String?
    public let creationDate: String?
    public let presentationState: GrayscalePresentationState
    
    public init(from ps: GrayscalePresentationState) {
        self.id = ps.sopInstanceUID
        self.label = ps.presentationLabel ?? "Presentation State"
        self.description = ps.presentationDescription
        
        if let date = ps.presentationCreationDate {
            self.creationDate = date.formatted()
        } else {
            self.creationDate = nil
        }
        
        self.presentationState = ps
    }
}

/// Extension for formatted date display
extension DICOMDate {
    /// Formats the DICOM date for display in the user interface
    ///
    /// Uses the system's medium date style (e.g., "Jun 15, 2024" in US locale).
    /// If the date cannot be converted to a Foundation Date, falls back to
    /// ISO 8601 format (YYYY-MM-DD).
    ///
    /// - Returns: A localized date string, or ISO 8601 format as fallback
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        // Create a date from components
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        // Fallback to ISO 8601 format
        return "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}
