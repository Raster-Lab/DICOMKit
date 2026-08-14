// PrintViewModel+CellSelection.swift
// DICOMStudio
//
// DICOM Studio — picking out the cells a tool is about to act on.
//
// The locks in `PrintViewModel+CellSync.swift` answer "which cells move with
// this one" by *rule* — same series, this film, everything. That is the right
// answer when the rule is the intent: window the whole series together. It is
// the wrong answer when the intent is "these four, and not the rest", which is
// a thing a reader wants often enough that stating it as a rule is a chore.
//
// So: an explicit set, built by ⌘-clicking cells or by taking everything from
// the focused cell to the end of the film. While it holds two or more cells,
// a tool acts on exactly them and the locks stand aside — one rule at a time,
// and the one the reader just stated by hand wins. Empty it and the locks are
// back in charge, which is what an unselected film has always done.
//
// Not print state: nothing here reaches the film. It decides which marks a drag
// writes to, and the marks are what the print path reads.

import Foundation
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintViewModel {

    // MARK: - What is selected

    /// Whether an explicit selection is in force.
    ///
    /// Two cells, not one: a single selected cell says nothing the focus does not
    /// already say, and treating it as a selection would silently switch the
    /// locks off the moment a reader clicked a cell.
    public var hasCellSelection: Bool { selectedItemIDs.count > 1 }

    /// Whether this cell is in the explicit selection.
    public func isCellSelected(_ itemID: String) -> Bool {
        selectedItemIDs.contains(itemID)
    }

    /// The cells a tool acting on `itemID` should write to, the source included.
    ///
    /// The one place that decision is made, so the marks list, the drag handlers
    /// and the lock badges cannot disagree about what the next drag will hit.
    ///
    /// An explicit selection wins outright. It is a statement the reader has just
    /// made by hand about *these* cells, and a lock quietly widening it — to the
    /// rest of the series, or to every cell in the job — would undo the point of
    /// making it. Cells outside the selection are left alone even when a lock
    /// would have reached them.
    public func cellsAffected(byEditing itemID: String) -> [PrintSelectionItem] {
        guard hasCellSelection, selectedItemIDs.contains(itemID) else {
            let source = [selection.items.first { $0.id == itemID }].compactMap { $0 }
            // Only when a lock is actually closed. `syncPeers` answers "which
            // cells does the *scope* cover", which is a different question and
            // always has an answer — asking it without checking the locks first
            // is how a drag on an unselected cell ended up reaching the whole
            // series with every lock open.
            guard isCellSyncActive else { return source }
            return source + syncPeers(of: itemID)
        }
        return selection.items.filter { selectedItemIDs.contains($0.id) }
    }

    /// The cells other than the source that an edit of `itemID` reaches.
    ///
    /// What the propagation in `PrintViewModel+CellSync.swift` iterates: the
    /// source has already been written by the tool that called in, and writing it
    /// twice would re-apply a relative delta.
    public func editPeers(of itemID: String) -> [PrintSelectionItem] {
        guard hasCellSelection, selectedItemIDs.contains(itemID) else {
            // As above: no lock closed, no peers. Each propagation still checks
            // its own lock through ``propagates(_:from:)`` before it writes —
            // this is the same rule stated for callers that only want the list.
            return isCellSyncActive ? syncPeers(of: itemID) : []
        }
        return selection.items.filter { selectedItemIDs.contains($0.id) && $0.id != itemID }
    }

    /// Whether an edit of this kind, made on this cell, travels to other cells.
    ///
    /// Two ways it can: the cell is part of a hand-made selection, or the lock
    /// for that kind of edit is closed. The first is checked against the *source*
    /// cell — a drag on a cell outside the selection is a drag on that cell
    /// alone, and must not reach the selection or the lock's peers.
    ///
    /// A job-wide window still stops window edits travelling anywhere, selection
    /// or not: nothing per-cell reaches the film then, so there is nothing to
    /// carry.
    func propagates(_ option: PrintCellSyncOptions, from itemID: String) -> Bool {
        if hasCellSelection, selectedItemIDs.contains(itemID) {
            return option != .window || !isCellWindowingOverridden
        }
        return isSynced(option)
    }

    /// Whether this cell moves when the focused cell is adjusted — what the badge
    /// on a cell means, and what the reader needs answered *before* dragging.
    public func movesWithFocus(_ itemID: String) -> Bool {
        if hasCellSelection { return selectedItemIDs.contains(itemID) }
        return isLinkedToFocus(itemID)
    }

    // MARK: - Building a selection

    /// Adds a cell to the selection, or takes it out — ⌘-click.
    ///
    /// The cell is focused either way: the tools act on the cell under the
    /// pointer, and a ⌘-click that selected a cell without taking it would leave
    /// the next drag writing to whichever cell happened to be focused before.
    public func toggleCellSelection(_ itemID: String) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
            // Focus follows the click even out of the selection: the cell was
            // pointed at, so it is the one being talked about.
            focusCell(itemID)
            return
        }
        selectedItemIDs.insert(itemID)
        focusCell(itemID)
    }

    /// Selects exactly these cells.
    public func selectCells(_ itemIDs: [String]) {
        selectedItemIDs = Set(itemIDs)
    }

    /// Drops the selection, handing the film back to the locks.
    public func clearCellSelection() {
        selectedItemIDs.removeAll()
    }

    /// Selects the focused cell and every cell after it on the same film.
    ///
    /// The film rather than the whole job: what it selected has to be visible on
    /// the sheet in front of the reader. A selection running off into films
    /// nobody has turned to is a drag whose effects are discovered later, on
    /// paper.
    @discardableResult
    public func selectSucceedingCellsOnFilm() -> Int {
        guard let focusedItemID,
              let index = selection.items.firstIndex(where: { $0.id == focusedItemID })
        else { return 0 }

        let cellsPerFilm = max(1, plan.cellsPerFilm)
        let film = index / cellsPerFilm
        let end = min(selection.items.count, (film + 1) * cellsPerFilm)
        guard index < end else { return 0 }

        selectCells(selection.items[index..<end].map(\.id))
        return end - index
    }

    /// Selects every cell on the film the focused cell is on.
    @discardableResult
    public func selectAllCellsOnFilm() -> Int {
        guard let focusedItemID,
              let index = selection.items.firstIndex(where: { $0.id == focusedItemID })
        else { return 0 }

        let cellsPerFilm = max(1, plan.cellsPerFilm)
        let film = index / cellsPerFilm
        let start = film * cellsPerFilm
        let end = min(selection.items.count, start + cellsPerFilm)
        guard start < end else { return 0 }

        selectCells(selection.items[start..<end].map(\.id))
        return end - start
    }

    // MARK: - Taking cells off the film

    /// Takes the picked cells — or the focused one — off the film.
    ///
    /// The marks behind them are removed, and everything after closes up: the
    /// marks are an ordered list and the layout fills cells from it in order, so
    /// image 7 moves into the hole image 4 left, image 8 into 7's, and the last
    /// film simply ends earlier. Nothing is re-ordered and no cell is left blank
    /// in the middle of a sheet, which is what "and the rest shuffle up" means
    /// on a light box.
    ///
    /// - Returns: how many cells were taken off.
    @discardableResult
    public func removeSelectedCells() -> Int {
        let doomed: [String]
        if hasCellSelection {
            // In film order, so the log and the focus that follows read in the
            // order the reader sees rather than in hash order.
            doomed = printedItems.map(\.id).filter { selectedItemIDs.contains($0) }
        } else if let focusedItemID {
            doomed = [focusedItemID]
        } else {
            return 0
        }
        guard !doomed.isEmpty else { return 0 }

        // Where the focus should land afterwards: the cell that shuffles up into
        // the first hole, so a run of deletions can be done from one spot
        // without chasing the picture around the sheet.
        let survivorID = firstSurvivor(after: doomed)

        for id in doomed {
            guard let item = selection.items.first(where: { $0.id == id }) else { continue }
            selection.remove(filePath: item.filePath, frameIndex: item.frameIndex)
        }

        clearCellSelection()
        pruneAnnotations()
        clampImageRange()
        focusCell(survivorID)
        return doomed.count
    }

    /// The first mark still on the film after these are taken off — the one that
    /// shuffles up into the first hole, or the new last cell when the deletions
    /// run to the end.
    private func firstSurvivor(after doomed: [String]) -> String? {
        let doomedSet = Set(doomed)
        let items = printedItems
        guard let firstHole = items.firstIndex(where: { doomedSet.contains($0.id) }) else {
            return focusedItemID
        }
        if let next = items[firstHole...].first(where: { !doomedSet.contains($0.id) }) {
            return next.id
        }
        return items[..<firstHole].last(where: { !doomedSet.contains($0.id) })?.id
    }

    /// What the delete command should say it is about to do.
    public var removableCellCount: Int {
        if hasCellSelection { return selectedItemIDs.count }
        return focusedItemID == nil ? 0 : 1
    }

    /// Forgets marks that are no longer on the film — the selection's half of
    /// ``pruneFocus()``.
    public func pruneCellSelection() {
        let live = Set(selection.items.map(\.id))
        selectedItemIDs.formIntersection(live)
    }

    /// What the film says about the selection, for the preview's caption.
    public var cellSelectionSummary: String? {
        guard hasCellSelection else { return nil }
        return "\(selectedItemIDs.count) cells selected · tools act on these"
    }
}
