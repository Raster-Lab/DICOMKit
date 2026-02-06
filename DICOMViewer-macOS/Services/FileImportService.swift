//
//  FileImportService.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import DICOMKit
import DICOMCore

/// Service for importing DICOM files into the local database
@MainActor
final class FileImportService {
    /// Shared singleton instance
    static let shared = FileImportService()
    
    private let databaseService = DatabaseService.shared
    private let fileManager = FileManager.default
    
    /// Application support directory for storing DICOM files
    private lazy var storageDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dicomDir = appSupport.appendingPathComponent("DICOMViewer/Studies", isDirectory: true)
        
        try? fileManager.createDirectory(at: dicomDir, withIntermediateDirectories: true)
        
        return dicomDir
    }()
    
    private init() {}
    
    // MARK: - Import Operations
    
    /// Import result for tracking progress and errors
    struct ImportResult {
        let successCount: Int
        let failureCount: Int
        let errors: [Error]
        let importedStudies: Set<String> // Study Instance UIDs
    }
    
    /// Import a single DICOM file
    func importFile(at url: URL) async throws -> String {
        // Read DICOM file
        let fileData = try Data(contentsOf: url)
        let dataset = try DICOMFile.read(from: fileData)
        
        // Extract metadata
        let studyUID = try extractStudyUID(from: dataset)
        let seriesUID = try extractSeriesUID(from: dataset)
        let instanceUID = try extractInstanceUID(from: dataset)
        
        // Copy file to storage
        let destinationPath = try copyFileToStorage(from: url, studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
        
        // Create or update database records
        try await createOrUpdateDatabaseRecords(
            dataset: dataset,
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            filePath: destinationPath,
            fileSize: Int64(fileData.count)
        )
        
        return studyUID
    }
    
    /// Import multiple files with progress reporting
    func importFiles(at urls: [URL], progress: @escaping (Int, Int) -> Void) async -> ImportResult {
        var successCount = 0
        var failureCount = 0
        var errors: [Error] = []
        var importedStudies = Set<String>()
        
        for (index, url) in urls.enumerated() {
            do {
                let studyUID = try await importFile(at: url)
                importedStudies.insert(studyUID)
                successCount += 1
            } catch {
                errors.append(error)
                failureCount += 1
            }
            
            progress(index + 1, urls.count)
        }
        
        // Rebuild statistics after import
        try? databaseService.rebuildStatistics()
        
        return ImportResult(
            successCount: successCount,
            failureCount: failureCount,
            errors: errors,
            importedStudies: importedStudies
        )
    }
    
    /// Import all DICOM files from a directory (recursive)
    func importDirectory(at url: URL, progress: @escaping (Int, Int) -> Void) async -> ImportResult {
        let files = findDICOMFiles(in: url)
        return await importFiles(at: files, progress: progress)
    }
    
    // MARK: - Helper Methods
    
    private func extractStudyUID(from dataset: DataSet) throws -> String {
        guard let uid = dataset.string(for: .studyInstanceUID), !uid.isEmpty else {
            throw ImportError.missingRequiredTag("Study Instance UID")
        }
        return uid
    }
    
    private func extractSeriesUID(from dataset: DataSet) throws -> String {
        guard let uid = dataset.string(for: .seriesInstanceUID), !uid.isEmpty else {
            throw ImportError.missingRequiredTag("Series Instance UID")
        }
        return uid
    }
    
    private func extractInstanceUID(from dataset: DataSet) throws -> String {
        guard let uid = dataset.string(for: .sopInstanceUID), !uid.isEmpty else {
            throw ImportError.missingRequiredTag("SOP Instance UID")
        }
        return uid
    }
    
    private func copyFileToStorage(from sourceURL: URL, studyUID: String, seriesUID: String, instanceUID: String) throws -> String {
        // Create directory structure: Studies/{StudyUID}/{SeriesUID}/
        let studyDir = storageDirectory.appendingPathComponent(studyUID, isDirectory: true)
        let seriesDir = studyDir.appendingPathComponent(seriesUID, isDirectory: true)
        
        try fileManager.createDirectory(at: seriesDir, withIntermediateDirectories: true)
        
        // Destination file: {InstanceUID}.dcm
        let destinationURL = seriesDir.appendingPathComponent("\(instanceUID).dcm")
        
        // Copy file (replace if exists)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL.path
    }
    
    private func createOrUpdateDatabaseRecords(
        dataset: DataSet,
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        filePath: String,
        fileSize: Int64
    ) async throws {
        // Get or create study
        let study: DicomStudy
        if let existing = try databaseService.fetchStudy(uid: studyUID) {
            study = existing
        } else {
            study = try createStudy(from: dataset, uid: studyUID)
            try databaseService.saveStudy(study)
        }
        
        // Get or create series
        let series: DicomSeries
        if let existing = try databaseService.fetchSeries(uid: seriesUID) {
            series = existing
        } else {
            series = try createSeries(from: dataset, uid: seriesUID)
            series.study = study
            study.series.append(series)
        }
        
        // Create instance (or update if exists)
        if let existing = try databaseService.fetchInstance(uid: instanceUID) {
            updateInstance(existing, from: dataset, filePath: filePath, fileSize: fileSize)
        } else {
            let instance = try createInstance(from: dataset, uid: instanceUID, filePath: filePath, fileSize: fileSize)
            instance.series = series
            series.instances.append(instance)
        }
        
        try databaseService.modelContext.save()
    }
    
    private func createStudy(from dataset: DataSet, uid: String) throws -> DicomStudy {
        let patientName = dataset.string(for: .patientName) ?? "Unknown"
        let patientID = dataset.string(for: .patientID) ?? ""
        let studyDescription = dataset.string(for: .studyDescription)
        let accessionNumber = dataset.string(for: .accessionNumber)
        let referringPhysician = dataset.string(for: .referringPhysicianName)
        let institutionName = dataset.string(for: .institutionName)
        
        // Parse dates
        let studyDate = parseDate(dataset.string(for: .studyDate))
        let patientBirthDate = parseDate(dataset.string(for: .patientBirthDate))
        
        let patientSex = dataset.string(for: .patientSex)
        
        return DicomStudy(
            studyInstanceUID: uid,
            patientName: patientName,
            patientID: patientID,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            studyDescription: studyDescription,
            studyDate: studyDate,
            accessionNumber: accessionNumber,
            referringPhysician: referringPhysician,
            institutionName: institutionName
        )
    }
    
    private func createSeries(from dataset: DataSet, uid: String) throws -> DicomSeries {
        let seriesNumber = dataset.int(for: .seriesNumber)
        let seriesDescription = dataset.string(for: .seriesDescription)
        let modality = dataset.string(for: .modality) ?? "OT"
        let bodyPartExamined = dataset.string(for: .bodyPartExamined)
        let protocolName = dataset.string(for: .protocolName)
        let seriesDate = parseDate(dataset.string(for: .seriesDate))
        
        return DicomSeries(
            seriesInstanceUID: uid,
            seriesNumber: seriesNumber,
            seriesDescription: seriesDescription,
            modality: modality,
            seriesDate: seriesDate,
            bodyPartExamined: bodyPartExamined,
            protocolName: protocolName
        )
    }
    
    private func createInstance(from dataset: DataSet, uid: String, filePath: String, fileSize: Int64) throws -> DicomInstance {
        let sopClassUID = dataset.string(for: .sopClassUID) ?? ""
        let instanceNumber = dataset.int(for: .instanceNumber)
        let rows = dataset.int(for: .rows)
        let columns = dataset.int(for: .columns)
        let numberOfFrames = dataset.int(for: .numberOfFrames) ?? 1
        let transferSyntaxUID = dataset.string(for: Tag(group: 0x0002, element: 0x0010))
        let sliceLocation = dataset.double(for: .sliceLocation)
        
        let instance = DicomInstance(
            sopInstanceUID: uid,
            sopClassUID: sopClassUID,
            instanceNumber: instanceNumber,
            filePath: filePath,
            fileSize: fileSize,
            rows: rows,
            columns: columns,
            numberOfFrames: numberOfFrames > 1 ? numberOfFrames : nil,
            transferSyntaxUID: transferSyntaxUID,
            sliceLocation: sliceLocation
        )
        
        // Extract image position and orientation
        if let position = dataset.doubles(for: .imagePositionPatient), position.count >= 3 {
            instance.imagePositionX = position[0]
            instance.imagePositionY = position[1]
            instance.imagePositionZ = position[2]
        }
        
        if let orientation = dataset.doubles(for: .imageOrientationPatient), orientation.count >= 6 {
            instance.orientationRow1 = orientation[0]
            instance.orientationRow2 = orientation[1]
            instance.orientationRow3 = orientation[2]
            instance.orientationCol1 = orientation[3]
            instance.orientationCol2 = orientation[4]
            instance.orientationCol3 = orientation[5]
        }
        
        return instance
    }
    
    private func updateInstance(_ instance: DicomInstance, from dataset: DataSet, filePath: String, fileSize: Int64) {
        instance.filePath = filePath
        instance.fileSize = fileSize
        // Update other metadata as needed
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        
        // DICOM date format: YYYYMMDD
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }
    
    private func findDICOMFiles(in directory: URL) -> [URL] {
        var files: [URL] = []
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            // Check if file might be DICOM (by extension or attempting to read)
            if isDICOMFile(fileURL) {
                files.append(fileURL)
            }
        }
        
        return files
    }
    
    private func isDICOMFile(_ url: URL) -> Bool {
        // Check extension
        let ext = url.pathExtension.lowercased()
        if ext == "dcm" || ext == "dicom" || ext == "dic" {
            return true
        }
        
        // Try to read DICOM preamble
        guard let handle = try? FileHandle(forReadingFrom: url),
              let preamble = try? handle.read(upToCount: 132) else {
            return false
        }
        
        // Check for DICM magic number at byte 128
        if preamble.count >= 132 {
            let dicm = preamble.subdata(in: 128..<132)
            if dicm == Data([0x44, 0x49, 0x43, 0x4D]) { // "DICM"
                return true
            }
        }
        
        return false
    }
}

// MARK: - Errors

enum ImportError: LocalizedError {
    case missingRequiredTag(String)
    case invalidDICOMFile
    case fileAccessError
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredTag(let tag):
            return "Missing required DICOM tag: \(tag)"
        case .invalidDICOMFile:
            return "Not a valid DICOM file"
        case .fileAccessError:
            return "Unable to access file"
        }
    }
}
