// DICOMwebViewModelTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("DICOMweb ViewModel Tests")
@MainActor
struct DICOMwebViewModelTests {

    // MARK: - Navigation

    @Test("default activeTab is serverConfig")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDefaultActiveTab() {
        let vm = DICOMwebViewModel()
        #expect(vm.activeTab == .serverConfig)
    }

    // MARK: - Server Config

    @Test("addServerProfile increases serverProfiles count")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddServerProfileIncreasesCount() {
        let vm = DICOMwebViewModel()
        vm.addServerProfile(DICOMwebServerProfile(name: "PACS1"))
        #expect(vm.serverProfiles.count == 1)
    }

    @Test("removeServerProfile decreases count and clears selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveServerProfileDecreasesCountAndClearsSelection() {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "Test")
        vm.addServerProfile(profile)
        vm.selectedServerProfileID = profile.id
        vm.removeServerProfile(id: profile.id)
        #expect(vm.serverProfiles.isEmpty)
        #expect(vm.selectedServerProfileID == nil)
    }

    @Test("updateServerProfile updates name")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testUpdateServerProfileUpdatesName() {
        let vm = DICOMwebViewModel()
        var profile = DICOMwebServerProfile(name: "Old")
        vm.addServerProfile(profile)
        profile.name = "New"
        vm.updateServerProfile(profile)
        #expect(vm.serverProfiles.first?.name == "New")
    }

