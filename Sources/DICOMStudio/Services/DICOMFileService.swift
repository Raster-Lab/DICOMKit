// DICOMFileService.swift
// DICOMStudio
//
// DICOM Studio — File I/O operations via DICOMKit

import Foundation
import DICOMKit
import DICOMCore

/// Provides DICOM file I/O operations using DICOMKit.
///
/// This service wraps DICOMKit's parsing and file operations, converting
/// raw DICOM data into the application's model types.
public final class DICOMFileService: Sendable {

    public init() {}

    /// Parses a DICOM file and returns an InstanceModel with extracted metadata.
    ///
    /// - Parameter url: File URL to the DICOM file.
    /// - Returns: A populated InstanceModel.
    /// - Throws: If the file cannot be read or parsed.
    public func parseFile(at url: URL) throws -> InstanceModel {
        let data = try Data(contentsOf: url)
        let dicomFile = try DICOMFile.read(from: data)
        let dataSet = dicomFile.dataSet

        let sopInstanceUID = dataSet.string(for: .sopInstanceUID) ?? UUID().uuidString
        let sopClassUID = dataSet.string(for: .sopClassUID) ?? ""
        let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) ?? ""
        let instanceNumber = dataSet.int32(for: .instanceNumber).map { Int($0) }
        let transferSyntaxUID = dataSet.string(for: .transferSyntaxUID)
        let rows = dataSet.uint16(for: .rows).map { Int($0) }
        let columns = dataSet.uint16(for: .columns).map { Int($0) }
        let bitsAllocated = dataSet.uint16(for: .bitsAllocated).map { Int($0) }
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation)
        let numberOfFramesString = dataSet.string(for: .numberOfFrames)
        let numberOfFrames = numberOfFramesString.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        return InstanceModel(
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
    }

    /// Extracts study-level metadata from a DICOM file's data set.
    ///
    /// - Parameter url: File URL to the DICOM file.
    /// - Returns: A StudyModel with extracted metadata.
    /// - Throws: If the file cannot be read or parsed.
    public func extractStudyMetadata(from url: URL) throws -> StudyModel {
        let data = try Data(contentsOf: url)
        let dicomFile = try DICOMFile.read(from: data)
        let dataSet = dicomFile.dataSet

        let studyInstanceUID = dataSet.string(for: .studyInstanceUID) ?? UUID().uuidString
        let studyID = dataSet.string(for: .studyID) ?? ""
        let studyDescription = dataSet.string(for: .studyDescription)
        let accessionNumber = dataSet.string(for: .accessionNumber)
        let referringPhysicianName = dataSet.string(for: .referringPhysicianName)
        let patientName = dataSet.string(for: .patientName)
        let patientID = dataSet.string(for: .patientID)
        let patientSex = dataSet.string(for: .patientSex)
        let institutionName = dataSet.string(for: .institutionName)
        let modality = dataSet.string(for: .modality)

        var modalitiesInStudy: Set<String> = []
        if let mod = modality {
            modalitiesInStudy.insert(mod)
        }

        return StudyModel(
            studyInstanceUID: studyInstanceUID,
            studyID: studyID,
            studyDescription: studyDescription,
            accessionNumber: accessionNumber,
            referringPhysicianName: referringPhysicianName,
            patientName: patientName,
            patientID: patientID,
            patientSex: patientSex,
            institutionName: institutionName,
            modalitiesInStudy: modalitiesInStudy
        )
    }

    /// Extracts series-level metadata from a DICOM file's data set.
    ///
    /// - Parameter url: File URL to the DICOM file.
    /// - Returns: A SeriesModel with extracted metadata.
    /// - Throws: If the file cannot be read or parsed.
    public func extractSeriesMetadata(from url: URL) throws -> SeriesModel {
        let data = try Data(contentsOf: url)
        let dicomFile = try DICOMFile.read(from: data)
        let dataSet = dicomFile.dataSet

        let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) ?? UUID().uuidString
        let studyInstanceUID = dataSet.string(for: .studyInstanceUID) ?? ""
        let seriesNumber = dataSet.int32(for: .seriesNumber).map { Int($0) }
        let modality = dataSet.string(for: .modality) ?? "OT"
        let seriesDescription = dataSet.string(for: .seriesDescription)
        let bodyPartExamined = dataSet.string(for: .bodyPartExamined)
        let transferSyntaxUID = dataSet.string(for: .transferSyntaxUID)

        return SeriesModel(
            seriesInstanceUID: seriesInstanceUID,
            studyInstanceUID: studyInstanceUID,
            seriesNumber: seriesNumber,
            modality: modality,
            seriesDescription: seriesDescription,
            bodyPartExamined: bodyPartExamined,
            transferSyntaxUID: transferSyntaxUID
        )
    }
}
