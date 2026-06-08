// ValidationViewModel.swift
// DICOMStudio
//
// ViewModel for the DICOM Validation view.
// Runs validation through DICOMKit.DICOMValidator — the exact same engine the
// `dicom-validate` CLI uses — so the app and the tool cannot drift. The library
// ValidationResult is mapped onto the view's display model (ValidationFileResult).

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

    /// Validates the input file/directory using the shared DICOMKit engine.
    /// Output text is rendered by ValidationHelpers (matching the CLI report).
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

    // MARK: - Private: Core Validation (shared DICOMKit engine)
    //
    // Validation runs through DICOMKit.DICOMValidator — the exact engine the
    // `dicom-validate` CLI uses. There is no app-local validation logic anymore;
    // library results are mapped onto ValidationFileResult for display so the app
    // and the CLI can never disagree on what is valid.

    private func validateInput() async throws -> [ValidationFileResult] {
        let url = URL(fileURLWithPath: inputPath)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir) else {
            throw NSError(domain: "ValidationViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Input path not found: \(inputPath)"])
        }

        let trimmedIOD = iod.trimmingCharacters(in: .whitespaces)
        let validator = DICOMKit.DICOMValidator(
            level: level,
            iod: trimmedIOD.isEmpty ? nil : trimmedIOD,
            force: force
        )

        if isDir.boolValue {
            guard recursive else {
                throw NSError(domain: "ValidationViewModel", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Directory validation requires --recursive flag"])
            }
            return validateDirectory(url: url, validator: validator)
        } else {
            return [validateFile(url: url, validator: validator)]
        }
    }

    private func validateDirectory(url: URL, validator: DICOMKit.DICOMValidator) -> [ValidationFileResult] {
        // Collect URLs synchronously to avoid NSDirectoryEnumerator's makeIterator
        // unavailability in an async context.
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

        return fileURLs.map { validateFile(url: $0, validator: validator) }
    }

    /// Validates one file through the shared DICOMKit engine and maps the library
    /// result onto the view model's display model.
    private func validateFile(url: URL, validator: DICOMKit.DICOMValidator) -> ValidationFileResult {
        do {
            let data = try Data(contentsOf: url)
            let result = try validator.validate(data: data, filePath: url.path)
            return Self.mapResult(result)
        } catch {
            return ValidationFileResult(
                filePath: url.path,
                isValid: false,
                errors: [ValidationIssueEntry(level: .error, message: error.localizedDescription)]
            )
        }
    }

    // MARK: - Mapping (library result -> display model)

    private static func mapResult(_ result: DICOMKit.ValidationResult) -> ValidationFileResult {
        ValidationFileResult(
            filePath: result.filePath,
            isValid: result.isValid,
            errors: result.errors.map(mapIssue),
            warnings: result.warnings.map(mapIssue)
        )
    }

    private static func mapIssue(_ issue: DICOMKit.ValidationIssue) -> ValidationIssueEntry {
        ValidationIssueEntry(
            level: issue.level == .error ? .error : .warning,
            message: issue.message,
            tagString: issue.tag.map { $0.description }
        )
    }
}
