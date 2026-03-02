// NetworkingServiceTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Networking Service Tests")
struct NetworkingServiceTests {

    // MARK: - Server Profiles

    @Test("addServerProfile and getServerProfiles round-trips")
    func testAddAndGetServerProfiles() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "PACS1", host: "pacs.hospital.com",
                                        remoteAETitle: "PACS", localAETitle: "DS")
        service.addServerProfile(profile)
        #expect(service.getServerProfiles().count == 1)
        #expect(service.getServerProfiles().first?.name == "PACS1")
    }

    @Test("addServerProfile with isDefault clears other defaults")
    func testAddDefaultClearsOtherDefaults() {
        let service = NetworkingService()
        let p1 = PACSServerProfile(name: "P1", host: "h1", remoteAETitle: "A1",
                                   localAETitle: "DS", isDefault: true)
        let p2 = PACSServerProfile(name: "P2", host: "h2", remoteAETitle: "A2",
                                   localAETitle: "DS", isDefault: true)
        service.addServerProfile(p1)
        service.addServerProfile(p2)
        let defaults = service.getServerProfiles().filter { $0.isDefault }
        #expect(defaults.count == 1)
        #expect(defaults.first?.name == "P2")
    }

    @Test("removeServerProfile removes by ID")
    func testRemoveServerProfile() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "PACS1", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        service.removeServerProfile(id: profile.id)
        #expect(service.getServerProfiles().isEmpty)
    }

    @Test("updateServerProfile updates existing profile")
    func testUpdateServerProfile() {
        let service = NetworkingService()
        var profile = PACSServerProfile(name: "Old", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        profile.name = "New"
        service.updateServerProfile(profile)
        #expect(service.getServerProfiles().first?.name == "New")
    }

    @Test("setServerStatus updates status")
    func testSetServerStatus() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        service.setServerStatus(profileID: profile.id, status: .online)
        #expect(service.getServerProfiles().first?.status == .online)
    }

    @Test("defaultServerProfile returns only the default")
    func testDefaultServerProfile() {
        let service = NetworkingService()
        let p1 = PACSServerProfile(name: "P1", host: "h1", remoteAETitle: "A1",
                                   localAETitle: "DS", isDefault: false)
        let p2 = PACSServerProfile(name: "P2", host: "h2", remoteAETitle: "A2",
                                   localAETitle: "DS", isDefault: true)
        service.addServerProfile(p1)
        service.addServerProfile(p2)
        #expect(service.defaultServerProfile()?.name == "P2")
    }

    // MARK: - Echo History

    @Test("recordEchoResult appends to history")
    func testRecordEchoResultAppends() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        let result = EchoResult(serverProfileID: profile.id, serverName: "P",
                                success: true, latencyMs: 20)
        service.recordEchoResult(result)
        #expect(service.getEchoHistory().count == 1)
    }

    @Test("recordEchoResult success updates server status to online")
    func testRecordEchoResultSuccessUpdatesStatus() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        let result = EchoResult(serverProfileID: profile.id, serverName: "P",
                                success: true, latencyMs: 10)
        service.recordEchoResult(result)
        #expect(service.getServerProfiles().first?.status == .online)
    }

    @Test("recordEchoResult failure updates server status to error")
    func testRecordEchoResultFailureUpdatesStatus() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        let result = EchoResult(serverProfileID: profile.id, serverName: "P",
                                success: false, errorMessage: "Refused")
        service.recordEchoResult(result)
        #expect(service.getServerProfiles().first?.status == .error)
    }

    @Test("recordEchoResult appends to audit log")
    func testRecordEchoResultAppendsAuditLog() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        let result = EchoResult(serverProfileID: profile.id, serverName: "P",
                                success: true, latencyMs: 5)
        service.recordEchoResult(result)
        let log = service.getAuditLog()
        #expect(log.contains { $0.eventType == .echo })
    }

    @Test("clearEchoHistory empties history")
    func testClearEchoHistory() {
        let service = NetworkingService()
        let profile = PACSServerProfile(name: "P", host: "h", remoteAETitle: "A", localAETitle: "DS")
        service.addServerProfile(profile)
        service.recordEchoResult(EchoResult(serverProfileID: profile.id, serverName: "P",
                                            success: true, latencyMs: 5))
        service.clearEchoHistory()
        #expect(service.getEchoHistory().isEmpty)
    }

    // MARK: - Query State

    @Test("setQueryFilter and getQueryFilter round-trips")
    func testQueryFilterRoundTrip() {
        let service = NetworkingService()
        let filter = QueryFilter(patientName: "DOE*", modality: "CT")
        service.setQueryFilter(filter)
        #expect(service.getQueryFilter().patientName == "DOE*")
        #expect(service.getQueryFilter().modality == "CT")
    }

    @Test("setQueryResults and getQueryResults round-trips")
    func testQueryResultsRoundTrip() {
        let service = NetworkingService()
        let results = [
            QueryResultItem(level: .study, patientName: "SMITH^J",
                            studyInstanceUID: "1.2.3"),
            QueryResultItem(level: .study, patientName: "JONES^A",
                            studyInstanceUID: "1.2.4")
        ]
        service.setQueryResults(results)
        #expect(service.getQueryResults().count == 2)
    }

    @Test("clearQueryResults empties results")
    func testClearQueryResults() {
        let service = NetworkingService()
        service.setQueryResults([QueryResultItem(level: .study, studyInstanceUID: "1.2.3")])
        service.clearQueryResults()
        #expect(service.getQueryResults().isEmpty)
    }

    @Test("saveQueryFilter stores and retrieveQueryFilter returns it")
    func testSaveAndGetQueryFilter() {
        let service = NetworkingService()
        let filter = QueryFilter(patientName: "TEST*")
        service.saveQueryFilter(name: "MyQuery", filter: filter)
        #expect(service.getSavedQueryFilters()["MyQuery"] != nil)
        #expect(service.getSavedQueryFilters()["MyQuery"]?.patientName == "TEST*")
    }

    @Test("removeSavedQueryFilter removes it")
    func testRemoveSavedQueryFilter() {
        let service = NetworkingService()
        service.saveQueryFilter(name: "ToRemove", filter: QueryFilter())
        service.removeSavedQueryFilter(name: "ToRemove")
        #expect(service.getSavedQueryFilters()["ToRemove"] == nil)
    }

    // MARK: - Transfer Queue

    @Test("enqueueTransfer and getTransferQueue round-trips")
    func testEnqueueTransfer() {
        let service = NetworkingService()
        let item = TransferItem(label: "Study 1", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID())
        service.enqueueTransfer(item)
        #expect(service.getTransferQueue().count == 1)
    }

    @Test("updateTransferItem updates existing item")
    func testUpdateTransferItem() {
        let service = NetworkingService()
        var item = TransferItem(label: "Study", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID())
        service.enqueueTransfer(item)
        item.status = .completed
        item.progress = 1.0
        service.updateTransferItem(item)
        #expect(service.getTransferQueue().first?.status == .completed)
    }

    @Test("removeTransferItem removes by ID")
    func testRemoveTransferItem() {
        let service = NetworkingService()
        let item = TransferItem(label: "Study", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID())
        service.enqueueTransfer(item)
        service.removeTransferItem(id: item.id)
        #expect(service.getTransferQueue().isEmpty)
    }

    @Test("setBandwidthLimit and getBandwidthLimit round-trips")
    func testBandwidthLimitRoundTrip() {
        let service = NetworkingService()
        let limit = BandwidthLimit(isEnabled: true, maxBytesPerSecond: 1_000_000)
        service.setBandwidthLimit(limit)
        #expect(service.getBandwidthLimit().isEnabled == true)
        #expect(service.getBandwidthLimit().maxBytesPerSecond == 1_000_000)
    }

    // MARK: - Send Queue

    @Test("enqueueSendItem and getSendQueue round-trips")
    func testEnqueueSendItem() {
        let service = NetworkingService()
        let item = SendItem(label: "CT001.dcm", sourceIdentifier: "UID1",
                            serverProfileID: UUID())
        service.enqueueSendItem(item)
        #expect(service.getSendQueue().count == 1)
    }

    @Test("updateSendItem updates existing item")
    func testUpdateSendItem() {
        let service = NetworkingService()
        var item = SendItem(label: "CT.dcm", sourceIdentifier: "UID1",
                            serverProfileID: UUID())
        service.enqueueSendItem(item)
        item.status = .completed
        service.updateSendItem(item)
        #expect(service.getSendQueue().first?.status == .completed)
    }

    @Test("removeSendItem removes by ID")
    func testRemoveSendItem() {
        let service = NetworkingService()
        let item = SendItem(label: "CT.dcm", sourceIdentifier: "UID1", serverProfileID: UUID())
        service.enqueueSendItem(item)
        service.removeSendItem(id: item.id)
        #expect(service.getSendQueue().isEmpty)
    }

    @Test("setSendRetryConfig and getSendRetryConfig round-trips")
    func testSendRetryConfigRoundTrip() {
        let service = NetworkingService()
        let config = SendRetryConfig(maxRetries: 5, initialDelaySeconds: 2.0)
        service.setSendRetryConfig(config)
        #expect(service.getSendRetryConfig().maxRetries == 5)
    }

    @Test("setValidationLevel and getValidationLevel round-trips")
    func testValidationLevelRoundTrip() {
        let service = NetworkingService()
        service.setValidationLevel(.strict)
        #expect(service.getValidationLevel() == .strict)
    }

    @Test("setCircuitBreakerState and getCircuitBreakerState round-trips")
    func testCircuitBreakerStateRoundTrip() {
        let service = NetworkingService()
        let id = UUID()
        service.setCircuitBreakerState(.open, profileID: id)
        #expect(service.getCircuitBreakerState(profileID: id) == .open)
    }

    @Test("getCircuitBreakerState returns closed by default")
    func testCircuitBreakerDefaultClosed() {
        let service = NetworkingService()
        #expect(service.getCircuitBreakerState(profileID: UUID()) == .closed)
    }

    // MARK: - MWL

    @Test("setMWLItems and getMWLItems round-trips")
    func testMWLItemsRoundTrip() {
        let service = NetworkingService()
        let items = [
            MWLWorklistItem(patientName: "DOE^J", patientID: "P1",
                            accessionNumber: "ACC1", requestedProcedureID: "RP1",
                            requestedProcedureDescription: "CT Chest",
                            scheduledStationAETitle: "CT1",
                            scheduledProcedureStepStartDate: "20260101", modality: "CT")
        ]
        service.setMWLItems(items)
        #expect(service.getMWLItems().count == 1)
        #expect(service.getMWLItems().first?.patientName == "DOE^J")
    }

    @Test("setMWLFilter and getMWLFilter round-trips")
    func testMWLFilterRoundTrip() {
        let service = NetworkingService()
        let filter = MWLFilter(date: "20260101", modality: "MR")
        service.setMWLFilter(filter)
        #expect(service.getMWLFilter().date == "20260101")
        #expect(service.getMWLFilter().modality == "MR")
    }

    // MARK: - MPPS

    @Test("createMPPS and getMPPSItems stores item")
    func testCreateMPPS() {
        let service = NetworkingService()
        let item = MPPSItem(patientName: "SMITH^J", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "Chest CT",
                            performedStationAETitle: "CT1", modality: "CT")
        service.createMPPS(item)
        #expect(service.getMPPSItems().count == 1)
        #expect(service.getMPPSItems().first?.status == .inProgress)
    }

    @Test("updateMPPSStatus to completed sets status")
    func testUpdateMPPSStatusCompleted() {
        let service = NetworkingService()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        service.createMPPS(item)
        service.updateMPPSStatus(id: item.id, status: .completed, endDateTime: Date())
        #expect(service.getMPPSItems().first?.status == .completed)
    }

    @Test("createMPPS appends to audit log")
    func testCreateMPPSAuditLog() {
        let service = NetworkingService()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        service.createMPPS(item)
        #expect(service.getAuditLog().contains { $0.eventType == .mppsCreate })
    }

    @Test("updateMPPSStatus appends to audit log")
    func testUpdateMPPSStatusAuditLog() {
        let service = NetworkingService()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        service.createMPPS(item)
        service.updateMPPSStatus(id: item.id, status: .discontinued)
        #expect(service.getAuditLog().contains { $0.eventType == .mppsUpdate })
    }

    // MARK: - Print

    @Test("addPrintJob and getPrintJobs round-trips")
    func testAddPrintJob() {
        let service = NetworkingService()
        let job = PrintJob(label: "Job 1", printerServerProfileID: UUID())
        service.addPrintJob(job)
        #expect(service.getPrintJobs().count == 1)
    }

    @Test("updatePrintJob updates status")
    func testUpdatePrintJob() {
        let service = NetworkingService()
        var job = PrintJob(label: "Job", printerServerProfileID: UUID())
        service.addPrintJob(job)
        job.status = .completed
        service.updatePrintJob(job)
        #expect(service.getPrintJobs().first?.status == .completed)
    }

    @Test("removePrintJob removes by ID")
    func testRemovePrintJob() {
        let service = NetworkingService()
        let job = PrintJob(label: "Job", printerServerProfileID: UUID())
        service.addPrintJob(job)
        service.removePrintJob(id: job.id)
        #expect(service.getPrintJobs().isEmpty)
    }

    @Test("addPrintJob appends to audit log")
    func testAddPrintJobAuditLog() {
        let service = NetworkingService()
        let job = PrintJob(label: "Job", printerServerProfileID: UUID())
        service.addPrintJob(job)
        #expect(service.getAuditLog().contains { $0.eventType == .printJob })
    }

    // MARK: - Monitoring

    @Test("updateMonitoringStats updates latest and history")
    func testUpdateMonitoringStats() {
        let service = NetworkingService()
        let stats = NetworkMonitoringStats(pooledConnectionCount: 3, activeAssociationCount: 1)
        service.updateMonitoringStats(stats)
        #expect(service.getMonitoringStats().pooledConnectionCount == 3)
        #expect(service.getMonitoringHistory().count == 1)
    }

    @Test("monitoring history is capped at 300 entries")
    func testMonitoringHistoryCap() {
        let service = NetworkingService()
        for i in 0..<310 {
            service.updateMonitoringStats(NetworkMonitoringStats(totalOperations: i))
        }
        #expect(service.getMonitoringHistory().count == 300)
    }

    @Test("recordNetworkError and getNetworkErrors round-trips")
    func testRecordNetworkError() {
        let service = NetworkingService()
        let err = NetworkErrorItem(category: .timeout, message: "Connection timed out")
        service.recordNetworkError(err)
        #expect(service.getNetworkErrors().count == 1)
        #expect(service.getNetworkErrors().first?.category == .timeout)
    }

    @Test("clearNetworkErrors empties errors")
    func testClearNetworkErrors() {
        let service = NetworkingService()
        service.recordNetworkError(NetworkErrorItem(category: .transient, message: "Retry"))
        service.clearNetworkErrors()
        #expect(service.getNetworkErrors().isEmpty)
    }

    // MARK: - Audit Log

    @Test("appendAuditEntry and getAuditLog round-trips")
    func testAppendAndGetAuditLog() {
        let service = NetworkingService()
        let entry = AuditLogEntry(eventType: .find, outcome: .success,
                                  remoteEntity: "PACS", localAETitle: "DS")
        service.appendAuditEntry(entry)
        #expect(service.getAuditLog().count >= 1)
    }

    @Test("auditLogEntries(for:) filters by event type")
    func testAuditLogFilterByEventType() {
        let service = NetworkingService()
        service.appendAuditEntry(AuditLogEntry(eventType: .echo, outcome: .success,
                                               remoteEntity: "PACS", localAETitle: "DS"))
        service.appendAuditEntry(AuditLogEntry(eventType: .store, outcome: .success,
                                               remoteEntity: "PACS", localAETitle: "DS"))
        #expect(service.auditLogEntries(for: .echo).count == 1)
        #expect(service.auditLogEntries(for: .store).count == 1)
    }

    @Test("auditLogEntries(outcome:) filters by outcome")
    func testAuditLogFilterByOutcome() {
        let service = NetworkingService()
        service.appendAuditEntry(AuditLogEntry(eventType: .find, outcome: .success,
                                               remoteEntity: "PACS", localAETitle: "DS"))
        service.appendAuditEntry(AuditLogEntry(eventType: .store, outcome: .failure,
                                               remoteEntity: "PACS", localAETitle: "DS"))
        #expect(service.auditLogEntries(outcome: .success).count >= 1)
        #expect(service.auditLogEntries(outcome: .failure).count >= 1)
    }

    @Test("clearAuditLog empties log")
    func testClearAuditLog() {
        let service = NetworkingService()
        service.appendAuditEntry(AuditLogEntry(eventType: .echo, outcome: .success,
                                               remoteEntity: "PACS", localAETitle: "DS"))
        service.clearAuditLog()
        #expect(service.getAuditLog().isEmpty)
    }

    @Test("getAuditLog returns newest entries first")
    func testAuditLogOrderedNewestFirst() {
        let service = NetworkingService()
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 2000)
        service.appendAuditEntry(AuditLogEntry(eventType: .echo, outcome: .success,
                                               remoteEntity: "A", localAETitle: "DS", timestamp: t1))
        service.appendAuditEntry(AuditLogEntry(eventType: .find, outcome: .success,
                                               remoteEntity: "B", localAETitle: "DS", timestamp: t2))
        let log = service.getAuditLog()
        #expect(log.first?.timestamp == t2)
    }
}
