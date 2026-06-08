import Foundation
import DICOMCore
import DICOMDictionary

/// Errors for tag-editing operations.
///
/// The engine itself never throws on an unresolved tag (it skips with a
/// description, see ``TagEditor/applyChanges(to:sets:deletes:deletePrivate:sourceDataSet:copyTags:verbose:dryRun:)``);
/// these cases are for adapters that want to fail fast on missing files or an
/// empty operation list.
public enum TagEditorError: Error, LocalizedError {
    case fileNotFound(String)
    case noOperationsSpecified
    case writeError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .noOperationsSpecified:
            return "No operations specified. Use --set, --delete, --delete-private, or --copy-from"
        case .writeError(let msg):
            return "Write error: \(msg)"
        }
    }
}

/// Core tag-editing engine: parses tag specifiers and applies set / delete /
/// delete-private / copy operations to a `DataSet`.
///
/// Tag names and VRs are resolved through `DataElementDictionary` (the full DICOM
/// data dictionary), and an unresolved specifier is skipped with a note rather
/// than aborting the whole edit — so one bad tag never discards otherwise-valid
/// changes. Shared by the `dicom-tags` CLI and DICOMStudio so they cannot drift.
public struct TagEditor {

    public init() {}

    /// Parse a tag specifier: `PatientName`, `0010,0010`, `(0010,0010)`, or `00100010`.
    /// Returns `nil` for an unresolved name or malformed hex.
    public func parseTagSpecifier(_ spec: String) -> Tag? {
        let t = spec.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        if t.contains(",") {
            let parts = t.split(separator: ",")
            if parts.count == 2,
               let g = UInt16(parts[0].trimmingCharacters(in: .whitespaces), radix: 16),
               let e = UInt16(parts[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                return Tag(group: g, element: e)
            }
        } else if t.count == 8, t.allSatisfy({ $0.isHexDigit }), let v = UInt32(t, radix: 16) {
            return Tag(group: UInt16((v >> 16) & 0xFFFF), element: UInt16(v & 0xFFFF))
        }
        // Tag-name lookup via the full DICOM dictionary.
        return DataElementDictionary.lookup(keyword: t)?.tag
    }

    /// Apply all tag operations to `dataSet`, returning a human-readable
    /// description of each change. Order matches `dicom-tags`: deletes, then
    /// delete-private, then copies, then sets (so `--set` overrides a copied
    /// value). Unknown/invalid specifiers are skipped with a note.
    ///
    /// - Parameters:
    ///   - copyTags: tag specifiers to copy from `sourceDataSet`; empty means copy
    ///     every tag in the source.
    ///   - verbose: when deleting private tags, list each one instead of a count.
    ///   - dryRun: compute and describe changes without mutating `dataSet`.
    public func applyChanges(
        to dataSet: inout DataSet,
        sets: [String],
        deletes: [String],
        deletePrivate: Bool,
        sourceDataSet: DataSet?,
        copyTags: [String],
        verbose: Bool,
        dryRun: Bool
    ) -> [String] {
        var descriptions: [String] = []

        // 1. Deletes
        for deleteSpec in deletes {
            if let tag = parseTagSpecifier(deleteSpec) {
                let label = self.label(for: tag)
                if dataSet[tag] != nil {
                    if !dryRun { dataSet.remove(tag: tag) }
                    descriptions.append("DELETE \(label)")
                } else {
                    descriptions.append("DELETE \(label) (not present, skipped)")
                }
            } else {
                descriptions.append("DELETE \(deleteSpec) (unknown tag, skipped)")
            }
        }

        // 2. Delete private tags
        if deletePrivate {
            var removed = 0
            for tag in dataSet.tags where tag.isPrivate {
                if !dryRun { dataSet.remove(tag: tag) }
                removed += 1
                if verbose { descriptions.append("DELETE private tag \(self.label(for: tag))") }
            }
            if !verbose { descriptions.append("DELETE \(removed) private tag(s)") }
        }

        // 3. Copy tags from source
        if let source = sourceDataSet {
            let tagsToCopy: [Tag] = copyTags.isEmpty
                ? source.tags
                : copyTags.compactMap { parseTagSpecifier($0) }
            for tag in tagsToCopy {
                if let element = source[tag] {
                    let label = self.label(for: tag)
                    if !dryRun { dataSet[tag] = element }
                    let value = element.stringValue ?? "<binary>"
                    descriptions.append("COPY \(label) = \(value)")
                }
            }
        }

        // 4. Set values (last, so they override copies)
        for setSpec in sets {
            if let eqRange = setSpec.range(of: "=") {
                let tagPart   = String(setSpec[..<eqRange.lowerBound])
                let valuePart = String(setSpec[eqRange.upperBound...])
                if let tag = parseTagSpecifier(tagPart) {
                    let label = self.label(for: tag)
                    let vr = dataSet[tag]?.vr ?? defaultVR(for: tag)
                    if !dryRun { dataSet.setString(valuePart, for: tag, vr: vr) }
                    descriptions.append("SET \(label) = \(valuePart)")
                } else {
                    descriptions.append("SET \(tagPart) (unknown tag, skipped)")
                }
            } else {
                descriptions.append("SET \(setSpec) (invalid format, expected TagName=Value)")
            }
        }

        return descriptions
    }

    // MARK: - Helpers

    /// `(GGGG,EEEE) Name` using the dictionary name when known, else just the hex.
    private func label(for tag: Tag) -> String {
        let hex = tag.description
        if let name = DataElementDictionary.lookup(tag: tag)?.name {
            return "\(hex) \(name)"
        }
        return hex
    }

    /// VR for a new tag: the dictionary default, else `.LO`.
    private func defaultVR(for tag: Tag) -> VR {
        DataElementDictionary.lookup(tag: tag)?.vr.first ?? .LO
    }
}
