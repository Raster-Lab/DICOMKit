// SecurityViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for the Security & Privacy Center (Milestone 11)
// Reference: DICOM PS3.15 (Security and System Management Profiles)
// Reference: HIPAA Security Rule §164.312

import Foundation
import Observation
import DICOMKit
import DICOMCore

/// ViewModel for the Security & Privacy Center, managing state for all four sections:
/// TLS configuration, anonymization tool, audit log viewer, and access control.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
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

    // MARK: - 11.2b Anon Builder (dicom-anon CLI parity)

    /// --input path
    public var anonInputPath: String = ""
    /// --output path
    public var anonOutputPath: String = ""
    /// --profile
    public var anonProfile: AnonymizationProfile = .basic
    /// --shift-dates N (nil = disabled)
    public var anonShiftDatesEnabled: Bool = false
    public var anonShiftDays: Int = 0
    /// --regenerate-uids
    public var anonRegenerateUIDs: Bool = false
    /// --remove tag (one per entry, format: 0010,0010 or PatientName)
    public var anonRemoveTags: [String] = []
    /// --replace tag=value
    public var anonReplacePairs: [String] = []
    /// --keep tag
    public var anonKeepTags: [String] = []
    /// --recursive
    public var anonRecursive: Bool = false
    /// --dry-run
    public var anonDryRun: Bool = false
    /// --backup
    public var anonBackup: Bool = false
    /// --audit-log path
    public var anonAuditLogPath: String = ""
    /// --force
    public var anonForce: Bool = false
    /// --verbose
    public var anonVerbose: Bool = false
    /// Running flag
    public var anonIsRunning: Bool = false
    /// Output text (matches dicom-anon printSummary() format)
    public var anonOutput: String = ""

    // MARK: - Security-Scoped Resource Access
    // Set by the view (or CLIWorkshopViewModel) immediately after NSOpenPanel /
    // NSSavePanel so the sandbox can read/write those paths.
    public var anonInputScopedURL: URL?
    public var anonOutputScopedURL: URL?

    /// Transient new-tag entry state
    public var anonNewRemoveTag: String = ""
    public var anonNewReplaceTag: String = ""
    public var anonNewReplaceValue: String = ""
    public var anonNewKeepTag: String = ""

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

    // MARK: - 11.2b Anon Builder Actions

    /// Returns the exact dicom-anon CLI command for current builder state.
    public var anonCLICommand: String {
        AnonHelpers.buildCommand(
            inputPath: anonInputPath,
            outputPath: anonOutputPath,
            profile: anonProfile,
            shiftDates: anonShiftDatesEnabled ? anonShiftDays : nil,
            regenerateUIDs: anonRegenerateUIDs,
            removeTags: anonRemoveTags,
            replacePairs: anonReplacePairs,
            keepTags: anonKeepTags,
            recursive: anonRecursive,
            dryRun: anonDryRun,
            backup: anonBackup,
            auditLogPath: anonAuditLogPath,
            force: anonForce,
            verbose: anonVerbose
        )
    }

    public func addRemoveTag() {
        let tag = anonNewRemoveTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !anonRemoveTags.contains(tag) else { return }
        anonRemoveTags.append(tag)
        anonNewRemoveTag = ""
    }

    public func removeRemoveTag(_ tag: String) {
        anonRemoveTags.removeAll { $0 == tag }
    }

    public func addReplacePair() {
        let tag   = anonNewReplaceTag.trimmingCharacters(in: .whitespaces)
        let value = anonNewReplaceValue.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        let pair = "\(tag)=\(value)"
        if !anonReplacePairs.contains(pair) {
            anonReplacePairs.append(pair)
        }
        anonNewReplaceTag = ""
        anonNewReplaceValue = ""
    }

    public func removeReplacePair(_ pair: String) {
        anonReplacePairs.removeAll { $0 == pair }
    }

    public func addKeepTag() {
        let tag = anonNewKeepTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !anonKeepTags.contains(tag) else { return }
        anonKeepTags.append(tag)
        anonNewKeepTag = ""
    }

    public func removeKeepTag(_ tag: String) {
        anonKeepTags.removeAll { $0 == tag }
    }

    /// Runs anonymization natively using DICOMKit APIs.
    /// Output matches dicom-anon printSummary() exactly.
    public func runAnonymization() {
        guard !anonInputPath.isEmpty else {
            anonOutput = "Error: Input path is required.\n"
            return
        }
        anonIsRunning = true
        anonOutput = "Running: \(anonCLICommand)\n"

        // Capture all parameters before crossing isolation boundary
        let inputPath   = anonInputPath
        let outputPath  = anonOutputPath
        let profile     = anonProfile
        let shiftDays   = anonShiftDatesEnabled ? anonShiftDays : nil
        let regen       = anonRegenerateUIDs
        let removeTags  = anonRemoveTags
        let replacePairs = anonReplacePairs
        let keepTags    = anonKeepTags
        let recursive   = anonRecursive
        let dryRun      = anonDryRun
        let backup      = anonBackup
        let auditLog    = anonAuditLogPath
        let force       = anonForce
        let verbose     = anonVerbose

        Task {
            let result = await self.executeAnonymization(
                inputPath: inputPath,
                outputPath: outputPath,
                profile: profile,
                shiftDays: shiftDays,
                regenerateUIDs: regen,
                removeTags: removeTags,
                replacePairs: replacePairs,
                keepTags: keepTags,
                recursive: recursive,
                dryRun: dryRun,
                backup: backup,
                auditLogPath: auditLog,
                force: force,
                verbose: verbose
            )
            self.anonOutput = result
            self.anonIsRunning = false
        }
    }

    public func clearAnonOutput() {
        anonOutput = ""
    }

    // MARK: - 11.2b Anon Engine (native DICOMKit, matches dicom-anon output)

    private func executeAnonymization(
        inputPath: String,
        outputPath: String,
        profile: AnonymizationProfile,
        shiftDays: Int?,
        regenerateUIDs: Bool,
        removeTags: [String],
        replacePairs: [String],
        keepTags: [String],
        recursive: Bool,
        dryRun: Bool,
        backup: Bool,
        auditLogPath: String,
        force: Bool,
        verbose: Bool
    ) async -> String {
        // Start security-scoped resource access so the sandbox allows reading
        // the user-selected input and writing to the chosen output directory.
        let inputAccessing  = anonInputScopedURL?.startAccessingSecurityScopedResource()  ?? false
        let outputAccessing = anonOutputScopedURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if inputAccessing  { anonInputScopedURL?.stopAccessingSecurityScopedResource() }
            if outputAccessing { anonOutputScopedURL?.stopAccessingSecurityScopedResource() }
        }

        // Resolve a guaranteed-writable output path before any file I/O.
        let (effectiveOutputPath, redirectNote) = Self.resolveWritableOutput(
            path: outputPath,
            scopedURL: anonOutputScopedURL
        )

        var totalFiles = 0
        var successful = 0
        var failed = 0
        var warnings: [String] = []
        var modifiedTagNames: [String] = []
        var output = redirectNote ?? ""

        // Resolve file list
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputPath, isDirectory: &isDir) else {
            return "Error: Input path not found: \(inputPath)\n"
        }

        var fileURLs: [URL] = []
        if isDir.boolValue {
            guard recursive else {
                return "Error: Directory anonymization requires --recursive flag\n"
            }
            guard !outputPath.isEmpty else {
                return "Error: Directory anonymization requires --output directory\n"
            }
            let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: inputPath),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                let rv = try? url.resourceValues(forKeys: [.isRegularFileKey])
                if rv?.isRegularFile == true { fileURLs.append(url) }
            }
        } else {
            fileURLs = [URL(fileURLWithPath: inputPath)]
        }

        // Parse custom tag actions
        let removedTagSet = Set(removeTags)
        var replaceMap: [String: String] = [:]
        for pair in replacePairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { replaceMap[String(parts[0])] = String(parts[1]) }
        }
        let keepTagSet = Set(keepTags)

        // Profile tag lists (mirrors Anonymizer.swift tagsToRemove)
        let basicTags   = Self.basicProfileTagNames
        let clinicalTags = basicTags.union([
            "0008,0020", "0008,0021", "0008,0022", "0008,0023",
            "0008,0030", "0008,0031", "0008,0032", "0008,0033",
        ])
        let researchTags: Set<String> = ["0010,0010", "0010,0020", "0010,0030"]

        let profileTags: Set<String>
        switch profile {
        case .basic, .hipaaeSafeHarbor: profileTags = basicTags
        case .clinicalTrial:            profileTags = clinicalTags
        case .research:                 profileTags = researchTags
        case .custom:                   profileTags = Set(removeTags)
        }

        for fileURL in fileURLs {
            totalFiles += 1
            if verbose { output += "Processing: \(fileURL.lastPathComponent)\n" }

            do {
                let data = try Data(contentsOf: fileURL)
                var dicomFile = try DICOMFile.read(from: data, force: force)
                var changed: [String] = []

                // Apply profile removals
                for tagStr in profileTags {
                    if keepTagSet.contains(tagStr) { continue }
                    if let tag = Self.parseTag(tagStr) {
                        if dicomFile.dataSet[tag] != nil {
                            dicomFile = DICOMFile(
                                fileMetaInformation: dicomFile.fileMetaInformation,
                                dataSet: { var ds = dicomFile.dataSet; ds[tag] = nil; return ds }()
                            )
                            changed.append(tagStr)
                        }
                    }
                }

                // Apply custom removals
                for tagStr in removedTagSet {
                    if keepTagSet.contains(tagStr) { continue }
                    if let tag = Self.parseTag(tagStr), dicomFile.dataSet[tag] != nil {
                        dicomFile = DICOMFile(
                            fileMetaInformation: dicomFile.fileMetaInformation,
                            dataSet: { var ds = dicomFile.dataSet; ds[tag] = nil; return ds }()
                        )
                        changed.append(tagStr)
                    }
                }

                // Apply replacements
                for (tagStr, value) in replaceMap {
                    if keepTagSet.contains(tagStr) { continue }
                    if let tag = Self.parseTag(tagStr) {
                        var ds = dicomFile.dataSet
                        ds.setString(value, for: tag, vr: .LO)
                        dicomFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: ds)
                        changed.append("\(tagStr)=\(value)")
                    }
                }

                // Date shift
                if let days = shiftDays {
                    let dateTags: [(Tag, String)] = [
                        (.studyDate, "0008,0020"), (.seriesDate, "0008,0021"),
                        (.acquisitionDate, "0008,0022"), (.contentDate, "0008,0023"),
                        (.patientBirthDate, "0010,0030"),
                    ]
                    for (tag, tagStr) in dateTags {
                        if keepTagSet.contains(tagStr) { continue }
                        if let dateStr = dicomFile.dataSet.string(for: tag),
                           let shifted = Self.shiftDICOMDate(dateStr, byDays: days) {
                            var ds = dicomFile.dataSet
                            ds.setString(shifted, for: tag, vr: .DA)
                            dicomFile = DICOMFile(fileMetaInformation: dicomFile.fileMetaInformation, dataSet: ds)
                            changed.append(tagStr)
                        }
                    }
                }

                modifiedTagNames.append(contentsOf: changed)

                if !dryRun {
                    let destURL: URL
                    if isDir.boolValue {
                        let relative = fileURL.path.replacingOccurrences(of: inputPath, with: "").drop(while: { $0 == "/" })
                        destURL = URL(fileURLWithPath: effectiveOutputPath).appendingPathComponent(String(relative))
                        try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    } else {
                        destURL = effectiveOutputPath.isEmpty ? fileURL : URL(fileURLWithPath: effectiveOutputPath)
                    }
                    if backup {
                        let backupURL = fileURL.appendingPathExtension("backup")
                        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
                    }
                    let outData = try dicomFile.write()
                    try outData.write(to: destURL)
                }

                successful += 1
                if verbose { output += "  ✓ \(changed.count) tags modified\n" }

            } catch {
                failed += 1
                warnings.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
                if verbose { output += "  ✗ \(error.localizedDescription)\n" }
            }
        }

        // Write audit log
        if !auditLogPath.isEmpty && !dryRun {
            let logURL = URL(fileURLWithPath: auditLogPath)
            let logText = "Anonymization audit log\n\(Date())\nFiles: \(totalFiles), Successful: \(successful), Failed: \(failed)\n"
            try? logText.write(to: logURL, atomically: true, encoding: .utf8)
        }

        let summary = AnonHelpers.renderSummary(
            totalFiles: totalFiles,
            successful: successful,
            failed: failed,
            dryRun: dryRun,
            warnings: warnings,
            modifiedTags: Array(Set(modifiedTagNames)),
            verbose: verbose
        )
        return output + summary
    }

    // MARK: - Anon Engine Helpers

    /// Resolves a writable output path within the sandbox.
    ///
    /// Priority:
    ///  1. The security-scoped URL from the file picker (always writable).
    ///  2. Any path already under ~/Downloads (covered by the downloads entitlement).
    ///  3. ~/Downloads/DICOMStudio/Anonymized/ as a safe fallback.
    ///
    /// Returns the resolved path and an optional redirect notice to display in the output.
    static func resolveWritableOutput(
        path: String,
        scopedURL: URL?
    ) -> (path: String, redirectNote: String?) {
        // 1. Scoped URL — always writable
        if let url = scopedURL { return (url.path, nil) }
        guard !path.isEmpty else { return (path, nil) }

        let fm = FileManager.default

        // 2. ~/Downloads — directly accessible via entitlement
        let downloadsPath = fm.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?.path ?? (NSHomeDirectory() + "/Downloads")
        if path.hasPrefix(downloadsPath) { return (path, nil) }

        // 3. Check if an existing ancestor is writable (handles paths the user
        //    has already been granted access to in a previous session)
        var ancestor = (path as NSString).deletingLastPathComponent
        for _ in 0..<5 {
            if fm.isWritableFile(atPath: ancestor) { return (path, nil) }
            let parent = (ancestor as NSString).deletingLastPathComponent
            if parent == ancestor { break }
            ancestor = parent
        }

        // 4. Fall back to ~/Downloads/DICOMStudio/Anonymized/
        let fallback = URL(fileURLWithPath: downloadsPath)
            .appendingPathComponent("DICOMStudio")
            .appendingPathComponent("Anonymized")
        try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
        let note = """
            ⚠ Output redirected to: \(fallback.path)
              (Sandbox: use the Browse button to select a writable output location)

            """
        return (fallback.path, note)
    }

    private static var basicProfileTagNames: Set<String> {
        Set([
            "0010,0010", // PatientName
            "0010,0020", // PatientID
            "0010,0030", // PatientBirthDate
            "0010,0035", // PatientBirthTime
            "0010,1000", // OtherPatientIDs
            "0010,1001", // OtherPatientNames
            "0010,4000", // PatientComments
            "0008,0090", // ReferringPhysicianName
            "0008,1050", // PerformingPhysicianName
            "0008,1070", // OperatorName
            "0008,0080", // InstitutionName
            "0008,0081", // InstitutionAddress
            "0008,1010", // StationName
            "0018,1000", // DeviceSerialNumber
        ])
    }

    private static func parseTag(_ string: String) -> Tag? {
        let clean = string
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard clean.count == 8, let value = UInt32(clean, radix: 16) else { return nil }
        let group   = UInt16((value >> 16) & 0xFFFF)
        let element = UInt16(value & 0xFFFF)
        return Tag(group: group, element: element)
    }

    private static func shiftDICOMDate(_ dateStr: String, byDays days: Int) -> String? {
        let trimmed = dateStr.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 8 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: trimmed),
              let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) else { return nil }
        return formatter.string(from: shifted)
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
