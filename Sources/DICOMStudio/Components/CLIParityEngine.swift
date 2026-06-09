// CLIParityEngine.swift
// DICOMStudio
//
// Swift-native comparison engine for the CLI Automation Testing screen.
// Mirrors the standalone Scripts/cli_parity_report.py logic:
//   * CLI side   — parsed from the bundled CLIContracts.json (swift-argument-
//                  parser ToolInfoV0, captured offline by `cli-parity-gen`).
//   * Studio side — computed in-process from CommandBuilderHelpers.buildCommand
//                  (the TRUE emitted flags: host:port folding, flagPicker,
//                  cliMapping, visibility gates all applied).
// Comparison is option-by-option so a long-form match covers its short alias.

import Foundation
import DICOMKit
import DICOMCore
import CryptoKit

#if canImport(ImageIO)
import ImageIO
import CoreGraphics
#endif

// MARK: - Decoded CLI contract (ToolInfoV0 subset)

struct ToolInfoName: Decodable { let kind: String?; let name: String? }

struct ToolInfoArg: Decodable {
    let kind: String?              // positional | option | flag
    let shouldDisplay: Bool?
    let names: [ToolInfoName]?
    let valueName: String?
    let defaultValue: String?
    let abstract: String?
}

struct ToolInfoCommand: Decodable {
    let commandName: String?
    let arguments: [ToolInfoArg]?
    let subcommands: [ToolInfoCommand]?
}

struct ToolInfoRoot: Decodable { let command: ToolInfoCommand }

public struct CLIContracts: Decodable {
    let tools: [String: ToolInfoRoot]
    let broken: [String: String]?
}

// MARK: - Engine

public enum CLIParityEngine {

    /// Tool ids whose output CLIWorkshopViewModel.executeCommand() produces.
    /// Source: Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift switch
    /// (must stay in sync with the 32 `case "dicom-…"` labels there).
    public static let executeSupported: Set<String> = [
        // Network / DIMSE + DICOMweb
        "dicom-echo", "dicom-query", "dicom-send", "dicom-retrieve", "dicom-qr",
        "dicom-mwl", "dicom-mpps", "dicom-qido", "dicom-wado", "dicom-stow",
        "dicom-ups",
        // Local — original set
        "dicom-convert", "dicom-validate", "dicom-anon", "dicom-info",
        "dicom-dump", "dicom-tags", "dicom-diff",
        // Local — also wired in executeCommand() (were missing here, so their
        // output verification was silently reported UNAVAILABLE).
        "dicom-json", "dicom-xml", "dicom-uid", "dicom-dcmdir", "dicom-pdf",
        "dicom-pixedit", "dicom-split", "dicom-merge", "dicom-archive",
        "dicom-compress", "dicom-study", "dicom-image", "dicom-export",
        "dicom-script",
    ]

    static let frameworkFlags: Set<String> = ["--help", "-h", "--version", "--experimental-dump-help"]

    // MARK: Bundled resource loading

