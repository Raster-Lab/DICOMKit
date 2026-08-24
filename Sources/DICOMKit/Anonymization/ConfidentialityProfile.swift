import Foundation
import DICOMCore

/// PS3.15 Annex E — Attribute Confidentiality Profiles.
///
/// This models the *action codes* of Table E.1-1 and a curated table of the attributes
/// that carry direct identifiers. It is deliberately additive: the legacy
/// ``AnonymizationProfile`` (basic/clinicalTrial/research) is unchanged; this type is the
/// standards-grounded engine used by the new ``Anonymizer/deidentify(file:)`` path.
///
/// ## Coverage
///
/// Table E.1-1 lists ~530 attributes. This table encodes the **direct-identifier core** —
/// every attribute in Table E.1-1 whose Basic Profile action is D/Z/X and that carries a
/// name, identifier, contact detail, address, date/time, description, device identity or
/// UID likely to hold PHI — plus the method-recording attributes. Attributes whose only
/// action is a retention *option* (C/K/U under a named option) are handled by the option
/// toggles rather than enumerated. Coverage is stated honestly in the tests and docs; the
/// engine also applies **VR-based sweeps** (all PN removed unless retained; all
/// UI regenerated consistently; all private tags removed unless retained) so an attribute
/// absent from the explicit table is not silently kept.
public enum ConfidentialityProfile {

    /// PS3.15 Table E.1-1 action codes.
    public enum Action: Sendable, Equatable {
        /// **D** — replace with a non-zero-length dummy value of consistent VR.
        case replaceDummy
        /// **Z** — replace with a zero-length value, or a dummy of consistent VR.
        case zero
        /// **X** — remove the attribute.
        case remove
        /// **K** — keep (retain unchanged). Used when an option turns retention on.
        case keep
        /// **C** — clean: retain but scrub embedded identifiers (best-effort; the
        /// engine currently zeroes free-text descriptors it cannot clean safely).
        case clean
        /// **U** — replace UID with an internally-consistent generated UID.
        case replaceUID
        /// **Z/D** — Z unless a dummy is required by an IOD; the engine treats as Z.
        case zeroOrDummy
        /// **X/Z**, **X/D**, **X/Z/D** etc. — the engine takes the most aggressive
        /// safe action (remove) unless a retention option applies.
        case removePreferred
    }

    /// Named retention options from PS3.15 E.3 that relax specific actions.
    public struct Options: Sendable, Equatable {
        public var retainLongitudinalTemporal: Bool  // dates/times kept (else removed/shifted)
        public var retainPatientCharacteristics: Bool // age/sex/weight/size kept
        public var retainDeviceIdentity: Bool          // device serial/UID/station kept
        public var retainInstitutionIdentity: Bool     // institution name/address kept
        public var retainUIDs: Bool                    // UIDs kept unchanged (else regenerated)
        public var cleanDescriptors: Bool              // scrub free-text rather than remove
        public var dateOffsetDays: Int?                // if set with retainLongitudinalTemporal, shift instead of remove

        public init(
            retainLongitudinalTemporal: Bool = false,
            retainPatientCharacteristics: Bool = false,
            retainDeviceIdentity: Bool = false,
            retainInstitutionIdentity: Bool = false,
            retainUIDs: Bool = false,
            cleanDescriptors: Bool = false,
            dateOffsetDays: Int? = nil
        ) {
            self.retainLongitudinalTemporal = retainLongitudinalTemporal
            self.retainPatientCharacteristics = retainPatientCharacteristics
            self.retainDeviceIdentity = retainDeviceIdentity
            self.retainInstitutionIdentity = retainInstitutionIdentity
            self.retainUIDs = retainUIDs
            self.cleanDescriptors = cleanDescriptors
            self.dateOffsetDays = dateOffsetDays
        }

        /// The strict Basic Application Level Confidentiality Profile: every option off.
        public static let basic = Options()
    }

    /// A single row of the confidentiality table: which option (if any) can relax it.
    public struct Rule: Sendable {
        public let action: Action
        /// If non-nil, this action is relaxed to `.keep` when the named option is on.
        public let relaxedBy: RelaxKey?
        public init(_ action: Action, relaxedBy: RelaxKey? = nil) {
            self.action = action
            self.relaxedBy = relaxedBy
        }
    }

    public enum RelaxKey: Sendable {
        case longitudinalTemporal
        case patientCharacteristics
        case deviceIdentity
        case institutionIdentity
        case uids
    }

