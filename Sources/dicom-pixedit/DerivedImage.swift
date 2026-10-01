// NEMA-verified: 2026a, checked 2026-10-01 — derived-image rules of PS3.3 2026a C.7.6.1.1.2 (Image Type Value 1 DERIVED; a new SOP Instance UID when pixel data change), C.12.4 General Reference Module Table C.12-10 (Derivation Description ST, Source Image Sequence with Table 10-3 items, Purpose of Reference DCM 121322 from CID 7202; CID 7203 has no code for mask/crop/window/invert, so no Derivation Code Sequence), C.7.6.2.1.1 Equation C.7.6.2.1-1 (Image Position (Patient) after a crop), C.11.2.1.2 window in Modality LUT output units (width >= 1, smaller refused), --fill-value outside the C.7.6.3.1 stored range refused (P-PIXEDIT-RANGE), PS3.5 Table 6.2-1 (ST 1024 chars, DS 16 bytes), PS3.10 Table 7.1-1 (0002,0003), (0002,0012), (0002,0013)
import Foundation
import DICOMCore
import DICOMKit

/// What dicom-pixedit adds around the shared `PixelEditor` engine so that the
/// output is a conformant Derived Image (PS3.3 2026a C.7.6.1.1.2, C.12.4).
enum DerivedImage {

    /// PS3.16 2026a CID 7202 "Source Image Purpose of Reference": DCM 121322.
    static let sourcePurpose = (value: "121322", scheme: "DCM",
                                meaning: "Source image for image processing operation")

    /// ST is at most 1024 characters (PS3.5 2026a Table 6.2-1).
    static let stMaximumLength = 1024

    // MARK: - Input checks done before the engine runs

    /// Range of a stored sample: Bits Stored (0028,0101) and Pixel Representation
    /// (0028,0103) of the Image Pixel Module (PS3.3 2026a C.7.6.3.1).
    static func storedRange(bitsStored: Int, signed: Bool) -> ClosedRange<Int> {
        let bits = max(1, min(bitsStored, 32))
        return signed ? -(1 << (bits - 1)) ... (1 << (bits - 1)) - 1 : 0 ... (1 << bits) - 1
    }

    static func storedRange(of dataSet: DataSet) -> ClosedRange<Int> {
        let allocated = Int(dataSet.uint16(for: .bitsAllocated) ?? 16)
        let stored = Int(dataSet.uint16(for: .bitsStored) ?? UInt16(allocated))
        let signed = (dataSet.uint16(for: .pixelRepresentation) ?? 0) == 1
        return storedRange(bitsStored: stored, signed: signed)
    }

    /// A refusal when `--fill-value` lies outside the stored range (P-PIXEDIT-RANGE,
    /// approved 2026-10-01: it was clamped with a warning); nil when it fits.
    static func fillValueViolation(_ value: Int, range: ClosedRange<Int>) -> String? {
        guard !range.contains(value) else { return nil }
        return "--fill-value \(value) is outside the stored range \(range.lowerBound)...\(range.upperBound) "
            + "given by Bits Stored (0028,0101) and Pixel Representation (0028,0103) (PS3.3 C.7.6.3.1)"
    }

    /// A refusal when `--window-width` is below 1 (P-PIXEDIT-RANGE): PS3.3 2026a
    /// C.11.2.1.2 "Window Width (0028,1051) shall always be greater than or equal to 1"
    /// (it was raised to 1 with a warning, and a width <= 0 went to the engine).
    static func windowWidthViolation(_ width: Double) -> String? {
        guard !(width >= 1) else { return nil }
        return "--window-width \(width) is below 1; Window Width (0028,1051) shall always be greater than "
            + "or equal to 1 (PS3.3 C.11.2.1.2)"
    }

    /// Window Center/Width (0028,1050/1051) are in the output units of the Modality
    /// LUT (PS3.3 2026a C.11.2.1.2: the VOI LUT input is the Modality LUT output,
    /// e.g. HU for CT). The engine windows stored values, so translate an output-unit
    /// window through y = slope·x + intercept. Exact for slope > 0:
    /// c' = (c − 0.5 − b)/m + 0.5, w' = (w − 1)/m + 1.
    static func storedWindow(center: Double, width: Double,
                             slope: Double, intercept: Double) -> (center: Double, width: Double) {
        guard slope > 0, slope.isFinite, intercept.isFinite else { return (center, width) }
        if slope == 1, intercept == 0 { return (center, width) }
        return ((center - 0.5 - intercept) / slope + 0.5, (width - 1) / slope + 1)
    }

    // MARK: - Output: mark the edited image as a Derived Image

    /// Text for Derivation Description (0008,2111) naming every operation applied.
    static func description(of operations: [PixelOperation]) -> String {
        let steps = operations.map { op -> String in
            switch op {
            case let .mask(x, y, w, h, fill): return "region x=\(x) y=\(y) \(w)x\(h) set to \(fill)"
            case let .crop(x, y, w, h): return "cropped to x=\(x) y=\(y) \(w)x\(h)"
            case let .windowLevel(c, w): return "window center \(formatted(c)) width \(formatted(w)) baked into the stored values"
            case .invert: return "pixel values inverted"
            }
        }
        return "dicom-pixedit: " + steps.joined(separator: "; ")
    }

