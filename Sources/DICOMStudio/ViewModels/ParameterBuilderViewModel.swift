// ParameterBuilderViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Dynamic GUI Controls & Parameter Builder (Milestone 21)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class ParameterBuilderViewModel {
    private let service: ParameterBuilderService

    // 21.3 Dynamic Form State
    public var formState: ParameterFormState = ParameterFormState(toolName: "")

    // 21.4 Network Parameter Injection
    public var networkInjection: NetworkInjectionState = NetworkInjectionState()

    // 21.5 Subcommand Handling
    public var subcommandState: SubcommandState? = nil

    // 21.2 Tool Parameter Catalog
    public var toolConfig: ToolParameterConfig? = nil

    public init(service: ParameterBuilderService = ParameterBuilderService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        formState        = service.getFormState()
        networkInjection = service.getNetworkInjection()
        subcommandState  = service.getSubcommandState()
        toolConfig       = service.getToolConfig()
    }

    // MARK: - 21.2 Tool Parameter Catalog

    /// Returns configurations for all catalogued CLI tools.
    public func allToolConfigs() -> [ToolParameterConfig] {
        service.allToolConfigs()
    }

    /// Loads the parameter form for the given CLI tool name.
    ///
    /// Resets the form, selects the first subcommand (if any), and re-applies
    /// any active server injection.
    public func loadTool(_ toolName: String) {
        service.loadTool(toolName)
        loadFromService()
    }

    // MARK: - 21.3 Dynamic Form Renderer

    /// Updates the value for a single parameter and refreshes the form state.
    public func updateValue(_ value: ParameterValue?, for parameterName: String) {
        service.updateValue(value, for: parameterName)
        formState = service.getFormState()
    }

    /// Resets all form fields to their default values.
    public func resetToDefaults() {
        service.resetToDefaults()
        loadFromService()
    }

    /// The current generated CLI command string.
    public var generatedCommand: String { formState.generatedCommand }

    /// Whether all required parameters have valid values.
    public var isValid: Bool { formState.isValid }

    /// Entries that are currently visible given the form's current values.
    public var visibleEntries: [ParameterFormEntry] {
        let currentValues = Dictionary(
            uniqueKeysWithValues: formState.entries.compactMap { entry -> (String, ParameterValue)? in
                guard let v = entry.currentValue else { return nil }
                return (entry.definition.name, v)
            }
        )
        return formState.entries.filter {
            FormRenderingHelpers.isVisible(entry: $0, currentValues: currentValues)
        }
    }

    /// Returns entries grouped by their `group` label.
    ///
    /// Entries with a `nil` group are placed under the key `""` (empty string).
    public var entriesByGroup: [(group: String, entries: [ParameterFormEntry])] {
        var order: [String] = []
        var grouped: [String: [ParameterFormEntry]] = [:]
        for entry in visibleEntries {
            let g = entry.definition.group ?? ""
            if grouped[g] == nil {
                order.append(g)
                grouped[g] = []
            }
            grouped[g]!.append(entry)
        }
        return order.map { g in (group: g, entries: grouped[g]!) }
    }

    // MARK: - 21.4 Network Parameter Integration

    /// Activates server parameter injection using `injection` and refreshes the form.
    public func setNetworkInjection(_ injection: NetworkInjectionState) {
        service.setNetworkInjection(injection)
        loadFromService()
    }

    /// Clears all server-injected parameter values and refreshes the form.
    public func clearNetworkInjection() {
        service.clearNetworkInjection()
        loadFromService()
    }

    // MARK: - 21.5 Subcommand Handling

    /// Selects the given subcommand, replacing the form's parameter list accordingly.
    public func selectSubcommand(_ subcommandName: String) {
        service.selectSubcommand(subcommandName)
        loadFromService()
    }

    /// Returns the names of all available subcommands for the current tool.
    public var subcommandNames: [String] {
        guard let state = subcommandState else { return [] }
        return state.subcommands.map(\.name)
    }

    /// The currently selected subcommand token, or `nil` when none applies.
    public var selectedSubcommand: String? { formState.selectedSubcommand }
}
