// PrintQueueService.swift
// DICOMStudio
//
// DICOM Studio — the app-side print queue. Submitted jobs line up here and are
// executed one at a time, so two jobs never interleave associations on the same
// printer. Queue management (start, stop, pause, resume, resend) is an app
// responsibility — no protocol logic lives here; execution is delegated to
// PrintService, and every transition is recorded in the audit trail.

import Foundation
import Observation
import DICOMNetwork
import DICOMPrintKit

/// Everything a queued job needs to run — captured at submission time, so the
/// job prints what was on the film when it was submitted, and "Resend" can run
/// the identical job again even after the sheet has moved on.
public struct PrintQueuePayload: Sendable, Codable {
    public let items: [PrintSelectionItem]
    public let request: PrintJobRequest
    public let profile: PrinterProfile
    public let useViewerWindow: Bool
    public let useViewerPresentation: Bool
    public let annotations: [String: PrintCornerAnnotation]
    public let annotationStyle: PrintAnnotationStyle
    public let drawnAnnotations: [String: [PrintOverlayAnnotation]]

    public init(
        items: [PrintSelectionItem],
        request: PrintJobRequest,
        profile: PrinterProfile,
        useViewerWindow: Bool = true,
        useViewerPresentation: Bool = true,
        annotations: [String: PrintCornerAnnotation] = [:],
        annotationStyle: PrintAnnotationStyle = .automatic,
        drawnAnnotations: [String: [PrintOverlayAnnotation]] = [:]
    ) {
        self.items = items
        self.request = request
        self.profile = profile
        self.useViewerWindow = useViewerWindow
        self.useViewerPresentation = useViewerPresentation
        self.annotations = annotations
        self.annotationStyle = annotationStyle
        self.drawnAnnotations = drawnAnnotations
    }
}

/// One job in the queue.
public struct PrintQueueJob: Identifiable, Sendable, Codable {

    /// Where the job is in its life. The names follow SRS §6.2's JobStatus.
    public enum State: Sendable, Equatable, Codable {
        /// Waiting its turn.
        case pending
        /// Picked up: association setup and image preparation (SUBMITTING).
        case submitting
        /// The film is going over the wire right now (PRINTING).
        case running
        /// Held by the user; the processor skips it until resumed.
        case paused
        /// Cancelled by the user before it finished.
        case stopped
        /// Failed, and the queue will send it again (RETRYING).
        case retrying(String)
        /// Ran and did not print.
        case failed(String)
        /// Ran and printed.
        case completed

        public var displayName: String {
            switch self {
            case .pending:    return "Pending"
            case .submitting: return "Submitting"
            case .running:    return "Printing"
            case .paused:     return "Paused"
            case .stopped:    return "Stopped"
            case .retrying:   return "Retrying"
            case .failed:     return "Failed"
            case .completed:  return "Completed"
            }
        }

        /// Whether the job has finished, one way or another.
        public var isFinished: Bool {
            switch self {
            case .stopped, .failed, .completed:                        return true
            case .pending, .submitting, .running, .paused, .retrying:  return false
            }
        }

        /// Whether the job is on the printer right now, in either phase.
        public var isActive: Bool {
            self == .submitting || self == .running
        }

        /// Whether the job is waiting for the processor to pick it up.
        public var isWaiting: Bool {
            switch self {
            case .pending, .paused, .retrying: return true
            default:                           return false
            }
        }
    }

    public let id: UUID
    /// When the job entered the queue.
    public let createdDate: Date
    /// The captured inputs the job runs with.
    public let payload: PrintQueuePayload

    // Display metadata, captured at submission so the row reads the same after
    // the printer profile or selection changes.
    public let printerName: String
    public let imageCount: Int
    public let filmCount: Int
    public let copies: Int
    public let layout: String

    public var state: State = .pending
    /// Fraction complete, 0...1, while running.
    public var progress: Double = 0
    /// The most recent progress or status message.
    public var progressMessage: String = ""
    /// Result of the run, once there is one.
    public var result: PrintResult?
    /// How many times this payload has been sent (resend and retry re-enqueue).
    public var attempt: Int = 1

