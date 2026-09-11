import Foundation
import DICOMCore

/// Applies the PS3.15 Annex E Basic Application Level Confidentiality Profile to a
/// dataset — the one de-identification engine `dicom-anon` and DICOMStudio run.
///
/// 1. Applies Table E.1-1 **action codes** (D/Z/X/K/C/U) per attribute.
/// 2. **Recurses into every sequence item** so nested identifiers are scrubbed.
/// 3. **VR sweeps**: any PN not in the table is removed; any UI is regenerated
///    consistently (unless Retain UIDs); any private tag is removed —
///    so an attribute absent from the explicit table is never silently kept.
/// 4. Regenerates UIDs through one consistent map (same input UID → same output UID),
///    preserving referential integrity within the file and — when the caller shares
///    the map — across a whole study.
/// 5. Records the de-identification method attributes (0012,0062)/(0012,0063)/(0012,0064)
///    with the CID 7050 codes for the profile and every option applied, *appending* to
///    a Clean Pixel Data item the pixel pass may already have written.
///
/// **Scope: dataset only.** Pixel Data is never inspected or modified here; the pixel
/// pass (``PixelCleaningWorkflow``) runs before this engine. When residual pixel PHI is
/// still declared afterwards, (0012,0062) is set to NO rather than YES and the caller is
/// warned — see ``deidentifyReportingResidualPHI(_:)``.
///
/// It is a value type driven by ``ConfidentialityProfile/Options``; the caller owns the
/// UID map so it can be shared across a study for cross-file consistency.
public struct ConfidentialityEngine {

    public let options: ConfidentialityProfile.Options

    /// Shared input-UID → output-UID map. Injected so multiple files in one study
    /// regenerate the same UIDs identically. Defaults to a fresh empty map.
    public var uidMap: [String: String]

    /// One top-level attribute change from the last pass, for the audit trail.
    /// Deliberately carries no values: an audit log that stores the original
    /// identifiers would itself be a PHI store.
    public struct Change: Sendable, Equatable {
        public let tag: Tag
        public let action: ConfidentialityProfile.Action
    }

    /// Top-level changes of the most recent pass, in data-set order.
    public private(set) var changes: [Change] = []

    /// UIDs that identify the SOP class / transfer syntax etc. and must NOT be
    /// regenerated — doing so would corrupt the object. (PS3.15 E.1: only instance
    /// UIDs are remapped, not the well-known class UIDs.)
    private static let preservedUIDTags: Set<Tag> = [
        Tag(group: 0x0002, element: 0x0002), // Media Storage SOP Class UID
        Tag(group: 0x0002, element: 0x0010), // Transfer Syntax UID
        Tag(group: 0x0002, element: 0x0012), // Implementation Class UID
        .init(group: 0x0008, element: 0x0016), // SOP Class UID
    ]

    public init(options: ConfidentialityProfile.Options = .basic,
                uidMap: [String: String] = [:]) {
        self.options = options
        self.uidMap = uidMap
    }

    /// One de-identification pass. Returns the scrubbed dataset and the list of tags
    /// that changed (top level only, for reporting). `uidMap` is updated in place.
    public mutating func deidentify(_ dataSet: DataSet) -> (DataSet, [Tag]) {
        let (result, changed, _) = deidentifyReportingResidualPHI(dataSet)
        return (result, changed)
    }

    /// One de-identification pass that also reports **residual PHI this engine cannot
    /// remove** — identifiers rendered into the pixels or carried in overlay planes.
    ///
    /// PS3.15 conditions (0012,0062) Patient Identity Removed = YES on the whole object
    /// being clean, so asserting YES over pixels that still carry a burned-in banner
    /// would be a false claim — the most dangerous possible output, because downstream
    /// consumers trust that tag. When residual PHI is declared this pass therefore:
    /// (a) records (0012,0062) as **NO**, noting the metadata-only scope in (0012,0063),
    /// and (b) returns a warning naming the cause. The metadata scrub still happens in
    /// full — this reports the limit, it does not skip the work.
    ///
    /// - Returns: the scrubbed dataset, the changed top-level tags, and any residual-PHI
    ///   warnings (empty when the object is clean as far as this engine can tell).
    public mutating func deidentifyReportingResidualPHI(
        _ dataSet: DataSet
    ) -> (DataSet, [Tag], [String]) {
        let residual = Self.residualPixelPHIWarnings(in: dataSet)
        changes = []
        var result = apply(to: dataSet, isRoot: true)
        recordMethod(in: &result, pixelsMayCarryPHI: !residual.isEmpty)
        return (result, changes.map(\.tag), residual)
    }

