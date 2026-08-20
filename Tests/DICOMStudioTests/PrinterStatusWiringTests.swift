// PrinterStatusWiringTests.swift
// DICOMStudioTests
//
// FR-012 — the seam between the background monitor and the print screen. The
// monitor is tested on its own elsewhere; these cover what the view model does
// with an update once it arrives, and that printer edits reach the monitor.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMNetwork
@testable import DICOMPrintKit

@MainActor
@Suite("Printer status wiring")
struct PrinterStatusWiringTests {

    /// A view model backed by a throwaway storage directory.
    private func makeViewModel() throws -> (PrintViewModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fr012-\(UUID().uuidString)", isDirectory: true)
        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let model = PrintViewModel(printerStorage: storage)
        return (model, directory)
    }

    private func makeProfile(name: String = "Printer") -> PrinterProfile {
        PrinterProfile(name: name, host: "127.0.0.1", remoteAETitle: "PRINT_SCP")
    }

    // MARK: - Applying updates

    @Test("A warning update lands on the printer row as warning, not error")
    func warningUpdateApplied() throws {
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = makeProfile()
        model.save(profile)

        model.apply(PrinterStatusUpdate(
            printerID: profile.id,
            connectionStatus: .warning,
            status: PrinterStatus(status: "WARNING", statusInfo: "SUPPLY LOW"),
            checkedAt: Date()
        ))

        let stored = try #require(model.printers.first { $0.id == profile.id })
        #expect(stored.status == .warning)
        #expect(stored.lastStatusDetail?.contains("SUPPLY LOW") == true)
        #expect(stored.lastStatusCheckDate != nil)
    }

    @Test("A successful poll counts as verification; a failed one does not")
    func verificationOnlyOnSuccess() throws {
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = makeProfile()
        model.save(profile)

        model.apply(PrinterStatusUpdate(
            printerID: profile.id,
            connectionStatus: .offline,
            errorDescription: "Connection refused",
            checkedAt: Date(),
            consecutiveFailures: 1
        ))
        var stored = try #require(model.printers.first { $0.id == profile.id })
        #expect(stored.status == .offline)
        // A printer we could not reach has not been verified.
        #expect(stored.lastVerifiedDate == nil)
        #expect(stored.lastStatusCheckDate != nil)

        model.apply(PrinterStatusUpdate(
            printerID: profile.id,
            connectionStatus: .online,
            status: PrinterStatus(status: "NORMAL"),
            checkedAt: Date()
        ))
        stored = try #require(model.printers.first { $0.id == profile.id })
        #expect(stored.lastVerifiedDate != nil)
    }

    @Test("An update for an unknown printer is ignored rather than crashing")
    func unknownPrinterIgnored() throws {
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        model.save(makeProfile())
        let before = model.printers

        model.apply(PrinterStatusUpdate(
            printerID: UUID(),
            connectionStatus: .online,
            checkedAt: Date()
        ))

        #expect(model.printers == before)
    }

    @Test("Only the selected printer's status reaches the detail pane")
    func selectedPrinterDrivesDetailPane() throws {
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = makeProfile(name: "First")
        let second = makeProfile(name: "Second")
        model.save(first)
        model.save(second)
        model.selectedPrinterID = first.id

        // An update for the printer nobody is looking at must not repaint the pane.
        model.apply(PrinterStatusUpdate(
            printerID: second.id,
            connectionStatus: .error,
            status: PrinterStatus(status: "FAILURE"),
            checkedAt: Date()
        ))
        #expect(model.printerStatus == nil)

        model.apply(PrinterStatusUpdate(
            printerID: first.id,
            connectionStatus: .warning,
            status: PrinterStatus(status: "WARNING"),
            checkedAt: Date()
        ))
        #expect(model.printerStatus?.severity == .warning)
    }

    @Test("Polled status is not written back to disk")
    func statusIsNotPersisted() throws {
        // Observed state, not configuration: persisting it would rewrite
        // printer-profiles.json every few seconds per monitored printer.
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let profile = makeProfile()
        model.save(profile)

        model.apply(PrinterStatusUpdate(
            printerID: profile.id,
            connectionStatus: .warning,
            status: PrinterStatus(status: "WARNING"),
            checkedAt: Date()
        ))

        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let onDisk = try #require(storage.load().first { $0.id == profile.id })
        #expect(onDisk.status == .unknown)
        #expect(onDisk.lastStatusDetail == nil)
    }

    // MARK: - Monitor lifecycle

