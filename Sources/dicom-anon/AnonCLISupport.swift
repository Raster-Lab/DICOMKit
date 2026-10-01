// NEMA-verified: 2026a, checked 2026-10-01 — option names diffed against the 12 Options of PS3.15 2026a E.3 and the Table E.1-1 Option columns (7 offered here: Retain UIDs, Device Identity, Institution Identity, Patient Characteristics, Longitudinal Temporal Information With Full Dates / With Modified Dates (E.3.6, mutually exclusive), Clean Descriptors; Clean Pixel Data in main.swift); action labels are the 6 PS3.15 2026a Table E.1-1a single codes (K not listed: unchanged); names from PS3.6 2026a Table 6-1 via DataElementDictionary
import Foundation
import DICOMCore
import DICOMDictionary
import DICOMKit

/// The `dicom-anon` command surface that is not ArgumentParser plumbing: option
/// validation against PS3.15 Annex E, tag parsing, and the per-attribute action report.
enum AnonCLI {

    /// The PS3.15 E.3 option flags the command offers for `--profile ps315`.
    struct PS315Flags: Equatable {
        var retainDates = false
        var retainFullDates = false
        var retainModifiedDates = false
        var retainCharacteristics = false
        var retainDevice = false
        var retainInstitution = false
        var retainUids = false
        var cleanDescriptors = false

        /// Every flag that is set, by its command-line spelling.
        var setFlags: [String] {
            [("--retain-dates", retainDates), ("--retain-full-dates", retainFullDates),
             ("--retain-modified-dates", retainModifiedDates),
             ("--retain-characteristics", retainCharacteristics), ("--retain-device", retainDevice),
             ("--retain-institution", retainInstitution), ("--retain-uids", retainUids),
             ("--clean-descriptors", cleanDescriptors)].filter(\.1).map(\.0)
        }
    }

    /// The legacy profile values: fixed attribute lists, not PS3.15 Annex E.
    static let legacyProfiles: Set<String> = ["basic", "clinical-trial", "clinicaltrial", "research"]

    /// Rejects option combinations that the command would otherwise ignore silently.
    ///
    /// - The PS3.15 E.3 option flags act only on `--profile ps315`.
    /// - PS3.15 E.3.6: the Full Dates and Modified Dates options are mutually exclusive;
    ///   `--shift-dates` is how the dates are modified, so it needs the Modified Dates
    ///   option and is meaningless with Full Dates.
    /// - `--keep` is applied only by the legacy profiles.
    static func validate(profile: String, flags: PS315Flags, shiftDates: Int?,
                         regenerateUids: Bool, keep: [String]) throws {
        let isPS315 = profile.lowercased() == "ps315"
        guard isPS315 else {
            if !flags.setFlags.isEmpty {
                throw ValidationError(
                    "PS3.15 Annex E Option flags apply only to --profile ps315: \(flags.setFlags.joined(separator: ", "))")
            }
            return
        }
        if flags.retainFullDates && (flags.retainModifiedDates || shiftDates != nil) {
            throw ValidationError(
                "--retain-full-dates (Retain Longitudinal Temporal Information With Full Dates Option) "
                + "excludes --retain-modified-dates and --shift-dates (PS3.15 E.3.6: the two Options are mutually exclusive)")
        }
        if flags.retainModifiedDates && shiftDates == nil {
            throw ValidationError(
                "--retain-modified-dates (Retain Longitudinal Temporal Information With Modified Dates Option) "
                + "needs --shift-dates N: shifting is how the dates are modified")
        }
        if shiftDates != nil && !(flags.retainDates || flags.retainModifiedDates) {
            throw ValidationError(
                "--shift-dates with --profile ps315 needs --retain-modified-dates (or --retain-dates): "
                + "without a Retain Longitudinal Temporal Information Option the Basic Profile removes dates")
        }
        if regenerateUids && flags.retainUids {
            throw ValidationError("--regenerate-uids contradicts --retain-uids (Retain UIDs Option)")
        }
        if !keep.isEmpty {
            throw ValidationError(
                "--keep is not applied by --profile ps315; select a PS3.15 Option (--retain-*) instead")
        }
    }

