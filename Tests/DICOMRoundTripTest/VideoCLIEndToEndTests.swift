//
// VideoCLIEndToEndTests.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import Foundation

/// Runs the built `dicom-video` binary against real files on disk.
///
/// Every other video test calls the library directly, which leaves the CLI's own
/// file handling — resolving `--output`, the existence check, choosing a name —
/// untested. A conversion that succeeded in the library but could not be written
/// to the user's chosen folder passed the whole suite while failing in the app,
/// so these tests drive the executable the way a person does: real paths, real
/// directories, real bytes compared afterwards.
final class VideoCLIEndToEndTests: XCTestCase {

    // MARK: - Harness

    /// The built binary, or nil when the products directory cannot be located.
    private static var binaryURL: URL? {
        guard let bundle = Bundle.allBundles.first(where: { $0.bundlePath.hasSuffix(".xctest") })
        else { return nil }
        let products = bundle.bundleURL.deletingLastPathComponent()
        let candidate = products.appendingPathComponent("dicom-video")
        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    private struct Run {
        let status: Int32
        let stdout: String
        let stderr: String
        var combined: String { stdout + stderr }
    }

    /// Invokes the CLI, or skips the test when the binary is not built.
    private func run(_ arguments: [String]) throws -> Run {
        guard let binary = Self.binaryURL else {
            throw XCTSkip("dicom-video is not in the build products directory")
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = arguments

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        // Drain before waiting: a full pipe buffer would deadlock the child.
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return Run(
            status: process.terminationStatus,
            stdout: String(decoding: outData, as: UTF8.self),
            stderr: String(decoding: errData, as: UTF8.self)
        )
    }

    private var workDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dicom-video-e2e-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: workDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workDirectory { try? FileManager.default.removeItem(at: workDirectory) }
        try super.tearDownWithError()
    }

    // MARK: - Fixture

    /// A conformant H.264 High@4.1 clip in an MP4 container, written to disk.
    ///
    /// Built here rather than checked in so the test stays hermetic; the SPS is
    /// the same 1080p High Profile one the parser tests use, stored in `avcC` as
    /// a whole NAL unit the way a camera writes it.
    private func writeConformantClip(named name: String) throws -> URL {
        try writeClip(named: name, sps: Self.highProfileSPS)
    }

    /// The 1080p High@4.1 SPS a real encoder emits, NAL header included.
    private static let highProfileSPS: [UInt8] = [
        0x67, 0x64, 0x00, 0x29, 0xAC, 0xB4, 0x03, 0xC0, 0x11, 0x3F, 0x2C, 0x20,
        0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x07, 0x98,
    ]

    /// Baseline@3.0, which no DICOM video transfer syntax carries.
    private static let baselineSPS: [UInt8] = [
        0x67, 0x42, 0x00, 0x1E, 0xDA, 0x02, 0x80, 0xF6, 0x40,
    ]

    /// Writes an MP4 carrying one H.264 track with the given SPS in its `avcC`.
    private func writeClip(named name: String, sps: [UInt8]) throws -> URL {
        func box(_ type: String, _ payload: Data) -> Data {
            var data = Data()
            var size = UInt32(payload.count + 8).bigEndian
            withUnsafeBytes(of: &size) { data.append(contentsOf: $0) }
            data.append(contentsOf: Array(type.utf8))
            data.append(payload)
            return data
        }
        func uint16(_ value: UInt16) -> Data {
            var big = value.bigEndian
            return withUnsafeBytes(of: &big) { Data($0) }
        }
        func uint32(_ value: UInt32) -> Data {
            var big = value.bigEndian
            return withUnsafeBytes(of: &big) { Data($0) }
        }

        var avcCPayload = Data([0x01, 0x64, 0x00, 0x29, 0xFF, 0xE1])
        avcCPayload.append(uint16(UInt16(sps.count)))
        avcCPayload.append(contentsOf: sps)
        avcCPayload.append(0x00)
        let avcC = box("avcC", avcCPayload)

        var entry = Data(repeating: 0, count: 6)
        entry.append(uint16(1))
        entry.append(uint16(0))
        entry.append(uint16(0))
        entry.append(Data(repeating: 0, count: 12))
        entry.append(uint16(1920))
        entry.append(uint16(1080))
        entry.append(uint32(0x0048_0000))
        entry.append(uint32(0x0048_0000))
        entry.append(uint32(0))
        entry.append(uint16(1))
        entry.append(Data(repeating: 0, count: 32))
        entry.append(uint16(24))
        entry.append(uint16(0xFFFF))
        entry.append(avcC)

        var stsdPayload = uint32(0)
        stsdPayload.append(uint32(1))
        stsdPayload.append(box("avc1", entry))

        var stszPayload = uint32(0)
        stszPayload.append(uint32(1000))
        stszPayload.append(uint32(300))

        let stbl = box("stbl", box("stsd", stsdPayload) + box("stsz", stszPayload))

        var mdhdPayload = uint32(0)
        mdhdPayload.append(uint32(0))
        mdhdPayload.append(uint32(0))
        mdhdPayload.append(uint32(30000))
        mdhdPayload.append(uint32(300_000))
        mdhdPayload.append(uint16(0x55C4))
        mdhdPayload.append(uint16(0))

        var hdlrPayload = uint32(0)
        hdlrPayload.append(uint32(0))
        hdlrPayload.append(contentsOf: Array("vide".utf8))
        hdlrPayload.append(Data(repeating: 0, count: 12))
        hdlrPayload.append(contentsOf: Array("Handler\0".utf8))

        let mdia = box("mdia", box("mdhd", mdhdPayload)
                       + box("hdlr", hdlrPayload) + box("minf", stbl))

        var ftypPayload = Data("isom".utf8)
        ftypPayload.append(uint32(512))
        for brand in ["isom", "mp41", "avc1"] {
            ftypPayload.append(contentsOf: Array(brand.utf8))
        }

        let mp4 = box("ftyp", ftypPayload)
            + box("moov", box("trak", mdia))
            + box("mdat", Data(repeating: 0xAB, count: 64))

        let url = workDirectory.appendingPathComponent(name)
        try mp4.write(to: url)
        return url
    }

    // MARK: - Converting into a chosen folder

    /// The exact shape of the failure people hit: pick a clip, pick a folder,
    /// convert. The tool must write the object into the folder rather than treat
    /// the folder as a file that is already there.
    func testConvertIntoAnExistingDirectoryWritesTheObjectInsideIt() throws {
        let input = try writeConformantClip(named: "IMG_0429.mp4")
        let destination = workDirectory.appendingPathComponent("Test")
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)

        let result = try run([
            "convert", input.path, "--output", destination.path,
            "--type", "photographic", "--patient-name", "test", "--patient-id", "1111",
        ])

        XCTAssertEqual(result.status, 0,
                       "converting into a chosen folder must succeed:\n\(result.combined)")
        XCTAssertFalse(result.combined.contains("already exists"),
                       "the chosen folder is a destination, not a name collision")

        let written = destination.appendingPathComponent("IMG_0429.dcm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path),
                      "the object is named after the clip, inside the folder")
    }

