// CLIParityScenarioGenerator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// In-app port of the offline `cli-parity-gen` scenario matrix (Sources/
// cli-parity-gen/main.swift autoTools / autoValues / autoTemplates). Given a
// tool id, it produces a BOUNDED set of test scenarios — one flag at a time,
// enum-expanded, NOT Cartesian — derived from the SAME source of truth the app
// and CLI use (ToolCatalogHelpers.parameterDefinitions + buildCommand), so the
// app's argv and the CLI's argv cannot skew.
//
// Unlike the offline generator, the FIXTURE is the USER's selected file (a
// `FIXTURE`/`FIXTURE2` placeholder resolved at run time), not a bundled fixture.

import Foundation

public enum CLIParityScenarioGenerator {

    // MARK: Per-tool config (ported from cli-parity-gen autoTools)

    /// Encodes, per tool, which parameter ids carry the input file(s), an optional
    /// subcommand parameter to iterate, always-set baseline params (so a one-flag
    /// scenario runs on a working baseline), and the output param + artifact kind
    /// for file producers.
    struct AutoTool {
        let id: String
        let inputKeys: [String]
        var subcommandParam: String? = nil
        var baselineParams: [String: String] = [:]
        var outputParam: String? = nil
        var artifactKind: String = "dicom"
        var artifactExt: String = "dcm"
        var configLabel: String = ""
        var onlySubcommands: [String]? = nil
        /// True when the tool's input must be a DIRECTORY of DICOM files (not a
        /// single file) — surfaced so a single-file input skips with a clear note.
        var requiresDirectory: Bool = false
        /// Human hint about the expected input shape, shown in the UI.
        var inputHint: String = "DICOM file"
    }

    static let autoTools: [AutoTool] = [
        AutoTool(id: "dicom-diff", inputKeys: ["file1", "file2"], inputHint: "two DICOM files"),
        AutoTool(id: "dicom-info", inputKeys: ["inputPath"]),
        AutoTool(id: "dicom-dump", inputKeys: ["inputPath"]),
        AutoTool(id: "dicom-validate", inputKeys: ["inputPath"]),
        AutoTool(id: "dicom-compress", inputKeys: ["input"], subcommandParam: "operation"),
        // STDOUT subcommands of dicom-study (summary/check/stats/compare). organize
        // is EXCLUDED here — it's an artifact (--output) subcommand handled by the
        // dedicated config below. Its positional id is "path" (organize's is "input").
        AutoTool(id: "dicom-study", inputKeys: ["path"], subcommandParam: "operation",
                 onlySubcommands: ["summary", "check", "stats", "compare"],
                 requiresDirectory: true, inputHint: "study directory"),
        // dicom-study organize: writes a Patient/Study/Series .dcm tree to --output.
        // --copy (not move) preserves the input; pattern (descriptive/uid) is swept.
        AutoTool(id: "dicom-study", inputKeys: ["input"], subcommandParam: "operation",
                 baselineParams: ["copy": "true"],
                 outputParam: "output", artifactKind: "dicom-tree", artifactExt: "dcm",
                 onlySubcommands: ["organize"],
                 requiresDirectory: true, inputHint: "study DIRECTORY of DICOM files"),
        AutoTool(id: "dicom-archive", inputKeys: ["archive"], subcommandParam: "subcommand",
                 requiresDirectory: true, inputHint: "archive directory"),
        // --- Artifact producers (compare the produced FILE, not stdout) ---
        AutoTool(id: "dicom-anon", inputKeys: ["inputPath"],
                 baselineParams: ["profile": "basic"], outputParam: "output",
                 artifactKind: "dicom", artifactExt: "dcm"),
        AutoTool(id: "dicom-pixedit", inputKeys: ["inputPath"],
                 outputParam: "output", artifactKind: "dicom", artifactExt: "dcm"),
        AutoTool(id: "dicom-json", inputKeys: ["inputPath"],
                 outputParam: "output", artifactKind: "text", artifactExt: "json"),
        AutoTool(id: "dicom-xml", inputKeys: ["input"],
                 outputParam: "output", artifactKind: "text", artifactExt: "xml"),
        AutoTool(id: "dicom-export", inputKeys: ["inputPath"], subcommandParam: "operation",
                 baselineParams: ["format": "png"], outputParam: "output",
                 artifactKind: "image-raster-hash", artifactExt: "png"),
        // DICOM-mode config: baseline --format dicom so every scenario writes a .dcm
        // (reduced via dicom re-dump). The img- config below owns image output. (The
        // offline gen uses "auto" + a post-hoc file sniff; in-app we split the two
        // modes so each scenario's artifactKind is known up front.)
        AutoTool(id: "dicom-convert", inputKeys: ["inputPath"],
                 baselineParams: ["format": "dicom"], outputParam: "output",
                 artifactKind: "dicom", artifactExt: "dcm"),
        AutoTool(id: "dicom-convert", inputKeys: ["inputPath"],
                 baselineParams: ["format": "png"], outputParam: "output",
                 artifactKind: "image-raster-hash", artifactExt: "png", configLabel: "img-"),
        AutoTool(id: "dicom-split", inputKeys: ["inputPath"],
                 outputParam: "output", artifactKind: "dicom-multi", artifactExt: "dcm",
                 inputHint: "multiframe DICOM file"),
        AutoTool(id: "dicom-tags", inputKeys: ["inputPath"],
                 outputParam: "output", artifactKind: "dicom", artifactExt: "dcm"),
        AutoTool(id: "dicom-compress", inputKeys: ["input"], subcommandParam: "operation",
                 baselineParams: ["codec": "rle"], outputParam: "output", artifactKind: "dicom",
                 artifactExt: "dcm", configLabel: "art-", onlySubcommands: ["compress"]),
    ]

