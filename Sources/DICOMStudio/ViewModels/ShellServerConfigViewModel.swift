// ShellServerConfigViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for Server Configuration Management (Milestone 19)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class ShellServerConfigViewModel {
    private let service: ShellServerConfigService

    // 19.1 Server Profiles
    public var serverProfiles: [ShellServerProfile] = []
    public var activeServerID: UUID? = nil
    public var connectionStatus: ShellServerConnectionStatus = .untested

    // 19.2 Persistence
    public var persistenceState: ServerPersistenceState = .idle
    public var lastSaveTime: Date? = nil

    // 19.3 UI State
    public var editorMode: ServerEditorMode = .add
    public var editingProfile: ShellServerProfile? = nil
    public var validationErrors: [ServerValidationError] = []
    public var isManagerSheetPresented: Bool = false
    public var isEditorSheetPresented: Bool = false

    // 19.4 Network Injection
    public var injectedParameters: [InjectedParameter] = []
    public var activeInjectionResult: InjectionResult? = nil

    public init(service: ShellServerConfigService = ShellServerConfigService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        serverProfiles          = service.getServerProfiles()
        activeServerID          = service.getActiveServerID()
        connectionStatus        = service.getConnectionStatus()
        persistenceState        = service.getPersistenceState()
        lastSaveTime            = service.getLastSaveTime()
        editorMode              = service.getEditorMode()
        editingProfile          = service.getEditingProfile()
        validationErrors        = service.getValidationErrors()
        isManagerSheetPresented = service.getIsManagerSheetPresented()
        isEditorSheetPresented  = service.getIsEditorSheetPresented()
        injectedParameters      = service.getInjectedParameters()
        activeInjectionResult   = service.getActiveInjectionResult()
    }

    // MARK: - 19.1 Server Profiles

    /// Adds a new server profile.
    public func addServer(_ profile: ShellServerProfile) {
        service.addServer(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Removes a server profile by ID.
    public func removeServer(id: UUID) {
        service.removeServer(id: id)
        serverProfiles = service.getServerProfiles()
        if activeServerID == id {
            activeServerID = nil
            service.setActiveServerID(nil)
        }
    }

    /// Updates an existing server profile.
    public func updateServer(_ profile: ShellServerProfile) {
        service.updateServer(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Sets the active server by ID.
    public func setActiveServer(id: UUID?) {
        service.setActiveServer(id: id)
        activeServerID = id
        serverProfiles = service.getServerProfiles()
    }

    /// Returns the currently active server profile, or nil.
    public func activeServer() -> ShellServerProfile? {
        service.activeServer()
    }

    /// Duplicates a server profile by ID.
    public func duplicateServer(id: UUID) {
        _ = service.duplicateServer(id: id)
        serverProfiles = service.getServerProfiles()
    }

    /// Whether there is an active server configured.
    public func hasActiveServer() -> Bool {
        activeServerID != nil && service.activeServer() != nil
    }

    // MARK: - 19.3 UI State

    /// Begins editing a profile (new or existing).
    public func startEditing(profile: ShellServerProfile?, mode: ServerEditorMode) {
        editorMode = mode
        service.setEditorMode(mode)
        if let profile = profile {
            editingProfile = profile
        } else {
            editingProfile = ServerProfileHelpers.defaultProfile()
        }
        service.setEditingProfile(editingProfile)
        validationErrors = []
        service.setValidationErrors([])
        isEditorSheetPresented = true
        service.setIsEditorSheetPresented(true)
    }

    /// Cancels the current editing session.
    public func cancelEditing() {
        editingProfile = nil
        service.setEditingProfile(nil)
        validationErrors = []
        service.setValidationErrors([])
        isEditorSheetPresented = false
        service.setIsEditorSheetPresented(false)
    }

    /// Validates and saves the editing profile.
    public func saveEditingProfile() {
        let errors = service.validateEditingProfile()
        validationErrors = errors
        guard errors.isEmpty, let profile = service.getEditingProfile() else { return }

        switch editorMode {
        case .add, .duplicate:
            service.addServer(profile)
        case .edit:
            service.updateServer(profile)
        }

        serverProfiles = service.getServerProfiles()
        editingProfile = nil
        service.setEditingProfile(nil)
        isEditorSheetPresented = false
        service.setIsEditorSheetPresented(false)
    }

    /// Validates the editing profile and returns whether it is valid.
    public func validateEditingProfile() -> Bool {
        let errors = service.validateEditingProfile()
        validationErrors = errors
        return errors.isEmpty
    }

    /// Tests the connection to the active server.
    public func testConnection() {
        connectionStatus = .testing
        service.setConnectionStatus(.testing)
    }

    /// Returns a connection summary string for the active server.
    public func connectionSummary() -> String {
        guard let server = service.activeServer() else { return "No server configured" }
        return ServerProfileHelpers.connectionSummary(for: server)
    }

    /// Returns display information for a server profile.
    public func serverDisplayInfo(for profile: ShellServerProfile) -> String {
        ServerProfileHelpers.serverDisplayInfo(for: profile)
    }

    /// Shows the server manager sheet.
    public func showServerManager() {
        isManagerSheetPresented = true
        service.setIsManagerSheetPresented(true)
    }

    /// Hides the server manager sheet.
    public func hideServerManager() {
        isManagerSheetPresented = false
        service.setIsManagerSheetPresented(false)
    }

    // MARK: - 19.4 Network Injection

    /// Injects server parameters for a specific network tool type.
    public func injectParametersForTool(_ toolType: NetworkToolType) {
        service.injectParametersForTool(toolType)
        injectedParameters = service.getInjectedParameters()
        activeInjectionResult = service.getActiveInjectionResult()
    }

    /// Checks whether a tool name corresponds to a network tool.
    public func isNetworkTool(_ toolName: String) -> Bool {
        NetworkInjectorHelpers.isNetworkTool(toolName)
    }
}
