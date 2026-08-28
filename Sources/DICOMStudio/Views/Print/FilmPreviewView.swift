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
// the selected tool over it — window/level, zoom or pan. The tools are on a rail
// down the left, along with the locks that hold an adjustment together across
// cells, and everything that can be done to one cell is also on the film's own
// right-click menu. A mode belongs on the rail rather than in the menu: which
// tool is armed and which cells are linked have to be answerable at a glance,
// and a menu that only exists while it is open cannot answer them. The locks are
// echoed on the cells themselves, which is the sole thing drawn over a picture
// that the film will not carry — see the cell's overlay for why it earns that.
// Every edit is written back into the mark, which is what the
// print path reads, so a cell that looks right here prints that way. What is
// rendered is ``PrintViewModel/previewItems`` rather than the raw marks:
// job-wide settings (an explicit window, raw pixels) override a mark's own
// arrangement, and a preview ignoring that would lie.
//
// Because the tools live here, the picture is drawn from a GPU texture: a cell's
// zoom, pan, rotation, flip and inversion are the display shader's transform, so a
// drag re-draws a quad instead of re-rendering the frame. The transform is built
// from the *film's* composition rather than the viewer's — see `PrintCellDisplay`
// — so what the shader draws is what the printer will lay down. The film itself is
// still composed on the CPU, and must be: the two are byte-identical only because
// neither invents anything the other does not. The one exception is a cell turned
// to a free angle: the shader would fill the corners the film leaves black with
// the neighbouring anatomy, so those cells are drawn by the film's own renderer.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit
import DICOMRenderKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FilmPreviewView: View {
    @Bindable var viewModel: PrintViewModel

    #if canImport(CoreGraphics)
    /// Thumbnails of the marked frames. Owned here so the preview is
    /// self-contained, and keyed by mark so changing the layout — which
    /// re-renders this view constantly — never re-decodes a frame.
    ///
    /// The CPU path: what a cell shows when the GPU will not take it, and what
    /// fills the cell for the moment before its texture arrives.
    @State private var thumbnails = PrintThumbnailCache()
    #endif

    #if canImport(Metal)
    /// GPU textures for the cells of the film on screen.
    ///
    /// The preview is where the tools are used, so the picture is drawn from a
    /// texture and every tool step is the display shader's transform: a zoom, pan,
    /// rotation, flip or invert re-draws a quad and renders nothing. Only a
    /// window/level change produces a new texture, and that is one GPU dispatch.
    @State private var cellTextures = PrintCellTextureCache()
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
        VStack(spacing: 0) {
            if plan.filmCount == 0 {
                ContentUnavailableView(
                    "Nothing marked",
                    systemImage: "square.dashed",
                    description: Text("Mark images in the viewer to place them on film.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // The rail is back beside the film. The right-click menu is a
                // fine place for the occasional command but a poor place for a
                // mode: it costs a click and a read to find out which tool is
                // armed and whether the cells are linked, and both are things
                // the eye should be able to answer while dragging. The menu
                // keeps everything it had, for the hand already on a cell.
                HStack(spacing: 0) {
                    toolRail
                    Divider()
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
                        // The keys the rail's buttons also carry. Hidden buttons
                        // rather than `.keyboardShortcut` on the menu items,
                        // because a context menu only exists while it is open.
                        .background(toolShortcuts)
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
        .onAppear { refreshCells() }
        // Textures belong to the film on screen; paging releases the last one's.
        .onChange(of: currentFilm) { _, _ in refreshCells() }
        .onChange(of: items) { _, _ in
            refreshCells()
            viewModel.pruneFocus()
            // Annotations belong to marks; a mark that has been taken off the film
            // must not leave its arrows behind to reappear on a later one.
            viewModel.pruneAnnotations()
            refreshOverlayTexts()
        }
        #endif
    }

    // MARK: - The tool rail

    /// Everything a cell can be worked on with, down the left of the film.
    ///
    /// Icon-only and narrow: the sheet is what the reader is judging, and every
    /// point the rail takes is a point the picture does not get. Names and keys
    /// live in the tooltips.
    private var toolRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(PrintViewModel.CellTool.allCases) { tool in
                    railButton(
                        symbol: tool.symbolName,
                        caption: Self.railCaption(for: tool),
                        isOn: viewModel.cellTool == tool,
                        help: "\(tool.displayName)  (\(Self.shortcut(for: tool).uppercased()))"
                    ) {
                        viewModel.cellTool = tool
                    }
                }

                // Invert is a switch on the focused cell, not a drag, so it does
                // not arm anything — its lit state is the cell's, which is what
                // "is this picture inverted" is asking. The film's own polarity
                // is a job setting and lives in the settings column; this is one
                // picture being read the other way round.
                railButton(
                    symbol: "circle.righthalf.filled",
                    caption: "Invert",
                    isOn: viewModel.focusedItem?.presentation?.invert ?? false,
                    help: viewModel.focusedItem == nil
                        ? "Invert a cell's greys — click a cell first."
                        : "Invert the focused cell's greys.  (V)"
                ) {
                    if let id = viewModel.focusedItemID {
                        viewModel.toggleCellInversion(forItemID: id)
                    }
                }
                .disabled(viewModel.focusedItemID == nil)

                Divider().padding(.horizontal, 6)

                // The locks. A closed one says this adjustment is held together
                // across the cells; an open one says each cell keeps its own.
                ForEach(PrintCellSyncOptions.catalog, id: \.title) { entry in
                    let isOn = viewModel.cellSync.contains(entry.option)
                    let blocked = entry.option == .window && viewModel.isCellWindowingOverridden
                    railButton(
                        symbol: isOn ? "lock.fill" : "lock.open",
                        caption: Self.railCaption(for: entry.option),
                        isOn: isOn && !blocked,
                        help: blocked
                            ? (viewModel.cellWindowingBlockedReason ?? "")
                            : (isOn ? "\(entry.title) is locked together across cells — unlock to adjust one cell alone."
                                    : "Lock \(entry.title.lowercased()) together, so adjusting one cell adjusts the others.")
                    ) {
                        viewModel.toggleSync(entry.option)
                        // Cells never opened carry no window, and a relative
                        // window edit has nothing to work from — so they are
                        // given one the moment the lock closes, not mid-drag.
                        if entry.option == .window && viewModel.cellSync.contains(.window) {
                            Task { await viewModel.seedWindowsForSync() }
                        }
                    }
                    .disabled(blocked)
                }

                // How far a locked adjustment reaches. Under the locks because
                // it is meaningless without one.
                Menu {
                    ForEach(PrintCellSyncScope.allCases) { scope in
                        Button {
                            viewModel.cellSyncScope = scope
                        } label: {
                            Label(scope.title,
                                  systemImage: viewModel.cellSyncScope == scope ? "checkmark" : "")
                        }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                            .font(.system(size: 17))
                        Text(Self.scopeCaption(viewModel.cellSyncScope))
                            .font(.system(size: 10))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: Self.railWidth - 8)
                .foregroundStyle(Color.secondary)
                .disabled(!viewModel.isCellSyncActive)
                .help("How far a locked adjustment reaches: \(viewModel.cellSyncScope.title).")

                Divider().padding(.horizontal, 6)

                railButton(symbol: "arrow.counterclockwise", caption: "Cell",
                           isOn: false,
                           help: "Return the focused cell to the untouched frame.  (0)") {
                    viewModel.resetFocusedCell()
                }
                .disabled(viewModel.focusedItem.map { !viewModel.isCellEdited($0) } ?? true)

                railButton(symbol: "arrow.counterclockwise.circle", caption: "All",
                           isOn: false,
                           help: "Return every cell to the untouched frame.  (\u{21E7}0)") {
                    viewModel.resetAllCells()
                }
                .disabled(!viewModel.hasEditedCells)
            }
            .padding(.vertical, 8)
        }
        .frame(width: Self.railWidth)
        .scrollBounceBehavior(.basedOnSize)
    }

    /// One rail button: a glyph, a word under it, and a tinted background when
    /// it is the one in force.
    private func railButton(
        symbol: String, caption: String, isOn: Bool, help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: isOn ? .semibold : .regular))
                Text(caption)
                    .font(.system(size: 10, weight: isOn ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: Self.railWidth - 8, height: 44)
            // The armed tool is filled, not merely tinted. A wash of accent
            // behind one of six glyphs is easy to miss on a bright sheet, and
            // "which tool is this drag about to run" is the question the rail
            // exists to answer — so the selected one reads as a solid chip with
            // the film's own contrast, the way a pressed key looks pressed.
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Color.accentColor : Color.clear)
                    .shadow(color: isOn ? Color.accentColor.opacity(0.35) : .clear,
                            radius: 3, y: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isOn ? Color.accentColor : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Color.white : Color.secondary)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// The word under a tool's glyph — short enough for the rail's width.
    private static func railCaption(for tool: PrintViewModel.CellTool) -> String {
        switch tool {
        case .window: return "W/L"
        case .zoom:   return "Zoom"
        case .pan:    return "Pan"
        case .text:   return "Text"
        case .arrow:  return "Arrow"
        }
    }

    /// The word under a lock.
    private static func railCaption(for option: PrintCellSyncOptions) -> String {
        if option == .zoomPan { return "Zoom+Pan" }
        if option == .window { return "W/L" }
        return "Invert"
    }

    private static func scopeCaption(_ scope: PrintCellSyncScope) -> String {
        switch scope {
        case .allCells: return "All"
        case .sameSeries: return "Series"
        case .thisFilm: return "Film"
        }
    }

    /// Wide enough for the longest caption at the rail's type size — "Zoom+Pan"
    /// — without it shrinking to fit, which is what a caption too small to read
    /// at a glance costs the rail its point.
    private static let railWidth: CGFloat = 68

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
                // The arrows take a gutter only when there is a second film to
                // turn to; on a single film that width is the film's.
                if plan.filmCount > 1 {
                    pagingButton(step: -1, symbol: "chevron.left")
                }
                filmSheet(filmIndex: currentFilm, width: sheetWidth, height: sheetHeight)
                    .frame(maxWidth: .infinity)
                if plan.filmCount > 1 {
                    pagingButton(step: 1, symbol: "chevron.right")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The film currently on screen, clamped to the plan — the count can shrink
    /// under us between a page turn and the next redraw.
    private var currentFilm: Int {
        min(max(0, visibleFilm), max(0, plan.filmCount - 1))
    }

    /// The marks on the film being shown.
    private var visibleItems: [PrintSelectionItem] {
        guard plan.filmCount > 0 else { return [] }
        let range = plan.imageIndices(onFilm: currentFilm)
        return range.compactMap { items.indices.contains($0) ? items[$0] : nil }
    }

    #if canImport(CoreGraphics)
    /// Marks that still need a CPU thumbnail: the ones the GPU is not drawing.
    ///
    /// A cell with a texture is deliberately excluded, and so is dropped from the
    /// thumbnail cache. That is what makes a tool drag free here — the CPU key
    /// includes the arrangement, so leaving a GPU-drawn cell in that cache would
    /// re-render it on every mouse delta the shader was about to handle for
    /// nothing, which is the cost this path exists to remove.
    private var itemsNeedingThumbnail: [PrintSelectionItem] {
        #if canImport(Metal)
        guard PrintCellTextureCache.isAvailable else { return visibleItems }
        return visibleItems.filter { drawnTexture(for: $0) == nil }
        #else
        return visibleItems
        #endif
    }

    #if canImport(Metal)
    /// The texture a cell is actually drawn from, if it is drawn from one.
    ///
    /// A freely rotated cell is not: the shader draws the whole frame and lets
    /// the view clip it, so the corners the film leaves black would come out as
    /// the neighbouring anatomy instead. The film's own renderer answers those
    /// cells, at the cost of a re-render per tool step on a rotated cell only.
    private func drawnTexture(for item: PrintSelectionItem) -> DisplayFrameTexture? {
        guard item.presentation?.isQuarterTurn ?? true else { return nil }
        return cellTextures.texture(for: item)
    }
    #endif

    /// Brings both cell caches up to date with the film on screen.
    private func refreshCells() {
        #if canImport(Metal)
        cellTextures.refresh(for: visibleItems)
        #endif
        thumbnails.refresh(for: itemsNeedingThumbnail)
    }
    #endif

    /// One page turn: an arrow either side of the film, disabled at the ends.
    ///
    /// Shown only when there is more than one film — an invisible gutter kept for
    /// symmetry is width the single film being judged could have used.
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
            return moveFocusVertically(-1) ? .handled : .ignored
        case KeyEquivalent.downArrow.character:
            return moveFocusVertically(1) ? .handled : .ignored
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

    /// Moves the focus one cell up or down, by where the cells actually are.
    ///
    /// A film's rows need not hold the same number of images — `ROW\1,2` is one
    /// over two — so "the cell above" is a question about geometry and not
    /// arithmetic on a column count. Off the top or bottom of a film the walk
    /// carries on to the next one, entering the band the eye would come to.
    @discardableResult
    private func moveFocusVertically(_ direction: Int) -> Bool {
        // A nominal sheet: only the proportions of the cells matter here — and
        // the footer, which shortens the rows the walk steps between.
        let cells = sheetCells(
            width: 1000 * sheetAspect, height: 1000,
            footerLines: identification(onFilm: currentFilm).footerLines.count)
        guard let current = focusedCell(among: cells) else {
            return moveFocus(by: direction)
        }
        let centerX = current.x + current.width / 2
        let centerY = current.y + current.height / 2

        /// The cell nearest this one in the direction travelled: the closest band
        /// first, then the cell in it whose horizontal centre is nearest.
        func nearest(_ pool: [FilmCell]) -> FilmCell? {
            pool.min { a, b in
                let dyA = abs((a.y + a.height / 2) - centerY)
                let dyB = abs((b.y + b.height / 2) - centerY)
                if abs(dyA - dyB) > 0.5 { return dyA < dyB }
                return abs((a.x + a.width / 2) - centerX) < abs((b.x + b.width / 2) - centerX)
            }
        }

        let ahead = cells.filter { cell in
            let y = cell.y + cell.height / 2
            return direction > 0 ? y > centerY + 0.5 : y < centerY - 0.5
        }
        if let target = nearest(ahead) {
            return moveFocus(by: target.position - current.position)
        }

        // At the edge of this film: onto the next one, entering from its far side.
        guard let edge = direction > 0
                ? cells.map({ $0.y + $0.height / 2 }).min()
                : cells.map({ $0.y + $0.height / 2 }).max() else { return false }
        let entryBand = cells.filter { abs(($0.y + $0.height / 2) - edge) < 0.5 }
        guard let target = entryBand.min(by: {
            abs(($0.x + $0.width / 2) - centerX) < abs(($1.x + $1.width / 2) - centerX)
        }) else { return false }
        return moveFocus(by: direction * plan.cellsPerFilm + target.position - current.position)
    }

    /// The cell the focused mark sits in, by its position on its own film.
    private func focusedCell(among cells: [FilmCell]) -> FilmCell? {
        guard plan.cellsPerFilm > 0,
              let focusedID = viewModel.focusedItemID,
              let index = viewModel.selection.items.firstIndex(where: { $0.id == focusedID })
        else { return nil }
        let position = index % plan.cellsPerFilm + 1
        return cells.first { $0.position == position }
    }

    // MARK: - Tools

    /// The keyboard shortcuts the tool rail used to carry.
    ///
    /// Zero-sized buttons behind the film: a context menu only exists while it
    /// is open, so its items cannot own the keys. W, Z, P, T, R still arm a
    /// tool, I toggles the identification caption and 0 resets the focused cell,
    /// exactly as they did when the rail was on screen.
    private var toolShortcuts: some View {
        ZStack {
            ForEach(PrintViewModel.CellTool.allCases) { tool in
                Button("") { viewModel.cellTool = tool }
                    .keyboardShortcut(KeyEquivalent(Self.shortcut(for: tool)), modifiers: [])
            }
            Button("") { viewModel.showPatientIdentification.toggle() }
                .keyboardShortcut("i", modifiers: [])
            Button("") {
                if let id = viewModel.focusedItemID {
                    viewModel.toggleCellInversion(forItemID: id)
                }
            }
            .keyboardShortcut("v", modifiers: [])
            Button("") { viewModel.resetFocusedCell() }
                .keyboardShortcut("0", modifiers: [])
            // The sheet-wide way out, shifted: linked cells make a bad
            // arrangement easy to spread, and undoing it cell by cell is the
            // work the link just saved.
            Button("") { viewModel.resetAllCells() }
                .keyboardShortcut("0", modifiers: [.shift])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// The film's own menu: what a drag will do, and what can be done to the
    /// cell under the pointer.
    ///
    /// On the film rather than beside it. A tool is chosen for the cell being
    /// worked on, and the right-click is already over that cell — so the menu
    /// costs the picture no width at all, which is what the rail cost it.
    @ViewBuilder
    private func cellMenu(for item: PrintSelectionItem?) -> some View {
        ForEach(PrintViewModel.CellTool.allCases) { tool in
            Button {
                viewModel.cellTool = tool
            } label: {
                Label("\(tool.displayName)  (\(String(Self.shortcut(for: tool)).uppercased()))",
                      systemImage: viewModel.cellTool == tool ? "checkmark" : tool.symbolName)
            }
        }

        Divider()

        Button {
            viewModel.showPatientIdentification.toggle()
        } label: {
            Label(viewModel.showPatientIdentification
                  ? "Hide Patient ID Caption  (I)" : "Show Patient ID Caption  (I)",
                  systemImage: "person.text.rectangle")
        }

        // Where that caption goes. Beside the switch that turns it on, because
        // "one name at the bottom or one under every picture" is the same
        // question as "does this film name its patient" — asked of the film in
        // front of the reader, not of a control in another panel.
        Menu {
            ForEach(PrintIdentificationPlacement.allCases, id: \.self) { placement in
                Button {
                    viewModel.identificationPlacement = placement
                } label: {
                    Label(placement.title,
                          systemImage: viewModel.identificationPlacement == placement
                          ? "checkmark" : "")
                }
            }
        } label: {
            Label("Patient ID Caption Goes", systemImage: "text.alignleft")
        }
        .disabled(!viewModel.showPatientIdentification)

        // Whether the film carries the viewer's zoom and pan at all. Here as
        // well as in the settings column, because "why is this cell showing a
        // close-up" is asked of the cell, not of a checkbox two panels away:
        // switching it off puts every whole image back on the film.
        Button {
            viewModel.useViewerPresentation.toggle()
        } label: {
            Label(viewModel.useViewerPresentation
                  ? "Fit the Whole Image in Every Cell"
                  : "Use the Viewer's Zoom and Pan",
                  systemImage: viewModel.useViewerPresentation
                  ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .disabled(viewModel.sendRawPixels)

        Divider()

        // The same switches as the strip above the film, for the hand that is
        // already on the cell.
        Menu {
            ForEach(PrintCellSyncOptions.catalog, id: \.title) { entry in
                Button {
                    viewModel.toggleSync(entry.option)
                    if entry.option == .window && viewModel.cellSync.contains(.window) {
                        Task { await viewModel.seedWindowsForSync() }
                    }
                } label: {
                    Label(entry.title,
                          systemImage: viewModel.cellSync.contains(entry.option)
                          ? "lock.fill" : "lock.open")
                }
                .disabled(entry.option == .window && viewModel.isCellWindowingOverridden)
            }
            Divider()
            ForEach(PrintCellSyncScope.allCases) { scope in
                Button {
                    viewModel.cellSyncScope = scope
                } label: {
                    Label(scope.title,
                          systemImage: viewModel.cellSyncScope == scope ? "checkmark" : "")
                }
            }
        } label: {
            Label("Lock Cells Together",
                  systemImage: viewModel.isCellSyncActive ? "lock.fill" : "lock.open")
        }

        if let item {
            Divider()

            Button("Apply This Window to All Cells") {
                viewModel.focusCell(item.id)
                viewModel.applyFocusedWindowToAllCells()
            }
            .disabled(viewModel.window(forItemID: item.id) == nil)

            Button("Revert to the Viewer's Arrangement") {
                viewModel.focusCell(item.id)
                viewModel.revertCell(forItemID: item.id)
            }
            .disabled(!viewModel.isCellAdjusted(item.id))

            Button(item.presentation?.invert == true
                   ? "Show This Cell the Right Way Round  (V)"
                   : "Invert This Cell's Greys  (V)") {
                viewModel.focusCell(item.id)
                viewModel.toggleCellInversion(forItemID: item.id)
            }

            Button("Reset This Cell  (0)") {
                viewModel.focusCell(item.id)
                viewModel.resetCell(forItemID: item.id)
            }
            .disabled(!viewModel.isCellEdited(item))

            if let focused = viewModel.focusedItem, focused.id != item.id {
                Button("Reset the Focused Cell") {
                    viewModel.resetFocusedCell()
                }
                .disabled(!viewModel.isCellEdited(focused))
            }

            Button("Reset All Cells  (⇧0)", role: .destructive) {
                viewModel.resetAllCells()
            }
            .disabled(!viewModel.hasEditedCells)

            if !viewModel.annotations(forItemID: item.id).isEmpty {
                Divider()
                Button("Clear This Cell's Annotations", role: .destructive) {
                    viewModel.clearAnnotations(forItemID: item.id)
                }
            }

            Divider()

            Button("Take Off the Film", role: .destructive) {
                viewModel.selection.remove(
                    filePath: item.filePath, frameIndex: item.frameIndex)
            }
        }
    }

    // MARK: - One film

    /// The cells of the film on screen, in Image Box Position order.
    ///
    /// Laid out by ``FilmCellLayout`` — the film composer's own geometry — rather
    /// than by a SwiftUI `Grid`, because a grid can only draw the layouts whose
    /// rows all hold the same number of images. `ROW\1,2` holds one over two, and
    /// the preview has to be able to show the film that is going to be printed.
    private func sheetCells(width: CGFloat, height: CGFloat, footerLines: Int = 0) -> [FilmCell] {
        plan.cells(onSheetOfWidth: Double(width), height: Double(height),
                   margin: Double(Self.sheetMargin), spacing: Double(Self.cellSpacing),
                   footer: plan.footerUnits(forLineCount: footerLines, sheetHeight: Double(height)))
    }

    /// How the film being drawn states its identification.
    ///
    /// Decided by ``FilmIdentificationPlanner`` — the rule the print run and the
    /// composed sheet apply — so the strip the reader approves is the strip the
    /// film carries. Nothing is drawn until every cell's header has been read:
    /// a film that footers on the first file to load and then breaks into
    /// per-image captions when the second arrives is a preview flickering
    /// between two answers.
    private func identification(onFilm filmIndex: Int) -> FilmIdentification {
        guard viewModel.showPatientIdentification, plan.filmCount > 0 else { return .none }
        var sources: [FilmIdentificationSource] = []
        for index in plan.imageIndices(onFilm: filmIndex) {
            guard items.indices.contains(index) else { continue }
            let item = items[index]
            guard let text = overlayTexts.text(forPath: item.filePath) else { return .none }
            sources.append(FilmIdentificationSource(
                key: item.id, studyKey: text.studyInstanceUID, lines: text.lines))
        }
        return FilmIdentificationPlanner.identification(
            for: sources, placement: viewModel.identificationPlacement)
    }

    @ViewBuilder
    private func filmSheet(filmIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let range = plan.imageIndices(onFilm: filmIndex)
        let identification = identification(onFilm: filmIndex)
        let footer = identification.footerLines
        VStack(spacing: 3) {
            ZStack(alignment: .topLeading) {
                Color.black
                ForEach(sheetCells(width: width, height: height, footerLines: footer.count),
                        id: \.position) { filmCell in
                    cell(filmCell: filmCell, range: range, identification: identification)
                        .frame(width: CGFloat(filmCell.width), height: CGFloat(filmCell.height))
                        .offset(x: CGFloat(filmCell.x), y: CGFloat(filmCell.y))
                }
                // The film's own caption, in the strip the layout kept clear for
                // it — one statement of whose study this sheet is, where the
                // composed film burns it.
                if !footer.isEmpty {
                    FilmIdentificationFooterView(
                        lines: footer,
                        sheetHeight: height,
                        sheetHeightMillimeters: sheetHeightMillimeters)
                    .padding(.bottom, CGFloat(Self.sheetMargin))
                    .frame(width: width, height: height, alignment: .bottom)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
            )

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
    private func cell(
        filmCell: FilmCell,
        range: Range<Int>,
        identification: FilmIdentification = .perImage
    ) -> some View {
        let itemIndex = range.lowerBound + filmCell.position - 1
        let isFilled = itemIndex < range.upperBound
        let item = items.indices.contains(itemIndex) ? items[itemIndex] : nil
        let isFocused = item != nil && item?.id == viewModel.focusedItemID
        // The cell's own size, from the layout rather than measured: under a band
        // layout the cells differ, and every tool that works in cell points —
        // zoom, pan, annotation anchors, the identification strip — has to be
        // told about *this* cell rather than about a film-wide average.
        let cellSize = CGSize(width: CGFloat(filmCell.width), height: CGFloat(filmCell.height))
        // The picture's own area: the cell less whatever the identification strip
        // takes. Zoom, pan and annotations all resolve against this rather than the
        // cell, because this is what actually gets printed.
        let picture = item.map {
            pictureSize(for: $0, cellSize: cellSize, identification: identification)
        } ?? cellSize

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
                        // Held to the picture's own rectangle. The shader draws
                        // the whole frame and lets the view clip it, so without
                        // this the margins either side of a crop would fill with
                        // the neighbouring anatomy — the cell would show more
                        // than the film prints, and read as an enlarged image
                        // spilling past its edges.
                        .mask(alignment: .center) {
                            let rect = item.map { imageRect(for: $0, in: picture) }
                                ?? CGRect(origin: .zero, size: picture)
                            Rectangle().frame(width: rect.width, height: rect.height)
                        }
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
            // Identification in its own strip under the picture, as the print
            // run burns it: on paper, text over anatomy is where a finding
            // hides, and the reader cannot move the picture out from under it.
            // `safeAreaInset` takes the height from the cell rather than
            // covering it, so the picture above is complete.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isFilled, identification.isPerImage, let item,
                   let text = overlayTexts.text(forPath: item.filePath), !text.isEmpty {
                    PatientIdentificationOverlayView(
                        primaryLine: text.primaryLine,
                        secondaryLine: text.secondaryLine,
                        cellSize: cellSize)
                    .allowsHitTesting(false)
                }
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            // The lock, on the picture itself. The one thing here that is not
            // burned into the film — the rule this file otherwise holds to — and
            // it earns the exception: it says this cell is about to move when
            // its neighbour is dragged, which is the fact a reader most needs
            // *before* dragging, and it costs a right-click to find anywhere
            // else. It appears only while a lock is closed, sits in the corner
            // over the letterbox margin rather than the anatomy, and never takes
            // a click — the rail is where locks are opened and shut.
            .overlay(alignment: .topTrailing) {
                if isFilled, let item, viewModel.isLinkedToFocus(item.id) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                        .padding(2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.black.opacity(0.55)))
                        .padding(3)
                        .allowsHitTesting(false)
                        .accessibilityLabel(
                            isFocused
                            ? "Linked: adjusting this cell adjusts the others"
                            : "Linked to the focused cell")
                }
            }
            .contentShape(Rectangle())
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
                                cellSize: picture,
                                pixelSize: sourcePixelSize(for: item))
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
                pixelSize: item.flatMap { sourcePixelSize(for: $0) },
                imageRect: item.map { imageRect(for: $0, in: picture) } ?? .zero))
            // The tools live here now. Each item acts on the cell that was
            // right-clicked — it takes the cell first — so the menu is about the
            // picture under the pointer rather than about whichever cell
            // happened to be focused before.
            .contextMenu { cellMenu(for: item) }
            .accessibilityLabel(
                isFilled
                ? "Cell \(itemIndex + 1): \(item?.displayLabel ?? "image")"
                : "Empty cell")
            .accessibilityAddTraits(isFocused ? [.isSelected] : [])
    }

    /// Lines of identification this cell will carry, which is what decides how
    /// deep its strip is — one line takes less room than two, and none takes none.
    ///
    /// None at all on a film that states its identification once at the foot of
    /// the sheet: the cell keeps the height a strip would have taken, which is
    /// the point of footering it.
    private func identificationLineCount(
        for item: PrintSelectionItem,
        identification: FilmIdentification
    ) -> Int {
        guard identification.isPerImage,
              let text = overlayTexts.text(forPath: item.filePath), !text.isEmpty else { return 0 }
        return (text.primaryLine.isEmpty ? 0 : 1) + (text.secondaryLine.isEmpty ? 0 : 1)
    }

    /// The area of a cell the picture itself gets: the cell, less the strip the
    /// identification reserves under it.
    private func pictureSize(
        for item: PrintSelectionItem,
        cellSize: CGSize,
        identification: FilmIdentification
    ) -> CGSize {
        let lines = identificationLineCount(for: item, identification: identification)
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
        guard let pixels = arrangedPixelSize(for: item),
              pixels.width > 0, pixels.height > 0,
              cellSize.width > 0, cellSize.height > 0 else { return cell }
        let imageAspect = CGFloat(pixels.width) / CGFloat(pixels.height)
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

    /// The size of the *source* frame behind a cell, when it is known.
    ///
    /// The zoom and pan tools need it to know how much of the image is hidden
    /// outside the cell, which is how far they are allowed to travel. Only the
    /// GPU path can answer: its texture is the whole frame, whereas the CPU
    /// thumbnail is already the arranged crop.
    private func sourcePixelSize(for item: PrintSelectionItem) -> CGSize? {
        #if canImport(Metal)
        if let texture = cellTextures.texture(for: item) {
            return CGSize(width: texture.width, height: texture.height)
        }
        #endif
        return nil
    }

    #if canImport(CoreGraphics)
    /// The size of the picture this cell prints, in source pixels.
    ///
    /// Whichever path drew the cell, this is the same number: the CPU thumbnail
    /// *is* the arranged picture, so its own dimensions say it, and on the GPU the
    /// arrangement is a transform over a full-frame texture, so it is worked out
    /// from the visible region instead. Getting the two to agree is what keeps an
    /// annotation in the same place when a cell's texture arrives.
    private func arrangedPixelSize(for item: PrintSelectionItem) -> (width: Int, height: Int)? {
        #if canImport(Metal)
        if let texture = drawnTexture(for: item) {
            return PrintCellDisplay.arrangedPixelSize(
                for: item, imageWidth: texture.width, imageHeight: texture.height)
        }
        #endif
        guard let image = thumbnails.image(for: item) else { return nil }
        return (image.width, image.height)
    }
    #endif

    /// The marked frame itself, or a placeholder while it loads or if it cannot
    /// be rendered.
    ///
    /// From the GPU when the frame is there — which is where the tools want it,
    /// since every drag then costs a redraw of a quad rather than a re-render —
    /// and from the CPU thumbnail otherwise. The two compose the same geometry:
    /// the shader is given the film's own composition (see ``PrintCellDisplay``),
    /// not the viewer's, so a cell does not change shape when its texture lands.
    @ViewBuilder
    private func cellImage(_ item: PrintSelectionItem?) -> some View {
        #if canImport(Metal)
        if let item, let texture = drawnTexture(for: item) {
            MetalImageView(
                frame: texture,
                presentation: PrintCellDisplay.presentation(
                    for: item,
                    imageWidth: texture.width,
                    imageHeight: texture.height))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            cellCPUImage(item)
        }
        #else
        cellCPUImage(item)
        #endif
    }

    /// A cell drawn from a CPU-rendered still — the fallback, and the only path on
    /// a machine without Metal.
    @ViewBuilder
    private func cellCPUImage(_ item: PrintSelectionItem?) -> some View {
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

    /// The printed sheet's height in millimetres — what the footer's type is
    /// scaled against, so the strip on screen is the strip on film.
    private var sheetHeightMillimeters: CGFloat {
        let sheet = FilmSheet(
            filmSize: plan.filmSize, orientation: plan.filmOrientation, dpi: 150)
        return CGFloat(sheet.heightMillimeters)
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
    private var captionAllowance: CGFloat { plan.filmCount > 1 ? 18 : 0 }

    /// Room left either side of a single film, so it does not touch the panel
    /// edges.
    private static let sideAllowance: CGFloat = 4

    /// Width of one page-turn arrow.
    private static let pagingButtonWidth: CGFloat = 34

    /// Width the two arrows take from the film — none at all on a single film,
    /// where the picture gets it instead.
    private var pagingAllowance: CGFloat {
        plan.filmCount > 1 ? Self.pagingButtonWidth * 2 : 0
    }

    /// Below this the cells stop being readable, so the preview scrolls instead.
    private static let minimumSheetHeight: CGFloat = 160

    /// The unprinted edge of the sheet, and the gutter between two cells.
    private static let sheetMargin: CGFloat = 6
    private static let cellSpacing: CGFloat = 4
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

    /// The source frame's own size, when the cell knows it — what bounds how far
    /// the zoom and pan tools may travel.
    let pixelSize: CGSize?

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
            viewModel.adjustZoom(forItemID: item.id, factor: factor,
                                 cellSize: cellSize, pixelSize: pixelSize)
        case .pan:
            viewModel.panCell(
                forItemID: item.id, dx: Double(dx), dy: Double(dy),
                cellSize: cellSize, pixelSize: pixelSize)
        }
    }

    /// Window units per point dragged. The window is in the viewer's space, so
    /// a CT drag moves in HU here exactly as it does in the viewer.
    private static let windowSensitivity: Double = 2.0

    /// Zoom fraction per point dragged.
    private static let zoomSensitivity: Double = 0.005
}

#endif
