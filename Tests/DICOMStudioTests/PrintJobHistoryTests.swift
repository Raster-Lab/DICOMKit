// PrintJobHistoryTests.swift
// DICOMStudioTests
//
// The print job history as an audit trail: persistence, clearing, export, and
// re-querying a past job's execution status from the history pane.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMNetwork

@MainActor
@Suite("Print job history")
struct PrintJobHistoryTests {

    /// A view model backed by a throwaway storage directory.
    private func makeViewModel(
        seededHistory: [PrintJobHistoryEntry] = [],
        querier: (any PrintJobStatusQuerying)? = nil
    ) throws -> (PrintViewModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-history-\(UUID().uuidString)", isDirectory: true)
        let storageService = StorageService(baseDirectory: directory)
        let historyStorage = PrintJobHistoryStorageService(storageService: storageService)
        if !seededHistory.isEmpty {
            try historyStorage.save(seededHistory)
        }
        let model = PrintViewModel(
            printerStorage: PrinterProfileStorageService(storageService: storageService),
            historyStorage: historyStorage,
            jobStatusQuerier: querier
        )
        return (model, directory)
    }

    private func makeEntry(
        printerName: String = "Printer",
        success: Bool = true,
        printJobUIDs: [String] = ["1.2.3.4"]
    ) -> PrintJobHistoryEntry {
        PrintJobHistoryEntry(
            printerName: printerName,
            imageCount: 4,
            filmCount: printJobUIDs.count,
            copies: 1,
            layout: "2×2",
            success: success,
            printJobUIDs: printJobUIDs,
            filmSessionUID: "1.2.3"
        )
    }

    // MARK: - Persistence

    @Test("History loads from storage at init")
    func historyLoadsAtInit() throws {
        let entries = [makeEntry(), makeEntry(success: false, printJobUIDs: [])]
        let (model, directory) = try makeViewModel(seededHistory: entries)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(model.history.map(\.id) == entries.map(\.id))
    }

    @Test("clearHistory empties memory and disk")
    func clearHistoryEmptiesBoth() throws {
        let (model, directory) = try makeViewModel(seededHistory: [makeEntry()])
        defer { try? FileManager.default.removeItem(at: directory) }

        model.clearHistory()

        #expect(model.history.isEmpty)
        let storage = PrintJobHistoryStorageService(
            storageService: StorageService(baseDirectory: directory))
        #expect(storage.load().isEmpty)
    }

    @Test("Exported data round-trips through the on-disk format")
    func exportRoundTrips() throws {
        let entries = [makeEntry(), makeEntry(success: false)]
        let (model, directory) = try makeViewModel(seededHistory: entries)
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = try model.historyExportData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([PrintJobHistoryEntry].self, from: data)

        #expect(decoded.map(\.id) == entries.map(\.id))
        #expect(decoded.first?.printJobUIDs == entries.first?.printJobUIDs)
    }

    // MARK: - Re-querying past jobs

    @Test("Re-query without job UIDs reports unavailable")
    func requeryWithoutUIDs() async throws {
        let entry = makeEntry(printJobUIDs: [])
        let (model, directory) = try makeViewModel(seededHistory: [entry])
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.refreshHistoryStatus(for: entry)

        guard case .unavailable(let reason) = model.historyStatusChecks[entry.id] else {
            Issue.record("Expected .unavailable, got \(String(describing: model.historyStatusChecks[entry.id]))")
            return
        }
        #expect(reason.contains("did not return job UIDs"))
    }

    @Test("Re-query on a removed printer reports unavailable")
    func requeryRemovedPrinter() async throws {
        let entry = makeEntry(printerName: "Gone")
        let (model, directory) = try makeViewModel(seededHistory: [entry])
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.refreshHistoryStatus(for: entry)

        guard case .unavailable(let reason) = model.historyStatusChecks[entry.id] else {
            Issue.record("Expected .unavailable, got \(String(describing: model.historyStatusChecks[entry.id]))")
            return
        }
        #expect(reason.contains("Gone"))
    }