    @Test("selectedServerProfile returns correct profile")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedServerProfileReturnsCorrect() {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "Target")
        vm.addServerProfile(profile)
        vm.selectedServerProfileID = profile.id
        #expect(vm.selectedServerProfile?.name == "Target")
    }

    @Test("selectedServerProfile nil when no selection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectedServerProfileNilWhenNoSelection() {
        let vm = DICOMwebViewModel()
        #expect(vm.selectedServerProfile == nil)
    }

    @Test("validationErrors for profile with empty name returns errors")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testValidationErrorsForEmptyNameReturnsErrors() {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "", baseURL: "not-a-url")
        let errors = vm.validationErrors(for: profile)
        #expect(!errors.isEmpty)
    }

    @Test("validationErrors for valid profile returns empty array")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testValidationErrorsForValidProfileReturnsEmpty() {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "Valid", baseURL: "https://pacs.example.com")
        let errors = vm.validationErrors(for: profile)
        #expect(errors.isEmpty)
    }

    @Test("setDefaultProfile marks one default")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetDefaultProfileMarksOneDefault() {
        let vm = DICOMwebViewModel()
        let p1 = DICOMwebServerProfile(name: "P1")
        let p2 = DICOMwebServerProfile(name: "P2")
        vm.addServerProfile(p1)
        vm.addServerProfile(p2)
        vm.setDefaultProfile(id: p1.id)
        #expect(vm.serverProfiles.first(where: { $0.id == p1.id })?.isDefault == true)
        #expect(vm.serverProfiles.first(where: { $0.id == p2.id })?.isDefault == false)
    }

    @Test("testConnection for unconfigured profile sets offline")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testConnectionUnconfiguredSetsOffline() async {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "NoURL", baseURL: "")
        vm.addServerProfile(profile)
        await vm.testConnection(profileID: profile.id)
        #expect(vm.serverProfiles.first?.connectionStatus == .offline)
    }

    @Test("testConnection for unreachable profile sets error")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testConnectionUnreachableSetsError() async {
        let vm = DICOMwebViewModel()
        let profile = DICOMwebServerProfile(name: "WithURL", baseURL: "https://pacs.example.com")
        vm.addServerProfile(profile)
        await vm.testConnection(profileID: profile.id)
        #expect(vm.serverProfiles.first?.connectionStatus == .error)
    }

    // MARK: - QIDO-RS

    @Test("runQIDOQuery clears previous results")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRunQIDOQueryClearsPreviousResults() async {
        let vm = DICOMwebViewModel()
        // Seed the service directly to simulate pre-existing results
        let service = DICOMwebService()
        service.setQIDOResults([QIDOResultItem(studyInstanceUID: "1.2.3")])
        let vm2 = DICOMwebViewModel(service: service)
        await vm2.runQIDOQuery()
        #expect(vm2.qidoResults.isEmpty)
    }

    @Test("clearQIDOResults empties results")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearQIDOResultsEmptiesResults() {
        let service = DICOMwebService()
        service.setQIDOResults([QIDOResultItem()])
        let vm = DICOMwebViewModel(service: service)
        vm.clearQIDOResults()
        #expect(vm.qidoResults.isEmpty)
    }

    @Test("saveQueryTemplate saves and is retrievable")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSaveQueryTemplateSavesAndRetrievable() {
        let vm = DICOMwebViewModel()
        vm.qidoQueryParams = QIDOQueryParams(patientName: "TEST*")
        vm.saveQueryTemplate(name: "MyTemplate")
        #expect(vm.savedQueryTemplates["MyTemplate"]?.patientName == "TEST*")
    }

    @Test("loadQueryTemplate restores params")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLoadQueryTemplateRestoresParams() {
        let vm = DICOMwebViewModel()
        vm.qidoQueryParams = QIDOQueryParams(patientName: "STORED*")
        vm.saveQueryTemplate(name: "Saved")
        vm.qidoQueryParams = QIDOQueryParams()
        vm.loadQueryTemplate(name: "Saved")
        #expect(vm.qidoQueryParams.patientName == "STORED*")
    }

    @Test("removeQueryTemplate removes it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveQueryTemplateRemovesIt() {
        let vm = DICOMwebViewModel()
        vm.qidoQueryParams = QIDOQueryParams(patientName: "TO_REMOVE")
        vm.saveQueryTemplate(name: "ToRemove")
        vm.removeQueryTemplate(name: "ToRemove")
        #expect(vm.savedQueryTemplates["ToRemove"] == nil)
    }

    @Test("selectQIDOResult sets selectedQIDOResult")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSelectQIDOResultSetsSelectedResult() {
        let service = DICOMwebService()
        let item = QIDOResultItem(studyInstanceUID: "1.2.3")
        service.setQIDOResults([item])
        let vm = DICOMwebViewModel(service: service)
        vm.selectQIDOResult(item.id)
        #expect(vm.selectedQIDOResult?.studyInstanceUID == "1.2.3")
    }

    @Test("qidoQuerySummary returns non-empty string")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testQIDOQuerySummaryNonEmpty() {
        let vm = DICOMwebViewModel()
        #expect(!vm.qidoQuerySummary.isEmpty)
    }

    // MARK: - WADO-RS

    @Test("enqueueWADOJob with empty study UID sets errorMessage")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueWADOJobEmptyUIDSetsError() async {
        let vm = DICOMwebViewModel()
        vm.wadoNewJobStudyUID = ""
        await vm.enqueueWADOJob()
        #expect(vm.errorMessage != nil)
    }

    @Test("enqueueWADOJob with valid study UID adds job")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueWADOJobValidUIDAddsJob() async {
        let vm = DICOMwebViewModel()
        vm.wadoNewJobStudyUID = "1.2.840.10008.5.1.4.1.2.2.1"
        await vm.enqueueWADOJob()
        #expect(vm.wadoJobs.count == 1)
    }

    @Test("clearCompletedWADOJobs removes only terminal jobs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearCompletedWADOJobsRemovesOnlyTerminal() {
        let vm = DICOMwebViewModel()
        vm.addWADOJob(WADORetrieveJob(studyInstanceUID: "1", status: .inProgress))
        vm.addWADOJob(WADORetrieveJob(studyInstanceUID: "2", status: .completed))
        vm.clearCompletedWADOJobs()
        #expect(vm.wadoJobs.count == 1)
        #expect(vm.wadoJobs.first?.status == .inProgress)
    }

    @Test("activeWADOJobCount counts only in-progress jobs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testActiveWADOJobCountInProgressOnly() {
        let vm = DICOMwebViewModel()
        vm.addWADOJob(WADORetrieveJob(studyInstanceUID: "1", status: .inProgress))
        vm.addWADOJob(WADORetrieveJob(studyInstanceUID: "2", status: .queued))
        vm.addWADOJob(WADORetrieveJob(studyInstanceUID: "3", status: .completed))
        #expect(vm.activeWADOJobCount == 1)
    }

    // MARK: - STOW-RS

    @Test("enqueueSTOWUpload with no files sets errorMessage")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueSTOWUploadNoFilesSetsError() async {
        let vm = DICOMwebViewModel()
        vm.stowNewFilePaths = []
        await vm.enqueueSTOWUpload()
        #expect(vm.errorMessage != nil)
    }

    @Test("enqueueSTOWUpload with file paths adds job")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEnqueueSTOWUploadWithFilesAddsJob() async {
        let vm = DICOMwebViewModel()
        vm.stowNewFilePaths = ["/tmp/image1.dcm", "/tmp/image2.dcm"]
        await vm.enqueueSTOWUpload()
        #expect(vm.stowJobs.count == 1)
        #expect(vm.stowJobs.first?.totalFiles == 2)
    }

    @Test("clearCompletedSTOWJobs removes only terminal jobs")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearCompletedSTOWJobsRemovesOnlyTerminal() {
        let vm = DICOMwebViewModel()
        vm.addSTOWJob(STOWUploadJob(status: .uploading))
        vm.addSTOWJob(STOWUploadJob(status: .completed))
        vm.clearCompletedSTOWJobs()
        #expect(vm.stowJobs.count == 1)
        #expect(vm.stowJobs.first?.status == .uploading)
    }

    // MARK: - UPS-RS

    @Test("transitionUPSState valid transition updates state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTransitionUPSStateValidTransition() {
        let service = DICOMwebService()
        let item = UPSWorkitem(workitemUID: "1.2.3", state: .scheduled)
        service.addUPSWorkitem(item)
        let vm = DICOMwebViewModel(service: service)
        vm.transitionUPSState(.inProgress, workitemID: item.id)
        #expect(vm.upsWorkitems.first?.state == .inProgress)
    }

    @Test("transitionUPSState invalid transition sets errorMessage")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testTransitionUPSStateInvalidTransitionSetsError() {
        let service = DICOMwebService()
        let item = UPSWorkitem(workitemUID: "1.2.3", state: .completed)
        service.addUPSWorkitem(item)
        let vm = DICOMwebViewModel(service: service)
        vm.transitionUPSState(.cancelled, workitemID: item.id)
        #expect(vm.errorMessage != nil)
    }

    @Test("addUPSSubscription with empty workitem UID creates global subscription")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAddUPSSubscriptionEmptyUIDCreatesGlobal() {
        let vm = DICOMwebViewModel()
        vm.upsNewSubscriptionWorkitemUID = ""
        vm.addUPSSubscription()
        #expect(vm.upsSubscriptions.count == 1)
        #expect(vm.upsSubscriptions.first?.isGlobal == true)
    }

    @Test("removeUPSSubscription removes it")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testRemoveUPSSubscriptionRemovesIt() {
        let vm = DICOMwebViewModel()
        vm.addUPSSubscription()
        let subID = vm.upsSubscriptions.first!.id
        vm.removeUPSSubscription(id: subID)
        #expect(vm.upsSubscriptions.isEmpty)
    }

    // MARK: - Performance

    @Test("resetPerformanceStats clears stats and history")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testResetPerformanceStatsClearsAll() {
        let vm = DICOMwebViewModel()
        vm.recordPerformanceSample(DICOMwebPerformanceStats(averageLatencyMs: 100))
        vm.resetPerformanceStats()
        #expect(vm.performanceHistory.isEmpty)
        #expect(vm.performanceStats.averageLatencyMs == 0)
    }

    @Test("performanceHealthDescription returns non-empty string")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testPerformanceHealthDescriptionNonEmpty() {
        let vm = DICOMwebViewModel()
        #expect(!vm.performanceHealthDescription.isEmpty)
    }
}
