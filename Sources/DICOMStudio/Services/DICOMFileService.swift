// DICOMFileService.swift
// DICOMStudio
//
// DICOM Studio — File I/O operations via DICOMKit

import Foundation
import DICOMKit
import DICOMCore
import os.log

/// Logger for DICOM file service diagnostics.
private let logger = Logger(subsystem: "com.dicomstudio", category: "DICOMFileService")

/// Result of a single DICOM parse, containing all three model levels.
///
/// Produced by ``DICOMFileService/parseAllMetadata(data:url:)``
/// so the caller can extract instance, study, and series data from
/// a single ``DICOMFile`` parse.
public struct DICOMParseResult: Sendable {
    public let instance: InstanceModel
    public let study: StudyModel
    public let series: SeriesModel
}

/// Provides DICOM file I/O operations using DICOMKit.
///
/// This service wraps DICOMKit's parsing and file operations, converting
/// raw DICOM data into the application's model types.
public final class DICOMFileService: Sendable {

    public init() {}

    // MARK: - Combined Parse (preferred)

    /// Parses raw DICOM data **once** and returns instance, study, and
    /// series models in a single pass.
    ///
    /// This is the preferred entry point — it avoids re-parsing the same
    /// bytes three times and correctly reads Transfer Syntax UID from
    /// File Meta Information.
    ///
    /// - Parameters:
    ///   - data: Raw file data.
    ///   - url:  Original file URL (used for file size and path).
    /// - Returns: A ``DICOMParseResult`` with all three models.
    /// - Throws: If the data cannot be parsed as DICOM.
    public func parseAllMetadata(data: Data, url: URL) throws -> DICOMParseResult {
        logger.debug("Parsing DICOM data (\(data.count) bytes) from \(url.lastPathComponent)")

        // Try standard Part 10 first, then fall back to force-parsing
        // for legacy DICOM files without the Part 10 preamble.
        let dicomFile: DICOMFile
        var usedForceFallback = false
        do {
            dicomFile = try DICOMFile.read(from: data)
        } catch {
            logger.info("Standard parse failed (\(error.localizedDescription)), retrying with force=true")
            dicomFile = try DICOMFile.read(from: data, force: true)
            usedForceFallback = true
        }
        let ds  = dicomFile.dataSet
        let fmi = dicomFile.fileMetaInformation

        // The legacy/force path uses a lenient "looks like DICOM" heuristic that
        // accepts any data whose first two bytes form an even uint16 < 0x7FFF —
        // which matches a lot of plain ASCII text. Reject force-parsed results
        // that carry none of the identifying UIDs every real instance has.
        if usedForceFallback {
            let hasIdentifyingTag = ds.string(for: .sopInstanceUID) != nil
                || ds.string(for: .sopClassUID) != nil
                || ds.string(for: .studyInstanceUID) != nil
                || ds.string(for: .seriesInstanceUID) != nil
            if !hasIdentifyingTag {
                throw DICOMError.parsingFailed("Force-parsed data lacks any DICOM identifying UID")
            }
        }

        // --- Transfer Syntax UID lives in File Meta Information (0002,0010) ---
        let transferSyntaxUID = fmi.string(for: .transferSyntaxUID)
            ?? ds.string(for: .transferSyntaxUID)

        // --- Instance ---
        let sopInstanceUID = ds.string(for: .sopInstanceUID) ?? UUID().uuidString
        let sopClassUID = ds.string(for: .sopClassUID)
            ?? fmi.string(for: .mediaStorageSOPClassUID)
            ?? ""
        let seriesInstanceUID = ds.string(for: .seriesInstanceUID) ?? ""
        let instanceNumber = ds.int32(for: .instanceNumber).map { Int($0) }
        let rows = ds.uint16(for: .rows).map { Int($0) }
        let columns = ds.uint16(for: .columns).map { Int($0) }
        let bitsAllocated = ds.uint16(for: .bitsAllocated).map { Int($0) }
        let photometricInterpretation = ds.string(for: .photometricInterpretation)
        let numberOfFrames = ds.string(for: .numberOfFrames)
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let fileSize = Int64(data.count)

        let instance = InstanceModel(
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            filePath: url.path,
            fileSize: fileSize,
            transferSyntaxUID: transferSyntaxUID,
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            numberOfFrames: numberOfFrames,
            photometricInterpretation: photometricInterpretation
        )

        // --- Study ---
        let studyInstanceUID = ds.string(for: .studyInstanceUID) ?? UUID().uuidString
        let modality = ds.string(for: .modality)
        var modalitiesInStudy: Set<String> = []
        if let mod = modality { modalitiesInStudy.insert(mod) }

        let studyDate: Date? = {
            guard let raw = ds.string(for: .studyDate)?
                    .trimmingCharacters(in: .whitespaces),
                  !raw.isEmpty else { return nil }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            for pattern in ["yyyyMMdd", "yyyy.MM.dd"] {
                fmt.dateFormat = pattern
                if let d = fmt.date(from: raw) { return d }
            }
            return nil
        }()

        let study = StudyModel(
            studyInstanceUID: studyInstanceUID,
            studyID: ds.string(for: .studyID) ?? "",
            studyDate: studyDate,
            studyDescription: ds.string(for: .studyDescription),
            accessionNumber: ds.string(for: .accessionNumber),
            referringPhysicianName: ds.string(for: .referringPhysicianName),
            patientName: ds.string(for: .patientName),
            patientID: ds.string(for: .patientID),
            patientSex: ds.string(for: .patientSex),
            institutionName: ds.string(for: .institutionName),
            modalitiesInStudy: modalitiesInStudy
        )

        // --- Series ---
        let series = SeriesModel(
            seriesInstanceUID: seriesInstanceUID,
            studyInstanceUID: studyInstanceUID,
            seriesNumber: ds.int32(for: .seriesNumber).map { Int($0) },
            modality: modality ?? "OT",
            seriesDescription: ds.string(for: .seriesDescription),
            bodyPartExamined: ds.string(for: .bodyPartExamined),
            transferSyntaxUID: transferSyntaxUID
        )

        logger.debug("Parsed OK — SOP UID=\(sopInstanceUID), Study UID=\(studyInstanceUID), Series UID=\(seriesInstanceUID)")
        return DICOMParseResult(instance: instance, study: study, series: series)
    }

