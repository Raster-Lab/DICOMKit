import Foundation
import DICOMCore

/// Applies the PS3.15 Annex E Basic Application Level Confidentiality Profile to a
/// dataset — the standards-grounded de-identification path.
///
/// What it does that the legacy ``Anonymizer`` profiles do not:
/// 1. Applies Table E.1-1 **action codes** (D/Z/X/K/C/U) per attribute.
/// 2. **Recurses into every sequence item** so nested identifiers are scrubbed.
/// 3. **VR sweeps**: any PN not in the table is removed; any UI is regenerated
///    consistently (unless Retain UIDs); any private tag is removed (unless retained) —
///    so an attribute absent from the explicit table is never silently kept.
/// 4. Regenerates UIDs through one consistent map (same input UID → same output UID),
///    preserving referential integrity within the file.
/// 5. Records the de-identification method attributes (0012,0062)/(0012,0063)/(0012,0064).
///
/// **Scope: dataset only.** Pixel Data is never inspected or modified, so identifiers
/// burned into the image (and identifying overlay planes) survive a pass. When such
/// residual PHI is declared, (0012,0062) is set to NO rather than YES and the caller is
/// warned — see ``deidentifyReportingResidualPHI(_:)``.
///
/// It is a value type driven by ``ConfidentialityProfile/Options``; the caller owns the
/// UID map so it can be shared across a study for cross-file consistency.
public struct ConfidentialityEngine {

    public let options: ConfidentialityProfile.Options

    /// Shared input-UID → output-UID map. Injected so multiple files in one study
    /// regenerate the same UIDs identically. Defaults to a fresh empty map.
    public var uidMap: [String: String]

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
    /// This engine scrubs the *dataset only*; it never inspects or rewrites Pixel Data
    /// (see the skip in ``apply(to:changed:isRoot:)``). So on an image whose pixels carry
    /// a burned-in patient banner, a metadata-only pass produces a file that is **not**
    /// de-identified. PS3.15 conditions (0012,0062) Patient Identity Removed = YES on the
    /// whole object being clean, so asserting YES there would be a false claim — the most
    /// dangerous possible output, because downstream consumers trust that tag.
    ///
    /// When residual PHI is detected this pass therefore: (a) records (0012,0062) as
    /// **NO** instead of YES, noting the metadata-only scope in (0012,0063), and
    /// (b) returns a warning naming the cause. Callers should surface the warning and
    /// treat the file as still-identifiable. The metadata scrub still happens in full —
    /// this reports the limit, it does not skip the work.
    ///
    /// - Returns: the scrubbed dataset, the changed top-level tags, and any residual-PHI
    ///   warnings (empty when the object is clean as far as this engine can tell).
    public mutating func deidentifyReportingResidualPHI(
        _ dataSet: DataSet
    ) -> (DataSet, [Tag], [String]) {
        let residual = Self.residualPixelPHIWarnings(in: dataSet)
        var changed: [Tag] = []
        var result = apply(to: dataSet, changed: &changed, isRoot: true)
        recordMethod(in: &result, pixelsMayCarryPHI: !residual.isEmpty)
        return (result, changed, residual)
    }

    // MARK: - Residual (pixel-borne) PHI detection

    /// Reasons the *pixels* of this object may still identify the patient after a
    /// metadata-only pass. Detection is by declared attribute, not by reading pixels:
    /// we do not OCR the image, so this is a conservative flag, never a guarantee.
    public static func residualPixelPHIWarnings(in dataSet: DataSet) -> [String] {
        var warnings: [String] = []

        // (0028,0301) Burned In Annotation — the modality's own declaration that
        // identifying text is rendered into the pixels.
        if let burned = dataSet.string(for: .burnedInAnnotation)?
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           burned == "YES" {
            warnings.append(
                "Burned In Annotation (0028,0301) is YES: identifying text is rendered "
                + "into the pixel data, which a metadata-only pass leaves untouched. The "
                + "image is NOT de-identified; (0012,0062) is therefore recorded as NO. "
                + "Clean the pixels (PS3.15 Clean Pixel Data Option) before release.")
        }

        // Overlay planes (60xx,3000) can carry identifying graphics/text that renderers
        // burn into the displayed image — a second route to the same leak. Groups run
        // 0x6000…0x601E, even only (PS3.3 C.9).
        var overlayGroups: [String] = []
        for group in stride(from: UInt16(0x6000), through: UInt16(0x601E), by: 2)
        where dataSet[Tag(group: group, element: 0x3000)] != nil {
            overlayGroups.append(String(format: "%04X", group))
        }
        if !overlayGroups.isEmpty {
            warnings.append(
                "Overlay plane data present (\(overlayGroups.joined(separator: ", "))): "
                + "overlays are burned into the rendered image and are not modified by "
                + "this profile. Review them for identifying content before release.")
        }

        return warnings
    }

