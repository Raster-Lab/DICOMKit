// PrintViewModel.swift
// DICOMStudio
//
// DICOM Studio — state for the print settings sheet, printer management, and
// job execution. All print behavior comes from DICOMPrintKit; this type only
// holds UI state and sequences the calls.

import Foundation
import Observation
import DICOMCore
import DICOMKit
import DICOMNetwork
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@MainActor
@Observable
public final class PrintViewModel {

    // MARK: - Job phase

    /// Where the sheet is in the print flow.
    public enum Phase: Sendable, Equatable {
        case configuring
        case preparing
        case printing
        case finished(success: Bool)
    }

    // MARK: - Selection

    /// The frames to print, in film-cell order.
    public var selection: PrintSelectionModel

    // MARK: - Printers

    /// Configured printers.
    public private(set) var printers: [PrinterProfile] = []

    /// The printer the job goes to.
    public var selectedPrinterID: UUID?

    /// The selected printer, if any.
    public var selectedPrinter: PrinterProfile? {
        guard let selectedPrinterID else { return printers.first { $0.isDefault } ?? printers.first }
        return printers.first { $0.id == selectedPrinterID }
    }

    /// Last printer status query result, for the status pill.
    public private(set) var printerStatus: PrinterStatus?

    /// Whether a printer query (echo/status) is in flight.
    public private(set) var isQueryingPrinter = false

    /// Result text of the last Test Connection / Query Status action.
    public private(set) var printerQueryMessage: String?

    // MARK: - Job settings

    /// Basic settings, shown in the sheet's visible zone.
    public var copies: Int = 1
    public var layoutMode: LayoutMode = .automatic

    /// The viewer's tile grid, when the sheet was raised from a viewer showing
    /// one. Lets the film mirror the arrangement on screen cell for cell.
    public var viewerLayout: PrintLayout?
    public var layoutOption: PrintLayoutOption = .layout2x2
    public var templatePreset: PrintTemplatePreset = .grid
    public var filmSize: FilmSize = .size14InX17In
    public var filmOrientation: FilmOrientation = .portrait

    /// Advanced settings.
    public var priority: DICOMNetwork.PrintPriority = .medium
    public var mediumType: MediumType = .paper
    public var filmDestination: FilmDestination = .processor
    public var magnificationType: MagnificationType = .replicate
    public var trimOption: TrimOption = .no
    public var borderDensity: String = "BLACK"
    public var emptyImageDensity: String = "BLACK"
    public var polarity: ImagePolarity = .normal
    public var colorMode: DICOMNetwork.PrintColorMode = .grayscale
    public var autoDetectColorMode: Bool = true
    public var bitDepth: Int = 8
    public var presentationLUTShape: DICOMNetwork.PresentationLUTShape?
    public var sessionLabel: String = ""
    public var configurationInformation: String = ""
    public var annotationTexts: [String] = []
    public var annotationDisplayFormatID: String = ""
    public var useViewerWindow: Bool = true
    /// Bake each mark's zoom, pan, rotation, flip and inversion into the film.
    ///
    /// On by default: the user composed the image on screen, and the film should
    /// be that image. Turn it off to print whole, unrotated frames.
    public var useViewerPresentation: Bool = true
    public var useExplicitWindow: Bool = false
    public var explicitWindowCenter: Double = 40
    public var explicitWindowWidth: Double = 400
    public var sendRawPixels: Bool = false
    public var checkStatusBeforePrinting: Bool = true
    public var verifyBeforePrinting: Bool = false
    public var retries: Int = 0
    public var timeoutSeconds: Double = 60
    public var dryRun: Bool = false

