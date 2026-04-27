// TagEditor.swift
// DICOMCLITools
//
// Shared tag-editing logic for `dicom-tags`. Used by both the CLI executable
// and the DICOMStudio GUI's CLI Workshop. The function returns log messages
// (instead of printing them directly) so callers can route them to stderr,
// stdout, or a GUI console as appropriate.

import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Errors for tag editing operations.
public enum TagEditorError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidTagFormat(String)
    case invalidSetFormat(String)
    case unknownTagName(String)
    case noOperationsSpecified
    case writeError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidTagFormat(let spec):
            return "Invalid tag format: \(spec). Use TagName or GGGG,EEEE"
        case .invalidSetFormat(let spec):
            return "Invalid set format: \(spec). Use TagName=Value or GGGG,EEEE=Value"
        case .unknownTagName(let name):
            return "Unknown tag name: \(name)"
        case .noOperationsSpecified:
            return "No operations specified. Use --set, --delete, --delete-private, or --copy-from"
        case .writeError(let msg):
            return "Write error: \(msg)"
        }
    }
}

/// Core tag editing logic shared between the `dicom-tags` CLI and DICOMStudio.
public struct TagEditor: Sendable {

    public init() {}

    /// Canonical tag name entries.
    private static let tagEntries: [(String, Tag)] = [
        ("PatientName", .patientName),
        ("PatientID", .patientID),
        ("PatientBirthDate", .patientBirthDate),
        ("PatientBirthTime", .patientBirthTime),
        ("PatientSex", .patientSex),
        ("PatientAge", .patientAge),
        ("PatientComments", .patientComments),
        ("OtherPatientIDs", .otherPatientIDs),
        ("OtherPatientNames", .otherPatientNames),
        ("StudyDate", .studyDate),
        ("StudyTime", .studyTime),
        ("StudyDescription", .studyDescription),
        ("StudyInstanceUID", .studyInstanceUID),
        ("AccessionNumber", .accessionNumber),
        ("ReferringPhysicianName", .referringPhysicianName),
        ("SeriesDate", .seriesDate),
        ("SeriesTime", .seriesTime),
        ("SeriesDescription", .seriesDescription),
        ("SeriesInstanceUID", .seriesInstanceUID),
        ("Modality", .modality),
        ("InstitutionName", .institutionName),
        ("InstitutionAddress", .institutionAddress),
        ("StationName", .stationName),
        ("PerformingPhysicianName", .performingPhysicianName),
        ("OperatorName", .operatorName),
        ("DeviceSerialNumber", .deviceSerialNumber),
        ("SOPInstanceUID", .sopInstanceUID),
        ("AcquisitionDate", .acquisitionDate),
        ("AcquisitionTime", .acquisitionTime),
        ("ContentDate", .contentDate),
        ("ContentTime", .contentTime),
    ]

    private static let tagNameMap: [String: Tag] = {
        var map: [String: Tag] = [:]
        for (name, tag) in tagEntries {
            map[name.lowercased()] = tag
        }
        return map
    }()

    private static let tagDisplayName: [Tag: String] = {
        var map: [Tag: String] = [:]
        for (name, tag) in tagEntries {
            map[tag] = name
        }
        return map
    }()

    private static let tagVRMap: [Tag: VR] = [
        .patientName: .PN,
        .patientID: .LO,
        .patientBirthDate: .DA,
        .patientBirthTime: .TM,
        .patientSex: .CS,
        .patientAge: .AS,
        .patientComments: .LT,
        .otherPatientIDs: .LO,
        .otherPatientNames: .PN,
        .studyDate: .DA,
        .studyTime: .TM,
        .studyDescription: .LO,
        .studyInstanceUID: .UI,
        .accessionNumber: .SH,
        .referringPhysicianName: .PN,
        .seriesDate: .DA,
        .seriesTime: .TM,
        .seriesDescription: .LO,
        .seriesInstanceUID: .UI,
        .modality: .CS,
        .institutionName: .LO,
        .institutionAddress: .ST,
        .stationName: .SH,
        .performingPhysicianName: .PN,
        .operatorName: .PN,
        .deviceSerialNumber: .LO,
        .sopInstanceUID: .UI,
        .acquisitionDate: .DA,
        .acquisitionTime: .TM,
        .contentDate: .DA,
        .contentTime: .TM,
    ]

    // MARK: - Public API

