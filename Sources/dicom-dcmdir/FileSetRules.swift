// NEMA-verified: 2026a, checked 2026-10-01 — File ID and File-set ID rules of PS3.10 2026a 8.1 (File-set ID 0-16 characters), 8.2 (1-8 components of 1-8 characters), 8.5 (A-Z, 0-9, _), 8.6 (no File outside the File-set); PS3.3 2026a Table F.3-2 File-set ID (0004,1130), Table F.3-3 Referenced File ID (0004,1500) (each File referenced by at most one Directory Record) and Referenced SOP Instance UID in File (0004,1511), Table F.4-1 (record hierarchy); every rule text extracted from the DocBook by script
import Foundation
import DICOMCore

/// The PS3.10 / PS3.3 rules `dicom-dcmdir validate` checks on top of
/// `DICOMDirectory.validate`, and the clause each failure names.
enum FileSetRules {

    /// PS3.10 8.5: File IDs and File-set IDs use A-Z, 0-9 and underscore only
    /// (the CS repertoire without SPACE).
    static let allowedCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
    /// PS3.10 8.2: a File ID has one to eight components.
    static let maxFileIDComponents = 8
    /// PS3.10 8.2: each component is one to eight characters.
    static let maxComponentLength = 8
    /// PS3.10 8.1: a File-set ID is zero to sixteen characters.
    static let maxFileSetIDLength = 16

    static let fileIDRule = "PS3.10 8.2, 8.5; PS3.3 Table F.3-3 Referenced File ID (0004,1500)"
    static let fileSetIDRule = "PS3.10 8.1, 8.5; PS3.3 Table F.3-2 File-set ID (0004,1130)"

    /// Violations of PS3.10 8.2 / 8.5 for one Referenced File ID (its components).
    static func fileIDViolations(_ components: [String]) -> [String] {
        let shown = components.joined(separator: "\\")
        var out: [String] = []
        if components.isEmpty || components.count > maxFileIDComponents {
            out.append("File ID \(shown) has \(components.count) components; a File ID has 1 to \(maxFileIDComponents) [\(fileIDRule)]")
        }
        for component in components {
            if component.isEmpty || component.count > maxComponentLength {
                out.append("File ID component '\(component)' of \(shown) has \(component.count) characters; each component has 1 to \(maxComponentLength) [\(fileIDRule)]")
            }
            if !component.allSatisfy({ allowedCharacters.contains($0) }) {
                out.append("File ID component '\(component)' of \(shown) uses characters other than A-Z, 0-9 and _ [\(fileIDRule)]")
            }
        }
        return out
    }

    /// Violations of PS3.10 8.1 / 8.5 for a File-set ID (an empty ID is allowed: Type 2).
    static func fileSetIDViolations(_ id: String) -> [String] {
        var out: [String] = []
        if id.count > maxFileSetIDLength {
            out.append("File-set ID '\(id)' has \(id.count) characters; at most \(maxFileSetIDLength) [\(fileSetIDRule)]")
        }
        if !id.allSatisfy({ allowedCharacters.contains($0) }) {
            out.append("File-set ID '\(id)' uses characters other than A-Z, 0-9 and _ [\(fileSetIDRule)]")
        }
        return out
    }

    /// The File-set ID `create` derives from the input directory name when
    /// `--file-set-id` is not given: upper-cased, every character outside the
    /// PS3.10 8.5 set replaced by `_`, cut to 16 characters (PS3.10 8.1).
    static func defaultFileSetID(fromDirectoryName name: String) -> String {
        let mapped = name.uppercased().map { allowedCharacters.contains($0) ? $0 : "_" }
        return String(String(mapped).prefix(maxFileSetIDLength))
    }

    /// The clause a `DICOMDirectory.ValidationError` breaks.
    static func citation(for error: DICOMDirectory.ValidationError) -> String {
        switch error {
        case .invalidFileSetID:
            return fileSetIDRule
        case .invalidHierarchy, .invalidRecordTypeInHierarchy:
            return "PS3.3 F.4, Table F.4-1"
        case .missingReferencedFile:
            return "PS3.10 8.6; PS3.3 Table F.3-3 Referenced File ID (0004,1500)"
        case .invalidSOPInstanceUID:
            return "PS3.5 9.1; PS3.3 Table F.3-3 Referenced SOP Instance UID in File (0004,1511)"
        case .duplicateSOPInstanceUID:
            return "PS3.3 Table F.3-3 Referenced SOP Instance UID in File (0004,1511); PS3.5 9"
        }
    }

    /// Text for any error thrown while reading or validating: the `description` of a
    /// `CustomStringConvertible` error (a plain Swift error's `localizedDescription` is
    /// only "The operation couldn't be completed"), with the clause for validation errors.
    static func describe(_ error: Error) -> String {
        if let v = error as? DICOMDirectory.ValidationError {
            return "\(v.description) [\(citation(for: v))]"
        }
        if !(type(of: error) is NSError.Type), let d = error as? CustomStringConvertible {
            return d.description
        }
        return error.localizedDescription
    }

    /// Every File ID / File-set ID finding for a directory. With `checkFiles`, each
    /// Referenced File ID must also name an existing file under `mediaFolder` (PS3.10 8.6).
    static func findings(for directory: DICOMDirectory, mediaFolder: URL?, checkFiles: Bool) -> [String] {
        var out = fileSetIDViolations(directory.fileSetID)
        var seen: [String: Int] = [:]
        for record in directory.allRecords() {
            guard let components = record.referencedFileID, !components.isEmpty else { continue }
            out += fileIDViolations(components)
            let key = components.joined(separator: "\\")
            seen[key, default: 0] += 1
            if seen[key] == 2 {
                out.append("File ID \(key) is referenced by more than one Directory Record; any File shall be referenced by at most one [PS3.3 Table F.3-3 Referenced File ID (0004,1500)]")
            }
            if checkFiles, let mediaFolder {
                let url = components.reduce(mediaFolder) { $0.appendingPathComponent($1) }
                if !FileManager.default.fileExists(atPath: url.path) {
                    out.append("Referenced File ID \(key) does not exist in the File-set [PS3.10 8.6; PS3.3 Table F.3-3 Referenced File ID (0004,1500)]")
                }
            }
        }
        return out
    }
}
