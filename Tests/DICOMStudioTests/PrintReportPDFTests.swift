// PrintReportPDFTests.swift
// DICOMStudioTests
//
// The PDF form of the print records: that what the Export menu writes is a
// real, openable, correctly paginated document — not just non-empty bytes.

#if canImport(CoreGraphics) && canImport(CoreText)
import Testing
import Foundation
import CoreGraphics
@testable import DICOMStudio

@MainActor
@Suite("Print record PDF export")
struct PrintReportPDFTests {

    private func historyEntry(
        printer: String = "Test Printer",
        success: Bool = true,
        error: String? = nil,
        uids: [String] = []
    ) -> PrintJobHistoryEntry {
        PrintJobHistoryEntry(
            printerName: printer,
            imageCount: 4,
            filmCount: 1,
            copies: 1,
            layout: "2×2",
            success: success,
            printJobUIDs: uids,
            errorMessage: error
        )
    }

    /// Opens rendered bytes as a PDF, which only succeeds on a real document.
    private func document(_ data: Data) throws -> CGPDFDocument {
        let provider = try #require(CGDataProvider(data: data as CFData))
        return try #require(CGPDFDocument(provider))
    }

    // MARK: - History

    @Test("The history PDF is a real document with a page")
    func historyPDFIsValid() throws {
        let data = try PrintReportPDF.historyReport([historyEntry()])
        #expect(!data.isEmpty)
        let pdf = try document(data)
        #expect(pdf.numberOfPages == 1)
    }

    @Test("An empty history still exports an openable one-page report")
    func emptyHistoryStillRenders() throws {
        // A zero-page PDF is a file no viewer will open — the report has to say
        // "no records" instead.
        let data = try PrintReportPDF.historyReport([])
        let pdf = try document(data)
        #expect(pdf.numberOfPages == 1)
    }

    @Test("A long history paginates rather than overflowing one page")
    func historyPaginates() throws {
        let entries = (0..<200).map { _ in historyEntry() }
        let pdf = try document(try PrintReportPDF.historyReport(entries))
        #expect(pdf.numberOfPages > 1)
    }

    @Test("Failed jobs and their reasons survive into the report")
    func failedHistoryRenders() throws {
        let data = try PrintReportPDF.historyReport([
            historyEntry(success: false, error: "Association rejected by the printer"),
            historyEntry(success: true, uids: ["1.2.840.10008.5.1.1.1.99"])
        ])
        let pdf = try document(data)
        #expect(pdf.numberOfPages == 1)
    }

    // MARK: - Audit trail

    @Test("The audit PDF is a real document with a page")
    func auditPDFIsValid() throws {
        let events = [
            PrintAuditEvent(action: .jobSubmitted, printerName: "P", detail: "4 image(s)"),
            PrintAuditEvent(action: .jobCompleted, printerName: "P", detail: "printed")
        ]
        let pdf = try document(try PrintReportPDF.auditReport(events))
        #expect(pdf.numberOfPages == 1)
    }

    @Test("An empty audit trail still exports an openable one-page report")
    func emptyAuditStillRenders() throws {
        let pdf = try document(try PrintReportPDF.auditReport([]))
        #expect(pdf.numberOfPages == 1)
    }

    @Test("A long audit trail paginates")
    func auditPaginates() throws {
        let events = (0..<200).map {
            PrintAuditEvent(action: .jobStarted, printerName: "P", detail: "event \($0)")
        }
        let pdf = try document(try PrintReportPDF.auditReport(events))
        #expect(pdf.numberOfPages > 1)
    }

    @Test("Every action renders, including those with no printer")
    func allActionsRender() throws {
        let events = PrintAuditAction.allCases.map {
            PrintAuditEvent(action: $0, detail: "detail for \($0.rawValue)")
        }
        let pdf = try document(try PrintReportPDF.auditReport(events))
        #expect(pdf.numberOfPages >= 1)
    }

    @Test("Detail far wider than its column does not break the render")
    func overlongDetailTruncates() throws {
        let long = String(repeating: "1.2.840.10008.5.1.4.1.1.7, ", count: 60)
        let pdf = try document(try PrintReportPDF.auditReport([
            PrintAuditEvent(action: .jobCompleted, printerName: "P", detail: long)
        ]))
        #expect(pdf.numberOfPages == 1)
    }

    // MARK: - Wiring

    @Test("The view model and trail hand the export menu PDF bytes")
    func exportEntryPointsProducePDFs() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-pdf-\(UUID().uuidString)", isDirectory: true)
        let storageService = StorageService(baseDirectory: directory)
        let historyStorage = PrintJobHistoryStorageService(storageService: storageService)
        try historyStorage.save([historyEntry()])

        let model = PrintViewModel(
            printerStorage: PrinterProfileStorageService(storageService: storageService),
            historyStorage: historyStorage,
            auditStorage: PrintAuditTrailStorageService(storageService: storageService))
        model.auditTrail.record(.jobSubmitted, printerName: "P", detail: "queued")

        // Both menu paths must produce something a PDF reader can open.
        #expect(try document(model.historyPDFData()).numberOfPages == 1)
        #expect(try document(model.auditTrail.pdfExportData()).numberOfPages == 1)

        // JSON still decodes as it always did — the PDF is an addition to the
        // Export menu, not a replacement for the machine-readable form.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            [PrintJobHistoryEntry].self, from: model.historyExportData())
        #expect(decoded.count == 1)
    }
}
#endif