    /// Tool ids this screen can sweep. (Each is also non-network and execute-supported.)
    public static let supportedToolIDs: Set<String> = Set(autoTools.map { $0.id })

    /// Tools whose CLI uses a NONZERO exit code as a normal RESULT rather than an
    /// error: `dicom-diff` exits 1 when the two files differ (the app mirrors this,
    /// CLIWorkshopViewModel returns `hasDifferences ? 1 : 0`). For these, app+CLI
    /// agreement on a nonzero exit is still compared, not flagged as a CLI error.
    /// (dicom-anon / dicom-compress nonzero exits ARE genuine errors — excluded.)
    public static let resultExitTools: Set<String> = ["dicom-diff"]

    /// A human hint about the expected input for a tool (first matching config).
    public static func inputHint(for toolId: String) -> String {
        autoTools.first { $0.id == toolId }?.inputHint ?? "DICOM file"
    }

    // MARK: Representative values (ported from cli-parity-gen autoValues)

    /// A representative value (or values, for enums) for a one-flag-at-a-time
    /// scenario, or [] when there is no safe generic value (a wrong guess simply
    /// makes the binary reject the combo → that row is SKIPPED, never a failure).
    static func autoValues(_ def: CLIParameterDefinition) -> [String] {
        if def.parameterType == .booleanToggle { return ["true"] }
        if !def.allowedValues.isEmpty { return def.allowedValues }   // enum: cover each value
        switch def.parameterType {
        case .integerField, .slider: return [String(def.minValue ?? 1)]
        case .textField, .arrayField:
            let key = (def.id + " " + def.flag).lowercased()
            if key.contains("tag") || key.contains("highlight") { return ["0008,0060"] }
            if key.contains("replace")        { return ["0010,0010=ANONYMIZED"] }
            if key.contains("keep") || key.contains("remove") { return ["0010,0010"] }
            if key.contains("window-center")  { return ["40"] }
            if key.contains("window-width")   { return ["400"] }
            if key.contains("shift") || key.contains("days") { return ["30"] }
            if key.contains("quality")        { return ["85"] }
            if key.contains("scale")          { return ["0.5"] }
            if key.contains("fps")            { return ["10"] }
            if key.contains("frame")          { return ["0"] }
            if key.contains("crop")           { return ["0,0,8,8"] }
            if key.contains("url")            { return ["https://example.org/{uid}"] }
            if key.contains("codec")          { return ["rle"] }
            if key.contains("syntax")         { return ["explicit-le"] }
            if key.contains("exif")           { return ["PatientName"] }
            if key.contains("variable")       { return ["VAR=value"] }
            if key.contains("title")          { return ["Parity Doc"] }
            return []
        default: return []
        }
    }

    // MARK: Scenario generation

