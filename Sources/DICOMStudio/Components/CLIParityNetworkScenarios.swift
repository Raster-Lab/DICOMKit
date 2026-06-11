// CLIParityNetworkScenarios.swift
// DICOMStudio
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  TESTING-ONLY — REMOVE BEFORE PRODUCTION  ⚠️                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// Generates the NETWORK-mode scenarios for the CLI Parity screen. Unlike the
// file tools (whose scenarios come from bundled goldens), network scenarios are
// a curated flag-wise matrix run against a USER-SUPPLIED PACS endpoint — the end
// user provides only the connection credentials and the harness sweeps each
// valid dicom-echo flag, running the app and the real CLI against the same live
// server and comparing the outcome semantically (see CLIParityEchoComparator).
//
// Endpoint placeholders are resolved at run time from the screen's editable
// credential fields:
//   HOST · PORT · AET (calling) · CALLED_AET · TIMEOUT

import Foundation

public enum CLIParityNetworkScenarios {

    /// Placeholder tokens the network runner resolves from the endpoint config.
    public static let hostToken = "HOST"
    public static let portToken = "PORT"
    public static let aetToken = "AET"
    public static let calledAETToken = "CALLED_AET"
    public static let timeoutToken = "TIMEOUT"

    /// Number of requests used by the multi-echo scenarios. Kept small so the
    /// live-server sweep stays quick and light on network traffic.
    private static let multiCount = "3"

    /// Tool ids that have a network-parity implementation today.
    public static let supportedToolIDs: Set<String> = ["dicom-echo"]

    /// Builds the scenario list for the selected network tools.
    public static func scenarios(toolIDs: Set<String>) -> [BatchScenario] {
        var out: [BatchScenario] = []
        if toolIDs.contains("dicom-echo") { out += echoScenarios() }
        return out
    }

    // MARK: dicom-echo flag matrix

    /// One scenario per valid dicom-echo flag (and the meaningful combinations),
    /// so parity is verified flag-by-flag.
    static func echoScenarios() -> [BatchScenario] {
        [
            echo("basic",          "echo (default)",            extraArgs: [],                              extraParams: [:]),
            echo("timeout",        "echo --timeout",            extraArgs: ["--timeout", timeoutToken],     extraParams: ["timeout": timeoutToken]),
            echo("verbose",        "echo --verbose",            extraArgs: ["--verbose"],                   extraParams: ["verbose": "true"]),
            echo("count",          "echo --count \(multiCount)",            extraArgs: ["--count", multiCount],          extraParams: ["count": multiCount]),
            echo("count-stats",    "echo --count \(multiCount) --stats",    extraArgs: ["--count", multiCount, "--stats"], extraParams: ["count": multiCount, "stats": "true"]),
            echo("stats",          "echo --stats",              extraArgs: ["--stats"],                     extraParams: ["stats": "true"]),
            echo("count-verbose",  "echo --count \(multiCount) --verbose",  extraArgs: ["--count", multiCount, "--verbose"], extraParams: ["count": multiCount, "verbose": "true"]),
            echo("diagnose",       "echo --diagnose",           extraArgs: ["--diagnose"],                  extraParams: ["diagnose": "true"]),
        ]
    }

    /// Assembles one dicom-echo scenario. Every scenario carries the endpoint
    /// (host/port) plus calling+called AE titles; `extraArgs`/`extraParams` add
    /// the flag(s) under test.
    private static func echo(_ idSuffix: String, _ label: String,
                             extraArgs: [String], extraParams: [String: String]) -> BatchScenario {
        // CLI: positional "HOST" + --port + AE titles, then the flag(s) under test.
        let cliArgs = [hostToken, "--port", portToken,
                       "--aet", aetToken, "--called-aet", calledAETToken] + extraArgs

        // App (Studio): the catalog param map for dicom-echo.
        var studioParams: [String: String] = [
            "host": hostToken, "port": portToken,
            "aet": aetToken, "called-aet": calledAETToken,
        ]
        for (k, v) in extraParams { studioParams[k] = v }

        return BatchScenario(
            scenarioId: "dicom-echo_net_\(idSuffix)",
            toolId: "dicom-echo",
            label: label,
            cliArgs: cliArgs,
            studioParams: studioParams,
            needsInputFile: false, needsSecondFile: false,
            artifactName: nil, artifactKind: "echo-semantic",
            needsDirectory: false,
            fixtureName: nil, fixture2Name: nil,
            userFileAllowed: false,
            fixtureKind: "none",
            resultExitOK: false,
            inputHint: "PACS endpoint")
    }
}
