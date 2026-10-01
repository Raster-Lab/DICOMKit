// NEMA-verified: 2026a, checked 2026-10-01 — --fill-value outside the C.7.6.3.1 stored range (Bits Stored / Pixel Representation) refused (P-PIXEDIT-RANGE); --window-width < 1 refused (C.11.2.1.2); the Derived Image marking (C.7.6.1.1.2, Table C.12-10), window in Modality LUT output units (C.11.2.1.2) and crop geometry (C.7.6.2.1.1) are done by the DICOMKit PixelEditor engine (D169-D174)
import Foundation
import DICOMCore
import DICOMKit

/// The input checks dicom-pixedit applies before the shared `PixelEditor` engine runs
/// (P-PIXEDIT-RANGE refusals; the engine itself clamps / throws).
enum DerivedImage {

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

    // The output marking (new SOP Instance UID, Image Type DERIVED, Derivation
    // Description, Source Image Sequence, Image Position (Patient) after a crop) and
    // the Modality LUT output units of the window moved into the DICOMKit
    // PixelEditor engine on 2026-10-01 (D169-D174), so DICOMStudio gets them too.
}
