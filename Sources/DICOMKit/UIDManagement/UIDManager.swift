import Foundation
import DICOMCore
import DICOMDictionary

// Shared UID workflow engine for the `dicom-uid` CLI and DICOMStudio. Builds on
// the already-shared `UIDGenerator` (DICOMCore) and `UIDDictionary`
// (DICOMDictionary); this layer is the generate/validate/lookup/regenerate
// workflow both adapters call. No ArgumentParser / Process / printing here —
// adapters format the returned values/structs and handle I/O.

/// Errors for UID management operations
public enum UIDManagerError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidUID(String, String)
    case noUIDsFound(String)
    case writeError(String)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidUID(let uid, let reason):
            return "Invalid UID '\(uid)': \(reason)"
        case .noUIDsFound(let path):
            return "No UIDs found in file: \(path)"
        case .writeError(let message):
            return "Write error: \(message)"
        }
    }
}

/// UID validation result
public struct UIDValidationResult {
    public let uid: String
    public let isValid: Bool
    public let errors: [String]
    public let registryName: String?

    public init(uid: String, isValid: Bool, errors: [String], registryName: String?) {
        self.uid = uid
        self.isValid = isValid
        self.errors = errors
        self.registryName = registryName
    }
}

/// UID mapping entry for old-to-new UID tracking
public struct UIDMapping: Codable {
    public let oldUID: String
    public let newUID: String
    public let tagName: String
    public let tagHex: String

    public init(oldUID: String, newUID: String, tagName: String, tagHex: String) {
        self.oldUID = oldUID
        self.newUID = newUID
        self.tagName = tagName
        self.tagHex = tagHex
    }
}

/// Manager for UID operations
public struct UIDManager {

    public init() {}

    // MARK: - UID Generation

    /// Generates UIDs with the specified root
    public func generateUIDs(count: Int, root: String?, type: String?) -> [String] {
        let generator = UIDGenerator(root: root ?? UIDGenerator.defaultRoot)
        var results: [String] = []

        for _ in 0..<count {
            let uid: DICOMUniqueIdentifier
            switch type?.lowercased() {
            case "study":
                uid = generator.generateStudyInstanceUID()
            case "series":
                uid = generator.generateSeriesInstanceUID()
            case "instance", "sop":
                uid = generator.generateSOPInstanceUID()
            default:
                uid = generator.generate()
            }
            results.append(uid.value)
        }

        return results
    }

    // MARK: - UID Validation

    /// Validates a UID string
    public func validateUID(_ uidString: String) -> UIDValidationResult {
        var errors: [String] = []

        // Check length
        if uidString.count > 64 {
            errors.append("Exceeds maximum length of 64 characters (length: \(uidString.count))")
        }

        // Check empty
        if uidString.isEmpty {
            errors.append("UID is empty")
            return UIDValidationResult(uid: uidString, isValid: false, errors: errors, registryName: nil)
        }

        // Check allowed characters
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        if uidString.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            errors.append("Contains invalid characters (only digits and periods allowed)")
        }

        // Check leading/trailing periods
        if uidString.hasPrefix(".") {
            errors.append("Must not start with a period")
        }
        if uidString.hasSuffix(".") {
            errors.append("Must not end with a period")
        }

        // Check consecutive periods
        if uidString.contains("..") {
            errors.append("Must not contain consecutive periods")
        }

        // Check leading zeros in components
        let components = uidString.split(separator: ".", omittingEmptySubsequences: false)
        for component in components {
            if component.count > 1 && component.hasPrefix("0") {
                errors.append("Component '\(component)' has a leading zero")
            }
        }

        // Check minimum components
        if components.count < 2 {
            errors.append("Must have at least 2 components")
        }

        // Registry lookup
        let entry = UIDDictionary.lookup(uid: uidString)
        let registryName = entry?.name

