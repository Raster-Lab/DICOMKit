// PrintSettingsView.swift
// DICOMStudio
//
// DICOM Studio — the print sheet: pick a printer and layout, check the film
// plan, and send the marked images to the DICOM printer.
//
// Three columns, like every other print dialog: the settings down the left, the
// film large in the middle, the focused cell's controls down the right. The film
// is the thing actually being judged, so it keeps the centre at full height —
// nothing is stacked above or below it that could take that height away.
//
// Visible zone: printer, layout, orientation, film size, copies, preview.
// Advanced zone: everything else the dicom-print CLI exposes.

#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import DICOMNetwork
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct PrintSettingsView: View {
    @Bindable var viewModel: PrintViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false

    /// Whether the full options band is showing. Collapsed, the sheet is film
    /// size, orientation and the preview — which is all a film usually needs.
    @State private var showOptions = true
    @State private var showPrinterManagement = false
    @State private var showImageList = false

    /// Keyboard focus for the annotation's text field, so text placed on a cell
    /// can be typed straight away rather than clicked into first.
    @FocusState private var isAnnotationTextFocused: Bool

    /// Size of the window the sheet was raised from. The print screen opens at
    /// the same size as the screen behind it.
    private let parentSize: CGSize?

    public init(viewModel: PrintViewModel, parentSize: CGSize? = nil) {
        self.viewModel = viewModel
        self.parentSize = parentSize
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if viewModel.isRunning || viewModel.phase != .configuring {
                PrintProgressView(viewModel: viewModel)
            } else {
                configurationForm
            }

            Divider()

            footer
        }
        // Text placed on a cell is created empty, so the caret goes to its field:
        // clicking to place text and then having to click again to type it is one
        // click too many for something done a dozen times a film.
        .onChange(of: viewModel.selectedAnnotationID) { _, _ in
            if let selected = viewModel.selectedAnnotation,
               selected.annotation.kind == .text, selected.annotation.text.isEmpty {
                isAnnotationTextFocused = true
            }
        }
        // A fixed size, not a range: given only a range, the sheet settles on
        // whatever its content asks for — which is the minimum — and the options
        // band ends up clipped with the film in a small square in the middle.
        .frame(width: sheetSize.width, height: sheetSize.height)
        .sheet(isPresented: $showPrinterManagement) {
            PrinterManagementView(viewModel: viewModel)
        }
    }

    /// The size the sheet opens at.
    ///
    /// Three quarters of the window it was raised from: enough that the options
    /// band fits without clipping and the film gets real room, while the viewer
    /// stays visible around it. Never below the size the band needs — on a small
    /// window the sheet takes the whole of it rather than hiding controls — and
    /// never past the display it sits on.
    private var sheetSize: CGSize {
        let parentWidth = parentSize?.width ?? Self.fallbackWidth
        let parentHeight = parentSize?.height ?? Self.fallbackHeight

        var width = max(Self.minimumWidth, parentWidth * Self.parentFraction)
        var height = max(Self.minimumHeight, parentHeight * Self.parentFraction)

        // Never larger than the window behind it, or its edges fall outside.
        width = min(width, parentWidth)
        height = min(height, parentHeight)

        #if canImport(AppKit)
        // A sheet is presented on its parent's screen, and the visible frame
        // already excludes the menu bar and Dock.
        if let visible = (NSApplication.shared.keyWindow?.screen ?? NSScreen.main)?.visibleFrame {
            width = min(width, visible.width)
            height = min(height, visible.height)
        }
        #endif

        return CGSize(width: width, height: height)
    }

    /// How much of the parent window the sheet takes.
    private static let parentFraction: CGFloat = 0.75

    /// Below these the two columns and the film stop fitting side by side.
    private static let minimumWidth: CGFloat = 1160
    private static let minimumHeight: CGFloat = 680

    /// Used when the sheet was raised without a window size to match.
    private static let fallbackWidth: CGFloat = 1100
    private static let fallbackHeight: CGFloat = 760

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Print to DICOM Printer")
                    .font(.headline)
                Text(viewModel.planSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !viewModel.isRunning {
                KeyboardShortcutsButton(
                    title: "Print Preview Shortcuts",
                    groups: KeyboardShortcutsLegendView.printPreviewGroups)
                    .controlSize(.small)

                Button {
                    showOptions.toggle()
                } label: {
                    Label(showOptions ? "Hide Options" : "Show Options",
                          systemImage: showOptions ? "chevron.up" : "slider.horizontal.3")
                }
                .controlSize(.small)
                .help("Hide the settings column and give the film the whole sheet")
            }
            if let message = viewModel.validationMessage, !viewModel.isRunning {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: 280, alignment: .trailing)
            }
        }
        .padding()
    }

    // MARK: - Configuration

    /// Settings left, film centre, focused cell right.
    ///
    /// The preview gets the whole middle column at full sheet height. The
    /// settings scroll in their own column instead of banding across the top,
    /// where they capped how tall the film could be drawn.
    private var configurationForm: some View {
        HStack(spacing: 0) {
            if showOptions {
                optionsSidebar
                Divider()
            }

            VStack(spacing: 0) {
                // Collapsed, the two things a reading room still changes per
                // film ride above the preview as a single slim row.
                if !showOptions {
                    compactBand
                    Divider()
                }

                previewSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !viewModel.selection.isEmpty {
                Divider()
                inspectorSidebar
            }
        }
    }

    /// The column of settings down the left edge.
    ///
    /// One card per subject — where the film goes, what the film is, what is on
    /// it — rather than a single run of controls under rules. A card is what makes
    /// "film size" obviously a property of the film and not of the printer, which
    /// a flat list of pickers cannot say.
    private var optionsSidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                card { printerSection }
                card { basicSection }
                card { marksSection }
                card { advancedSection }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(width: Self.sidebarWidth, alignment: .leading)
        }
        .frame(width: Self.sidebarWidth)
    }

    /// One section of the settings column.
    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    /// Width of the settings column — enough for a picker and its caption.
    private static let sidebarWidth: CGFloat = 320

    /// Width of the focused-cell column on the right.
    private static let inspectorWidth: CGFloat = 260

    /// The band collapsed to what a reading room changes per film: the sheet it
    /// prints on and which way round it goes. Everything else keeps the value it
    /// already has — collapsing hides controls, it never resets them.
    private var compactBand: some View {
        HStack(spacing: 14) {
            labeledControl("Film size") {
                Picker("Film size", selection: $viewModel.filmSize) {
                    ForEach(PrintOptionCatalog.filmSizes, id: \.cliToken) { entry in
                        Text(entry.label).tag(entry.value)
                    }
                }
                .labelsHidden()
                .disabled(viewModel.layoutMode == .template)
            }

            Picker("Orientation", selection: $viewModel.filmOrientation) {
                ForEach(PrintOptionCatalog.orientations, id: \.cliToken) { entry in
                    Text(entry.label).tag(entry.value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .disabled(viewModel.layoutMode == .template)

            if let printer = viewModel.selectedPrinter {
                Text(printer.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    /// Widest a picker in the sidebar grows to.
    private static let controlWidth: CGFloat = 180

    // MARK: Printer

    private var printerSection: some View {
        bandGroup("Printer") {
            if viewModel.printers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No printers configured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Add Printer…") { showPrinterManagement = true }
                        .controlSize(.small)
                }
            } else {
                Picker("Printer", selection: $viewModel.selectedPrinterID) {
                    ForEach(viewModel.printers) { printer in
                        Text(printer.summary).tag(Optional(printer.id))
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity)

                // One row of equal buttons, so the column reads as a column
                // rather than as three differently-sized things.
                HStack(spacing: 6) {
                    Button("Manage…") { showPrinterManagement = true }
                        .frame(maxWidth: .infinity)
                        .help("Add, edit, or remove printers")

                    Button("Test") {
                        Task { await viewModel.testConnection() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isQueryingPrinter)
                    .help("C-ECHO the printer AE")

                    Button("Status") {
                        Task { await viewModel.queryPrinterStatus() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isQueryingPrinter)
                    .help("Query printer status (N-GET)")
                }
                .controlSize(.small)

                if viewModel.isQueryingPrinter {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Querying the printer…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let status = viewModel.printerStatus {
                    Label(
                        "Printer status: \(status.status)"
                            + (status.statusInfo.map { " (\($0))" } ?? ""),
                        systemImage: status.isNormal
                            ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(status.isNormal ? .green : .orange)
                    .lineLimit(2)
                } else if let message = viewModel.printerQueryMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: Basic settings

    private var basicSection: some View {
        bandGroup("Film") {
            stackedControl("Layout") {
                Picker("Layout mode", selection: $viewModel.layoutMode) {
                    ForEach(PrintViewModel.LayoutMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            switch viewModel.layoutMode {
            case .matchViewer, .automatic:
                EmptyView()
            case .explicit:
                stackedControl("Grid") {
                    Picker("Grid", selection: $viewModel.layoutOption) {
                        ForEach(PrintLayoutOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                }
            case .template:
                stackedControl("Preset") {
                    Picker("Preset", selection: $viewModel.templatePreset) {
                        ForEach(PrintTemplatePreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .labelsHidden()
                }
            }

            stackedControl("Film size") {
                Picker("Film size", selection: $viewModel.filmSize) {
                    ForEach(PrintOptionCatalog.filmSizes, id: \.cliToken) { entry in
                        Text(entry.label).tag(entry.value)
                    }
                }
                .labelsHidden()
                .disabled(viewModel.layoutMode == .template)
            }

            stackedControl("Orientation") {
                Picker("Orientation", selection: $viewModel.filmOrientation) {
                    ForEach(PrintOptionCatalog.orientations, id: \.cliToken) { entry in
                        Text(entry.label).tag(entry.value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .disabled(viewModel.layoutMode == .template)
            }

            stackedControl("Copies") {
                Stepper(value: $viewModel.copies, in: 1...99) {
                    Text("\(viewModel.copies)")
                        .monospacedDigit()
                }
                .controlSize(.small)
            }

            Text(layoutCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One line explaining what the chosen layout mode will do.
    private var layoutCaption: String {
        switch viewModel.layoutMode {
        case .matchViewer:
            if let viewerLayout = viewModel.viewerLayout {
                return "Matching the viewer's \(viewerLayout.rows)×\(viewerLayout.columns) grid"
            }
            return "No viewer grid — falling back to automatic"
        case .automatic:
            return "Grid chosen to fit \(viewModel.selection.count) image(s)"
        case .explicit:
            return "Fixed grid"
        case .template:
            return "Film size and orientation are set by the preset."
        }
    }

    /// A caption beside its control, sized so a row of them lines up.
    @ViewBuilder
    private func labeledControl<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: Self.controlWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// A titled cluster of controls: the section's name, then its controls.
    @ViewBuilder
    private func bandGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    /// A titled block inside the Advanced disclosure.
    ///
    /// A plain header rather than a `GroupBox`: the disclosure already sits inside
    /// a card, and a box inside a box inside a card is three borders deep for one
    /// row of pickers.
    @ViewBuilder
    private func subsection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        FilmPreviewView(viewModel: viewModel)
            // Tight to the panel: the film is the thing being judged, and every
            // point of padding is a point it cannot use. Its own aspect ratio
            // still decides its shape.
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    // MARK: Cell inspector

    /// Window/level and arrangement of the cell picked in the preview.
    ///
    /// A column beside the film rather than a strip beneath it: the film is what
    /// is being judged and height is what it needs most, so these controls take
    /// width instead. Every control here writes into the mark, so what it
    /// changes is what prints.
    private var inspectorSidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                bandGroup("Cell") { cellInspector }
                Divider()
                bandGroup(annotationSectionTitle) { annotationInspector }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: Self.inspectorWidth, alignment: .leading)
        }
        .frame(width: Self.inspectorWidth)
    }

    /// The annotation section says whether it is editing something or setting up
    /// the next thing drawn — the controls are the same either way, and without
    /// the distinction it is unclear what a change is about to affect.
    private var annotationSectionTitle: String {
        viewModel.selectedAnnotation == nil ? "New annotations" : "Annotation"
    }

    // MARK: Annotations

    /// Text, size and colour of the selected annotation — or, with nothing
    /// selected, of the next one drawn.
    @ViewBuilder
    private var annotationInspector: some View {
        let selected = viewModel.selectedAnnotation

        VStack(alignment: .leading, spacing: 8) {
            if let selected, selected.annotation.kind == .text {
                stackedControl("Text") {
                    TextField("Type the annotation", text: annotationTextBinding(selected))
                        .focused($isAnnotationTextFocused)
                        .onSubmit { isAnnotationTextFocused = false }
                }
            }

            stackedControl("Size") {
                HStack(spacing: 6) {
                    Slider(
                        value: annotationScaleBinding(selected),
                        in: PrintOverlayAnnotation.minimumScale...PrintOverlayAnnotation.maximumScale)
                    Text(annotationSizeLabel(selected))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            stackedControl("Colour") {
                HStack(spacing: 6) {
                    ForEach(Self.annotationSwatches, id: \.name) { swatch in
                        swatchButton(swatch, selected: selected)
                    }
                    Spacer(minLength: 0)
                    ColorPicker("Colour", selection: annotationColorBinding(selected))
                        .labelsHidden()
                }
            }

            if viewModel.resolvedColorMode == .grayscale {
                Text("This printer prints in greys — a colour is burned in at its "
                     + "own brightness, not as a colour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let selected {
                HStack(spacing: 6) {
                    Button("Delete") {
                        viewModel.removeAnnotation(selected.annotation.id,
                                                   forItemID: selected.itemID)
                    }
                    .frame(maxWidth: .infinity)
                    .help("Remove this annotation (⌫)")

                    Button("Clear Cell") {
                        viewModel.clearAnnotations(forItemID: selected.itemID)
                    }
                    .frame(maxWidth: .infinity)
                    .help("Remove every annotation from this cell")
                }
                .controlSize(.small)
            } else {
                Text(viewModel.cellTool.isDrawing
                     ? (viewModel.cellTool == .text
                        ? "Click a cell to place text."
                        : "Drag on a cell to draw an arrow.")
                     : "Pick the text (T) or arrow (R) tool, then draw on a cell.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.hasAnnotations {
                    Button("Clear All Annotations", role: .destructive) {
                        viewModel.clearAllAnnotations()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    /// One colour swatch. The reading-room set: yellow reads over lung and over
    /// mediastinum, and the rest are there for telling two arrows apart.
    private func swatchButton(
        _ swatch: (name: String, color: PrintOverlayColor),
        selected: (itemID: String, annotation: PrintOverlayAnnotation)?
    ) -> some View {
        let current = selected?.annotation.color ?? viewModel.annotationColor
        let isCurrent = current == swatch.color
        return Button {
            apply(color: swatch.color, to: selected)
        } label: {
            Circle()
                .fill(Color(red: swatch.color.red,
                            green: swatch.color.green,
                            blue: swatch.color.blue))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().strokeBorder(isCurrent ? Color.accentColor : .secondary.opacity(0.4),
                                          lineWidth: isCurrent ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
        .help(swatch.name)
    }

    private static let annotationSwatches: [(name: String, color: PrintOverlayColor)] = [
        ("Yellow", .yellow), ("White", .white), ("Red", .red),
        ("Green", .green), ("Cyan", .cyan)
    ]

    /// Writes a colour to the selected annotation, or to the next one drawn.
    private func apply(
        color: PrintOverlayColor,
        to selected: (itemID: String, annotation: PrintOverlayAnnotation)?
    ) {
        if let selected {
            viewModel.setAnnotationColor(color, id: selected.annotation.id,
                                         forItemID: selected.itemID)
        } else {
            viewModel.annotationColor = color
        }
    }

    private func annotationTextBinding(
        _ selected: (itemID: String, annotation: PrintOverlayAnnotation)
    ) -> Binding<String> {
        Binding(
            get: {
                viewModel.annotations(forItemID: selected.itemID)
                    .first { $0.id == selected.annotation.id }?.text ?? ""
            },
            set: { newValue in
                viewModel.setAnnotationText(newValue, id: selected.annotation.id,
                                            forItemID: selected.itemID)
            }
        )
    }

    /// Size of the selected annotation, or the size the next one will be drawn at.
    private func annotationScaleBinding(
        _ selected: (itemID: String, annotation: PrintOverlayAnnotation)?
    ) -> Binding<Double> {
        Binding(
            get: {
                guard let selected else { return viewModel.annotationScale }
                return viewModel.annotations(forItemID: selected.itemID)
                    .first { $0.id == selected.annotation.id }?.scale ?? viewModel.annotationScale
            },
            set: { newValue in
                guard let selected else {
                    viewModel.annotationScale = PrintOverlayAnnotation.clampScale(newValue)
                    return
                }
                viewModel.setAnnotationScale(newValue, id: selected.annotation.id,
                                             forItemID: selected.itemID)
            }
        )
    }

    private func annotationColorBinding(
        _ selected: (itemID: String, annotation: PrintOverlayAnnotation)?
    ) -> Binding<Color> {
        Binding(
            get: {
                let color = selected?.annotation.color ?? viewModel.annotationColor
                return Color(red: color.red, green: color.green, blue: color.blue)
            },
            set: { newValue in
                guard let overlayColor = PrintOverlayColor(newValue) else { return }
                apply(color: overlayColor, to: selected)
            }
        )
    }

    /// Size as a percentage of the image's height — the unit it is actually
    /// stored in, so what the slider says is what gets burned in.
    private func annotationSizeLabel(
        _ selected: (itemID: String, annotation: PrintOverlayAnnotation)?
    ) -> String {
        let scale = annotationScaleBinding(selected).wrappedValue
        return "\(Int((scale * 100).rounded()))%"
    }

    @ViewBuilder
    private var cellInspector: some View {
        if let focused = viewModel.focusedItem {
            VStack(alignment: .leading, spacing: 8) {
                Text(focused.displayLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    labeledControl("Center") {
                        TextField("Center", value: windowCenterBinding(focused), format: .number)
                            .frame(width: 80)
                            .monospacedDigit()
                    }
                    labeledControl("Width") {
                        TextField("Width", value: windowWidthBinding(focused), format: .number)
                            .frame(width: 80)
                            .monospacedDigit()
                    }

                    Menu("Presets") {
                        ForEach(WindowLevelPresets.allPresets) { preset in
                            Button("\(preset.modality) \(preset.name)  "
                                   + "\(Int(preset.center))/\(Int(preset.width))") {
                                viewModel.applyWindowPreset(preset, toItemID: focused.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button("Apply to All") { viewModel.applyFocusedWindowToAllCells() }
                        .help("Give every image on film this window")
                        .disabled(viewModel.window(forItemID: focused.id) == nil)

                    Button("Revert") { viewModel.revertCell(forItemID: focused.id) }
                        .help("Undo the adjustments made here, back to how the viewer left it")
                        .disabled(!viewModel.isCellAdjusted(focused.id))

                    Button("Reset Cell") { viewModel.resetCell(forItemID: focused.id) }
                        .help("Back to the untouched frame: the file's own window, no crop")
                        .disabled(!viewModel.isCellEdited(focused))
                }
                .controlSize(.small)
                .disabled(viewModel.isCellWindowingOverridden)

                if let reason = viewModel.cellWindowingBlockedReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if viewModel.useExplicitWindow && !viewModel.sendRawPixels {
                        Button("Use Per-Image Windows") {
                            viewModel.useExplicitWindow = false
                        }
                        .controlSize(.small)
                    }
                } else {
                    Text("Drag on a cell to \(viewModel.cellTool.displayName.lowercased()) it."
                         + (viewModel.isCellAdjusted(focused.id)
                            ? " This cell no longer follows the viewer." : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                arrangementToggle
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Click a film cell to window or arrange it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                arrangementToggle
            }
        }
    }

    /// Arrangement is a job-wide switch, not a windowing control, so a window
    /// override must not grey it out — and it stays reachable with no cell
    /// focused.
    private var arrangementToggle: some View {
        Toggle("Viewer arrangement", isOn: $viewModel.useViewerPresentation)
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .help("Print each image zoomed, rotated and flipped as the viewer showed it")
    }

    /// Editing binding for the focused cell's window centre.
    ///
    /// Reads the mark and writes straight back to it — there is no separate
    /// editing copy that could drift from what prints.
    private func windowCenterBinding(_ item: PrintSelectionItem) -> Binding<Double> {
        Binding(
            get: { viewModel.window(forItemID: item.id)?.center ?? 0 },
            set: { newValue in
                let width = viewModel.window(forItemID: item.id)?.width ?? 400
                viewModel.setWindow(forItemID: item.id, center: newValue, width: width)
            }
        )
    }

    private func windowWidthBinding(_ item: PrintSelectionItem) -> Binding<Double> {
        Binding(
            get: { viewModel.window(forItemID: item.id)?.width ?? 0 },
            set: { newValue in
                let center = viewModel.window(forItemID: item.id)?.center ?? 0
                viewModel.setWindow(forItemID: item.id, center: center, width: newValue)
            }
        )
    }

    // MARK: Marks

    /// The marked images. Film order is the viewer's order, so it is reported
    /// here rather than edited — reordering happens on screen, by arranging the
    /// tiles the film is meant to reproduce.
    private var marksSection: some View {
        bandGroup("Images (\(viewModel.selection.count))") {
            if viewModel.selection.isEmpty {
                Text("Mark images in the viewer, then return here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Button("Show List…") { showImageList = true }
                        .frame(maxWidth: .infinity)
                        .popover(isPresented: $showImageList, arrowEdge: .bottom) {
                            imageListPopover
                        }
                    Button("Clear All", role: .destructive) {
                        viewModel.selection.clear()
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.small)

                Text("In viewer order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var imageListPopover: some View {
        List {
            ForEach(Array(viewModel.selection.items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    Text(item.displayLabel)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .onDelete { offsets in
                viewModel.selection.remove(atOffsets: offsets)
            }
        }
        .frame(width: 320, height: 240)
    }

    // MARK: Advanced

    private var advancedSection: some View {
        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
            // Stacked in the settings column: it is already scrolling, so
            // expanding these can never push the film out of the centre.
            VStack(alignment: .leading, spacing: 10) {
                filmAdvanced
                Divider()
                imageAdvanced
                Divider()
                renderingAdvanced
                Divider()
                executionAdvanced
            }
            .padding(.top, 8)
        }
        .font(.caption)
    }

    private var filmAdvanced: some View {
        subsection("Film session") {
            VStack(alignment: .leading, spacing: 8) {
                stackedControl("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(PrintOptionCatalog.priorities, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Medium") {
                    Picker("Medium", selection: $viewModel.mediumType) {
                        ForEach(PrintOptionCatalog.mediumTypes, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Destination") {
                    Picker("Destination", selection: $viewModel.filmDestination) {
                        ForEach(PrintOptionCatalog.filmDestinations, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Session label") {
                    TextField("Optional", text: $viewModel.sessionLabel)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var imageAdvanced: some View {
        subsection("Film box & image box") {
            VStack(alignment: .leading, spacing: 8) {
                stackedControl("Magnification") {
                    Picker("Magnification", selection: $viewModel.magnificationType) {
                        ForEach(PrintOptionCatalog.magnificationTypes, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Trim") {
                    Picker("Trim", selection: $viewModel.trimOption) {
                        ForEach(PrintOptionCatalog.trimOptions, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Border density") {
                    Picker("Border density", selection: $viewModel.borderDensity) {
                        ForEach(PrintOptionCatalog.densities, id: \.self) { density in
                            Text(density.capitalized).tag(density)
                        }
                    }.labelsHidden()
                }
                stackedControl("Empty cells") {
                    Picker("Empty image density", selection: $viewModel.emptyImageDensity) {
                        ForEach(PrintOptionCatalog.densities, id: \.self) { density in
                            Text(density.capitalized).tag(density)
                        }
                    }.labelsHidden()
                }
                stackedControl("Polarity") {
                    Picker("Polarity", selection: $viewModel.polarity) {
                        ForEach(PrintOptionCatalog.polarities, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden()
                }
                stackedControl("Configuration info") {
                    TextField("Printer-specific", text: $viewModel.configurationInformation)
                }
                stackedControl("Annotation format ID") {
                    TextField("Required for annotations", text: $viewModel.annotationDisplayFormatID)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A caption above its control, for the settings column — a label beside the
    /// control needs width the column does not have.
    @ViewBuilder
    private func stackedControl<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity)
        }
    }

    private var renderingAdvanced: some View {
        subsection("Rendering") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Auto-detect color mode from the printer", isOn: $viewModel.autoDetectColorMode)
                if !viewModel.autoDetectColorMode {
                    stackedControl("Color mode") {
                        Picker("Color mode", selection: $viewModel.colorMode) {
                            ForEach(PrintOptionCatalog.colorModes, id: \.cliToken) { entry in
                                Text(entry.label).tag(entry.value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                Toggle("Match the viewer's window/level", isOn: $viewModel.useViewerWindow)
                Toggle("Match the viewer's zoom, rotation and flip",
                       isOn: $viewModel.useViewerPresentation)
                    .help("Prints the region and orientation you arranged on screen, "
                          + "cropped from the full-resolution frame.")
                    .disabled(viewModel.sendRawPixels || viewModel.useExplicitWindow)
                    .help("Prints what is on screen rather than the file's stored window")

                Toggle("Use an explicit window", isOn: $viewModel.useExplicitWindow)
                    .disabled(viewModel.sendRawPixels)
                if viewModel.useExplicitWindow && !viewModel.sendRawPixels {
                    HStack {
                        TextField("Center", value: $viewModel.explicitWindowCenter, format: .number)
                            .frame(width: 100)
                        TextField("Width", value: $viewModel.explicitWindowWidth, format: .number)
                            .frame(width: 100)
                    }
                }

                stackedControl("Grayscale bit depth") {
                    Picker("Grayscale bit depth", selection: $viewModel.bitDepth) {
                        ForEach(PrintOptionCatalog.bitDepths, id: \.self) { depth in
                            Text("\(depth)-bit").tag(depth)
                        }
                    }
                    .labelsHidden()
                    .disabled(viewModel.sendRawPixels)
                }

                stackedControl("Presentation LUT") {
                    Picker("Presentation LUT", selection: $viewModel.presentationLUTShape) {
                        Text("None").tag(DICOMNetwork.PresentationLUTShape?.none)
                        ForEach(PrintOptionCatalog.presentationLUTShapes, id: \.cliToken) { entry in
                            Text(entry.label).tag(Optional(entry.value))
                        }
                    }
                    .labelsHidden()
                }

                Toggle("Send stored pixels unprocessed (raw)", isOn: $viewModel.sendRawPixels)
                    .help("No rescale, window, or inversion. Compressed sources are still decoded.")
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var executionAdvanced: some View {
        subsection("Execution") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Check printer status before printing", isOn: $viewModel.checkStatusBeforePrinting)
                    .help("Aborts on FAILURE, warns on WARNING")
                Toggle("Verify with C-ECHO before printing", isOn: $viewModel.verifyBeforePrinting)
                Toggle("Dry run (build the film plan, send nothing)", isOn: $viewModel.dryRun)
                Stepper(value: $viewModel.retries, in: 0...5) {
                    Text("Retries: \(viewModel.retries)")
                }
                .help("Retries on connection failure")
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !viewModel.history.isEmpty, viewModel.phase == .configuring {
                Menu("Recent Jobs") {
                    ForEach(viewModel.history.prefix(10)) { entry in
                        Text("\(entry.success ? "✓" : "✗") \(entry.summary)")
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 140)
            }

            Spacer()

            switch viewModel.phase {
            case .configuring:
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(viewModel.dryRun ? "Dry Run" : "Print") {
                    viewModel.print()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canPrint)
            case .preparing, .printing:
                Button("Cancel Job", role: .destructive) { viewModel.cancel() }
            case .finished:
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                Button("Print Again") { viewModel.reset() }
            }
        }
        .padding()
    }
}
#endif
