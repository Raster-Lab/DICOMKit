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

    // NOTE: The app-local renderText/renderJSON copies were removed — they had
    // drifted from the CLI (an app-only trailing "Exit code:" block). Console
    // rendering now goes through the SHARED DICOMKit.ValidationReport, the exact
    // renderer dicom-validate uses (see ValidationViewModel.runValidation).
}
