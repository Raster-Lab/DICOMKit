// CLIToolBuilderRepoRootTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

#if os(macOS)

/// Guards the CLI-binary resolution used by the CLI Workshop's "Compare CLI" and the CLI
/// Parity screen. A GUI app runs with cwd `/`, so any absolute fallback path becomes the
/// *only* match — which is how the app came to build and run a sibling checkout's stale
/// `dicom-convert` / `dicom-compress`, rejecting transfer-syntax tokens (`jpeg-xl-lossless-only`)
/// that the DICOMKit linked into the very same app accepts.
@Suite("CLIToolBuilder repo-root resolution")
struct CLIToolBuilderRepoRootTests {

    /// This test file's own checkout, found the same way the fix finds it.
    private var thisCheckout: String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir.path
            }
            dir = dir.deletingLastPathComponent()
        }
        return "/"
    }

    @Test("repoRoot() resolves the checkout the app was compiled from, not the process cwd")
    func testRepoRootIgnoresCwd() throws {
        let fm = FileManager.default
        let saved = fm.currentDirectoryPath
        defer { fm.changeCurrentDirectoryPath(saved) }

        // Reproduce a GUI app's environment: cwd is `/`, which holds no Package.swift.
        #expect(fm.changeCurrentDirectoryPath("/"))

        let root = try #require(CLIToolBuilder.repoRoot(),
                                "repoRoot() must still resolve when cwd is not a package")
        #expect(root == thisCheckout,
                "repoRoot() returned \(root), expected this checkout \(thisCheckout)")
        #expect(fm.fileExists(atPath: "\(root)/Package.swift"))
    }

    @Test("repoRoot() honours DICOM_REPO_DIR only when it names a real package")
    func testRepoRootRejectsNonPackageOverride() {
        // `/` has no Package.swift, so the override must be ignored rather than returned.
        setenv("DICOM_REPO_DIR", "/", 1)
        defer { unsetenv("DICOM_REPO_DIR") }
        #expect(CLIToolBuilder.repoRoot() == thisCheckout)
    }

    @Test("no absolute checkout path is hard-coded into the CLI harness sources")
    func testNoHardCodedCheckoutPath() throws {
        // The bug was a literal sibling-repo path. Assert the sources cannot regress to one.
        let harness = ["Sources/DICOMStudio/Components/CLIToolBuilder.swift",
                       "Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift"]
        for rel in harness {
            let source = try String(contentsOfFile: "\(thisCheckout)/\(rel)", encoding: .utf8)
            for (n, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // Ignore the explanatory comments; only executable string literals matter.
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//") else { continue }
                #expect(!code.contains("\"/Users/"),
                        "\(rel):\(n + 1) hard-codes an absolute checkout path: \(code)")
            }
        }
    }
}

#endif
