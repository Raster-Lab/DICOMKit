// ImageViewerViewModel+Series.swift
// DICOMStudio
//
// DICOM Studio — the study's series, and hanging them in tiles.
//
// The viewer's left pane lists every series of the open study. A series is hung
// in a tile by dragging its card onto the tile, or by selecting the tile and
// double-clicking the card. Each tile keeps its own series, so a 2×2 can show
// four different series of the same study side by side.

import Foundation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    // MARK: - The study's series

    /// Loads the series pane's contents.
    ///
    /// Marks as visited whichever series the viewer is already showing, so the
    /// pane opens describing the state the user is actually in.
    public func loadStudySeries(_ entries: [ViewerSeriesEntry], studyUID: String? = nil) {
        // Series Number order, whatever order the caller had them in: the pane
        // is how a reader finds "series 4", and that only works if the list is
        // in the order the study itself asserts. Unnumbered series sort last —
        // see `ViewerSeriesCatalog.isOrderedBefore`.
        studySeries = entries.sorted(by: ViewerSeriesCatalog.isOrderedBefore)
        studyInstanceUID = studyUID
        if let current = seriesEntry(containing: filePath) {
            currentSeriesUID = current.seriesInstanceUID
            visitedSeriesUIDs.insert(current.seriesInstanceUID)
            return
        }
        // Nothing of this study is on screen yet — open the pane on its first
        // series, showing that series' first image. A study that lists its
        // series but shows none of them leaves the reader with an empty viewer
        // and no obvious next click.
        selectFirstSeriesIfNothingShown()
    }

    /// Clears the viewer down to a blank slate for a different study.
    ///
    /// Opening a study from the library is a fresh read, and everything the
    /// previous one left behind is misleading here: another study's tiles in the
    /// grid, its zoom and rotation, its window, its stale error or report — and
    /// its print selection, whose marks point at files that are no longer on
    /// screen. Opening a study from the library is the one entry point that means
    /// "start over", so the selected-images panel starts over with it; the
    /// library's own "Print…" does not come through here, so the files it marks
    /// survive.
    public func prepareForNewStudy() {
        layout = .single
        cells = []
        focusedCellIndex = 0
        studySeries = []
        studyInstanceUID = nil
        currentSeriesUID = nil
        visitedSeriesUIDs = []
        waveform = nil
        nonImageContent = nil
        errorMessage = nil
        #if canImport(CoreGraphics)
        currentImage = nil
        #endif
        currentFrameIndex = 0
        playbackState = .stopped
        resetTransformations()
        isInverted = false
        // Everything the print panel held: the marks, their captured windows and
        // their film positions, and the sheet itself if it was still up.
        printSelection.clear()
        isPrintSheetPresented = false
    }

    /// Hangs the first series of the study when the viewer has nothing to show.
    ///
    /// Deliberately conditional: a viewer already showing an image is showing
    /// what the user asked for, and replacing it would take the study away from
    /// them the moment the pane finished loading.
    func selectFirstSeriesIfNothingShown() {
        guard filePath == nil, let first = studySeries.first(where: { $0.firstFilePath != nil })
        else { return }
        selectSeries(first.seriesInstanceUID)
    }

    /// Shows a series in the viewer, from its first image.
    ///
    /// The single-click path from the series pane: clicking a card is a request
    /// to read that series, which means it lands in the tile the user is working
    /// in and starts at the top of the stack.
    @discardableResult
    public func selectSeries(_ uid: String) -> Bool {
        assignSeriesToFocusedCell(uid)
    }

    /// The series pane entry a file belongs to, if any.
    public func seriesEntry(containing filePath: String?) -> ViewerSeriesEntry? {
        guard let filePath else { return nil }
        return studySeries.first { $0.filePaths.contains(filePath) }
    }

    /// The entry for a series UID.
    public func seriesEntry(uid: String) -> ViewerSeriesEntry? {
        studySeries.first { $0.seriesInstanceUID == uid }
    }

    /// Whether a series has been shown in a tile at some point this session.
    public func isSeriesVisited(_ uid: String) -> Bool {
        visitedSeriesUIDs.contains(uid)
    }

    /// Whether a series is the one the focused tile is showing.
    public func isCurrentSeries(_ uid: String) -> Bool {
        currentSeriesUID == uid
    }

    // MARK: - Hanging a series

    /// Hangs a series in a tile.
    ///
    /// The tile starts at the series' first instance with a clean arrangement:
    /// a zoom and pan chosen for a different series would be meaningless here,
    /// and silently carrying it over would print a crop the user never composed.
    ///
    /// - Returns: `true` when the series was hung.
    @discardableResult
    public func assignSeries(_ uid: String, toCell index: Int) -> Bool {
        guard let entry = seriesEntry(uid: uid),
              let firstFile = entry.firstFilePath else { return false }

        // At 1×1 there are no tiles until a layout is applied; hang the series
        // in the viewer itself.
        guard cells.indices.contains(index) else {
            guard index == 0 else { return false }
            return hangInViewer(entry, firstFile: firstFile)
        }

        captureFocusedCell()

        var cell = ViewerCellState(index: index)
        cell.filePath = firstFile
        cell.seriesUID = entry.seriesInstanceUID
        cell.seriesFiles = entry.filePaths
        cell.fileIndex = 0
        // The tile keeps the size it already occupies on screen.
        if cells.indices.contains(index) {
            cell.viewportWidth = cells[index].viewportWidth
            cell.viewportHeight = cells[index].viewportHeight
        }
        cells[index] = cell

        visitedSeriesUIDs.insert(entry.seriesInstanceUID)
        if index == focusedCellIndex {
            loadCell(at: index)
        }
        return true
    }

    /// Hangs a series in the focused tile — the double-click path.
    @discardableResult
    public func assignSeriesToFocusedCell(_ uid: String) -> Bool {
        assignSeries(uid, toCell: cells.isEmpty ? 0 : focusedCellIndex)
    }

    /// Replaces the whole viewer with a series, for the 1×1 case.
    private func hangInViewer(_ entry: ViewerSeriesEntry, firstFile: String) -> Bool {
        loadSeries(
            files: entry.filePaths,
            startIndex: 0,
            securityScopedParent: seriesSecurityScopedParent)
        currentSeriesUID = entry.seriesInstanceUID
        visitedSeriesUIDs.insert(entry.seriesInstanceUID)
        resetTransformations()
        return true
    }

    /// Loads a tile's series and file into the live view model.
    func loadCell(at index: Int) {
        guard cells.indices.contains(index) else { return }
        let cell = cells[index]

        // The live viewport is the focused tile's, not the previous tile's —
        // and this holds even for an empty tile, which will adopt the viewer's
        // file on the next capture and would otherwise adopt a stale size with
        // it, resolving its zoom against the wrong viewport.
        if cell.viewportWidth > 0, cell.viewportHeight > 0 {
            viewContentWidth = cell.viewportWidth
            viewContentHeight = cell.viewportHeight
        }

        guard let path = cell.filePath else { return }

        // The focused tile owns navigation: arrow keys and the series controls
        // step through *its* series, not whatever was loaded before it.
        if !cell.seriesFiles.isEmpty {
            seriesFiles = cell.seriesFiles
            currentFileIndex = min(cell.fileIndex, max(0, cell.seriesFiles.count - 1))
        }
        currentSeriesUID = cell.seriesUID ?? seriesEntry(containing: path)?.seriesInstanceUID

        if path != filePath {
            loadFileInternal(at: path, securityScopedParent: seriesSecurityScopedParent)
        }
        restoreArrangement(of: cell)
    }
}
