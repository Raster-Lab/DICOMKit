// DICOMwebViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for the DICOMweb Integration Hub (Milestone 10)
// Reference: DICOM PS3.18 (Web Services), PS3.19 (Application Hosting)

import Foundation
import Observation

/// ViewModel for the DICOMweb Integration Hub, managing state for all six sections:
/// server configuration, QIDO-RS queries, WADO-RS retrieval, STOW-RS uploads,
/// UPS-RS workitem management, and performance monitoring.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class DICOMwebViewModel {

    // MARK: - Dependencies

    private let service: DICOMwebService

    // MARK: - Navigation

    /// Currently active DICOMweb tab.
    public var activeTab: DICOMwebTab = .serverConfig
    /// Whether an operation is in progress.
    public var isLoading: Bool = false
    /// Error message to display, if any.
    public var errorMessage: String? = nil

    // MARK: - 10.1 Server Configuration

    /// All configured DICOMweb server profiles.
    public var serverProfiles: [DICOMwebServerProfile] = []
    /// Currently selected server profile ID (for editing/testing).
    public var selectedServerProfileID: UUID? = nil
    /// Whether the add-server sheet is showing.
    public var isAddServerSheetPresented: Bool = false
    /// Whether the edit-server sheet is showing.
    public var isEditServerSheetPresented: Bool = false
    /// Conformance statement text for the currently selected server (fetched on demand).
    public var serverCapabilitiesText: String = ""

    // MARK: - 10.2 QIDO-RS

    /// The query level (study / series / instance).
    public var qidoQueryLevel: QIDOQueryLevel = .study
    /// Current query parameters.
    public var qidoQueryParams: QIDOQueryParams = QIDOQueryParams()
    /// Results from the most recent QIDO-RS query.
    public var qidoResults: [QIDOResultItem] = []
    /// Whether a QIDO query is currently running.
    public var isQIDORunning: Bool = false
    /// Currently selected query result ID for drill-down.
    public var qidoSelectedResultID: UUID? = nil
    /// Named query templates (name → params).
    public var savedQueryTemplates: [String: QIDOQueryParams] = [:]
    /// Total number of results available on the server (for pagination display).
    public var qidoTotalResultCount: Int? = nil

    // MARK: - 10.3 WADO-RS

    /// All WADO-RS retrieve jobs.
    public var wadoJobs: [WADORetrieveJob] = []
    /// Study UID for the next job to enqueue.
    public var wadoNewJobStudyUID: String = ""
    /// Series UID for the next job to enqueue (empty = study-level).
    public var wadoNewJobSeriesUID: String = ""
    /// SOP Instance UID for the next job to enqueue (empty = series/study-level).
    public var wadoNewJobInstanceUID: String = ""
    /// Retrieve mode for the next job.
    public var wadoNewJobMode: WADORetrieveMode = .study
    /// Whether the new-WADO-job sheet is showing.
    public var isWADOJobSheetPresented: Bool = false
    /// Currently selected WADO job ID.
    public var wadoSelectedJobID: UUID? = nil

    // MARK: - 10.4 STOW-RS

    /// All STOW-RS upload jobs.
    public var stowJobs: [STOWUploadJob] = []
    /// File paths staged for the next upload job.
    public var stowNewFilePaths: [String] = []
    /// How to handle duplicate instances.
    public var stowDuplicateHandling: STOWDuplicateHandling = .reject
    /// Whether DICOM validation runs before upload.
    public var stowValidationEnabled: Bool = true
    /// Number of concurrent upload streams for new jobs.
    public var stowPipelineConcurrency: Int = 5
    /// Whether the new-STOW-upload sheet is showing.
    public var isSTOWUploadSheetPresented: Bool = false
    /// Currently selected STOW job ID.
    public var stowSelectedJobID: UUID? = nil

    // MARK: - 10.5 UPS-RS

    /// All UPS-RS workitems.
    public var upsWorkitems: [UPSWorkitem] = []
    /// All active UPS-RS event subscriptions.
    public var upsSubscriptions: [UPSEventSubscription] = []
    /// Whether a UPS workitem query is running.
    public var isUPSQueryRunning: Bool = false
    /// Currently selected UPS workitem ID.
    public var upsSelectedWorkitemID: UUID? = nil
    /// Event types to subscribe to when creating a new subscription.
    public var upsSubscribeEventTypes: Set<UPSEventType> = Set(UPSEventType.allCases)
    /// Workitem UID for the next subscription (empty = global subscription).
    public var upsNewSubscriptionWorkitemUID: String = ""
    /// Whether the new-subscription sheet is showing.
    public var isUPSSubscriptionSheetPresented: Bool = false

    // MARK: - 10.6 Performance Dashboard

    /// Latest performance statistics snapshot.
    public var performanceStats: DICOMwebPerformanceStats = DICOMwebPerformanceStats()
    /// Historical performance snapshots (up to 100 entries).
    public var performanceHistory: [DICOMwebPerformanceStats] = []

    // MARK: - Init

    public init(service: DICOMwebService = DICOMwebService()) {
        self.service = service
        loadFromService()
    }

    // MARK: - Load All State

    private func loadFromService() {
        serverProfiles        = service.getServerProfiles()
        qidoQueryParams       = service.getQIDOQueryParams()
        qidoResults           = service.getQIDOResults()
        qidoSelectedResultID  = service.getQIDOSelectedResultID()
        savedQueryTemplates   = service.getSavedQueryTemplates()
        wadoJobs              = service.getWADOJobs()
        stowJobs              = service.getSTOWJobs()
        upsWorkitems          = service.getUPSWorkitems()
        upsSubscriptions      = service.getUPSSubscriptions()
        performanceStats      = service.getPerformanceStats()
        performanceHistory    = service.getPerformanceHistory()
    }

    // MARK: - 10.1 Server Config Operations

    /// Adds a new DICOMweb server profile.
    public func addServerProfile(_ profile: DICOMwebServerProfile) {
        service.addServerProfile(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Updates an existing DICOMweb server profile.
    public func updateServerProfile(_ profile: DICOMwebServerProfile) {
        service.updateServerProfile(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Removes a DICOMweb server profile by ID.
    public func removeServerProfile(id: UUID) {
        service.removeServerProfile(id: id)
        if selectedServerProfileID == id { selectedServerProfileID = nil }
        serverProfiles = service.getServerProfiles()
    }

    /// Makes the profile with the given ID the default.
    public func setDefaultProfile(id: UUID) {
        service.setDefaultProfile(id: id)
        serverProfiles = service.getServerProfiles()
    }

    /// Returns the currently selected server profile, if any.
    public var selectedServerProfile: DICOMwebServerProfile? {
        guard let id = selectedServerProfileID else { return nil }
        return serverProfiles.first { $0.id == id }
    }

    /// Returns the default server profile, if any.
    public var defaultServerProfile: DICOMwebServerProfile? {
        service.defaultProfile()
    }

    /// Simulates a connectivity test for the profile with the given ID.
    ///
    /// Sets the status to `.testing`, then resolves to `.online` for configured
    /// profiles or `.offline` for unconfigured ones. In production this would
    /// issue a real HTTPS OPTIONS or capabilities request.
    public func testConnection(profileID: UUID) {
        service.updateConnectionStatus(.testing, error: nil, for: profileID)
        serverProfiles = service.getServerProfiles()

        if let profile = service.profile(for: profileID), profile.isConfigured {
            service.updateConnectionStatus(.online, error: nil, for: profileID)
        } else {
            service.updateConnectionStatus(.offline, error: "No URL configured", for: profileID)
        }
        serverProfiles = service.getServerProfiles()
    }

    /// Returns validation errors for a server profile.
    public func validationErrors(for profile: DICOMwebServerProfile) -> [String] {
        var errors: [String] = []
        if profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Server name must not be empty.")
        }
        if let urlError = DICOMwebURLHelpers.validationError(for: profile.baseURL) {
            errors.append(urlError)
        }
        if let authError = DICOMwebAuthHelpers.validationError(
            for: profile.authMethod,
            token: profile.bearerToken,
            username: profile.username,
            password: profile.password
        ) {
            errors.append(authError)
        }
        return errors
    }

    // MARK: - 10.2 QIDO-RS Operations

    /// Executes a QIDO-RS query using the current parameters.
    ///
    /// Clears previous results. In production this calls the DICOMweb client's
    /// searchStudies / searchSeries / searchInstances methods.
    public func runQIDOQuery() {
        isQIDORunning = true
        errorMessage = nil
        service.setQIDOQueryParams(qidoQueryParams)
        service.clearQIDOResults()
        qidoResults = []
        qidoTotalResultCount = 0
        isQIDORunning = false
    }

    /// Clears all QIDO-RS results and resets selection.
    public func clearQIDOResults() {
        service.clearQIDOResults()
        qidoResults = []
        qidoSelectedResultID = nil
        qidoTotalResultCount = nil
        service.setQIDOSelectedResultID(nil)
    }

    /// Saves the current query parameters under the given template name.
    public func saveQueryTemplate(name: String) {
        guard !name.isEmpty else { return }
        service.saveQueryTemplate(name: name, params: qidoQueryParams)
        savedQueryTemplates = service.getSavedQueryTemplates()
    }

    /// Loads a saved query template by name into the active parameters.
    public func loadQueryTemplate(name: String) {
        guard let params = savedQueryTemplates[name] else { return }
        qidoQueryParams = params
    }

    /// Removes a saved query template by name.
    public func removeQueryTemplate(name: String) {
        service.removeQueryTemplate(name: name)
        savedQueryTemplates = service.getSavedQueryTemplates()
    }

    /// Selects a QIDO result item by ID and persists the selection.
    public func selectQIDOResult(_ id: UUID?) {
        qidoSelectedResultID = id
        service.setQIDOSelectedResultID(id)
    }

    /// Returns the currently selected QIDO result item, if any.
    public var selectedQIDOResult: QIDOResultItem? {
        guard let id = qidoSelectedResultID else { return nil }
        return qidoResults.first { $0.id == id }
    }

    /// Returns a short human-readable summary of the current query parameters.
    public var qidoQuerySummary: String {
        DICOMwebQIDOHelpers.buildQuerySummary(params: qidoQueryParams)
    }

    // MARK: - 10.3 WADO-RS Operations

    /// Adds a WADO-RS retrieve job.
    public func addWADOJob(_ job: WADORetrieveJob) {
        service.addWADOJob(job)
        wadoJobs = service.getWADOJobs()
    }

    /// Removes a WADO-RS retrieve job by ID.
    public func removeWADOJob(id: UUID) {
        service.removeWADOJob(id: id)
        if wadoSelectedJobID == id { wadoSelectedJobID = nil }
        wadoJobs = service.getWADOJobs()
    }

    /// Removes all WADO-RS jobs that have reached a terminal status.
    public func clearCompletedWADOJobs() {
        service.clearCompletedWADOJobs()
        wadoJobs = service.getWADOJobs()
    }

    /// Creates a new WADO-RS job from the current `wadoNewJob*` fields and enqueues it.
    public func enqueueWADOJob() {
        guard !wadoNewJobStudyUID.isEmpty else {
            errorMessage = "Study UID is required."
            return
        }
        let job = WADORetrieveJob(
            studyInstanceUID: wadoNewJobStudyUID,
            seriesInstanceUID: wadoNewJobSeriesUID.isEmpty ? nil : wadoNewJobSeriesUID,
            sopInstanceUID: wadoNewJobInstanceUID.isEmpty ? nil : wadoNewJobInstanceUID,
            retrieveMode: wadoNewJobMode
        )
        addWADOJob(job)
        wadoNewJobStudyUID = ""
        wadoNewJobSeriesUID = ""
        wadoNewJobInstanceUID = ""
        isWADOJobSheetPresented = false
    }

    /// Returns the currently selected WADO-RS job, if any.
    public var selectedWADOJob: WADORetrieveJob? {
        guard let id = wadoSelectedJobID else { return nil }
        return wadoJobs.first { $0.id == id }
    }

    /// Returns the number of WADO-RS jobs currently in progress.
    public var activeWADOJobCount: Int {
        wadoJobs.filter { $0.status == .inProgress }.count
    }

    // MARK: - 10.4 STOW-RS Operations

    /// Adds a STOW-RS upload job.
    public func addSTOWJob(_ job: STOWUploadJob) {
        service.addSTOWJob(job)
        stowJobs = service.getSTOWJobs()
    }

    /// Removes a STOW-RS upload job by ID.
    public func removeSTOWJob(id: UUID) {
        service.removeSTOWJob(id: id)
        if stowSelectedJobID == id { stowSelectedJobID = nil }
        stowJobs = service.getSTOWJobs()
    }

    /// Removes all STOW-RS jobs that have reached a terminal status.
    public func clearCompletedSTOWJobs() {
        service.clearCompletedSTOWJobs()
        stowJobs = service.getSTOWJobs()
    }

    /// Creates a new STOW-RS job from the current staging fields and enqueues it.
    public func enqueueSTOWUpload() {
        guard !stowNewFilePaths.isEmpty else {
            errorMessage = "No files selected for upload."
            return
        }
        let job = STOWUploadJob(
            filePaths: stowNewFilePaths,
            totalFiles: stowNewFilePaths.count,
            duplicateHandling: stowDuplicateHandling,
            validationEnabled: stowValidationEnabled,
            pipelineConcurrency: stowPipelineConcurrency
        )
        addSTOWJob(job)
        stowNewFilePaths = []
        isSTOWUploadSheetPresented = false
    }

    /// Returns the currently selected STOW-RS job, if any.
    public var selectedSTOWJob: STOWUploadJob? {
        guard let id = stowSelectedJobID else { return nil }
        return stowJobs.first { $0.id == id }
    }

    /// Returns the number of STOW-RS jobs not yet in a terminal state.
    public var activeSTOWJobCount: Int {
        stowJobs.filter { !$0.status.isTerminal }.count
    }

    // MARK: - 10.5 UPS-RS Operations

    /// Loads UPS-RS workitems (simulated; production calls the DICOMweb UPS query endpoint).
    public func loadUPSWorkitems() {
        isUPSQueryRunning = true
        errorMessage = nil
        isUPSQueryRunning = false
    }

    /// Transitions a UPS workitem to a new state, enforcing the DICOM state machine.
    public func transitionUPSState(_ newState: UPSState, workitemID: UUID) {
        guard let workitem = upsWorkitems.first(where: { $0.id == workitemID }) else { return }
        guard DICOMwebUPSHelpers.canTransition(from: workitem.state, to: newState) else {
            errorMessage = "Cannot transition from \(workitem.state.displayName) to \(newState.displayName)."
            return
        }
        service.updateUPSWorkitemState(newState, for: workitemID)
        upsWorkitems = service.getUPSWorkitems()
    }

    /// Creates a new UPS-RS event subscription from the current subscription fields.
    public func addUPSSubscription() {
        let sub = UPSEventSubscription(
            workitemUID: upsNewSubscriptionWorkitemUID.isEmpty ? nil : upsNewSubscriptionWorkitemUID,
            eventTypes: upsSubscribeEventTypes
        )
        service.addUPSSubscription(sub)
        upsSubscriptions = service.getUPSSubscriptions()
        upsNewSubscriptionWorkitemUID = ""
        isUPSSubscriptionSheetPresented = false
    }

    /// Removes a UPS-RS event subscription by ID.
    public func removeUPSSubscription(id: UUID) {
        service.removeUPSSubscription(id: id)
        upsSubscriptions = service.getUPSSubscriptions()
    }

    /// Returns the currently selected UPS workitem, if any.
    public var selectedUPSWorkitem: UPSWorkitem? {
        guard let id = upsSelectedWorkitemID else { return nil }
        return upsWorkitems.first { $0.id == id }
    }

    /// Returns the first active global subscription (workitem UID = nil), if any.
    public var globalSubscription: UPSEventSubscription? {
        upsSubscriptions.first { $0.isGlobal && $0.isActive }
    }

    // MARK: - 10.6 Performance Operations

    /// Refreshes the performance stats and history from the service.
    public func refreshPerformanceStats() {
        performanceStats    = service.getPerformanceStats()
        performanceHistory  = service.getPerformanceHistory()
    }

    /// Records a new performance sample and updates the history.
    public func recordPerformanceSample(_ stats: DICOMwebPerformanceStats) {
        service.updatePerformanceStats(stats)
        performanceStats   = service.getPerformanceStats()
        performanceHistory = service.getPerformanceHistory()
    }

    /// Resets all performance stats and clears the history.
    public func resetPerformanceStats() {
        service.resetPerformanceStats()
        performanceStats   = DICOMwebPerformanceStats()
        performanceHistory = []
    }

    /// Returns an overall health label for the current performance stats.
    public var performanceHealthDescription: String {
        DICOMwebPerformanceHelpers.overallHealthDescription(stats: performanceStats)
    }
}
