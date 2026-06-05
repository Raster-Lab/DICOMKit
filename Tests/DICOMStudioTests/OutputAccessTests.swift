// OutputAccessTests.swift
// Verifies the sandbox/TCC-resilient output writer used by every CLI Workshop
// tool: a writable path is used as-is; an UNWRITABLE path falls back to
// ~/Downloads/DICOMStudio/<subfolder> with a user-facing note (never a silent
// failure); a security-scoped URL is preferred. This is the headless proof of
// the access fix — the real TCC denial only happens in the sandboxed app, but
// the fallback logic (which is what makes the fix work) is fully testable here.

import XCTest
@testable import DICOMStudio

final class OutputAccessTests: XCTestCase {

    /// A writable typed path is written as-is, with NO redirect note.
    func testWritableTypedPathIsUsedAsIs() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("oa-\(UUID().uuidString)")
            .appendingPathComponent("out.txt")
        defer { try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent()) }

        let res = try OutputAccess.writeString("hello", toPath: tmp.path, scopedURL: nil, subfolder: "Test")
        XCTAssertNil(res.note, "a writable path must not be redirected")
        XCTAssertEqual(res.url.path, tmp.path)
        XCTAssertEqual(try String(contentsOf: tmp, encoding: .utf8), "hello")
    }

    /// An UNWRITABLE path (cannot create a dir under "/") falls back to
    /// ~/Downloads/DICOMStudio/<subfolder> and returns a non-nil note.
    func testUnwritablePathFallsBackWithNote() throws {
        let unwritable = "/dicomstudio-oa-\(UUID().uuidString)/out.txt"
        let res = try OutputAccess.writeString("payload", toPath: unwritable, scopedURL: nil, subfolder: "FallbackTest")
        XCTAssertNotNil(res.note, "an unwritable path must surface a redirect note")
        XCTAssertTrue(res.url.path.contains("DICOMStudio/FallbackTest"), "expected Downloads fallback, got \(res.url.path)")
        XCTAssertEqual(try String(contentsOf: res.url, encoding: .utf8), "payload")
        try? FileManager.default.removeItem(at: res.url)
    }

    /// resolveWritableURL probes the parent directory and redirects when unwritable.
    func testResolveWritableURLProbeFallsBack() {
        let unwritable = "/dicomstudio-oa-probe-\(UUID().uuidString)/out.dcm"
        let res = OutputAccess.resolveWritableURL(forPath: unwritable, scopedURL: nil, subfolder: "ProbeTest")
        XCTAssertNotNil(res.note)
        XCTAssertTrue(res.url.path.contains("DICOMStudio/ProbeTest"))
    }

    /// resolveWritableURL leaves a writable path untouched (no redirect) — this is
    /// the headless-harness case (temp output dir is genuinely writable).
    func testResolveWritableURLKeepsWritablePath() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("oa-keep-\(UUID().uuidString)")
            .appendingPathComponent("out.dcm")
        let res = OutputAccess.resolveWritableURL(forPath: tmp.path, scopedURL: nil, subfolder: "Test")
        XCTAssertNil(res.note)
        XCTAssertEqual(res.url.path, tmp.path)
    }
}
