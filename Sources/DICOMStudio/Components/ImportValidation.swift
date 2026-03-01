// ImportValidation.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent DICOM file validation logic

import Foundation

/// Platform-independent helper for DICOM file validation.
///
/// Provides validation logic for DICOM file import, checking:
/// - File preamble and DICM magic bytes
/// - File Meta Information presence
/// - Required DICOM tags
/// - Transfer Syntax support
public enum ImportValidation: Sendable {

    /// The DICOM magic bytes "DICM" expected at offset 128.
    public static let dicmMagicBytes: [UInt8] = [0x44, 0x49, 0x43, 0x4D]

    /// Minimum valid DICOM file size (128-byte preamble + 4-byte magic + minimal meta).
    public static let minimumFileSize: Int = 132

    /// Offset where the DICM magic bytes are located.
    public static let dicmMagicOffset: Int = 128

    /// Validates raw file data for DICOM compliance.
    ///
    /// - Parameter data: The raw file data.
    /// - Returns: Array of validation issues found.
    public static func validate(data: Data) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check minimum file size
        if data.count < minimumFileSize {
            issues.append(ValidationIssue(
                severity: .error,
                message: "File is too small to be a valid DICOM file (\(data.count) bytes, minimum \(minimumFileSize))",
                rule: .fileSize
            ))
            return issues
        }

        // Check preamble (first 128 bytes should exist, typically zeros)
        let preamble = data.prefix(dicmMagicOffset)
        if preamble.count < dicmMagicOffset {
            issues.append(ValidationIssue(
                severity: .error,
                message: "File is missing the 128-byte DICOM preamble",
                rule: .preamble
            ))
        }

        // Check DICM magic bytes
        let magicRange = dicmMagicOffset..<(dicmMagicOffset + 4)
        let magicBytes = Array(data[magicRange])
        if magicBytes != dicmMagicBytes {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing DICM magic bytes at offset 128",
                rule: .dicmMagic
            ))
        }

        return issues
    }

    /// Checks if data has a valid DICOM preamble and magic bytes.
    ///
    /// - Parameter data: The raw file data.
    /// - Returns: `true` if the file has valid DICM magic bytes.
    public static func hasDICMMagic(_ data: Data) -> Bool {
        guard data.count >= minimumFileSize else { return false }
        let magicRange = dicmMagicOffset..<(dicmMagicOffset + 4)
        return Array(data[magicRange]) == dicmMagicBytes
    }

    /// Validates that required study-level tags are present.
    ///
    /// - Parameters:
    ///   - hasStudyInstanceUID: Whether Study Instance UID is present.
    ///   - hasSOPInstanceUID: Whether SOP Instance UID is present.
    ///   - hasSOPClassUID: Whether SOP Class UID is present.
    /// - Returns: Array of validation issues for missing required tags.
    public static func validateRequiredTags(
        hasStudyInstanceUID: Bool,
        hasSOPInstanceUID: Bool,
        hasSOPClassUID: Bool
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if !hasSOPInstanceUID {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required SOP Instance UID (0008,0018)",
                rule: .requiredTags
            ))
        }

        if !hasSOPClassUID {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Missing SOP Class UID (0008,0016)",
                rule: .sopClassUID
            ))
        }

        if !hasStudyInstanceUID {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Missing Study Instance UID (0020,000D)",
                rule: .requiredTags
            ))
        }

        return issues
    }

    /// Validates the Transfer Syntax UID.
    ///
    /// - Parameter transferSyntaxUID: The Transfer Syntax UID string, if present.
    /// - Returns: Array of validation issues related to transfer syntax.
    public static func validateTransferSyntax(_ transferSyntaxUID: String?) -> [ValidationIssue] {
        guard let uid = transferSyntaxUID, !uid.isEmpty else {
            return [ValidationIssue(
                severity: .info,
                message: "No Transfer Syntax UID specified; assuming Implicit VR Little Endian",
                rule: .transferSyntax
            )]
        }

        let knownTransferSyntaxes: Set<String> = [
            "1.2.840.10008.1.2",        // Implicit VR Little Endian
            "1.2.840.10008.1.2.1",      // Explicit VR Little Endian
            "1.2.840.10008.1.2.2",      // Explicit VR Big Endian
            "1.2.840.10008.1.2.1.99",   // Deflated Explicit VR Little Endian
            "1.2.840.10008.1.2.4.50",   // JPEG Baseline
            "1.2.840.10008.1.2.4.51",   // JPEG Extended
            "1.2.840.10008.1.2.4.57",   // JPEG Lossless NH
            "1.2.840.10008.1.2.4.70",   // JPEG Lossless FOP
            "1.2.840.10008.1.2.4.80",   // JPEG-LS Lossless
            "1.2.840.10008.1.2.4.81",   // JPEG-LS Lossy
            "1.2.840.10008.1.2.4.90",   // JPEG 2000 Lossless
            "1.2.840.10008.1.2.4.91",   // JPEG 2000
            "1.2.840.10008.1.2.5",      // RLE Lossless
        ]

        if !knownTransferSyntaxes.contains(uid) {
            return [ValidationIssue(
                severity: .warning,
                message: "Unrecognized Transfer Syntax UID: \(uid)",
                rule: .transferSyntax
            )]
        }

        return []
    }

    /// Returns a summary categorization of validation issues.
    ///
    /// - Parameter issues: The validation issues to summarize.
    /// - Returns: A tuple of (errors, warnings, infos) counts.
    public static func summarize(_ issues: [ValidationIssue]) -> (errors: Int, warnings: Int, infos: Int) {
        var errors = 0, warnings = 0, infos = 0
        for issue in issues {
            switch issue.severity {
            case .error: errors += 1
            case .warning: warnings += 1
            case .info: infos += 1
            }
        }
        return (errors, warnings, infos)
    }

    /// Whether a file with the given issues should be rejected.
    ///
    /// - Parameter issues: The validation issues.
    /// - Returns: `true` if any error-level issues exist.
    public static func shouldReject(_ issues: [ValidationIssue]) -> Bool {
        issues.contains { $0.severity == .error }
    }
}
