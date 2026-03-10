// ServerProfileStorageService.swift
// DICOMStudio
//
// DICOM Studio — Persistence service for PACS server profiles

import Foundation

/// Service for persisting PACS server profiles to disk.
///
/// Uses JSON-based storage alongside the library index.
public final class ServerProfileStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the server profiles index.
    public static let filename = "server-profiles.json"

    /// Creates a server profile storage service.
    ///
    /// - Parameter storageService: The storage service.
    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the server profiles file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the server profiles to disk.
    ///
    /// - Parameter profiles: The profiles to persist.
    /// - Throws: If the file cannot be written.
    public func save(_ profiles: [PACSServerProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profiles)
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads the server profiles from disk.
    ///
    /// - Returns: The loaded profiles, or an empty array if no file exists.
    public func load() -> [PACSServerProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PACSServerProfile].self, from: data)
        } catch {
            return []
        }
    }
}