    /// The curated Table E.1-1 direct-identifier rows.
    ///
    /// Grouped by concern for auditability. Tags are referenced by their DICOMCore
    /// constants where defined; raw `Tag(group:element:)` otherwise (with the E.1-1
    /// keyword in a trailing comment).
    public static let table: [Tag: Rule] = {
        var t: [Tag: Rule] = [:]

        // --- Patient identity (D/Z/X) ---
        t[.patientName]              = Rule(.zero)                  // (0010,0010) Z
        t[.patientID]                = Rule(.zero)                  // (0010,0020) Z
        t[.patientBirthDate]         = Rule(.zero, relaxedBy: .longitudinalTemporal) // (0010,0030) Z
        t[.patientBirthTime]         = Rule(.remove, relaxedBy: .longitudinalTemporal) // (0010,0032) X
        t[.patientSex]               = Rule(.zero, relaxedBy: .patientCharacteristics) // (0010,0040) Z
        t[.otherPatientIDs]          = Rule(.remove)               // (0010,1000) X
        t[.otherPatientNames]        = Rule(.remove)               // (0010,1001) X
        t[Tag(group: 0x0010, element: 0x1002)] = Rule(.remove)     // Other Patient IDs Sequence X
        t[Tag(group: 0x0010, element: 0x1005)] = Rule(.remove)     // Patient's Birth Name X
        t[Tag(group: 0x0010, element: 0x1040)] = Rule(.remove)     // Patient's Address X
        t[Tag(group: 0x0010, element: 0x1060)] = Rule(.remove)     // Patient's Mother's Birth Name X
        t[Tag(group: 0x0010, element: 0x2154)] = Rule(.remove)     // Patient's Telephone Numbers X
        t[Tag(group: 0x0010, element: 0x2160)] = Rule(.remove)     // Ethnic Group X
        t[.patientComments]          = Rule(.remove)               // (0010,4000) X
        t[Tag(group: 0x0010, element: 0x1010)] = Rule(.remove, relaxedBy: .patientCharacteristics) // Patient's Age X
        t[Tag(group: 0x0010, element: 0x1020)] = Rule(.remove, relaxedBy: .patientCharacteristics) // Patient's Size X
        t[Tag(group: 0x0010, element: 0x1030)] = Rule(.remove, relaxedBy: .patientCharacteristics) // Patient's Weight X
        t[Tag(group: 0x0010, element: 0x21B0)] = Rule(.remove)     // Additional Patient History X
        t[Tag(group: 0x0010, element: 0x21C0)] = Rule(.remove)     // Pregnancy Status X
        t[Tag(group: 0x0010, element: 0x2180)] = Rule(.remove)     // Occupation X
        t[Tag(group: 0x0038, element: 0x0300)] = Rule(.remove)     // Current Patient Location X
        t[Tag(group: 0x0038, element: 0x0400)] = Rule(.remove)     // Patient's Institution Residence X
        t[Tag(group: 0x0038, element: 0x0500)] = Rule(.clean)      // Patient State C→clean/remove

        // --- Physicians & operators (X/Z) ---
        t[.referringPhysicianName]   = Rule(.zero)                 // (0008,0090) Z
        t[Tag(group: 0x0008, element: 0x0092)] = Rule(.remove)     // Referring Physician's Address X
        t[Tag(group: 0x0008, element: 0x0094)] = Rule(.remove)     // Referring Physician's Telephone X
        t[Tag(group: 0x0008, element: 0x0096)] = Rule(.remove)     // Referring Physician ID Sequence X
        t[.performingPhysicianName]  = Rule(.remove)               // (0008,1050) X
        t[Tag(group: 0x0008, element: 0x1052)] = Rule(.remove)     // Performing Physician ID Sequence X
        t[Tag(group: 0x0008, element: 0x1060)] = Rule(.remove)     // Name of Physician(s) Reading Study X
        t[Tag(group: 0x0008, element: 0x1062)] = Rule(.remove)     // Physician(s) Reading Study ID Sequence X
        t[.operatorName]             = Rule(.remove)               // (0008,1070) X
        t[Tag(group: 0x0008, element: 0x1072)] = Rule(.remove)     // Operator Identification Sequence X
        t[Tag(group: 0x0032, element: 0x1032)] = Rule(.remove)     // Requesting Physician X
        t[Tag(group: 0x0040, element: 0x0006)] = Rule(.remove)     // Scheduled Performing Physician's Name X
        t[Tag(group: 0x0040, element: 0x1010)] = Rule(.remove)     // Names of Intended Recipients of Results X

        // --- Institution / station / device ---
        t[.institutionName]          = Rule(.remove, relaxedBy: .institutionIdentity) // (0008,0080) X
        t[.institutionAddress]       = Rule(.remove, relaxedBy: .institutionIdentity) // (0008,0081) X
        t[Tag(group: 0x0008, element: 0x0082)] = Rule(.remove, relaxedBy: .institutionIdentity) // Institution Code Sequence X
        t[Tag(group: 0x0008, element: 0x1040)] = Rule(.remove, relaxedBy: .institutionIdentity) // Institutional Department Name X
        t[.stationName]              = Rule(.remove, relaxedBy: .deviceIdentity) // (0008,1010) X
        t[.deviceSerialNumber]       = Rule(.remove, relaxedBy: .deviceIdentity) // (0018,1000) X
        t[Tag(group: 0x0018, element: 0x1002)] = Rule(.remove, relaxedBy: .deviceIdentity) // Device UID U/X
        t[Tag(group: 0x0018, element: 0x1004)] = Rule(.remove, relaxedBy: .deviceIdentity) // Plate ID X
        t[Tag(group: 0x0018, element: 0x1005)] = Rule(.remove, relaxedBy: .deviceIdentity) // Generator ID X
        t[Tag(group: 0x0018, element: 0x1030)] = Rule(.clean)      // Protocol Name C
        t[Tag(group: 0x0040, element: 0x0241)] = Rule(.remove, relaxedBy: .deviceIdentity) // Performed Station AE Title X

        // --- Free-text descriptions (X or clean) ---
        t[.studyDescription]         = Rule(.clean)                // (0008,1030) C→clean/remove
        t[.seriesDescription]        = Rule(.clean)                // (0008,103E) C→clean/remove
        t[Tag(group: 0x0018, element: 0x4000)] = Rule(.remove)     // Acquisition Comments X
        t[Tag(group: 0x0020, element: 0x4000)] = Rule(.remove)     // Image Comments X
        t[Tag(group: 0x0040, element: 0x2400)] = Rule(.remove)     // Imaging Service Request Comments X
        t[Tag(group: 0x4008, element: 0x0300)] = Rule(.remove)     // Impressions X
        t[Tag(group: 0x0032, element: 0x4000)] = Rule(.remove)     // Study Comments X
        t[Tag(group: 0x0038, element: 0x4000)] = Rule(.remove)     // Visit Comments X

        // --- Identifiers / accession / request ---
        t[Tag(group: 0x0008, element: 0x0050)] = Rule(.zero)       // Accession Number Z
        t[Tag(group: 0x0008, element: 0x0051)] = Rule(.remove)     // Issuer of Accession Number Sequence X
        t[Tag(group: 0x0020, element: 0x0010)] = Rule(.zero)       // Study ID Z
        t[Tag(group: 0x0038, element: 0x0010)] = Rule(.remove)     // Admission ID X
        t[Tag(group: 0x0038, element: 0x0011)] = Rule(.remove)     // Issuer of Admission ID X
        t[Tag(group: 0x0040, element: 0x1001)] = Rule(.remove)     // Requested Procedure ID X
        t[Tag(group: 0x0040, element: 0x2016)] = Rule(.remove)     // Placer Order Number X
        t[Tag(group: 0x0040, element: 0x2017)] = Rule(.remove)     // Filler Order Number X

        // --- Dates & times (relaxed by longitudinal-temporal) ---
        for dateTag in [
            Tag(group: 0x0008, element: 0x0020), // Study Date
            Tag(group: 0x0008, element: 0x0021), // Series Date
            Tag(group: 0x0008, element: 0x0022), // Acquisition Date
            Tag(group: 0x0008, element: 0x0023), // Content Date
            Tag(group: 0x0008, element: 0x0030), // Study Time
            Tag(group: 0x0008, element: 0x0031), // Series Time
            Tag(group: 0x0008, element: 0x0032), // Acquisition Time
            Tag(group: 0x0008, element: 0x0033), // Content Time
            Tag(group: 0x0008, element: 0x0024), // Overlay Date
            Tag(group: 0x0008, element: 0x0025), // Curve Date
            Tag(group: 0x0038, element: 0x0020), // Admitting Date
            Tag(group: 0x0038, element: 0x0021), // Admitting Time
            Tag(group: 0x0040, element: 0x0002), // Scheduled Procedure Step Start Date
            Tag(group: 0x0040, element: 0x0004), // Scheduled Procedure Step End Date
            Tag(group: 0x0040, element: 0x0244), // Performed Procedure Step Start Date
            Tag(group: 0x0040, element: 0x0250), // Performed Procedure Step End Date
        ] {
            t[dateTag] = Rule(.zeroOrDummy, relaxedBy: .longitudinalTemporal)
        }

        return t
    }()

    /// Resolves the effective action for a tag under the given options.
    /// Returns nil when the tag is not in the explicit table (VR sweeps handle those).
    public static func action(for tag: Tag, options: Options) -> Action? {
        guard let rule = table[tag] else { return nil }
        if let key = rule.relaxedBy, isRelaxed(key, options) {
            // "Retain Longitudinal Temporal Information with Modified Dates": when an
            // offset is set, dates are *shifted*, not kept verbatim. Leave the original
            // action (.zeroOrDummy) so the engine's date-shift path runs; only a
            // no-offset retention becomes a plain keep.
            if key == .longitudinalTemporal, options.dateOffsetDays != nil,
               rule.action == .zeroOrDummy {
                return rule.action
            }
            return .keep
        }
        return rule.action
    }

    static func isRelaxed(_ key: RelaxKey, _ o: Options) -> Bool {
        switch key {
        case .longitudinalTemporal: return o.retainLongitudinalTemporal
        case .patientCharacteristics: return o.retainPatientCharacteristics
        case .deviceIdentity: return o.retainDeviceIdentity
        case .institutionIdentity: return o.retainInstitutionIdentity
        case .uids: return o.retainUIDs
        }
    }
}