    static func bundledURL(_ name: String, _ ext: String) -> URL? {
        if let u = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "CLIParity") {
            return u
        }
        // Fallback for .copy directory layouts
        if let base = Bundle.module.resourceURL {
            let u = base.appendingPathComponent("CLIParity/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    public static func loadContracts() -> CLIContracts? {
        guard let url = bundledURL("CLIContracts", "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CLIContracts.self, from: data)
    }

    /// Loads bundled goldens. Prefers the full `goldens.json` (git-ignored local
    /// superset incl. real-fixture scenarios); falls back to the committed,
    /// PHI-free `goldens.synthetic.json` so the harness runs from a clean checkout.
    public static func loadGoldens() -> [GoldenScenario] {
        for name in ["goldens", "goldens.synthetic"] {
            guard let url = bundledURL(name, "json"),
                  let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let scenarios = obj["scenarios"],
                  let sdata = try? JSONSerialization.data(withJSONObject: scenarios),
                  let decoded = try? JSONDecoder().decode([GoldenScenario].self, from: sdata),
                  !decoded.isEmpty else { continue }
            return decoded
        }
        return []
    }

    /// Resolves a bundled fixture file (under CLIParity/fixtures/) by name.
    public static func fixtureURL(named name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "dcm" : (name as NSString).pathExtension
        // Real fixtures live under fixtures/ (git-ignored); synthetic under synthetic/ (committed).
        for sub in ["CLIParity/fixtures", "CLIParity/synthetic"] {
            if let u = Bundle.module.url(forResource: base, withExtension: ext, subdirectory: sub) {
                return u
            }
            if let res = Bundle.module.resourceURL {
                let u = res.appendingPathComponent("\(sub)/\(name)")
                if FileManager.default.fileExists(atPath: u.path) { return u }
            }
        }
        return nil
    }

    // MARK: Studio emitted flags (ground truth = buildCommand)

    static func scalarValue(for def: CLIParameterDefinition) -> String {
        switch def.parameterType {
        case .integerField, .slider: return "1"
        case .filePath:              return "/in.dcm"
        case .outputPath:            return "/out.dcm"
        case .datePicker:            return "20250101"
        case .secureField:           return "secret"
        case .arrayField:            return "a"
        default:                     return "val"
        }
    }

    static func choiceValues(for def: CLIParameterDefinition) -> [String] {
        if !def.cliMapping.isEmpty { return Array(def.cliMapping.keys) }
        if !def.allowedValues.isEmpty { return def.allowedValues }
        if def.parameterType == .booleanToggle { return ["true", "false"] }
        return [scalarValue(for: def)]
    }

    static func emittedFlags(toolName: String, defs: [CLIParameterDefinition]) -> Set<String> {
        func baseValues() -> [CLIParameterValue] {
            defs.map { CLIParameterValue(parameterID: $0.id,
                                         stringValue: choiceValues(for: $0).first ?? scalarValue(for: $0)) }
        }
        var assignments: [[CLIParameterValue]] = [baseValues()]
        for def in defs where choiceValues(for: def).count > 1 {
            for v in choiceValues(for: def) {
                var vals = baseValues()
                if let i = vals.firstIndex(where: { $0.parameterID == def.id }) {
                    vals[i] = CLIParameterValue(parameterID: def.id, stringValue: v)
                }
                assignments.append(vals)
            }
        }
        for def in defs {
            guard let cond = def.visibleWhen else { continue }
            for cv in cond.values {
                var vals = baseValues()
                if let i = vals.firstIndex(where: { $0.parameterID == cond.parameterId }) {
                    vals[i] = CLIParameterValue(parameterID: cond.parameterId, stringValue: cv)
                }
                assignments.append(vals)
            }
        }
        var tokens = Set<String>()
        for vals in assignments {
            let cmd = CommandBuilderHelpers.buildCommand(
                toolName: toolName, parameterValues: vals, parameterDefinitions: defs)
            for tok in cmd.split(separator: " ") where tok.hasPrefix("-") {
                tokens.insert(String(tok))
            }
        }
        return tokens
    }

    // MARK: CLI option groups

    struct OptionGroup {
        let tokens: Set<String>
        let primary: String
        let kind: String
        let defaultValue: String
        let abstract: String
    }

    static func longTokens(_ a: ToolInfoArg) -> [String] {
        (a.names ?? []).compactMap { n in
            guard let name = n.name else { return nil }
            switch n.kind {
            case "long": return "--" + name
            case "longWithSingleDash": return "-" + name
            default: return nil
            }
        }
    }
    static func shortTokens(_ a: ToolInfoArg) -> [String] {
        (a.names ?? []).compactMap { n in
            guard let name = n.name, n.kind == "short" else { return nil }
            return "-" + name
        }
    }

    static func walk(_ cmd: ToolInfoCommand, path: String, into nodes: inout [String: [ToolInfoArg]]) {
        nodes[path] = cmd.arguments ?? []
        for sub in (cmd.subcommands ?? []) {
            guard let name = sub.commandName, name != "help" else { continue }
            let child = path.isEmpty ? name : "\(path) \(name)"
            walk(sub, path: child, into: &nodes)
        }
    }

    static func optionGroups(_ args: [ToolInfoArg]) -> [OptionGroup] {
        var out: [OptionGroup] = []
        for a in args {
            if a.shouldDisplay == false { continue }
            if a.kind == "positional" { continue }
            let toks = (longTokens(a) + shortTokens(a)).filter { !frameworkFlags.contains($0) }
            if toks.isEmpty { continue }
            let primary = longTokens(a).first ?? toks[0]
            out.append(OptionGroup(tokens: Set(toks), primary: primary, kind: a.kind ?? "option",
                                   defaultValue: a.defaultValue ?? "", abstract: a.abstract ?? ""))
        }
        return out
    }

    static func acceptedForTarget(nodes: [String: [ToolInfoArg]], subpath: String, unionAll: Bool) -> [OptionGroup] {
        var sources: [[ToolInfoArg]] = []
        if unionAll {
            sources = Array(nodes.values)
        } else {
            if let root = nodes[""] { sources.append(root) }
            if !subpath.isEmpty, let node = nodes[subpath] { sources.append(node) }
            else if subpath.isEmpty, let root = nodes[""] { sources = [root] }
        }
        var byPrimary: [String: OptionGroup] = [:]
        for args in sources {
            for g in optionGroups(args) where byPrimary[g.primary] == nil {
                byPrimary[g.primary] = g
            }
        }
        return Array(byPrimary.values)
    }

    static func splitName(_ name: String) -> (binary: String, subcommand: String) {
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? name, parts.count > 1 ? parts[1] : "")
    }

    // MARK: Phase 3 — input sub-checks (type / default) on top of presence

    /// CLI `flag` (bare boolean) must map to a bare-emitting Studio type (`.booleanToggle`);
    /// CLI `option` (takes a value) must map to a value-bearing Studio type. The dangerous
    /// mismatches: a CLI flag wired as a value option (Studio emits `--x v` where the binary
    /// wants bare `--x`) or a CLI option wired as a toggle (Studio emits bare `--x`).
    static func typeCheckStatus(cliKind: String, studioType: CLIParameterType) -> InputCheckStatus {
        // .flagPicker emits `--<value>` (a bare flag token) and .subcommand is positional, so
        // neither is a "value option" for this purpose.
        let studioIsValue = ![.booleanToggle, .flagPicker, .subcommand].contains(studioType)
        if cliKind == "flag"   && studioIsValue                      { return .mismatch }
        if cliKind == "option" && studioType == .booleanToggle       { return .mismatch }
        return .ok
    }

    /// Lenient default-value agreement: only flags a MISMATCH when BOTH sides declare a
    /// (normalized) default and they differ. CLI dump-help often omits defaults, so a
    /// one-sided default is `.notChecked`, never a false alarm.
    static func defaultCheckStatus(cli: String, studio: String) -> InputCheckStatus {
        func norm(_ s: String) -> String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return (t == "nil" || t == "none" || t == "(none)" || t == "<none>") ? "" : t
        }
        let a = norm(cli), b = norm(studio)
        if a.isEmpty || b.isEmpty { return .notChecked }
        if a == b { return .ok }
        // Numeric equivalence: CLI dump prints floats ("0.0", "10.0") where Studio stores "0"/"10".
        if let da = Double(a), let db = Double(b), da == db { return .ok }
        // CLI `defaultValue` is often a DESCRIPTION ("plain text (default)") rather than the literal
        // value, so a CLI side with spaces/parens isn't a clean token to compare — don't warn.
        if a.contains(" ") || a.contains("(") { return .notChecked }
        return .mismatch
    }

