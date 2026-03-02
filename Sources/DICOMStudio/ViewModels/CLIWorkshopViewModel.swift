// CLIWorkshopViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for CLI Tools Workshop (Milestone 16)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class CLIWorkshopViewModel {
    private let service: CLIWorkshopService

    public var activeTab: CLIWorkshopTab = .fileInspection
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // 16.1 Network Configuration
    public var networkProfiles: [CLINetworkProfile] = []
    public var activeProfileID: UUID? = nil
    public var connectionTestStatus: CLIConnectionTestStatus = .untested

    // 16.2 Tool Catalog
    public var tools: [CLIToolDefinition] = []
    public var selectedToolID: String? = nil

    // 16.3 Parameter Configuration
    public var parameterDefinitions: [CLIParameterDefinition] = []
    public var parameterValues: [CLIParameterValue] = []

    // 16.4 File Drop Zone
    public var inputFiles: [CLIFileEntry] = []
    public var outputPath: String = ""
    public var fileDropState: CLIFileDropState = .empty

    // 16.5 Console
    public var consoleStatus: CLIConsoleStatus = .idle
    public var consoleOutput: String = ""
    public var commandPreview: String = ""

    // 16.6 Command History
    public var commandHistory: [CLICommandHistoryEntry] = []

    // 16.8 Educational Features
    public var experienceMode: CLIExperienceMode = .beginner
    public var glossaryEntries: [CLIGlossaryEntry] = []
    public var glossarySearchQuery: String = ""

    public init(service: CLIWorkshopService = CLIWorkshopService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        networkProfiles      = service.getNetworkProfiles()
        activeProfileID      = service.getActiveProfileID()
        connectionTestStatus = service.getConnectionTestStatus()
        tools                = service.getTools()
        selectedToolID       = service.getSelectedToolID()
        parameterDefinitions = service.getParameterDefinitions()
        parameterValues      = service.getParameterValues()
        inputFiles           = service.getInputFiles()
        outputPath           = service.getOutputPath()
        fileDropState        = service.getFileDropState()
        consoleStatus        = service.getConsoleStatus()
        consoleOutput        = service.getConsoleOutput()
        commandPreview       = service.getCommandPreview()
        commandHistory       = service.getCommandHistory()
        experienceMode       = service.getExperienceMode()
        glossaryEntries      = service.getGlossaryEntries()
        glossarySearchQuery  = service.getGlossarySearchQuery()
    }

    // MARK: - 16.1 Network Configuration

    /// Adds a new network profile.
    public func addProfile(_ profile: CLINetworkProfile) {
        networkProfiles.append(profile)
        service.addProfile(profile)
    }

    /// Removes a network profile by ID.
    public func removeProfile(id: UUID) {
        networkProfiles.removeAll { $0.id == id }
        service.removeProfile(id: id)
        if activeProfileID == id {
            activeProfileID = networkProfiles.first?.id
            service.setActiveProfileID(activeProfileID)
        }
    }

    /// Updates an existing network profile.
    public func updateProfile(_ profile: CLINetworkProfile) {
        guard let idx = networkProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        networkProfiles[idx] = profile
        service.updateProfile(profile)
    }

    /// Sets the active network profile by ID.
    public func setActiveProfile(id: UUID?) {
        activeProfileID = id
        service.setActiveProfileID(id)
    }

    /// Returns the currently active network profile, or nil.
    public func activeProfile() -> CLINetworkProfile? {
        guard let id = activeProfileID else { return networkProfiles.first }
        return networkProfiles.first { $0.id == id }
    }

    /// Returns the connection summary for the active profile.
    public func activeConnectionSummary() -> String {
        guard let profile = activeProfile() else { return "No profile configured" }
        return NetworkConfigHelpers.connectionSummary(for: profile)
    }

    /// Updates the connection test status.
    public func updateConnectionTestStatus(_ status: CLIConnectionTestStatus) {
        connectionTestStatus = status
        service.setConnectionTestStatus(status)
    }

    // MARK: - 16.2 Tool Selection

    /// Selects a tool by ID.
    public func selectTool(id: String?) {
        selectedToolID = id
        service.setSelectedToolID(id)
        // Reset parameters when tool changes
        parameterValues.removeAll()
        service.setParameterValues([])
        inputFiles.removeAll()
        service.setInputFiles([])
        consoleOutput = ""
        service.setConsoleOutput("")
        consoleStatus = .idle
        service.setConsoleStatus(.idle)
    }

    /// Returns the currently selected tool definition, or nil.
    public func selectedTool() -> CLIToolDefinition? {
        guard let id = selectedToolID else { return nil }
        return tools.first { $0.id == id }
    }

    /// Returns tools filtered by the active tab.
    public func toolsForActiveTab() -> [CLIToolDefinition] {
        ToolCatalogHelpers.tools(for: activeTab)
    }

    // MARK: - 16.3 Parameter Configuration

    /// Sets parameter definitions for the selected tool.
    public func setParameterDefinitions(_ defs: [CLIParameterDefinition]) {
        parameterDefinitions = defs
        service.setParameterDefinitions(defs)
    }

    /// Updates a single parameter value.
    public func updateParameterValue(parameterID: String, value: String) {
        if let idx = parameterValues.firstIndex(where: { $0.parameterID == parameterID }) {
            parameterValues[idx].stringValue = value
        } else {
            parameterValues.append(CLIParameterValue(parameterID: parameterID, stringValue: value))
        }
        service.setParameterValues(parameterValues)
        rebuildCommandPreview()
    }

    /// Checks whether all required parameters are satisfied.
    public var isCommandValid: Bool {
        CommandBuilderHelpers.validateRequired(
            parameterValues: parameterValues,
            parameterDefinitions: parameterDefinitions
        )
    }

    /// Returns visible parameters based on experience mode.
    public func visibleParameters() -> [CLIParameterDefinition] {
        switch experienceMode {
        case .beginner:
            return parameterDefinitions.filter { !$0.isAdvanced }
        case .advanced:
            return parameterDefinitions
        }
    }

    // MARK: - 16.4 File Drop Zone

    /// Adds an input file.
    public func addInputFile(_ file: CLIFileEntry) {
        inputFiles.append(file)
        service.addInputFile(file)
        fileDropState = .selected
        service.setFileDropState(.selected)
        rebuildCommandPreview()
    }

    /// Removes an input file by ID.
    public func removeInputFile(id: UUID) {
        inputFiles.removeAll { $0.id == id }
        service.removeInputFile(id: id)
        fileDropState = inputFiles.isEmpty ? .empty : .selected
        service.setFileDropState(fileDropState)
        rebuildCommandPreview()
    }

    /// Updates the file drop state (e.g., for drag hover).
    public func updateFileDropState(_ state: CLIFileDropState) {
        fileDropState = state
        service.setFileDropState(state)
    }

    /// Updates the output path.
    public func updateOutputPath(_ path: String) {
        outputPath = path
        service.setOutputPath(path)
        rebuildCommandPreview()
    }

    // MARK: - 16.5 Console

    /// Rebuilds the command preview based on current tool and parameter state.
    public func rebuildCommandPreview() {
        guard let tool = selectedTool() else {
            commandPreview = ""
            service.setCommandPreview("")
            return
        }
        let preview = CommandBuilderHelpers.buildCommand(
            toolName: tool.name,
            parameterValues: parameterValues,
            parameterDefinitions: parameterDefinitions
        )
        commandPreview = preview
        service.setCommandPreview(preview)
    }

    /// Returns syntax tokens for the current command preview.
    public func commandTokens() -> [CLISyntaxToken] {
        CommandBuilderHelpers.tokenize(commandPreview)
    }

    /// Clears the console output.
    public func clearConsoleOutput() {
        consoleOutput = ""
        service.setConsoleOutput("")
        consoleStatus = .idle
        service.setConsoleStatus(.idle)
    }

    /// Updates the console status.
    public func updateConsoleStatus(_ status: CLIConsoleStatus) {
        consoleStatus = status
        service.setConsoleStatus(status)
    }

    /// Appends text to the console output.
    public func appendConsoleOutput(_ text: String) {
        consoleOutput += text
        service.appendConsoleOutput(text)
    }

    // MARK: - 16.6 Command History

    /// Adds an entry to command history with PHI redaction.
    public func addToHistory(toolName: String, command: String, exitCode: Int?, output: String) {
        let redacted = ConsoleHelpers.redactPHI(command)
        let state: CLIExecutionState = (exitCode == 0) ? .completed : .failed
        let entry = CLICommandHistoryEntry(
            toolName: toolName,
            rawCommand: command,
            redactedCommand: redacted,
            executionState: state,
            exitCode: exitCode,
            outputSnippet: String(output.prefix(200))
        )
        commandHistory.append(entry)
        commandHistory = ConsoleHelpers.trimHistory(commandHistory)
        service.addCommandHistoryEntry(entry)
    }

    /// Clears all command history.
    public func clearHistory() {
        commandHistory.removeAll()
        service.clearCommandHistory()
    }

    // MARK: - 16.8 Educational Features

    /// Toggles between beginner and advanced experience mode.
    public func toggleExperienceMode() {
        experienceMode = (experienceMode == .beginner) ? .advanced : .beginner
        service.setExperienceMode(experienceMode)
    }

    /// Sets the experience mode directly.
    public func setExperienceMode(_ mode: CLIExperienceMode) {
        experienceMode = mode
        service.setExperienceMode(mode)
    }

    /// Returns glossary entries filtered by the current search query.
    public func filteredGlossaryEntries() -> [CLIGlossaryEntry] {
        EducationalHelpers.filterGlossary(glossaryEntries, query: glossarySearchQuery)
    }

    /// Updates the glossary search query.
    public func updateGlossarySearch(_ query: String) {
        glossarySearchQuery = query
        service.setGlossarySearchQuery(query)
    }

    /// Returns example presets for the selected tool.
    public func examplePresetsForSelectedTool() -> [CLIExamplePreset] {
        guard let id = selectedToolID else { return [] }
        return EducationalHelpers.examplePresets(for: id)
    }
}