    /// What survives a restart. `result` is deliberately absent: it wraps DIMSE
    /// types with no JSON form, and a restored job re-runs rather than reports —
    /// the job history file is the durable record of past outcomes.
    private enum CodingKeys: String, CodingKey {
        case id, createdDate, payload, printerName, imageCount, filmCount,
             copies, layout, state, progress, progressMessage, attempt
    }

    public init(
        id: UUID = UUID(),
        createdDate: Date = Date(),
        payload: PrintQueuePayload,
        printerName: String,
        imageCount: Int,
        filmCount: Int,
        copies: Int,
        layout: String
    ) {
        self.id = id
        self.createdDate = createdDate
        self.payload = payload
        self.printerName = printerName
        self.imageCount = imageCount
        self.filmCount = filmCount
        self.copies = copies
        self.layout = layout
    }

    /// One-line summary for the queue list.
    public var summary: String {
        let films = filmCount == 1 ? "1 film" : "\(filmCount) films"
        let copiesText = copies > 1 ? " × \(copies)" : ""
        return "\(printerName) — \(imageCount) image(s), \(films)\(copiesText), \(layout)"
    }
}

/// How a queue job ended.
public enum PrintQueueOutcome: Sendable {
    /// The workflow ran to completion (the result itself may report failure).
    case finished(PrintResult, preparedImageCount: Int)
    /// The workflow threw.
    case failed(String)
    /// The user stopped the job mid-run.
    case cancelled
}

/// Per-job callbacks, for the screen that submitted the job to mirror its run.
///
/// All optional: a job resent from the queue screen has no sheet behind it and
/// runs on the queue's own state alone.
public struct PrintQueueJobHandlers: Sendable {
    public var onDiagnostic: (@MainActor @Sendable (PrintDiagnostic) -> Void)?
    public var onConsole: (@MainActor @Sendable (String) -> Void)?
    /// Preparation has started (`false`) / printing has started (`true`).
    public var onPhase: (@MainActor @Sendable (_ printing: Bool) -> Void)?
    public var onProgress: (@MainActor @Sendable (Double, String) -> Void)?
    public var onFinish: (@MainActor @Sendable (PrintQueueOutcome) -> Void)?

    public init(
        onDiagnostic: (@MainActor @Sendable (PrintDiagnostic) -> Void)? = nil,
        onConsole: (@MainActor @Sendable (String) -> Void)? = nil,
        onPhase: (@MainActor @Sendable (_ printing: Bool) -> Void)? = nil,
        onProgress: (@MainActor @Sendable (Double, String) -> Void)? = nil,
        onFinish: (@MainActor @Sendable (PrintQueueOutcome) -> Void)? = nil
    ) {
        self.onDiagnostic = onDiagnostic
        self.onConsole = onConsole
        self.onPhase = onPhase
        self.onProgress = onProgress
        self.onFinish = onFinish
    }
}

