// CLIWorkshopViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for CLI Tools Workshop (Milestone 16)

import Foundation
import Observation
import DICOMCore
import DICOMKit
import DICOMNetwork
import DICOMWeb

// MARK: - DICOM Part 10 File Format helpers (file-private, context-free)

/// Encodes a 16-bit unsigned integer in little-endian byte order.
private func le16(_ v: UInt16) -> Data {
    Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)])
}

/// Encodes a 32-bit unsigned integer in little-endian byte order.
private func le32(_ v: UInt32) -> Data {
    Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
          UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
}

/// Encodes a File Meta Information element with VR "UL" (4-byte unsigned long).
private func fmiUL(_ group: UInt16, _ element: UInt16, _ value: UInt32) -> Data {
    le16(group) + le16(element)
    + Data([0x55, 0x4C])  // "UL"
    + le16(4)             // value length
    + le32(value)
}

/// Encodes a File Meta Information element with VR "OB" (uses 4-byte length field).
private func fmiOB(_ group: UInt16, _ element: UInt16, _ value: Data) -> Data {
    le16(group) + le16(element)
    + Data([0x4F, 0x42])  // "OB"
    + Data([0x00, 0x00])  // reserved
    + le32(UInt32(value.count))
    + value
}

/// Encodes a File Meta Information element with VR "UI".
/// UI values are null-padded to even byte length per PS3.5 §6.2.
private func fmiUI(_ group: UInt16, _ element: UInt16, _ value: String) -> Data {
    var bytes = value.data(using: .ascii) ?? Data()
    if bytes.count % 2 != 0 { bytes.append(0x00) }  // null padding for UI
    return le16(group) + le16(element)
        + Data([0x55, 0x49])      // "UI"
        + le16(UInt16(bytes.count))
        + bytes
}

/// Wraps raw DICOM C-STORE dataset bytes in a DICOM Part 10 file container.
///
/// C-STORE transfers deliver raw dataset bytes without the 128-byte preamble,
/// DICM magic bytes, or File Meta Information group (0002,xxxx).  This function
/// reconstructs the proper Part 10 layout required by every conformant DICOM
/// reader, following PS3.10 §7.1.
///
/// - Parameters:
///   - dataset:          Raw dataset bytes as delivered by C-STORE / C-GET.
///   - sopClassUID:      SOP Class UID for (0002,0002) and (0002,0003).
///   - sopInstanceUID:   SOP Instance UID for (0002,0003).
///   - transferSyntaxUID: Transfer Syntax UID for (0002,0010).
/// - Returns: A complete Part 10 DICOM file object (Data).
func part10Wrap(dataset: Data, sopClassUID: String,
                sopInstanceUID: String,
                transferSyntaxUID: String) -> Data {
    // Build the File Meta Information elements (all Explicit VR LE)
    var meta = Data()
    meta += fmiOB(0x0002, 0x0001, Data([0x00, 0x01]))       // FileMetaInformationVersion
    meta += fmiUI(0x0002, 0x0002, sopClassUID)               // MediaStorageSOPClassUID
    meta += fmiUI(0x0002, 0x0003, sopInstanceUID)            // MediaStorageSOPInstanceUID
    meta += fmiUI(0x0002, 0x0010, transferSyntaxUID)         // TransferSyntaxUID
    meta += fmiUI(0x0002, 0x0012, "1.2.826.0.1.3680043.9.7433.1.1")  // ImplementationClassUID

    var file = Data()
    file += Data(repeating: 0, count: 128)                  // 128-byte preamble
    file += Data([0x44, 0x49, 0x43, 0x4D])                  // "DICM" magic
    file += fmiUL(0x0002, 0x0000, UInt32(meta.count))       // FileMetaInformationGroupLength
    file += meta
    file += dataset
    return file
}

// MARK: - SCP Storage Delegate

