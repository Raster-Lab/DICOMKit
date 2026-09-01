// PrinterStatusMonitor.swift
// DICOMStudio
//
// DICOM Studio — background printer status polling (FR-012).
//
// Until now a printer's state was only ever as fresh as the last time someone
// pressed a button. FR-012 wants the workstation to notice a printer going
// warning or offline on its own, on a configurable 10–300s cadence, so a
// technologist finds out before submitting a film rather than after.
//
// Each printer gets its own polling task: one printer being slow or unreachable
// must not delay the others, and a shared timer would make the slowest printer
// set everyone's cadence.

import Foundation
import DICOMNetwork

// MARK: - Probe seam

/// The one operation the monitor needs from the network layer.
///
/// A protocol rather than a concrete `PrintService` so tests can drive the
/// monitor's timing and backoff without a printer on the other end.
public protocol PrinterStatusProbing: Sendable {
    func probe(profile: PrinterProfile) async throws -> PrinterStatus
}

extension PrintService: PrinterStatusProbing {
    public func probe(profile: PrinterProfile) async throws -> PrinterStatus {
        try await printerStatus(profile: profile)
    }
}

// MARK: - Observation

/// The result of one poll, as the UI needs it.
public struct PrinterStatusUpdate: Sendable, Equatable {
    /// Which printer this is about.
    public let printerID: UUID
    /// Mapped connection status, ready for the profile row.
    public let connectionStatus: ServerConnectionStatus
    /// What the printer reported, when it answered.
    public let status: PrinterStatus?
    /// Why the poll failed, when it did.
    public let errorDescription: String?
    /// When the poll completed.
    public let checkedAt: Date
    /// Consecutive failures before this update, for the UI to show "retrying".
    public let consecutiveFailures: Int

    public init(
        printerID: UUID,
        connectionStatus: ServerConnectionStatus,
        status: PrinterStatus? = nil,
        errorDescription: String? = nil,
        checkedAt: Date,
        consecutiveFailures: Int = 0
    ) {
        self.printerID = printerID
        self.connectionStatus = connectionStatus
        self.status = status
        self.errorDescription = errorDescription
        self.checkedAt = checkedAt
        self.consecutiveFailures = consecutiveFailures
    }

    /// A one-line detail for the profile row.
    public var detail: String? {
        if let errorDescription { return errorDescription }
        guard let status else { return nil }
        return PrinterStatusPresentation.summary(for: status)
    }
}

// MARK: - Backoff

/// How long to wait after a failed poll.
///
/// A printer that is switched off should not be probed every 10 seconds all
/// night; the delay grows to a ceiling and resets the moment it answers.
public struct PrinterStatusBackoff: Sendable, Equatable {
    /// Multiplier applied per consecutive failure.
    public var multiplier: Double
    /// Longest a backed-off poll will ever wait, regardless of failure count.
    public var ceilingSeconds: Double

    public static let `default` = PrinterStatusBackoff(multiplier: 2.0, ceilingSeconds: 600)

    public init(multiplier: Double = 2.0, ceilingSeconds: Double = 600) {
        self.multiplier = multiplier
        self.ceilingSeconds = ceilingSeconds
    }

    /// Delay before the next attempt.
    ///
    /// `consecutiveFailures == 0` is the healthy case and returns the printer's
    /// configured interval unchanged.
    public func delay(base: Double, consecutiveFailures: Int) -> Double {
        guard consecutiveFailures > 0 else { return base }
        // Cap the exponent before it reaches `pow` — at 1024 failures the
        // multiplication itself overflows to infinity, and a nil-out here is
        // much harder to debug than a clamped delay.
        let exponent = Double(min(consecutiveFailures, 16))
        let grown = base * pow(multiplier, exponent)
        guard grown.isFinite else { return ceilingSeconds }
        return min(grown, ceilingSeconds)
    }
}

// MARK: - Monitor

