//
// FilmGeometry.swift
// DICOMPrintKit
//
// Physical film geometry: sheet size in millimetres for every Film Size ID, and
// the cell rectangles an Image Display Format lays out on that sheet.
//
// Deliberately free of CoreGraphics so the layout maths is testable anywhere
// and independent of the rasterizer that consumes it.
//
// Reference: PS3.3 C.13.3 (Film Box Module), C.13.6 (Film Size ID).
//

import Foundation
import DICOMNetwork

// MARK: - Sheet

/// The physical sheet a film is printed on.
public struct FilmSheet: Sendable, Equatable {
    /// Sheet width in millimetres, after orientation is applied.
    public let widthMillimeters: Double

    /// Sheet height in millimetres, after orientation is applied.
    public let heightMillimeters: Double

    /// Rasterization resolution in dots per inch.
    public let dpi: Double

    public init(widthMillimeters: Double, heightMillimeters: Double, dpi: Double) {
        self.widthMillimeters = max(1, widthMillimeters)
        self.heightMillimeters = max(1, heightMillimeters)
        self.dpi = max(1, dpi)
    }

    /// The sheet for a Film Size ID in the given orientation.
    public init(filmSize: FilmSize, orientation: FilmOrientation, dpi: Double) {
        let portrait = FilmSheet.portraitSizeMillimeters(for: filmSize)
        switch orientation {
        case .portrait:
            self.init(widthMillimeters: portrait.width, heightMillimeters: portrait.height, dpi: dpi)
        case .landscape:
            self.init(widthMillimeters: portrait.height, heightMillimeters: portrait.width, dpi: dpi)
        }
    }

    /// Pixels per millimetre at this resolution.
    public var pixelsPerMillimeter: Double { dpi / 25.4 }

    /// Sheet width in pixels.
    public var pixelWidth: Int { Int((widthMillimeters * pixelsPerMillimeter).rounded()) }

    /// Sheet height in pixels.
    public var pixelHeight: Int { Int((heightMillimeters * pixelsPerMillimeter).rounded()) }

    /// Converts millimetres to pixels at this resolution.
    public func pixels(fromMillimeters millimeters: Double) -> Double {
        millimeters * pixelsPerMillimeter
    }

    /// The nominal portrait size of a Film Size ID, in millimetres.
    ///
    /// Imperial sizes are the exact inch conversions (1 in = 25.4 mm); the
    /// metric and ISO sizes are their standard dimensions.
    public static func portraitSizeMillimeters(for filmSize: FilmSize) -> (width: Double, height: Double) {
        func inches(_ w: Double, _ h: Double) -> (Double, Double) { (w * 25.4, h * 25.4) }
        switch filmSize {
        case .size8InX10In:    return inches(8, 10)
        case .size8_5InX11In:  return inches(8.5, 11)
        case .size10InX12In:   return inches(10, 12)
        case .size10InX14In:   return inches(10, 14)
        case .size11InX14In:   return inches(11, 14)
        case .size11InX17In:   return inches(11, 17)
        case .size14InX14In:   return inches(14, 14)
        case .size14InX17In:   return inches(14, 17)
        case .size24CmX24Cm:   return (240, 240)
        case .size24CmX30Cm:   return (240, 300)
        case .a4:              return (210, 297)
        case .a3:              return (297, 420)
        }
    }
}

// MARK: - Cells

/// One image-box cell on a film sheet, in pixels, origin top-left.
public struct FilmCell: Sendable, Equatable {
    /// The 1-based Image Box Position this cell belongs to.
    public let position: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(position: Int, x: Double, y: Double, width: Double, height: Double) {
        self.position = position
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Whether the cell has a drawable area.
    public var isEmpty: Bool { width <= 0 || height <= 0 }
}

/// Lays out the cells an Image Display Format defines on a sheet.
public enum FilmCellLayout {

