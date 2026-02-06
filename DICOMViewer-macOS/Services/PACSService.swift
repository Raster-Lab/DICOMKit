//
//  PACSService.swift
//  DICOMViewer-macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import DICOMNetwork
import DICOMCore

/// App-level service wrapping DICOMNetwork APIs (C-ECHO, C-FIND, C-MOVE, C-STORE)
/// for PACS integration in the macOS viewer.
@MainActor
final class PACSService {
    let server: PACSServer

    init(server: PACSServer) {
        self.server = server
    }

    // MARK: - C-ECHO

    /// Tests connectivity to the configured PACS server.
    func testConnection() async throws -> Bool {
        try await DICOMVerificationService.verify(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle
        )
    }

    // MARK: - C-FIND

    /// Queries studies matching the given criteria.
    func findStudies(
        patientName: String? = nil,
        patientID: String? = nil,
        studyDate: String? = nil,
        modality: String? = nil,
        accessionNumber: String? = nil
    ) async throws -> [StudyResult] {
        var keys = QueryKeys(level: .study)
        if let name = patientName, !name.isEmpty {
            keys = keys.patientName(name)
        }
        if let id = patientID, !id.isEmpty {
            keys = keys.patientID(id)
        }
        if let date = studyDate, !date.isEmpty {
            keys = keys.studyDate(date)
        }
        if let mod = modality, !mod.isEmpty {
            keys = keys.modality(mod)
        }
        if let accession = accessionNumber, !accession.isEmpty {
            keys = keys.accessionNumber(accession)
        }
        return try await DICOMQueryService.findStudies(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            matching: keys
        )
    }

    /// Queries series for a given study.
    func findSeries(studyInstanceUID: String) async throws -> [SeriesResult] {
        try await DICOMQueryService.findSeries(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            forStudy: studyInstanceUID
        )
    }

    /// Queries instances for a given series within a study.
    func findInstances(
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) async throws -> [InstanceResult] {
        try await DICOMQueryService.findInstances(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            forStudy: studyInstanceUID,
            forSeries: seriesInstanceUID
        )
    }

    // MARK: - C-MOVE

    /// Retrieves an entire study to a local destination AE.
    func retrieveStudy(
        studyInstanceUID: String,
        destinationAE: String,
        onProgress: @escaping @Sendable (RetrieveProgress) -> Void
    ) async throws -> RetrieveResult {
        try await DICOMRetrieveService.moveStudy(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            studyInstanceUID: studyInstanceUID,
            moveDestination: destinationAE,
            onProgress: onProgress
        )
    }

    /// Retrieves a specific series to a local destination AE.
    func retrieveSeries(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        destinationAE: String,
        onProgress: @escaping @Sendable (RetrieveProgress) -> Void
    ) async throws -> RetrieveResult {
        try await DICOMRetrieveService.moveSeries(
            host: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            moveDestination: destinationAE,
            onProgress: onProgress
        )
    }

    // MARK: - C-STORE

    /// Sends a single DICOM file to the configured PACS server.
    func sendFile(fileData: Data) async throws -> StoreResult {
        try await DICOMStorageService.store(
            fileData: fileData,
            to: server.host,
            port: UInt16(server.port),
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle
        )
    }

    /// Sends multiple DICOM files to the configured PACS server, reporting progress.
    func sendFiles(
        filesData: [Data],
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> [StoreResult] {
        var results: [StoreResult] = []
        results.reserveCapacity(filesData.count)
        for (index, data) in filesData.enumerated() {
            let result = try await DICOMStorageService.store(
                fileData: data,
                to: server.host,
                port: UInt16(server.port),
                callingAE: server.callingAETitle,
                calledAE: server.calledAETitle
            )
            results.append(result)
            onProgress(index + 1, filesData.count)
        }
        return results
    }
}
