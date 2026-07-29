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

    /// The series file for a tile, or `nil` when the series runs out.
    private func fileForCell(offset: Int, anchorIndex: Int) -> String? {
        guard !seriesFiles.isEmpty else {
            return offset == 0 ? filePath : nil
        }
        let index = anchorIndex + offset
        return seriesFiles.indices.contains(index) ? seriesFiles[index] : nil
    }

    /// A tile showing `filePath` with the viewer's default presentation.
    ///
    /// New tiles inherit the viewer's current series, so a fresh grid reads as
    /// "this series, continued" until the user hangs something else in a tile.
    private func blankCell(at index: Int, filePath: String?) -> ViewerCellState {
        ViewerCellState(
            index: index,
            filePath: filePath,
            seriesUID: currentSeriesUID,
            seriesFiles: seriesFiles,
            fileIndex: filePath.flatMap { seriesFiles.firstIndex(of: $0) } ?? 0,
            frameIndex: 0,
            frameCount: 1,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
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
        if cell.windowWidth >= 1 {
            windowCenter = cell.windowCenter
            windowWidth = cell.windowWidth
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
    public func isCellMarkedForPrint(_ index: Int) -> Bool {
        guard cells.indices.contains(index),
              let path = cells[index].filePath else { return false }
        let frame = index == focusedCellIndex ? currentFrameIndex : cells[index].frameIndex
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

    /// Marks every non-empty tile, in grid order.
    ///
    /// Grid order is film order, so a 2×2 of viewer tiles prints as that 2×2.
    @discardableResult
    public func markLayoutForPrint() -> Int {
        captureFocusedCell()
        let items = cells.compactMap { cell -> PrintSelectionItem? in
            let isFocused = cell.index == focusedCellIndex
            return cell.selectionItem(
                sopInstanceUID: isFocused ? sopInstanceUID : nil,
                seriesDescription: isFocused ? seriesDescriptionForPrint : nil,
                instanceNumber: isFocused ? instanceNumberForPrint : nil
            )
        }
        return printSelection.add(contentsOf: items)
    }
}
