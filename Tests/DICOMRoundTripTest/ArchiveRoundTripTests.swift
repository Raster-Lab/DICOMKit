// ArchiveRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-archive` tool.
//
// These tests call the DICOMKit library (`ArchiveStore`) directly — never the
// CLI. Every assertion is a semantic invariant of the archive engine
// (fileCount == total instances, dedup by SOP UID, wildcard/modality filtering,
// export → re-import pixel-exact, integrity detection, stats aggregation).
//
// Shared synthetic builders / I/O helpers live in RoundTripFixture.swift and are
// reused here (not redefined).

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class ArchiveRoundTripTests: XCTestCase {

    // MARK: - Private helpers (class-scoped so they never collide across files)

    /// Parse a JSON string (as returned by ArchiveStore's json formats) into an object.
    private func parseJSONObject(_ s: String) throws -> [String: Any] {
        let data = Data(s.utf8)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Parse a JSON string into a top-level array of objects.
    private func parseJSONArray(_ s: String) throws -> [[String: Any]] {
        let data = Data(s.utf8)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }

    /// Write a DICOMFile to a fresh temp directory and return its path (as a String).
    private func stageFile(_ file: DICOMFile, name: String) throws -> String {
        try writeTempDICOM(file, name: name).path
    }

    /// Build a synthetic grayscale-8 file with explicit patient/study/series/modality
    /// identity so tests can assert on filtering. Returns the file plus the SOP UID.
    private func makeFile(
        patientName: String,
        patientID: String,
        studyUID: String,
        seriesUID: String,
        modality: String,
        fill: UInt8 = 7
    ) -> (file: DICOMFile, sop: String) {
        var ds = DataSet()
        let sop = rtUID()
        ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
        ds.setString(sop, for: .sopInstanceUID, vr: .UI)
        ds.setString(studyUID, for: .studyInstanceUID, vr: .UI)
        ds.setString(seriesUID, for: .seriesInstanceUID, vr: .UI)
        ds.setString(modality, for: .modality, vr: .CS)
        ds.setString(patientName, for: .patientName, vr: .PN)
        ds.setString(patientID, for: .patientID, vr: .LO)
        ds.setUInt16(4, for: .rows)
        ds.setUInt16(4, for: .columns)
        ds.setUInt16(8, for: .bitsAllocated)
        ds.setUInt16(8, for: .bitsStored)
        ds.setUInt16(7, for: .highBit)
        ds.setUInt16(0, for: .pixelRepresentation)
        ds.setUInt16(1, for: .samplesPerPixel)
        ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        let pixels = Data(repeating: fill, count: 16)
        ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
        let file = DICOMFile.create(dataSet: ds, sopClassUID: "1.2.840.10008.5.1.4.1.1.2")
        return (file, sop)
    }

    /// Initialize a fresh archive in a fresh temp dir; returns its path.
    ///
    /// The archive base is created with `mkdtemp` under the system temp dir and its
    /// path is captured as the CANONICAL (fully symlink-resolved) form. This matters
    /// only for `check`'s orphan-detection: it strips `data/`'s raw path prefix from
    /// the paths yielded by FileManager's directory enumerator, and on macOS those
    /// enumerator paths are `/private`-prefixed. If the archive path we pass in were
    /// not the same canonical form, every stored file would be mis-reported as an
    /// orphan for reasons unrelated to the archive logic under test.
    private func freshArchive() throws -> String {
        let base = try makeCanonicalTempDir()
        let dir = base.appendingPathComponent("archive").path
        _ = try ArchiveStore.initArchive(at: dir, force: false)
        return dir
    }

    /// A fresh temp directory whose path is the canonical (`/private`-resolved) form,
    /// matching what FileManager's enumerator yields — see `freshArchive`.
    private func makeCanonicalTempDir() throws -> URL {
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMRoundTrip-Archive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        // FileManager's directory enumerator yields `/private`-prefixed paths for the
        // system temp dir (which lives under the `/var` -> `/private/var` symlink),
        // while URL/NSString symlink-resolution strips `/private`. Prepend it here so
        // our archive path matches the enumerator form used by `check`.
        let fm = FileManager.default
        let privatePath = "/private" + raw.path
        if fm.fileExists(atPath: privatePath) {
            return URL(fileURLWithPath: privatePath, isDirectory: true)
        }
        return raw
    }

    // MARK: - init

    // Oracle: init creates the index file + data/ dir, no throw, empty index (fileCount == 0).
    func testInitCreatesEmptyIndex() throws {
        let dir = try makeTempDir().appendingPathComponent("arch").path
        _ = try ArchiveStore.initArchive(at: dir, force: false)

        let idxURL = ArchiveStore.indexURL(for: dir)
        let dataURL = ArchiveStore.dataDirectory(for: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: idxURL.path))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dataURL.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)

        let index = try ArchiveStore.loadIndex(from: dir)
        XCTAssertEqual(index.fileCount, 0)
        XCTAssertTrue(index.patients.isEmpty)
    }

    // Oracle: init on an existing archive without --force throws archiveExists.
    func testInitTwiceWithoutForceThrows() throws {
        let dir = try freshArchive()
        XCTAssertThrowsError(try ArchiveStore.initArchive(at: dir, force: false)) { error in
            guard case ArchiveError.archiveExists = error else {
                return XCTFail("expected archiveExists, got \(error)")
            }
        }
        // With force it succeeds (no throw).
        XCTAssertNoThrow(try ArchiveStore.initArchive(at: dir, force: true))
    }

    // MARK: - import

    // Oracle: importing 3 files with distinct SOP UIDs → fileCount == 3, all UIDs indexed.
    func testImportThreeDistinctFiles() throws {
        let dir = try freshArchive()
        var sops: Set<String> = []
        var paths: [String] = []
        for i in 0..<3 {
            let (f, sop) = makeFile(
                patientName: "P^\(i)", patientID: "PID\(i)",
                studyUID: "1.2.\(i).100", seriesUID: "1.2.\(i).200", modality: "CT")
            sops.insert(sop)
            paths.append(try stageFile(f, name: "in\(i).dcm"))
        }
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dir)
        XCTAssertEqual(index.fileCount, 3)

        // fileCount must equal the total instance count across the tree (invariant).
        var total = 0
        var indexed: Set<String> = []
        for p in index.patients {
            for st in p.studies {
                for se in st.series {
                    for inst in se.instances {
                        total += 1
                        indexed.insert(inst.sopInstanceUID)
                    }
                }
            }
        }
        XCTAssertEqual(total, 3)
        XCTAssertEqual(indexed, sops)
    }

    // Oracle: importing the SAME file twice → deduped by SOP UID → exactly 1 instance.
    func testImportDeduplicatesBySOPUID() throws {
        let dir = try freshArchive()
        let (f, sop) = makeFile(
            patientName: "Dup^One", patientID: "DUP1",
            studyUID: "1.2.9.1", seriesUID: "1.2.9.2", modality: "CT")
        let path = try stageFile(f, name: "dup.dcm")

        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)
        // Second import of the same SOP UID: engine dedups (does not throw, count stays 1).
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dir)
        XCTAssertEqual(index.fileCount, 1)
        let uids = index.patients.flatMap { $0.studies }.flatMap { $0.series }
            .flatMap { $0.instances }.map { $0.sopInstanceUID }
        XCTAssertEqual(uids, [sop])
    }

    // Oracle: --skip-duplicates re-import succeeds silently and leaves count unchanged.
    func testImportSkipDuplicatesFlag() throws {
        let dir = try freshArchive()
        let (f, _) = makeFile(
            patientName: "Skip^One", patientID: "SKIP1",
            studyUID: "1.2.10.1", seriesUID: "1.2.10.2", modality: "MR")
        let path = try stageFile(f, name: "skip.dcm")

        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)
        XCTAssertNoThrow(try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: true, verbose: false))

        let index = try ArchiveStore.loadIndex(from: dir)
        XCTAssertEqual(index.fileCount, 1)
    }

    // Oracle: each ArchiveInstance.filePath is a RELATIVE path (no leading slash),
    // formatted PatientID/StudyUID/SeriesUID/SOP.dcm.
    func testImportedFilePathIsRelative() throws {
        let dir = try freshArchive()
        let (f, _) = makeFile(
            patientName: "Rel^One", patientID: "RELPID",
            studyUID: "1.2.11.1", seriesUID: "1.2.11.2", modality: "CT")
        let path = try stageFile(f, name: "rel.dcm")
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dir)
        let inst = try XCTUnwrap(index.patients.first?.studies.first?.series.first?.instances.first)
        XCTAssertFalse(inst.filePath.hasPrefix("/"))
        let comps = inst.filePath.split(separator: "/")
        XCTAssertEqual(comps.count, 4)
        XCTAssertEqual(comps.first.map(String.init), "RELPID")
        XCTAssertTrue(inst.filePath.hasSuffix(".dcm"))
        // The stored file must actually exist at that relative path under data/.
        let stored = ArchiveStore.dataDirectory(for: dir).appendingPathComponent(inst.filePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
    }

    // MARK: - query

    // Oracle: query by PatientName wildcard "JONES*" matches exactly the 2 JONES studies.
    func testQueryPatientNameWildcard() throws {
        let dir = try freshArchive()
        let files = [
            makeFile(patientName: "JONES^ALICE", patientID: "J1",
                     studyUID: "1.2.20.1", seriesUID: "1.2.20.11", modality: "CT"),
            makeFile(patientName: "JONES^BOB", patientID: "J2",
                     studyUID: "1.2.20.2", seriesUID: "1.2.20.21", modality: "CT"),
            makeFile(patientName: "SMITH^CAROL", patientID: "S1",
                     studyUID: "1.2.20.3", seriesUID: "1.2.20.31", modality: "CT"),
        ]
        var paths: [String] = []
        for (i, entry) in files.enumerated() {
            paths.append(try stageFile(entry.file, name: "q\(i).dcm"))
        }
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.query(
            in: dir, patientName: "JONES*", patientID: nil, studyUID: nil,
            modality: nil, studyDate: nil, format: "json")
        let results = try parseJSONArray(json)
        XCTAssertEqual(results.count, 2)
        let names = Set(results.compactMap { $0["patientName"] as? String })
        XCTAssertEqual(names, ["JONES^ALICE", "JONES^BOB"])
        XCTAssertFalse(names.contains("SMITH^CAROL"))
    }

    // Oracle: query by modality "CT" returns only CT studies (MR excluded).
    func testQueryByModality() throws {
        let dir = try freshArchive()
        let ct = makeFile(patientName: "Mod^CT", patientID: "MCT",
                          studyUID: "1.2.21.1", seriesUID: "1.2.21.11", modality: "CT")
        let mr = makeFile(patientName: "Mod^MR", patientID: "MMR",
                          studyUID: "1.2.21.2", seriesUID: "1.2.21.21", modality: "MR")
        let paths = [try stageFile(ct.file, name: "ct.dcm"),
                     try stageFile(mr.file, name: "mr.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.query(
            in: dir, patientName: nil, patientID: nil, studyUID: nil,
            modality: "CT", studyDate: nil, format: "json")
        let results = try parseJSONArray(json)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?["modality"] as? String, "CT")
    }

    // Oracle: invalid format string throws invalidFormat.
    func testQueryInvalidFormatThrows() throws {
        let dir = try freshArchive()
        XCTAssertThrowsError(try ArchiveStore.query(
            in: dir, patientName: nil, patientID: nil, studyUID: nil,
            modality: nil, studyDate: nil, format: "xml")) { error in
            guard case ArchiveError.invalidFormat = error else {
                return XCTFail("expected invalidFormat, got \(error)")
            }
        }
    }

    // MARK: - export

    // Oracle: export by StudyUID copies exactly the instances of that study; with
    // --flatten they land directly in the output dir as SOP.dcm files.
    func testExportByStudyUIDFlatten() throws {
        let dir = try freshArchive()
        // Study A: 2 instances (same patient/study/series). Study B: 1 instance.
        let a1 = makeFile(patientName: "Exp^One", patientID: "E1",
                          studyUID: "1.2.30.A", seriesUID: "1.2.30.A1", modality: "CT")
        let a2 = makeFile(patientName: "Exp^One", patientID: "E1",
                          studyUID: "1.2.30.A", seriesUID: "1.2.30.A1", modality: "CT")
        let b1 = makeFile(patientName: "Exp^Two", patientID: "E2",
                          studyUID: "1.2.30.B", seriesUID: "1.2.30.B1", modality: "CT")
        let paths = [try stageFile(a1.file, name: "a1.dcm"),
                     try stageFile(a2.file, name: "a2.dcm"),
                     try stageFile(b1.file, name: "b1.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let outDir = try makeTempDir().appendingPathComponent("export")
        _ = try ArchiveStore.export(
            from: dir, output: outDir.path, studyUID: "1.2.30.A", seriesUID: nil,
            patientID: nil, flatten: true, verbose: false)

        // Exactly 2 .dcm files directly in the output dir (flatten = no subdirs).
        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), 2)

        // Both exported files must carry StudyInstanceUID == A.
        let exported = try FileManager.default.contentsOfDirectory(
            at: outDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "dcm" }
        for url in exported {
            let f = try DICOMFile.read(from: url, force: true)
            XCTAssertEqual(f.dataSet.string(for: .studyInstanceUID), "1.2.30.A")
        }
    }

    // Oracle: export with NO filter throws noExportFilter.
    func testExportNoFilterThrows() throws {
        let dir = try freshArchive()
        let outDir = try makeTempDir().appendingPathComponent("export2")
        XCTAssertThrowsError(try ArchiveStore.export(
            from: dir, output: outDir.path, studyUID: nil, seriesUID: nil,
            patientID: nil, flatten: false, verbose: false)) { error in
            guard case ArchiveError.noExportFilter = error else {
                return XCTFail("expected noExportFilter, got \(error)")
            }
        }
    }

    // Oracle: export → re-import round-trip is pixel-exact (stored bytes are copied
    // verbatim, so the re-imported native pixel data equals the original).
    func testExportReimportPixelExact() throws {
        let srcDir = try freshArchive()
        let original = makeGrayscale8(rows: 8, cols: 8) { UInt8(($0 * 3) % 256) }
        let originalPixels = pixelBytes(original)
        let sop = try XCTUnwrap(original.dataSet.string(for: .sopInstanceUID))
        let studyUID = try XCTUnwrap(original.dataSet.string(for: .studyInstanceUID))
        let inPath = try stageFile(original, name: "orig.dcm")

        _ = try ArchiveStore.importFiles(
            into: srcDir, files: [inPath], recursive: false, skipDuplicates: false, verbose: false)

        let outDir = try makeTempDir().appendingPathComponent("rt-export")
        _ = try ArchiveStore.export(
            from: srcDir, output: outDir.path, studyUID: studyUID, seriesUID: nil,
            patientID: nil, flatten: true, verbose: false)

        // Re-import the exported file into a fresh archive.
        let dstDir = try freshArchive()
        let exportedURL = try FileManager.default.contentsOfDirectory(
            at: outDir, includingPropertiesForKeys: nil)
            .first { $0.pathExtension == "dcm" }
        let reimportPath = try XCTUnwrap(exportedURL).path
        _ = try ArchiveStore.importFiles(
            into: dstDir, files: [reimportPath], recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dstDir)
        let inst = try XCTUnwrap(index.patients.first?.studies.first?.series.first?.instances.first)
        XCTAssertEqual(inst.sopInstanceUID, sop)
        let storedURL = ArchiveStore.dataDirectory(for: dstDir).appendingPathComponent(inst.filePath)
        let reimported = try DICOMFile.read(from: storedURL, force: true)
        XCTAssertEqual(pixelBytes(reimported), originalPixels)
    }

    // MARK: - check

    // Oracle: a freshly-imported, untouched archive passes integrity check
    // (no missing / size-mismatch / unreadable / orphaned files).
    func testCheckValidArchiveNoIssues() throws {
        let dir = try freshArchive()
        let (f, _) = makeFile(patientName: "Chk^Ok", patientID: "COK",
                              studyUID: "1.2.40.1", seriesUID: "1.2.40.11", modality: "CT")
        let path = try stageFile(f, name: "chk.dcm")
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let report = try ArchiveStore.check(in: dir, verifyFiles: true, verbose: false)
        XCTAssertTrue(report.contains("Archive integrity OK"))
        XCTAssertFalse(report.contains("integrity issues"))
    }

    // Oracle: overwriting a stored .dcm with garbage is flagged by check --verify-files
    // as an unreadable DICOM file.
    func testCheckDetectsCorruptFile() throws {
        let dir = try freshArchive()
        let (f, _) = makeFile(patientName: "Chk^Bad", patientID: "CBAD",
                              studyUID: "1.2.41.1", seriesUID: "1.2.41.11", modality: "CT")
        let path = try stageFile(f, name: "bad.dcm")
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dir)
        let inst = try XCTUnwrap(index.patients.first?.studies.first?.series.first?.instances.first)
        let stored = ArchiveStore.dataDirectory(for: dir).appendingPathComponent(inst.filePath)
        // Corrupt the stored file: overwrite with garbage but keep the SAME byte length
        // so this specifically exercises the readability check (not the size check).
        let originalSize = try FileManager.default
            .attributesOfItem(atPath: stored.path)[.size] as? Int
        let garbage = Data(repeating: 0x00, count: originalSize ?? 64)
        try garbage.write(to: stored)

        let report = try ArchiveStore.check(in: dir, verifyFiles: true, verbose: true)
        XCTAssertTrue(report.contains("Unreadable"))
        XCTAssertTrue(report.contains("integrity issues"))
    }

    // Oracle: deleting a stored file is flagged as a missing file by check.
    func testCheckDetectsMissingFile() throws {
        let dir = try freshArchive()
        let (f, _) = makeFile(patientName: "Chk^Miss", patientID: "CMISS",
                              studyUID: "1.2.42.1", seriesUID: "1.2.42.11", modality: "CT")
        let path = try stageFile(f, name: "miss.dcm")
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let index = try ArchiveStore.loadIndex(from: dir)
        let inst = try XCTUnwrap(index.patients.first?.studies.first?.series.first?.instances.first)
        let stored = ArchiveStore.dataDirectory(for: dir).appendingPathComponent(inst.filePath)
        try FileManager.default.removeItem(at: stored)

        let report = try ArchiveStore.check(in: dir, verifyFiles: false, verbose: true)
        XCTAssertTrue(report.contains("Missing"))
        XCTAssertTrue(report.contains("integrity issues"))
    }

    // MARK: - stats

    // Oracle: stats counts match imports — 3 instances across 2 patients.
    func testStatsCountsMatchImports() throws {
        let dir = try freshArchive()
        // Patient 1: 2 instances (2 studies). Patient 2: 1 instance.
        let p1a = makeFile(patientName: "Stat^One", patientID: "SP1",
                           studyUID: "1.2.50.1", seriesUID: "1.2.50.11", modality: "CT")
        let p1b = makeFile(patientName: "Stat^One", patientID: "SP1",
                           studyUID: "1.2.50.2", seriesUID: "1.2.50.21", modality: "CT")
        let p2 = makeFile(patientName: "Stat^Two", patientID: "SP2",
                          studyUID: "1.2.50.3", seriesUID: "1.2.50.31", modality: "MR")
        let paths = [try stageFile(p1a.file, name: "s1.dcm"),
                     try stageFile(p1b.file, name: "s2.dcm"),
                     try stageFile(p2.file, name: "s3.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.stats(in: dir, format: "json")
        let obj = try parseJSONObject(json)
        XCTAssertEqual(obj["instances"] as? Int, 3)
        XCTAssertEqual(obj["patients"] as? Int, 2)
        XCTAssertEqual(obj["studies"] as? Int, 3)

        // Modalities dict must sum to the instance count.
        let mods = try XCTUnwrap(obj["modalities"] as? [String: Int])
        XCTAssertEqual(mods.values.reduce(0, +), 3)
        XCTAssertEqual(mods["CT"], 2)
        XCTAssertEqual(mods["MR"], 1)
    }

    // MARK: - list

    // Oracle: list json returns the full index tree; instance count equals fileCount.
    func testListReflectsImportedCount() throws {
        let dir = try freshArchive()
        var paths: [String] = []
        for i in 0..<3 {
            let (f, _) = makeFile(patientName: "List^\(i)", patientID: "LP\(i)",
                                  studyUID: "1.2.60.\(i)", seriesUID: "1.2.60.\(i)1", modality: "CT")
            paths.append(try stageFile(f, name: "l\(i).dcm"))
        }
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.list(in: dir, format: "json", showInstances: true)
        let obj = try parseJSONObject(json)
        XCTAssertEqual(obj["fileCount"] as? Int, 3)
        let patients = try XCTUnwrap(obj["patients"] as? [[String: Any]])
        XCTAssertEqual(patients.count, 3)
    }

    // MARK: - query (additional filters)

    /// Return a copy of `file` with a StudyDate set on its dataSet.
    private func withStudyDate(_ file: DICOMFile, _ date: String) -> DICOMFile {
        var ds = file.dataSet
        ds.setString(date, for: .studyDate, vr: .DA)
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
    }

    // Oracle: query by patientID returns only the matching patient's study.
    func testQueryByPatientIDFilters() throws {
        let dir = try freshArchive()
        let a = makeFile(patientName: "PID^A", patientID: "AAA111",
                         studyUID: "1.2.70.1", seriesUID: "1.2.70.11", modality: "CT")
        let b = makeFile(patientName: "PID^B", patientID: "BBB222",
                         studyUID: "1.2.70.2", seriesUID: "1.2.70.21", modality: "CT")
        let paths = [try stageFile(a.file, name: "pa.dcm"), try stageFile(b.file, name: "pb.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.query(
            in: dir, patientName: nil, patientID: "AAA111", studyUID: nil,
            modality: nil, studyDate: nil, format: "json")
        let results = try parseJSONArray(json)
        XCTAssertEqual(results.count, 1, "patientID filter must return exactly the matching patient")
        XCTAssertEqual(results.first?["patientName"] as? String, "PID^A")
    }

    // Oracle: query by studyUID returns only that study.
    func testQueryByStudyUIDFilters() throws {
        let dir = try freshArchive()
        let a = makeFile(patientName: "SU^A", patientID: "SUA",
                         studyUID: "1.2.71.100", seriesUID: "1.2.71.11", modality: "CT")
        let b = makeFile(patientName: "SU^B", patientID: "SUB",
                         studyUID: "1.2.71.200", seriesUID: "1.2.71.21", modality: "CT")
        let paths = [try stageFile(a.file, name: "sa.dcm"), try stageFile(b.file, name: "sb.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.query(
            in: dir, patientName: nil, patientID: nil, studyUID: "1.2.71.100",
            modality: nil, studyDate: nil, format: "json")
        let results = try parseJSONArray(json)
        XCTAssertEqual(results.count, 1, "studyUID filter must return exactly the matching study")
        XCTAssertEqual(results.first?["patientName"] as? String, "SU^A")
    }

    // Oracle: query by studyDate returns only studies acquired on that date.
    func testQueryByStudyDateFilters() throws {
        let dir = try freshArchive()
        let a = withStudyDate(makeFile(patientName: "SD^A", patientID: "SDA",
                              studyUID: "1.2.72.1", seriesUID: "1.2.72.11", modality: "CT").file, "20240101")
        let b = withStudyDate(makeFile(patientName: "SD^B", patientID: "SDB",
                              studyUID: "1.2.72.2", seriesUID: "1.2.72.21", modality: "CT").file, "20240202")
        let paths = [try stageFile(a, name: "da.dcm"), try stageFile(b, name: "db.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let json = try ArchiveStore.query(
            in: dir, patientName: nil, patientID: nil, studyUID: nil,
            modality: nil, studyDate: "20240101", format: "json")
        let results = try parseJSONArray(json)
        XCTAssertEqual(results.count, 1, "studyDate filter must return only the matching-date study")
        XCTAssertEqual(results.first?["patientName"] as? String, "SD^A")
    }

    // MARK: - export (additional filters)

    // Oracle: export by seriesUID copies exactly that series's instances (not the whole study).
    func testExportBySeriesUIDFilters() throws {
        let dir = try freshArchive()
        // One study, two series: S1 (2 instances), S2 (1 instance).
        let s1a = makeFile(patientName: "Ser^X", patientID: "SX",
                           studyUID: "1.2.73.1", seriesUID: "1.2.73.S1", modality: "CT")
        let s1b = makeFile(patientName: "Ser^X", patientID: "SX",
                           studyUID: "1.2.73.1", seriesUID: "1.2.73.S1", modality: "CT")
        let s2 = makeFile(patientName: "Ser^X", patientID: "SX",
                          studyUID: "1.2.73.1", seriesUID: "1.2.73.S2", modality: "CT")
        let paths = [try stageFile(s1a.file, name: "s1a.dcm"),
                     try stageFile(s1b.file, name: "s1b.dcm"),
                     try stageFile(s2.file, name: "s2.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let outDir = try makeTempDir().appendingPathComponent("exp-series")
        _ = try ArchiveStore.export(
            from: dir, output: outDir.path, studyUID: nil, seriesUID: "1.2.73.S1",
            patientID: nil, flatten: true, verbose: false)

        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), 2, "only series S1's 2 instances export")
        let exported = try FileManager.default.contentsOfDirectory(
            at: outDir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "dcm" }
        for url in exported {
            XCTAssertEqual(try DICOMFile.read(from: url, force: true).dataSet.string(for: .seriesInstanceUID),
                           "1.2.73.S1")
        }
    }

    // Oracle: export by patientID copies exactly that patient's instances.
    func testExportByPatientIDFilters() throws {
        let dir = try freshArchive()
        let p1 = makeFile(patientName: "Exp^P1", patientID: "EP1",
                          studyUID: "1.2.74.1", seriesUID: "1.2.74.11", modality: "CT")
        let p2 = makeFile(patientName: "Exp^P2", patientID: "EP2",
                          studyUID: "1.2.74.2", seriesUID: "1.2.74.21", modality: "CT")
        let paths = [try stageFile(p1.file, name: "p1.dcm"), try stageFile(p2.file, name: "p2.dcm")]
        _ = try ArchiveStore.importFiles(
            into: dir, files: paths, recursive: false, skipDuplicates: false, verbose: false)

        let outDir = try makeTempDir().appendingPathComponent("exp-patient")
        _ = try ArchiveStore.export(
            from: dir, output: outDir.path, studyUID: nil, seriesUID: nil,
            patientID: "EP1", flatten: true, verbose: false)

        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), 1, "only patient EP1's instance exports")
        let exported = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
            at: outDir, includingPropertiesForKeys: nil).first { $0.pathExtension == "dcm" })
        XCTAssertEqual(try DICOMFile.read(from: exported, force: true).dataSet.string(for: .patientID), "EP1")
    }

    // Oracle: export with flatten=false nests files in a subdirectory hierarchy — nothing
    // lands directly in the output root; the exported instance sits under sub-folders.
    func testExportNonFlattenHierarchicalLayout() throws {
        let dir = try freshArchive()
        let f = makeFile(patientName: "Hier^One", patientID: "HP1",
                         studyUID: "1.2.75.1", seriesUID: "1.2.75.11", modality: "CT")
        let path = try stageFile(f.file, name: "h.dcm")
        _ = try ArchiveStore.importFiles(
            into: dir, files: [path], recursive: false, skipDuplicates: false, verbose: false)

        let outDir = try makeTempDir().appendingPathComponent("exp-hier")
        _ = try ArchiveStore.export(
            from: dir, output: outDir.path, studyUID: "1.2.75.1", seriesUID: nil,
            patientID: nil, flatten: false, verbose: false)

        // Non-flatten: no .dcm directly in the output root.
        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), 0,
                       "non-flatten export must not place files in the output root")
        // The exported file exists nested at least one subdirectory deep.
        var found: URL?
        if let en = FileManager.default.enumerator(at: outDir, includingPropertiesForKeys: nil) {
            for case let url as URL in en where url.pathExtension == "dcm" { found = url; break }
        }
        let exported = try XCTUnwrap(found, "exported file must exist under a subdirectory")
        let rel = exported.path.replacingOccurrences(of: outDir.path + "/", with: "")
        XCTAssertTrue(rel.contains("/"), "non-flatten export must nest the file: \(rel)")
        XCTAssertEqual(try DICOMFile.read(from: exported, force: true).dataSet.string(for: .studyInstanceUID),
                       "1.2.75.1")
    }
}
