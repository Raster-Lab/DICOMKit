// NetworkingViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for the DICOM Networking Hub (Milestone 9)
// Reference: DICOM PS3.4, PS3.7, PS3.8, PS3.15

import Foundation
import Observation
import DICOMNetwork

/// ViewModel for the DICOM Networking Hub, managing state for all nine networking
/// sections: server configuration, C-ECHO, C-FIND, C-MOVE/GET, C-STORE, MWL,
/// MPPS, Print Management, and Network Monitoring.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class NetworkingViewModel {

    // MARK: - Dependencies

    private let service: NetworkingService

    // MARK: - Navigation

    /// Currently active networking tab.
    public var activeTab: NetworkingTab = .serverConfig
    /// Whether an operation is in progress.
    public var isLoading: Bool = false
    /// Error message to display, if any.
    public var errorMessage: String? = nil

    // MARK: - 9.1 Server Configuration

    /// All configured server profiles.
    public var serverProfiles: [PACSServerProfile] = []
    /// Currently selected server profile ID (for editing/testing).
    public var selectedServerProfileID: UUID? = nil
    /// Whether the add-server sheet is showing.
    public var isAddServerSheetPresented: Bool = false
    /// Whether the edit-server sheet is showing.
    public var isEditServerSheetPresented: Bool = false

    // MARK: - 9.2 C-ECHO

    /// Echo history (most recent first).
    public var echoHistory: [EchoResult] = []
    /// Whether a batch echo to all servers is in progress.
    public var isBatchEchoInProgress: Bool = false
    /// Number of servers tested so far in a batch echo.
    public var batchEchoProgress: Int = 0

    // MARK: - 9.3 C-FIND

    /// Current query filter.
    public var queryFilter: QueryFilter = QueryFilter()
    /// Query results.
    public var queryResults: [QueryResultItem] = []
    /// Whether a query is running.
    public var isQueryRunning: Bool = false
    /// Saved query templates (name → filter).
    public var savedQueryFilters: [String: QueryFilter] = [:]
    /// Currently selected query result ID for drill-down.
    public var selectedQueryResultID: UUID? = nil

    // MARK: - 9.4 C-MOVE / C-GET

    /// Transfer queue items.
    public var transferQueue: [TransferItem] = []
    /// Bandwidth limit configuration.
    public var bandwidthLimit: BandwidthLimit = BandwidthLimit()
    /// Currently selected transfer item ID.
    public var selectedTransferItemID: UUID? = nil

    // MARK: - 9.5 C-STORE

    /// Send queue items.
    public var sendQueue: [SendItem] = []
    /// Retry configuration for sends.
    public var sendRetryConfig: SendRetryConfig = .default
    /// Pre-send validation level.
    public var validationLevel: ValidationLevel = .standard
    /// Circuit breaker states keyed by server profile ID.
    public var circuitBreakerStates: [UUID: CircuitBreakerDisplayState] = [:]
    /// Whether the retry config sheet is showing.
    public var isRetryConfigSheetPresented: Bool = false

    // MARK: - 9.6 MWL

    /// Modality Worklist items.
    public var mwlItems: [MWLWorklistItem] = []
    /// MWL filter.
    public var mwlFilter: MWLFilter = MWLFilter()
    /// Whether a MWL query is running.
    public var isMWLQueryRunning: Bool = false
    /// Selected MWL item for auto-populate.
    public var selectedMWLItemID: UUID? = nil

    // MARK: - 9.7 MPPS

    /// All MPPS items.
    public var mppsItems: [MPPSItem] = []
    /// Currently selected MPPS item ID.
    public var selectedMPPSItemID: UUID? = nil
    /// Whether the new-MPPS sheet is presenting.
    public var isCreateMPPSSheetPresented: Bool = false

    // MARK: - 9.8 Print Management

    /// All print jobs.
    public var printJobs: [PrintJob] = []
    /// Currently selected print job ID.
    public var selectedPrintJobID: UUID? = nil
    /// Whether the new-print-job sheet is presenting.
    public var isNewPrintJobSheetPresented: Bool = false

    // MARK: - 9.9 Monitoring

    /// Latest monitoring statistics snapshot.
    public var monitoringStats: NetworkMonitoringStats = NetworkMonitoringStats()
    /// Audit log entries.
    public var auditLog: [AuditLogEntry] = []
    /// Audit log search query.
    public var auditLogSearchQuery: String = ""
    /// Network error items.
    public var networkErrors: [NetworkErrorItem] = []
    /// Whether monitoring is active.
    public var isMonitoringActive: Bool = false

    // MARK: - Init

    public init(service: NetworkingService = NetworkingService()) {
        self.service = service
        loadAllState()
    }

    // MARK: - Load All State

    private func loadAllState() {
        serverProfiles       = service.getServerProfiles()
        echoHistory          = service.getEchoHistory()
        queryFilter          = service.getQueryFilter()
        queryResults         = service.getQueryResults()
        savedQueryFilters    = service.getSavedQueryFilters()
        transferQueue        = service.getTransferQueue()
        bandwidthLimit       = service.getBandwidthLimit()
        sendQueue            = service.getSendQueue()
        sendRetryConfig      = service.getSendRetryConfig()
        validationLevel      = service.getValidationLevel()
        mwlItems             = service.getMWLItems()
        mwlFilter            = service.getMWLFilter()
        mppsItems            = service.getMPPSItems()
        printJobs            = service.getPrintJobs()
        monitoringStats      = service.getMonitoringStats()
        auditLog             = service.getAuditLog()
        networkErrors        = service.getNetworkErrors()
    }

    // MARK: - 9.1 Server Config Operations

    /// Adds a new server profile.
    public func addServerProfile(_ profile: PACSServerProfile) {
        service.addServerProfile(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Updates an existing server profile.
    public func updateServerProfile(_ profile: PACSServerProfile) {
        service.updateServerProfile(profile)
        serverProfiles = service.getServerProfiles()
    }

    /// Removes a server profile.
    public func removeServerProfile(id: UUID) {
        service.removeServerProfile(id: id)
        serverProfiles = service.getServerProfiles()
        if selectedServerProfileID == id { selectedServerProfileID = nil }
    }

    /// Returns the currently selected server profile, if any.
    public var selectedServerProfile: PACSServerProfile? {
        guard let id = selectedServerProfileID else { return nil }
        return serverProfiles.first { $0.id == id }
    }

    /// Returns validation errors for a server profile.
    public func validationErrors(for profile: PACSServerProfile) -> [String] {
        ServerProfileValidation.validate(profile)
    }

    // MARK: - 9.2 C-ECHO Operations

    /// Performs a real C-ECHO verification against the given server profile
    /// using DICOMNetwork's VerificationService.
    public func performEcho(profileID: UUID) async {
        guard let profile = serverProfiles.first(where: { $0.id == profileID }) else { return }
        service.setServerStatus(profileID: profileID, status: .testing)
        serverProfiles = service.getServerProfiles()

        let result: EchoResult
        do {
            let verificationResult = try await DICOMVerificationService.echo(
                host: profile.host,
                port: profile.port,
                callingAE: profile.localAETitle,
                calledAE: profile.remoteAETitle,
                timeout: profile.timeoutSeconds
            )
            result = EchoResult(
                serverProfileID: profileID,
                serverName: profile.name,
                success: verificationResult.success,
                latencyMs: verificationResult.roundTripTime * 1000
            )
        } catch {
            result = EchoResult(
                serverProfileID: profileID,
                serverName: profile.name,
                success: false,
                errorMessage: error.localizedDescription
            )
        }
        service.recordEchoResult(result)
        echoHistory  = service.getEchoHistory()
        serverProfiles = service.getServerProfiles()
        auditLog     = service.getAuditLog()
    }

    /// Performs a batch echo to all configured servers.
    public func performBatchEcho() async {
        isBatchEchoInProgress = true
        batchEchoProgress = 0
        for profile in serverProfiles {
            await performEcho(profileID: profile.id)
            batchEchoProgress += 1
        }
        isBatchEchoInProgress = false
    }

    /// Clears the echo history.
    public func clearEchoHistory() {
        service.clearEchoHistory()
        echoHistory = service.getEchoHistory()
    }

    // MARK: - 9.3 C-FIND Operations

    /// Updates the query filter.
    public func updateQueryFilter(_ filter: QueryFilter) {
        queryFilter = filter
        service.setQueryFilter(filter)
    }

    /// Loads simulated query results into the view model.
    public func loadQueryResults(_ results: [QueryResultItem]) {
        service.setQueryResults(results)
        queryResults = service.getQueryResults()
        auditLog     = service.getAuditLog()
    }

    /// Clears all query results.
    public func clearQueryResults() {
        service.clearQueryResults()
        queryResults = []
    }

    /// Saves the current query filter under the given name.
    public func saveQueryFilter(name: String) {
        service.saveQueryFilter(name: name, filter: queryFilter)
        savedQueryFilters = service.getSavedQueryFilters()
    }

    /// Loads a saved query filter by name.
    public func loadSavedQueryFilter(name: String) {
        guard let filter = savedQueryFilters[name] else { return }
        updateQueryFilter(filter)
    }

    /// Removes a saved query filter template by name.
    public func removeSavedQueryFilter(name: String) {
        service.removeSavedQueryFilter(name: name)
        savedQueryFilters = service.getSavedQueryFilters()
    }

    /// Returns a summary string for the current query filter.
    public var queryFilterSummary: String {
        QueryFilterHelpers.summary(for: queryFilter)
    }

    // MARK: - 9.4 C-MOVE/GET Operations

    /// Enqueues a transfer item in the download queue.
    public func enqueueTransfer(_ item: TransferItem) {
        service.enqueueTransfer(item)
        transferQueue = service.getTransferQueue()
    }

    /// Updates a transfer item's state.
    public func updateTransferItem(_ item: TransferItem) {
        service.updateTransferItem(item)
        transferQueue = service.getTransferQueue()
    }

    /// Removes a transfer item.
    public func removeTransferItem(id: UUID) {
        service.removeTransferItem(id: id)
        transferQueue = service.getTransferQueue()
        if selectedTransferItemID == id { selectedTransferItemID = nil }
    }

    /// Sets the bandwidth limit.
    public func updateBandwidthLimit(_ limit: BandwidthLimit) {
        bandwidthLimit = limit
        service.setBandwidthLimit(limit)
    }

    /// Items sorted by priority (high first), then queued date.
    public var prioritizedTransferQueue: [TransferItem] {
        transferQueue.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.queuedDate < $1.queuedDate
        }
    }

    // MARK: - 9.5 C-STORE Operations

    /// Enqueues a send item.
    public func enqueueSendItem(_ item: SendItem) {
        service.enqueueSendItem(item)
        sendQueue = service.getSendQueue()
    }

    /// Updates a send item's state.
    public func updateSendItem(_ item: SendItem) {
        service.updateSendItem(item)
        sendQueue = service.getSendQueue()
    }

    /// Removes a send item.
    public func removeSendItem(id: UUID) {
        service.removeSendItem(id: id)
        sendQueue = service.getSendQueue()
    }

    /// Updates the retry configuration.
    public func updateSendRetryConfig(_ config: SendRetryConfig) {
        sendRetryConfig = config
        service.setSendRetryConfig(config)
    }

    /// Updates the pre-send validation level.
    public func updateValidationLevel(_ level: ValidationLevel) {
        validationLevel = level
        service.setValidationLevel(level)
    }

    /// Returns the circuit breaker state for a given server profile.
    public func circuitBreakerState(for profileID: UUID) -> CircuitBreakerDisplayState {
        service.getCircuitBreakerState(profileID: profileID)
    }

    /// Updates the circuit breaker state for a given server profile.
    public func updateCircuitBreakerState(_ state: CircuitBreakerDisplayState, profileID: UUID) {
        service.setCircuitBreakerState(state, profileID: profileID)
        circuitBreakerStates[profileID] = state
    }

    // MARK: - 9.6 MWL Operations

    /// Loads MWL worklist items (simulated query result).
    public func loadMWLItems(_ items: [MWLWorklistItem]) {
        service.setMWLItems(items)
        mwlItems = service.getMWLItems()
        auditLog = service.getAuditLog()
    }

    /// Updates the MWL filter.
    public func updateMWLFilter(_ filter: MWLFilter) {
        mwlFilter = filter
        service.setMWLFilter(filter)
    }

    /// Returns filtered MWL items based on the current filter.
    public var filteredMWLItems: [MWLWorklistItem] {
        mwlItems.filter { item in
            let dateMatch = mwlFilter.date.isEmpty
                || item.scheduledProcedureStepStartDate == mwlFilter.date
            let modMatch  = mwlFilter.modality.isEmpty
                || item.modality.uppercased() == mwlFilter.modality.uppercased()
            let aeMatch   = mwlFilter.stationAETitle.isEmpty
                || item.scheduledStationAETitle.uppercased() == mwlFilter.stationAETitle.uppercased()
            return dateMatch && modMatch && aeMatch
        }
    }

    /// Returns the selected MWL item, if any.
    public var selectedMWLItem: MWLWorklistItem? {
        guard let id = selectedMWLItemID else { return nil }
        return mwlItems.first { $0.id == id }
    }

    // MARK: - 9.7 MPPS Operations

    /// Creates a new MPPS procedure step (N-CREATE).
    public func createMPPS(_ item: MPPSItem) {
        service.createMPPS(item)
        mppsItems = service.getMPPSItems()
        auditLog  = service.getAuditLog()
    }

    /// Completes an MPPS item (N-SET to Completed).
    public func completeMPPS(id: UUID) {
        service.updateMPPSStatus(id: id, status: .completed, endDateTime: Date())
        mppsItems = service.getMPPSItems()
        auditLog  = service.getAuditLog()
    }

    /// Discontinues an MPPS item (N-SET to Discontinued).
    public func discontinueMPPS(id: UUID) {
        service.updateMPPSStatus(id: id, status: .discontinued, endDateTime: Date())
        mppsItems = service.getMPPSItems()
        auditLog  = service.getAuditLog()
    }

    /// Returns the currently selected MPPS item, if any.
    public var selectedMPPSItem: MPPSItem? {
        guard let id = selectedMPPSItemID else { return nil }
        return mppsItems.first { $0.id == id }
    }

    // MARK: - 9.8 Print Operations

    /// Adds a new print job.
    public func addPrintJob(_ job: PrintJob) {
        service.addPrintJob(job)
        printJobs = service.getPrintJobs()
        auditLog  = service.getAuditLog()
    }

    /// Updates an existing print job.
    public func updatePrintJob(_ job: PrintJob) {
        service.updatePrintJob(job)
        printJobs = service.getPrintJobs()
    }

    /// Removes a print job.
    public func removePrintJob(id: UUID) {
        service.removePrintJob(id: id)
        printJobs = service.getPrintJobs()
        if selectedPrintJobID == id { selectedPrintJobID = nil }
    }

    /// Returns the currently selected print job, if any.
    public var selectedPrintJob: PrintJob? {
        guard let id = selectedPrintJobID else { return nil }
        return printJobs.first { $0.id == id }
    }

    // MARK: - 9.9 Monitoring Operations

    /// Refreshes monitoring statistics from the service.
    public func refreshMonitoringStats(_ stats: NetworkMonitoringStats) {
        service.updateMonitoringStats(stats)
        monitoringStats = service.getMonitoringStats()
    }

    /// Returns audit log entries filtered by the current search query.
    public var filteredAuditLog: [AuditLogEntry] {
        guard !auditLogSearchQuery.isEmpty else { return auditLog }
        let q = auditLogSearchQuery.lowercased()
        return auditLog.filter {
            $0.eventType.displayName.lowercased().contains(q)
            || $0.remoteEntity.lowercased().contains(q)
            || $0.detail.lowercased().contains(q)
            || $0.outcome.displayName.lowercased().contains(q)
        }
    }

    /// Exports the full audit log as a CSV string.
    public func exportAuditLogCSV() -> String {
        AuditLogHelpers.csvExport(entries: auditLog)
    }

    /// Clears the audit log.
    public func clearAuditLog() {
        service.clearAuditLog()
        auditLog = service.getAuditLog()
    }

    /// Records a network error and refreshes the errors list.
    public func recordNetworkError(_ error: NetworkErrorItem) {
        service.recordNetworkError(error)
        networkErrors = service.getNetworkErrors()
    }

    /// Clears all network errors.
    public func clearNetworkErrors() {
        service.clearNetworkErrors()
        networkErrors = service.getNetworkErrors()
    }

    /// Returns a monitoring summary string.
    public var monitoringSummary: String {
        MonitoringHelpers.summary(monitoringStats)
    }
}
