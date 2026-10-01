// NEMA-verified: 2026a, checked 2026-10-01 — --iod accepts the PS3.6 2026a Table A-1 keyword or UID of the 7 image / presentation-state SOP Classes and every SR SOP Class (DICOMCore.SRDocumentType) that DICOMValidator implements; the 7 UID literals below match Table A-1 (diff_cli.py uid check); the engine's own short names stay accepted
import Foundation
import DICOMCore
import DICOMDictionary

/// Maps an `--iod` value to the IOD name `DICOMValidator` switches on.
///
/// The engine knows its IODs by names of its own (`CRImageStorage`, `USImageStorage`,
/// `GrayscaleSoftcopyPresentationState`, `KeyObjectSelection`, ...), several of which
/// are not PS3.6 Table A-1 keywords (`ComputedRadiographyImageStorage`,
/// `UltrasoundImageStorage`, `GrayscaleSoftcopyPresentationStateStorage`,
/// `KeyObjectSelectionDocumentStorage`). The tool also accepts the Table A-1 keyword
/// (any letter case) or the SOP Class UID and passes the engine name on.
enum IODOption {

    /// Engine IOD name per SOP Class UID (PS3.6 Table A-1), as `DICOMValidator` detects it.
    static let engineNameBySOPClassUID: [String: String] = [
        "1.2.840.10008.5.1.4.1.1.2": "CTImageStorage",                         // CT Image Storage
        "1.2.840.10008.5.1.4.1.1.4": "MRImageStorage",                         // MR Image Storage
        "1.2.840.10008.5.1.4.1.1.1": "CRImageStorage",                         // Computed Radiography Image Storage
        "1.2.840.10008.5.1.4.1.1.6.1": "USImageStorage",                       // Ultrasound Image Storage
        "1.2.840.10008.5.1.4.1.1.7": "SecondaryCaptureImageStorage",           // Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.11.1": "GrayscaleSoftcopyPresentationState",  // Grayscale Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.3": "PseudoColorSoftcopyPresentationState", // Pseudo-Color Softcopy Presentation State Storage
    ]

    /// The SOP Class UID an `--iod` value names, by Table A-1 keyword (any case) or UID.
    static func sopClassUID(for value: String) -> String? {
        if let entry = UIDDictionary.lookup(uid: value) { return entry.uid }
        if let entry = UIDDictionary.lookup(keyword: value) { return entry.uid }
        let lower = value.lowercased()
        return UIDDictionary.sopClasses.first { $0.keyword.lowercased() == lower }?.uid
    }

    /// The engine IOD name for an `--iod` value; values that name no supported SOP Class
    /// are passed through unchanged (the engine's short names, or an unsupported IOD,
    /// which the engine reports as "IOD validation not implemented").
    static func engineName(for value: String) -> String {
        if value.lowercased() == "us" { return "USImageStorage" }   // the engine knows "ultrasound" only
        guard let uid = sopClassUID(for: value) else { return value }
        if let name = engineNameBySOPClassUID[uid] { return name }
        if SRDocumentType.isSRDocument(sopClassUID: uid) { return "StructuredReport" }
        return value
    }
}
