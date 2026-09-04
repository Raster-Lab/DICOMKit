import Foundation
import DICOMCore

/// Decides, for text OCR found in the pixels, whether it is PHI (redact) or provably
/// safe clinical/technical annotation (keep).
///
/// ## Failure direction is pinned
///
/// There are two verdicts and the default is **redact**. Text is kept **only** when
/// every token is positively matched against a small allowlist (laterality, units,
/// technique factors, bare scale numerals) *and* nothing about it matches a harvested
/// PHI term, a PHI-shaped pattern, or a PHI keyword. Low OCR confidence never lets text
/// pass. Classification can therefore only make redaction *less* aggressive than
/// `all` — text Vision missed never reaches this type — so classify mode is never
/// safer than `all`, only more preserving.
///
/// ## Term harvest runs BEFORE header de-identification
///
/// ``harvestTerms(from:)`` reads PatientName, IDs, accession, institution, physician
/// and operator names, dates and age from the **original** header — attributes the
/// header pass deletes — and renders them in the forms devices burn into images.
public struct PHITextClassifier: Sendable, Equatable {

    /// PHI strings harvested from the original header, already normalized
    /// (uppercase, alphanumerics only) and OCR-confusion folded.
    public struct Terms: Sendable, Equatable {
        /// Names, IDs, institution — matched fuzzily.
        public var identifiers: [String]
        /// Dates and ages rendered in burned formats — matched exactly after normalization.
        public var derived: [String]

        public init(identifiers: [String] = [], derived: [String] = []) {
            self.identifiers = identifiers
            self.derived = derived
        }

        public var isEmpty: Bool { identifiers.isEmpty && derived.isEmpty }
    }

    public enum Verdict: Sendable, Equatable {
        case redact(reason: String)
        case keep(reason: String)

        public var isRedact: Bool {
            if case .redact = self { return true }
            return false
        }
        public var reason: String {
            switch self {
            case .redact(let r), .keep(let r): return r
            }
        }
        public var name: String { isRedact ? "redact" : "keep" }
    }

    /// OCR confidence below this is treated as uncertain → redact, whatever the text.
    public static let defaultMinimumConfidence: Float = 0.5

    public var terms: Terms
    public var minimumConfidence: Float

    public init(terms: Terms = Terms(), minimumConfidence: Float = PHITextClassifier.defaultMinimumConfidence) {
        self.terms = terms
        self.minimumConfidence = minimumConfidence
    }

    // MARK: - Allowlist

    /// Tokens that are provably clinical/technical when they stand alone.
    static let allowlistedTokens: Set<String> = [
        // laterality / orientation markers
        "L", "R", "LT", "RT", "LEFT", "RIGHT", "A", "P", "S", "I", "H", "F", "AP", "PA", "LAT",
        "ANT", "POST", "SUP", "INF", "MED", "LATERAL", "MEDIAL", "OBL", "SUPINE", "PRONE",
        // units
        "CM", "MM", "M", "UM", "KG", "G", "MG", "ML", "L", "MS", "S", "MIN", "HZ", "KHZ", "MHZ", "DB",
        "DEG", "FPS", "BPM", "MGY", "GY", "MSV", "SV", "MAS", "MA", "KV", "KVP", "MV", "W", "T", "PPM",
        // technique / display labels
        "KVP", "MAS", "FOV", "TR", "TE", "TI", "TA", "SL", "THK", "SP", "NEX", "FA", "ETL", "BW",
        "WW", "WL", "WC", "WIN", "LEV", "ZOOM", "MAG", "SCALE", "DEPTH", "GAIN", "MI", "TIS", "TIB",
        "FR", "FRQ", "FREQ", "PRF", "DR", "GN", "DYN", "MHZ", "HR",
        "AXIAL", "SAGITTAL", "CORONAL", "AX", "SAG", "COR", "TRA",
        "T1", "T2", "PD", "FLAIR", "DWI", "ADC", "STIR", "SWI", "TOF", "MIP", "MPR",
        "SOFT", "BONE", "LUNG", "BRAIN", "TISSUE", "WINDOW", "LEVEL", "KERNEL",
        "B", "X", "Y", "Z", "MM2", "MM3", "CM2", "CM3", "CC", "IN", "PX",
    ]