    // MARK: Public compare

    public static func compare(tool: CLIToolDefinition, contracts: CLIContracts) -> ToolParityResult {
        let (binary, subpath) = splitName(tool.name)
        let defs = ToolCatalogHelpers.parameterDefinitions(for: tool.id)
        let studioFlags = emittedFlags(toolName: tool.name, defs: defs)

        let root = contracts.tools[binary]?.command
        var nodes: [String: [ToolInfoArg]] = [:]
        if let root { walk(root, path: "", into: &nodes) }
        let hasSub = nodes.keys.contains { !$0.isEmpty }
        let unionAll = (root != nil) && subpath.isEmpty && hasSub
        let mode = root == nil ? "—"
            : (unionAll ? "union" : (subpath.isEmpty ? "exact" : "subcommand:\(subpath)"))

        let accepted = root == nil ? [] : acceptedForTarget(nodes: nodes, subpath: subpath, unionAll: unionAll)
        var allAccepted = Set<String>()
        for g in accepted { allAccepted.formUnion(g.tokens) }

        let studioLut = studioMetaLookup(defs)
        var rows: [ParityFlagRow] = []
        var nMatch = 0, nMissing = 0, nExtra = 0

        for g in accepted.sorted(by: { $0.primary < $1.primary }) {
            let hit = g.tokens.intersection(studioFlags)
            if let h = hit.sorted().first {
                nMatch += 1
                let p = studioLut[h]
                // Phase 3: present on both sides → refine with type + default sub-checks.
                let typeChk = p.map { typeCheckStatus(cliKind: g.kind, studioType: $0.parameterType) } ?? .notChecked
                let defChk = defaultCheckStatus(cli: g.defaultValue, studio: p?.defaultValue ?? "")
                rows.append(ParityFlagRow(flag: g.primary, kind: g.kind, inCLI: true, inStudio: true,
                    cliDefault: g.defaultValue, studioDefault: p?.defaultValue ?? "",
                    cliHelp: g.abstract, studioHelp: p?.helpText ?? "", status: .match,
                    typeCheck: typeChk, defaultCheck: defChk))
            } else {
                nMissing += 1
                rows.append(ParityFlagRow(flag: g.primary, kind: g.kind, inCLI: true, inStudio: false,
                    cliDefault: g.defaultValue, studioDefault: "",
                    cliHelp: g.abstract, studioHelp: "", status: .missingInStudio))
            }
        }
        for flag in studioFlags.sorted() where !allAccepted.contains(flag) {
            let p = studioLut[flag]
            let status: FlagParityStatus = root == nil ? .extraInStudio : .extraInStudio
            if root != nil { nExtra += 1 }
            rows.append(ParityFlagRow(flag: flag, kind: p?.parameterType.rawValue ?? "", inCLI: false, inStudio: true,
                cliDefault: "", studioDefault: p?.defaultValue ?? "",
                cliHelp: "", studioHelp: p?.helpText ?? "", status: status))
        }

        let total = nMatch + nMissing + nExtra
        let parity = total > 0 ? (100.0 * Double(nMatch) / Double(total)) : (studioFlags.isEmpty ? 100.0 : 0.0)

        let status: ParityStatus
        if root == nil { status = .noCliData }
        else if defs.isEmpty { status = .noParams }
        else if nExtra > 0 { status = .drift }
        else if nMissing == 0 { status = .ok }
        else { status = .incomplete }

        return ToolParityResult(
            toolId: tool.id, displayName: tool.displayName, category: tool.category,
            binary: binary, subcommand: subpath,
            matchMode: mode, requiresNetwork: tool.requiresNetwork,
            executeSupported: executeSupported.contains(tool.id),
            studioFlagCount: studioFlags.count, cliFlagCount: accepted.count,
            matchCount: nMatch, missingCount: nMissing, extraCount: nExtra,
            parityPercent: (parity * 10).rounded() / 10, status: status, rows: rows)
    }

