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
        selection.items.map(previewItem(for:))
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
        return item.with(
            windowCenter: .some(center),
            windowWidth: .some(width),
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

    /// The lines burned into each marked file's pixels, keyed by path.
    ///
    /// The same two lines the viewer draws and the preview overlays — patient,
    /// ID and study date over the study description — so film, screen and
    /// preview all say the same thing about whose study this is.
    ///
    /// Read here rather than taken from the preview's cache: printing must not
    /// depend on whether the user happened to look at the preview first, and a
    /// missing caption is not something to discover on the film.
    public func identificationLines(for items: [PrintSelectionItem]) async -> [String: [String]] {
        var result: [String: [String]] = [:]
        for path in Set(items.map(\.filePath)).sorted() {
            let text = await Task.detached(priority: .userInitiated) { () -> PatientOverlayText? in
                guard let data = FileManager.default.contents(atPath: path),
                      let file = try? DICOMFile.read(from: data, force: true) else { return nil }
                return PatientOverlayText.make(from: file.dataSet)
            }.value
            guard let text, !text.isEmpty else { continue }
            result[path] = [text.primaryLine, text.secondaryLine].filter { !$0.isEmpty }
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
        // Rounded to whole units. A drag emits a window value per mouse event
        // and each distinct value is a re-render; fractions of a Hounsfield unit
        // change no pixel, so they are quantised away before they can queue up.
        selection.adjust(item.with(
            windowCenter: .some(center.rounded()),
            windowWidth: .some(max(1, width.rounded()))))
    }

    /// Nudges a mark's window, as a window/level drag does.
    public func adjustWindow(forItemID itemID: String, deltaCenter: Double, deltaWidth: Double) {
        guard let current = window(forItemID: itemID) else { return }
        setWindow(forItemID: itemID,
                  center: current.center + deltaCenter,
                  width: current.width + deltaWidth)
    }

    /// Applies a preset to a mark.
    public func applyWindowPreset(_ preset: WindowLevelPreset, toItemID itemID: String) {
        setWindow(forItemID: itemID, center: preset.center, width: preset.width)
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
    public func adjustZoom(forItemID itemID: String, factor: Double, cellSize: CGSize) {
        guard factor.isFinite, factor > 0 else { return }
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.zoom = min(Self.maximumCellZoom,
                                    max(Self.minimumCellZoom, presentation.zoom * factor))
            if presentation.zoom <= 1.0 {
                // Fitted again: a pan that was only meaningful while zoomed in
                // would otherwise keep cropping the fitted image.
                presentation.panX = 0
                presentation.panY = 0
            }
        }
    }

    /// Pans a cell by a drag in cell points.
    public func panCell(forItemID itemID: String, dx: Double, dy: Double, cellSize: CGSize) {
        guard dx.isFinite, dy.isFinite, cellSize.width > 0 else { return }
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            // The drag is measured on the cell; the pan is stored in the
            // viewport the mark was composed in, which is usually larger.
            let scale = presentation.viewportWidth / Double(cellSize.width)
            presentation.panX += dx * scale
            presentation.panY += dy * scale
        }
    }

    /// Turns a cell a quarter turn clockwise.
    public func rotateCell(forItemID itemID: String, cellSize: CGSize) {
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.quarterTurns = (presentation.quarterTurns + 1) % 4
        }
    }

    /// Inverts a cell's greyscale.
    public func toggleCellInversion(forItemID itemID: String, cellSize: CGSize) {
        mutatePresentation(forItemID: itemID, cellSize: cellSize) { presentation in
            presentation.invert.toggle()
        }
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
    private func mutatePresentation(
        forItemID itemID: String,
        cellSize: CGSize,
        _ transform: (inout ViewerPresentation) -> Void
    ) {
        guard let item = selection.items.first(where: { $0.id == itemID }) else { return }
        var presentation = item.presentation ?? ViewerPresentation()

        // The film cell becomes the viewport for anything adjusted here.
        //
        // The viewport decides the *shape* of the region a zoom keeps: crop an
        // image through a tall viewer tile and show the result in a wide film
        // cell, and the cell can only letterbox it — which reads as the image
        // being cut off in height rather than filling the cell. Re-basing on the
        // cell means what the user zooms into is the shape of what will print.
        // The zoom factor is carried across so the picture does not jump: the
        // same magnification, seen through a differently shaped window.
        let cellWidth = max(1, Double(cellSize.width))
        let cellHeight = max(1, Double(cellSize.height))
        if !Self.aspectsMatch(width: presentation.viewportWidth,
                              height: presentation.viewportHeight,
                              otherWidth: cellWidth, otherHeight: cellHeight) {
            presentation.viewportWidth = cellWidth
            presentation.viewportHeight = cellHeight
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
