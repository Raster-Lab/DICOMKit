// MergeRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-merge` tool.
// Drives the DICOMKit library (FrameMerger) directly; never spawns the CLI.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

final class MergeRoundTripTests: XCTestCase {

    // MARK: - Private helpers

    /// Writes each `DICOMFile` to a fresh temp directory and returns their paths (in order).
    private func writeInputs(_ files: [DICOMFile], dir: URL) throws -> [String] {
        var paths: [String] = []
        for (i, f) in files.enumerated() {
            let url = dir.appendingPathComponent(String(format: "in_%03d.dcm", i))
            try f.write().write(to: url)
            paths.append(url.path)
        }
        return paths
    }

    /// Returns a copy of `file` with `mutate` applied to its dataSet (dataSet is `let`, so rebuild).
    private func withDataSet(_ file: DICOMFile, _ mutate: (inout DataSet) -> Void) -> DICOMFile {
        var ds = file.dataSet
        mutate(&ds)
        return DICOMFile(fileMetaInformation: file.fileMetaInformation, dataSet: ds)
    }

    /// A single-frame grayscale-8 file with a fixed pixel value and a given InstanceNumber.
    private func makeFrame(value: UInt8, instanceNumber: Int, rows: UInt16 = 4, cols: UInt16 = 4) -> DICOMFile {
        let file = makeGrayscale8(rows: rows, cols: cols, fillPattern: { _ in value })
        return withDataSet(file) { $0.setString("\(instanceNumber)", for: .instanceNumber, vr: .IS) }
    }

