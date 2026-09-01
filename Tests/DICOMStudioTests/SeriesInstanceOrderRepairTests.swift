// SeriesInstanceOrderRepairTests.swift
// DICOMStudioTests
//
// Repairing a series whose instance order was lost.
//
// A library index written by a build that could not read Instance Number (an
// IS — text — once read as binary, which always answered nil) holds the
// series in file-system order, and re-imports never refresh it: duplicates
// are skipped by SOP Instance UID. The reader then sees "image 17" where
// every conformant viewer — Weasis, sorting by Instance Number — sees image
// 4, and a saved presentation state looks misplaced when it is exactly where
// it was made. The repair pass reads the numbers off the files when the
// index lacks them, re-sorts the pane's entry, and hands the numbers back so
// the index is healed once rather than re-read on every open.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("Series Instance Order Repair Tests")
struct SeriesInstanceOrderRepairTests {

    /// Writes one single-frame image file with a SOP Instance UID and an
    /// Instance Number, returning its path.
    private func writeImage(
        in directory: URL, name: String, sopUID: String, instanceNumber: Int
    ) throws -> String {
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.4", for: .sopClassUID, vr: .UI)
        dataSet.setString(sopUID, for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.9.9", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.9.9.1", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString(String(instanceNumber), for: .instanceNumber, vr: .IS)
        let file = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.4",
            sopInstanceUID: sopUID,
            transferSyntaxUID: "1.2.840.10008.1.2.1")
        let url = directory.appendingPathComponent(name)
        try file.write().write(to: url)
        return url.path
    }

    @Test("A stale entry is re-sorted by the numbers read off its files")
    func testRepairReordersAndRecoversNumbers() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("order-repair-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Files whose name order is not their acquisition order — the shape a
        // PACS retrieve leaves behind, where names are download order.
        let a = try writeImage(in: directory, name: "a.dcm", sopUID: "1.9.9.1.10", instanceNumber: 3)
        let b = try writeImage(in: directory, name: "b.dcm", sopUID: "1.9.9.1.11", instanceNumber: 1)
        let c = try writeImage(in: directory, name: "c.dcm", sopUID: "1.9.9.1.12", instanceNumber: 2)

        // The stale index's entry: file-system order, no numbers known.
        let stale = ViewerSeriesEntry(
            seriesInstanceUID: "1.9.9.1", title: "t2_tse", modality: "MR",
            filePaths: [a, b, c], frameCount: 3)

        let repaired = await ViewerSeriesCatalog.resolvingInstanceOrder([stale])

        #expect(repaired.entries.first?.filePaths == [b, c, a],
                "Instance Number order, not file-system order")
        #expect(repaired.entries.first?.instanceNumbersBySOPUID
                == ["1.9.9.1.10": 3, "1.9.9.1.11": 1, "1.9.9.1.12": 2])
        #expect(repaired.recoveredNumbers
                == ["1.9.9.1.10": 3, "1.9.9.1.11": 1, "1.9.9.1.12": 2],
                "The caller gets the numbers to heal the index with")
    }

    @Test("An entry whose numbers the index already holds is not re-read")
    func testHealthyEntryIsLeftAlone() async {
        // Paths that do not exist: touching them would fail loudly, which is
        // the point — a healthy entry must not be read at all.
        let healthy = ViewerSeriesEntry(
            seriesInstanceUID: "1.9.9.2", title: "ok", modality: "MR",
            filePaths: ["/nope/1.dcm", "/nope/2.dcm"], frameCount: 2,
            instanceNumbersBySOPUID: ["s1": 1, "s2": 2])

        let repaired = await ViewerSeriesCatalog.resolvingInstanceOrder([healthy])

        #expect(repaired.entries.first?.filePaths == healthy.filePaths)
        #expect(repaired.recoveredNumbers.isEmpty)
    }

    @Test("Unreadable files leave the entry as it was, not half-sorted")
    func testUnreadableSeriesKeepsItsOrder() async {
        let stale = ViewerSeriesEntry(
            seriesInstanceUID: "1.9.9.3", title: "gone", modality: "MR",
            filePaths: ["/nope/x.dcm", "/nope/y.dcm"], frameCount: 2)

        let repaired = await ViewerSeriesCatalog.resolvingInstanceOrder([stale])

        #expect(repaired.entries.first?.filePaths == stale.filePaths)
        #expect(repaired.recoveredNumbers.isEmpty)
    }
}