        return UIDValidationResult(
            uid: uidString,
            isValid: errors.isEmpty,
            errors: errors,
            registryName: registryName
        )
    }

    /// Validates all UIDs in a DICOM file
    public func validateFileUIDs(path: String) throws -> [UIDValidationResult] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw UIDManagerError.fileNotFound(path)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let file = try DICOMFile.read(from: data)
        var results: [UIDValidationResult] = []

        for element in file.dataSet.allElements {
            if element.vr == .UI {
                if let uidString = file.dataSet.string(for: element.tag) {
                    let trimmed = uidString.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
                    if !trimmed.isEmpty {
                        results.append(validateUID(trimmed))
                    }
                }
            }
        }

        return results
    }

    // MARK: - UID Lookup

    /// Look up a UID in the DICOM registry
    public func lookupUID(_ uidString: String) -> (name: String, type: String)? {
        if let entry = UIDDictionary.lookup(uid: uidString) {
            return (name: entry.name, type: Self.uidTypeDescription(entry.type))
        }
        return nil
    }

    // MARK: - UID Regeneration

    /// UID tags that should be regenerated
    public static let uidTags: [(tag: Tag, name: String)] = [
        (.sopInstanceUID, "SOPInstanceUID"),
        (.studyInstanceUID, "StudyInstanceUID"),
        (.seriesInstanceUID, "SeriesInstanceUID"),
    ]

    /// Regenerates instance UIDs in DICOM bytes, returning the new bytes plus the
    /// old→new mapping. Well-known UIDs (transfer syntaxes, SOP classes) are
    /// preserved. No file I/O — the caller decides how to persist (e.g. a
    /// sandbox-aware write), so this is shared by the CLI and DICOMStudio.
    public func regenerateData(
        _ inputData: Data,
        root: String?,
        maintainRelationships: Bool,
        existingMappings: inout [String: String]
    ) throws -> (data: Data, mappings: [UIDMapping]) {
        let file = try DICOMFile.read(from: inputData)
        var dataSet = file.dataSet
        let generator = UIDGenerator(root: root ?? UIDGenerator.defaultRoot)
        var mappings: [UIDMapping] = []

        // Process all UI (UID) elements
        for element in file.dataSet.allElements {
            if element.vr == .UI {
                if let uidString = file.dataSet.string(for: element.tag) {
                    let trimmed = uidString.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
                    if trimmed.isEmpty { continue }

                    // Skip well-known UIDs (transfer syntaxes, SOP classes)
                    if UIDDictionary.lookup(uid: trimmed) != nil {
                        continue
                    }

                    let newUID: String
                    if maintainRelationships, let existing = existingMappings[trimmed] {
                        newUID = existing
                    } else {
                        newUID = generator.generate().value
                        if maintainRelationships {
                            existingMappings[trimmed] = newUID
                        }
                    }

                    let tagName = Self.tagName(for: element.tag)
                    let tagHex = String(format: "%04X,%04X", element.tag.group, element.tag.element)

                    mappings.append(UIDMapping(
                        oldUID: trimmed,
                        newUID: newUID,
                        tagName: tagName,
                        tagHex: tagHex
                    ))

                    dataSet.setString(newUID, for: element.tag, vr: .UI)
                }
            }
        }

        // Use Secondary Capture Image Storage as fallback SOP Class when the original is missing,
        // since it is the most generic storage SOP Class for DICOM files
        let newFile = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.7"
        )
        let newData = try newFile.write()
        return (newData, mappings)
    }

    /// Regenerates UIDs in a DICOM file on disk (CLI convenience over `regenerateData`).
    @discardableResult
    public func regenerateUIDs(
        inputPath: String,
        outputPath: String?,
        root: String?,
        maintainRelationships: Bool,
        existingMappings: inout [String: String]
    ) throws -> [UIDMapping] {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw UIDManagerError.fileNotFound(inputPath)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let (newData, mappings) = try regenerateData(
            data, root: root, maintainRelationships: maintainRelationships, existingMappings: &existingMappings)

        let outPath = outputPath ?? inputPath
        try newData.write(to: URL(fileURLWithPath: outPath))

        return mappings
    }

    // MARK: - Helpers

    /// Gets a human-readable tag name
    public static func tagName(for tag: Tag) -> String {
        switch tag {
        case .sopInstanceUID: return "SOPInstanceUID"
        case .sopClassUID: return "SOPClassUID"
        case .studyInstanceUID: return "StudyInstanceUID"
        case .seriesInstanceUID: return "SeriesInstanceUID"
        case .instanceCreatorUID: return "InstanceCreatorUID"
        default:
            return String(format: "(%04X,%04X)", tag.group, tag.element)
        }
    }

    /// Gets a human-readable description of a UID type
    public static func uidTypeDescription(_ type: UIDType) -> String {
        switch type {
        case .transferSyntax: return "Transfer Syntax"
        case .sopClass: return "SOP Class"
        case .metaSOPClass: return "Meta SOP Class"
        case .wellKnown: return "Well-Known UID"
        case .ldap: return "LDAP OID"
        case .codingScheme: return "Coding Scheme"
        case .applicationContext: return "Application Context"
        }
    }
}
