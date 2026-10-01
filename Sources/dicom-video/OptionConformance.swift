// NEMA-verified: 2026a, checked 2026-10-01 — Modality ES/GM/XC per PS3.3 2026a A.32.5.4.1/A.32.6.4.1/A.32.7.4.1 ("shall be"); SOP Class names of the 3 --type values per PS3.6 2026a Table A-1; Patient's Sex Enumerated Values M/F/O per PS3.3 Table C.7-1; Patient's Birth Date VR DA per PS3.6 Table 6-1; --transfer-syntax values checked against the PS3.6 2026a Table A-1 registry (16 video UIDs registered; the 2 Fragmentable HEVC UIDs DICOMCore accepts are not), by script; values outside these are refused with exit 1 (P-VIDEO-MODALITY-ENUMERATED, P-VIDEO-SEX-ENUMERATED, P-VIDEO-TS-REGISTERED, approved 2026-10-01)

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Refusals for `convert` / `batch` option values that the engine accepts but
/// that yield an object the standard does not allow.
///
/// Approved 2026-10-01 (P-VIDEO-MODALITY-ENUMERATED, P-VIDEO-SEX-ENUMERATED,
/// P-VIDEO-TS-REGISTERED): any line returned stops the run with exit 1 before
/// anything is written. Until then the same values were written with a warning.
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

    /// CLI help suffixes stating the refusal (the shared `VideoConsole.Help`
    /// strings are also DICOMStudio's form help, which does not refuse yet).
    static let modalityHelp = VideoConsole.Help.modality + "; any other value is refused (exit 1)"
    static let patientSexHelp = VideoConsole.Help.patientSex + "; other values are refused (exit 1, PS3.3 Table C.7-1)"
    static let patientBirthDateHelp = VideoConsole.Help.patientBirthDate + "; other forms are refused (exit 1, VR DA)"
    static let transferSyntaxHelp = VideoConsole.Help.transferSyntax + "; a UID not registered there is refused (exit 1)"

    /// Every refusal for one run, in option order.
    ///
    /// - Parameters:
    ///   - type: The `--type` in effect (the default when none was given).
    ///   - metadata: The validated metadata (modality already resolved).
    ///   - transferSyntax: The `--transfer-syntax` value, if given.
    static func violations(
        type: VideoConsole.TypeArgument,
        metadata: VideoWorkflow.Metadata,
        transferSyntax: String?
    ) -> [String] {
        var lines: [String] = []
        if let uid = transferSyntax, let line = transferSyntaxViolation(uid) {
            lines.append(line)
        }
        if let modality = metadata.modality {
            let required = requiredModality(for: type)
            if modality != required.value {
                lines.append(VideoConsole.errorLine("""
                    --modality \(modality): PS3.3 \(required.section) requires Modality (0008,0060) \
                    \(required.value) for \(type.sopClassName); refused.
                    """))
            }
        }
        if let sex = metadata.patientSex, !patientSexValues.contains(sex) {
            lines.append(VideoConsole.errorLine("""
                --patient-sex \(sex) is not an Enumerated Value of Patient's Sex (0010,0040) \
                (M, F or O; PS3.3 Table C.7-1); refused.
                """))
        }
        if let date = metadata.patientBirthDate, DICOMDate.parse(date) == nil {
            lines.append(VideoConsole.errorLine("""
                --patient-birth-date \(date) is not a DA value (YYYYMMDD; PS3.5 Table 6.2-1) for \
                Patient's Birth Date (0010,0030); refused.
                """))
        }
        return lines
    }

    /// A refusal when `--transfer-syntax` names a UID that DICOMCore treats as
    /// video but PS3.6 Table A-1 does not register (the two "Fragmentable HEVC"
    /// UIDs, kept in DICOMCore by decision P2).
    static func transferSyntaxViolation(_ uid: String) -> String? {
        guard let entry = UIDDictionary.lookup(uid: uid), !entry.registered else { return nil }
        return VideoConsole.errorLine("""
            --transfer-syntax \(uid) is not registered in PS3.6 Table A-1; \
            HEVC/H.265 has only the non-fragmentable 1.2.840.10008.1.2.4.107 and .108; refused.
            """)
    }
}
