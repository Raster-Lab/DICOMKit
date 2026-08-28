// StudioTestFixtures.swift
// DICOMStudioTests
//
// Locates the small synthetic DICOM files bundled with this test target
// (Tests/DICOMStudioTests/Fixtures). These used to live with the CLI-parity
// harness's generated data and were reached via CLIParityEngine.fixtureURL;
// that harness is gone, so the one fixture the print tests need is committed
// here instead — owned by the tests that actually use it.

import Foundation

enum StudioTestFixtures {
    /// URL of a bundled fixture (e.g. "syn-ct.dcm"), or nil if it is missing.
    static func url(named name: String) -> URL? {
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        return Bundle.module.url(forResource: stem, withExtension: ext, subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: stem, withExtension: ext)
    }
}
