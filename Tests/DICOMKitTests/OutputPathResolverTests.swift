import Testing
import Foundation
@testable import DICOMKit

/// Contract tests for ``OutputPathResolver`` — the single rule that turns a user-supplied
/// `--output` into a destination file for the single-file tools.
///
/// `dicom-convert` and `dicom-compress` bypassed this helper and passed `--output` straight
/// to `Data.write(to:)`, so a directory (what the Workshop's Browse button hands back, and
/// what `~/Desktop/DICOM_Output/` means) failed with *"Is a directory"* on the CLI while the
/// in-process app happily wrote into it. These pin the behaviour both surfaces now share.
@Suite("OutputPathResolver")
struct OutputPathResolverTests {

    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "opr-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("an existing directory receives the input's filename")
    func testExistingDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let resolved = OutputPathResolver.resolveFileOutput(output: dir, input: "/in/CT.dcm")
        #expect(resolved == "\(dir)/CT.dcm")
    }

    @Test("a trailing slash marks a directory even when it does not exist yet")
    func testTrailingSlashNonExistent() {
        let resolved = OutputPathResolver.resolveFileOutput(
            output: "/nope/does/not/exist/", input: "/in/CT.dcm")
        #expect(resolved == "/nope/does/not/exist/CT.dcm")
    }

    @Test("an explicit file path is returned verbatim")
    func testExplicitFilePath() {
        let resolved = OutputPathResolver.resolveFileOutput(
            output: "/out/custom.dcm", input: "/in/CT.dcm")
        #expect(resolved == "/out/custom.dcm")
    }

    @Test("fileExtension overrides the input's extension inside a directory")
    func testExtensionOverride() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        // This is what `dicom-convert --format png --output <dir>` relies on.
        #expect(OutputPathResolver.resolveFileOutput(
            output: dir, input: "/in/CT.dcm", fileExtension: "png") == "\(dir)/CT.png")
        #expect(OutputPathResolver.resolveFileOutput(
            output: dir, input: "/in/CT.dcm", fileExtension: "jpg") == "\(dir)/CT.jpg")
        // A DICOM-out tool asks for `dcm`, which is a no-op for a `.dcm` input but still
        // names the file correctly when the input carries no extension at all.
        #expect(OutputPathResolver.resolveFileOutput(
            output: dir, input: "/in/CT", fileExtension: "dcm") == "\(dir)/CT.dcm")
    }

    @Test("an explicit file path keeps its own extension, ignoring fileExtension")
    func testExplicitFileIgnoresExtension() {
        // The user named a file — honour it rather than rewriting the suffix.
        #expect(OutputPathResolver.resolveFileOutput(
            output: "/out/custom.tiff", input: "/in/CT.dcm", fileExtension: "png") == "/out/custom.tiff")
    }

    @Test("an empty or omitted output means overwrite the input in place")
    func testEmptyOutputOverwritesInput() {
        #expect(OutputPathResolver.resolveFileOutput(output: nil, input: "/in/CT.dcm") == "/in/CT.dcm")
        #expect(OutputPathResolver.resolveFileOutput(output: "", input: "/in/CT.dcm") == "/in/CT.dcm")
        #expect(OutputPathResolver.resolveFileOutput(output: "   ", input: "/in/CT.dcm") == "/in/CT.dcm")
    }

    @Test("resolving into a directory never returns the directory itself")
    func testNeverReturnsDirectoryItself() throws {
        // The precise failure that surfaced as "The file 'DICOM_Output' couldn't be saved":
        // a directory path must never come back unchanged, or the caller writes onto it.
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        for output in [dir, dir + "/"] {
            let resolved = OutputPathResolver.resolveFileOutput(
                output: output, input: "/in/CT.dcm", fileExtension: "dcm")
            #expect(resolved != output)
            var isDir: ObjCBool = false
            _ = FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir)
            #expect(!isDir.boolValue)
        }
    }
}