    /// Units that may be glued to a numeral (`120KVP`, `10CM`, `2.5MM`).
    static let allowlistedUnits: Set<String> = [
        "CM", "MM", "M", "UM", "KG", "G", "MG", "ML", "L", "MS", "S", "MIN", "HZ", "KHZ", "MHZ", "DB",
        "DEG", "FPS", "BPM", "MGY", "GY", "MSV", "SV", "MAS", "MA", "KV", "KVP", "MV", "W", "T", "PPM",
        "X", "MM2", "MM3", "CM2", "CM3", "CC", "IN", "PX", "FPS",
    ]

    /// Words that mark identifying content on the same line (`Pt:`, `Name:`, `DOB`, …).
    static let phiKeywords: Set<String> = [
        "PT", "PATIENT", "NAME", "DOB", "BIRTH", "BORN", "ACC", "ACCESSION", "MRN", "ID", "PID",
        "AGE", "SEX", "DR", "MD", "DOCTOR", "PHYSICIAN", "REF", "REFERRING", "HOSPITAL", "CLINIC",
        "CENTER", "CENTRE", "MEDICAL", "INSTITUTE", "UNIVERSITY", "RADIOLOGY", "IMAGING",
        "MR", "MRS", "MS", "MISS", "PROF", "STUDY", "EXAM", "DATE", "TIME", "OPERATOR", "TECH",
        "SONOGRAPHER", "ADDRESS", "PHONE", "TEL", "SSN", "DOD", "STATION",
    ]

    // MARK: - Harvest

