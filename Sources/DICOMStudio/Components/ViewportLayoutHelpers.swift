// ViewportLayoutHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent viewport layout calculation helpers

import Foundation

/// Platform-independent helpers for multi-viewport layout calculations.
///
/// Provides grid layout computations, viewport sizing, and position mapping
/// for the multi-viewport display.
public enum ViewportLayoutHelpers: Sendable {

    /// A viewport cell frame within a layout.
    public struct CellFrame: Sendable, Equatable {
        /// X origin.
        public let x: Double
        /// Y origin.
        public let y: Double
        /// Cell width.
        public let width: Double
        /// Cell height.
        public let height: Double

        /// Creates a new cell frame.
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    // MARK: - Grid Layout

    /// Computes cell frames for a grid layout.
    ///
    /// - Parameters:
    ///   - columns: Number of columns.
    ///   - rows: Number of rows.
    ///   - totalWidth: Total available width.
    ///   - totalHeight: Total available height.
    ///   - spacing: Spacing between cells.
    /// - Returns: Array of cell frames in row-major order.
    public static func gridCellFrames(
        columns: Int,
        rows: Int,
        totalWidth: Double,
        totalHeight: Double,
        spacing: Double = 2.0
    ) -> [CellFrame] {
        let cols = max(1, columns)
        let rws = max(1, rows)

        let totalHSpacing = spacing * Double(cols - 1)
        let totalVSpacing = spacing * Double(rws - 1)

        let cellWidth = (totalWidth - totalHSpacing) / Double(cols)
        let cellHeight = (totalHeight - totalVSpacing) / Double(rws)

        var frames: [CellFrame] = []

        for row in 0..<rws {
            for col in 0..<cols {
                let x = Double(col) * (cellWidth + spacing)
                let y = Double(row) * (cellHeight + spacing)
                frames.append(CellFrame(x: x, y: y, width: cellWidth, height: cellHeight))
            }
        }

        return frames
    }

    /// Computes cell frames for a layout type.
    ///
    /// - Parameters:
    ///   - layout: Layout type.
    ///   - totalWidth: Total available width.
    ///   - totalHeight: Total available height.
    ///   - spacing: Spacing between cells.
    /// - Returns: Array of cell frames.
    public static func cellFrames(
        for layout: LayoutType,
        totalWidth: Double,
        totalHeight: Double,
        spacing: Double = 2.0
    ) -> [CellFrame] {
        gridCellFrames(
            columns: layout.columns,
            rows: layout.rows,
            totalWidth: totalWidth,
            totalHeight: totalHeight,
            spacing: spacing
        )
    }

    /// Computes cell frames for a hanging protocol.
    ///
    /// - Parameters:
    ///   - protocol: The hanging protocol.
    ///   - totalWidth: Total available width.
    ///   - totalHeight: Total available height.
    ///   - spacing: Spacing between cells.
    /// - Returns: Array of cell frames.
    public static func cellFrames(
        for hangingProtocol: HangingProtocolModel,
        totalWidth: Double,
        totalHeight: Double,
        spacing: Double = 2.0
    ) -> [CellFrame] {
        gridCellFrames(
            columns: hangingProtocol.effectiveColumns,
            rows: hangingProtocol.effectiveRows,
            totalWidth: totalWidth,
            totalHeight: totalHeight,
            spacing: spacing
        )
    }

    // MARK: - Position Mapping

    /// Converts a grid position to row and column indices.
    ///
    /// - Parameters:
    ///   - position: Position index (0-based, row-major).
    ///   - columns: Number of columns in the grid.
    /// - Returns: Tuple of (row, column).
    public static func positionToRowColumn(position: Int, columns: Int) -> (row: Int, column: Int) {
        let cols = max(1, columns)
        return (position / cols, position % cols)
    }

    /// Converts row and column indices to a grid position.
    ///
    /// - Parameters:
    ///   - row: Row index.
    ///   - column: Column index.
    ///   - columns: Number of columns in the grid.
    /// - Returns: Position index.
    public static func rowColumnToPosition(row: Int, column: Int, columns: Int) -> Int {
        row * max(1, columns) + column
    }

    // MARK: - Hit Testing

    /// Finds which viewport cell contains a given point.
    ///
    /// - Parameters:
    ///   - x: X coordinate.
    ///   - y: Y coordinate.
    ///   - frames: Cell frames.
    /// - Returns: Index of the cell containing the point, or nil.
    public static func hitTestCell(x: Double, y: Double, frames: [CellFrame]) -> Int? {
        for (index, frame) in frames.enumerated() {
            if x >= frame.x && x <= frame.x + frame.width &&
               y >= frame.y && y <= frame.y + frame.height {
                return index
            }
        }
        return nil
    }

    // MARK: - Viewport State Management

    /// Creates initial viewport states for a layout.
    ///
    /// - Parameters:
    ///   - layout: Layout type.
    ///   - activeIndex: Index of the initial active viewport.
    /// - Returns: Array of viewport states.
    public static func createViewportStates(
        for layout: LayoutType,
        activeIndex: Int = 0
    ) -> [ViewportState] {
        let count = layout.cellCount
        return (0..<count).map { index in
            ViewportState(position: index, isActive: index == activeIndex)
        }
    }

    /// Creates viewport states from a hanging protocol's viewport definitions.
    ///
    /// - Parameter hangingProtocol: The hanging protocol.
    /// - Returns: Array of viewport states.
    public static func createViewportStates(
        from hangingProtocol: HangingProtocolModel
    ) -> [ViewportState] {
        let cellCount = hangingProtocol.effectiveCellCount
        let definitions = hangingProtocol.viewportDefinitions

        return (0..<cellCount).map { index in
            let def = definitions.first { $0.position == index }
            return ViewportState(
                position: index,
                isActive: def?.isInitialActive ?? (index == 0 && definitions.isEmpty)
            )
        }
    }

    // MARK: - Display Text

    /// Returns a formatted layout description.
    ///
    /// - Parameters:
    ///   - columns: Number of columns.
    ///   - rows: Number of rows.
    /// - Returns: Formatted string (e.g., "2×2 (4 viewports)").
    public static func layoutDescription(columns: Int, rows: Int) -> String {
        let total = columns * rows
        return "\(columns)×\(rows) (\(total) viewport\(total == 1 ? "" : "s"))"
    }

    /// Returns a formatted layout description for a layout type.
    ///
    /// - Parameter layout: Layout type.
    /// - Returns: Formatted string.
    public static func layoutDescription(for layout: LayoutType) -> String {
        layoutDescription(columns: layout.columns, rows: layout.rows)
    }
}
