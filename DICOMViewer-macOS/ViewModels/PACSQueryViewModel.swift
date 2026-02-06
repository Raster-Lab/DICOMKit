//
//  PACSQueryViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import DICOMNetwork

/// ViewModel for managing PACS queries (C-FIND / QIDO-RS)
@MainActor
@Observable
final class PACSQueryViewModel {
    // MARK: - Query Form

    /// Patient name filter
    var patientName = ""

    /// Patient ID filter
    var patientID = ""

    /// Study date filter (DICOM format: YYYYMMDD or range)
    var studyDate = ""

    /// Modality filter
    var modality = ""

    /// Accession number filter
    var accessionNumber = ""

    /// Query level (uses DICOMNetwork.QueryLevel)
    var queryLevel: DICOMNetwork.QueryLevel = .study

    // MARK: - Results

    /// Study-level query results
    private(set) var studyResults: [QueryStudyItem] = []

    /// Series-level query results
    private(set) var seriesResults: [QuerySeriesItem] = []

    // MARK: - State

    /// Whether a query is in progress
    private(set) var isQuerying = false

    /// Error message from last operation
    var errorMessage: String?

    /// Currently selected PACS server
    var selectedServer: PACSServer?

    /// Set of selected study UIDs for batch operations
    var selectedStudyUIDs: Set<String> = []

    // MARK: - Result Types

    /// Simplified study result for UI display
    struct QueryStudyItem: Identifiable, Hashable {
        let id: String
        let patientName: String
        let patientID: String
        let studyDate: String
        let studyDescription: String
        let modality: String
        let accessionNumber: String
        let numberOfSeries: Int
        let numberOfInstances: Int
    }

    /// Simplified series result for UI display
    struct QuerySeriesItem: Identifiable, Hashable {
        let id: String
        let seriesNumber: Int
        let modality: String
        let seriesDescription: String
        let numberOfInstances: Int
    }

    // MARK: - Public Methods

    /// Execute a study-level query against the selected PACS server
    func executeQuery() async {
        guard let server = selectedServer else {
            errorMessage = "No PACS server selected"
            return
        }

        isQuerying = true
        errorMessage = nil
        studyResults = []

        let service = PACSService(server: server)

        do {
            let results = try await service.findStudies(
                patientName: patientName.isEmpty ? nil : patientName,
                patientID: patientID.isEmpty ? nil : patientID,
                studyDate: studyDate.isEmpty ? nil : studyDate,
                modality: modality.isEmpty ? nil : modality,
                accessionNumber: accessionNumber.isEmpty ? nil : accessionNumber
            )

            studyResults = results.map { result in
                QueryStudyItem(
                    id: result.studyInstanceUID ?? UUID().uuidString,
                    patientName: result.patientName ?? "Unknown",
                    patientID: result.patientID ?? "",
                    studyDate: result.studyDate ?? "",
                    studyDescription: result.studyDescription ?? "",
                    modality: result.modalitiesInStudy ?? "",
                    accessionNumber: result.accessionNumber ?? "",
                    numberOfSeries: result.numberOfStudyRelatedSeries ?? 0,
                    numberOfInstances: result.numberOfStudyRelatedInstances ?? 0
                )
            }
        } catch {
            errorMessage = "Query failed: \(error.localizedDescription)"
        }

        isQuerying = false
    }

    /// Query series for a specific study
    func querySeries(studyUID: String) async {
        guard let server = selectedServer else {
            errorMessage = "No PACS server selected"
            return
        }

        isQuerying = true
        errorMessage = nil
        seriesResults = []

        let service = PACSService(server: server)

        do {
            let results = try await service.findSeries(studyInstanceUID: studyUID)

            seriesResults = results.map { result in
                QuerySeriesItem(
                    id: result.seriesInstanceUID ?? UUID().uuidString,
                    seriesNumber: result.seriesNumber ?? 0,
                    modality: result.modality ?? "",
                    seriesDescription: result.seriesDescription ?? "",
                    numberOfInstances: result.numberOfSeriesRelatedInstances ?? 0
                )
            }
        } catch {
            errorMessage = "Series query failed: \(error.localizedDescription)"
        }

        isQuerying = false
    }

    /// Retrieve selected studies via C-MOVE
    func retrieveSelected(destinationAE: String) async {
        guard let server = selectedServer else {
            errorMessage = "No PACS server selected"
            return
        }

        guard !selectedStudyUIDs.isEmpty else {
            errorMessage = "No studies selected for retrieval"
            return
        }

        let downloadManager = DownloadManager.shared
        let service = PACSService(server: server)

        for studyUID in selectedStudyUIDs {
            let studyItem = studyResults.first { $0.id == studyUID }

            let itemID = await downloadManager.enqueue(
                serverName: server.name,
                studyDescription: studyItem?.studyDescription ?? "Unknown Study",
                patientName: studyItem?.patientName ?? "Unknown",
                studyInstanceUID: studyUID
            )

            Task {
                await downloadManager.markStarted(id: itemID)

                do {
                    let result = try await service.retrieveStudy(
                        studyInstanceUID: studyUID,
                        destinationAE: destinationAE
                    ) { progress in
                        Task {
                            await downloadManager.updateProgress(
                                id: itemID,
                                progress: progress.fractionComplete,
                                completed: progress.completed,
                                total: progress.total
                            )
                        }
                    }

                    if result.isSuccess {
                        await downloadManager.markCompleted(id: itemID)
                    } else {
                        await downloadManager.markFailed(
                            id: itemID,
                            error: "Retrieve completed with failures"
                        )
                    }
                } catch {
                    await downloadManager.markFailed(
                        id: itemID,
                        error: error.localizedDescription
                    )
                }
            }
        }
    }

    /// Clear all query results and reset form
    func clearResults() {
        studyResults = []
        seriesResults = []
        selectedStudyUIDs = []
        errorMessage = nil
    }

}
