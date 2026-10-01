// NEMA-verified: 2026a, checked 2026-10-01 — Conversion Type Defined Terms DV, DI, DF, WSD, SD, SI, DRW, SYN (PS3.3 2026a Table C.8-24, 8 of 8, via ConversionType.definedTerms); Specific Character Set "ISO_IR 192" (Table C.12-5, Unicode in UTF-8; Type 1C Table C.12-1); Media Storage SOP Instance UID (0002,0003) equals SOP Instance UID (PS3.10 Table 7.1-1); value limits of PS3.5 Table 6.2-1 (UI 64 bytes + 9.1 component rules, LO 64 chars, PN 64 chars per component group, IS -2^31..2^31-1, no backslash in LO/PN)
import Foundation
import DICOMCore
import DICOMKit

/// Checks and post-processing that dicom-image applies around the shared
/// `ImageConverter` engine.
enum SCOutput {

    // MARK: - --conversion-type

    /// Parses `--conversion-type` (case-insensitive) into a PS3.3 2026a Table C.8-24
    /// Defined Term. Nil means "not one of the eight terms".
    static func conversionType(_ raw: String?) -> ConversionType? {
        guard let raw else { return .workstation }
        let term = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard ConversionType.definedTerms.contains(term) else { return nil }
        return ConversionType(rawValue: term)
    }

    // MARK: - Value checks (warnings; PS3.5 2026a Table 6.2-1)

    /// Warnings for option values that the written VR cannot hold. They are not
    /// errors: the tool always wrote these values as given (P-IMAGE-VR proposes rejecting).
    static func valueWarnings(patientName: String?, patientID: String?,
                              studyDescription: String?, seriesDescription: String?,
                              studyUID: String?, seriesUID: String?,
                              seriesNumber: Int?, instanceNumber: Int?) -> [String] {
        var out: [String] = []
        for (option, value) in [("--study-uid", studyUID), ("--series-uid", seriesUID)] {
            if let value, DICOMUniqueIdentifier.parse(value) == nil {
                out.append("warning: \(option) '\(value)' is not a valid UID (PS3.5 9.1: digits and '.', "
                           + "no leading zero in a component, at most 64 bytes)")
            }
        }
        for (option, value) in [("--patient-id", patientID), ("--study-description", studyDescription),
                                ("--series-description", seriesDescription)] {
            guard let value else { continue }
            if value.count > 64 {
                out.append("warning: \(option) has \(value.count) characters; LO allows at most 64 (PS3.5 Table 6.2-1)")
            }
            if value.contains("\\") {
                out.append("warning: \(option) contains a backslash, which LO does not allow (PS3.5 Table 6.2-1)")
            }
        }
        if let name = patientName {
            for group in name.split(separator: "=", omittingEmptySubsequences: false) where group.count > 64 {
                out.append("warning: --patient-name component group has \(group.count) characters; "
                           + "PN allows at most 64 per component group (PS3.5 Table 6.2-1)")
            }
            if name.contains("\\") {
                out.append("warning: --patient-name contains a backslash, which PN does not allow (PS3.5 Table 6.2-1)")
            }
        }
        let isRange = Int(Int32.min)...Int(Int32.max)
        for (option, value) in [("--series-number", seriesNumber), ("--instance-number", instanceNumber)] {
            if let value, !isRange.contains(value) {
                out.append("warning: \(option) \(value) is outside the IS range -2^31...2^31-1 (PS3.5 Table 6.2-1)")
            }
        }
        return out
    }

    // MARK: - Output post-processing

    /// Specific Character Set (0008,0005) Defined Term for UTF-8 (PS3.3 2026a Table C.12-5).
    static let utf8CharacterSet = "ISO_IR 192"

    /// Fixes the engine's output file:
    /// - Media Storage SOP Instance UID (0002,0003) set to the data set's SOP Instance
    ///   UID (0008,0018) — PS3.10 Table 7.1-1 (the engine minted two different UIDs).
    /// - Specific Character Set (0008,0005) = ISO_IR 192 when a text value is not ASCII:
    ///   Type 1C "Required if an expanded or replacement character set is used"
    ///   (Table C.12-1); the engine writes text as UTF-8.
    static func finalize(_ data: Data) throws -> Data {
        let file = try DICOMFile.read(from: data)
        var meta = file.fileMetaInformation
        var ds = file.dataSet
        if let sop = ds.string(for: .sopInstanceUID),
           meta.string(for: .mediaStorageSOPInstanceUID) != sop {
            meta.setString(sop, for: .mediaStorageSOPInstanceUID, vr: .UI)
            meta.remove(tag: .fileMetaInformationGroupLength)   // recomputed by write()
        }
        if ds[.specificCharacterSet] == nil, usesNonASCIIText(ds) {
            ds.setString(utf8CharacterSet, for: .specificCharacterSet, vr: .CS)
        }
        return try DICOMFile(fileMetaInformation: meta, dataSet: ds).write()
    }

    /// Whether any top-level text value (PN, LO, SH, ST, LT, UT, UC) holds a non-ASCII byte.
    static func usesNonASCIIText(_ ds: DataSet) -> Bool {
        let textVRs: Set<VR> = [.PN, .LO, .SH, .ST, .LT, .UT, .UC]
        for element in ds where textVRs.contains(element.vr) {
            if element.valueData.contains(where: { $0 >= 0x80 }) { return true }
        }
        return false
    }
}
