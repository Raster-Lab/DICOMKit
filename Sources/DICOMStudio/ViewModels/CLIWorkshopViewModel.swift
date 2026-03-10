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

    // Server selection for network tools
    /// Saved PACS server profiles from the Networking tab.
    public var savedServerProfiles: [PACSServerProfile] = []
    /// Whether the user is picking a saved server or entering details manually.
    public var networkInputMode: NetworkInputMode = .manual
    /// The ID of the selected saved server profile.
    public var selectedSavedServerID: UUID? = nil

    /// Toggles between using a saved server profile and entering parameters manually.
    public enum NetworkInputMode: String, Sendable, CaseIterable, Identifiable {
        case savedServer = "Saved Server"
        case manual = "Manual"
        public var id: String { rawValue }
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
                queryKeys = queryKeys.patientName(patientName)
                appendConsoleOutput("  Patient Name:     \(patientName)\n")
            } else {
                queryKeys = queryKeys.requestPatientName()
            }
            queryKeys = queryKeys
                .requestPatientBirthDate()
                .requestPatientSex()

        case .study:
            if !patientID.isEmpty {
                queryKeys = queryKeys.patientID(patientID)
                appendConsoleOutput("  Patient ID:       \(patientID)\n")
            } else {
                queryKeys = queryKeys.requestPatientID()
            }
            if !patientName.isEmpty {
                queryKeys = queryKeys.patientName(patientName)
                appendConsoleOutput("  Patient Name:     \(patientName)\n")
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
                appendConsoleOutput("Found \(allResults.count) result(s):\n\n")
                for (index, result) in allResults.enumerated() {
                    appendConsoleOutput(formatQueryResult(result, index: index + 1, level: level))
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
        if !patientName.isEmpty { studyQueryKeys = studyQueryKeys.patientName(patientName) }
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

    /// Formats a single generic query result for console display.
    private func formatQueryResult(_ result: GenericQueryResult, index: Int, level: QueryLevel) -> String {
        var lines: [String] = ["--- Result \(index) ---"]
        switch level {
        case .patient:
            let p = result.toPatientResult()
            if let v = p.patientName    { lines.append("  Patient Name:  \(v)") }
            if let v = p.patientID      { lines.append("  Patient ID:    \(v)") }
            if let v = p.patientBirthDate { lines.append("  Birth Date:    \(v)") }
            if let v = p.patientSex     { lines.append("  Sex:           \(v)") }
        case .study:
            let s = result.toStudyResult()
            if let v = s.patientName    { lines.append("  Patient:       \(v)") }
            if let v = s.patientID      { lines.append("  Patient ID:    \(v)") }
            if let v = s.studyDate      { lines.append("  Study Date:    \(v)") }
            if let v = s.studyDescription { lines.append("  Description:   \(v)") }
            if let v = s.accessionNumber { lines.append("  Accession:     \(v)") }
            if let v = s.modalitiesInStudy { lines.append("  Modalities:    \(v)") }
            if let v = s.studyInstanceUID { lines.append("  Study UID:     \(v)") }
        case .series:
            let s = result.toSeriesResult()
            if let v = s.seriesDescription { lines.append("  Description:   \(v)") }
            if let v = s.modality       { lines.append("  Modality:      \(v)") }
            if let v = s.seriesNumber   { lines.append("  Series #:      \(v)") }
            if let v = s.seriesDate     { lines.append("  Series Date:   \(v)") }
            if let v = s.numberOfSeriesRelatedInstances { lines.append("  Instances:     \(v)") }
            if let v = s.seriesInstanceUID { lines.append("  Series UID:    \(v)") }
        case .image:
            let i = result.toInstanceResult()
            if let v = i.sopClassUID    { lines.append("  SOP Class:     \(v)") }
            if let v = i.sopInstanceUID { lines.append("  SOP Instance:  \(v)") }
            if let v = i.instanceNumber { lines.append("  Instance #:    \(v)") }
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
