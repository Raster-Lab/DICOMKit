// PrintViewModel+CellEditing.swift
// DICOMStudio
//
// DICOM Studio — adjusting a single film cell from inside the print preview.
//
// Windowing a cell on the film is the last chance to fix a picture before it is
// committed to a sheet, and it is where the user is already looking. Every edit
// here writes back into the mark itself, which is the same field
// ``PrintService/prepare(items:request:useViewerWindow:applyViewerPresentation:onProgress:)``
// reads — so the preview cannot drift away from the film. Nothing here renders,
// and nothing here is print-only state.

import Foundation
import DICOMKit
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    // MARK: - What the preview must show

    /// The marks as they will actually print, with the job-wide settings folded in.
    ///
    /// The preview renders these rather than the raw marks: a job-wide explicit
    /// window, or `useViewerWindow`/`useViewerPresentation` switched off, changes
    /// what the printer receives, and a preview still showing the mark's own
    /// arrangement would be quietly lying about the film.
    public var previewItems: [PrintSelectionItem] {
        printedItems.map(previewItem(for:))
    }

    /// One mark resolved against the job-wide settings.
    public func previewItem(for item: PrintSelectionItem) -> PrintSelectionItem {
        // Raw sends stored pixels: no window, no arrangement, by definition.
        if sendRawPixels {
            return item.with(windowCenter: .some(nil), windowWidth: .some(nil),
                             presentation: .some(nil))
        }
        let center: Double? = useExplicitWindow ? explicitWindowCenter
                            : (useViewerWindow ? item.windowCenter : nil)
        let width: Double? = useExplicitWindow ? explicitWindowWidth
                           : (useViewerWindow ? item.windowWidth : nil)
        // The job-wide window is typed by a user, so it is in output units (HU);
        // the mark's own window came off the viewer, which holds stored values.
        // Rendering one as the other puts the window nowhere near the pixels and
        // washes the cell out, so which it is travels with the numbers.
        return item.with(
            windowCenter: .some(center),
            windowWidth: .some(width),
            windowSpace: useExplicitWindow ? .outputUnits : item.windowSpace,
            presentation: .some(useViewerPresentation ? item.presentation : nil))
    }

    /// Whether a job-wide window is overriding every cell's own window.
    ///
    /// While this is on, editing one cell changes nothing on film, so the
    /// preview says so rather than accepting edits that will be discarded.
    public var isCellWindowingOverridden: Bool {
        sendRawPixels || useExplicitWindow
    }

    /// Why cell windowing is currently unavailable, if it is.
    public var cellWindowingBlockedReason: String? {
        if sendRawPixels {
            return "Raw pixels are being sent — windowing is not applied to this job."
        }
        if useExplicitWindow {
            return "One window is set for the whole job, so per-image windows are ignored."
        }
        return nil
    }

    // MARK: - Identification

    /// The identification each marked file carries, keyed by path.
    ///
    /// The same lines the preview overlays — patient, ID and study date, the
    /// study description, and what made the picture — so film, screen and
    /// preview all say the same thing about whose study this is.
    ///
    /// Read here rather than taken from the preview's cache: printing must not
    /// depend on whether the user happened to look at the preview first, and a
    /// missing caption is not something to discover on the film.
    public func identificationTexts(
        for items: [PrintSelectionItem]
    ) async -> [String: PatientOverlayText] {
        var result: [String: PatientOverlayText] = [:]
        for path in Set(items.map(\.filePath)).sorted() {
            let text = await Task.detached(priority: .userInitiated) { () -> PatientOverlayText? in
                guard let data = FileManager.default.contents(atPath: path),
                      let file = try? DICOMFile.read(from: data, force: true) else { return nil }
                return PatientOverlayText.make(from: file.dataSet)
            }.value
            guard let text, !text.isEmpty else { continue }
            result[path] = text
        }
        return result
    }

    /// How each film of a job states its identification, in film order.
    ///
    /// Under each image, or — when identification is switched off, or nothing
    /// could be read from the files — not at all. A caption states the technique
    /// of the image it sits under as well as the patient, and that differs from
    /// cell to cell, so there is nothing a single footer could say for a whole
    /// sheet. The rule lives in ``FilmIdentificationPlanner``, shared with the
    /// preview and the composer so all three agree.
    public func filmIdentifications(
        for items: [PrintSelectionItem],
        texts: [String: PatientOverlayText],
        plan: PrintPlan
    ) -> [FilmIdentification] {
        guard showPatientIdentification else {
            return Array(repeating: .none, count: max(0, plan.filmCount))
        }
        return (0..<max(0, plan.filmCount)).map { filmIndex in
            let sources = plan.imageIndices(onFilm: filmIndex).compactMap { index -> FilmIdentificationSource? in
                guard items.indices.contains(index) else { return nil }
                let item = items[index]
                let text = texts[item.filePath]
                return FilmIdentificationSource(
                    key: item.id,
                    studyKey: text?.studyInstanceUID ?? "",
                    lines: text?.lines ?? [])
            }
            return FilmIdentificationPlanner.identification(for: sources, placement: .perImage)
        }
    }

    /// The corner text to burn into each mark's pixels, keyed by mark ID.
    ///
    /// Burned rather than sent as annotation boxes: a DICOM printer lays those
    /// out to its own configured format and many ignore them, and a caption that
    /// names the slice it stands on is no use anywhere but on that slice.
    public func identificationBurns(
        for items: [PrintSelectionItem],
        texts: [String: PatientOverlayText],
        identifications: [FilmIdentification],
        plan: PrintPlan
    ) -> [String: PrintCornerAnnotation] {
        var result: [String: PrintCornerAnnotation] = [:]
        for filmIndex in 0..<max(0, plan.filmCount) {
            let identification = filmIndex < identifications.count
                ? identifications[filmIndex] : .perImage
            guard identification != .none else { continue }
            for index in plan.imageIndices(onFilm: filmIndex) {
                guard items.indices.contains(index) else { continue }
                let item = items[index]
                guard let corners = texts[item.filePath]?
                    .corners(including: identificationFields),
                    !corners.isEmpty else { continue }
                result[item.id] = corners
            }
        }
        return result
    }

    // MARK: - Focus

    /// The cell the preview's tools act on, identified by its mark.
    public var focusedItem: PrintSelectionItem? {
        guard let focusedItemID else { return nil }
        return selection.items.first { $0.id == focusedItemID }
    }

    /// Focuses a cell, or clears the focus when passed `nil`.
    public func focusCell(_ itemID: String?) {
        focusedItemID = itemID
    }

    /// Drops the focus if the focused mark is no longer on film.
    public func pruneFocus() {
        if let focusedItemID, !selection.items.contains(where: { $0.id == focusedItemID }) {
            self.focusedItemID = nil
        }
    }

    // MARK: - Windowing

    /// The window a mark is currently printing with, once it is known.
    public func window(forItemID itemID: String) -> WindowSettings? {
        guard let item = selection.items.first(where: { $0.id == itemID }),
              let center = item.windowCenter, let width = item.windowWidth else { return nil }
        return WindowSettings(center: center, width: width)
    }

    /// Gives a mark a concrete window if it has none, without changing the picture.
    ///
    /// A mark made without ever opening the file (marking a whole series, say)
    /// carries no window, and the cell is rendered with the file's own. An edit
    /// has to start from those same values or the first drag would jump; this
    /// resolves them through the shared export policy the renderer uses.
    public func seedWindowIfNeeded(forItemID itemID: String) async {
        #if canImport(CoreGraphics)
        guard let item = selection.items.first(where: { $0.id == itemID }),
              item.windowCenter == nil || item.windowWidth == nil else { return }
        guard let resolved = await FrameRenderer.resolvedWindow(
            path: item.filePath, frameIndex: item.frameIndex) else { return }
        // The mark may have been unmarked or edited while the file was read.
        guard let current = selection.items.first(where: { $0.id == itemID }),
              current.windowCenter == nil || current.windowWidth == nil else { return }
        // Seeding is not an edit: the values are the ones already on screen, so
        // the mark is not flagged as hand-adjusted by having been picked up.
        selection.update(current.with(
            windowCenter: .some(resolved.center), windowWidth: .some(resolved.width)),
                         force: true)
        #endif
    }

    /// Sets a mark's window. Width is held at 1 or more — a zero-width window is
    /// not a picture.
    public func setWindow(forItemID itemID: String, center: Double, width: Double) {
        guard let item = selection.items.first(where: { $0.id == itemID }) else { return }
        guard center.isFinite, width.isFinite else { return }
        // Read before the write: a synchronised edit is carried to the other
        // cells as a proportion of this one's change, which is gone once the
        // new numbers are in. See `PrintViewModel+CellSync.swift`.
        let previous = window(forItemID: itemID)
        // Rounded to whole units. A drag emits a window value per mouse event
        // and each distinct value is a re-render; fractions of a Hounsfield unit
        // change no pixel, so they are quantised away before they can queue up.
        let current = WindowSettings(center: center.rounded(), width: max(1, width.rounded()))
        selection.adjust(item.with(
            windowCenter: .some(current.center),
            windowWidth: .some(current.width)))
        if let previous {
            propagateWindowDelta(from: itemID, previous: previous, current: current)
        }
    }

    /// Nudges a mark's window, as a window/level drag does.
    public func adjustWindow(forItemID itemID: String, deltaCenter: Double, deltaWidth: Double) {
        guard let current = window(forItemID: itemID) else { return }
        setWindow(forItemID: itemID,
                  center: current.center + deltaCenter,
                  width: current.width + deltaWidth)
    }

    /// Applies a preset to a mark.
    ///
    /// A preset is copied to synchronised cells as the window it is, not as the
    /// change it made here: "lung" names a tissue, and the cells beside this one
    /// should show that tissue too.
    public func applyWindowPreset(_ preset: WindowLevelPreset, toItemID itemID: String) {
        let window = WindowSettings(center: preset.center, width: preset.width)
        guard let item = selection.items.first(where: { $0.id == itemID }) else { return }
        selection.adjust(item.with(
            windowCenter: .some(window.center.rounded()),
            windowWidth: .some(max(1, window.width.rounded()))))
        propagateWindowAbsolute(from: itemID, window: window)
    }

    /// Gives every mark on film the focused cell's window.
    ///
    /// The job-wide explicit window is switched off as part of this: the two are
    /// the same intent expressed twice, and leaving the override on would make
    /// every cell ignore the values just written to it.
    public func applyFocusedWindowToAllCells() {
        guard let focusedItemID, let window = window(forItemID: focusedItemID) else { return }
        useExplicitWindow = false
        for item in selection.items {
            selection.adjust(item.with(
                windowCenter: .some(window.center), windowWidth: .some(window.width)))
        }
    }

    /// Copies the focused cell's window into the job-wide explicit window fields.
    public func liftFocusedWindowToJob() {
        guard let focusedItemID, let window = window(forItemID: focusedItemID) else { return }
        explicitWindowCenter = window.center
        explicitWindowWidth = window.width
    }

    // MARK: - Zoom, pan and orientation

    /// Zooms a cell about its centre.
    ///
    /// - Parameter cellSize: the size the cell is drawn at, which stands in as
    ///   the viewport for marks that never carried one (marked from the library
    ///   rather than composed on screen). Zoom and pan are meaningless without a
    ///   viewport — see ``ViewerPresentation/visibleRegion(imageWidth:imageHeight:)``.
    /// - Parameter pixelSize: the source frame's own size, when the caller knows
    ///   it, so the pan can be held to what the image covers. Without it the
    ///   cell is assumed to be filled by the image, which bounds the pan on the
    ///   tight axis and is no worse than not bounding it at all.
    public func adjustZoom(
        forItemID itemID: String, factor: Double, cellSize: CGSize,
        pixelSize: CGSize? = nil
    ) {
        guard factor.isFinite, factor > 0 else { return }
        let covers = picturesCoverTheirCells
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.zoom = min(Self.maximumCellZoom,
                                    max(Self.minimumCellZoom, presentation.zoom * factor))
            if presentation.zoom <= 1.0 && !covers {
                // Back to fitted: a pan that was only meaningful while zoomed in
                // would otherwise keep cropping the fitted image. Not so on a
                // filled cell, where zoom 1 is already a crop and the pan
                // chooses which part of it prints — throwing that away would
                // undo the reader's framing every time they zoomed back out.
                presentation.panX = 0
                presentation.panY = 0
            } else {
                // Zooming back out leaves less of the image hidden, so a pan
                // that was legal a moment ago can now be off the edge.
                Self.clampPan(of: &presentation, pixelSize: pixelSize,
                              covers: covers)
            }
        }
        propagateZoomPan(from: itemID, cellSize: cellSize)
    }

    /// Pans a cell by a drag in cell points.
    ///
    /// - Parameter pixelSize: the source frame's own size — see
    ///   ``adjustZoom(forItemID:factor:cellSize:pixelSize:)``.
    public func panCell(
        forItemID itemID: String, dx: Double, dy: Double, cellSize: CGSize,
        pixelSize: CGSize? = nil
    ) {
        guard dx.isFinite, dy.isFinite, cellSize.width > 0 else { return }
        let covers = picturesCoverTheirCells
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            // The drag is measured on the cell; the pan is stored in the
            // viewport the mark was composed in, which is usually larger.
            let scale = presentation.viewportWidth / Double(cellSize.width)
            presentation.panX += dx * scale
            presentation.panY += dy * scale
            // The picture slides and stops at the image's edge; without this the
            // drag runs off it and the cell refits a shrinking crop instead.
            Self.clampPan(of: &presentation, pixelSize: pixelSize,
                          covers: covers)
        }
        propagateZoomPan(from: itemID, cellSize: cellSize)
    }

    /// Whether the film's scaling *crops* each picture to cover its whole cell.
    ///
    /// Fill only. What it decides is whether a pan has anywhere to go at zoom 1
    /// — a fill-cropped cell is showing part of the image, so it does. Stretch
    /// also covers the cell but by distortion, not by cropping: the whole image
    /// is in the cell and there is nothing hidden for a pan to bring in, which
    /// is the fitted situation, not the filled one.
    var picturesCoverTheirCells: Bool {
        scalingMode == .fillToFilm
    }

    /// Holds a presentation's pan inside the image it is over.
    ///
    /// With no frame size to go on the viewport stands in for the image, which
    /// is exact on whichever axis the image fills and generous on the other.
    static func clampPan(of presentation: inout ViewerPresentation,
                                 pixelSize: CGSize?, covers: Bool = false) {
        let width = Int((pixelSize.map { Double($0.width) } ?? presentation.viewportWidth).rounded())
        let height = Int((pixelSize.map { Double($0.height) } ?? presentation.viewportHeight).rounded())
        guard width > 0, height > 0 else { return }
        let clamped = presentation.clampedPan(
            x: presentation.panX, y: presentation.panY,
            imageWidth: width, imageHeight: height, covers: covers)
        presentation.panX = clamped.x
        presentation.panY = clamped.y
    }

    /// Turns a cell a quarter turn clockwise.
    public func rotateCell(forItemID itemID: String, cellSize: CGSize) {
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.quarterTurns = (presentation.quarterTurns + 1) % 4
        }
    }

    /// Inverts a cell's greyscale.
    ///
    /// - Parameter cellSize: the cell the picture is drawn in, when the caller
    ///   knows it. Optional because inversion is not geometry: a rail button has
    ///   no cell to speak of, and re-basing the viewport on a guess would change
    ///   the crop while claiming only to have flipped the greys.
    public func toggleCellInversion(forItemID itemID: String, cellSize: CGSize? = nil) {
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.invert.toggle()
        }
        propagateInversion(from: itemID, cellSize: cellSize)
    }

    /// Returns a cell to the untouched frame: the file's own window, no crop, no
    /// rotation, no inversion.
    public func resetCell(forItemID itemID: String) {
        guard let item = selection.items.first(where: { $0.id == itemID }) else { return }
        selection.update(item.with(
            windowCenter: .some(nil), windowWidth: .some(nil), presentation: .some(nil)),
                         force: true)
        // The untouched frame is not a hand-made arrangement worth defending
        // from the viewer, so the cell follows the screen again.
        selection.clearAdjustment(forID: itemID)
    }

    /// Returns the focused cell to the untouched frame.
    ///
    /// The same edit as ``resetCell(forItemID:)``, aimed at the focus rather
    /// than at a cell named by the caller: the menu's own reset acts on whatever
    /// was right-clicked, which is not always the cell the tools are on.
    public func resetFocusedCell() {
        guard let focusedItemID else { return }
        resetCell(forItemID: focusedItemID)
    }

    /// Returns every cell on the film to the untouched frame.
    ///
    /// The way out of an arrangement that has gone wrong across the sheet —
    /// which linked cells make easy to produce, since one drag now moves many.
    /// Job-wide switches are left alone: this undoes the hand-made arrangement,
    /// and how the job is set up is a different decision.
    public func resetAllCells() {
        for item in selection.items {
            resetCell(forItemID: item.id)
        }
    }

    /// Whether any cell differs from the untouched frame, so a sheet-wide reset
    /// has something to undo.
    public var hasEditedCells: Bool {
        selection.items.contains { isCellEdited($0) }
    }

    /// Takes back the adjustments made to a cell here, restoring the mark to how
    /// the viewer left it.
    ///
    /// Distinct from ``resetCell(forItemID:)``: reset goes to the untouched
    /// frame, revert goes back to what was marked — usually the window the user
    /// had set on screen, which reset would throw away too.
    public func revertCell(forItemID itemID: String) {
        selection.revertAdjustments(forID: itemID)
    }

    /// Whether a cell has been adjusted here and can be taken back.
    public func isCellAdjusted(_ itemID: String) -> Bool {
        selection.isAdjusted(itemID)
    }

    /// Whether a cell differs from the untouched frame.
    public func isCellEdited(_ item: PrintSelectionItem) -> Bool {
        item.windowCenter != nil || (item.presentation.map { !$0.isIdentity } ?? false)
    }

    /// Edits a mark's presentation, giving it one first if it has none.
    ///
    /// Deliberately does not propagate to synchronised cells: this is the write
    /// itself, and the peers are driven from the public tools above so that one
    /// gesture produces one round of propagation rather than a cascade. See
    /// `PrintViewModel+CellSync.swift`.
    func mutatePresentation(
        forItemID itemID: String,
        cellSize: CGSize?,
        _ transform: (inout ViewerPresentation) -> Void
    ) {
        guard let item = selection.items.first(where: { $0.id == itemID }) else { return }
        var presentation = item.presentation ?? ViewerPresentation()

        // Arranging a cell says the film should carry arrangements. With the
        // job-wide switch off the edit is written to the mark and then dropped
        // by `previewItem(for:)`, so the tool looks broken — nothing on the cell
        // moves however far it is dragged. Raw pixels are left alone: there the
        // switch would change nothing either way.
        if !useViewerPresentation && !sendRawPixels {
            useViewerPresentation = true
        }

        // The film cell becomes the viewport for anything adjusted here.
        //
        // The viewport decides the *shape* of the region a zoom keeps: crop an
        // image through a tall viewer tile and show the result in a wide film
        // cell, and the cell can only letterbox it — which reads as the image
        // being cut off in height rather than filling the cell. Re-basing on the
        // cell means what the user zooms into is the shape of what will print.
        // The zoom factor is carried across so the picture does not jump: the
        // same magnification, seen through a differently shaped window.
        if let cellSize {
            let cellWidth = max(1, Double(cellSize.width))
            let cellHeight = max(1, Double(cellSize.height))
            if !Self.aspectsMatch(width: presentation.viewportWidth,
                                  height: presentation.viewportHeight,
                                  otherWidth: cellWidth, otherHeight: cellHeight) {
                presentation.viewportWidth = cellWidth
                presentation.viewportHeight = cellHeight
            }
        }
        transform(&presentation)
        // Quantised for the same reason as the window: a zoom that differs in
        // the fourth decimal is the same picture, and re-rendering for it makes
        // the drag stutter without changing anything on screen.
        presentation.zoom = (presentation.zoom * 100).rounded() / 100
        presentation.panX = presentation.panX.rounded()
        presentation.panY = presentation.panY.rounded()
        selection.adjust(item.with(presentation: .some(presentation)))
    }

    /// Whether two viewports are the same shape, within rounding.
    ///
    /// Cell sizes arrive from layout as fractional points, so an exact
    /// comparison would re-base the viewport on every redraw and slowly walk the
    /// crop across the image.
    static func aspectsMatch(
        width: Double, height: Double,
        otherWidth: Double, otherHeight: Double
    ) -> Bool {
        guard width > 0, height > 0, otherWidth > 0, otherHeight > 0 else { return false }
        return abs(width / height - otherWidth / otherHeight) < 0.01
    }

    /// Zoom bounds for a cell — the viewer's own limits, so a film cell cannot be
    /// pushed somewhere the screen would refuse to go.
    static let minimumCellZoom: Double = 0.25
    static let maximumCellZoom: Double = 20.0
}