    /// Harvests PHI terms from the **original** (not yet de-identified) data set.
    public static func harvestTerms(from dataSet: DataSet) -> Terms {
        var identifiers = Set<String>()
        var derived = Set<String>()

        func value(_ tag: Tag) -> String? {
            dataSet.string(for: tag)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
        func values(_ tag: Tag) -> [String] {
            (dataSet[tag]?.stringValues ?? [value(tag)].compactMap { $0 })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        // Person names: every component, and the joined forms in both orders.
        let nameTags: [Tag] = [
            .patientName, .otherPatientNames, .referringPhysicianName, .performingPhysicianName,
            Tag(group: 0x0008, element: 0x1070),   // Operators' Name
            Tag(group: 0x0008, element: 0x1048),   // Physician(s) of Record
            Tag(group: 0x0008, element: 0x1060),   // Name of Physician(s) Reading Study
            .requestingPhysician,
        ]
        for tag in nameTags {
            for pn in values(tag) {
                // Drop ideographic/phonetic groups; split components on "^".
                let alphabetic = pn.split(separator: "=", omittingEmptySubsequences: false).first.map(String.init) ?? pn
                let components = alphabetic.split(separator: "^").map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                for c in components {
                    // A component may itself hold several words ("JOHN PAUL").
                    for word in c.split(whereSeparator: { $0 == " " || $0 == "-" }) {
                        let n = normalize(String(word))
                        if n.count >= 3 { identifiers.insert(n) }
                    }
                    let n = normalize(c)
                    if n.count >= 3 { identifiers.insert(n) }
                }
                if components.count >= 2 {
                    identifiers.insert(normalize(components.joined()))                  // SMITHJOHN
                    identifiers.insert(normalize(components.reversed().joined()))       // JOHNSMITH
                    identifiers.insert(normalize(components[1].prefix(1) + components[0])) // JSMITH
                }
            }
        }

        // Identifiers: IDs, accession, institution, department, station.
        let idTags: [Tag] = [
            .patientID, .otherPatientIDs, .accessionNumber, .institutionName,
            .institutionalDepartmentName, .stationName,
            Tag(group: 0x0020, element: 0x0010),   // Study ID
        ]
        for tag in idTags {
            for raw in values(tag) {
                let n = normalize(raw)
                guard n.count >= 3 else { continue }
                identifiers.insert(n)
                // MRN with and without leading zeros.
                let stripped = String(n.drop(while: { $0 == "0" }))
                if stripped.count >= 3 { identifiers.insert(stripped) }
                // Multi-word institutions: each significant word too.
                for word in raw.split(separator: " ") {
                    let w = normalize(String(word))
                    if w.count >= 5 { identifiers.insert(w) }
                }
            }
        }

        // Dates in the formats devices burn.
        let dateTags: [Tag] = [.patientBirthDate, .studyDate, .seriesDate, .acquisitionDate, .contentDate]
        for tag in dateTags {
            for raw in values(tag) {
                for rendered in renderedDateForms(raw) { derived.insert(normalize(rendered)) }
            }
        }
        // Patient age: 045Y → 45Y, 45.
        if let age = value(.patientAge) {
            let digits = age.filter(\.isNumber)
            let unit = age.filter(\.isLetter)
            let n = String(Int(digits) ?? -1)
            if n != "-1" {
                derived.insert(normalize(n + unit))
                derived.insert(normalize(digits + unit))
                derived.insert(n)
            }
        }

        return Terms(identifiers: identifiers.sorted(), derived: derived.sorted())
    }

    /// Common burned renderings of a DICOM DA value (`YYYYMMDD`).
    static func renderedDateForms(_ da: String) -> [String] {
        let digits = da.filter(\.isNumber)
        guard digits.count == 8, let y = Int(digits.prefix(4)),
              let m = Int(digits.dropFirst(4).prefix(2)), let d = Int(digits.suffix(2)),
              (1...12).contains(m), (1...31).contains(d)
        else { return [] }
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        let mon = months[m - 1]
        let yy = String(format: "%02d", y % 100)
        let mm = String(format: "%02d", m), dd = String(format: "%02d", d)
        return [
            digits,                                  // 19611203
            "\(y)-\(mm)-\(dd)", "\(y)/\(mm)/\(dd)", "\(y).\(mm).\(dd)",
            "\(mm)/\(dd)/\(y)", "\(dd)/\(mm)/\(y)", "\(mm)-\(dd)-\(y)", "\(dd)-\(mm)-\(y)",
            "\(dd).\(mm).\(y)", "\(m)/\(d)/\(y)", "\(d)/\(m)/\(y)",
            "\(mm)/\(dd)/\(yy)", "\(dd)/\(mm)/\(yy)", "\(m)/\(d)/\(yy)", "\(d)/\(m)/\(yy)",
            "\(dd)-\(mon)-\(y)", "\(d)-\(mon)-\(y)", "\(dd) \(mon) \(y)", "\(mon) \(dd) \(y)",
            "\(mon) \(d), \(y)", "\(dd)\(mon)\(y)", "\(dd)-\(mon)-\(yy)",
        ]
    }

    // MARK: - Normalization

    /// Uppercase, alphanumerics only, PN separators and punctuation dropped.
    public static func normalize(_ text: String) -> String {
        String(text.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// Folds the classic OCR substitutions so `SM1TH` matches `SMITH` and `O`↔`0`.
    static func foldConfusions(_ normalized: String) -> String {
        var out = ""
        out.reserveCapacity(normalized.count)
        for ch in normalized {
            switch ch {
            case "0", "O", "Q", "D": out.append("0")
            case "1", "I", "L", "|": out.append("1")
            case "5", "S": out.append("5")
            case "8", "B": out.append("8")
            case "2", "Z": out.append("2")
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: - Classification

    /// Classifies one recognized string.
    public func classify(_ text: String, confidence: Float) -> Verdict {
        if confidence < minimumConfidence {
            return .redact(reason: "uncertain: OCR confidence \(String(format: "%.2f", confidence)) below \(String(format: "%.2f", minimumConfidence))")
        }
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return .redact(reason: "uncertain: no recognizable characters") }
        let folded = Self.foldConfusions(normalized)

        // 1. Harvested PHI terms (fuzzy).
        for term in terms.identifiers {
            if Self.fuzzyContains(haystack: folded, needle: Self.foldConfusions(term)) {
                return .redact(reason: "matched header identifier")
            }
        }
        for term in terms.derived where folded.contains(Self.foldConfusions(term)) {
            return .redact(reason: "matched header date/age")
        }

        // 2. PHI-shaped patterns (no header source needed).
        if let pattern = Self.phiPattern(in: text) {
            return .redact(reason: "pattern: \(pattern)")
        }

        // 3. Keyword proximity: a PHI label on the line taints the whole line.
        let tokens = Self.tokens(of: text)
        if let keyword = tokens.first(where: { Self.phiKeywords.contains($0) }) {
            return .redact(reason: "near PHI keyword \(keyword)")
        }

        // 4. Keep ONLY when every token is positively allowlisted.
        if !tokens.isEmpty, tokens.allSatisfy(Self.isAllowlisted) {
            return .keep(reason: "allowlist: " + Self.allowlistCategory(tokens))
        }
        return .redact(reason: "uncertain: not on the allowlist")
    }

    /// Classifies every detection.
    public func classify(_ detections: [TextRegionDetector.Detection]) -> [Verdict] {
        detections.map { classify($0.text, confidence: $0.confidence) }
    }

    // MARK: Helpers

    static func tokens(of text: String) -> [String] {
        text.uppercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "." ) })
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            .filter { !$0.isEmpty }
    }

    static func isAllowlisted(_ token: String) -> Bool {
        if allowlistedTokens.contains(token) { return true }
        // Numeral, optionally decimal, optionally with a glued unit: 120, 2.5, 10CM, 120KVP.
        let digits = token.prefix(while: { $0.isNumber || $0 == "." })
        let rest = String(token.dropFirst(digits.count))
        guard !digits.isEmpty, Double(digits) != nil else { return false }
        let integerDigits = digits.split(separator: ".").first.map { $0.count } ?? 0
        guard integerDigits <= 4 else { return false }               // longer runs are IDs
        return rest.isEmpty || allowlistedUnits.contains(rest)
    }

    static func allowlistCategory(_ tokens: [String]) -> String {
        if tokens.allSatisfy({ ["L", "R", "LT", "RT", "LEFT", "RIGHT"].contains($0) }) { return "laterality" }
        if tokens.allSatisfy({ Double($0.prefix(while: { $0.isNumber || $0 == "." })) != nil }) { return "numeral/unit" }
        return "technical label"
    }

    /// Returns the name of the first PHI-shaped pattern found, or nil.
    static func phiPattern(in text: String) -> String? {
        let upper = text.uppercased()
        let patterns: [(String, String)] = [
            ("date", #"\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b"#),
            ("date", #"\b\d{4}[/.\-]\d{1,2}[/.\-]\d{1,2}\b"#),
            ("date", #"\b\d{1,2}[ \-]?(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[ \-,]*\d{2,4}\b"#),
            ("date", #"\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[ \-]?\d{1,2}[ ,\-]+\d{2,4}\b"#),
            ("date", #"\b(19|20)\d{6}\b"#),
            ("time", #"\b\d{1,2}:\d{2}(:\d{2})?\b"#),
            ("long digit run (ID)", #"\d{5,}"#),
            ("mixed alphanumeric ID", #"\b(?=[A-Z0-9\-]{6,}\b)(?=[A-Z\-]*\d)(?=[\d\-]*[A-Z])[A-Z0-9\-]+\b"#),
        ]
        for (name, pattern) in patterns {
            if upper.range(of: pattern, options: .regularExpression) != nil { return name }
        }
        return nil
    }

    /// Normalized-substring, else any window of `needle.count` (±1) within `haystack`
    /// at bounded edit distance (1 for short terms, 2 for 8+ characters).
    static func fuzzyContains(haystack: String, needle: String) -> Bool {
        guard !needle.isEmpty, !haystack.isEmpty else { return false }
        if haystack.contains(needle) { return true }
        guard needle.count >= 4 else { return false }
        let budget = needle.count >= 8 ? 2 : 1
        let h = Array(haystack), n = Array(needle)
        for width in max(1, n.count - 1)...(n.count + 1) where width <= h.count {
            for start in 0...(h.count - width) {
                if editDistance(Array(h[start..<(start + width)]), n, limit: budget) <= budget { return true }
            }
        }
        return false
    }

    static func editDistance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if abs(a.count - b.count) > limit { return limit + 1 }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...max(1, a.count) where i <= a.count {
            cur[0] = i
            var rowMin = cur[0]
            for j in 1...max(1, b.count) where j <= b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
                rowMin = min(rowMin, cur[j])
            }
            if rowMin > limit { return limit + 1 }
            swap(&prev, &cur)
        }
        return a.isEmpty ? b.count : prev[b.count]
    }
}

private extension String {
    var nilIfBlank: String? { isEmpty ? nil : self }
}
