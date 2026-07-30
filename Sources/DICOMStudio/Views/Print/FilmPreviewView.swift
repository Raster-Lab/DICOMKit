// FilmPreviewView.swift
// DICOMStudio
//
// DICOM Studio — what the film will actually look like, and where it is fixed.
//
// The preview exists to make spillover obvious: images beyond one layout's
// cells land on additional films, and the count is easy to get wrong when the
// layout is chosen by hand.
//
// It is also where a cell is adjusted. Clicking a cell focuses it; dragging runs
// the selected tool over it — window/level, zoom or pan. Every edit is written
// back into the mark, which is what the print path reads, so a cell that looks
// right here prints that way. What is rendered is ``PrintViewModel/previewItems``
// rather than the raw marks: job-wide settings (an explicit window, raw pixels)
// override a mark's own arrangement, and a preview ignoring that would lie.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmPreviewView: View {
    @Bindable var viewModel: PrintViewModel

    #if canImport(CoreGraphics)
    /// Thumbnails of the marked frames. Owned here so the preview is
    /// self-contained, and keyed by mark so changing the layout — which
    /// re-renders this view constantly — never re-decodes a frame.
    @State private var thumbnails = PrintThumbnailCache()
    #endif

    /// Live drag state, so a gesture applies deltas rather than absolutes.
    @State private var dragAnchor: CGSize = .zero

    /// The arrow being dragged out right now, if any.
    @State private var draftArrowID: UUID?

    /// The film on screen. One film is shown at a time and paged through, so the
    /// sheet being judged is drawn as large as the panel allows — a row of films
    /// side by side makes every one of them too small to judge.
    @State private var visibleFilm: Int = 0

    /// Patient identification for the marked files, for the annotation toggle.
    @State private var overlayTexts = PatientOverlayTextCache()

    private var plan: PrintPlan { viewModel.plan }
    private var items: [PrintSelectionItem] { viewModel.previewItems }

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
                HStack(spacing: 6) {
                    toolRail
                    filmStrip
                        // The film takes focus so the arrow keys walk cells and
                        // the tool shortcuts land here rather than in whatever
                        // text field was last touched.
                        .focusable()
                        .focusEffectDisabled()
                        // One handler for every key rather than one per key: the
                        // arrows mean two different things depending on ⌥, and
                        // separate per-key handlers cannot tell them apart — both
                        // would fire and the page would fight the focus.
                        .onKeyPress(phases: .down) { press in handleKeyPress(press) }
                }
            }

            // The plan summary is in the sheet's header; repeating it here cost
            // the film a line of height it can use for the picture.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { refreshOverlayTexts() }
        .onChange(of: viewModel.showPatientIdentification) { _, _ in refreshOverlayTexts() }
        // A film that no longer exists must not stay on screen: changing the
        // layout or clearing marks can drop the film being looked at.
        .onChange(of: plan.filmCount) { _, count in
            visibleFilm = min(visibleFilm, max(0, count - 1))
        }
        // Walking cells with the arrow keys runs off the end of a film, so the
        // page follows the focus rather than making the reader page by hand.
        .onChange(of: viewModel.focusedItemID) { _, _ in showFilmOfFocusedCell() }
        #if canImport(CoreGraphics)
        .onAppear { thumbnails.refresh(for: items) }
        .onChange(of: items) { _, newItems in
            thumbnails.refresh(for: newItems)
            viewModel.pruneFocus()
            // Annotations belong to marks; a mark that has been taken off the film
            // must not leave its arrows behind to reappear on a later one.
            viewModel.pruneAnnotations()
            refreshOverlayTexts()
        }
        #endif
    }

    private var filmStrip: some View {
        // The film is sized from the space actually available rather than a
        // fixed thumbnail size, so the preview reads as a sheet of film instead
        // of a row of stamps.
        GeometryReader { geo in
            // The sheet takes whichever of the two dimensions runs out first, so
            // the film fills the space it has been given in *both* directions
            // instead of being sized by height alone and leaving the width empty.
            let availableHeight = geo.size.height - captionAllowance
            let availableWidth = max(0, geo.size.width - Self.sideAllowance - pagingAllowance)
            let fitted = min(availableHeight, availableWidth / max(sheetAspect, 0.01))
            let sheetHeight = max(Self.minimumSheetHeight, fitted)
            let sheetWidth = sheetHeight * sheetAspect

            HStack(spacing: 0) {
                pagingButton(step: -1, symbol: "chevron.left")
                filmSheet(filmIndex: currentFilm, width: sheetWidth, height: sheetHeight)
                    .frame(maxWidth: .infinity)
                pagingButton(step: 1, symbol: "chevron.right")
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The film currently on screen, clamped to the plan — the count can shrink
    /// under us between a page turn and the next redraw.
    private var currentFilm: Int {
        min(max(0, visibleFilm), max(0, plan.filmCount - 1))
    }

    /// One page turn: an arrow either side of the film, disabled at the ends.
    ///
    /// Reserved even for a single film so the sheet does not shift sideways when
    /// a second film appears; it is simply invisible and takes no clicks.
    @ViewBuilder
    private func pagingButton(step: Int, symbol: String) -> some View {
        let isEnabled = canTurnPage(by: step)
        Button {
            turnPage(by: step)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: Self.pagingButtonWidth, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.3))
        .disabled(!isEnabled)
        .opacity(plan.filmCount > 1 ? 1 : 0)
        .accessibilityLabel(step < 0 ? "Previous film" : "Next film")
        .help(step < 0 ? "Previous film (⌥←)" : "Next film (⌥→)")
    }

    private func canTurnPage(by step: Int) -> Bool {
        let target = currentFilm + step
        return plan.filmCount > 1 && target >= 0 && target < plan.filmCount
    }

    /// Turns to the next or previous film, if there is one.
    @discardableResult
    private func turnPage(by step: Int) -> Bool {
        guard canTurnPage(by: step) else { return false }
        let target = currentFilm + step
        visibleFilm = target
        // The focus belongs to a cell on the film that was showing, and a ring on
        // a film nobody can see is a lie about what the next drag will hit.
        if let focusedID = viewModel.focusedItemID, film(ofItemID: focusedID) != target {
            viewModel.focusCell(nil)
        }
        return true
    }

    /// Which film a mark sits on, by its position in film order.
    private func film(ofItemID itemID: String) -> Int? {
        guard let index = viewModel.selection.items.firstIndex(where: { $0.id == itemID }),
              plan.cellsPerFilm > 0 else { return nil }
        return index / plan.cellsPerFilm
    }

    /// Brings the film holding the focused cell on screen.
    private func showFilmOfFocusedCell() {
        guard let focusedID = viewModel.focusedItemID,
              let film = film(ofItemID: focusedID), film != visibleFilm else { return }
        visibleFilm = film
    }

    /// Reads identification for the marked files, and only while it is shown —
    /// a hundred header reads for an overlay nobody asked for is not worth it.
    private func refreshOverlayTexts() {
        overlayTexts.refresh(
            for: viewModel.showPatientIdentification ? items.map(\.filePath) : [])
    }

    /// The film's own keys: arrows walk cells, ⌥-arrows turn the page, esc lets
    /// the cell go. Everything else is left for the tool buttons' own shortcuts.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let key = press.key.character
        let isOption = press.modifiers.contains(.option)

        switch key {
        case KeyEquivalent.leftArrow.character:
            if isOption { return turnPage(by: -1) ? .handled : .ignored }
            return moveFocus(by: -1) ? .handled : .ignored
        case KeyEquivalent.rightArrow.character:
            if isOption { return turnPage(by: 1) ? .handled : .ignored }
            return moveFocus(by: 1) ? .handled : .ignored
        case KeyEquivalent.upArrow.character:
            return moveFocus(by: -plan.layout.columns) ? .handled : .ignored
        case KeyEquivalent.downArrow.character:
            return moveFocus(by: plan.layout.columns) ? .handled : .ignored
        case KeyEquivalent.delete.character:
            // Deleting removes what is selected, and only that: the marks
            // themselves are taken off the film in the images list, not by
            // pressing delete over a picture.
            return viewModel.removeSelectedAnnotation() ? .handled : .ignored
        case KeyEquivalent.escape.character:
            // The annotation first, then the cell — esc lets go of one thing at a
            // time, innermost first, as it does everywhere else.
            if viewModel.selectedAnnotationID != nil {
                viewModel.selectAnnotation(nil)
                return .handled
            }
            guard viewModel.focusedItemID != nil else { return .ignored }
            viewModel.focusCell(nil)
            return .handled
        default:
            return .ignored
        }
    }

    /// Moves the focus along the film by a number of cells.
    ///
    /// Cells are film order, so ±1 steps along a row and ±columns steps down a
    /// column, across film boundaries — which is how the marks are ordered
    /// anyway. Nothing focused yet means "start at the first cell".
    @discardableResult
    private func moveFocus(by offset: Int) -> Bool {
        let all = viewModel.selection.items
        guard !all.isEmpty else { return false }
        guard let focusedID = viewModel.focusedItemID,
              let current = all.firstIndex(where: { $0.id == focusedID }) else {
            viewModel.focusCell(all[0].id)
            return true
        }
        let target = current + offset
        guard all.indices.contains(target) else { return false }
        viewModel.focusCell(all[target].id)
        return true
    }

    // MARK: - Tools

    /// The tool a drag on a cell runs, plus the per-cell actions.
    ///
    /// A rail rather than a menu bar: it sits beside the film, where the cell
    /// being adjusted is, and costs the film no height.
    private var toolRail: some View {
        VStack(spacing: 6) {
            ForEach(PrintViewModel.CellTool.allCases) { tool in
                Button {
                    viewModel.cellTool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Self.shortcut(for: tool)), modifiers: [])
                .padding(4)
                .background(
                    viewModel.cellTool == tool ? Color.accentColor.opacity(0.25) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(viewModel.cellTool == tool ? Color.accentColor : .secondary)
                .help("\(tool.displayName) — drag on a film cell (\(Self.shortcut(for: tool)))")
                .accessibilityLabel(tool.displayName)
                .accessibilityAddTraits(viewModel.cellTool == tool ? [.isSelected] : [])
            }

            Divider().frame(width: 24)

            Button {
                viewModel.showPatientIdentification.toggle()
            } label: {
                Image(systemName: "person.text.rectangle").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(
                viewModel.showPatientIdentification ? Color.accentColor.opacity(0.25) : .clear,
                in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(viewModel.showPatientIdentification ? Color.accentColor : .secondary)
            .keyboardShortcut("i", modifiers: [])
            .help("Patient ID caption (I) — the patient, ID and study burned across "
                  + "the bottom of every cell")
            .accessibilityLabel("Patient ID caption")
            .accessibilityAddTraits(viewModel.showPatientIdentification ? [.isSelected] : [])

            // Rotation and inversion of a single cell are not offered here: the
            // film is meant to reproduce what the viewer showed, and arranging a
            // cell differently from the screen it came from is how a film ends up
            // disagreeing with the report written from that screen.

            Button {
                if let id = viewModel.focusedItemID {
                    viewModel.resetCell(forItemID: id)
                }
            } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.focusedItemID == nil)
            .keyboardShortcut("0", modifiers: [])
            .help("Reset the focused cell to the untouched frame (0)")
            .accessibilityLabel("Reset focused cell")

            Spacer()
        }
        .padding(.vertical, 4)
        .frame(width: 34)
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
        .accessibilityElement(children: .contain)
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
        let isFocused = item != nil && item?.id == viewModel.focusedItemID
        // The picture's own area: the cell less whatever the identification strip
        // takes. Zoom, pan and annotations all resolve against this rather than the
        // cell, because this is what actually gets printed.
        let picture = item.map { pictureSize(for: $0, cellSize: focusedCellSize) }
            ?? focusedCellSize

        // Nothing is drawn over the image that the film will not carry: the cell
        // shows the frame, the identification band and the reader's own
        // annotations, all of which are burned in. Position and labels live in the
        // marks list beside it, and in the accessibility label here. The focus
        // ring is chrome around the cell, not over it.
        RoundedRectangle(cornerRadius: 2)
            .fill(isFilled ? Color.black : Color.white.opacity(0.05))
            .overlay {
                if isFilled {
                    cellImage(item)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
            // The reader's own text and arrows, over the picture and under the
            // focus ring. Attached before the identification strip is inset, so
            // this layer covers the picture and not the strip — an annotation
            // belongs to the image, and the strip is not part of the image.
            .overlay {
                if isFilled, let item {
                    FilmCellAnnotationLayer(
                        viewModel: viewModel,
                        itemID: item.id,
                        imageRect: imageRect(for: item, in: picture),
                        isInteractive: viewModel.cellTool.isDrawing
                            || !viewModel.annotations(forItemID: item.id).isEmpty)
                }
            }
            // Identification in its own strip under the picture, as the viewer
            // draws it and as the print run now burns it: text over anatomy is
            // where a finding hides. `safeAreaInset` takes the height from the
            // cell rather than covering it, so the picture above is complete.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isFilled, viewModel.showPatientIdentification, let item,
                   let text = overlayTexts.text(forPath: item.filePath), !text.isEmpty {
                    PatientIdentificationOverlayView(
                        primaryLine: text.primaryLine,
                        secondaryLine: text.secondaryLine,
                        cellSize: focusedCellSize,
                        style: .band)
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { recordCellSize(geo.size) }
                        .onChange(of: geo.size) { _, size in recordCellSize(size) }
                }
            )
            #if os(macOS)
            // Scroll zooms the cell under the cursor, as it does in the viewer.
            // The handler scopes itself to this view in this window, so scrolling
            // the film strip sideways does not zoom whatever is behind it.
            .background(
                Group {
                    if isFilled, let item {
                        ScrollWheelHandler { delta in
                            guard delta.y != 0 else { return }
                            if viewModel.focusedItemID != item.id {
                                viewModel.focusCell(item.id)
                            }
                            // A notch is a fixed zoom step; a trackpad scales
                            // with how far it was actually swiped.
                            let amount = delta.isPrecise ? Double(delta.y) : (delta.y > 0 ? 4 : -4)
                            viewModel.adjustZoom(
                                forItemID: item.id,
                                factor: 1.0 + amount * Self.scrollZoomSensitivity,
                                cellSize: picture)
                        }
                    }
                }
            )
            #endif
            .modifier(CellInteraction(
                enabled: isFilled,
                item: item,
                viewModel: viewModel,
                dragAnchor: $dragAnchor,
                draftArrowID: $draftArrowID,
                cellSize: picture,
                imageRect: item.map { imageRect(for: $0, in: picture) } ?? .zero))
            .accessibilityLabel(
                isFilled
                ? "Cell \(itemIndex + 1): \(item?.displayLabel ?? "image")"
                : "Empty cell")
            .accessibilityAddTraits(isFocused ? [.isSelected] : [])
    }

    /// The size a film cell is drawn at, for edits and overlay type measured in
    /// cell points. The grid is uniform, so one size describes every cell.
    @State private var focusedCellSize: CGSize = CGSize(width: 200, height: 200)

    private func recordCellSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        focusedCellSize = size
    }

    /// Lines of identification this cell will carry, which is what decides how
    /// deep its strip is — one line takes less room than two, and none takes none.
    private func identificationLineCount(for item: PrintSelectionItem) -> Int {
        guard viewModel.showPatientIdentification,
              let text = overlayTexts.text(forPath: item.filePath), !text.isEmpty else { return 0 }
        return (text.primaryLine.isEmpty ? 0 : 1) + (text.secondaryLine.isEmpty ? 0 : 1)
    }

    /// The area of a cell the picture itself gets: the cell, less the strip the
    /// identification reserves under it.
    private func pictureSize(for item: PrintSelectionItem, cellSize: CGSize) -> CGSize {
        let lines = identificationLineCount(for: item)
        guard lines > 0 else { return cellSize }
        let band = PatientIdentificationOverlayView.bandHeight(for: cellSize, lines: lines)
        return CGSize(width: cellSize.width, height: max(1, cellSize.height - band))
    }

    /// Where the image is actually drawn inside a cell.
    ///
    /// The frame is fitted, so unless it happens to be the cell's shape there are
    /// margins either side of it or above and below. Annotations are anchored to
    /// this rect, not to the cell: the margin is not part of the picture and the
    /// printer has no pixels there.
    private func imageRect(for item: PrintSelectionItem, in cellSize: CGSize) -> CGRect {
        let cell = CGRect(origin: .zero, size: cellSize)
        #if canImport(CoreGraphics)
        guard let image = thumbnails.image(for: item),
              image.width > 0, image.height > 0,
              cellSize.width > 0, cellSize.height > 0 else { return cell }
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let cellAspect = cellSize.width / cellSize.height
        if imageAspect > cellAspect {
            // Wider than the cell: full width, margins top and bottom.
            let height = cellSize.width / imageAspect
            return CGRect(x: 0, y: (cellSize.height - height) / 2,
                          width: cellSize.width, height: height)
        }
        let width = cellSize.height * imageAspect
        return CGRect(x: (cellSize.width - width) / 2, y: 0,
                      width: width, height: cellSize.height)
        #else
        return cell
        #endif
    }

    /// The marked frame itself, or a placeholder while it loads or if it cannot
    /// be rendered.
    @ViewBuilder
    private func cellImage(_ item: PrintSelectionItem?) -> some View {
        #if canImport(CoreGraphics)
        if let item, let image = thumbnails.image(for: item) {
            // Fills the cell in both directions, aspect ratio intact — the same
            // fit the printer performs when it places the image in its box.
            Image(decorative: image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// Width over height, from the physical sheet the job will actually print on.
    ///
    /// Taken from ``FilmSheet`` rather than assumed: 8×10, 14×17 and A4 are
    /// visibly different shapes, and a preview drawn at a nominal 3:4 gives its
    /// cells the wrong aspect — which is the aspect the user judges the crop by.
    /// The dpi is irrelevant here; only the ratio is used.
    private var sheetAspect: CGFloat {
        let sheet = FilmSheet(
            filmSize: plan.filmSize, orientation: plan.filmOrientation, dpi: 150)
        guard sheet.heightMillimeters > 0 else { return 3.0 / 4.0 }
        return CGFloat(sheet.widthMillimeters / sheet.heightMillimeters)
    }

    /// Zoom fraction per unit of scroll.
    private static let scrollZoomSensitivity: Double = 0.02

    /// The key that picks a tool. Single letters, no modifier: the film has
    /// keyboard focus while it is being worked on.
    private static func shortcut(for tool: PrintViewModel.CellTool) -> Character {
        switch tool {
        case .window: return "w"
        case .zoom:   return "z"
        case .pan:    return "p"
        case .text:   return "t"
        case .arrow:  return "r"
        }
    }

    /// Room reserved under the film, and only when there is something to put
    /// there: with one film there is no caption, so the film takes that height.
    private var captionAllowance: CGFloat { plan.filmCount > 1 ? 22 : 0 }

    /// Room left either side of a single film, so it does not touch the panel
    /// edges.
    private static let sideAllowance: CGFloat = 8

    /// Width of one page-turn arrow.
    private static let pagingButtonWidth: CGFloat = 34

    /// Width the two arrows take from the film, reserved whether or not there is
    /// a second film to turn to.
    private var pagingAllowance: CGFloat { Self.pagingButtonWidth * 2 }

    /// Below this the cells stop being readable, so the preview scrolls instead.
    private static let minimumSheetHeight: CGFloat = 160
}

// MARK: - Cell interaction

/// Click-to-focus and drag-to-adjust on one film cell.
///
/// Split out as a modifier so the cell body stays a description of the film
/// rather than a pile of gesture plumbing.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct CellInteraction: ViewModifier {
    let enabled: Bool
    let item: PrintSelectionItem?
    @Bindable var viewModel: PrintViewModel
    @Binding var dragAnchor: CGSize

    /// The arrow currently being dragged out, so the drag lengthens that arrow
    /// rather than starting a new one on every mouse event.
    @Binding var draftArrowID: UUID?

    let cellSize: CGSize

    /// Where the picture is inside the cell, for placing what gets drawn on it.
    let imageRect: CGRect

    func body(content: Content) -> some View {
        guard enabled, let item else { return AnyView(content) }
        return AnyView(
            content
                // The location matters for the drawing tools — text lands where
                // it was clicked — and is harmless to the rest.
                .onTapGesture { location in handleTap(at: location, on: item) }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if viewModel.cellTool == .arrow {
                                dragArrow(from: value.startLocation,
                                          to: value.location, on: item)
                                return
                            }
                            if viewModel.focusedItemID != item.id { focus(item) }
                            apply(value.translation, to: item)
                        }
                        .onEnded { _ in
                            dragAnchor = .zero
                            finishArrow(on: item)
                        }
                )
        )
    }

    private func focus(_ item: PrintSelectionItem) {
        viewModel.focusCell(item.id)
        // Windowing needs concrete values to start from; resolving them costs a
        // file read, so it happens once, when a cell is first picked up.
        Task { await viewModel.seedWindowIfNeeded(forItemID: item.id) }
    }

    // MARK: - Drawing

    /// A click: place text with the text tool, otherwise just take the cell.
    private func handleTap(at location: CGPoint, on item: PrintSelectionItem) {
        focus(item)
        guard viewModel.cellTool == .text, let point = normalized(location) else {
            // Clicking the picture with no drawing tool active lets go of
            // whatever annotation was selected — the inspector then talks about
            // the cell again rather than about text nobody is editing.
            if !viewModel.cellTool.isDrawing { viewModel.selectAnnotation(nil) }
            return
        }
        viewModel.addTextAnnotation(forItemID: item.id, at: point)
    }

    /// Drags an arrow out from where the drag began.
    private func dragArrow(from start: CGPoint, to end: CGPoint, on item: PrintSelectionItem) {
        guard let tail = normalized(start), let head = normalized(end) else { return }
        if viewModel.focusedItemID != item.id { focus(item) }

        guard let draftArrowID else {
            draftArrowID = viewModel.addArrowAnnotation(
                forItemID: item.id, from: tail, to: head)
            return
        }
        viewModel.moveArrowEnd(draftArrowID, forItemID: item.id, isHead: true, to: head)
    }

    /// Ends an arrow drag, dropping an arrow too short to be a drawing rather
    /// than a slip of the mouse.
    private func finishArrow(on item: PrintSelectionItem) {
        guard let draftArrowID else { return }
        self.draftArrowID = nil
        if let drawn = viewModel.annotations(forItemID: item.id)
            .first(where: { $0.id == draftArrowID }), drawn.isBlank {
            viewModel.removeAnnotation(draftArrowID, forItemID: item.id)
        }
    }

    /// A point in the cell as a fraction of the image, or `nil` when the click
    /// landed in the letterbox margin, where the film has no pixels.
    private func normalized(_ location: CGPoint) -> PrintOverlayPoint? {
        guard imageRect.width > 0, imageRect.height > 0 else { return nil }
        let x = (location.x - imageRect.minX) / imageRect.width
        let y = (location.y - imageRect.minY) / imageRect.height
        guard x >= 0, x <= 1, y >= 0, y <= 1 else { return nil }
        return PrintOverlayPoint(x: Double(x), y: Double(y))
    }

    /// Turns the running translation into a per-frame delta and applies the tool.
    private func apply(_ translation: CGSize, to item: PrintSelectionItem) {
        let dx = translation.width - dragAnchor.width
        let dy = translation.height - dragAnchor.height
        dragAnchor = translation

        switch viewModel.cellTool {
        case .text, .arrow:
            // Handled by the tap and the arrow drag; a drawing tool must not also
            // window the cell under it.
            return
        case .window:
            // Horizontal widens, vertical raises the centre — the viewer's own
            // convention, so the gesture means the same thing on both screens.
            guard !viewModel.isCellWindowingOverridden else { return }
            viewModel.adjustWindow(
                forItemID: item.id,
                deltaCenter: -Double(dy) * Self.windowSensitivity,
                deltaWidth: Double(dx) * Self.windowSensitivity)
        case .zoom:
            // Dragging up enlarges, as a zoom slider pushed away from you does.
            let factor = 1.0 - Double(dy) * Self.zoomSensitivity
            viewModel.adjustZoom(forItemID: item.id, factor: factor, cellSize: cellSize)
        case .pan:
            viewModel.panCell(
                forItemID: item.id, dx: Double(dx), dy: Double(dy), cellSize: cellSize)
        }
    }

    /// Window units per point dragged. The window is in the viewer's space, so
    /// a CT drag moves in HU here exactly as it does in the viewer.
    private static let windowSensitivity: Double = 2.0

    /// Zoom fraction per point dragged.
    private static let zoomSensitivity: Double = 0.005
}
#endif
