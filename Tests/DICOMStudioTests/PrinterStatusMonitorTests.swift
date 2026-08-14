// PrinterStatusMonitorTests.swift
// DICOMStudioTests
//
// FR-012 — the background poller. Time and the network are both injected, so
// these assert the monitor's decisions (when to poll, how far to back off, what
// state to publish) rather than waiting on a real clock or a real printer.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMNetwork

// MARK: - Test doubles

/// A probe with scripted answers and a recorded call count.
private actor ScriptedProbe: PrinterStatusProbing {
    enum Answer: Sendable {
        case status(String)
        case failure
    }

    private var answers: [Answer]
    private var callCount = 0
    private let repeatLast: Bool

    init(answers: [Answer], repeatLast: Bool = true) {
        self.answers = answers
        self.repeatLast = repeatLast
    }

    var calls: Int { callCount }

    func probe(profile: PrinterProfile) async throws -> PrinterStatus {
        let index = callCount
        callCount += 1
        let answer: Answer
        if index < answers.count {
            answer = answers[index]
        } else if repeatLast, let last = answers.last {
            answer = last
        } else {
            answer = .failure
        }
        switch answer {
        case .status(let value): return PrinterStatus(status: value)
        case .failure:           throw URLError(.cannotConnectToHost)
        }
    }
}

private func makeProfile(
    monitoring: Bool = true,
    interval: Double = 30
) -> PrinterProfile {
    PrinterProfile(
        name: "Test printer",
        host: "127.0.0.1",
        remoteAETitle: "PRINT_SCP",
        isMonitoringEnabled: monitoring,
        monitoringIntervalSeconds: interval
    )
}

@Suite("Printer status monitor")
struct PrinterStatusMonitorTests {

    // MARK: - Interval clamping

    @Test("Intervals outside the FR-012 range are clamped, never trusted")
    func intervalClamping() {
        // A stored 0 would be a hot loop against a hospital printer.
        #expect(PrinterProfile.clampInterval(0) == 10)
        #expect(PrinterProfile.clampInterval(-5) == 10)
        #expect(PrinterProfile.clampInterval(5) == 10)
        #expect(PrinterProfile.clampInterval(10) == 10)
        #expect(PrinterProfile.clampInterval(30) == 30)
        #expect(PrinterProfile.clampInterval(300) == 300)
        #expect(PrinterProfile.clampInterval(10_000) == 300)
        #expect(PrinterProfile.clampInterval(.nan) == PrinterProfile.defaultMonitoringInterval)
        #expect(PrinterProfile.clampInterval(.infinity) == 300)
    }

    @Test("The initialiser clamps too, so no profile can carry a bad interval")
    func initialiserClamps() {
        #expect(makeProfile(interval: 1).monitoringIntervalSeconds == 10)
        #expect(makeProfile(interval: 9_999).monitoringIntervalSeconds == 300)
    }

    // MARK: - Backoff

    @Test("A healthy printer polls at exactly its configured interval")
    func noBackoffWhenHealthy() {
        let backoff = PrinterStatusBackoff.default
        #expect(backoff.delay(base: 30, consecutiveFailures: 0) == 30)
    }

    @Test("Delay grows with consecutive failures and stops at the ceiling")
    func backoffGrowsAndCaps() {
        let backoff = PrinterStatusBackoff(multiplier: 2, ceilingSeconds: 600)
        #expect(backoff.delay(base: 30, consecutiveFailures: 1) == 60)
        #expect(backoff.delay(base: 30, consecutiveFailures: 2) == 120)
        #expect(backoff.delay(base: 30, consecutiveFailures: 3) == 240)
        // Ceiling holds however long the printer stays down.
        #expect(backoff.delay(base: 30, consecutiveFailures: 10) == 600)
        #expect(backoff.delay(base: 30, consecutiveFailures: 100) == 600)
        #expect(backoff.delay(base: 30, consecutiveFailures: 100_000) == 600)
    }

