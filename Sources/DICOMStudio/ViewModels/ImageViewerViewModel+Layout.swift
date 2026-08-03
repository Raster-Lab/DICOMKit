// ImageViewerViewModel+Layout.swift
// DICOMStudio
//
// DICOM Studio — driving the viewer's tile grid.
//
// One tile is *focused* at a time, and the focused tile is the live view model:
// gestures, window/level, cine and rendering all keep working exactly as they do
// at 1×1. Changing focus writes the outgoing tile's arrangement back into
// ``cells`` and loads the incoming tile's, so every tile keeps its own zoom,
// pan, orientation and window without the view model having to hold N copies of
// its rendering machinery.

import Foundation
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    // MARK: - Layout

    /// Whether more than one tile is on screen.
    public var isMultiCellLayout: Bool { layout.cellCount > 1 }

    /// Switches the tile grid, filling tiles from the series.
    ///
    /// The focused tile's file stays put and the rest follow it in series order,
    /// which is what makes a 2×2 read as "this image and the next three".
    public func applyLayout(_ newLayout: ViewerTileLayout) {
        captureFocusedCell()

        let previousCells = cells
        let anchorPath = cells.indices.contains(focusedCellIndex)
            ? cells[focusedCellIndex].filePath ?? filePath
            : filePath
        let anchorIndex = anchorPath.flatMap { seriesFiles.firstIndex(of: $0) } ?? currentFileIndex

        layout = newLayout
        cells = (0..<newLayout.cellCount).map { position in
            // Keep an existing tile's arrangement when it already showed this
            // file: resizing the grid should not throw away the user's work.
            let path = fileForCell(offset: position, anchorIndex: anchorIndex)
            if let existing = previousCells.first(where: { $0.filePath == path && !$0.isEmpty }) {
                var moved = existing
                moved.index = position
                return moved
            }
            return blankCell(at: position, filePath: path)
        }

        focusedCellIndex = 0
        loadFocusedCellIfNeeded()
    }

    /// The file a tile shows when a grid is applied.
    ///
    /// With a study open, a grid is a comparison of *series*: each tile takes
    /// the first image of the next series, starting from the one on screen, so a
    /// 2×2 reads as "this series and the next three" rather than four adjacent
    /// slices of one stack — which the wheel already gives, one tile at a time.
    /// Grids larger than the study has series fall back to filling the rest from
    /// the current stack, so no tile is left blank while there are images to put
    /// in it.
    private func fileForCell(offset: Int, anchorIndex: Int) -> String? {
        if let path = seriesLedFile(offset: offset) { return path }
        guard !seriesFiles.isEmpty else {
            return offset == 0 ? filePath : nil
        }
        let index = anchorIndex + offset
        return seriesFiles.indices.contains(index) ? seriesFiles[index] : nil
    }

    /// The first image of the offset-th series from the current one.
    private func seriesLedFile(offset: Int) -> String? {
        guard !studySeries.isEmpty else { return nil }
        let start = currentSeriesIndex ?? 0
        let index = start + offset
        guard studySeries.indices.contains(index) else { return nil }
        return studySeries[index].firstFilePath
    }

    /// Where the series on screen sits in the study's series list.
    private var currentSeriesIndex: Int? {
        if let currentSeriesUID,
           let index = studySeries.firstIndex(where: { $0.seriesInstanceUID == currentSeriesUID }) {
            return index
        }
        guard let filePath else { return nil }
        return studySeries.firstIndex { $0.filePaths.contains(filePath) }
    }

    /// The series a tile's file belongs to, for hanging it as a series rather
    /// than as a loose file.
    private func seriesEntryForFile(_ path: String?) -> ViewerSeriesEntry? {
        guard let path else { return nil }
        return studySeries.first { $0.filePaths.contains(path) }
    }

    /// A tile showing `filePath` with the viewer's default presentation.
    ///
    /// New tiles inherit the viewer's current series, so a fresh grid reads as
    /// "this series, continued" until the user hangs something else in a tile.
    private func blankCell(at index: Int, filePath: String?) -> ViewerCellState {
        // A tile showing another series navigates *that* series: scrolling it
        // must walk its own stack, not the one the grid was applied from.
        let entry = seriesEntryForFile(filePath)
        let tileSeriesFiles = entry?.filePaths ?? seriesFiles
        return ViewerCellState(
            index: index,
            filePath: filePath,
            seriesUID: entry?.seriesInstanceUID ?? currentSeriesUID,
            seriesFiles: tileSeriesFiles,
            fileIndex: filePath.flatMap { tileSeriesFiles.firstIndex(of: $0) } ?? 0,
            frameIndex: 0,
            frameCount: 1,
            windowCenter: inheritedWindowCenter(for: filePath),
            windowWidth: inheritedWindowWidth(for: filePath)
        )
    }

    /// The window a new tile should start from, or `nil` to let its image decide.
    ///
    /// The viewer's window is only meaningful for images that share the current
    /// one's presentation: it is held in stored-value space, so it has been
    /// divided through *this* image's rescale pair, and it may be an adjustment
    /// the user made for this reconstruction. A grid drawn from a flat file list
    /// can span several series — a lung kernel, a soft-tissue kernel, an MPR —
    /// and stamping one series' window across all of them is what washes the
    /// other tiles out. So the window travels only within its own series.
    private func windowTravels(to filePath: String?) -> Bool {
        guard let filePath else { return false }
        if filePath == self.filePath { return true }
        guard let anchorSeries = seriesEntry(containing: self.filePath) else {
            // No catalogue to check against — only the current file is known to
            // share this window.
            return false
        }
        return anchorSeries.filePaths.contains(filePath)
    }

    private func inheritedWindowCenter(for filePath: String?) -> Double? {
        windowTravels(to: filePath) ? windowCenter : nil
    }

    private func inheritedWindowWidth(for filePath: String?) -> Double? {
        windowTravels(to: filePath) ? windowWidth : nil
    }

    // MARK: - Focus

    /// Focuses a tile, handing the live view model over to it.
    public func focusCell(_ index: Int) {
        guard cells.indices.contains(index), index != focusedCellIndex else { return }
        captureFocusedCell()
        focusedCellIndex = index
        loadFocusedCellIfNeeded()
    }

    /// Writes the live view model's arrangement back into the focused tile.
    ///
    /// Called before anything reads ``cells`` — focus changes, layout changes,
    /// and marking for print — because the live state is the truth for the
    /// focused tile until it is handed back.
    public func captureFocusedCell() {
        guard cells.indices.contains(focusedCellIndex) else { return }
        var cell = cells[focusedCellIndex]
        // A tile that never had a file adopts whatever the viewer is showing.
        if cell.filePath == nil { cell.filePath = filePath }
        // The focused tile owns navigation, so stepping through its series moves
        // the *tile* onto the new file. Without this the tile keeps pointing at
        // the file it was hung with, and everything read from `cells` — the
        // print checkbox, the marks, film order — describes an image that is no
        // longer on screen.
        if cell.filePath != filePath, let filePath,
           cell.seriesFiles.contains(filePath) || seriesFiles.contains(filePath) {
            cell.filePath = filePath
        }
        guard cell.filePath == filePath else { return }

        cell.frameIndex = currentFrameIndex
        cell.frameCount = numberOfFrames
        // The focused tile owns navigation, so where it got to is its own state.
        if !seriesFiles.isEmpty {
            cell.seriesFiles = seriesFiles
            cell.fileIndex = currentFileIndex
        }
        cell.windowCenter = windowCenter
        cell.windowWidth = windowWidth
        cell.zoom = zoomLevel
        cell.panX = panOffsetX
        cell.panY = panOffsetY
        cell.rotationAngle = rotationAngle
        cell.isFlippedHorizontal = isFlippedHorizontal
        cell.isFlippedVertical = isFlippedVertical
        cell.isInverted = isInverted
        cell.viewportWidth = viewContentWidth
        cell.viewportHeight = viewContentHeight
        cells[focusedCellIndex] = cell
    }

    /// Loads the focused tile into the live view model.
    private func loadFocusedCellIfNeeded() {
        loadCell(at: focusedCellIndex)
    }

    /// Restores a tile's arrangement onto the live view model.
    func restoreArrangement(of cell: ViewerCellState) {
        zoomLevel = cell.zoom
        panOffsetX = cell.panX
        panOffsetY = cell.panY
        rotationAngle = cell.rotationAngle
        isFlippedHorizontal = cell.isFlippedHorizontal
        isFlippedVertical = cell.isFlippedVertical
        isInverted = cell.isInverted
        // A tile with no window of its own reads at the image's VOI — the
        // previous tile's window must not follow the user across a hang.
        if let cellCenter = cell.windowCenter, let cellWidth = cell.windowWidth, cellWidth >= 1 {
            windowCenter = cellCenter
            windowWidth = cellWidth
        } else {
            resetWindowToFileDefault()
        }
        if cell.frameIndex != currentFrameIndex, cell.frameIndex < numberOfFrames {
            currentFrameIndex = cell.frameIndex
        }
        renderCurrentFrame()
    }

    /// Records a tile's on-screen size, so its zoom/pan resolves to a crop.
    public func setCellViewport(_ index: Int, width: Double, height: Double) {
        guard cells.indices.contains(index) else { return }
        cells[index].viewportWidth = width
        cells[index].viewportHeight = height
        if index == focusedCellIndex {
            viewContentWidth = width
            viewContentHeight = height
        }
    }

    // MARK: - Print marking

    /// Whether a tile is marked for print.
    ///
    /// The focused tile is read from the live view model rather than from its
    /// stored state: it is the one tile the user can navigate, and its box must
    /// track the image actually on screen — ticked only for images that are
    /// marked, unticked the moment it scrolls onto one that is not.
    public func isCellMarkedForPrint(_ index: Int) -> Bool {
        guard cells.indices.contains(index) else { return false }
        let isFocused = index == focusedCellIndex
        guard let path = isFocused ? (filePath ?? cells[index].filePath)
                                   : cells[index].filePath else { return false }
        let frame = isFocused ? currentFrameIndex : cells[index].frameIndex
        return printSelection.contains(filePath: path, frameIndex: frame)
    }

    /// Marks or unmarks one tile, carrying that tile's own arrangement.
    @discardableResult
    public func togglePrintMarkForCell(_ index: Int) -> Bool {
        captureFocusedCell()
        guard cells.indices.contains(index) else { return false }
        let isFocused = index == focusedCellIndex
        guard let item = cells[index].selectionItem(
            sopInstanceUID: isFocused ? sopInstanceUID : nil,
            seriesDescription: isFocused ? seriesDescriptionForPrint : nil,
            instanceNumber: isFocused ? instanceNumberForPrint : nil
        ) else { return false }
        return printSelection.toggle(item)
    }

    /// Brings existing marks back in step with what the viewer is showing.
    ///
    /// A mark is taken when the checkbox is ticked, but the user usually keeps
    /// arranging afterwards — zooming a tile, rotating it, changing the window.
    /// Without this the film would print the arrangement as it stood at the
    /// moment of the tick, and the preview would disagree with the screen.
    /// Only frames that are still marked are touched; nothing is added.
    public func refreshMarksFromViewer() {
        captureFocusedCell()

        if isMultiCellLayout {
            for cell in cells {
                let isFocused = cell.index == focusedCellIndex
                guard let item = cell.selectionItem(
                    sopInstanceUID: isFocused ? sopInstanceUID : nil,
                    seriesDescription: isFocused ? seriesDescriptionForPrint : nil,
                    instanceNumber: isFocused ? instanceNumberForPrint : nil
                ) else { continue }
                printSelection.update(item)
            }
        } else if let item = currentSelectionItem {
            printSelection.update(item)
        }
    }

    /// Reorders existing marks to follow the viewer's tile order.
    ///
    /// Marks accumulate in the order the user ticked them, which need not be the
    /// order the images sit on screen. The film preview is read against the
    /// viewer, so tile order wins: marks that correspond to a tile take that
    /// tile's position, and anything not on screen keeps its relative order
    /// behind them.
    public func syncPrintOrderToViewer() {
        guard isMultiCellLayout else { return }
        var rankByID: [String: Int] = [:]
        for cell in cells {
            guard let path = cell.filePath else { continue }
            let frame = cell.index == focusedCellIndex ? currentFrameIndex : cell.frameIndex
            rankByID["\(path)#\(frame)"] = cell.index
        }
        guard !rankByID.isEmpty else { return }
        let ordered = printSelection.items.enumerated().sorted { lhs, rhs in
            switch (rankByID[lhs.element.id], rankByID[rhs.element.id]) {
            case let (left?, right?):
                return left == right ? lhs.offset < rhs.offset : left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
        printSelection.replace(with: ordered)
    }

    /// The images the layout is currently showing, in grid order.
    ///
    /// This is what "select all" means in the viewer: the pictures on screen,
    /// not the study behind them. At 1×1 the viewer itself is the one tile.
    /// Grid order is film order, so a 2×2 of viewer tiles prints as that 2×2.
    public var layoutSelectionItems: [PrintSelectionItem] {
        guard isMultiCellLayout else {
            return currentSelectionItem.map { [$0] } ?? []
        }
        return cells.compactMap { cell -> PrintSelectionItem? in
            let isFocused = cell.index == focusedCellIndex
            return cell.selectionItem(
                sopInstanceUID: isFocused ? sopInstanceUID : nil,
                seriesDescription: isFocused ? seriesDescriptionForPrint : nil,
                instanceNumber: isFocused ? instanceNumberForPrint : nil
            )
        }
    }

    /// Marks every image the layout is showing. Returns how many were added.
    @discardableResult
    public func markLayoutForPrint() -> Int {
        captureFocusedCell()
        return printSelection.add(contentsOf: layoutSelectionItems)
    }

    /// Unmarks every image the layout is showing.
    ///
    /// Scoped to the screen, like its counterpart: marks taken elsewhere in the
    /// study are left alone, because the user is unticking what they can see.
    /// Returns how many were removed.
    @discardableResult
    public func unmarkLayoutForPrint() -> Int {
        captureFocusedCell()
        let before = printSelection.count
        for item in layoutSelectionItems {
            printSelection.remove(filePath: item.filePath, frameIndex: item.frameIndex)
        }
        return before - printSelection.count
    }

    /// Whether every image on screen is already marked.
    public var isLayoutFullyMarkedForPrint: Bool {
        let items = layoutSelectionItems
        guard !items.isEmpty else { return false }
        return items.allSatisfy {
            printSelection.contains(filePath: $0.filePath, frameIndex: $0.frameIndex)
        }
    }

    /// Whether any image on screen is marked.
    public var isAnyLayoutImageMarkedForPrint: Bool {
        layoutSelectionItems.contains {
            printSelection.contains(filePath: $0.filePath, frameIndex: $0.frameIndex)
        }
    }
}
