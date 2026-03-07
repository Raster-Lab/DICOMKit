// ParameterBuilderService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Dynamic GUI Controls & Parameter Builder (Milestone 21)

import Foundation

/// Thread-safe service that manages state for the Dynamic GUI Controls & Parameter Builder feature.
public final class ParameterBuilderService: @unchecked Sendable {
    private let lock = NSLock()

    // 21.3 Dynamic Form State
    private var _formState: ParameterFormState = ParameterFormState(toolName: "")

    // 21.4 Network Parameter Injection
    private var _networkInjection: NetworkInjectionState = NetworkInjectionState()

    // 21.5 Subcommand Handling
    private var _subcommandState: SubcommandState? = nil

    // 21.2 Currently loaded tool config
    private var _toolConfig: ToolParameterConfig? = nil

    public init() {}

    // MARK: - 21.2 Tool Parameter Catalog

    /// Returns the parameter configuration for the given tool name, or `nil` when not catalogued.
    public func config(for toolName: String) -> ToolParameterConfig? {
        ParameterCatalogHelpers.config(for: toolName)
    }

    /// Returns configurations for all catalogued tools.
    public func allToolConfigs() -> [ToolParameterConfig] {
        ParameterCatalogHelpers.allToolConfigs()
    }

    /// Returns the currently loaded `ToolParameterConfig`, or `nil` when no tool is loaded.
    public func getToolConfig() -> ToolParameterConfig? { lock.withLock { _toolConfig } }

    /// Loads the parameter configuration for `toolName` and resets the form state.
    ///
    /// If the tool has subcommands, a `SubcommandState` is created with no selection.
    /// If the tool has no subcommands, the subcommand state is set to `nil`.
    public func loadTool(_ toolName: String) {
        guard let cfg = ParameterCatalogHelpers.config(for: toolName) else { return }
        lock.withLock {
            _toolConfig = cfg

            let initialParams: [ToolParameterDefinition]
            let initialSubcmd: String?

            if cfg.hasSubcommands, let first = cfg.subcommands.first {
                initialSubcmd = first.name
                initialParams = first.parameters
            } else {
                initialSubcmd = nil
                initialParams = cfg.parameters
            }

            let entries: [ParameterFormEntry] = initialParams.map { defn in
                ParameterFormEntry(
                    definition: defn,
                    currentValue: defn.defaultValue,
                    source: defn.defaultValue != nil ? .defaultValue : .userSet
                )
            }

            _formState = ParameterFormState(
                toolName: toolName,
                selectedSubcommand: initialSubcmd,
                entries: entries,
                mode: _networkInjection.isServerConfigured ? .withServerInjection : .standalone,
                isValid: false,
                generatedCommand: "",
                lastCommandUpdate: Date(),
                isResettingToDefaults: false
            )

            if cfg.hasSubcommands {
                _subcommandState = SubcommandState(
                    toolName: toolName,
                    subcommands: cfg.subcommands,
                    selectedSubcommand: initialSubcmd,
                    activeParameters: initialParams
                )
            } else {
                _subcommandState = nil
            }

            _applyNetworkInjectionIfNeeded()
            _regenerateCommand()
            _validateAll()
        }
    }

    // MARK: - 21.3 Dynamic Form State

    /// Returns the current form state.
    public func getFormState() -> ParameterFormState { lock.withLock { _formState } }

    /// Replaces the form state wholesale.
    public func setFormState(_ state: ParameterFormState) { lock.withLock { _formState = state } }

    /// Updates the value for the parameter identified by `parameterName`.
    ///
    /// After the update, validation and command regeneration are performed.
    public func updateValue(_ value: ParameterValue?, for parameterName: String) {
        lock.withLock {
            guard let idx = _formState.entries.firstIndex(where: { $0.definition.name == parameterName }) else { return }
            _formState.entries[idx].currentValue = value
            _formState.entries[idx].source = .userSet
            _formState.entries[idx].validationError = nil
            _validateEntry(at: idx)
            _regenerateCommand()
            _validateAll()
        }
    }