    @Test("Backoff never returns a non-finite delay")
    func backoffStaysFinite() {
        let backoff = PrinterStatusBackoff(multiplier: 10, ceilingSeconds: 600)
        for failures in [1, 8, 16, 32, 1024, Int.max] {
            let delay = backoff.delay(base: 300, consecutiveFailures: failures)
            #expect(delay.isFinite)
            #expect(delay <= 600)
        }
    }

    // MARK: - Polling outcomes

    @Test("A NORMAL reply publishes online and clears the failure count")
    func normalReplyPublishesOnline() async {
        let probe = ScriptedProbe(answers: [.status("NORMAL")])
        let monitor = PrinterStatusMonitor(probe: probe)
        let update = await monitor.pollOnce(profile: makeProfile())

        #expect(update.connectionStatus == .online)
        #expect(update.consecutiveFailures == 0)
        #expect(update.errorDescription == nil)
        #expect(update.status?.severity == .normal)
    }

    @Test("A WARNING reply stays distinct from a failure reply")
    func warningIsNotError() async {
        let warning = PrinterStatusMonitor(probe: ScriptedProbe(answers: [.status("WARNING")]))
        let failure = PrinterStatusMonitor(probe: ScriptedProbe(answers: [.status("FAILURE")]))

        #expect(await warning.pollOnce(profile: makeProfile()).connectionStatus == .warning)
        #expect(await failure.pollOnce(profile: makeProfile()).connectionStatus == .error)
    }

    @Test("An unreachable printer is offline, not error")
    func unreachableIsOffline() async {
        // "We could not ask" is a different fact from "it said it is broken",
        // and the operator needs to tell them apart.
        let monitor = PrinterStatusMonitor(probe: ScriptedProbe(answers: [.failure]))
        let update = await monitor.pollOnce(profile: makeProfile())

        #expect(update.connectionStatus == .offline)
        #expect(update.consecutiveFailures == 1)
        #expect(update.errorDescription != nil)
    }

    @Test("Consecutive failures accumulate, then reset on the first success")
    func failureCountResets() async {
        let probe = ScriptedProbe(answers: [.failure, .failure, .status("NORMAL")],
                                  repeatLast: false)
        let monitor = PrinterStatusMonitor(probe: probe)
        let profile = makeProfile()

        #expect(await monitor.pollOnce(profile: profile).consecutiveFailures == 1)
        #expect(await monitor.pollOnce(profile: profile).consecutiveFailures == 2)

        let recovered = await monitor.pollOnce(profile: profile)
        #expect(recovered.consecutiveFailures == 0)
        #expect(recovered.connectionStatus == .online)
    }

    // MARK: - Lifecycle

    @Test("sync starts only printers with monitoring enabled")
    func syncStartsEnabledOnly() async {
        let monitor = PrinterStatusMonitor(
            probe: ScriptedProbe(answers: [.status("NORMAL")]),
            sleep: { _ in try await Task.sleep(for: .milliseconds(1)) }
        )
        let on = makeProfile(monitoring: true)
        let off = makeProfile(monitoring: false)

        await monitor.sync(profiles: [on, off])
        let monitored = await monitor.monitoredPrinterIDs

        #expect(monitored.contains(on.id))
        #expect(!monitored.contains(off.id))
        await monitor.stopAll()
    }

    @Test("Disabling a printer stops its loop")
    func syncStopsDisabled() async {
        let monitor = PrinterStatusMonitor(
            probe: ScriptedProbe(answers: [.status("NORMAL")]),
            sleep: { _ in try await Task.sleep(for: .milliseconds(1)) }
        )
        var profile = makeProfile(monitoring: true)
        await monitor.sync(profiles: [profile])
        #expect(await monitor.monitoredPrinterIDs.contains(profile.id))

        profile.isMonitoringEnabled = false
        await monitor.sync(profiles: [profile])
        #expect(await monitor.monitoredPrinterIDs.isEmpty)
    }

