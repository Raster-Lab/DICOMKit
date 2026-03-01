// ImportService.swift
// DICOMStudio
//
// DICOM Studio — DICOM file import service

import Foundation
import DICOMKit
import DICOMCore

/// Service for importing DICOM files into the local library.
///
/// Handles file validation, metadata extraction, duplicate detection,
/// and batch import with progress tracking.
public final class ImportService: Sendable {

    /// The file service used for parsing DICOM files.
    public let fileService: DICOMFileService

    /// Creates an import service with the given file service.
    ///
    /// - Parameter fileService: The DICOM file parsing service.
    public init(fileService: DICOMFileService = DICOMFileService()) {
        self.fileService = fileService
    }

    /// Imports a single DICOM file, performing validation and metadata extraction.
    ///
    /// - Parameters:
    ///   - url: The file URL to import.
    ///   - existingInstanceUIDs: Set of already-imported SOP Instance UIDs for duplicate detection.
    /// - Returns: The import result with parsed metadata and any validation issues.
    public func importFile(
        at url: URL,
        existingInstanceUIDs: Set<String> = []
    ) -> ImportResult {
        // Read raw data for validation
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return ImportResult(
                sourceURL: url,
                validationIssues: [ValidationIssue(
                    severity: .error,
                    message: "Cannot read file: \(error.localizedDescription)",
                    rule: .fileSize
                )]
            )
        }

        // Run structural validation
        var allIssues = ImportValidation.validate(data: data)

        // If structural validation found errors, don't try to parse
        if ImportValidation.shouldReject(allIssues) {
            return ImportResult(sourceURL: url, validationIssues: allIssues)
        }

        // Try to parse the DICOM file
        let instance: InstanceModel
        let study: StudyModel
        let series: SeriesModel
        do {
            instance = try fileService.parseFile(at: url)
            study = try fileService.extractStudyMetadata(from: url)
            series = try fileService.extractSeriesMetadata(from: url)
        } catch {
            allIssues.append(ValidationIssue(
                severity: .error,
                message: "DICOM parse error: \(error.localizedDescription)",
                rule: .fileMetaInformation
            ))
            return ImportResult(sourceURL: url, validationIssues: allIssues)
        }

        // Validate required tags
        let tagIssues = ImportValidation.validateRequiredTags(
            hasStudyInstanceUID: !study.studyInstanceUID.isEmpty,
            hasSOPInstanceUID: !instance.sopInstanceUID.isEmpty,
            hasSOPClassUID: !instance.sopClassUID.isEmpty
        )
        allIssues.append(contentsOf: tagIssues)

        // Validate transfer syntax
        let tsIssues = ImportValidation.validateTransferSyntax(instance.transferSyntaxUID)
        allIssues.append(contentsOf: tsIssues)

        // Check for duplicates
        let isDuplicate = existingInstanceUIDs.contains(instance.sopInstanceUID)
        if isDuplicate {
            allIssues.append(ValidationIssue(
                severity: .warning,
                message: "Duplicate SOP Instance UID: \(instance.sopInstanceUID)",
                rule: .duplicateDetection
            ))
        }

        return ImportResult(
            sourceURL: url,
            instance: instance,
            study: study,
            series: series,
            validationIssues: allIssues,
            isDuplicate: isDuplicate
        )
    }

    /// Imports multiple DICOM files, collecting results for each.
    ///
    /// - Parameters:
    ///   - urls: The file URLs to import.
    ///   - existingInstanceUIDs: Set of already-imported SOP Instance UIDs for duplicate detection.
    ///   - progressHandler: Optional callback invoked after each file is processed.
    /// - Returns: Array of import results, one per file.
    public func importFiles(
        at urls: [URL],
        existingInstanceUIDs: Set<String> = [],
        progressHandler: ((ImportProgress) -> Void)? = nil
    ) -> [ImportResult] {
        var results: [ImportResult] = []
        var knownUIDs = existingInstanceUIDs
        var succeeded = 0
        var failed = 0
        var duplicates = 0

        for (index, url) in urls.enumerated() {
            let result = importFile(at: url, existingInstanceUIDs: knownUIDs)
            results.append(result)

            if result.succeeded {
                if result.isDuplicate {
                    duplicates += 1
                } else {
                    succeeded += 1
                    if let uid = result.instance?.sopInstanceUID {
                        knownUIDs.insert(uid)
                    }
                }
            } else {
                failed += 1
            }

            progressHandler?(ImportProgress(
                totalFiles: urls.count,
                processedFiles: index + 1,
                succeededFiles: succeeded,
                failedFiles: failed,
                duplicateFiles: duplicates
            ))
        }

        return results
    }

    /// Scans a directory for DICOM files (non-recursive by default).
    ///
    /// - Parameters:
    ///   - directoryURL: The directory to scan.
    ///   - recursive: Whether to scan subdirectories.
    /// - Returns: Array of file URLs that may be DICOM files.
    public func scanDirectory(
        at directoryURL: URL,
        recursive: Bool = false
    ) -> [URL] {
        let fm = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if !recursive {
            options.insert(.skipsSubdirectoryDescendants)
        }

        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: options
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                let ext = url.pathExtension.lowercased()
                // Include files with .dcm extension, no extension, or common DICOM extensions
                if ext == "dcm" || ext == "dicom" || ext == "dic" || ext.isEmpty {
                    urls.append(url)
                }
            }
        }
        return urls
    }
}
