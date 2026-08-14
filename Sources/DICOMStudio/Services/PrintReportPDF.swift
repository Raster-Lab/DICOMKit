// PrintReportPDF.swift
// DICOMStudio
//
// DICOM Studio — the print records as a PDF report.
//
// JSON export is for another program to read; this is for a person. A print
// job history or an audit trail is routinely asked for as evidence — attached
// to a QA record, filed with a service visit, handed to someone who will not
// run `jq` over it — and those readers need a paginated document with the rows
// laid out and dated, not an object graph.

import Foundation

#if canImport(CoreGraphics) && canImport(CoreText)
import CoreGraphics
import CoreText

/// Renders a simple paginated table report to PDF.
///
/// Deliberately plain: monospaced columns, a title block, and a page footer.
/// The value here is legibility and a stable column layout, not typography.
public enum PrintReportPDF {

    /// One report column: a heading and how wide it sits, in points.
    public struct Column: Sendable {
        public let title: String
        public let width: Double

        public init(title: String, width: Double) {
            self.title = title
            self.width = width
        }
    }

    // MARK: - Page metrics

    /// US Letter, the size a report is most likely to be printed on.
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: Double = 40
    static let titleFontSize: Double = 16
    static let metaFontSize: Double = 9
    static let headerFontSize: Double = 9
    static let bodyFontSize: Double = 8.5
    static let rowSpacing: Double = 4

    // MARK: - Rendering

    /// Renders `rows` as a paginated table.
    ///
    /// - Parameters:
    ///   - title: Report title, repeated on the first page only.
    ///   - subtitle: A line under the title — typically the generation date and
    ///     the row count.
    ///   - columns: Column headings and widths. A row's cells are matched to
    ///     these by position; a cell too wide for its column is truncated with
    ///     an ellipsis rather than overrunning its neighbour.
    ///   - rows: The table body. Each row is one line of cells.
    /// - Returns: The PDF file's bytes.
    public static func render(
        title: String,
        subtitle: String,
        columns: [Column],
        rows: [[String]]
    ) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw PrintReportPDFError.couldNotCreateDocument
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PrintReportPDFError.couldNotCreateDocument
        }

        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, titleFontSize, nil)
        let metaFont = CTFontCreateWithName("Helvetica" as CFString, metaFontSize, nil)
        let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, headerFontSize, nil)
        let bodyFont = CTFontCreateWithName("Menlo" as CFString, bodyFontSize, nil)

        let bodyLineHeight = bodyFontSize + rowSpacing
        var pageNumber = 0
        var rowIndex = 0

        // At least one page, so an empty report is still a document that says
        // so rather than a zero-page PDF no viewer will open.
        repeat {
            pageNumber += 1
            context.beginPDFPage(nil)

            var y = pageSize.height - margin

            if pageNumber == 1 {
                draw(title, font: titleFont, at: CGPoint(x: margin, y: y - titleFontSize),
                     in: context)
                y -= titleFontSize + 8
                draw(subtitle, font: metaFont, at: CGPoint(x: margin, y: y - metaFontSize),
                     in: context, gray: 0.35)
                y -= metaFontSize + 14
            }

            // Column headings, ruled off from the body.
            var x = margin
            for column in columns {
                draw(column.title, font: headerFont,
                     at: CGPoint(x: x, y: y - headerFontSize), in: context)
                x += column.width
            }
            y -= headerFontSize + 4
            context.setStrokeColor(gray: 0.6, alpha: 1)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: margin, y: y))
            context.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
            context.strokePath()
            y -= rowSpacing + 2

            if rows.isEmpty {
                draw("No records.", font: metaFont,
                     at: CGPoint(x: margin, y: y - metaFontSize), in: context, gray: 0.35)
            }

            // Fill the page, then carry on to the next one.
            while rowIndex < rows.count, y - bodyLineHeight > margin + 20 {
                var cellX = margin
                let row = rows[rowIndex]
                for (columnIndex, column) in columns.enumerated() {
                    let text = columnIndex < row.count ? row[columnIndex] : ""
                    draw(truncate(text, toWidth: column.width - 6, font: bodyFont),
                         font: bodyFont,
                         at: CGPoint(x: cellX, y: y - bodyFontSize), in: context)
                    cellX += column.width
                }
                y -= bodyLineHeight
                rowIndex += 1
            }

            draw("Page \(pageNumber)", font: metaFont,
                 at: CGPoint(x: pageSize.width - margin - 50, y: margin - 12),
                 in: context, gray: 0.45)

            context.endPDFPage()
        } while rowIndex < rows.count

        context.closePDF()
        return data as Data
    }

    // MARK: - Text

    private static func draw(
        _ text: String, font: CTFont, at point: CGPoint,
        in context: CGContext, gray: CGFloat = 0
    ) {
        guard !text.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(gray: gray, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes))
        context.textPosition = point
        CTLineDraw(line, context)
    }

    /// Trims `text` to fit `width`, ending in an ellipsis when it had to cut.
    private static func truncate(_ text: String, toWidth width: Double, font: CTFont) -> String {
        guard width > 0, !text.isEmpty else { return "" }
        if measure(text, font: font) <= width { return text }
        var candidate = text
        while !candidate.isEmpty, measure(candidate + "…", font: font) > width {
            candidate.removeLast()
        }
        return candidate.isEmpty ? "" : candidate + "…"
    }

    private static func measure(_ text: String, font: CTFont) -> Double {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]))
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}

