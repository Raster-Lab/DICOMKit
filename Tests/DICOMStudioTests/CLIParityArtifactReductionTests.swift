// CLIParityArtifactReductionTests.swift
// Guards against the offline CLI-Parity artifact reductions touching a path that
// wasn't produced — the case behind the "IIOImageSource … can't open" console
// spam for error-result image scenarios (e.g. `dicom-export bulk` on a file).

import XCTest
@testable import DICOMStudio
import Foundation

@available(macOS 14.0, *)
final class CLIParityArtifactReductionTests: XCTestCase {

    func testImageRasterHashReturnsNilForMissingFileWithoutImageIONoise() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).png")
        XCTAssertNil(CLIParityEngine.imageRasterHash(fileURL: missing),
                     "A missing artifact must reduce to nil (callers map nil → decode-failed) without invoking ImageIO")
    }

    func testImageRasterHashReturnsNilForDirectory() {
        // `dicom-export bulk` resolves its output as a directory; hashing it as a
        // single image must fail gracefully, not log an ImageIO error.
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dir-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNil(CLIParityEngine.imageRasterHash(fileURL: dir),
                     "A directory must reduce to nil, never invoke ImageIO on it")
    }

    func testDecodedPixelHashReturnsNilForMissingFile() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nope-\(UUID().uuidString).dcm")
        XCTAssertNil(CLIParityEngine.decodedPixelHash(fileURL: missing))
    }
}
