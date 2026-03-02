// NetworkingViewModelTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Networking ViewModel Tests")
struct NetworkingViewModelTests {

    // MARK: - Navigation

    @Test("default activeTab is serverConfig")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultActiveTab() {
        let vm = NetworkingViewModel()
        #expect(vm.activeTab == .serverConfig)
    }

    // MARK: - Server Config

    @Test("addServerProfile increases serverProfiles count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddServerProfile() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "Test", host: "localhost",
                                        remoteAETitle: "ORTHANC", localAETitle: "DS")
        vm.addServerProfile(profile)
        #expect(vm.serverProfiles.count == 1)
    }

    @Test("removeServerProfile decreases count and clears selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveServerProfile() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "Test", host: "localhost",
                                        remoteAETitle: "ORTHANC", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.selectedServerProfileID = profile.id
        vm.removeServerProfile(id: profile.id)
        #expect(vm.serverProfiles.isEmpty)
        #expect(vm.selectedServerProfileID == nil)
    }

    @Test("updateServerProfile updates name")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateServerProfile() {
        let vm = NetworkingViewModel()
        var profile = PACSServerProfile(name: "Old", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        profile.name = "New"
        vm.updateServerProfile(profile)
        #expect(vm.serverProfiles.first?.name == "New")
    }

    @Test("selectedServerProfile returns correct profile")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedServerProfile() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "PACS", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.selectedServerProfileID = profile.id
        #expect(vm.selectedServerProfile?.name == "PACS")
    }

    @Test("selectedServerProfile returns nil when no selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedServerProfileNilWhenNoSelection() {
        let vm = NetworkingViewModel()
        #expect(vm.selectedServerProfile == nil)
    }

    @Test("validationErrors for invalid profile returns errors")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testValidationErrors() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: " ", host: "  ",
                                        remoteAETitle: "lowercase", localAETitle: "DS")
        let errors = vm.validationErrors(for: profile)
        #expect(!errors.isEmpty)
    }

    // MARK: - C-ECHO

    @Test("performEcho appends echo history")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerformEcho() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "PACS", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, latencyMs: 20, success: true)
        #expect(vm.echoHistory.count == 1)
        #expect(vm.echoHistory.first?.success == true)
    }

    @Test("performEcho failure updates server status to error")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerformEchoFailure() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "PACS", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, success: false, errorMessage: "Refused")
        #expect(vm.serverProfiles.first?.status == .error)
    }

    @Test("clearEchoHistory empties echoHistory")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearEchoHistory() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "P", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, success: true)
        vm.clearEchoHistory()
        #expect(vm.echoHistory.isEmpty)
    }

    @Test("performBatchEcho runs echo for each server")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerformBatchEcho() {
        let vm = NetworkingViewModel()
        let p1 = PACSServerProfile(name: "P1", host: "h1", remoteAETitle: "A1", localAETitle: "DS")
        let p2 = PACSServerProfile(name: "P2", host: "h2", remoteAETitle: "A2", localAETitle: "DS")
        vm.addServerProfile(p1)
        vm.addServerProfile(p2)
        vm.performBatchEcho()
        #expect(vm.echoHistory.count == 2)
        #expect(vm.isBatchEchoInProgress == false)
    }

    // MARK: - C-FIND

    @Test("updateQueryFilter updates filter and summary")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateQueryFilter() {
        let vm = NetworkingViewModel()
        let filter = QueryFilter(patientName: "SMITH*", modality: "CT")
        vm.updateQueryFilter(filter)
        #expect(vm.queryFilter.patientName == "SMITH*")
        #expect(vm.queryFilterSummary.contains("SMITH*"))
    }

    @Test("loadQueryResults populates queryResults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadQueryResults() {
        let vm = NetworkingViewModel()
        let results = [
            QueryResultItem(level: .study, patientName: "DOE^J",
                            studyInstanceUID: "1.2.3"),
            QueryResultItem(level: .study, patientName: "SMITH^A",
                            studyInstanceUID: "1.2.4")
        ]
        vm.loadQueryResults(results)
        #expect(vm.queryResults.count == 2)
    }

    @Test("clearQueryResults empties queryResults")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearQueryResults() {
        let vm = NetworkingViewModel()
        vm.loadQueryResults([QueryResultItem(level: .study, studyInstanceUID: "1.2.3")])
        vm.clearQueryResults()
        #expect(vm.queryResults.isEmpty)
    }

    @Test("saveQueryFilter and loadSavedQueryFilter round-trips")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSaveAndLoadQueryFilter() {
        let vm = NetworkingViewModel()
        vm.updateQueryFilter(QueryFilter(patientName: "TEST*"))
        vm.saveQueryFilter(name: "MySearch")
        vm.updateQueryFilter(QueryFilter())
        vm.loadSavedQueryFilter(name: "MySearch")
        #expect(vm.queryFilter.patientName == "TEST*")
    }

    @Test("removeSavedQueryFilter removes from savedQueryFilters")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveSavedQueryFilter() {
        let vm = NetworkingViewModel()
        vm.updateQueryFilter(QueryFilter(patientName: "TO_REMOVE"))
        vm.saveQueryFilter(name: "ToRemove")
        vm.removeSavedQueryFilter(name: "ToRemove")
        #expect(vm.savedQueryFilters["ToRemove"] == nil)
    }

    // MARK: - C-MOVE/GET

    @Test("enqueueTransfer adds to transferQueue")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueTransfer() {
        let vm = NetworkingViewModel()
        let item = TransferItem(label: "Study 1", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID())
        vm.enqueueTransfer(item)
        #expect(vm.transferQueue.count == 1)
    }

    @Test("removeTransferItem clears selection when removing selected")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveTransferItemClearsSelection() {
        let vm = NetworkingViewModel()
        let item = TransferItem(label: "Study", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID())
        vm.enqueueTransfer(item)
        vm.selectedTransferItemID = item.id
        vm.removeTransferItem(id: item.id)
        #expect(vm.selectedTransferItemID == nil)
    }

    @Test("prioritizedTransferQueue orders high priority first")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPrioritizedTransferQueue() {
        let vm = NetworkingViewModel()
        let t = Date()
        let low  = TransferItem(label: "Low", studyInstanceUID: "1",
                                serverProfileID: UUID(), priority: .low,
                                queuedDate: t)
        let high = TransferItem(label: "High", studyInstanceUID: "2",
                                serverProfileID: UUID(), priority: .high,
                                queuedDate: t)
        vm.enqueueTransfer(low)
        vm.enqueueTransfer(high)
        #expect(vm.prioritizedTransferQueue.first?.priority == .high)
    }

    @Test("updateBandwidthLimit updates bandwidthLimit")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateBandwidthLimit() {
        let vm = NetworkingViewModel()
        vm.updateBandwidthLimit(BandwidthLimit(isEnabled: true, maxBytesPerSecond: 500_000))
        #expect(vm.bandwidthLimit.isEnabled == true)
        #expect(vm.bandwidthLimit.maxBytesPerSecond == 500_000)
    }

    // MARK: - C-STORE

    @Test("enqueueSendItem adds to sendQueue")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueSendItem() {
        let vm = NetworkingViewModel()
        let item = SendItem(label: "CT.dcm", sourceIdentifier: "UID1",
                            serverProfileID: UUID())
        vm.enqueueSendItem(item)
        #expect(vm.sendQueue.count == 1)
    }

    @Test("updateValidationLevel updates validationLevel")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateValidationLevel() {
        let vm = NetworkingViewModel()
        vm.updateValidationLevel(.strict)
        #expect(vm.validationLevel == .strict)
    }

    @Test("updateCircuitBreakerState updates state for profile")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateCircuitBreakerState() {
        let vm = NetworkingViewModel()
        let id = UUID()
        vm.updateCircuitBreakerState(.open, profileID: id)
        #expect(vm.circuitBreakerState(for: id) == .open)
    }

    // MARK: - MWL

    @Test("loadMWLItems populates mwlItems")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadMWLItems() {
        let vm = NetworkingViewModel()
        let items = [
            MWLWorklistItem(patientName: "DOE^J", patientID: "P1",
                            accessionNumber: "ACC1", requestedProcedureID: "RP1",
                            requestedProcedureDescription: "Chest CT",
                            scheduledStationAETitle: "CT1",
                            scheduledProcedureStepStartDate: "20260101", modality: "CT")
        ]
        vm.loadMWLItems(items)
        #expect(vm.mwlItems.count == 1)
    }

    @Test("filteredMWLItems filters by modality")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredMWLItemsByModality() {
        let vm = NetworkingViewModel()
        let ct = MWLWorklistItem(patientName: "DOE^J", patientID: "P1",
                                 accessionNumber: "ACC1", requestedProcedureID: "RP1",
                                 requestedProcedureDescription: "Chest CT",
                                 scheduledStationAETitle: "CT1",
                                 scheduledProcedureStepStartDate: "20260101", modality: "CT")
        let mr = MWLWorklistItem(patientName: "SMITH^A", patientID: "P2",
                                 accessionNumber: "ACC2", requestedProcedureID: "RP2",
                                 requestedProcedureDescription: "Brain MR",
                                 scheduledStationAETitle: "MR1",
                                 scheduledProcedureStepStartDate: "20260101", modality: "MR")
        vm.loadMWLItems([ct, mr])
        vm.updateMWLFilter(MWLFilter(modality: "CT"))
        #expect(vm.filteredMWLItems.count == 1)
        #expect(vm.filteredMWLItems.first?.modality == "CT")
    }

    @Test("selectedMWLItem returns correct item")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedMWLItem() {
        let vm = NetworkingViewModel()
        let item = MWLWorklistItem(patientName: "DOE^J", patientID: "P1",
                                   accessionNumber: "ACC1", requestedProcedureID: "RP1",
                                   requestedProcedureDescription: "CT",
                                   scheduledStationAETitle: "CT1",
                                   scheduledProcedureStepStartDate: "20260101", modality: "CT")
        vm.loadMWLItems([item])
        vm.selectedMWLItemID = item.id
        #expect(vm.selectedMWLItem?.patientID == "P1")
    }

    // MARK: - MPPS

    @Test("createMPPS adds to mppsItems")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCreateMPPS() {
        let vm = NetworkingViewModel()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "Chest CT",
                            performedStationAETitle: "CT1", modality: "CT")
        vm.createMPPS(item)
        #expect(vm.mppsItems.count == 1)
        #expect(vm.mppsItems.first?.status == .inProgress)
    }

    @Test("completeMPPS updates MPPS status to completed")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCompleteMPPS() {
        let vm = NetworkingViewModel()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        vm.createMPPS(item)
        vm.completeMPPS(id: item.id)
        #expect(vm.mppsItems.first?.status == .completed)
    }

    @Test("discontinueMPPS updates MPPS status to discontinued")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDiscontinueMPPS() {
        let vm = NetworkingViewModel()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        vm.createMPPS(item)
        vm.discontinueMPPS(id: item.id)
        #expect(vm.mppsItems.first?.status == .discontinued)
    }

    @Test("selectedMPPSItem returns correct item")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedMPPSItem() {
        let vm = NetworkingViewModel()
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT")
        vm.createMPPS(item)
        vm.selectedMPPSItemID = item.id
        #expect(vm.selectedMPPSItem?.patientID == "P1")
    }

    // MARK: - Print Management

    @Test("addPrintJob adds to printJobs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddPrintJob() {
        let vm = NetworkingViewModel()
        let job = PrintJob(label: "Job 1", printerServerProfileID: UUID())
        vm.addPrintJob(job)
        #expect(vm.printJobs.count == 1)
    }

    @Test("removePrintJob removes by ID and clears selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemovePrintJob() {
        let vm = NetworkingViewModel()
        let job = PrintJob(label: "Job", printerServerProfileID: UUID())
        vm.addPrintJob(job)
        vm.selectedPrintJobID = job.id
        vm.removePrintJob(id: job.id)
        #expect(vm.printJobs.isEmpty)
        #expect(vm.selectedPrintJobID == nil)
    }

    @Test("selectedPrintJob returns correct job")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedPrintJob() {
        let vm = NetworkingViewModel()
        let job = PrintJob(label: "Job", printerServerProfileID: UUID())
        vm.addPrintJob(job)
        vm.selectedPrintJobID = job.id
        #expect(vm.selectedPrintJob?.label == "Job")
    }

    // MARK: - Monitoring

    @Test("refreshMonitoringStats updates monitoringStats")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRefreshMonitoringStats() {
        let vm = NetworkingViewModel()
        let stats = NetworkMonitoringStats(activeAssociationCount: 3)
        vm.refreshMonitoringStats(stats)
        #expect(vm.monitoringStats.activeAssociationCount == 3)
    }

    @Test("monitoringSummary returns non-empty string")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testMonitoringSummaryNonEmpty() {
        let vm = NetworkingViewModel()
        #expect(!vm.monitoringSummary.isEmpty)
    }

    @Test("filteredAuditLog returns all when searchQuery is empty")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredAuditLogEmpty() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "P", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, success: true)
        vm.auditLogSearchQuery = ""
        #expect(vm.filteredAuditLog.count == vm.auditLog.count)
    }

    @Test("filteredAuditLog filters by search query")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testFilteredAuditLogSearch() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "MY_PACS", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, success: true)
        vm.auditLogSearchQuery = "echo"
        #expect(!vm.filteredAuditLog.isEmpty)
    }

    @Test("exportAuditLogCSV returns CSV with header")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testExportAuditLogCSV() {
        let vm = NetworkingViewModel()
        let csv = vm.exportAuditLogCSV()
        #expect(csv.contains("Timestamp"))
    }

    @Test("clearAuditLog empties auditLog")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearAuditLog() {
        let vm = NetworkingViewModel()
        let profile = PACSServerProfile(name: "P", host: "h",
                                        remoteAETitle: "AE", localAETitle: "DS")
        vm.addServerProfile(profile)
        vm.performEcho(profileID: profile.id, success: true)
        vm.clearAuditLog()
        #expect(vm.auditLog.isEmpty)
    }

    @Test("recordNetworkError adds to networkErrors")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRecordNetworkError() {
        let vm = NetworkingViewModel()
        let error = NetworkErrorItem(category: .timeout, message: "Timed out")
        vm.recordNetworkError(error)
        #expect(vm.networkErrors.count == 1)
    }

    @Test("clearNetworkErrors empties networkErrors")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearNetworkErrors() {
        let vm = NetworkingViewModel()
        vm.recordNetworkError(NetworkErrorItem(category: .transient, message: "Retry"))
        vm.clearNetworkErrors()
        #expect(vm.networkErrors.isEmpty)
    }
}
