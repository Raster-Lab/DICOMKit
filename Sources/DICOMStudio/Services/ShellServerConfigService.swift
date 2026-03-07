// ShellServerConfigService.swift
// DICOMStudio
//
// DICOM Studio — Thread-safe service for Server Configuration state (Milestone 19)

import Foundation

/// Thread-safe service that manages state for the Server Configuration feature.
public final class ShellServerConfigService: @unchecked Sendable {
    private let lock = NSLock()

    // 19.1 Server Profiles
    private var _serverProfiles: [ShellServerProfile] = []
    private var _activeServerID: UUID? = nil
    private var _connectionStatus: ShellServerConnectionStatus = .untested

    // 19.2 Persistence
    private var _persistenceState: ServerPersistenceState = .idle
    private var _lastSaveTime: Date? = nil

    // 19.3 UI State
    private var _editorMode: ServerEditorMode = .add
    private var _editingProfile: ShellServerProfile? = nil
    private var _validationErrors: [ServerValidationError] = []
    private var _isManagerSheetPresented: Bool = false
    private var _isEditorSheetPresented: Bool = false

    // 19.4 Network Injection
    private var _injectedParameters: [InjectedParameter] = []
    private var _activeInjectionResult: InjectionResult? = nil

    public init() {}

    // MARK: - 19.1 Server Profiles

    public func getServerProfiles() -> [ShellServerProfile] { lock.withLock { _serverProfiles } }
    public func setServerProfiles(_ profiles: [ShellServerProfile]) { lock.withLock { _serverProfiles = profiles } }
    public func getActiveServerID() -> UUID? { lock.withLock { _activeServerID } }
    public func setActiveServerID(_ id: UUID?) { lock.withLock { _activeServerID = id } }
    public func getConnectionStatus() -> ShellServerConnectionStatus { lock.withLock { _connectionStatus } }
    public func setConnectionStatus(_ status: ShellServerConnectionStatus) { lock.withLock { _connectionStatus = status } }

    /// Adds a server profile, enforcing the maximum server limit.
    public func addServer(_ profile: ShellServerProfile) {
        lock.withLock {
            guard _serverProfiles.count < ServerProfileHelpers.maxServers else { return }
            _serverProfiles.append(profile)
        }
    }

    /// Removes a server profile by ID. Clears active server if the removed profile was active.
    public func removeServer(id: UUID) {
        lock.withLock {
            _serverProfiles.removeAll { $0.id == id }
            if _activeServerID == id {
                _activeServerID = nil
            }
        }
    }

    /// Updates an existing server profile by matching ID.
    public func updateServer(_ profile: ShellServerProfile) {
        lock.withLock {
            guard let idx = _serverProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
            _serverProfiles[idx] = profile
        }
    }

    /// Sets the active server by ID, clearing the previous active flag.
    public func setActiveServer(id: UUID?) {
        lock.withLock {
            for i in _serverProfiles.indices {
                _serverProfiles[i].isActive = (_serverProfiles[i].id == id)
            }
            _activeServerID = id
        }
    }

    /// Returns the currently active server profile, or nil.
    public func activeServer() -> ShellServerProfile? {
        lock.withLock {
            guard let id = _activeServerID else { return nil }
            return _serverProfiles.first { $0.id == id }
        }
    }

    /// Duplicates a server profile using ServerProfileHelpers.
    public func duplicateServer(id: UUID) -> ShellServerProfile? {
        lock.withLock {
            guard let original = _serverProfiles.first(where: { $0.id == id }) else { return nil }
            let duplicate = ServerProfileHelpers.duplicateProfile(original)
            guard _serverProfiles.count < ServerProfileHelpers.maxServers else { return nil }
            _serverProfiles.append(duplicate)
            return duplicate
        }
    }

    /// Returns the number of server profiles.
    public func serverCount() -> Int { lock.withLock { _serverProfiles.count } }

    // MARK: - 19.2 Persistence

    public func getPersistenceState() -> ServerPersistenceState { lock.withLock { _persistenceState } }
    public func setPersistenceState(_ state: ServerPersistenceState) { lock.withLock { _persistenceState = state } }
    public func getLastSaveTime() -> Date? { lock.withLock { _lastSaveTime } }
    public func setLastSaveTime(_ date: Date?) { lock.withLock { _lastSaveTime = date } }

    // MARK: - 19.3 UI State

    public func getEditorMode() -> ServerEditorMode { lock.withLock { _editorMode } }
    public func setEditorMode(_ mode: ServerEditorMode) { lock.withLock { _editorMode = mode } }
    public func getEditingProfile() -> ShellServerProfile? { lock.withLock { _editingProfile } }
    public func setEditingProfile(_ profile: ShellServerProfile?) { lock.withLock { _editingProfile = profile } }
    public func getValidationErrors() -> [ServerValidationError] { lock.withLock { _validationErrors } }
    public func setValidationErrors(_ errors: [ServerValidationError]) { lock.withLock { _validationErrors = errors } }
    public func getIsManagerSheetPresented() -> Bool { lock.withLock { _isManagerSheetPresented } }
    public func setIsManagerSheetPresented(_ presented: Bool) { lock.withLock { _isManagerSheetPresented = presented } }
    public func getIsEditorSheetPresented() -> Bool { lock.withLock { _isEditorSheetPresented } }
    public func setIsEditorSheetPresented(_ presented: Bool) { lock.withLock { _isEditorSheetPresented = presented } }

    /// Validates the editing profile using ServerValidationHelpers.
    public func validateEditingProfile() -> [ServerValidationError] {
        lock.withLock {
            guard let profile = _editingProfile else { return [] }
            let errors = ServerValidationHelpers.validateProfile(profile)
            _validationErrors = errors
            return errors
        }
    }

    // MARK: - 19.4 Network Injection

    public func getInjectedParameters() -> [InjectedParameter] { lock.withLock { _injectedParameters } }
    public func setInjectedParameters(_ params: [InjectedParameter]) { lock.withLock { _injectedParameters = params } }
    public func getActiveInjectionResult() -> InjectionResult? { lock.withLock { _activeInjectionResult } }
    public func setActiveInjectionResult(_ result: InjectionResult?) { lock.withLock { _activeInjectionResult = result } }

    /// Injects server parameters for a specific network tool type using NetworkInjectorHelpers.
    public func injectParametersForTool(_ toolType: NetworkToolType) {
        lock.withLock {
            let server: ShellServerProfile?
            if let activeID = _activeServerID {
                server = _serverProfiles.first(where: { $0.id == activeID })
            } else {
                server = nil
            }
            _injectedParameters = server.map {
                NetworkInjectorHelpers.injectParameters(from: $0, for: toolType)
            } ?? []
            _activeInjectionResult = NetworkInjectorHelpers.buildInjectionResult(
                server: server,
                toolType: toolType
            )
        }
    }
}
