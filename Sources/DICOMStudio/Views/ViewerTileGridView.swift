// ViewerTileGridView.swift
// DICOMStudio
//
// DICOM Studio — the viewer's tile grid.
//
// The focused tile hosts the live viewer, so gestures, window/level and cine
// behave exactly as they do at 1×1. Every other tile is a rendered still of its
// own file, frame and arrangement. Each tile carries its own print checkbox, so
// what reaches the film is still only what the user ticked.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerTileGridView<FocusedContent: View>: View {
    @Bindable var viewModel: ImageViewerViewModel

    /// The live viewer, shown in whichever tile has focus.
    @ViewBuilder let focusedContent: () -> FocusedContent

    #if canImport(CoreGraphics)
    @State private var tileImages = ViewerTileImageCache()
    #endif

    /// Tile a series card is currently hovering over, for the drop highlight.
    @State private var dropTargetIndex: Int?

    /// Patient identification for the files the unfocused tiles are showing.
    @State private var overlayTexts = PatientOverlayTextCache()

    /// Turns scroll events into whole image steps — one per wheel notch.
    @State private var scrollSteps = ScrollStepAccumulator()

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<viewModel.layout.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<viewModel.layout.columns, id: \.self) { column in
                        let index = row * viewModel.layout.columns + column
                        tile(at: index)
                    }
                }
            }
        }
        .padding(2)
        .onAppear { overlayTexts.refresh(for: overlayPaths) }
        .onChange(of: overlayPaths) { _, paths in overlayTexts.refresh(for: paths) }
        #if canImport(CoreGraphics)
        .onAppear { tileImages.refresh(for: unfocusedCells) }
        .onChange(of: viewModel.cells) { _, _ in
            tileImages.refresh(for: unfocusedCells)
        }
        .onChange(of: viewModel.focusedCellIndex) { _, _ in
            // The tile losing focus becomes a still, so it needs rendering now.
            viewModel.captureFocusedCell()
            tileImages.refresh(for: unfocusedCells)
        }
        #endif
    }

    /// Files the unfocused tiles are showing, for the overlay-text cache.
    private var overlayPaths: [String] {
        viewModel.cells
            .filter { $0.index != viewModel.focusedCellIndex && !$0.isEmpty }
            .compactMap(\.filePath)
    }

    /// The overlay text for a tile.
    ///
    /// The focused tile is the file the view model has loaded, so its text is
    /// already to hand; every other tile is read once and cached.
    private func overlayText(for cell: ViewerCellState) -> PatientOverlayText? {
        if cell.index == viewModel.focusedCellIndex {
            return viewModel.patientOverlayText
        }
        guard let path = cell.filePath else { return nil }
        return overlayTexts.text(forPath: path)
    }

    /// Tiles that are not the live viewer, and so need a rendered still.
    private var unfocusedCells: [ViewerCellState] {
        viewModel.cells.filter { $0.index != viewModel.focusedCellIndex && !$0.isEmpty }
    }

    // MARK: - One tile

    @ViewBuilder
    private func tile(at index: Int) -> some View {
        let cell = viewModel.cells.indices.contains(index) ? viewModel.cells[index] : nil
        let isFocused = index == viewModel.focusedCellIndex

        ZStack {
            Color.black

            if isFocused {
                focusedContent()
            } else if let cell, !cell.isEmpty {
                tileImage(cell)
            } else {
                Image(systemName: "square.dashed")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
        // Zoom and pan are drawn with `scaleEffect`/`offset`, which do not
        // affect layout — without clipping, a zoomed tile paints over its
        // neighbours. Each tile is its own viewport, so it must clip to itself.
        .clipped()
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if let cell, !cell.isEmpty {
                tileCheckbox(index: index)
                    .padding(4)
            }
        }
        // Patient identification in a band under the picture, sized to this tile
        // rather than the viewer: a 4×4 tile gets small type, a 1×2 tile gets
        // large, and both stay legible without covering anatomy. The text is
        // this tile's own file, not the focused one — two studies can hang side
        // by side, and a tile naming the wrong patient is worse than no label.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let cell, !cell.isEmpty, viewModel.showPatientOverlay,
               let text = overlayText(for: cell), !text.isEmpty {
                PatientIdentificationOverlayView(
                    primaryLine: text.primaryLine,
                    secondaryLine: text.secondaryLine,
                    cellSize: CGSize(width: cell.viewportWidth, height: cell.viewportHeight),
                    style: .band
                )
                .allowsHitTesting(false)
            }
        }
        .overlay {
            // A focus ring, not a selection highlight: it marks where gestures
            // and window/level will land. A drop target outranks it — during a
            // drag the question is "where will this land", not "what is focused".
            let isDropTarget = dropTargetIndex == index
            Rectangle()
                .strokeBorder(
                    isDropTarget ? Color.accentColor
                                 : (isFocused ? Color.accentColor : .white.opacity(0.12)),
                    lineWidth: isDropTarget ? 3 : (isFocused ? 2 : 1))
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewModel.setCellViewport(
                            index, width: geo.size.width, height: geo.size.height)
                    }
                    .onChange(of: geo.size) { _, size in
                        viewModel.setCellViewport(
                            index, width: size.width, height: size.height)
                    }
            }
        )
        .onTapGesture { viewModel.focusCell(index) }
        #if os(macOS)
        // Scrolling a tile steps through its images. The tile takes focus first:
        // navigation belongs to the focused tile, so scrolling an unfocused one
        // would otherwise page the tile the user is not pointing at.
        .background(
            Group {
                if let cell, !cell.isEmpty {
                    ScrollWheelHandler { delta in
                        let steps = scrollSteps.steps(for: delta)
                        guard steps != 0 else { return }
                        if index != viewModel.focusedCellIndex { viewModel.focusCell(index) }
                        for _ in 0..<abs(steps) {
                            if steps > 0 {
                                viewModel.navigateToPreviousImage()
                            } else {
                                viewModel.navigateToNextImage()
                            }
                        }
                    }
                }
            }
        )
        #endif
        // Dropping a series card here hangs that series in this tile.
        .dropDestination(for: String.self) { seriesUIDs, _ in
            guard let uid = seriesUIDs.first else { return false }
            viewModel.focusCell(index)
            return viewModel.assignSeries(uid, toCell: index)
        } isTargeted: { targeted in
            dropTargetIndex = targeted ? index : (dropTargetIndex == index ? nil : dropTargetIndex)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tile \(index + 1)\(isFocused ? ", focused" : "")")
        .accessibilityHint("Drop a series here to show it in this tile")
    }

    @ViewBuilder
    private func tileImage(_ cell: ViewerCellState) -> some View {
        #if canImport(CoreGraphics)
        if let image = tileImages.image(for: cell) {
            // Fills the tile in both directions but never distorts: `.fit`
            // scales up to whichever edge runs out first, which is what makes a
            // portrait CR use the tile's full height and a wide image its full
            // width, with the aspect ratio the modality recorded.
            Image(decorative: image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tileImages.didFail(cell) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        } else {
            ProgressView()
                .controlSize(.small)
        }
        #else
        Color.black
        #endif
    }

    /// Per-tile print checkbox — unticked until the user ticks it.
    private func tileCheckbox(index: Int) -> some View {
        let isMarked = viewModel.isCellMarkedForPrint(index)
        return Button {
            viewModel.togglePrintMarkForCell(index)
        } label: {
            Image(systemName: isMarked ? "checkmark.square.fill" : "square")
                .font(.body)
                .foregroundStyle(isMarked ? Color.accentColor : .white.opacity(0.75))
                .padding(3)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMarked
                            ? "Unmark tile \(index + 1) for print"
                            : "Mark tile \(index + 1) for print")
        .help(isMarked ? "Marked for print — click to unmark" : "Mark this tile for print")
    }
}
#endif