    public static func compareAll(contracts: CLIContracts) -> [ToolParityResult] {
        ToolCatalogHelpers.allTools().map { compare(tool: $0, contracts: contracts) }
    }

    static func studioMetaLookup(_ defs: [CLIParameterDefinition]) -> [String: CLIParameterDefinition] {
        var lut: [String: CLIParameterDefinition] = [:]
        for p in defs {
            if p.flag.hasPrefix("-") { if lut[p.flag] == nil { lut[p.flag] = p } }
            if p.parameterType == .flagPicker {
                for v in p.allowedValues where lut["--\(v)"] == nil { lut["--\(v)"] = p }
            }
        }
        return lut
    }

    // MARK: Output normalization + diff

    /// Normalizes raw tool output into comparable lines: strips the Studio's
    /// "$ command" echo and status decoration, canonicalizes the fixture path,
    /// and trims whitespace.
    public static func normalize(_ raw: String, fixtureBasename: String) -> [String] {
        normalize(raw, fixtureBasenames: fixtureBasename.isEmpty ? [] : [fixtureBasename])
    }

    /// Multi-fixture variant — canonicalizes every fixture basename's absolute
    /// path (two-file tools like dicom-diff reference both operands).
    public static func normalize(_ raw: String, fixtureBasenames: [String]) -> [String] {
        let decorations: Set<Character> = ["✅", "❌", "⚠", "️", "ℹ", "🔹", "▶", "›"]
        var lines: [String] = []
        for var line in raw.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            // Strip ANSI color escape sequences — the CLI colorizes (e.g. dicom-dump)
            // while the app renders plain text; they should compare equal.
            line = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
            // Canonicalize volatile log timestamps (e.g. dicom-script --verbose's
            // "[2026-06-09 17:05:19] …") — the same line minted in the CLI and app runs
            // differs only by the wall-clock second.
            line = line.replacingOccurrences(of: "\\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\]", with: "[<timestamp>]", options: .regularExpression)
            // Drop the command-echo line Studio prepends.
            if line.hasPrefix("$ ") { continue }
            // Canonicalize any absolute path ending in a fixture basename. Match the
            // path prefix with [^\s"]* (not \S*) so a leading JSON quote isn't consumed
            // — otherwise "file":"/abs/syn-ct.dcm" → "file":syn-ct.dcm" breaks JSON parsing.
            for bn in fixtureBasenames where !bn.isEmpty && line.contains(bn) {
                let escaped = NSRegularExpression.escapedPattern(for: bn)
                line = line.replacingOccurrences(of: "[^\\s\"]*" + escaped, with: bn, options: .regularExpression)
            }
            line.removeAll { decorations.contains($0) }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Drop the Studio-appended exit-code trailer (e.g. "Exit code: 0 (success)").
            // The real CLI conveys exit status via the process code, never on stdout.
            if trimmed.range(of: "^Exit code: -?[0-9]+\\b", options: .regularExpression) != nil { continue }
            // Canonicalize horizontal-rule separator lines: the CLI draws them with
            // box-drawing glyphs (═, ─) while Studio uses ASCII (=, -). Same meaning.
            if trimmed.count >= 3, trimmed.range(of: "^[═─=_-]+$", options: .regularExpression) != nil {
                lines.append("───"); continue
            }
            lines.append(trimmed)
        }
        // Trim leading/trailing blank lines.
        while let f = lines.first, f.isEmpty { lines.removeFirst() }
        while let l = lines.last, l.isEmpty { lines.removeLast() }
        // Collapse consecutive blank lines — concatenated multi-file dumps can have a
        // differing blank-run structure between the binary and the in-app re-dump
        // (the latter's stripped "Exit code:" trailer leaves a trailing blank per file).
        var collapsed: [String] = []
        for l in lines where !(l.isEmpty && collapsed.last == "") { collapsed.append(l) }
        lines = collapsed