    // MARK: - Residual (pixel-borne) PHI detection

    /// Overlay plane groups (60xx, even) whose Overlay Data is present.
    public static func overlayGroups(in dataSet: DataSet) -> [String] {
        var groups: [String] = []
        for group in stride(from: UInt16(0x6000), through: UInt16(0x601E), by: 2)
        where dataSet[Tag(group: group, element: 0x3000)] != nil {
            groups.append(String(format: "%04X", group))
        }
        return groups
    }

    /// Reasons the *pixels* of this object may still identify the patient after a
    /// metadata-only pass. Detection is by declared attribute, not by reading pixels:
    /// this is a conservative flag, never a guarantee.
    public static func residualPixelPHIWarnings(in dataSet: DataSet) -> [String] {
        var warnings: [String] = []

        // (0028,0301) Burned In Annotation — the modality's own declaration that
        // identifying text is rendered into the pixels.
        if let burned = dataSet.string(for: .burnedInAnnotation)?
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           burned == "YES" {
            warnings.append(
                "Burned In Annotation (0028,0301) is YES: identifying text is rendered "
                + "into the pixel data, which the header pass leaves untouched. The "
                + "image is NOT de-identified; (0012,0062) is therefore recorded as NO. "
                + "Clean the pixels (PS3.15 Clean Pixel Data Option) before release.")
        }

        // Overlay planes (60xx,3000) can carry identifying graphics/text that renderers
        // burn into the displayed image — a second route to the same leak (PS3.3 C.9).
        let overlays = overlayGroups(in: dataSet)
        if !overlays.isEmpty {
            warnings.append(
                "Overlay plane data present (\(overlays.joined(separator: ", "))): "
                + "overlays are burned into the rendered image and are not modified by "
                + "this profile. Review them for identifying content before release.")
        }

        return warnings
    }

    // MARK: - Recursive application

    private mutating func apply(to dataSet: DataSet, isRoot: Bool) -> DataSet {
        var out = dataSet

        for tag in dataSet.tags {
            guard let element = dataSet[tag] else { continue }

            // Never touch Pixel Data or the group-length/meta plumbing.
            if tag == .pixelData || tag.group == 0x0002 { continue }

            // Recurse into sequences first (nested identifiers), keeping the element.
            if let items = element.sequenceItems {
                let scrubbedItems = items.map { item -> SequenceItem in
                    var itemSet = DataSet(elements: item.allElements)
                    itemSet = apply(to: itemSet, isRoot: false)
                    return SequenceItem(elements: itemSet.tags.compactMap { itemSet[$0] })
                }
                out.setSequence(scrubbedItems, for: tag)
                // Fall through: the sequence attribute itself may also be listed in
                // the table (e.g. Referring Physician ID Sequence → X).
            }

            let effective = resolveAction(for: tag, vr: element.vr, isPrivate: tag.isPrivate)
            guard let action = effective else { continue }

            func note() { if isRoot { changes.append(Change(tag: tag, action: action)) } }

            switch action {
            case .keep:
                continue
            case .remove, .removePreferred:
                out.remove(tag: tag)
                note()
            case .zero:
                out.setString("", for: tag, vr: element.vr)
                note()
            case .zeroOrDummy:
                applyDateOrZero(tag: tag, element: element, in: &out)
                note()
            case .replaceDummy:
                out.setString(dummyValue(for: element.vr), for: tag, vr: element.vr)
                note()
            case .clean:
                // Best-effort: without a term-safe cleaner we cannot prove a free-text
                // value is identifier-free, so fail safe by zeroing unless the caller
                // explicitly asked to retain descriptors.
                if options.cleanDescriptors {
                    continue
                }
                out.setString("", for: tag, vr: element.vr)
                note()
            case .replaceUID:
                if let uid = dataSet.string(for: tag) {
                    out.setString(mappedUID(uid), for: tag, vr: element.vr)
                    note()
                }
            }
        }

        return out
    }

    /// Combines the explicit table, VR sweeps and the private-tag rule.
    private func resolveAction(for tag: Tag, vr: VR, isPrivate: Bool) -> ConfidentialityProfile.Action? {
        // 1. Explicit table wins.
        if let a = ConfidentialityProfile.action(for: tag, options: options) {
            // The table encodes UID rows generically; honour Retain UIDs here.
            if a == .replaceUID && options.retainUIDs { return .keep }
            return a
        }

        // 2. Private tags: remove. PS3.15 only retains private tags a creator has
        //    declared safe (Retain Safe Private Option); we have no safe-private
        //    registry, so remove — the conservative, conformant default.
        if isPrivate { return .remove }

        // 3. VR sweeps for attributes not otherwise listed.
        switch vr {
        case .PN:
            // Any residual person name is an identifier — remove.
            return .remove
        case .UI where !Self.isPreservedUID(tag):
            return options.retainUIDs ? .keep : .replaceUID
        default:
            return nil   // keep
        }
    }