    /// Resets all form entries to their default values and clears validation errors.
    public func resetToDefaults() {
        lock.withLock {
            _formState.isResettingToDefaults = true
            _formState.entries = FormRenderingHelpers.resetToDefaults(entries: _formState.entries)
            _applyNetworkInjectionIfNeeded()
            _regenerateCommand()
            _validateAll()
            _formState.isResettingToDefaults = false
        }
    }

    // MARK: - 21.4 Network Parameter Injection

    /// Returns the current network injection state.
    public func getNetworkInjection() -> NetworkInjectionState { lock.withLock { _networkInjection } }

    /// Sets the active server configuration and re-applies injection to the form.
    public func setNetworkInjection(_ injection: NetworkInjectionState) {
        lock.withLock {
            _networkInjection = injection
            _formState.mode = injection.isServerConfigured ? .withServerInjection : .standalone
            _applyNetworkInjectionIfNeeded()
            _regenerateCommand()
            _validateAll()
        }
    }

    /// Clears all injected network parameters, reverting to defaults.
    public func clearNetworkInjection() {
        lock.withLock {
            _networkInjection = NetworkInjectionState()
            _formState.mode = .standalone
            // Revert injected entries back to default or user set
            _formState.entries = _formState.entries.map { entry in
                guard entry.source == .serverInjected else { return entry }
                return ParameterFormEntry(
                    definition: entry.definition,
                    currentValue: entry.definition.defaultValue,
                    source: .defaultValue,
                    validationError: nil
                )
            }
            _regenerateCommand()
            _validateAll()
        }
    }

    // MARK: - 21.5 Subcommand Handling

    /// Returns the current subcommand state, or `nil` for tools without subcommands.
    public func getSubcommandState() -> SubcommandState? { lock.withLock { _subcommandState } }

    /// Selects a subcommand by token, replacing the form entries with its parameters.
    ///
    /// Injected network parameters are re-applied and the command is regenerated.
    public func selectSubcommand(_ subcommandName: String) {
        lock.withLock {
            guard let cfg = _toolConfig, cfg.hasSubcommands else { return }
            guard let subCmd = cfg.subcommands.first(where: { $0.name == subcommandName }) else { return }

            _subcommandState?.selectedSubcommand = subcommandName
            _subcommandState?.activeParameters = subCmd.parameters
            _formState.selectedSubcommand = subcommandName

            _formState.entries = subCmd.parameters.map { defn in
                ParameterFormEntry(
                    definition: defn,
                    currentValue: defn.defaultValue,
                    source: defn.defaultValue != nil ? .defaultValue : .userSet
                )
            }

            _applyNetworkInjectionIfNeeded()
            _regenerateCommand()
            _validateAll()
        }
    }

    // MARK: - Private helpers (must be called within `lock`)

    private func _applyNetworkInjectionIfNeeded() {
        guard _networkInjection.isServerConfigured else { return }
        _formState.entries = FormRenderingHelpers.applyNetworkInjection(
            to: _formState.entries,
            injection: _networkInjection
        )
    }

    private func _regenerateCommand() {
        _formState.generatedCommand = FormRenderingHelpers.generateCommand(
            toolName: _formState.toolName,
            subcommand: _formState.selectedSubcommand,
            entries: _formState.entries
        )
        _formState.lastCommandUpdate = Date()
    }

    private func _validateEntry(at index: Int) {
        let entry = _formState.entries[index]
        guard let value = entry.currentValue else {
            if entry.definition.isRequired {
                _formState.entries[index].validationError = "This field is required."
            }
            return
        }
        _formState.entries[index].validationError = ParameterValidationHelpers.validate(
            value: value,
            against: entry.definition.validations
        )
    }

    private func _validateAll() {
        for idx in _formState.entries.indices {
            _validateEntry(at: idx)
        }
        let hasErrors = _formState.entries.contains { $0.validationError != nil }
        let missingRequired = _formState.entries.contains { entry in
            entry.definition.isRequired && entry.currentValue == nil
        }
        _formState.isValid = !hasErrors && !missingRequired
    }
}
