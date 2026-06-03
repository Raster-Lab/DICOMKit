// CLIParityEngineTests.swift
// Validates the Swift-native CLI parity engine + in-app output verification
// against the bundled CLI-parity data.

import XCTest
@testable import DICOMStudio

@available(macOS 14.0, *)
final class CLIParityEngineTests: XCTestCase {

    func testBundledContractsLoad() throws {
        let contracts = try XCTUnwrap(CLIParityEngine.loadContracts(),
                                      "CLIContracts.json should be bundled (run: swift run cli-parity-gen)")
        XCTAssertGreaterThan(contracts.tools.count, 20, "Expected many CLI contracts")
        XCTAssertNotNil(contracts.tools["dicom-info"])
    }

    func testFixtureAndGoldensBundled() throws {
        let goldens = CLIParityEngine.loadGoldens()
        XCTAssertFalse(goldens.isEmpty, "goldens.json should contain scenarios")
        XCTAssertTrue(goldens.contains { $0.toolId == "dicom-info" })
        // The fixture referenced by the goldens must actually be bundled. Derive
        // the name from the goldens rather than hardcoding it, so the test stays
        // correct as fixtures are renamed/added.
        let fixtureName = try XCTUnwrap(goldens.first?.fixtureFile, "golden scenario should name a fixture file")
        XCTAssertNotNil(CLIParityEngine.fixtureURL(named: fixtureName), "\(fixtureName) should be bundled")
    }

    func testCompareAllCoversCatalogAndHasNoFalseDrift() throws {
        let contracts = try XCTUnwrap(CLIParityEngine.loadContracts())
        let results = CLIParityEngine.compareAll(contracts: contracts)
        XCTAssertGreaterThan(results.count, 20)

        // dicom-info is a known-good exact-parity tool (its short aliases -f/-t
        // are covered by the long forms via option-group matching).
        let info = try XCTUnwrap(results.first { $0.toolId == "dicom-info" })
        XCTAssertEqual(info.status, .ok, "dicom-info should be exact parity")
        XCTAssertEqual(info.extraCount, 0)
        XCTAssertEqual(info.missingCount, 0)

        // No tool with bundled contract data should show EXTRA flags the CLI
        // rejects (that would be a real drift / false positive in the engine).
        for r in results where r.status != .noCliData {
            // network host/port folding etc. must not produce phantom drift on dicom-echo
            if r.toolId == "dicom-echo" {
                XCTAssertEqual(r.extraCount, 0, "dicom-echo should not show --host/--port drift")
            }
        }
    }

    @MainActor
    func testOutputVerificationForDicomInfoRunsInProcess() async throws {
        let vm = CLIAutomationTestingViewModel()
        vm.runParityAnalysis()
        XCTAssertTrue(vm.contractsAvailable)
        XCTAssertFalse(vm.results.isEmpty)

        await vm.runOutputVerification(for: "dicom-info")
        XCTAssertFalse(vm.outputComparisons.isEmpty, "dicom-info should have golden scenarios")

        // Every scenario should have produced Studio output and a verdict.
        for c in vm.outputComparisons {
            XCTAssertTrue(c.status == .match || c.status == .differs,
                          "scenario \(c.scenarioId) should run in-process, got \(c.status)")
            XCTAssertFalse(c.studioOutput.isEmpty, "Studio output captured for \(c.scenarioId)")
            // Print for visibility into real parity.
            print("OUTPUT-PARITY \(c.scenarioId): \(c.status.displayName) — \(c.note)")
        }
    }

    func testNormalizeStripsCommandEchoAndFixturePath() {
        let raw = "$ dicom-info /tmp/abc/fixture.dcm\n\n✅ (0008,0060) Modality CT\n"
        let lines = CLIParityEngine.normalize(raw, fixtureBasename: "fixture.dcm")
        XCTAssertFalse(lines.contains { $0.hasPrefix("$ ") }, "command echo stripped")
        XCTAssertTrue(lines.contains { $0.contains("Modality CT") })
        XCTAssertFalse(lines.contains { $0.contains("/tmp/abc/") }, "absolute path canonicalized")
    }

    func testDiffDetectsDifferences() {
        let same = CLIParityEngine.diff(cli: ["a", "b"], studio: ["a", "b"])
        XCTAssertFalse(same.contains { $0.kind != .same })

        let differ = CLIParityEngine.diff(cli: ["a", "b", "c"], studio: ["a", "x", "c"])
        XCTAssertTrue(differ.contains { $0.kind == .cliOnly && $0.text == "b" })
        XCTAssertTrue(differ.contains { $0.kind == .studioOnly && $0.text == "x" })
    }
}