    @Test("stopAll leaves nothing running")
    func stopAllClears() async {
        let monitor = PrinterStatusMonitor(
            probe: ScriptedProbe(answers: [.status("NORMAL")]),
            sleep: { _ in try await Task.sleep(for: .milliseconds(1)) }
        )
        await monitor.sync(profiles: [makeProfile(), makeProfile()])
        #expect(await monitor.monitoredPrinterIDs.count == 2)

        await monitor.stopAll()
        #expect(await monitor.monitoredPrinterIDs.isEmpty)
    }

    @Test("A running loop actually polls repeatedly")
    func loopPolls() async throws {
        // Sleep is collapsed to nothing, so the loop spins as fast as the actor
        // allows and we can observe several polls without waiting real seconds.
        let probe = ScriptedProbe(answers: [.status("NORMAL")])
        let monitor = PrinterStatusMonitor(probe: probe, sleep: { _ in })
        await monitor.start(profile: makeProfile())

        var calls = 0
        for _ in 0..<200 {
            calls = await probe.calls
            if calls >= 3 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        await monitor.stopAll()
        #expect(calls >= 3)
    }

    @Test("Updates reach a subscriber")
    func updatesAreStreamed() async throws {
        let monitor = PrinterStatusMonitor(probe: ScriptedProbe(answers: [.status("WARNING")]))
        let profile = makeProfile()
        let stream = await monitor.updates()

        await monitor.pollOnce(profile: profile)

        var received: PrinterStatusUpdate?
        for await update in stream {
            received = update
            break
        }
        #expect(received?.connectionStatus == .warning)
    }

    @Test("A late subscriber is replayed the last known state")
    func lateSubscriberGetsReplay() async throws {
        // A view appearing between polls should show the current state, not
        // "unknown" until the next tick lands.
        let monitor = PrinterStatusMonitor(probe: ScriptedProbe(answers: [.status("NORMAL")]))
        await monitor.pollOnce(profile: makeProfile())

        let stream = await monitor.updates()
        var received: PrinterStatusUpdate?
        for await update in stream {
            received = update
            break
        }
        #expect(received?.connectionStatus == .online)
    }

    // MARK: - Persistence compatibility

    @Test("A profile written before monitoring existed still decodes")
    func legacyProfileDecodes() throws {
        // The exact shape printer-profiles.json had before FR-012.
        let legacy = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Old printer",
          "host": "10.0.0.5",
          "port": 11112,
          "remoteAETitle": "PRINT_SCP",
          "localAETitle": "DICOMSTUDIO",
          "colorMode": "grayscale",
          "timeoutSeconds": 60,
          "status": "UNKNOWN",
          "isDefault": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(PrinterProfile.self, from: legacy)

        #expect(profile.name == "Old printer")
        #expect(!profile.isMonitoringEnabled)
        #expect(profile.monitoringIntervalSeconds == PrinterProfile.defaultMonitoringInterval)
        #expect(profile.lastStatusCheckDate == nil)
    }

    @Test("Monitoring fields survive a round trip")
    func roundTrip() throws {
        var profile = makeProfile(monitoring: true, interval: 45)
        profile.lastStatusDetail = "Warning — SUPPLY LOW"
        profile.lastStatusCheckDate = Date(timeIntervalSince1970: 1_700_000_000)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            PrinterProfile.self, from: try encoder.encode(profile))

        #expect(decoded.isMonitoringEnabled)
        #expect(decoded.monitoringIntervalSeconds == 45)
        #expect(decoded.lastStatusDetail == "Warning — SUPPLY LOW")
        #expect(decoded.lastStatusCheckDate == profile.lastStatusCheckDate)
    }

    @Test("An out-of-range stored interval is clamped on decode")
    func storedIntervalClampedOnDecode() throws {
        let hostile = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Hand-edited",
          "host": "10.0.0.5",
          "port": 11112,
          "remoteAETitle": "PRINT_SCP",
          "localAETitle": "DICOMSTUDIO",
          "colorMode": "grayscale",
          "timeoutSeconds": 60,
          "status": "UNKNOWN",
          "isDefault": false,
          "isMonitoringEnabled": true,
          "monitoringIntervalSeconds": 0.001
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(PrinterProfile.self, from: hostile)
        #expect(profile.monitoringIntervalSeconds == 10)
    }
}