    /// Reads an IS-VR (integer-string) tag as Int. NumberOfFrames (0028,0008) and
    /// InstanceNumber (0020,0013) are VR=IS; `int32(for:)` only decodes binary SL
    /// and returns nil for them, so it must not be used here.
    private func isInt(_ file: DICOMFile, _ tag: Tag) -> Int? {
        file.dataSet.string(for: tag).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Tests

    // Oracle: merged file has NumberOfFrames == input count; frame 0 all-zero, frame 1 all-255.
    func testMergeTwoFilesFrameCountAndPixels() async throws {
        let dir = try makeTempDir()
        let a = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 0 })
        let b = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 255 })
        let paths = try writeInputs([a, b], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(isInt(merged, .numberOfFrames), 2)

        let px = pixelBytes(merged)
        let frameSize = 4 * 4
        XCTAssertEqual(px.count, frameSize * 2)
        // Frame 0 all-zero.
        for i in 0..<frameSize { XCTAssertEqual(readU8(px, at: i), 0) }
        // Frame 1 all-255.
        for i in 0..<frameSize { XCTAssertEqual(readU8(px, at: frameSize + i), 255) }
    }

    // Oracle: merged pixel bytes == exact concatenation of source pixel bytes in sort order.
    func testMergePixelBytesAreConcatenation() async throws {
        let dir = try makeTempDir()
        let frames = [makeFrame(value: 10, instanceNumber: 1),
                      makeFrame(value: 20, instanceNumber: 2),
                      makeFrame(value: 30, instanceNumber: 3)]
        let paths = try writeInputs(frames, dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .instanceNumber,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        var expected = Data()
        for f in frames { expected.append(pixelBytes(f)) }

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(pixelBytes(merged), expected)
    }

    // Oracle: common metadata (PatientName, StudyInstanceUID) inherited from first file unchanged.
    func testMergePreservesCommonMetadata() async throws {
        let dir = try makeTempDir()
        let a = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 1 })
        let b = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 2 })
        let paths = try writeInputs([a, b], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(merged.dataSet.string(for: .patientName), a.dataSet.string(for: .patientName))
        XCTAssertEqual(merged.dataSet.string(for: .studyInstanceUID), a.dataSet.string(for: .studyInstanceUID))
        XCTAssertEqual(merged.dataSet.string(for: .seriesInstanceUID), a.dataSet.string(for: .seriesInstanceUID))
    }

    // Oracle: merged multi-frame instance has InstanceNumber == 1 and a fresh (differing) SOPInstanceUID.
    func testMergeSetsInstanceNumberOneAndNewSOPUID() async throws {
        let dir = try makeTempDir()
        let a = makeFrame(value: 1, instanceNumber: 7)
        let b = makeFrame(value: 2, instanceNumber: 8)
        let paths = try writeInputs([a, b], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(isInt(merged, .instanceNumber), 1)
        let newUID = try XCTUnwrap(merged.dataSet.string(for: .sopInstanceUID))
        XCTAssertNotEqual(newUID, a.dataSet.string(for: .sopInstanceUID))
        XCTAssertNotEqual(newUID, b.dataSet.string(for: .sopInstanceUID))
    }

    // Oracle: sortBy=.instanceNumber ascending orders frames by InstanceNumber regardless of input order.
    func testMergeSortByInstanceNumberAscending() async throws {
        let dir = try makeTempDir()
        // Input order (path-sorted) does NOT match instance order: value encodes intended position.
        let f3 = makeFrame(value: 30, instanceNumber: 3)
        let f1 = makeFrame(value: 10, instanceNumber: 1)
        let f2 = makeFrame(value: 20, instanceNumber: 2)
        let paths = try writeInputs([f3, f1, f2], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .instanceNumber,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        let px = pixelBytes(merged)
        let frameSize = 4 * 4
        XCTAssertEqual(px.count, frameSize * 3)
        // Frame values, in output order, must be 10, 20, 30 (ascending by InstanceNumber).
        XCTAssertEqual(readU8(px, at: 0 * frameSize), 10)
        XCTAssertEqual(readU8(px, at: 1 * frameSize), 20)
        XCTAssertEqual(readU8(px, at: 2 * frameSize), 30)
    }

    // Oracle: sortBy=.instanceNumber descending reverses the ascending order.
    func testMergeSortByInstanceNumberDescending() async throws {
        let dir = try makeTempDir()
        let f1 = makeFrame(value: 10, instanceNumber: 1)
        let f2 = makeFrame(value: 20, instanceNumber: 2)
        let f3 = makeFrame(value: 30, instanceNumber: 3)
        let paths = try writeInputs([f1, f2, f3], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .instanceNumber,
                                 order: .descending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        let px = pixelBytes(merged)
        let frameSize = 4 * 4
        XCTAssertEqual(readU8(px, at: 0 * frameSize), 30)
        XCTAssertEqual(readU8(px, at: 1 * frameSize), 20)
        XCTAssertEqual(readU8(px, at: 2 * frameSize), 10)
    }

    // Oracle: validate=true throws MergeError.inconsistentPixelDataSize when frame byte-sizes differ.
    func testValidateThrowsOnInconsistentPixelSize() async throws {
        let dir = try makeTempDir()
        let a = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 1 })   // 16 bytes
        let b = makeGrayscale8(rows: 8, cols: 8, fillPattern: { _ in 2 })   // 64 bytes
        let paths = try writeInputs([a, b], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: true, verbose: false)
        do {
            try await merger.mergeToSingleFile(files: paths, outputPath: out.path)
            XCTFail("Expected validation to throw on inconsistent pixel data size")
        } catch let error as MergeError {
            guard case .inconsistentPixelDataSize = error else {
                return XCTFail("Expected .inconsistentPixelDataSize, got \(error)")
            }
        }
    }

    // Oracle: validate=true accepts consistent frames (no throw) and still produces the merged file.
    func testValidatePassesOnConsistentFrames() async throws {
        let dir = try makeTempDir()
        let a = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 5 })
        let b = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in 9 })
        let paths = try writeInputs([a, b], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: true, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(isInt(merged, .numberOfFrames), 2)
    }

    // Oracle: mergeToSingleFile with no valid files throws MergeError.noValidFiles.
    func testMergeNoValidFilesThrows() async throws {
        let dir = try makeTempDir()
        let bogus = dir.appendingPathComponent("notdicom.txt")
        try Data("hello".utf8).write(to: bogus)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        do {
            try await merger.mergeToSingleFile(files: [bogus.path], outputPath: out.path)
            XCTFail("Expected MergeError.noValidFiles")
        } catch let error as MergeError {
            guard case .noValidFiles = error else {
                return XCTFail("Expected .noValidFiles, got \(error)")
            }
        }
    }

    // Oracle: mergeBySeries produces one output file per distinct SeriesInstanceUID; total frames preserved.
    func testMergeBySeriesGroupsBySeriesUID() async throws {
        let dir = try makeTempDir()
        let seriesA = rtUID()
        let seriesB = rtUID()

        func frame(series: String, value: UInt8) -> DICOMFile {
            let f = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in value })
            return withDataSet(f) { $0.setString(series, for: .seriesInstanceUID, vr: .UI) }
        }

        let files = [frame(series: seriesA, value: 1),
                     frame(series: seriesA, value: 2),
                     frame(series: seriesB, value: 3)]
        let paths = try writeInputs(files, dir: dir)

        let outDir = try makeTempDir()
        let merger = FrameMerger(format: .standard, level: .series, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeBySeries(files: paths, outputDirectory: outDir.path)

        // Two distinct series -> two output .dcm files.
        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), 2)

        // Sum of frames across all series outputs must equal the total input count.
        let outputs = try FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "dcm" }
        var totalFrames = 0
        for url in outputs {
            let f = try DICOMFile.read(from: url)
            totalFrames += isInt(f, .numberOfFrames) ?? 0
        }
        XCTAssertEqual(totalFrames, 3)
    }

    // Oracle: merge output round-trips (write -> read -> write -> read) with stable pixel bytes and frame count.
    func testMergeOutputRoundTripsStable() async throws {
        let dir = try makeTempDir()
        let frames = [makeFrame(value: 11, instanceNumber: 1),
                      makeFrame(value: 22, instanceNumber: 2)]
        let paths = try writeInputs(frames, dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .instanceNumber,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let first = try DICOMFile.read(from: out)
        let firstPixels = pixelBytes(first)
        let reWritten = try first.write()
        let second = try DICOMFile.read(from: reWritten)
        XCTAssertEqual(pixelBytes(second), firstPixels)
        XCTAssertEqual(isInt(second, .numberOfFrames), isInt(first, .numberOfFrames))
    }

    // MARK: - Oracle: --level study groups by study then series, one file per series

    // Oracle: mergeByStudy nests output as study_<studyUID>/series_<seriesUID>.dcm,
    // producing one multi-frame file per distinct series within each study; frames
    // sort ascending by InstanceNumber and the total frame count is preserved.
    func testMergeByStudyGroupsByStudyThenSeries() async throws {
        let dir = try makeTempDir()
        let studyA = rtUID(), studyB = rtUID()
        let seriesA1 = rtUID(), seriesB1 = rtUID()

        func frame(study: String, series: String, value: UInt8, inst: Int) -> DICOMFile {
            let f = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in value })
            return withDataSet(f) {
                $0.setString(study, for: .studyInstanceUID, vr: .UI)
                $0.setString(series, for: .seriesInstanceUID, vr: .UI)
                $0.setString("\(inst)", for: .instanceNumber, vr: .IS)
            }
        }

        // Study A: one series, two frames (values 10, 20). Study B: one series, one frame (30).
        let files = [
            frame(study: studyA, series: seriesA1, value: 20, inst: 2),  // deliberately out of order
            frame(study: studyA, series: seriesA1, value: 10, inst: 1),
            frame(study: studyB, series: seriesB1, value: 30, inst: 1),
        ]
        let paths = try writeInputs(files, dir: dir)

        let outDir = try makeTempDir()
        let merger = FrameMerger(format: .standard, level: .study, sortBy: .instanceNumber,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeByStudy(files: paths, outputDirectory: outDir.path)

        // Deterministic nested layout: study_<UID>/series_<UID>.dcm.
        let aFile = outDir.appendingPathComponent("study_\(studyA)/series_\(seriesA1).dcm")
        let bFile = outDir.appendingPathComponent("study_\(studyB)/series_\(seriesB1).dcm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: aFile.path), "study A series file missing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bFile.path), "study B series file missing")

        // Study A merged: 2 frames, ordered 10 then 20 by InstanceNumber.
        let aMerged = try DICOMFile.read(from: aFile)
        XCTAssertEqual(isInt(aMerged, .numberOfFrames), 2)
        let aPx = pixelBytes(aMerged)
        let frameSize = 4 * 4
        XCTAssertEqual(readU8(aPx, at: 0 * frameSize), 10, "study A frame 0 must be InstanceNumber 1 (value 10)")
        XCTAssertEqual(readU8(aPx, at: 1 * frameSize), 20, "study A frame 1 must be InstanceNumber 2 (value 20)")

        // Study B merged: single frame value 30.
        let bMerged = try DICOMFile.read(from: bFile)
        XCTAssertEqual(isInt(bMerged, .numberOfFrames), 1)
        XCTAssertEqual(readU8(pixelBytes(bMerged), at: 0), 30)

        // Total frames across the two study/series outputs equals the input count (3).
        let totalFrames = (isInt(aMerged, .numberOfFrames) ?? 0) + (isInt(bMerged, .numberOfFrames) ?? 0)
        XCTAssertEqual(totalFrames, 3)
        // Exactly two output files were produced (one per series).
        XCTAssertEqual(countFiles(in: outDir.appendingPathComponent("study_\(studyA)"), extension: "dcm"), 1)
        XCTAssertEqual(countFiles(in: outDir.appendingPathComponent("study_\(studyB)"), extension: "dcm"), 1)
    }

    // MARK: - Oracle: --sort-by ImagePositionPatient / AcquisitionTime

    // Oracle: sortBy=.imagePositionPatient orders frames ascending by the z-coordinate
    // of ImagePositionPatient (0020,0032), independent of input path order.
    func testMergeSortByImagePositionPatientAscending() async throws {
        let dir = try makeTempDir()
        func frame(z: Double, value: UInt8) -> DICOMFile {
            let f = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in value })
            return withDataSet(f) { $0.setString("0\\0\\\(z)", for: .imagePositionPatient, vr: .DS) }
        }
        // Input order (path-sorted) mismatches z-order; the fill value encodes intended position.
        let paths = try writeInputs(
            [frame(z: 30, value: 30), frame(z: 10, value: 10), frame(z: 20, value: 20)], dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .imagePositionPatient,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let px = pixelBytes(try DICOMFile.read(from: out))
        let fs = 4 * 4
        XCTAssertEqual(readU8(px, at: 0 * fs), 10, "ascending by z → frame 0 is z=10")
        XCTAssertEqual(readU8(px, at: 1 * fs), 20)
        XCTAssertEqual(readU8(px, at: 2 * fs), 30)
    }

    // Oracle: sortBy=.acquisitionTime orders frames ascending by AcquisitionTime
    // (0008,0032), independent of input path order.
    func testMergeSortByAcquisitionTimeAscending() async throws {
        let dir = try makeTempDir()
        func frame(time: String, value: UInt8) -> DICOMFile {
            let f = makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in value })
            return withDataSet(f) { $0.setString(time, for: .acquisitionTime, vr: .TM) }
        }
        let paths = try writeInputs(
            [frame(time: "120300", value: 30), frame(time: "120100", value: 10), frame(time: "120200", value: 20)],
            dir: dir)

        let out = dir.appendingPathComponent("merged.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .acquisitionTime,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let px = pixelBytes(try DICOMFile.read(from: out))
        let fs = 4 * 4
        XCTAssertEqual(readU8(px, at: 0 * fs), 10, "ascending by time → frame 0 is 120100")
        XCTAssertEqual(readU8(px, at: 1 * fs), 20)
        XCTAssertEqual(readU8(px, at: 2 * fs), 30)
    }

    // MARK: - Oracle: --format enhanced-ct emits the Enhanced IOD (SOP class + functional groups)

    // The Enhanced formats were formerly inert (FrameMerger stored but never read
    // `format`). Oracle: enhanced-ct output carries the Enhanced CT Image Storage
    // SOP Class (dataset AND file meta), a SharedFunctionalGroupsSequence, and one
    // PerFrameFunctionalGroups item per source frame with FrameContent stack
    // bookkeeping; pixel bytes are unchanged versus a standard merge.
    func testEnhancedCTFormatSetsSOPClassAndFunctionalGroups() async throws {
        let dir = try makeTempDir()
        let frames = [10, 20, 30].map { v in
            withDataSet(makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in UInt8(v) })) { ds in
                ds.setString("0.5\\0.5", for: .pixelSpacing, vr: .DS)
                ds.setString("1.0\\2.0\\\(v).0", for: .imagePositionPatient, vr: .DS)
            }
        }
        let paths = try writeInputs(frames, dir: dir)

        let out = dir.appendingPathComponent("enhanced.dcm")
        let merger = FrameMerger(format: .enhancedCt, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        let enhancedCT = "1.2.840.10008.5.1.4.1.1.2.1"
        XCTAssertEqual(merged.dataSet.string(for: .sopClassUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), enhancedCT)
        XCTAssertEqual(merged.fileMetaInformation.string(for: .mediaStorageSOPClassUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")), enhancedCT)
        XCTAssertEqual(isInt(merged, .numberOfFrames), 3)

        // Shared FG present, with Pixel Measures lifted from the template frame.
        let shared = merged.dataSet[.sharedFunctionalGroupsSequence]?.sequenceItems
        XCTAssertEqual(shared?.count, 1, "one shared functional-groups item")
        XCTAssertNotNil(shared?.first?.elements[Tag.pixelMeasuresSequence],
                        "PixelMeasuresSequence expected (source had PixelSpacing)")

        // Per-frame FG: one item per source frame, each with FrameContent + PlanePosition.
        let perFrame = merged.dataSet[.perFrameFunctionalGroupsSequence]?.sequenceItems
        XCTAssertEqual(perFrame?.count, 3, "one per-frame item per source frame")
        for item in perFrame ?? [] {
            XCTAssertNotNil(item.elements[Tag.frameContentSequence],
                            "each per-frame item carries a FrameContentSequence")
            XCTAssertNotNil(item.elements[Tag.planePositionSequence],
                            "each per-frame item carries a PlanePositionSequence (source had IPP)")
        }

        // Pixel bytes are the same concatenation a standard merge produces.
        var expected = Data()
        for f in frames { expected.append(pixelBytes(f)) }
        XCTAssertEqual(pixelBytes(merged), expected)
    }

    // MARK: - Oracle: --format standard is unchanged (no functional groups, SOP class inherited)

    func testStandardFormatCarriesNoFunctionalGroups() async throws {
        let dir = try makeTempDir()
        let frames = [1, 2].map { v in makeGrayscale8(rows: 4, cols: 4, fillPattern: { _ in UInt8(v) }) }
        let sourceSOPClass = frames[0].dataSet.string(for: .sopClassUID)
        let paths = try writeInputs(frames, dir: dir)

        let out = dir.appendingPathComponent("standard.dcm")
        let merger = FrameMerger(format: .standard, level: .file, sortBy: .none,
                                 order: .ascending, validate: false, verbose: false)
        try await merger.mergeToSingleFile(files: paths, outputPath: out.path)

        let merged = try DICOMFile.read(from: out)
        XCTAssertEqual(merged.dataSet.string(for: .sopClassUID), sourceSOPClass,
                       "standard merge inherits the template SOP class")
        XCTAssertNil(merged.dataSet[.sharedFunctionalGroupsSequence])
        XCTAssertNil(merged.dataSet[.perFrameFunctionalGroupsSequence])
    }
}
