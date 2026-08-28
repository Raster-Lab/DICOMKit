// PrintViewModel+CellSync.swift
// DICOMStudio
//
// DICOM Studio — carrying one cell's adjustment to the other cells on the film.
//
// Distinct from "apply this window to all cells", which is a one-shot copy the
// user asks for after the fact. This is a mode: while it is on, zooming one cell
// zooms its neighbours as the gesture happens, the way a linked viewer does.
//
// Two rules decide what "the same adjustment" means, and they are not the same
// rule for every tool:
//
// * Geometry (zoom, pan, rotation, inversion) is copied **absolutely**. Every
//   cell on a film is the same size, so "the same zoom and the same pan" is
//   exactly the picture the user has in mind. Each peer's pan is then re-held
//   inside its own image, because a 512² CT and a 3000² CR cannot share a raw
//   offset.
// * Windowing is carried **relatively**, as a delta. A film routinely mixes
//   modalities, and marks do not all state their window in the same space —
//   see ``PrintWindowSpace``. Copying a CT's centre of 40 onto an ultrasound
//   cell would black it out, whereas "widen everything by the same proportion"
//   means the same thing everywhere. Presets are the exception: a preset names
//   a tissue, so it is copied as the absolute window it is.
//
// Nothing here renders and nothing here is print-only state: the edits land in
// the marks, exactly as a hand edit of each cell would have.

import Foundation
import DICOMKit
import DICOMPrintKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - What is synchronised

/// The cell adjustments that travel to the other cells as they are made.
public struct PrintCellSyncOptions: OptionSet, Sendable, Hashable {

    public let rawValue: Int

    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Zoom and pan, as one switch.
    ///
    /// Deliberately not two: cells that magnify together but sit over different
    /// parts of the image are the confusing state, not a state anyone asks for.
    public static let zoomPan = PrintCellSyncOptions(rawValue: 1 << 0)

    /// Window centre and width.
    public static let window = PrintCellSyncOptions(rawValue: 1 << 1)

    /// Greyscale inversion.
    public static let invert = PrintCellSyncOptions(rawValue: 1 << 3)

    public static let all: PrintCellSyncOptions = [.zoomPan, .window, .invert]

    /// The switches in the order they are offered, with their labels.
    ///
    /// Rotation and flip are deliberately absent. They are how a cell is put the
    /// right way up, which is a fact about that image rather than a way of
    /// looking at the film — turning every cell because one was upside down is
    /// never what was meant.
    public static let catalog: [(option: PrintCellSyncOptions, title: String, symbol: String)] = [
        (.zoomPan, "Zoom & Pan", "arrow.up.left.and.arrow.down.right"),
        (.window, "Window", "circle.lefthalf.filled"),
        (.invert, "Invert", "circle.righthalf.filled")
    ]
}

// MARK: - How far it reaches

/// Which other cells a synchronised edit reaches.
public enum PrintCellSyncScope: String, CaseIterable, Sendable, Identifiable {

    /// Every mark in the job, across all films.
    case allCells

    /// Only marks from the same series as the cell being edited.
    ///
    /// The default: a film that carries two series is usually carrying them for
    /// comparison, and dragging one series' window onto the other is rarely what
    /// was meant.
    case sameSeries

    /// Only the cells on the film the edited cell is on.
    case thisFilm

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .allCells: return "All Cells"
        case .sameSeries: return "Same Series"
        case .thisFilm: return "This Film"
        }
    }
}

