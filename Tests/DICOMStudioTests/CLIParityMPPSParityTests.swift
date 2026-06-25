// CLIParityMPPSParityTests.swift
// dicom-mpps network parity: the comparator must reduce the CLI's N-CREATE /
// N-SET stderr to the same lifecycle-outcome record the SDK reference produces
// (ignoring the client-minted UID), and the scenario matrix must drive the full
// create → complete / discontinue lifecycle.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityMPPSParityTests: XCTestCase {

    private typealias C = CLIParityMPPSComparator

    // MARK: parse — create

    func testParsesCreateUIDAndSuccess() {
        let cli = """
        ── stderr ──
        ✓ MPPS instance created successfully
          MPPS Instance UID: 1.2.840.113619.2.55.3.1234

        Use this UID to update the MPPS when the procedure completes:
          dicom-mpps update host --port 11112 --aet AET --mpps-uid 1.2.840.113619.2.55.3.1234 --status COMPLETED
        """
        let r = C.parseCreate(cli, exitOK: true)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.uid, "1.2.840.113619.2.55.3.1234")
    }

    /// A nonzero exit means the create failed even if the text is partial; the UID
    /// may be absent.
    func testCreateFailureFromExitCode() {
        let r = C.parseCreate("Error: association rejected\n", exitOK: false)
        XCTAssertFalse(r.ok)
        XCTAssertNil(r.uid)
    }

    // MARK: parse — update

    func testParsesUpdateStatusAndRefImages() {
        let cli = """
        ── stderr ──
        ✓ MPPS instance updated successfully
          MPPS Instance UID: 1.2.840.113619.2.55.3.1234
          New Status: COMPLETED
          Referenced Images: 3
        """
        let r = C.parseUpdate(cli, exitOK: true)
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.status, "COMPLETED")
        XCTAssertEqual(r.refImages, 3)
    }

    /// No "Referenced Images:" line (none referenced) parses as 0, not nil.
    func testUpdateWithoutRefImagesIsZero() {
        let cli = """
        ✓ MPPS instance updated successfully
          New Status: DISCONTINUED
        """
        let r = C.parseUpdate(cli, exitOK: true)
        XCTAssertEqual(r.status, "DISCONTINUED")
        XCTAssertEqual(r.refImages, 0)
    }

    // MARK: canonical / compare — UID is NEVER compared

    func testMatchIgnoresClientMintedUID() {
        // Same outcome, regardless of the (uncompared) UID each side minted.
        let ref = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 2)
        let cli = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 2)
        XCTAssertTrue(C.compare(reference: ref, cli: cli).match)
        // The canonical rendering carries no UID line at all.
        XCTAssertFalse(C.canonical(ref).contains { $0.lowercased().contains("uid") })
    }

    func testFinalStatusMismatchIsDrift() {
        let ref = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 0)
        let cli = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "DISCONTINUED", referencedImages: 0)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testReferencedImageCountDriftIsDetected() {
        let ref = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 3)
        let cli = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 2)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testUpdateOutcomeMismatchIsDrift() {
        let ref = C.record(lifecycle: true, createOK: true, updateOK: true,
                           finalStatus: "COMPLETED", referencedImages: 0)
        let cli = C.record(lifecycle: true, createOK: true, updateOK: false,
                           finalStatus: "COMPLETED", referencedImages: 0)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    /// Create-only rows carry no update outcome (nil), rendered as "—" and matching.
    func testCreateOnlyHasNilUpdate() {
        let ref = C.record(lifecycle: false, createOK: true, updateOK: nil,
                           finalStatus: "IN PROGRESS", referencedImages: 0)
        XCTAssertNil(ref.updateOK)
        XCTAssertTrue(ref.success)
        XCTAssertTrue(C.canonical(ref).contains("updateOK: —"))
    }

    // MARK: success semantics

    func testCreateFailureSinksOverallSuccess() {
        let r = C.record(lifecycle: true, createOK: false, updateOK: false,
                         finalStatus: "COMPLETED", referencedImages: 0)
        XCTAssertFalse(r.success)
    }

    // MARK: scenario matrix

    func testLifecycleScenariosAlwaysGenerated() {
        let scs = CLIParityNetworkScenarios.mppsScenarios(scope: MPPSScope())
        let ids = scs.map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-mpps_net_create-in-progress"))
        XCTAssertTrue(ids.contains("dicom-mpps_net_lifecycle-completed"))
        XCTAssertTrue(ids.contains("dicom-mpps_net_lifecycle-discontinued"))
        // No referenced-image row without a Series UID + image UIDs.
        XCTAssertFalse(ids.contains("dicom-mpps_net_lifecycle-completed-images"))
    }

    func testReferencedImagesRowAppearsWithSeriesAndImages() {
        var scope = MPPSScope()
        scope.studyUID = "1.2.3"; scope.seriesUID = "1.2.3.4"; scope.imageUIDs = ["1.2.3.4.5", "1.2.3.4.6"]
        let scs = CLIParityNetworkScenarios.mppsScenarios(scope: scope)
        let img = scs.first { $0.scenarioId == "dicom-mpps_net_lifecycle-completed-images" }
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.studioParams["series-uid"], "1.2.3.4")
        XCTAssertEqual(img?.studioParams["image-uids"], "1.2.3.4.5,1.2.3.4.6")
    }

    /// Every scenario's CLI argv is the N-CREATE command (subcommand `create`, status
    /// starting IN PROGRESS); the lifecycle/final-status drive the runner's N-SET.
    func testCreateArgvAndLifecycleParams() {
        var scope = MPPSScope(); scope.studyUID = "1.2.3"
        let scs = CLIParityNetworkScenarios.mppsScenarios(scope: scope)
        for s in scs {
            XCTAssertEqual(s.cliArgs.first, "create", "\(s.scenarioId) must run the create subcommand")
            if let i = s.cliArgs.firstIndex(of: "--study-uid") { XCTAssertEqual(s.cliArgs[i + 1], "1.2.3") }
            else { XCTFail("\(s.scenarioId) must carry --study-uid") }
            if let i = s.cliArgs.firstIndex(of: "--status") { XCTAssertEqual(s.cliArgs[i + 1], "IN PROGRESS") }
            else { XCTFail("\(s.scenarioId) create must start IN PROGRESS") }
        }
        let completed = scs.first { $0.scenarioId == "dicom-mpps_net_lifecycle-completed" }
        XCTAssertEqual(completed?.studioParams["operation"], "lifecycle")
        XCTAssertEqual(completed?.studioParams["final-status"], "COMPLETED")
        let createOnly = scs.first { $0.scenarioId == "dicom-mpps_net_create-in-progress" }
        XCTAssertEqual(createOnly?.studioParams["operation"], "create")
    }

    func testSupportedToolsIncludeMPPS() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-mpps"))
    }

    // MARK: server pin — dicom-mpps may only run against DCM4CHEE5 MWL

    @MainActor
    func testMPPSIsPinnedToWorklistServer() {
        let vm = CLIParityRunnerViewModel()
        XCTAssertEqual(vm.requiredServer(for: "dicom-mpps"), "DCM4CHEE5 MWL")
        XCTAssertNil(vm.requiredServer(for: "dicom-echo"))
        XCTAssertNil(vm.requiredServer(for: "dicom-query"))
    }

    /// Selecting dicom-mpps locks the picker to its preset and applies that endpoint
    /// (host + Called AE), so it can never be pointed at the wrong PACS.
    @MainActor
    func testSelectingMPPSLocksAndAppliesWorklistPreset() {
        let vm = CLIParityRunnerViewModel()
        vm.setMode(.network)
        vm.clearToolSelection()
        XCTAssertNil(vm.lockedServerID)                 // nothing pins the server yet
        vm.toggleTool("dicom-mpps")
        XCTAssertEqual(vm.lockedServerID, "DCM4CHEE5 MWL")
        XCTAssertEqual(vm.selectedServerID, "DCM4CHEE5 MWL")
        XCTAssertEqual(vm.networkHost, "172.17.1.111")
        XCTAssertEqual(vm.networkCalledAET, "WORKLIST")
    }

    /// While dicom-mpps is selected, the server picker refuses any other preset.
    @MainActor
    func testServerPickerRefusesOtherPresetsWhileMPPSSelected() {
        let vm = CLIParityRunnerViewModel()
        vm.setMode(.network)
        vm.clearToolSelection()
        vm.toggleTool("dicom-mpps")
        vm.selectServer("DCM4CHEE2")                    // must be ignored — mpps is pinned
        XCTAssertEqual(vm.selectedServerID, "DCM4CHEE5 MWL")
        XCTAssertEqual(vm.networkCalledAET, "WORKLIST")
    }

    /// Deselecting dicom-mpps releases the lock; the picker is free again.
    @MainActor
    func testDeselectingMPPSUnlocksServer() {
        let vm = CLIParityRunnerViewModel()
        vm.setMode(.network)
        vm.clearToolSelection()
        vm.toggleTool("dicom-mpps")
        vm.toggleTool("dicom-mpps")                     // off again
        XCTAssertNil(vm.lockedServerID)
        vm.selectServer("DCM4CHEE2")                    // now allowed
        XCTAssertEqual(vm.selectedServerID, "DCM4CHEE2")
    }
}
