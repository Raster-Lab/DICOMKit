// PrintWorkflow.swift
// DICOMPrintKit
//
// Outer orchestration of a print job: optional C-ECHO verification, optional
// printer-status pre-flight, retries with exponential backoff, and the call
// into the Print SCU. The DIMSE sequence itself (film session → film boxes →
// image boxes → print → cleanup, one association) lives in
// DICOMNetwork.DICOMPrintService and is NOT reimplemented here.

import Foundation
import DICOMNetwork

// MARK: - Diagnostics

/// A line the workflow wants to surface while it runs.
public enum PrintDiagnostic: Sendable {
    /// Detail shown only in verbose mode.
    case info(String)
    /// Something the user should always see.
    case notice(String)
    /// A problem that does not stop the job.
    case warning(String)
    /// An N-EVENT-REPORT pushed by the printer during the association.
    case event(PrintEvent)

    /// The text to display for this diagnostic.
    public var text: String {
        switch self {
        case .info(let message), .notice(let message), .warning(let message):
            return message
        case .event(let event):
            return event.summary
        }
    }
}

// MARK: - Errors

/// A failure raised by the workflow itself rather than by the SCU.
public enum PrintWorkflowError: Error, CustomStringConvertible, Sendable {
    /// The printer reported FAILURE during the pre-flight status check. The
    /// explanatory line has already been emitted as a diagnostic.
    case printerReportedFailure(String)

    public var description: String {
        switch self {
        case .printerReportedFailure(let info):
            return "Printer reports FAILURE\(info)"
        }
    }
}

// MARK: - Workflow

/// Runs a print job end to end.
public enum PrintWorkflow {

    /// Receives diagnostic lines as the job progresses.
    public typealias DiagnosticHandler = @Sendable (PrintDiagnostic) -> Void

    /// Receives progress updates from the SCU.
    public typealias ProgressHandler = @Sendable (PrintProgress) -> Void

    // MARK: Pre-flight

    /// Runs the request's optional pre-flight checks against the printer.
    ///
    /// - C-ECHO verification when ``PrintJobRequest/verifyFirst`` is set.
    /// - Printer status when ``PrintJobRequest/checkStatus`` is set: FAILURE
    ///   aborts the job, WARNING is reported and the job continues.
    public static func preflight(
        configuration: PrintConfiguration,
        request: PrintJobRequest,
        diagnostics: DiagnosticHandler? = nil
    ) async throws {
        if request.verifyFirst {
            let ok = try await DICOMVerificationService.verify(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                timeout: configuration.timeout
            )
            guard ok else {
                throw PrintRequestError(
                    "C-ECHO verification failed — printer AE is not responding correctly")
            }
            diagnostics?(.info("✓ C-ECHO verification succeeded"))
        }

        if request.checkStatus {
            let printerStatus = try await DICOMPrintService.getPrinterStatus(
                configuration: configuration)
            switch printerStatus.status {
            case "FAILURE":
                let info = printerStatus.statusInfo.map { " (\($0))" } ?? ""
                diagnostics?(.notice("✗ Printer reports FAILURE\(info) — aborting"))
                throw PrintWorkflowError.printerReportedFailure(info)
            case "WARNING":
                let info = printerStatus.statusInfo.map { " (\($0))" } ?? ""
                diagnostics?(.warning("⚠ Printer reports WARNING\(info) — continuing"))
            default:
                diagnostics?(.info("✓ Printer status: \(printerStatus.status)"))
            }
        }
    }

    /// Whether this printer can carry film-level annotation text.
    ///
    /// Asked before the frames are prepared, because the answer decides how they
    /// are prepared: a film footer travels as a Basic Annotation Box, and a
    /// printer that has none needs the caption burned into each image instead.
    /// Costs one short association; a printer that cannot be reached answers
    /// `false`, so the job falls back to burning rather than to nothing.
    public static func supportsAnnotationBoxes(
        configuration: PrintConfiguration
    ) async -> Bool {
        await DICOMPrintService.supportsAnnotationBoxes(configuration: configuration)
    }

    // MARK: Execute

    /// Prints the prepared images, honoring the request's retry policy.
    ///
    /// Retries apply only to *thrown* connection/setup failures, i.e. before the
    /// print job is submitted. A returned ``PrintResult`` — success or failure —
    /// is never retried, so a submitted job is never duplicated.
    ///
    /// - Parameters:
    ///   - configuration: Printer connection settings.
    ///   - request: The validated job description.
    ///   - images: Frames from ``PrintImagePreparer``, in film-cell order.
    ///   - diagnostics: Receives retry notices and printer events.
    ///   - progress: Receives SCU progress updates (nil uses the non-streaming API).
    public static func execute(
        configuration: PrintConfiguration,
        request: PrintJobRequest,
        images: [PreparedPrintImage],
        diagnostics: DiagnosticHandler? = nil,
        progress: ProgressHandler? = nil
    ) async throws -> PrintResult {
        let payloads = images.pixelPayloads
        let descriptors = images.imageDescriptors
        let options = request.printOptions
        let layout = request.resolvedLayout
        // Carries the band layouts a grid cannot state; nil lets the SCU size the
        // grid to the image count, as before.
        let displayFormat = request.resolvedDisplayFormat

        let eventHandler: PrintEventHandler? = diagnostics.map { handler -> PrintEventHandler in
            { (event: PrintEvent) in handler(.event(event)) }
        }

        let maxAttempts = max(1, request.retries + 1)
        let retryPolicy = PrintRetryPolicy(maxAttempts: request.retries)

        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await DICOMPrintService.printImages(
                    configuration: configuration,
                    images: payloads,
                    options: options,
                    imageDescriptors: descriptors,
                    layout: layout,
                    displayFormat: displayFormat,
                    eventHandler: eventHandler,
                    progressHandler: progress
                )
            } catch {
                // A cancelled job must not be retried.
                if error is CancellationError { throw error }
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = retryPolicy.delay(for: attempt)
                    diagnostics?(.notice(
                        "Attempt \(attempt + 1)/\(maxAttempts) failed: \(error). "
                        + "Retrying in \(String(format: "%.1f", delay))s..."))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? PrintRequestError("Print failed")
    }

    // MARK: Job status

    /// Queries the execution status of a submitted print job.
    public static func jobStatus(
        configuration: PrintConfiguration,
        printJobUID: String
    ) async throws -> PrintJobStatus {
        try await DICOMPrintService.getPrintJobStatus(
            configuration: configuration,
            printJobUID: printJobUID
        )
    }

    /// Queries printer status (N-GET) outside of a print job.
    public static func printerStatus(
        configuration: PrintConfiguration
    ) async throws -> PrinterStatus {
        try await DICOMPrintService.getPrinterStatus(configuration: configuration)
    }
}