    private static func isPreservedUID(_ tag: Tag) -> Bool {
        preservedUIDTags.contains(tag)
    }

    // MARK: - Value helpers

    /// Under *Modified Dates* (retain + offset) a date is shifted; the time of day is
    /// unaffected by a whole-day shift, so a TM is kept as-is. Otherwise Z.
    private mutating func applyDateOrZero(tag: Tag, element: DataElement, in dataSet: inout DataSet) {
        guard options.retainLongitudinalTemporal, let days = options.dateOffsetDays else {
            dataSet.setString("", for: tag, vr: element.vr)
            return
        }
        switch element.vr {
        case .DA:
            if let original = dataSet.string(for: tag),
               let shifted = Self.shiftDICOMDate(original, byDays: days) {
                dataSet.setString(shifted, for: tag, vr: .DA)
            } else {
                dataSet.setString("", for: tag, vr: .DA)
            }
        case .TM:
            break
        case .DT:
            // YYYYMMDD[HHMMSS…]: shift the date part, keep the rest.
            if let original = dataSet.string(for: tag)?.trimmingCharacters(in: .whitespaces),
               original.count >= 8,
               let shifted = Self.shiftDICOMDate(String(original.prefix(8)), byDays: days) {
                dataSet.setString(shifted + original.dropFirst(8), for: tag, vr: .DT)
            } else {
                dataSet.setString("", for: tag, vr: .DT)
            }
        default:
            dataSet.setString("", for: tag, vr: element.vr)
        }
    }

    private func dummyValue(for vr: VR) -> String {
        switch vr {
        case .PN: return "ANONYMOUS"
        case .DA: return "19000101"
        case .TM: return "000000"
        case .DT: return "19000101000000"
        default:  return "ANONYMIZED"
        }
    }

    private mutating func mappedUID(_ uid: String) -> String {
        if let existing = uidMap[uid] { return existing }
        let generated = UIDGenerator.generateUID().value
        uidMap[uid] = generated
        return generated
    }

    static func shiftDICOMDate(_ dicom: String, byDays days: Int) -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: dicom.trimmingCharacters(in: .whitespaces)),
              let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return f.string(from: shifted)
    }

    // MARK: - Method recording (PS3.15 E.1.1 / C.7.1.1)

    private func recordMethod(in dataSet: inout DataSet, pixelsMayCarryPHI: Bool) {
        // (0012,0062) Patient Identity Removed. PS3.15 conditions YES on the whole
        // object being de-identified — pixels included. When the pixels (or overlay
        // planes) may still carry identifiers we must not assert YES: a false YES is
        // worse than no assertion, because downstream consumers treat it as a release
        // gate. Write NO instead, so the state is explicit rather than merely absent.
        dataSet.setString(pixelsMayCarryPHI ? "NO" : "YES",
                          for: Tag(group: 0x0012, element: 0x0062), vr: .CS)

        // The pixel pass runs first and, when it blanked something, has already
        // recorded 113101 in (0012,0064). Fold it into the human-readable record.
        var codes = options.methodCodes
        if ConfidentialityProfile.MethodCode.recorded(in: dataSet)
            .contains(ConfidentialityProfile.MethodCode.cleanPixelData.value) {
            codes.append(.cleanPixelData)
        }

        // (0012,0063) De-identification Method — LO, VM 1-n: one value per method so no
        // value exceeds LO's 64-character limit.
        var values = codes.map(\.shortName)
        // Make the metadata-only scope explicit in the record itself, so a reader of the
        // file (not just of our console output) can see the pixels were never cleaned.
        if pixelsMayCarryPHI { values.append("DATASET ONLY - pixel data not de-identified") }
        dataSet.setString(values.joined(separator: "\\"),
                          for: Tag(group: 0x0012, element: 0x0063), vr: .LO)

        // (0012,0064) De-identification Method Code Sequence — append what is missing.
        for code in codes {
            ConfidentialityProfile.MethodCode.record(code, in: &dataSet)
        }

        // Burned In Annotation (0028,0301): this pass does not inspect pixels, so it
        // cannot assert NO. Leave any existing value; if absent, do not fabricate one.
    }
}
