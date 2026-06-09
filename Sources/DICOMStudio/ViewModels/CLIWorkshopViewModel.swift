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

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

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

    // ⚠️ TESTING-ONLY — terminal-vs-app parity check for the selected tool (see
    // CLIToolTerminalCompare.swift). Requires the App Sandbox to be disabled.
    // REMOVE BEFORE PRODUCTION (memory: dicom-info-terminal-compare-testonly).
    var isRunningTerminalCompare: Bool = false
    var terminalCompareResult: CLIToolCompareResult?

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

    // MARK: - UPS Transaction UID Cache
    /// Stores the Transaction UID used when claiming each workitem (IN PROGRESS).
    /// Per PS3.18 §11.5.2, the server never returns the Transaction UID in
    /// Retrieve Workitem responses — it acts as an access lock.  We must
    /// remember it ourselves for subsequent COMPLETED / CANCELED transitions.
    /// Key = Workitem UID, Value = Transaction UID.
    private var upsTransactionUIDs: [String: String] = [:]

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
        let hostVal = paramValue("host")
        let portVal = paramValue("port")
        let calledAET = paramValue("called-aet")
        let callingAET = paramValue("aet")
        if !hostVal.isEmpty { UserDefaults.standard.set(hostVal, forKey: DefaultServerKeys.host) }
        if !portVal.isEmpty { UserDefaults.standard.set(portVal, forKey: DefaultServerKeys.port) }
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

    /// Switches to a category tab and refreshes the UI by selecting that
    /// category's first tool — so the parameter form, command preview, and
    /// console all update to the new selection (rather than showing stale state).
    public func selectCategory(_ tab: CLIWorkshopTab) {
        activeTab = tab
        if tab == .listener {
            selectTool(id: nil)
        } else {
            selectTool(id: toolsForActiveTab().first?.id)
        }
    }

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
        // Refresh the output side: drop any TESTING-ONLY terminal-compare result
        // from the previously selected tool.
        terminalCompareResult = nil
        isRunningTerminalCompare = false
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
                    updateParameterValueSilent(parameterID: "aet", value: callingAET)
                }
            }
            // If a saved server is selected, override with its values;
            // otherwise the persistent defaults (applied above) remain.
            if let serverID = selectedSavedServerID,
               let server = savedServerProfiles.first(where: { $0.id == serverID }),
               hasHostParam {
                updateParameterValueSilent(parameterID: "host", value: server.host)
                let port = server.port > 0 ? server.port : 11112
                updateParameterValueSilent(parameterID: "port", value: String(port))
                updateParameterValueSilent(parameterID: "aet", value: server.localAETitle)
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
        let port = server.port > 0 ? server.port : 11112
        updateParameterValue(parameterID: "host", value: server.host)
        updateParameterValue(parameterID: "port", value: String(port))
        updateParameterValue(parameterID: "aet", value: server.localAETitle)
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
    ///
    /// When the security-scoped URL for `parameterID` is a directory (e.g. the user
    /// browsed for a folder), the scope is started on the directory and the individual
    /// file at `path` is read within that scope.
    public func readFileData(at path: String, parameterID: String = "files") throws -> Data {
        if let scopedURL = securityScopedURLs[parameterID] {
            let accessing = scopedURL.startAccessingSecurityScopedResource()
            defer {
                if accessing { scopedURL.stopAccessingSecurityScopedResource() }
            }
            // If the scoped URL is a directory or differs from the target path,
            // read the actual file at `path` (which is covered by the directory scope).
            let fileURL = URL(fileURLWithPath: path)
            if scopedURL.path == path {
                return try Data(contentsOf: scopedURL)
            } else {
                return try Data(contentsOf: fileURL)
            }
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
        return base.filter { satisfiesVisibility($0) }
    }

    /// Advanced parameters that are kept out of the main grid in Beginner mode so
    /// they can be shown in a collapsible "Advanced options" section — this keeps
    /// every available flag reachable in the UI without cluttering the default
    /// view. Empty in Advanced mode, where all parameters already appear.
    public func advancedParameters() -> [CLIParameterDefinition] {
        guard experienceMode == .beginner else { return [] }
        return parameterDefinitions.filter { $0.isAdvanced && satisfiesVisibility($0) }
    }

    /// Evaluates a parameter's `visibleWhen` condition against the current values.
    private func satisfiesVisibility(_ param: CLIParameterDefinition) -> Bool {
        guard let condition = param.visibleWhen else { return true }
        let currentValue = paramValue(condition.parameterId)
        let effectiveValue = currentValue.isEmpty
            ? parameterDefinitions.first(where: { $0.id == condition.parameterId })?.defaultValue ?? ""
            : currentValue
        return condition.values.contains(effectiveValue)
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

    // MARK: - dicom-json Execution

    /// Converts between DICOM and JSON (DICOM JSON Model / DICOMweb JSON) in-process,
    /// mirroring the dicom-json CLI using DICOMWeb's DICOMJSONEncoder/DICOMJSONDecoder.
    private func executeDicomJSON() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-json", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let reverse = paramValue("reverse") == "true"
        let pretty = paramValue("pretty") == "true"
        let noSortKeys = paramValue("no-sort-keys") == "true"
        let includeEmpty = paramValue("include-empty") == "true"
        let metadataOnly = paramValue("metadata-only") == "true"
        let verbose = paramValue("verbose") == "true"
        let format = paramValue("format").isEmpty ? "standard" : paramValue("format")
        let bulkDataURLString = paramValue("bulk-data-url")
        let inlineThresholdValue = Int(paramValue("inline-threshold")) ?? 1024

        // --filter-tag is an array field; split on newlines/commas-as-separator-lines.
        let filterTags: [String] = paramValue("filter-tag")
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Resolve input access.
        let inputScopedURL = securityScopedURLs["inputPath"]
        let inputAccessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if inputAccessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)

        // Resolve output target.
        let outputPathParam = paramValue("output")
        let hasOutput = !outputPathParam.isEmpty
        let outputScopedURL = securityScopedURLs["output"]
        let outputAccessing = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if outputAccessing { outputScopedURL?.stopAccessingSecurityScopedResource() } }
        let resolvedOutputURL: URL? = hasOutput ? (outputScopedURL ?? URL(fileURLWithPath: outputPathParam)) : nil

        let formatFileSize: @Sendable (Int) -> String = { bytes in
            let kb = Double(bytes) / 1024.0
            let mb = kb / 1024.0
            if mb >= 1 { return String(format: "%.2f MB", mb) }
            if kb >= 1 { return String(format: "%.2f KB", kb) }
            return "\(bytes) bytes"
        }

        struct JSONToolError: Error { let message: String }

        // Parse a "GGGG,EEEE" hex tag string.
        let parseHexTag: @Sendable (String) -> Tag? = { string in
            let comps = string.split(separator: ",")
            guard comps.count == 2,
                  let group = UInt16(comps[0].trimmingCharacters(in: .whitespaces), radix: 16),
                  let element = UInt16(comps[1].trimmingCharacters(in: .whitespaces), radix: 16) else {
                return nil
            }
            return Tag(group: group, element: element)
        }

        let (output, exitCode): (String, Int) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var log = ""
            do {
                let inputData = try Data(contentsOf: inputURL)
                if verbose {
                    log += "Input:  \(inputPath)\n"
                    log += "Mode:   \(reverse ? "JSON -> DICOM" : "DICOM -> JSON")\n"
                    log += "Read input file: \(formatFileSize(inputData.count))\n\n"
                }

                if reverse {
                    // JSON -> DICOM
                    let decoderConfig = DICOMJSONDecoder.Configuration(
                        allowMissingVR: true,
                        fetchBulkData: false,
                        bulkDataHandler: nil
                    )
                    let decoder = DICOMJSONDecoder(configuration: decoderConfig)
                    let elements = try decoder.decode(inputData)
                    if verbose { log += "Decoded JSON: \(elements.count) elements\n" }

                    let dataSet = DataSet(elements: elements)
                    let transferSyntaxUID = dataSet[Tag.transferSyntaxUID]?.stringValue ?? "1.2.840.10008.1.2.1"
                    let dicomFile = DICOMFile.create(dataSet: dataSet, transferSyntaxUID: transferSyntaxUID)
                    let dicomData = try dicomFile.write()

                    if hasOutput {
                        // Sandbox/TCC-resilient: prefer the picker's scoped URL; else try the
                        // typed path; on failure fall back to ~/Downloads/DICOMStudio + note.
                        let res = try OutputAccess.write(dicomData, toPath: outputPathParam,
                                                         scopedURL: outputScopedURL, subfolder: "dicom-json")
                        log += "Wrote DICOM file: \(formatFileSize(dicomData.count))\n"
                        log += "Output: \(res.url.path)\n"
                        if let note = res.note { log += note + "\n" }
                        log += "\u{2713} Conversion complete\n"
                    } else {
                        log += "Error: --output is required when converting JSON -> DICOM (binary output cannot be printed to console).\n"
                        return (log, 1)
                    }
                    return (log, 0)
                } else {
                    // DICOM -> JSON
                    let dicomFile = try DICOMFile.read(from: inputData, force: false)
                    if verbose { log += "Parsed DICOM: \(dicomFile.dataSet.allElements.count) elements\n" }

                    var elements = dicomFile.dataSet.allElements

                    if !filterTags.isEmpty {
                        var tagSet = Set<Tag>()
                        for tagString in filterTags {
                            if let entry = DataElementDictionary.lookup(keyword: tagString) {
                                tagSet.insert(entry.tag)
                            } else if let tag = parseHexTag(tagString) {
                                tagSet.insert(tag)
                            } else {
                                throw JSONToolError(message: "Invalid tag: \(tagString). Expected a keyword (e.g. PatientName) or GGGG,EEEE.")
                            }
                        }
                        elements = elements.filter { tagSet.contains($0.tag) }
                        if verbose { log += "Filtered to \(elements.count) elements\n" }
                    }

                    if metadataOnly {
                        elements = elements.filter { $0.tag != Tag.pixelData }
                    }

                    let bulkDataBaseURL: URL? = bulkDataURLString.isEmpty ? nil : URL(string: bulkDataURLString)

                    let encoderConfig = DICOMJSONEncoder.Configuration(
                        includeEmptyValues: includeEmpty,
                        inlineBinaryThreshold: inlineThresholdValue > 0 ? inlineThresholdValue : nil,
                        bulkDataBaseURL: bulkDataBaseURL,
                        prettyPrinted: pretty,
                        sortedKeys: !noSortKeys
                    )
                    let encoder = DICOMJSONEncoder(configuration: encoderConfig)
                    let jsonData = try encoder.encode(elements)

                    if verbose {
                        log += "Encoded to JSON (\(format)): \(formatFileSize(jsonData.count))\n"
                    }

                    if hasOutput {
                        let res = try OutputAccess.write(jsonData, toPath: outputPathParam,
                                                         scopedURL: outputScopedURL, subfolder: "dicom-json")
                        log += "Wrote output file: \(formatFileSize(jsonData.count))\n"
                        log += "Output: \(res.url.path)\n"
                        if let note = res.note { log += note + "\n" }
                        log += "\u{2713} Conversion complete\n"
                    } else {
                        // No output path: print JSON to the console.
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "<non-UTF8 JSON>"
                        if verbose { log += "\n" }
                        log += jsonString
                        if !log.hasSuffix("\n") { log += "\n" }
                    }
                    return (log, 0)
                }
            } catch let err as JSONToolError {
                return (log + "Error: \(err.message)\n", 1)
            } catch {
                return (log + "Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-json", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-xml Execution

    /// Converts between DICOM and the DICOM Native XML Model (PS3.19) in-process.
    ///
    /// Mirrors the `dicom-xml` CLI: DICOM → XML via `DICOMXMLEncoder` and
    /// XML → DICOM (`--reverse`) via `DICOMXMLDecoder`. Supports --pretty,
    /// --no-keywords, --include-empty, --inline-threshold, --bulk-data-url,
    /// --metadata-only, --filter-tag and --verbose.
    private func executeDicomXML() async {
        let inputPath = paramValue("input")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-xml", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let reverse = paramValue("reverse") == "true"
        let pretty = paramValue("pretty") == "true"
        let noKeywords = paramValue("no-keywords") == "true"
        let includeEmpty = paramValue("include-empty") == "true"
        let metadataOnly = paramValue("metadata-only") == "true"
        let verbose = paramValue("verbose") == "true"
        let bulkDataURLString = paramValue("bulk-data-url")
        let inlineThreshold = Int(paramValue("inline-threshold")) ?? 1024

        // --filter-tag is an array field; one tag per line. Do NOT split on commas —
        // a tag is written `GGGG,EEEE`, so comma-splitting `0008,0060` would corrupt it
        // into "0008"+"0060" and match nothing (the empty-output bug). Matches the
        // dicom-json path and the CLI, which split on newlines only.
        let filterRaw = paramValue("filter-tag")
        let filterTags: [String] = filterRaw
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Determine output path (mirrors the CLI default-extension logic).
        var outputPath = paramValue("output")
        if outputPath.isEmpty {
            let inputURL = URL(fileURLWithPath: inputPath)
            outputPath = inputURL.deletingPathExtension()
                .appendingPathExtension(reverse ? "dcm" : "xml").path
        }

        // Sandbox access.
        let inputScopedURL = securityScopedURLs["input"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        // Sandbox/TCC-resilient output: prefer the picker's scoped URL; else probe the
        // typed path and, if it's not writable (TCC), redirect to ~/Downloads/DICOMStudio.
        let (outputURL, outRedirectNote) = OutputAccess.resolveWritableURL(
            forPath: outputPath, scopedURL: outputScopedURL, subfolder: "dicom-xml")
        if let note = outRedirectNote { appendConsoleOutput(note + "\n") }

        if verbose {
            appendConsoleOutput("Input:  \(inputURL.path)\n")
            appendConsoleOutput("Output: \(outputURL.path)\n")
            appendConsoleOutput("Mode:   \(reverse ? "XML → DICOM" : "DICOM → XML")\n\n")
        }

        let (output, exitCode) = await Task.detached(priority: .userInitiated) {
            () -> (String, Int) in
            var log = ""
            func fmtSize(_ bytes: Int) -> String {
                let kb = Double(bytes) / 1024.0
                let mb = kb / 1024.0
                if mb >= 1 { return String(format: "%.2f MB", mb) }
                if kb >= 1 { return String(format: "%.2f KB", kb) }
                return "\(bytes) bytes"
            }
            do {
                let inputData = try Data(contentsOf: inputURL)
                if verbose {
                    log += "Read input file: \(fmtSize(inputData.count))\n"
                }

                if reverse {
                    // --- XML → DICOM ---
                    let decoderConfig = DICOMXMLDecoder.Configuration(
                        allowMissingVR: true,
                        fetchBulkData: false,
                        bulkDataHandler: nil
                    )
                    let decoder = DICOMXMLDecoder(configuration: decoderConfig)
                    let elements = try decoder.decode(inputData)
                    if verbose {
                        log += "Decoded XML: \(elements.count) elements\n"
                    }

                    let dataSet = DataSet(elements: elements)
                    let transferSyntaxUID = dataSet[Tag.transferSyntaxUID]?.stringValues?.first
                        ?? "1.2.840.10008.1.2.1"
                    let dicomFile = DICOMFile.create(
                        dataSet: dataSet,
                        transferSyntaxUID: transferSyntaxUID
                    )
                    let dicomData = try dicomFile.write()
                    try dicomData.write(to: outputURL)
                    log += "✓ Wrote DICOM file: \(outputURL.path) (\(fmtSize(dicomData.count)))\n"
                    return (log, 0)
                } else {
                    // --- DICOM → XML ---
                    let dicomFile = try DICOMFile.read(from: inputData, force: false)
                    if verbose {
                        log += "Parsed DICOM: \(dicomFile.dataSet.allElements.count) elements\n"
                    }

                    var elements = dicomFile.dataSet.allElements

                    // --filter-tag (keyword or GGGG,EEEE).
                    if !filterTags.isEmpty {
                        var tagSet = Set<Tag>()
                        for tagString in filterTags {
                            if let entry = DataElementDictionary.lookup(keyword: tagString) {
                                tagSet.insert(entry.tag)
                            } else {
                                let comps = tagString.split(separator: ",")
                                if comps.count == 2,
                                   let group = UInt16(comps[0].trimmingCharacters(in: .whitespaces), radix: 16),
                                   let elem = UInt16(comps[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                                    tagSet.insert(Tag(group: group, element: elem))
                                } else {
                                    return ("Error: Invalid tag: \(tagString)\n", 1)
                                }
                            }
                        }
                        elements = elements.filter { tagSet.contains($0.tag) }
                        if verbose { log += "Filtered to \(elements.count) elements\n" }
                    }

                    // --metadata-only excludes PixelData.
                    if metadataOnly {
                        elements = elements.filter { $0.tag != Tag.pixelData }
                    }

                    let bulkDataBaseURL: URL? = bulkDataURLString.isEmpty
                        ? nil : URL(string: bulkDataURLString)

                    let encoderConfig = DICOMXMLEncoder.Configuration(
                        includeEmptyValues: includeEmpty,
                        inlineBinaryThreshold: inlineThreshold > 0 ? inlineThreshold : nil,
                        bulkDataBaseURL: bulkDataBaseURL,
                        prettyPrinted: pretty,
                        includeKeywords: !noKeywords
                    )
                    let encoder = DICOMXMLEncoder(configuration: encoderConfig)
                    let xmlData = try encoder.encode(elements)
                    if verbose {
                        log += "Encoded to XML: \(fmtSize(xmlData.count))\n"
                    }
                    try xmlData.write(to: outputURL)
                    log += "✓ Wrote XML file: \(outputURL.path) (\(fmtSize(xmlData.count)))\n"
                    return (log, 0)
                }
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-xml", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

// MARK: - dicom-uid Execution

/// Performs DICOM UID generation, validation, registry lookup, and in-file
/// regeneration in-process using DICOMCore `UIDGenerator`, DICOMDictionary
/// `UIDDictionary`, and DICOMKit `DICOMFile`. Mirrors the `dicom-uid` CLI
/// (subcommands: generate, validate, lookup, regenerate).
private func executeDicomUID() async {
    let subcommand = paramValue("subcommand").isEmpty ? "generate" : paramValue("subcommand")
    switch subcommand {
    case "validate":
        await executeDicomUIDValidate()
    case "lookup":
        await executeDicomUIDLookup()
    case "regenerate":
        await executeDicomUIDRegenerate()
    default:
        await executeDicomUIDGenerate()
    }
}

/// `dicom-uid generate` — create one or more fresh UIDs.
private func executeDicomUIDGenerate() async {
    let countStr = paramValue("count").isEmpty ? "1" : paramValue("count")
    let typeRaw = paramValue("type")
    let rootRaw = paramValue("root").trimmingCharacters(in: .whitespacesAndNewlines)
    let asJSON = paramValue("json") == "true"

    guard let count = Int(countStr), count >= 1 else {
        appendConsoleOutput("Error: Count must be at least 1.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: 1, output: "Invalid count")
        return
    }
    guard count <= 1000 else {
        appendConsoleOutput("Error: Count must not exceed 1000.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: 1, output: "Count exceeds 1000")
        return
    }
    let type: String? = (typeRaw.isEmpty || typeRaw.lowercased() == "generic") ? nil : typeRaw
    let root: String? = rootRaw.isEmpty ? nil : rootRaw

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        // Generate via the shared DICOMKit UIDManager (same code the CLI runs).
        let uids = UIDManager().generateUIDs(count: count, root: root, type: type)

        if asJSON {
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: uids,
                    options: [.prettyPrinted, .sortedKeys]
                )
                let str = String(data: jsonData, encoding: .utf8) ?? "[]"
                return (str + "\n", 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        } else {
            return (uids.joined(separator: "\n") + "\n", 0)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

/// `dicom-uid validate` — validate UIDs from arguments and/or a DICOM file
/// against PS3.5 Section 9 rules.
private func executeDicomUIDValidate() async {
    let rawUIDs = paramValue("uids")
    let argUIDs = rawUIDs
        .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" })
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    let filePath = paramValue("file")
    let checkRegistry = paramValue("check-registry") == "true"
    let asJSON = paramValue("json") == "true"

    guard !argUIDs.isEmpty || !filePath.isEmpty else {
        appendConsoleOutput("Error: Provide UIDs as arguments or use a DICOM file to validate.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: 1, output: "No UIDs or file")
        return
    }

    let inputScopedURL = securityScopedURLs["file"]
    let accessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
    let fileURL: URL? = filePath.isEmpty ? nil : (inputScopedURL ?? URL(fileURLWithPath: filePath))

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        // Validate via the shared DICOMKit UIDManager (PS3.5 Section 9 rules).
        // (Qualify the result type: DICOMStudio has its own UIDValidationResult.)
        let manager = UIDManager()
        var results: [DICOMKit.UIDValidationResult] = []
        for uid in argUIDs { results.append(manager.validateUID(uid)) }

        if let url = fileURL {
            do {
                let data = try Data(contentsOf: url)
                let file = try DICOMFile.read(from: data, force: false)
                for element in file.dataSet.allElements where element.vr == .UI {
                    if let uidString = file.dataSet.string(for: element.tag) {
                        let trimmed = uidString.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
                        if !trimmed.isEmpty { results.append(manager.validateUID(trimmed)) }
                    }
                }
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }

        if asJSON {
            let jsonResults: [[String: Any]] = results.map { r in
                var dict: [String: Any] = ["uid": r.uid, "valid": r.isValid]
                if !r.errors.isEmpty { dict["errors"] = r.errors }
                if let name = r.registryName { dict["registryName"] = name }
                return dict
            }
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonResults,
                    options: [.prettyPrinted, .sortedKeys]
                )
                return ((String(data: jsonData, encoding: .utf8) ?? "[]") + "\n", 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        } else {
            var lines: [String] = []
            var allValid = true
            for r in results {
                if r.isValid {
                    var line = "\u{2705} \(r.uid)"
                    if checkRegistry, let name = r.registryName { line += " [\(name)]" }
                    lines.append(line)
                } else {
                    allValid = false
                    lines.append("\u{274C} \(r.uid)")
                    for error in r.errors { lines.append("   - \(error)") }
                }
            }
            return (lines.joined(separator: "\n") + "\n", allValid ? 0 : 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

/// `dicom-uid lookup` — look up a single UID, or list/search registry entries.
private func executeDicomUIDLookup() async {
    let uid = paramValue("lookup-uid").trimmingCharacters(in: .whitespacesAndNewlines)
    let listAll = paramValue("list-all") == "true"
    let typeFilter = paramValue("lookup-type")
    let search = paramValue("search").trimmingCharacters(in: .whitespacesAndNewlines)
    let asJSON = paramValue("json") == "true"

    guard !uid.isEmpty || listAll || !search.isEmpty else {
        appendConsoleOutput("Error: Provide a UID, enable List All, or enter a Search term.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: 1, output: "No lookup criteria")
        return
    }

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        // Use the shared DICOMKit UIDManager type-description.
        let typeDescription: (UIDType) -> String = UIDManager.uidTypeDescription

        if !uid.isEmpty {
            guard let entry = UIDDictionary.lookup(uid: uid) else {
                return ("UID not found in DICOM registry (not a standard Transfer Syntax or SOP Class UID): \(uid)\n", 1)
            }
            if asJSON {
                let dict: [String: String] = [
                    "uid": uid,
                    "name": entry.name,
                    "type": typeDescription(entry.type),
                ]
                do {
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: dict,
                        options: [.prettyPrinted, .sortedKeys]
                    )
                    return ((String(data: jsonData, encoding: .utf8) ?? "{}") + "\n", 0)
                } catch {
                    return ("Error: \(error.localizedDescription)\n", 1)
                }
            } else {
                let text = "UID:  \(uid)\nName: \(entry.name)\nType: \(typeDescription(entry.type))\n"
                return (text, 0)
            }
        }

        // List / search.
        var entries = UIDDictionary.allEntries
        if !typeFilter.isEmpty {
            switch typeFilter.lowercased() {
            case "transfer-syntax", "transfersyntax":
                entries = UIDDictionary.transferSyntaxes
            case "sop-class", "sopclass":
                entries = UIDDictionary.sopClasses
            default:
                return ("Unknown type filter '\(typeFilter)'. Valid types: transfer-syntax, sop-class\n", 1)
            }
        }
        if !search.isEmpty {
            let lower = search.lowercased()
            entries = entries.filter {
                $0.name.lowercased().contains(lower) || $0.uid.lowercased().contains(lower)
            }
        }
        if entries.isEmpty {
            return ("No UIDs found matching criteria\n", 1)
        }
        if asJSON {
            let jsonEntries: [[String: String]] = entries.map {
                ["uid": $0.uid, "name": $0.name, "type": typeDescription($0.type)]
            }
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonEntries,
                    options: [.prettyPrinted, .sortedKeys]
                )
                return ((String(data: jsonData, encoding: .utf8) ?? "[]") + "\n", 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        } else {
            var lines = entries.map { "\($0.uid)  \($0.name)  (\(typeDescription($0.type)))" }
            lines.append("")
            lines.append("\(entries.count) UIDs found")
            return (lines.joined(separator: "\n") + "\n", 0)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

/// `dicom-uid regenerate` — replace instance UIDs in a DICOM file with fresh
/// ones (preserving well-known UIDs). Single-file subset of the CLI.
private func executeDicomUIDRegenerate() async {
    let inputPath = paramValue("inputPath")
    guard !inputPath.isEmpty else {
        appendConsoleOutput("Error: At least one input file is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: 1, output: "Missing input path")
        return
    }
    let outputPath = paramValue("output").trimmingCharacters(in: .whitespacesAndNewlines)
    let rootRaw = paramValue("root").trimmingCharacters(in: .whitespacesAndNewlines)
    let root: String? = rootRaw.isEmpty ? nil : rootRaw
    let dryRun = paramValue("dry-run") == "true"
    let verbose = paramValue("verbose") == "true"
    let exportMap = paramValue("export-map").trimmingCharacters(in: .whitespacesAndNewlines)

    let inputScopedURL = securityScopedURLs["inputPath"]
    let inAccessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer { if inAccessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
    let inURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)

    let outputScopedURL = securityScopedURLs["output"]
    let outAccessing = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer { if outAccessing { outputScopedURL?.stopAccessingSecurityScopedResource() } }

    let mapScopedURL = securityScopedURLs["export-map"]
    let mapAccessing = mapScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer { if mapAccessing { mapScopedURL?.stopAccessingSecurityScopedResource() } }

    // Resolve effective output URL/path on the main actor (sandbox URLs).
    let resolvedOutURL: URL = {
        if let scoped = outputScopedURL { return scoped }
        if !outputPath.isEmpty { return URL(fileURLWithPath: outputPath) }
        return inURL
    }()
    let resolvedOutDescription = outputPath.isEmpty ? inputPath : outputPath
    let resolvedMapURL: URL? = {
        if let scoped = mapScopedURL { return scoped }
        if !exportMap.isEmpty { return URL(fileURLWithPath: exportMap) }
        return nil
    }()

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        // Use the shared DICOMKit UIDManager tag-name helper.
        func tagName(for tag: Tag) -> String { UIDManager.tagName(for: tag) }

        do {
            let data = try Data(contentsOf: inURL)
            let file = try DICOMFile.read(from: data, force: false)

            if dryRun {
                // Shared preview (DICOMKit UIDManager) → byte-identical to the CLI's dry-run
                // stdout. `Processing:` is verbose-only (the CLI prints it to stderr); no
                // "Dry run complete" line (the CLI doesn't emit one) so the two stay text-exact.
                var lines: [String] = []
                if verbose { lines.append("Processing: \(inURL.lastPathComponent)") }
                lines.append(contentsOf: UIDManager.regenerationPreviewLines(for: file.dataSet))
                return (lines.joined(separator: "\n") + "\n", 0)
            }

            // Regenerate via the shared engine (no-write transform); the result is
            // written below through the app's sandbox-aware OutputAccess path.
            var existingMappings: [String: String] = [:]
            let (newData, mappings) = try UIDManager().regenerateData(
                data, root: root, maintainRelationships: false, existingMappings: &existingMappings)

            // Sandbox/TCC-resilient write (prefer scoped URL; else fall back to ~/Downloads).
            let writeRes = try OutputAccess.write(newData, toPath: resolvedOutURL.path,
                                                  scopedURL: outputScopedURL, subfolder: "UIDRegenerate")

            var lines: [String] = []
            if verbose {
                lines.append("Processing: \(inURL.lastPathComponent)")
                for m in mappings {
                    lines.append("  \(m.tagName): \(m.oldUID) \u{2192} \(m.newUID)")
                }
            }
            if let note = writeRes.note { lines.append(note) }
            lines.append("Wrote: \(writeRes.url.path) (\(mappings.count) UIDs regenerated)")

            if resolvedMapURL != nil {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let mapData = try encoder.encode(mappings)
                let mapRes = try OutputAccess.write(mapData, toPath: resolvedMapURL?.path ?? "",
                                                    scopedURL: mapScopedURL, subfolder: "UIDRegenerate")
                if let note = mapRes.note { lines.append(note) }
                lines.append("UID mapping exported to: \(mapRes.url.path)")
            }

            return (lines.joined(separator: "\n") + "\n", 0)
        } catch {
            return ("Error: \(error.localizedDescription)\n", 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-uid", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

private func executeDicomDcmdir() async {
        let subcommand = paramValue("subcommand").isEmpty ? "create" : paramValue("subcommand")
        switch subcommand {
        case "create":   await executeDicomDcmdirCreate()
        case "validate": await executeDicomDcmdirValidate()
        case "dump":     await executeDicomDcmdirDump()
        case "update":   await executeDicomDcmdirUpdate()
        default:
            appendConsoleOutput("Error: Unknown subcommand '\(subcommand)'. Use create, validate, dump, or update.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: 1, output: "Unknown subcommand")
        }
    }

    // MARK: dicom-dcmdir create

    private func executeDicomDcmdirCreate() async {
        let inputDirectory = paramValue("inputDirectory")
        guard !inputDirectory.isEmpty else {
            appendConsoleOutput("Error: Input directory is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: 1, output: "Missing input directory")
            return
        }

        let outputArg = paramValue("output")
        let fileSetIDArg = paramValue("fileSetID")
        let profileStr = paramValue("profile").isEmpty ? "STD-GEN-CD" : paramValue("profile")
        let recursive = paramValue("recursive").isEmpty ? true : (paramValue("recursive") == "true")
        let strict = paramValue("strict") == "true"
        let verbose = paramValue("createVerbose") == "true"

        let inputScopedURL = securityScopedURLs["inputDirectory"]
        let inputAccessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if inputAccessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputDirectory)

        let outputScopedURL = securityScopedURLs["output"]
        let outputAccessing = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if outputAccessing { outputScopedURL?.stopAccessingSecurityScopedResource() } }

        // Resolve output URL: explicit output, security-scoped output, or DICOMDIR inside input.
        let outputURL: URL
        let outputDisplayPath: String
        if let scoped = outputScopedURL {
            outputURL = scoped
            outputDisplayPath = outputArg.isEmpty ? scoped.path : outputArg
        } else if !outputArg.isEmpty {
            outputURL = URL(fileURLWithPath: outputArg)
            outputDisplayPath = outputArg
        } else {
            outputURL = inputURL.appendingPathComponent("DICOMDIR")
            outputDisplayPath = inputDirectory + "/DICOMDIR"
        }

        let fsID = fileSetIDArg.isEmpty ? inputURL.lastPathComponent : fileSetIDArg

        let (output, exitCode): (String, Int) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var out = ""

            guard let dicomProfile = DICOMDIRProfile(rawValue: profileStr) else {
                return ("Error: Invalid profile: \(profileStr). Use STD-GEN-CD, STD-GEN-DVD, or STD-GEN-USB\n", 1)
            }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
                return ("Error: Input directory not found: \(inputDirectory)\n", 1)
            }
            guard isDir.boolValue else {
                return ("Error: Input path is not a directory: \(inputDirectory)\n", 1)
            }

            if verbose {
                out += "Creating DICOMDIR...\n"
                out += "  Input directory: \(inputDirectory)\n"
                out += "  Output file: \(outputDisplayPath)\n"
                out += "  File-set ID: \(fsID)\n"
                out += "  Profile: \(profileStr)\n"
                out += "  Recursive: \(recursive)\n\n"
            }

            // Enumerate DICOM files (mirrors the CLI's findDICOMFiles).
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
            var dicomFiles: [URL] = []
            do {
                if recursive {
                    guard let enumerator = FileManager.default.enumerator(
                        at: inputURL,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles]
                    ) else {
                        return ("Error: Cannot enumerate directory: \(inputURL.path)\n", 1)
                    }
                    while let fileURL = enumerator.nextObject() as? URL {
                        let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                        if values.isRegularFile == true {
                            if fileURL.lastPathComponent == "DICOMDIR" { continue }
                            dicomFiles.append(fileURL)
                        }
                    }
                } else {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: inputURL,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles]
                    )
                    for fileURL in contents {
                        let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                        if values.isRegularFile == true {
                            if fileURL.lastPathComponent == "DICOMDIR" { continue }
                            dicomFiles.append(fileURL)
                        }
                    }
                }
            } catch {
                return (out + "Error: \(error.localizedDescription)\n", 1)
            }
            dicomFiles.sort { $0.path < $1.path }

            if dicomFiles.isEmpty {
                return (out + "Error: No DICOM files found in directory: \(inputDirectory)\n", 1)
            }

            if verbose {
                out += "Found \(dicomFiles.count) DICOM files\n\n"
            }

            var builder = DICOMDirectory.Builder(fileSetID: fsID, profile: dicomProfile)
            var successCount = 0
            var failureCount = 0

            for (index, fileURL) in dicomFiles.enumerated() {
                if verbose {
                    out += "[\(index + 1)/\(dicomFiles.count)] Processing \(fileURL.lastPathComponent)...\n"
                }
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let dicomFile = try DICOMFile.read(from: fileData, force: !strict)
                    let relativePath = fileURL.path.replacingOccurrences(of: inputURL.path + "/", with: "")
                    let pathComponents = relativePath.components(separatedBy: "/")
                    try builder.addFile(dicomFile, relativePath: pathComponents)
                    successCount += 1
                } catch {
                    failureCount += 1
                    if verbose {
                        out += "  Failed: \(error.localizedDescription)\n"
                    }
                }
            }

            let directory = builder.build()

            do {
                // Sandbox/TCC-resilient: resolve a writable destination (scoped URL, else
                // probe the typed path, else ~/Downloads/DICOMStudio) for the library writer.
                let dest = OutputAccess.resolveWritableURL(forPath: outputURL.path, scopedURL: outputScopedURL, subfolder: "DICOMDIR")
                if let note = dest.note { out += note + "\n" }
                try DICOMDIRWriter.write(directory, to: dest.url)
            } catch {
                return (out + "Error: Failed to write DICOMDIR: \(error.localizedDescription)\n", 1)
            }

            out += "\nDICOMDIR created successfully\n\n"
            out += "Summary:\n"
            out += "  Files processed: \(successCount)/\(dicomFiles.count)\n"
            if failureCount > 0 {
                out += "  Failed: \(failureCount)\n"
            }
            let stats = directory.statistics()
            out += "  Patients: \(stats.patientCount)\n"
            out += "  Studies: \(stats.studyCount)\n"
            out += "  Series: \(stats.seriesCount)\n"
            out += "  Images: \(stats.imageCount)\n\n"
            out += "Output: \(outputDisplayPath)\n"
            return (out, 0)
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: dicom-dcmdir validate

    private func executeDicomDcmdirValidate() async {
        let dicomdirPath = paramValue("dicomdirPath")
        guard !dicomdirPath.isEmpty else {
            appendConsoleOutput("Error: DICOMDIR path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: 1, output: "Missing DICOMDIR path")
            return
        }
        let checkFiles = paramValue("checkFiles") == "true"
        let detailed = paramValue("detailed") == "true"

        let scopedURL = securityScopedURLs["dicomdirPath"]
        let accessing = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scopedURL?.stopAccessingSecurityScopedResource() } }
        let fileURL = scopedURL ?? URL(fileURLWithPath: dicomdirPath)

        let (output, exitCode): (String, Int) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var out = ""
            out += "Validating DICOMDIR: \(dicomdirPath)\n\n"

            let directory: DICOMDirectory
            do {
                let data = try Data(contentsOf: fileURL)
                directory = try DICOMDIRReader.read(from: data)
            } catch {
                out += "Failed to read DICOMDIR: \(error.localizedDescription)\n"
                return (out, 1)
            }

            do {
                try directory.validate(checkFileExistence: checkFiles)
                out += "DICOMDIR structure is valid\n"
            } catch {
                out += "Validation failed: \(error.localizedDescription)\n"
                return (out, 1)
            }

            out += "\nStatistics:\n"
            let stats = directory.statistics()
            out += "  Patients: \(stats.patientCount)\n"
            out += "  Studies: \(stats.studyCount)\n"
            out += "  Series: \(stats.seriesCount)\n"
            out += "  Images: \(stats.imageCount)\n"
            out += "  Total records: \(stats.totalRecordCount)\n"
            out += "  Active records: \(stats.activeRecordCount)\n"
            out += "  Inactive records: \(stats.inactiveRecordCount)\n"
            out += "\nFile-set:\n"
            out += "  ID: \(directory.fileSetID.isEmpty ? "<none>" : directory.fileSetID)\n"
            out += "  Profile: \(directory.profile.rawValue)\n"
            out += "  Consistent: \(directory.isConsistent ? "Yes" : "No")\n"

            if detailed {
                out += "\nRecords by type:\n"
                let allRecords = directory.allRecords()
                let recordTypes = Set(allRecords.map { $0.recordType })
                for recordType in recordTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                    let count = allRecords.filter { $0.recordType == recordType }.count
                    out += "  \(recordType.rawValue): \(count)\n"
                }
            }

            out += "\nValidation complete\n"
            return (out, 0)
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: dicom-dcmdir dump

    private func executeDicomDcmdirDump() async {
        let dicomdirPath = paramValue("dicomdirPath")
        guard !dicomdirPath.isEmpty else {
            appendConsoleOutput("Error: DICOMDIR path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: 1, output: "Missing DICOMDIR path")
            return
        }
        let format = paramValue("format").isEmpty ? "tree" : paramValue("format")
        let verbose = paramValue("dumpVerbose") == "true"

        let scopedURL = securityScopedURLs["dicomdirPath"]
        let accessing = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scopedURL?.stopAccessingSecurityScopedResource() } }
        let fileURL = scopedURL ?? URL(fileURLWithPath: dicomdirPath)

        let (output, exitCode): (String, Int) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var out = ""

            let directory: DICOMDirectory
            do {
                let data = try Data(contentsOf: fileURL)
                directory = try DICOMDIRReader.read(from: data)
            } catch {
                out += "Error reading DICOMDIR: \(error.localizedDescription)\n"
                return (out, 1)
            }

            func formatRecordName(_ record: DirectoryRecord) -> String {
                var name = record.recordType.rawValue
                switch record.recordType {
                case .patient:
                    if let patientName = record.attribute(for: .patientName)?.stringValue {
                        name += " - \(patientName)"
                    }
                    if let patientID = record.attribute(for: .patientID)?.stringValue {
                        name += " (ID: \(patientID))"
                    }
                case .study:
                    if let studyDesc = record.attribute(for: .studyDescription)?.stringValue {
                        name += " - \(studyDesc)"
                    }
                    if let studyDate = record.attribute(for: .studyDate)?.stringValue {
                        name += " [\(studyDate)]"
                    }
                case .series:
                    if let modality = record.attribute(for: .modality)?.stringValue {
                        name += " - \(modality)"
                    }
                    if let seriesDesc = record.attribute(for: .seriesDescription)?.stringValue {
                        name += " - \(seriesDesc)"
                    }
                case .image:
                    if let instanceNum = record.attribute(for: .instanceNumber)?.stringValue {
                        name += " #\(instanceNum)"
                    }
                    if let filePath = record.referencedFilePath() {
                        name += " (\(filePath))"
                    }
                default:
                    break
                }
                return name
            }

            func printRecord(_ record: DirectoryRecord, prefix: String, isLast: Bool) {
                let connector = isLast ? "└── " : "├── "
                out += "\(prefix)\(connector)\(formatRecordName(record))\n"
                if verbose {
                    for (tag, element) in record.attributes.sorted(by: { $0.key < $1.key }) {
                        if let stringValue = element.stringValue {
                            let attrPrefix = isLast ? "    " : "│   "
                            out += "\(prefix)\(attrPrefix)    \(tag): \(stringValue)\n"
                        }
                    }
                }
                let childPrefix = prefix + (isLast ? "    " : "│   ")
                for (index, child) in record.children.enumerated() {
                    let childIsLast = index == record.children.count - 1
                    printRecord(child, prefix: childPrefix, isLast: childIsLast)
                }
            }

            switch format.lowercased() {
            case "tree":
                out += "DICOMDIR: \(directory.fileSetID)\n"
                out += "├─ Profile: \(directory.profile.rawValue)\n"
                out += "├─ Consistent: \(directory.isConsistent)\n"
                out += "└─ Records:\n"
                for (index, patient) in directory.rootRecords.enumerated() {
                    let isLast = index == directory.rootRecords.count - 1
                    printRecord(patient, prefix: isLast ? "    " : "│   ", isLast: true)
                }
            case "json":
                let stats = directory.statistics()
                out += "{\n"
                out += "  \"fileSetID\": \"\(directory.fileSetID)\",\n"
                out += "  \"profile\": \"\(directory.profile.rawValue)\",\n"
                out += "  \"isConsistent\": \(directory.isConsistent),\n"
                out += "  \"statistics\": {\n"
                out += "    \"patients\": \(stats.patientCount),\n"
                out += "    \"studies\": \(stats.studyCount),\n"
                out += "    \"series\": \(stats.seriesCount),\n"
                out += "    \"images\": \(stats.imageCount)\n"
                out += "  },\n"
                out += "  \"recordCount\": \(stats.totalRecordCount)\n"
                out += "}\n"
            case "text":
                out += "DICOMDIR Information\n"
                out += "====================\n\n"
                out += "File-set ID: \(directory.fileSetID.isEmpty ? "<none>" : directory.fileSetID)\n"
                out += "Profile: \(directory.profile.rawValue)\n"
                out += "Consistent: \(directory.isConsistent)\n\n"
                let stats = directory.statistics()
                out += "Statistics:\n"
                out += "  Patients: \(stats.patientCount)\n"
                out += "  Studies: \(stats.studyCount)\n"
                out += "  Series: \(stats.seriesCount)\n"
                out += "  Images: \(stats.imageCount)\n"
                out += "  Total records: \(stats.totalRecordCount)\n\n"
                if verbose {
                    out += "All Records:\n"
                    out += "------------\n"
                    for record in directory.allRecords() {
                        out += "\n"
                        out += "Type: \(record.recordType.rawValue)\n"
                        if let filePath = record.referencedFilePath() {
                            out += "File: \(filePath)\n"
                        }
                        for (tag, element) in record.attributes {
                            if let value = element.stringValue {
                                out += "  \(tag): \(value)\n"
                            }
                        }
                    }
                }
            default:
                out += "Error: Invalid format: \(format). Use tree, json, or text\n"
                return (out, 1)
            }

            return (out, 0)
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: dicom-dcmdir update (stub — matches the CLI, which is not yet implemented)

    private func executeDicomDcmdirUpdate() async {
        var out = ""
        out += "Update functionality not yet implemented\n\n"
        out += "To update a DICOMDIR:\n"
        out += "  1. Extract its structure\n"
        out += "  2. Add new files\n"
        out += "  3. Recreate the DICOMDIR\n\n"
        out += "For now, use 'dicom-dcmdir create' to recreate from scratch.\n"
        appendConsoleOutput(out)
        addToHistory(toolName: "dicom-dcmdir", command: commandPreview, exitCode: 1, output: out)
        consoleStatus = .error
        service.setConsoleStatus(.error)
    }

    // MARK: - dicom-pdf Execution

    /// Extracts an embedded document from a DICOM Encapsulated Document, or
    /// encapsulates a document (PDF/CDA/STL/OBJ/MTL) into a DICOM file.
    /// In-process reimplementation of the `dicom-pdf` CLI using DICOMKit's
    /// EncapsulatedDocumentParser / EncapsulatedDocumentBuilder. Directory
    /// (`--recursive`) mode is supported via the scoped directory URL.
    private func executeDicomPdf() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-pdf", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let outputPath  = paramValue("output")
        let extractMode = paramValue("extract") == "true"
        let patientName = paramValue("patient-name")
        let patientID   = paramValue("patient-id")
        let title       = paramValue("title")
        let studyUID    = paramValue("study-uid")
        let seriesUID   = paramValue("series-uid")
        let modality    = paramValue("modality")
        let seriesDesc  = paramValue("series-description")
        let seriesNumber   = Int(paramValue("series-number"))
        let instanceNumber = Int(paramValue("instance-number"))
        let recursive   = paramValue("recursive") == "true"
        let showMeta    = paramValue("show-metadata") == "true"
        let verbose     = paramValue("verbose") == "true"

        // Gain sandbox access via security-scoped URLs registered by the file pickers.
        let inputScopedURL  = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput  = inputScopedURL?.startAccessingSecurityScopedResource()  ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput  { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)

        // Resolve a sandbox-writable destination (scoped URL → ~/Downloads → fallback).
        let (resolvedOutput, redirectNote) = SecurityViewModel.resolveWritableOutput(
            path: outputScopedURL?.path ?? outputPath,
            scopedURL: outputScopedURL
        )
        if let note = redirectNote { appendConsoleOutput(note) }
        let effectiveOutput = resolvedOutput.isEmpty ? outputPath : resolvedOutput

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            let fm = FileManager.default

            // MARK: helpers (mirror the CLI exactly)

            func formatFileSize(_ bytes: Int64) -> String {
                let kb = Double(bytes) / 1024
                let mb = kb / 1024
                if mb >= 1 { return String(format: "%.2f MB", mb) }
                else if kb >= 1 { return String(format: "%.2f KB", kb) }
                else { return "\(bytes) bytes" }
            }

            func extensionForDocumentType(_ type: DICOMKit.EncapsulatedDocumentType) -> String {
                switch type {
                case .pdf: return "pdf"
                case .cda: return "xml"
                case .stl: return "stl"
                case .obj: return "obj"
                case .mtl: return "mtl"
                case .unknown: return "bin"
                }
            }

            func documentTypeFromExtension(_ ext: String) -> DICOMKit.EncapsulatedDocumentType {
                switch ext.lowercased() {
                case "pdf": return .pdf
                case "xml": return .cda
                case "stl": return .stl
                case "obj": return .obj
                case "mtl": return .mtl
                default:    return .unknown
                }
            }

            func generateUID() -> String { UIDGenerator.generateUID().value }

            func documentMetadata(_ document: EncapsulatedDocument) -> String {
                var s = ""
                s += "\n"
                s += "Document Metadata:\n"
                s += "  Type: \(document.documentType)\n"
                s += "  MIME Type: \(document.mimeType)\n"
                s += "  Size: \(formatFileSize(Int64(document.documentData.count)))\n"
                s += "  SOP Class: \(document.sopClassUID)\n"
                s += "  SOP Instance: \(document.sopInstanceUID)\n"
                if let title = document.documentTitle { s += "  Title: \(title)\n" }
                s += "\n"
                s += "Patient Information:\n"
                if let pn = document.patientName { s += "  Name: \(pn)\n" }
                if let pid = document.patientID { s += "  ID: \(pid)\n" }
                s += "\n"
                s += "Study/Series:\n"
                s += "  Study UID: \(document.studyInstanceUID)\n"
                s += "  Series UID: \(document.seriesInstanceUID)\n"
                if let m = document.modality { s += "  Modality: \(m)\n" }
                if let sd = document.seriesDescription { s += "  Series Description: \(sd)\n" }
                if let sn = document.seriesNumber { s += "  Series Number: \(sn)\n" }
                if let inum = document.instanceNumber { s += "  Instance Number: \(inum)\n" }
                s += "\n"
                return s
            }

            // MARK: input classification

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
                return ("Error: Input path not found: \(inputURL.path)\n", 1)
            }

            // MARK: single-file extraction

            func extractFromFile(_ srcURL: URL, outURLOrPath: String?) -> (String, Int) {
                var log = ""
                if verbose { log += "Extracting document from: \(srcURL.path)\n" }
                do {
                    let data = try Data(contentsOf: srcURL)
                    let dicomFile = try DICOMFile.read(from: data, force: false)
                    let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)

                    if showMeta { log += documentMetadata(document) }

                    // Determine output path.
                    let finalOutputPath: String
                    if let specified = outURLOrPath, !specified.isEmpty {
                        // If a directory was supplied, auto-name inside it.
                        var d: ObjCBool = false
                        if fm.fileExists(atPath: specified, isDirectory: &d), d.boolValue {
                            let baseName = srcURL.deletingPathExtension().lastPathComponent
                            let ext = extensionForDocumentType(document.documentType)
                            finalOutputPath = URL(fileURLWithPath: specified)
                                .appendingPathComponent("\(baseName).\(ext)").path
                        } else {
                            finalOutputPath = specified
                        }
                    } else {
                        let baseName = srcURL.deletingPathExtension().lastPathComponent
                        let ext = extensionForDocumentType(document.documentType)
                        finalOutputPath = srcURL.deletingLastPathComponent()
                            .appendingPathComponent("\(baseName).\(ext)").path
                    }

                    let writeRes = try OutputAccess.write(document.documentData, toPath: finalOutputPath,
                                                          scopedURL: outputScopedURL, subfolder: "PDF/Extracted")
                    if let note = writeRes.note { log += note + "\n" }

                    if verbose {
                        log += "✓ Extracted \(document.documentType) (\(formatFileSize(Int64(document.documentData.count))))\n"
                        log += "  Output: \(writeRes.url.path)\n"
                    } else {
                        log += "Extracted: \(writeRes.url.path)\n"
                    }
                    return (log, 0)
                } catch {
                    log += "Error: \(error.localizedDescription)\n"
                    return (log, 1)
                }
            }

            // MARK: single-file encapsulation

            func encapsulateFile(_ srcURL: URL, outURLOrPath: String?) -> (String, Int) {
                var log = ""
                if verbose { log += "Encapsulating document: \(srcURL.path)\n" }

                guard !patientName.isEmpty else {
                    return ("Error: Patient Name is required for encapsulation (--patient-name)\n", 1)
                }
                guard !patientID.isEmpty else {
                    return ("Error: Patient ID is required for encapsulation (--patient-id)\n", 1)
                }

                do {
                    let documentData = try Data(contentsOf: srcURL)
                    let documentType = documentTypeFromExtension(srcURL.pathExtension)

                    let finalStudyUID  = studyUID.isEmpty  ? generateUID() : studyUID
                    let finalSeriesUID = seriesUID.isEmpty ? generateUID() : seriesUID

                    let finalModality: String
                    if !modality.isEmpty {
                        finalModality = modality
                    } else {
                        switch documentType {
                        case .stl, .obj, .mtl: finalModality = "M3D"
                        default:               finalModality = "DOC"
                        }
                    }

                    let builder = EncapsulatedDocumentBuilder(
                        documentData: documentData,
                        mimeType: documentType.expectedMIMEType,
                        documentType: documentType,
                        studyInstanceUID: finalStudyUID,
                        seriesInstanceUID: finalSeriesUID
                    )
                    .setPatientName(patientName)
                    .setPatientID(patientID)
                    .setModality(finalModality)

                    if !title.isEmpty { _ = builder.setDocumentTitle(title) }
                    if !seriesDesc.isEmpty { _ = builder.setSeriesDescription(seriesDesc) }
                    if let sn = seriesNumber { _ = builder.setSeriesNumber(sn) }
                    if let inum = instanceNumber { _ = builder.setInstanceNumber(inum) }

                    let dataSet = try builder.buildDataSet()
                    let dicomFile = DICOMFile.create(
                        dataSet: dataSet,
                        sopClassUID: documentType.sopClassUID,
                        transferSyntaxUID: "1.2.840.10008.1.2.1" // Explicit VR Little Endian
                    )
                    let dicomData = try dicomFile.write()

                    let finalOutputPath: String
                    if let specified = outURLOrPath, !specified.isEmpty {
                        var d: ObjCBool = false
                        if fm.fileExists(atPath: specified, isDirectory: &d), d.boolValue {
                            let baseName = srcURL.deletingPathExtension().lastPathComponent
                            finalOutputPath = URL(fileURLWithPath: specified)
                                .appendingPathComponent("\(baseName).dcm").path
                        } else {
                            finalOutputPath = specified
                        }
                    } else {
                        finalOutputPath = srcURL.deletingPathExtension()
                            .appendingPathExtension("dcm").path
                    }

                    let writeRes = try OutputAccess.write(dicomData, toPath: finalOutputPath,
                                                          scopedURL: outputScopedURL, subfolder: "PDF/Encapsulated")
                    if let note = writeRes.note { log += note + "\n" }

                    if verbose {
                        log += "✓ Encapsulated \(documentType) (\(formatFileSize(Int64(documentData.count))))\n"
                        log += "  DICOM size: \(formatFileSize(Int64(dicomData.count)))\n"
                        log += "  Patient: \(patientName) [\(patientID)]\n"
                        log += "  Study UID: \(finalStudyUID)\n"
                        log += "  Output: \(writeRes.url.path)\n"
                    } else {
                        log += "Encapsulated: \(writeRes.url.path)\n"
                    }
                    return (log, 0)
                } catch {
                    log += "Error: \(error.localizedDescription)\n"
                    return (log, 1)
                }
            }

            // MARK: directory mode

            func enumerateFiles(_ dir: URL) -> [URL] {
                var files: [URL] = []
                let en = fm.enumerator(
                    at: dir,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let f = en?.nextObject() as? URL {
                    if let isReg = try? f.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isReg {
                        files.append(f)
                    }
                }
                return files
            }

            func extractFromDirectory(_ dir: URL) -> (String, Int) {
                var log = ""
                let outDirRequested: URL = (outURLOrPathString().isEmpty)
                    ? dir.appendingPathComponent("extracted")
                    : URL(fileURLWithPath: outURLOrPathString())
                // Sandbox/TCC-resilient output directory (else fall back to ~/Downloads/DICOMStudio).
                let _od = OutputAccess.resolveWritableURL(forPath: outDirRequested.path, scopedURL: outputScopedURL, subfolder: "PDF/Extracted", isDirectory: true)
                let outDir = _od.url
                if let note = _od.note { log += note + "\n" }
                do {
                    try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
                } catch {
                    return ("Error: Unable to create output directory: \(error.localizedDescription)\n", 1)
                }
                if verbose {
                    log += "Extracting documents from: \(dir.path)\n"
                    log += "Output directory: \(outDir.path)\n\n"
                }
                var success = 0, failure = 0
                for f in enumerateFiles(dir) {
                    do {
                        let data = try Data(contentsOf: f)
                        let dicomFile = try DICOMFile.read(from: data, force: false)
                        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
                        let baseName = f.deletingPathExtension().lastPathComponent
                        let ext = extensionForDocumentType(document.documentType)
                        let outFile = outDir.appendingPathComponent("\(baseName).\(ext)")
                        try document.documentData.write(to: outFile)
                        success += 1
                        if verbose { log += "✓ \(f.lastPathComponent) → \(outFile.lastPathComponent)\n" }
                    } catch {
                        failure += 1
                        if verbose { log += "✗ \(f.lastPathComponent): \(error.localizedDescription)\n" }
                    }
                }
                log += "\nExtraction complete:\n"
                log += "  Successful: \(success)\n"
                if failure > 0 { log += "  Failed: \(failure)\n" }
                log += "  Output directory: \(outDir.path)\n"
                return (log, failure > 0 && success == 0 ? 1 : 0)
            }

            func encapsulateFromDirectory(_ dir: URL) -> (String, Int) {
                var log = ""
                guard !patientName.isEmpty else {
                    return ("Error: Patient Name is required for batch encapsulation (--patient-name)\n", 1)
                }
                guard !patientID.isEmpty else {
                    return ("Error: Patient ID is required for batch encapsulation (--patient-id)\n", 1)
                }
                let outDirRequested: URL = (outURLOrPathString().isEmpty)
                    ? dir.appendingPathComponent("encapsulated")
                    : URL(fileURLWithPath: outURLOrPathString())
                // Sandbox/TCC-resilient output directory (else fall back to ~/Downloads/DICOMStudio).
                let _od = OutputAccess.resolveWritableURL(forPath: outDirRequested.path, scopedURL: outputScopedURL, subfolder: "PDF/Encapsulated", isDirectory: true)
                let outDir = _od.url
                if let note = _od.note { log += note + "\n" }
                do {
                    try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
                } catch {
                    return ("Error: Unable to create output directory: \(error.localizedDescription)\n", 1)
                }
                if verbose {
                    log += "Encapsulating documents from: \(dir.path)\n"
                    log += "Output directory: \(outDir.path)\n\n"
                }
                var success = 0, failure = 0
                var instNum = instanceNumber ?? 1
                let finalStudyUID  = studyUID.isEmpty  ? generateUID() : studyUID
                let finalSeriesUID = seriesUID.isEmpty ? generateUID() : seriesUID

                for f in enumerateFiles(dir) {
                    let docType = documentTypeFromExtension(f.pathExtension)
                    guard docType != .unknown else {
                        if verbose { log += "⊘ \(f.lastPathComponent): Unsupported file type\n" }
                        continue
                    }
                    do {
                        let documentData = try Data(contentsOf: f)
                        let finalModality: String
                        if !modality.isEmpty {
                            finalModality = modality
                        } else {
                            switch docType {
                            case .stl, .obj, .mtl: finalModality = "M3D"
                            default:               finalModality = "DOC"
                            }
                        }
                        let builder = EncapsulatedDocumentBuilder(
                            documentData: documentData,
                            mimeType: docType.expectedMIMEType,
                            documentType: docType,
                            studyInstanceUID: finalStudyUID,
                            seriesInstanceUID: finalSeriesUID
                        )
                        .setPatientName(patientName)
                        .setPatientID(patientID)
                        .setModality(finalModality)
                        .setInstanceNumber(instNum)

                        if !title.isEmpty { _ = builder.setDocumentTitle(title) }
                        if !seriesDesc.isEmpty { _ = builder.setSeriesDescription(seriesDesc) }
                        if let sn = seriesNumber { _ = builder.setSeriesNumber(sn) }

                        let dataSet = try builder.buildDataSet()
                        let dicomFile = DICOMFile.create(
                            dataSet: dataSet,
                            sopClassUID: docType.sopClassUID,
                            transferSyntaxUID: "1.2.840.10008.1.2.1"
                        )
                        let dicomData = try dicomFile.write()
                        let baseName = f.deletingPathExtension().lastPathComponent
                        let outFile = outDir.appendingPathComponent("\(baseName).dcm")
                        try dicomData.write(to: outFile)
                        success += 1
                        instNum += 1
                        if verbose { log += "✓ \(f.lastPathComponent) → \(outFile.lastPathComponent)\n" }
                    } catch {
                        failure += 1
                        if verbose { log += "✗ \(f.lastPathComponent): \(error.localizedDescription)\n" }
                    }
                }
                log += "\nEncapsulation complete:\n"
                log += "  Successful: \(success)\n"
                if failure > 0 { log += "  Failed: \(failure)\n" }
                log += "  Study UID: \(finalStudyUID)\n"
                log += "  Series UID: \(finalSeriesUID)\n"
                log += "  Output directory: \(outDir.path)\n"
                return (log, failure > 0 && success == 0 ? 1 : 0)
            }

            func outURLOrPathString() -> String { effectiveOutput }

            // MARK: dispatch

            if isDir.boolValue {
                guard recursive else {
                    return ("Error: Directory processing requires --recursive flag\n", 1)
                }
                return extractMode ? extractFromDirectory(inputURL) : encapsulateFromDirectory(inputURL)
            } else {
                let outArg = effectiveOutput.isEmpty ? nil : effectiveOutput
                return extractMode
                    ? extractFromFile(inputURL, outURLOrPath: outArg)
                    : encapsulateFile(inputURL, outURLOrPath: outArg)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-pdf", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-pixedit Execution

    /// Edits pixel data in a DICOM file (mask / crop / window-level / invert) and
    /// writes a new DICOM file. Reimplements the executable-local PixelEditor logic
    /// in-process using DICOMKit/DICOMCore APIs.
    private func executeDicomPixedit() async {
        let inputPath = paramValue("inputPath")
        let outputPath = paramValue("output")
        let maskRegionStr = paramValue("mask-region")
        let fillValueStr = paramValue("fill-value")
        let cropStr = paramValue("crop")
        let windowCenterStr = paramValue("window-center")
        let windowWidthStr = paramValue("window-width")
        let applyWindow = paramValue("apply-window") == "true"
        let invert = paramValue("invert") == "true"
        let verbose = paramValue("verbose") == "true"

        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }
        guard !outputPath.isEmpty else {
            appendConsoleOutput("Error: Output path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "Missing output path")
            return
        }

        // Build the operation list (shared DICOMKit PixelOperation), mirroring
        // main.swift validation order.
        func parseRegion(_ s: String) -> (x: Int, y: Int, width: Int, height: Int)? {
            let parts = s.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 4 else { return nil }
            guard parts[0] >= 0, parts[1] >= 0, parts[2] > 0, parts[3] > 0 else { return nil }
            return (x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        }

        var operations: [PixelOperation] = []

        if !maskRegionStr.isEmpty {
            guard let r = parseRegion(maskRegionStr) else {
                appendConsoleOutput("Error: Invalid region format '\(maskRegionStr)'. Expected x,y,width,height with positive width/height\n")
                consoleStatus = .error; service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "Invalid mask region")
                return
            }
            operations.append(.mask(x: r.x, y: r.y, width: r.width, height: r.height, fillValue: Int(fillValueStr) ?? 0))
        }

        if !cropStr.isEmpty {
            guard let r = parseRegion(cropStr) else {
                appendConsoleOutput("Error: Invalid region format '\(cropStr)'. Expected x,y,width,height with positive width/height\n")
                consoleStatus = .error; service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "Invalid crop region")
                return
            }
            operations.append(.crop(x: r.x, y: r.y, width: r.width, height: r.height))
        }

        if applyWindow {
            guard let center = Double(windowCenterStr), let width = Double(windowWidthStr) else {
                appendConsoleOutput("Error: --apply-window requires both --window-center and --window-width\n")
                consoleStatus = .error; service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "Window center/width required")
                return
            }
            operations.append(.windowLevel(center: center, width: width))
        }

        if invert { operations.append(.invert) }

        guard !operations.isEmpty else {
            appendConsoleOutput("Error: No operations specified. Use --mask-region, --crop, --apply-window, or --invert\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: "No operations specified")
            return
        }

        // Gain sandbox access via security-scoped URLs.
        let inputScopedURL = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }
        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        let outputURL = outputScopedURL ?? URL(fileURLWithPath: outputPath)

        if verbose {
            appendConsoleOutput("Input: \(inputURL.path)\n")
            appendConsoleOutput("Output: \(outputURL.path)\n")
            appendConsoleOutput("Operations: \(operations.count)\n")
        }

        let (output, outputData, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Data?, Int) in
            var log = ""
            do {
                let fileData = try Data(contentsOf: inputURL)
                // Apply pixel operations via the shared DICOMKit engine — the exact
                // same PixelEditor the `dicom-pixedit` CLI uses, so the produced
                // DICOM bytes are identical. Output is written below via the
                // sandbox-aware OutputAccess path.
                let editor = PixelEditor(verbose: verbose, log: { log += $0 + "\n" })
                let (written, info) = try editor.processData(fileData, operations: operations)
                log += "Edited pixel data: \(operations.count) operation(s) applied.\n"
                log += "Image: \(info.columns)x\(info.rows), \(info.bitsAllocated)-bit, \(info.samplesPerPixel) sample(s)\n"
                return (log, written, 0)
            } catch let e as PixelEditError {
                return ("Error: \(e.errorDescription ?? "\(e)")\n", nil, 1)
            } catch {
                return ("Error: \(error.localizedDescription)\n", nil, 1)
            }
        }.value

        if exitCode == 0, let outputData {
            do {
                // Sandbox/TCC-resilient write (prefer scoped URL; else fall back to ~/Downloads).
                let writeRes = try OutputAccess.write(outputData, toPath: outputPath, scopedURL: outputScopedURL, subfolder: "PixEdit")
                appendConsoleOutput(output)
                if let note = writeRes.note { appendConsoleOutput(note + "\n") }
                appendConsoleOutput("Written: \(writeRes.url.path) (\(ByteCountFormatter.string(fromByteCount: Int64(outputData.count), countStyle: .file)))\n")
                appendConsoleOutput("\nDone.\n")
                consoleStatus = .success; service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 0, output: output)
            } catch {
                let msg = "Error: Failed to write output: \(error.localizedDescription)\n"
                appendConsoleOutput(output)
                appendConsoleOutput(msg)
                consoleStatus = .error; service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: 1, output: msg)
            }
        } else {
            appendConsoleOutput(output)
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-pixedit", command: commandPreview, exitCode: exitCode, output: output)
        }
    }

private func executeDicomSplit() async {
    let inputPath = paramValue("inputPath")
    guard !inputPath.isEmpty else {
        appendConsoleOutput("Error: Input DICOM file or directory is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: 1, output: "Missing input path")
        return
    }

    let outputDir = paramValue("output").isEmpty ? "." : paramValue("output")
    let framesSpec = paramValue("frames")
    let format = paramValue("format").isEmpty ? "dicom" : paramValue("format")
    let applyWindow = paramValue("apply-window") == "true"
    let windowCenter = Double(paramValue("window-center"))
    let windowWidth = Double(paramValue("window-width"))
    let pattern = paramValue("pattern").isEmpty ? nil : paramValue("pattern")
    let recursive = paramValue("recursive") == "true"
    let verbose = paramValue("verbose") == "true"

    // Parse the --frames selection (0-based, matching the CLI's frame index semantics).
    var frameIndices: Set<Int>? = nil
    if !framesSpec.isEmpty {
        var parsed = Set<Int>()
        var parseError: String? = nil
        for rawPart in framesSpec.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            if part.isEmpty { continue }
            if part.contains("-") {
                let bounds = part.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2, let start = Int(bounds[0]), let end = Int(bounds[1]), start <= end else {
                    parseError = "Invalid frame range: \(part)"; break
                }
                for i in start...end { parsed.insert(i) }
            } else if let single = Int(part) {
                parsed.insert(single)
            } else {
                parseError = "Invalid frame number: \(part)"; break
            }
        }
        if let parseError = parseError {
            appendConsoleOutput("Error: \(parseError)\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: 1, output: parseError)
            return
        }
        frameIndices = parsed
    }

    // Sandbox access.
    let inputScopedURL = securityScopedURLs["inputPath"]
    let outputScopedURL = securityScopedURLs["output"]
    let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer {
        if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
        if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
    }
    let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
    // Sandbox/TCC-resilient output directory (frames are written inside it).
    let _splitOut = OutputAccess.resolveWritableURL(forPath: outputDir, scopedURL: outputScopedURL, subfolder: "SplitFrames", isDirectory: true)
    let outputBaseURL = _splitOut.url
    if let note = _splitOut.note { appendConsoleOutput(note + "\n") }

    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
        appendConsoleOutput("Error: Input path does not exist: \(inputURL.path)\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: 1, output: "Input not found")
        return
    }

    // Ensure output directory exists.
    do {
        try fm.createDirectory(at: outputBaseURL, withIntermediateDirectories: true)
    } catch {
        appendConsoleOutput("Error: Output path exists but is not a usable directory: \(outputBaseURL.path)\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: 1, output: error.localizedDescription)
        return
    }

    if verbose {
        appendConsoleOutput("DICOM Split Tool\n")
        appendConsoleOutput("========================\n")
        appendConsoleOutput("Input: \(inputURL.path)\n")
        appendConsoleOutput("Output: \(outputBaseURL.path)\n")
        appendConsoleOutput("Format: \(format)\n")
        if !framesSpec.isEmpty { appendConsoleOutput("Frames: \(framesSpec)\n") }
        if applyWindow {
            appendConsoleOutput("Window Center: \(windowCenter ?? 0)\n")
            appendConsoleOutput("Window Width: \(windowWidth ?? 0)\n")
        }
        appendConsoleOutput("\n")
    }

    // Gather the list of files to process.
    var filesToProcess: [URL] = []
    if isDir.boolValue {
        if recursive {
            if let enumerator = fm.enumerator(at: inputURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                while let url = enumerator.nextObject() as? URL {
                    if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                        filesToProcess.append(url)
                    }
                }
            }
        } else {
            if let contents = try? fm.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for url in contents {
                    if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                        filesToProcess.append(url)
                    }
                }
            }
        }
        // Keep only plausible DICOM files (extension or DICM magic) to mirror the CLI's filtering.
        filesToProcess = filesToProcess.filter { url in
            let ext = url.pathExtension.lowercased()
            if ["dcm", "dicom", "dic"].contains(ext) { return true }
            guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? handle.close() }
            guard let head = try? handle.read(upToCount: 132), head.count >= 132 else { return false }
            return head[128..<132] == Data([0x44, 0x49, 0x43, 0x4D])
        }
        if verbose {
            appendConsoleOutput("Found \(filesToProcess.count) files to process\n\n")
        }
    } else {
        filesToProcess = [inputURL]
    }

    // Capture immutable values for the detached worker.
    let workFiles = filesToProcess
    let workOutputBase = outputBaseURL.path
    let workFrameIndices = frameIndices
    let workFormat = format
    let workApplyWindow = applyWindow
    let workWindowCenter = windowCenter
    let workWindowWidth = windowWidth
    let workPattern = pattern
    let workVerbose = verbose

    struct SplitOutcome: Sendable {
        var log: String = ""
        var writtenPaths: [String] = []
        var processedFiles = 0
        var skippedFiles = 0
        var extracted = 0
        var failed = 0
    }

    let outcome = await Task.detached(priority: .userInitiated) { () -> SplitOutcome in
        // Delegate frame extraction to the shared DICOMKit engine — the exact same
        // FrameSplitter the `dicom-split` CLI uses. Verbose progress is collected
        // through the log sink; per-frame stats come back in SplitResult.
        final class LogBox: @unchecked Sendable { var text = "" }
        let logBox = LogBox()
        let splitter = FrameSplitter(
            outputPath: workOutputBase,
            format: SplitOutputFormat(rawValue: workFormat) ?? .dicom,
            applyWindow: workApplyWindow,
            windowCenter: workWindowCenter,
            windowWidth: workWindowWidth,
            namingPattern: workPattern,
            verbose: workVerbose,
            log: { logBox.text += $0 + "\n" }
        )

        var split = SplitResult()
        for fileURL in workFiles {
            await splitter.processFile(fileURL.path, frameIndices: workFrameIndices, into: &split)
        }

        var result = SplitOutcome()
        result.log = logBox.text
        result.writtenPaths = split.writtenPaths
        result.processedFiles = split.processedFiles
        result.skippedFiles = split.skippedFiles
        result.extracted = split.extracted
        result.failed = split.failed
        return result
    }.value

    // Emit detailed log if verbose.
    if verbose && !outcome.log.isEmpty {
        appendConsoleOutput(outcome.log)
    }

    // Summary.
    if outcome.extracted == 0 {
        let msg = outcome.processedFiles == 0
            ? "No multi-frame DICOM files were found to split."
            : "No frames were extracted."
        appendConsoleOutput("\n\(msg)\n")
        let exitCode = outcome.failed > 0 ? 1 : 0
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
        addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: exitCode, output: msg)
        return
    }

    appendConsoleOutput("\nExtracted \(outcome.extracted) frame(s) to \(outputBaseURL.path)\n")
    let previewCount = min(outcome.writtenPaths.count, 10)
    for path in outcome.writtenPaths.prefix(previewCount) {
        appendConsoleOutput("  \(path)\n")
    }
    if outcome.writtenPaths.count > previewCount {
        appendConsoleOutput("  ... and \(outcome.writtenPaths.count - previewCount) more\n")
    }
    if outcome.failed > 0 {
        appendConsoleOutput("\(outcome.failed) frame(s) failed to extract.\n")
    }
    appendConsoleOutput("\nSplit complete!\n")

    let exitCode = outcome.failed > 0 ? 1 : 0
    let summary = "Extracted \(outcome.extracted) frame(s), \(outcome.failed) failed"
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
    addToHistory(toolName: "dicom-split", command: commandPreview, exitCode: exitCode, output: summary)
}

    // MARK: - dicom-merge Execution

    /// Merges multiple single-frame DICOM files into a multi-frame object.
    ///
    /// Reimplements the executable-local `FrameMerger` using DICOMKit/DICOMCore APIs:
    /// gathers input files (file or directory, optionally recursive), optionally validates
    /// pixel/attribute consistency, sorts frames, concatenates Pixel Data, sets
    /// Number of Frames, mints a fresh SOP Instance UID, and writes the result.
    ///
    /// Levels:
    ///  - `file`   -> a single merged multi-frame file written to `--output`
    ///  - `series` -> one merged file per Series Instance UID, written into `--output` dir
    ///  - `study`  -> per-study dir, one merged file per series within each study
    ///
    /// Note: the `--format` enhanced-ct/-mr/-xa functional-group construction from the real
    /// CLI is not reproduced here (the executable's FrameMerger only concatenates pixel data
    /// and sets NumberOfFrames regardless of format); behavior matches the standard path.
    private func executeDicomMerge() async {
        let inputPath = paramValue("inputPath")
        let outputPath = paramValue("output")
        let level = paramValue("level").isEmpty ? "file" : paramValue("level")
        let sortBy = paramValue("sort-by").isEmpty ? "InstanceNumber" : paramValue("sort-by")
        let order = paramValue("order").isEmpty ? "ascending" : paramValue("order")
        let validate = paramValue("validate") == "true"
        let recursive = paramValue("recursive") == "true"
        let verbose = paramValue("verbose") == "true"

        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-merge", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }
        guard !outputPath.isEmpty else {
            appendConsoleOutput("Error: Output path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-merge", command: commandPreview, exitCode: 1, output: "Missing output path")
            return
        }

        // Gain sandbox access via security-scoped URLs.
        let inputScopedURL = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        // Sandbox/TCC-resilient output (series/study modes write a directory; file mode a single file).
        let (outputURL, outRedirectNote) = OutputAccess.resolveWritableURL(
            forPath: outputPath, scopedURL: outputScopedURL, subfolder: "Merge", isDirectory: level != "file")
        if let note = outRedirectNote { appendConsoleOutput(note + "\n") }

        if verbose {
            appendConsoleOutput("DICOM Merge Tool\n")
            appendConsoleOutput("========================\n")
            appendConsoleOutput("Input:  \(inputURL.path)\n")
            appendConsoleOutput("Output: \(outputURL.path)\n")
            appendConsoleOutput("Level:  \(level)\n")
            appendConsoleOutput("Sort:   \(sortBy) (\(order))\n\n")
        }

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var log = ""
            let fm = FileManager.default

            // --- isDICOMFile (mirrors the CLI heuristic) ---
            func isDICOMFile(_ path: String) -> Bool {
                let ext = (path as NSString).pathExtension.lowercased()
                if ["dcm", "dicom", "dic"].contains(ext) { return true }
                guard let fh = FileHandle(forReadingAtPath: path),
                      let data = try? fh.read(upToCount: 132) else { return false }
                try? fh.close()
                if data.count >= 132 {
                    return data[128..<132] == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
                }
                return false
            }

            // --- gatherInputFiles (single file, or directory with optional recursion) ---
            func gatherInputFiles(from rootPath: String) -> [String] {
                var files: [String] = []
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: rootPath, isDirectory: &isDir) else { return files }
                if isDir.boolValue {
                    if recursive {
                        if let en = fm.enumerator(atPath: rootPath) {
                            for case let item as String in en {
                                let full = (rootPath as NSString).appendingPathComponent(item)
                                var itemIsDir: ObjCBool = false
                                if fm.fileExists(atPath: full, isDirectory: &itemIsDir),
                                   !itemIsDir.boolValue, isDICOMFile(full) {
                                    files.append(full)
                                }
                            }
                        }
                    } else if let contents = try? fm.contentsOfDirectory(atPath: rootPath) {
                        for item in contents {
                            let full = (rootPath as NSString).appendingPathComponent(item)
                            var itemIsDir: ObjCBool = false
                            if fm.fileExists(atPath: full, isDirectory: &itemIsDir),
                               !itemIsDir.boolValue, isDICOMFile(full) {
                                files.append(full)
                            }
                        }
                    }
                } else if isDICOMFile(rootPath) {
                    files.append(rootPath)
                }
                return files.sorted()
            }

            do {
                let files = gatherInputFiles(from: inputURL.path)
                guard !files.isEmpty else {
                    return ("Error: No DICOM files found in input path\n", 1)
                }
                if verbose { log += "Found \(files.count) DICOM files to process\n\n" }

                // Delegate the merge to the shared DICOMKit engine — the exact same
                // FrameMerger the `dicom-merge` CLI uses. Verbose progress flows
                // through the log sink so app and CLI cannot drift.
                let mergeLevel = MergeLevel(rawValue: level) ?? .file
                let merger = FrameMerger(
                    format: .standard,
                    level: mergeLevel,
                    sortBy: MergeSortCriteria(rawValue: sortBy) ?? .instanceNumber,
                    order: MergeSortOrder(rawValue: order) ?? .ascending,
                    validate: validate,
                    verbose: verbose,
                    log: { log += $0 + "\n" }
                )

                switch mergeLevel {
                case .file:
                    // Ensure the parent directory exists for a single-file output.
                    try? fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try await merger.mergeToSingleFile(files: files, outputPath: outputURL.path)
                case .series:
                    try await merger.mergeBySeries(files: files, outputDirectory: outputURL.path)
                case .study:
                    try await merger.mergeByStudy(files: files, outputDirectory: outputURL.path)
                }

                log += "\nMerge complete!\n"
                return (log, 0)
            } catch let e as MergeError {
                return (log + "Error: \(e.description)\n", 1)
            } catch {
                return (log + "Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-merge", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

private func executeDicomArchive() async {
    let sub = paramValue("subcommand").isEmpty ? "list" : paramValue("subcommand")

    // Resolve the relevant directory path per subcommand (init uses "path", others "archive").
    let archivePathParam = sub == "init" ? paramValue("path") : paramValue("archive")
    guard !archivePathParam.isEmpty else {
        let msg = sub == "init"
            ? "Error: New archive path is required.\n"
            : "Error: Archive path is required.\n"
        appendConsoleOutput(msg)
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-archive", command: commandPreview, exitCode: 1, output: "Missing archive path")
        return
    }

    // Security-scoped access. "init"/"export" may write under "path"/"output";
    // "import" reads from "files". Start access on whatever scoped URLs we have.
    let archiveScopedURL = securityScopedURLs[sub == "init" ? "path" : "archive"]
    let outputScopedURL = securityScopedURLs["output"]
    let filesScopedURL = securityScopedURLs["files"]
    let a1 = archiveScopedURL?.startAccessingSecurityScopedResource() ?? false
    let a2 = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    let a3 = filesScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer {
        if a1 { archiveScopedURL?.stopAccessingSecurityScopedResource() }
        if a2 { outputScopedURL?.stopAccessingSecurityScopedResource() }
        if a3 { filesScopedURL?.stopAccessingSecurityScopedResource() }
    }

    let archiveURL: URL
    if sub == "init" || sub == "import" {
        // Write subcommands: ensure the archive directory is writable (sandbox/TCC).
        // Read subcommands (list/query/check/stats) must NOT redirect.
        let r = OutputAccess.resolveWritableURL(forPath: archivePathParam, scopedURL: archiveScopedURL, subfolder: "Archive", isDirectory: true)
        if let note = r.note { appendConsoleOutput(note + "\n") }
        archiveURL = r.url
    } else {
        archiveURL = archiveScopedURL ?? URL(fileURLWithPath: archivePathParam)
    }
    let archivePathResolved = archiveURL.path

    // Gather parameter values on the main actor before detaching.
    let force = paramValue("force") == "true"
    let recursive = paramValue("recursive") == "true"
    let skipDuplicates = paramValue("skip-duplicates") == "true"
    let verbose = paramValue("verbose") == "true"
    let format = paramValue("format")
    let showInstances = paramValue("show-instances") == "true"
    let verifyFiles = paramValue("verify-files") == "true"
    let flatten = paramValue("flatten") == "true"
    let filesArg = paramValue("files")
    let filesScopedPath = filesScopedURL?.path
    let outputParam = paramValue("output")
    let outputResolved = (outputScopedURL ?? (outputParam.isEmpty ? nil : URL(fileURLWithPath: outputParam)))?.path ?? outputParam
    let qPatientName = paramValue("patient-name")
    let qPatientID = paramValue("patient-id")
    let qStudyUID = paramValue("study-uid")
    let qSeriesUID = paramValue("series-uid")
    let qModality = paramValue("modality")
    let qStudyDate = paramValue("study-date")

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        // All archive operations are delegated to the shared DICOMKit engine —
        // the exact same ArchiveStore the `dicom-archive` CLI uses, so the app and
        // CLI cannot drift. Sandbox-resolved paths are passed in from the caller.
        do {
            let out: String
            switch sub {
            case "init":
                out = try ArchiveStore.initArchive(at: archivePathResolved, force: force)
            case "import":
                let inputs: [String]
                if let scoped = filesScopedPath {
                    inputs = [scoped]
                } else {
                    inputs = filesArg.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                }
                out = try ArchiveStore.importFiles(
                    into: archivePathResolved, files: inputs,
                    recursive: recursive, skipDuplicates: skipDuplicates, verbose: verbose)
            case "query":
                out = try ArchiveStore.query(
                    in: archivePathResolved,
                    patientName: qPatientName.isEmpty ? nil : qPatientName,
                    patientID: qPatientID.isEmpty ? nil : qPatientID,
                    studyUID: qStudyUID.isEmpty ? nil : qStudyUID,
                    modality: qModality.isEmpty ? nil : qModality,
                    studyDate: qStudyDate.isEmpty ? nil : qStudyDate,
                    format: format.isEmpty ? "table" : format)
            case "list":
                out = try ArchiveStore.list(
                    in: archivePathResolved,
                    format: format.isEmpty ? "tree" : format,
                    showInstances: showInstances)
            case "export":
                out = try ArchiveStore.export(
                    from: archivePathResolved, output: outputResolved,
                    studyUID: qStudyUID.isEmpty ? nil : qStudyUID,
                    seriesUID: qSeriesUID.isEmpty ? nil : qSeriesUID,
                    patientID: qPatientID.isEmpty ? nil : qPatientID,
                    flatten: flatten, verbose: verbose)
            case "check":
                out = try ArchiveStore.check(in: archivePathResolved, verifyFiles: verifyFiles, verbose: verbose)
            case "stats":
                out = try ArchiveStore.stats(in: archivePathResolved, format: format.isEmpty ? "text" : format)
            default:
                return ("Error: Unknown subcommand '\(sub)'.\n", 1)
            }
            return (out, 0)
        } catch {
            return ("Error: \(error.localizedDescription)\n", 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-archive", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

private func executeDicomCompress() async {
    let operation = paramValue("operation").isEmpty ? "info" : paramValue("operation")

    switch operation {
    case "compress":
        await executeDicomCompressCompress()
    case "decompress":
        await executeDicomCompressDecompress()
    case "batch":
        await executeDicomCompressBatch()
    case "backends":
        await executeDicomCompressBackends()
    default:
        await executeDicomCompressInfo()
    }
}

// MARK: - dicom-compress display helpers (the compression engine now lives in DICOMKit's CompressionManager)

private nonisolated static func dcCompressFormatBytes(_ bytes: Int) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
    if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0)) }
    return String(format: "%.1f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
}

private nonisolated static func dcCompressParseQuality(_ q: String?) throws -> CompressionQuality? {
    guard let qs = q?.trimmingCharacters(in: .whitespaces), !qs.isEmpty else { return nil }
    switch qs.lowercased() {
    case "maximum": return .maximum
    case "high":    return .high
    case "medium":  return .medium
    case "low":     return .low
    default:
        if let v = Double(qs), v >= 0.0, v <= 1.0 { return .custom(v) }
        throw NSError(domain: "dicom-compress", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid quality '\(qs)'. Use maximum, high, medium, low, or a value 0.0-1.0"])
    }
}

// MARK: - dicom-compress: info

private func executeDicomCompressInfo() async {
    let inputPath = paramValue("input")
    guard !inputPath.isEmpty else {
        appendConsoleOutput("Error: Input file path is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing input path")
        return
    }
    let asJSON = paramValue("json") == "true"
    let inputScopedURL = securityScopedURLs["input"]
    let accessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer { if accessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
    let fileURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
    let displayPath = inputPath

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        do {
            // Extract via the shared DICOMKit engine; the format below stays app-side
            // (byte-identical to the CLI — verified by the info/info-json goldens).
            let data = try Data(contentsOf: fileURL)
            let info = try CompressionManager().getCompressionInfo(data: data)
            let tsUID = info.transferSyntaxUID
            let tsName = info.transferSyntaxName
            let isCompressed = info.isCompressed
            let isLossless = info.isLossless
            let isJPEG = info.isJPEG
            let isJPEG2000 = info.isJPEG2000
            let isRLE = info.isRLE
            let isDeflated = info.isDeflated
            let pixelDataSize = info.pixelDataSize
            let rows = info.rows
            let cols = info.columns
            let ba = info.bitsAllocated
            let bs = info.bitsStored
            let spp = info.samplesPerPixel
            let pi = info.photometricInterpretation
            let nf = info.numberOfFrames

            if asJSON {
                var dict: [String: Any] = [
                    "file": displayPath,
                    "transferSyntax": tsName,
                    "transferSyntaxUID": tsUID,
                    "compressed": isCompressed,
                    "lossless": isLossless,
                ]
                if isJPEG { dict["codec"] = "JPEG" }
                else if isJPEG2000 { dict["codec"] = "JPEG 2000" }
                else if isRLE { dict["codec"] = "RLE" }
                else if isDeflated { dict["codec"] = "Deflate" }
                else { dict["codec"] = "None" }
                if let v = pixelDataSize { dict["pixelDataSize"] = v }
                if let v = rows { dict["rows"] = Int(v) }
                if let v = cols { dict["columns"] = Int(v) }
                if let v = ba { dict["bitsAllocated"] = Int(v) }
                if let v = bs { dict["bitsStored"] = Int(v) }
                if let v = spp { dict["samplesPerPixel"] = Int(v) }
                if let v = pi { dict["photometricInterpretation"] = v }
                if let v = nf { dict["numberOfFrames"] = v }
                let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
                return ((String(data: jsonData, encoding: .utf8) ?? "") + "\n", 0)
            }

            var lines: [String] = []
            lines.append("File: \(displayPath)")
            lines.append("Transfer Syntax: \(tsName)")
            lines.append("Transfer Syntax UID: \(tsUID)")
            lines.append("Compressed: \(isCompressed ? "Yes" : "No")")
            lines.append("Lossless: \(isLossless ? "Yes" : "No")")
            if isJPEG { lines.append("Codec: JPEG") }
            else if isJPEG2000 {
                if tsUID.hasPrefix("1.2.840.10008.1.2.4.20") { lines.append("Codec: HTJ2K (High-Throughput JPEG 2000)") }
                else { lines.append("Codec: JPEG 2000") }
            }
            else if isRLE { lines.append("Codec: RLE") }
            else if isDeflated { lines.append("Codec: Deflate") }
            else { lines.append("Codec: None (uncompressed)") }
            if let size = pixelDataSize { lines.append("Pixel Data Size: \(Self.dcCompressFormatBytes(size))") }
            else { lines.append("Pixel Data Size: N/A (no pixel data)") }
            if let r = rows, let c = cols { lines.append("Image Dimensions: \(c) x \(r)") }
            if let v = ba { lines.append("Bits Allocated: \(v)") }
            if let v = bs { lines.append("Bits Stored: \(v)") }
            if let v = spp { lines.append("Samples Per Pixel: \(v)") }
            if let v = pi { lines.append("Photometric Interpretation: \(v)") }
            if let v = nf { lines.append("Number of Frames: \(v)") }
            return (lines.joined(separator: "\n") + "\n", 0)
        } catch {
            return ("Error reading file: \(error.localizedDescription)\n", 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

// MARK: - dicom-compress: compress

private func executeDicomCompressCompress() async {
    let inputPath = paramValue("input")
    let outputPath = paramValue("output")
    let codec = paramValue("codec")
    let qualityStr = paramValue("quality")
    let verbose = paramValue("verbose") == "true"
    let backendRaw = paramValue("backend").isEmpty ? "auto" : paramValue("backend")

    guard !inputPath.isEmpty else {
        appendConsoleOutput("Error: Input file path is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing input path")
        return
    }
    guard !outputPath.isEmpty else {
        appendConsoleOutput("Error: Output file path is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing output path")
        return
    }
    guard CompressionManager.transferSyntax(for: codec) != nil else {
        let msg = "Error: Unknown codec '\(codec)'.\n"
        appendConsoleOutput(msg)
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: msg)
        return
    }

    let inputScopedURL = securityScopedURLs["input"]
    let outputScopedURL = securityScopedURLs["output"]
    let accessingIn = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    let accessingOut = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer {
        if accessingIn { inputScopedURL?.stopAccessingSecurityScopedResource() }
        if accessingOut { outputScopedURL?.stopAccessingSecurityScopedResource() }
    }
    let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
    let outputURL = outputScopedURL ?? URL(fileURLWithPath: outputPath)
    let backendName: String = {
        switch backendRaw.lowercased() {
        case "metal": return CodecBackendPreference.metal.effective.displayName
        case "accelerate": return CodecBackendPreference.accelerate.effective.displayName
        case "scalar": return CodecBackendPreference.scalar.effective.displayName
        default: return CodecBackendPreference.auto.effective.displayName
        }
    }()

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        var log = ""
        do {
            let quality = try Self.dcCompressParseQuality(qualityStr)
            if verbose {
                log += "Compressing: \(inputPath)\n"
                log += "Codec: \(codec)\n"
                if let q = qualityStr.trimmingCharacters(in: .whitespaces) as String?, !q.isEmpty { log += "Quality: \(q)\n" }
                log += "Backend: \(backendName)\n"
            }
            let inputData = try Data(contentsOf: inputURL)
            // Compress via the shared DICOMKit engine (same code the CLI runs).
            let outputData = try CompressionManager().compressData(inputData, codec: codec, quality: quality)
            // Sandbox/TCC-resilient write (prefer scoped URL; else fall back to ~/Downloads).
            let writeRes = try OutputAccess.write(outputData, toPath: outputPath, scopedURL: outputScopedURL, subfolder: "Compressed")
            if let note = writeRes.note { log += note + "\n" }
            log += "Compressed: \(inputPath) → \(writeRes.url.path)\n"
            if verbose {
                let inSize = inputData.count
                let outSize = outputData.count
                log += "Input size:  \(Self.dcCompressFormatBytes(inSize))\n"
                log += "Output size: \(Self.dcCompressFormatBytes(outSize))\n"
                if inSize > 0 {
                    let ratio = Double(outSize) / Double(inSize) * 100.0
                    log += "Ratio: \(String(format: "%.1f%%", ratio))\n"
                }
            }
            return (log, 0)
        } catch {
            log += "Error: \(error.localizedDescription)\n"
            return (log, 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

// MARK: - dicom-compress: decompress

private func executeDicomCompressDecompress() async {
    let inputPath = paramValue("input")
    let outputPath = paramValue("output")
    let syntax = paramValue("syntax").isEmpty ? "explicit-le" : paramValue("syntax")
    let verbose = paramValue("verbose") == "true"

    guard !inputPath.isEmpty else {
        appendConsoleOutput("Error: Input file path is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing input path")
        return
    }
    guard !outputPath.isEmpty else {
        appendConsoleOutput("Error: Output file path is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing output path")
        return
    }
    guard let targetSyntax = CompressionManager.transferSyntax(for: syntax) else {
        let msg = "Error: Unknown syntax '\(syntax)'. Use explicit-le or implicit-le.\n"
        appendConsoleOutput(msg)
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: msg)
        return
    }

    let inputScopedURL = securityScopedURLs["input"]
    let outputScopedURL = securityScopedURLs["output"]
    let accessingIn = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    let accessingOut = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer {
        if accessingIn { inputScopedURL?.stopAccessingSecurityScopedResource() }
        if accessingOut { outputScopedURL?.stopAccessingSecurityScopedResource() }
    }
    let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
    let outputURL = outputScopedURL ?? URL(fileURLWithPath: outputPath)
    let targetName = CompressionManager.transferSyntaxDisplayName(targetSyntax)

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        var log = ""
        do {
            if verbose {
                log += "Decompressing: \(inputPath)\n"
                log += "Target syntax: \(targetName)\n"
            }
            let inputData = try Data(contentsOf: inputURL)
            // Decompress via the shared DICOMKit engine (same code the CLI runs).
            let outputData = try CompressionManager().decompressData(inputData, syntax: targetSyntax)
            let writeRes = try OutputAccess.write(outputData, toPath: outputPath, scopedURL: outputScopedURL, subfolder: "Decompressed")
            if let note = writeRes.note { log += note + "\n" }
            log += "Decompressed: \(inputPath) → \(writeRes.url.path)\n"
            if verbose {
                log += "Input size:  \(Self.dcCompressFormatBytes(inputData.count))\n"
                log += "Output size: \(Self.dcCompressFormatBytes(outputData.count))\n"
            }
            return (log, 0)
        } catch {
            log += "Error: \(error.localizedDescription)\n"
            return (log, 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

// MARK: - dicom-compress: batch

private func executeDicomCompressBatch() async {
    let inputDir = paramValue("inputDir")
    let outputDir = paramValue("outputDir")
    let codec = paramValue("batchCodec")
    let decompress = paramValue("decompress") == "true"
    let qualityStr = paramValue("quality")
    let syntax = paramValue("syntax").isEmpty ? "explicit-le" : paramValue("syntax")
    let recursive = paramValue("recursive") == "true"
    let verbose = paramValue("verbose") == "true"

    guard !inputDir.isEmpty else {
        appendConsoleOutput("Error: Input directory is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing input directory")
        return
    }
    guard !outputDir.isEmpty else {
        appendConsoleOutput("Error: Output directory is required.\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: "Missing output directory")
        return
    }
    if !decompress && codec.trimmingCharacters(in: .whitespaces).isEmpty {
        let msg = "Error: Specify --codec for compression or enable Decompress for decompression.\n"
        appendConsoleOutput(msg)
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: msg)
        return
    }
    if !codec.trimmingCharacters(in: .whitespaces).isEmpty, CompressionManager.transferSyntax(for: codec) == nil {
        let msg = "Error: Unknown codec '\(codec)'.\n"
        appendConsoleOutput(msg)
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: 1, output: msg)
        return
    }

    let inputScopedURL = securityScopedURLs["inputDir"]
    let outputScopedURL = securityScopedURLs["outputDir"]
    let accessingIn = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
    let accessingOut = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
    defer {
        if accessingIn { inputScopedURL?.stopAccessingSecurityScopedResource() }
        if accessingOut { outputScopedURL?.stopAccessingSecurityScopedResource() }
    }
    let inputBase = inputScopedURL ?? URL(fileURLWithPath: inputDir)
    let outputBase = outputScopedURL ?? URL(fileURLWithPath: outputDir)

    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        var log = ""
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: outputBase, withIntermediateDirectories: true)
            let quality = try Self.dcCompressParseQuality(qualityStr)

            // Discover DICOM files
            func isDICOM(_ url: URL) -> Bool {
                let ext = url.pathExtension.lowercased()
                if ext == "dcm" || ext == "dicom" || ext == "dic" { return true }
                if ext.isEmpty {
                    guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
                    defer { try? handle.close() }
                    let header = handle.readData(ofLength: 132)
                    if header.count >= 132 {
                        return String(data: header.subdata(in: 128..<132), encoding: .ascii) == "DICM"
                    }
                }
                return false
            }

            var files: [URL] = []
            if recursive {
                if let en = fm.enumerator(at: inputBase, includingPropertiesForKeys: [.isRegularFileKey]) {
                    while let u = en.nextObject() as? URL {
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue, isDICOM(u) {
                            files.append(u)
                        }
                    }
                }
            } else {
                let contents = (try? fm.contentsOfDirectory(at: inputBase, includingPropertiesForKeys: [.isRegularFileKey])) ?? []
                for u in contents {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue, isDICOM(u) {
                        files.append(u)
                    }
                }
            }
            files.sort { $0.path < $1.path }

            if files.isEmpty {
                log += "No DICOM files found in: \(inputDir)\n"
                return (log, 1)
            }
            log += "Found \(files.count) DICOM file(s)\n"

            let basePath = inputBase.path
            var successCount = 0
            var failCount = 0
            for fileURL in files {
                let filePath = fileURL.path
                let relativePath: String
                if filePath.hasPrefix(basePath) {
                    var rel = String(filePath.dropFirst(basePath.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                    relativePath = rel.isEmpty ? fileURL.lastPathComponent : rel
                } else {
                    relativePath = fileURL.lastPathComponent
                }
                let outURL = outputBase.appendingPathComponent(relativePath)
                do {
                    try fm.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let inputData = try Data(contentsOf: fileURL)
                    // Compress/decompress via the shared DICOMKit engine.
                    let outputData: Data
                    if decompress {
                        let target = CompressionManager.transferSyntax(for: syntax) ?? .explicitVRLittleEndian
                        outputData = try CompressionManager().decompressData(inputData, syntax: target)
                    } else {
                        outputData = try CompressionManager().compressData(inputData, codec: codec, quality: quality)
                    }
                    try outputData.write(to: outURL)
                    successCount += 1
                    if verbose { log += "  OK \(relativePath)\n" }
                } catch {
                    failCount += 1
                    if verbose { log += "  FAIL \(relativePath): \(error.localizedDescription)\n" }
                }
            }
            let action = decompress ? "Decompressed" : "Compressed"
            log += "\(action): \(successCount) succeeded, \(failCount) failed out of \(files.count) files\n"
            return (log, failCount > 0 ? 1 : 0)
        } catch {
            log += "Error: \(error.localizedDescription)\n"
            return (log, 1)
        }
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

// MARK: - dicom-compress: backends

private func executeDicomCompressBackends() async {
    let asJSON = paramValue("json") == "true"
    let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
        let best = CodecBackendProbe.bestAvailable
        if asJSON {
            var items: [[String: Any]] = []
            for backend in CodecBackend.allCases {
                items.append([
                    "backend": backend.rawValue,
                    "available": CodecBackendProbe.isAvailable(backend),
                    "active": backend == best,
                    "displayName": backend.displayName
                ])
            }
            if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted]),
               let s = String(data: data, encoding: .utf8) {
                return (s + "\n", 0)
            }
            return ("[]\n", 0)
        }
        var lines: [String] = []
        lines.append("Available hardware acceleration backends:")
        lines.append("")
        for backend in CodecBackend.allCases {
            let isAvail = CodecBackendProbe.isAvailable(backend)
            let marker = isAvail ? (backend == best ? "✓ (active)" : "✓") : "✗"
            let name = backend.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)
            lines.append("  [\(marker)] \(name)\(backend.displayName)")
        }
        lines.append("")
        lines.append("Active backend: \(best.displayName)")
        lines.append("Use --backend <name> on the compress command to select a specific backend.")
        return (lines.joined(separator: "\n") + "\n", 0)
    }.value

    appendConsoleOutput(output)
    addToHistory(toolName: "dicom-compress", command: commandPreview, exitCode: exitCode, output: output)
    consoleStatus = exitCode == 0 ? .success : .error
    service.setConsoleStatus(exitCode == 0 ? .success : .error)
}

private func executeDicomStudy() async {
        let operation = paramValue("operation").isEmpty ? "organize" : paramValue("operation")

        switch operation {
        case "organize": await executeDicomStudyOrganize()
        case "summary":  await executeDicomStudySummary()
        case "check":    await executeDicomStudyCheck()
        case "stats":    await executeDicomStudyStats()
        case "compare":  await executeDicomStudyCompare()
        default:
            appendConsoleOutput("Error: Unknown operation '\(operation)'.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Unknown operation")
        }
    }

    // MARK: - dicom-study : organize

    private func executeDicomStudyOrganize() async {
        let input = paramValue("input")
        let output = paramValue("output")
        guard !input.isEmpty else {
            appendConsoleOutput("Error: Input directory is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing input")
            return
        }
        guard !output.isEmpty else {
            appendConsoleOutput("Error: Output directory is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing output")
            return
        }
        let pattern = paramValue("pattern").isEmpty ? "descriptive" : paramValue("pattern")
        let copy = paramValue("copy") == "true"
        let verbose = paramValue("verbose") == "true"

        let inputScoped = securityScopedURLs["input"] ?? securityScopedURLs["inputPath"]
        let outputScoped = securityScopedURLs["output"]
        let aIn = inputScoped?.startAccessingSecurityScopedResource() ?? false
        let aOut = outputScoped?.startAccessingSecurityScopedResource() ?? false
        defer {
            if aIn { inputScoped?.stopAccessingSecurityScopedResource() }
            if aOut { outputScoped?.stopAccessingSecurityScopedResource() }
        }
        let inputURL = inputScoped ?? URL(fileURLWithPath: input)
        // Sandbox/TCC-resilient output directory (organize writes a folder tree).
        let _orgOut = OutputAccess.resolveWritableURL(forPath: output, scopedURL: outputScoped, subfolder: "StudyOrganize", isDirectory: true)
        let outputURL = _orgOut.url
        if let note = _orgOut.note { appendConsoleOutput(note + "\n") }

        let (output_, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var log = ""
            do {
                // Organize via the shared DICOMKit StudyOrganizer — identical file
                // naming/ordering and the same copy/move "already exists" error as the
                // CLI (Sources/DICOMKit/Study/StudyOrganizer.swift). Output is written
                // under the sandbox-resolved outputURL.
                try StudyOrganizer().organize(
                    inputPath: inputURL.path, outputPath: outputURL.path,
                    pattern: pattern, copy: copy, verbose: verbose,
                    log: { log += $0 + "\n" })
                return (log, 0)
            } catch let e as StudyError {
                return (log + "Error: \(e.errorDescription ?? "\(e)")\n", 1)
            } catch {
                return (log + "Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output_)
        addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: exitCode, output: output_)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-study : summary

    private func executeDicomStudySummary() async {
        let path = paramValue("path")
        guard !path.isEmpty else {
            appendConsoleOutput("Error: Study path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing path")
            return
        }
        let format = paramValue("summary-format").isEmpty ? "table" : paramValue("summary-format")
        let verbose = paramValue("verbose") == "true"

        let scoped = securityScopedURLs["path"] ?? securityScopedURLs["inputPath"]
        let accessing = scoped?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scoped?.stopAccessingSecurityScopedResource() } }
        let pathURL = scoped ?? URL(fileURLWithPath: path)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            guard FileManager.default.fileExists(atPath: pathURL.path) else {
                return ("Error: Directory not found: \(pathURL.path)\n", 1)
            }
            let studies = StudyScanner.scanStudies(at: pathURL.path)
            if studies.isEmpty { return ("Error: No DICOM files found in the specified directory\n", 1) }
            // Render via the shared DICOMKit engine — same code the CLI uses.
            do {
                let out = try StudyReport.renderSummary(studies: studies, format: format, verbose: verbose)
                return (out, 0)
            } catch {
                return ("Error: Invalid format: \(format). Use 'table', 'json', or 'csv'\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-study : check

    private func executeDicomStudyCheck() async {
        let path = paramValue("path")
        guard !path.isEmpty else {
            appendConsoleOutput("Error: Study path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing path")
            return
        }
        let expectedSeries = Int(paramValue("expected-series"))
        let expectedInstances = Int(paramValue("expected-instances"))
        let reportPath = paramValue("report")
        let verbose = paramValue("verbose") == "true"

        let scoped = securityScopedURLs["path"] ?? securityScopedURLs["inputPath"]
        let reportScoped = securityScopedURLs["report"] ?? securityScopedURLs["output"]
        let accessing = scoped?.startAccessingSecurityScopedResource() ?? false
        let accessingReport = reportScoped?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessing { scoped?.stopAccessingSecurityScopedResource() }
            if accessingReport { reportScoped?.stopAccessingSecurityScopedResource() }
        }
        let pathURL = scoped ?? URL(fileURLWithPath: path)
        let reportURL: URL? = reportPath.isEmpty ? nil : (reportScoped ?? URL(fileURLWithPath: reportPath))

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            guard FileManager.default.fileExists(atPath: pathURL.path) else {
                return ("Error: Directory not found: \(pathURL.path)\n", 1)
            }
            var out = ""
            if verbose { out += "Checking study completeness: \(pathURL.path)\n" }
            let studies = StudyScanner.scanStudies(at: pathURL.path)
            guard let study = studies.first else {
                return (out + "Error: No DICOM files found in the specified directory\n", 1)
            }
            // Evaluate via the shared DICOMKit engine — same code the CLI uses.
            let result = StudyReport.evaluateCompleteness(
                study: study, expectedSeries: expectedSeries, expectedInstances: expectedInstances)
            let issues = result.issues
            out += result.output

            if let reportURL = reportURL {
                let report = issues.joined(separator: "\n")
                // Sandbox/TCC-resilient: prefer the scoped URL; else try the typed path;
                // on failure fall back to ~/Downloads/DICOMStudio and note the redirect.
                do {
                    let res = try OutputAccess.writeString(report, toPath: reportURL.path,
                                                           scopedURL: reportScoped, subfolder: "StudyCheck")
                    out += "Report written to: \(res.url.path)\n"
                    if let note = res.note { out += note + "\n" }
                } catch {
                    return (out + "Error: Write error: \(error.localizedDescription)\n", 1)
                }
            }
            return (out, 0)
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-study : stats

    private func executeDicomStudyStats() async {
        let path = paramValue("path")
        guard !path.isEmpty else {
            appendConsoleOutput("Error: Study path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing path")
            return
        }
        let detailed = paramValue("detailed") == "true"
        let format = paramValue("stats-format").isEmpty ? "text" : paramValue("stats-format")

        let scoped = securityScopedURLs["path"] ?? securityScopedURLs["inputPath"]
        let accessing = scoped?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scoped?.stopAccessingSecurityScopedResource() } }
        let pathURL = scoped ?? URL(fileURLWithPath: path)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            guard FileManager.default.fileExists(atPath: pathURL.path) else {
                return ("Error: Directory not found: \(pathURL.path)\n", 1)
            }
            let studies = StudyScanner.scanStudies(at: pathURL.path)
            guard let study = studies.first else {
                return ("Error: No DICOM files found in the specified directory\n", 1)
            }
            // Compute + render via the shared DICOMKit engine — same code as the CLI.
            let stats = StudyReport.computeStatistics(for: study, detailed: detailed)
            do {
                let out = try StudyReport.renderStats(stats, detailed: detailed, format: format)
                return (out, 0)
            } catch {
                return ("Error: Failed to encode JSON\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-study : compare

    private func executeDicomStudyCompare() async {
        let path1 = paramValue("path1")
        let path2 = paramValue("path2")
        guard !path1.isEmpty, !path2.isEmpty else {
            appendConsoleOutput("Error: Both study directories are required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: 1, output: "Missing path")
            return
        }
        let format = paramValue("compare-format").isEmpty ? "text" : paramValue("compare-format")

        let scoped1 = securityScopedURLs["path1"] ?? securityScopedURLs["inputPath"]
        let scoped2 = securityScopedURLs["path2"]
        let a1 = scoped1?.startAccessingSecurityScopedResource() ?? false
        let a2 = scoped2?.startAccessingSecurityScopedResource() ?? false
        defer {
            if a1 { scoped1?.stopAccessingSecurityScopedResource() }
            if a2 { scoped2?.stopAccessingSecurityScopedResource() }
        }
        let url1 = scoped1 ?? URL(fileURLWithPath: path1)
        let url2 = scoped2 ?? URL(fileURLWithPath: path2)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            guard FileManager.default.fileExists(atPath: url1.path) else {
                return ("Error: Directory not found: \(url1.path)\n", 1)
            }
            guard FileManager.default.fileExists(atPath: url2.path) else {
                return ("Error: Directory not found: \(url2.path)\n", 1)
            }
            let studies1 = StudyScanner.scanStudies(at: url1.path)
            let studies2 = StudyScanner.scanStudies(at: url2.path)
            guard let s1 = studies1.first else { return ("Error: No DICOM files found in the specified directory\n", 1) }
            guard let s2 = studies2.first else { return ("Error: No DICOM files found in the specified directory\n", 1) }
            // Compare + render via the shared DICOMKit engine — same code as the CLI.
            let cmp = StudyReport.compareStudies(s1, s2)
            do {
                let out = try StudyReport.renderComparison(cmp, format: format, verbose: false)
                return (out, 0)
            } catch {
                return ("Error: Failed to encode JSON\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-study", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-image Execution

    /// Converts standard image files (JPEG/PNG/TIFF/BMP/GIF) to DICOM Secondary
    /// Capture, faithfully reproducing the `dicom-image` CLI in-process using
    /// CoreGraphics/ImageIO + DICOMKit. Supports single-file, recursive batch
    /// directory, and multi-page TIFF splitting, plus optional EXIF extraction.
    private func executeDicomImage() async {
        let input = paramValue("input")
        guard !input.isEmpty else {
            appendConsoleOutput("Error: Input path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-image", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let outputRaw = paramValue("output")
        let outputPath: String? = outputRaw.isEmpty ? nil : outputRaw
        let patientName = paramValue("patient-name")
        let patientID = paramValue("patient-id")
        let studyDescription = paramValue("study-description").isEmpty ? nil : paramValue("study-description")
        let seriesDescription = paramValue("series-description").isEmpty ? nil : paramValue("series-description")
        let studyUIDArg = paramValue("study-uid").isEmpty ? nil : paramValue("study-uid")
        let seriesUIDArg = paramValue("series-uid").isEmpty ? nil : paramValue("series-uid")
        let seriesNumber = Int(paramValue("series-number"))
        let instanceNumberArg = Int(paramValue("instance-number"))
        let modalityVal = paramValue("modality").isEmpty ? "OT" : paramValue("modality")
        let useExif = paramValue("use-exif") == "true"
        let splitPages = paramValue("split-pages") == "true"
        let recursive = paramValue("recursive") == "true"
        let verbose = paramValue("verbose") == "true"

        // Security-scoped access for input and output (when provided as bookmarks).
        let inputScopedURL = securityScopedURLs["input"]
        let inputAccessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if inputAccessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }
        let outputScopedURL = securityScopedURLs["output"]
        let outputAccessing = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if outputAccessing { outputScopedURL?.stopAccessingSecurityScopedResource() } }

        let inputURL = inputScopedURL ?? URL(fileURLWithPath: input)
        // Resolve the output URL: prefer a scoped bookmark; else probe the typed path and
        // redirect to ~/Downloads/DICOMStudio if it isn't writable (sandbox/TCC).
        let resolvedOutputURL: URL?
        if let scoped = outputScopedURL {
            resolvedOutputURL = scoped
        } else if let op = outputPath, !op.isEmpty {
            let r = OutputAccess.resolveWritableURL(forPath: op, scopedURL: nil,
                                                    subfolder: "ImageConversion",
                                                    isDirectory: recursive || splitPages)
            if let note = r.note { appendConsoleOutput(note + "\n") }
            resolvedOutputURL = r.url
        } else {
            resolvedOutputURL = nil
        }

        #if canImport(CoreGraphics)
        let (output, exitCode) = await Task.detached(priority: .userInitiated) {
            () -> (String, Int) in
            let fm = FileManager.default

            // Validate input exists.
            guard fm.fileExists(atPath: inputURL.path) else {
                return ("Error: Input path not found: \(inputURL.path)\n", 1)
            }

            // Patient identity is mandatory for any conversion.
            guard !patientName.isEmpty else {
                return ("Error: Patient Name is required for conversion (--patient-name)\n", 1)
            }
            guard !patientID.isEmpty else {
                return ("Error: Patient ID is required for conversion (--patient-id)\n", 1)
            }

            var out = ""

            // Pixel extraction, EXIF mapping, and Secondary Capture assembly now
            // come from the shared DICOMKit ImageConverter — the exact same code
            // the dicom-image CLI runs. These thin wrappers keep call sites tidy.
            func generateUID() -> String { ImageConverter.generateUID() }
            func isImageFile(_ url: URL) -> Bool { ImageConverter.isImageFile(url) }

            func makeMetadata(studyUID: String, seriesUID: String, instanceNumber: Int) -> ImageConverter.Metadata {
                ImageConverter.Metadata(
                    patientName: patientName, patientID: patientID,
                    studyUID: studyUID, seriesUID: seriesUID, instanceNumber: instanceNumber,
                    studyDescription: studyDescription, seriesDescription: seriesDescription,
                    modality: modalityVal, seriesNumber: seriesNumber)
            }

            // Loads, encodes and writes a single image (page 0) to a .dcm file URL
            // via the shared engine. Output is written here so the sandbox-resolved
            // path is honored.
            func convertImageFile(
                imageURL: URL,
                outputURL: URL,
                studyUID: String,
                seriesUID: String,
                instanceNumber: Int
            ) -> String? {
                do {
                    let data = try ImageConverter.secondaryCaptureData(
                        imageURL: imageURL,
                        metadata: makeMetadata(studyUID: studyUID, seriesUID: seriesUID, instanceNumber: instanceNumber),
                        useExif: useExif)
                    try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: outputURL, options: .atomic)
                    return nil
                } catch let e as ImageConversionError {
                    return e.errorDescription
                } catch {
                    return error.localizedDescription
                }
            }

            // MARK: Dispatch on input kind.

            var isDir: ObjCBool = false
            _ = fm.fileExists(atPath: inputURL.path, isDirectory: &isDir)

            if isDir.boolValue {
                // ---- Directory (batch) conversion ----
                guard recursive else {
                    return ("Error: Directory processing requires --recursive flag\n", 1)
                }
                let outputDirURL = resolvedOutputURL ?? inputURL.appendingPathComponent("dicom")
                do {
                    try fm.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
                } catch {
                    return ("Error: \(error.localizedDescription)\n", 1)
                }
                if verbose {
                    out += "Converting images from: \(inputURL.path)\n"
                    out += "Output directory: \(outputDirURL.path)\n\n"
                }

                let finalStudyUID = studyUIDArg ?? generateUID()
                let finalSeriesUID = seriesUIDArg ?? generateUID()
                var instanceNum = instanceNumberArg ?? 1
                var successCount = 0
                var failureCount = 0

                let enumerator = fm.enumerator(
                    at: inputURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    guard let isRegular = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                          isRegular else { continue }
                    guard isImageFile(fileURL) else {
                        if verbose { out += "\u{2298} \(fileURL.lastPathComponent): Not a supported image file\n" }
                        continue
                    }
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    let outFileURL = outputDirURL.appendingPathComponent("\(baseName).dcm")
                    if let err = convertImageFile(
                        imageURL: fileURL, outputURL: outFileURL,
                        studyUID: finalStudyUID, seriesUID: finalSeriesUID,
                        instanceNumber: instanceNum
                    ) {
                        failureCount += 1
                        if verbose { out += "\u{2717} \(fileURL.lastPathComponent): \(err)\n" }
                    } else {
                        successCount += 1
                        instanceNum += 1
                        if verbose { out += "\u{2713} \(fileURL.lastPathComponent) \u{2192} \(outFileURL.lastPathComponent)\n" }
                    }
                }

                out += "\nConversion complete:\n"
                out += "  Successful: \(successCount)\n"
                if failureCount > 0 { out += "  Failed: \(failureCount)\n" }
                out += "  Study UID: \(finalStudyUID)\n"
                out += "  Series UID: \(finalSeriesUID)\n"
                out += "  Output directory: \(outputDirURL.path)\n"
                return (out, successCount > 0 || failureCount == 0 ? 0 : 1)
            }

            let ext = inputURL.pathExtension.lowercased()
            if splitPages && (ext == "tiff" || ext == "tif") {
                // ---- Multi-page TIFF split (shared ImageConverter) ----
                let pageCount: Int
                do { pageCount = try ImageConverter.pageCount(of: inputURL) }
                catch { return ("Error: Failed to load image file\n", 1) }
                guard pageCount > 0 else {
                    return ("Error: TIFF file contains no pages\n", 1)
                }
                let outputDirURL: URL
                if let resolved = resolvedOutputURL {
                    outputDirURL = resolved
                } else {
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    outputDirURL = inputURL.deletingLastPathComponent().appendingPathComponent("\(baseName)_frames")
                }
                do {
                    try fm.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
                } catch {
                    return ("Error: \(error.localizedDescription)\n", 1)
                }
                if verbose {
                    out += "Splitting multi-page TIFF: \(inputURL.lastPathComponent)\n"
                    out += "Pages: \(pageCount)\n"
                    out += "Output directory: \(outputDirURL.path)\n\n"
                }
                let finalStudyUID = studyUIDArg ?? generateUID()
                let finalSeriesUID = seriesUIDArg ?? generateUID()
                for pageIndex in 0..<pageCount {
                    let fileName = String(format: "frame_%04d.dcm", pageIndex + 1)
                    let outFileURL = outputDirURL.appendingPathComponent(fileName)
                    do {
                        let data = try ImageConverter.secondaryCaptureData(
                            imageURL: inputURL, pageIndex: pageIndex,
                            metadata: makeMetadata(studyUID: finalStudyUID, seriesUID: finalSeriesUID,
                                                   instanceNumber: (instanceNumberArg ?? 1) + pageIndex),
                            useExif: false)
                        try data.write(to: outFileURL, options: .atomic)
                        if verbose { out += "\u{2713} Page \(pageIndex + 1) \u{2192} \(fileName)\n" }
                    } catch {
                        if verbose { out += "\u{2717} Page \(pageIndex + 1): \(error.localizedDescription)\n" }
                    }
                }
                out += "\nMulti-page TIFF conversion complete:\n"
                out += "  Pages: \(pageCount)\n"
                out += "  Output directory: \(outputDirURL.path)\n"
                return (out, 0)
            }

            // ---- Single-file conversion ----
            let finalOutputURL: URL
            if let resolved = resolvedOutputURL {
                finalOutputURL = resolved
            } else {
                finalOutputURL = inputURL.deletingPathExtension().appendingPathExtension("dcm")
            }
            if verbose { out += "Converting image: \(inputURL.path)\n" }
            if let err = convertImageFile(
                imageURL: inputURL, outputURL: finalOutputURL,
                studyUID: studyUIDArg ?? generateUID(),
                seriesUID: seriesUIDArg ?? generateUID(),
                instanceNumber: instanceNumberArg ?? 1
            ) {
                return ("Error: \(err)\n", 1)
            }
            if verbose {
                out += "\u{2713} Converted to: \(finalOutputURL.path)\n"
            } else {
                out += "Converted: \(finalOutputURL.path)\n"
            }
            return (out, 0)
        }.value
        #else
        let output = "Error: Image conversion not supported on this platform\n"
        let exitCode = 1
        #endif

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-image", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-export Execution

    /// Advanced DICOM image export: single image (+EXIF), contact sheet, animated GIF, and bulk export.
    /// Reimplements the dicom-export CLI in-process using DICOMKit rendering + CoreGraphics/ImageIO.
    private func executeDicomExport() async {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let operation = paramValue("operation").isEmpty ? "single" : paramValue("operation")
        let inputPath = paramValue("inputPath")
        let outputPath = paramValue("output")

        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-export", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }
        guard !outputPath.isEmpty else {
            appendConsoleOutput("Error: Output path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-export", command: commandPreview, exitCode: 1, output: "Missing output path")
            return
        }

        // Gather all parameter values on the MainActor before detaching.
        let formatSel: String
        switch operation {
        case "contact-sheet": formatSel = paramValue("sheet-format").isEmpty ? "png" : paramValue("sheet-format")
        case "bulk":          formatSel = paramValue("bulk-format").isEmpty ? "png" : paramValue("bulk-format")
        case "single":        formatSel = paramValue("format").isEmpty ? "jpeg" : paramValue("format")
        default:              formatSel = "png"
        }
        let quality = Int(paramValue("quality")) ?? 90
        let embedMetadata = paramValue("embed-metadata") == "true"
        let exifFieldsRaw = paramValue("exif-fields")
        let frame = Int(paramValue("frame"))
        let applyWindow = paramValue("apply-window") == "true"
        let windowCenter = Double(paramValue("window-center"))
        let windowWidth = Double(paramValue("window-width"))
        let columns = max(1, Int(paramValue("columns")) ?? 4)
        let thumbnailSize = max(16, Int(paramValue("thumbnail-size")) ?? 256)
        let spacing = max(0, Int(paramValue("spacing")) ?? 4)
        let labels = paramValue("labels") == "true"
        let fps = Double(paramValue("fps")) ?? 10
        let loopCount = Int(paramValue("loop-count")) ?? 0
        let startFrame = Int(paramValue("start-frame")) ?? 0
        let endFrame = Int(paramValue("end-frame"))
        let scale = Double(paramValue("scale")) ?? 1.0
        let organizeBy = paramValue("organize-by").isEmpty ? "flat" : paramValue("organize-by")
        let recursive = paramValue("recursive") == "true"
        let verbose = paramValue("verbose") == "true"

        // Sandbox access.
        let inputScopedURL = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }
        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        // Sandbox/TCC-resilient output (single/contact-sheet/animate write a file; bulk a directory).
        let _exportOut = OutputAccess.resolveWritableURL(forPath: outputPath, scopedURL: outputScopedURL, subfolder: "Export", isDirectory: operation == "bulk")
        let outputURL = _exportOut.url
        if let note = _exportOut.note { appendConsoleOutput(note + "\n") }

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            var log = ""

            // MARK: helpers — pure export logic (EXIF, paths, window, encoding)
            // comes from the shared DICOMKit DICOMImageExporter; these thin
            // wrappers keep the orchestration call sites unchanged.

            func sanitizePathComponent(_ value: String) -> String {
                DICOMImageExporter.sanitizePathComponent(value)
            }

            func buildEXIFMetadata(from file: DICOMFile, fields: [String]?) -> CFDictionary {
                DICOMImageExporter.buildEXIFMetadata(from: file, fields: fields)
            }

            func fileExtension(_ format: String) -> String { format }

            func exportCGImage(_ image: CGImage, to url: URL, format: String, quality: Int, metadata: CFDictionary?) throws {
                let fmt = ExportImageFormat(rawValue: format.lowercased()) ?? .png
                try DICOMImageExporter.exportCGImage(image, to: url, format: fmt, quality: quality, metadata: metadata)
            }

            func determineWindow(from file: DICOMFile, pixelData: PixelData, frameIndex: Int,
                                 center: Double?, width: Double?) -> WindowSettings {
                DICOMImageExporter.determineWindowSettings(from: file, pixelData: pixelData,
                                                           frameIndex: frameIndex, windowCenter: center, windowWidth: width)
            }

            func renderFrame(file: DICOMFile, frameIndex: Int, applyWindow: Bool,
                             center: Double?, width: Double?) throws -> CGImage? {
                if applyWindow {
                    if let c = center, let w = width {
                        return try file.tryRenderFrame(frameIndex, window: WindowSettings(center: c, width: w))
                    } else if let pd = file.pixelData() {
                        let window = determineWindow(from: file, pixelData: pd, frameIndex: frameIndex, center: center, width: width)
                        return try file.tryRenderFrame(frameIndex, window: window)
                    } else {
                        return try file.tryRenderFrameWithStoredWindow(frameIndex)
                    }
                } else {
                    return try file.tryRenderFrame(frameIndex)
                }
            }

            // Collect DICOM files from a directory (used by contact-sheet & bulk).
            func collectDICOMFiles(in dir: URL, recursive: Bool) -> [URL] {
                let options: FileManager.DirectoryEnumerationOptions = recursive
                    ? [.skipsHiddenFiles]
                    : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                guard let en = FileManager.default.enumerator(
                    at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: options
                ) else { return [] }
                let urls = (en.allObjects as? [URL] ?? []).filter {
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }
                return urls.sorted { $0.path < $1.path }
            }

            do {
                switch operation {

                // MARK: single
                case "single":
                    guard FileManager.default.fileExists(atPath: inputURL.path) else {
                        return ("Error: Input file not found: \(inputURL.path)\n", 1)
                    }
                    let fileData = try Data(contentsOf: inputURL)
                    let dicomFile = try DICOMFile.read(from: fileData)
                    guard let pixelData = dicomFile.pixelData() else {
                        return ("Error: No pixel data found in DICOM file\n", 1)
                    }
                    let frameIndex = frame ?? 0
                    let totalFrames = pixelData.descriptor.numberOfFrames
                    guard frameIndex >= 0 && frameIndex < totalFrames else {
                        return ("Error: Invalid frame \(frameIndex). File has \(totalFrames) frames (0-\(totalFrames - 1))\n", 1)
                    }
                    guard let image = try renderFrame(file: dicomFile, frameIndex: frameIndex,
                                                      applyWindow: applyWindow,
                                                      center: windowCenter, width: windowWidth) else {
                        return ("Error: Failed to render pixel data to image\n", 1)
                    }
                    // Determine output path; if output looks like a directory, derive filename.
                    var finalOutput = outputURL
                    var outIsDir: ObjCBool = false
                    let outExists = FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &outIsDir)
                    if (outExists && outIsDir.boolValue) || (!outExists && outputURL.pathExtension.isEmpty) {
                        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                        let baseName = inputURL.deletingPathExtension().lastPathComponent
                        finalOutput = outputURL.appendingPathComponent("\(baseName).\(fileExtension(formatSel))")
                    } else {
                        try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                                 withIntermediateDirectories: true)
                    }
                    var metadata: CFDictionary? = nil
                    if embedMetadata {
                        let fields = exifFieldsRaw.isEmpty ? nil : exifFieldsRaw.split(separator: ",").map(String.init)
                        metadata = buildEXIFMetadata(from: dicomFile, fields: fields)
                    }
                    try exportCGImage(image, to: finalOutput, format: formatSel, quality: quality, metadata: metadata)
                    log += "Exported: \(finalOutput.path)\n"
                    return (log, 0)

                // MARK: contact-sheet
                case "contact-sheet":
                    var inputs: [URL] = []
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir), isDir.boolValue {
                        inputs = collectDICOMFiles(in: inputURL, recursive: false)
                    } else {
                        inputs = [inputURL]
                    }
                    guard !inputs.isEmpty else {
                        return ("Error: No input files specified\n", 1)
                    }
                    let rows = max(1, (inputs.count + columns - 1) / columns)
                    let labelHeight = labels ? 20 : 0
                    let totalWidth = columns * thumbnailSize + (columns + 1) * spacing
                    let totalHeight = rows * (thumbnailSize + labelHeight) + (rows + 1) * spacing

                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    guard let context = CGContext(
                        data: nil, width: totalWidth, height: totalHeight,
                        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    ) else {
                        return ("Error: Failed to export image to file\n", 1)
                    }
                    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))

                    for (index, inPath) in inputs.enumerated() {
                        let col = index % columns
                        let row = index / columns
                        let x = spacing + col * (thumbnailSize + spacing)
                        let y = spacing + row * (thumbnailSize + labelHeight + spacing)
                        let flippedY = totalHeight - y - thumbnailSize
                        let rect = CGRect(x: x, y: flippedY, width: thumbnailSize, height: thumbnailSize)
                        do {
                            let fileData = try Data(contentsOf: inPath)
                            let dicomFile = try DICOMFile.read(from: fileData)
                            let cgImage: CGImage?
                            if applyWindow {
                                cgImage = try dicomFile.tryRenderFrameWithStoredWindow(0)
                            } else {
                                cgImage = try dicomFile.tryRenderFrame(0)
                            }
                            if let image = cgImage {
                                context.draw(image, in: rect)
                            }
                        } catch {
                            context.setFillColor(CGColor(red: 0.2, green: 0, blue: 0, alpha: 1))
                            context.fill(rect)
                        }
                    }
                    guard let sheetImage = context.makeImage() else {
                        return ("Error: Failed to render pixel data to image\n", 1)
                    }
                    try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                             withIntermediateDirectories: true)
                    try exportCGImage(sheetImage, to: outputURL, format: formatSel, quality: quality, metadata: nil)
                    log += "Contact sheet exported: \(outputURL.path) (\(inputs.count) images, \(columns)x\(rows) grid)\n"
                    return (log, 0)

                // MARK: animate
                case "animate":
                    guard FileManager.default.fileExists(atPath: inputURL.path) else {
                        return ("Error: Input file not found: \(inputURL.path)\n", 1)
                    }
                    let fileData = try Data(contentsOf: inputURL)
                    let dicomFile = try DICOMFile.read(from: fileData)
                    let totalFrames = dicomFile.numberOfFrames ?? 1
                    guard totalFrames > 0 else {
                        return ("Error: No frames available in DICOM file\n", 1)
                    }
                    let clampedStart = max(0, min(startFrame, totalFrames - 1))
                    let clampedEnd: Int
                    if let e = endFrame { clampedEnd = max(clampedStart, min(e, totalFrames - 1)) }
                    else { clampedEnd = totalFrames - 1 }
                    let clampedScale = max(0.1, min(2.0, scale))
                    let delay = fps > 0 ? 1.0 / fps : 0.1
                    let frameCount = clampedEnd - clampedStart + 1

                    try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                             withIntermediateDirectories: true)
                    guard let destination = CGImageDestinationCreateWithURL(
                        outputURL as CFURL, "com.compuserve.gif" as CFString, frameCount, nil
                    ) else {
                        return ("Error: Failed to export image to file\n", 1)
                    }
                    let gifFileProperties: [String: Any] = [
                        kCGImagePropertyGIFDictionary as String: [
                            kCGImagePropertyGIFLoopCount as String: loopCount
                        ]
                    ]
                    CGImageDestinationSetProperties(destination, gifFileProperties as CFDictionary)
                    let frameProperties: [String: Any] = [
                        kCGImagePropertyGIFDictionary as String: [
                            kCGImagePropertyGIFDelayTime as String: delay
                        ]
                    ]
                    let pixelData = dicomFile.pixelData()
                    for frameIndex in clampedStart...clampedEnd {
                        let cgImage: CGImage?
                        if applyWindow, let pd = pixelData {
                            let window = determineWindow(from: dicomFile, pixelData: pd, frameIndex: frameIndex,
                                                         center: windowCenter, width: windowWidth)
                            cgImage = try dicomFile.tryRenderFrame(frameIndex, window: window)
                        } else {
                            cgImage = try dicomFile.tryRenderFrame(frameIndex)
                        }
                        guard var image = cgImage else {
                            return ("Error: Failed to render pixel data to image\n", 1)
                        }
                        if clampedScale != 1.0 {
                            let newWidth = Int(Double(image.width) * clampedScale)
                            let newHeight = Int(Double(image.height) * clampedScale)
                            if newWidth > 0, newHeight > 0,
                               let cs = image.colorSpace,
                               let ctx = CGContext(
                                   data: nil, width: newWidth, height: newHeight,
                                   bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                               ) {
                                ctx.interpolationQuality = .high
                                ctx.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                                if let scaled = ctx.makeImage() { image = scaled }
                            }
                        }
                        CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
                    }
                    guard CGImageDestinationFinalize(destination) else {
                        return ("Error: Failed to export image to file\n", 1)
                    }
                    log += "Animated GIF exported: \(outputURL.path) (\(frameCount) frames, \(fps) fps)\n"
                    return (log, 0)

                // MARK: bulk
                case "bulk":
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        return ("Error: Input must be a directory: \(inputURL.path)\n", 1)
                    }
                    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                    let files = collectDICOMFiles(in: inputURL, recursive: recursive)

                    var fileCount = 0, successCount = 0, errorCount = 0
                    for fileURL in files {
                        fileCount += 1
                        do {
                            let fileData = try Data(contentsOf: fileURL)
                            let dicomFile = try DICOMFile.read(from: fileData)
                            guard dicomFile.pixelData() != nil else {
                                if verbose { log += "⚠ Skipping (no pixel data): \(fileURL.lastPathComponent)\n" }
                                continue
                            }
                            guard let image = try renderFrame(file: dicomFile, frameIndex: 0,
                                                              applyWindow: applyWindow,
                                                              center: nil, width: nil) else {
                                if verbose { log += "✗ Render failed: \(fileURL.lastPathComponent)\n" }
                                errorCount += 1
                                continue
                            }
                            let patientName = dicomFile.dataSet.string(for: .patientName)
                            let studyUID = dicomFile.dataSet.string(for: .studyInstanceUID)
                            let seriesUID = dicomFile.dataSet.string(for: .seriesInstanceUID)
                            let baseName = fileURL.deletingPathExtension().lastPathComponent + "." + fileExtension(formatSel)

                            // Build organized relative path.
                            let relative: String
                            switch organizeBy {
                            case "patient":
                                relative = sanitizePathComponent(patientName ?? "UNKNOWN") + "/" + baseName
                            case "study":
                                relative = sanitizePathComponent(patientName ?? "UNKNOWN") + "/"
                                    + sanitizePathComponent(studyUID ?? "UNKNOWN") + "/" + baseName
                            case "series":
                                relative = sanitizePathComponent(patientName ?? "UNKNOWN") + "/"
                                    + sanitizePathComponent(studyUID ?? "UNKNOWN") + "/"
                                    + sanitizePathComponent(seriesUID ?? "UNKNOWN") + "/" + baseName
                            default:
                                relative = baseName
                            }
                            let outFileURL = outputURL.appendingPathComponent(relative)
                            try FileManager.default.createDirectory(at: outFileURL.deletingLastPathComponent(),
                                                                    withIntermediateDirectories: true)
                            var metadata: CFDictionary? = nil
                            if embedMetadata { metadata = buildEXIFMetadata(from: dicomFile, fields: nil) }
                            try exportCGImage(image, to: outFileURL, format: formatSel, quality: quality, metadata: metadata)
                            successCount += 1
                            if verbose { log += "✓ \(outFileURL.path)\n" }
                        } catch {
                            errorCount += 1
                            if verbose { log += "✗ \(fileURL.lastPathComponent): \(error.localizedDescription)\n" }
                        }
                    }
                    log += "Bulk export complete: \(successCount)/\(fileCount) succeeded, \(errorCount) failed\n"
                    return (log, errorCount == 0 ? 0 : 1)

                default:
                    return ("Error: Unknown operation '\(operation)'\n", 1)
                }
            } catch {
                return (log + "Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-export", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
        #else
        appendConsoleOutput("Error: Image export requires macOS or iOS (CoreGraphics).\n")
        consoleStatus = .error; service.setConsoleStatus(.error)
        addToHistory(toolName: "dicom-export", command: commandPreview, exitCode: 1, output: "Unsupported platform")
        #endif
    }

    // MARK: - dicom-script Execution

    private func executeDicomScript() async {
        let operation = paramValue("operation").isEmpty ? "run" : paramValue("operation")

        // Template operation emits a canned starter script (no script file needed),
        // matching the CLI's `dicom-script template <name>` stdout.
        if operation == "template" {
            let name = paramValue("templateName")
            // Emit the canned starter script from the shared DICOMKit
            // TemplateGenerator — the exact same templates the CLI uses.
            do {
                let template = try TemplateGenerator().generate(templateName: name)
                appendConsoleOutput(template)
                consoleStatus = .success; service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-script", command: commandPreview, exitCode: 0, output: template)
            } catch {
                appendConsoleOutput("Error: Unknown template '\(name)'.\n")
                consoleStatus = .error; service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-script", command: commandPreview, exitCode: 1, output: "Invalid template")
            }
            return
        }

        let scriptPath = paramValue("scriptPath")
        guard !scriptPath.isEmpty else {
            appendConsoleOutput("Error: Script file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-script", command: commandPreview, exitCode: 1, output: "Missing script path")
            return
        }
        let dryRun = paramValue("dryRun") == "true"
        let verbose = paramValue("verbose") == "true"

        let scopedURL = securityScopedURLs["scriptPath"]
        let accessing = scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { scopedURL?.stopAccessingSecurityScopedResource() } }
        let url = scopedURL ?? URL(fileURLWithPath: scriptPath)

        let (output, exitCode): (String, Int) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let rawLines = content.split(separator: "\n", omittingEmptySubsequences: false)
                var assignments = 0, pipelines = 0, conditionals = 0, commands = 0
                var steps: [String] = []
                for raw in rawLines {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    if line.isEmpty || line.hasPrefix("#") { continue }
                    if line.hasPrefix("if ") { conditionals += 1; steps.append("if: \(line)") }
                    else if line.contains("|") { pipelines += 1; steps.append("pipeline: \(line)") }
                    else if line.contains("=") { assignments += 1; steps.append("set: \(line)") }
                    else { commands += 1; steps.append("run: \(line)") }
                }
                var out = "dicom-script \(operation): \(url.lastPathComponent)\n\n"
                out += "Parsed \(steps.count) step(s): "
                out += "\(commands) command(s), \(assignments) variable(s), "
                out += "\(pipelines) pipeline(s), \(conditionals) conditional(s)\n"
                if operation == "validate" {
                    out += "\nScript parsed successfully.\n"
                } else {
                    out += "\nPlanned steps:\n"
                    for (idx, step) in steps.enumerated() {
                        out += "  \(idx + 1). \(step)\n"
                    }
                    if !dryRun {
                        out += "\nNote: in-app execution shows the plan only. Run the script with the\n"
                        out += "dicom-script CLI in a terminal to execute the nested tool operations.\n"
                    }
                }
                if verbose { out += "\n(\(rawLines.count) total lines)\n" }
                return (out, 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-script", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    /// Ensures the directories referenced by any output-path parameters exist,
    /// so writing output files succeeds (e.g. the default DICOM_Output folder).
    /// Combined with the sandbox temporary-exception entitlement, this fixes
    /// read/write permission for the configured input/output folders.
    private func ensureOutputDirectories() {
        for def in parameterDefinitions where def.parameterType == .outputPath {
            let value = paramValue(def.id)
            guard !value.isEmpty else { continue }
            let url = URL(fileURLWithPath: value)
            let dir = value.hasSuffix("/") ? url : url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Executes the currently selected command.
    /// For dicom-echo, performs a real C-ECHO via DICOMVerificationService.
    public func executeCommand() async {
        guard let tool = selectedTool() else { return }
        rebuildCommandPreview()
        ensureOutputDirectories()

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
        case "dicom-qido":
            await executeDicomQIDO()
        case "dicom-wado":
            await executeDicomWADO()
        case "dicom-stow":
            await executeDicomSTOW()
        case "dicom-ups":
            await executeDicomUPS()
        case "dicom-convert":
            await executeDicomConvert()
        case "dicom-validate":
            await executeDicomValidate()
        case "dicom-anon":
            await executeDicomAnon()
        case "dicom-info":
            await executeDicomInfo()
        case "dicom-dump":
            await executeDicomDump()
        case "dicom-tags":
            await executeDicomTags()
        case "dicom-diff":
            await executeDicomDiff()
        case "dicom-json":
            await executeDicomJSON()
        case "dicom-xml":
            await executeDicomXML()
case "dicom-uid":
    await executeDicomUID()
case "dicom-dcmdir":
            await executeDicomDcmdir()
        case "dicom-pdf":
            await executeDicomPdf()
        case "dicom-pixedit":
            await executeDicomPixedit()
case "dicom-split":
            await executeDicomSplit()
        case "dicom-merge":
            await executeDicomMerge()
case "dicom-archive":
            await executeDicomArchive()
case "dicom-compress":
    await executeDicomCompress()
case "dicom-study":
            await executeDicomStudy()
        case "dicom-image":
            await executeDicomImage()
        case "dicom-export":
            await executeDicomExport()
        case "dicom-script":
            await executeDicomScript()
        default:
            appendConsoleOutput("⚠ Command execution not yet supported for \(tool.name).\n")
            consoleStatus = .idle
            service.setConsoleStatus(.idle)
        }
    }

    // MARK: - dicom-convert Execution

    /// Performs DICOM file conversion: transfer syntax conversion or image export.
    private func executeDicomConvert() async {
        let inputPath = paramValue("inputPath")
        let outputPath = paramValue("output")
        let format = paramValue("format").isEmpty ? "dicom" : paramValue("format")
        let transferSyntax = paramValue("transfer-syntax")
        let qualityStr = paramValue("quality")
        let windowCenterStr = paramValue("window-center")
        let windowWidthStr = paramValue("window-width")
        let applyWindow = paramValue("apply-window") == "true"
        let frameStr = paramValue("frame")
        let stripPrivate = paramValue("strip-private") == "true"
        let recursive = paramValue("recursive") == "true"
        let validateOutput = paramValue("validate") == "true"
        let force = paramValue("force") == "true"

        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }
        guard !outputPath.isEmpty else {
            appendConsoleOutput("Error: Output path is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: "Missing output path")
            return
        }

        // Gain sandbox access via security-scoped URLs
        let inputScopedURL = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let inputURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        // Sandbox/TCC-resilient output: prefer the picker's scoped URL; else probe the typed
        // path and redirect to ~/Downloads/DICOMStudio if it isn't writable. Covers both the
        // DICOM-convert Data write and the image-export CGImageDestination below.
        let _convOut = OutputAccess.resolveWritableURL(forPath: outputPath, scopedURL: outputScopedURL, subfolder: "dicom-convert")
        var outputURL = _convOut.url
        if let note = _convOut.note { appendConsoleOutput(note + "\n") }

        appendConsoleOutput("Input:  \(inputURL.path)\n")
        appendConsoleOutput("Output: \(outputURL.path)\n")
        appendConsoleOutput("Format: \(format)\n")
        if format == "dicom" && !transferSyntax.isEmpty {
            appendConsoleOutput("Transfer Syntax: \(transferSyntax)\n")
        }
        appendConsoleOutput("\n")

        // Check if the input is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
            appendConsoleOutput("Error: Input path not found: \(inputURL.path)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: "Input not found")
            return
        }

        // When converting a single file and the output path is (or was chosen as) a
        // directory, write the result *inside* that directory using the input filename.
        if !isDirectory.boolValue {
            var outIsDir: ObjCBool = false
            let outExists = FileManager.default.fileExists(atPath: outputURL.path, isDirectory: &outIsDir)
            let treatAsDir = (outExists && outIsDir.boolValue)
                || (!outExists && outputURL.pathExtension.isEmpty)
            if treatAsDir {
                // Ensure the directory exists
                try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                // Build output filename: input stem + appropriate extension
                let stem = inputURL.deletingPathExtension().lastPathComponent
                let ext: String
                switch format {
                case "png":  ext = "png"
                case "jpeg": ext = "jpg"
                case "tiff": ext = "tiff"
                default:     ext = "dcm"
                }
                outputURL = outputURL.appendingPathComponent("\(stem).\(ext)")
            } else if !outExists {
                // Output path has an extension (e.g. output.dcm) — ensure parent dir exists
                let parentDir = outputURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }
        } else {
            // Directory-to-directory: make sure output dir exists
            try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }

        if isDirectory.boolValue {
            guard recursive else {
                appendConsoleOutput("Error: Directory conversion requires the Recursive option to be enabled.\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: "Recursive required")
                return
            }
            await convertDirectory(
                inputURL: inputURL, outputURL: outputURL,
                format: format, transferSyntax: transferSyntax,
                quality: Int(qualityStr) ?? 90,
                windowCenter: Double(windowCenterStr), windowWidth: Double(windowWidthStr),
                applyWindow: applyWindow, frame: Int(frameStr),
                stripPrivate: stripPrivate, validateOutput: validateOutput, force: force
            )
        } else {
            do {
                try convertSingleFile(
                    inputURL: inputURL, outputURL: outputURL,
                    format: format, transferSyntax: transferSyntax,
                    quality: Int(qualityStr) ?? 90,
                    windowCenter: Double(windowCenterStr), windowWidth: Double(windowWidthStr),
                    applyWindow: applyWindow, frame: Int(frameStr),
                    stripPrivate: stripPrivate, validateOutput: validateOutput, force: force
                )
                appendConsoleOutput("\n✅ Conversion completed successfully.\n")
                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 0, output: "Success")
            } catch {
                appendConsoleOutput("\n❌ Conversion failed: \(error.localizedDescription)\n")
                consoleStatus = .error
                service.setConsoleStatus(.error)
                addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: error.localizedDescription)
            }
        }
    }

    /// Converts a single DICOM file to the specified format.
    private func convertSingleFile(
        inputURL: URL, outputURL: URL,
        format: String, transferSyntax: String,
        quality: Int,
        windowCenter: Double?, windowWidth: Double?,
        applyWindow: Bool, frame: Int?,
        stripPrivate: Bool, validateOutput: Bool, force: Bool
    ) throws {
        let fileData = try Data(contentsOf: inputURL)
        let dicomFile = try DICOMFile.read(from: fileData, force: force)

        let inputSize = fileData.count
        appendConsoleOutput("  Read \(inputURL.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(inputSize), countStyle: .file)))\n")

        switch format {
        case "png", "jpeg", "tiff":
            try exportDicomImage(
                dicomFile: dicomFile, outputURL: outputURL, format: format,
                quality: quality, windowCenter: windowCenter, windowWidth: windowWidth,
                applyWindow: applyWindow, frame: frame
            )
        default:
            // DICOM transfer syntax conversion
            guard !transferSyntax.isEmpty else {
                throw ConvertError.missingTransferSyntax
            }
            let targetSyntax = try parseTransferSyntax(transferSyntax)
            var dataSet = dicomFile.dataSet

            if stripPrivate {
                let publicTags = dataSet.tags.filter { !$0.isPrivate }
                var filtered = DataSet()
                for tag in publicTags {
                    if let element = dataSet[tag] {
                        filtered[tag] = element
                    }
                }
                let removedCount = dataSet.tags.count - publicTags.count
                dataSet = filtered
                appendConsoleOutput("  Stripped \(removedCount) private tag(s)\n")
            }

            // Determine source transfer syntax from the file
            let sourceSyntaxUID = dicomFile.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
            let sourceSyntax = TransferSyntax.from(uid: sourceSyntaxUID) ?? .explicitVRLittleEndian

            // Use DICOMCore TransferSyntaxConverter for full transcoding (pixel data included)
            // Use lossless compression config for lossless targets, default for lossy
            let compressionConfig: DICOMCore.CompressionConfiguration = targetSyntax.isLossless
                ? .lossless
                : .default
            let converter = TransferSyntaxConverter(
                configuration: TranscodingConfiguration(
                    preferredSyntaxes: [targetSyntax],
                    allowLossyCompression: !targetSyntax.isLossless,
                    preservePixelDataFidelity: targetSyntax.isLossless
                ),
                compressionConfiguration: compressionConfig
            )

            // Serialize the dataset to bytes in the source transfer syntax
            let sourceWriter = DICOMWriter(
                byteOrder: sourceSyntax.byteOrder,
                explicitVR: sourceSyntax.isExplicitVR
            )
            let dataSetBytes = dataSet.write(using: sourceWriter)

            // Transcode
            let result = try converter.transcode(
                dataSetData: dataSetBytes,
                from: sourceSyntax,
                to: targetSyntax
            )

            // Build output file: preamble + DICM + file meta info + transcoded dataset
            let sopClassUID = dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.7"
            let sopInstanceUID = dataSet.string(for: .sopInstanceUID) ?? UIDGenerator.generateSOPInstanceUID().value
            let outputFile = DICOMFile.create(
                dataSet: dataSet,
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                transferSyntaxUID: targetSyntax.uid
            )

            var outputData = Data()
            outputData.append(Data(repeating: 0, count: 128))  // Preamble
            outputData.append(contentsOf: "DICM".utf8)          // DICM prefix
            let fmiWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
            outputData.append(outputFile.fileMetaInformation.write(using: fmiWriter))
            outputData.append(result.data)

            // Create output directory if needed
            let outputDir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            try outputData.write(to: outputURL)
            appendConsoleOutput("  Wrote \(outputURL.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(outputData.count), countStyle: .file)))\n")
            let lossInfo = result.isLossless ? "lossless" : "lossy"
            appendConsoleOutput("  Transfer Syntax: \(targetSyntax.uid) (\(lossInfo))\n")
            if result.wasTranscoded {
                appendConsoleOutput("  Transcoded from \(sourceSyntax.uid)\n")
            }

            if validateOutput {
                let validationData = try Data(contentsOf: outputURL)
                _ = try DICOMFile.read(from: validationData, force: false)
                appendConsoleOutput("  ✓ Output validation passed\n")
            }
        }
    }

    /// Exports DICOM pixel data to an image format (PNG, JPEG, or TIFF).
    private func exportDicomImage(
        dicomFile: DICOMFile, outputURL: URL,
        format: String, quality: Int,
        windowCenter: Double?, windowWidth: Double?,
        applyWindow: Bool, frame: Int?
    ) throws {
        #if canImport(CoreGraphics)
        let pixelData = try dicomFile.tryPixelData()
        let frameIndex = frame ?? 0
        guard frameIndex < pixelData.descriptor.numberOfFrames else {
            throw ConvertError.invalidFrame(frameIndex, pixelData.descriptor.numberOfFrames)
        }

        appendConsoleOutput("  Exporting frame \(frameIndex) of \(pixelData.descriptor.numberOfFrames) as \(format.uppercased())\n")

        let cgImage: CGImage?
        if applyWindow {
            if let center = windowCenter, let width = windowWidth {
                let window = WindowSettings(center: center, width: width)
                cgImage = try dicomFile.tryRenderFrame(frameIndex, window: window)
            } else {
                cgImage = try dicomFile.tryRenderFrameWithStoredWindow(frameIndex)
            }
        } else {
            cgImage = try dicomFile.tryRenderFrame(frameIndex)
        }

        guard let image = cgImage else {
            throw ConvertError.renderFailed
        }

        let utType: String
        switch format {
        case "png":  utType = "public.png"
        case "jpeg": utType = "public.jpeg"
        case "tiff": utType = "public.tiff"
        default:     utType = "public.png"
        }

        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL, utType as CFString, 1, nil
        ) else {
            throw ConvertError.exportFailed
        }

        var options: [CFString: Any] = [:]
        if format == "jpeg" {
            options[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConvertError.exportFailed
        }

        appendConsoleOutput("  Wrote \(outputURL.lastPathComponent) (\(image.width)×\(image.height))\n")
        if format == "jpeg" {
            appendConsoleOutput("  JPEG quality: \(quality)%\n")
        }
        #else
        throw ConvertError.unsupportedPlatform
        #endif
    }

    /// Recursively converts all DICOM files in a directory.
    private func convertDirectory(
        inputURL: URL, outputURL: URL,
        format: String, transferSyntax: String,
        quality: Int,
        windowCenter: Double?, windowWidth: Double?,
        applyWindow: Bool, frame: Int?,
        stripPrivate: Bool, validateOutput: Bool, force: Bool
    ) async {
        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        } catch {
            appendConsoleOutput("Error: Could not create output directory: \(error.localizedDescription)\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: error.localizedDescription)
            return
        }

        guard let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            appendConsoleOutput("Error: Failed to enumerate directory.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1, output: "Enumeration failed")
            return
        }

        var fileCount = 0
        var successCount = 0
        var errorCount = 0

        // Collect file URLs via allObjects to avoid async iterator restriction on NSEnumerator
        let fileURLs: [URL] = (enumerator.allObjects as? [URL] ?? []).filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }

        for fileURL in fileURLs {

            fileCount += 1
            let relativePath = fileURL.path.replacingOccurrences(of: inputURL.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let outFileURL = outputURL.appendingPathComponent(relativePath)
            let outDir = outFileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

            do {
                try convertSingleFile(
                    inputURL: fileURL, outputURL: outFileURL,
                    format: format, transferSyntax: transferSyntax,
                    quality: quality, windowCenter: windowCenter, windowWidth: windowWidth,
                    applyWindow: applyWindow, frame: frame,
                    stripPrivate: stripPrivate, validateOutput: validateOutput, force: force
                )
                successCount += 1
                appendConsoleOutput("  ✓ \(relativePath)\n")
            } catch {
                errorCount += 1
                appendConsoleOutput("  ✗ \(relativePath): \(error.localizedDescription)\n")
            }
        }

        appendConsoleOutput("\nBatch conversion complete: \(successCount)/\(fileCount) succeeded, \(errorCount) failed\n")
        if errorCount == 0 {
            consoleStatus = .success
            service.setConsoleStatus(.success)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 0,
                         output: "\(successCount)/\(fileCount) converted")
        } else {
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-convert", command: commandPreview, exitCode: 1,
                         output: "\(successCount)/\(fileCount) succeeded, \(errorCount) failed")
        }
    }

    /// Parses a transfer syntax name string to a TransferSyntax value.
    private func parseTransferSyntax(_ name: String) throws -> TransferSyntax {
        switch name.lowercased() {
        // Uncompressed
        case "explicitvrlittleendian", "explicit", "evle":
            return .explicitVRLittleEndian
        case "implicitvrlittleendian", "implicit", "ivle":
            return .implicitVRLittleEndian
        case "explicitvrbigendian", "evbe":
            return .explicitVRBigEndian
        case "deflate", "deflated":
            return .deflatedExplicitVRLittleEndian
        // JPEG
        case "jpegbaseline", "jpeg-baseline", "jpeg":
            return .jpegBaseline
        case "jpegextended", "jpeg-extended":
            return .jpegExtended
        case "jpeglossless", "jpeg-lossless":
            return .jpegLossless
        case "jpeglosslesssv1", "jpeg-lossless-sv1":
            return .jpegLosslessSV1
        // JPEG 2000
        case "jpeg2000lossless", "jpeg2000-lossless", "j2k-lossless":
            return .jpeg2000Lossless
        case "jpeg2000", "jpeg2000-lossy", "j2k":
            return .jpeg2000
        case "htj2klossless", "htj2k-lossless":
            return .htj2kLossless
        case "htj2krpcllossless", "htj2k-rpcl", "htj2k-lossless-rpcl":
            return .htj2kRPCLLossless
        case "htj2k", "htj2k-lossy":
            return .htj2kLossy
        // JPEG-LS
        case "jpeglslossless", "jpeg-ls-lossless", "jpegls":
            return .jpegLSLossless
        case "jpeglsnearlossless", "jpeg-ls-near-lossless", "jpegls-near":
            return .jpegLSNearLossless
        // RLE
        case "rlelossless", "rle-lossless", "rle":
            return .rleLossless
        default:
            throw ConvertError.unknownTransferSyntax(name)
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
            // Reset running state so the listener can be restarted after
            // a failure (e.g. port already in use).
            scpIsRunning = false
            scpEventTask?.cancel()
            scpEventTask = nil
            storageSCP = nil
        default:
            break
        }
    }

    /// Clears the application event log.
    public func clearAppLog() {
        appLog.removeAll()
    }

    /// Parses host string that may contain an embedded port (e.g. "server:4242").
    /// Returns the host and resolved port, using the given explicit port if non-nil.
    private func resolveHostPort(_ hostValue: String, explicitPort: String?) -> (host: String, port: UInt16)? {
        guard !hostValue.isEmpty else { return nil }
        var host = hostValue
        var port: UInt16 = 11112

        // Strip pacs:// prefix for backward compatibility with saved defaults
        if host.hasPrefix("pacs://") {
            host = String(host.dropFirst(7))
        }

        // Check if host contains embedded port
        if let lastColon = host.lastIndex(of: ":") {
            let portStr = String(host[host.index(after: lastColon)...])
            if let embeddedPort = UInt16(portStr) {
                host = String(host[..<lastColon])
                port = embeddedPort
            }
        }

        // Explicit --port overrides embedded port
        if let ep = explicitPort, let explicitPortNum = UInt16(ep) {
            port = explicitPortNum
        }

        guard !host.isEmpty else { return nil }
        return (host, port)
    }

    // MARK: - dicom-validate Execution

    /// Validates DICOM files for IOD conformance, matching dicom-validate CLI output exactly.
    private func executeDicomValidate() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input path is required.\n")
            addToHistory(toolName: "dicom-validate", command: commandPreview, exitCode: 1, output: "Missing input path")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            return
        }

        let levelStr  = paramValue("level")
        let level     = Int(levelStr) ?? 3
        let iod       = paramValue("iod")
        let detailed  = paramValue("detailed") == "true"
        let recursive = paramValue("recursive") == "true"
        let strict    = paramValue("strict") == "true"
        let format    = paramValue("format").isEmpty ? "text" : paramValue("format")
        let outputPath = paramValue("output")
        let force     = paramValue("force") == "true"

        // Gain sandbox access via security-scoped URLs registered by the file picker.
        let inputScopedURL  = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput  = inputScopedURL?.startAccessingSecurityScopedResource()  ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput  { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        // Delegate to ValidationViewModel's engine via the shared helpers.
        // Pass the scoped URLs so it can re-acquire the scope in its own Task.
        let vm = ValidationViewModel()
        vm.inputPath   = (inputScopedURL ?? URL(fileURLWithPath: inputPath)).path
        vm.level       = level
        vm.iod         = iod
        vm.detailed    = detailed
        vm.recursive   = recursive
        vm.strict      = strict
        vm.format      = format == "json" ? .json : .text
        vm.outputPath  = outputPath
        vm.force       = force
        vm.inputScopedURL  = inputScopedURL
        vm.outputScopedURL = outputScopedURL

        vm.runValidation()

        // Wait for the async operation to complete
        var waited = 0
        while vm.isRunning && waited < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        let output = vm.validationOutput
        appendConsoleOutput(output)

        let hasErrors   = vm.lastResults.contains { !$0.errors.isEmpty }
        let hasWarnings = vm.lastResults.contains { !$0.warnings.isEmpty }
        let code: Int = hasErrors ? 1 : (strict && hasWarnings ? 2 : 0)

        // ValidationViewModel already writes the file if outputPath is set.
        // No duplicate write needed here.

        addToHistory(toolName: "dicom-validate", command: commandPreview, exitCode: code, output: output)
        consoleStatus = code == 0 ? .success : .error
        service.setConsoleStatus(code == 0 ? .success : .error)
    }

    // MARK: - dicom-anon Execution

    /// Anonymizes DICOM files, matching dicom-anon CLI output exactly.
    private func executeDicomAnon() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input path is required.\n")
            addToHistory(toolName: "dicom-anon", command: commandPreview, exitCode: 1, output: "Missing input path")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            return
        }

        let outputPath     = paramValue("output")
        let profileStr     = paramValue("profile").isEmpty ? "basic" : paramValue("profile")
        let shiftDaysStr   = paramValue("shift-dates")
        let regenUIDs      = paramValue("regenerate-uids") == "true"
        let removeTagsRaw  = paramValue("remove")
        let replaceRaw     = paramValue("replace")
        let keepTagsRaw    = paramValue("keep")
        let recursive      = paramValue("recursive") == "true"
        let dryRun         = paramValue("dry-run") == "true"
        let backup         = paramValue("backup") == "true"
        let auditLogPath   = paramValue("audit-log")
        let force          = paramValue("force") == "true"
        let verbose        = paramValue("verbose") == "true"

        // Gain sandbox access via security-scoped URLs registered by the file picker.
        let inputScopedURL  = securityScopedURLs["inputPath"]
        let outputScopedURL = securityScopedURLs["output"]
        let accessingInput  = inputScopedURL?.startAccessingSecurityScopedResource()  ?? false
        let accessingOutput = outputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessingInput  { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessingOutput { outputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        // Map CLI profile string to model enum
        let profile: AnonymizationProfile
        switch profileStr {
        case "clinical-trial": profile = .clinicalTrial
        case "research":       profile = .research
        default:               profile = .basic
        }

        let shiftDays = Int(shiftDaysStr)

        // Parse tag lists — one entry per line. Do NOT split on commas: a tag is written
        // `GGGG,EEEE` (and --replace is `GGGG,EEEE=value`), so comma-splitting `0010,0010`
        // would shred it into "0010"+"0010", match nothing, and silently drop the modifier
        // (F19 — same class as the F18 xml --filter-tag bug). The CLI honors these per-tag.
        func tagList(_ raw: String) -> [String] {
            raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        let removeTags   = tagList(removeTagsRaw)
        let replacePairs = tagList(replaceRaw)
        let keepTags     = tagList(keepTagsRaw)

        // Build a SecurityViewModel scoped just for this run.
        // Resolve a sandbox-writable output path: scoped URL → ~/Downloads path → fallback.
        let (resolvedOutputPath, outputRedirectNote) = SecurityViewModel.resolveWritableOutput(
            path: outputScopedURL?.path ?? outputPath,
            scopedURL: outputScopedURL
        )
        if let note = outputRedirectNote { appendConsoleOutput(note) }

        let secVM = SecurityViewModel()
        secVM.anonInputPath       = (inputScopedURL ?? URL(fileURLWithPath: inputPath)).path
        secVM.anonOutputPath      = resolvedOutputPath
        secVM.anonProfile         = profile
        secVM.anonShiftDatesEnabled = shiftDays != nil
        secVM.anonShiftDays       = shiftDays ?? 0
        secVM.anonRegenerateUIDs  = regenUIDs
        secVM.anonRemoveTags      = removeTags
        secVM.anonReplacePairs    = replacePairs
        secVM.anonKeepTags        = keepTags
        secVM.anonRecursive       = recursive
        secVM.anonDryRun          = dryRun
        secVM.anonBackup          = backup
        secVM.anonAuditLogPath    = auditLogPath
        secVM.anonForce           = force
        secVM.anonVerbose         = verbose
        secVM.anonInputScopedURL  = inputScopedURL
        secVM.anonOutputScopedURL = outputScopedURL

        secVM.runAnonymization()

        var waited = 0
        while secVM.anonIsRunning && waited < 300 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        let output = secVM.anonOutput
        appendConsoleOutput(output)

        let exitCode: Int = output.contains("Failed: 0") || output.contains("Total files: 0") ? 0 :
                              output.lowercased().contains("error") ? 1 : 0
        addToHistory(toolName: "dicom-anon", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - dicom-info Execution

    /// Displays DICOM file metadata — output matches `dicom-info` CLI tool exactly.
    private func executeDicomInfo() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-info", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let format      = paramValue("format").isEmpty ? "text" : paramValue("format")
        let tagFilters  = CommandBuilderHelpers.splitMultiValue(paramValue("tag"))
        let showPrivate = paramValue("show-private") == "true"
        let statistics  = paramValue("statistics") == "true"
        let force       = paramValue("force") == "true"

        let inputScopedURL = securityScopedURLs["inputPath"]
        let accessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }

        let fileURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            do {
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    return ("Error: File not found: \(fileURL.path)\n", 1)
                }
                let data = try Data(contentsOf: fileURL)
                let dicomFile = try DICOMFile.read(from: data, force: force)
                // Render via the shared DICOMKit.MetadataPresenter — the exact same
                // code the `dicom-info` CLI uses — so UI and CLI output cannot drift.
                let presenter = MetadataPresenter(
                    file: dicomFile, filterTags: tagFilters,
                    includePrivate: showPrivate, showStats: statistics
                )
                let rendered = try presenter.render(format: MetadataOutputFormat(rawValue: format) ?? .text)
                return (rendered, 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-info", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    // MARK: - ⚠️ TESTING-ONLY: terminal-vs-app parity check (all tools)
    //
    // Runs the REAL `dicom-*` binary for the selected tool as a subprocess and
    // compares its output to the app's in-process output, shown side-by-side in
    // the console. Requires the App Sandbox to be DISABLED. REMOVE BEFORE
    // PRODUCTION — see CLIToolTerminalCompare.swift and memory
    // `dicom-info-terminal-compare-testonly`.

    /// Clears the active terminal-compare result (returns the console to normal).
    public func clearTerminalCompare() {
        terminalCompareResult = nil
    }

    /// TESTING-ONLY. Runs the selected tool in-process AND via its real binary
    /// (argv taken verbatim from the command preview), then stores a side-by-side
    /// comparison. Works for any tool.
    public func runTerminalCompare() async {
        #if os(macOS)
        guard let tool = selectedToolID, !commandPreview.isEmpty else { return }

        isRunningTerminalCompare = true
        terminalCompareResult = nil
        defer { isRunningTerminalCompare = false }

        // 1. App (in-process) output — drive the real Studio code path.
        clearConsoleOutput()
        await executeCommand()
        let appOutput = consoleOutput

        // 2. argv from the exact command preview (single source of truth).
        let argv = CLIToolTerminalCompare.shellSplit(commandPreview)
        guard let executable = argv.first else { return }
        let arguments = Array(argv.dropFirst())

        // 3. Grant file access (sandbox-off test build), then run the binary AND
        //    compute the comparison entirely off the main actor. A large dump can
        //    be thousands of lines, so use a cheap O(n) line comparison — an
        //    O(n·m) LCS on the main thread would freeze the UI (the compare view
        //    shows raw side-by-side text, not a line-level diff).
        let basename = compareFixtureBasename()
        let scopedURLs = securityScopedURLs.values.map { ($0, $0.startAccessingSecurityScopedResource()) }
        let computed = await Task.detached { () -> (CLIToolTerminalCompare.Outcome, Int) in
            let oc = CLIToolTerminalCompare.run(tool: executable, arguments: arguments)
            let appLines  = CLIParityEngine.normalize(appOutput, fixtureBasename: basename)
            let termLines = CLIParityEngine.normalize(oc.stdout, fixtureBasename: basename)
            var diffCount = abs(appLines.count - termLines.count)
            for (a, b) in zip(appLines, termLines) where a != b { diffCount += 1 }
            return (oc, diffCount)
        }.value
        for (url, ok) in scopedURLs where ok { url.stopAccessingSecurityScopedResource() }

        // 4. Verdict from the cheap comparison.
        let outcome = computed.0
        let differing = computed.1
        let matched = outcome.launchError == nil && outcome.exitCode == 0 && differing == 0

        let note: String
        if let err = outcome.launchError {
            note = err
        } else if outcome.exitCode != 0 {
            note = "\(tool) exited with code \(outcome.exitCode)" + (outcome.stderr.isEmpty ? "" : ": \(outcome.stderr)")
        } else if matched {
            note = "✓ Terminal output matches the app output."
        } else {
            note = "⚠ \(differing) line(s) differ between terminal and app output."
        }

        let terminalText: String = {
            if let err = outcome.launchError { return err }
            if !outcome.stdout.isEmpty { return outcome.stdout }
            return outcome.stderr
        }()

        terminalCompareResult = CLIToolCompareResult(
            toolName: tool,
            appOutput: appOutput,
            terminalOutput: terminalText,
            binaryPath: outcome.binaryPath,
            commandLine: commandPreview,
            matched: matched,
            differingLineCount: differing,
            note: note)
        #endif
    }

    /// Best-effort fixture basename (from the first file-ish parameter) used to
    /// canonicalize absolute paths when diffing terminal vs app output.
    private func compareFixtureBasename() -> String {
        for key in ["inputPath", "input", "filePath", "file1", "file"] {
            let v = paramValue(key)
            if !v.isEmpty { return (v as NSString).lastPathComponent }
        }
        return ""
    }

    // dicom-info and dicom-dump now render through shared DICOMKit code
    // (`MetadataPresenter`, `HexDumper`/`HexDumper.tagDump`), so the previous
    // in-app renderers and value formatter were removed — one code path per tool
    // for UI and CLI.

    // MARK: - dicom-dump Execution

    /// Hex-dumps a DICOM file — output matches `dicom-dump` CLI tool exactly.
    private func executeDicomDump() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-dump", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let tagFilter    = paramValue("tag")
        let offsetStr    = paramValue("offset")
        let lengthStr    = paramValue("length")
        let bplStr       = paramValue("bytes-per-line")
        let highlightTag = paramValue("highlight")
        let annotate     = paramValue("annotate") == "true"
        let verbose      = paramValue("verbose") == "true"
        let force        = paramValue("force") == "true"
        let bytesPerLine = Int(bplStr) ?? 16

        let inputScopedURL = securityScopedURLs["inputPath"]
        let accessing = inputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { inputScopedURL?.stopAccessingSecurityScopedResource() } }

        let fileURL = inputScopedURL ?? URL(fileURLWithPath: inputPath)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            do {
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    return ("Error: File not found: \(fileURL.path)\n", 1)
                }
                let fileData = try Data(contentsOf: fileURL)

                // --tag: dump only the value bytes of that tag (shared core helper,
                // identical to the dicom-dump CLI).
                if !tagFilter.isEmpty {
                    let dicomFile = try DICOMFile.read(from: fileData, force: force)
                    guard let tag = Self.parseDumpTagStr(tagFilter) else {
                        return ("Error: Invalid tag format '\(tagFilter)'. Use GGGG,EEEE (e.g. 7FE0,0010).\n", 1)
                    }
                    // Cap to --length (default 65,536) — same as the CLI. Without
                    // this, dumping PixelData builds a multi-MB string and the
                    // SwiftUI console hangs in CoreText layout on the main thread.
                    guard let dump = HexDumper.tagDump(
                        tag: tag, in: dicomFile,
                        bytesPerLine: bytesPerLine, useColor: false, verbose: verbose,
                        maxBytes: Int(lengthStr) ?? 65_536
                    ) else {
                        return ("Tag \(tag.description) not found in file.\n", 1)
                    }
                    return (dump, 0)
                }

                // Parse start offset
                let startOffset: Int
                if offsetStr.lowercased().hasPrefix("0x") {
                    startOffset = Int(offsetStr.dropFirst(2), radix: 16) ?? 0
                } else {
                    startOffset = Int(offsetStr) ?? 0
                }

                guard startOffset >= 0, startOffset <= fileData.count else {
                    return ("Error: Offset \(startOffset) is out of range (file is \(fileData.count) bytes).\n", 1)
                }
                // When no explicit --length is given, cap the dump so a whole
                // (possibly large) file doesn't build a huge string and freeze
                // the UI. Pass --length to dump more.
                let defaultDumpCap = 65_536
                let lengthGiven = Int(lengthStr) != nil
                let requestedLength = Int(lengthStr) ?? min(defaultDumpCap, fileData.count - startOffset)
                let endOffset = min(startOffset + requestedLength, max(startOffset, fileData.count))
                let dataSlice = fileData[startOffset..<endOffset]

                let dicomFile: DICOMFile? = annotate ? (try? DICOMFile.read(from: fileData, force: force)) : nil
                let highlightTagObj: Tag? = highlightTag.isEmpty ? nil : Self.parseDumpTagStr(highlightTag)

                // Render via the shared DICOMKit.HexDumper — the same engine the
                // `dicom-dump` CLI uses — with color off for the plain console, so
                // the Compare-CLI view matches (ANSI is stripped in the diff).
                var dumpOut = HexDumper(
                    bytesPerLine: bytesPerLine, useColor: false,
                    annotate: annotate, verbose: verbose
                ).dump(
                    data: Data(dataSlice), startOffset: startOffset,
                    dicomFile: dicomFile, highlightTag: highlightTagObj
                )
                if !lengthGiven && endOffset < fileData.count {
                    dumpOut += "\n… showing first \(endOffset - startOffset) of \(fileData.count) bytes — pass --length to dump more.\n"
                }
                return (dumpOut, 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-dump", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    /// Parses a GGGG,EEEE or GGGGEEEE tag string.
    nonisolated private static func parseDumpTagStr(_ s: String) -> Tag? {
        let t = s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        if t.contains(",") {
            let parts = t.split(separator: ",")
            if parts.count == 2,
               let g = UInt16(parts[0].trimmingCharacters(in: .whitespaces), radix: 16),
               let e = UInt16(parts[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                return Tag(group: g, element: e)
            }
        } else if t.count == 8, let v = UInt32(t, radix: 16) {
            return Tag(group: UInt16((v >> 16) & 0xFFFF), element: UInt16(v & 0xFFFF))
        }
        return nil
    }

    // dicom-dump now renders through the shared `DICOMKit.HexDumper` (see
    // executeDicomDump), so the previous in-app hexDump/buildHexAnnotations
    // reimplementations were removed — there is one dump engine for UI and CLI.

    // MARK: - dicom-tags Execution

    /// Adds, modifies, or deletes tags in a DICOM file — output matches `dicom-tags` CLI tool.
    private func executeDicomTags() async {
        let inputPath = paramValue("inputPath")
        guard !inputPath.isEmpty else {
            appendConsoleOutput("Error: Input file path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-tags", command: commandPreview, exitCode: 1, output: "Missing input path")
            return
        }

        let outputPath     = paramValue("output")
        let setRaw         = paramValue("set")
        let deleteRaw      = paramValue("delete")
        let deletePrivate  = paramValue("delete-private") == "true"
        let copyFromPath   = paramValue("copy-from")
        let tagsRaw        = paramValue("tags")
        let verbose        = paramValue("verbose") == "true"
        let dryRun         = paramValue("dry-run") == "true"

        // --set / --delete are repeatable array options in the CLI; split
        // hex-tag aware so `0008,0090=...` survives and the values match the
        // repeated flags emitted in the command preview.
        let sets    = CommandBuilderHelpers.splitMultiValue(setRaw)
        let deletes = CommandBuilderHelpers.splitMultiValue(deleteRaw)
        // --tags (copy) is a single option the CLI itself comma-splits, so plain
        // comma splitting matches the CLI exactly here.
        let copyTags = tagsRaw.isEmpty ? [String]() : tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        guard !sets.isEmpty || !deletes.isEmpty || deletePrivate || !copyFromPath.isEmpty else {
            appendConsoleOutput("Error: No operations specified. Use --set, --delete, --delete-private, or --copy-from.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-tags", command: commandPreview, exitCode: 1, output: "No operations")
            return
        }

        // Sandbox access for input, output, copy-from
        let inputScopedURL    = securityScopedURLs["inputPath"]
        let outputScopedURL   = securityScopedURLs["output"]
        let copyFromScopedURL = securityScopedURLs["copy-from"]
        let accessIn  = inputScopedURL?.startAccessingSecurityScopedResource()    ?? false
        let accessOut = outputScopedURL?.startAccessingSecurityScopedResource()   ?? false
        let accessCF  = copyFromScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if accessIn  { inputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessOut { outputScopedURL?.stopAccessingSecurityScopedResource() }
            if accessCF  { copyFromScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let fileURL      = inputScopedURL ?? URL(fileURLWithPath: inputPath)
        let copyFromURL  = copyFromPath.isEmpty ? nil : (copyFromScopedURL ?? URL(fileURLWithPath: copyFromPath))

        // Resolve writable output path
        let (resolvedOutputPath, redirectNote) = SecurityViewModel.resolveWritableOutput(
            path: outputScopedURL?.path ?? outputPath,
            scopedURL: outputScopedURL
        )
        if let note = redirectNote { appendConsoleOutput(note) }

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            do {
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    return ("Error: File not found: \(fileURL.path)\n", 1)
                }
                let fileData = try Data(contentsOf: fileURL)
                let dicomFile = try DICOMFile.read(from: fileData)
                var dataSet = dicomFile.dataSet

                // Load copy-from file if requested
                var sourceDataSet: DataSet?
                if let cfURL = copyFromURL {
                    let cfData = try Data(contentsOf: cfURL)
                    let cfFile = try DICOMFile.read(from: cfData)
                    sourceDataSet = cfFile.dataSet
                }

                // Apply all operations via the shared DICOMKit engine — the exact
                // same TagEditor the `dicom-tags` CLI uses, so app and CLI cannot
                // drift. (Resolution and wording are unchanged: dictionary-based
                // names/VRs, unknown specifiers skipped with a note.)
                let descriptions = TagEditor().applyChanges(
                    to: &dataSet,
                    sets: sets,
                    deletes: deletes,
                    deletePrivate: deletePrivate,
                    sourceDataSet: sourceDataSet,
                    copyTags: copyTags,
                    verbose: verbose,
                    dryRun: dryRun
                )

                // Build output text
                var out = ""
                if verbose || dryRun {
                    for desc in descriptions { out += desc + "\n" }
                    out += "\(descriptions.count) change(s) applied.\n"
                    if dryRun { out += "Dry run complete — no files modified.\n" }
                } else {
                    out += "\(descriptions.count) change(s) applied.\n"
                }

                // Write output
                if !dryRun {
                    let modifiedFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: dataSet)
                    let outData = try modifiedFile.write()
                    // When --output is a directory, write <dir>/<inputName> instead
                    // of failing ("… couldn't be saved in the folder"). Resolved by
                    // the shared core helper, so the CLI lands on the same path.
                    let destPath = OutputPathResolver.resolveFileOutput(
                        output: resolvedOutputPath, input: fileURL.path)
                    let destURL  = URL(fileURLWithPath: destPath)
                    try FileManager.default.createDirectory(
                        at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try outData.write(to: destURL)
                    out += "Saved: \(destURL.path)\n"
                }

                return (out, 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-tags", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    nonisolated private static func tagsParseSpecifier(_ spec: String) -> Tag? {
        let t = spec.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        if t.contains(",") {
            let parts = t.split(separator: ",")
            if parts.count == 2,
               let g = UInt16(parts[0].trimmingCharacters(in: .whitespaces), radix: 16),
               let e = UInt16(parts[1].trimmingCharacters(in: .whitespaces), radix: 16) {
                return Tag(group: g, element: e)
            }
        } else if t.count == 8, t.allSatisfy({ $0.isHexDigit }), let v = UInt32(t, radix: 16) {
            return Tag(group: UInt16((v >> 16) & 0xFFFF), element: UInt16(v & 0xFFFF))
        }
        // Try tag name lookup via DICOMDictionary
        return DataElementDictionary.lookup(keyword: t)?.tag
    }

    // MARK: - dicom-diff Execution

    /// Compares two DICOM files — output matches `dicom-diff` CLI tool exactly.
    private func executeDicomDiff() async {
        let file1Path = paramValue("file1")
        let file2Path = paramValue("file2")
        guard !file1Path.isEmpty else {
            appendConsoleOutput("Error: File 1 path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-diff", command: commandPreview, exitCode: 1, output: "Missing file1")
            return
        }
        guard !file2Path.isEmpty else {
            appendConsoleOutput("Error: File 2 path is required.\n")
            consoleStatus = .error; service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-diff", command: commandPreview, exitCode: 1, output: "Missing file2")
            return
        }

        let format         = paramValue("format").isEmpty ? "text" : paramValue("format")
        let ignoreTagsRaw  = paramValue("ignore-tag")
        let ignorePrivate  = paramValue("ignore-private") == "true"
        let comparePixels  = paramValue("compare-pixels") == "true"
        let toleranceStr   = paramValue("tolerance")
        let quick          = paramValue("quick") == "true"
        let showIdentical  = paramValue("show-identical") == "true"
        let verbose        = paramValue("verbose") == "true"

        let tolerance = Double(toleranceStr) ?? 0.0
        let ignoreTags = CommandBuilderHelpers.splitMultiValue(ignoreTagsRaw)

        let file1ScopedURL = securityScopedURLs["file1"]
        let file2ScopedURL = securityScopedURLs["file2"]
        let access1 = file1ScopedURL?.startAccessingSecurityScopedResource() ?? false
        let access2 = file2ScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if access1 { file1ScopedURL?.stopAccessingSecurityScopedResource() }
            if access2 { file2ScopedURL?.stopAccessingSecurityScopedResource() }
        }

        let url1 = file1ScopedURL ?? URL(fileURLWithPath: file1Path)
        let url2 = file2ScopedURL ?? URL(fileURLWithPath: file2Path)

        let (output, exitCode) = await Task.detached(priority: .userInitiated) { () -> (String, Int) in
            do {
                guard FileManager.default.fileExists(atPath: url1.path) else {
                    return ("Error: File not found: \(url1.path)\n", 1)
                }
                guard FileManager.default.fileExists(atPath: url2.path) else {
                    return ("Error: File not found: \(url2.path)\n", 1)
                }

                let data1 = try Data(contentsOf: url1)
                let data2 = try Data(contentsOf: url2)
                let df1   = try DICOMFile.read(from: data1)
                let df2   = try DICOMFile.read(from: data2)

                // Resolve each ignore-tag by hex (GGGG,EEEE / GGGGEEEE) or by
                // keyword name (e.g. SOPInstanceUID) — matching the CLI's parseTag.
                let ignoreTagSet = Set(ignoreTags.compactMap { Self.tagsParseSpecifier($0) })

                // Compare + render via the shared DICOMKit engine — the exact same
                // code the `dicom-diff` CLI uses, so app and CLI cannot drift.
                let comparer = DICOMComparer(
                    file1: df1, file2: df2,
                    tagsToIgnore: ignoreTagSet, ignorePrivate: ignorePrivate,
                    comparePixels: comparePixels && !quick,
                    pixelTolerance: tolerance, showIdentical: showIdentical
                )
                let result = try comparer.compare()
                let report = ComparisonReport(
                    result: result,
                    file1Name: url1.lastPathComponent, file2Name: url2.lastPathComponent,
                    showIdentical: showIdentical
                )
                let outputFormat = ComparisonOutputFormat(rawValue: format) ?? .text
                var rendered = try report.render(format: outputFormat)

                // --verbose prints a comparison header before the results (matches CLI).
                if verbose {
                    rendered = "Comparing: \(url1.lastPathComponent)\n     with: \(url2.lastPathComponent)\n\n" + rendered
                }

                return (rendered, result.hasDifferences ? 1 : 0)
            } catch {
                return ("Error: \(error.localizedDescription)\n", 1)
            }
        }.value

        appendConsoleOutput(output)
        addToHistory(toolName: "dicom-diff", command: commandPreview, exitCode: exitCode, output: output)
        consoleStatus = exitCode == 0 ? .success : .error
        service.setConsoleStatus(exitCode == 0 ? .success : .error)
    }

    /// Performs a real C-ECHO against the server configured in the parameter fields.
    private func executeDicomEcho() async {
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")

        guard let server = resolveHostPort(hostValue, explicitPort: portValue.isEmpty ? nil : portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or 192.168.1.1).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-echo", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 30

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

            // Pass patient name as-is (matches CLI behavior)
            if !patientName.isEmpty {
                query = query.patientName(patientName)
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
        let protocol_ = paramValue("wado-protocol")
        if protocol_ == "wado-uri" {
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
        let metadataFlag = paramValue("metadata") == "true"
        let renderedFlag = paramValue("rendered") == "true"
        let thumbnailFlag = paramValue("thumbnail") == "true"
        let framesStr = paramValue("frames")
        let frameNumber = Int(framesStr.split(separator: ",").first ?? "") ?? 0

        // Determine effective mode from flags
        let mode: String
        if metadataFlag {
            mode = "metadata"
        } else if renderedFlag {
            mode = "rendered"
        } else if thumbnailFlag {
            mode = "thumbnail"
        } else if !framesStr.isEmpty {
            mode = "frames"
        } else if !instanceUID.isEmpty {
            mode = "instance"
        } else if !seriesUID.isEmpty {
            mode = "series"
        } else {
            mode = "study"
        }

        guard !studyUID.isEmpty else {
            appendConsoleOutput("Error: Study Instance UID is required.\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-wado", command: commandPreview, exitCode: 1, output: "Study UID is required")
            return
        }

        appendConsoleOutput("Retrieving from \(profile.baseURL) ...\n")
        appendConsoleOutput("  Mode:       \(mode)\n")
        appendConsoleOutput("  Study UID:  \(studyUID)\n")
        if !seriesUID.isEmpty { appendConsoleOutput("  Series UID: \(seriesUID)\n") }
        if !instanceUID.isEmpty { appendConsoleOutput("  Instance UID: \(instanceUID)\n") }
        if frameNumber > 0 { appendConsoleOutput("  Frame:      \(frameNumber)\n") }
        appendConsoleOutput("\n")

        let outputDir = resolvedOutputDir(paramValue("output"))
        let hierarchical = false

        // Track retrieved files for viewer integration
        lastRetrievedFiles.removeAll()
        lastRetrievedOutputURL = securityScopedURLs["output"]

        do {
            let client = try DICOMwebClientFactory.makeClient(from: profile)

            switch mode {
            case "instance", "frames":
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
                let formatParam = paramValue("format").lowercased()
                switch formatParam {
                case "png":
                    imageFormat = .png
                    fileExtension = "png"
                case "gif":
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
        let acceptType = paramValue("content-type")
        let framesStr = paramValue("frames")
        let frameNumber = Int(framesStr.split(separator: ",").first ?? "") ?? 0

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
        let hierarchical = false

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
            case "image/jp2":   contentType = .jpeg2000
            case "image/jph":   contentType = .htj2k
            case "image/jphc":  contentType = .htj2kContainer
            default:             contentType = .dicom
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
                case .jpeg:           ext = "jpg"
                case .png:            ext = "png"
                case .gif:            ext = "gif"
                case .jpeg2000:       ext = "jp2"
                case .htj2k:          ext = "jph"
                case .htj2kContainer: ext = "jphc"
                default:              ext = "bin"
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
        let batchSize = Int(paramValue("batch")) ?? 10
        let continueOnError = paramValue("continue-on-error") == "true"
        let recursive = true  // Always scan directories recursively

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
        appendConsoleOutput("  Batch size: \(batchSize)\n")
        appendConsoleOutput("\n")

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
        // Resolve workitem UID from the appropriate parameter based on operation
        let workitemUID: String
        switch operation {
        case "get":
            workitemUID = paramValue("get-uid")
        case "change-state":
            workitemUID = paramValue("update-uid")
        default:
            workitemUID = paramValue("workitem-uid")
        }

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

            case "create-workitem":
                // DICOMweb (UPS-RS) create flow
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
                // DICOMweb (UPS-RS) change-state flow
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
                case "CANCELED":  rawState = "CANCELED"
                default:          rawState = "IN PROGRESS"
                }

                // Per PS3.4 CC.2 UPS State Machine:
                //   SCHEDULED → IN PROGRESS  : client supplies a new Transaction UID
                //   IN PROGRESS → COMPLETED  : client MUST supply the same Transaction UID
                //   IN PROGRESS → CANCELED   : client MUST supply the same Transaction UID
                //
                // Per PS3.18 §11.5.2, the server NEVER returns the Transaction UID
                // in Retrieve Workitem responses — it acts as an access lock.
                // We cache it locally when claiming (IN PROGRESS) and auto-fill it
                // for subsequent COMPLETED / CANCELED transitions.
                let userTxUID = paramValue("transaction-uid")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                var effectiveTxUID: String
                if rawState == "IN PROGRESS" {
                    // New transition — generate a fresh Transaction UID
                    effectiveTxUID = userTxUID.isEmpty ? generateDICOMUID() : userTxUID
                } else {
                    // COMPLETED / CANCELED — must reuse the Transaction UID from IN PROGRESS.
                    // Check (in order): user-provided → cached from previous IN PROGRESS claim.
                    let cachedTxUID = upsTransactionUIDs[workitemUID]
                    if !userTxUID.isEmpty {
                        effectiveTxUID = userTxUID
                    } else if let cached = cachedTxUID, !cached.isEmpty {
                        effectiveTxUID = cached
                        appendConsoleOutput("  ℹ️  Using cached Transaction UID from IN PROGRESS claim\n")
                    } else {
                        appendConsoleOutput("Error: Transaction UID is required for \(rawState) transition.\n")
                        appendConsoleOutput("  💡 Use the Transaction UID returned when the workitem was moved to IN PROGRESS.\n")
                        consoleStatus = .error
                        service.setConsoleStatus(.error)
                        return
                    }
                }

                // Per PS3.18 §11.6 the Requesting AE may be appended as the last
                // path segment of the state URL.  Some servers (e.g. dcm4chee-arc)
                // **require** this segment; without it the route returns 404.
                // Use the server's Called AE Title (e.g. "DCM4CHEE") — this is the
                // AE that owns the UPS instance.
                let calledAE = paramValue("called-aet")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let requestingAE = calledAE.isEmpty ? "DCM4CHEE" : calledAE

                appendConsoleOutput("Changing state of \(workitemUID) to \(rawState) ...\n")
                appendConsoleOutput("  Transaction UID: \(effectiveTxUID)\n")
                appendConsoleOutput("  Requesting AE:   \(requestingAE)\n")

                // Per PS3.18 §11.6, the Transaction UID for the state
                // change goes in the REQUEST BODY only (not the URL).
                // The URL query parameter ?00081195 belongs only to the
                // Update Workitem endpoint (§11.5).
                let stateURL = client.urlBuilder.workitemStateURL(
                    workitemUID: workitemUID,
                    requestingAE: requestingAE)
                appendConsoleOutput("  URL: \(stateURL.absoluteString)\n")

                // Pre-flight: retrieve the workitem to verify current state.
                // NOTE: Per PS3.18 §11.5.2, the server NEVER returns Transaction
                // UID (0008,1195) — it acts as an access lock known only to the
                // owner.  We rely on our local cache instead.
                do {
                    let currentAttrs = try await client.retrieveWorkitem(uid: workitemUID)
                    if let stateElem = currentAttrs[UPSTag.procedureStepState] as? [String: Any],
                       let vals = stateElem["Value"] as? [String],
                       let currentRaw = vals.first {
                        appendConsoleOutput("  Current state:   \(currentRaw)\n")

                        // Validate transition using the DICOM PS3.4 CC.1.1 state machine
                        let validTargets: [String]
                        switch currentRaw {
                        case "SCHEDULED":   validTargets = ["IN PROGRESS"]
                        case "IN PROGRESS": validTargets = ["COMPLETED", "CANCELED"]
                        default:            validTargets = []
                        }
                        if !validTargets.contains(rawState) {
                            appendConsoleOutput("\n❌ Invalid state transition: \(currentRaw) → \(rawState)\n")
                            if currentRaw == "COMPLETED" || currentRaw == "CANCELED" {
                                appendConsoleOutput("  💡 The workitem is in a final state and cannot be changed.\n")
                            } else {
                                appendConsoleOutput("  💡 The workitem must be in \(rawState == "IN PROGRESS" ? "SCHEDULED" : "IN PROGRESS") state.\n")
                            }
                            consoleStatus = .error
                            service.setConsoleStatus(.error)
                            addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 1,
                                         output: "Invalid transition \(currentRaw) → \(rawState)")
                            return
                        }
                    } else {
                        appendConsoleOutput("  ⚠️  Could not read current state from server\n")
                    }
                    appendConsoleOutput("\n")
                } catch {
                    // Pre-flight check is best-effort; proceed with the state
                    // change even if it fails.
                    appendConsoleOutput("  ⚠️  Pre-flight check failed: \(error.localizedDescription)\n\n")
                }

                // ── Update Workitem with Final State attributes before COMPLETED ──
                // Per PS3.4 CC.2.1.3 / Table CC.2.5-3, the SCP validates that
                // Unified Procedure Step Performed Procedure Sequence (0074,1216)
                // is populated before allowing transition to COMPLETED.  We send
                // a minimal Update Workitem (PS3.18 §11.6) to satisfy this.
                if rawState == "COMPLETED" {
                    appendConsoleOutput("📝 Updating workitem with Final State attributes ...\n")
                    appendConsoleOutput("   (required by DICOM PS3.4 CC.2.5-3 before COMPLETED)\n")

                    let updateURL = client.urlBuilder.updateWorkitemURL(
                        workitemUID: workitemUID, transactionUID: effectiveTxUID)

                    // DICOM DT VR format: YYYYMMDDHHMMSS.FFFFFF (PS3.5 §6.2)
                    let nowDT: String = {
                        let f = DateFormatter()
                        f.dateFormat = "yyyyMMddHHmmss.SSS000"
                        f.locale = Locale(identifier: "en_US_POSIX")
                        f.timeZone = TimeZone.current
                        return f.string(from: Date())
                    }()

                    // Per PS3.4 Table CC.2.5-3, Start/End DateTimes and
                    // Performed Workitem Code Sequence must all be INSIDE
                    // the Unified Procedure Step Performed Procedure Sequence
                    // (0074,1216) sequence item.
                    //
                    // dcm4chee-arc reads the Transaction UID from the JSON
                    // request body (NOT from URL query parameters).  The
                    // server parses it for authentication, validates it
                    // matches the stored lock, then REMOVES it before
                    // persisting — so it is never stored as a DICOM
                    // attribute.  The URL ?00081195 query param is also
                    // present for PS3.18 §11.5 conformance but dcm4chee
                    // ignores it.
                    let performedBody: [String: Any] = [
                        UPSTag.transactionUID: [
                            "vr": "UI", "Value": [effectiveTxUID]
                        ] as [String: Any],
                        UPSTag.unifiedProcedureStepPerformedProcedureSequence: [
                            "vr": "SQ",
                            "Value": [
                                [
                                    UPSTag.performedProcedureStepStartDateTime: [
                                        "vr": "DT", "Value": [nowDT]
                                    ] as [String: Any],
                                    UPSTag.performedProcedureStepEndDateTime: [
                                        "vr": "DT", "Value": [nowDT]
                                    ] as [String: Any],
                                    UPSTag.performedWorkitemCodeSequence: [
                                        "vr": "SQ",
                                        "Value": [
                                            [
                                                UPSTag.codeValue: ["vr": "SH", "Value": ["12345"]],
                                                UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["99LOCAL"]],
                                                UPSTag.codeMeaning: ["vr": "LO", "Value": ["Procedure Step Performed"]]
                                            ] as [String: Any]
                                        ] as [[String: Any]]
                                    ] as [String: Any],
                                    UPSTag.performedStationNameCodeSequence: [
                                        "vr": "SQ",
                                        "Value": [
                                            [
                                                UPSTag.codeValue: ["vr": "SH", "Value": ["STATION01"]],
                                                UPSTag.codingSchemeDesignator: ["vr": "SH", "Value": ["99LOCAL"]],
                                                UPSTag.codeMeaning: ["vr": "LO", "Value": ["Default Performing Station"]]
                                            ] as [String: Any]
                                        ] as [[String: Any]]
                                    ] as [String: Any],
                                    UPSTag.outputInformationSequence: [
                                        "vr": "SQ",
                                        "Value": [] as [[String: Any]]
                                    ] as [String: Any]
                                ] as [String: Any]
                            ] as [[String: Any]]
                        ] as [String: Any]
                    ]

                    let updateData = try JSONSerialization.data(
                        withJSONObject: performedBody, options: [.sortedKeys])

                    appendConsoleOutput("  POST \(updateURL.absoluteString)\n")
                    if let prettyJSON = try? JSONSerialization.data(
                        withJSONObject: performedBody,
                        options: [.prettyPrinted, .sortedKeys]),
                       let prettyStr = String(data: prettyJSON, encoding: .utf8) {
                        appendConsoleOutput("  \(prettyStr.replacingOccurrences(of: "\n", with: "\n  "))\n")
                    }

                    let updateRequest = HTTPClient.Request(
                        url: updateURL,
                        method: .post,
                        headers: [
                            "Content-Type": "application/dicom+json",
                            "Accept": "application/dicom+json"
                        ],
                        body: updateData
                    )

                    do {
                        let updateResp = try await client.httpClient.execute(updateRequest)
                        appendConsoleOutput("  ✅ Workitem updated (HTTP \(updateResp.statusCode))\n")
                        if !updateResp.body.isEmpty,
                           let respStr = String(data: updateResp.body, encoding: .utf8),
                           !respStr.isEmpty {
                            appendConsoleOutput("  Response: \(respStr)\n")
                        }

                        // Verification: GET the workitem to confirm the
                        // Performed Procedure Sequence was actually stored.
                        appendConsoleOutput("  🔍 Verifying attributes were stored ...\n")
                        do {
                            let verifyAttrs = try await client.retrieveWorkitem(uid: workitemUID)
                            if let perfSeq = verifyAttrs[UPSTag.unifiedProcedureStepPerformedProcedureSequence] as? [String: Any],
                               let values = perfSeq["Value"] as? [[String: Any]],
                               !values.isEmpty {
                                appendConsoleOutput("  ✅ Performed Procedure Sequence confirmed on server (\(values.count) item(s))\n")
                            } else {
                                appendConsoleOutput("  ⚠️  Performed Procedure Sequence NOT found on server after update!\n")
                                appendConsoleOutput("     This may indicate the server accepted but did not persist the attributes.\n")
                            }
                            // Also check current state
                            if let stateElem = verifyAttrs[UPSTag.procedureStepState] as? [String: Any],
                               let stateVals = stateElem["Value"] as? [String],
                               let currentState = stateVals.first {
                                appendConsoleOutput("  📋 Current state after update: \(currentState)\n")
                            }
                            // Check if Transaction UID leaked into stored attributes
                            if let txElem = verifyAttrs[UPSTag.transactionUID] as? [String: Any] {
                                appendConsoleOutput("  ⚠️  Transaction UID found in stored attributes: \(txElem)\n")
                                appendConsoleOutput("     (This is unexpected — server should NOT store TX UID as a DICOM attribute)\n")
                            }
                        } catch {
                            appendConsoleOutput("  ⚠️  Verification GET failed: \(error.localizedDescription)\n")
                        }
                        appendConsoleOutput("\n")
                    } catch {
                        appendConsoleOutput("  ❌ Update workitem FAILED: \(error.localizedDescription)\n")
                        if let webErr = error as? DICOMwebError,
                           case .conflict(let msg) = webErr, let msg = msg {
                            appendConsoleOutput("  Server says: \(msg)\n")
                        }
                        appendConsoleOutput("  💡 Cannot proceed to COMPLETED without Final State attributes.\n")
                        appendConsoleOutput("     The Update Workitem POST must succeed first.\n")
                        appendConsoleOutput("     Check that the Transaction UID matches the one used for IN PROGRESS.\n")
                        consoleStatus = .error
                        service.setConsoleStatus(.error)
                        addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 1,
                                     output: "Update workitem failed before COMPLETED: \(error.localizedDescription)")
                        return
                    }
                }

                // Build DICOM JSON body per PS3.18 §11.6
                let stateChangeBody: [String: Any] = [
                    UPSTag.procedureStepState: ["vr": "CS", "Value": [rawState]],
                    UPSTag.transactionUID: ["vr": "UI", "Value": [effectiveTxUID]]
                ]
                let bodyData = try JSONSerialization.data(withJSONObject: stateChangeBody, options: [.sortedKeys])

                // ── curl equivalent for manual reproduction ──
                if let bodyStr = String(data: bodyData, encoding: .utf8) {
                    appendConsoleOutput("─── curl equivalent ───\n")
                    appendConsoleOutput("curl -X PUT \\\n")
                    appendConsoleOutput("  '\(stateURL.absoluteString)' \\\n")
                    appendConsoleOutput("  -H 'Content-Type: application/dicom+json' \\\n")
                    appendConsoleOutput("  -H 'Accept: application/dicom+json' \\\n")
                    if let pretty = try? JSONSerialization.data(
                        withJSONObject: stateChangeBody,
                        options: [.prettyPrinted, .sortedKeys]),
                       let prettyStr = String(data: pretty, encoding: .utf8) {
                        appendConsoleOutput("  -d '\(prettyStr)'\n")
                    } else {
                        appendConsoleOutput("  -d '\(bodyStr)'\n")
                    }
                    appendConsoleOutput("───────────────────────\n\n")
                }

                // ── Show the final HTTP request in the console ──
                appendConsoleOutput("──── HTTP Request ────\n")
                appendConsoleOutput("PUT \(stateURL.absoluteString)\n")
                appendConsoleOutput("Content-Type: application/dicom+json\n")
                appendConsoleOutput("Accept: application/dicom+json\n")
                if let bodyStr = String(data: bodyData, encoding: .utf8) {
                    // Pretty-print the JSON for readability
                    if let jsonObj = try? JSONSerialization.jsonObject(with: bodyData),
                       let pretty = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .sortedKeys]),
                       let prettyStr = String(data: pretty, encoding: .utf8) {
                        appendConsoleOutput("\n\(prettyStr)\n")
                    } else {
                        appendConsoleOutput("\n\(bodyStr)\n")
                    }
                }
                appendConsoleOutput("──────────────────────\n\n")

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

                    // ── Show the HTTP response ──
                    appendConsoleOutput("──── HTTP Response ────\n")
                    appendConsoleOutput("Status: \(response.statusCode)\n")
                    if !response.body.isEmpty,
                       let respStr = String(data: response.body, encoding: .utf8),
                       !respStr.isEmpty {
                        if let jsonObj = try? JSONSerialization.jsonObject(with: response.body),
                           let pretty = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted, .sortedKeys]),
                           let prettyStr = String(data: pretty, encoding: .utf8) {
                            appendConsoleOutput("\n\(prettyStr)\n")
                        } else {
                            appendConsoleOutput("\n\(respStr)\n")
                        }
                    }
                    appendConsoleOutput("───────────────────────\n\n")

                    appendConsoleOutput("✅ State changed to \(rawState)\n")

                    // Cache / clear the Transaction UID for this workitem
                    if rawState == "IN PROGRESS" {
                        // Store the TX UID so COMPLETED/CANCELED can auto-fill it
                        upsTransactionUIDs[workitemUID] = effectiveTxUID
                    } else if rawState == "COMPLETED" || rawState == "CANCELED" {
                        // Terminal state — remove the cached TX UID
                        upsTransactionUIDs.removeValue(forKey: workitemUID)
                    }

                    // Parse response body for the server's Transaction UID
                    if !response.body.isEmpty,
                       let json = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
                       let txElem = json[UPSTag.transactionUID] as? [String: Any],
                       let txVals = txElem["Value"] as? [String],
                       let responseTxUID = txVals.first {
                        if rawState == "IN PROGRESS" {
                            // Server returned a TX UID — update the cache with it
                            upsTransactionUIDs[workitemUID] = responseTxUID
                            appendConsoleOutput("\n  📋 Transaction UID (cached): \(responseTxUID)\n")
                        } else {
                            appendConsoleOutput("  📋 Transaction UID: \(responseTxUID)\n")
                        }
                    } else if rawState == "IN PROGRESS" {
                        // No Transaction UID in response body — show the one we sent
                        appendConsoleOutput("\n  📋 Transaction UID (cached): \(effectiveTxUID)\n")
                        appendConsoleOutput("  ℹ️  This UID is stored locally — COMPLETED/CANCELED will auto-fill it.\n")
                    }
                } catch let error as DICOMwebError {
                    // ── Show the error response ──
                    appendConsoleOutput("──── HTTP Response ────\n")
                    appendConsoleOutput("Error: \(error.localizedDescription)\n")
                    appendConsoleOutput("───────────────────────\n\n")

                    switch error {
                    case .conflict(let message):
                        appendConsoleOutput("❌ State change failed (HTTP 409)\n")
                        if let msg = message, !msg.isEmpty {
                            appendConsoleOutput("  Server message: \(msg)\n")
                        }
                        appendConsoleOutput("  💡 State transition conflict — check:\n")
                        appendConsoleOutput("     • Current state allows transition to \(rawState)?\n")
                        appendConsoleOutput("     • Transaction UID matches the one from IN PROGRESS?\n")
                        appendConsoleOutput("     • Workitem is not locked by another performer?\n")
                        if rawState == "COMPLETED" {
                            appendConsoleOutput("     • Final State attributes (Performed Procedure Sequence) are populated?\n")
                        }
                    case .notFound:
                        appendConsoleOutput("❌ State change failed (HTTP 404)\n")
                        appendConsoleOutput("  💡 Workitem \(workitemUID) not found on the server.\n")
                    case .badRequest(let message):
                        appendConsoleOutput("❌ State change failed (HTTP 400)\n")
                        if let msg = message, !msg.isEmpty {
                            appendConsoleOutput("  Server message: \(msg)\n")
                        }
                    default:
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

                // Fetch and display workitem details for context
                appendConsoleOutput("\nFetching workitem details...\n")
                do {
                    let result = try await client.retrieveWorkitemResult(uid: workitemUID)
                    appendConsoleOutput("  Workitem UID:   \(result.workitemUID)\n")
                    if let label = result.procedureStepLabel {
                        appendConsoleOutput("  Procedure:      \(label)\n")
                    }
                    if let state = result.state {
                        appendConsoleOutput("  State:          \(state.rawValue)\n")
                    }
                    if let priority = result.priority {
                        appendConsoleOutput("  Priority:       \(priority.rawValue)\n")
                    }
                    if let name = result.patientName {
                        appendConsoleOutput("  Patient Name:   \(name)\n")
                    }
                    if let pid = result.patientID {
                        appendConsoleOutput("  Patient ID:     \(pid)\n")
                    }
                    if let accession = result.accessionNumber {
                        appendConsoleOutput("  Accession:      \(accession)\n")
                    }
                    if let scheduled = result.scheduledStartDateTime {
                        appendConsoleOutput("  Scheduled:      \(scheduled)\n")
                    }
                    if let pct = result.progressPercentage {
                        appendConsoleOutput("  Progress:       \(pct)%\n")
                    }
                    if let desc = result.progressDescription {
                        appendConsoleOutput("  Progress Desc:  \(desc)\n")
                    }
                    appendConsoleOutput("\n")
                } catch {
                    appendConsoleOutput("  (Could not fetch workitem details: \(error.localizedDescription))\n\n")
                }

                appendConsoleOutput("📡 Events for this workitem will appear in the DICOMweb Event Monitor.\n")
                appendConsoleOutput("   Navigate to DICOMweb → UPS → Event Monitor to view live events.\n")

                consoleStatus = .success
                service.setConsoleStatus(.success)
                addToHistory(toolName: "dicom-ups", command: commandPreview, exitCode: 0,
                             output: "Subscribed to \(workitemUID)")

            default: // search
                // Build a UPSQuery from the user-provided filter parameters
                var query = UPSQuery()

                let stepStateFilter = paramValue("filter-state")
                if !stepStateFilter.isEmpty {
                    // Use raw attribute tag to avoid DICOMWeb.UPSState / DICOMStudio.UPSState ambiguity
                    query = query.attribute("00741000", value: stepStateFilter)
                }
                let priorityFilter = paramValue("priority")
                if !priorityFilter.isEmpty {
                    query = query.attribute("00741200", value: priorityFilter)
                }
                let patientNameFilter = paramValue("patient-name")
                if !patientNameFilter.isEmpty {
                    query = query.attribute("00100010", value: patientNameFilter)
                }
                let stationFilter = paramValue("scheduled-station")
                if !stationFilter.isEmpty {
                    query = query.attribute("00404025", value: stationFilter)
                }
                let limitStr = paramValue("limit")
                if let limitVal = Int(limitStr), limitVal > 0 {
                    query = query.limit(limitVal)
                } else {
                    query = query.limit(50)
                }
                query = query.includeAllFields()

                // Log the outgoing query
                let searchURL = client.urlBuilder.searchWorkitemsURL(parameters: query.toParameters())
                appendConsoleOutput("Query URL: \(searchURL.absoluteString)\n")
                if !query.toParameters().isEmpty {
                    appendConsoleOutput("Filters:\n")
                    for (key, value) in query.toParameters().sorted(by: { $0.key < $1.key }) {
                        appendConsoleOutput("  \(key) = \(value)\n")
                    }
                }
                appendConsoleOutput("\n")

                let results = try await client.searchWorkitems(query: query)
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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
        let levelStr = paramValue("level")
        let outputFormat = paramValue("output-format").lowercased()

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-query", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 30

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
                case "table":
                    appendConsoleOutput(formatQueryResultsTable(collected, level: level))
                default:
                    appendConsoleOutput(formatQueryResultsTable(collected, level: level))
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
        if !patientName.isEmpty { studyQueryKeys = studyQueryKeys.patientName(patientName) }
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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
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

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 60
        let recursive = paramValue("recursive") == "true"

        // ── Collect DICOM file paths ────────────────────────────────
        // Merge drag-and-drop entries with the text-field path, resolve
        // directories into individual DICOM files, and obtain
        // security-scoped access for sandboxed reads.

        let filesParamPath = paramValue("files").trimmingCharacters(in: .whitespaces)
        var resolvedFiles: [CLIFileEntry] = []

        // Start security-scoped access for the entire collection phase
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
                if recursive {
                    if let enumerator = fm.enumerator(atPath: basePath) {
                        while let relativePath = enumerator.nextObject() as? String {
                            let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
                            if isDICOMCandidate(fullPath),
                               !resolvedFiles.contains(where: { $0.path == fullPath }) {
                                let size = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? Int64) ?? 0
                                resolvedFiles.append(CLIFileEntry(
                                    path: fullPath,
                                    filename: (fullPath as NSString).lastPathComponent,
                                    fileSize: size
                                ))
                            }
                        }
                    }
                } else {
                    if let contents = try? fm.contentsOfDirectory(atPath: basePath) {
                        for name in contents where !name.hasPrefix(".") {
                            let fullPath = (basePath as NSString).appendingPathComponent(name)
                            if isDICOMCandidate(fullPath),
                               !resolvedFiles.contains(where: { $0.path == fullPath }) {
                                let size = (try? fm.attributesOfItem(atPath: fullPath)[.size] as? Int64) ?? 0
                                resolvedFiles.append(CLIFileEntry(
                                    path: fullPath,
                                    filename: name,
                                    fileSize: size
                                ))
                            }
                        }
                    }
                }
            } else {
                // Single file
                if !resolvedFiles.contains(where: { $0.path == basePath }) {
                    let size = (try? fm.attributesOfItem(atPath: basePath)[.size] as? Int64) ?? 0
                    resolvedFiles.append(CLIFileEntry(
                        path: basePath,
                        filename: (basePath as NSString).lastPathComponent,
                        fileSize: size
                    ))
                }
            }
        }

        // Collect from drag-and-drop inputFiles
        for entry in inputFiles {
            collectDICOMFiles(from: entry.path)
        }

        // Collect from text-field path
        if !filesParamPath.isEmpty {
            collectDICOMFiles(from: filesParamPath)
        }

        let fileEntries = resolvedFiles

        guard !fileEntries.isEmpty else {
            appendConsoleOutput("Error: No DICOM files found. Verify the path exists and contains DICOM files.\n")
            if filesParamPath.isEmpty {
                appendConsoleOutput("  💡 Hint: Enter a file or directory path, or drag and drop DICOM files.\n")
            } else {
                appendConsoleOutput("  💡 Hint: The path '\(filesParamPath)' may be a directory. Enable 'Recursive Scan' to search subdirectories.\n")
            }
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-send", command: commandPreview, exitCode: 1, output: "No DICOM files found")
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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
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

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-retrieve", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 60

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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
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

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-qr", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 60

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

            if !patientName.isEmpty { queryKeys = queryKeys.patientName(patientName) }
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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mwl", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 60

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
        let hostValue = paramValue("host")
        let portValue = paramValue("port")
        let callingAET = paramValue("aet").isEmpty ? "DICOMSTUDIO" : paramValue("aet")
        let calledAET = paramValue("called-aet").isEmpty ? "ANY-SCP" : paramValue("called-aet")
        let timeoutStr = paramValue("timeout")
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

        guard let server = resolveHostPort(hostValue, explicitPort: portValue) else {
            appendConsoleOutput("Error: A valid host is required (e.g. hostname or hostname:11112).\n")
            consoleStatus = .error
            service.setConsoleStatus(.error)
            addToHistory(toolName: "dicom-mpps", command: commandPreview, exitCode: 1, output: "Invalid host")
            return
        }

        let host = server.host
        let port = server.port
        let timeout = TimeInterval(timeoutStr) ?? 60

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

    /// Formats a single generic query result for console display.
    // MARK: - Query Result Formatters

    /// Renders all results as a table matching the CLI's `dicom-query --format table` output.
    private func formatQueryResultsTable(_ pairs: [(result: GenericQueryResult, parent: GenericQueryResult?)], level: QueryLevel) -> String {
        guard !pairs.isEmpty else { return "No results found.\n" }

        switch level {
        case .patient:
            var output = ""
            output += String(repeating: "─", count: 100) + "\n"
            output += padRight("Patient Name", 30) + " "
            output += padRight("Patient ID", 15) + " "
            output += padRight("Birth Date", 12) + " "
            output += padRight("Sex", 5) + " "
            output += padRight("Studies", 8) + "\n"
            output += String(repeating: "─", count: 100) + "\n"
            for pair in pairs {
                let p = pair.result.toPatientResult()
                output += padRight(p.patientName ?? "", 30) + " "
                output += padRight(p.patientID ?? "", 15) + " "
                output += padRight(formatDICOMDate(p.patientBirthDate), 12) + " "
                output += padRight(p.patientSex ?? "", 5) + " "
                output += padRight(p.numberOfPatientRelatedStudies.map(String.init) ?? "", 8) + "\n"
            }
            output += String(repeating: "─", count: 100) + "\n"
            output += "Total: \(pairs.count) patient(s)\n"
            return output

        case .study:
            var output = ""
            output += String(repeating: "─", count: 120) + "\n"
            output += padRight("Patient Name", 25) + " "
            output += padRight("Patient ID", 12) + " "
            output += padRight("Date", 12) + " "
            output += padRight("Description", 30) + " "
            output += padRight("Modalities", 12) + " "
            output += padRight("Series", 8) + "\n"
            output += String(repeating: "─", count: 120) + "\n"
            for pair in pairs {
                let s = pair.result.toStudyResult()
                output += padRight(s.patientName ?? "", 25) + " "
                output += padRight(s.patientID ?? "", 12) + " "
                output += padRight(formatDICOMDate(s.studyDate), 12) + " "
                output += padRight(s.studyDescription ?? "", 30) + " "
                output += padRight(s.modalitiesInStudy ?? "", 12) + " "
                output += padRight(s.numberOfStudyRelatedSeries.map(String.init) ?? "", 8) + "\n"
            }
            output += String(repeating: "─", count: 120) + "\n"
            output += "Total: \(pairs.count) study(ies)\n"
            return output

        case .series:
            var output = ""
            output += String(repeating: "─", count: 100) + "\n"
            output += padRight("Series Number", 15) + " "
            output += padRight("Modality", 10) + " "
            output += padRight("Description", 40) + " "
            output += padRight("Date", 12) + " "
            output += padRight("Instances", 10) + "\n"
            output += String(repeating: "─", count: 100) + "\n"
            for pair in pairs {
                let s = pair.result.toSeriesResult()
                output += padRight(s.seriesNumber.map(String.init) ?? "", 15) + " "
                output += padRight(s.modality ?? "", 10) + " "
                output += padRight(s.seriesDescription ?? "", 40) + " "
                output += padRight(formatDICOMDate(s.seriesDate), 12) + " "
                output += padRight(s.numberOfSeriesRelatedInstances.map(String.init) ?? "", 10) + "\n"
            }
            output += String(repeating: "─", count: 100) + "\n"
            output += "Total: \(pairs.count) series\n"
            return output

        case .image:
            var output = ""
            output += String(repeating: "─", count: 100) + "\n"
            output += padRight("Instance Number", 17) + " "
            output += padRight("SOP Class", 30) + " "
            output += padRight("Dimensions", 15) + " "
            output += padRight("Frames", 8) + "\n"
            output += String(repeating: "─", count: 100) + "\n"
            for pair in pairs {
                let i = pair.result.toInstanceResult()
                output += padRight(i.instanceNumber.map(String.init) ?? "", 17) + " "
                let sopClass = i.sopClassUID ?? ""
                let sopComponents = sopClass.split(separator: ".")
                let shortSOP = sopComponents.count > 5
                    ? "..." + sopComponents.suffix(3).joined(separator: ".")
                    : sopClass
                output += padRight(shortSOP, 30) + " "
                let dims: String
                if let rows = i.rows, let cols = i.columns {
                    dims = "\(cols)×\(rows)"
                } else {
                    dims = ""
                }
                output += padRight(dims, 15) + " "
                output += padRight(i.numberOfFrames.map(String.init) ?? "1", 8) + "\n"
            }
            output += String(repeating: "─", count: 100) + "\n"
            output += "Total: \(pairs.count) instance(s)\n"
            return output
        }
    }

    /// Pads a string to a fixed width, truncating if longer.
    private func padRight(_ string: String, _ width: Int) -> String {
        let truncated = String(string.prefix(width))
        return truncated.padding(toLength: width, withPad: " ", startingAt: 0)
    }

    /// Converts a DICOM date string (YYYYMMDD) to YYYY-MM-DD for display.
    private func formatDICOMDate(_ dateString: String?) -> String {
        guard let dateString = dateString, dateString.count == 8 else {
            return dateString ?? ""
        }
        let year = dateString.prefix(4)
        let month = dateString.dropFirst(4).prefix(2)
        let day = dateString.dropFirst(6)
        return "\(year)-\(month)-\(day)"
    }

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

// MARK: - Convert Error

/// Errors specific to the dicom-convert execution in the CLI Workshop.
enum ConvertError: LocalizedError {
    case missingTransferSyntax
    case unknownTransferSyntax(String)
    case invalidFrame(Int, Int)
    case renderFailed
    case exportFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .missingTransferSyntax:
            return "Transfer syntax is required for DICOM output format"
        case .unknownTransferSyntax(let name):
            return "Unknown transfer syntax: \(name). Use: ExplicitVRLittleEndian, ImplicitVRLittleEndian, ExplicitVRBigEndian, or DEFLATE"
        case .invalidFrame(let requested, let total):
            return "Invalid frame \(requested). File has \(total) frame(s) (0-\(total - 1))"
        case .renderFailed:
            return "Failed to render pixel data to image"
        case .exportFailed:
            return "Failed to export image to file"
        case .unsupportedPlatform:
            return "Image export is not supported on this platform"
        }
    }
}
