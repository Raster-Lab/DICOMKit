// PrintAuditEvent.swift
// DICOMStudio
//
// DICOM Studio — the print activity audit trail: who did what to which job,
// and when. App-side only: the trail records the actions taken in this app
// (submit, start, pause, stop, resend, completion) with no user accounts —
// the machine's app instance is the actor, identified by host and launch
// session. Events are hash-chained (SRS §11.2) and never user-deletable;
// retention is tiered by age (§11.3), not capped by count.

import Foundation
import Observation
import CryptoKit

/// What happened, as the audit trail categorizes it.
public enum PrintAuditAction: String, Sendable, Codable, CaseIterable, Identifiable {
    case jobSubmitted
    case jobStarted
    case jobCompleted
    case jobFailed
    case jobPaused
    case jobResumed
    case jobStopped
    case jobResent
    case jobRetried
    case jobHeldOffline
    case jobRemoved
    case queuePaused
    case queueResumed
    case queueStopped
    case queueCleared
    case queueReordered
    case queueRestored
    case historyCleared
    case retentionApplied

    public var id: String { rawValue }

    /// Human-readable name for lists and filters.
    public var displayName: String {
        switch self {
        case .jobSubmitted:     return "Job Submitted"
        case .jobStarted:       return "Job Started"
        case .jobCompleted:     return "Job Completed"
        case .jobFailed:        return "Job Failed"
        case .jobPaused:        return "Job Paused"
        case .jobResumed:       return "Job Resumed"
        case .jobStopped:       return "Job Stopped"
        case .jobResent:        return "Job Resent"
        case .jobRetried:       return "Job Retried"
        case .jobHeldOffline:   return "Job Held (Printer Offline)"
        case .jobRemoved:       return "Job Removed"
        case .queuePaused:      return "Queue Paused"
        case .queueResumed:     return "Queue Resumed"
        case .queueStopped:     return "Queue Stopped"
        case .queueCleared:     return "Queue Cleared"
        case .queueReordered:   return "Queue Reordered"
        case .queueRestored:    return "Queue Restored"
        case .historyCleared:   return "History Cleared"
        case .retentionApplied: return "Retention Applied"
        }
    }

    /// SF Symbol the audit list renders the action with.
    public var symbolName: String {
        switch self {
        case .jobSubmitted:     return "tray.and.arrow.down"
        case .jobStarted:       return "play.circle"
        case .jobCompleted:     return "checkmark.circle.fill"
        case .jobFailed:        return "xmark.circle.fill"
        case .jobPaused:        return "pause.circle"
        case .jobResumed:       return "play.circle"
        case .jobStopped:       return "stop.circle"
        case .jobResent:        return "arrow.clockwise.circle"
        case .jobRetried:       return "arrow.triangle.2.circlepath.circle"
        case .jobHeldOffline:   return "wifi.slash"
        case .jobRemoved:       return "trash.circle"
        case .queuePaused:      return "pause.rectangle"
        case .queueResumed:     return "play.rectangle"
        case .queueStopped:     return "stop.circle.fill"
        case .queueCleared:     return "xmark.bin"
        case .queueReordered:   return "arrow.up.arrow.down"
        case .queueRestored:    return "arrow.counterclockwise.circle"
        case .historyCleared:   return "clock.badge.xmark"
        case .retentionApplied: return "calendar.badge.minus"
        }
    }

    /// Whether the event reports a problem — the audit list colors these.
    public var isFailure: Bool {
        self == .jobFailed
    }
}

/// One recorded print activity.
///
/// The compliance fields (§11.1) are optional in the type so trails written
/// before they existed still decode; every *new* event carries all of them.
public struct PrintAuditEvent: Sendable, Identifiable, Equatable, Codable {
    public let id: UUID
    /// When the action happened.
    public let date: Date
    /// What happened.
    public let action: PrintAuditAction
    /// The queue job the action concerned, when it concerned one.
    public let jobID: UUID?
    /// Printer name at the time, when the action concerned one.
    public let printerName: String?
    /// Free-text detail: image counts, error text, job UIDs.
    ///
    /// `var`, not `let`: the §11.3 retention tiering blanks the detail of
    /// failure events after a year while keeping the events themselves.
    public var detail: String

