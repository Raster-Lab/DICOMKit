// PrintQueueAuditTests.swift
// DICOMStudioTests
//
// The app-side print queue and audit trail: job state transitions under user
// control (start, stop, pause, resume, resend), and the audit trail's
// recording and persistence. The queue is held paused throughout, so no test
// ever opens an association.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMPrintKit

@MainActor
@Suite("Print queue and audit trail")
struct PrintQueueAuditTests {

    /// A queue held paused, backed by a throwaway audit store.
    private func makeQueue() -> (PrintQueueService, PrintAuditTrail, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-queue-\(UUID().uuidString)", isDirectory: true)
        let storage = PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory))
        let trail = PrintAuditTrail(storage: storage)
        let queue = PrintQueueService(audit: trail)
        queue.pauseQueue()   // nothing may actually run in tests
        return (queue, trail, directory)
    }

    private func makePayload() -> PrintQueuePayload {
        PrintQueuePayload(
            items: [],
            request: PrintJobRequest(),
            profile: PrinterProfile(name: "Test Printer", host: "127.0.0.1",
                                    remoteAETitle: "PRINT_SCP")
        )
    }

    @discardableResult
    private func enqueue(_ queue: PrintQueueService) -> UUID {
        queue.enqueue(payload: makePayload(), imageCount: 4, filmCount: 1,
                      copies: 1, layout: "2×2")
    }

    private func job(_ queue: PrintQueueService, _ id: UUID) -> PrintQueueJob? {
        queue.jobs.first { $0.id == id }
    }

    // MARK: - Submission

    @Test("An enqueued job waits as pending while the queue is paused")
    func enqueuePending() {
        let (queue, trail, _) = makeQueue()
        let id = enqueue(queue)

        #expect(job(queue, id)?.state == .pending)
        #expect(queue.runningJobID == nil)
        #expect(trail.events.first?.action == .jobSubmitted)
        #expect(trail.events.first?.jobID == id)
        #expect(trail.events.first?.printerName == "Test Printer")
    }

    // MARK: - Pause / resume / stop

    @Test("Pausing holds a pending job and resuming releases it")
    func pauseResumeJob() {
        let (queue, trail, _) = makeQueue()
        let id = enqueue(queue)

        queue.pause(id)
        #expect(job(queue, id)?.state == .paused)
        #expect(trail.events.first?.action == .jobPaused)

        queue.resume(id)
        #expect(job(queue, id)?.state == .pending)
        #expect(trail.events.first?.action == .jobResumed)
    }

    @Test("Stopping a waiting job takes it out of the line")
    func stopPendingJob() {
        let (queue, trail, _) = makeQueue()
        let id = enqueue(queue)

        queue.stop(id)
        #expect(job(queue, id)?.state == .stopped)
        #expect(trail.events.first?.action == .jobStopped)

        // Stopping again is a no-op, not a second audit event.
        let count = trail.events.count
        queue.stop(id)
        #expect(trail.events.count == count)
    }

    @Test("Stopping a job that never ran still reports the outcome")
    func stopPendingJobNotifiesHandlers() {
        let (queue, _, _) = makeQueue()

        // The print sheet's only exit is this handler, so a job stopped before
        // it ran has to fire it too — otherwise the sheet stays on "Working…".
        var outcomes: [PrintQueueOutcome] = []
        let id = queue.enqueue(
            payload: makePayload(), imageCount: 4, filmCount: 1, copies: 1, layout: "2×2",
            handlers: PrintQueueJobHandlers(onFinish: { outcomes.append($0) })
        )

        queue.stop(id)

        #expect(outcomes.count == 1)
        if case .cancelled = outcomes.first {} else {
            Issue.record("expected .cancelled, got \(String(describing: outcomes.first))")
        }

        // Handlers are released, so a second stop cannot report twice.
        queue.stop(id)
        #expect(outcomes.count == 1)
    }

    // MARK: - Activity summary

    @Test("An idle, empty queue labels itself with nothing")
    func activitySummaryIdle() {
        let (queue, _, _) = makeQueue()
        #expect(queue.activitySummary == nil)
    }

    @Test("Waiting jobs are counted, and read as held while the queue is paused")
    func activitySummaryCountsWaiting() {
        let (queue, _, _) = makeQueue()   // makeQueue() pauses the queue
        let first = enqueue(queue)
        enqueue(queue)

        #expect(queue.activitySummary == "2 Held")

        // Stopping one leaves a single job still holding up the line.
        queue.stop(first)
        #expect(queue.activitySummary == "1 Held")
    }

    @Test("A running job outranks whatever is still queued behind it")
    func activitySummaryPrefersRunning() {
        let (queue, _, _) = makeQueue()
        enqueue(queue)
        enqueue(queue)

        // Resuming starts the head of the line — it fails later against a
        // printer that is not there, but it is running now, and that is what
        // the label has to say.
        queue.resumeQueue()
        #expect(queue.runningJobID != nil)
        #expect(queue.activitySummary == "Printing")
    }

    @Test("A stopped job is not a failure — it was the user's own doing")
    func activitySummaryIgnoresStopped() {
        let (queue, _, _) = makeQueue()
        let id = enqueue(queue)

        queue.stop(id)
        #expect(queue.activitySummary == nil)

        queue.remove(id)
        #expect(queue.activitySummary == nil)
    }

    @Test("A job that ran and failed keeps saying so until it is cleared")
    func activitySummaryReportsFailure() async throws {
        let (queue, _, _) = makeQueue()
        queue.maxAutoRetries = 0   // this test is about the *failed* label
        let id = enqueue(queue)

        // The payload names a printer that is not there, so resuming runs the
        // job through to a genuine failure rather than a simulated one.
        queue.resumeQueue()
        var waited = 0
        while queue.runningJobID != nil, waited < 200 {
            try await Task.sleep(for: .milliseconds(25))
            waited += 1
        }

        let state = queue.jobs.first { $0.id == id }?.state
        if case .failed = state {
            #expect(queue.activitySummary == "Failed")
            queue.remove(id)
            #expect(queue.activitySummary == nil)
        } else {
            Issue.record("expected the job to fail against an absent printer, got \(String(describing: state))")
        }
    }

    @Test("Start Now moves a held job to the front of the waiting line")
    func startNowReorders() {
        let (queue, _, _) = makeQueue()
        let first = enqueue(queue)
        let second = enqueue(queue)

        queue.start(second)
        #expect(queue.jobs.map(\.id) == [second, first])
        // The queue is paused, so nothing may actually have started.
        #expect(queue.runningJobID == nil)
        #expect(job(queue, second)?.state == .pending)
    }

    // MARK: - Resend

    @Test("Resending a stopped job enqueues a fresh attempt of the same payload")
    func resendStoppedJob() {
        let (queue, trail, _) = makeQueue()
        let id = enqueue(queue)
        queue.stop(id)

        let resent = queue.resend(id)
        #expect(resent != nil)
        #expect(resent != id)
        let newJob = queue.jobs.first { $0.id == resent }
        #expect(newJob?.state == .pending)
        #expect(newJob?.attempt == 2)
        #expect(newJob?.printerName == "Test Printer")
        #expect(trail.events.first?.action == .jobResent)

        // The original stays as the record of its run.
        #expect(job(queue, id)?.state == .stopped)
    }

    @Test("A waiting job cannot be resent — it has not run")
    func resendPendingIsRefused() {
        let (queue, _, _) = makeQueue()
        let id = enqueue(queue)
        #expect(queue.resend(id) == nil)
        #expect(queue.jobs.count == 1)
    }

    // MARK: - Remove / clear

    @Test("Removing a job deletes it and records the removal")
    func removeJob() {
        let (queue, trail, _) = makeQueue()
        let id = enqueue(queue)
        queue.stop(id)

        queue.remove(id)
        #expect(queue.jobs.isEmpty)
        #expect(trail.events.first?.action == .jobRemoved)
    }

    @Test("Clear Finished keeps waiting jobs and drops finished ones")
    func clearFinished() {
        let (queue, trail, _) = makeQueue()
        let waiting = enqueue(queue)
        let stopped = enqueue(queue)
        queue.stop(stopped)

        queue.clearFinished()
        #expect(queue.jobs.map(\.id) == [waiting])
        #expect(trail.events.first?.action == .queueCleared)
    }

    // MARK: - Queue-level control

    @Test("Queue pause and resume flip the flag and are audited")
    func queuePauseResume() {
        let (queue, trail, _) = makeQueue()   // makeQueue already paused it
        #expect(queue.isPaused)
        #expect(trail.events.first?.action == .queuePaused)

        queue.resumeQueue()
        #expect(!queue.isPaused)
        #expect(trail.events.first?.action == .queueResumed)

        // Pausing an already-paused queue records nothing twice.
        queue.pauseQueue()
        let count = trail.events.count
        queue.pauseQueue()
        #expect(trail.events.count == count)
    }

    @Test("Stop All stops every waiting job")
    func stopAll() {
        let (queue, trail, _) = makeQueue()
        let first = enqueue(queue)
        let second = enqueue(queue)
        queue.pause(second)

        queue.stopAll()
        #expect(job(queue, first)?.state == .stopped)
        #expect(job(queue, second)?.state == .stopped)
        #expect(trail.events.first?.action == .queueStopped)
    }

    // MARK: - Audit trail persistence

    // MARK: - Persistence and restore

    /// A queue backed by a throwaway on-disk store.
    private func makeStoredQueue(directory: URL) -> (PrintQueueService, PrintQueueStorageService) {
        let storage = PrintQueueStorageService(
            storageService: StorageService(baseDirectory: directory))
        let trail = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        let queue = PrintQueueService(audit: trail, storage: storage)
        queue.pauseQueue()
        return (queue, storage)
    }

    private func throwawayDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-queue-store-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("A pending job survives a relaunch, and the restored queue is held")
    func queuePersistsAcrossRelaunch() throws {
        let directory = throwawayDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // The payload references a file that exists, so restore keeps it.
        let source = directory.appendingPathComponent("frame.dcm")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: source)

        let (queue, storage) = makeStoredQueue(directory: directory)
        let payload = PrintQueuePayload(
            items: [PrintSelectionItem(filePath: source.path)],
            request: PrintJobRequest(),
            profile: PrinterProfile(name: "P", host: "127.0.0.1", remoteAETitle: "AE"))
        let id = queue.enqueue(payload: payload, imageCount: 1, filmCount: 1,
                               copies: 2, layout: "1×1")

        // "Relaunch": a fresh service instance over the same file.
        let trail2 = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        let reloaded = PrintQueueService(audit: trail2, storage: storage)

        #expect(reloaded.jobs.count == 1)
        #expect(reloaded.jobs.first?.id == id)
        #expect(reloaded.jobs.first?.state == .pending)
        #expect(reloaded.jobs.first?.copies == 2)
        #expect(reloaded.jobs.first?.payload.items.first?.filePath == source.path)
        // A restored queue never prints on its own — it waits to be resumed.
        #expect(reloaded.isPaused)
    }

    @Test("A job that was printing when the app died restores as failed")
    func interruptedJobRestoresFailed() throws {
        let directory = throwawayDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (queue, storage) = makeStoredQueue(directory: directory)
        enqueue(queue)

        // Rewrite the stored state to .running, as a crash mid-print leaves it.
        var saved = storage.load()
        var job = saved.jobs[0]
        job.state = .running
        saved = PersistedPrintQueue(jobs: [job], isPaused: false)
        try storage.save(saved)

        let trail2 = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        let reloaded = PrintQueueService(audit: trail2, storage: storage)
        if case .failed(let message)? = reloaded.jobs.first?.state {
            #expect(message.contains("Interrupted"))
        } else {
            Issue.record("expected .failed, got \(String(describing: reloaded.jobs.first?.state))")
        }
    }

    @Test("A restored job whose source file is gone fails at restore, not at print")
    func missingSourceFailsAtRestore() {
        let directory = throwawayDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (queue, storage) = makeStoredQueue(directory: directory)
        let payload = PrintQueuePayload(
            items: [PrintSelectionItem(filePath: "/nonexistent/frame.dcm")],
            request: PrintJobRequest(),
            profile: PrinterProfile(name: "P", host: "127.0.0.1", remoteAETitle: "AE"))
        queue.enqueue(payload: payload, imageCount: 1, filmCount: 1, copies: 1, layout: "1×1")

        let trail2 = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        let reloaded = PrintQueueService(audit: trail2, storage: storage)
        if case .failed(let message)? = reloaded.jobs.first?.state {
            #expect(message.contains("missing"))
        } else {
            Issue.record("expected .failed, got \(String(describing: reloaded.jobs.first?.state))")
        }
    }

    // MARK: - Reorder

    @Test("Move reorders the waiting line")
    func moveReorders() {
        let (queue, _, _) = makeQueue()
        let first = enqueue(queue)
        let second = enqueue(queue)
        let third = enqueue(queue)

        queue.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(queue.jobs.map(\.id) == [third, first, second])
    }

    // MARK: - Automatic retry (SRS §8.2 FAILED → RETRYING)

    @Test("A thrown failure retries up to the cap, then fails for good")
    func automaticRetry() async throws {
        let (queue, trail, _) = makeQueue()
        queue.maxAutoRetries = 1
        queue.retryDelay = 0.05
        // An unreadable source file makes preparation *throw* — the fault kind
        // that retries. (A printer rejection is final and must not retry.)
        let payload = PrintQueuePayload(
            items: [PrintSelectionItem(filePath: "/nonexistent/frame.dcm")],
            request: PrintJobRequest(),
            profile: PrinterProfile(name: "P", host: "127.0.0.1", remoteAETitle: "AE"))
        let id = queue.enqueue(payload: payload, imageCount: 1, filmCount: 1,
                               copies: 1, layout: "1×1")

        queue.resumeQueue()
        var waited = 0
        while !(queue.jobs.first?.state.isFinished ?? false), waited < 400 {
            try await Task.sleep(for: .milliseconds(25))
            waited += 1
        }

        let job = try #require(queue.jobs.first { $0.id == id })
        if case .failed = job.state {} else {
            Issue.record("expected .failed after retries, got \(job.state)")
        }
        // attempt 2 = the original send plus exactly one automatic retry.
        #expect(job.attempt == 2)
        #expect(trail.events.contains { $0.action == .jobRetried })
    }

    // MARK: - Offline auto-queue (FR-012)

    @Test("A job for an offline printer waits instead of failing")
    func offlineJobWaits() async throws {
        let (queue, _, _) = makeQueue()
        var printerIsUp = false
        queue.isPrinterReady = { _ in printerIsUp }
        queue.maxAutoRetries = 0
        let id = enqueue(queue)
        queue.resumeQueue()

        // The gate held it: still pending, saying why, nothing running.
        #expect(queue.jobs.first?.state == .pending)
        #expect(queue.runningJobID == nil)
        #expect(queue.jobs.first?.progressMessage.contains("come online") == true)

        // The printer comes back; reevaluate is the monitor's signal.
        printerIsUp = true
        queue.reevaluate()
        var waited = 0
        while !(queue.jobs.first?.state.isFinished ?? false), waited < 200 {
            try await Task.sleep(for: .milliseconds(25))
            waited += 1
        }
        // It ran (and failed against the absent printer) — the point is it left pending.
        #expect(queue.jobs.first { $0.id == id }?.state.isFinished == true)
    }

    @Test("The audit trail survives a relaunch")
    func auditPersistence() {
        let (_, trail, directory) = makeQueue()
        trail.record(.jobSubmitted, printerName: "Persisted", detail: "2 image(s)")

        let reloaded = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        #expect(reloaded.events.count == trail.events.count)
        #expect(reloaded.events.first?.action == .jobSubmitted)
        #expect(reloaded.events.first?.printerName == "Persisted")
    }

    @Test("Every event carries the compliance fields and chains to the last")
    func auditComplianceFields() {
        let (_, trail, _) = makeQueue()
        trail.record(.jobSubmitted, printerName: "P", detail: "first")
        trail.record(.jobStarted, printerName: "P", detail: "second",
                     beforeState: "Pending", afterState: "Submitting")

        let newest = trail.events[0]
        #expect(newest.sessionID == PrintAuditTrail.sessionID)
        #expect(newest.source == PrintAuditTrail.source)
        #expect(newest.beforeState == "Pending")
        #expect(newest.afterState == "Submitting")
        // The chain: newest links to the one before it.
        #expect(newest.previousHash == trail.events[1].entryHash)
        #expect(newest.entryHash != nil)
        #expect(trail.verifyIntegrity() == nil)
    }

    @Test("Tampering with a recorded event breaks the chain, visibly")
    func auditTamperDetection() throws {
        let (_, trail, directory) = makeQueue()
        trail.record(.jobSubmitted, printerName: "P", detail: "genuine detail")
        trail.record(.jobCompleted, printerName: "P", detail: "done")

        // Edit the older event's detail on disk, as an outside tamperer would.
        let file = PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)).fileURL
        let text = try String(contentsOf: file, encoding: .utf8)
            .replacingOccurrences(of: "genuine detail", with: "doctored detail")
        try text.write(to: file, atomically: true, encoding: .utf8)

        let reloaded = PrintAuditTrail(storage: PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory)))
        #expect(reloaded.verifyIntegrity() != nil)
    }

    @Test("CSV export has a header and one row per event")
    func auditCSVExport() throws {
        let (_, trail, _) = makeQueue()
        trail.record(.jobSubmitted, printerName: "Has, comma", detail: "quote \" inside")

        let csv = try #require(String(data: trail.csvExportData(), encoding: .utf8))
        let lines = csv.split(separator: "\n")
        #expect(lines.first?.hasPrefix("date,action,printer") == true)
        #expect(lines.count == 1 + trail.events.count)
        #expect(csv.contains("\"Has, comma\""))
        #expect(csv.contains("\"quote \"\" inside\""))
    }

    @Test("Export encodes the same events the store holds")
    func auditExport() throws {
        let (_, trail, _) = makeQueue()
        trail.record(.jobCompleted, printerName: "Exported", detail: "done")

        let data = try trail.exportData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([PrintAuditEvent].self, from: data)
        // ISO 8601 keeps whole seconds, so dates are compared to that precision.
        #expect(decoded.map(\.id) == trail.events.map(\.id))
        #expect(decoded.map(\.action) == trail.events.map(\.action))
        #expect(decoded.map(\.detail) == trail.events.map(\.detail))
        #expect(decoded.map(\.printerName) == trail.events.map(\.printerName))
    }

    @Test("Retention is by age, not count — old events leave, stale failure detail is redacted")
    func auditTieredRetention() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("audit-retention-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = PrintAuditTrailStorageService(
            storageService: StorageService(baseDirectory: directory))

        // Handwrite a trail: one 8-year-old event (past the 7y tier), one
        // 2-year-old failure (its detail is past the 1y tier), one fresh event.
        let ancient = PrintAuditEvent(
            date: Date(timeIntervalSinceNow: -8 * 365.25 * 24 * 3600),
            action: .jobSubmitted, detail: "ancient")
        let staleFailure = PrintAuditEvent(
            date: Date(timeIntervalSinceNow: -2 * 365.25 * 24 * 3600),
            action: .jobFailed, detail: "connection refused")
        let fresh = PrintAuditEvent(action: .jobCompleted, detail: "printed")
        try storage.save([fresh, staleFailure, ancient])

        let trail = PrintAuditTrail(storage: storage)

        #expect(!trail.events.contains { $0.detail == "ancient" })
        let failure = trail.events.first { $0.action == .jobFailed }
        #expect(failure != nil)                    // the *event* stays…
        #expect(failure?.detail.isEmpty == true)   // …its detail is gone
        #expect(trail.events.contains { $0.detail == "printed" })
        // The rewrite is itself on the record, and the re-chained trail verifies.
        #expect(trail.events.contains { $0.action == .retentionApplied })
        #expect(trail.verifyIntegrity() == nil)

        // A count well past the old 500 cap survives — no count truncation.
        for index in 0..<600 { trail.record(.jobSubmitted, detail: "bulk \(index)") }
        #expect(trail.events.count > 500)
    }

    // MARK: - History wiring

    @Test("Clearing the job history is recorded in the audit trail")
    func clearHistoryAudited() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-history-audit-\(UUID().uuidString)", isDirectory: true)
        let storageService = StorageService(baseDirectory: directory)
        let historyStorage = PrintJobHistoryStorageService(storageService: storageService)
        try historyStorage.save([PrintJobHistoryEntry(
            printerName: "P", imageCount: 1, filmCount: 1, copies: 1,
            layout: "1×1", success: true)])

        let model = PrintViewModel(
            printerStorage: PrinterProfileStorageService(storageService: storageService),
            historyStorage: historyStorage,
            auditStorage: PrintAuditTrailStorageService(storageService: storageService))
        #expect(model.history.count == 1)

        model.clearHistory()
        #expect(model.history.isEmpty)
        #expect(model.auditTrail.events.first?.action == .historyCleared)
        #expect(model.auditTrail.events.first?.detail.contains("1 entry") == true)
    }
}
