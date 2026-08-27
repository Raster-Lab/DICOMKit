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

    /// The pseudo-colour palette.
    ///
    /// Worth shutting more often than the geometry locks, though it opens with
    /// the rest: a palette is a way of reading the film rather than a fact about
    /// one image — a reader who colours the PET usually means "show this study
    /// in colour", not "show this one slice in colour". The film-wide default in
    /// the print sheet is the blunter way to say the same thing, and this lock
    /// is for saying it from a cell.
    public static let palette = PrintCellSyncOptions(rawValue: 1 << 2)

    /// Rotation — the angle the cell is turned to.
    ///
    /// The angle alone, not the flips. A flip is a statement about laterality,
    /// and mirroring a whole film because one image was marked from the far
    /// side is a way to print a sheet nobody can read; a turn is how a run of
    /// images is stood up the same way, which is exactly what a lock is for.
    public static let rotate = PrintCellSyncOptions(rawValue: 1 << 4)

    public static let all: PrintCellSyncOptions =
        [.zoomPan, .window, .rotate, .invert, .palette]

    /// The switches in the order they are offered, with their labels.
    ///
    /// The order matches the tool rail's — W/L, then zoom and pan, then rotate,
    /// then invert — so a lock sits in the same place in the list as the tool it
    /// holds together. A lock list ordered differently from the tools above it
    /// makes the reader search for "the one for the tool I am holding" every
    /// time.
    ///
    /// Rotation is on the list, and its lock is open by default. Turning a cell
    /// is often how *one* image is put the right way up — which is why it is not
    /// carried unless asked — but a run of frames marked from the same series
    /// comes off the scanner the same way round, and standing thirteen of them
    /// up one drag at a time is the work a lock exists to remove. Open by
    /// default, shut when the reader says so, exactly like the others.
    ///
    /// Flip is still absent: it states which side of the patient is which, and
    /// there is no film on which mirroring every cell is what was meant.
    public static let catalog: [(option: PrintCellSyncOptions, title: String, symbol: String)] = [
        (.window, "Window", "sun.max"),
        (.zoomPan, "Zoom & Pan", "arrow.up.left.and.arrow.down.right"),
        (.rotate, "Rotate", "arrow.triangle.2.circlepath"),
        (.invert, "Invert", "circle.righthalf.filled")
        // No CLUT lock: the rail's per-cell palette menu was dropped (colour
        // now lives with the film-wide picker under More), so a lock for edits
        // no control can make would be dead chrome. `.palette` itself survives
        // in the option set — saved views and the model API still carry
        // per-cell palettes — and the chip returns with any future per-cell
        // colour control.
    ]
}

// MARK: - How far it reaches

/// Which other cells on the film a synchronised edit reaches.
///
/// Never past the film the edited cell is on. A reader judges one sheet at a
/// time — it is the sheet in front of them, and the only one whose cells they
/// can see move — so an edit that also re-windowed thirteen films they have not
/// turned to is an edit whose effects are discovered on paper. Both cases below
/// are read as "…on this film".
public enum PrintCellSyncScope: String, CaseIterable, Sendable, Identifiable {

    /// Only marks from the same series as the cell being edited.
    ///
    /// The default: a film that carries two series is usually carrying them for
    /// comparison, and dragging one series' window onto the other is rarely what
    /// was meant.
    case sameSeries

    /// Every cell on the film the edited cell is on.
    case thisFilm

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sameSeries: return "Same Series"
        case .thisFilm: return "Whole Film"
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

    /// Shuts or opens a lock the way the rail's button does, seeding included.
    ///
    /// The window lock cannot simply be set: cells never opened carry no window,
    /// and a relative window edit has nothing to work from, so they are given
    /// one the moment the lock shuts (see ``seedWindowsForSync()``). That is a
    /// precondition of the lock, not a detail of the button that happened to
    /// shut it — and with a keyboard shortcut now shutting the same lock, a
    /// caller that forgot it would leave the unseeded cells sitting still while
    /// their neighbours moved. One door in, so neither caller can forget.
    ///
    /// Refuses while a job-wide window is in force, where nothing per-cell
    /// reaches the film and a lit lock would promise otherwise.
    @discardableResult
    public func toggleSyncFromUI(_ option: PrintCellSyncOptions) -> Bool {
        guard option != .window || !isCellWindowingOverridden else { return false }
        toggleSync(option)
        if option == .window, cellSync.contains(.window) {
            Task { await seedWindowsForSync() }
        }
        return true
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
        guard let source = printedItems.first(where: { $0.id == itemID }) else { return [] }
        // The film first, always: whatever the scope says, an edit stops at the
        // edge of the sheet being judged.
        let onFilm = cellsOnFilm(containing: itemID)
        let candidates: [PrintSelectionItem]
        switch cellSyncScope {
        case .thisFilm:
            candidates = onFilm
        case .sameSeries:
            let key = source.seriesKey
            candidates = onFilm.filter { $0.seriesKey == key }
        }
        return candidates.filter { $0.id != itemID }
    }