    /// Generates the bounded scenario sweep for one tool: a baseline per
    /// subcommand plus one scenario per uncovered, varied flag (enum-expanded).
    public static func scenarios(for toolId: String) -> [BatchScenario] {
        var out: [BatchScenario] = []
        for at in autoTools where at.id == toolId {
            let defs = ToolCatalogHelpers.parameterDefinitions(for: at.id)
            let needsSecond = at.inputKeys.count >= 2
            let needsInput = !at.inputKeys.isEmpty
            let artifactName = at.outputParam != nil ? "out.\(at.artifactExt)" : nil
            let artifactKind = at.outputParam != nil ? at.artifactKind : "stdout"

            // Subcommands to iterate (flat tool → [nil]).
            let subcommands: [String?]
            if let scParam = at.subcommandParam,
               let scDef = defs.first(where: { $0.id == scParam }), !scDef.allowedValues.isEmpty {
                let allowed = at.onlySubcommands.map { only in scDef.allowedValues.filter { only.contains($0) } }
                    ?? scDef.allowedValues
                subcommands = allowed.map { Optional($0) }
            } else {
                subcommands = [nil]
            }

            // Shared param/arg seed for a scenario: inputs + subcommand + baseline + OUTPUT.
            func seed(subcommand sc: String?) -> (pv: [CLIParameterValue], sp: [String: String]) {
                var pv: [CLIParameterValue] = at.inputKeys.enumerated().map {
                    CLIParameterValue(parameterID: $1, stringValue: $0 == 0 ? "FIXTURE" : "FIXTURE2")
                }
                var sp: [String: String] = [:]
                for (i, key) in at.inputKeys.enumerated() { sp[key] = i == 0 ? "FIXTURE" : "FIXTURE2" }
                if let scParam = at.subcommandParam, let sc {
                    pv.append(CLIParameterValue(parameterID: scParam, stringValue: sc)); sp[scParam] = sc
                }
                for (k, v) in at.baselineParams {
                    pv.append(CLIParameterValue(parameterID: k, stringValue: v)); sp[k] = v
                }
                if let op = at.outputParam {
                    pv.append(CLIParameterValue(parameterID: op, stringValue: "OUTPUT")); sp[op] = "OUTPUT"
                }
                return (pv, sp)
            }

            func makeScenario(label: String, pv: [CLIParameterValue], sp: [String: String]) -> BatchScenario? {
                let cmd = CommandBuilderHelpers.buildCommand(toolName: at.id, parameterValues: pv,
                                                             parameterDefinitions: defs)
                var toks = cmd.split(separator: " ").map(String.init)
                if !toks.isEmpty { toks.removeFirst() }   // drop the tool name
                return BatchScenario(
                    scenarioId: "\(at.id)::\(label)", toolId: at.id, label: label,
                    cliArgs: toks, studioParams: sp,
                    needsInputFile: needsInput, needsSecondFile: needsSecond,
                    artifactName: artifactName, artifactKind: artifactKind,
                    needsDirectory: at.requiresDirectory, inputHint: at.inputHint)
            }

            for sc in subcommands {
                let scPrefix = sc.map { "\($0)-" } ?? ""
                let (basePV, baseSP) = seed(subcommand: sc)

                // 1) Baseline scenario (inputs + subcommand + baseline, no extra flag).
                if let s = makeScenario(label: "auto-\(at.configLabel)\(scPrefix)baseline",
                                        pv: basePV, sp: baseSP) {
                    out.append(s)
                }

                // 2) One flag at a time, enum-expanded.
                for def in defs {
                    if def.isInternal || def.flag.isEmpty { continue }            // skip internal + positionals
                    if def.parameterType == .subcommand || def.id == at.subcommandParam { continue }
                    if def.parameterType == .filePath || def.parameterType == .outputPath { continue }
                    if def.id == at.outputParam || at.baselineParams[def.id] != nil { continue }
                    // Artifact producers: skip "no-write" preview flags (comparing a produced file is moot).
                    if at.outputParam != nil &&
                        (def.id.lowercased().contains("dry") || def.flag.contains("dry-run")) { continue }

                    for value in autoValues(def) {
                        var pv = basePV
                        pv.append(CLIParameterValue(parameterID: def.id, stringValue: value))
                        var sp = baseSP
                        sp[def.id] = value
                        let suffix = def.allowedValues.count > 1 ? "-\(value)" : ""
                        let label = "auto-\(at.configLabel)\(scPrefix)\(def.id)\(suffix)"
                        guard let s = makeScenario(label: label, pv: pv, sp: sp) else { continue }
                        // Self-check: the flag must actually be emitted (else not visible under `sc`).
                        guard s.cliArgs.contains(def.flag) || s.cliArgs.contains("--\(value)") else { continue }
                        out.append(s)
                    }
                }
            }
        }
        return out
    }
}
