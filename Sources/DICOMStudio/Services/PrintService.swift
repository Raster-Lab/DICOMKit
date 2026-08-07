// PrintService.swift
// DICOMStudio
//
// DICOM Studio — DICOM print execution.
//
// A thin adapter over DICOMPrintKit: it turns the app's marked frames into
// prepared film images and runs the job. No DIMSE logic and no pixel
// preparation live here — both come from the shared print core, so the app and
// the dicom-print CLI put identical bytes on film.

import Foundation
import DICOMCore
import DICOMKit
import DICOMNetwork
import DICOMPrintKit

/// Executes DICOM print jobs on behalf of the app.
public struct PrintService: Sendable {

    /// Receives console lines as a job runs.
    public typealias DiagnosticHandler = @Sendable (PrintDiagnostic) -> Void

    /// Receives progress updates as a job runs.
    public typealias ProgressHandler = @Sendable (PrintProgress) -> Void

    private let preparer: PrintImagePreparer

    public init(preparer: PrintImagePreparer = PrintImagePreparer()) {
        self.preparer = preparer
    }

    // MARK: - Preparation

    /// Prepares the marked frames for printing, in marked order.
    ///
    /// Each mark carries its own frame index — and, when the viewer supplied
    /// one, its own window/level — so a request-wide frame selection would be
    /// wrong here. Every item is prepared under a request specialized to it.
    ///
    /// - Parameters:
    ///   - items: The marked frames, in film-cell order.
    ///   - request: The job settings the print sheet produced.
    ///   - useViewerWindow: When `true` (the default) a mark's captured window
    ///     overrides the file's own window, so the film matches the screen. The
    ///     request's explicit window still wins over both.
    ///   - applyViewerPresentation: When `true` (the default) the mark's zoom,
    ///     pan, rotation, flip and inversion are baked into the film pixels.
    ///     Cropping and permutation happen on the full-resolution decoded frame,
    ///     so a zoomed print keeps the modality's detail. Ignored for `raw`
    ///     requests, whose whole point is untouched stored pixels.
    ///   - annotations: Lines of identification to burn into each frame's
    ///     pixels, keyed by mark ID. Empty leaves the pixels alone. Burning is
    ///     how film carries a patient's name reliably: a DICOM printer draws
    ///     annotation boxes to its own layout, and many ignore them entirely.
    ///
    ///     Per mark rather than per file, because whether a mark carries its own
    ///     caption is a question about the *film* it lands on: one sheet of a
    ///     single study states the patient once at its foot, while the next
    ///     sheet — mixing studies — captions every image, and the same file can
    ///     be marked onto both.
    ///   - drawnAnnotations: The text and arrows a reader drew on each film cell,
    ///     keyed by mark ID — per mark rather than per file, because two marks can
    ///     be different frames of the same file and each carries its own drawing.
    ///   - onProgress: Optional per-frame diagnostic line.
    public func prepare(
        items: [PrintSelectionItem],
        request: PrintJobRequest,
        useViewerWindow: Bool = true,
        applyViewerPresentation: Bool = true,
        annotations: [String: [String]] = [:],
        drawnAnnotations: [String: [PrintOverlayAnnotation]] = [:],
        onProgress: PrintImagePreparer.ProgressHandler? = nil
    ) async throws -> [PreparedPrintImage] {
        var prepared: [PreparedPrintImage] = []
        // Files are re-read per mark rather than cached: marks routinely span
        // whole series, and holding every decoded frame would dwarf the film.
        for item in items {
            var itemRequest = request
            itemRequest.frameSelection = .single(item.frameIndex + 1)
            if request.windowSettings == nil, useViewerWindow, !request.raw,
               let center = item.windowCenter, let width = item.windowWidth, width >= 1 {
                // A mark carries the viewer's window, which is in stored values:
                // the renderer works on stored pixels, so `applyPreset` and
                // `applyDefaultWindow` divide the header's output-unit window
                // through the rescale pair before holding it. The preparer
                // windows *after* rescaling, so it is told which space these
                // numbers are in rather than left to assume the wrong one — on
                // a CT with a −1024 (or −8192) intercept that assumption puts
                // the window clear of every pixel and prints a black cell.
                itemRequest.windowSettings = WindowSettings(center: center, width: width)
                itemRequest.windowSpace = item.windowSpace
            }
            let frames = try await preparer.prepare(
                paths: [item.filePath],
                request: itemRequest,
                onProgress: onProgress
            )
            var arranged: [PreparedPrintImage]
            if applyViewerPresentation, !request.raw,
               let presentation = item.presentation, !presentation.isIdentity {
                arranged = frames.map { $0.applying(presentation, onProgress: onProgress) }
            } else {
                arranged = frames
            }

            // Burned last, on the pixels as they will be sent: cropping or
            // rotating afterwards would take the caption with it, and a
            // half-rotated patient name is worse than none. The reader's own
            // drawing goes on first and the identification caption over it — the
            // caption is the one thing on the film that must stay legible, and an
            // arrow drawn across the bottom would otherwise cover it.
            #if canImport(CoreGraphics)
            if !request.raw, let overlays = drawnAnnotations[item.id], !overlays.isEmpty {
                arranged = arranged.map { ImageAnnotationBurner.burning(overlays: overlays, into: $0) }
            }
            if !request.raw, let lines = annotations[item.id], !lines.isEmpty {
                arranged = arranged.map { ImageAnnotationBurner.burning(lines, into: $0) }
            }
            #endif

            prepared.append(contentsOf: arranged)
        }
        return prepared
    }

