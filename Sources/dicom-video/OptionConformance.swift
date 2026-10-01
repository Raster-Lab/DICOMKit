// NEMA-verified: 2026a, checked 2026-10-01 — Modality ES/GM/XC per PS3.3 2026a A.32.5.4.1/A.32.6.4.1/A.32.7.4.1 ("shall be"); SOP Class names of the 3 --type values per PS3.6 2026a Table A-1; Patient's Sex Enumerated Values M/F/O per PS3.3 Table C.7-1; Patient's Birth Date VR DA per PS3.6 Table 6-1; --transfer-syntax values checked against the PS3.6 2026a Table A-1 registry (16 video UIDs registered; the 2 Fragmentable HEVC UIDs DICOMCore accepts are not), by script

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Warnings for `convert` / `batch` option values that the engine accepts but
/// that yield an object the standard does not allow.
///
/// They are warnings, not rejections: refusing a value the tool used to accept
/// changes its accepted-value set, which is the owner's decision (P-items
/// P-VIDEO-MODALITY-ENUMERATED, P-VIDEO-SEX-ENUMERATED, P-VIDEO-TS-REGISTERED).
enum VideoOptionConformance {

    /// The Modality (0008,0060) each IOD fixes, with the PS3.3 2026a section
    /// that says "The Value of Modality (0008,0060) shall be …".
    static func requiredModality(
        for type: VideoConsole.TypeArgument
    ) -> (value: String, section: String) {
        switch type {
        case .endoscopic: return ("ES", "A.32.5.4.1")
        case .microscopic: return ("GM", "A.32.6.4.1")
        case .photographic: return ("XC", "A.32.7.4.1")
        }
    }

    /// PS3.3 2026a Table C.7-1, Patient's Sex (0010,0040): Enumerated Values.
    static let patientSexValues = ["M", "F", "O"]

    /// Every warning for one run, in option order.
    ///
    /// - Parameters:
    ///   - type: The `--type` in effect (the default when none was given).
    ///   - metadata: The validated metadata (modality already resolved).
    ///   - transferSyntax: The `--transfer-syntax` value, if given.
    static func warnings(
        type: VideoConsole.TypeArgument,
        metadata: VideoWorkflow.Metadata,
        transferSyntax: String?
    ) -> [String] {
        var lines: [String] = []
        if let uid = transferSyntax, let line = transferSyntaxWarning(uid) {
            lines.append(line)
        }
        if let modality = metadata.modality {
            let required = requiredModality(for: type)
            if modality != required.value {
                lines.append(VideoConsole.warningLine("""
                    --modality \(modality): PS3.3 \(required.section) requires Modality (0008,0060) \
                    \(required.value) for \(type.sopClassName); the object will not conform.
                    """))
            }
        }
        if let sex = metadata.patientSex, !patientSexValues.contains(sex) {
            lines.append(VideoConsole.warningLine("""
                --patient-sex \(sex) is not an Enumerated Value of Patient's Sex (0010,0040) \
                (M, F or O; PS3.3 Table C.7-1); the object will not conform.
                """))
        }
        if let date = metadata.patientBirthDate, DICOMDate.parse(date) == nil {
            lines.append(VideoConsole.warningLine("""
                --patient-birth-date \(date) is not a DA value (YYYYMMDD); \
                Patient's Birth Date (0010,0030) is written empty.
                """))
        }
        return lines
    }

    /// A warning when `--transfer-syntax` names a UID that DICOMCore treats as
    /// video but PS3.6 Table A-1 does not register (the two "Fragmentable HEVC"
    /// UIDs, kept in DICOMCore by decision P2).
    static func transferSyntaxWarning(_ uid: String) -> String? {
        guard let entry = UIDDictionary.lookup(uid: uid), !entry.registered else { return nil }
        return VideoConsole.warningLine("""
            --transfer-syntax \(uid) is not registered in PS3.6 Table A-1; \
            HEVC/H.265 has only the non-fragmentable 1.2.840.10008.1.2.4.107 and .108, \
            and an object written with \(uid) will not conform.
            """)
    }
}
