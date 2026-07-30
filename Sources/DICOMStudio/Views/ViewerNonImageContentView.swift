// ViewerNonImageContentView.swift
// DICOMStudio
//
// DICOM Studio — showing a report, a document, or an object with no pixels.
//
// The centre panel is not only for pictures. A structured report is read as a
// narrative, an encapsulated PDF is read as pages, and anything else at least
// says what it is. Nothing here decodes a file: the content was parsed when the
// instance was loaded, so paging through a series stays as cheap as it is for
// images.

#if canImport(SwiftUI)
import SwiftUI
import DICOMCore
import DICOMKit
#if canImport(PDFKit)
import PDFKit
#endif

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerNonImageContentView: View {
    let content: ViewerNonImageContent

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(Color.white.opacity(0.15))

            // Content the viewer cannot show at all says so first, in place of
            // a summary the reader would otherwise scan looking for the image.
            if let reason = content.kind.cannotDisplayReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: 520, alignment: .leading)
                    .accessibilityLabel("Cannot be displayed: \(reason)")
            }

            switch content {
            case .report(let document):
                StructuredReportNarrativeView(document: document)
            case .document(let document):
                encapsulatedDocument(document)
            case .summary(_, _, let rows):
                summary(rows)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: content.kind.symbolName)
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(content.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(10)
    }

    // MARK: - Encapsulated document

    @ViewBuilder
    private func encapsulatedDocument(_ document: DICOMKit.EncapsulatedDocument) -> some View {
        #if canImport(PDFKit) && os(macOS)
        if document.isPDF, let pdf = PDFDocument(data: document.documentData) {
            PDFDocumentView(document: pdf)
        } else {
            documentPlaceholder(document)
        }
        #else
        documentPlaceholder(document)
        #endif
    }

    /// A document the app cannot render inline — a CDA, an STL, or a PDF whose
    /// bytes will not open. It is still described rather than refused.
    private func documentPlaceholder(_ document: DICOMKit.EncapsulatedDocument) -> some View {
        summary([
            .init(label: "Type",
                  value: ViewerNonImageContent.name(of: document.documentType)),
            .init(label: "MIME type", value: document.mimeType),
            .init(label: "Size",
                  value: EncapsulatedDocumentFormatting.fileSize(Int64(document.documentSize)))
        ])
    }

    // MARK: - Summary

    private func summary(_ rows: [ViewerNonImageContent.Row]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 120, alignment: .trailing)
                        Text(row.value)
                            .font(.callout)
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Structured report

/// An SR content tree, read as a report.
///
/// Indented by depth rather than drawn as a disclosure tree: a report is read
/// top to bottom, and collapsing sections hides findings.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct StructuredReportNarrativeView: View {
    let document: DICOMKit.SRDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                metadata

                Divider().overlay(Color.white.opacity(0.15))

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let name = row.name {
                            Text(name)
                                .font(.callout.weight(row.isContainer ? .bold : .semibold))
                                .foregroundStyle(.white.opacity(row.isContainer ? 1 : 0.7))
                        }
                        if let value = row.value {
                            Text(value)
                                .font(.callout)
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, CGFloat(row.depth) * 16)
                    .padding(.top, row.isContainer ? 6 : 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let flag = document.completionFlag {
                label("Completion", flag.rawValue)
            }
            if let flag = document.verificationFlag {
                label("Verification", flag.rawValue)
            }
            if let date = document.contentDate {
                label("Content date", DICOMValueParser.formatDate(date))
            }
            label("Content items", "\(document.contentItemCount)")
        }
    }

    private func label(_ name: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// One line of the report.
    private struct Row {
        let depth: Int
        let name: String?
        let value: String?
        let isContainer: Bool
    }

    private var rows: [Row] {
        var result: [Row] = []
        append(container: document.rootContent, depth: 0, into: &result)
        return result
    }

    private func append(container: ContainerContentItem, depth: Int, into rows: inout [Row]) {
        for item in container.contentItems {
            let name = item.conceptName?.codeMeaning
            if let nested = item.asContainer {
                rows.append(Row(depth: depth, name: name ?? "Section",
                                value: nil, isContainer: true))
                append(container: nested, depth: depth + 1, into: &rows)
            } else {
                rows.append(Row(depth: depth,
                                name: name.map { "\($0):" },
                                value: Self.value(of: item),
                                isContainer: false))
            }
        }
    }

    /// The item's value as a reader would say it aloud.
    static func value(of item: AnyContentItem) -> String? {
        if let text = item.asText { return text.textValue }
        if let code = item.asCode { return code.conceptCode.codeMeaning }
        if let numeric = item.asNumeric {
            let numbers = numeric.numericValues.map { number -> String in
                number == number.rounded() && abs(number) < 1e15
                    ? String(Int(number)) : String(number)
            }.joined(separator: ", ")
            if let units = numeric.measurementUnits?.codeMeaning, !units.isEmpty {
                return "\(numbers) \(units)"
            }
            return numbers
        }
        if let date = item.asDate { return DICOMValueParser.formatDate(date.dateValue) }
        if let time = item.asTime { return DICOMValueParser.formatTime(time.timeValue) }
        if let dateTime = item.asDateTime {
            return DICOMValueParser.formatDateTime(dateTime.dateTimeValue)
        }
        if let name = item.asPersonName {
            return DICOMValueParser.formatPersonName(name.personName)
        }
        if item.asImage != nil { return "(referenced image)" }
        if item.asWaveform != nil { return "(referenced waveform)" }
        if item.isCoordinate { return "(coordinates)" }
        if item.asComposite != nil { return "(referenced object)" }
        if let uid = item.asUIDRef { return uid.uidValue }
        return nil
    }
}

// MARK: - PDF

#if canImport(PDFKit) && os(macOS)
/// PDFKit's own view, which brings scrolling, zooming and text selection with it.
@available(macOS 14.0, *)
struct PDFDocumentView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .black
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}
#endif
#endif
