// SharedConsoleParityTests.swift
// Locks the console text that `dicom-split`, `dicom-merge` and `dicom-script`
// share with DICOMStudio's CLI Workshop.
//
// These three tools used to carry two copies of their banner/summary/verdict
// lines — one in the CLI, one in the Workshop executor — and the copies had
// drifted (missing version, relabelled fields, prose instead of the stats line,
// option enums printed as case names). The text now lives once in SplitConsole /
// MergeConsole / ScriptConsole; these tests pin the CLI-canonical wording so a
// future edit to either surface has to change it here, deliberately.
//
// Verified against source:
//   Sources/DICOMKit/Splitting/SplitConsole.swift  + Sources/dicom-split/DICOMSplit.swift
//   Sources/DICOMKit/Merging/MergeConsole.swift    + Sources/dicom-merge/DICOMMerge.swift
//   Sources/DICOMKit/Scripting/ScriptConsole.swift + Sources/dicom-script/main.swift

import XCTest
import Foundation
@testable import DICOMKit

final class SharedConsoleParityTests: XCTestCase {

    // MARK: - SplitConsole

    func testSplitHeaderCarriesVersionAndOptionalFields() {
        let minimal = SplitConsole.headerLines(
            input: "in.dcm", output: "out", format: .dicom, frames: nil,
            applyWindow: false, windowCenter: nil, windowWidth: nil)
        XCTAssertEqual(minimal, [
            "DICOM Split Tool v\(SplitConsole.toolVersion)",
            "========================",
            "Input: in.dcm",
            "Output: out",
            "Format: dicom",
            "",
        ])

        // Frames and window lines appear only when the user asked for them.
        let full = SplitConsole.headerLines(
            input: "in.dcm", output: "out", format: .png, frames: "1,3",
            applyWindow: true, windowCenter: 40, windowWidth: 400)
        XCTAssertEqual(full, [
            "DICOM Split Tool v\(SplitConsole.toolVersion)",
            "========================",
            "Input: in.dcm",
            "Output: out",
            "Format: png",
            "Frames: 1,3",
            "Window Center: 40.0",
            "Window Width: 400.0",
            "",
        ])
    }

    func testSplitCompletionAlwaysReportsCounts() {
        var result = SplitResult()
        result.processedFiles = 3
        result.extracted = 12
        result.skippedFiles = 1
        result.failed = 2
        XCTAssertEqual(SplitConsole.completionLines(result: result), [
            "",
            "Split complete! Processed: 3, extracted: 12, skipped: 1, failed: 2",
        ])

        // The all-zero run reports zeros rather than substituting prose.
        XCTAssertEqual(SplitConsole.completionLines(result: SplitResult()), [
            "",
            "Split complete! Processed: 0, extracted: 0, skipped: 0, failed: 0",
        ])
    }

    func testSplitFrameSelectionGrammar() throws {
        XCTAssertEqual(try SplitConsole.parseFrameSelection("1,3,5-7"), [1, 3, 5, 6, 7])
        // `split` omits empty components, so a trailing comma is accepted.
        XCTAssertEqual(try SplitConsole.parseFrameSelection("1,"), [1])
        // Whitespace-only components are not (the app's copy used to skip them).
        XCTAssertThrowsError(try SplitConsole.parseFrameSelection("1, ,2")) { error in
            XCTAssertEqual((error as? SplitConsole.FrameSelectionError)?.description,
                           "Invalid frame number: ")
        }
        XCTAssertThrowsError(try SplitConsole.parseFrameSelection("5-2")) { error in
            XCTAssertEqual((error as? SplitConsole.FrameSelectionError)?.description,
                           "Invalid frame range: 5-2")
        }
        XCTAssertThrowsError(try SplitConsole.parseFrameSelection("abc")) { error in
            XCTAssertEqual((error as? SplitConsole.FrameSelectionError)?.description,
                           "Invalid frame number: abc")
        }
    }

    // MARK: - MergeConsole

    func testMergeHeaderEchoesOptionsAsTyped() {
        // The options must render as the user typed them (`enhanced-ct`,
        // `ImagePositionPatient`) — the CLI used to interpolate the enum cases and
        // print `enhancedCt` / `imagePositionPatient`.
        XCTAssertEqual(
            MergeConsole.headerLines(
                inputCount: 2, output: "out.dcm", format: .enhancedCt,
                level: .series, sortBy: .imagePositionPatient, order: .descending),
            [
                "DICOM Merge Tool v\(MergeConsole.toolVersion)",
                "========================",
                "Inputs: 2 path(s)",
                "Output: out.dcm",
                "Format: enhanced-ct",
                "Level: series",
                "Sort: ImagePositionPatient (descending)",
                "",
            ])
    }

    func testMergeProgressAndCompletionLines() {
        XCTAssertEqual(MergeConsole.foundFilesLines(count: 7),
                       ["Found 7 DICOM files to process", ""])
        XCTAssertEqual(MergeConsole.completionLines(), ["", "Merge complete!"])
    }

    // MARK: - ScriptConsole

    func testScriptValidationVerdictBlock() {
        XCTAssertEqual(ScriptConsole.validationLines(issues: []), ["\u{2713} Script is valid"])
        XCTAssertEqual(ScriptConsole.validationLines(issues: ["bad tool", "bad tag"]), [
            "\u{2717} Script has 2 issue(s):",
            "  - bad tool",
            "  - bad tag",
        ])
    }

    func testScriptVariableParsingRejectsMissingEquals() throws {
        XCTAssertEqual(try ScriptConsole.parseVariables(["A=1", "B=x=y"]),
                       ["A": "1", "B": "x=y"])
        XCTAssertThrowsError(try ScriptConsole.parseVariables(["NOEQUALS"])) { error in
            XCTAssertEqual((error as? ScriptError)?.errorDescription,
                           "Invalid variable format: NOEQUALS. Use KEY=VALUE")
        }
    }

    func testScriptUnsupportedRunnerMessageIsSharedByBothSurfaces() {
        XCTAssertEqual(ScriptConsole.unsupportedRunnerMessage(tool: "dicom-anon"),
                       "Command execution is not supported on this platform: dicom-anon")
    }
}
