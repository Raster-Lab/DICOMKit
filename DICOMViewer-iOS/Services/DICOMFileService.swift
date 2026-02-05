// DICOMFileService.swift
// DICOMViewer iOS - DICOM File Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import DICOMKit
import DICOMCore

/// Service for reading and managing DICOM files
///
/// Provides methods for:
/// - Reading DICOM files from disk
/// - Extracting metadata for library organization
/// - Managing file storage
actor DICOMFileService {
    /// Shared instance
    static let shared = DICOMFileService()
    
    /// File manager for file operations
    private let fileManager = FileManager.default
    
    /// Documents directory for app storage
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// DICOM library storage directory
    var libraryDirectory: URL {
        documentsDirectory.appendingPathComponent("DICOMLibrary", isDirectory: true)
    }
    
    /// Thumbnails cache directory
    var thumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Create directories if needed
        try? fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Reading
    
    /// Reads a DICOM file from disk
    /// - Parameter url: URL of the DICOM file
    /// - Returns: Parsed DICOM file
    /// - Throws: Error if file cannot be read or parsed
    func readDICOMFile(at url: URL) throws -> DICOMFile {
        let data = try Data(contentsOf: url)
        return try DICOMFile.read(from: data, force: true)
    }
    
    /// Reads DICOM file metadata without loading pixel data
    /// - Parameter url: URL of the DICOM file
    /// - Returns: Tuple containing file metadata
    /// - Throws: Error if file cannot be read
    func readMetadata(at url: URL) throws -> DICOMMetadata {
        let data = try Data(contentsOf: url)
        let options = ParsingOptions(metadataOnly: true)
        let dicomFile = try DICOMFile.read(from: data, force: true, options: options)
        return extractMetadata(from: dicomFile, fileURL: url)
    }
    
    /// Extracts metadata from a DICOM file
    private func extractMetadata(from dicomFile: DICOMFile, fileURL: URL) -> DICOMMetadata {
        let dataSet = dicomFile.dataSet
        
        // Patient information
        let patientName = dataSet.string(for: .patientName) ?? "Unknown"
        let patientID = dataSet.string(for: .patientID) ?? "Unknown"
        let patientSex = dataSet.string(for: .patientSex)
        let patientBirthDate = parseDate(dataSet.string(for: .patientBirthDate))
        
        // Study information
        let studyInstanceUID = dataSet.string(for: .studyInstanceUID) ?? UUID().uuidString
        let studyDate = parseDate(dataSet.string(for: .studyDate))
        let studyDescription = dataSet.string(for: .studyDescription)
        let accessionNumber = dataSet.string(for: .accessionNumber)
        
        // Series information
        let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) ?? UUID().uuidString
        let seriesNumber = dataSet.int32(for: .seriesNumber).map { Int($0) }
        let seriesDescription = dataSet.string(for: .seriesDescription)
        let modality = dataSet.string(for: .modality) ?? "OT"
        
        // Instance information
        let sopInstanceUID = dataSet.string(for: .sopInstanceUID) ?? UUID().uuidString
        let sopClassUID = dataSet.string(for: .sopClassUID) ?? ""
        let instanceNumber = dataSet.int32(for: .instanceNumber).map { Int($0) }
        
        // Image attributes
        let rows = dataSet.uint16(for: .rows).map { Int($0) } ?? 0
        let columns = dataSet.uint16(for: .columns).map { Int($0) } ?? 0
        let bitsAllocated = dataSet.uint16(for: .bitsAllocated).map { Int($0) } ?? 16
        let bitsStored = dataSet.uint16(for: .bitsStored).map { Int($0) } ?? 12
        let photometric = dataSet.string(for: .photometricInterpretation) ?? "MONOCHROME2"
        
        // Number of frames
        var numberOfFrames = 1
        if let frameStr = dataSet.string(for: .numberOfFrames),
           let frames = Int(frameStr.trimmingCharacters(in: .whitespaces)) {
            numberOfFrames = frames
        }
        
        // Window/Level
        let windowCenter = dataSet.decimalString(for: .windowCenter)?.value
        let windowWidth = dataSet.decimalString(for: .windowWidth)?.value
        
        // Pixel spacing
        var pixelSpacing: [Double]?
        if let spacingStrings = dataSet.decimalStrings(for: .pixelSpacing), spacingStrings.count >= 2 {
            pixelSpacing = spacingStrings.map { $0.value }
        }
        
        // Transfer syntax
        let transferSyntaxUID = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID)
        
        // File size
        let fileSize = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        
        return DICOMMetadata(
            // Patient
            patientName: patientName,
            patientID: patientID,
            patientSex: patientSex,
            patientBirthDate: patientBirthDate,
            // Study
            studyInstanceUID: studyInstanceUID,
            studyDate: studyDate,
            studyDescription: studyDescription,
            accessionNumber: accessionNumber,
            // Series
            seriesInstanceUID: seriesInstanceUID,
            seriesNumber: seriesNumber,
            seriesDescription: seriesDescription,
            modality: modality,
            // Instance
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            instanceNumber: instanceNumber,
            numberOfFrames: numberOfFrames,
            // Image
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            photometricInterpretation: photometric,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            pixelSpacing: pixelSpacing,
            transferSyntaxUID: transferSyntaxUID,
            // File
            filePath: fileURL.path,
            fileSize: fileSize
        )
    }
    
    /// Parses DICOM date string to Date
    private func parseDate(_ dateString: String?) -> Date? {
        guard let str = dateString?.trimmingCharacters(in: .whitespaces),
              str.count >= 8 else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: String(str.prefix(8)))
    }
    
    // MARK: - File Import
    
    /// Imports a DICOM file into the library
    /// - Parameter sourceURL: URL of the file to import
    /// - Returns: URL of the imported file
    /// - Throws: Error if import fails
    func importFile(from sourceURL: URL) throws -> URL {
        // Generate a unique filename
        let filename = UUID().uuidString + ".dcm"
        let destinationURL = libraryDirectory.appendingPathComponent(filename)
        
        // Copy the file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    /// Imports multiple DICOM files
    /// - Parameter urls: URLs of files to import
    /// - Returns: Array of (originalURL, importedURL) tuples
    func importFiles(from urls: [URL]) async throws -> [(URL, URL)] {
        var results: [(URL, URL)] = []
        
        for url in urls {
            let importedURL = try importFile(from: url)
            results.append((url, importedURL))
        }
        
        return results
    }
    
    // MARK: - Storage Management
    
    /// Gets the total size of the DICOM library
    func librarySize() throws -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: libraryDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        return totalSize
    }
    
    /// Deletes a file from the library
    func deleteFile(at path: String) throws {
        try fileManager.removeItem(atPath: path)
    }
    
    /// Deletes all files in the library
    func clearLibrary() throws {
        let contents = try fileManager.contentsOfDirectory(at: libraryDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}

/// Extracted DICOM metadata structure
struct DICOMMetadata: Sendable {
    // Patient
    let patientName: String
    let patientID: String
    let patientSex: String?
    let patientBirthDate: Date?
    
    // Study
    let studyInstanceUID: String
    let studyDate: Date?
    let studyDescription: String?
    let accessionNumber: String?
    
    // Series
    let seriesInstanceUID: String
    let seriesNumber: Int?
    let seriesDescription: String?
    let modality: String
    
    // Instance
    let sopInstanceUID: String
    let sopClassUID: String
    let instanceNumber: Int?
    let numberOfFrames: Int
    
    // Image
    let rows: Int
    let columns: Int
    let bitsAllocated: Int
    let bitsStored: Int
    let photometricInterpretation: String
    let windowCenter: Double?
    let windowWidth: Double?
    let pixelSpacing: [Double]?
    let transferSyntaxUID: String?
    
    // File
    let filePath: String
    let fileSize: Int64
    
    /// Creates a copy of this metadata with an updated file path
    /// - Parameter path: The new file path
    /// - Returns: A new DICOMMetadata instance with the updated path
    func withFilePath(_ path: String) -> DICOMMetadata {
        DICOMMetadata(
            patientName: patientName,
            patientID: patientID,
            patientSex: patientSex,
            patientBirthDate: patientBirthDate,
            studyInstanceUID: studyInstanceUID,
            studyDate: studyDate,
            studyDescription: studyDescription,
            accessionNumber: accessionNumber,
            seriesInstanceUID: seriesInstanceUID,
            seriesNumber: seriesNumber,
            seriesDescription: seriesDescription,
            modality: modality,
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            instanceNumber: instanceNumber,
            numberOfFrames: numberOfFrames,
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            photometricInterpretation: photometricInterpretation,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            pixelSpacing: pixelSpacing,
            transferSyntaxUID: transferSyntaxUID,
            filePath: path,
            fileSize: fileSize
        )
    }
}