    /// Computes cell rectangles in pixels, in Image Box Position order.
    ///
    /// - `STANDARD\C,R` — a uniform grid filled left-to-right, top-to-bottom.
    /// - `ROW\c1,c2,…`  — one band per row; each band's cells share the full width.
    /// - `COL\r1,r2,…`  — one band per column; each band's cells share the full height.
    /// - `SLIDE` / `SUPERSLIDE` / `CUSTOM\i` — a single cell filling the sheet.
    ///
    /// - Parameters:
    ///   - format: the parsed Image Display Format.
    ///   - sheet: the film sheet.
    ///   - margin: sheet margin in millimetres, applied on all four edges.
    ///   - spacing: gap between adjacent cells in millimetres.
    ///   - footer: a strip in millimetres kept clear along the bottom of the
    ///     sheet, below the margin, for film-wide text. The cells are laid out
    ///     in what is left, so a footer never lands on the bottom row's anatomy.
    public static func cells(
        for format: PrintImageDisplayFormat,
        on sheet: FilmSheet,
        marginMillimeters margin: Double = 5,
        spacingMillimeters spacing: Double = 2,
        footerMillimeters footer: Double = 0
    ) -> [FilmCell] {
        let inset = max(0, sheet.pixels(fromMillimeters: margin))
        let gap = max(0, sheet.pixels(fromMillimeters: spacing))
        let originX = inset
        let originY = inset
        let usableWidth = max(0, Double(sheet.pixelWidth) - 2 * inset)
        // The footer eats into the picture's height, never into its own
        // clearance: a strip deeper than the sheet can spare would leave no
        // cells at all, so it is capped at a third of what the margins left.
        let available = max(0, Double(sheet.pixelHeight) - 2 * inset)
        let reserved = min(max(0, sheet.pixels(fromMillimeters: footer)), available / 3)
        let usableHeight = available - reserved

        switch format.kind {
        case .standard(let rows, let columns):
            return grid(rows: rows, columns: columns,
                        originX: originX, originY: originY,
                        width: usableWidth, height: usableHeight, gap: gap)

        case .row(let counts):
            var cells: [FilmCell] = []
            var position = 1
            let bandHeight = band(usableHeight, count: counts.count, gap: gap)
            for (rowIndex, cellCount) in counts.enumerated() {
                let cellWidth = band(usableWidth, count: cellCount, gap: gap)
                let y = originY + Double(rowIndex) * (bandHeight + gap)
                for column in 0..<cellCount {
                    cells.append(FilmCell(
                        position: position,
                        x: originX + Double(column) * (cellWidth + gap),
                        y: y, width: cellWidth, height: bandHeight))
                    position += 1
                }
            }
            return cells

        case .column(let counts):
            var cells: [FilmCell] = []
            var position = 1
            let bandWidth = band(usableWidth, count: counts.count, gap: gap)
            for (columnIndex, cellCount) in counts.enumerated() {
                let cellHeight = band(usableHeight, count: cellCount, gap: gap)
                let x = originX + Double(columnIndex) * (bandWidth + gap)
                for row in 0..<cellCount {
                    cells.append(FilmCell(
                        position: position,
                        x: x,
                        y: originY + Double(row) * (cellHeight + gap),
                        width: bandWidth, height: cellHeight))
                    position += 1
                }
            }
            return cells

        case .slide, .superslide, .custom:
            return [FilmCell(position: 1, x: originX, y: originY,
                             width: usableWidth, height: usableHeight)]
        }
    }

    /// A uniform rows × columns grid, filled row-major.
    private static func grid(
        rows: Int, columns: Int,
        originX: Double, originY: Double,
        width: Double, height: Double, gap: Double
    ) -> [FilmCell] {
        let rows = max(1, rows), columns = max(1, columns)
        let cellWidth = band(width, count: columns, gap: gap)
        let cellHeight = band(height, count: rows, gap: gap)
        var cells: [FilmCell] = []
        var position = 1
        for row in 0..<rows {
            for column in 0..<columns {
                cells.append(FilmCell(
                    position: position,
                    x: originX + Double(column) * (cellWidth + gap),
                    y: originY + Double(row) * (cellHeight + gap),
                    width: cellWidth, height: cellHeight))
                position += 1
            }
        }
        return cells
    }