    @Test("Saving a monitored printer starts polling it")
    func savingEnabledPrinterStartsMonitoring() async throws {
        let (model, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let monitor = PrinterStatusMonitor(
            probe: StubProbe(), sleep: { _ in try await Task.sleep(for: .milliseconds(1)) })
        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let wired = PrintViewModel(printerStorage: storage, statusMonitor: monitor)
        wired.startMonitoring()

        var profile = makeProfile()
        profile.isMonitoringEnabled = true
        let printerID = profile.id
        wired.save(profile)

        try await waitUntil { await monitor.monitoredPrinterIDs.contains(printerID) }
        #expect(await monitor.monitoredPrinterIDs.contains(printerID))

        wired.stopMonitoring()
    }

    @Test("stopMonitoring halts every loop")
    func stopMonitoringHaltsAll() async throws {
        let (_, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let monitor = PrinterStatusMonitor(
            probe: StubProbe(), sleep: { _ in try await Task.sleep(for: .milliseconds(1)) })
        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let model = PrintViewModel(printerStorage: storage, statusMonitor: monitor)
        model.startMonitoring()

        var profile = makeProfile()
        profile.isMonitoringEnabled = true
        let printerID = profile.id
        model.save(profile)
        try await waitUntil { await monitor.monitoredPrinterIDs.contains(printerID) }

        model.stopMonitoring()
        try await waitUntil { await monitor.monitoredPrinterIDs.isEmpty }
        #expect(await monitor.monitoredPrinterIDs.isEmpty)
    }

    // MARK: - Queue-driven monitoring

    /// The bug this guards against: a job submitted from the film screen was
    /// held for its offline printer, but polling only ran while the print
    /// screen was open — so nothing ever called `reevaluate()` and the job sat
    /// in the queue until the user happened to focus that screen.
    @Test("A held job keeps its printer polled with no print screen open")
    func waitingJobKeepsPrinterPolled() async throws {
        let (_, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let probe = UnreachableProbe()
        let monitor = PrinterStatusMonitor(
            probe: probe, sleep: { _ in try await Task.sleep(for: .milliseconds(1)) })
        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let model = PrintViewModel(printerStorage: storage, statusMonitor: monitor)
        // The print screen is never opened: startMonitoring() is not called.

        var editable = makeProfile()
        editable.isMonitoringEnabled = true
        let profile = editable
        model.save(profile)
        // The last thing the monitor saw, some time ago: offline. The gate
        // holds the job on this.
        model.apply(PrinterStatusUpdate(
            printerID: profile.id, connectionStatus: .offline,
            errorDescription: "Connection refused", checkedAt: Date()))

        let id = model.queue.enqueue(
            payload: PrintQueuePayload(items: [], request: PrintJobRequest(),
                                       profile: profile),
            imageCount: 1, filmCount: 1, copies: 1, layout: "1×1")

        // Held, not failed — and its printer is being watched for it.
        #expect(model.queue.jobs.first { $0.id == id }?.state == .pending)
        try await waitUntil { await monitor.monitoredPrinterIDs.contains(profile.id) }
        #expect(await monitor.monitoredPrinterIDs.contains(profile.id))

        // Submission also probed immediately, rather than waiting out the poll
        // loop's jittered first tick.
        try await waitUntil { await probe.count > 0 }
        #expect(await probe.count > 0)

        // The queue draining ends the claim, so a backgrounded app is not
        // holding associations open on printers no job is waiting for.
        model.queue.stop(id)
        try await waitUntil { await monitor.monitoredPrinterIDs.isEmpty }
        #expect(await monitor.monitoredPrinterIDs.isEmpty)
    }

    @Test("A paused queue demands no polling")
    func pausedQueueDemandsNoPolling() async throws {
        let (_, directory) = try makeViewModel()
        defer { try? FileManager.default.removeItem(at: directory) }

        let monitor = PrinterStatusMonitor(
            probe: UnreachableProbe(),
            sleep: { _ in try await Task.sleep(for: .milliseconds(1)) })
        let storage = PrinterProfileStorageService(
            storageService: StorageService(baseDirectory: directory))
        let model = PrintViewModel(printerStorage: storage, statusMonitor: monitor)

        var profile = makeProfile()
        profile.isMonitoringEnabled = true
        model.save(profile)
        model.queue.pauseQueue()

        model.queue.enqueue(
            payload: PrintQueuePayload(items: [], request: PrintJobRequest(),
                                       profile: profile),
            imageCount: 1, filmCount: 1, copies: 1, layout: "1×1")

        // A held queue starts nothing, so its jobs' printers need no watching.
        try await Task.sleep(for: .milliseconds(50))
        #expect(await monitor.monitoredPrinterIDs.isEmpty)
    }

    // MARK: - Probe timeout

    @Test("An interactive probe does not inherit the long print timeout")
    func probeTimeoutIsClamped() {
        var profile = makeProfile()
        profile.timeoutSeconds = 60

        #expect(profile.printConfiguration().timeout == 60)
        #expect(profile.printConfiguration(probe: true).timeout
            == PrinterProfile.probeTimeoutCeiling)
    }

    @Test("A profile set below the probe ceiling keeps its shorter timeout")
    func probeTimeoutKeepsShorterValue() {
        var profile = makeProfile()
        profile.timeoutSeconds = 5

        #expect(profile.printConfiguration(probe: true).timeout == 5)
    }

    /// Polls a condition rather than sleeping a fixed time, so the test is not
    /// racing a timer under load.
    private func waitUntil(
        _ condition: @Sendable () async -> Bool,
        attempts: Int = 200
    ) async throws {
        for _ in 0..<attempts {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// Always reports a healthy printer.
private struct StubProbe: PrinterStatusProbing {
    func probe(profile: PrinterProfile) async throws -> PrinterStatus {
        PrinterStatus(status: "NORMAL")
    }
}

/// Never reachable, and counts the attempts. Keeps a held job held: were the
/// probe to answer, the queue would release the job into a real print run.
private actor UnreachableProbe: PrinterStatusProbing {
    private(set) var count = 0
    func probe(profile: PrinterProfile) async throws -> PrinterStatus {
        count += 1
        throw URLError(.cannotConnectToHost)
    }
}
