// FilmPreviewView.swift
// DICOMStudio
//
// DICOM Studio — what the film will actually look like.
//
// The preview exists to make spillover obvious: images beyond one layout's
// cells land on additional films, and the count is easy to get wrong when the
// layout is chosen by hand.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmPreviewView: View {
    let plan: PrintPlan
    let items: [PrintSelectionItem]

    #if canImport(CoreGraphics)
    /// Thumbnails of the marked frames. Owned here so the preview is
    /// self-contained, and keyed by mark so changing the layout — which
    /// re-renders this view constantly — never re-decodes a frame.
    @State private var thumbnails = PrintThumbnailCache()
    #endif

    var body: some View {
        VStack(spacing: 10) {
            if plan.filmCount == 0 {
                ContentUnavailableView(
                    "Nothing marked",
                    systemImage: "square.dashed",
                    description: Text("Mark images in the viewer to place them on film.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // The film is sized from the space actually available rather
                // than a fixed thumbnail size, so the preview reads as a sheet
                // of film instead of a row of stamps.
                GeometryReader { geo in
                    let sheetHeight = max(Self.minimumSheetHeight,
                                          geo.size.height - Self.captionAllowance)
                    let sheetWidth = sheetHeight * sheetAspect

                    ScrollView(.horizontal, showsIndicators: plan.filmCount > 1) {
                        HStack(alignment: .center, spacing: 20) {
                            ForEach(0..<plan.filmCount, id: \.self) { filmIndex in
                                filmSheet(filmIndex: filmIndex,
                                          width: sheetWidth, height: sheetHeight)
                            }
                        }
                        .padding(.horizontal, 4)
                        // Centres a single film instead of pinning it left.
                        .frame(minWidth: geo.size.width)
                        .frame(height: geo.size.height)
                    }
                }
            }

            Text(PrintConsoleFormatter.planSummary(plan))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Film plan: \(PrintConsoleFormatter.planSummary(plan))")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if canImport(CoreGraphics)
        .onAppear { thumbnails.refresh(for: items) }
        .onChange(of: items) { _, newItems in thumbnails.refresh(for: newItems) }
        #endif
    }

    // MARK: - One film

    @ViewBuilder
    private func filmSheet(filmIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let range = plan.imageIndices(onFilm: filmIndex)
        VStack(spacing: 6) {
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<plan.layout.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<plan.layout.columns, id: \.self) { column in
                            cell(filmIndex: filmIndex, row: row, column: column, range: range)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
            )
            .frame(width: width, height: height)

            // Only worth naming when there is more than one film to tell apart.
            if plan.filmCount > 1 {
                Text("Film \(filmIndex + 1) of \(plan.filmCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Film \(filmIndex + 1) of \(plan.filmCount), "
            + "\(range.count) of \(plan.cellsPerFilm) cells filled")
    }

    @ViewBuilder
    private func cell(filmIndex: Int, row: Int, column: Int, range: Range<Int>) -> some View {
        let cellIndex = row * plan.layout.columns + column
        let itemIndex = range.lowerBound + cellIndex
        let isFilled = itemIndex < range.upperBound
        let item = items.indices.contains(itemIndex) ? items[itemIndex] : nil

        // Nothing is drawn over the image: the cell shows the frame and only the
        // frame, so the preview is judged the way the film will be. Position and
        // labels live in the marks list beside it, and in the accessibility
        // label here.
        RoundedRectangle(cornerRadius: 2)
            .fill(isFilled ? Color.black : Color.white.opacity(0.05))
            .overlay {
                if isFilled {
                    cellImage(item)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .accessibilityLabel(
                isFilled
                ? "Cell \(itemIndex + 1): \(item?.displayLabel ?? "image")"
                : "Empty cell")
    }

    /// The marked frame itself, or a placeholder while it loads or if it cannot
    /// be rendered.
    @ViewBuilder
    private func cellImage(_ item: PrintSelectionItem?) -> some View {
        #if canImport(CoreGraphics)
        if let item, let image = thumbnails.image(for: item) {
            Image(decorative: image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let item, thumbnails.didFail(item) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            ProgressView()
                .controlSize(.mini)
        }
        #else
        Color.gray.opacity(0.35)
        #endif
    }

    // MARK: - Geometry

    /// Width over height. Portrait films are taller than wide; landscape swaps it.
    private var sheetAspect: CGFloat {
        plan.filmOrientation == .portrait ? 3.0 / 4.0 : 4.0 / 3.0
    }

    /// Room reserved under the film for the plan summary and film caption.
    private static let captionAllowance: CGFloat = 26

    /// Below this the cells stop being readable, so the preview scrolls instead.
    private static let minimumSheetHeight: CGFloat = 160
}
#endif
