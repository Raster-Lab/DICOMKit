// ArchiveManagementService.swift
// DICOMStudio
//
// DICOM Studio — Service for Archive Management state management

import Foundation

/// Thread-safe service managing DICOM Archive state.
public final class ArchiveManagementService: @unchecked Sendable {
    private let lock = NSLock()
    private var _archivePath: String = ""
    private var _patients: [ArchivePatientEntry] = []
    private var _statistics: ArchiveStatistics = ArchiveStatistics()

    public init() {}

    // MARK: - Archive Path

    public var archivePath: String {
        get { lock.withLock { _archivePath } }
        set { lock.withLock { _archivePath = newValue } }
    }

    // MARK: - Patients

    public var patients: [ArchivePatientEntry] {
        lock.withLock { _patients }
    }

    public func setPatients(_ patients: [ArchivePatientEntry]) {
        lock.withLock { _patients = patients }
    }

    // MARK: - Statistics

    public var statistics: ArchiveStatistics {
        lock.withLock { _statistics }
    }

    public func setStatistics(_ stats: ArchiveStatistics) {
        lock.withLock { _statistics = stats }
    }
}
