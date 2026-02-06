//
//  DICOMWebService.swift
//  DICOMViewer-macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import DICOMWeb
import DICOMCore

/// App-level service wrapping DICOMWeb module APIs (QIDO-RS, WADO-RS, STOW-RS)
/// for DICOMweb connectivity in the macOS viewer.
@MainActor
final class DICOMWebService {
    let server: PACSServer
    private var client: DICOMwebClient?

    init(server: PACSServer) {
        self.server = server
        setupClient()
    }

    private func setupClient() {
        guard let urlString = server.webBaseURL,
              let url = URL(string: urlString) else { return }
        let config = DICOMwebConfiguration(baseURL: url)
        client = DICOMwebClient(configuration: config)
    }

    // MARK: - QIDO-RS

    /// Searches for studies matching the given criteria via QIDO-RS.
    func searchStudies(
        patientName: String? = nil,
        patientID: String? = nil,
        studyDate: String? = nil,
        modality: String? = nil
    ) async throws -> QIDOStudyResults {
        guard let client else {
            throw DICOMWebServiceError.clientNotConfigured
        }
        var query = QIDOQuery()
        if let name = patientName, !name.isEmpty {
            query = query.patientName(name)
        }
        if let id = patientID, !id.isEmpty {
            query = query.patientID(id)
        }
        if let date = studyDate, !date.isEmpty {
            query = query.studyDate(date)
        }
        if let mod = modality, !mod.isEmpty {
            query = query.modality(mod)
        }
        return try await client.searchStudies(query: query)
    }

    /// Retrieves all instances for a study via WADO-RS.
    func retrieveStudy(studyUID: String) async throws -> DICOMwebClient.RetrieveResult {
        guard let client else {
            throw DICOMWebServiceError.clientNotConfigured
        }
        return try await client.retrieveStudy(studyUID: studyUID)
    }

    /// Retrieves all instances for a series via WADO-RS.
    func retrieveSeries(
        studyUID: String,
        seriesUID: String
    ) async throws -> DICOMwebClient.RetrieveResult {
        guard let client else {
            throw DICOMWebServiceError.clientNotConfigured
        }
        return try await client.retrieveSeries(studyUID: studyUID, seriesUID: seriesUID)
    }

    // MARK: - STOW-RS

    /// Stores DICOM instances via STOW-RS.
    func storeInstances(
        data: [Data],
        studyUID: String? = nil
    ) async throws -> STOWResponse {
        guard let client else {
            throw DICOMWebServiceError.clientNotConfigured
        }
        return try await client.storeInstances(instances: data, studyUID: studyUID)
    }
}

// MARK: - Errors

enum DICOMWebServiceError: LocalizedError {
    case clientNotConfigured

    var errorDescription: String? {
        switch self {
        case .clientNotConfigured:
            return "DICOMweb client is not configured. Ensure the server has a valid web base URL."
        }
    }
}
