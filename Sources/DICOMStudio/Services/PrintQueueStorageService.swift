// PrintQueueStorageService.swift
// DICOMStudio
//
// DICOM Studio — persistence for the print queue, so a quit or crash does not
// silently discard film someone asked for. Mirrors PrinterProfileStorageService:
// same directory, same JSON conventions, same failure behavior.

import Foundation

/// What the queue writes to disk: the jobs and whether the queue was held.
///
/// Job results are not part of this (see `PrintQueueJob.CodingKeys`) — the
/// queue file exists so *unfinished* work survives, and the job history file
/// is the record of finished work.
public struct PersistedPrintQueue: Codable, Sendable {
    public let jobs: [PrintQueueJob]
    public let isPaused: Bool

    public init(jobs: [PrintQueueJob], isPaused: Bool) {
        self.jobs = jobs
        self.isPaused = isPaused
    }
}

/// Service for persisting the print queue to disk.
public final class PrintQueueStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the queue file.
    public static let filename = "print-queue.json"

    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the queue file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the queue to disk.
    public func save(_ queue: PersistedPrintQueue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(queue)
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads the queue from disk. A missing or unreadable file is an empty
    /// queue, not an error — same tolerance as every other studio store.
    public func load() -> PersistedPrintQueue {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PersistedPrintQueue(jobs: [], isPaused: false)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedPrintQueue.self, from: data)
        } catch {
            return PersistedPrintQueue(jobs: [], isPaused: false)
        }
    }
}