    /// The cells sharing a film with this one, in cell order — the film's own
    /// slice of the printed marks.
    ///
    /// Computed from ``printedItems`` rather than the raw marks: a range filter
    /// decides what is laid out, so it decides which cells are neighbours.
    public func cellsOnFilm(containing itemID: String) -> [PrintSelectionItem] {
        let items = printedItems
        let cellsPerFilm = max(1, plan.cellsPerFilm)
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return [] }
        let start = (index / cellsPerFilm) * cellsPerFilm
        let end = min(items.count, start + cellsPerFilm)
        return Array(items[start..<end])
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
        guard propagates(.zoomPan, from: itemID),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        // The same laying-in rule as the cell that was dragged: a peer clamped
        // as though it were fitted would sit still at zoom 1 while the source
        // slid, which is the linked-cells version of the pan tool looking dead.
        let covers = picturesCoverTheirCells
        for peer in editPeers(of: itemID) {
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
                PrintViewModel.clampPan(of: &presentation, pixelSize: nil,
                                        covers: covers)
            }
        }
    }

    /// Copies the edited cell's angle onto its peers.
    ///
    /// The angle itself, absolutely — not the delta that was just applied. Two
    /// cells that started at different angles and were then turned by the same
    /// amount are still at different angles, which is the one thing a shut
    /// rotate lock is meant to rule out: the point of turning a run together is
    /// that they end up standing the same way round. It is the same rule the
    /// zoom and pan lock follows, and for the same reason.
    func propagateRotation(from itemID: String, cellSize: CGSize?) {
        guard propagates(.rotate, from: itemID),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        for peer in editPeers(of: itemID) {
            mutatePresentation(forItemID: peer.id, cellSize: cellSize) { presentation in
                presentation.rotationDegrees = source.rotationDegrees
            }
        }
    }

    /// Copies the edited cell's palette onto its peers.
    ///
    /// The palette itself, not a delta: unlike a window, there is no sense in
    /// which one cell's Hot Iron is "more" than another's, so the peers take the
    /// same palette outright.
    func propagatePalette(from itemID: String, cellSize: CGSize?) {
        guard propagates(.palette, from: itemID),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        for peer in editPeers(of: itemID) {
            mutatePresentation(forItemID: peer.id, cellSize: cellSize) { presentation in
                presentation.palette = source.palette
            }
            // A palette arriving through the CLUT lock is as hand-made as one
            // picked on the cell itself, so the peer stops following the film
            // for the same reason the source did — unless it has just landed
            // back on the film's own colour.
            if source.palette == filmPalette {
                selfPalettedItemIDs.remove(peer.id)
            } else {
                selfPalettedItemIDs.insert(peer.id)
            }
        }
    }

    /// Copies the edited cell's inversion onto its peers.
    func propagateInversion(from itemID: String, cellSize: CGSize?) {
        guard propagates(.invert, from: itemID),
              let source = selection.items.first(where: { $0.id == itemID })?.presentation
        else { return }
        for peer in editPeers(of: itemID) {
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
        guard propagates(.window, from: itemID), previous.width > 0 else { return }
        let widthFactor = current.width / previous.width
        let centerShift = (current.center - previous.center) / previous.width
        guard widthFactor.isFinite, centerShift.isFinite else { return }
        for peer in editPeers(of: itemID) {
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
    /// the same numbers everywhere they are applied. The space comes with the
    /// numbers for the same reason: a preset's −600 HU written into a peer
    /// still labelled "stored values" would wash that peer out instead.
    func propagateWindowAbsolute(
        from itemID: String, window: WindowSettings, space: PrintWindowSpace
    ) {
        guard propagates(.window, from: itemID) else { return }
        for peer in editPeers(of: itemID) {
            selection.adjust(peer.with(
                windowCenter: .some(window.center.rounded()),
                windowWidth: .some(max(1, window.width.rounded())),
                windowSpace: space))
        }
    }
}