    // MARK: - Legacy convenience (kept for tests / callers that need a single model)

    /// Parses a DICOM file and returns an InstanceModel with extracted metadata.
    public func parseFile(at url: URL) throws -> InstanceModel {
        let data = try Data(contentsOf: url)
        return try parseAllMetadata(data: data, url: url).instance
    }

    /// Parses already-loaded DICOM data and returns an InstanceModel.
    public func parseFileData(_ data: Data, at url: URL) throws -> InstanceModel {
        try parseAllMetadata(data: data, url: url).instance
    }

    /// Extracts study-level metadata from a DICOM file's data set.
    public func extractStudyMetadata(from url: URL) throws -> StudyModel {
        let data = try Data(contentsOf: url)
        return try parseAllMetadata(data: data, url: url).study
    }

    /// Extracts study-level metadata from already-loaded DICOM data.
    public func extractStudyMetadataFromData(_ data: Data) throws -> StudyModel {
        try parseAllMetadata(data: data, url: URL(fileURLWithPath: "/unknown")).study
    }

    /// Extracts series-level metadata from a DICOM file's data set.
    public func extractSeriesMetadata(from url: URL) throws -> SeriesModel {
        let data = try Data(contentsOf: url)
        return try parseAllMetadata(data: data, url: url).series
    }

    /// Extracts series-level metadata from already-loaded DICOM data.
    public func extractSeriesMetadataFromData(_ data: Data) throws -> SeriesModel {
        try parseAllMetadata(data: data, url: URL(fileURLWithPath: "/unknown")).series
    }
}