    /// Extraction takes a folder the same way, and names the file for the
    /// container actually recovered.
    func testExtractIntoAnExistingDirectoryUsesThePayloadExtension() throws {
        let input = try writeConformantClip(named: "clip.mp4")
        let object = workDirectory.appendingPathComponent("clip.dcm")
        let convert = try run([
            "convert", input.path, "--output", object.path, "--type", "photographic",
        ])
        XCTAssertEqual(convert.status, 0, convert.combined)

        let destination = workDirectory.appendingPathComponent("Out")
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)

        let result = try run(["extract", object.path, "--output", destination.path])

        XCTAssertEqual(result.status, 0,
                       "extracting into a chosen folder must succeed:\n\(result.combined)")
        let written = destination.appendingPathComponent("clip.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path),
                      "an MP4 payload lands under .mp4, not the object's own name")
    }

    /// The whole point of remuxing, verified through the CLI on real files: the
    /// bytes that go in come back out unchanged.
    func testConvertThenExtractThroughDirectoriesIsByteIdentical() throws {
        let input = try writeConformantClip(named: "IMG_0429.mp4")
        let original = try Data(contentsOf: input)

        let objects = workDirectory.appendingPathComponent("Objects")
        let recovered = workDirectory.appendingPathComponent("Recovered")
        for url in [objects, recovered] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let convert = try run([
            "convert", input.path, "--output", objects.path, "--type", "photographic",
        ])
        XCTAssertEqual(convert.status, 0, convert.combined)

        let object = objects.appendingPathComponent("IMG_0429.dcm")
        let extract = try run(["extract", object.path, "--output", recovered.path])
        XCTAssertEqual(extract.status, 0, extract.combined)

        let output = try Data(contentsOf: recovered.appendingPathComponent("IMG_0429.mp4"))
        XCTAssertEqual(output, original,
                       "remuxing must preserve the camera's pixel data bit-for-bit")
    }

    // MARK: - The behaviour the fix must not disturb

    /// An explicit filename is still obeyed exactly.
    func testConvertToAnExplicitFileNameIsUnchanged() throws {
        let input = try writeConformantClip(named: "clip.mp4")
        let output = workDirectory.appendingPathComponent("named.dcm")

        let result = try run([
            "convert", input.path, "--output", output.path, "--type", "photographic",
        ])

        XCTAssertEqual(result.status, 0, result.combined)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    /// A real collision — an existing *file* — must still be refused, so the fix
    /// cannot become a way to silently overwrite someone's work.
    func testExistingFileIsStillRefusedWithoutForce() throws {
        let input = try writeConformantClip(named: "clip.mp4")
        let output = workDirectory.appendingPathComponent("taken.dcm")
        try Data("prior work".utf8).write(to: output)

        let result = try run([
            "convert", input.path, "--output", output.path, "--type", "photographic",
        ])

        XCTAssertNotEqual(result.status, 0, "an existing file is a genuine collision")
        XCTAssertTrue(result.combined.contains("already exists"), result.combined)
        XCTAssertEqual(try Data(contentsOf: output), Data("prior work".utf8),
                       "the existing file is left untouched")
    }

    /// `--force` overwrites a real file, as documented.
    func testForceOverwritesAnExistingFile() throws {
        let input = try writeConformantClip(named: "clip.mp4")
        let output = workDirectory.appendingPathComponent("taken.dcm")
        try Data("prior work".utf8).write(to: output)

        let result = try run([
            "convert", input.path, "--output", output.path,
            "--type", "photographic", "--force",
        ])

        XCTAssertEqual(result.status, 0, result.combined)
        XCTAssertNotEqual(try Data(contentsOf: output), Data("prior work".utf8))
    }

    /// Converting into a folder twice is a real collision the second time, and is
    /// refused rather than silently overwriting the first object.
    func testSecondConvertIntoTheSameDirectoryIsRefused() throws {
        let input = try writeConformantClip(named: "IMG_0429.mp4")
        let destination = workDirectory.appendingPathComponent("Test")
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)

        let arguments = [
            "convert", input.path, "--output", destination.path, "--type", "photographic",
        ]
        XCTAssertEqual(try run(arguments).status, 0)

        let second = try run(arguments)
        XCTAssertNotEqual(second.status, 0, "the object written a moment ago is now in the way")
        XCTAssertTrue(second.combined.contains("already exists"), second.combined)
        XCTAssertTrue(second.combined.contains("IMG_0429.dcm"),
                      "the message must name the real destination, not the folder")
    }

    // MARK: - Rejections still reach the user

    /// A non-conformant profile is still rejected, with the constraint named.
    func testBaselineProfileIsStillRejected() throws {
        // In an MP4, so the container rule passes and the profile rule is what
        // decides — a raw stream would be turned away one step earlier.
        let input = try writeClip(named: "baseline.mp4", sps: Self.baselineSPS)

        let destination = workDirectory.appendingPathComponent("Test")
        try FileManager.default.createDirectory(
            at: destination, withIntermediateDirectories: true)

        let result = try run([
            "convert", input.path, "--output", destination.path, "--type", "photographic",
        ])

        XCTAssertEqual(result.status, 2, "conformance rejections exit 2")
        XCTAssertTrue(result.combined.contains("profile_idc 66"),
                      "the rejection names the observed profile:\n\(result.combined)")
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.appendingPathComponent("baseline.dcm").path),
            "a rejected clip writes nothing")
    }

    /// High Profile is accepted — the regression that started all this. A real
    /// camera's SPS carries its NAL header inside `avcC`; reading that header byte
    /// as `profile_idc` yields 39 and rejects perfectly valid footage.
    func testHighProfileClipIsAcceptedNotMisreadAs39() throws {
        let input = try writeConformantClip(named: "high.mp4")

        let result = try run(["probe", input.path])

        XCTAssertEqual(result.status, 0, result.combined)
        XCTAssertTrue(result.combined.contains("High"),
                      "High Profile must be reported as High:\n\(result.combined)")
        XCTAssertFalse(result.combined.contains("profile_idc 39"),
                       "0x67 is the NAL header, not a profile")
    }
}
