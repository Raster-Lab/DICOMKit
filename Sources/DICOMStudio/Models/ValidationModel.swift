// ValidationModel.swift
// DICOMStudio
//
// Model types for the DICOM Validation view.
// Maps 1-to-1 with dicom-validate CLI options and output format.
// Reference: DICOM PS3.5 §7, PS3.10 §7, PS3.3 (IOD Conformance)

import Foundation

// MARK: - Output Format

/// Output format matching dicom-validate --format
public enum ValidateOutputFormat: String, Sendable, Equatable, Hashable, CaseIterable {
    case text = "text"
    case json = "json"

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .json: return "JSON"
        }
    }
}

// MARK: - Issue Level

public enum ValidationIssueLevel: String, Sendable, Equatable, Hashable, CaseIterable {
    case error   = "error"
    case warning = "warning"
    case info    = "info"

    public var displayName: String { rawValue.capitalized }

    public var sfSymbol: String {
        switch self {
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

// MARK: - Validation Issue

/// A single validation finding — mirrors ValidationIssue in dicom-validate/Report.swift
public struct ValidationIssueEntry: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var level: ValidationIssueLevel
    public var message: String
    /// DICOM tag in (gggg,eeee) notation, if applicable.
    public var tagString: String?

    public init(id: UUID = UUID(), level: ValidationIssueLevel, message: String, tagString: String? = nil) {
        self.id = id
        self.level = level
        self.message = message
        self.tagString = tagString
    }
}

// MARK: - File Validation Result

/// Per-file validation result — mirrors ValidationResult in dicom-validate/Report.swift
public struct ValidationFileResult: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var filePath: String
    public var isValid: Bool
    public var errors: [ValidationIssueEntry]
    public var warnings: [ValidationIssueEntry]

    public var issueCount: Int { errors.count + warnings.count }

    public init(
        id: UUID = UUID(),
        filePath: String,
        isValid: Bool,
        errors: [ValidationIssueEntry] = [],
        warnings: [ValidationIssueEntry] = []
    ) {
        self.id = id
        self.filePath = filePath
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - Validation Run Record

/// A historical record of a single validation run.
public struct ValidationRunRecord: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var inputPath: String
    public var level: Int
    public var iod: String
    public var strict: Bool
    public var recursive: Bool
    public var format: ValidateOutputFormat
    public var results: [ValidationFileResult]
    public var output: String
    public var ranAt: Date
    public var exitCode: Int32

    public init(
        id: UUID = UUID(),
        inputPath: String,
        level: Int,
        iod: String,
        strict: Bool,
        recursive: Bool,
        format: ValidateOutputFormat,
        results: [ValidationFileResult],
        output: String,
        ranAt: Date = Date(),
        exitCode: Int32
    ) {
        self.id = id
        self.inputPath = inputPath
        self.level = level
        self.iod = iod
        self.strict = strict
        self.recursive = recursive
        self.format = format
        self.results = results
        self.output = output
        self.ranAt = ranAt
        self.exitCode = exitCode
    }
}

// MARK: - Helpers (platform-independent)

/// Platform-independent helpers for ValidationView.
public enum ValidationHelpers: Sendable {
    /// Known IOD names accepted by the --iod flag.
    public static let knownIODs: [String] = [
        "CTImageStorage",
        "MRImageStorage",
        "UltrasoundImageStorage",
        "UltrasoundMultiframeImageStorage",
        "XRayAngiographicImageStorage",
        "DigitalXRayImageStorageForPresentation",
        "DigitalXRayImageStorageForProcessing",
        "SecondaryCaptureImageStorage",
        "MultiframeSingleBitSecondaryCaptureImageStorage",
        "MultiframeGrayscaleByteSecondaryCaptureImageStorage",
        "MultiframeGrayscaleWordSecondaryCaptureImageStorage",
        "MultiframeTrueColorSecondaryCaptureImageStorage",
        "EnhancedCTImageStorage",
        "EnhancedMRImageStorage",
        "EnhancedPETImageStorage",
        "NuclearMedicineImageStorage",
        "PositronEmissionTomographyImageStorage",
        "ComputedRadiographyImageStorage",
        "EncapsulatedPDFStorage",
        "BasicTextSRStorage",
        "EnhancedSRStorage",
        "ComprehensiveSRStorage",
        "Comprehensive3DSRStorage",
        "MammographyCADSRStorage",
        "ChestCADSRStorage",
        "RTStructureSetStorage",
        "RTPlanStorage",
        "RTDoseStorage",
        "RTImageStorage",
        "SegmentationStorage",
    ]

    /// Validation level descriptions matching the CLI help text.
    public static func levelDescription(_ level: Int) -> String {
        switch level {
        case 1: return "1 — File format (preamble, DICM prefix, meta)"
        case 2: return "2 — Tags, VR/VM conformance"
        case 3: return "3 — IOD-specific mandatory elements"
        case 4: return "4 — Best practices"
        case 5: return "5 — JPEG 2000 codestream conformance"
        default: return "Unknown"
        }
    }

    /// Builds the exact dicom-validate CLI command string.
    public static func buildCommand(
        inputPath: String,
        level: Int,
        iod: String,
        detailed: Bool,
        recursive: Bool,
        format: ValidateOutputFormat,
        outputPath: String,
        strict: Bool,
        force: Bool
    ) -> String {
        guard !inputPath.isEmpty else { return "dicom-validate <input>" }
        var cmd = "dicom-validate \"\(inputPath)\""
        if level != 3 { cmd += " --level \(level)" }
        if !iod.isEmpty { cmd += " --iod \(iod)" }
        if detailed { cmd += " --detailed" }
        if recursive { cmd += " --recursive" }
        if format != .text { cmd += " --format \(format.rawValue)" }
        if !outputPath.isEmpty { cmd += " --output \"\(outputPath)\"" }
        if strict { cmd += " --strict" }
        if force { cmd += " --force" }
        return cmd
    }

    /// Renders a list of ValidationFileResults as text matching Report.renderText().
    public static func renderText(
        results: [ValidationFileResult],
        detailed: Bool,
        strict: Bool
    ) -> String {
        var out = ""

        if results.count == 1 {
            let r = results[0]
            out += "DICOM Validation Report\n"
            out += "=======================\n\n"
            out += "File: \(r.filePath)\n"
            out += "Status: \(r.isValid ? "✓ VALID" : "✗ INVALID")\n\n"
            if !r.errors.isEmpty {
                out += "Errors (\(r.errors.count)):\n"
                out += renderIssues(r.errors)
                out += "\n"
            }
            if !r.warnings.isEmpty {
                out += "Warnings (\(r.warnings.count)):\n"
                out += renderIssues(r.warnings)
                out += "\n"
            }
            if r.errors.isEmpty && r.warnings.isEmpty {
                out += "No issues found.\n"
            }
        } else {
            let validFiles   = results.filter { $0.isValid }.count
            let invalidFiles = results.count - validFiles
            let totalErrors  = results.reduce(0) { $0 + $1.errors.count }
            let totalWarnings = results.reduce(0) { $0 + $1.warnings.count }

            out += "DICOM Validation Summary\n"
            out += "========================\n\n"
            out += "Total files: \(results.count)\n"
            out += "Valid: \(validFiles)\n"
            out += "Invalid: \(invalidFiles)\n"
            out += "Total errors: \(totalErrors)\n"
            out += "Total warnings: \(totalWarnings)\n\n"

            if detailed {
                out += "Detailed Results:\n"
                out += "-----------------\n\n"
                for r in results {
                    let sym = r.isValid ? "✓" : "✗"
                    out += "\(sym) \(r.filePath)\n"
                    if !r.errors.isEmpty {
                        out += "  Errors (\(r.errors.count)):\n"
                        for e in r.errors {
                            out += "    • \(e.message)"
                            if let t = e.tagString { out += " [\(t)]" }
                            out += "\n"
                        }
                    }
                    if !r.warnings.isEmpty {
                        out += "  Warnings (\(r.warnings.count)):\n"
                        for w in r.warnings {
                            out += "    • \(w.message)"
                            if let t = w.tagString { out += " [\(t)]" }
                            out += "\n"
                        }
                    }
                    out += "\n"
                }
            } else {
                let invalid = results.filter { !$0.isValid }
                if !invalid.isEmpty {
                    out += "Invalid Files:\n"
                    out += "--------------\n"
                    for r in invalid {
                        out += "✗ \(r.filePath) (\(r.errors.count) errors, \(r.warnings.count) warnings)\n"
                    }
                }
            }
        }

        // Exit code annotation (informational)
        let hasErrors   = results.contains { !$0.errors.isEmpty }
        let hasWarnings = results.contains { !$0.warnings.isEmpty }
        if hasErrors {
            out += "\nExit code: 1 (errors found)\n"
        } else if strict && hasWarnings {
            out += "\nExit code: 2 (warnings treated as errors in strict mode)\n"
        } else {
            out += "\nExit code: 0 (success)\n"
        }

        return out
    }

    private static func renderIssues(_ issues: [ValidationIssueEntry]) -> String {
        var out = ""
        for issue in issues {
            out += "  • \(issue.message)"
            if let t = issue.tagString { out += " [\(t)]" }
            out += "\n"
        }
        return out
    }
}
