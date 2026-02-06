// ExportService.swift
// DICOMViewer iOS - Export Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftUI
import Photos
import CoreGraphics
import DICOMKit

/// Service for exporting DICOM images to various formats
actor ExportService {
    
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - Export Formats
    
    /// Export format options
    enum ExportFormat {
        case png
        case jpeg(quality: Double) // 0.0 to 1.0
        case tiff
    }
    
    // MARK: - Export Options
    
    /// Options for image export
    struct ExportOptions {
        var format: ExportFormat = .png
        var burnInAnnotations: Bool = false
        var includeMetadata: Bool = false
        var saveToPhotos: Bool = false
        
        static let `default` = ExportOptions()
    }
    
    // MARK: - Export Methods
    
    /// Export a CGImage to a file
    /// - Parameters:
    ///   - image: The image to export
    ///   - options: Export options
    /// - Returns: URL of the exported file
    @MainActor
    func exportImage(
        _ image: CGImage,
        options: ExportOptions = .default
    ) async throws -> URL {
        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let filename = generateFilename(for: options.format)
        let fileURL = tempDir.appendingPathComponent(filename)
        
        // Create UIImage for export
        let uiImage = UIImage(cgImage: image)
        
        // Convert to data based on format
        let data: Data
        switch options.format {
        case .png:
            guard let pngData = uiImage.pngData() else {
                throw ExportError.imageConversionFailed
            }
            data = pngData
            
        case .jpeg(let quality):
            guard let jpegData = uiImage.jpegData(compressionQuality: quality) else {
                throw ExportError.imageConversionFailed
            }
            data = jpegData
            
        case .tiff:
            // For TIFF, we'll use PNG as fallback since iOS doesn't have native TIFF encoding
            guard let pngData = uiImage.pngData() else {
                throw ExportError.imageConversionFailed
            }
            data = pngData
        }
        
        // Write to file
        try data.write(to: fileURL)
        
        // Save to Photos if requested
        if options.saveToPhotos {
            try await saveToPhotosLibrary(uiImage)
        }
        
        return fileURL
    }
    
    /// Export metadata to JSON
    /// - Parameter dataset: DICOM dataset
    /// - Returns: URL of the exported JSON file
    func exportMetadataJSON(_ metadata: [String: String]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "dicom-metadata-\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: fileURL)
        
        return fileURL
    }
    
    /// Export metadata to CSV
    /// - Parameter metadata: Metadata dictionary
    /// - Returns: URL of the exported CSV file
    func exportMetadataCSV(_ metadata: [String: String]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "dicom-metadata-\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(filename)
        
        var csv = "Tag,Value\n"
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            // Escape quotes in values
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(key)\",\"\(escapedValue)\"\n"
        }
        
        guard let data = csv.data(using: .utf8) else {
            throw ExportError.metadataEncodingFailed
        }
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Photos Library
    
    /// Save image to Photos library
    @MainActor
    private func saveToPhotosLibrary(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(throwing: ExportError.photosPermissionDenied)
                    return
                }
                
                PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ExportError.photosSaveFailed)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate filename based on format
    private func generateFilename(for format: ExportFormat) -> String {
        let timestamp = Date().timeIntervalSince1970
        
        switch format {
        case .png:
            return "dicom-export-\(timestamp).png"
        case .jpeg:
            return "dicom-export-\(timestamp).jpg"
        case .tiff:
            return "dicom-export-\(timestamp).tiff"
        }
    }
}

// MARK: - Export Errors

/// Errors that can occur during export
enum ExportError: LocalizedError {
    case imageConversionFailed
    case metadataEncodingFailed
    case photosPermissionDenied
    case photosSaveFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to export format"
        case .metadataEncodingFailed:
            return "Failed to encode metadata"
        case .photosPermissionDenied:
            return "Permission to access Photos library was denied"
        case .photosSaveFailed:
            return "Failed to save image to Photos library"
        case .fileWriteFailed:
            return "Failed to write export file"
        }
    }
}