/// The print queue: serial execution with user control.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintQueueService {

    /// The jobs, in queue order (running/pending first come first).
    public private(set) var jobs: [PrintQueueJob] = []

    /// Whether the queue is held. A held queue accepts jobs but starts none;
    /// the job already running finishes — a DIMSE association cannot be
    /// suspended halfway through a film box.
    public private(set) var isPaused = false

    /// The job being executed right now, if any.
    public private(set) var runningJobID: UUID?

    /// Called after every job finishes, however it was submitted — the owner
    /// records job history here, so resent jobs land in history too.
    public var onJobFinished: (@MainActor (PrintQueueJob, PrintQueueOutcome) -> Void)?

    /// Answers "can this printer take a job right now?" before a job starts.
    ///
    /// Wired by the owner to the status monitor. When it answers `false` the
    /// job stays pending — the FR-012 offline auto-queue — and the owner calls
    /// ``reevaluate()`` when the printer comes back. `nil` means "always ready".
    public var isPrinterReady: (@MainActor (PrinterProfile) -> Bool)?

    /// Extra automatic sends after a failed one (SRS §8.2 FAILED → RETRYING,
    /// gated on retry count < max). 2 means a job is sent at most 3 times.
    public var maxAutoRetries = 2

    /// Seconds between a failure and its automatic resend — long enough for a
    /// transient fault (a dropped association, a busy SCP) to clear, short
    /// enough that film is not left sitting.
    public var retryDelay: TimeInterval = 5

    private let service: PrintService
    private let audit: PrintAuditTrail
    private let storage: PrintQueueStorageService?
    private var handlers: [UUID: PrintQueueJobHandlers] = [:]
    private var runTask: Task<Void, Never>?

    public init(
        service: PrintService = PrintService(),
        audit: PrintAuditTrail,
        storage: PrintQueueStorageService? = nil
    ) {
        self.service = service
        self.audit = audit
        self.storage = storage
        restore()
    }

    /// Brings back the queue a previous launch left behind.
    ///
    /// Jobs that were on the printer when the app died cannot resume — their
    /// association is gone — so they come back failed, honestly. Waiting jobs
    /// come back waiting, but the queue itself restores **held**: an app launch
    /// must never open an association and print film on its own, so the user
    /// resumes the queue deliberately. A waiting job whose source file no
    /// longer exists fails at restore rather than at print time.
    private func restore() {
        guard let storage else { return }
        let saved = storage.load()
        guard !saved.jobs.isEmpty else {
            isPaused = saved.isPaused
            return
        }

        jobs = saved.jobs.map { job in
            var job = job
            switch job.state {
            case .submitting, .running:
                job.state = .failed("Interrupted — the app quit while it was printing")
                job.progressMessage = "Interrupted — the app quit while it was printing"
            case .retrying:
                job.state = .pending
            case .pending, .paused:
                if let missing = job.payload.items.first(
                    where: { !FileManager.default.fileExists(atPath: $0.filePath) }) {
                    job.state = .failed("Source file missing: \(missing.filePath)")
                    job.progressMessage = "Source file missing"
                }
            case .stopped, .failed, .completed:
                break
            }
            return job
        }

        let waiting = jobs.filter { $0.state.isWaiting }.count
        isPaused = saved.isPaused || waiting > 0
        audit.record(.queueRestored,
                     detail: "\(jobs.count) job(s) restored, \(waiting) waiting"
                     + (waiting > 0 ? " — queue held until resumed" : ""))
        persist()
    }

    /// Writes the queue to disk, when there is a disk to write to.
    ///
    /// Called on every state transition and never on progress ticks — progress
    /// is observed state, and a job restarting at 40% would be a lie anyway.
    private func persist() {
        guard let storage else { return }
        try? storage.save(PersistedPrintQueue(jobs: jobs, isPaused: isPaused))
    }

    /// The queue in a couple of words, or `nil` when it is idle and empty.
    ///
    /// Both the sidebar row and the Print screen's title label themselves with
    /// this, so the two always agree on what the queue is doing. `nil` for an
    /// idle queue is deliberate: a suffix that never goes away stops being read.
    public var activitySummary: String? {
        if runningJobID != nil { return "Printing" }

        let waiting = jobs.filter { $0.state.isWaiting }.count
        if waiting > 0 { return isPaused ? "\(waiting) Held" : "\(waiting) Waiting" }

        // Nothing queued, so a failure is the only thing left still wanting
        // attention and it outranks staying silent.
        let failed = jobs.contains {
            if case .failed = $0.state { return true } else { return false }
        }
        return failed ? "Failed" : nil
    }

    // MARK: - Submission

    /// Adds a job to the back of the queue and starts processing unless held.
    @discardableResult
    public func enqueue(
        payload: PrintQueuePayload,
        imageCount: Int,
        filmCount: Int,
        copies: Int,
        layout: String,
        handlers jobHandlers: PrintQueueJobHandlers = PrintQueueJobHandlers()
    ) -> UUID {
        let job = PrintQueueJob(
            payload: payload,
            printerName: payload.profile.name,
            imageCount: imageCount,
            filmCount: filmCount,
            copies: copies,
            layout: layout
        )
        jobs.append(job)
        handlers[job.id] = jobHandlers
        audit.record(.jobSubmitted, jobID: job.id, printerName: job.printerName,
                     detail: job.summary)
        persist()
        processNext()
        return job.id
    }

    // MARK: - Queue-level control

    /// Holds the queue: no new job starts. The running job finishes.
    public func pauseQueue() {
        guard !isPaused else { return }
        isPaused = true
        audit.record(.queuePaused, detail: pendingCountDetail)
        persist()
    }

    /// Releases a held queue and starts the next pending job.
    public func resumeQueue() {
        guard isPaused else { return }
        isPaused = false
        audit.record(.queueResumed, detail: pendingCountDetail)
        persist()
        processNext()
    }

    /// Stops everything: cancels the running job and stops every waiting one.
    public func stopAll() {
        for index in jobs.indices where jobs[index].state.isWaiting {
            jobs[index].state = .stopped
            jobs[index].progressMessage = "Stopped with the queue"
            let id = jobs[index].id
            handlers[id]?.onFinish?(.cancelled)
            onJobFinished?(jobs[index], .cancelled)
            handlers[id] = nil
        }
        if let running = runningJobID {
            stop(running)
        }
        audit.record(.queueStopped, detail: pendingCountDetail)
        persist()
    }

    /// Removes every finished job from the list.
    public func clearFinished() {
        let removed = jobs.filter { $0.state.isFinished }
        guard !removed.isEmpty else { return }
        jobs.removeAll { $0.state.isFinished }
        for job in removed { handlers[job.id] = nil }
        audit.record(.queueCleared, detail: "\(removed.count) finished job(s) removed")
        persist()
    }

    /// Reorders the queue list (drag in the queue screen). The running job is
    /// not moved by its position — the processor tracks it by ID — so moving
    /// rows is always safe; order only decides who goes next.
    public func move(fromOffsets: IndexSet, toOffset: Int) {
        jobs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        audit.record(.queueReordered, detail: pendingCountDetail)
        persist()
    }

    // MARK: - Job-level control

    /// Starts a waiting job ahead of its turn: it moves to the front of the
    /// queue and, if nothing is running, runs now.
    public func start(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state.isWaiting else { return }
        var job = jobs.remove(at: index)
        let wasPaused = job.state == .paused
        job.state = .pending
        // Ahead of every other waiting job, behind the one running.
        let insertAt = jobs.firstIndex { $0.state.isWaiting } ?? jobs.endIndex
        jobs.insert(job, at: insertAt)
        if wasPaused {
            audit.record(.jobResumed, jobID: id, printerName: job.printerName, detail: job.summary)
        }
        persist()
        processNext()
    }

    /// Holds a waiting job; the processor skips it until it is resumed.
    /// A running job cannot pause — its association is already open — so pausing
    /// one is a no-op rather than a half-honored promise.
    public func pause(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .pending else { return }
        jobs[index].state = .paused
        audit.record(.jobPaused, jobID: id, printerName: jobs[index].printerName,
                     detail: jobs[index].summary,
                     beforeState: "Pending", afterState: "Paused")
        persist()
    }

    /// Releases a held job back to pending.
    public func resume(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              jobs[index].state == .paused else { return }
        jobs[index].state = .pending
        audit.record(.jobResumed, jobID: id, printerName: jobs[index].printerName,
                     detail: jobs[index].summary,
                     beforeState: "Paused", afterState: "Pending")
        persist()
        processNext()
    }

    /// Stops a job: cancels it if running (the SCU tears the association down
    /// and N-DELETEs the film session), or takes it out of the waiting line.
    public func stop(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        switch jobs[index].state {
        case .submitting, .running:
            runTask?.cancel()
        case .pending, .paused, .retrying:
            jobs[index].state = .stopped
            jobs[index].progressMessage = "Stopped before it ran"
            audit.record(.jobStopped, jobID: id, printerName: jobs[index].printerName,
                         detail: jobs[index].summary)
            // A job stopped before it ran still has to tell whoever submitted it
            // that it is over. Without this the print sheet, whose only exit is
            // its onFinish handler, sits on "Working…" with no way out.
            handlers[id]?.onFinish?(.cancelled)
            onJobFinished?(jobs[index], .cancelled)
            handlers[id] = nil
            persist()
        case .stopped, .failed, .completed:
            break
        }
    }

    /// Sends a finished job again: same captured payload, new attempt at the
    /// back of the queue. The original entry stays as the record of its run.
    @discardableResult
    public func resend(_ id: UUID) -> UUID? {
        guard let original = jobs.first(where: { $0.id == id }),
              original.state.isFinished else { return nil }
        var job = PrintQueueJob(
            payload: original.payload,
            printerName: original.printerName,
            imageCount: original.imageCount,
            filmCount: original.filmCount,
            copies: original.copies,
            layout: original.layout
        )
        job.attempt = original.attempt + 1
        jobs.append(job)
        audit.record(.jobResent, jobID: job.id, printerName: job.printerName,
                     detail: "\(job.summary) (attempt \(job.attempt))")
        persist()
        processNext()
        return job.id
    }

    /// Removes a job that is not on the printer.
    public func remove(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              !jobs[index].state.isActive else { return }
        let job = jobs.remove(at: index)
        handlers[id] = nil
        audit.record(.jobRemoved, jobID: id, printerName: job.printerName, detail: job.summary)
        persist()
    }

    // MARK: - Processing

    private var pendingCountDetail: String {
        let waiting = jobs.filter { $0.state.isWaiting }.count
        return "\(waiting) job(s) waiting"
    }

    /// Re-checks whether the head of the queue can start now.
    ///
    /// Called by the owner when a printer's status changes — the offline
    /// auto-queue's "the printer is back" signal.
    public func reevaluate() {
        processNext()
    }

    private func processNext() {
        guard !isPaused, runningJobID == nil,
              let index = jobs.firstIndex(where: { $0.state == .pending }) else { return }
        // The offline auto-queue: a job whose printer cannot take it stays
        // pending, saying why, until reevaluate() reports the printer back.
        // Strictly FIFO — a later job does not jump an offline printer's job,
        // because the queue's ordering is a promise about film order.
        if let ready = isPrinterReady, !ready(jobs[index].payload.profile) {
            if jobs[index].progressMessage.isEmpty {
                jobs[index].progressMessage = "Waiting for \(jobs[index].printerName) to come online"
                audit.record(.jobHeldOffline, jobID: jobs[index].id,
                             printerName: jobs[index].printerName,
                             detail: jobs[index].summary)
            }
            return
        }
        run(jobs[index].id)
    }

    private func run(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        let job = jobs[index]
        jobs[index].state = .submitting
        jobs[index].progress = 0
        jobs[index].progressMessage = "Preparing images…"
        runningJobID = id
        audit.record(.jobStarted, jobID: id, printerName: job.printerName,
                     detail: job.summary,
                     beforeState: "Pending", afterState: "Submitting")
        persist()

        let payload = job.payload
        let jobHandlers = handlers[id]
        let service = self.service

        runTask = Task { [weak self] in
            let outcome: PrintQueueOutcome
            var preparedCount = 0
            do {
                // Diagnostics are per-sheet detail; the queue row keeps only
                // its progress line.
                let diagnostics: PrintService.DiagnosticHandler = { diagnostic in
                    Task { @MainActor in jobHandlers?.onDiagnostic?(diagnostic) }
                }
                jobHandlers?.onPhase?(false)
                try await service.preflight(
                    profile: payload.profile, request: payload.request, diagnostics: diagnostics)

                let images = try await service.prepare(
                    items: payload.items,
                    request: payload.request,
                    useViewerWindow: payload.useViewerWindow,
                    applyViewerPresentation: payload.useViewerPresentation,
                    annotations: payload.annotations,
                    annotationStyle: payload.annotationStyle,
                    drawnAnnotations: payload.drawnAnnotations,
                    onProgress: { line in
                        Task { @MainActor in jobHandlers?.onConsole?(line) }
                    }
                )
                preparedCount = images.count
                try Task.checkCancellation()

                jobHandlers?.onPhase?(true)
                self?.updateJob(id) {
                    $0.state = .running   // SUBMITTING → PRINTING: film going over the wire
                    $0.progressMessage = "Printing \(images.count) image(s)…"
                }

                // `self` is a captured weak var here; a @Sendable closure may
                // only capture immutable state, so it is rebound to a let.
                let queue = self
                let progressHandler: PrintService.ProgressHandler = { update in
                    Task { @MainActor in
                        queue?.updateJob(id) {
                            $0.progress = update.progress
                            $0.progressMessage = update.message
                        }
                        jobHandlers?.onProgress?(update.progress, update.message)
                    }
                }

                let result = try await service.print(
                    images: images,
                    profile: payload.profile,
                    request: payload.request,
                    diagnostics: diagnostics,
                    progress: progressHandler
                )
                outcome = .finished(result, preparedImageCount: preparedCount)
            } catch is CancellationError {
                outcome = .cancelled
            } catch let error as PrintRequestError {
                outcome = .failed(error.message)
            } catch let error as PrintWorkflowError {
                outcome = .failed(error.description)
            } catch {
                outcome = .failed(error.localizedDescription)
            }
            self?.complete(id, outcome: outcome)
        }
    }

    private func updateJob(_ id: UUID, _ mutate: (inout PrintQueueJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }

    private func complete(_ id: UUID, outcome: PrintQueueOutcome) {
        runTask = nil
        runningJobID = nil

        if let index = jobs.firstIndex(where: { $0.id == id }) {
            switch outcome {
            case .finished(let result, _):
                jobs[index].result = result
                jobs[index].progress = 1
                if result.success {
                    jobs[index].state = .completed
                    jobs[index].progressMessage = "Printed"
                    audit.record(.jobCompleted, jobID: id, printerName: jobs[index].printerName,
                                 detail: auditDetail(for: jobs[index], result: result),
                                 beforeState: "Printing", afterState: "Completed")
                } else {
                    let message = result.errorMessage ?? "The printer rejected the job."
                    jobs[index].state = .failed(message)
                    jobs[index].progressMessage = message
                    audit.record(.jobFailed, jobID: id, printerName: jobs[index].printerName,
                                 detail: message)
                }
            case .failed(let message):
                // SRS §8.2: FAILED → RETRYING, gated on retry count < max. Only
                // thrown failures retry — a printer that *answered* and rejected
                // the job (the .finished-unsuccessfully arm above) would just
                // reject it again, so rejection is final and a fault is not.
                if jobs[index].attempt < 1 + maxAutoRetries {
                    scheduleRetry(at: index, after: message)
                    persist()
                    processNext()
                    return
                }
                jobs[index].state = .failed(message)
                jobs[index].progressMessage = message
                audit.record(.jobFailed, jobID: id, printerName: jobs[index].printerName,
                             detail: message)
            case .cancelled:
                jobs[index].state = .stopped
                jobs[index].progressMessage = "Cancelled"
                audit.record(.jobStopped, jobID: id, printerName: jobs[index].printerName,
                             detail: jobs[index].summary)
            }
            handlers[id]?.onFinish?(outcome)
            onJobFinished?(jobs[index], outcome)
        }
        handlers[id] = nil
        persist()
        processNext()
    }

    /// Puts a failed job back in line for another automatic send.
    ///
    /// The job keeps its handlers — the sheet that submitted it is still
    /// watching, and hears the retry as console lines rather than a finish it
    /// would mistake for the end of the job. The wait exists so a transient
    /// fault has time to clear; stopping the job during the wait wins, which is
    /// why the delayed hop back to pending re-checks the state.
    private func scheduleRetry(at index: Int, after message: String) {
        let id = jobs[index].id
        jobs[index].attempt += 1
        let attempt = jobs[index].attempt
        jobs[index].state = .retrying(message)
        jobs[index].progressMessage =
            "Retrying in \(Int(retryDelay))s (attempt \(attempt) of \(1 + maxAutoRetries)) — \(message)"
        audit.record(.jobRetried, jobID: id, printerName: jobs[index].printerName,
                     detail: "attempt \(attempt) of \(1 + maxAutoRetries) — \(message)")
        handlers[id]?.onConsole?("Print failed (\(message)) — retrying, attempt \(attempt) of \(1 + maxAutoRetries)")

        let delay = retryDelay
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self,
                  let index = self.jobs.firstIndex(where: { $0.id == id }),
                  case .retrying = self.jobs[index].state else { return }
            self.jobs[index].state = .pending
            self.persist()
            self.processNext()
        }
    }

    /// What the audit trail keeps about a successful job: enough to answer
    /// "did that print, and under which UIDs?" without the history pane.
    private func auditDetail(for job: PrintQueueJob, result: PrintResult) -> String {
        var parts = [job.summary]
        if !result.printJobUIDs.isEmpty {
            parts.append("Print Job UID(s): \(result.printJobUIDs.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}