    /// The size of one band when `count` bands share `total` with `gap` between them.
    private static func band(_ total: Double, count: Int, gap: Double) -> Double {
        guard count > 0 else { return 0 }
        return max(0, (total - gap * Double(count - 1)) / Double(count))
    }
}

// MARK: - Fitting

/// How an image is placed inside its cell.
public enum FilmFitResult: Sendable, Equatable {
    /// The destination rectangle in sheet pixels, and the source rectangle in
    /// image pixels that maps onto it (the full image unless cropped).
    case placed(destination: FilmCell, sourceX: Double, sourceY: Double,
                sourceWidth: Double, sourceHeight: Double)
    /// The image could not be placed (FAIL decimate/crop behavior).
    case failed(reason: String)
}

/// Places an image inside a cell honoring Requested Image Size and
/// Requested Decimate/Crop Behavior.
public enum FilmImageFitter {

    /// - Parameters:
    ///   - imageWidth/imageHeight: the image's pixel dimensions.
    ///   - cell: the destination cell in sheet pixels.
    ///   - requestedSizeMillimeters: Requested Image Size (2020,0030), the
    ///     desired *width* of the printed image, when the SCU asked for one.
    ///   - behavior: Requested Decimate/Crop Behavior (2020,0040).
    ///   - sheet: the sheet, for millimetre → pixel conversion.
    public static func fit(
        imageWidth: Double,
        imageHeight: Double,
        in cell: FilmCell,
        requestedSizeMillimeters: Double?,
        behavior: DecimateCropBehavior,
        sheet: FilmSheet
    ) -> FilmFitResult {
        guard imageWidth > 0, imageHeight > 0, !cell.isEmpty else {
            return .failed(reason: "Empty image or cell")
        }

        // A requested physical width pins the scale; otherwise fit the cell.
        let requestedPixels = requestedSizeMillimeters.map { sheet.pixels(fromMillimeters: $0) }

        switch behavior {
        case .decimate:
            let scale: Double
            if let requested = requestedPixels, requested > 0 {
                // Honor the request, but never overflow the cell.
                scale = min(requested / imageWidth,
                            min(cell.width / imageWidth, cell.height / imageHeight))
            } else {
                scale = min(cell.width / imageWidth, cell.height / imageHeight)
            }
            let width = imageWidth * scale
            let height = imageHeight * scale
            return .placed(
                destination: FilmCell(
                    position: cell.position,
                    x: cell.x + (cell.width - width) / 2,
                    y: cell.y + (cell.height - height) / 2,
                    width: width, height: height),
                sourceX: 0, sourceY: 0, sourceWidth: imageWidth, sourceHeight: imageHeight)

        case .crop:
            // Fill the cell and crop the overflow, centred.
            let scale = max(cell.width / imageWidth, cell.height / imageHeight)
            let visibleWidth = min(imageWidth, cell.width / scale)
            let visibleHeight = min(imageHeight, cell.height / scale)
            return .placed(
                destination: cell,
                sourceX: (imageWidth - visibleWidth) / 2,
                sourceY: (imageHeight - visibleHeight) / 2,
                sourceWidth: visibleWidth, sourceHeight: visibleHeight)

        case .failOver:
            // FAIL: the image must fit at 1:1 (or at the requested size) or the
            // box is reported as unprintable.
            let scale = requestedPixels.map { $0 / imageWidth } ?? 1
            let width = imageWidth * scale
            let height = imageHeight * scale
            guard width <= cell.width + 0.5, height <= cell.height + 0.5 else {
                return .failed(reason: String(
                    format: "Image %.0f×%.0f px does not fit cell %.0f×%.0f px and behavior is FAIL",
                    width, height, cell.width, cell.height))
            }
            return .placed(
                destination: FilmCell(
                    position: cell.position,
                    x: cell.x + (cell.width - width) / 2,
                    y: cell.y + (cell.height - height) / 2,
                    width: width, height: height),
                sourceX: 0, sourceY: 0, sourceWidth: imageWidth, sourceHeight: imageHeight)
        }
    }
}
