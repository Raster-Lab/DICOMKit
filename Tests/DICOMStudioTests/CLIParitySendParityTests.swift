// CLIParitySendParityTests.swift
// dicom-send network parity: the comparator must reduce the CLI's send output to
// the same outcome counts the SDK reference produces, and the scenario matrix must
// cover dry-run + the flag variants.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParitySendParityTests: XCTestCase {

    private typealias C = CLIParitySendComparator

    func testParsesSummaryCounts() {
        let cli = """
        ── stderr ──
        [1/1] Sending: syn-ct.dcm (1.2 KB)... ✓ (0.012s)
            SOP Instance UID: 1.2.3.4

        Transfer Summary
        ================
        Total files:     1
        Succeeded:       1
        Failed:          0
        """
        let s = C.parse(cli, dryRun: false)
        XCTAssertEqual(s.sent, 1)
        XCTAssertEqual(s.succeeded, 1)
        XCTAssertEqual(s.failed, 0)
        XCTAssertTrue(s.overallOK)
        XCTAssertFalse(s.dryRun)
    }

    func testParsesDryRun() {
        let cli = "Found 1 file(s) to send\nDry run complete. Use without --dry-run to send files.\n"
        let s = C.parse(cli, dryRun: true)
        XCTAssertTrue(s.dryRun)
        XCTAssertEqual(s.sent, 1)
        XCTAssertEqual(s.succeeded, 0)
    }

    func testMatchAndDrift() {
        let ref = SendSemantics(dryRun: false, sent: 1, succeeded: 1, failed: 0)
        let cliMatch = C.parse("Total files: 1\nSucceeded: 1\nFailed: 0\n", dryRun: false)
        XCTAssertTrue(C.compare(reference: ref, cli: cliMatch).match)

        let cliDrift = C.parse("Total files: 1\nSucceeded: 0\nFailed: 1\n", dryRun: false)
        XCTAssertFalse(C.compare(reference: ref, cli: cliDrift).match)
    }

    func testPartialSuccessIsDrift() {
        let ref = SendSemantics(dryRun: false, sent: 2, succeeded: 2, failed: 0)
        let cli = C.parse("Total files: 2\nSucceeded: 1\nFailed: 1\n", dryRun: false)
        XCTAssertFalse(C.compare(reference: ref, cli: cli).match)
    }

    func testScenarioMatrix() {
        let ids = CLIParityNetworkScenarios.sendScenarios().map { $0.scenarioId }
        XCTAssertTrue(ids.contains("dicom-send_net_dry-run"))
        XCTAssertTrue(ids.contains("dicom-send_net_default"))
        XCTAssertTrue(ids.contains("dicom-send_net_priority-high"))
        XCTAssertTrue(ids.contains("dicom-send_net_ts-evle"))
        XCTAssertTrue(ids.contains("dicom-send_net_verify"))

        let dry = CLIParityNetworkScenarios.sendScenarios().first { $0.scenarioId == "dicom-send_net_dry-run" }
        XCTAssertEqual(dry?.studioParams["dry-run"], "true")
        XCTAssertTrue(dry?.cliArgs.contains("--dry-run") ?? false)
        XCTAssertTrue(dry?.cliArgs.contains(CLIParityNetworkScenarios.sendFileToken) ?? false)
    }

    func testSupportedToolsIncludeSend() {
        XCTAssertTrue(CLIParityNetworkScenarios.supportedToolIDs.contains("dicom-send"))
    }

    // MARK: User-directory send (shared gatherer)

    /// The reference enumerates a directory through the SAME shared gatherer the CLI
    /// uses, so a picked directory yields exactly the files dicom-send would transmit:
    /// DICOM by extension (.dcm) OR by the "DICM" magic, direct-children vs recursive.
    func testGathererSelectsDICOMFilesFlatAndRecursive() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("clipar-send-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try Data("x".utf8).write(to: root.appendingPathComponent("a.dcm"))      // by extension
        try Data("x".utf8).write(to: root.appendingPathComponent("readme.txt")) // ignored
        var magic = Data(count: 132)                                            // by DICM magic, no ext
        magic.replaceSubrange(128..<132, with: Data([0x44, 0x49, 0x43, 0x4D]))
        try magic.write(to: root.appendingPathComponent("noext"))
        let sub = root.appendingPathComponent("series1")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: sub.appendingPathComponent("b.dcm"))       // nested

        let flat = CLIParityNetworkReference.gatherSendFiles(path: root.path, recursive: false)
        XCTAssertEqual(Set(flat.map { ($0 as NSString).lastPathComponent }), ["a.dcm", "noext"])

        let deep = CLIParityNetworkReference.gatherSendFiles(path: root.path, recursive: true)
        XCTAssertEqual(Set(deep.map { ($0 as NSString).lastPathComponent }), ["a.dcm", "noext", "b.dcm"])
    }

    func testGathererSingleFileAndEmptyPath() throws {
        let fm = FileManager.default
        let f = fm.temporaryDirectory.appendingPathComponent("one-\(UUID().uuidString).dcm")
        try Data("x".utf8).write(to: f)
        defer { try? fm.removeItem(at: f) }
        XCTAssertEqual(CLIParityNetworkReference.gatherSendFiles(path: f.path, recursive: true), [f.path])
        XCTAssertTrue(CLIParityNetworkReference.gatherSendFiles(path: "", recursive: true).isEmpty)
    }

    /// Every send scenario passes --recursive so a picked directory is scanned in full
    /// (and the reference gathers with the same flag). Harmless for the bundled file.
    func testSendScenariosPassRecursive() {
        for s in CLIParityNetworkScenarios.sendScenarios() {
            XCTAssertTrue(s.cliArgs.contains("--recursive"), "\(s.scenarioId) must pass --recursive")
        }
    }
}
