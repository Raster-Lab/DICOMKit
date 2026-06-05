// ValidationViewModel.swift
// DICOMStudio
//
// ViewModel for the DICOM Validation view.
// Implements dicom-validate functionality natively using DICOMKit APIs,
// producing output that matches the CLI tool exactly.

import Foundation
import Observation
import DICOMKit
import DICOMCore
import DICOMDictionary

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class ValidationViewModel {
    private let service: ValidationService

    // MARK: - Options (mirrors dicom-validate CLI flags)

    /// Positional argument: path to DICOM file or directory.
    public var inputPath: String = ""
    /// --level 1-5
    public var level: Int = 3
    /// --iod CTImageStorage etc.
    public var iod: String = ""
    /// --detailed
    public var detailed: Bool = false
    /// --recursive
    public var recursive: Bool = false
    /// --format text|json
    public var format: ValidateOutputFormat = .text
    /// --output path (empty = stdout / display in UI)
    public var outputPath: String = ""
    /// --strict
    public var strict: Bool = false
    /// --force
    public var force: Bool = false

    // MARK: - UI State

    public var isRunning: Bool = false
    public var validationOutput: String = ""
    public var lastResults: [ValidationFileResult] = []
    public var runHistory: [ValidationRunRecord] = []
    public var iodSuggestions: [String] = ValidationHelpers.knownIODs
    public var showIODPicker: Bool = false

    // MARK: - Security-Scoped Resource Access
    // Set by the view (or CLIWorkshopViewModel) immediately after the user picks
    // a file via NSOpenPanel / NSSavePanel.  Required for sandbox file access.
    public var inputScopedURL: URL?
    public var outputScopedURL: URL?

    // MARK: - Init

    public init(service: ValidationService = ValidationService()) {
        self.service = service
    }

    // MARK: - Command Builder

    /// Returns the exact dicom-validate CLI command for the current settings.
    public var cliCommand: String {
        ValidationHelpers.buildCommand(
            inputPath: inputPath,
            level: level,
            iod: iod,
            detailed: detailed,
            recursive: recursive,
            format: format,
            outputPath: outputPath,
            strict: strict,
            force: force
        )
    }

    // MARK: - Run Validation

    /// Validates the input file/directory using DICOMKit APIs.
    /// Output text matches dicom-validate Report.renderText() / renderJSON() exactly.
    public func runValidation() {
        guard !inputPath.isEmpty else {
            validationOutput = "Error: Input path is required.\n"
            return
        }
        guard level >= 1 && level <= 5 else {
            validationOutput = "Error: Validation level must be between 1 and 5.\n"
            return
        }

        isRunning = true
        validationOutput = "Running: \(cliCommand)\n\n"

        Task {
            // Start security-scoped resource access for the entire validation run.
            // The sandbox requires this for any user-selected file or directory.
            let inputAccessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
            let outputAccessing = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
            defer {
                if inputAccessing  { inputScopedURL?.stopAccessingSecurityScopedResource() }
                if outputAccessing { outputScopedURL?.stopAccessingSecurityScopedResource() }
            }
            do {
                let results = try await validateInput()
                let output: String
                if format == .json {
                    output = (try? ValidationHelpers.renderJSON(results: results)) ?? ""
                } else {
                    output = ValidationHelpers.renderText(
                        results: results,
                        detailed: detailed,
                        strict: strict
                    )
                }
                let hasErrors   = results.contains { !$0.errors.isEmpty }
                let hasWarnings = results.contains { !$0.warnings.isEmpty }
                let code: Int32 = hasErrors ? 1 : (strict && hasWarnings ? 2 : 0)

                // Save to history
                let record = ValidationRunRecord(
                    inputPath: inputPath,
                    level: level,
                    iod: iod,
                    strict: strict,
                    recursive: recursive,
                    format: format,
                    results: results,
                    output: output,
                    exitCode: code
                )
                service.addHistory(record)

                // Optionally write to file — sandbox/TCC-resilient: prefer the picker's
                // scoped URL; else try the typed path; on failure (e.g. macOS TCC blocks
                // ~/Desktop) fall back to ~/Downloads/DICOMStudio and surface a note so the
                // write never silently fails (the old `try?` swallowed TCC denials).
                var writeNote: String? = nil
                if !outputPath.isEmpty {
                    do {
                        writeNote = try OutputAccess.writeString(output, toPath: outputPath,
                                                                 scopedURL: outputScopedURL,
                                                                 subfolder: "Validate").note
                    } catch {
                        writeNote = "⚠ Could not write report to \(outputPath): \(error.localizedDescription)"
                    }
                }

                await MainActor.run {
                    self.lastResults = results
                    self.validationOutput = writeNote.map { output + "\n" + $0 } ?? output
                    self.runHistory.insert(record, at: 0)
                    self.isRunning = false
                }
            } catch {
                await MainActor.run {
                    self.validationOutput += "Error: \(error.localizedDescription)\n"
                    self.isRunning = false
                }
            }
        }
    }

    // MARK: - Clear

    public func clearOutput() {
        validationOutput = ""
        lastResults = []
    }

    public func clearHistory() {
        runHistory.removeAll()
        service.clearHistory()
    }

    // MARK: - Private: Core Validation Logic
    // Mirrors DICOMValidator in dicom-validate/Validator.swift

    private func validateInput() async throws -> [ValidationFileResult] {
        let url = URL(fileURLWithPath: inputPath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir) else {
            throw NSError(domain: "ValidationViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Input path not found: \(inputPath)"])
        }

        if isDir.boolValue {
            guard recursive else {
                throw NSError(domain: "ValidationViewModel", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Directory validation requires --recursive flag"])
            }
            return try await validateDirectory(url: url)
        } else {
            return [try validateFile(url: url)]
        }
    }

    private func validateDirectory(url: URL) async throws -> [ValidationFileResult] {
        // Collect URLs synchronously on the current executor to avoid
        // NSDirectoryEnumerator's makeIterator unavailability in async context.
        let fileURLs: [URL] = {
            var collected: [URL] = []
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            for case let fileURL as URL in enumerator {
                let rv = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if rv?.isRegularFile == true { collected.append(fileURL) }
            }
            return collected
        }()

        var results: [ValidationFileResult] = []
        for fileURL in fileURLs {
            do {
                results.append(try validateFile(url: fileURL))
            } catch {
                results.append(ValidationFileResult(
                    filePath: fileURL.path,
                    isValid: false,
                    errors: [ValidationIssueEntry(level: .error, message: error.localizedDescription)]
                ))
            }
        }
        return results
    }

    /// Validates a single DICOM file — mirrors DICOMValidator.validate().
    private func validateFile(url: URL) throws -> ValidationFileResult {
        var errors: [ValidationIssueEntry] = []
        var warnings: [ValidationIssueEntry] = []

        let data = try Data(contentsOf: url)

        // Level 1: File format
        let dicomFile: DICOMFile
        do {
            dicomFile = try DICOMFile.read(from: data, force: force)
        } catch {
            errors.append(ValidationIssueEntry(level: .error,
                message: "Failed to parse DICOM file: \(error.localizedDescription)"))
            return ValidationFileResult(filePath: url.path, isValid: false, errors: errors, warnings: warnings)
        }

        // Check DICM prefix
        if !force && data.count >= 132 {
            let offset = data.startIndex.advanced(by: 128)
            let prefix = data[offset..<offset.advanced(by: 4)]
            if String(data: prefix, encoding: .ascii) != "DICM" {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Missing DICM prefix at byte 128"))
            }
        }

        // Validate required File Meta Information
        let requiredMetaTags: [(Tag, String)] = [
            (.mediaStorageSOPClassUID,    "Media Storage SOP Class UID"),
            (.mediaStorageSOPInstanceUID, "Media Storage SOP Instance UID"),
            (.transferSyntaxUID,          "Transfer Syntax UID"),
        ]
        for (tag, name) in requiredMetaTags {
            if dicomFile.fileMetaInformation[tag] == nil {
                errors.append(ValidationIssueEntry(level: .error,
                    message: "Missing required File Meta Information element: \(name)",
                    tagString: tag.description))
            }
        }

        if level >= 2 {
            // Level 2: Required Type 1 tags
            let type1Tags: [(Tag, String)] = [
                (.sopClassUID,    "SOP Class UID"),
                (.sopInstanceUID, "SOP Instance UID"),
            ]
            for (tag, name) in type1Tags {
                if let el = dicomFile.dataSet[tag] {
                    if el.length == 0 {
                        errors.append(ValidationIssueEntry(level: .error,
                            message: "Type 1 element \(name) is empty",
                            tagString: tag.description))
                    }
                } else {
                    errors.append(ValidationIssueEntry(level: .error,
                        message: "Missing required Type 1 element: \(name)",
                        tagString: tag.description))
                }
            }

            // VR mismatch validation
            for tag in dicomFile.dataSet.tags {
                if let element = dicomFile.dataSet[tag],
                   let entry = DataElementDictionary.lookup(tag: tag) {
                    if !entry.vr.contains(element.vr) && element.vr != .UN {
                        warnings.append(ValidationIssueEntry(level: .warning,
                            message: "Unexpected VR \(element.vr) for tag \(tag) (expected: \(entry.vr.map { $0.rawValue }.joined(separator: " or ")))",
                            tagString: tag.description))
                    }
                }
            }

            // UID format validation
            let uidTags: [(Tag, String)] = [
                (.sopClassUID,    "SOP Class UID"),
                (.sopInstanceUID, "SOP Instance UID"),
                (.studyInstanceUID, "Study Instance UID"),
                (.seriesInstanceUID, "Series Instance UID"),
            ]
            for (tag, name) in uidTags {
                if let val = dicomFile.dataSet.string(for: tag), !val.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !isValidUID(val) {
                        errors.append(ValidationIssueEntry(level: .error,
                            message: "Invalid UID format for \(name)",
                            tagString: tag.description))
                    }
                }
            }

            // Date format
            let dateTags: [(Tag, String)] = [
                (.studyDate, "Study Date"),
                (.seriesDate, "Series Date"),
                (.patientBirthDate, "Patient Birth Date"),
            ]
            for (tag, name) in dateTags {
                if let val = dicomFile.dataSet.string(for: tag), !val.isEmpty {
                    if !isValidDICOMDate(val) {
                        errors.append(ValidationIssueEntry(level: .error,
                            message: "Invalid date format for \(name) (expected YYYYMMDD)",
                            tagString: tag.description))
                    }
                }
            }
        }

        if level >= 3 {
            // Level 3: IOD-specific mandatory tags
            let iodName = iod.isEmpty ? detectIOD(from: dicomFile.dataSet) : iod
            if let iodName {
                validateIOD(iodName: iodName, dataSet: dicomFile.dataSet, errors: &errors, warnings: &warnings)
            } else {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Cannot determine IOD type for validation",
                    tagString: Tag.sopClassUID.description))
            }
        }

        if level >= 4 {
            // Level 4: Best practices
            if dicomFile.dataSet.string(for: .patientName) == nil {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Patient Name (0010,0010) is absent — recommended for identification"))
            }
            if dicomFile.dataSet.string(for: .studyInstanceUID) == nil {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Study Instance UID (0020,000D) is absent"))
            }
            if dicomFile.dataSet.string(for: .seriesInstanceUID) == nil {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Series Instance UID (0020,000E) is absent"))
            }
            // Check for private creator tags without group length
            validateBestPractices(dataSet: dicomFile.dataSet, warnings: &warnings)
        }

        if level >= 5 {
            // Level 5: J2K codestream — informational note
            let tsUID = dicomFile.fileMetaInformation.string(for: .transferSyntaxUID) ?? ""
            if isJ2KTransferSyntax(tsUID) {
                warnings.append(ValidationIssueEntry(level: .info,
                    message: "JPEG 2000 codestream conformance check (Level 5) — use dicom-validate CLI for full J2K validation"))
            }
        }

        return ValidationFileResult(
            filePath: url.path,
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - IOD Validation

    private func detectIOD(from dataSet: DataSet) -> String? {
        guard let uid = dataSet.string(for: .sopClassUID)?.trimmingCharacters(in: .whitespaces) else { return nil }
        let map: [String: String] = [
            "1.2.840.10008.5.1.4.1.1.2":     "CTImageStorage",
            "1.2.840.10008.5.1.4.1.1.4":     "MRImageStorage",
            "1.2.840.10008.5.1.4.1.1.6.1":   "UltrasoundImageStorage",
            "1.2.840.10008.5.1.4.1.1.3.1":   "UltrasoundMultiframeImageStorage",
            "1.2.840.10008.5.1.4.1.1.12.1":  "XRayAngiographicImageStorage",
            "1.2.840.10008.5.1.4.1.1.7":     "SecondaryCaptureImageStorage",
            "1.2.840.10008.5.1.4.1.1.88.11": "BasicTextSRStorage",
            "1.2.840.10008.5.1.4.1.1.88.22": "EnhancedSRStorage",
            "1.2.840.10008.5.1.4.1.1.88.33": "ComprehensiveSRStorage",
            "1.2.840.10008.5.1.4.1.1.66.4":  "SegmentationStorage",
            "1.2.840.10008.5.1.4.1.1.104.1": "EncapsulatedPDFStorage",
            "1.2.840.10008.5.1.4.1.1.2.1":   "EnhancedCTImageStorage",
            "1.2.840.10008.5.1.4.1.1.4.1":   "EnhancedMRImageStorage",
            "1.2.840.10008.5.1.4.1.1.20":    "NuclearMedicineImageStorage",
            "1.2.840.10008.5.1.4.1.1.128":   "PositronEmissionTomographyImageStorage",
            "1.2.840.10008.5.1.4.1.1.1":     "ComputedRadiographyImageStorage",
        ]
        return map[uid]
    }

    private func validateIOD(iodName: String, dataSet: DataSet, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        switch iodName {
        case "CTImageStorage", "MRImageStorage",
             "UltrasoundImageStorage", "NuclearMedicineImageStorage",
             "ComputedRadiographyImageStorage", "PositronEmissionTomographyImageStorage":
            validateImageIOD(dataSet: dataSet, iodName: iodName, errors: &errors, warnings: &warnings)
        case "SecondaryCaptureImageStorage":
            validateSecondaryCaptureIOD(dataSet: dataSet, errors: &errors, warnings: &warnings)
        case "BasicTextSRStorage", "EnhancedSRStorage", "ComprehensiveSRStorage":
            validateSRIOD(dataSet: dataSet, errors: &errors, warnings: &warnings)
        case "SegmentationStorage":
            validateSegmentationIOD(dataSet: dataSet, errors: &errors, warnings: &warnings)
        case "EncapsulatedPDFStorage":
            validateEncapsulatedPDFIOD(dataSet: dataSet, errors: &errors, warnings: &warnings)
        default:
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "IOD-specific validation not available for \(iodName)"))
        }
    }

    private func validateImageIOD(dataSet: DataSet, iodName: String, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        let mandatory: [(Tag, String)] = [
            (.rows,            "Rows (0028,0010)"),
            (.columns,         "Columns (0028,0011)"),
            (.bitsAllocated,   "Bits Allocated (0028,0100)"),
            (.bitsStored,      "Bits Stored (0028,0101)"),
            (.highBit,         "High Bit (0028,0102)"),
            (.pixelRepresentation, "Pixel Representation (0028,0103)"),
            (.samplesPerPixel, "Samples Per Pixel (0028,0002)"),
            (.photometricInterpretation, "Photometric Interpretation (0028,0004)"),
        ]
        for (tag, name) in mandatory {
            if dataSet[tag] == nil {
                errors.append(ValidationIssueEntry(level: .error,
                    message: "Missing mandatory element for \(iodName): \(name)",
                    tagString: tag.description))
            }
        }
    }

    private func validateSecondaryCaptureIOD(dataSet: DataSet, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        let mandatory: [(Tag, String)] = [
            (.rows, "Rows (0028,0010)"),
            (.columns, "Columns (0028,0011)"),
        ]
        for (tag, name) in mandatory {
            if dataSet[tag] == nil {
                errors.append(ValidationIssueEntry(level: .error,
                    message: "Missing mandatory element for SecondaryCaptureImageStorage: \(name)",
                    tagString: tag.description))
            }
        }
        if dataSet.string(for: .conversionType) == nil {
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "Conversion Type (0008,0064) is recommended for Secondary Capture"))
        }
    }

    private func validateSRIOD(dataSet: DataSet, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        let mandatory: [(Tag, String)] = [
            (.contentDate, "Content Date (0008,0023)"),
            (.contentTime, "Content Time (0008,0033)"),
            (.completionFlag, "Completion Flag (0040,A491)"),
            (.verificationFlag, "Verification Flag (0040,A493)"),
        ]
        for (tag, name) in mandatory {
            if dataSet[tag] == nil {
                warnings.append(ValidationIssueEntry(level: .warning,
                    message: "Missing recommended element: \(name)",
                    tagString: tag.description))
            }
        }
    }

    private func validateSegmentationIOD(dataSet: DataSet, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        if dataSet[.segmentationType] == nil {
            errors.append(ValidationIssueEntry(level: .error,
                message: "Missing mandatory element for Segmentation: Segmentation Type (0062,0001)",
                tagString: Tag.segmentationType.description))
        }
    }

    private func validateEncapsulatedPDFIOD(dataSet: DataSet, errors: inout [ValidationIssueEntry], warnings: inout [ValidationIssueEntry]) {
        if dataSet[.encapsulatedDocument] == nil {
            errors.append(ValidationIssueEntry(level: .error,
                message: "Missing mandatory element: Encapsulated Document (0042,0011)",
                tagString: Tag.encapsulatedDocument.description))
        }
        if dataSet.string(for: .mimeTypeOfEncapsulatedDocument) == nil {
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "MIME Type of Encapsulated Document (0042,0012) is absent"))
        }
    }

    // MARK: - Best Practices

    private func validateBestPractices(dataSet: DataSet, warnings: inout [ValidationIssueEntry]) {
        // Check instance number is present
        if dataSet[.instanceNumber] == nil {
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "Instance Number (0020,0013) is absent — recommended for ordering"))
        }
        // Check specific character set (wording/tag match CLI Validator.validateBestPractices).
        if dataSet[.specificCharacterSet] == nil {
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "Specific Character Set not specified (ISO_IR 100 or UTF-8 recommended)",
                tagString: "(0008,0005)"))
        }
        // Private-tag interoperability check (matches CLI Validator.validateBestPractices).
        let privateTagCount = dataSet.tags.filter { $0.isPrivate }.count
        if privateTagCount > 10 {
            warnings.append(ValidationIssueEntry(level: .warning,
                message: "File contains \(privateTagCount) private tags (may affect interoperability)"))
        }
    }

    // MARK: - Format Validators

    private func isValidUID(_ uid: String) -> Bool {
        let cleaned = uid.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        guard !cleaned.isEmpty, cleaned.count <= 64 else { return false }
        let components = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        for component in components {
            guard !component.isEmpty else { return false }
            guard component.allSatisfy({ $0.isNumber }) else { return false }
            if component.count > 1 && component.first == "0" { return false }
        }
        return true
    }

    private func isValidDICOMDate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 8, trimmed.allSatisfy({ $0.isNumber }) else { return false }
        guard let month = Int(trimmed.dropFirst(4).prefix(2)),
              let day   = Int(trimmed.dropFirst(6)) else { return false }
        return month >= 1 && month <= 12 && day >= 1 && day <= 31
    }

    private func isJ2KTransferSyntax(_ uid: String) -> Bool {
        let j2kUIDs = [
            "1.2.840.10008.1.2.4.90",
            "1.2.840.10008.1.2.4.91",
            "1.2.840.10008.1.2.4.92",
            "1.2.840.10008.1.2.4.93",
            "1.2.840.10008.1.2.4.202",
            "1.2.840.10008.1.2.4.203",
        ]
        return j2kUIDs.contains(uid.trimmingCharacters(in: .whitespaces))
    }
}
