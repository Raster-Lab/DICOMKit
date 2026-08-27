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
import DICOMRenderKit
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerTileGridView<FocusedContent: View>: View {
    @Bindable var viewModel: ImageViewerViewModel

    /// The live viewer, shown in whichever tile has focus.
    @ViewBuilder let focusedContent: () -> FocusedContent

    #if canImport(CoreGraphics)
    @State private var tileImages = ViewerTileImageCache()
    #endif

    #if canImport(Metal)
    /// GPU textures for the unfocused tiles, when this machine has Metal.
    ///
    /// Kept alongside the image cache rather than replacing it: a tile whose frame
    /// cannot go on the GPU — overlay planes, an unresolvable window — still needs
    /// a picture, and that is the CPU image it has always had.
    @State private var tileTextures = ViewerTileTextureCache()

    /// Drawn text and arrows for the unfocused tiles. The focused tile draws
    /// its own through the live viewer; without this, an annotated image lost
    /// its arrows the moment focus moved to another tile.
    @State private var tileAnnotationTextures = ViewerTileAnnotationTextureCache()
    #endif

    /// Tile a series card is currently hovering over, for the drop highlight.
    @State private var dropTargetIndex: Int?

    /// Corner annotations for the files the unfocused tiles are showing.
    @State private var overlayTexts = ViewerAnnotationTextCache()

    /// Turns scroll events into whole image steps — one per wheel notch.
    @State private var scrollSteps = ScrollStepAccumulator()

    /// Where the pointer is inside the tile it is over, and which tile that is.
    @State private var hoverPoint: CGPoint?
    @State private var hoveredIndex: Int?

    /// The tile whose saved-views list is open, if any.
    ///
    /// One index rather than a flag per tile: only one list can be open at a
    /// time, and holding the *tile* it belongs to is what lets the popover be
    /// anchored to the badge that was clicked rather than to the grid.
    @State private var savedViewListTile: Int?

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
        // A list belongs to the image the tile was showing when it opened. Re-hang
        // the tiles or change the layout and that image may be gone or somewhere
        // else, so the list goes with it rather than applying a view to whatever
        // took its place.
        .onChange(of: viewModel.layout) { _, _ in savedViewListTile = nil }
        .onChange(of: overlayPaths) { _, _ in savedViewListTile = nil }
        #if canImport(CoreGraphics)
        .onAppear { refreshTiles() }
        .onChange(of: viewModel.cells) { _, _ in
            refreshTiles()
        }
        .onChange(of: viewModel.focusedCellIndex) { _, _ in
            // The tile losing focus becomes a still, so it needs rendering now.
            viewModel.captureFocusedCell()
            refreshTiles()
        }
        // A texture arriving — or turning out to be impossible — moves a tile
        // between the two paths, and the loser of that move releases its copy.
        .onChange(of: cellsNeedingCPUImage) { _, cells in
            tileImages.refresh(for: cells)
        }
        #endif
    }

    /// Files the unfocused tiles are showing, for the overlay-text cache.
    private var overlayPaths: [String] {
        viewModel.cells
            .filter { $0.index != viewModel.focusedCellIndex && !$0.isEmpty }
            .compactMap(\.filePath)
    }

    /// The annotation text for a tile.
    ///
    /// The focused tile is the file the view model has loaded, so its text is
    /// already to hand; every other tile is read once and cached.
    private func overlayText(for cell: ViewerCellState) -> ViewerAnnotationText? {
        if cell.index == viewModel.focusedCellIndex {
            return viewModel.annotationText
        }
        guard let path = cell.filePath else { return nil }
        return overlayTexts.text(forPath: path)
    }

    /// What a tile is doing with its file, for the annotation corners.
    ///
    /// The focused tile is asked of the *view model*, not of its stored
    /// ``ViewerCellState``. The cell is only written back by
    /// ``ImageViewerViewModel/captureFocusedCell()``, which runs when focus
    /// moves, a layout is applied or a tile is marked — never on navigation. So
    /// a reader scrolling the focused tile advanced `currentFileIndex` while the
    /// cell kept the index it was hung at, and the "Im:" line sat at 1/33 for
    /// the whole stack even as the picture and every other annotation line —
    /// which come from the live ``annotationText`` — changed underneath it.
    /// Reading the live state here means the number is derived from the same
    /// place the image is, and cannot lag behind it.
    ///
    /// The unfocused tiles keep reading their cell: they are not being
    /// navigated, and their cell *is* where they got to.
    private func viewportState(for cell: ViewerCellState) -> ViewerAnnotationViewportState {
        if cell.index == viewModel.focusedCellIndex {
            return viewModel.annotationViewportState(
                viewSize: CGSize(width: cell.viewportWidth, height: cell.viewportHeight),
                cursor: cursorReadout(for: cell))
        }
        return viewModel.annotationViewportState(for: cell, cursor: cursorReadout(for: cell))
    }

    /// The pixel under the pointer, for the tile it is over.
    ///
    /// The focused tile only: it is the one the view model has decoded pixels
    /// for, and a value read from a file the viewer has not opened would mean
    /// decoding a second image on the hover path. Clicking a tile focuses it,
    /// which is the same gesture that arms every other tool for it.
    private func cursorReadout(for cell: ViewerCellState) -> ViewerCursorReadout? {
        guard cell.index == viewModel.focusedCellIndex,
              hoveredIndex == cell.index,
              let hoverPoint else { return nil }
        return viewModel.cursorReadout(
            atViewPoint: hoverPoint,
            viewSize: CGSize(width: cell.viewportWidth, height: cell.viewportHeight),
            zoom: cell.zoom,
            panX: cell.panX,
            panY: cell.panY)
    }

    /// Tiles that are not the live viewer, and so need a rendered still.
    private var unfocusedCells: [ViewerCellState] {
        viewModel.cells.filter { $0.index != viewModel.focusedCellIndex && !$0.isEmpty }
    }

    #if canImport(CoreGraphics)
    /// Tiles that still need a CPU image: the ones the GPU is not already drawing.
    ///
    /// A tile with a texture is deliberately excluded, and so is dropped from the
    /// image cache. That is what makes a tool drag free on this path — the CPU key
    /// includes the arrangement, so leaving a GPU-drawn tile in that cache would
    /// re-render on every mouse delta the shader was about to handle for nothing.
    private var cellsNeedingCPUImage: [ViewerCellState] {
        #if canImport(Metal)
        guard ViewerTileTextureCache.isAvailable else { return unfocusedCells }
        return unfocusedCells.filter { tileTextures.texture(for: $0) == nil }
        #else
        return unfocusedCells
        #endif
    }

    /// Brings both tile caches up to date with what the grid is showing.
    private func refreshTiles() {
        #if canImport(Metal)
        tileTextures.refresh(for: unfocusedCells)
        #endif
        tileImages.refresh(for: cellsNeedingCPUImage)
    }
    #endif

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
        // The tick, down the middle of the right edge rather than in the
        // top-right corner — the same move as the single-image view, for the
        // same reason: that corner belongs to the identification block, and a
        // control standing in it forces the text to start below whatever is
        // showing. The middle of the edge is empty in the four-corner scheme.
        .overlay(alignment: .trailing) {
            if let cell, !cell.isEmpty {
                // The tick, and under it the saved-views badge when this tile's
                // image has presentation states. The 1x1 viewport has carried
                // that badge since saved views existed; a tile did not, so a
                // reader who split the screen lost the only on-image sign that
                // an image had a saved view at all — and the grid is exactly
                // where they are comparing an image against its saved version.
                //
                // Stacked in the same column as the single-image view, in the
                // same order, so the two screens do not disagree about where
                // this image's controls are.
                VStack(alignment: .trailing, spacing: 4) {
                    tileCheckbox(index: index)
                    if let count = savedViewCount(for: cell), count > 0 {
                        tileSavedViewsBadge(count: count, index: index)
                    }
                }
                .padding(4)
                // The arrow over the controls, in place of the armed tool's
                // glyph. The viewer's tool cursor covers the whole reading area
                // — tiles included — and a tick that offers the windowing sun
                // is telling the reader to drag where they should click.
                #if os(macOS)
                .arrowPointer()
                #endif
            }
        }
        // Where this tile lands on the film, in the corner opposite its tick.
        // A grid of twenty tiles all wearing the same small check answered "is
        // this one on the film?" only if you looked at each in turn; a lit,
        // numbered chip answers it — and the running order — across the whole
        // grid at once.
        .overlay(alignment: .topLeading) {
            if let position = viewModel.printPositionForCell(index) {
                filmPositionChip(position)
                    .padding(4)
            }
        }
        // No third mark for "on the film". A marked tile used to carry an accent
        // edge along its bottom as well as the chip and the tick — three cues for
        // one fact, and on a grid where everything is marked (which is the normal
        // way a film gets composed) it drew a blue rule under every tile. The only
        // accent *edge* in the grid is now the focus ring, so the lit tile is the
        // one being worked on; whether a tile is on the film is the chip in one
        // corner and the tick in the other.
        // Reading annotations in this tile's corners, sized to the tile rather
        // than to the viewer: a 4×4 tile carries small type and only the lines
        // that matter at that size, a 1×2 tile carries the block in full. The
        // text is this tile's own file, not the focused one — two studies can
        // hang side by side, and a tile naming the wrong patient is worse than
        // no label at all.
        .overlay {
            if let cell, !cell.isEmpty, viewModel.showImageAnnotations,
               let text = overlayText(for: cell), !text.isEmpty {
                // Measured here rather than read from the cell. The block picks
                // how much to say from the size of the tile it is drawn in, and
                // the stored viewport is still zero on the pass a fresh grid
                // first draws — the geometry reader that fills it has not run
                // yet. A zero read as the smallest tile there is, so every
                // unfocused tile came up `.minimal`, without its patient and
                // study lines, while the focused tile — which reads the live
                // viewer's own size — was labelled in full. That is the "only
                // the first image shows patient and study data" the reader sees,
                // and why choosing the same layout a second time appears to fix
                // it: by then the cells carry the sizes the first pass recorded.
                // An overlay's geometry reader is handed the host's bounds
                // during that same first layout, so the size is right the first
                // time and the cell viewport goes back to being purely what it
                // was for — resolving a tile's zoom and pan to a crop.
                GeometryReader { geo in
                    let measured = geo.size.width >= 1 && geo.size.height >= 1
                        ? geo.size
                        : CGSize(width: cell.viewportWidth, height: cell.viewportHeight)
                    ViewerAnnotationOverlayView(
                        text: text,
                        state: viewportState(for: cell),
                        cellSize: measured,
                        // No top-trailing inset: the print tick has left that
                        // corner for the middle of the right edge.
                        //
                        // The film chip still holds the top-left, and its room is
                        // reserved on every tile rather than only on the tiles
                        // that currently wear one. The inset used to be
                        // conditional, so ticking a tile for print shifted its
                        // identification text down while its neighbours' stayed
                        // put — the same unevenness across the grid that the
                        // checkbox caused down the side, and worse here because
                        // marking tiles is what composing a film *is*.
                        topLeadingInset: Self.filmChipInset,
                        showOrientation: viewModel.showOrientationLabels,
                        // The tick — and now the saved-views badge under it — sit
                        // at the middle of this tile's right edge, which is where
                        // the right-hand orientation letter is centred. Same fix
                        // as the 1x1 viewport: the letter moves in, because a
                        // covered "L" is read as an unchecked one.
                        trailingControlsInset: Self.trailingControlsInset
                    )
                }
            }
        }
        .overlay {
            // A focus ring, not a selection highlight: it marks where gestures
            // and window/level will land. A drop target outranks it — during a
            // drag the question is "where will this land", not "what is focused".
            // Hovering brightens the hairline, so the tile a click would take
            // answers before the click.
            let isDropTarget = dropTargetIndex == index
            let isHovered = hoveredIndex == index
            Rectangle()
                .strokeBorder(
                    isDropTarget || isFocused ? Color.accentColor
                        : .white.opacity(isHovered ? 0.35 : 0.12),
                    lineWidth: isDropTarget ? 3 : (isFocused ? Self.focusRingWidth : 1))
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
        // The pointer, for the focused tile's pixel readout. Tracked on every
        // tile so the readout disappears the moment the pointer leaves the one
        // it belongs to, rather than freezing on the last pixel it was over.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point):
                hoverPoint = point
                hoveredIndex = index
            case .ended:
                if hoveredIndex == index {
                    hoverPoint = nil
                    hoveredIndex = nil
                }
            }
        }
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
        #if canImport(Metal)
        if let texture = tileTextures.texture(for: cell) {
            // The GPU tile path. Zoom, pan, rotation, flip and inversion are the
            // shader's transform here, exactly as in the focused viewport — which
            // is what lets a synchronised tool move redraw a quad per tile instead
            // of re-decoding the grid. `.fit` is the shader's zoom 1.0, so a tile
            // frames its image the same way it did on the CPU path.
            MetalImageView(frame: texture, presentation: cell.displayPresentation,
                           annotationOverlay: annotationOverlay(for: cell, frame: texture))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            tileCPUImage(cell)
        }
        #else
        tileCPUImage(cell)
        #endif
    }

    #if canImport(Metal)
    /// The drawn annotations of a tile's image, as the overlay texture the
    /// shader composites — the same store and rasterizer the focused viewport
    /// and the film use, so a tile shows exactly what will print.
    private func annotationOverlay(
        for cell: ViewerCellState, frame: DisplayFrameTexture
    ) -> AnnotationOverlayTexture? {
        guard let filePath = cell.filePath,
              let device = MetalRenderDevice.shared?.device else { return nil }
        let key = ImageAnnotationKey(filePath: filePath, frameIndex: cell.frameIndex)
        // The tile's own turn and mirrors, so its lettering is rasterized level
        // — see `ImageViewerView.annotationOrientation` for why the crop is
        // left out.
        let orientation = PrintOverlayOrientation(
            presentation: ViewerPresentation(
                rotationDegrees: cell.rotationAngle,
                flipHorizontal: cell.isFlippedHorizontal,
                flipVertical: cell.isFlippedVertical),
            imageWidth: frame.width,
            imageHeight: frame.height)
        return tileAnnotationTextures.texture(
            for: key,
            overlays: viewModel.printSelection.cellAnnotations[key] ?? [],
            width: frame.width, height: frame.height, device: device,
            orientation: orientation)
    }
    #endif

    /// A tile drawn from a CPU-rendered still — the fallback, and the only path on
    /// a machine without Metal.
    @ViewBuilder
    private func tileCPUImage(_ cell: ViewerCellState) -> some View {
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

    /// Room the film-position chip takes in the top-left corner, which the
    /// identification block starts below.
    ///
    /// Reserved on every tile, marked or not, so a tile's text does not move
    /// when it is ticked for print. The tick itself no longer needs an inset:
    /// it sits at the middle of the right edge, clear of all four corners.
    private static var filmChipInset: CGFloat { 26 }

    /// Room the right-edge controls take, which the orientation letter beside
    /// them starts inside of. Narrower than the 1x1 viewport's, because a
    /// tile's tick is the bare glyph rather than the labelled capsule.
    private static var trailingControlsInset: CGFloat { 34 }

    /// Width of the ring around the live tile. Three points rather than two: a
    /// 4×5 grid puts twenty edges on screen, and the one that matters has to win
    /// against nineteen others from a normal seating distance.
    private static var focusRingWidth: CGFloat { 3 }

    /// Where a marked tile lands on the film.
    ///
    /// Numbered, not merely lit: film order is the other half of the question,
    /// and the tray on the right lists the same numbers, so a tile and its row
    /// can be matched without counting either of them.
    private func filmPositionChip(_ position: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "printer.fill")
                .font(.system(size: 8))
            Text("\(position)")
                .font(.caption2.monospacedDigit().bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.accentColor, in: Capsule())
        // The tiles are black and the accent is a mid blue: a hairline keeps the
        // chip's shape when it happens to sit over bone rather than over air.
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel("On film at position \(position)")
    }

    /// How many saved views cover this tile's image, or `nil` when the
    /// question cannot be answered yet.
    ///
    /// The focused tile is the image the view model has loaded, so it answers
    /// from the same accessor the 1x1 viewport's badge uses. Every other tile
    /// is answered from its cached header — the SOP Instance UID read once when
    /// the tile's corner annotations were read — against the same store. A tile
    /// whose header has not arrived yet simply has no badge for a moment, which
    /// is the same way its corner text behaves.
    private func savedViewCount(for cell: ViewerCellState) -> Int? {
        if cell.index == viewModel.focusedCellIndex {
            return viewModel.savedViewsForCurrentImage.count
        }
        guard let studyInstanceUID = viewModel.studyInstanceUID,
              let store = viewModel.presentationStateStore,
              let sopInstanceUID = overlayText(for: cell)?.sopInstanceUID
        else { return nil }
        return store.views(forStudy: studyInstanceUID, image: sopInstanceUID).count
    }

    /// The saved-views badge on a tile.
    ///
    /// Same promise as the 1x1 viewport's badge: the image's first PR is
    /// applied automatically when it is hung (see `offerSavedViewsIfNeeded`),
    /// and clicking opens the list, where one click applies another view or
    /// the default.
    ///
    /// Applying is the *focused* tile's operation — it moves that tile's
    /// window, zoom and rotation — so the badge focuses its own tile first,
    /// synchronously, and opens the list second. By the time the list is built
    /// this tile is the focused one, so `savedViewsForCurrentImage` and
    /// `applySavedView` both answer for the image whose badge was clicked.
    private func tileSavedViewsBadge(count: Int, index: Int) -> some View {
        Button {
            viewModel.focusCell(index)
            savedViewListTile = savedViewListTile == index ? nil : index
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "slider.horizontal.below.rectangle")
                    .font(.system(size: 8, weight: .bold))
                Text("\(count)")
                    .font(.caption2.monospacedDigit().bold())
            }
            // The purple that says "presentation state" everywhere else in the
            // app — the toolbar picker, the series-pane badge, the 1x1
            // viewport's own badge.
            .foregroundStyle(Color.purple)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.45), in: Capsule())
        }
        .buttonStyle(.plain)
        .interactiveControl(cornerRadius: 12, horizontal: 2, vertical: 2)
        .popover(isPresented: Binding(
            get: { savedViewListTile == index },
            set: { if !$0 && savedViewListTile == index { savedViewListTile = nil } }
        ), arrowEdge: .bottom) {
            // The same list the 1x1 badge opens, so a reader who has met one
            // recognises the other. Focus has already moved to this tile, so
            // it answers for the image whose badge was clicked.
            ViewerImageSavedViewList(viewModel: viewModel) {
                savedViewListTile = nil
            }
        }
        .accessibilityLabel("Tile \(index + 1) has \(count) saved views")
        .help(count == 1
              ? "This image has 1 saved view, applied when the image was hung — click to list it and the default view"
              : "This image has \(count) saved views; the first was applied when the image was hung — click to list and apply another")
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
        .interactiveControl(cornerRadius: 13, horizontal: 2, vertical: 2)
        .accessibilityLabel(isMarked
                            ? "Unmark tile \(index + 1) for print"
                            : "Mark tile \(index + 1) for print")
        .help(isMarked ? "Marked for print — click to unmark" : "Mark this tile for print")
    }
}
#endif