    /// The engine options for `--profile ps315`.
    static func options(flags: PS315Flags, shiftDates: Int?) -> ConfidentialityProfile.Options {
        ConfidentialityProfile.Options(
            retainLongitudinalTemporal: flags.retainDates || flags.retainFullDates || flags.retainModifiedDates,
            retainPatientCharacteristics: flags.retainCharacteristics,
            retainDeviceIdentity: flags.retainDevice,
            retainInstitutionIdentity: flags.retainInstitution,
            retainUIDs: flags.retainUids,
            cleanDescriptors: flags.cleanDescriptors,
            dateOffsetDays: shiftDates)
    }

    /// Stderr notice for the legacy profiles, which are not PS3.15 Annex E.
    static func legacyProfileNotice(_ profile: String) -> String? {
        guard legacyProfiles.contains(profile.lowercased()) else { return nil }
        return "Note: --profile \(profile) is a legacy attribute list, not the PS3.15 Basic Application "
            + "Level Confidentiality Profile; it records no Patient Identity Removed (0012,0062). "
            + "Use --profile ps315 for PS3.15 Annex E de-identification."
    }

    /// A tag given to --remove / --replace / --keep: `gggg,eeee`, `(gggg,eeee)`,
    /// `ggggeeee`, or a PS3.6 Table 6-1 keyword (e.g. `PatientAge`).
    static func parseTag(_ string: String) -> Tag? {
        if let tag = Anonymizer.parseFlexibleTag(string) { return tag }
        let keyword = string.trimmingCharacters(in: .whitespaces)
        return DataElementDictionary.lookup(keyword: keyword)?.tag
    }

    /// Applies --remove / --replace after the PS3.15 pass (the engine takes no custom
    /// actions). A replacement is written only for an attribute present in the source,
    /// with the source VR, as the legacy path does.
    static func applyCustomActions(_ actions: [Tag: AnonymizationAction], source: DataSet,
                                   to dataSet: inout DataSet) {
        for (tag, action) in actions {
            switch action {
            case .remove:
                dataSet.remove(tag: tag)
            case .replaceWithDummy(let value):
                if let element = source[tag] { dataSet.setString(value, for: tag, vr: element.vr) }
            default:
                break
            }
        }
    }

    /// PS3.10 7.1: the file meta Media Storage SOP Instance UID (0002,0003) is the SOP
    /// Instance UID (0008,0018) of the data set. Applied to the output file, so a replaced
    /// (U) SOP Instance UID does not survive in the meta header.
    static func syncingMediaStorageSOPInstanceUID(_ file: DICOMFile) -> DICOMFile {
        guard let uid = file.dataSet.string(for: .sopInstanceUID)?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \0")), !uid.isEmpty,
              file.fileMetaInformation[.mediaStorageSOPInstanceUID] != nil else { return file }
        var meta = file.fileMetaInformation
        meta.setString(uid, for: .mediaStorageSOPInstanceUID, vr: .UI)
        return DICOMFile(fileMetaInformation: meta, dataSet: file.dataSet)
    }

    // MARK: - Per-attribute action report

    /// One top-level attribute the run changed, with the PS3.15 Table E.1-1a action code
    /// that describes what was done to it.
    struct AttributeAction: Equatable {
        let tag: Tag
        /// D, Z, X, C or U (Table E.1-1a), or "recorded" for the de-identification
        /// method / attestation attributes the run writes.
        let code: String
        /// PS3.6 Table 6-1 name.
        let name: String
    }