    /// How the layout is chosen.
    public enum LayoutMode: String, CaseIterable, Sendable, Identifiable {
        case matchViewer
        case automatic
        case explicit
        case template

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .matchViewer: return "Viewer"
            case .automatic:   return "Automatic"
            case .explicit:    return "Layout"
            case .template:    return "Preset"
            }
        }
    }

    // MARK: - Run state

    /// Current phase of the flow.
    public private(set) var phase: Phase = .configuring

    /// Console lines, oldest first, rendered by the shared formatter.
    public private(set) var consoleLines: [ConsoleLine] = []

    /// Fraction complete, 0...1, while printing.
    public private(set) var progress: Double = 0

    /// The most recent progress message.
    public private(set) var progressMessage: String = ""

    /// Result of the last completed job.
    public private(set) var result: PrintResult?

    /// Status of a queried print job.
    public private(set) var jobStatus: DICOMNetwork.PrintJobStatus?

    /// Submitted jobs, newest first.
    public private(set) var history: [PrintJobHistoryEntry] = []

    /// A console line with a severity, so the view can style it.
    public struct ConsoleLine: Identifiable, Sendable, Equatable {
        public enum Level: Sendable { case info, notice, warning, failure, success }
        public let id = UUID()
        public let level: Level
        public let text: String
    }

    /// Whether a job is currently running.
    public var isRunning: Bool {
        phase == .preparing || phase == .printing
    }

    // MARK: - Dependencies

    private let service: PrintService
    private let printerStorage: PrinterProfileStorageService
    private let historyStorage: PrintJobHistoryStorageService
    private var runTask: Task<Void, Never>?

    public init(
        selection: PrintSelectionModel = PrintSelectionModel(),
        service: PrintService = PrintService(),
        printerStorage: PrinterProfileStorageService = PrinterProfileStorageService(),
        historyStorage: PrintJobHistoryStorageService = PrintJobHistoryStorageService()
    ) {
        self.selection = selection
        self.service = service
        self.printerStorage = printerStorage
        self.historyStorage = historyStorage
        loadPrinters()
        history = historyStorage.load()
    }

    // MARK: - Printer management

    /// Reloads printers from storage and re-resolves the selected one.
    public func loadPrinters() {
        printers = printerStorage.load()
        if selectedPrinterID == nil || !printers.contains(where: { $0.id == selectedPrinterID }) {
            selectedPrinterID = (printers.first { $0.isDefault } ?? printers.first)?.id
        }
    }

    /// Adds or updates a printer, enforcing a single default.
    public func save(_ profile: PrinterProfile) {
        var updated = printers
        if profile.isDefault {
            for index in updated.indices { updated[index].isDefault = false }
        }
        if let index = updated.firstIndex(where: { $0.id == profile.id }) {
            updated[index] = profile
        } else {
            updated.append(profile)
        }
        // The first printer added is the default — otherwise nothing is selected.
        if !updated.contains(where: { $0.isDefault }), !updated.isEmpty {
            updated[0].isDefault = true
        }
        persist(updated)
        selectedPrinterID = profile.id
    }

    /// Removes a printer.
    public func delete(_ profile: PrinterProfile) {
        var updated = printers.filter { $0.id != profile.id }
        if !updated.contains(where: { $0.isDefault }), !updated.isEmpty {
            updated[0].isDefault = true
        }
        persist(updated)
        if selectedPrinterID == profile.id {
            selectedPrinterID = (updated.first { $0.isDefault } ?? updated.first)?.id
        }
    }

    /// Makes a printer the default.
    public func makeDefault(_ profile: PrinterProfile) {
        var updated = printers
        for index in updated.indices {
            updated[index].isDefault = (updated[index].id == profile.id)
        }
        persist(updated)
    }

    private func persist(_ profiles: [PrinterProfile]) {
        printers = profiles
        do {
            try printerStorage.save(profiles)
        } catch {
            append(.warning, "Could not save printers: \(error.localizedDescription)")
        }
    }

    /// C-ECHO the selected printer.
    public func testConnection() async {
        guard let printer = selectedPrinter else { return }
        isQueryingPrinter = true
        printerQueryMessage = nil
        defer { isQueryingPrinter = false }
        do {
            let ok = try await service.verify(profile: printer)
            printerQueryMessage = ok
                ? "✓ C-ECHO succeeded"
                : "✗ C-ECHO failed — printer AE is not responding correctly"
            updateStatus(of: printer, to: ok ? .online : .error, verified: ok)
        } catch {
            printerQueryMessage = "✗ C-ECHO failed: \(error.localizedDescription)"
            updateStatus(of: printer, to: .error, verified: false)
        }
    }

    /// N-GET the selected printer's status.
    public func queryPrinterStatus() async {
        guard let printer = selectedPrinter else { return }
        isQueryingPrinter = true
        printerQueryMessage = nil
        defer { isQueryingPrinter = false }
        do {
            let status = try await service.printerStatus(profile: printer)
            printerStatus = status
            printerQueryMessage = PrintConsoleFormatter.printerStatusText(status)
                .joined(separator: "\n")
            updateStatus(of: printer, to: status.isNormal ? .online : .error, verified: status.isNormal)
        } catch {
            printerStatus = nil
            printerQueryMessage = "✗ Status query failed: \(error.localizedDescription)"
            updateStatus(of: printer, to: .error, verified: false)
        }
    }

    private func updateStatus(of printer: PrinterProfile, to status: ServerConnectionStatus, verified: Bool) {
        guard let index = printers.firstIndex(where: { $0.id == printer.id }) else { return }
        printers[index].status = status
        if verified { printers[index].lastVerifiedDate = Date() }
    }

    // MARK: - Request

    /// The print job the current settings describe.
    public var request: PrintJobRequest {
        let annotations = annotationTexts
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { DICOMNetwork.PrintAnnotation(position: UInt16($0.offset + 1), text: $0.element) }

        let layoutSelection: PrintLayoutSelection
        switch layoutMode {
        case .matchViewer:
            // Falls back to automatic if the sheet was opened without a viewer
            // grid behind it (e.g. "Print…" straight from the library).
            layoutSelection = viewerLayout.map { .custom($0) } ?? .automatic
        case .automatic: layoutSelection = .automatic
        case .explicit:  layoutSelection = .explicit(layoutOption)
        case .template:  layoutSelection = .template(templatePreset)
        }

        let trimmedFormatID = annotationDisplayFormatID.trimmingCharacters(in: .whitespaces)
        let trimmedLabel = sessionLabel.trimmingCharacters(in: .whitespaces)
        let trimmedConfig = configurationInformation.trimmingCharacters(in: .whitespaces)

        return PrintJobRequest(
            copies: copies,
            priority: priority,
            mediumType: mediumType,
            filmDestination: filmDestination,
            sessionLabel: trimmedLabel.isEmpty ? nil : trimmedLabel,
            layoutSelection: layoutSelection,
            filmSize: filmSize,
            filmOrientation: filmOrientation,
            magnificationType: magnificationType,
            borderDensity: borderDensity,
            emptyImageDensity: emptyImageDensity,
            trimOption: trimOption,
            configurationInformation: trimmedConfig.isEmpty ? nil : trimmedConfig,
            polarity: polarity,
            presentationLUTShape: presentationLUTShape,
            annotations: annotations,
            annotationDisplayFormatID: trimmedFormatID.isEmpty ? nil : trimmedFormatID,
            colorMode: resolvedColorMode,
            frameSelection: .first,     // per-mark frames are applied by PrintService
            raw: sendRawPixels,
            windowSettings: (useExplicitWindow && !sendRawPixels)
                ? WindowSettings(center: explicitWindowCenter, width: explicitWindowWidth)
                : nil,
            bitDepth: sendRawPixels ? 8 : bitDepth,
            verifyFirst: verifyBeforePrinting,
            checkStatus: checkStatusBeforePrinting,
            retries: retries,
            dryRun: dryRun
        )
    }

    /// The color mode actually used: the printer's own mode when auto-detecting.
    public var resolvedColorMode: DICOMNetwork.PrintColorMode {
        guard autoDetectColorMode, let printer = selectedPrinter else { return colorMode }
        return printer.colorMode.printColorMode
    }

    /// The film-by-film plan for the current selection and settings.
    public var plan: PrintPlan {
        request.plan(forImageCount: selection.count)
    }

    /// One-line plan summary for the sheet header.
    public var planSummary: String {
        PrintConsoleFormatter.planSummary(plan)
    }

    /// Whether the current settings can start a job.
    public var canPrint: Bool {
        selectedPrinter != nil && !selection.isEmpty && !isRunning && validationMessage == nil
    }

    /// The first validation problem with the current settings, if any.
    public var validationMessage: String? {
        do {
            try request.validate()
            return nil
        } catch let error as PrintRequestError {
            return error.message
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Running a job

    /// Prepares and prints the current selection.
    public func print() {
        guard let printer = selectedPrinter, !selection.isEmpty else { return }
        guard validationMessage == nil else { return }

        let items = selection.items
        let jobRequest = request
        let useViewerWindow = self.useViewerWindow
        let useViewerPresentation = self.useViewerPresentation
        let service = self.service

        consoleLines = []
        result = nil
        jobStatus = nil
        progress = 0
        progressMessage = ""
        phase = .preparing

        runTask = Task { [weak self] in
            guard let self else { return }

            let plan = jobRequest.plan(forImageCount: items.count)
            self.append(.info, PrintConsoleFormatter.planSummary(plan))
            if plan.filmCount > 1 {
                for line in PrintConsoleFormatter.planDetail(plan) {
                    self.append(.info, line)
                }
            }

            if jobRequest.dryRun {
                self.append(.notice, "Dry run — nothing was sent to the printer.")
                self.phase = .finished(success: true)
                return
            }

            let diagnostics: PrintService.DiagnosticHandler = { [weak self] diagnostic in
                Task { @MainActor in self?.appendDiagnostic(diagnostic) }
            }
            let progressHandler: PrintService.ProgressHandler = { [weak self] update in
                Task { @MainActor in
                    self?.progress = update.progress
                    self?.progressMessage = update.message
                }
            }

            do {
                try await service.preflight(
                    profile: printer, request: jobRequest, diagnostics: diagnostics)

                let images = try await service.prepare(
                    items: items,
                    request: jobRequest,
                    useViewerWindow: useViewerWindow,
                    applyViewerPresentation: useViewerPresentation,
                    onProgress: { line in
                        Task { @MainActor in self.append(.info, line) }
                    }
                )
                if Task.isCancelled { return }

                self.phase = .printing
                self.progressMessage = "Printing \(images.count) image(s)…"

                let outcome = try await service.print(
                    images: images,
                    profile: printer,
                    request: jobRequest,
                    diagnostics: diagnostics,
                    progress: progressHandler
                )

                self.finish(with: outcome, printer: printer, plan: plan, imageCount: images.count)
            } catch is CancellationError {
                self.append(.notice, "Print cancelled.")
                self.phase = .configuring
            } catch let error as PrintRequestError {
                self.fail(error.message, printer: printer, plan: plan)
            } catch let error as PrintWorkflowError {
                self.fail(error.description, printer: printer, plan: plan)
            } catch {
                self.fail(error.localizedDescription, printer: printer, plan: plan)
            }
        }
    }

    /// Cancels a running job.
    ///
    /// The SCU tears the association down on cancellation and issues a
    /// best-effort Film Session N-DELETE, so a cancelled job does not leave the
    /// printer holding a session.
    public func cancel() {
        runTask?.cancel()
        runTask = nil
    }

    /// Queries the status of a print job from the last result.
    public func refreshJobStatus(printJobUID: String) async {
        guard let printer = selectedPrinter else { return }
        do {
            jobStatus = try await service.jobStatus(profile: printer, printJobUID: printJobUID)
            for line in PrintConsoleFormatter.jobStatusText(jobStatus!) {
                append(.info, line)
            }
        } catch {
            append(.failure, "Job status query failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Completion

    private func finish(with outcome: PrintResult, printer: PrinterProfile, plan: PrintPlan, imageCount: Int) {
        result = outcome
        progress = 1.0
        for line in PrintConsoleFormatter.printResultText(outcome) {
            append(outcome.success ? .success : .failure, line)
        }
        if outcome.printJobUIDs.count > 1 {
            append(.info, "Print job UIDs: \(outcome.printJobUIDs.joined(separator: ", "))")
        }
        phase = .finished(success: outcome.success)
        record(
            printer: printer,
            plan: plan,
            imageCount: imageCount,
            success: outcome.success,
            printJobUIDs: outcome.printJobUIDs,
            filmSessionUID: outcome.filmSessionUID,
            errorMessage: outcome.errorMessage
        )
    }

    private func fail(_ message: String, printer: PrinterProfile, plan: PrintPlan) {
        append(.failure, "✗ Print failed")
        append(.failure, "  Error: \(message)")
        phase = .finished(success: false)
        record(
            printer: printer,
            plan: plan,
            imageCount: selection.count,
            success: false,
            printJobUIDs: [],
            filmSessionUID: nil,
            errorMessage: message
        )
    }

    private func record(
        printer: PrinterProfile,
        plan: PrintPlan,
        imageCount: Int,
        success: Bool,
        printJobUIDs: [String],
        filmSessionUID: String?,
        errorMessage: String?
    ) {
        let entry = PrintJobHistoryEntry(
            printerName: printer.name,
            imageCount: imageCount,
            filmCount: plan.filmCount,
            copies: plan.copies,
            layout: "\(plan.layout.rows)×\(plan.layout.columns)",
            success: success,
            printJobUIDs: printJobUIDs,
            filmSessionUID: filmSessionUID,
            errorMessage: errorMessage
        )
        history.insert(entry, at: 0)
        try? historyStorage.save(history)
    }

    // MARK: - Console

    private func appendDiagnostic(_ diagnostic: PrintDiagnostic) {
        switch diagnostic {
        case .info(let text):    append(.info, text)
        case .notice(let text):  append(.notice, text)
        case .warning(let text): append(.warning, text)
        case .event(let event):  append(event.isFault ? .warning : .info, event.summary)
        }
    }

    private func append(_ level: ConsoleLine.Level, _ text: String) {
        consoleLines.append(ConsoleLine(level: level, text: text))
    }

    /// Resets the sheet to configuring after a finished job.
    public func reset() {
        phase = .configuring
        progress = 0
        progressMessage = ""
        result = nil
        jobStatus = nil
    }
}