    @Test("Re-query labels each film and flags a failure")
    func requeryMultiFilm() async throws {
        let entry = makeEntry(printJobUIDs: ["1.1", "1.2"])
        let querier = MockJobStatusQuerier(statuses: [
            "1.1": DICOMNetwork.PrintJobStatus(printJobUID: "1.1", executionStatus: "DONE"),
            "1.2": DICOMNetwork.PrintJobStatus(printJobUID: "1.2", executionStatus: "FAILURE",
                                  executionStatusInfo: "CHECK PRINTER"),
        ])
        let (model, directory) = try makeViewModel(seededHistory: [entry], querier: querier)
        defer { try? FileManager.default.removeItem(at: directory) }
        model.save(PrinterProfile(name: "Printer", host: "127.0.0.1", remoteAETitle: "PRINT_SCP"))

        await model.refreshHistoryStatus(for: entry)

        guard case .checked(let lines, let anyFailed) = model.historyStatusChecks[entry.id] else {
            Issue.record("Expected .checked, got \(String(describing: model.historyStatusChecks[entry.id]))")
            return
        }
        #expect(anyFailed)
        #expect(lines.map(\.text) == ["Film 1: DONE", "Film 2: FAILURE (CHECK PRINTER)"])
        #expect(lines.map(\.kind) == [.completed, .failed])
    }

    @Test("A pending single-film job renders without a film prefix")
    func requerySingleFilmPending() async throws {
        let entry = makeEntry(printJobUIDs: ["1.1"])
        let querier = MockJobStatusQuerier(statuses: [
            "1.1": DICOMNetwork.PrintJobStatus(printJobUID: "1.1", executionStatus: "PENDING"),
        ])
        let (model, directory) = try makeViewModel(seededHistory: [entry], querier: querier)
        defer { try? FileManager.default.removeItem(at: directory) }
        model.save(PrinterProfile(name: "Printer", host: "127.0.0.1", remoteAETitle: "PRINT_SCP"))

        await model.refreshHistoryStatus(for: entry)

        guard case .checked(let lines, let anyFailed) = model.historyStatusChecks[entry.id] else {
            Issue.record("Expected .checked, got \(String(describing: model.historyStatusChecks[entry.id]))")
            return
        }
        #expect(!anyFailed)
        #expect(lines.map(\.text) == ["PENDING"])
        #expect(lines.map(\.kind) == [.inProgress])
    }

    @Test("A query error marks the film failed instead of throwing")
    func requeryErrorMarksFailed() async throws {
        let entry = makeEntry(printJobUIDs: ["1.9"])
        let (model, directory) = try makeViewModel(
            seededHistory: [entry],
            querier: MockJobStatusQuerier(statuses: [:]))
        defer { try? FileManager.default.removeItem(at: directory) }
        model.save(PrinterProfile(name: "Printer", host: "127.0.0.1", remoteAETitle: "PRINT_SCP"))

        await model.refreshHistoryStatus(for: entry)

        guard case .checked(let lines, let anyFailed) = model.historyStatusChecks[entry.id] else {
            Issue.record("Expected .checked, got \(String(describing: model.historyStatusChecks[entry.id]))")
            return
        }
        #expect(anyFailed)
        #expect(lines.first?.kind == .failed)
        #expect(lines.first?.text.contains("Query failed") == true)
    }
}

/// Answers job-status queries from a fixed table; unknown UIDs throw.
private struct MockJobStatusQuerier: PrintJobStatusQuerying {
    struct UnknownJob: Error, LocalizedError {
        var errorDescription: String? { "no such job" }
    }

    let statuses: [String: DICOMNetwork.PrintJobStatus]

    func jobStatus(profile: PrinterProfile, printJobUID: String) async throws -> DICOMNetwork.PrintJobStatus {
        guard let status = statuses[printJobUID] else { throw UnknownJob() }
        return status
    }
}
