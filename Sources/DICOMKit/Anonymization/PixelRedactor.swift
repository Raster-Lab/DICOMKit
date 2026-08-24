import Foundation
import DICOMCore

/// Blanks burned-in identifiers out of Pixel Data and records the PS3.15 attestation.
///
/// ## What "cleaned" means here
///
/// PS3.15 E.3 is explicit that the Clean Pixel Data Option requires the **actual pixel
/// values** to be altered. Obscuring with an overlay, a display shutter, or a
/// presentation-state graphic does not qualify — the identifying bytes remain in the
/// file. Nor does cropping (it changes the image geometry rather than blanking), nor
/// modifying JPEG coefficients in place (that blurs rather than blanks). This type
/// decodes to native samples, overwrites the region, and re-emits uncompressed.
///
/// ## The attestation is earned, not assumed
///
/// (0028,0301) Burned In Annotation → `NO` and DCM **113101** "Clean Pixel Data Option"
/// in (0012,0064) are written *only* when regions were actually blanked. No surveyed
/// toolkit does this: DCMTK defines 113101 as a string constant with no behaviour,
/// dcm4che has the option commented out, fo-dicom omits the sequence entirely.
/// Stamping it on a pass-through file would be the same false-confidence bug the
/// (0012,0062) guard exists to prevent.
public struct PixelRedactor {

    /// What a redaction run did, for the console and the audit trail.
    public struct Outcome: Sendable, Equatable {
        /// Regions actually blanked.
        public let regions: [PixelRedactionPlan.Region]
        /// How the regions were chosen.
        public let basis: PixelRedactionPlan.Basis
        /// Provenance detail (template note, or the derivation used).
        public let note: String
        /// Frames blanked — every frame is redacted, never just the first.
        public let frameCount: Int
        /// True when an Icon Image Sequence was removed rather than re-derived.
        public let removedIconImage: Bool
        /// True when overlay plane elements were removed.
        public let removedOverlays: Bool
    }

    public init() {}

    /// Executes a plan against DICOM file bytes, returning redacted bytes.
    ///
    /// - Important: run this **before** header de-identification. The plan reads
    ///   Manufacturer / model / Modality to choose regions, and de-identification
    ///   removes those attributes. CTP and Presidio document the same dependency.
    ///
    /// - Returns: the redacted DICOM bytes and what was done, or `nil` when the plan
    ///   required no pixel work.
    /// - Throws: ``PixelRedactionError/unresolvedRegion(_:)`` when the plan could not
    ///   locate the burned-in content — a refusal, never a silent pass-through.
    public func redact(
        fileData: Data,
        plan: PixelRedactionPlan,
        fillValue: Int? = nil
    ) throws -> (data: Data, outcome: Outcome)? {
        switch plan.decision {
        case .nothingToDo:
            return nil

        case .unresolved(let reason):
            throw PixelRedactionError.unresolvedRegion(reason)

        case .redact(let regions, let basis):
            return try apply(regions: regions, basis: basis,
                             to: fileData, fillValue: fillValue)
        }
    }

    // MARK: - Application