    /// The attributes the run writes to record what it did (PS3.15 E.1.1, E.3).
    static let recordingTags: Set<Tag> = [
        Tag(group: 0x0012, element: 0x0062), // Patient Identity Removed
        Tag(group: 0x0012, element: 0x0063), // De-identification Method
        Tag(group: 0x0012, element: 0x0064), // De-identification Method Code Sequence
        Tag(group: 0x0028, element: 0x0301), // Burned In Annotation
        Tag(group: 0x0028, element: 0x0302), // Recognizable Visual Features
        Tag(group: 0x0028, element: 0x0303), // Longitudinal Temporal Information Modified
    ]

    /// PS3.6 name of a tag; private and unknown tags are labelled as such.
    static func name(of tag: Tag) -> String {
        if tag.isPrivate { return "Private Data Element" }
        return DataElementDictionary.lookup(tag: tag)?.name ?? "(not in PS3.6)"
    }

    /// Compares the source and output data sets attribute by attribute (top level;
    /// Pixel Data and group 0002 excluded) and labels each change with its E.1-1a code.
    /// `options` is nil for the legacy profiles.
    static func attributeActions(before: DataSet, after: DataSet,
                                 options: ConfidentialityProfile.Options?) -> [AttributeAction] {
        var out: [AttributeAction] = []
        let tags = Set(before.tags).union(after.tags)
            .filter { $0 != .pixelData && $0.group != 0x0002 }
            .sorted { ($0.group, $0.element) < ($1.group, $1.element) }
        for tag in tags {
            let old = before[tag], new = after[tag]
            if let old, let new, fingerprint(old) == fingerprint(new) { continue }
            let code: String
            if recordingTags.contains(tag) {
                code = "recorded"
            } else if old == nil {
                code = "added"
            } else if let new {
                if isZeroLength(new) {
                    code = "Z"
                } else if let options, let applied = ConfidentialityProfile.action(for: tag, options: options),
                          applied == .clean
                            || (applied == .zeroOrDummy && options.retainLongitudinalTemporal
                                && options.dateOffsetDays != nil) {
                    code = "C"
                } else {
                    code = new.vr == .UI ? "U" : "D"
                }
            } else {
                code = "X"
            }
            out.append(AttributeAction(tag: tag, code: code, name: name(of: tag)))
        }
        return out
    }

    /// The action lines printed for one file (--dry-run or --verbose).
    static func actionLines(path: String, actions: [AttributeAction]) -> String {
        var s = "\nAttribute actions for \(path) (PS3.15 Table E.1-1a: D dummy, Z zero length, "
            + "X removed, C cleaned, U new UID):\n"
        if actions.isEmpty { s += "  (none)\n" }
        for a in actions { s += "  \(a.code.padding(toLength: 8, withPad: " ", startingAt: 0)) \(a.tag) \(a.name)\n" }
        return s
    }

    /// The --audit-log text for `--profile ps315`: one line per changed attribute with
    /// its E.1-1a code and PS3.6 name. Values are not written (the log must not itself
    /// carry the identifiers that were removed).
    static func auditLogText(profileDescription: [String], files: [(path: String, actions: [AttributeAction])],
                             generated: Date) -> String {
        let iso = ISO8601DateFormatter().string(from: generated)
        var text = "DICOM Anonymization Audit Log\nGenerated: \(iso)\n"
        text += "Method: \(profileDescription.joined(separator: "; "))\n\n"
        for file in files {
            for a in file.actions { text += "[\(iso)] \(file.path) - \(a.code) - \(a.tag) \(a.name)\n" }
        }
        return text
    }

    private static func isZeroLength(_ e: DataElement) -> Bool {
        if let items = e.sequenceItems { return items.isEmpty }
        return e.valueData.allSatisfy { $0 == 0x20 || $0 == 0x00 }
    }

    private static func fingerprint(_ e: DataElement) -> String {
        if let items = e.sequenceItems {
            return "SQ[" + items.map { item in
                item.allElements.sorted { ($0.tag.group, $0.tag.element) < ($1.tag.group, $1.tag.element) }
                    .map(fingerprint).joined(separator: ",")
            }.joined(separator: "|") + "]"
        }
        return "\(e.tag)\(e.vr):\(e.valueData.base64EncodedString())"
    }
}
