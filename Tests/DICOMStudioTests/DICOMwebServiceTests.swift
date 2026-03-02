// DICOMwebServiceTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("DICOMweb Service Tests")
struct DICOMwebServiceTests {

    // MARK: - Server Profiles

    @Test("initial server profiles is empty")
    func testInitialServerProfilesEmpty() {
        let service = DICOMwebService()
        #expect(service.getServerProfiles().isEmpty)
    }

    @Test("addServerProfile increases count")
    func testAddServerProfileIncreasesCount() {
        let service = DICOMwebService()
        service.addServerProfile(DICOMwebServerProfile(name: "Test", baseURL: "https://pacs.example.com"))
        #expect(service.getServerProfiles().count == 1)
    }

    @Test("addServerProfile with isDefault clears other defaults")
    func testAddServerProfileDefaultClearsOthers() {
        let service = DICOMwebService()
        let p1 = DICOMwebServerProfile(name: "P1", baseURL: "https://pacs1.example.com", isDefault: true)
        let p2 = DICOMwebServerProfile(name: "P2", baseURL: "https://pacs2.example.com", isDefault: true)
        service.addServerProfile(p1)
        service.addServerProfile(p2)
        let defaults = service.getServerProfiles().filter { $0.isDefault }
        #expect(defaults.count == 1)
        #expect(defaults.first?.name == "P2")
    }

    @Test("updateServerProfile updates name")
    func testUpdateServerProfileUpdatesName() {
        let service = DICOMwebService()
        var profile = DICOMwebServerProfile(name: "Old")
        service.addServerProfile(profile)
        profile.name = "New"
        service.updateServerProfile(profile)
        #expect(service.getServerProfiles().first?.name == "New")
    }

    @Test("removeServerProfile decreases count")
    func testRemoveServerProfileDecreasesCount() {
        let service = DICOMwebService()
        let profile = DICOMwebServerProfile(name: "Test")
        service.addServerProfile(profile)
        service.removeServerProfile(id: profile.id)
        #expect(service.getServerProfiles().isEmpty)
    }

    @Test("setDefaultProfile sets one default and clears others")
    func testSetDefaultProfileClearsOthers() {
        let service = DICOMwebService()
        let p1 = DICOMwebServerProfile(name: "P1")
        let p2 = DICOMwebServerProfile(name: "P2")
        service.addServerProfile(p1)
        service.addServerProfile(p2)
        service.setDefaultProfile(id: p1.id)
        let profiles = service.getServerProfiles()
        #expect(profiles.first(where: { $0.id == p1.id })?.isDefault == true)
        #expect(profiles.first(where: { $0.id == p2.id })?.isDefault == false)
    }

    @Test("defaultProfile returns the default profile")
    func testDefaultProfileReturnsDefault() {
        let service = DICOMwebService()
        let p1 = DICOMwebServerProfile(name: "P1")
        let p2 = DICOMwebServerProfile(name: "P2", isDefault: true)
        service.addServerProfile(p1)
        service.addServerProfile(p2)
        #expect(service.defaultProfile()?.name == "P2")
    }

    @Test("profile(for:) returns correct profile")
    func testProfileForIDReturnsCorrect() {
        let service = DICOMwebService()
        let profile = DICOMwebServerProfile(name: "Target")
        service.addServerProfile(profile)
        #expect(service.profile(for: profile.id)?.name == "Target")
    }

    @Test("updateConnectionStatus updates correctly")
    func testUpdateConnectionStatusUpdates() {
        let service = DICOMwebService()
        let profile = DICOMwebServerProfile()
        service.addServerProfile(profile)
        service.updateConnectionStatus(.online, error: nil, for: profile.id)
        #expect(service.getServerProfiles().first?.connectionStatus == .online)
    }

    // MARK: - QIDO-RS State

