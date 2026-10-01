// NEMA-verified: 2026a, checked 2026-10-01 — the 7 keyword → UID rows below are PS3.6 2026a Table A-1 rows (keyword column) whose keyword the shared DICOMConverter catalog does not accept; diffed by script against the 21 target UIDs of the catalog (A-1 keywords: 11 accepted for the same UID, 3 accepted for another UID (P-item), 7 added here)
import DICOMCore
import DICOMKit

/// `--transfer-syntax` accepts the shared catalog's names (DICOMConverter) and, in addition,
/// these PS3.6 2026a Table A-1 keywords. The shared catalog is tried first, so the three
/// catalog names that are also Table A-1 keywords of another UID keep their meaning
/// (`JPEG2000Lossless`, `HTJ2KLossless`, `JPEGXLLossless` = reversible encode into .91 / .203 /
/// .112, see P-CONVERT-TS-KEYWORDS); the Table A-1 meaning of those three is reached with
/// the `…LosslessOnly` names or the UID.
enum TransferSyntaxKeywords {

    /// Table A-1 keyword → Transfer Syntax UID, for catalog targets whose keyword is missing.
    static let additional: [String: String] = [
        "DeflatedExplicitVRLittleEndian": "1.2.840.10008.1.2.1.99",
        "JPEGBaseline8Bit": "1.2.840.10008.1.2.4.50",
        "JPEGExtended12Bit": "1.2.840.10008.1.2.4.51",
        "JPEG2000MCLossless": "1.2.840.10008.1.2.4.92",
        "JPEG2000MC": "1.2.840.10008.1.2.4.93",
        "JPEGXLJPEGRecompression": "1.2.840.10008.1.2.4.111",
        "HTJ2KLosslessRPCL": "1.2.840.10008.1.2.4.202",
    ]

    /// Resolves a `--transfer-syntax` token: the shared catalog first, then a Table A-1
    /// keyword from `additional` (through its UID, so the catalog decides the intent).
    static func resolve(_ token: String) -> SelectableEncoding? {
        if let encoding = DICOMConverter.resolveTargetEncoding(token) { return encoding }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let uid = additional.first(where: { $0.key.lowercased() == trimmed })?.value else {
            return nil
        }
        return DICOMConverter.resolveTargetEncoding(uid)
    }

    /// `--transfer-syntax` help: the catalog names, plus what else is accepted.
    static var optionHelp: String {
        DICOMConverter.transferSyntaxOptionHelp
            + ". Also a Transfer Syntax UID or a PS3.6 Table A-1 keyword ("
            + additional.keys.sorted().joined(separator: ", ")
            + "). JPEG2000Lossless, HTJ2KLossless and JPEGXLLossless here select the reversible "
            + "encode into .91 / .203 / .112; for .90 / .201 / .110 use the …LosslessOnly names."
    }
}
