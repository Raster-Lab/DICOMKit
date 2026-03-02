// SecurityViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for the Security & Privacy Center (Milestone 11)
// Reference: DICOM PS3.15 (Security and System Management Profiles)
// Reference: HIPAA Security Rule §164.312

import Foundation
import Observation

/// ViewModel for the Security & Privacy Center, managing state for all four sections:
/// TLS configuration, anonymization tool, audit log viewer, and access control.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class SecurityViewModel {

    // MARK: - Dependencies

    private let service: SecurityService

    // MARK: - Navigation

    /// Currently active security tab.
    public var activeTab: SecurityTab = .tlsConfiguration
    /// Whether an operation is in progress.
    public var isLoading: Bool = false
    /// Error message to display, if any.
    public var errorMessage: String? = nil

    // MARK: - 11.1 TLS Configuration

    /// Global TLS mode applied to all new connections.
    public var globalTLSMode: SecurityTLSMode = .compatible
    /// All certificates in the certificate store.
    public var certificates: [SecurityCertificateEntry] = []
    /// Currently selected certificate ID for detail/editing.
    public var selectedCertificateID: UUID? = nil
    /// Whether the add-certificate sheet is showing.
    public var isAddCertificateSheetPresented: Bool = false
    /// All server security entries.
    public var serverSecurityEntries: [SecurityServerEntry] = []
    /// Currently selected server security entry ID.
    public var selectedServerSecurityID: UUID? = nil
    /// Whether the TLS handshake details sheet is showing.
    public var isTLSHandshakeSheetPresented: Bool = false

    // MARK: - 11.2 Anonymization

    /// Currently selected anonymization profile.
    public var selectedProfile: AnonymizationProfile = .basic
    /// Custom rules (active when profile == .custom).
    public var customRules: [AnonymizationTagRule] = []
    /// Files staged for anonymization.
    public var stagedFilePaths: [String] = []
    /// Output directory for anonymized files.
    public var outputDirectory: String = ""
    /// Whether key escrow is enabled for reversibility.
    public var keyEscrowEnabled: Bool = false
    /// All anonymization jobs.
    public var anonymizationJobs: [AnonymizationJob] = []
    /// Currently selected job ID.
    public var selectedJobID: UUID? = nil
    /// Whether the new-job sheet is showing.
    public var isNewJobSheetPresented: Bool = false
    /// PHI detection results.
    public var phiDetectionResults: [PHIDetectionResult] = []
    /// Whether PHI scan is running.
    public var isPHIScanRunning: Bool = false

    // MARK: - 11.3 Audit Log

    /// All audit log entries.
    public var auditEntries: [SecurityAuditEntry] = []
    /// Filter: event type (nil = all types).
    public var auditFilterEventType: SecurityAuditEventType? = nil
    /// Filter: user identity substring.
    public var auditFilterUser: String = ""
    /// Filter: patient/study reference substring.
    public var auditFilterReference: String = ""
    /// Filter: start date for date-range filter (nil = no lower bound).
    public var auditFilterStartDate: Date? = nil
    /// Filter: end date for date-range filter (nil = no upper bound).
    public var auditFilterEndDate: Date? = nil
    /// Selected export format for audit log export.
    public var auditExportFormat: SecurityAuditExportFormat = .csv
    /// Currently enabled log handlers.
    public var enabledHandlers: Set<SecurityAuditHandlerType> = [.console]
    /// Current audit log retention policy.
    public var retentionPolicy: SecurityAuditRetentionPolicy = .days365
    /// Whether the export sheet is showing.
    public var isAuditExportSheetPresented: Bool = false

    // MARK: - 11.4 Access Control

    /// Current user session.
    public var currentSession: AccessControlSession? = nil
    /// Permission matrix entries for display.
    public var permissionMatrix: [PermissionEntry] = []
    /// All break-glass events.
    public var breakGlassEvents: [BreakGlassEvent] = []
    /// Whether the break-glass dialog is showing.
    public var isBreakGlassDialogPresented: Bool = false
    /// Reason text for a pending break-glass request.
    public var breakGlassReason: String = ""

    // MARK: - Init

    public init(service: SecurityService = SecurityService()) {
        self.service = service
        loadAll()
    }

    // MARK: - Private Loader

    private func loadAll() {
        globalTLSMode = service.getGlobalTLSMode()
        certificates = service.getCertificates()
        serverSecurityEntries = service.getServerSecurityEntries()
        selectedProfile = service.getSelectedProfile()
        customRules = service.getCustomRules()
        anonymizationJobs = service.getAnonymizationJobs()
        phiDetectionResults = service.getPHIDetectionResults()
        auditEntries = service.getAuditEntries()
        enabledHandlers = service.getEnabledHandlers()
        retentionPolicy = service.getRetentionPolicy()
        currentSession = service.getCurrentSession()
        breakGlassEvents = service.getBreakGlassEvents()
        permissionMatrix = AccessControlHelpers.standardPermissionMatrix()
    }

    // MARK: - 11.1 TLS Actions

    /// Updates the global TLS mode.
    public func setGlobalTLSMode(_ mode: SecurityTLSMode) {
        globalTLSMode = mode
        service.setGlobalTLSMode(mode)
    }

    /// Adds a certificate to the store.
    public func addCertificate(_ certificate: SecurityCertificateEntry) {
        service.addCertificate(certificate)
        certificates = service.getCertificates()
    }

    /// Updates an existing certificate.
    public func updateCertificate(_ certificate: SecurityCertificateEntry) {
        service.updateCertificate(certificate)
        certificates = service.getCertificates()
    }

    /// Removes a certificate by ID.
    public func removeCertificate(id: UUID) {
        service.removeCertificate(id: id)
        certificates = service.getCertificates()
        if selectedCertificateID == id { selectedCertificateID = nil }
    }

    /// Returns the currently selected certificate, if any.
    public var selectedCertificate: SecurityCertificateEntry? {
        guard let id = selectedCertificateID else { return nil }
        return certificates.first(where: { $0.id == id })
    }

    /// Returns certificates that are expiring or already expired.
    public var expiringCertificates: [SecurityCertificateEntry] {
        service.expiringCertificates()
    }

    /// Adds a server security entry.
    public func addServerSecurityEntry(_ entry: SecurityServerEntry) {
        service.addServerSecurityEntry(entry)
        serverSecurityEntries = service.getServerSecurityEntries()
    }

    /// Updates an existing server security entry.
    public func updateServerSecurityEntry(_ entry: SecurityServerEntry) {
        service.updateServerSecurityEntry(entry)
        serverSecurityEntries = service.getServerSecurityEntries()
    }

    /// Removes a server security entry by ID.
    public func removeServerSecurityEntry(id: UUID) {
        service.removeServerSecurityEntry(id: id)
        serverSecurityEntries = service.getServerSecurityEntries()
        if selectedServerSecurityID == id { selectedServerSecurityID = nil }
    }

    // MARK: - 11.2 Anonymization Actions

    /// Sets the anonymization profile and loads its default rules if not custom.
    public func setProfile(_ profile: AnonymizationProfile) {
        selectedProfile = profile
        service.setSelectedProfile(profile)
        if profile != .custom {
            let rules = AnonymizationHelpers.defaultRules(for: profile)
            customRules = rules
            service.setCustomRules(rules)
        }
    }

    /// Adds a custom rule.
    public func addCustomRule(_ rule: AnonymizationTagRule) {
        service.addCustomRule(rule)
        customRules = service.getCustomRules()
    }

    /// Removes a custom rule by ID.
    public func removeCustomRule(id: UUID) {
        service.removeCustomRule(id: id)
        customRules = service.getCustomRules()
    }

    /// Enqueues a new anonymization job with the current settings.
    public func enqueueAnonymizationJob() {
        let rules = selectedProfile == .custom
            ? customRules
            : AnonymizationHelpers.defaultRules(for: selectedProfile)
        var job = AnonymizationJob(
            filePaths: stagedFilePaths,
            profile: selectedProfile,
            customRules: rules,
            status: .pending,
            totalFiles: stagedFilePaths.count,
            outputDirectory: outputDirectory,
            keyEscrowEnabled: keyEscrowEnabled
        )
        job.totalFiles = stagedFilePaths.count
        service.enqueueAnonymizationJob(job)
        anonymizationJobs = service.getAnonymizationJobs()
        stagedFilePaths = []
        isNewJobSheetPresented = false
    }

    /// Cancels a running or pending job.
    public func cancelAnonymizationJob(id: UUID) {
        service.cancelAnonymizationJob(id: id)
        anonymizationJobs = service.getAnonymizationJobs()
    }

    /// Removes a terminal job.
    public func removeAnonymizationJob(id: UUID) {
        service.removeAnonymizationJob(id: id)
        anonymizationJobs = service.getAnonymizationJobs()
        if selectedJobID == id { selectedJobID = nil }
    }

    /// Returns the currently selected anonymization job.
    public var selectedJob: AnonymizationJob? {
        guard let id = selectedJobID else { return nil }
        return anonymizationJobs.first(where: { $0.id == id })
    }

    /// Returns a validation error message if the staged file list is empty or output dir is missing.
    public func jobValidationError() -> String? {
        if stagedFilePaths.isEmpty { return "No files staged for anonymization." }
        if outputDirectory.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Output directory must not be empty."
        }
        return nil
    }

    // MARK: - 11.3 Audit Log Actions

    /// Appends an audit log entry (and syncs to service).
    public func addAuditEntry(_ entry: SecurityAuditEntry) {
        service.addAuditEntry(entry)
        auditEntries = service.getAuditEntries()
    }

    /// Clears all audit log entries.
    public func clearAuditEntries() {
        service.clearAuditEntries()
        auditEntries = []
    }

    /// Applies the current retention policy.
    public func applyRetentionPolicy() {
        service.applyRetentionPolicy()
        auditEntries = service.getAuditEntries()
    }

    /// Enables or disables a log handler.
    public func setHandler(_ handler: SecurityAuditHandlerType, enabled: Bool) {
        service.setHandler(handler, enabled: enabled)
        enabledHandlers = service.getEnabledHandlers()
    }

    /// Sets the audit retention policy.
    public func setRetentionPolicy(_ policy: SecurityAuditRetentionPolicy) {
        retentionPolicy = policy
        service.setRetentionPolicy(policy)
    }

    /// Returns audit entries that match the current filter settings.
    public var filteredAuditEntries: [SecurityAuditEntry] {
        var result = auditEntries
        if let type = auditFilterEventType {
            result = SecurityAuditHelpers.filter(result, byType: type)
        }
        if !auditFilterUser.isEmpty {
            result = SecurityAuditHelpers.filter(result, byUser: auditFilterUser)
        }
        if !auditFilterReference.isEmpty {
            result = SecurityAuditHelpers.filter(result, byReference: auditFilterReference)
        }
        if let start = auditFilterStartDate, let end = auditFilterEndDate {
            result = result.filter { SecurityAuditHelpers.entry($0, isInRange: start...end) }
        }
        return result
    }

    /// Clears all audit log filters.
    public func clearAuditFilters() {
        auditFilterEventType = nil
        auditFilterUser = ""
        auditFilterReference = ""
        auditFilterStartDate = nil
        auditFilterEndDate = nil
    }

    /// Returns the audit log as CSV text for export.
    public func exportAuditLogCSV() -> String {
        SecurityAuditHelpers.toCSV(filteredAuditEntries)
    }

    /// Returns audit log statistics (counts per event type).
    public var auditStatistics: [SecurityAuditEventType: Int] {
        SecurityAuditHelpers.statistics(auditEntries)
    }

    // MARK: - 11.4 Access Control Actions

    /// Sets the current user session.
    public func setCurrentSession(_ session: AccessControlSession?) {
        service.setCurrentSession(session)
        currentSession = service.getCurrentSession()
    }

    /// Touches the session to update the last activity timestamp.
    public func touchSession() {
        service.touchSession()
        currentSession = service.getCurrentSession()
    }

    /// Locks the current session.
    public func lockSession() {
        service.lockSession()
        currentSession = service.getCurrentSession()
    }

    /// Records a break-glass emergency access event.
    public func recordBreakGlassEvent(resource: String) {
        guard !breakGlassReason.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let event = BreakGlassEvent(
            userName: currentSession?.userName ?? "Unknown",
            resourceReference: resource,
            reason: breakGlassReason,
            supervisorNotified: true
        )
        service.recordBreakGlassEvent(event)
        breakGlassEvents = service.getBreakGlassEvents()
        auditEntries = service.getAuditEntries()
        breakGlassReason = ""
        isBreakGlassDialogPresented = false
    }

    /// Returns whether the current user has a given permission.
    public func currentUserHasPermission(for action: String) -> Bool {
        guard let session = currentSession else { return false }
        return AccessControlHelpers.hasPermission(session.role, for: action)
    }

    /// Returns remaining session idle time in seconds, or nil if no session.
    public var remainingSessionTime: TimeInterval? {
        guard let session = currentSession else { return nil }
        return AccessControlHelpers.remainingSessionTime(for: session)
    }
}