    /// Process a DICOM file with the specified tag operations.
    ///
    /// Returns log lines describing each change, plus a trailing
    /// "N change(s) applied." line when verbose or dry-run is requested.
    /// Callers (CLI or GUI) decide where to display them.
    @discardableResult
    public func processFile(
        inputPath: String,
        outputPath: String?,
        sets: [String],
        deletes: [String],
        deletePrivate: Bool,
        copyFromPath: String?,
        copyTags: [String]?,
        verbose: Bool,
        dryRun: Bool
    ) throws -> [String] {
        let inputURL = URL(fileURLWithPath: inputPath)
        let fileData = try Data(contentsOf: inputURL)
        let dicomFile = try DICOMFile.read(from: fileData)
        var dataSet = dicomFile.dataSet

        var sourceDataSet: DataSet?
        if let copyFromPath = copyFromPath {
            let sourceURL = URL(fileURLWithPath: copyFromPath)
            let sourceData = try Data(contentsOf: sourceURL)
            let sourceFile = try DICOMFile.read(from: sourceData)
            sourceDataSet = sourceFile.dataSet
        }

        let changes = try applyChanges(
            to: &dataSet,
            sets: sets,
            deletes: deletes,
            deletePrivate: deletePrivate,
            sourceDataSet: sourceDataSet,
            copyTags: copyTags,
            verbose: verbose,
            dryRun: dryRun
        )

        var logLines: [String] = []
        if verbose || dryRun {
            logLines.append(contentsOf: changes)
            logLines.append("\(changes.count) change(s) applied.")
        }

        if !dryRun {
            let modifiedFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: dataSet)
            let outputData = try modifiedFile.write()
            // If `outputPath` points at an existing directory, write the
            // modified file inside that directory using the input's filename
            // instead of trying to overwrite the directory itself (which
            // produces the cryptic "couldn't be saved in the folder …"
            // error). When `outputPath` is nil, overwrite the input.
            let destPath: String
            if let outputPath = outputPath {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDir),
                   isDir.boolValue {
                    destPath = (outputPath as NSString)
                        .appendingPathComponent(inputURL.lastPathComponent)
                } else {
                    destPath = outputPath
                }
            } else {
                destPath = inputPath
            }
            let destURL = URL(fileURLWithPath: destPath)
            try outputData.write(to: destURL)
        }

        return logLines
    }

    // MARK: - Tag Parsing

    public func parseTagSpecifier(_ spec: String) throws -> Tag {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        if trimmed.contains(",") {
            let parts = trimmed.split(separator: ",")
            if parts.count == 2,
               let group = UInt16(parts[0].trimmingCharacters(in: .whitespaces), radix: 16),
               let element = UInt16(parts[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                return Tag(group: group, element: element)
            }
        }

        if trimmed.count == 8, trimmed.allSatisfy({ $0.isHexDigit }),
           let value = UInt32(trimmed, radix: 16) {
            let group = UInt16((value >> 16) & 0xFFFF)
            let element = UInt16(value & 0xFFFF)
            return Tag(group: group, element: element)
        }

        return try resolveTagByName(spec.trimmingCharacters(in: .whitespaces))
    }

    public func parseTagValue(_ setSpec: String) throws -> (Tag, String) {
        let parts: (String, String)

        if let eqRange = setSpec.range(of: "=") {
            let tagPart = String(setSpec[setSpec.startIndex..<eqRange.lowerBound])
            let valuePart = String(setSpec[eqRange.upperBound...])
            parts = (tagPart, valuePart)
        } else {
            throw TagEditorError.invalidSetFormat(setSpec)
        }

        let tag = try parseTagSpecifier(parts.0)
        return (tag, parts.1)
    }

    public func resolveTagByName(_ name: String) throws -> Tag {
        let key = name.lowercased()
        guard let tag = Self.tagNameMap[key] else {
            throw TagEditorError.unknownTagName(name)
        }
        return tag
    }

    // MARK: - Apply Changes

    public func applyChanges(
        to dataSet: inout DataSet,
        sets: [String],
        deletes: [String],
        deletePrivate: Bool,
        sourceDataSet: DataSet?,
        copyTags: [String]?,
        verbose: Bool,
        dryRun: Bool
    ) throws -> [String] {
        var descriptions: [String] = []

        // 1. Delete specified tags
        for deleteSpec in deletes {
            let tag = try parseTagSpecifier(deleteSpec)
            let label = tagLabel(tag)
            if dataSet[tag] != nil {
                if !dryRun {
                    dataSet.remove(tag: tag)
                }
                descriptions.append("DELETE \(label)")
            } else {
                descriptions.append("DELETE \(label) (not present, skipped)")
            }
        }

        // 2. Delete private tags
        if deletePrivate {
            var removed = 0
            let allTags = dataSet.tags
            for tag in allTags {
                if tag.isPrivate {
                    if !dryRun {
                        dataSet.remove(tag: tag)
                    }
                    removed += 1
                    if verbose {
                        descriptions.append("DELETE private tag \(tagLabel(tag))")
                    }
                }
            }
            if !verbose {
                descriptions.append("DELETE \(removed) private tag(s)")
            }
        }

        // 3. Copy tags from source
        if let sourceDataSet = sourceDataSet {
            let tagsToCopy: [Tag]
            if let copyTags = copyTags {
                tagsToCopy = try copyTags.map { try parseTagSpecifier($0) }
            } else {
                tagsToCopy = sourceDataSet.tags
            }

            for tag in tagsToCopy {
                if let element = sourceDataSet[tag] {
                    let label = tagLabel(tag)
                    if !dryRun {
                        dataSet[tag] = element
                    }
                    let valueStr = element.stringValue ?? "<binary>"
                    descriptions.append("COPY \(label) = \(valueStr)")
                }
            }
        }

        // 4. Set tag values (applied last so they override copies)
        for setSpec in sets {
            let (tag, value) = try parseTagValue(setSpec)
            let label = tagLabel(tag)
            let vr = vrForTag(tag, in: dataSet)
            if !dryRun {
                dataSet.setString(value, for: tag, vr: vr)
            }
            descriptions.append("SET \(label) = \(value)")
        }

        return descriptions
    }

    // MARK: - Helpers

    private func vrForTag(_ tag: Tag, in dataSet: DataSet) -> VR {
        if let existing = dataSet[tag] {
            return existing.vr
        }
        return Self.tagVRMap[tag] ?? .LO
    }

    private func tagLabel(_ tag: Tag) -> String {
        let hex = "(\(hexGroup(tag.group)),\(hexElement(tag.element)))"
        if let name = Self.tagDisplayName[tag] {
            return "\(hex) \(name)"
        }
        return hex
    }

    private func hexGroup(_ value: UInt16) -> String {
        String(format: "%04X", value)
    }

    private func hexElement(_ value: UInt16) -> String {
        String(format: "%04X", value)
    }
}