    @Test("initial QIDO params are default")
    func testInitialQIDOParamsAreDefault() {
        let service = DICOMwebService()
        let params = service.getQIDOQueryParams()
        #expect(params.patientName.isEmpty)
        #expect(params.limit == 100)
    }

    @Test("setQIDOQueryParams and getQIDOQueryParams round-trips")
    func testQIDOQueryParamsRoundTrip() {
        let service = DICOMwebService()
        let params = QIDOQueryParams(patientName: "SMITH*", modality: "CT")
        service.setQIDOQueryParams(params)
        #expect(service.getQIDOQueryParams().patientName == "SMITH*")
        #expect(service.getQIDOQueryParams().modality == "CT")
    }

    @Test("setQIDOResults and getQIDOResults round-trips")
    func testQIDOResultsRoundTrip() {
        let service = DICOMwebService()
        let results = [
            QIDOResultItem(studyInstanceUID: "1.2.3"),
            QIDOResultItem(studyInstanceUID: "1.2.4")
        ]
        service.setQIDOResults(results)
        #expect(service.getQIDOResults().count == 2)
    }

    @Test("clearQIDOResults clears results")
    func testClearQIDOResultsClears() {
        let service = DICOMwebService()
        service.setQIDOResults([QIDOResultItem()])
        service.clearQIDOResults()
        #expect(service.getQIDOResults().isEmpty)
    }

    @Test("setQIDOSelectedResultID and getQIDOSelectedResultID round-trips")
    func testQIDOSelectedResultIDRoundTrip() {
        let service = DICOMwebService()
        let id = UUID()
        service.setQIDOSelectedResultID(id)
        #expect(service.getQIDOSelectedResultID() == id)
    }

    @Test("saveQueryTemplate and getSavedQueryTemplates adds template")
    func testSaveQueryTemplateAddsTemplate() {
        let service = DICOMwebService()
        let params = QIDOQueryParams(patientName: "DOE*")
        service.saveQueryTemplate(name: "MyTemplate", params: params)
        #expect(service.getSavedQueryTemplates()["MyTemplate"]?.patientName == "DOE*")
    }

    @Test("removeQueryTemplate removes template")
    func testRemoveQueryTemplateRemoves() {
        let service = DICOMwebService()
        service.saveQueryTemplate(name: "ToRemove", params: QIDOQueryParams())
        service.removeQueryTemplate(name: "ToRemove")
        #expect(service.getSavedQueryTemplates()["ToRemove"] == nil)
    }

    // MARK: - WADO-RS State

    @Test("addWADOJob increases count")
    func testAddWADOJobIncreasesCount() {
        let service = DICOMwebService()
        service.addWADOJob(WADORetrieveJob(studyInstanceUID: "1.2.3"))
        #expect(service.getWADOJobs().count == 1)
    }

    @Test("updateWADOJob updates status")
    func testUpdateWADOJobUpdatesStatus() {
        let service = DICOMwebService()
        var job = WADORetrieveJob(studyInstanceUID: "1.2.3")
        service.addWADOJob(job)
        job.status = .completed
        service.updateWADOJob(job)
        #expect(service.getWADOJobs().first?.status == .completed)
    }

    @Test("removeWADOJob decreases count")
    func testRemoveWADOJobDecreasesCount() {
        let service = DICOMwebService()
        let job = WADORetrieveJob(studyInstanceUID: "1.2.3")
        service.addWADOJob(job)
        service.removeWADOJob(id: job.id)
        #expect(service.getWADOJobs().isEmpty)
    }

    @Test("clearCompletedWADOJobs removes terminal jobs only")
    func testClearCompletedWADOJobsLeavesActive() {
        let service = DICOMwebService()
        let active = WADORetrieveJob(studyInstanceUID: "1.2.3", status: .inProgress)
        let done   = WADORetrieveJob(studyInstanceUID: "1.2.4", status: .completed)
        service.addWADOJob(active)
        service.addWADOJob(done)
        service.clearCompletedWADOJobs()
        #expect(service.getWADOJobs().count == 1)
        #expect(service.getWADOJobs().first?.status == .inProgress)
    }

