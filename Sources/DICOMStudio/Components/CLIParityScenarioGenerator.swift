// CLIParityScenarioGenerator.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Builds the CLI Parity screen's scenarios DIRECTLY from the bundled goldens
// (Resources/CLIParity/goldens.json — the full, validated corpus the Claude
// parity test was generated from; falls back to goldens.synthetic.json on a
// clean checkout). Each golden is an already-validated, VALID command (correct
// subcommand + flag combination, captured from a successful CLI run), so this
// reproduces the parity test's scenario set per tool instead of re-deriving a
// lossy one-flag-at-a-time sweep.

import Foundation

public enum CLIParityScenarioGenerator {

    /// Maps a golden's bundled `fixtureFile` name to an input-shape kind (drives
    /// corpus resolution + UI hint). Image/JSON/XML/dir format-specific kinds get
    /// their own kind so the corpus never hands them a plain .dcm.
    static func fixtureKind(forFixtureFile name: String) -> String {
        switch name {
        case "":                                  return "none"
        case "CT.dcm", "syn-ct.dcm", "syn-ct2.dcm": return "ct"
        case "syn-mf.dcm":                        return "mf"
        case "syn-ct-rle.dcm":                    return "ctrle"
        case "syn-studyset", "syn-studyset2":     return "studyset"
        case "syn-series":                        return "series"
        case "syn-archive":                       return "archive"
        case "syn-doc.pdf":                       return "pdf"
        case "syn-pdf.dcm":                       return "pdfdcm"
        case "syn-pdfdcm-dir":                    return "pdfdcmdir"
        case "syn-workflow.dcmscript":            return "script"
        case "syn-ct.json":                       return "ctjson"
        case "syn-ct.xml":                        return "ctxml"
        case "syn-frame.png":                     return "framepng"
        case "syn-multi.tiff":                    return "multitiff"
        case "syn-png-dir":                       return "pngdir"
        case "syn-rle-dir":                       return "rledir"
        default:                                  return name.isEmpty ? "none" : "ct"
        }
    }

    /// Kinds the user corpus may supply (so the live test runs on real data).
    /// Format-specific kinds (json/xml/png/tiff/dirs) always use the bundled fixture.
    static let userOverridableKinds: Set<String> = ["ct", "ctpair"]

    /// Kinds whose input is a DIRECTORY (used for the UI hint / skip messaging).
    static let directoryKinds: Set<String> = ["studyset", "series", "archive", "pdfdcmdir", "pngdir", "rledir"]

    /// Human hint about the expected input for a tool.
    public static func inputHint(for toolId: String) -> String {
        switch toolId {
        case "dicom-split":             return "multiframe DICOM file"
        case "dicom-diff":              return "two DICOM files"
        case "dicom-study", "dicom-merge": return "study directory"
        case "dicom-archive":           return "archive directory"
        case "dicom-pdf":               return "PDF / encapsulated DICOM"
        case "dicom-script":            return "no input / .dcmscript"
        case "dicom-uid":               return "UID / DICOM file"
        case "dicom-image":             return "image file(s)"
        default:                        return "DICOM file"
        }
    }

    // MARK: Goldens → scenarios

    /// Maps one validated golden scenario to a runnable BatchScenario.
    static func batchScenario(from g: GoldenScenario) -> BatchScenario {
        var kind = fixtureKind(forFixtureFile: g.fixtureFile)
        // Two-file scenarios (diff, tags copy-from, study compare) → a pair kind so
        // the corpus can supply both files (else they'd fall back to bundled).
        if g.fixtureFile2 != nil {
            if kind == "ct" { kind = "ctpair" }
            else if kind == "studyset" { kind = "studypair" }
        }
        // JSON null → stdout (NOT "dicom"): nil artifactKind always pairs with a
        // nil artifactName, i.e. a stdout scenario.
        var artifactKind = g.artifactKind ?? "stdout"
        var artifactName = g.artifactName
        // The bundled fixture name IS the fixtureFile string (resolves via fixtureURL).
        var fixtureName: String? = g.fixtureFile.isEmpty ? nil : g.fixtureFile
        // A nonzero recorded exit is a RESULT (diff differs, validate fails, …),
        // so app+CLI agreement on it is compared, not flagged as an error.
        var resultExitOK = g.exitCode != 0

        // `dicom-export bulk` reads a DIRECTORY of DICOM files and writes a DIRECTORY
        // of images. The goldens captured it on a SINGLE file (which bulk rejects →
        // exit 1), so steer it to a study directory and compare the produced image
        // set. The user's corpus (a folder of DICOMs) drives it when provided.
        if g.toolId == "dicom-export", g.cliArgs.first == "bulk" {
            kind = "studyset"            // directory input (corpus study dir / bundled syn-studyset)
            fixtureName = "syn-studyset"
            artifactName = "out"         // OUTPUT is a directory
            artifactKind = "image-multi" // compare the produced directory of images
            resultExitOK = false         // bulk on a directory succeeds (exit 0)
        }

        let usesFixture  = !g.fixtureFile.isEmpty || g.cliArgs.contains("FIXTURE") || g.studioParams.values.contains("FIXTURE")
        let usesFixture2 = (g.fixtureFile2 != nil) || g.cliArgs.contains("FIXTURE2") || g.studioParams.values.contains("FIXTURE2")
        return BatchScenario(
            scenarioId: g.scenarioId, toolId: g.toolId, label: g.label,
            cliArgs: g.cliArgs, studioParams: g.studioParams,
            needsInputFile: usesFixture, needsSecondFile: usesFixture2,
            artifactName: artifactName,
            artifactKind: artifactKind,
            needsDirectory: directoryKinds.contains(kind),
            fixtureName: fixtureName,
            fixture2Name: g.fixtureFile2,
            userFileAllowed: userOverridableKinds.contains(kind),
            fixtureKind: kind,
            resultExitOK: resultExitOK,
            inputHint: inputHint(for: g.toolId))
    }

    /// Builds the scenario list for the selected tools from the loaded goldens.
    /// When `dedupByCliArgs` is true, collapses the same command run on multiple
    /// fixtures (e.g. CT.dcm + syn-ct.dcm) to ONE row, preferring the PHI-free
    /// synthetic fixture — yielding the unique validated command set.
    public static func scenarios(fromGoldens goldens: [GoldenScenario],
                                 toolIDs: Set<String>,
                                 dedupByCliArgs: Bool) -> [BatchScenario] {
        let mapped = goldens.filter { toolIDs.contains($0.toolId) }.map(batchScenario(from:))
        guard dedupByCliArgs else { return mapped }

        var best: [String: BatchScenario] = [:]
        var order: [String] = []
        for s in mapped {
            // Include fixtureKind so DIFFERENT input shapes with identical args (e.g.
            // dicom-info on syn-ct vs syn-mf) both survive; only same-shape fixture
            // duplicates (CT.dcm + syn-ct.dcm, both "ct") collapse.
            let key = s.toolId + "\u{1}" + s.fixtureKind + "\u{1}" + s.cliArgs.joined(separator: "\u{1}")
            if let existing = best[key] {
                let existingSyn = existing.fixtureName?.hasPrefix("syn") ?? true
                let newSyn = s.fixtureName?.hasPrefix("syn") ?? true
                if newSyn && !existingSyn { best[key] = s }   // prefer synthetic
            } else {
                best[key] = s
                order.append(key)
            }
        }
        return order.compactMap { best[$0] }
    }
}
