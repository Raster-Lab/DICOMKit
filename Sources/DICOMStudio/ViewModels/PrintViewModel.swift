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

    // MARK: - Preview editing

    /// The film cell the preview's tools act on. See
    /// `PrintViewModel+CellEditing.swift`.
    public var focusedItemID: String?

    /// The run of image numbers each series carries on film, keyed by
    /// ``PrintSelectionItem/seriesKey``. A series with no entry prints whole.
    /// See `PrintViewModel+ImageRange.swift`.
    public var imageRanges: [String: ClosedRange<Int>] = [:]

    /// Instance Numbers of the marked files, read on demand — what the image
    /// range matches against.
    public let imageNumbers = PrintImageNumberCache()

    /// Cells picked out by hand, by mark ID. See
    /// `PrintViewModel+CellSelection.swift`.
    ///
    /// While this holds two or more, a tool acts on exactly these and the sync
    /// locks stand aside: an explicit selection is a statement the reader has
    /// just made, and a rule quietly widening it would undo the point of making
    /// it.
    public var selectedItemIDs: Set<String> = []

    /// Which cell edits are carried to the other cells as they are made.
    /// See `PrintViewModel+CellSync.swift`.
    public var cellSync: PrintCellSyncOptions = []

    /// How far a synchronised edit reaches.
    public var cellSyncScope: PrintCellSyncScope = .sameSeries

    /// What a drag on a film cell does.
    public enum CellTool: String, CaseIterable, Sendable, Identifiable {
        case window
        case zoom
        case pan
        case text
        case arrow

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .window: return "Window/Level"
            case .zoom:   return "Zoom"
            case .pan:    return "Pan"
            case .text:   return "Text Annotation"
            case .arrow:  return "Arrow"
            }
        }

        public var symbolName: String {
            switch self {
            // The pointer, not the half-filled circle. The circle is the
            // *result* of windowing — it is the same glyph the Invert button
            // carries, mirrored — and two buttons a few points apart showing
            // the same shape is what made the rail hard to scan. The pointer
            // says what the button arms instead: a drag, on a cell.
            case .window: return "cursorarrow"
            case .zoom:   return "magnifyingglass"
            case .pan:    return "hand.draw"
            case .text:   return "character.textbox"
            case .arrow:  return "arrow.up.left"
            }
        }

        /// Whether this tool draws something new rather than adjusting the picture.
        public var isDrawing: Bool {
            self == .text || self == .arrow
        }
    }

    /// The active preview tool. Windowing by default — it is the adjustment a
    /// film is actually rejected over.
    public var cellTool: CellTool = .window

    // MARK: - Drawn annotations

    /// The text and arrows drawn on each cell, keyed by mark ID. See
    /// `PrintViewModel+Annotations.swift`.
    public var cellAnnotations: [String: [PrintOverlayAnnotation]] = [:]

    /// The annotation the inspector is editing, if any.
    public var selectedAnnotationID: UUID?

    /// Size the next annotation is drawn at, as a fraction of the image's height.
    /// Changing a selected annotation's size adopts it here too.
    public var annotationScale: Double = PrintOverlayAnnotation.defaultScale

    /// Colour the next annotation is drawn in.
    public var annotationColor: PrintOverlayColor = .yellow

    /// Whether patient identification is drawn over each image and burned into
    /// the film.
    ///
    /// One setting for both halves of the same intent: the preview overlays the
    /// text (cheap, and it moves with the cell as it is windowed and zoomed) and
    /// the print run burns those same lines into the pixels it sends. Burning is
    /// what makes it reliable — a DICOM printer draws annotation boxes to its own
    /// layout and many ignore them — and it costs one bitmap pass per film cell.
    ///
    /// On by default: film that cannot be tied to a patient is not useful film.
    public var showPatientIdentification: Bool = true

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

    /// An Image Display Format (2010,0010) typed by hand, for the films a grid
    /// cannot describe: `ROW\2,1,2` puts two images over one over two.
    ///
    /// Held as text, not as a parsed value, because it is edited a character at a
    /// time and "ROW\2," is not a layout yet — the film keeps the last one that
    /// was while the rest is typed.
    public var customLayoutText: String = "ROW\\1,2"
    public var filmSize: FilmSize = .size14InX17In
    public var filmOrientation: FilmOrientation = .portrait

    /// How images are scaled to their cells (SRS FR-003).
    public var scalingMode: PrintScalingMode = .fitToFilm

    /// Where an image sits in a cell it does not fill (SRS FR-003). Applies to
    /// composed film (preview, save, the emulator); a real printer centres.
    public var cellAlignment: PrintCellAlignment = .center

    /// Advanced settings.
    public var priority: DICOMNetwork.PrintPriority = .medium
    // Department defaults, chosen for the common radiology setup: blue-base
    // film out of the magazine, smoothed on the printer's side. Not persisted —
    // every launch starts from these, and `resetForNewFilm()` keeps a session's
    // own changes only between films, not between launches.
    public var mediumType: MediumType = .blueFilm
    public var filmDestination: FilmDestination = .magazine
    public var magnificationType: MagnificationType = .bilinear
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

    /// The optional identification fields this job burns (SRS FR-006).
    ///
    /// Birth date and institution on by default — a deliberate choice, since
    /// both are burned into pixels and survive later header de-identification;
    /// film that reaches another hospital is expected to say who it is about
    /// and where it was made. Accession number and series description stay off
    /// unless asked for.
    public var identificationFields: PrintIdentificationFields = [.birthDate, .institutionName]

    /// Typography of the burned identification (SRS FR-006). Custom values
    /// feed ``identificationStyle``; the defaults are the automatic behaviour.
    public var identificationFontFamily: String = "Helvetica"
    public var identificationUsesCustomSize: Bool = false
    public var identificationSizePercent: Double = 3.5
    public var identificationForeground: PrintAnnotationStyle.Foreground = .automatic

    /// The style the burner is handed for this job.
    public var identificationStyle: PrintAnnotationStyle {
        PrintAnnotationStyle(
            fontFamily: identificationFontFamily.trimmingCharacters(in: .whitespaces)
                .isEmpty ? "Helvetica" : identificationFontFamily,
            sizeFraction: identificationUsesCustomSize
                ? identificationSizePercent / 100 : nil,
            foreground: identificationForeground)
    }

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
        /// A hand-written Image Display Format — see ``customLayoutText``.
        case custom

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .matchViewer: return "Viewer"
            case .automatic:   return "Automatic"
            case .explicit:    return "Layout"
            case .template:    return "Preset"
            case .custom:      return "Custom"
            }
        }
    }

    /// The typed format, if what is in the field is one.
    ///
    /// `nil` while the text is not a valid Image Display Format, which is what
    /// the field shows as a warning and what makes the film fall back to the
    /// automatic grid rather than silently printing 1×1.
    public var customLayoutFormat: PrintImageDisplayFormat? {
        PrintImageDisplayFormat.validated(customLayoutText)
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

    /// Results of re-querying past jobs from the history pane, keyed by entry.
    ///
    /// In-memory only: an execution status is what the printer says right now,
    /// so a stale answer from a previous launch would mislead.
    public private(set) var historyStatusChecks: [PrintJobHistoryEntry.ID: HistoryStatusCheck] = [:]

    /// One re-query of a past job, as the history pane renders it.
    public enum HistoryStatusCheck: Sendable, Equatable {
        case running
        /// One line per film, plus whether any film failed or errored.
        case checked(lines: [HistoryJobStatusLine], anyFailed: Bool)
        /// The entry cannot be queried — printer removed, for instance.
        case unavailable(String)
    }

    /// One film's execution status within a history re-query.
    public struct HistoryJobStatusLine: Sendable, Equatable {
        public enum Kind: Sendable, Equatable { case completed, inProgress, failed }
        public let text: String
        public let kind: Kind
    }

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

    /// Whether the submitted job is sitting in the queue rather than printing.
    ///
    /// The sheet is showing progress, but nothing is happening and nothing will
    /// until the queue is resumed — so the job outlives the sheet, and the user
    /// can close it without cancelling anything.
    public var isWaitingOnQueue: Bool {
        guard let id = submittedJobID, isRunning else { return false }
        return queue.runningJobID != id
    }

    // MARK: - Dependencies

    /// The print queue every submitted job goes through. Serial: one job's
    /// association finishes before the next opens.
    public let queue: PrintQueueService

    /// The app-side audit trail: every queue action and job outcome, recorded
    /// with a timestamp and persisted locally. No user accounts are involved.
    public let auditTrail: PrintAuditTrail

    private let service: PrintService
    private let jobStatusQuerier: any PrintJobStatusQuerying
    private let printerStorage: PrinterProfileStorageService
    private let historyStorage: PrintJobHistoryStorageService
    private let statusMonitor: PrinterStatusMonitor
    private var runTask: Task<Void, Never>?
    private var monitorObservationTask: Task<Void, Never>?

    /// The queue job the print sheet is currently mirroring, if any.
    private var submittedJobID: UUID?

    public init(
        selection: PrintSelectionModel = PrintSelectionModel(),
        service: PrintService = PrintService(),
        printerStorage: PrinterProfileStorageService = PrinterProfileStorageService(),
        historyStorage: PrintJobHistoryStorageService = PrintJobHistoryStorageService(),
        auditStorage: PrintAuditTrailStorageService = PrintAuditTrailStorageService(),
        statusMonitor: PrinterStatusMonitor? = nil,
        jobStatusQuerier: (any PrintJobStatusQuerying)? = nil,
        queueStorage: PrintQueueStorageService? = nil
    ) {
        self.selection = selection
        self.service = service
        self.jobStatusQuerier = jobStatusQuerier ?? service
        self.printerStorage = printerStorage
        self.historyStorage = historyStorage
        self.statusMonitor = statusMonitor ?? PrinterStatusMonitor(probe: service)
        let trail = PrintAuditTrail(storage: auditStorage)
        self.auditTrail = trail
        // `nil` storage keeps stray instances (previews, standalone viewers) and
        // tests off the real queue file; the app's shared instance passes one.
        self.queue = PrintQueueService(service: service, audit: trail, storage: queueStorage)
        loadPrinters()
        history = historyStorage.load()
        // History is recorded off the queue, not the sheet, so a job resent
        // from the queue screen lands in history like any other.
        queue.onJobFinished = { [weak self] job, outcome in
            self?.recordFinishedJob(job, outcome: outcome)
        }
        // The FR-012 offline auto-queue: a job whose printer's last monitored
        // status is offline stays queued instead of failing against a dead
        // socket. Only a monitored printer holds jobs — an unmonitored one has
        // no live status to trust, so its jobs run and fail honestly.
        queue.isPrinterReady = { [weak self] profile in
            guard let self,
                  let current = self.printers.first(where: { $0.id == profile.id }),
                  current.isMonitoringEnabled else { return true }
            return current.status != .offline
        }
    }

    // MARK: - Background status monitoring (FR-012)

    /// Starts observing the background monitor and polls the printers that opt in.
    ///
    /// Called when the print screen appears. Safe to call repeatedly — the
    /// observation task is only created once.
    public func startMonitoring() {
        if monitorObservationTask == nil {
            let monitor = statusMonitor
            monitorObservationTask = Task { [weak self] in
                for await update in await monitor.updates() {
                    guard !Task.isCancelled else { return }
                    self?.apply(update)
                }
            }
        }
        let profiles = printers
        Task { [statusMonitor] in await statusMonitor.sync(profiles: profiles) }
    }

    /// Stops all background polling. Called when the print screen goes away, so
    /// a backgrounded app is not holding associations open on hospital printers.
    public func stopMonitoring() {
        monitorObservationTask?.cancel()
        monitorObservationTask = nil
        Task { [statusMonitor] in await statusMonitor.stopAll() }
    }

    /// Folds one poll result into the printer list.
    func apply(_ update: PrinterStatusUpdate) {
        guard let index = printers.firstIndex(where: { $0.id == update.printerID }) else { return }
        printers[index].status = update.connectionStatus
        printers[index].lastStatusCheckDate = update.checkedAt
        printers[index].lastStatusDetail = update.detail
        // Only a printer that actually answered counts as verified.
        if update.errorDescription == nil {
            printers[index].lastVerifiedDate = update.checkedAt
        }
        // Deliberately not persisted: status is observed state, and writing
        // printer-profiles.json on every poll would rewrite the file every few
        // seconds per printer for data that is meaningless after a restart.
        if update.printerID == selectedPrinterID, let status = update.status {
            printerStatus = status
        }
        // A printer coming back is the signal a held job has been waiting for.
        if update.connectionStatus != .offline {
            queue.reevaluate()
        }
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
        // Every printer edit funnels through here, so this is the one place that
        // has to tell the monitor about an added, removed or re-timed printer.
        if monitorObservationTask != nil {
            Task { [statusMonitor] in await statusMonitor.sync(profiles: profiles) }
        }
    }

    /// C-ECHO the selected printer.
    public func testConnection() async {
        guard let printer = selectedPrinter else { return }
        isQueryingPrinter = true
        printerQueryMessage = nil
        // A C-ECHO says nothing about printer status, so leaving the previous
        // N-GET result on screen would caption this probe with stale detail.
        printerStatus = nil
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
            updateStatus(
                of: printer,
                to: Self.connectionStatus(for: status.severity),
                // A WARNING printer answered the N-GET, so the association is
                // verified even though the printer is telling us about a problem.
                verified: status.severity.acceptsJobs
            )
        } catch {
            printerStatus = nil
            printerQueryMessage = "✗ Status query failed: \(error.localizedDescription)"
            updateStatus(of: printer, to: .error, verified: false)
        }
    }

    /// Drops the last probe result.
    ///
    /// Nothing expires `printerQueryMessage` on its own, so without this the
    /// text from a probe run minutes ago reappears the next time the sheet is
    /// opened, reading as a fresh answer about the printer's current state.
    public func clearPrinterProbeResult() {
        printerQueryMessage = nil
        printerStatus = nil
    }

    /// Maps a printer's reported severity onto the shared connection-status enum.
    ///
    /// WARNING stays distinct from FAILURE: a printer low on film still prints,
    /// and collapsing the two would either hide a real fault or block usable work.
    nonisolated static func connectionStatus(for severity: PrinterStatusSeverity) -> ServerConnectionStatus {
        switch severity {
        case .normal:  return .online
        case .warning: return .warning
        case .failure: return .error
        case .unknown: return .unknown
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
        case .custom:
            // Half-typed text is not a layout; the film waits rather than
            // printing the 1×1 a lenient parse would have made of it.
            layoutSelection = customLayoutFormat.map { .displayFormat($0) } ?? .automatic
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
            scalingMode: scalingMode,
            cellAlignment: cellAlignment,
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
        // Counted from what the films actually carry, not from every mark: an
        // image range narrows the job to a run of the series, and a plan
        // counting the marks it is holding back would report films nobody asked
        // for and page the preview past the end of the sheet.
        request.plan(forImageCount: printedItems.count)
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

    /// Submits the current selection to the print queue.
    ///
    /// The sheet's phase, console and progress mirror the queue's execution of
    /// this job through the handlers passed at enqueue — the run itself belongs
    /// to ``queue``, which serializes it against anything else waiting.
    public func print() {
        guard let printer = selectedPrinter, !selection.isEmpty else { return }
        guard validationMessage == nil else { return }

        let items = printedItems
        let jobRequest = request
        let useViewerWindow = self.useViewerWindow
        let useViewerPresentation = self.useViewerPresentation
        let burnIdentification = self.showPatientIdentification
        let drawnAnnotations = self.annotationsForPrinting

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

            // Read from the files themselves, so what is burned in does not
            // depend on the preview having been opened. Captured now, before
            // enqueueing: the queue may hold the job while the sheet moves on,
            // and the job must print what was on the film when it was submitted.
            let texts = burnIdentification
                ? await self.identificationTexts(for: items) : [:]
            let identifications = self.filmIdentifications(
                for: items, texts: texts, plan: plan)

            // Burned into the pixels rather than sent as annotation boxes:
            // the caption names the image it sits under — its number, its
            // slice thickness — so it has to travel with that image, and a
            // printer lays annotation boxes out to its own configured
            // format wherever it likes.
            let annotationLines = self.identificationBurns(
                for: items, texts: texts, identifications: identifications, plan: plan)
            if !annotationLines.isEmpty {
                self.append(.info, "Burning patient identification into \(annotationLines.count) image(s)")
            }
            if !drawnAnnotations.isEmpty {
                let count = drawnAnnotations.values.reduce(0) { $0 + $1.count }
                self.append(.info,
                            "Burning \(count) drawn annotation(s) into "
                            + "\(drawnAnnotations.count) image(s)")
            }
            if !drawnAnnotations.isEmpty, jobRequest.raw {
                self.append(.warning,
                            "Raw pixels are being sent — drawn annotations are not burned in.")
            }
            if Task.isCancelled {
                self.append(.notice, "Print cancelled.")
                self.phase = .configuring
                return
            }

            let payload = PrintQueuePayload(
                items: items,
                request: jobRequest,
                profile: printer,
                useViewerWindow: useViewerWindow,
                useViewerPresentation: useViewerPresentation,
                annotations: annotationLines,
                annotationStyle: self.identificationStyle,
                drawnAnnotations: drawnAnnotations
            )

            let handlers = PrintQueueJobHandlers(
                onDiagnostic: { [weak self] diagnostic in self?.appendDiagnostic(diagnostic) },
                onConsole: { [weak self] line in self?.append(.info, line) },
                onPhase: { [weak self] printing in
                    self?.phase = printing ? .printing : .preparing
                },
                onProgress: { [weak self] fraction, message in
                    self?.progress = fraction
                    self?.progressMessage = message
                },
                onFinish: { [weak self] outcome in self?.applySheetOutcome(outcome) }
            )

            let layoutText = plan.displayFormat.isUniformGrid
                ? "\(plan.layout.rows)×\(plan.layout.columns)"
                : plan.displayFormat.raw
            self.submittedJobID = self.queue.enqueue(
                payload: payload,
                imageCount: items.count,
                filmCount: plan.filmCount,
                copies: plan.copies,
                layout: layoutText,
                handlers: handlers
            )
            if self.queue.isPaused {
                self.append(.notice, "The print queue is paused — the job starts when the queue is resumed.")
            } else if self.queue.runningJobID != self.submittedJobID {
                self.append(.info, "Queued behind the job currently printing.")
            }
        }
    }

    /// Folds the queue's outcome for the sheet-submitted job back into the
    /// sheet's own state.
    private func applySheetOutcome(_ outcome: PrintQueueOutcome) {
        submittedJobID = nil
        switch outcome {
        case .finished(let printResult, _):
            result = printResult
            progress = 1.0
            for line in PrintConsoleFormatter.printResultText(printResult) {
                append(printResult.success ? .success : .failure, line)
            }
            if printResult.printJobUIDs.count > 1 {
                append(.info, "Print job UIDs: \(printResult.printJobUIDs.joined(separator: ", "))")
            }
            phase = .finished(success: printResult.success)
        case .failed(let message):
            append(.failure, "✗ Print failed")
            append(.failure, "  Error: \(message)")
            phase = .finished(success: false)
        case .cancelled:
            append(.notice, "Print cancelled.")
            phase = .configuring
        }
    }

    // MARK: - Saving the film

    /// Whether a film is being composed for a file right now.
    ///
    /// Composing re-reads and re-renders every marked frame, so it is not
    /// instant on a full sheet — the button says so rather than looking dead.
    public private(set) var isSavingFilm = false

    /// A file name for the composed film, taken from what is on it.
    public var suggestedFilmFileName: String {
        let label = selection.items.first?.displayLabel ?? "film"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = String(label.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return cleaned.isEmpty ? "film" : cleaned
    }

    /// Composes the marked images into film sheets and writes them to `url`.
    ///
    /// Not a picture of the preview: the images go through the same
    /// ``PrintService/prepare(items:request:useViewerWindow:applyViewerPresentation:annotations:drawnAnnotations:onProgress:)``
    /// an actual print sends them through, and the sheet comes out of the same
    /// ``FilmComposer`` the printer emulator composes a received film with. What
    /// lands on disk is therefore the film the printer would have laid down,
    /// identification band, annotations, spillover and all.
    ///
    /// A PDF holds every film of the job as one page each; PNG and TIFF hold one
    /// sheet apiece, so a job spilling onto a second film writes two files.
    ///
    /// - Returns: `nil` on success, or the reason it failed.
    @discardableResult
    public func saveFilm(to url: URL) async -> String? {
        guard !selection.isEmpty else { return "Nothing is marked." }
        guard !isSavingFilm else { return nil }

        isSavingFilm = true
        defer { isSavingFilm = false }

        let items = printedItems
        let jobRequest = request
        let plan = jobRequest.plan(forImageCount: items.count)
        append(.info, "Composing \(items.count) image(s) into "
               + "\(plan.filmCount) film(s) for \(url.lastPathComponent)…")

        do {
            let texts = showPatientIdentification
                ? await identificationTexts(for: items) : [:]
            let identifications = filmIdentifications(for: items, texts: texts, plan: plan)
            let annotationLines = identificationBurns(
                for: items, texts: texts, identifications: identifications, plan: plan)
            let images = try await service.prepare(
                items: items,
                request: jobRequest,
                useViewerWindow: useViewerWindow,
                applyViewerPresentation: useViewerPresentation,
                annotations: annotationLines,
                annotationStyle: identificationStyle,
                drawnAnnotations: annotationsForPrinting)

            // Rasterizing a 14×17 sheet at 300 dpi is tens of megapixels of
            // drawing; done on the main actor it stalls the film it is drawing.
            let composeRequest = jobRequest
            let written = try await Task.detached(priority: .userInitiated) {
                let films = try PrintSCPSimulator().composeFilms(
                    images: images,
                    request: composeRequest,
                    settings: PrintSCPSettings(),
                    callingAETitle: "DICOMSTUDIO")
                return try Self.writeFilms(films, to: url)
            }.value

            for name in written { append(.success, "Saved film to \(name)") }
            return nil
        } catch {
            let message: String
            switch error {
            case let error as PrintRequestError:      message = error.message
            case let error as FilmCompositionError:   message = error.description
            case let error as PrintSinkError:         message = error.description
            default:                                  message = error.localizedDescription
            }
            append(.failure, "Failed to save the film: \(message)")
            return message
        }
    }

    /// Writes composed sheets to `url`, in the format its extension names.
    ///
    /// - Returns: the names of the files written.
    nonisolated private static func writeFilms(
        _ films: [ComposedFilm], to url: URL
    ) throws -> [String] {
        guard !films.isEmpty else { return [] }

        // A PDF is a document, so every sheet of the job is a page of it.
        if url.pathExtension.lowercased() == "pdf" {
            try PDFSink.write(films: films, to: url)
            return [url.lastPathComponent]
        }

        let format: ImageSink.Format =
            ["tif", "tiff"].contains(url.pathExtension.lowercased()) ? .tiff : .png
        guard films.count > 1 else {
            try ImageSink.write(film: films[0], to: url, format: format)
            return [url.lastPathComponent]
        }

        // An image file holds one picture and a film is one sheet, so a job that
        // spilled writes one file per sheet, numbered as the films are.
        let base = url.deletingPathExtension()
        let ext = url.pathExtension
        return try films.enumerated().map { index, film in
            let target = URL(fileURLWithPath: "\(base.path)-\(index + 1)")
                .appendingPathExtension(ext)
            try ImageSink.write(film: film, to: target, format: format)
            return target.lastPathComponent
        }
    }

    /// Cancels the sheet's job — still-preparing, waiting in the queue, or
    /// mid-print.
    ///
    /// The SCU tears the association down on cancellation and issues a
    /// best-effort Film Session N-DELETE, so a cancelled job does not leave the
    /// printer holding a session.
    public func cancel() {
        runTask?.cancel()
        runTask = nil
        if let id = submittedJobID {
            queue.stop(id)
        }
    }

    /// Queries the status of a print job from the last result.
    public func refreshJobStatus(printJobUID: String) async {
        guard let printer = selectedPrinter else { return }
        do {
            jobStatus = try await jobStatusQuerier.jobStatus(profile: printer, printJobUID: printJobUID)
            for line in PrintConsoleFormatter.jobStatusText(jobStatus!) {
                append(.info, line)
            }
        } catch {
            append(.failure, "Job status query failed: \(error.localizedDescription)")
        }
    }

    // MARK: - History

    /// Re-queries the execution status of a past job from the history pane.
    ///
    /// The entry stores its Print Job UIDs precisely so "did that print?" can
    /// be asked again later. The printer is found by name — the profile the
    /// job was sent to may have been edited or removed since.
    public func refreshHistoryStatus(for entry: PrintJobHistoryEntry) async {
        guard !entry.printJobUIDs.isEmpty else {
            historyStatusChecks[entry.id] = .unavailable(
                "The printer did not return job UIDs for this job, so it cannot be queried.")
            return
        }
        guard let printer = printers.first(where: { $0.name == entry.printerName }) else {
            historyStatusChecks[entry.id] = .unavailable(
                "Printer “\(entry.printerName)” is no longer configured.")
            return
        }
        historyStatusChecks[entry.id] = .running
        var lines: [HistoryJobStatusLine] = []
        var anyFailed = false
        for (index, uid) in entry.printJobUIDs.enumerated() {
            // Multi-film jobs label each line; a single film speaks for the job.
            let prefix = entry.printJobUIDs.count > 1 ? "Film \(index + 1): " : ""
            do {
                let status = try await jobStatusQuerier.jobStatus(profile: printer, printJobUID: uid)
                let info = status.executionStatusInfo.map { " (\($0))" } ?? ""
                let kind: HistoryJobStatusLine.Kind = status.isFailed ? .failed
                    : (status.isCompleted ? .completed : .inProgress)
                lines.append(HistoryJobStatusLine(
                    text: "\(prefix)\(status.executionStatus)\(info)", kind: kind))
                if status.isFailed { anyFailed = true }
            } catch {
                lines.append(HistoryJobStatusLine(
                    text: "\(prefix)Query failed — \(error.localizedDescription)", kind: .failed))
                anyFailed = true
            }
        }
        historyStatusChecks[entry.id] = .checked(lines: lines, anyFailed: anyFailed)
    }

    /// Removes all history entries, on disk as well. The removal itself is
    /// recorded in the audit trail — a wiped history should not be silent.
    public func clearHistory() {
        let removed = history.count
        history = []
        historyStatusChecks = [:]
        try? historyStorage.save(history)
        auditTrail.record(.historyCleared, detail: "\(removed) entr\(removed == 1 ? "y" : "ies") removed")
    }

    /// The history in its on-disk JSON form, for "Export…".
    public func historyExportData() throws -> Data {
        try PrintJobHistoryStorageService.exportData(history)
    }

    /// The history as CSV, one row per job.
    public func historyCSVData() -> Data {
        var lines = ["date,printer,images,films,copies,layout,success,print_job_uids,film_session_uid,error"]
        let formatter = ISO8601DateFormatter()
        for entry in history {
            lines.append([
                formatter.string(from: entry.date),
                entry.printerName,
                String(entry.imageCount),
                String(entry.filmCount),
                String(entry.copies),
                entry.layout,
                entry.success ? "true" : "false",
                entry.printJobUIDs.joined(separator: " "),
                entry.filmSessionUID ?? "",
                entry.errorMessage ?? ""
            ].map { field -> String in
                guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
                return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
            }.joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    #if canImport(CoreGraphics) && canImport(CoreText)
    /// The history as a paginated PDF report — the form a job record is asked
    /// for when it has to be filed or handed to someone.
    public func historyPDFData() throws -> Data {
        try PrintReportPDF.historyReport(history)
    }
    #endif

    // MARK: - Completion

    /// Records a finished queue job in the history — called by the queue for
    /// every job it finishes, whether the sheet or the queue screen sent it.
    private func recordFinishedJob(_ job: PrintQueueJob, outcome: PrintQueueOutcome) {
        let entry: PrintJobHistoryEntry
        switch outcome {
        case .finished(let result, let preparedCount):
            entry = PrintJobHistoryEntry(
                printerName: job.printerName,
                // The prepared count is what actually left; the planned count
                // stands in only if preparation never got that far.
                imageCount: preparedCount > 0 ? preparedCount : job.imageCount,
                filmCount: job.filmCount,
                copies: job.copies,
                layout: job.layout,
                success: result.success,
                printJobUIDs: result.printJobUIDs,
                filmSessionUID: result.filmSessionUID,
                errorMessage: result.errorMessage
            )
        case .failed(let message):
            entry = PrintJobHistoryEntry(
                printerName: job.printerName,
                imageCount: job.imageCount,
                filmCount: job.filmCount,
                copies: job.copies,
                layout: job.layout,
                success: false,
                errorMessage: message
            )
        case .cancelled:
            // A cancelled job never reached the printer; the audit trail keeps
            // the stop, and history stays a record of jobs that were sent.
            return
        }
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

    /// Clears the console log — called when the print preview is (re)opened, so
    /// a prior job's lines don't linger on the next look at the film.
    public func resetConsole() {
        consoleLines = []
    }

    /// Puts the film back to a fresh sheet, for a new set of marks.
    ///
    /// The print screen is kept alive between visits so that reopening it is
    /// instant and so the printer stays chosen — but everything that describes
    /// *this film* is about the images that were on it, and those have just been
    /// replaced. A range reading "60 to 140" filters a series that is no longer
    /// marked; arrows drawn on cell 7 belong to a study nobody is printing;
    /// image numbers cached from the old paths answer for files that are not on
    /// the film. Carried over, each of them silently prints something other than
    /// what was ticked.
    ///
    /// What survives is what is not about these images: the chosen printer, film
    /// size and medium, and the identification switch — department settings,
    /// which a reader sets once and expects to find again. The tools and the
    /// locks do not survive; see ``resetPreviewTools()``.
    public func resetForNewFilm() {
        resetPreviewTools()
        // The ranges filter by numbers from the previous series.
        imageRanges = [:]
        imageNumbers.clear()

        // Drawn text and arrows are keyed by mark ID, and the marks are new.
        cellAnnotations = [:]
        selectedAnnotationID = nil

        // Nothing on this film has been picked out or focused yet.
        selectedItemIDs = []
        focusedItemID = nil

        // A finished job's outcome is not this film's outcome.
        reset()
        resetConsole()
    }

    /// Puts the preview's tools and locks back to how the screen opens.
    ///
    /// A mode is only safe to leave lying around while the thing it acts on is
    /// still on screen. The preview is opened, worked in and closed, and the
    /// state it leaves behind is invisible from the viewer — so a reader who
    /// closed the screen with the pan tool armed and every lock shut comes back,
    /// drags a cell to window it, and instead slides all four cells sideways.
    /// The first drag of a visit is the one that has to behave, and there is no
    /// way to see what is armed before making it.
    ///
    /// So the screen always opens the same way: windowing, nothing locked,
    /// nothing picked out, scope back to the series. Habits that outlive a visit
    /// belong to the job settings — printer, film size, medium — not here.
    public func resetPreviewTools() {
        cellTool = .window
        cellSync = []
        cellSyncScope = .sameSeries
        selectedItemIDs = []
        focusedItemID = nil
        selectedAnnotationID = nil
        annotationScale = PrintOverlayAnnotation.defaultScale
        annotationColor = .yellow
    }
}