    // MARK: - STOW-RS State

    @Test("addSTOWJob increases count")
    func testAddSTOWJobIncreasesCount() {
        let service = DICOMwebService()
        service.addSTOWJob(STOWUploadJob(filePaths: ["a.dcm"]))
        #expect(service.getSTOWJobs().count == 1)
    }

    @Test("clearCompletedSTOWJobs removes terminal jobs only")
    func testClearCompletedSTOWJobsLeavesActive() {
        let service = DICOMwebService()
        let active = STOWUploadJob(status: .uploading)
        let done   = STOWUploadJob(status: .completed)
        service.addSTOWJob(active)
        service.addSTOWJob(done)
        service.clearCompletedSTOWJobs()
        #expect(service.getSTOWJobs().count == 1)
        #expect(service.getSTOWJobs().first?.status == .uploading)
    }

    // MARK: - UPS-RS State

    @Test("addUPSWorkitem increases count")
    func testAddUPSWorkitemIncreasesCount() {
        let service = DICOMwebService()
        service.addUPSWorkitem(UPSWorkitem(workitemUID: "1.2.3"))
        #expect(service.getUPSWorkitems().count == 1)
    }

    @Test("updateUPSWorkitemState updates state")
    func testUpdateUPSWorkitemStateUpdates() {
        let service = DICOMwebService()
        let item = UPSWorkitem(workitemUID: "1.2.3", state: .scheduled)
        service.addUPSWorkitem(item)
        service.updateUPSWorkitemState(.inProgress, for: item.id)
        #expect(service.getUPSWorkitems().first?.state == .inProgress)
    }

    @Test("addUPSSubscription increases subscription count")
    func testAddUPSSubscriptionIncreasesCount() {
        let service = DICOMwebService()
        service.addUPSSubscription(UPSEventSubscription())
        #expect(service.getUPSSubscriptions().count == 1)
    }

    @Test("removeUPSSubscription decreases count")
    func testRemoveUPSSubscriptionDecreasesCount() {
        let service = DICOMwebService()
        let sub = UPSEventSubscription()
        service.addUPSSubscription(sub)
        service.removeUPSSubscription(id: sub.id)
        #expect(service.getUPSSubscriptions().isEmpty)
    }

    @Test("deactivateUPSSubscription sets isActive to false")
    func testDeactivateUPSSubscriptionSetsInactive() {
        let service = DICOMwebService()
        let sub = UPSEventSubscription(isActive: true)
        service.addUPSSubscription(sub)
        service.deactivateUPSSubscription(id: sub.id)
        #expect(service.getUPSSubscriptions().first?.isActive == false)
    }

    // MARK: - Performance Stats

    @Test("updatePerformanceStats appends to history")
    func testUpdatePerformanceStatsAppendsHistory() {
        let service = DICOMwebService()
        let stats = DICOMwebPerformanceStats(averageLatencyMs: 42)
        service.updatePerformanceStats(stats)
        #expect(service.getPerformanceHistory().count == 1)
        #expect(service.getPerformanceStats().averageLatencyMs == 42)
    }

    @Test("resetPerformanceStats clears history")
    func testResetPerformanceStatsClearsHistory() {
        let service = DICOMwebService()
        service.updatePerformanceStats(DICOMwebPerformanceStats(averageLatencyMs: 10))
        service.resetPerformanceStats()
        #expect(service.getPerformanceHistory().isEmpty)
    }

    @Test("getPerformanceHistory returns at most 100 entries")
    func testGetPerformanceHistoryCappedAt100() {
        let service = DICOMwebService()
        for i in 0..<110 {
            service.updatePerformanceStats(DICOMwebPerformanceStats(averageLatencyMs: Double(i)))
        }
        #expect(service.getPerformanceHistory().count == 100)
    }
}
