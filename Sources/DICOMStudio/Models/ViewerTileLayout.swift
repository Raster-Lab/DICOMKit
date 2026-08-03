// ViewerTileLayout.swift
// DICOMStudio
//
// DICOM Studio — the viewer's tile layout.
//
// The viewer can show one image or a grid of them. The grid is the same shape
// as a film: what you arrange in the viewer's cells is what lands in the film's
// cells, in the same order. Each tile keeps its own zoom, pan, orientation and
// window, so "the image as I arranged it" is per tile, not global.

import Foundation
import DICOMPrintKit

// MARK: - Layout

/// A rows × columns tile grid, from 1×1 up to 4×4.
public struct ViewerTileLayout: Sendable, Hashable, Identifiable {
    public let rows: Int
    public let columns: Int

    public init(rows: Int, columns: Int) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
    }

    public var id: String { "\(rows)x\(columns)" }

    /// Tiles in this layout.
    public var cellCount: Int { rows * columns }

    /// Menu label, e.g. "2×3".
    public var displayName: String { "\(rows)×\(columns)" }

    /// The single-image default.
    public static let single = ViewerTileLayout(rows: 1, columns: 1)

    /// Every offered layout: 1×1, 1×2 … 1×4, 2×1 … 4×4, plus the 4×5 film-sheet
    /// grid.
    ///
    /// Rows vary slowest so the menu reads the way the labels do.
    public static let allCases: [ViewerTileLayout] = (1...4).flatMap { rows in
        (1...4).map { ViewerTileLayout(rows: rows, columns: $0) }
    } + [ViewerTileLayout(rows: 4, columns: 5)]
}

// MARK: - Tile state

/// One tile: what it shows, and how the user arranged it.
///
/// Transforms live here rather than on the view model because each tile is
/// arranged independently — zooming the top-left tile must not move the others.
public struct ViewerCellState: Sendable, Equatable, Identifiable {

    /// 0-based position in the grid, in reading order. Also the film cell order.
    public var index: Int

    public var id: Int { index }

    /// The file this tile shows, or `nil` for an empty tile.
    public var filePath: String?

    /// The series hung in this tile, when it came from the series pane.
    ///
    /// Tiles are independent: hanging a different series in one tile must not
    /// disturb the others, so the series lives per tile rather than on the
    /// view model.
    public var seriesUID: String?

    /// The tile's own navigation list — the files of its series, in order.
    public var seriesFiles: [String]

    /// Index of ``filePath`` within ``seriesFiles``.
    public var fileIndex: Int

    /// 0-based frame within that file.
    public var frameIndex: Int

    /// Frames in the source, for the tile's label.
    public var frameCount: Int

    /// The tile's window, or `nil` when it has none of its own yet.
    ///
    /// `nil` means "whatever this image's own VOI says": a freshly hung series
    /// has never been windowed by the user, and inventing a value here would
    /// show it at a window belonging to some other image.
    public var windowCenter: Double?
    public var windowWidth: Double?

    public var zoom: Double
    public var panX: Double
    public var panY: Double
    public var rotationAngle: Double
    public var isFlippedHorizontal: Bool
    public var isFlippedVertical: Bool
    public var isInverted: Bool

    /// Size of this tile on screen, needed to resolve zoom/pan to a crop.
    public var viewportWidth: Double
    public var viewportHeight: Double

    public init(
        index: Int,
        filePath: String? = nil,
        seriesUID: String? = nil,
        seriesFiles: [String] = [],
        fileIndex: Int = 0,
        frameIndex: Int = 0,
        frameCount: Int = 1,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        zoom: Double = 1,
        panX: Double = 0,
        panY: Double = 0,
        rotationAngle: Double = 0,
        isFlippedHorizontal: Bool = false,
        isFlippedVertical: Bool = false,
        isInverted: Bool = false,
        viewportWidth: Double = 0,
        viewportHeight: Double = 0
    ) {
        self.index = index
        self.filePath = filePath
        self.seriesUID = seriesUID
        self.seriesFiles = seriesFiles
        self.fileIndex = fileIndex
        self.frameIndex = frameIndex
        self.frameCount = frameCount
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
        self.rotationAngle = rotationAngle
        self.isFlippedHorizontal = isFlippedHorizontal
        self.isFlippedVertical = isFlippedVertical
        self.isInverted = isInverted
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
    }

    /// Whether this tile has anything to show.
    public var isEmpty: Bool { filePath == nil }

    /// This tile's arrangement, in the form the print path consumes.
    public var presentation: ViewerPresentation {
        ViewerPresentation(
            zoom: zoom,
            panX: panX,
            panY: panY,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            rotationDegrees: rotationAngle,
            flipHorizontal: isFlippedHorizontal,
            flipVertical: isFlippedVertical,
            invert: isInverted
        )
    }

    /// A print mark for this tile, or `nil` when the tile is empty.
    public func selectionItem(
        sopInstanceUID: String? = nil,
        seriesDescription: String? = nil,
        instanceNumber: Int? = nil
    ) -> PrintSelectionItem? {
        guard let filePath else { return nil }
        return PrintSelectionItem(
            filePath: filePath,
            sopInstanceUID: sopInstanceUID,
            frameIndex: frameIndex,
            frameCount: frameCount,
            seriesDescription: seriesDescription,
            instanceNumber: instanceNumber,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            presentation: presentation
        )
    }
}