/// Why a report could not be produced.
public enum PrintReportPDFError: Error, CustomStringConvertible {
    case couldNotCreateDocument

    public var description: String {
        switch self {
        case .couldNotCreateDocument:
            return "The PDF document could not be created."
        }
    }
}

// MARK: - Reports

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension PrintReportPDF {

    /// Formats a date the way both reports date their rows.
    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// The width left for the final column once the fixed ones are placed, so
    /// the detail column runs to the right margin instead of stopping short.
    static func remainingWidth(after fixed: [Column]) -> Double {
        let used = fixed.reduce(0) { $0 + $1.width }
        return pageSize.width - (margin * 2) - used
    }

    /// The print job history as a PDF report.
    public static func historyReport(_ entries: [PrintJobHistoryEntry]) throws -> Data {
        let fixed = [
            Column(title: "Date", width: 106),
            Column(title: "Printer", width: 104),
            Column(title: "Result", width: 48),
            Column(title: "Images", width: 44),
            Column(title: "Films", width: 40),
            Column(title: "Layout", width: 48)
        ]
        let columns = fixed + [Column(title: "Detail", width: remainingWidth(after: fixed))]
        let rows = entries.map { entry -> [String] in
            let copies = entry.copies > 1 ? " ×\(entry.copies)" : ""
            // The failure reason is what a reader of this report is looking
            // for; a successful job shows the UIDs that prove it printed.
            let detail = entry.errorMessage
                ?? (entry.printJobUIDs.isEmpty ? "" : entry.printJobUIDs.joined(separator: ", "))
            return [
                timestamp(entry.date),
                entry.printerName,
                entry.success ? "Printed" : "Failed",
                "\(entry.imageCount)",
                "\(entry.filmCount)\(copies)",
                entry.layout,
                detail
            ]
        }
        return try render(
            title: "DICOM Print — Job History",
            subtitle: "\(entries.count) job(s) · generated \(timestamp(Date()))",
            columns: columns,
            rows: rows
        )
    }

    /// The audit trail as a PDF report.
    public static func auditReport(_ events: [PrintAuditEvent]) throws -> Data {
        let fixed = [
            Column(title: "Date", width: 106),
            Column(title: "Action", width: 104),
            Column(title: "Printer", width: 96)
        ]
        let columns = fixed + [Column(title: "Detail", width: remainingWidth(after: fixed))]
        let rows = events.map { event in
            [
                timestamp(event.date),
                event.action.displayName,
                event.printerName ?? "—",
                event.detail
            ]
        }
        return try render(
            title: "DICOM Print — Audit Trail",
            subtitle: "\(events.count) event(s) · generated \(timestamp(Date()))",
            columns: columns,
            rows: rows
        )
    }
}
#endif