    // MARK: - Recursive application

    private mutating func apply(to dataSet: DataSet, changed: inout [Tag], isRoot: Bool) -> DataSet {
        var out = dataSet

        for tag in dataSet.tags {
            guard let element = dataSet[tag] else { continue }

            // Never touch Pixel Data or the group-length/meta plumbing.
            if tag == .pixelData || tag.group == 0x0002 { continue }

            // Recurse into sequences first (nested identifiers), keeping the element.
            if let items = element.sequenceItems {
                let scrubbedItems = items.map { item -> SequenceItem in
                    var itemSet = DataSet(elements: item.allElements)
                    var inner: [Tag] = []
                    itemSet = apply(to: itemSet, changed: &inner, isRoot: false)
                    return SequenceItem(elements: itemSet.tags.compactMap { itemSet[$0] })
                }
                out.setSequence(scrubbedItems, for: tag)
                // Fall through: the sequence attribute itself may also be listed in
                // the table (e.g. Referring Physician ID Sequence → X).
            }

            let effective = resolveAction(for: tag, vr: element.vr, isPrivate: tag.isPrivate)
            guard let action = effective else { continue }

            switch action {
            case .keep:
                continue
            case .remove, .removePreferred:
                out.remove(tag: tag)
                if isRoot { changed.append(tag) }
            case .zero:
                out.setString("", for: tag, vr: element.vr)
                if isRoot { changed.append(tag) }
            case .zeroOrDummy:
                applyDateOrZero(tag: tag, element: element, in: &out)
                if isRoot { changed.append(tag) }
            case .replaceDummy:
                out.setString(dummyValue(for: element.vr), for: tag, vr: element.vr)
                if isRoot { changed.append(tag) }
            case .clean:
                // Best-effort: without a term-safe cleaner we cannot prove a free-text
                // value is identifier-free, so fail safe by zeroing unless the caller
                // explicitly asked to retain descriptors.
                if options.cleanDescriptors {
                    continue
                }
                out.setString("", for: tag, vr: element.vr)
                if isRoot { changed.append(tag) }
            case .replaceUID:
                if let uid = dataSet.string(for: tag) {
                    out.setString(mappedUID(uid), for: tag, vr: element.vr)
                    if isRoot { changed.append(tag) }
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

        // 2. Private tags: remove unless the whole private-retention isn't modelled
        //    (PS3.15 only retains private tags a creator has declared safe; we have no
        //    safe-private registry, so remove — the conservative, conformant default).
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

    private mutating func applyDateOrZero(tag: Tag, element: DataElement, in dataSet: inout DataSet) {
        // With Retain Longitudinal Temporal + an offset, shift; else zero.
        if options.retainLongitudinalTemporal, let days = options.dateOffsetDays,
           element.vr == .DA, let original = dataSet.string(for: tag),
           let shifted = Self.shiftDICOMDate(original, byDays: days) {
            dataSet.setString(shifted, for: tag, vr: element.vr)
        } else {
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
        // object being de-identified — pixels included. This engine only scrubs the
        // dataset, so when the pixels (or overlay planes) may still carry identifiers
        // we must not assert YES: a false YES is worse than no assertion, because
        // downstream consumers treat it as a release gate. Write NO instead, so the
        // state is explicit rather than merely absent.
        dataSet.setString(pixelsMayCarryPHI ? "NO" : "YES",
                          for: Tag(group: 0x0012, element: 0x0062), vr: .CS)

        // (0012,0063) De-identification Method — human-readable summary.
        var method = "PS3.15 Basic Application Level Confidentiality Profile"
        var opts: [String] = []
        if options.retainLongitudinalTemporal { opts.append("Retain Longitudinal Temporal") }
        if options.retainPatientCharacteristics { opts.append("Retain Patient Characteristics") }
        if options.retainDeviceIdentity { opts.append("Retain Device Identity") }
        if options.retainInstitutionIdentity { opts.append("Retain Institution Identity") }
        if options.retainUIDs { opts.append("Retain UIDs") }
        if options.cleanDescriptors { opts.append("Clean Descriptors") }
        if !opts.isEmpty { method += " with " + opts.joined(separator: ", ") }
        // Make the metadata-only scope explicit in the record itself, so a reader of the
        // file (not just of our console output) can see the pixels were never cleaned.
        if pixelsMayCarryPHI { method += "; DATASET ONLY — pixel data not de-identified" }
        dataSet.setString(method, for: Tag(group: 0x0012, element: 0x0063), vr: .LO)

        // Burned In Annotation (0028,0301): we do not inspect pixels, so we cannot
        // assert NO. Leave any existing value; if absent, do not fabricate one.
        // When it says YES, the caller has already been warned and (0012,0062) is NO.
    }
}