/// StorageDelegate that saves received C-STORE instances as proper Part 10
/// DICOM files (with preamble, DICM magic, and File Meta Information).
private actor DICOMStudioSCPDelegate: StorageDelegate {
    private let storageDir: URL

    init(storageDir: URL) {
        self.storageDir = storageDir
    }

    func didReceive(file: ReceivedFile) async throws {
        let wrapped = part10Wrap(
            dataset: file.dataSetData,
            sopClassUID: file.sopClassUID,
            sopInstanceUID: file.sopInstanceUID,
            transferSyntaxUID: file.transferSyntaxUID
        )
        try FileManager.default.createDirectory(
            at: storageDir, withIntermediateDirectories: true)
        let dst = storageDir.appendingPathComponent("\(file.sopInstanceUID).dcm")
        try wrapped.write(to: dst, options: .atomic)
    }
}

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class CLIWorkshopViewModel {
    private let service: CLIWorkshopService

    /// Callback to open a retrieved file in the Viewer tab.
    /// Set by MainViewModel to wire navigation.
    public var onOpenInViewer: ((String, URL?) -> Void)?

    /// Callback to open a set of retrieved files as a navigable series in the Viewer tab.
    /// Parameters: ordered file paths, start index, optional security-scoped parent URL.
    /// When set, `openRetrievedFileInViewer()` uses this instead of `onOpenInViewer`.
    public var onOpenSeriesInViewer: (([String], Int, URL?) -> Void)?

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

    // MARK: - Local SCP Listener

    /// Whether the local DICOM SCP listener is currently running.
    public var scpIsRunning: Bool = false
    /// Port the local SCP listens on.
    public var scpPort: String = "11112"
    /// AE Title used by the local SCP.
    public var scpAETitle: String = "DICOMSTUDIO"
    /// Output directory where the SCP writes received DICOM files.
    public var scpOutputDir: String = {
        NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
    }()
    /// Human-readable status message for the local SCP.
    public var scpStatusMessage: String = "SCP not started"
    /// Files received through the local SCP listener (most recent first).
    public var scpReceivedFiles: [String] = []
    /// Structured event log for the local SCP listener.
    public var appLog: [SCPLogEntry] = []

    private var storageSCP: DICOMStorageServer?
    private var scpEventTask: Task<Void, Never>?

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

    // DICOMweb server selection
    /// Saved DICOMweb server profiles.
    public var savedDICOMwebProfiles: [DICOMwebServerProfile] = []
    /// The ID of the selected DICOMweb server profile.
    public var selectedDICOMwebServerID: UUID? = nil
    /// Whether the "Add DICOMweb Server" sheet is shown.
    public var showAddDICOMwebServerSheet: Bool = false
    /// Whether the "Edit DICOMweb Server" sheet is shown.
    public var showEditDICOMwebServerSheet: Bool = false
    /// The ID of the DICOMweb server being edited (nil when adding).
    public var editingDICOMwebServerID: UUID? = nil
    /// Editable fields for adding/editing a DICOMweb server.
    public var newDICOMwebServerName: String = ""
    public var newDICOMwebServerURL: String = ""
    public var newDICOMwebAuthMethod: String = "none"
    public var newDICOMwebUsername: String = ""
    public var newDICOMwebToken: String = ""

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

        // Load persisted DICOMweb server profiles from disk.
        let webStorage = DICOMwebServerProfileStorageService()
        savedDICOMwebProfiles = webStorage.load()
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
            // If a saved server is selected, override with its values;
            // otherwise the persistent defaults (applied above) remain.
            if let serverID = selectedSavedServerID,
               let server = savedServerProfiles.first(where: { $0.id == serverID }),
               hasHostParam {
                updateParameterValueSilent(parameterID: "host", value: server.host)
                updateParameterValueSilent(parameterID: "port", value: String(server.port))
                updateParameterValueSilent(parameterID: "calling-aet", value: server.localAETitle)
                updateParameterValueSilent(parameterID: "called-aet", value: server.remoteAETitle)
                updateParameterValueSilent(parameterID: "timeout", value: String(Int(server.timeoutSeconds)))
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

    /// Whether the currently selected tool is a DICOMweb tool (vs DIMSE).
    public var isDICOMwebToolSelected: Bool {
        guard let tool = selectedTool() else { return false }
        return tool.networkToolGroup == .dicomweb
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

    /// Applies a saved DICOMweb server profile's values to the current parameters.
    public func applySavedDICOMwebServer(id: UUID?) {
        selectedDICOMwebServerID = id
        guard let serverID = id,
              let server = savedDICOMwebProfiles.first(where: { $0.id == serverID }) else {
            return
        }
        updateParameterValue(parameterID: "url", value: server.baseURL)
        switch server.authMethod {
        case .none:
            updateParameterValue(parameterID: "auth", value: "none")
        case .basic:
            updateParameterValue(parameterID: "auth", value: "basic")
            updateParameterValue(parameterID: "username", value: server.username)
            updateParameterValue(parameterID: "token", value: server.password)
        case .bearer, .jwt:
            updateParameterValue(parameterID: "auth", value: "bearer")
            updateParameterValue(parameterID: "token", value: server.bearerToken)
        case .oauth2PKCE:
            updateParameterValue(parameterID: "auth", value: "bearer")
            updateParameterValue(parameterID: "token", value: server.bearerToken)
        }
        rebuildCommandPreview()
    }

    /// Adds a new DICOMweb server profile from the "Add DICOMweb Server" form.
    public func addNewDICOMwebServerFromForm() {
        let name = newDICOMwebServerName.trimmingCharacters(in: .whitespaces)
        let url = newDICOMwebServerURL.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !url.isEmpty else { return }

        let authMethod: DICOMwebAuthMethod
        switch newDICOMwebAuthMethod {
        case "basic": authMethod = .basic
        case "bearer": authMethod = .bearer
        default: authMethod = .none
        }

        let profile = DICOMwebServerProfile(
            name: name,
            baseURL: url,
            authMethod: authMethod,
            bearerToken: authMethod == .bearer ? newDICOMwebToken : "",
            username: authMethod == .basic ? newDICOMwebUsername : "",
            password: authMethod == .basic ? newDICOMwebToken : ""
        )
        savedDICOMwebProfiles.append(profile)

        // Persist via DICOMwebServerProfileStorageService
        let storage = DICOMwebServerProfileStorageService()
        try? storage.save(savedDICOMwebProfiles)

        // Reset form
        newDICOMwebServerName = ""
        newDICOMwebServerURL = ""
        newDICOMwebAuthMethod = "none"
        newDICOMwebUsername = ""
        newDICOMwebToken = ""
        showAddDICOMwebServerSheet = false

        // Auto-select the newly added server
        applySavedDICOMwebServer(id: profile.id)
    }

    /// Removes a saved DICOMweb server profile by ID.
    public func removeSavedDICOMwebServer(id: UUID) {
        savedDICOMwebProfiles.removeAll { $0.id == id }
        if selectedDICOMwebServerID == id {
            selectedDICOMwebServerID = nil
        }

        // Persist removal
        let storage = DICOMwebServerProfileStorageService()
        try? storage.save(savedDICOMwebProfiles)
    }

    /// Populates the edit form with an existing DICOMweb server profile's data.
    public func beginEditDICOMwebServer(id: UUID) {
        guard let server = savedDICOMwebProfiles.first(where: { $0.id == id }) else { return }
        editingDICOMwebServerID = server.id
        newDICOMwebServerName = server.name
        newDICOMwebServerURL = server.baseURL
        switch server.authMethod {
        case .basic:
            newDICOMwebAuthMethod = "basic"
            newDICOMwebUsername = server.username
            newDICOMwebToken = server.password
        case .bearer, .jwt:
            newDICOMwebAuthMethod = "bearer"
            newDICOMwebToken = server.bearerToken
        case .oauth2PKCE:
            newDICOMwebAuthMethod = "bearer"
            newDICOMwebToken = server.bearerToken
        case .none:
            newDICOMwebAuthMethod = "none"
        }
        showEditDICOMwebServerSheet = true
    }

    /// Saves edits to an existing DICOMweb server profile.
    public func saveEditedDICOMwebServer() {
        guard let editID = editingDICOMwebServerID,
              let idx = savedDICOMwebProfiles.firstIndex(where: { $0.id == editID }) else { return }
        let name = newDICOMwebServerName.trimmingCharacters(in: .whitespaces)
        let url = newDICOMwebServerURL.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !url.isEmpty else { return }

        let authMethod: DICOMwebAuthMethod
        switch newDICOMwebAuthMethod {
        case "basic": authMethod = .basic
        case "bearer": authMethod = .bearer
        default: authMethod = .none
        }

        savedDICOMwebProfiles[idx] = DICOMwebServerProfile(
            id: editID,
            name: name,
            baseURL: url,
            authMethod: authMethod,
            bearerToken: authMethod == .bearer ? newDICOMwebToken : "",
            username: authMethod == .basic ? newDICOMwebUsername : "",
            password: authMethod == .basic ? newDICOMwebToken : ""
        )

        let storage = DICOMwebServerProfileStorageService()
        try? storage.save(savedDICOMwebProfiles)

        // Reset form
        editingDICOMwebServerID = nil
        newDICOMwebServerName = ""
        newDICOMwebServerURL = ""
        newDICOMwebAuthMethod = "none"
        newDICOMwebUsername = ""
        newDICOMwebToken = ""
        showEditDICOMwebServerSheet = false

        // Re-apply if this was the selected server
        if selectedDICOMwebServerID == editID {
            applySavedDICOMwebServer(id: editID)
        }
    }

    /// Saves the current DICOMweb server parameters as persistent defaults.
    public func saveDICOMwebServerAsDefault() {
        let url = paramValue("url")
        let auth = paramValue("auth")
        let user = paramValue("username")
        let token = paramValue("token")
        if !url.isEmpty { UserDefaults.standard.set(url, forKey: DICOMwebDefaultKeys.url) }
        if !auth.isEmpty { UserDefaults.standard.set(auth, forKey: DICOMwebDefaultKeys.auth) }
        if !user.isEmpty { UserDefaults.standard.set(user, forKey: DICOMwebDefaultKeys.username) }
        if !token.isEmpty { UserDefaults.standard.set(token, forKey: DICOMwebDefaultKeys.token) }
    }

    /// UserDefaults keys for persistent default DICOMweb server values.
    private enum DICOMwebDefaultKeys {
        static let url = "studio.cli.defaultDICOMwebURL"
        static let auth = "studio.cli.defaultDICOMwebAuth"
        static let username = "studio.cli.defaultDICOMwebUsername"
        static let token = "studio.cli.defaultDICOMwebToken"
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
    /// The raw dataset bytes delivered by C-STORE / C-GET sub-operations lack the
    /// Part 10 header (128-byte preamble + "DICM" magic + File Meta Information).
    /// This function wraps them in a proper Part 10 container before saving so that
    /// all conformant DICOM readers can open the resulting file directly.
    ///
    /// - Parameters:
    ///   - data: The raw DICOM dataset bytes (no Part 10 header).
    ///   - sopInstanceUID: The SOP Instance UID (used as the filename).
    ///   - sopClassUID: The SOP Class UID for the File Meta Information.
    ///   - transferSyntaxUID: The transfer syntax the dataset is encoded in.
    ///   - studyUID: The Study Instance UID (for hierarchical organisation).
    ///   - seriesUID: Optional Series Instance UID (for hierarchical organisation).
    ///   - outputDir: The base output directory path.
    ///   - hierarchical: If true, organises as `<studyUID>/<seriesUID>/<sopInstanceUID>.dcm`.
    /// - Returns: The full path where the file was written.
    @discardableResult
    public func writeReceivedDICOMFile(
        data: Data,
        sopInstanceUID: String,
        sopClassUID: String = "1.2.840.10008.5.1.4.1.1.7",
        transferSyntaxUID: String = "1.2.840.10008.1.2.1",
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

        // If the data already has a DICM prefix it is a complete Part 10 file
        // (e.g. from WADO-RS). Write it as-is to avoid double-wrapping.
        let fileData: Data
        if data.count >= 132,
           data[128] == 0x44, data[129] == 0x49, data[130] == 0x43, data[131] == 0x4D {
            fileData = data
        } else {
            fileData = part10Wrap(
                dataset: data,
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                transferSyntaxUID: transferSyntaxUID
            )
        }
        try fileData.write(to: fileURL, options: .atomic)

        return fileURL.path
    }

    /// Writes arbitrary data to a file in the output directory, handling security-scoped access.
    ///
    /// Unlike `writeReceivedDICOMFile` (which wraps DICOM datasets in Part 10 containers),
    /// this writes raw data as-is — suitable for rendered images, JSON exports, etc.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - filename: The filename (including extension) for the output file.
    ///   - outputDir: The resolved output directory path.
    /// - Returns: The full path where the file was written.
    @discardableResult
    public func writeOutputFile(data: Data, filename: String, outputDir: String) throws -> String {
        let fm = FileManager.default
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

        try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
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

    /// Returns visible parameters based on experience mode and conditional visibility rules.
    public func visibleParameters() -> [CLIParameterDefinition] {
        let base: [CLIParameterDefinition]
        switch experienceMode {
        case .beginner:
            base = parameterDefinitions.filter { !$0.isAdvanced }
        case .advanced:
            base = parameterDefinitions
        }
        return base.filter { param in
            guard let condition = param.visibleWhen else { return true }
            let currentValue = paramValue(condition.parameterId)
            let effectiveValue = currentValue.isEmpty
                ? parameterDefinitions.first(where: { $0.id == condition.parameterId })?.defaultValue ?? ""
                : currentValue
            return condition.values.contains(effectiveValue)
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

    /// Opens retrieved files from the last retrieve/QR operation in the viewer.
    ///
    /// If multiple files were retrieved, loads them as a navigable series via
    /// `onOpenSeriesInViewer`. Falls back to opening just the first file via
    /// `onOpenInViewer` when the series callback is not set.
    public func openRetrievedFileInViewer() {
        guard !lastRetrievedFiles.isEmpty else { return }
        if let seriesCallback = onOpenSeriesInViewer, lastRetrievedFiles.count > 1 {
            seriesCallback(lastRetrievedFiles, 0, lastRetrievedOutputURL)
        } else {
            onOpenInViewer?(lastRetrievedFiles[0], lastRetrievedOutputURL)
        }
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
        case "dicom-mwl":
            await executeDicomMWL()
        case "dicom-mpps":
            await executeDicomMPPS()
        case "dcm2dcm":
            await executeDcm2Dcm()
        case "dicom-qido":
            await executeDicomQIDO()
        case "dicom-wado":
            await executeDicomWADO()
        case "dicom-stow":
            await executeDicomSTOW()
        case "dicom-ups":
            await executeDicomUPS()
        default:
            appendConsoleOutput("⚠ Command execution not yet supported for \(tool.name).\n")
            consoleStatus = .idle
            service.setConsoleStatus(.idle)
        }
    }

    // MARK: - Local SCP Listener Management

    /// Starts the local DICOM SCP listener so other applications can connect,
    /// send C-ECHO (verification), and C-STORE (push files) to DICOMStudio.
    ///
    /// The SCP uses ``DICOMStorageServer`` which already accepts all common
    /// storage SOP classes as well as the Verification SOP Class, so incoming
    /// C-ECHO requests are handled automatically alongside C-STORE sub-operations.
    public func startLocalSCP() async {
        guard !scpIsRunning else { return }
        let portNum = UInt16(scpPort) ?? 11112
        let aetStr = scpAETitle.isEmpty ? "DICOMSTUDIO" : scpAETitle
        let outputURL = URL(fileURLWithPath:
            scpOutputDir.isEmpty
                ? (NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true).first
                    ?? NSTemporaryDirectory())
                : scpOutputDir
        )

        do {
            let aeTitle = try AETitle(aetStr)
            let config = StorageSCPConfiguration(aeTitle: aeTitle, port: portNum)
            let delegate = DICOMStudioSCPDelegate(storageDir: outputURL)
            let scp = DICOMStorageServer(configuration: config, delegate: delegate)
            try await scp.start()
            storageSCP = scp
            scpIsRunning = true
            scpStatusMessage = "Listening on port \(portNum) as \(aetStr)"
            appendConsoleOutput("\n🔌 Local SCP started — port \(portNum), AE Title: \(aetStr)\n")
            appendConsoleOutput("   Files will be written to: \(outputURL.path)\n\n")
            appLog.insert(SCPLogEntry(
                level: .info,
                message: "Local SCP started on port \(portNum) as \(aetStr)"
            ), at: 0)

            // Consume the event stream and relay updates to main-actor state
            scpEventTask = Task { [weak self] in
                guard let self else { return }
                let eventStream = await scp.events
                for await event in eventStream {
                    await MainActor.run { self.handleSCPEvent(event) }
                }
            }
        } catch {
            scpStatusMessage = "Failed to start: \(error.localizedDescription)"
            appendConsoleOutput("\n❌ Failed to start local SCP: \(error.localizedDescription)\n")
            appLog.insert(SCPLogEntry(
                level: .error,
                message: "Failed to start SCP: \(error.localizedDescription)"
            ), at: 0)
        }
    }

    /// Stops the local DICOM SCP listener.
    public func stopLocalSCP() async {
        guard scpIsRunning, let scp = storageSCP else { return }
        await scp.stop()
        scpEventTask?.cancel()
        scpEventTask = nil
        storageSCP = nil
        scpIsRunning = false
        scpStatusMessage = "SCP stopped"
        appendConsoleOutput("\n🔌 Local SCP stopped\n")
        appLog.insert(SCPLogEntry(level: .info, message: "Local SCP stopped"), at: 0)
    }

    private func handleSCPEvent(_ event: StorageServerEvent) {
        switch event {
        case .fileReceived(let file):
            let path = scpOutputDir + "/" + file.sopInstanceUID + ".dcm"
            scpReceivedFiles.insert(path, at: 0)
            appendConsoleOutput("  📥 Received: \(file.sopInstanceUID)"
                + " from \(file.callingAETitle) → \(path)\n")
            appLog.insert(SCPLogEntry(
                level: .fileReceived,
                message: "Received \(file.sopInstanceUID).dcm",
                remoteAETitle: file.callingAETitle
            ), at: 0)
        case .associationEstablished(let info):
            appendConsoleOutput("  🔗 Association from \(info.callingAETitle)"
                + " (\(info.remoteHost):\(info.remotePort))\n")
            appLog.insert(SCPLogEntry(
                level: .connection,
                message: "Association established from \(info.callingAETitle)",
                remoteAETitle: info.callingAETitle,
                remoteHost: "\(info.remoteHost):\(info.remotePort)"
            ), at: 0)
        case .associationRejected(let ae, let reason):
            appendConsoleOutput("  ⛔ Rejected association from \(ae): \(reason)\n")
            appLog.insert(SCPLogEntry(
                level: .warning,
                message: "Association rejected from \(ae): \(reason)",
                remoteAETitle: ae
            ), at: 0)
        case .error(let error):
            appendConsoleOutput("  ❌ SCP error: \(error.localizedDescription)\n")
            scpStatusMessage = "SCP error: \(error.localizedDescription)"
            appLog.insert(SCPLogEntry(
                level: .error,
                message: "SCP error: \(error.localizedDescription)"
            ), at: 0)
        default:
            break
        }
    }

    /// Clears the application event log.
    public func clearAppLog() {
        appLog.removeAll()
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
        } catch let netErr as DICOMNetworkError {
            appendConsoleOutput("❌ C-ECHO failed\n")
            switch netErr {
            case .associationRejected(let result, let source, let reason):
                appendConsoleOutput("  Reason: Association rejected (\(result))\n")
                appendConsoleOutput("  Source: \(source)\n")
                let reasonDesc = Self.associateRejectReasonDescription(source: source, reason: reason)
                appendConsoleOutput("  Code  : \(reason) — \(reasonDesc)\n")
                appendConsoleOutput("\n")
                // Actionable hints for the most common dcm4chee2 / legacy-PACS rejection reasons
                switch (source, reason) {
                case (.serviceUser, 3):
                    appendConsoleOutput("  💡 Hint: The remote SCP does not recognise the Called AE Title\n")
                    appendConsoleOutput("           (\"\(calledAET)\"). Register it in the remote AE Manager\n")
                    appendConsoleOutput("           (e.g. dcm4chee AE Management → Add AE Title) or change the\n")
                    appendConsoleOutput("           Called AE Title field above to match the server's configured AE.\n")
                case (.serviceUser, 7):
                    appendConsoleOutput("  💡 Hint: The remote SCP does not recognise the Calling AE Title\n")
                    appendConsoleOutput("           (\"\(callingAET)\"). Add it to the remote server's list of\n")
                    appendConsoleOutput("           permitted calling AE titles, or change Calling AE Title above.\n")
                case (.serviceUser, 2):
                    appendConsoleOutput("  💡 Hint: The remote SCP reports the application context is not supported.\n")
                    appendConsoleOutput("           Make sure the server has DICOM networking enabled.\n")
                case (.serviceProviderACSE, 2):
                    appendConsoleOutput("  💡 Hint: Protocol version mismatch. Try switching to Implicit VR transfer\n")
                    appendConsoleOutput("           syntax for legacy server compatibility.\n")
                case (.serviceProviderPresentation, 1):
                    appendConsoleOutput("  💡 Hint: Server temporarily busy. Wait a moment and retry.\n")
                default:
                    appendConsoleOutput("  💡 Hint: Verify the host, port, and AE titles. For dcm4chee2, ensure\n")
                    appendConsoleOutput("           both the Calling and Called AE Titles are registered in the\n")
                    appendConsoleOutput("           server's AE Management console.\n")
                }
            case .connectionFailed(let msg):
                appendConsoleOutput("  Error: \(msg)\n")
                appendConsoleOutput("  💡 Hint: Check host (\(host)), port (\(port)), and that the DICOM server is running.\n")
            case .timeout, .artimTimerExpired:
                appendConsoleOutput("  Error: Connection timed out after \(Int(timeout))s\n")
                appendConsoleOutput("  💡 Hint: Verify host/port are reachable. Try increasing the Timeout value.\n")
            case .connectionClosed:
                appendConsoleOutput("  Error: Connection closed unexpectedly by remote peer\n")
                appendConsoleOutput("  💡 Hint: The server may have rejected the connection silently.\n")
                appendConsoleOutput("           Check that the Called AE Title is registered on the server.\n")
            default:
                appendConsoleOutput("  Error: \(netErr.description)\n")
            }
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1,
                         output: netErr.description)
        } catch {
            appendConsoleOutput("❌ C-ECHO failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Translates an A-ASSOCIATE-RJ reason byte into a human-readable string.
    ///
    /// Reference: PS3.8 Tables 9-20, 9-21, 9-22
    private static func associateRejectReasonDescription(source: AssociateRejectSource, reason: UInt8) -> String {
        switch source {
        case .serviceUser:
            switch reason {
            case 1: return "No reason given"
            case 2: return "Application context name not supported"
            case 3: return "Called AE Title not recognised"
            case 7: return "Calling AE Title not recognised"
            default: return "Unknown reason"
            }
        case .serviceProviderACSE:
            switch reason {
            case 1: return "No reason given"
            case 2: return "Protocol version not supported"
            default: return "Unknown reason"
            }
        case .serviceProviderPresentation:
            switch reason {
            case 0: return "No reason given"
            case 1: return "Temporary congestion"
            case 2: return "Local limit exceeded"
            default: return "Unknown reason"
            }
        }
    }

    /// Returns the current string value for a parameter by ID.
    private func paramValue(_ paramID: String) -> String {
        parameterValues.first(where: { $0.parameterID == paramID })?.stringValue ?? ""
    }

    // MARK: - DICOMweb Tool Execution

    /// Creates a `DICOMwebServerProfile` from the current parameter values.
    private func dicomwebProfileFromParams() -> DICOMwebServerProfile? {
        let url = paramValue("url")
        guard !url.isEmpty else { return nil }
        let authStr = paramValue("auth")
        let authMethod: DICOMwebAuthMethod
        switch authStr {
        case "basic": authMethod = .basic
        case "bearer": authMethod = .bearer
        default: authMethod = .none
        }
        return DICOMwebServerProfile(
            name: "CLI",
            baseURL: url,
            authMethod: authMethod,
            bearerToken: paramValue("token"),
            username: paramValue("username"),
            password: paramValue("token")
        )
    }

    /// Executes a QIDO-RS query against a DICOMweb server.
    private func executeDicomQIDO() async {
        guard let profile = dicomwebProfileFromParams() else {
            appendConsoleOutput("Error: Base URL is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qido", command: commandPreview, exitCode: 1, output: "Base URL is required")
            return
        }

        let levelStr = paramValue("level").uppercased()
        let limit = Int(paramValue("limit")) ?? 100
        let offset = Int(paramValue("offset")) ?? 0
        let outputFormat = paramValue("output-format").lowercased()

        appendConsoleOutput("Querying \(profile.baseURL) ...\n")
        appendConsoleOutput("  Level:   \(levelStr.isEmpty ? "STUDY" : levelStr)\n")
        appendConsoleOutput("  Limit:   \(limit)\n")
        appendConsoleOutput("  Offset:  \(offset)\n\n")

        do {
            let client = try DICOMwebClientFactory.makeClient(from: profile)

            var query = QIDOQuery().limit(limit).offset(offset).includeAllFields()
            let patientName = paramValue("patient-name")
            let patientID = paramValue("patient-id")
            let studyDate = paramValue("study-date")
            let modality = paramValue("modality")
            let studyUID = paramValue("study-uid")
            let studyDesc = paramValue("study-description")

            // Case-insensitive patient name with auto-wildcard suffix
            if !patientName.isEmpty {
                var nameQuery = patientName.uppercased()
                if !nameQuery.contains("*") && !nameQuery.contains("?") {
                    nameQuery += "*"
                }
                query = query.patientName(nameQuery)
            }
            if !patientID.isEmpty { query = query.patientID(patientID) }
            if !studyDate.isEmpty { query = query.studyDate(studyDate) }
            if !modality.isEmpty {
                // Use the correct DICOM tag per query level:
                // Study level: Modalities in Study (0008,0061)
                // Series level: Modality (0008,0060)
                if levelStr == "SERIES" {
                    query = query.modality(modality)
                } else {
                    query = query.modalitiesInStudy(modality)
                }
            }
            if !studyUID.isEmpty { query = query.studyInstanceUID(studyUID) }
            if !studyDesc.isEmpty { query = query.studyDescription(studyDesc) }

            switch levelStr {
            case "SERIES":
                let results = try await client.searchAllSeries(query: query)
                let count = results.results.count
                appendConsoleOutput("✅ QIDO-RS returned \(count) series\n\n")
                formatQIDOSeriesOutput(results.results, format: outputFormat)
                if count > 50 { appendConsoleOutput("... and \(count - 50) more (showing first 50)\n") }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-qido", command: commandPreview, exitCode: 0,
                             output: "\(count) series returned")

            case "INSTANCE":
                let results = try await client.searchAllInstances(query: query)
                let count = results.results.count
                appendConsoleOutput("✅ QIDO-RS returned \(count) instances\n\n")
                formatQIDOInstanceOutput(results.results, format: outputFormat)
                if count > 50 { appendConsoleOutput("... and \(count - 50) more (showing first 50)\n") }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-qido", command: commandPreview, exitCode: 0,
                             output: "\(count) instances returned")

            default: // STUDY
                let results = try await client.searchStudies(query: query)
                let count = results.results.count
                let total = results.totalCount.map { " (total: \($0))" } ?? ""
                appendConsoleOutput("✅ QIDO-RS returned \(count) studies\(total)\n\n")
                formatQIDOStudyOutput(results.results, format: outputFormat)
                if count > 50 { appendConsoleOutput("... and \(count - 50) more (showing first 50)\n") }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-qido", command: commandPreview, exitCode: 0,
                             output: "\(count) studies returned\(total)")
            }
        } catch {
            appendConsoleOutput("❌ QIDO-RS query failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            appendConsoleOutput("\n  💡 Hint: Verify the Base URL is correct and the DICOMweb server is reachable.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qido", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    // MARK: - QIDO-RS Output Formatters

    /// Formats QIDO-RS study results as a detailed dataset in the requested output format.
    private func formatQIDOStudyOutput(_ studies: [QIDOStudyResult], format: String) {
        let items = studies.prefix(50)
        switch format {
        case "json":
            appendConsoleOutput("[\n")
            for (i, study) in items.enumerated() {
                appendConsoleOutput("  {\n")
                appendConsoleOutput("    \"StudyInstanceUID\": \"\(study.studyInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"PatientName\": \"\(study.patientName ?? "")\",\n")
                appendConsoleOutput("    \"PatientID\": \"\(study.patientID ?? "")\",\n")
                appendConsoleOutput("    \"PatientBirthDate\": \"\(study.patientBirthDate ?? "")\",\n")
                appendConsoleOutput("    \"PatientSex\": \"\(study.patientSex ?? "")\",\n")
                appendConsoleOutput("    \"StudyDate\": \"\(study.studyDate ?? "")\",\n")
                appendConsoleOutput("    \"StudyTime\": \"\(study.studyTime ?? "")\",\n")
                appendConsoleOutput("    \"StudyDescription\": \"\(study.studyDescription ?? "")\",\n")
                appendConsoleOutput("    \"AccessionNumber\": \"\(study.accessionNumber ?? "")\",\n")
                appendConsoleOutput("    \"StudyID\": \"\(study.studyID ?? "")\",\n")
                appendConsoleOutput("    \"ReferringPhysicianName\": \"\(study.referringPhysicianName ?? "")\",\n")
                appendConsoleOutput("    \"ModalitiesInStudy\": [\(study.modalitiesInStudy.map { "\"\($0)\"" }.joined(separator: ", "))],\n")
                appendConsoleOutput("    \"NumberOfStudyRelatedSeries\": \(study.numberOfStudyRelatedSeries.map(String.init) ?? "null"),\n")
                appendConsoleOutput("    \"NumberOfStudyRelatedInstances\": \(study.numberOfStudyRelatedInstances.map(String.init) ?? "null")\n")
                appendConsoleOutput("  }\(i < items.count - 1 ? "," : "")\n")
            }
            appendConsoleOutput("]\n")
        case "csv":
            appendConsoleOutput("StudyInstanceUID,PatientName,PatientID,PatientBirthDate,PatientSex,StudyDate,StudyTime,StudyDescription,AccessionNumber,StudyID,ReferringPhysicianName,ModalitiesInStudy,NumSeries,NumInstances\n")
            for study in items {
                let fields: [String] = [
                    study.studyInstanceUID ?? "",
                    csvQuote(study.patientName ?? ""),
                    csvQuote(study.patientID ?? ""),
                    study.patientBirthDate ?? "",
                    study.patientSex ?? "",
                    study.studyDate ?? "",
                    study.studyTime ?? "",
                    csvQuote(study.studyDescription ?? ""),
                    csvQuote(study.accessionNumber ?? ""),
                    study.studyID ?? "",
                    csvQuote(study.referringPhysicianName ?? ""),
                    csvQuote(study.modalitiesInStudy.joined(separator: "/")),
                    study.numberOfStudyRelatedSeries.map(String.init) ?? "",
                    study.numberOfStudyRelatedInstances.map(String.init) ?? ""
                ]
                appendConsoleOutput(fields.joined(separator: ",") + "\n")
            }
        case "xml":
            appendConsoleOutput("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<QIDOResults level=\"STUDY\" count=\"\(items.count)\">\n")
            for study in items {
                appendConsoleOutput("  <Study>\n")
                appendConsoleOutput("    <StudyInstanceUID>\(xmlEscape(study.studyInstanceUID ?? ""))</StudyInstanceUID>\n")
                appendConsoleOutput("    <PatientName>\(xmlEscape(study.patientName ?? ""))</PatientName>\n")
                appendConsoleOutput("    <PatientID>\(xmlEscape(study.patientID ?? ""))</PatientID>\n")
                appendConsoleOutput("    <PatientBirthDate>\(study.patientBirthDate ?? "")</PatientBirthDate>\n")
                appendConsoleOutput("    <PatientSex>\(study.patientSex ?? "")</PatientSex>\n")
                appendConsoleOutput("    <StudyDate>\(study.studyDate ?? "")</StudyDate>\n")
                appendConsoleOutput("    <StudyTime>\(study.studyTime ?? "")</StudyTime>\n")
                appendConsoleOutput("    <StudyDescription>\(xmlEscape(study.studyDescription ?? ""))</StudyDescription>\n")
                appendConsoleOutput("    <AccessionNumber>\(xmlEscape(study.accessionNumber ?? ""))</AccessionNumber>\n")
                appendConsoleOutput("    <StudyID>\(study.studyID ?? "")</StudyID>\n")
                appendConsoleOutput("    <ReferringPhysicianName>\(xmlEscape(study.referringPhysicianName ?? ""))</ReferringPhysicianName>\n")
                appendConsoleOutput("    <ModalitiesInStudy>\(study.modalitiesInStudy.joined(separator: ","))</ModalitiesInStudy>\n")
                appendConsoleOutput("    <NumberOfStudyRelatedSeries>\(study.numberOfStudyRelatedSeries.map(String.init) ?? "")</NumberOfStudyRelatedSeries>\n")
                appendConsoleOutput("    <NumberOfStudyRelatedInstances>\(study.numberOfStudyRelatedInstances.map(String.init) ?? "")</NumberOfStudyRelatedInstances>\n")
                appendConsoleOutput("  </Study>\n")
            }
            appendConsoleOutput("</QIDOResults>\n")
        default: // text — detailed dataset
            for (i, study) in items.enumerated() {
                appendConsoleOutput("─── Study [\(i + 1)] ───────────────────────────────────────\n")
                appendConsoleOutput("  Study Instance UID .... \(study.studyInstanceUID ?? "N/A")\n")
                appendConsoleOutput("  Patient Name ......... \(study.patientName ?? "")\n")
                appendConsoleOutput("  Patient ID ........... \(study.patientID ?? "")\n")
                appendConsoleOutput("  Patient Birth Date ... \(study.patientBirthDate ?? "")\n")
                appendConsoleOutput("  Patient Sex .......... \(study.patientSex ?? "")\n")
                appendConsoleOutput("  Study Date ........... \(study.studyDate ?? "")\n")
                appendConsoleOutput("  Study Time ........... \(study.studyTime ?? "")\n")
                appendConsoleOutput("  Study Description .... \(study.studyDescription ?? "")\n")
                appendConsoleOutput("  Accession Number ..... \(study.accessionNumber ?? "")\n")
                appendConsoleOutput("  Study ID ............. \(study.studyID ?? "")\n")
                appendConsoleOutput("  Referring Physician .. \(study.referringPhysicianName ?? "")\n")
                let mods = study.modalitiesInStudy
                appendConsoleOutput("  Modalities ........... \(mods.isEmpty ? "" : mods.joined(separator: ", "))\n")
                appendConsoleOutput("  # Series ............. \(study.numberOfStudyRelatedSeries.map(String.init) ?? "—")\n")
                appendConsoleOutput("  # Instances .......... \(study.numberOfStudyRelatedInstances.map(String.init) ?? "—")\n")
                appendConsoleOutput("\n")
            }
        }
    }

    /// Formats QIDO-RS series results as a detailed dataset in the requested output format.
    private func formatQIDOSeriesOutput(_ seriesList: [QIDOSeriesResult], format: String) {
        let items = seriesList.prefix(50)
        switch format {
        case "json":
            appendConsoleOutput("[\n")
            for (i, s) in items.enumerated() {
                appendConsoleOutput("  {\n")
                appendConsoleOutput("    \"SeriesInstanceUID\": \"\(s.seriesInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"StudyInstanceUID\": \"\(s.studyInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"Modality\": \"\(s.modality ?? "")\",\n")
                appendConsoleOutput("    \"SeriesNumber\": \(s.seriesNumber.map(String.init) ?? "null"),\n")
                appendConsoleOutput("    \"SeriesDescription\": \"\(s.seriesDescription ?? "")\",\n")
                appendConsoleOutput("    \"BodyPartExamined\": \"\(s.bodyPartExamined ?? "")\",\n")
                appendConsoleOutput("    \"PerformedProcedureStepStartDate\": \"\(s.performedProcedureStepStartDate ?? "")\",\n")
                appendConsoleOutput("    \"NumberOfSeriesRelatedInstances\": \(s.numberOfSeriesRelatedInstances.map(String.init) ?? "null")\n")
                appendConsoleOutput("  }\(i < items.count - 1 ? "," : "")\n")
            }
            appendConsoleOutput("]\n")
        case "csv":
            appendConsoleOutput("SeriesInstanceUID,StudyInstanceUID,Modality,SeriesNumber,SeriesDescription,BodyPartExamined,ProcedureDate,NumInstances\n")
            for s in items {
                let fields: [String] = [
                    s.seriesInstanceUID ?? "",
                    s.studyInstanceUID ?? "",
                    s.modality ?? "",
                    s.seriesNumber.map(String.init) ?? "",
                    csvQuote(s.seriesDescription ?? ""),
                    s.bodyPartExamined ?? "",
                    s.performedProcedureStepStartDate ?? "",
                    s.numberOfSeriesRelatedInstances.map(String.init) ?? ""
                ]
                appendConsoleOutput(fields.joined(separator: ",") + "\n")
            }
        case "xml":
            appendConsoleOutput("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<QIDOResults level=\"SERIES\" count=\"\(items.count)\">\n")
            for s in items {
                appendConsoleOutput("  <Series>\n")
                appendConsoleOutput("    <SeriesInstanceUID>\(xmlEscape(s.seriesInstanceUID ?? ""))</SeriesInstanceUID>\n")
                appendConsoleOutput("    <StudyInstanceUID>\(xmlEscape(s.studyInstanceUID ?? ""))</StudyInstanceUID>\n")
                appendConsoleOutput("    <Modality>\(s.modality ?? "")</Modality>\n")
                appendConsoleOutput("    <SeriesNumber>\(s.seriesNumber.map(String.init) ?? "")</SeriesNumber>\n")
                appendConsoleOutput("    <SeriesDescription>\(xmlEscape(s.seriesDescription ?? ""))</SeriesDescription>\n")
                appendConsoleOutput("    <BodyPartExamined>\(s.bodyPartExamined ?? "")</BodyPartExamined>\n")
                appendConsoleOutput("    <PerformedProcedureStepStartDate>\(s.performedProcedureStepStartDate ?? "")</PerformedProcedureStepStartDate>\n")
                appendConsoleOutput("    <NumberOfSeriesRelatedInstances>\(s.numberOfSeriesRelatedInstances.map(String.init) ?? "")</NumberOfSeriesRelatedInstances>\n")
                appendConsoleOutput("  </Series>\n")
            }
            appendConsoleOutput("</QIDOResults>\n")
        default: // text — detailed dataset
            for (i, s) in items.enumerated() {
                appendConsoleOutput("─── Series [\(i + 1)] ──────────────────────────────────────\n")
                appendConsoleOutput("  Series Instance UID ... \(s.seriesInstanceUID ?? "N/A")\n")
                appendConsoleOutput("  Study Instance UID ... \(s.studyInstanceUID ?? "")\n")
                appendConsoleOutput("  Modality ............. \(s.modality ?? "")\n")
                appendConsoleOutput("  Series Number ........ \(s.seriesNumber.map(String.init) ?? "—")\n")
                appendConsoleOutput("  Series Description ... \(s.seriesDescription ?? "")\n")
                appendConsoleOutput("  Body Part Examined ... \(s.bodyPartExamined ?? "")\n")
                appendConsoleOutput("  Procedure Date ....... \(s.performedProcedureStepStartDate ?? "")\n")
                appendConsoleOutput("  # Instances .......... \(s.numberOfSeriesRelatedInstances.map(String.init) ?? "—")\n")
                appendConsoleOutput("\n")
            }
        }
    }

    /// Formats QIDO-RS instance results as a detailed dataset in the requested output format.
    private func formatQIDOInstanceOutput(_ instances: [QIDOInstanceResult], format: String) {
        let items = instances.prefix(50)
        switch format {
        case "json":
            appendConsoleOutput("[\n")
            for (i, inst) in items.enumerated() {
                appendConsoleOutput("  {\n")
                appendConsoleOutput("    \"SOPInstanceUID\": \"\(inst.sopInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"SOPClassUID\": \"\(inst.sopClassUID ?? "")\",\n")
                appendConsoleOutput("    \"SeriesInstanceUID\": \"\(inst.seriesInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"StudyInstanceUID\": \"\(inst.studyInstanceUID ?? "")\",\n")
                appendConsoleOutput("    \"InstanceNumber\": \(inst.instanceNumber.map(String.init) ?? "null"),\n")
                appendConsoleOutput("    \"NumberOfFrames\": \(inst.numberOfFrames.map(String.init) ?? "null"),\n")
                appendConsoleOutput("    \"Rows\": \(inst.rows.map(String.init) ?? "null"),\n")
                appendConsoleOutput("    \"Columns\": \(inst.columns.map(String.init) ?? "null")\n")
                appendConsoleOutput("  }\(i < items.count - 1 ? "," : "")\n")
            }
            appendConsoleOutput("]\n")
        case "csv":
            appendConsoleOutput("SOPInstanceUID,SOPClassUID,SeriesInstanceUID,StudyInstanceUID,InstanceNumber,NumberOfFrames,Rows,Columns\n")
            for inst in items {
                let fields: [String] = [
                    inst.sopInstanceUID ?? "",
                    inst.sopClassUID ?? "",
                    inst.seriesInstanceUID ?? "",
                    inst.studyInstanceUID ?? "",
                    inst.instanceNumber.map(String.init) ?? "",
                    inst.numberOfFrames.map(String.init) ?? "",
                    inst.rows.map(String.init) ?? "",
                    inst.columns.map(String.init) ?? ""
                ]
                appendConsoleOutput(fields.joined(separator: ",") + "\n")
            }
        case "xml":
            appendConsoleOutput("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<QIDOResults level=\"INSTANCE\" count=\"\(items.count)\">\n")
            for inst in items {
                appendConsoleOutput("  <Instance>\n")
                appendConsoleOutput("    <SOPInstanceUID>\(xmlEscape(inst.sopInstanceUID ?? ""))</SOPInstanceUID>\n")
                appendConsoleOutput("    <SOPClassUID>\(inst.sopClassUID ?? "")</SOPClassUID>\n")
                appendConsoleOutput("    <SeriesInstanceUID>\(xmlEscape(inst.seriesInstanceUID ?? ""))</SeriesInstanceUID>\n")
                appendConsoleOutput("    <StudyInstanceUID>\(xmlEscape(inst.studyInstanceUID ?? ""))</StudyInstanceUID>\n")
                appendConsoleOutput("    <InstanceNumber>\(inst.instanceNumber.map(String.init) ?? "")</InstanceNumber>\n")
                appendConsoleOutput("    <NumberOfFrames>\(inst.numberOfFrames.map(String.init) ?? "")</NumberOfFrames>\n")
                appendConsoleOutput("    <Rows>\(inst.rows.map(String.init) ?? "")</Rows>\n")
                appendConsoleOutput("    <Columns>\(inst.columns.map(String.init) ?? "")</Columns>\n")
                appendConsoleOutput("  </Instance>\n")
            }
            appendConsoleOutput("</QIDOResults>\n")
        default: // text — detailed dataset
            for (i, inst) in items.enumerated() {
                appendConsoleOutput("─── Instance [\(i + 1)] ────────────────────────────────────\n")
                appendConsoleOutput("  SOP Instance UID ..... \(inst.sopInstanceUID ?? "N/A")\n")
                appendConsoleOutput("  SOP Class UID ........ \(inst.sopClassUID ?? "")\n")
                appendConsoleOutput("  Series Instance UID .. \(inst.seriesInstanceUID ?? "")\n")
                appendConsoleOutput("  Study Instance UID ... \(inst.studyInstanceUID ?? "")\n")
                appendConsoleOutput("  Instance Number ...... \(inst.instanceNumber.map(String.init) ?? "—")\n")
                appendConsoleOutput("  # Frames ............. \(inst.numberOfFrames.map(String.init) ?? "—")\n")
                appendConsoleOutput("  Rows ................. \(inst.rows.map(String.init) ?? "—")\n")
                appendConsoleOutput("  Columns .............. \(inst.columns.map(String.init) ?? "—")\n")
                appendConsoleOutput("\n")
            }
        }
    }

    /// Executes a WADO retrieve (WADO-RS or WADO-URI) against a DICOMweb server.
    private func executeDicomWADO() async {
        let wadoProtocol = paramValue("protocol").lowercased()
        if wadoProtocol == "wado-uri" {
            await executeDicomWADOURI()
            return
        }
        // Default: WADO-RS path
        guard let profile = dicomwebProfileFromParams() else {
            appendConsoleOutput("Error: Base URL is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Base URL is required")
            return
        }

        let studyUID = paramValue("study-uid")
        let seriesUID = paramValue("series-uid")
        let instanceUID = paramValue("instance-uid")
        let mode = paramValue("mode").lowercased()
        let acceptType = paramValue("accept")
        let frameStr = paramValue("frame")
        let frameNumber = Int(frameStr) ?? 0

        guard !studyUID.isEmpty else {
            appendConsoleOutput("Error: Study Instance UID is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Study UID is required")
            return
        }

        appendConsoleOutput("Retrieving from \(profile.baseURL) ...\n")
        appendConsoleOutput("  Mode:       \(mode.isEmpty ? "study" : mode)\n")
        appendConsoleOutput("  Accept:     \(acceptType.isEmpty ? "application/dicom" : acceptType)\n")
        appendConsoleOutput("  Study UID:  \(studyUID)\n")
        if !seriesUID.isEmpty { appendConsoleOutput("  Series UID: \(seriesUID)\n") }
        if !instanceUID.isEmpty { appendConsoleOutput("  Instance UID: \(instanceUID)\n") }
        if frameNumber > 0 { appendConsoleOutput("  Frame:      \(frameNumber)\n") }
        appendConsoleOutput("\n")

        let outputDir = resolvedOutputDir(paramValue("output"))
        let hierarchical = paramValue("hierarchical") == "true"

        // Track retrieved files for viewer integration
        lastRetrievedFiles.removeAll()
        lastRetrievedOutputURL = securityScopedURLs["output"]

        do {
            let client = try DICOMwebClientFactory.makeClient(from: profile)

            switch mode {
            case "instance":
                guard !seriesUID.isEmpty, !instanceUID.isEmpty else {
                    appendConsoleOutput("Error: Series UID and Instance UID are required for instance-level retrieve.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                if frameNumber > 0 {
                    let frames = try await client.retrieveFrames(
                        studyUID: studyUID, seriesUID: seriesUID,
                        instanceUID: instanceUID, frames: [frameNumber]
                    )
                    guard let frameResult = frames.first else {
                        appendConsoleOutput("Error: No data returned for frame \(frameNumber).\n")
                        consoleStatus = .error
                        service.setConsoleStatus(.error)
                        return
                    }
                    let frameData = frameResult.data
                    appendConsoleOutput("✅ Retrieved frame \(frameNumber) (\(frameData.count) bytes)\n")
                    let savedPath = try writeReceivedDICOMFile(
                        data: frameData, sopInstanceUID: "\(instanceUID)_frame\(frameNumber)",
                        studyUID: studyUID, seriesUID: seriesUID,
                        outputDir: outputDir, hierarchical: hierarchical
                    )
                    appendConsoleOutput("  Saved to: \(savedPath)\n")
                    consoleStatus = .success
                    service.setConsoleStatus(.success)
                    addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                                 output: "Frame \(frameNumber), \(frameData.count) bytes → \(outputDir)")
                } else {
                    let data = try await client.retrieveInstance(
                        studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID
                    )
                    appendConsoleOutput("✅ Retrieved 1 instance (\(data.count) bytes)\n")
                    let savedPath = try writeReceivedDICOMFile(
                        data: data, sopInstanceUID: instanceUID,
                        studyUID: studyUID, seriesUID: seriesUID,
                        outputDir: outputDir, hierarchical: hierarchical
                    )
                    appendConsoleOutput("  Saved to: \(savedPath)\n")
                    appendConsoleOutput("\n")
                    wadoDisplayDataset(data, index: 1)
                    consoleStatus = .success
                    service.setConsoleStatus(.success)
                    addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                                 output: "1 instance, \(data.count) bytes → \(outputDir)")
                }

            case "series":
                guard !seriesUID.isEmpty else {
                    appendConsoleOutput("Error: Series UID is required for series-level retrieve.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                let result = try await client.retrieveSeries(
                    studyUID: studyUID, seriesUID: seriesUID
                )
                let count = result.instances.count
                let totalBytes = result.instances.reduce(0) { $0 + $1.count }
                appendConsoleOutput("✅ Retrieved \(count) instances (\(totalBytes) bytes total)\n")
                appendConsoleOutput("  Output directory: \(outputDir)\n\n")
                for (index, instanceData) in result.instances.enumerated() {
                    let sopUID = wadoExtractSOPInstanceUID(instanceData) ?? "instance_\(index + 1)"
                    do {
                        let savedPath = try writeReceivedDICOMFile(
                            data: instanceData, sopInstanceUID: sopUID,
                            studyUID: studyUID, seriesUID: seriesUID,
                            outputDir: outputDir, hierarchical: hierarchical
                        )
                        appendConsoleOutput("  [\(index + 1)] \(sopUID) → \(savedPath)\n")
                    } catch {
                        appendConsoleOutput("  [\(index + 1)] ⚠️ Save failed: \(error.localizedDescription)\n")
                    }
                    wadoDisplayDataset(instanceData, index: index + 1)
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                             output: "\(count) instances, \(totalBytes) bytes → \(outputDir)")

            case "rendered":
                guard !seriesUID.isEmpty, !instanceUID.isEmpty else {
                    appendConsoleOutput("Error: Series UID and Instance UID are required for rendered retrieve.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                let imageFormat: DICOMwebClient.RenderOptions.ImageFormat
                let fileExtension: String
                switch acceptType {
                case "image/png":
                    imageFormat = .png
                    fileExtension = "png"
                case "image/gif":
                    imageFormat = .gif
                    fileExtension = "gif"
                default:
                    imageFormat = .jpeg
                    fileExtension = "jpg"
                }
                let renderOptions = DICOMwebClient.RenderOptions(format: imageFormat)

                if frameNumber > 0 {
                    let frames = try await client.retrieveRenderedFrames(
                        studyUID: studyUID, seriesUID: seriesUID,
                        instanceUID: instanceUID, frames: [frameNumber],
                        options: renderOptions
                    )
                    guard let data = frames.first else {
                        appendConsoleOutput("Error: No data returned for rendered frame \(frameNumber).\n")
                        consoleStatus = .error
                        service.setConsoleStatus(.error)
                        return
                    }
                    appendConsoleOutput("✅ Retrieved rendered frame \(frameNumber) (\(data.count) bytes, image/\(fileExtension))\n")
                    let filename = "rendered_\(instanceUID)_frame\(frameNumber).\(fileExtension)"
                    let savedPath = try writeOutputFile(data: data, filename: filename, outputDir: outputDir)
                    lastRetrievedFiles.append(savedPath)
                    appendConsoleOutput("  Saved to: \(savedPath)\n")
                    consoleStatus = .success
                    service.setConsoleStatus(.success)
                    addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                                 output: "Rendered frame \(frameNumber), \(data.count) bytes → \(savedPath)")
                } else {
                    let data = try await client.retrieveRenderedInstance(
                        studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID,
                        options: renderOptions
                    )
                    appendConsoleOutput("✅ Retrieved rendered image (\(data.count) bytes, image/\(fileExtension))\n")
                    let filename = "rendered_\(instanceUID).\(fileExtension)"
                    let savedPath = try writeOutputFile(data: data, filename: filename, outputDir: outputDir)
                    lastRetrievedFiles.append(savedPath)
                    appendConsoleOutput("  Saved to: \(savedPath)\n")
                    consoleStatus = .success
                    service.setConsoleStatus(.success)
                    addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                                 output: "Rendered image, \(data.count) bytes → \(savedPath)")
                }

            default: // study-level
                let result = try await client.retrieveStudy(studyUID: studyUID)
                let count = result.instances.count
                let totalBytes = result.instances.reduce(0) { $0 + $1.count }
                appendConsoleOutput("✅ Retrieved \(count) instances (\(totalBytes) bytes total)\n")
                appendConsoleOutput("  Output directory: \(outputDir)\n\n")
                for (index, instanceData) in result.instances.enumerated() {
                    let sopUID = wadoExtractSOPInstanceUID(instanceData) ?? "instance_\(index + 1)"
                    do {
                        let savedPath = try writeReceivedDICOMFile(
                            data: instanceData, sopInstanceUID: sopUID,
                            studyUID: studyUID,
                            outputDir: outputDir, hierarchical: hierarchical
                        )
                        appendConsoleOutput("  [\(index + 1)] \(sopUID) → \(savedPath)\n")
                    } catch {
                        appendConsoleOutput("  [\(index + 1)] ⚠️ Save failed: \(error.localizedDescription)\n")
                    }
                    wadoDisplayDataset(instanceData, index: index + 1)
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                             output: "\(count) instances, \(totalBytes) bytes → \(outputDir)")
            }
        } catch {
            appendConsoleOutput("❌ WADO-RS retrieve failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            appendConsoleOutput("\n  💡 Hint: Verify the Study UID exists on the server and the Base URL is correct.\n")
            if mode == "rendered" {
                appendConsoleOutput("  💡 Hint: Not all servers support the /rendered endpoint. Try 'instance' mode instead.\n")
            }
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Executes a WADO-URI retrieve against a legacy DICOMweb/WADO server.
    ///
    /// WADO-URI uses query parameters (`?requestType=WADO&studyUID=...&seriesUID=...&objectUID=...`)
    /// and retrieves a single DICOM object per request. Common for dcm4chee2 and older PACS.
    ///
    /// Reference: DICOM PS3.18 §8 — WADO by means of URI
    private func executeDicomWADOURI() async {
        guard let profile = dicomwebProfileFromParams() else {
            appendConsoleOutput("Error: Base URL is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Base URL is required")
            return
        }

        let studyUID = paramValue("study-uid")
        let seriesUID = paramValue("series-uid")
        let instanceUID = paramValue("instance-uid")
        let acceptType = paramValue("accept")
        let frameStr = paramValue("frame")
        let frameNumber = Int(frameStr) ?? 0

        guard !studyUID.isEmpty else {
            appendConsoleOutput("Error: Study Instance UID is required for WADO-URI.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Study UID is required")
            return
        }
        guard !seriesUID.isEmpty else {
            appendConsoleOutput("Error: Series Instance UID is required for WADO-URI.\n")
            appendConsoleOutput("  💡 WADO-URI requires Study UID, Series UID, and SOP Instance UID.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Series UID is required for WADO-URI")
            return
        }
        guard !instanceUID.isEmpty else {
            appendConsoleOutput("Error: SOP Instance UID is required for WADO-URI.\n")
            appendConsoleOutput("  💡 WADO-URI requires Study UID, Series UID, and SOP Instance UID.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "SOP Instance UID is required for WADO-URI")
            return
        }

        appendConsoleOutput("Retrieving from \(profile.baseURL) via WADO-URI ...\n")
        appendConsoleOutput("  Protocol:     WADO-URI (PS3.18 §8)\n")
        appendConsoleOutput("  Accept:       \(acceptType.isEmpty ? "application/dicom" : acceptType)\n")
        appendConsoleOutput("  Study UID:    \(studyUID)\n")
        appendConsoleOutput("  Series UID:   \(seriesUID)\n")
        appendConsoleOutput("  Instance UID: \(instanceUID)\n")
        if frameNumber > 0 { appendConsoleOutput("  Frame:        \(frameNumber)\n") }
        appendConsoleOutput("\n")

        let outputDir = resolvedOutputDir(paramValue("output"))
        let hierarchical = paramValue("hierarchical") == "true"

        lastRetrievedFiles.removeAll()
        lastRetrievedOutputURL = securityScopedURLs["output"]

        do {
            let client = try DICOMwebClientFactory.makeWADOURIClient(from: profile)

            // Map accept type parameter to WADOURIClient.ContentType
            let contentType: WADOURIClient.ContentType
            switch acceptType {
            case "image/jpeg":  contentType = .jpeg
            case "image/png":   contentType = .png
            case "image/gif":   contentType = .gif
            default:            contentType = .dicom
            }

            let result = try await client.retrieve(
                studyUID: studyUID,
                seriesUID: seriesUID,
                objectUID: instanceUID,
                contentType: contentType,
                frameNumber: frameNumber > 0 ? frameNumber : nil
            )

            let data = result.data
            appendConsoleOutput("✅ WADO-URI retrieve successful (\(data.count) bytes)\n")

            if contentType == .dicom {
                let sopUID = wadoExtractSOPInstanceUID(data) ?? instanceUID
                let savedPath = try writeReceivedDICOMFile(
                    data: data, sopInstanceUID: sopUID,
                    studyUID: studyUID, seriesUID: seriesUID,
                    outputDir: outputDir, hierarchical: hierarchical
                )
                appendConsoleOutput("  Saved to: \(savedPath)\n\n")
                wadoDisplayDataset(data, index: 1)
            } else {
                let ext: String
                switch contentType {
                case .jpeg: ext = "jpg"
                case .png:  ext = "png"
                case .gif:  ext = "gif"
                default:    ext = "bin"
                }
                let frameSuffix = frameNumber > 0 ? "_frame\(frameNumber)" : ""
                let filename = "wado_\(instanceUID)\(frameSuffix).\(ext)"
                let savedPath = try writeOutputFile(data: data, filename: filename, outputDir: outputDir)
                lastRetrievedFiles.append(savedPath)
                appendConsoleOutput("  Saved to: \(savedPath)\n")
            }

            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 0,
                         output: "WADO-URI: 1 object, \(data.count) bytes → \(outputDir)")
        } catch {
            appendConsoleOutput("❌ WADO-URI retrieve failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            appendConsoleOutput("\n  💡 Hint: Verify all three UIDs (Study, Series, SOP Instance) exist on the server.\n")
            appendConsoleOutput("  💡 Hint: Ensure the Base URL points to the WADO endpoint (e.g. http://server:8080/wado).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Attempts to extract the SOP Instance UID from raw DICOM instance data.
    private func wadoExtractSOPInstanceUID(_ data: Data) -> String? {
        guard let file = try? DICOMFile.read(from: data, force: true) else { return nil }
        return file.sopInstanceUID
    }

    /// Displays a detailed DICOM dataset summary for a retrieved instance.
    private func wadoDisplayDataset(_ data: Data, index: Int) {
        guard let file = try? DICOMFile.read(from: data, force: true) else { return }
        let ds = file.dataSet
        appendConsoleOutput("─── Instance [\(index)] ────────────────────────────────────\n")
        appendConsoleOutput("  SOP Instance UID ..... \(file.sopInstanceUID ?? "N/A")\n")
        appendConsoleOutput("  SOP Class UID ........ \(file.sopClassUID ?? "N/A")\n")
        appendConsoleOutput("  Transfer Syntax ...... \(file.transferSyntaxUID ?? "N/A")\n")
        appendConsoleOutput("  Patient Name ......... \(ds.string(for: .patientName) ?? "N/A")\n")
        appendConsoleOutput("  Patient ID ........... \(ds.string(for: .patientID) ?? "N/A")\n")
        appendConsoleOutput("  Study Instance UID ... \(ds.string(for: .studyInstanceUID) ?? "N/A")\n")
        appendConsoleOutput("  Series Instance UID .. \(ds.string(for: .seriesInstanceUID) ?? "N/A")\n")
        appendConsoleOutput("  Modality ............. \(ds.string(for: .modality) ?? "N/A")\n")
        appendConsoleOutput("  Study Date ........... \(ds.string(for: .studyDate) ?? "N/A")\n")
        appendConsoleOutput("  Study Description .... \(ds.string(for: .studyDescription) ?? "N/A")\n")
        appendConsoleOutput("  Series Number ........ \(ds.string(for: .seriesNumber) ?? "N/A")\n")
        appendConsoleOutput("  Instance Number ...... \(ds.string(for: .instanceNumber) ?? "N/A")\n")
        appendConsoleOutput("  Rows ................. \(ds.uint16(for: .rows).map(String.init) ?? "N/A")\n")
        appendConsoleOutput("  Columns .............. \(ds.uint16(for: .columns).map(String.init) ?? "N/A")\n")
        appendConsoleOutput("  Bits Allocated ....... \(ds.uint16(for: .bitsAllocated).map(String.init) ?? "N/A")\n")
        appendConsoleOutput("  Bits Stored .......... \(ds.uint16(for: .bitsStored).map(String.init) ?? "N/A")\n")
        appendConsoleOutput("  Photometric Interp ... \(ds.string(for: .photometricInterpretation) ?? "N/A")\n")
        appendConsoleOutput("\n")
    }

    /// Executes a STOW-RS upload against a DICOMweb server.
    private func executeDicomSTOW() async {
        guard let profile = dicomwebProfileFromParams() else {
            appendConsoleOutput("Error: Base URL is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-stow", command: commandPreview, exitCode: 1, output: "Base URL is required")
            return
        }

        let filesPath = paramValue("files")
        let studyUID = paramValue("study-uid").isEmpty ? nil : paramValue("study-uid")
        let dryRun = paramValue("dry-run") == "true"
        let validateFlag = paramValue("validate") == "true"
        let batchSize = Int(paramValue("batch-size")) ?? 10
        let recursive = paramValue("recursive") == "true"
        let continueOnError = paramValue("continue-on-error") == "true"

        // ── Collect DICOM file paths ────────────────────────────────
        // Merge drag-and-drop entries with the text-field path, resolve
        // directories into individual .dcm files, and obtain
        // security-scoped access for sandboxed reads.

        var resolvedFiles: [(path: String, url: URL)] = []

        // Start security-scoped access if we have one for "files"
        let scopedURL = securityScopedURLs["files"]
        let accessing = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessing { scopedURL?.stopAccessingSecurityScopedResource() }
        }

        // Helper: collect DICOM files from a single path (file or directory)
        func collectDICOMFiles(from basePath: String) {
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: basePath, isDirectory: &isDir) else { return }

            if isDir.boolValue {
                // Directory — enumerate contents
                let enumerator: FileManager.DirectoryEnumerator?
                if recursive {
                    enumerator = fm.enumerator(atPath: basePath)
                } else {
                    // Non-recursive: just immediate children via shallow enumeration
                    enumerator = fm.enumerator(at: URL(fileURLWithPath: basePath),
                                               includingPropertiesForKeys: [.isRegularFileKey],
                                               options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
                        .map { ShallowEnumeratorWrapper($0) }
                }
                if let enumerator = enumerator {
                    if recursive {
                        // String-based enumerator
                        while let relativePath = enumerator.nextObject() as? String {
                            let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
                            if isDICOMCandidate(fullPath) {
                                resolvedFiles.append((path: fullPath, url: URL(fileURLWithPath: fullPath)))
                            }
                        }
                    }
                } else {
                    // Fallback: try shallow contents
                    if let contents = try? fm.contentsOfDirectory(atPath: basePath) {
                        for name in contents where !name.hasPrefix(".") {
                            let fullPath = (basePath as NSString).appendingPathComponent(name)
                            if isDICOMCandidate(fullPath) {
                                resolvedFiles.append((path: fullPath, url: URL(fileURLWithPath: fullPath)))
                            }
                        }
                    }
                }
                // For non-recursive URL enumerator, handled via contentsOfDirectory fallback above
                if !recursive {
                    if let contents = try? fm.contentsOfDirectory(atPath: basePath) {
                        for name in contents where !name.hasPrefix(".") {
                            let fullPath = (basePath as NSString).appendingPathComponent(name)
                            if isDICOMCandidate(fullPath),
                               !resolvedFiles.contains(where: { $0.path == fullPath }) {
                                resolvedFiles.append((path: fullPath, url: URL(fileURLWithPath: fullPath)))
                            }
                        }
                    }
                }
            } else {
                // Single file
                resolvedFiles.append((path: basePath, url: URL(fileURLWithPath: basePath)))
            }
        }

        // Collect from inputFiles (drag-and-drop)
        for entry in inputFiles {
            collectDICOMFiles(from: entry.path)
        }

        // Collect from text field path(s)
        if !filesPath.isEmpty {
            let paths = filesPath.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for path in paths {
                if !resolvedFiles.contains(where: { $0.path == path }) {
                    collectDICOMFiles(from: path)
                }
            }
        }

        guard !resolvedFiles.isEmpty else {
            appendConsoleOutput("Error: No DICOM files found. Verify the path exists and contains DICOM files.\n")
            if filesPath.isEmpty {
                appendConsoleOutput("  💡 Hint: Enter a file or directory path, or drag and drop DICOM files.\n")
            } else {
                appendConsoleOutput("  💡 Hint: The path '\(filesPath)' may be a directory. Enable 'Recursive Scan' to search subdirectories.\n")
            }
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-stow", command: commandPreview, exitCode: 1, output: "No DICOM files found")
            return
        }

        appendConsoleOutput("Uploading to \(profile.baseURL) ...\n")
        appendConsoleOutput("  Files:      \(resolvedFiles.count)\n")
        if let uid = studyUID { appendConsoleOutput("  Study UID:  \(uid)\n") }
        if dryRun { appendConsoleOutput("  Mode:       DRY RUN (no actual upload)\n") }
        appendConsoleOutput("  Batch size: \(batchSize)\n")
        if validateFlag { appendConsoleOutput("  Validate:   yes\n") }
        appendConsoleOutput("\n")

        if dryRun {
            for (i, file) in resolvedFiles.enumerated() {
                appendConsoleOutput("  [\(i + 1)] \(file.url.lastPathComponent)\n")
            }
            appendConsoleOutput("\n✅ Dry run complete — \(resolvedFiles.count) files would be uploaded.\n")
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-stow", command: commandPreview, exitCode: 0,
                         output: "Dry run: \(resolvedFiles.count) files")
            return
        }

        do {
            let client = try DICOMwebClientFactory.makeClient(from: profile)

            var totalStored = 0
            var totalFailed = 0

            // Upload in batches
            let batches = stride(from: 0, to: resolvedFiles.count, by: batchSize).map {
                Array(resolvedFiles[$0..<min($0 + batchSize, resolvedFiles.count)])
            }

            for (batchIndex, batch) in batches.enumerated() {
                if batches.count > 1 {
                    appendConsoleOutput("Batch \(batchIndex + 1)/\(batches.count) (\(batch.count) files)...\n")
                }

                var batchInstances: [Data] = []
                for file in batch {
                    do {
                        let data = try Data(contentsOf: file.url)
                        batchInstances.append(data)
                    } catch {
                        appendConsoleOutput("  ⚠️ Cannot read \(file.url.lastPathComponent): \(error.localizedDescription)\n")
                        totalFailed += 1
                        if !continueOnError {
                            appendConsoleOutput("❌ Aborting (continue-on-error is off)\n")
                            consoleStatus = .error
                            service.setConsoleStatus(.error)
                            addToHistory(toolName: "dicom-stow", command: commandPreview, exitCode: 1,
                                         output: error.localizedDescription)
                            return
                        }
                    }
                }

                guard !batchInstances.isEmpty else { continue }

                let response = try await client.storeInstances(instances: batchInstances, studyUID: studyUID)
                let stored = response.storedInstances.count
                let failed = response.failedInstances.count
                totalStored += stored
                totalFailed += failed

                if batches.count > 1 {
                    appendConsoleOutput("  Stored: \(stored), Failed: \(failed)\n")
                }

                for failure in response.failedInstances {
                    let reason = failure.failureDescription ?? (failure.failureReason.map { "code \($0)" } ?? "unknown reason")
                    appendConsoleOutput("  ❌ \(failure.sopInstanceUID ?? "unknown"): \(reason)\n")
                }
            }

            appendConsoleOutput("\n✅ STOW-RS complete\n")
            appendConsoleOutput("  Stored:  \(totalStored)\n")
            if totalFailed > 0 {
                appendConsoleOutput("  Failed:  \(totalFailed)\n")
            }
            consoleStatus = totalFailed > 0 ? .error : .success
            service.setConsoleStatus(totalFailed > 0 ? .error : .success)
            addToHistory(toolName: "dicom-stow", command: commandPreview,
                         exitCode: totalFailed > 0 ? 1 : 0,
                         output: "\(totalStored) stored, \(totalFailed) failed")
        } catch {
            appendConsoleOutput("❌ STOW-RS upload failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            appendConsoleOutput("\n  💡 Hint: Verify the file paths are valid DICOM files and the Base URL is correct.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-stow", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Checks whether a file path looks like a DICOM candidate (by extension or lack thereof).
    private func isDICOMCandidate(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else { return false }
        let lower = (path as NSString).lastPathComponent.lowercased()
        // Accept .dcm, .dicom, .dic, or files without an extension (common in DICOM)
        return lower.hasSuffix(".dcm") || lower.hasSuffix(".dicom") || lower.hasSuffix(".dic") || !lower.contains(".")
    }

    /// Minimal wrapper to bridge URL-based directory enumeration into the string pattern.
    private class ShallowEnumeratorWrapper: FileManager.DirectoryEnumerator {
        private let inner: FileManager.DirectoryEnumerator
        init(_ inner: FileManager.DirectoryEnumerator) { self.inner = inner }
        override func nextObject() -> Any? { inner.nextObject() }
    }

    /// Executes a UPS-RS operation against a DICOMweb server.
    private func executeDicomUPS() async {
        guard let profile = dicomwebProfileFromParams() else {
            appendConsoleOutput("Error: Base URL is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 1, output: "Base URL is required")
            return
        }

        let operation = paramValue("operation").lowercased()
        let workitemUID = paramValue("workitem-uid")

        appendConsoleOutput("UPS-RS \(operation.isEmpty ? "search" : operation) on \(profile.baseURL) ...\n\n")

        do {
            let client = try DICOMwebClientFactory.makeClient(from: profile)

            switch operation {
            case "get":
                guard !workitemUID.isEmpty else {
                    appendConsoleOutput("Error: Workitem UID is required for get operation.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                let workitem = try await client.retrieveWorkitem(uid: workitemUID)
                appendConsoleOutput("✅ Retrieved workitem \(workitemUID)\n")
                appendConsoleOutput("  Attributes: \(workitem.count)\n\n")
                // Display all attributes with tag lookup
                for (tag, value) in workitem.sorted(by: { $0.key < $1.key }) {
                    let tagName = EducationalHelpers.dicomTagName(for: tag)
                    if let element = value as? [String: Any],
                       let vr = element["vr"] as? String {
                        let valueStr: String
                        if let values = element["Value"] as? [Any] {
                            valueStr = values.map { item -> String in
                                if let dict = item as? [String: Any],
                                   let alpha = dict["Alphabetic"] as? String {
                                    return alpha
                                }
                                return "\(item)"
                            }.joined(separator: ", ")
                        } else {
                            valueStr = "(empty)"
                        }
                        appendConsoleOutput("  (\(EducationalHelpers.formatTag(tag))) \(tagName) [\(vr)]: \(valueStr)\n")
                    } else {
                        appendConsoleOutput("  (\(EducationalHelpers.formatTag(tag))) \(tagName): \(value)\n")
                    }
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "Workitem retrieved")

            case "create":
                let stepLabel = paramValue("create-label")
                guard !stepLabel.isEmpty else {
                    appendConsoleOutput("Error: Procedure Step Label is required for create operation.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }

                let uid = workitemUID.isEmpty ? generateDICOMUID() : workitemUID
                appendConsoleOutput("Creating workitem \(uid)...\n")
                appendConsoleOutput("  Label: \(stepLabel)\n")

                let builder = WorkitemBuilder(workitemUID: uid)
                    .setState(.scheduled)
                    .setProcedureStepLabel(stepLabel)

                let priorityStr = paramValue("create-priority")
                if !priorityStr.isEmpty {
                    switch priorityStr.uppercased() {
                    case "STAT": builder.setPriority(.stat)
                    case "HIGH": builder.setPriority(.high)
                    case "MEDIUM": builder.setPriority(.medium)
                    case "LOW": builder.setPriority(.low)
                    default: break
                    }
                    appendConsoleOutput("  Priority: \(priorityStr)\n")
                }

                let patName = paramValue("create-patient-name")
                if !patName.isEmpty {
                    builder.setPatientName(patName)
                    appendConsoleOutput("  Patient Name: \(patName)\n")
                }

                let patID = paramValue("create-patient-id")
                if !patID.isEmpty {
                    builder.setPatientID(patID)
                    appendConsoleOutput("  Patient ID: \(patID)\n")
                }

                let startStr = paramValue("create-scheduled-start")
                if !startStr.isEmpty, let startDate = parseISO8601(startStr) {
                    builder.setScheduledStartDateTime(startDate)
                    appendConsoleOutput("  Scheduled Start: \(startStr)\n")
                }

                let studyRef = paramValue("create-study-uid")
                if !studyRef.isEmpty {
                    builder.setStudyInstanceUID(studyRef)
                    appendConsoleOutput("  Study UID: \(studyRef) (→ Input Information + Referenced Request)\n")
                }

                let accession = paramValue("create-accession")
                if !accession.isEmpty {
                    builder.setAccessionNumber(accession)
                    appendConsoleOutput("  Accession: \(accession)\n")
                }

                let station = paramValue("create-station-name")
                if !station.isEmpty {
                    builder.setScheduledStationNameCodes([
                        CodedEntry(codeValue: station, codingSchemeDesignator: "L", codeMeaning: station)
                    ])
                    appendConsoleOutput("  Station: \(station)\n")
                }

                let performer = paramValue("create-performer")
                if !performer.isEmpty {
                    builder.addScheduledHumanPerformer(
                        HumanPerformer(performerName: performer)
                    )
                    appendConsoleOutput("  Performer: \(performer)\n")
                }

                let cmt = paramValue("create-comments")
                if !cmt.isEmpty {
                    builder.setComments(cmt)
                }

                appendConsoleOutput("\n")

                let workitem = try builder.build()

                // Log the equivalent curl command for debugging
                do {
                    let createJSON = workitem.toDICOMJSONForCreate()
                    let createURL: URL
                    if uid.isEmpty {
                        createURL = client.urlBuilder.workitemsURL
                    } else {
                        createURL = client.urlBuilder.createWorkitemURL(workitemUID: uid)
                    }
                    if let jsonData = try? JSONSerialization.data(
                        withJSONObject: createJSON,
                        options: [.prettyPrinted, .sortedKeys]
                    ),
                       let jsonStr = String(data: jsonData, encoding: .utf8) {
                        let escapedJSON = jsonStr.replacingOccurrences(of: "'", with: "'\\''")
                        appendConsoleOutput("─── curl equivalent ───\n")
                        appendConsoleOutput("curl -X POST \\\n")
                        appendConsoleOutput("  '\(createURL.absoluteString)' \\\n")
                        appendConsoleOutput("  -H 'Content-Type: application/dicom+json' \\\n")
                        appendConsoleOutput("  -H 'Accept: application/dicom+json' \\\n")
                        appendConsoleOutput("  -d '\(escapedJSON)'\n")
                        appendConsoleOutput("───────────────────────\n\n")
                    }
                }

                let response = try await client.createWorkitem(workitem)

                appendConsoleOutput("✅ Workitem created successfully\n")
                appendConsoleOutput("  UID: \(response.workitemUID)\n")
                if let url = response.retrieveURL {
                    appendConsoleOutput("  Retrieve URL: \(url)\n")
                }
                if !response.warnings.isEmpty {
                    for w in response.warnings {
                        appendConsoleOutput("  ⚠️ \(w)\n")
                    }
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "Workitem created: \(response.workitemUID)")

            case "change-state":
                guard !workitemUID.isEmpty else {
                    appendConsoleOutput("Error: Workitem UID is required for change-state operation.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                let stateStr = paramValue("state")
                let rawState: String
                switch stateStr.uppercased() {
                case "COMPLETED": rawState = "COMPLETED"
                case "CANCELED": rawState = "CANCELED"
                default: rawState = "IN PROGRESS"
                }

                // Per PS3.4 CC.2 UPS State Machine:
                //   SCHEDULED → IN PROGRESS  : client supplies a new Transaction UID
                //   IN PROGRESS → COMPLETED  : client MUST supply the same Transaction UID
                //   IN PROGRESS → CANCELED   : client MUST supply the same Transaction UID
                let userTxUID = paramValue("transaction-uid")
                let txUID: String
                if rawState == "IN PROGRESS" {
                    // New transition — generate a fresh Transaction UID
                    txUID = userTxUID.isEmpty ? generateDICOMUID() : userTxUID
                } else {
                    // COMPLETED / CANCELED — must reuse the Transaction UID from IN PROGRESS
                    guard !userTxUID.isEmpty else {
                        appendConsoleOutput("Error: Transaction UID is required for \(rawState) transition.\n")
                        appendConsoleOutput("  💡 Use the Transaction UID returned when the workitem was moved to IN PROGRESS.\n")
                        consoleStatus = .error
                        service.setConsoleStatus(.error)
                        return
                    }
                    txUID = userTxUID
                }

                appendConsoleOutput("Changing state of \(workitemUID) to \(rawState) ...\n")
                appendConsoleOutput("  Transaction UID: \(txUID)\n")

                // Per PS3.18 §11.6: PUT /workitems/{uid}/state
                let stateChangeBody: [String: Any] = [
                    "00741000": ["vr": "CS", "Value": [rawState]],
                    "00081195": ["vr": "UI", "Value": [txUID]]
                ]
                let bodyData = try JSONSerialization.data(withJSONObject: stateChangeBody)

                let stateURL = client.urlBuilder.workitemStateURL(workitemUID: workitemUID)
                appendConsoleOutput("  URL: \(stateURL.absoluteString)\n\n")

                let stateRequest = HTTPClient.Request(
                    url: stateURL,
                    method: .put,
                    headers: [
                        "Content-Type": "application/dicom+json",
                        "Accept": "application/dicom+json"
                    ],
                    body: bodyData
                )

                do {
                    let response = try await client.httpClient.execute(stateRequest)
                    appendConsoleOutput("✅ State changed to \(rawState)\n")

                    // For IN PROGRESS, parse the response to capture the Transaction UID
                    if rawState == "IN PROGRESS" {
                        appendConsoleOutput("\n  ⚠️ Save this Transaction UID — you will need it for COMPLETED or CANCELED transitions:\n")
                        appendConsoleOutput("  📋 Transaction UID: \(txUID)\n")
                    }

                    // Show response body if present
                    if !response.body.isEmpty,
                       let responseStr = String(data: response.body, encoding: .utf8),
                       !responseStr.isEmpty {
                        appendConsoleOutput("  Response: \(responseStr)\n")
                    }
                } catch let error as DICOMwebError {
                    if case .httpError(let statusCode, let message) = error {
                        appendConsoleOutput("❌ State change failed (HTTP \(statusCode))\n")
                        if let msg = message {
                            appendConsoleOutput("  Server: \(msg)\n")
                        }
                        switch statusCode {
                        case 400:
                            appendConsoleOutput("  💡 Bad Request — the request body may be malformed or missing required attributes.\n")
                        case 404:
                            appendConsoleOutput("  💡 Workitem \(workitemUID) not found on the server.\n")
                        case 409:
                            appendConsoleOutput("  💡 State transition conflict — check:\n")
                            appendConsoleOutput("     • Current state allows transition to \(rawState)?\n")
                            appendConsoleOutput("     • Transaction UID matches the one from IN PROGRESS?\n")
                            appendConsoleOutput("     • Workitem is not locked by another performer?\n")
                        default:
                            break
                        }
                    } else {
                        appendConsoleOutput("❌ State change failed: \(error.localizedDescription)\n")
                    }
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 1,
                                 output: "State change to \(rawState) failed")
                    return
                }

                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "State changed to \(rawState)")

            case "subscribe":
                guard !workitemUID.isEmpty else {
                    appendConsoleOutput("Error: Workitem UID is required for subscribe operation.\n")
                    consoleStatus = .error
                    service.setConsoleStatus(.error)
                    return
                }
                appendConsoleOutput("Subscribing to workitem \(workitemUID) ...\n")
                try await client.subscribeToWorkitem(
                    workitemUID: workitemUID,
                    aeTitle: "DICOM_STUDIO"
                )
                appendConsoleOutput("✅ Subscription created\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "Subscribed to \(workitemUID)")

            default: // search
                let results = try await client.searchWorkitems(query: UPSQuery())
                let count = results.workitems.count
                appendConsoleOutput("✅ UPS-RS returned \(count) workitems\n\n")
                for (i, item) in results.workitems.prefix(50).enumerated() {
                    appendConsoleOutput("─── [\(i + 1)] \(item.workitemUID) ───\n")
                    if let state = item.state { appendConsoleOutput("  State:      \(state.rawValue)\n") }
                    if let pri = item.priority { appendConsoleOutput("  Priority:   \(pri.rawValue)\n") }
                    if let step = item.procedureStepLabel { appendConsoleOutput("  Label:      \(step)\n") }
                    if let wl = item.worklistLabel { appendConsoleOutput("  Worklist:   \(wl)\n") }
                    if let stepID = item.scheduledProcedureStepID { appendConsoleOutput("  Step ID:    \(stepID)\n") }
                    if let name = item.patientName { appendConsoleOutput("  Patient:    \(name)\n") }
                    if let pid = item.patientID { appendConsoleOutput("  Patient ID: \(pid)\n") }
                    if let dob = item.patientBirthDate { appendConsoleOutput("  Birth Date: \(dob)\n") }
                    if let sex = item.patientSex { appendConsoleOutput("  Sex:        \(sex)\n") }
                    if let start = item.scheduledStartDateTime { appendConsoleOutput("  Start:      \(start)\n") }
                    if let exp = item.expectedCompletionDateTime { appendConsoleOutput("  Expected:   \(exp)\n") }
                    if let mod = item.modificationDateTime { appendConsoleOutput("  Modified:   \(mod)\n") }
                    if let study = item.studyInstanceUID { appendConsoleOutput("  Study UID:  \(study)\n") }
                    if let acc = item.accessionNumber { appendConsoleOutput("  Accession:  \(acc)\n") }
                    if let ref = item.referringPhysicianName { appendConsoleOutput("  Ref. Phys:  \(ref)\n") }
                    if let tx = item.transactionUID { appendConsoleOutput("  Tx UID:     \(tx)\n") }
                    if let prog = item.progressPercentage { appendConsoleOutput("  Progress:   \(prog)%\n") }
                    if let desc = item.progressDescription { appendConsoleOutput("  Prog Desc:  \(desc)\n") }
                    appendConsoleOutput("\n")
                }
                if count > 50 { appendConsoleOutput("... and \(count - 50) more\n") }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "\(count) workitems returned")
            }
        } catch {
            appendConsoleOutput("❌ UPS-RS \(operation) failed\n")
            appendConsoleOutput("  Error: \(error.localizedDescription)\n")
            appendConsoleOutput("\n  💡 Hint: Verify the Base URL is correct and the server supports UPS-RS.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
        }
    }

    /// Generates a DICOM UID for workitem creation.
    private func generateDICOMUID() -> String {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000000)
        let random = UInt32.random(in: 1...999999)
        return "1.2.826.0.1.3680043.8.498.\(timestamp).\(random)"
    }

    /// Parses an ISO 8601 date string into a Date.
    private func parseISO8601(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) { return date }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            fallback.dateFormat = fmt
            if let date = fallback.date(from: value) { return date }
        }
        return nil
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
        let outputFormat = paramValue("output-format").lowercased()

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
        let rawPatientName = paramValue("patient-name")
        let patientName = rawPatientName.isEmpty ? "" : (rawPatientName.hasSuffix("*") ? rawPatientName : rawPatientName + "*")
        let studyDate = paramValue("study-date")
        let modality = paramValue("modality")
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
            queryKeys = queryKeys
                .requestAccessionNumber()
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
                            studyDate: studyDate,
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
                    studyDate: studyDate,
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
                let collected: [(result: GenericQueryResult, parent: GenericQueryResult?)] = allResults.enumerated().map { (index, result) in
                    let parent = (level == .series || level == .image)
                        ? parentLookup[result.toStudyResult().studyInstanceUID ?? ""]
                        : nil
                    return (result: result, parent: parent)
                }
                switch outputFormat {
                case "json":
                    appendConsoleOutput(formatQueryResultsJSON(collected, level: level))
                case "csv":
                    appendConsoleOutput(formatQueryResultsCSV(collected, level: level))
                case "xml":
                    appendConsoleOutput(formatQueryResultsXML(collected, level: level))
                case "hl7":
                    appendConsoleOutput(formatQueryResultsHL7(collected, level: level))
                default:
                    for (index, pair) in collected.enumerated() {
                        appendConsoleOutput(formatQueryResult(pair.result, index: index + 1, level: level, parentStudyInfo: pair.parent))
                    }
                }
            }
            consoleStatus = .success
            service.setConsoleStatus(.success)
            // Warn about likely server-side result limit
            if isLikelyServerLimit(allResults.count) {
                appendConsoleOutput("⚠️  The result count (\(allResults.count)) may be capped by a server-side limit.\n")
                appendConsoleOutput("    Check your PACS server configuration (e.g., LimitFindResults in Orthanc,\n")
                appendConsoleOutput("    or LimitFindResults in dcm4chee) to increase or remove the limit.\n")
            }
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
        studyDate: String,
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
        let transferSyntaxSend = paramValue("transfer-syntax")
        if !transferSyntaxSend.isEmpty {
            appendConsoleOutput("  Transfer Syntax:  \(transferSyntaxSend) (proposed TS)\n")
        }
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
                        // Use preferred TS if the user selected one; otherwise let the service use the file's own TS
                        let result: StoreResult
                        if let tsUID = transferSyntaxUID(for: transferSyntaxSend) {
                            result = try await DICOMStorageService.store(
                                fileData: fileData,
                                preferredTransferSyntaxUID: tsUID,
                                to: host,
                                port: port,
                                callingAE: callingAET,
                                calledAE: calledAET,
                                priority: priority,
                                timeout: timeout
                            )
                        } else {
                            result = try await DICOMStorageService.store(
                                fileData: fileData,
                                to: host,
                                port: port,
                                callingAE: callingAET,
                                calledAE: calledAET,
                                priority: priority,
                                timeout: timeout
                            )
                        }
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
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        let transferSyntaxRetrieve = paramValue("transfer-syntax")
        let preferredTSRetrieve = transferSyntaxUID(for: transferSyntaxRetrieve)
        if !transferSyntaxRetrieve.isEmpty {
            if isCMove {
                appendConsoleOutput("  Transfer Syntax:  \(transferSyntaxRetrieve) (advisory — negotiated by destination AE)\n")
            } else {
                appendConsoleOutput("  Transfer Syntax:  \(transferSyntaxRetrieve) → \(preferredTSRetrieve ?? "unrecognised, using default") (proposed for C-STORE sub-ops)\n")
            }
        }
        appendConsoleOutput("\n")

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
                // C-GET — pass preferred TS so the SCP sends back in that encoding
                let stream: AsyncStream<DICOMRetrieveService.GetEvent>
                if !instanceUID.isEmpty && !seriesUID.isEmpty {
                    stream = try await DICOMRetrieveService.getInstance(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        sopInstanceUID: instanceUID,
                        preferredTransferSyntaxUID: preferredTSRetrieve,
                        timeout: timeout
                    )
                } else if !seriesUID.isEmpty {
                    stream = try await DICOMRetrieveService.getSeries(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        seriesInstanceUID: seriesUID,
                        preferredTransferSyntaxUID: preferredTSRetrieve,
                        timeout: timeout
                    )
                } else {
                    stream = try await DICOMRetrieveService.getStudy(
                        host: host, port: port,
                        callingAE: callingAET, calledAE: calledAET,
                        studyInstanceUID: resolvedStudyUID,
                        preferredTransferSyntaxUID: preferredTSRetrieve,
                        timeout: timeout
                    )
                }

                var receivedCount = 0
                for await event in stream {
                    switch event {
                    case .instance(let sopInstanceUID, let sopClassUID, let transferSyntaxUID, let data):
                        receivedCount += 1
                        let sizeStr = FileDropHelpers.formatFileSize(Int64(data.count))
                        appendConsoleOutput("  Received [\(receivedCount)]: \(sopInstanceUID) (\(sizeStr))")
                        // Write the received data to disk wrapped in a Part 10 container
                        do {
                            let savedPath = try writeReceivedDICOMFile(
                                data: data,
                                sopInstanceUID: sopInstanceUID,
                                sopClassUID: sopClassUID,
                                transferSyntaxUID: transferSyntaxUID,
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
        let transferSyntaxQR = paramValue("transfer-syntax")
        let preferredTSQR = transferSyntaxUID(for: transferSyntaxQR)
        if !transferSyntaxQR.isEmpty {
            if isCMove {
                appendConsoleOutput("  Transfer Syntax:  \(transferSyntaxQR) (advisory — negotiated by destination AE)\n")
            } else {
                appendConsoleOutput("  Transfer Syntax:  \(transferSyntaxQR) → \(preferredTSQR ?? "unrecognised, using default") (proposed for C-STORE sub-ops)\n")
            }
        }

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
                            preferredTransferSyntaxUID: preferredTSQR,
                            timeout: timeout
                        )
                        var fileCount = 0
                        for await event in stream {
                            switch event {
                            case .instance(let sopInstanceUID, let sopClassUID, let transferSyntaxUID, let data):
                                fileCount += 1
                                do {
                                    let savedPath = try writeReceivedDICOMFile(
                                        data: data,
                                        sopInstanceUID: sopInstanceUID,
                                        sopClassUID: sopClassUID,
                                        transferSyntaxUID: transferSyntaxUID,
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

    // MARK: - MWL Execution (dicom-mwl)

    /// Performs a Modality Worklist C-FIND query.
    private func executeDicomMWL() async {
        let operation = paramValue("operation").isEmpty ? "query" : paramValue("operation")
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 60

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        if operation == "create" {
            await executeDicomMWLCreate(
                host: host, port: port,
                callingAET: callingAET, calledAET: calledAET,
                timeout: timeout
            )
        } else {
            await executeDicomMWLQuery(
                host: host, port: port,
                callingAET: callingAET, calledAET: calledAET,
                timeout: timeout
            )
        }
    }

    // MARK: - MWL Query (C-FIND)

    private func executeDicomMWLQuery(
        host: String, port: UInt16,
        callingAET: String, calledAET: String,
        timeout: TimeInterval
    ) async {
        let dateFrom = paramValue("date-from")
        let dateTo = paramValue("date-to")
        let station = paramValue("station")
        let patient = paramValue("patient")
        let patientID = paramValue("patient-id")
        let modality = paramValue("modality")
        let spsStatus = paramValue("sps-status")
        let jsonOutput = paramValue("json") == "true"

        appendConsoleOutput("DICOM Modality Worklist (C-FIND)\n")
        appendConsoleOutput("================================\n")
        appendConsoleOutput("  Server:           \(host):\(port)\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        if !dateFrom.isEmpty || !dateTo.isEmpty {
            let fromDisplay = dateFrom.isEmpty ? "(open)" : dateFrom
            let toDisplay = dateTo.isEmpty ? "(open)" : dateTo
            appendConsoleOutput("  Date Range:       \(fromDisplay) — \(toDisplay)\n")
        }
        if !station.isEmpty   { appendConsoleOutput("  Station AET:      \(station)\n") }
        if !patient.isEmpty   { appendConsoleOutput("  Patient Name:     \(patient)\n") }
        if !patientID.isEmpty { appendConsoleOutput("  Patient ID:       \(patientID)\n") }
        if !modality.isEmpty  { appendConsoleOutput("  Modality:         \(modality)\n") }
        if !spsStatus.isEmpty { appendConsoleOutput("  SPS Status:       \(spsStatus)\n") }
        appendConsoleOutput("\nQuerying Modality Worklist...\n\n")

        do {
            var queryKeys = WorklistQueryKeys.default()
            // Build DICOM date or date range: "YYYYMMDD", "YYYYMMDD-YYYYMMDD",
            // "YYYYMMDD-" (from only), or "-YYYYMMDD" (to only).
            let resolvedFrom = dateFrom.isEmpty ? "" : resolvedWorklistDate(dateFrom)
            let resolvedTo   = dateTo.isEmpty   ? "" : resolvedWorklistDate(dateTo)
            if !resolvedFrom.isEmpty || !resolvedTo.isEmpty {
                let dateQuery: String
                if !resolvedFrom.isEmpty && resolvedTo.isEmpty {
                    dateQuery = "\(resolvedFrom)-"          // from onwards
                } else if resolvedFrom.isEmpty && !resolvedTo.isEmpty {
                    dateQuery = "-\(resolvedTo)"            // up to
                } else if resolvedFrom == resolvedTo {
                    dateQuery = resolvedFrom                // single day
                } else {
                    dateQuery = "\(resolvedFrom)-\(resolvedTo)"  // range
                }
                queryKeys = queryKeys.scheduledDate(dateQuery)
            }
            if !station.isEmpty   { queryKeys = queryKeys.scheduledStationAET(station) }
            if !patient.isEmpty {
                let wildcardPatient = patient.hasSuffix("*") ? patient : patient + "*"
                queryKeys = queryKeys.patientName(wildcardPatient)
            }
            if !patientID.isEmpty { queryKeys = queryKeys.patientID(patientID) }
            if !modality.isEmpty  { queryKeys = queryKeys.modality(modality) }
            if !spsStatus.isEmpty { queryKeys = queryKeys.scheduledProcedureStepStatus(spsStatus) }

            let items = try await DICOMModalityWorklistService.find(
                host: host,
                port: port,
                callingAE: callingAET,
                calledAE: calledAET,
                matching: queryKeys,
                timeout: timeout
            )

            if items.isEmpty {
                appendConsoleOutput("No worklist items found matching the specified criteria.\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 0, output: "0 worklist items found")
                return
            }

            appendConsoleOutput("Found \(items.count) worklist item(s):\n\n")

            if jsonOutput {
                appendConsoleOutput("[\n")
                for (index, item) in items.enumerated() {
                    appendConsoleOutput("  {\n")
                    if let v = item.patientName                      { appendConsoleOutput("    \"PatientName\": \"\(v)\",\n") }
                    if let v = item.patientID                        { appendConsoleOutput("    \"PatientID\": \"\(v)\",\n") }
                    if let v = item.patientBirthDate                 { appendConsoleOutput("    \"PatientBirthDate\": \"\(v)\",\n") }
                    if let v = item.patientSex                       { appendConsoleOutput("    \"PatientSex\": \"\(v)\",\n") }
                    if let v = item.accessionNumber                  { appendConsoleOutput("    \"AccessionNumber\": \"\(v)\",\n") }
                    if let v = item.studyInstanceUID                 { appendConsoleOutput("    \"StudyInstanceUID\": \"\(v)\",\n") }
                    if let v = item.referringPhysicianName           { appendConsoleOutput("    \"ReferringPhysicianName\": \"\(v)\",\n") }
                    if let v = item.requestedProcedureID             { appendConsoleOutput("    \"RequestedProcedureID\": \"\(v)\",\n") }
                    if let v = item.requestedProcedureDescription    { appendConsoleOutput("    \"RequestedProcedureDescription\": \"\(v)\",\n") }
                    if let v = item.modality                         { appendConsoleOutput("    \"Modality\": \"\(v)\",\n") }
                    if let v = item.scheduledStationAETitle          { appendConsoleOutput("    \"ScheduledStationAETitle\": \"\(v)\",\n") }
                    if let v = item.scheduledStationName             { appendConsoleOutput("    \"ScheduledStationName\": \"\(v)\",\n") }
                    if let v = item.scheduledProcedureStepStartDate  { appendConsoleOutput("    \"SPSStartDate\": \"\(v)\",\n") }
                    if let v = item.scheduledProcedureStepStartTime  { appendConsoleOutput("    \"SPSStartTime\": \"\(v)\",\n") }
                    if let v = item.scheduledProcedureStepStatus     { appendConsoleOutput("    \"SPSStatus\": \"\(v)\",\n") }
                    if let v = item.scheduledProcedureStepID         { appendConsoleOutput("    \"SPSID\": \"\(v)\",\n") }
                    if let v = item.scheduledProcedureStepDescription{ appendConsoleOutput("    \"SPSDescription\": \"\(v)\",\n") }
                    if let v = item.scheduledPerformingPhysicianName { appendConsoleOutput("    \"ScheduledPhysician\": \"\(v)\"\n") }
                    appendConsoleOutput("  }\(index < items.count - 1 ? "," : "")\n")
                }
                appendConsoleOutput("]\n")
            } else {
                let sep = String(repeating: "─", count: 60)
                for (index, item) in items.enumerated() {
                    appendConsoleOutput("[\(index + 1)] Worklist Item\n")
                    appendConsoleOutput("\(sep)\n")
                    // Patient
                    if let v = item.patientName    { appendConsoleOutput("  Patient Name:          \(v)\n") }
                    if let v = item.patientID      { appendConsoleOutput("  Patient ID:            \(v)\n") }
                    if let v = item.patientBirthDate { appendConsoleOutput("  Date of Birth:         \(v)\n") }
                    if let v = item.patientSex     { appendConsoleOutput("  Sex:                   \(v)\n") }
                    // Study
                    if let v = item.accessionNumber { appendConsoleOutput("  Accession Number:      \(v)\n") }
                    if let v = item.referringPhysicianName { appendConsoleOutput("  Referring Physician:   \(v)\n") }
                    if let v = item.requestedProcedureID  { appendConsoleOutput("  Requested Proc. ID:    \(v)\n") }
                    if let v = item.requestedProcedureDescription { appendConsoleOutput("  Requested Proc. Desc:  \(v)\n") }
                    if let v = item.studyInstanceUID { appendConsoleOutput("  Study UID:             \(v)\n") }
                    // SPS
                    if let v = item.modality       { appendConsoleOutput("  Modality:              \(v)\n") }
                    if let v = item.scheduledProcedureStepStartDate {
                        var dateTime = v
                        if let t = item.scheduledProcedureStepStartTime { dateTime += "  \(t)" }
                        appendConsoleOutput("  Scheduled Date/Time:   \(dateTime)\n")
                    }
                    if let v = item.scheduledProcedureStepStatus    { appendConsoleOutput("  SPS Status:            \(v)\n") }
                    if let v = item.scheduledProcedureStepID        { appendConsoleOutput("  SPS ID:                \(v)\n") }
                    if let v = item.scheduledProcedureStepDescription { appendConsoleOutput("  SPS Description:       \(v)\n") }
                    if let v = item.scheduledStationAETitle         { appendConsoleOutput("  Station AE Title:      \(v)\n") }
                    if let v = item.scheduledStationName            { appendConsoleOutput("  Station Name:          \(v)\n") }
                    if let v = item.scheduledPerformingPhysicianName { appendConsoleOutput("  Performing Physician:  \(v)\n") }
                    appendConsoleOutput("\n")
                }
            }

            appendConsoleOutput("✅ Worklist query completed — \(items.count) item(s) returned\n")
            // Warn about likely server-side result limit
            if isLikelyServerLimit(items.count) {
                appendConsoleOutput("⚠️  The result count (\(items.count)) may be capped by a server-side limit.\n")
                appendConsoleOutput("    Check your PACS server configuration (e.g., LimitFindResults in Orthanc,\n")
                appendConsoleOutput("    or max_worklist_results in dcm4chee) to increase or remove the limit.\n")
            }
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 0,
                         output: "\(items.count) worklist item(s) found")
        } catch {
            let errorDesc = (error as? DICOMNetworkError)?.description ?? error.localizedDescription
            appendConsoleOutput("❌ Worklist query failed: \(errorDesc)\n")
            if let netError = error as? DICOMNetworkError {
                switch netError {
                case .sopClassNotSupported, .noPresentationContextAccepted:
                    appendConsoleOutput("  💡 Hint: The server may not support MWL (Modality Worklist).\n")
                    appendConsoleOutput("     dcm4chee5: Ensure the MWL SCP is enabled in the archive configuration.\n")
                case .associationRejected:
                    appendConsoleOutput("  💡 Hint: The server rejected the association. Check the Called AE Title matches the server configuration.\n")
                case .connectionFailed, .connectionClosed, .timeout, .operationTimeout, .artimTimerExpired:
                    appendConsoleOutput("  💡 Hint: Could not connect. Verify the hostname, port, and that the PACS is running.\n")
                default:
                    break
                }
            }
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1,
                         output: errorDesc)
        }
    }

    // MARK: - MWL Create (REST API)

    private func executeDicomMWLCreate(
        host: String, port: UInt16,
        callingAET: String, calledAET: String,
        timeout: TimeInterval
    ) async {
        let createMethod = paramValue("create-method").isEmpty ? "hl7" : paramValue("create-method")
        let patientName = paramValue("create-patient-name")
        let patientID = paramValue("create-patient-id")
        let patientDOB = paramValue("patient-dob")
        let patientSex = paramValue("patient-sex")
        let accessionNumber = paramValue("accession-number")
        let referringPhysician = paramValue("referring-physician")
        let procedureID = paramValue("procedure-id")
        let procedureDesc = paramValue("procedure-desc")
        let modality = paramValue("create-modality").isEmpty ? "CT" : paramValue("create-modality")
        let scheduledStation = paramValue("scheduled-station")
        let stationName = paramValue("station-name")
        let scheduledDate = paramValue("scheduled-date")
        let scheduledTime = paramValue("scheduled-time")
        let spsID = paramValue("sps-id")
        let spsDesc = paramValue("sps-desc")
        let performingPhysician = paramValue("performing-physician")

        guard !patientName.isEmpty else {
            appendConsoleOutput("Error: Patient Name is required for worklist creation.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1,
                         output: "Patient Name is required")
            return
        }
        guard !patientID.isEmpty else {
            appendConsoleOutput("Error: Patient ID is required for worklist creation.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1,
                         output: "Patient ID is required")
            return
        }

        // Resolve scheduled date
        let resolvedDate: String
        if scheduledDate.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            resolvedDate = formatter.string(from: Date())
        } else {
            resolvedDate = resolvedWorklistDate(scheduledDate)
        }

        if createMethod == "hl7" {
            await executeDicomMWLCreateHL7(
                host: host, timeout: timeout,
                patientName: patientName, patientID: patientID,
                patientDOB: patientDOB, patientSex: patientSex,
                accessionNumber: accessionNumber,
                referringPhysician: referringPhysician,
                procedureID: procedureID, procedureDesc: procedureDesc,
                modality: modality, scheduledStation: scheduledStation,
                stationName: stationName, resolvedDate: resolvedDate,
                scheduledTime: scheduledTime, spsID: spsID,
                spsDesc: spsDesc, performingPhysician: performingPhysician
            )
        } else {
            await executeDicomMWLCreateREST(
                host: host, port: port,
                callingAET: callingAET, calledAET: calledAET,
                timeout: timeout,
                patientName: patientName, patientID: patientID,
                patientDOB: patientDOB, patientSex: patientSex,
                accessionNumber: accessionNumber,
                referringPhysician: referringPhysician,
                procedureID: procedureID, procedureDesc: procedureDesc,
                modality: modality, scheduledStation: scheduledStation,
                stationName: stationName, resolvedDate: resolvedDate,
                scheduledTime: scheduledTime, spsID: spsID,
                spsDesc: spsDesc, performingPhysician: performingPhysician
            )
        }
    }

    // MARK: - MWL Create via HL7 ORM^O01 (MLLP)

    private func executeDicomMWLCreateHL7(
        host: String, timeout: TimeInterval,
        patientName: String, patientID: String,
        patientDOB: String, patientSex: String,
        accessionNumber: String, referringPhysician: String,
        procedureID: String, procedureDesc: String,
        modality: String, scheduledStation: String,
        stationName: String, resolvedDate: String,
        scheduledTime: String, spsID: String,
        spsDesc: String, performingPhysician: String
    ) async {
        let hl7PortStr = paramValue("hl7-port")
        let hl7Port = UInt16(hl7PortStr) ?? 2575
        let sendingApp = paramValue("sending-application").isEmpty ? "DICOMSTUDIO" : paramValue("sending-application")
        let sendingFacility = paramValue("sending-facility").isEmpty ? "IMAGING" : paramValue("sending-facility")
        let receivingApp = paramValue("receiving-application").isEmpty ? "DCM4CHEE" : paramValue("receiving-application")
        let receivingFacility = paramValue("receiving-facility").isEmpty ? "HOSPITAL" : paramValue("receiving-facility")

        appendConsoleOutput("DICOM Modality Worklist (HL7 ORM^O01 via MLLP)\n")
        appendConsoleOutput("================================================\n")
        appendConsoleOutput("  HL7 Server:       \(host):\(hl7Port)\n")
        appendConsoleOutput("  Sending App:      \(sendingApp) | \(sendingFacility)\n")
        appendConsoleOutput("  Receiving App:    \(receivingApp) | \(receivingFacility)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        appendConsoleOutput("\n  Patient Name:     \(patientName)\n")
        appendConsoleOutput("  Patient ID:       \(patientID)\n")
        if !patientDOB.isEmpty       { appendConsoleOutput("  Date of Birth:    \(patientDOB)\n") }
        if !patientSex.isEmpty       { appendConsoleOutput("  Patient Sex:      \(patientSex)\n") }
        if !accessionNumber.isEmpty  { appendConsoleOutput("  Accession Number: \(accessionNumber)\n") }
        if !referringPhysician.isEmpty { appendConsoleOutput("  Referring Phys:   \(referringPhysician)\n") }
        appendConsoleOutput("  Modality:         \(modality)\n")
        appendConsoleOutput("  Scheduled Date:   \(resolvedDate)\n")
        if !scheduledTime.isEmpty    { appendConsoleOutput("  Scheduled Time:   \(scheduledTime)\n") }
        if !scheduledStation.isEmpty { appendConsoleOutput("  Station AET:      \(scheduledStation)\n") }
        if !stationName.isEmpty      { appendConsoleOutput("  Station Name:     \(stationName)\n") }
        if !spsID.isEmpty            { appendConsoleOutput("  SPS ID:           \(spsID)\n") }
        if !spsDesc.isEmpty          { appendConsoleOutput("  SPS Description:  \(spsDesc)\n") }
        if !procedureID.isEmpty      { appendConsoleOutput("  Procedure ID:     \(procedureID)\n") }
        if !procedureDesc.isEmpty    { appendConsoleOutput("  Procedure Desc:   \(procedureDesc)\n") }
        if !performingPhysician.isEmpty { appendConsoleOutput("  Performing Phys:  \(performingPhysician)\n") }
        appendConsoleOutput("\nSending HL7 ORM^O01 order message via MLLP...\n\n")

        do {
            let messageControlID = try await DICOMModalityWorklistService.createViaHL7(
                host: host,
                hl7Port: hl7Port,
                sendingApplication: sendingApp,
                sendingFacility: sendingFacility,
                receivingApplication: receivingApp,
                receivingFacility: receivingFacility,
                patientName: patientName,
                patientID: patientID,
                patientBirthDate: patientDOB.isEmpty ? nil : patientDOB,
                patientSex: patientSex.isEmpty ? nil : patientSex,
                accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber,
                referringPhysicianName: referringPhysician.isEmpty ? nil : referringPhysician,
                requestedProcedureID: procedureID.isEmpty ? nil : procedureID,
                requestedProcedureDescription: procedureDesc.isEmpty ? nil : procedureDesc,
                modality: modality.isEmpty ? nil : modality,
                scheduledStationAETitle: scheduledStation.isEmpty ? nil : scheduledStation,
                scheduledStationName: stationName.isEmpty ? nil : stationName,
                scheduledStartDate: resolvedDate,
                scheduledStartTime: scheduledTime.isEmpty ? nil : scheduledTime,
                scheduledProcedureStepID: spsID.isEmpty ? nil : spsID,
                scheduledProcedureStepDescription: spsDesc.isEmpty ? nil : spsDesc,
                scheduledPerformingPhysicianName: performingPhysician.isEmpty ? nil : performingPhysician,
                timeout: timeout
            )

            appendConsoleOutput("✅ HL7 ORM^O01 accepted by server (ACK: AA)\n")
            appendConsoleOutput("  Message Control ID: \(messageControlID)\n")
            appendConsoleOutput("  Patient and worklist item created automatically.\n")
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 0,
                         output: "HL7 ORM sent: \(messageControlID)")
        } catch {
            let errorDesc = (error as? DICOMNetworkError)?.description ?? error.localizedDescription
            appendConsoleOutput("❌ HL7 ORM^O01 failed: \(errorDesc)\n")
            appendConsoleOutput("  💡 Hints:\n")
            appendConsoleOutput("     • Ensure the HL7 MLLP listener is running on \(host):\(hl7Port)\n")
            appendConsoleOutput("     • dcm4chee-arc default HL7 port is 2575 (check hl7-connection in UI config)\n")
            appendConsoleOutput("     • Verify Sending/Receiving Application names match the server config\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1,
                         output: errorDesc)
        }
    }

    // MARK: - MWL Create via REST API

    private func executeDicomMWLCreateREST(
        host: String, port: UInt16,
        callingAET: String, calledAET: String,
        timeout: TimeInterval,
        patientName: String, patientID: String,
        patientDOB: String, patientSex: String,
        accessionNumber: String, referringPhysician: String,
        procedureID: String, procedureDesc: String,
        modality: String, scheduledStation: String,
        stationName: String, resolvedDate: String,
        scheduledTime: String, spsID: String,
        spsDesc: String, performingPhysician: String
    ) async {
        let restBaseURLRaw = paramValue("rest-base-url")

        // Construct REST base URL (default: dcm4chee-arc pattern)
        let restBaseURL: String? = restBaseURLRaw.isEmpty ? nil : restBaseURLRaw
        let displayURL = restBaseURL ?? "http://\(host):8080/dcm4chee-arc"

        appendConsoleOutput("DICOM Modality Worklist (REST API)\n")
        appendConsoleOutput("===================================\n")
        appendConsoleOutput("  REST Endpoint:    \(displayURL)/aets/\(calledAET)/rs/mwlitems\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        appendConsoleOutput("\n  Patient Name:     \(patientName)\n")
        appendConsoleOutput("  Patient ID:       \(patientID)\n")
        if !patientDOB.isEmpty       { appendConsoleOutput("  Date of Birth:    \(patientDOB)\n") }
        if !patientSex.isEmpty       { appendConsoleOutput("  Patient Sex:      \(patientSex)\n") }
        if !accessionNumber.isEmpty  { appendConsoleOutput("  Accession Number: \(accessionNumber)\n") }
        if !referringPhysician.isEmpty { appendConsoleOutput("  Referring Phys:   \(referringPhysician)\n") }
        appendConsoleOutput("  Modality:         \(modality)\n")
        appendConsoleOutput("  Scheduled Date:   \(resolvedDate)\n")
        if !scheduledTime.isEmpty    { appendConsoleOutput("  Scheduled Time:   \(scheduledTime)\n") }
        if !scheduledStation.isEmpty { appendConsoleOutput("  Station AET:      \(scheduledStation)\n") }
        if !stationName.isEmpty      { appendConsoleOutput("  Station Name:     \(stationName)\n") }
        if !spsID.isEmpty            { appendConsoleOutput("  SPS ID:           \(spsID)\n") }
        if !spsDesc.isEmpty          { appendConsoleOutput("  SPS Description:  \(spsDesc)\n") }
        if !procedureID.isEmpty      { appendConsoleOutput("  Procedure ID:     \(procedureID)\n") }
        if !procedureDesc.isEmpty    { appendConsoleOutput("  Procedure Desc:   \(procedureDesc)\n") }
        if !performingPhysician.isEmpty { appendConsoleOutput("  Performing Phys:  \(performingPhysician)\n") }
        appendConsoleOutput("\nCreating Modality Worklist item via REST...\n\n")

        do {
            let sopInstanceUID = try await DICOMModalityWorklistService.create(
                host: host,
                port: port,
                callingAE: callingAET,
                calledAE: calledAET,
                patientName: patientName,
                patientID: patientID,
                patientBirthDate: patientDOB.isEmpty ? nil : patientDOB,
                patientSex: patientSex.isEmpty ? nil : patientSex,
                accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber,
                referringPhysicianName: referringPhysician.isEmpty ? nil : referringPhysician,
                requestedProcedureID: procedureID.isEmpty ? nil : procedureID,
                requestedProcedureDescription: procedureDesc.isEmpty ? nil : procedureDesc,
                modality: modality.isEmpty ? nil : modality,
                scheduledStationAETitle: scheduledStation.isEmpty ? nil : scheduledStation,
                scheduledStationName: stationName.isEmpty ? nil : stationName,
                scheduledStartDate: resolvedDate,
                scheduledStartTime: scheduledTime.isEmpty ? nil : scheduledTime,
                scheduledProcedureStepID: spsID.isEmpty ? nil : spsID,
                scheduledProcedureStepDescription: spsDesc.isEmpty ? nil : spsDesc,
                scheduledPerformingPhysicianName: performingPhysician.isEmpty ? nil : performingPhysician,
                restBaseURL: restBaseURL,
                timeout: timeout
            )

            appendConsoleOutput("✅ Worklist item created successfully\n")
            appendConsoleOutput("  SOP Instance UID: \(sopInstanceUID)\n")
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 0,
                         output: "Worklist item created: \(sopInstanceUID)")
        } catch {
            let errorDesc = (error as? DICOMNetworkError)?.description ?? error.localizedDescription
            appendConsoleOutput("❌ Worklist create failed: \(errorDesc)\n")
            appendConsoleOutput("  💡 Hint: REST requires the patient to exist first on the server.\n")
            appendConsoleOutput("     Consider using \"HL7\" create method instead — it auto-creates patient + worklist.\n")
            appendConsoleOutput("     Default endpoint: http://<host>:8080/dcm4chee-arc/aets/<AET>/rs/mwlitems\n")
            appendConsoleOutput("     Set \"REST Base URL\" if your server uses a different URL.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1,
                         output: errorDesc)
        }
    }

    /// Returns `true` when the result count looks like a server-side cap
    /// (common defaults: 50, 100, 200, 250, 500, 1000).
    private func isLikelyServerLimit(_ count: Int) -> Bool {
        let commonLimits: Set<Int> = [50, 100, 200, 250, 500, 1000, 2000, 5000]
        return commonLimits.contains(count)
    }

    /// Resolves a date filter string for MWL queries.
    /// Accepts "today", "tomorrow", or YYYYMMDD format.
    private func resolvedWorklistDate(_ filter: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        switch filter.lowercased() {
        case "today":
            return formatter.string(from: Date())
        case "tomorrow":
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return formatter.string(from: tomorrow)
        default:
            return filter
        }
    }

    /// Maps user-friendly transfer syntax names to DICOM UIDs.
    private func transferSyntaxUID(for name: String) -> String? {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        // If already a UID (starts with digit), pass through
        if n.first?.isNumber == true { return name }
        switch n {
        case "explicit-vr-le":    return "1.2.840.10008.1.2.1"
        case "implicit-vr-le":    return "1.2.840.10008.1.2"
        case "jpeg-baseline":     return "1.2.840.10008.1.2.4.50"
        case "jpeg-lossless":     return "1.2.840.10008.1.2.4.70"
        case "jpeg2000-lossless": return "1.2.840.10008.1.2.4.90"
        case "jpeg2000":          return "1.2.840.10008.1.2.4.91"
        case "rle-lossless":      return "1.2.840.10008.1.2.5"
        case "deflate":           return "1.2.840.10008.1.2.1.99"
        default:                  return nil
        }
    }

    // MARK: - MPPS Execution (dicom-mpps)

    /// Performs an MPPS N-CREATE or N-SET operation.
    private func executeDicomMPPS() async {
        let host = paramValue("host")
        let portStr = paramValue("port")
        let callingAET = paramValue("calling-aet").isEmpty ? "DICOMSTUDIO" : paramValue("calling-aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let port = UInt16(portStr) ?? 11112
        let timeout = TimeInterval(timeoutStr) ?? 60
        let operation = paramValue("operation").lowercased()
        let studyUID = paramValue("study-uid")
        let mppsUID = paramValue("mpps-uid")
        let statusStr = paramValue("status")
        // N-CREATE attributes
        let patientName = paramValue("patient-name")
        let patientID = paramValue("patient-id")
        let modality = paramValue("modality")
        let procedureID = paramValue("procedure-id")
        let procedureDesc = paramValue("procedure-desc")
        let accessionNumber = paramValue("accession-number")
        let performingPhysician = paramValue("performing-physician")
        let stationName = paramValue("station-name")
        // N-SET attributes
        let seriesUID = paramValue("series-uid")
        let imageUIDsRaw = paramValue("image-uids")
        let discontinueReason = paramValue("discontinue-reason")

        guard !host.isEmpty else {
            appendConsoleOutput("Error: Hostname is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 1, output: "Hostname is required")
            return
        }

        let isCreate = operation != "update"

        if isCreate && studyUID.isEmpty {
            appendConsoleOutput("Error: Study Instance UID is required for create operation.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 1, output: "Study UID required for create")
            return
        }

        if !isCreate && mppsUID.isEmpty {
            appendConsoleOutput("Error: MPPS Instance UID is required for update operation.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 1, output: "MPPS UID required for update")
            return
        }

        let mppsStatus: DICOMNetwork.MPPSStatus
        switch statusStr.uppercased().replacingOccurrences(of: " ", with: "") {
        case "INPROGRESS":
            mppsStatus = DICOMNetwork.MPPSStatus.inProgress
        case "COMPLETED":
            mppsStatus = DICOMNetwork.MPPSStatus.completed
        case "DISCONTINUED":
            mppsStatus = DICOMNetwork.MPPSStatus.discontinued
        default:
            mppsStatus = isCreate ? DICOMNetwork.MPPSStatus.inProgress : DICOMNetwork.MPPSStatus.completed
        }

        appendConsoleOutput("DICOM MPPS (\(isCreate ? "N-CREATE" : "N-SET"))\n")
        appendConsoleOutput("=====================================\n")
        appendConsoleOutput("  Operation:        \(isCreate ? "Create (N-CREATE)" : "Update (N-SET)")\n")
        appendConsoleOutput("  Server:           \(host):\(port)\n")
        appendConsoleOutput("  Calling AE Title: \(callingAET)\n")
        appendConsoleOutput("  Called AE Title:  \(calledAET)\n")
        appendConsoleOutput("  Status:           \(mppsStatus.rawValue)\n")
        appendConsoleOutput("  Timeout:          \(Int(timeout))s\n")
        if isCreate {
            if !studyUID.isEmpty        { appendConsoleOutput("  Study UID:        \(studyUID)\n") }
            if !patientName.isEmpty     { appendConsoleOutput("  Patient Name:     \(patientName)\n") }
            if !patientID.isEmpty       { appendConsoleOutput("  Patient ID:       \(patientID)\n") }
            if !modality.isEmpty        { appendConsoleOutput("  Modality:         \(modality)\n") }
            if !procedureID.isEmpty     { appendConsoleOutput("  Procedure ID:     \(procedureID)\n") }
            if !procedureDesc.isEmpty   { appendConsoleOutput("  Procedure Desc:   \(procedureDesc)\n") }
            if !accessionNumber.isEmpty { appendConsoleOutput("  Accession Number: \(accessionNumber)\n") }
            if !performingPhysician.isEmpty { appendConsoleOutput("  Physician:        \(performingPhysician)\n") }
            if !stationName.isEmpty     { appendConsoleOutput("  Station Name:     \(stationName)\n") }
        } else {
            if !mppsUID.isEmpty         { appendConsoleOutput("  MPPS UID:         \(mppsUID)\n") }
            if !seriesUID.isEmpty       { appendConsoleOutput("  Series UID:       \(seriesUID)\n") }
            if !imageUIDsRaw.isEmpty    { appendConsoleOutput("  Image UIDs:       \(imageUIDsRaw)\n") }
            if mppsStatus == .discontinued && !discontinueReason.isEmpty {
                appendConsoleOutput("  Discontinue Reason: \(discontinueReason)\n")
            }
        }
        appendConsoleOutput("\n")

        do {
            if isCreate {
                appendConsoleOutput("Creating MPPS instance (N-CREATE)...\n")
                let createdUID = try await DICOMMPPSService.create(
                    host: host,
                    port: port,
                    callingAE: callingAET,
                    calledAE: calledAET,
                    studyInstanceUID: studyUID,
                    status: mppsStatus,
                    timeout: timeout,
                    patientName: patientName.isEmpty ? nil : patientName,
                    patientID: patientID.isEmpty ? nil : patientID,
                    modality: modality.isEmpty ? nil : modality,
                    procedureStepID: procedureID.isEmpty ? nil : procedureID,
                    procedureStepDescription: procedureDesc.isEmpty ? nil : procedureDesc,
                    performingPhysicianName: performingPhysician.isEmpty ? nil : performingPhysician,
                    performedStationName: stationName.isEmpty ? nil : stationName,
                    accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber
                )
                appendConsoleOutput("✅ MPPS instance created\n")
                appendConsoleOutput("  MPPS Instance UID: \(createdUID)\n\n")
                appendConsoleOutput("To complete or discontinue this procedure step:\n")
                appendConsoleOutput("  Set Operation to 'update', paste the MPPS UID above,\n")
                appendConsoleOutput("  and set Status to COMPLETED or DISCONTINUED.\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 0,
                             output: "Created MPPS: \(createdUID)")
            } else {
                appendConsoleOutput("Updating MPPS instance (N-SET) to \(mppsStatus.rawValue)...\n")
                // Build referenced SOPs for the update
                var referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = []
                if !seriesUID.isEmpty && !imageUIDsRaw.isEmpty {
                    let imageUIDs = imageUIDsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let refStudyUID = studyUID.isEmpty ? mppsUID : studyUID
                    for uid in imageUIDs where !uid.isEmpty {
                        referencedSOPs.append((studyUID: refStudyUID, seriesUID: seriesUID, sopInstanceUID: uid))
                    }
                }
                try await DICOMMPPSService.update(
                    host: host,
                    port: port,
                    callingAE: callingAET,
                    calledAE: calledAET,
                    mppsInstanceUID: mppsUID,
                    status: mppsStatus,
                    referencedSOPs: referencedSOPs,
                    studyInstanceUID: studyUID.isEmpty ? nil : studyUID,
                    accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber,
                    scheduledProcedureStepID: procedureID.isEmpty ? nil : procedureID,
                    procedureStepID: procedureID.isEmpty ? nil : procedureID,
                    timeout: timeout
                )
                appendConsoleOutput("✅ MPPS instance updated to \(mppsStatus.rawValue)\n")
                if !referencedSOPs.isEmpty {
                    appendConsoleOutput("  Referenced Images: \(referencedSOPs.count)\n")
                }
                if mppsStatus == .discontinued && !discontinueReason.isEmpty {
                    appendConsoleOutput("  Discontinuation Reason: \(discontinueReason)\n")
                }
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 0,
                             output: "Updated MPPS \(mppsUID) to \(mppsStatus.rawValue)")
            }
        } catch {
            let errorMessage: String
            if let networkError = error as? DICOMNetworkError {
                errorMessage = networkError.description
            } else {
                errorMessage = error.localizedDescription
            }
            appendConsoleOutput("❌ MPPS operation failed: \(errorMessage)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 1,
                         output: errorMessage)
        }
    }

    // MARK: - DCM2DCM Execution (Transfer Syntax Conversion)

    /// Maps user-facing transfer syntax names to DICOM Transfer Syntax UIDs.
    private static let transferSyntaxNameToUID: [String: String] = [
        "Explicit VR Little Endian":  "1.2.840.10008.1.2.1",
        "Implicit VR Little Endian":  "1.2.840.10008.1.2",
        "Explicit VR Big Endian":     "1.2.840.10008.1.2.2",
        "JPEG Baseline":              "1.2.840.10008.1.2.4.50",
        "JPEG Extended":              "1.2.840.10008.1.2.4.51",
        "JPEG Lossless":              "1.2.840.10008.1.2.4.57",
        "JPEG Lossless SV1":          "1.2.840.10008.1.2.4.70",
        "JPEG 2000 Lossless":         "1.2.840.10008.1.2.4.90",
        "JPEG 2000":                  "1.2.840.10008.1.2.4.91",
        "JPEG-LS Lossless":           "1.2.840.10008.1.2.4.80",
        "JPEG-LS Near-Lossless":      "1.2.840.10008.1.2.4.81",
        "RLE Lossless":               "1.2.840.10008.1.2.5",
    ]

    /// Performs DCM2DCM transfer syntax conversion.
    private func executeDcm2Dcm() async {
        let inputPath = paramValue("input-file")
        let targetSyntaxName = paramValue("target-syntax")
        let outputParam = paramValue("output-file")
        let openInViewer = paramValue("open-in-viewer").lowercased() != "false"

        guard !inputPath.isEmpty else {
            appendConsoleOutput("❌ No input DICOM file specified.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            return
        }

        guard !targetSyntaxName.isEmpty else {
            appendConsoleOutput("❌ No target transfer syntax selected.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            return
        }

        guard let targetUID = Self.transferSyntaxNameToUID[targetSyntaxName],
              let targetTS = TransferSyntax.from(uid: targetUID) else {
            appendConsoleOutput("❌ Unknown transfer syntax: \(targetSyntaxName)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            return
        }

        appendConsoleOutput("📁 Reading input file…\n")

        // Read input file with security-scoped access if available
        let data: Data
        let scopedURL = securityScopedURLs["input-file"]
        let accessing = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scopedURL?.stopAccessingSecurityScopedResource() } }

        do {
            let inputURL = scopedURL ?? URL(fileURLWithPath: inputPath)
            data = try Data(contentsOf: inputURL)
        } catch {
            appendConsoleOutput("❌ Failed to read input file: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dcm2dcm", command: commandPreview, exitCode: 1,
                         output: error.localizedDescription)
            return
        }

        do {
            let file = try DICOMFile.read(from: data)
            let sourceUID = file.transferSyntaxUID ?? "1.2.840.10008.1.2.1"
            let sourceName = ImageMetadataHelpers.transferSyntaxLabel(for: sourceUID)

            appendConsoleOutput("  Source transfer syntax: \(sourceName)\n")
            appendConsoleOutput("  Target transfer syntax: \(targetSyntaxName)\n\n")

            if sourceUID == targetUID {
                appendConsoleOutput("ℹ️ Source and target transfer syntaxes are identical — no conversion needed.\n")
                consoleStatus = .idle
                service.setConsoleStatus(.idle)
                addToHistory(toolName: "dcm2dcm", command: commandPreview, exitCode: 0,
                             output: "No conversion needed (same transfer syntax)")
                return
            }

            guard let sourceTS = TransferSyntax.from(uid: sourceUID) else {
                appendConsoleOutput("❌ Unknown source transfer syntax: \(sourceUID)\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                return
            }

            // Check if conversion is supported
            let converter = DICOMCore.TransferSyntaxConverter(
                configuration: TranscodingConfiguration(
                    preferredSyntaxes: [targetTS],
                    allowLossyCompression: !targetTS.isLossless,
                    preservePixelDataFidelity: targetTS.isLossless
                )
            )

            guard converter.canTranscode(from: sourceTS, to: targetTS) else {
                appendConsoleOutput("❌ Conversion from \(sourceName) to \(targetSyntaxName) is not supported.\n")
                appendConsoleOutput("   Hint: Ensure the required codec is available for both source and target syntaxes.\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dcm2dcm", command: commandPreview, exitCode: 1,
                             output: "Unsupported conversion path")
                return
            }

            appendConsoleOutput("🔄 Converting…\n")

            // Serialize the data set to bytes using the source transfer syntax encoding
            let sourceWriter = DICOMWriter(
                byteOrder: sourceTS.byteOrder,
                explicitVR: sourceTS.isExplicitVR
            )
            let dataSetBytes = file.dataSet.write(using: sourceWriter)

            let result = try converter.transcode(
                dataSetData: dataSetBytes,
                from: sourceTS,
                to: targetTS
            )

            // Build the output Part 10 DICOM file using the existing file-level helper
            let sopClassUID = file.dataSet.string(for: .sopClassUID)
                ?? file.fileMetaInformation.string(for: .mediaStorageSOPClassUID)
                ?? "1.2.840.10008.5.1.4.1.1.7"
            let sopInstanceUID = file.dataSet.string(for: .sopInstanceUID)
                ?? file.fileMetaInformation.string(for: .mediaStorageSOPInstanceUID)
                ?? ""
            let outputData = part10Wrap(
                dataset: result.data,
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                transferSyntaxUID: targetUID
            )

            // Determine output URL, preferring security-scoped access for sandbox compliance.
            // The Browse button for output picks a *folder*; the text field holds the full file path.
            // We start security-scoped access on the folder URL so that writing to the child path succeeds.
            let outputScopedURL = securityScopedURLs["output-file"]
            let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
            defer { if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() } }

            let outputURL: URL
            if !outputParam.isEmpty {
                outputURL = URL(fileURLWithPath: outputParam)
            } else {
                // Fallback: derive from input filename
                let inputPathURL = URL(fileURLWithPath: inputPath)
                let stem = inputPathURL.deletingPathExtension().lastPathComponent
                let ext = inputPathURL.pathExtension.isEmpty ? "dcm" : inputPathURL.pathExtension

                if let scopedDir = outputScopedURL {
                    // User browsed to a folder but didn't type a filename — save next to input name
                    outputURL = scopedDir.appendingPathComponent("\(stem)_converted.\(ext)")
                } else {
                    // No browse, no output param — place next to input file
                    outputURL = inputPathURL
                        .deletingLastPathComponent()
                        .appendingPathComponent("\(stem)_converted.\(ext)")
                }
            }
            let outputPath = outputURL.path

            // Ensure the output directory exists
            let outputDir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            // Write converted file
            try outputData.write(to: outputURL)

            let savedSize = ByteCountFormatter.string(fromByteCount: Int64(outputData.count), countStyle: .file)
            let originalSize = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)

            appendConsoleOutput("\n✅ Conversion complete!\n")
            appendConsoleOutput("   Output:   \(outputPath)\n")
            appendConsoleOutput("   Original: \(originalSize) → Converted: \(savedSize)\n")
            if result.isLossless {
                appendConsoleOutput("   Quality:  Lossless\n")
            } else {
                appendConsoleOutput("   Quality:  Lossy\n")
            }

            lastRetrievedFiles = [outputPath]
            lastRetrievedOutputURL = nil

            consoleStatus = .idle
            service.setConsoleStatus(.idle)
            addToHistory(toolName: "dcm2dcm", command: commandPreview, exitCode: 0,
                         output: "Converted \(sourceName) → \(targetSyntaxName)")

            // Open in viewer if requested
            if openInViewer {
                appendConsoleOutput("\n📺 Opening converted file in Viewer…\n")
                onOpenInViewer?(outputPath, nil)
            }

        } catch {
            let desc = error.localizedDescription
            appendConsoleOutput("❌ Conversion failed: \(desc)\n")

            if let transErr = error as? TranscodingError {
                appendConsoleOutput("   Detail: \(transErr.description)\n")
            }

            // Provide a hint when the failure is a sandbox permission issue
            if desc.contains("permission") || desc.contains("not permitted") {
                appendConsoleOutput("   Hint: Use the Browse button to select the output folder so the app can write there.\n")
            }

            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dcm2dcm", command: commandPreview, exitCode: 1,
                         output: desc)
        }
    }

    /// Formats a single generic query result for console display.
    // MARK: - Query Result Formatters

    /// Renders all results as a JSON array string.
    private func formatQueryResultsJSON(_ pairs: [(result: GenericQueryResult, parent: GenericQueryResult?)], level: QueryLevel) -> String {
        var entries: [String] = []
        for pair in pairs {
            var fields: [String] = []
            let r = pair.result
            let ps = pair.parent?.toStudyResult()
            let pp = pair.parent?.toPatientResult()
            if level == .image {
                let i = r.toInstanceResult()
                if let v = i.sopClassUID    { fields.append("    \"sopClassUID\": \"\(jsonEscape(v))\"") }
                if let v = i.sopInstanceUID { fields.append("    \"sopInstanceUID\": \"\(jsonEscape(v))\"") }
                if let v = i.instanceNumber { fields.append("    \"instanceNumber\": \(v)") }
                if let v = i.contentDate    { fields.append("    \"contentDate\": \"\(jsonEscape(v))\"") }
                if let r = i.rows, let c = i.columns { fields.append("    \"dimensions\": \"\(c)x\(r)\"") }
                if let v = i.numberOfFrames { fields.append("    \"numberOfFrames\": \(v)") }
            }
            if level == .series || level == .image {
                let s = r.toSeriesResult()
                if let v = s.seriesDescription { fields.append("    \"seriesDescription\": \"\(jsonEscape(v))\"") }
                if let v = s.modality          { fields.append("    \"modality\": \"\(jsonEscape(v))\"") }
                if let v = s.seriesNumber      { fields.append("    \"seriesNumber\": \(v)") }
                if let v = s.seriesDate        { fields.append("    \"seriesDate\": \"\(jsonEscape(v))\"") }
                if let v = s.numberOfSeriesRelatedInstances { fields.append("    \"instances\": \(v)") }
                if let v = s.seriesInstanceUID { fields.append("    \"seriesInstanceUID\": \"\(jsonEscape(v))\"") }
            }
            if level == .study || level == .series || level == .image {
                let s = r.toStudyResult()
                if let v = s.studyDate ?? ps?.studyDate                           { fields.append("    \"studyDate\": \"\(jsonEscape(v))\"") }
                if let v = s.studyTime ?? ps?.studyTime                           { fields.append("    \"studyTime\": \"\(jsonEscape(v))\"") }
                if let v = s.studyDescription ?? ps?.studyDescription             { fields.append("    \"studyDescription\": \"\(jsonEscape(v))\"") }
                if let v = s.accessionNumber ?? ps?.accessionNumber               { fields.append("    \"accessionNumber\": \"\(jsonEscape(v))\"") }
                if let v = s.modalitiesInStudy ?? ps?.modalitiesInStudy           { fields.append("    \"modalitiesInStudy\": \"\(jsonEscape(v))\"") }
                if let v = s.numberOfStudyRelatedSeries ?? ps?.numberOfStudyRelatedSeries         { fields.append("    \"studySeries\": \(v)") }
                if let v = s.numberOfStudyRelatedInstances ?? ps?.numberOfStudyRelatedInstances   { fields.append("    \"studyImages\": \(v)") }
                if let v = s.studyInstanceUID ?? ps?.studyInstanceUID             { fields.append("    \"studyInstanceUID\": \"\(jsonEscape(v))\"") }
            }
            let p = r.toPatientResult()
            if let v = p.patientName ?? pp?.patientName         { fields.append("    \"patientName\": \"\(jsonEscape(v))\"") }
            if let v = p.patientID ?? pp?.patientID             { fields.append("    \"patientID\": \"\(jsonEscape(v))\"") }
            if let v = p.patientBirthDate ?? pp?.patientBirthDate { fields.append("    \"patientBirthDate\": \"\(jsonEscape(v))\"") }
            if let v = p.patientSex ?? pp?.patientSex           { fields.append("    \"patientSex\": \"\(jsonEscape(v))\"") }
            if level == .patient {
                if let v = p.numberOfPatientRelatedStudies   { fields.append("    \"studies\": \(v)") }
                if let v = p.numberOfPatientRelatedSeries    { fields.append("    \"series\": \(v)") }
                if let v = p.numberOfPatientRelatedInstances { fields.append("    \"instances\": \(v)") }
            }
            entries.append("  {\n" + fields.joined(separator: ",\n") + "\n  }")
        }
        return "[\n" + entries.joined(separator: ",\n") + "\n]\n"
    }

    /// Renders all results as a CSV table.
    private func formatQueryResultsCSV(_ pairs: [(result: GenericQueryResult, parent: GenericQueryResult?)], level: QueryLevel) -> String {
        var header: [String] = []
        if level == .image { header += ["SOPClassUID", "SOPInstanceUID", "InstanceNumber", "ContentDate", "Dimensions", "Frames"] }
        if level == .series || level == .image { header += ["SeriesDescription", "Modality", "SeriesNumber", "SeriesDate", "Instances", "SeriesInstanceUID"] }
        if level == .study || level == .series || level == .image { header += ["StudyDate", "StudyTime", "StudyDescription", "AccessionNumber", "ModalitiesInStudy", "StudySeries", "StudyImages", "StudyInstanceUID"] }
        header += ["PatientName", "PatientID", "PatientBirthDate", "PatientSex"]
        if level == .patient { header += ["Studies", "Series", "Instances"] }

        var lines: [String] = [header.map { csvQuote($0) }.joined(separator: ",")]
        for pair in pairs {
            var row: [String] = []
            let r = pair.result
            let ps = pair.parent?.toStudyResult()
            let pp = pair.parent?.toPatientResult()
            if level == .image {
                let i = r.toInstanceResult()
                row += [csvQuote(i.sopClassUID ?? ""),
                        csvQuote(i.sopInstanceUID ?? ""),
                        csvQuote(i.instanceNumber.map(String.init) ?? ""),
                        csvQuote(i.contentDate ?? ""),
                        csvQuote((i.rows != nil && i.columns != nil) ? "\(i.columns!)x\(i.rows!)" : ""),
                        csvQuote(i.numberOfFrames.map(String.init) ?? "")]
            }
            if level == .series || level == .image {
                let s = r.toSeriesResult()
                row += [csvQuote(s.seriesDescription ?? ""),
                        csvQuote(s.modality ?? ""),
                        csvQuote(s.seriesNumber.map(String.init) ?? ""),
                        csvQuote(s.seriesDate ?? ""),
                        csvQuote(s.numberOfSeriesRelatedInstances.map(String.init) ?? ""),
                        csvQuote(s.seriesInstanceUID ?? "")]
            }
            if level == .study || level == .series || level == .image {
                let s = r.toStudyResult()
                let nSeries = (s.numberOfStudyRelatedSeries ?? ps?.numberOfStudyRelatedSeries).map(String.init) ?? ""
                let nImages = (s.numberOfStudyRelatedInstances ?? ps?.numberOfStudyRelatedInstances).map(String.init) ?? ""
                row += [csvQuote(s.studyDate ?? ps?.studyDate ?? ""),
                        csvQuote(s.studyTime ?? ps?.studyTime ?? ""),
                        csvQuote(s.studyDescription ?? ps?.studyDescription ?? ""),
                        csvQuote(s.accessionNumber ?? ps?.accessionNumber ?? ""),
                        csvQuote(s.modalitiesInStudy ?? ps?.modalitiesInStudy ?? ""),
                        csvQuote(nSeries), csvQuote(nImages),
                        csvQuote(s.studyInstanceUID ?? ps?.studyInstanceUID ?? "")]
            }
            let p = r.toPatientResult()
            row += [csvQuote(p.patientName ?? pp?.patientName ?? ""),
                    csvQuote(p.patientID ?? pp?.patientID ?? ""),
                    csvQuote(p.patientBirthDate ?? pp?.patientBirthDate ?? ""),
                    csvQuote(p.patientSex ?? pp?.patientSex ?? "")]
            if level == .patient {
                row += [csvQuote(p.numberOfPatientRelatedStudies.map(String.init) ?? ""),
                        csvQuote(p.numberOfPatientRelatedSeries.map(String.init) ?? ""),
                        csvQuote(p.numberOfPatientRelatedInstances.map(String.init) ?? "")]
            }
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Renders all results as an XML document.
    private func formatQueryResultsXML(_ pairs: [(result: GenericQueryResult, parent: GenericQueryResult?)], level: QueryLevel) -> String {
        var lines: [String] = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<QueryResults level=\"\(level)\">"]
        for pair in pairs {
            lines.append("  <Result>")
            let r = pair.result
            let ps = pair.parent?.toStudyResult()
            let pp = pair.parent?.toPatientResult()
            if level == .image {
                let i = r.toInstanceResult()
                if let v = i.sopClassUID    { lines.append("    <SOPClassUID>\(xmlEscape(v))</SOPClassUID>") }
                if let v = i.sopInstanceUID { lines.append("    <SOPInstanceUID>\(xmlEscape(v))</SOPInstanceUID>") }
                if let v = i.instanceNumber { lines.append("    <InstanceNumber>\(v)</InstanceNumber>") }
                if let v = i.contentDate    { lines.append("    <ContentDate>\(xmlEscape(v))</ContentDate>") }
                if let rr = i.rows, let c = i.columns { lines.append("    <Dimensions>\(c)x\(rr)</Dimensions>") }
                if let v = i.numberOfFrames { lines.append("    <NumberOfFrames>\(v)</NumberOfFrames>") }
            }
            if level == .series || level == .image {
                let s = r.toSeriesResult()
                if let v = s.seriesDescription { lines.append("    <SeriesDescription>\(xmlEscape(v))</SeriesDescription>") }
                if let v = s.modality          { lines.append("    <Modality>\(xmlEscape(v))</Modality>") }
                if let v = s.seriesNumber      { lines.append("    <SeriesNumber>\(v)</SeriesNumber>") }
                if let v = s.seriesDate        { lines.append("    <SeriesDate>\(xmlEscape(v))</SeriesDate>") }
                if let v = s.numberOfSeriesRelatedInstances { lines.append("    <Instances>\(v)</Instances>") }
                if let v = s.seriesInstanceUID { lines.append("    <SeriesInstanceUID>\(xmlEscape(v))</SeriesInstanceUID>") }
            }
            if level == .study || level == .series || level == .image {
                let s = r.toStudyResult()
                if let v = s.studyDate ?? ps?.studyDate             { lines.append("    <StudyDate>\(xmlEscape(v))</StudyDate>") }
                if let v = s.studyTime ?? ps?.studyTime             { lines.append("    <StudyTime>\(xmlEscape(v))</StudyTime>") }
                if let v = s.studyDescription ?? ps?.studyDescription { lines.append("    <StudyDescription>\(xmlEscape(v))</StudyDescription>") }
                if let v = s.accessionNumber ?? ps?.accessionNumber { lines.append("    <AccessionNumber>\(xmlEscape(v))</AccessionNumber>") }
                if let v = s.modalitiesInStudy ?? ps?.modalitiesInStudy { lines.append("    <ModalitiesInStudy>\(xmlEscape(v))</ModalitiesInStudy>") }
                if let v = s.numberOfStudyRelatedSeries ?? ps?.numberOfStudyRelatedSeries         { lines.append("    <StudySeries>\(v)</StudySeries>") }
                if let v = s.numberOfStudyRelatedInstances ?? ps?.numberOfStudyRelatedInstances   { lines.append("    <StudyImages>\(v)</StudyImages>") }
                if let v = s.studyInstanceUID ?? ps?.studyInstanceUID { lines.append("    <StudyInstanceUID>\(xmlEscape(v))</StudyInstanceUID>") }
            }
            let p = r.toPatientResult()
            if let v = p.patientName ?? pp?.patientName           { lines.append("    <PatientName>\(xmlEscape(v))</PatientName>") }
            if let v = p.patientID ?? pp?.patientID               { lines.append("    <PatientID>\(xmlEscape(v))</PatientID>") }
            if let v = p.patientBirthDate ?? pp?.patientBirthDate { lines.append("    <PatientBirthDate>\(xmlEscape(v))</PatientBirthDate>") }
            if let v = p.patientSex ?? pp?.patientSex             { lines.append("    <PatientSex>\(xmlEscape(v))</PatientSex>") }
            if level == .patient {
                if let v = p.numberOfPatientRelatedStudies   { lines.append("    <Studies>\(v)</Studies>") }
                if let v = p.numberOfPatientRelatedSeries    { lines.append("    <Series>\(v)</Series>") }
                if let v = p.numberOfPatientRelatedInstances { lines.append("    <Instances>\(v)</Instances>") }
            }
            lines.append("  </Result>")
        }
        lines.append("</QueryResults>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Renders results as HL7 v2.x ADT^A28 / ZDS segment messages (one per result).
    private func formatQueryResultsHL7(_ pairs: [(result: GenericQueryResult, parent: GenericQueryResult?)], level: QueryLevel) -> String {
        let now = Date()
        let dtFormatter = DateFormatter()
        dtFormatter.dateFormat = "yyyyMMddHHmmss"
        let msgDateTime = dtFormatter.string(from: now)
        var messages: [String] = []
        for (idx, pair) in pairs.enumerated() {
            let r = pair.result
            let ps = pair.parent?.toStudyResult()
            let pp = pair.parent?.toPatientResult()
            let p  = r.toPatientResult()
            let s  = r.toStudyResult()
            let patName   = p.patientName ?? pp?.patientName ?? "UNKNOWN"
            let patID     = p.patientID ?? pp?.patientID ?? ""
            let patDOB    = p.patientBirthDate ?? pp?.patientBirthDate ?? ""
            let patSex    = p.patientSex ?? pp?.patientSex ?? ""
            let studyUID  = s.studyInstanceUID ?? ps?.studyInstanceUID ?? ""
            let studyDate = s.studyDate ?? ps?.studyDate ?? ""
            let accession = s.accessionNumber ?? ps?.accessionNumber ?? ""
            let modalities = s.modalitiesInStudy ?? ps?.modalitiesInStudy ?? ""
            let studyDesc  = s.studyDescription ?? ps?.studyDescription ?? ""
            let msgID = String(format: "DICOMSTUDIO%07d", idx + 1)
            var segs: [String] = []
            segs.append("MSH|^~\\&|DICOMSTUDIO||DICOMSERVER||\(msgDateTime)||ADT^A28|\(msgID)|P|2.5")
            segs.append("PID|1||\(hl7Escape(patID))|||\(hl7Escape(patName))||\(hl7Escape(patDOB))|\(hl7Escape(patSex))")
            // ZDS: study information (HL7 Z-segment for DICOM)
            segs.append("ZDS|\(hl7Escape(studyUID))|\(hl7Escape(accession))|\(hl7Escape(studyDate))|\(hl7Escape(modalities))|\(hl7Escape(studyDesc))")
            if level == .series || level == .image {
                let sr = r.toSeriesResult()
                let serUID  = sr.seriesInstanceUID ?? ""
                let serMod  = sr.modality ?? ""
                let serDesc = sr.seriesDescription ?? ""
                let serNum  = sr.seriesNumber.map(String.init) ?? ""
                segs.append("ZSE|\(hl7Escape(serUID))|\(hl7Escape(serNum))|\(hl7Escape(serMod))|\(hl7Escape(serDesc))")
            }
            if level == .image {
                let ir = r.toInstanceResult()
                segs.append("ZIM|\(hl7Escape(ir.sopInstanceUID ?? ""))|\(hl7Escape(ir.sopClassUID ?? ""))|\(ir.instanceNumber ?? 0)")
            }
            messages.append(segs.joined(separator: "\n"))
        }
        return messages.joined(separator: "\n---\n") + "\n"
    }

    private func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\\\\\\\\").replacingOccurrences(of: "\"", with: "\\\\\"")
    }
    private func csvQuote(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
    private func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
    private func hl7Escape(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\F\\").replacingOccurrences(of: "^", with: "\\S\\")
    }

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