    private func apply(
        regions: [PixelRedactionPlan.Region],
        basis: PixelRedactionPlan.Basis,
        to fileData: Data,
        fillValue: Int?
    ) throws -> (data: Data, outcome: Outcome) {
        let sourceFile = try DICOMFile.read(from: fileData)
        let note = provenanceNote(basis: basis, dataSet: sourceFile.dataSet)
        let frameCount = max(1, sourceFile.dataSet.numberOfFrames ?? 1)

        // Blank via the shared PixelEditor so the CLI, Studio and this path run one
        // masking implementation. It decodes encapsulated sources to native samples
        // and masks the region on *every* frame.
        let editor = PixelEditor(verbose: false)
        let operations = regions.map {
            PixelOperation.mask(x: $0.x, y: $0.y, width: $0.width, height: $0.height,
                                fillValue: fillValue ?? 0)
        }
        let (maskedData, _) = try editor.processData(fileData, operations: operations)

        // Re-read so the attestation is written onto the masked result.
        var file = try DICOMFile.read(from: maskedData)
        var dataSet = file.dataSet

        // A thumbnail derived before cleaning still shows the identifiers. PS3.15 notes
        // the icon may be cleaned or recreated; removing it is the safe option, since
        // re-deriving one here would need a render policy this type should not own.
        let removedIcon = dataSet[.iconImageSequence] != nil
        if removedIcon { dataSet.remove(tag: .iconImageSequence) }

        // Overlay planes are burned into the rendered image by viewers and the film
        // path, so identifying overlay graphics survive pixel masking. Remove the
        // plane elements outright (PS3.15 Clean Graphics territory).
        let removedOverlays = removeOverlayPlanes(from: &dataSet)

        recordAttestation(in: &dataSet)

        file = DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: dataSet)
        let outcome = Outcome(
            regions: regions, basis: basis, note: note, frameCount: frameCount,
            removedIconImage: removedIcon, removedOverlays: removedOverlays)
        return (try file.write(), outcome)
    }

    private func provenanceNote(basis: PixelRedactionPlan.Basis, dataSet: DataSet) -> String {
        switch basis {
        case .explicit:
            return "caller-specified region"
        case .keepRegionInversion:
            return "inverted from Sequence of Ultrasound Regions (0018,6011) — "
                + "blanked everything outside the declared scan area"
        case .deviceTemplate:
            return DeviceRedactionTemplates.matchNote(for: dataSet) ?? "device template"
        }
    }

    /// Removes every overlay plane group (0x6000–0x601E, even), including the retired
    /// *embedded* form whose bits live in Pixel Data's high bits and which therefore has
    /// no (60xx,3000) element of its own.
    private func removeOverlayPlanes(from dataSet: inout DataSet) -> Bool {
        var removed = false
        for group in stride(from: UInt16(0x6000), through: UInt16(0x601E), by: 2) {
            let present = dataSet.tags.contains { $0.group == group }
            guard present else { continue }
            for tag in dataSet.tags where tag.group == group {
                dataSet.remove(tag: tag)
                removed = true
            }
        }
        return removed
    }

    /// Writes the PS3.15 record for work that actually happened.
    private func recordAttestation(in dataSet: inout DataSet) {
        // (0028,0301) — PS3.15 E.3: "shall be added to the Data Set with a Value of NO".
        dataSet.setString("NO", for: .burnedInAnnotation, vr: .CS)

        // (0012,0064) De-identification Method Code Sequence — append DCM 113101 rather
        // than replacing, so a Basic-Profile item written by the header pass survives.
        var items = dataSet.sequence(for: Tag(group: 0x0012, element: 0x0064)) ?? []
        let alreadyRecorded = items.contains { item in
            let set = DataSet(elements: item.allElements)
            return set.string(for: Tag(group: 0x0008, element: 0x0100))?
                .trimmingCharacters(in: .whitespaces) == "113101"
        }
        if !alreadyRecorded {
            // Code Value / Coding Scheme Designator / Code Meaning (PS3.3 C.8-2).
            items.append(SequenceItem(elements: [
                DataElement.string(
                    tag: Tag(group: 0x0008, element: 0x0100), vr: .SH, value: "113101"),
                DataElement.string(
                    tag: Tag(group: 0x0008, element: 0x0102), vr: .SH, value: "DCM"),
                DataElement.string(
                    tag: Tag(group: 0x0008, element: 0x0104), vr: .LO,
                    value: "Clean Pixel Data Option"),
            ]))
            dataSet.setSequence(items, for: Tag(group: 0x0012, element: 0x0064))
        }
    }
}

/// Errors from the pixel-redaction path.
public enum PixelRedactionError: Error, LocalizedError, Equatable {
    /// The image declares burned-in identifiers but no strategy located them.
    case unresolvedRegion(String)

    public var errorDescription: String? {
        switch self {
        case .unresolvedRegion(let reason):
            return """
                Cannot determine which pixels to blank. \(reason)

                No caller-specified region was given, the data set declares no clinical \
                region to invert (e.g. Sequence of Ultrasound Regions), and no device \
                template matched this Modality/Manufacturer/model.

                Refusing rather than guessing: passing the file through unchanged would \
                leave the identifiers in place while the output looked de-identified.
                """
        }
    }
}
