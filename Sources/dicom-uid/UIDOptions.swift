// NEMA-verified: 2026a, checked 2026-10-01 — --root is checked against PS3.5 2026a 9.1 (numeric components, no leading zero unless the component is "0", "." separators, at most 64 characters) and must leave room for the generated suffix; --uuid builds the UUID derived UID of PS3.5 B.2 ("2.25." + the UUID as a decimal integer, at most 39 digits); lookup --type covers all 12 UID Type values of PS3.6 2026a Table A-1 (465 rows dumped by script; "DICOM UIDs as a Coding Scheme" is folded into coding-scheme by DICOMDictionary.UIDType)
import Foundation
import DICOMCore
import DICOMDictionary

/// PS3.5 9.1 checks for a `--root` value and the room it leaves for generated UIDs.
enum UIDRootRule {

    /// The longest suffix `UIDGenerator` appends to the root: `.<µs timestamp>.<random 0-999999>`,
    /// plus `.<1|2|3>` for a typed (study / series / instance) UID.
    static func suffixLength(typed: Bool) -> Int {
        let timestampDigits = String(UInt64(Date().timeIntervalSince1970 * 1_000_000)).count
        return 1 + timestampDigits + 1 + 6 + (typed ? 2 : 0)
    }

    /// Problems with `root` as a UID root: the PS3.5 9.1 syntax rules, and the 64-character
    /// limit of 9.1 for the generated UID. A root too long for the suffix would make the
    /// generator cut the unique part off and return the same UID every time.
    static func problems(root: String, typed: Bool) -> [String] {
        var out: [String] = []
        let components = root.split(separator: ".", omittingEmptySubsequences: false)
        if root.isEmpty || components.contains(where: { $0.isEmpty }) {
            out.append("UID root '\(root)' has an empty component; components are separated by single \".\" characters (PS3.5 9.1)")
        }
        for component in components where !component.isEmpty {
            if !component.allSatisfy({ ("0"..."9").contains($0) }) {
                out.append("UID root component '\(component)' is not a number; only the digits 0-9 are allowed (PS3.5 9.1)")
            } else if component.count > 1 && component.hasPrefix("0") {
                out.append("UID root component '\(component)' has a leading zero; only a single-digit component may start with 0 (PS3.5 9.1)")
            }
        }
        let room = DICOMUniqueIdentifier.maximumLength - suffixLength(typed: typed)
        if root.count > room {
            out.append("UID root is \(root.count) characters; generated UIDs add up to \(suffixLength(typed: typed)) more and may not exceed \(DICOMUniqueIdentifier.maximumLength) (PS3.5 9.1), so the root may have at most \(room)")
        }
        return out
    }
}

/// The UUID derived UID of PS3.5 B.2: the root "2.25." followed by the 128-bit UUID
/// as an unsigned decimal integer without leading zeros (up to 39 digits).
enum UUIDDerivedUID {
    static func make(from uuid: UUID = UUID()) -> String {
        let t = uuid.uuid
        var bytes = [t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, t.8, t.9, t.10, t.11, t.12, t.13, t.14, t.15]
        var digits: [Character] = []
        // Repeated division of the big-endian 128-bit value by 10.
        while bytes.contains(where: { $0 != 0 }) {
            var remainder = 0
            for i in 0..<bytes.count {
                let value = remainder * 256 + Int(bytes[i])
                bytes[i] = UInt8(value / 10)
                remainder = value % 10
            }
            digits.append(Character(String(remainder)))
        }
        return "2.25." + (digits.isEmpty ? "0" : String(digits.reversed()))
    }
}

/// `lookup --type` values: one per UID Type of PS3.6 Table A-1.
enum LookupTypeFilter {
    /// (option value, DICOMDictionary type, PS3.6 Table A-1 "UID Type" text)
    static let all: [(value: String, type: UIDType, tableA1: String)] = [
        ("transfer-syntax", .transferSyntax, "Transfer Syntax"),
        ("sop-class", .sopClass, "SOP Class"),
        ("meta-sop-class", .metaSOPClass, "Meta SOP Class"),
        ("well-known-sop-instance", .wellKnown, "Well-known SOP Instance"),
        ("ldap-oid", .ldap, "LDAP OID"),
        ("coding-scheme", .codingScheme, "Coding Scheme"),
        ("application-context-name", .applicationContext, "Application Context Name"),
        ("service-class", .serviceClass, "Service Class"),
        ("application-hosting-model", .applicationHostingModel, "Application Hosting Model"),
        ("mapping-resource", .mappingResource, "Mapping Resource"),
        ("synchronization-frame-of-reference", .synchronizationFrameOfReference, "Synchronization Frame of Reference"),
    ]

    /// The original spellings without a hyphen stay accepted.
    static let aliases: [String: String] = ["transfersyntax": "transfer-syntax", "sopclass": "sop-class"]

    static var valueList: String { all.map(\.value).joined(separator: ", ") }

    static func type(for value: String) -> UIDType? {
        let v = value.lowercased()
        let key = aliases[v] ?? v
        return all.first { $0.value == key }?.type
    }

    static func entries(for value: String) -> [UIDEntry]? {
        guard let type = type(for: value) else { return nil }
        return UIDDictionary.allEntries.filter { $0.type == type }
    }
}