// MARK: - Propagation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    /// Whether any cell edit is currently being carried to other cells.
    ///
    /// Asked of what would actually happen, not of what is switched on: with a
    /// job-wide window overriding the cells, a closed window lock carries
    /// nothing, and a film showing locks over cells that will not move is
    /// worse than no locks at all.
    public var isCellSyncActive: Bool {
        PrintCellSyncOptions.catalog.contains { isSynced($0.option) }
    }

    /// Whether a particular kind of edit is being carried.
    ///
    /// Window sync reads as off while a job-wide window is overriding the cells:
    /// nothing per-cell reaches the film then, so a lit switch would be claiming
    /// an effect the job has already taken away.
    public func isSynced(_ option: PrintCellSyncOptions) -> Bool {
        guard cellSync.contains(option) else { return false }
        if option == .window && isCellWindowingOverridden { return false }
        return true
    }

    /// Turns one kind of synchronisation on or off.
    public func toggleSync(_ option: PrintCellSyncOptions) {
        if cellSync.contains(option) {
            cellSync.remove(option)
        } else {
            cellSync.insert(option)
        }
    }

    /// Gives every mark a concrete window, so a synchronised drag moves all of
    /// them and not just the ones that have been looked at.
    ///
    /// A mark made without opening its file carries no window, and a relative
    /// edit has nothing to be relative to — that cell would sit still while its
    /// neighbours moved. Done once when the link is switched on rather than
    /// during the drag: it reads files, and a drag emits an edit per mouse
    /// event.
    public func seedWindowsForSync() async {
        for item in selection.items where item.windowCenter == nil || item.windowWidth == nil {
            await seedWindowIfNeeded(forItemID: item.id)
        }
    }

    /// A short description of what is linked, for the preview's caption.
    public var cellSyncSummary: String? {
        let names = PrintCellSyncOptions.catalog
            .filter { cellSync.contains($0.option) }
            .map(\.title)
        guard !names.isEmpty else { return nil }
        return "Linked: " + names.joined(separator: ", ") + " · " + cellSyncScope.title
    }

    // MARK: Peers

    /// The other marks a synchronised edit of `itemID` should reach.
    ///
    /// The source itself is never in the result — it has already been written by
    /// the tool that called in, and writing it twice would re-apply the delta.
    public func syncPeers(of itemID: String) -> [PrintSelectionItem] {
        guard let source = selection.items.first(where: { $0.id == itemID }) else { return [] }
        let candidates: [PrintSelectionItem]
        switch cellSyncScope {
        case .allCells:
            candidates = selection.items
        case .sameSeries:
            let key = source.seriesKey
            candidates = selection.items.filter { $0.seriesKey == key }
        case .thisFilm:
            let cellsPerFilm = max(1, plan.cellsPerFilm)
            guard let index = selection.items.firstIndex(where: { $0.id == itemID }) else {
                return []
            }
            let film = index / cellsPerFilm
            let start = film * cellsPerFilm
            let end = min(selection.items.count, start + cellsPerFilm)
            candidates = Array(selection.items[start..<end])
        }
        return candidates.filter { $0.id != itemID }
    }

    /// Whether this cell moves when the focused cell is adjusted.
    ///
    /// What the lock on a cell means. Drawn per cell rather than stated once,
    /// because the scope is the part that is easy to get wrong: "Same Series"
    /// looks identical to "All Cells" until a film carries two series, and by
    /// then the drag has already happened. A closed lock on the cells that will
    /// move — and none on the cells that will not — answers it before the drag.
    public func isLinkedToFocus(_ itemID: String) -> Bool {
        guard isCellSyncActive, let focusedItemID else { return false }
        guard itemID != focusedItemID else { return true }
        return syncPeers(of: focusedItemID).contains { $0.id == itemID }
    }

    // MARK: Geometry

    /// Copies the edited cell's zoom and pan onto its peers.
    ///
    /// - Parameter cellSize: the cell the edit was made in. Every cell on a film
    ///   is drawn at the same size, so the source's cell stands for the peers'
    ///   too, and re-basing each peer's viewport on it is what makes the copied
    ///   pan mean the same crop.
    func propagateZoomPan(from itemID: String, cellSize: CGSize) {
        guard isSynced(.zoomPan),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        for peer in syncPeers(of: itemID) {
            mutatePresentation(forItemID: peer.id, cellSize: cellSize) { presentation in
                presentation.zoom = source.zoom
                presentation.panX = source.panX
                presentation.panY = source.panY
                // The peer's own frame is not known here — the view only holds
                // the size of the cell it is dragging — so the pan is held
                // against the viewport, which is exact on whichever axis the
                // image fills and generous on the other. A pan that is a little
                // loose is recoverable; one that is not clamped at all slides
                // the picture off the cell.
                PrintViewModel.clampPan(of: &presentation, pixelSize: nil)
            }
        }
    }

    /// Copies the edited cell's inversion onto its peers.
    func propagateInversion(from itemID: String, cellSize: CGSize?) {
        guard isSynced(.invert),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        for peer in syncPeers(of: itemID) {
            mutatePresentation(forItemID: peer.id, cellSize: cellSize) { presentation in
                presentation.invert = source.invert
            }
        }
    }

    // MARK: Window

    /// Carries a window change to the peers in proportion to their own window.
    ///
    /// - Parameters:
    ///   - previous: the source cell's window before the edit.
    ///   - current: the source cell's window after it.
    ///
    /// Width is scaled by the same factor and the centre moves by the same
    /// fraction of a width, so a drag that opens up a CT by a third opens the MR
    /// beside it by a third — rather than moving it to a number that means
    /// nothing in its pixels.
    func propagateWindowDelta(
        from itemID: String, previous: WindowSettings, current: WindowSettings
    ) {
        guard isSynced(.window), previous.width > 0 else { return }
        let widthFactor = current.width / previous.width
        let centerShift = (current.center - previous.center) / previous.width
        guard widthFactor.isFinite, centerShift.isFinite else { return }
        for peer in syncPeers(of: itemID) {
            guard let window = window(forItemID: peer.id) else { continue }
            selection.adjust(peer.with(
                windowCenter: .some((window.center + centerShift * window.width).rounded()),
                windowWidth: .some(max(1, (window.width * widthFactor).rounded())),
                windowSpace: peer.windowSpace))
        }
    }

    /// Copies a window onto the peers unchanged.
    ///
    /// Used for presets, which name a tissue rather than a nudge, and so mean
    /// the same numbers everywhere they are applied.
    func propagateWindowAbsolute(from itemID: String, window: WindowSettings) {
        guard isSynced(.window) else { return }
        for peer in syncPeers(of: itemID) {
            selection.adjust(peer.with(
                windowCenter: .some(window.center.rounded()),
                windowWidth: .some(max(1, window.width.rounded())),
                windowSpace: peer.windowSpace))
        }
    }
}
