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
    /// Source: Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift switch.
    public static let executeSupported: Set<String> = [
        "dicom-echo", "dicom-query", "dicom-send", "dicom-retrieve", "dicom-qr",
        "dicom-mwl", "dicom-mpps", "dicom-qido", "dicom-wado", "dicom-stow",
        "dicom-ups", "dicom-convert", "dicom-validate", "dicom-anon", "dicom-info",
        "dicom-dump", "dicom-tags", "dicom-diff",
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

    public static func loadGoldens() -> [GoldenScenario] {
        guard let url = bundledURL("goldens", "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scenarios = obj["scenarios"] else { return [] }
        guard let sdata = try? JSONSerialization.data(withJSONObject: scenarios) else { return [] }
        return (try? JSONDecoder().decode([GoldenScenario].self, from: sdata)) ?? []
    }

    /// Resolves a bundled fixture file (under CLIParity/fixtures/) by name.
    public static func fixtureURL(named name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "dcm" : (name as NSString).pathExtension
        if let u = Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "CLIParity/fixtures") {
            return u
        }
        if let res = Bundle.module.resourceURL {
            let u = res.appendingPathComponent("CLIParity/fixtures/\(name)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
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
                rows.append(ParityFlagRow(flag: g.primary, kind: g.kind, inCLI: true, inStudio: true,
                    cliDefault: g.defaultValue, studioDefault: p?.defaultValue ?? "",
                    cliHelp: g.abstract, studioHelp: p?.helpText ?? "", status: .match))
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
        let decorations: Set<Character> = ["✅", "❌", "⚠", "️", "ℹ", "🔹", "▶", "›"]
        let escaped = NSRegularExpression.escapedPattern(for: fixtureBasename)
        var lines: [String] = []
        for var line in raw.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            // Strip ANSI color escape sequences — the CLI colorizes (e.g. dicom-dump)
            // while the app renders plain text; they should compare equal.
            line = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
            // Drop the command-echo line Studio prepends.
            if line.hasPrefix("$ ") { continue }
            // Canonicalize any absolute path ending in the fixture basename.
            if !fixtureBasename.isEmpty && line.contains(fixtureBasename) {
                line = line.replacingOccurrences(of: "\\S*" + escaped, with: fixtureBasename, options: .regularExpression)
            }
            line.removeAll { decorations.contains($0) }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            lines.append(trimmed)
        }
        // Trim leading/trailing blank lines.
        while let f = lines.first, f.isEmpty { lines.removeFirst() }
        while let l = lines.last, l.isEmpty { lines.removeLast() }
        return lines
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