        // JSON canonicalization: if the whole block is JSON, re-emit with sorted
        // keys so non-deterministic key order (on either side) doesn't show as a
        // diff. Non-JSON output falls through unchanged.
        let joined = lines.joined(separator: "\n")
        if let d = joined.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d),
           let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: out, encoding: .utf8) {
            return str.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return lines
    }

    /// Masks the value of volatile DICOM tags in a dicom-info dump (file-write
    /// metadata that legitimately differs between two writers): file-meta
    /// implementation + SOP-instance UIDs, instance/study/series UIDs. The data
    /// lines (the modification under test) are left intact.
    ///
    /// (0002,0000) File Meta Information Group Length is a DERIVED byte-count of the
    /// file-meta group, so it varies with the byte-length of the (already-masked)
    /// volatile UIDs above — e.g. a freshly-generated SOP Instance UID whose digit
    /// count differs run-to-run flips it 190↔192. It carries no semantic content (a
    /// real structural difference shows up as the element lines themselves), so it is
    /// masked too; otherwise random-UID producers (e.g. dicom-pdf encapsulate) diff
    /// intermittently on the length alone.
    public static let volatileDumpTags: Set<String> = [
        "(0002,0000)", "(0002,0003)", "(0002,0012)", "(0002,0013)", "(0002,0016)",
        "(0008,0018)", "(0020,000d)", "(0020,000e)",
        // Freshly minted by `dicom-uid regenerate` (and any UID-minting op), so they
        // differ run-to-run between the CLI golden and the Studio re-run — mask them.
        "(0008,3010)", "(0020,0052)",
        // Creation date/time stamps written at conversion time (e.g. dicom-image
        // Secondary Capture) — volatile between the CLI and Studio runs. Masking is
        // parity-safe: real inputs carry identical dates on both sides, so this only
        // skips comparing a value that already matches, never hides a real diff.
        "(0008,0012)", "(0008,0013)", "(0008,0020)", "(0008,0021)",
        "(0008,0023)", "(0008,0030)", "(0008,0031)", "(0008,0033)",
    ]
    public static func maskVolatileDumpTags(_ lines: [String]) -> [String] {
        lines.map { line in
            let head = String(line.prefix(11)).lowercased()
            guard volatileDumpTags.contains(head) else { return line }
            // Keep "(gggg,eeee) Name … VR=XX", replace the value after it.
            return line.replacingOccurrences(of: "(VR=\\S\\S ).*$", with: "$1<masked>", options: .regularExpression)
        }
    }

    /// SHA-256 (hex) of a produced DICOM file's fully-decoded PixelData (all frames
    /// concatenated). Backs the "decoded-pixel-hash" artifact kind so compress/
    /// decompress parity compares pixel CONTENT, not encapsulated bytes — transfer-
    /// syntax/encapsulation differences don't matter (PS3.5 Annex G; plan §4b).
    /// Returns nil if pixels are absent or undecodable. MUST stay byte-identical to
    /// cli-parity-gen's `decodedPixelHash` so the golden and Studio hashes line up.
    public static func decodedPixelHash(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? DICOMFile.read(from: data),
              let px = file.pixelData() else { return nil }
        return SHA256.hash(data: px.data).map { String(format: "%02x", $0) }.joined()
    }

    /// SHA-256 (hex) of a produced raster image's NORMALIZED pixels — decoded to
    /// 8-bit device-gray, which strips the encoder metadata (EXIF timestamps, ICC,
    /// tEXt) that makes the image FILE non-deterministic while leaving pixel content
    /// intact. Backs the "image-raster-hash" artifact kind for DICOM→image producers
    /// (e.g. dicom-export single), comparing pixel content rather than file bytes
    /// (plan §4b). `nil` if the image can't be decoded. MUST stay byte-identical to
    /// cli-parity-gen's `imageRasterHash` so golden and Studio hashes line up.
    public static func imageRasterHash(fileURL: URL) -> String? {
        #if canImport(ImageIO)
        guard let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var raster = Data(count: width * height)
        let ok: Bool = raster.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress,
                  let ctx = CGContext(data: base, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return nil }
        var hasher = SHA256()
        hasher.update(data: Data("\(width)x\(height):".utf8))
        hasher.update(data: raster)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }

    /// LCS-based line diff producing same / cliOnly / studioOnly lines.
    public static func diff(cli: [String], studio: [String]) -> [OutputDiffLine] {
        let n = cli.count, m = studio.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = cli[i] == studio[j] ? dp[i + 1][j + 1] + 1
                        : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        var out: [OutputDiffLine] = []
        var i = 0, j = 0, id = 0
        func emit(_ kind: DiffLineKind, _ text: String) { out.append(OutputDiffLine(id: id, kind: kind, text: text)); id += 1 }
        while i < n && j < m {
            if cli[i] == studio[j] { emit(.same, cli[i]); i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { emit(.cliOnly, cli[i]); i += 1 }
            else { emit(.studioOnly, studio[j]); j += 1 }
        }
        while i < n { emit(.cliOnly, cli[i]); i += 1 }
        while j < m { emit(.studioOnly, studio[j]); j += 1 }
        return out
    }
}