    // MARK: - Execution

    /// Runs the pre-flight checks the request asks for (C-ECHO, printer status).
    public func preflight(
        profile: PrinterProfile,
        request: PrintJobRequest,
        diagnostics: DiagnosticHandler? = nil
    ) async throws {
        try await PrintWorkflow.preflight(
            configuration: profile.printConfiguration(),
            request: request,
            diagnostics: diagnostics
        )
    }

    /// Prints prepared images, honoring the request's retry policy.
    public func print(
        images: [PreparedPrintImage],
        profile: PrinterProfile,
        request: PrintJobRequest,
        diagnostics: DiagnosticHandler? = nil,
        progress: ProgressHandler? = nil
    ) async throws -> PrintResult {
        try await PrintWorkflow.execute(
            configuration: profile.printConfiguration(),
            request: request,
            images: images,
            diagnostics: diagnostics,
            progress: progress
        )
    }

    // MARK: - Printer queries

    /// C-ECHO the printer AE (the "Test Connection" action).
    public func verify(profile: PrinterProfile) async throws -> Bool {
        let config = profile.printConfiguration()
        return try await DICOMVerificationService.verify(
            host: config.host,
            port: config.port,
            callingAE: config.callingAETitle,
            calledAE: config.calledAETitle,
            timeout: config.timeout
        )
    }

    /// Whether this printer can carry film-level annotation text (the patient
    /// footer). Costs one short association, and is asked before the frames are
    /// prepared because the answer decides whether they are captioned.
    public func supportsAnnotationBoxes(profile: PrinterProfile) async -> Bool {
        await PrintWorkflow.supportsAnnotationBoxes(
            configuration: profile.printConfiguration())
    }

    /// N-GET the printer's status.
    public func printerStatus(profile: PrinterProfile) async throws -> PrinterStatus {
        try await PrintWorkflow.printerStatus(configuration: profile.printConfiguration())
    }

    /// N-GET the execution status of a submitted print job.
    public func jobStatus(profile: PrinterProfile, printJobUID: String) async throws -> DICOMNetwork.PrintJobStatus {
        try await PrintWorkflow.jobStatus(
            configuration: profile.printConfiguration(),
            printJobUID: printJobUID
        )
    }
}