    /// Rewrites the engine output as a Derived Image of `source`.
    ///
    /// - New SOP Instance UID (0008,0018) and Media Storage SOP Instance UID (0002,0003):
    ///   the pixel data differ from the source (C.7.6.1.1.2, last paragraph).
    /// - Image Type (0008,0008) Value 1 DERIVED, other Values kept; DERIVED\SECONDARY when absent.
    /// - Derivation Description (0008,2111) appended (successive derivations).
    /// - Source Image Sequence (0008,2112): one more Item referencing the source.
    /// - Smallest/Largest Image Pixel Value and … in Series (0028,0106–0109) removed (stale).
    /// - Image Position (Patient) (0020,0032) moved to the new first pixel after a crop.
    /// - Implementation Class UID / Version Name (0002,0012/0013) set to this implementation.
    /// `described` lists the operations as the user gave them (window in output units);
    /// `operations` are what the engine ran (used for the crop geometry).
    static func markDerived(edited: DICOMFile, source: DICOMFile,
                            operations: [PixelOperation], described: [PixelOperation]? = nil,
                            newUID: String) -> DICOMFile {
        var ds = edited.dataSet
        var meta = edited.fileMetaInformation

        ds.setString(newUID, for: .sopInstanceUID, vr: .UI)
        meta.setString(newUID, for: .mediaStorageSOPInstanceUID, vr: .UI)
        // (0002,0012)/(0002,0013) identify the implementation that last wrote the file
        // (PS3.10 Table 7.1-1); the engine kept the source file's values.
        meta.setString(DICOMFile.implementationClassUID, for: .implementationClassUID, vr: .UI)
        meta.setString(DICOMFile.implementationVersionName, for: .implementationVersionName, vr: .SH)
        meta.remove(tag: .fileMetaInformationGroupLength)   // recomputed by DICOMFile.write()

        var imageType = ds.strings(for: .imageType) ?? []
        if imageType.isEmpty {
            imageType = ["DERIVED", "SECONDARY"]
        } else {
            imageType[0] = "DERIVED"
        }
        ds.setStrings(imageType, for: .imageType, vr: .CS)

        var text = description(of: described ?? operations)
        if let previous = ds.string(for: .derivationDescription)?
            .trimmingCharacters(in: .whitespaces), !previous.isEmpty {
            text = previous + "; " + text
        }
        ds.setString(String(text.prefix(stMaximumLength)), for: .derivationDescription, vr: .ST)

        if let sourceClass = source.dataSet.string(for: .sopClassUID),
           let sourceInstance = source.dataSet.string(for: .sopInstanceUID) {
            let purpose = SequenceItem(elements: [
                DataElement.string(tag: .codeValue, vr: .SH, value: sourcePurpose.value),
                DataElement.string(tag: .codingSchemeDesignator, vr: .SH, value: sourcePurpose.scheme),
                DataElement.string(tag: .codeMeaning, vr: .LO, value: sourcePurpose.meaning),
            ])
            var purposeSequence = DataSet()
            purposeSequence.setSequence([purpose], for: .purposeOfReferenceCodeSequence)
            let item = SequenceItem(elements: [
                DataElement.string(tag: .referencedSOPClassUID, vr: .UI, value: sourceClass),
                DataElement.string(tag: .referencedSOPInstanceUID, vr: .UI, value: sourceInstance),
            ] + (purposeSequence[.purposeOfReferenceCodeSequence].map { [$0] } ?? []))
            let existing = ds.sequence(for: .sourceImageSequence) ?? []
            ds.setSequence(existing + [item], for: .sourceImageSequence)
        }

        for tag in [Tag.smallestImagePixelValue, .largestImagePixelValue,
                    .smallestPixelValueInSeries, .largestPixelValueInSeries] {
            ds.remove(tag: tag)
        }

        if let position = croppedPosition(source: source.dataSet, operations: operations) {
            ds.setStrings(position.map(formatted), for: .imagePositionPatient, vr: .DS)
        }

        return DICOMFile(fileMetaInformation: meta, dataSet: ds)
    }

    /// Image Position (Patient) of the first pixel kept by the crop(s), per
    /// PS3.3 2026a C.7.6.2.1.1 Equation C.7.6.2.1-1: P = S + X·Δi·i + Y·Δj·j, with
    /// Δi = Pixel Spacing Value 2 (column spacing) and Δj = Value 1 (row spacing).
    /// Nil when there is no crop or the image carries no top-level plane geometry.
    static func croppedPosition(source: DataSet, operations: [PixelOperation]) -> [Double]? {
        var dx = 0, dy = 0
        for op in operations { if case let .crop(x, y, _, _) = op { dx += x; dy += y } }
        guard dx != 0 || dy != 0,
              let s = source.decimalStrings(for: .imagePositionPatient)?.map(\.value), s.count == 3,
              let o = source.decimalStrings(for: .imageOrientationPatient)?.map(\.value), o.count == 6,
              let ps = source.decimalStrings(for: .pixelSpacing)?.map(\.value), ps.count == 2
        else { return nil }
        let di = ps[1], dj = ps[0]
        return (0..<3).map { s[$0] + o[$0] * di * Double(dx) + o[$0 + 3] * dj * Double(dy) }
    }

    /// DS text (PS3.5 2026a Table 6.2-1: at most 16 bytes).
    static func formatted(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        var s = String(format: "%.10g", value)
        if s.count > 16 { s = String(format: "%.8g", value) }
        if s.count > 16 { s = String(s.prefix(16)) }
        return s
    }
}