    // MARK: §11.1 compliance fields

    /// The app launch this event was recorded in. One UUID per process, so a
    /// reader can group "what happened in that sitting".
    public let sessionID: UUID?
    /// Where the action came from: host name of the machine running the app.
    /// There is no remote actor — printing is initiated locally — so this is
    /// the source address the requirement asks after.
    public let source: String?
    /// The job's state before the action, when the action changed one.
    public let beforeState: String?
    /// The job's state after the action, when the action changed one.
    public let afterState: String?

    // MARK: §11.2 tamper evidence

    /// The previous event's ``entryHash`` — the chain link.
    public var previousHash: String?
    /// SHA-256 over this event's canonical form including ``previousHash``.
    /// Editing any recorded field, or removing an event from the middle,
    /// breaks every hash after it — which is the point.
    public var entryHash: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        action: PrintAuditAction,
        jobID: UUID? = nil,
        printerName: String? = nil,
        detail: String = "",
        sessionID: UUID? = nil,
        source: String? = nil,
        beforeState: String? = nil,
        afterState: String? = nil,
        previousHash: String? = nil,
        entryHash: String? = nil
    ) {
        self.id = id
        self.date = date
        self.action = action
        self.jobID = jobID
        self.printerName = printerName
        self.detail = detail
        self.sessionID = sessionID
        self.source = source
        self.beforeState = beforeState
        self.afterState = afterState
        self.previousHash = previousHash
        self.entryHash = entryHash
    }

    /// The string the hash covers. Field order is part of the format — change
    /// it and every existing chain reads as tampered.
    var canonicalForm: String {
        [
            id.uuidString,
            String(date.timeIntervalSince1970),
            action.rawValue,
            jobID?.uuidString ?? "",
            printerName ?? "",
            detail,
            sessionID?.uuidString ?? "",
            source ?? "",
            beforeState ?? "",
            afterState ?? "",
            previousHash ?? ""
        ].joined(separator: "|")
    }

    /// The hash this event should carry, given its recorded fields.
    var computedHash: String {
        SHA256.hash(data: Data(canonicalForm.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Persistence

/// Persists the audit trail, alongside the other Studio indexes.
public final class PrintAuditTrailStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the audit trail.
    public static let filename = "print-audit-trail.json"

    /// §11.3: audit events are kept seven years.
    public static let eventRetention: TimeInterval = 7 * 365.25 * 24 * 3600

    /// §11.3: failed-job *detail* is kept one year; the event itself stays.
    public static let failureDetailRetention: TimeInterval = 365.25 * 24 * 3600

    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the audit trail file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the trail, newest first. No count cap: retention is by age
    /// (``PrintAuditTrail`` applies it at load), because "the last 500 things"
    /// is not a retention policy and silently dropping the 501st was data loss.
    public func save(_ events: [PrintAuditEvent]) throws {
        let data = try Self.exportData(events)
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Encodes events in the on-disk format — also what "Export…" writes.
    public static func exportData(_ events: [PrintAuditEvent]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(events)
    }

    /// Loads the trail, or an empty array if there is none.
    public func load() -> [PrintAuditEvent] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PrintAuditEvent].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - Live trail

/// The audit trail as the app holds it: newest first, persisted on every write.
///
/// Persisting per event rather than on quit is deliberate — an audit trail that
/// evaporates when the app crashes mid-job is not a record of anything. There
/// is deliberately no `clear()`: §11.2 forbids deleting historical records, so
/// the only thing that removes an event is the retention policy.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintAuditTrail {

    /// One ID per app launch — the §11.1 session identifier.
    public static let sessionID = UUID()

    /// The recording machine — the §11.1 source. Printing is initiated
    /// locally, so the local host *is* the source address.
    public static let source = ProcessInfo.processInfo.hostName

    /// Recorded events, newest first.
    public private(set) var events: [PrintAuditEvent] = []

    private let storage: PrintAuditTrailStorageService

    public init(storage: PrintAuditTrailStorageService = PrintAuditTrailStorageService()) {
        self.storage = storage
        events = storage.load()
        applyRetention()
    }

    /// Appends an event, chains its hash to the newest one, and persists.
    public func record(
        _ action: PrintAuditAction,
        jobID: UUID? = nil,
        printerName: String? = nil,
        detail: String = "",
        beforeState: String? = nil,
        afterState: String? = nil
    ) {
        var event = PrintAuditEvent(
            action: action,
            jobID: jobID,
            printerName: printerName,
            detail: detail,
            sessionID: Self.sessionID,
            source: Self.source,
            beforeState: beforeState,
            afterState: afterState,
            previousHash: events.first?.entryHash
        )
        event.entryHash = event.computedHash
        events.insert(event, at: 0)
        try? storage.save(events)
    }

    /// §11.3 tiered retention, applied at launch: events older than seven
    /// years leave; failure events older than one year keep the fact but lose
    /// the detail text. Either change re-chains the hashes — a policy the
    /// trail records about itself, so the rewrite is on the record too.
    private func applyRetention() {
        let now = Date()
        var changed = 0

        let beforeCount = events.count
        events.removeAll {
            now.timeIntervalSince($0.date) > PrintAuditTrailStorageService.eventRetention
        }
        changed += beforeCount - events.count

        for index in events.indices
        where events[index].action == .jobFailed
            && !events[index].detail.isEmpty
            && now.timeIntervalSince(events[index].date)
                > PrintAuditTrailStorageService.failureDetailRetention {
            events[index].detail = ""
            changed += 1
        }

        guard changed > 0 else { return }
        rechain()
        record(.retentionApplied,
               detail: "\(changed) event(s) aged out or redacted per retention policy")
    }

    /// Recomputes the whole chain, oldest to newest. Only retention calls
    /// this — everything else appends and must never rewrite history.
    private func rechain() {
        var previous: String?
        for index in events.indices.reversed() {
            events[index].previousHash = previous
            events[index].entryHash = events[index].computedHash
            previous = events[index].entryHash
        }
    }

    /// Walks the chain and reports the first broken link, or `nil` if the
    /// trail is intact. Events recorded before hashing existed are exempt —
    /// they carry no hash to check.
    public func verifyIntegrity() -> PrintAuditEvent? {
        var previous: String?
        for event in events.reversed() {   // oldest first
            guard let entryHash = event.entryHash else {
                previous = nil
                continue
            }
            if event.previousHash != previous || entryHash != event.computedHash {
                return event
            }
            previous = entryHash
        }
        return nil
    }

    /// The trail in its on-disk JSON form, for "Export…".
    public func exportData() throws -> Data {
        try PrintAuditTrailStorageService.exportData(events)
    }

    /// The trail as CSV (§11.3 names it as a required export form).
    public func csvExportData() -> Data {
        var lines = ["date,action,printer,job_id,session_id,source,before,after,detail,entry_hash"]
        let formatter = ISO8601DateFormatter()
        for event in events {
            lines.append([
                formatter.string(from: event.date),
                event.action.rawValue,
                event.printerName ?? "",
                event.jobID?.uuidString ?? "",
                event.sessionID?.uuidString ?? "",
                event.source ?? "",
                event.beforeState ?? "",
                event.afterState ?? "",
                event.detail,
                event.entryHash ?? ""
            ].map(Self.csvEscaped).joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func csvEscaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    #if canImport(CoreGraphics) && canImport(CoreText)
    /// The trail as a paginated PDF report — the form an audit record is asked
    /// for when it has to be filed or handed to someone.
    public func pdfExportData() throws -> Data {
        try PrintReportPDF.auditReport(events)
    }
    #endif
}