/// Polls each monitored printer on its own schedule.
public actor PrinterStatusMonitor {

    private let probe: any PrinterStatusProbing
    private let backoff: PrinterStatusBackoff

    /// Sleeps for a duration. Injected so tests advance time without waiting.
    private let sleep: @Sendable (Duration) async throws -> Void

    /// One running poll loop per printer.
    private var tasks: [UUID: Task<Void, Never>] = [:]

    /// Consecutive failure counts, keyed by printer.
    private var failureCounts: [UUID: Int] = [:]

    /// The latest update per printer, for a UI that attaches after a poll landed.
    private var latest: [UUID: PrinterStatusUpdate] = [:]

    private var continuations: [UUID: AsyncStream<PrinterStatusUpdate>.Continuation] = [:]

    public init(
        probe: any PrinterStatusProbing,
        backoff: PrinterStatusBackoff = .default,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.probe = probe
        self.backoff = backoff
        self.sleep = sleep
    }

    deinit {
        for task in tasks.values { task.cancel() }
        for continuation in continuations.values { continuation.finish() }
    }

    // MARK: Observation

    /// A stream of every status update, for the duration of the returned stream.
    public func updates() -> AsyncStream<PrinterStatusUpdate> {
        AsyncStream { continuation in
            let key = UUID()
            continuations[key] = continuation
            // Replay what we already know, so a view appearing between polls
            // shows the current state instead of "unknown" until the next tick.
            for update in latest.values {
                continuation.yield(update)
            }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(key) }
            }
        }
    }

    private func removeContinuation(_ key: UUID) {
        continuations[key] = nil
    }

    /// The most recent update for a printer, if it has been polled.
    public func lastUpdate(for printerID: UUID) -> PrinterStatusUpdate? {
        latest[printerID]
    }

    /// Printers currently being polled.
    public var monitoredPrinterIDs: Set<UUID> {
        Set(tasks.keys)
    }

    // MARK: Control

    /// Starts, stops and re-times polling to match `profiles`.
    ///
    /// Idempotent: call it whenever the printer list changes. A printer whose
    /// interval changed is restarted; one that is unchanged keeps its in-flight
    /// schedule rather than being reset on every save.
    public func sync(profiles: [PrinterProfile]) {
        let wanted = profiles.filter(\.isMonitoringEnabled)
        let wantedIDs = Set(wanted.map(\.id))

        for id in tasks.keys where !wantedIDs.contains(id) {
            stop(printerID: id)
        }

        for profile in wanted {
            if let existing = intervals[profile.id],
               existing == profile.monitoringIntervalSeconds,
               tasks[profile.id] != nil {
                continue
            }
            start(profile: profile)
        }
    }

    /// Interval each running task was started with, so `sync` can tell a
    /// re-timed printer from an unchanged one.
    private var intervals: [UUID: Double] = [:]

    /// Begins polling one printer, replacing any existing loop for it.
    public func start(profile: PrinterProfile) {
        stop(printerID: profile.id)
        let interval = PrinterProfile.clampInterval(profile.monitoringIntervalSeconds)
        intervals[profile.id] = profile.monitoringIntervalSeconds
        tasks[profile.id] = Task { [weak self] in
            await self?.run(profile: profile, interval: interval)
        }
    }

    /// Stops polling one printer.
    public func stop(printerID: UUID) {
        tasks[printerID]?.cancel()
        tasks[printerID] = nil
        intervals[printerID] = nil
    }

    /// Stops all polling.
    public func stopAll() {
        for id in tasks.keys { stop(printerID: id) }
    }

    // MARK: Polling

    private func run(profile: PrinterProfile, interval: Double) async {
        // Spread the first poll across the interval. Several printers enabled
        // together would otherwise open associations in lockstep forever.
        let jitter = Double.random(in: 0...min(interval, 5))
        do {
            try await sleep(.seconds(jitter))
        } catch {
            return
        }

        while !Task.isCancelled {
            await pollOnce(profile: profile)
            let failures = failureCounts[profile.id] ?? 0
            let delay = backoff.delay(base: interval, consecutiveFailures: failures)
            do {
                try await sleep(.seconds(delay))
            } catch {
                return
            }
        }
    }

    /// One probe, recorded and published. Exposed for tests and for a manual refresh.
    @discardableResult
    public func pollOnce(profile: PrinterProfile) async -> PrinterStatusUpdate {
        let update: PrinterStatusUpdate
        do {
            let status = try await probe.probe(profile: profile)
            failureCounts[profile.id] = 0
            update = PrinterStatusUpdate(
                printerID: profile.id,
                connectionStatus: Self.connectionStatus(for: status.severity),
                status: status,
                checkedAt: Date(),
                consecutiveFailures: 0
            )
        } catch is CancellationError {
            // Cancellation is the app shutting the loop down, not the printer
            // failing — recording it would show a spurious offline badge.
            return latest[profile.id] ?? PrinterStatusUpdate(
                printerID: profile.id,
                connectionStatus: profile.status,
                checkedAt: Date()
            )
        } catch {
            let failures = (failureCounts[profile.id] ?? 0) + 1
            failureCounts[profile.id] = failures
            update = PrinterStatusUpdate(
                printerID: profile.id,
                // Unreachable is offline, not error: the distinction is between
                // "we could not ask" and "it answered and told us it is broken".
                connectionStatus: .offline,
                errorDescription: error.localizedDescription,
                checkedAt: Date(),
                consecutiveFailures: failures
            )
        }

        latest[profile.id] = update
        for continuation in continuations.values {
            continuation.yield(update)
        }
        return update
    }

    /// Maps reported severity onto the stored connection status.
    ///
    /// Mirrors `PrintViewModel.connectionStatus(for:)`; kept here so the monitor
    /// does not have to touch a `@MainActor` type from inside the actor.
    static func connectionStatus(for severity: PrinterStatusSeverity) -> ServerConnectionStatus {
        switch severity {
        case .normal:  return .online
        case .warning: return .warning
        case .failure: return .error
        case .unknown: return .unknown
        }
    }
}
