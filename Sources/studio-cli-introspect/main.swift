// studio-cli-introspect
//
// Developer tool — NOT shipped in DICOMStudio.app.
//
// Dumps the DICOMStudio "CLI Tools Workshop" tool catalog
// (`ToolCatalogHelpers.allTools()` + `parameterDefinitions(for:)`) to JSON on
// stdout, so it can be diffed against the real `dicom-*` binaries'
// `--experimental-dump-help` output by Scripts/cli_parity_report.py.
//
// This is the "UI side" of the CLI parity harness: it serialises exactly what
// the Studio believes each tool's input contract to be (flags, types,
// defaults, required-ness), which is what drifts from the real ArgumentParser
// commands.
//
// Usage:
//   swift run studio-cli-introspect > studio-catalog.json

import Foundation
import DICOMStudio

// MARK: - JSON mirror types (the model structs aren't Codable)

private struct CatalogDumpJSON: Encodable {
    let schemaVersion: Int
    let toolCount: Int
    let tools: [ToolJSON]
}

private struct ToolJSON: Encodable {
    let id: String
    let name: String
    let displayName: String
    let category: String
    let hasSubcommands: Bool
    let requiresNetwork: Bool
    let networkToolGroup: String?
    /// The flag/option tokens (`--foo`, `-o`) that `buildCommand()` actually
    /// emits — the TRUE Studio invocation contract. This already accounts for
    /// positional-endpoint folding (host/port -> `host:port`), flagPicker
    /// (`--value`), and internal `cliMapping` tokens. The parity report
    /// compares THIS against the CLI, not the raw `parameters[].flag`.
    let emittedFlags: [String]
    let parameters: [ParameterJSON]
}

private struct ParameterJSON: Encodable {
    let id: String
    let flag: String
    let isPositional: Bool
    let displayName: String
    let type: String
    let isRequired: Bool
    let isAdvanced: Bool
    let isInternal: Bool
    let defaultValue: String
    let allowedValues: [String]
    let placeholder: String
    let minValue: Int?
    let maxValue: Int?
    let visibleWhenParameterId: String?
    let visibleWhenValues: [String]
}

// MARK: - Emitted-flag discovery (ground truth = buildCommand())

/// A representative non-empty scalar value for a parameter type.
private func scalarValue(for def: CLIParameterDefinition) -> String {
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

/// The candidate values worth trying for a parameter when discovering which
/// flags it can contribute. Enum/flag/subcommand/internal-mapped/boolean params
/// are varied across all their values so visibility-gated and flagPicker
/// tokens are all revealed.
private func choiceValues(for def: CLIParameterDefinition) -> [String] {
    if !def.cliMapping.isEmpty { return Array(def.cliMapping.keys) }
    if !def.allowedValues.isEmpty { return def.allowedValues }
    if def.parameterType == .booleanToggle { return ["true", "false"] }
    return [scalarValue(for: def)]
}

/// Discover every flag/option token `buildCommand()` can emit for a tool, by
/// running it once with all parameters populated and once per choice-value of
/// each multi-valued parameter, then unioning the dash-prefixed tokens.
private func emittedFlags(toolName: String, defs: [CLIParameterDefinition]) -> [String] {
    func baseValues() -> [CLIParameterValue] {
        defs.map { def in
            CLIParameterValue(parameterID: def.id,
                              stringValue: choiceValues(for: def).first ?? scalarValue(for: def))
        }
    }

    var assignments: [[CLIParameterValue]] = [baseValues()]

    // (a) Vary each multi-valued parameter across all its values so flagPicker
    //     forms and value-dependent branches are revealed.
    for def in defs {
        let choices = choiceValues(for: def)
        guard choices.count > 1 else { continue }
        for v in choices {
            var vals = baseValues()
            if let idx = vals.firstIndex(where: { $0.parameterID == def.id }) {
                vals[idx] = CLIParameterValue(parameterID: def.id, stringValue: v)
            }
            assignments.append(vals)
        }
    }

    // (b) For every parameter gated by a `visibleWhen` condition, explicitly set
    //     its CONTROLLING parameter to each gate-opening value. This guarantees
    //     each conditional flag (e.g. dicom-ups operation-specific fields) gets a
    //     scenario in which it is visible, independent of dictionary ordering.
    for def in defs {
        guard let cond = def.visibleWhen else { continue }
        for cv in cond.values {
            var vals = baseValues()
            if let idx = vals.firstIndex(where: { $0.parameterID == cond.parameterId }) {
                vals[idx] = CLIParameterValue(parameterID: cond.parameterId, stringValue: cv)
            }
            assignments.append(vals)
        }
    }

    var tokens = Set<String>()
    for vals in assignments {
        let cmd = CommandBuilderHelpers.buildCommand(
            toolName: toolName,
            parameterValues: vals,
            parameterDefinitions: defs
        )
        for tok in cmd.split(separator: " ") where tok.hasPrefix("-") {
            tokens.insert(String(tok))
        }
    }
    return tokens.sorted()
}

// MARK: - Build the dump from the live catalog

private func buildDump() -> CatalogDumpJSON {
let tools = ToolCatalogHelpers.allTools().map { tool -> ToolJSON in
    let params = ToolCatalogHelpers.parameterDefinitions(for: tool.id).map { def -> ParameterJSON in
        ParameterJSON(
            id: def.id,
            flag: def.flag,
            isPositional: def.flag.isEmpty,
            displayName: def.displayName,
            type: def.parameterType.rawValue,
            isRequired: def.isRequired,
            isAdvanced: def.isAdvanced,
            isInternal: def.isInternal,
            defaultValue: def.defaultValue,
            allowedValues: def.allowedValues,
            placeholder: def.placeholder,
            minValue: def.minValue,
            maxValue: def.maxValue,
            visibleWhenParameterId: def.visibleWhen?.parameterId,
            visibleWhenValues: def.visibleWhen?.values ?? []
        )
    }
    let defs = ToolCatalogHelpers.parameterDefinitions(for: tool.id)
    return ToolJSON(
        id: tool.id,
        name: tool.name,
        displayName: tool.displayName,
        category: tool.category.rawValue,
        hasSubcommands: tool.hasSubcommands,
        requiresNetwork: tool.requiresNetwork,
        networkToolGroup: tool.networkToolGroup.map { String(describing: $0) },
        emittedFlags: emittedFlags(toolName: tool.name, defs: defs),
        parameters: params
    )
}

return CatalogDumpJSON(schemaVersion: 1, toolCount: tools.count, tools: tools)
}

private let dump = buildDump()

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

do {
    let data = try encoder.encode(dump)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A])) // trailing newline
} catch {
    FileHandle.standardError.write(Data("studio-cli-introspect: failed to encode catalog: \(error)\n".utf8))
    exit(1)
}
