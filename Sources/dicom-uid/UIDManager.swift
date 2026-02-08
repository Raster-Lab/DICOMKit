import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Errors for UID management operations
enum UIDManagerError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidUID(String, String)
    case noUIDsFound(String)
    case writeError(String)

    var description: String {
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
struct UIDValidationResult {
    let uid: String
    let isValid: Bool
    let errors: [String]
    let registryName: String?
}

/// UID mapping entry for old-to-new UID tracking
struct UIDMapping: Codable {
    let oldUID: String
    let newUID: String
    let tagName: String
    let tagHex: String
}

/// Manager for UID operations
struct UIDManager {

    // MARK: - UID Generation

    /// Generates UIDs with the specified root
    func generateUIDs(count: Int, root: String?, type: String?) -> [String] {
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
    func validateUID(_ uidString: String) -> UIDValidationResult {
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
    func validateFileUIDs(path: String) throws -> [UIDValidationResult] {
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
    func lookupUID(_ uidString: String) -> (name: String, type: String)? {
        if let entry = UIDDictionary.lookup(uid: uidString) {
            return (name: entry.name, type: Self.uidTypeDescription(entry.type))
        }
        return nil
    }

    // MARK: - UID Regeneration

    /// UID tags that should be regenerated
    static let uidTags: [(tag: Tag, name: String)] = [
        (.sopInstanceUID, "SOPInstanceUID"),
        (.studyInstanceUID, "StudyInstanceUID"),
        (.seriesInstanceUID, "SeriesInstanceUID"),
    ]

    /// Regenerates UIDs in a DICOM file
    func regenerateUIDs(
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
        let file = try DICOMFile.read(from: data)
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

        // Write the modified file
        let outPath = outputPath ?? inputPath
        let newFile = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.7"
        )
        let newData = try newFile.write()
        try newData.write(to: URL(fileURLWithPath: outPath))

        return mappings
    }

    // MARK: - Helpers

    /// Gets a human-readable tag name
    static func tagName(for tag: Tag) -> String {
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
    static func uidTypeDescription(_ type: UIDType) -> String {
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
