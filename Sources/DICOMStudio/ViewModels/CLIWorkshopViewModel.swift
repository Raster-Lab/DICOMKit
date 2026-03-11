// CLIWorkshopViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for CLI Tools Workshop (Milestone 16)

import Foundation
import Observation
import DICOMNetwork

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class CLIWorkshopViewModel {
    private let service: CLIWorkshopService

    /// Callback to open a retrieved file in the Viewer tab.
    /// Set by MainViewModel to wire navigation.
    public var onOpenInViewer: ((String, URL?) -> Void)?

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

    /// Security-scoped URLs from file importers, keyed by parameter ID.
    /// Used to gain sandbox access when reading user-selected files.
    public var securityScopedURLs: [String: URL] = [:]

    /// File paths of the most recently retrieved DICOM files (from dicom-retrieve or dicom-qr).
    /// Used to enable "Open in Viewer" after retrieval.
    public var lastRetrievedFiles: [String] = []

    /// Security-scoped output URL used for the last file write batch.
    /// Stored here so the viewer can access files written outside the sandbox container.
    public var lastRetrievedOutputURL: URL? = nil

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

    // Server selection for network tools
    /// Saved PACS server profiles from the Networking tab.
    public var savedServerProfiles: [PACSServerProfile] = []
    /// Whether the user is picking a saved server or entering details manually.
    public var networkInputMode: NetworkInputMode = .manual
    /// The ID of the selected saved server profile.
    public var selectedSavedServerID: UUID? = nil
    /// Whether the "Add Server" sheet is shown.
    public var showAddServerSheet: Bool = false
    /// Editable fields for adding a new server.
    public var newServerName: String = ""
    public var newServerHost: String = ""
    public var newServerPort: String = "11112"
    public var newServerCalledAET: String = ""
    public var newServerCallingAET: String = "DICOMSTUDIO"

    /// Toggles between using a saved server profile and entering parameters manually.
    public enum NetworkInputMode: String, Sendable, CaseIterable, Identifiable {
        case savedServer = "Saved Server"
        case manual = "Manual"
        public var id: String { rawValue }
    }

    // MARK: - Persistent Default Server

    /// UserDefaults keys for persistent default server values.
    private enum DefaultServerKeys {
        static let host = "studio.cli.defaultServerHost"
        static let port = "studio.cli.defaultServerPort"
        static let calledAET = "studio.cli.defaultCalledAET"
        static let callingAET = "studio.cli.defaultCallingAET"
    }

    /// Saves the current server parameters as persistent defaults.
    public func saveCurrentServerAsDefault() {
        let host = paramValue("host")
        let port = paramValue("port")
        let calledAET = paramValue("called-aet")
        let callingAET = paramValue("calling-aet")
        if !host.isEmpty { UserDefaults.standard.set(host, forKey: DefaultServerKeys.host) }
        if !port.isEmpty { UserDefaults.standard.set(port, forKey: DefaultServerKeys.port) }
        if !calledAET.isEmpty { UserDefaults.standard.set(calledAET, forKey: DefaultServerKeys.calledAET) }
        if !callingAET.isEmpty { UserDefaults.standard.set(callingAET, forKey: DefaultServerKeys.callingAET) }
    }

    /// Loads persistent default server values, returning non-nil values for each.
    public func persistentDefaults() -> (host: String?, port: String?, calledAET: String?, callingAET: String?) {
        return (
            host: UserDefaults.standard.string(forKey: DefaultServerKeys.host),
            port: UserDefaults.standard.string(forKey: DefaultServerKeys.port),
            calledAET: UserDefaults.standard.string(forKey: DefaultServerKeys.calledAET),
            callingAET: UserDefaults.standard.string(forKey: DefaultServerKeys.callingAET)
        )
    }

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
        // Clear security-scoped URLs from previous tool
        securityScopedURLs.removeAll()
        // Load parameter definitions and apply defaults for the selected tool
        if let toolID = id {
            let defs = ToolCatalogHelpers.parameterDefinitions(for: toolID)
            parameterDefinitions = defs
            service.setParameterDefinitions(defs)
            // Pre-populate default values
            for def in defs where !def.defaultValue.isEmpty {
                let pv = CLIParameterValue(parameterID: def.id, stringValue: def.defaultValue)
                parameterValues.append(pv)
            }
            // Override with persistent default server values for network tools
            let defaults = persistentDefaults()
            let hasHostParam = defs.contains(where: { $0.id == "host" })
            if hasHostParam {
                if let host = defaults.host, !host.isEmpty {
                    updateParameterValueSilent(parameterID: "host", value: host)
                }
                if let port = defaults.port, !port.isEmpty {
                    updateParameterValueSilent(parameterID: "port", value: port)
                }
                if let calledAET = defaults.calledAET, !calledAET.isEmpty {
                    updateParameterValueSilent(parameterID: "called-aet", value: calledAET)
                }
                if let callingAET = defaults.callingAET, !callingAET.isEmpty {
                    updateParameterValueSilent(parameterID: "calling-aet", value: callingAET)
                }
            }
            service.setParameterValues(parameterValues)
            rebuildCommandPreview()
        } else {
            parameterDefinitions = []
            service.setParameterDefinitions([])
        }
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

    /// Returns network tools grouped by DIMSE vs DICOMweb for the Network Operations tab.
    public func groupedNetworkTools() -> [(group: NetworkToolGroup, tools: [CLIToolDefinition])] {
        ToolCatalogHelpers.groupedNetworkOperationsTools()
    }

    /// Whether the currently selected tool is a network tool that supports server selection.
    public var isNetworkToolSelected: Bool {
        guard let tool = selectedTool() else { return false }
        return tool.requiresNetwork
    }

    /// Applies a saved PACS server profile's values to the current parameters.
    public func applySavedServer(id: UUID?) {
        selectedSavedServerID = id
        guard let serverID = id,
              let server = savedServerProfiles.first(where: { $0.id == serverID }) else {
            return
        }
        updateParameterValue(parameterID: "host", value: server.host)
        updateParameterValue(parameterID: "port", value: String(server.port))
        updateParameterValue(parameterID: "calling-aet", value: server.localAETitle)
        updateParameterValue(parameterID: "called-aet", value: server.remoteAETitle)
        updateParameterValue(parameterID: "timeout", value: String(Int(server.timeoutSeconds)))
        rebuildCommandPreview()
    }

    /// Adds a new server profile from the CLI Workshop "Add Server" form and persists it.
    public func addNewServerFromForm() {
        let name = newServerName.trimmingCharacters(in: .whitespaces)
        let host = newServerHost.trimmingCharacters(in: .whitespaces)
        let port = UInt16(newServerPort) ?? 11112
        let calledAET = newServerCalledAET.trimmingCharacters(in: .whitespaces)
        let callingAET = newServerCallingAET.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty, !host.isEmpty, !calledAET.isEmpty else { return }

        let profile = PACSServerProfile(
            name: name,
            host: host,
            port: port,
            remoteAETitle: calledAET,
            localAETitle: callingAET.isEmpty ? "DICOMSTUDIO" : callingAET
        )
        savedServerProfiles.append(profile)

        // Also persist via ServerProfileStorageService
        let storage = ServerProfileStorageService()
        var all = storage.load()
        all.append(profile)
        try? storage.save(all)

        // Reset form
        newServerName = ""
        newServerHost = ""
        newServerPort = "11112"
        newServerCalledAET = ""
        newServerCallingAET = "DICOMSTUDIO"
        showAddServerSheet = false

        // Auto-select the newly added server
        applySavedServer(id: profile.id)
    }

    /// Removes a saved server profile by ID.
    public func removeSavedServer(id: UUID) {
        savedServerProfiles.removeAll { $0.id == id }
        if selectedSavedServerID == id {
            selectedSavedServerID = nil
        }

        // Persist removal
        let storage = ServerProfileStorageService()
        var all = storage.load()
        all.removeAll { $0.id == id }
        try? storage.save(all)
    }

    /// Resets network parameters to defaults when switching to manual mode.
    public func resetToManualInput() {
        selectedSavedServerID = nil
        // Reload defaults from parameter definitions
        parameterValues.removeAll()
        for def in parameterDefinitions where !def.defaultValue.isEmpty {
            parameterValues.append(CLIParameterValue(parameterID: def.id, stringValue: def.defaultValue))
        }
        service.setParameterValues(parameterValues)
        rebuildCommandPreview()
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

    /// Silently updates a parameter value without rebuilding the command preview.
    /// Used when batch-setting multiple defaults at tool selection time.
    private func updateParameterValueSilent(parameterID: String, value: String) {
        if let idx = parameterValues.firstIndex(where: { $0.parameterID == parameterID }) {
            parameterValues[idx].stringValue = value
        } else {
            parameterValues.append(CLIParameterValue(parameterID: parameterID, stringValue: value))
        }
    }

    /// Stores a security-scoped URL for the given parameter ID and updates the parameter value.
    public func setSecurityScopedURL(_ url: URL, forParameterID parameterID: String) {
        securityScopedURLs[parameterID] = url
        updateParameterValue(parameterID: parameterID, value: url.path)
    }

    /// Reads file data from a path, handling security-scoped resource access if needed.
    public func readFileData(at path: String, parameterID: String = "files") throws -> Data {
        if let scopedURL = securityScopedURLs[parameterID] {
            let accessing = scopedURL.startAccessingSecurityScopedResource()
            defer {
                if accessing { scopedURL.stopAccessingSecurityScopedResource() }
            }
            return try Data(contentsOf: scopedURL)
        }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// Resolves the output directory for retrieved files.
    /// If the user hasn't set a path (or left the default "."),
    /// falls back to ~/Downloads/DICOMStudio (entitlement-allowed).
    private func resolvedOutputDir(_ rawOutput: String) -> String {
        if rawOutput == "." || rawOutput.isEmpty {
            if let scopedURL = securityScopedURLs["output"] {
                return scopedURL.path
            }
            // Use ~/Downloads/DICOMStudio as the default (sandbox entitlement: downloads.read-write)
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            let defaultDir = downloads.appendingPathComponent("DICOMStudio")
            try? FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
            return defaultDir.path
        }
        return rawOutput
    }

    /// Writes received DICOM data to disk in the specified output directory.
    ///
    /// - Parameters:
    ///   - data: The raw DICOM file data.
    ///   - sopInstanceUID: The SOP Instance UID (used as the filename).
    ///   - studyUID: The Study Instance UID (for hierarchical organization).
    ///   - seriesUID: Optional Series Instance UID (for hierarchical organization).
    ///   - outputDir: The base output directory path.
    ///   - hierarchical: If true, organizes as `<studyUID>/<seriesUID>/<sopInstanceUID>.dcm`.
    /// - Returns: The full path where the file was written.
    @discardableResult
    public func writeReceivedDICOMFile(
        data: Data,
        sopInstanceUID: String,
        studyUID: String,
        seriesUID: String? = nil,
        outputDir: String,
        hierarchical: Bool
    ) throws -> String {
        let fm = FileManager.default

        // Build destination directory
        var dirURL: URL
        var accessing = false
        if let scopedURL = securityScopedURLs["output"] {
            accessing = scopedURL.startAccessingSecurityScopedResource()
            dirURL = scopedURL
        } else {
            dirURL = URL(fileURLWithPath: outputDir)
        }
        defer {
            if accessing {
                securityScopedURLs["output"]?.stopAccessingSecurityScopedResource()
            }
        }

        if hierarchical {
            dirURL = dirURL.appendingPathComponent(studyUID)
            if let series = seriesUID, !series.isEmpty {
                dirURL = dirURL.appendingPathComponent(series)
            }
        }

        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let filename = "\(sopInstanceUID).dcm"
        let fileURL = dirURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        return fileURL.path
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

    /// Opens the first retrieved file from the last retrieve/QR operation in the viewer.
    public func openRetrievedFileInViewer() {
        guard let firstFile = lastRetrievedFiles.first else { return }
        onOpenInViewer?(firstFile, lastRetrievedOutputURL)
    }

    /// Executes the currently selected command.
    /// For dicom-echo, performs a real C-ECHO via DICOMVerificationService.
    public func executeCommand() async {
        guard let tool = selectedTool() else { return }
        rebuildCommandPreview()

        consoleOutput = ""
        consoleStatus = .running
        service.setConsoleStatus(.running)
        appendConsoleOutput("$ \(commandPreview)\n\n")

        switch tool.id {
        case "dicom-echo":
            await executeDicomEcho()
        case "dicom-query":
            await executeDicomQuery()
        case "dicom-send":
            await executeDicomSend()
        case "dicom-retrieve":
            await executeDicomRetrieve()
        case "dicom-qr":
            await executeDicomQR()
        default:
            appendConsoleOutput("⚠ Command execution not yet supported for \(tool.name).\n")
            consoleStatus = .idle
            service.setConsoleStatus(.idle)
        }
    }

    /// Performs a real C-ECHO against the server configured in the parameter fields.
    private func executeDicomEcho() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 30

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        appendConsoleOutput("Connecting to \(host):\(port) ...\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n\n")

        do {
            let result = try await DICOMVerificationService.echo(
                host: host,
                port: port,
                callingAE: callingAET,
                calledAE: calledAET,
                timeout: timeout
            )
            if result.success {
                let latencyMs = result.roundTripTime * 1000
                appendConsoleOutput("✅ C-ECHO successful\n")
                appendConsoleOutput("  Round-trip time: \(String(format: "%.1f", latencyMs)) ms\n")
                if !result.remoteAETitle.isEmpty {
                    appendConsoleOutput("  Remote AE Title: \(result.remoteAETitle)\n")
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 0,
                             output: "C-ECHO successful (\(String(format: "%.1f", latencyMs)) ms)")
            } else {
                appendConsoleOutput("❌ C-ECHO failed: server returned non-success status\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1,
                             output: "C-ECHO failed")
            }
        } catch {
            appendConsoleOutput("❌ C-ECHO failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Returns the current string value for a parameter by ID.
    private func paramValue(_ paramID: String) -> String {
        parameterValues.first(where: { $0.parameterID == paramID })?.stringValue ?? ""
    }

    /// Performs a C-FIND query against the server configured in the parameter fields.
    private func executeDicomQuery() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 30
        let levelStr = paramValue("level")

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-query", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        let level: QueryLevel
        switch levelStr.uppercased() {
        case "PATIENT": level = .patient
        case "SERIES":  level = .series
        case "IMAGE":   level = .image
        default:         level = .study
        }

        appendConsoleOutput("Querying \(host):\(port) at \(level) level ...\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")

        // Collect all user-provided filter values
        let patientID = paramValue("patient-id")
        let patientName = paramValue("patient-name")
        let studyDate = paramValue("study-date")
        let modality = paramValue("modality")
        let accession = paramValue("accession")
        let studyUID = paramValue("study-uid")
        let seriesUID = paramValue("series-uid")
        let seriesDate = paramValue("series-date")
        let instanceUID = paramValue("instance-uid")

        // Per PS3.4 C.6, at SERIES and IMAGE levels under Study Root:
        //   - Only UNIQUE keys from parent levels carry through (Study Instance UID)
        //   - Patient Name, Study Date, etc. are NOT valid and cause 0xA900
        // Strategy:
        //   PATIENT → Patient Root, patient attributes only
        //   STUDY   → Study Root, patient + study attributes
        //   SERIES/IMAGE → Study Root: direct query when Study UID is provided.
        //     When a globally unique UID (Series/SOP Instance) is given without Study UID,
        //     try direct first (empty Study UID = universal match per PS3.4 C.6).
        //     If the server rejects it (0xA900), fall back to concurrent two-step.
        //     For non-unique filters (modality, date) without Study UID, use two-step.

        var queryKeys = QueryKeys(level: level)

        // Classify the query strategy for SERIES/IMAGE levels:
        //   - hasStudyUID: direct query is always safe
        //   - hasGloballyUniqueUID: try direct first (should work per standard),
        //     fall back to concurrent two-step if server rejects it
        //   - neither: must use two-step (non-unique filters need parent context)
        let hasGloballyUniqueUID: Bool
        switch level {
        case .series: hasGloballyUniqueUID = !seriesUID.isEmpty
        case .image:  hasGloballyUniqueUID = !instanceUID.isEmpty
        default:      hasGloballyUniqueUID = false
        }
        let canTryDirect = (level == .series || level == .image) &&
            studyUID.isEmpty && hasGloballyUniqueUID
        let needsTwoStepQuery = (level == .series || level == .image) &&
            studyUID.isEmpty && !hasGloballyUniqueUID

        switch level {
        case .patient:
            if !patientID.isEmpty {
                queryKeys = queryKeys.patientID(patientID)
                appendConsoleOutput("  Patient ID:       \(patientID)\n")
            } else {
                queryKeys = queryKeys.requestPatientID()
            }
            if !patientName.isEmpty {
                queryKeys = queryKeys.patientName(patientName.uppercased())
                appendConsoleOutput("  Patient Name:     \(patientName) (uppercased for matching)\n")
            } else {
                queryKeys = queryKeys.requestPatientName()
            }
            queryKeys = queryKeys
                .requestPatientBirthDate()
                .requestPatientSex()
                .requestNumberOfPatientRelatedStudies()
                .requestNumberOfPatientRelatedSeries()
                .requestNumberOfPatientRelatedInstances()

        case .study:
            if !patientID.isEmpty {
                queryKeys = queryKeys.patientID(patientID)
                appendConsoleOutput("  Patient ID:       \(patientID)\n")
            } else {
                queryKeys = queryKeys.requestPatientID()
            }
            if !patientName.isEmpty {
                queryKeys = queryKeys.patientName(patientName.uppercased())
                appendConsoleOutput("  Patient Name:     \(patientName) (uppercased for matching)\n")
            } else {
                queryKeys = queryKeys.requestPatientName()
            }
            queryKeys = queryKeys.requestPatientBirthDate()
            if !studyUID.isEmpty {
                queryKeys = queryKeys.studyInstanceUID(studyUID)
                appendConsoleOutput("  Study UID:        \(studyUID)\n")
            } else {
                queryKeys = queryKeys.requestStudyInstanceUID()
            }
            if !studyDate.isEmpty {
                queryKeys = queryKeys.studyDate(studyDate)
                appendConsoleOutput("  Study Date:       \(studyDate)\n")
            } else {
                queryKeys = queryKeys.requestStudyDate()
            }
            if !modality.isEmpty {
                queryKeys = queryKeys.modalitiesInStudy(modality)
                appendConsoleOutput("  Modality:         \(modality)\n")
            } else {
                queryKeys = queryKeys.requestModalitiesInStudy()
            }
            if !accession.isEmpty {
                queryKeys = queryKeys.accessionNumber(accession)
                appendConsoleOutput("  Accession:        \(accession)\n")
            } else {
                queryKeys = queryKeys.requestAccessionNumber()
            }
            queryKeys = queryKeys
                .requestStudyDescription()
                .requestStudyTime()
                .requestNumberOfStudyRelatedSeries()
                .requestNumberOfStudyRelatedInstances()

        case .series:
            // Study Root SERIES: Study Instance UID (required unique key) + series attributes
            if !studyUID.isEmpty {
                queryKeys = queryKeys.studyInstanceUID(studyUID)
                appendConsoleOutput("  Study UID:        \(studyUID)\n")
            } else {
                queryKeys = queryKeys.requestStudyInstanceUID()
            }
            if !seriesUID.isEmpty {
                queryKeys = queryKeys.seriesInstanceUID(seriesUID)
                appendConsoleOutput("  Series UID:       \(seriesUID)\n")
            } else {
                queryKeys = queryKeys.requestSeriesInstanceUID()
            }
            if !modality.isEmpty {
                queryKeys = queryKeys.modality(modality)
                appendConsoleOutput("  Modality:         \(modality)\n")
            } else {
                queryKeys = queryKeys.requestModality()
            }
            if !seriesDate.isEmpty {
                queryKeys = queryKeys.seriesDate(seriesDate)
                appendConsoleOutput("  Series Date:      \(seriesDate)\n")
            }
            queryKeys = queryKeys
                .requestSeriesNumber()
                .requestSeriesDescription()
                .requestNumberOfSeriesRelatedInstances()
                // Parent-level return keys (dcm4chee5 style)
                .requestPatientName()
                .requestPatientID()
                .requestStudyDate()
                .requestStudyDescription()
                .requestAccessionNumber()

            // Log parent-level criteria handled via 2-step
            if needsTwoStepQuery {
                appendConsoleOutput("  (Patient/study filters will be resolved via study lookup)\n")
            }

        case .image:
            // Study Root IMAGE: Study UID + Series UID (required unique keys) + instance attributes
            if !studyUID.isEmpty {
                queryKeys = queryKeys.studyInstanceUID(studyUID)
                appendConsoleOutput("  Study UID:        \(studyUID)\n")
            } else {
                queryKeys = queryKeys.requestStudyInstanceUID()
            }
            if !seriesUID.isEmpty {
                queryKeys = queryKeys.seriesInstanceUID(seriesUID)
                appendConsoleOutput("  Series UID:       \(seriesUID)\n")
            } else {
                queryKeys = queryKeys.requestSeriesInstanceUID()
            }
            if !instanceUID.isEmpty {
                queryKeys = queryKeys.sopInstanceUID(instanceUID)
                appendConsoleOutput("  Instance UID:     \(instanceUID)\n")
            } else {
                queryKeys = queryKeys.requestSOPInstanceUID()
            }
            queryKeys = queryKeys
                .requestSOPClassUID()
                .requestInstanceNumber()
                .requestContentDate()
                .requestRows()
                .requestColumns()
                .requestNumberOfFrames()
                // Parent-level return keys (dcm4chee5 style)
                .requestPatientName()
                .requestPatientID()
                .requestStudyDate()
                .requestStudyDescription()
                .requestAccessionNumber()
                .requestModality()
                .requestSeriesNumber()
                .requestSeriesDescription()

            if needsTwoStepQuery {
                appendConsoleOutput("  (Patient/study filters will be resolved via study lookup)\n")
            }
        }
        let modelName = (level == .patient) ? "Patient Root" : "Study Root"
        appendConsoleOutput("  Model:            \(modelName)\n\n")

        do {
            let informationModel: QueryRetrieveInformationModel = (level == .patient) ? .patientRoot : .studyRoot
            let config = QueryConfiguration(
                callingAETitle: try AETitle(callingAET),
                calledAETitle: try AETitle(calledAET),
                timeout: timeout,
                informationModel: informationModel
            )

            var allResults: [GenericQueryResult] = []

            if canTryDirect {
                // Globally unique UID without Study UID — try direct query first.
                // Per PS3.4 C.6 empty Study UID = universal match, which should work.
                appendConsoleOutput("Querying directly with \(level) UID...\n")
                do {
                    allResults = try await DICOMQueryService.find(
                        host: host, port: port,
                        configuration: config,
                        queryKeys: queryKeys
                    )
                } catch let error as DICOMNetworkError {
                    // Check if the server rejected the empty Study UID (0xA900)
                    if case .queryFailed(let status) = error,
                       status == .errorIdentifierDoesNotMatchSOPClass {
                        // Server doesn't support universal match on Study UID —
                        // fall back to concurrent two-step with early exit.
                        appendConsoleOutput("Server requires Study UID — falling back to study lookup...\n")
                        allResults = try await concurrentSeriesLookup(
                            host: host, port: port, config: config,
                            level: level,
                            patientID: patientID, patientName: patientName,
                            studyDate: studyDate, accession: accession,
                            modality: modality, seriesUID: seriesUID,
                            seriesDate: seriesDate, instanceUID: instanceUID,
                            callingAET: callingAET, calledAET: calledAET,
                            timeout: timeout
                        )
                    } else {
                        throw error
                    }
                }
            } else if needsTwoStepQuery {
                allResults = try await concurrentSeriesLookup(
                    host: host, port: port, config: config,
                    level: level,
                    patientID: patientID, patientName: patientName,
                    studyDate: studyDate, accession: accession,
                    modality: modality, seriesUID: seriesUID,
                    seriesDate: seriesDate, instanceUID: instanceUID,
                    callingAET: callingAET, calledAET: calledAET,
                    timeout: timeout
                )
            } else {
                // Direct single query (Study UID provided)
                allResults = try await DICOMQueryService.find(
                    host: host, port: port,
                    configuration: config,
                    queryKeys: queryKeys
                )
            }

            if allResults.isEmpty {
                appendConsoleOutput("No results found.\n")
            } else {
                // For SERIES/IMAGE levels, fetch parent study/patient info
                // because servers often don't return parent-level attributes
                // at child query levels (per PS3.4 C.6).
                var parentLookup: [String: GenericQueryResult] = [:]
                if level == .series || level == .image {
                    let uniqueStudyUIDs = Set(
                        allResults.compactMap { $0.toStudyResult().studyInstanceUID }
                    ).sorted()
                    if !uniqueStudyUIDs.isEmpty {
                        appendConsoleOutput("Fetching parent study/patient info...\n")
                        parentLookup = await fetchParentStudyInfo(
                            host: host, port: port,
                            callingAET: callingAET, calledAET: calledAET,
                            timeout: timeout, studyUIDs: uniqueStudyUIDs
                        )
                    }
                }

                appendConsoleOutput("Found \(allResults.count) result(s):\n\n")
                for (index, result) in allResults.enumerated() {
                    let parentInfo = (level == .series || level == .image)
                        ? parentLookup[result.toStudyResult().studyInstanceUID ?? ""]
                        : nil
                    appendConsoleOutput(formatQueryResult(result, index: index + 1, level: level, parentStudyInfo: parentInfo))
                }
            }
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-query", command: commandPreview, exitCode: 0,
                         output: "\(allResults.count) result(s) found")
        } catch {
            let errorDetail = String(describing: error)
            appendConsoleOutput("❌ C-FIND failed\n")
            appendConsoleOutput("  Error: \(errorDetail)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-query", command: commandPreview, exitCode: 1,
                         output: errorDetail)
        }
    }

    /// Fetches parent study/patient info from the server for a set of Study UIDs.
    /// Returns a lookup dictionary keyed by Study Instance UID.
    private func fetchParentStudyInfo(
        host: String, port: UInt16,
        callingAET: String, calledAET: String,
        timeout: TimeInterval,
        studyUIDs: [String]
    ) async -> [String: GenericQueryResult] {
        var lookup: [String: GenericQueryResult] = [:]
        for uid in studyUIDs {
            do {
                let keys = QueryKeys(level: .study)
                    .studyInstanceUID(uid)
                    .requestPatientName()
                    .requestPatientID()
                    .requestPatientBirthDate()
                    .requestPatientSex()
                    .requestStudyDate()
                    .requestStudyTime()
                    .requestStudyDescription()
                    .requestAccessionNumber()
                    .requestModalitiesInStudy()
                    .requestNumberOfStudyRelatedSeries()
                    .requestNumberOfStudyRelatedInstances()
                let config = QueryConfiguration(
                    callingAETitle: try AETitle(callingAET),
                    calledAETitle: try AETitle(calledAET),
                    timeout: timeout,
                    informationModel: .studyRoot
                )
                let results = try await DICOMQueryService.find(
                    host: host, port: port,
                    configuration: config,
                    queryKeys: keys
                )
                if let first = results.first {
                    lookup[uid] = first
                }
            } catch {
                // Parent info is supplementary — continue on failure
            }
        }
        return lookup
    }

    /// Performs a concurrent two-step lookup for SERIES/IMAGE queries without Study UID.
    ///
    /// Step 1: Find all matching Study UIDs (applying patient/study filters).
    /// Step 2: Query target level concurrently across studies with early cancellation
    ///         when a globally unique UID is provided.
    private func concurrentSeriesLookup(
        host: String, port: UInt16, config: QueryConfiguration,
        level: QueryLevel,
        patientID: String, patientName: String,
        studyDate: String, accession: String,
        modality: String, seriesUID: String,
        seriesDate: String, instanceUID: String,
        callingAET: String, calledAET: String,
        timeout: TimeInterval
    ) async throws -> [GenericQueryResult] {
        // Step 1: Find matching studies
        appendConsoleOutput("Step 1: Finding matching studies...\n")
        var studyQueryKeys = QueryKeys(level: .study)
            .requestStudyInstanceUID()
        if !patientID.isEmpty { studyQueryKeys = studyQueryKeys.patientID(patientID) }
        if !patientName.isEmpty { studyQueryKeys = studyQueryKeys.patientName(patientName.uppercased()) }
        if !studyDate.isEmpty { studyQueryKeys = studyQueryKeys.studyDate(studyDate) }
        if !accession.isEmpty { studyQueryKeys = studyQueryKeys.accessionNumber(accession) }
        if !modality.isEmpty { studyQueryKeys = studyQueryKeys.modalitiesInStudy(modality) }

        let studyConfig = QueryConfiguration(
            callingAETitle: try AETitle(callingAET),
            calledAETitle: try AETitle(calledAET),
            timeout: timeout,
            informationModel: .studyRoot
        )
        let studies = try await DICOMQueryService.find(
            host: host, port: port,
            configuration: studyConfig,
            queryKeys: studyQueryKeys
        )
        let studyUIDs = studies.compactMap { $0.toStudyResult().studyInstanceUID }
        appendConsoleOutput("  Found \(studyUIDs.count) matching study(ies)\n")

        guard !studyUIDs.isEmpty else {
            appendConsoleOutput("No matching studies found — no \(level) results.\n")
            return []
        }

        let hasUniqueMatch = (level == .series && !seriesUID.isEmpty) ||
            (level == .image && !instanceUID.isEmpty)

        // Step 2: Query concurrently across studies
        appendConsoleOutput("Step 2: Querying \(level) level across \(studyUIDs.count) study(ies)...\n")

        let allResults: [GenericQueryResult] = try await withThrowingTaskGroup(
            of: [GenericQueryResult].self
        ) { group in
            // Limit concurrency to avoid overwhelming the PACS
            let maxConcurrent = min(studyUIDs.count, 8)
            var submitted = 0
            var collected: [GenericQueryResult] = []

            for uid in studyUIDs.prefix(maxConcurrent) {
                group.addTask { [self] in
                    try await self.queryLevelForStudy(
                        host: host, port: port, config: config,
                        level: level, studyUID: uid,
                        seriesUID: seriesUID, modality: modality,
                        seriesDate: seriesDate, instanceUID: instanceUID
                    )
                }
                submitted += 1
            }

            var uidIndex = maxConcurrent
            for try await results in group {
                collected.append(contentsOf: results)
                // Early exit for globally unique UIDs
                if hasUniqueMatch && !collected.isEmpty {
                    group.cancelAll()
                    break
                }
                // Submit next batch
                if uidIndex < studyUIDs.count {
                    let nextUID = studyUIDs[uidIndex]
                    group.addTask { [self] in
                        try await self.queryLevelForStudy(
                            host: host, port: port, config: config,
                            level: level, studyUID: nextUID,
                            seriesUID: seriesUID, modality: modality,
                            seriesDate: seriesDate, instanceUID: instanceUID
                        )
                    }
                    uidIndex += 1
                }
            }
            return collected
        }

        if hasUniqueMatch && !allResults.isEmpty {
            appendConsoleOutput("  Found match (searched \(studyUIDs.count) studies concurrently)\n\n")
        } else if hasUniqueMatch {
            appendConsoleOutput("  No match found across \(studyUIDs.count) studies\n\n")
        } else {
            appendConsoleOutput("\n")
        }

        return allResults
    }

    /// Queries a specific level within a single study.
    /// For IMAGE level without a Series UID, performs an intermediate series discovery.
    private func queryLevelForStudy(
        host: String, port: UInt16, config: QueryConfiguration,
        level: QueryLevel, studyUID: String,
        seriesUID: String, modality: String,
        seriesDate: String, instanceUID: String
    ) async throws -> [GenericQueryResult] {
        if level == .series {
            var subKeys = QueryKeys(level: .series)
                .studyInstanceUID(studyUID)
            if !seriesUID.isEmpty { subKeys = subKeys.seriesInstanceUID(seriesUID) }
            else { subKeys = subKeys.requestSeriesInstanceUID() }
            if !modality.isEmpty { subKeys = subKeys.modality(modality) }
            else { subKeys = subKeys.requestModality() }
            if !seriesDate.isEmpty { subKeys = subKeys.seriesDate(seriesDate) }
            subKeys = subKeys
                .requestSeriesNumber()
                .requestSeriesDescription()
                .requestNumberOfSeriesRelatedInstances()

            return try await DICOMQueryService.find(
                host: host, port: port,
                configuration: config,
                queryKeys: subKeys
            )
        }

        // IMAGE level — DCM4CHEE requires non-empty Series Instance UID
        if !seriesUID.isEmpty {
            // Series UID provided — direct image query
            var subKeys = QueryKeys(level: .image)
                .studyInstanceUID(studyUID)
                .seriesInstanceUID(seriesUID)
            if !instanceUID.isEmpty { subKeys = subKeys.sopInstanceUID(instanceUID) }
            else { subKeys = subKeys.requestSOPInstanceUID() }
            subKeys = subKeys
                .requestSOPClassUID()
                .requestInstanceNumber()
            return try await DICOMQueryService.find(
                host: host, port: port,
                configuration: config,
                queryKeys: subKeys
            )
        }

        // No Series UID — discover series first, then query images within each
        let seriesKeys = QueryKeys(level: .series)
            .studyInstanceUID(studyUID)
            .requestSeriesInstanceUID()
        let seriesResults = try await DICOMQueryService.find(
            host: host, port: port,
            configuration: config,
            queryKeys: seriesKeys
        )
        let discoveredSeriesUIDs = seriesResults.compactMap {
            $0.toSeriesResult().seriesInstanceUID
        }

        var imageResults: [GenericQueryResult] = []
        for sUID in discoveredSeriesUIDs {
            var subKeys = QueryKeys(level: .image)
                .studyInstanceUID(studyUID)
                .seriesInstanceUID(sUID)
            if !instanceUID.isEmpty { subKeys = subKeys.sopInstanceUID(instanceUID) }
            else { subKeys = subKeys.requestSOPInstanceUID() }
            subKeys = subKeys
                .requestSOPClassUID()
                .requestInstanceNumber()

            let results = try await DICOMQueryService.find(
                host: host, port: port,
                configuration: config,
                queryKeys: subKeys
            )
            imageResults.append(contentsOf: results)

            // Early exit when searching for a unique SOP Instance UID
            if !instanceUID.isEmpty && !imageResults.isEmpty {
                break
            }
        }
        return imageResults
    }

    // MARK: - C-STORE Execution (dicom-send)

    /// Performs a real C-STORE to send DICOM files to the configured server.
    private func executeDicomSend() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 60
        let priorityStr = paramValue("priority").lowercased()
        let verifyFirst = paramValue("verify") == "true"
        let dryRun = paramValue("dry-run") == "true"
        let retryCount = Int(paramValue("retry")) ?? 0

        let priority: DIMSEPriority
        switch priorityStr {
        case "low": priority = .low
        case "high": priority = .high
        default: priority = .medium
        }

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        // Collect files from both the file drop zone and the text parameter
        let filesParamPath = paramValue("files").trimmingCharacters(in: .whitespaces)
        var fileEntries = inputFiles
        if !filesParamPath.isEmpty && !fileEntries.contains(where: { $0.path == filesParamPath }) {
            let url = URL(fileURLWithPath: filesParamPath)
            let fileSize: Int64
            if let attrs = try? FileManager.default.attributesOfItem(atPath: filesParamPath),
               let size = attrs[.size] as? Int64 {
                fileSize = size
            } else {
                fileSize = 0
            }
            fileEntries.append(CLIFileEntry(
                path: filesParamPath,
                filename: url.lastPathComponent,
                fileSize: fileSize
            ))
        }

        guard !fileEntries.isEmpty else {
            appendConsoleOutput("Error: No DICOM files specified. Enter a file path or drag and drop files.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1, output: "No files selected")
            return
        }

        appendConsoleOutput("DICOM Send (C-STORE)\n")
        appendConsoleOutput("====================\n")
        appendConsoleOutput("  Server:           \(host):\(port)\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Priority:         \(priorityStr)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        if retryCount > 0 {
            appendConsoleOutput("  Retry attempts:   \(retryCount)\n")
        }
        appendConsoleOutput("  Files:            \(fileEntries.count)\n")
        if dryRun {
            appendConsoleOutput("  Mode:             DRY RUN\n")
        }
        appendConsoleOutput("\n")

        if dryRun {
            for (index, file) in fileEntries.enumerated() {
                appendConsoleOutput("  [\(index + 1)/\(fileEntries.count)] \(file.filename) (\(FileDropHelpers.formatFileSize(file.fileSize)))\n")
            }
            appendConsoleOutput("\nDry run complete. Disable 'Dry Run' to send files.\n")
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 0,
                         output: "Dry run: \(fileEntries.count) file(s)")
            return
        }

        // Verify connection first if requested
        if verifyFirst {
            appendConsoleOutput("Verifying connection with C-ECHO...\n")
            do {
                let echoResult = try await DICOMVerificationService.echo(
                    host: host, port: port,
                    callingAE: callingAET, calledAE: calledAET,
                    timeout: timeout
                )
                if echoResult.success {
                    appendConsoleOutput("  ✅ Connection verified\n\n")
                } else {
                    appendConsoleOutput("  ❌ C-ECHO failed — aborting send\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1,
                                 output: "C-ECHO verification failed")
                    return
                }
            } catch {
                appendConsoleOutput("  ❌ C-ECHO failed: \(error.localizedDescription)\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1,
                             output: "C-ECHO verification failed")
                return
            }
        }

        // Send each file
        var successCount = 0
        var failureCount = 0
        let startTime = Date()

        for (index, file) in fileEntries.enumerated() {
            let fileNumber = index + 1
            appendConsoleOutput("[\(fileNumber)/\(fileEntries.count)] Sending: \(file.filename) (\(FileDropHelpers.formatFileSize(file.fileSize)))...")

            do {
                let fileData = try readFileData(at: file.path, parameterID: "files")
                var lastError: Error?
                var sent = false

                for attempt in 0...retryCount {
                    do {
                        let result = try await DICOMStorageService.store(
                            fileData: fileData,
                            to: host,
                            port: port,
                            callingAE: callingAET,
                            calledAE: calledAET,
                            priority: priority,
                            timeout: timeout
                        )
                        successCount += 1
                        let rtt = String(format: "%.1f", result.roundTripTime * 1000)
                        appendConsoleOutput(" ✅ (\(rtt) ms)\n")
                        sent = true
                        break
                    } catch {
                        lastError = error
                        if attempt < retryCount {
                            appendConsoleOutput(" retry \(attempt + 1)/\(retryCount)...")
                        }
                    }
                }

                if !sent {
                    failureCount += 1
                    appendConsoleOutput(" ❌ \(lastError?.localizedDescription ?? "Unknown error")\n")
                }
            } catch {
                failureCount += 1
                appendConsoleOutput(" ❌ Cannot read file: \(error.localizedDescription)\n")
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        appendConsoleOutput("\nTransfer Summary\n")
        appendConsoleOutput("================\n")
        appendConsoleOutput("  Total files:  \(fileEntries.count)\n")
        appendConsoleOutput("  Succeeded:    \(successCount)\n")
        appendConsoleOutput("  Failed:       \(failureCount)\n")
        appendConsoleOutput("  Duration:     \(String(format: "%.1f", elapsed))s\n")

        if failureCount == 0 {
            appendConsoleOutput("\n✅ All files sent successfully\n")
            consoleStatus = .success
            service.setConsoleStatus(.success)
        } else if successCount == 0 {
            appendConsoleOutput("\n❌ All files failed to send\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
        } else {
            appendConsoleOutput("\n⚠️ Partial success: \(successCount) succeeded, \(failureCount) failed\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
        }
        addToHistory(toolName: "dicom-send", command: commandPreview,
                     exitCode: failureCount == 0 ? 0 : 1,
                     output: "\(successCount)/\(fileEntries.count) files sent in \(String(format: "%.1f", elapsed))s")
    }

    // MARK: - C-MOVE / C-GET Execution (dicom-retrieve)

    /// Performs a C-MOVE or C-GET retrieval from the configured server.
    private func executeDicomRetrieve() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 60
        let methodStr = paramValue("method").lowercased()
        let moveDest = paramValue("move-dest")
        let studyUID = paramValue("study-uid")
        let seriesUID = paramValue("series-uid")
        let instanceUID = paramValue("instance-uid")
        let outputDir = resolvedOutputDir(paramValue("output"))
        let hierarchical = paramValue("hierarchical") == "true"

        // Clear previous retrieval state
        lastRetrievedFiles.removeAll()
        lastRetrievedOutputURL = securityScopedURLs["output"]

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        guard !studyUID.isEmpty || !seriesUID.isEmpty || !instanceUID.isEmpty else {
            appendConsoleOutput("Error: At least one UID is required (Study, Series, or Instance).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1, output: "At least one UID required")
            return
        }

        let isCMove = methodStr != "c-get"
        if isCMove && moveDest.isEmpty {
            appendConsoleOutput("Error: Move Destination AET is required for C-MOVE.\n")
            appendConsoleOutput("  Tip: Switch to C-GET or provide a destination AE title.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1,
                         output: "Move destination required for C-MOVE")
            return
        }

        // If Study UID is missing, look it up from the server (dcm4chee5 style).
        // Try direct child-level query first (empty Study UID = universal match per PS3.4 C.6).
        // If the server rejects it, fall back to iterating studies.
        var resolvedStudyUID = studyUID
        if resolvedStudyUID.isEmpty {
            appendConsoleOutput("Resolving Study UID from server...\n")
            do {
                let lookupConfig = QueryConfiguration(
                    callingAETitle: try AETitle(callingAET),
                    calledAETitle: try AETitle(calledAET),
                    timeout: timeout,
                    informationModel: .studyRoot
                )

                // Attempt 1: direct child-level query with empty Study UID
                var resolved = false
                do {
                    let lookupLevel: QueryLevel = !seriesUID.isEmpty ? .series : .image
                    var lookupKeys = QueryKeys(level: lookupLevel)
                        .requestStudyInstanceUID()
                    if !seriesUID.isEmpty { lookupKeys = lookupKeys.seriesInstanceUID(seriesUID) }
                    if !instanceUID.isEmpty { lookupKeys = lookupKeys.sopInstanceUID(instanceUID) }
                    let lookupResults = try await DICOMQueryService.find(
                        host: host, port: port,
                        configuration: lookupConfig,
                        queryKeys: lookupKeys
                    )
                    if let first = lookupResults.first,
                       let uid = first.toStudyResult().studyInstanceUID, !uid.isEmpty {
                        resolvedStudyUID = uid
                        resolved = true
                        appendConsoleOutput("  Resolved Study UID: \(resolvedStudyUID)\n")
                    }
                } catch {
                    // Direct query failed — fall through to study iteration
                    appendConsoleOutput("  Direct lookup failed, searching studies...\n")
                }

                // Attempt 2: iterate studies to find the one containing the target series/instance
                if !resolved {
                    let studyKeys = QueryKeys(level: .study)
                        .requestStudyInstanceUID()
                    let studies = try await DICOMQueryService.find(
                        host: host, port: port,
                        configuration: lookupConfig,
                        queryKeys: studyKeys
                    )
                    let studyUIDs = studies.compactMap { $0.toStudyResult().studyInstanceUID }
                    appendConsoleOutput("  Searching \(studyUIDs.count) study(ies)...\n")

                    for sUID in studyUIDs {
                        var subKeys: QueryKeys
                        if !seriesUID.isEmpty {
                            subKeys = QueryKeys(level: .series)
                                .studyInstanceUID(sUID)
                                .seriesInstanceUID(seriesUID)
                                .requestSeriesInstanceUID()
                        } else {
                            // Instance UID only — discover series first, then check
                            subKeys = QueryKeys(level: .image)
                                .studyInstanceUID(sUID)
                                .sopInstanceUID(instanceUID)
                                .requestSOPInstanceUID()
                        }
                        let subResults = try await DICOMQueryService.find(
                            host: host, port: port,
                            configuration: lookupConfig,
                            queryKeys: subKeys
                        )
                        if !subResults.isEmpty {
                            resolvedStudyUID = sUID
                            resolved = true
                            appendConsoleOutput("  Resolved Study UID: \(resolvedStudyUID)\n")
                            break
                        }
                    }
                }

                if !resolved {
                    appendConsoleOutput("Error: Could not resolve Study UID from server.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1,
                                 output: "Study UID lookup failed")
                    return
                }
            } catch {
                appendConsoleOutput("Error: Study UID lookup failed — \(error.localizedDescription)\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1,
                             output: "Study UID lookup failed: \(error.localizedDescription)")
                return
            }
        }

        // Determine retrieval level
        let levelLabel: String
        if !instanceUID.isEmpty { levelLabel = "Instance" }
        else if !seriesUID.isEmpty { levelLabel = "Series" }
        else { levelLabel = "Study" }

        appendConsoleOutput("DICOM Retrieve (\(isCMove ? "C-MOVE" : "C-GET"))\n")
        appendConsoleOutput("=================================\n")
        appendConsoleOutput("  Server:           \(host):\(port)\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Method:           \(isCMove ? "C-MOVE" : "C-GET")\n")
        if isCMove {
            appendConsoleOutput("  Move Destination: \(moveDest)\n")
        }
        appendConsoleOutput("  Level:            \(levelLabel)\n")
        appendConsoleOutput("  Study UID:        \(resolvedStudyUID)\n")
        if !seriesUID.isEmpty {
            appendConsoleOutput("  Series UID:       \(seriesUID)\n")
        }
        if !instanceUID.isEmpty {
            appendConsoleOutput("  Instance UID:     \(instanceUID)\n")
        }
        appendConsoleOutput("  Output:           \(outputDir)\n")
        appendConsoleOutput("  Organization:     \(hierarchical ? "Hierarchical" : "Flat")\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n\n")

        appendConsoleOutput("Executing \(isCMove ? "C-MOVE" : "C-GET")...\n")

        do {
            if isCMove {
                let onProgress: @Sendable (RetrieveProgress) -> Void = { _ in }

                if !instanceUID.isEmpty && !seriesUID.isEmpty {
                    let result = try await DICOMRetrieveService.moveInstance(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        sopInstanceUID: instanceUID,
                        moveDestination: moveDest,
                        onProgress: onProgress,
                        timeout: timeout
                    )
                    appendConsoleOutput(formatRetrieveResult(result))
                } else if !seriesUID.isEmpty {
                    let result = try await DICOMRetrieveService.moveSeries(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        moveDestination: moveDest,
                        onProgress: onProgress,
                        timeout: timeout
                    )
                    appendConsoleOutput(formatRetrieveResult(result))
                } else {
                    let result = try await DICOMRetrieveService.moveStudy(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        moveDestination: moveDest,
                        onProgress: onProgress,
                        timeout: timeout
                    )
                    appendConsoleOutput(formatRetrieveResult(result))
                }
            } else {
                // C-GET
                let stream: AsyncStream<DICOMRetrieveService.GetEvent>
                if !instanceUID.isEmpty && !seriesUID.isEmpty {
                    stream = try await DICOMRetrieveService.getInstance(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        sopInstanceUID: instanceUID,
                        timeout: timeout
                    )
                } else if !seriesUID.isEmpty {
                    stream = try await DICOMRetrieveService.getSeries(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        timeout: timeout
                    )
                } else {
                    stream = try await DICOMRetrieveService.getStudy(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        timeout: timeout
                    )
                }

                var receivedCount = 0
                for await event in stream {
                    switch event {
                    case .instance(let sopInstanceUID, let sopClassUID, let data):
                        receivedCount += 1
                        let sizeStr = FileDropHelpers.formatFileSize(Int64(data.count))
                        appendConsoleOutput("  Received [\(receivedCount)]: \(sopInstanceUID) (\(sizeStr))")
                        // Write the received data to disk
                        do {
                            let savedPath = try writeReceivedDICOMFile(
                                data: data,
                                sopInstanceUID: sopInstanceUID,
                                studyUID: resolvedStudyUID,
                                seriesUID: seriesUID.isEmpty ? nil : seriesUID,
                                outputDir: outputDir,
                                hierarchical: hierarchical
                            )
                            lastRetrievedFiles.append(savedPath)
                            appendConsoleOutput(" → \(savedPath)\n")
                        } catch {
                            appendConsoleOutput(" ⚠️ Save failed: \(error.localizedDescription)\n")
                        }
                    case .progress(let progress):
                        appendConsoleOutput("  Progress: \(progress.completed) completed, \(progress.remaining) remaining, \(progress.failed) failed\n")
                    case .completed(let result):
                        appendConsoleOutput("\n✅ C-GET completed — \(result.progress.completed) file(s) received\n")
                        appendConsoleOutput("  Output directory: \(outputDir)\n")
                    case .error(let error):
                        appendConsoleOutput("\n❌ C-GET failed: \(error.localizedDescription)\n")
                    }
                }
            }

            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 0,
                         output: "Retrieve completed")
        } catch {
            appendConsoleOutput("\n❌ Retrieval failed: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Formats a C-MOVE RetrieveResult for console display.
    private func formatRetrieveResult(_ result: RetrieveResult) -> String {
        var lines: [String] = []
        lines.append("\nC-MOVE Result:")
        lines.append("  Status:    \(result.status)")
        lines.append("  Completed: \(result.progress.completed)")
        lines.append("  Failed:    \(result.progress.failed)")
        lines.append("  Warnings:  \(result.progress.warning)")
        if result.isSuccess {
            lines.append("\n✅ Retrieval successful")
        } else {
            lines.append("\n❌ Retrieval returned non-success status")
        }
        lines.append("")
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Query-Retrieve Execution (dicom-qr)

    /// Performs an integrated C-FIND query followed by C-MOVE/C-GET retrieval.
    private func executeDicomQR() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 60
        let modeStr = paramValue("mode").lowercased()
        let methodStr = paramValue("method").lowercased()
        let moveDest = paramValue("move-dest")
        let patientName = paramValue("patient-name")
        let patientID = paramValue("patient-id")
        let studyDate = paramValue("study-date")
        let modality = paramValue("modality")
        let studyUID = paramValue("study-uid")
        let accession = paramValue("accession")
        let studyDesc = paramValue("study-description")
        let outputDir = resolvedOutputDir(paramValue("output"))
        let hierarchical = paramValue("hierarchical") == "true"
        let _ = paramValue("validate") == "true" // used for CLI command preview

        // Clear previous retrieval state
        lastRetrievedFiles.removeAll()
        lastRetrievedOutputURL = securityScopedURLs["output"]

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        let isCMove = methodStr != "c-get"
        let isReviewOnly = modeStr == "review"

        if !isReviewOnly && isCMove && moveDest.isEmpty {
            appendConsoleOutput("Error: Move Destination AET is required for C-MOVE retrieval.\n")
            appendConsoleOutput("  Tip: Switch to C-GET, use Review mode, or provide a destination AE title.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 1,
                         output: "Move destination required for C-MOVE")
            return
        }

        let modeLabel: String = {
            switch modeStr {
            case "automatic": return "Automatic"
            case "review": return "Review"
            default: return "Interactive"
            }
        }()

        appendConsoleOutput("DICOM Query-Retrieve\n")
        appendConsoleOutput("====================\n")
        appendConsoleOutput("  Server:           \(host):\(port)\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Mode:             \(modeLabel)\n")
        if !isReviewOnly {
            appendConsoleOutput("  Method:           \(isCMove ? "C-MOVE" : "C-GET")\n")
            if isCMove {
                appendConsoleOutput("  Move Destination: \(moveDest)\n")
            }
        }
        appendConsoleOutput("  Output:           \(outputDir)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")

        // Display active filters
        var hasFilters = false
        if !patientName.isEmpty { appendConsoleOutput("  Patient Name:     \(patientName)\n"); hasFilters = true }
        if !patientID.isEmpty { appendConsoleOutput("  Patient ID:       \(patientID)\n"); hasFilters = true }
        if !studyDate.isEmpty { appendConsoleOutput("  Study Date:       \(studyDate)\n"); hasFilters = true }
        if !modality.isEmpty { appendConsoleOutput("  Modality:         \(modality)\n"); hasFilters = true }
        if !studyUID.isEmpty { appendConsoleOutput("  Study UID:        \(studyUID)\n"); hasFilters = true }
        if !accession.isEmpty { appendConsoleOutput("  Accession:        \(accession)\n"); hasFilters = true }
        if !studyDesc.isEmpty { appendConsoleOutput("  Study Desc:       \(studyDesc)\n"); hasFilters = true }
        if !hasFilters {
            appendConsoleOutput("  Filters:          (none — returns all studies)\n")
        }
        appendConsoleOutput("\n")

        // Step 1: Query
        appendConsoleOutput("Phase 1: Querying studies...\n")

        do {
            var queryKeys = QueryKeys(level: .study)
                .requestPatientName()
                .requestPatientID()
                .requestStudyInstanceUID()
                .requestStudyDate()
                .requestStudyDescription()
                .requestAccessionNumber()
                .requestModalitiesInStudy()
                .requestNumberOfStudyRelatedSeries()
                .requestNumberOfStudyRelatedInstances()

            if !patientName.isEmpty { queryKeys = queryKeys.patientName(patientName.uppercased()) }
            if !patientID.isEmpty { queryKeys = queryKeys.patientID(patientID) }
            if !studyDate.isEmpty { queryKeys = queryKeys.studyDate(studyDate) }
            if !modality.isEmpty { queryKeys = queryKeys.modalitiesInStudy(modality) }
            if !studyUID.isEmpty { queryKeys = queryKeys.studyInstanceUID(studyUID) }
            if !accession.isEmpty { queryKeys = queryKeys.accessionNumber(accession) }
            if !studyDesc.isEmpty { queryKeys = queryKeys.studyDescription(studyDesc) }

            let config = QueryConfiguration(
                callingAETitle: try AETitle(callingAET),
                calledAETitle: try AETitle(calledAET),
                timeout: timeout,
                informationModel: .studyRoot
            )

            let results = try await DICOMQueryService.find(
                host: host, port: port,
                configuration: config,
                queryKeys: queryKeys
            )

            if results.isEmpty {
                appendConsoleOutput("No studies found matching the query criteria.\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 0,
                             output: "0 studies found")
                return
            }

            appendConsoleOutput("Found \(results.count) study(ies):\n\n")
            for (index, result) in results.enumerated() {
                let s = result.toStudyResult()
                appendConsoleOutput("  [\(index + 1)] \(s.patientName ?? "Unknown") (ID: \(s.patientID ?? "N/A"))\n")
                appendConsoleOutput("      Study: \(s.studyDescription ?? "No description")\n")
                appendConsoleOutput("      Date: \(s.studyDate ?? "N/A")  Modality: \(s.modalitiesInStudy ?? "N/A")\n")
                if let uid = s.studyInstanceUID {
                    appendConsoleOutput("      UID: \(uid)\n")
                }
                appendConsoleOutput("\n")
            }

            // Review mode — done
            if isReviewOnly {
                appendConsoleOutput("Review complete. \(results.count) study(ies) found.\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 0,
                             output: "\(results.count) studies found (review only)")
                return
            }

            // Phase 2: Retrieve
            let studiesToRetrieve = results
            appendConsoleOutput("Phase 2: Retrieving \(studiesToRetrieve.count) study(ies)...\n\n")

            var successCount = 0
            var failureCount = 0

            for (index, result) in studiesToRetrieve.enumerated() {
                let s = result.toStudyResult()
                guard let uid = s.studyInstanceUID else {
                    appendConsoleOutput("[\(index + 1)/\(studiesToRetrieve.count)] ⚠️ Missing Study UID\n")
                    failureCount += 1
                    continue
                }

                appendConsoleOutput("[\(index + 1)/\(studiesToRetrieve.count)] Retrieving: \(s.patientName ?? "Unknown") — \(uid)\n")

                do {
                    if isCMove {
                        _ = try await DICOMRetrieveService.moveStudy(
                            host: host, port: port,
                            callingAE: callingAET, calledAE: calledAET,
                            studyInstanceUID: uid,
                            moveDestination: moveDest,
                            timeout: timeout
                        )
                    } else {
                        let stream = try await DICOMRetrieveService.getStudy(
                            host: host, port: port,
                            callingAE: callingAET, calledAE: calledAET,
                            studyInstanceUID: uid,
                            timeout: timeout
                        )
                        var fileCount = 0
                        for await event in stream {
                            switch event {
                            case .instance(let sopInstanceUID, _, let data):
                                fileCount += 1
                                do {
                                    let savedPath = try writeReceivedDICOMFile(
                                        data: data,
                                        sopInstanceUID: sopInstanceUID,
                                        studyUID: uid,
                                        outputDir: outputDir,
                                        hierarchical: hierarchical
                                    )
                                    lastRetrievedFiles.append(savedPath)
                                    appendConsoleOutput("    Saved: \(savedPath)\n")
                                } catch {
                                    appendConsoleOutput("    ⚠️ Save failed: \(error.localizedDescription)\n")
                                }
                            case .progress(let progress):
                                appendConsoleOutput("    Progress: \(progress.completed)/\(progress.completed + progress.remaining)\n")
                            case .completed(_):
                                appendConsoleOutput("    \(fileCount) file(s) saved to \(outputDir)\n")
                            case .error(let err):
                                appendConsoleOutput("    ⚠️ \(err.localizedDescription)\n")
                            }
                        }
                    }
                    successCount += 1
                    appendConsoleOutput("  ✅ Success\n\n")
                } catch {
                    failureCount += 1
                    appendConsoleOutput("  ❌ Failed: \(error.localizedDescription)\n\n")
                }
            }

            appendConsoleOutput("Retrieval Summary\n")
            appendConsoleOutput("=================\n")
            appendConsoleOutput("  Total:     \(studiesToRetrieve.count)\n")
            appendConsoleOutput("  Succeeded: \(successCount)\n")
            appendConsoleOutput("  Failed:    \(failureCount)\n")

            if failureCount == 0 {
                appendConsoleOutput("\n✅ All studies retrieved successfully\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
            } else if successCount == 0 {
                appendConsoleOutput("\n❌ All retrievals failed\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
            } else {
                appendConsoleOutput("\n⚠️ Partial success\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
            }

            addToHistory(toolName: "dicom-qr", command: commandPreview,
                         exitCode: failureCount == 0 ? 0 : 1,
                         output: "\(successCount)/\(studiesToRetrieve.count) studies retrieved")
        } catch {
            appendConsoleOutput("❌ Query-Retrieve failed: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Formats a single generic query result for console display.
    private func formatQueryResult(_ result: GenericQueryResult, index: Int, level: QueryLevel, parentStudyInfo: GenericQueryResult? = nil) -> String {
        var lines: [String] = ["--- Result \(index) ---"]

        // Display attributes from the queried (lower) level up to higher parent levels.

        // Image-level attributes
        if level == .image {
            let i = result.toInstanceResult()
            if let v = i.sopClassUID    { lines.append("  SOP Class:     \(v)") }
            if let v = i.sopInstanceUID { lines.append("  SOP Instance:  \(v)") }
            if let v = i.instanceNumber { lines.append("  Instance #:    \(v)") }
            if let v = i.contentDate    { lines.append("  Content Date:  \(v)") }
            if let v = i.rows, let c = i.columns { lines.append("  Dimensions:    \(c)x\(v)") }
            if let v = i.numberOfFrames { lines.append("  Frames:        \(v)") }
        }

        // Series-level attributes
        if level == .series || level == .image {
            let s = result.toSeriesResult()
            if let v = s.seriesDescription { lines.append("  Series Desc:   \(v)") }
            if let v = s.modality       { lines.append("  Modality:      \(v)") }
            if let v = s.seriesNumber   { lines.append("  Series #:      \(v)") }
            if let v = s.seriesDate     { lines.append("  Series Date:   \(v)") }
            if let v = s.numberOfSeriesRelatedInstances { lines.append("  Instances:     \(v)") }
            if let v = s.seriesInstanceUID { lines.append("  Series UID:    \(v)") }
        }

        // Study-level attributes (with parent info fallback for series/image levels)
        if level == .study || level == .series || level == .image {
            let s = result.toStudyResult()
            let ps = parentStudyInfo?.toStudyResult()
            if let v = s.studyDate ?? ps?.studyDate { lines.append("  Study Date:    \(v)") }
            if let v = s.studyTime ?? ps?.studyTime { lines.append("  Study Time:    \(v)") }
            if let v = s.studyDescription ?? ps?.studyDescription { lines.append("  Study Desc:    \(v)") }
            if let v = s.accessionNumber ?? ps?.accessionNumber { lines.append("  Accession:     \(v)") }
            if let v = s.modalitiesInStudy ?? ps?.modalitiesInStudy { lines.append("  Modalities:    \(v)") }
            if let v = s.numberOfStudyRelatedSeries ?? ps?.numberOfStudyRelatedSeries { lines.append("  Study Series:  \(v)") }
            if let v = s.numberOfStudyRelatedInstances ?? ps?.numberOfStudyRelatedInstances { lines.append("  Study Images:  \(v)") }
            if let v = s.studyInstanceUID ?? ps?.studyInstanceUID { lines.append("  Study UID:     \(v)") }
        }

        // Patient-level attributes (highest level — always shown, with parent info fallback)
        let p = result.toPatientResult()
        let pp = parentStudyInfo?.toPatientResult()
        if let v = p.patientName ?? pp?.patientName { lines.append("  Patient Name:  \(v)") }
        if let v = p.patientID ?? pp?.patientID { lines.append("  Patient ID:    \(v)") }
        if let v = p.patientBirthDate ?? pp?.patientBirthDate { lines.append("  Birth Date:    \(v)") }
        if let v = p.patientSex ?? pp?.patientSex { lines.append("  Sex:           \(v)") }
        if level == .patient {
            if let v = p.numberOfPatientRelatedStudies { lines.append("  Studies:       \(v)") }
            if let v = p.numberOfPatientRelatedSeries  { lines.append("  Series:        \(v)") }
            if let v = p.numberOfPatientRelatedInstances { lines.append("  Instances:     \(v)") }
        }

        lines.append("")
        return lines.joined(separator: "\n") + "\n"
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
