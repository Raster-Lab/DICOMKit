// PrintSCPSettingsStorageService.swift
// DICOMStudio
//
// DICOM Studio — persistence for the Print SCP (printer emulator) settings.
//
// Mirrors PrinterProfileStorageService one-for-one: same directory, same JSON
// conventions, same silent-fallback behavior. A modality is configured once
// against this printer's AE title and port, so both have to survive a relaunch.
//
// The document itself is `PrintSCPSettingsFile` in DICOMPrintKit, shared with
// `dicom-printscp --config`; only the location is Studio's own, because a
// sandboxed app and a CLI cannot agree on a directory.

import Foundation
import DICOMPrintKit

/// Persists the Print SCP screen's settings to disk.
public final class PrintSCPSettingsStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the Print SCP settings.
    public static let filename = "print-scp-settings.json"

    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the settings file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the settings.
    ///
    /// - Throws: If the file cannot be written.
    public func save(_ settings: PrintSCPSettings) throws {
        try storageService.createDirectories()
        try PrintSCPSettingsFile.write(settings, to: fileURL)
    }

    /// Loads the settings, returning defaults when none are stored.
    ///
    /// A settings file written by an older build that no longer decodes must not
    /// stop the printer from starting, so a decode failure falls back to the
    /// defaults rather than propagating.
    public func load() -> PrintSCPSettings {
        PrintSCPSettingsFile.read(from: fileURL)
    }
}
