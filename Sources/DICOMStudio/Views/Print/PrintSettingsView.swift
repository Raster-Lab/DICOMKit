// PrintSettingsView.swift
// DICOMStudio
//
// DICOM Studio — the print sheet: pick a printer and layout, check the film
// plan, and send the marked images to the DICOM printer.
//
// Every option lives in a band across the top; the whole centre belongs to the
// film preview, which is the thing actually being judged.
//
// Visible zone: printer, layout, orientation, film size, copies, preview.
// Advanced zone: everything else the dicom-print CLI exposes.

#if canImport(SwiftUI)
import SwiftUI
import DICOMNetwork
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct PrintSettingsView: View {
    @Bindable var viewModel: PrintViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAdvanced = false
    @State private var showPrinterManagement = false
    @State private var showImageList = false

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
        // Match the screen it was raised from; fall back to a size wide enough
        // that the options band fits without scrolling.
        .frame(
            minWidth: max(960, parentSize?.width ?? 0),
            minHeight: max(640, parentSize?.height ?? 0)
        )
        .sheet(isPresented: $showPrinterManagement) {
            PrinterManagementView(viewModel: viewModel)
        }
    }

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

    /// Options across the top, film everywhere below.
    ///
    /// The preview is the thing being judged, so it gets the whole centre: the
    /// controls live in one band that scrolls sideways rather than a column that
    /// eats width the film needs.
    private var configurationForm: some View {
        VStack(spacing: 0) {
            optionsBand

            Divider()

            previewSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The band of controls pinned to the top of the sheet.
    private var optionsBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    printerSection
                    bandDivider
                    basicSection
                    bandDivider
                    marksSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            }

            advancedSection
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
    }

    private var bandDivider: some View {
        Divider().frame(height: Self.bandRowHeight)
    }

    /// Height of one row of band controls, used to size the separators.
    private static let bandRowHeight: CGFloat = 54

    /// Widest a picker in the band grows to.
    private static let controlWidth: CGFloat = 180

    // MARK: Printer

    private var printerSection: some View {
        bandGroup("Printer") {
            if viewModel.printers.isEmpty {
                HStack {
                    Text("No printers configured.")
                        .foregroundStyle(.secondary)
                    Button("Add Printer…") { showPrinterManagement = true }
                        .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Picker("Printer", selection: $viewModel.selectedPrinterID) {
                        ForEach(viewModel.printers) { printer in
                            Text(printer.summary).tag(Optional(printer.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    Button("Manage…") { showPrinterManagement = true }
                        .help("Add, edit, or remove printers")

                    Button("Test") {
                        Task { await viewModel.testConnection() }
                    }
                    .disabled(viewModel.isQueryingPrinter)
                    .help("C-ECHO the printer AE")

                    Button("Status") {
                        Task { await viewModel.queryPrinterStatus() }
                    }
                    .disabled(viewModel.isQueryingPrinter)
                    .help("Query printer status (N-GET)")

                    if viewModel.isQueryingPrinter {
                        ProgressView().controlSize(.small)
                    }
                }
                .controlSize(.small)

                if let status = viewModel.printerStatus {
                    Label(
                        "Printer status: \(status.status)"
                            + (status.statusInfo.map { " (\($0))" } ?? ""),
                        systemImage: status.isNormal
                            ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(status.isNormal ? .green : .orange)
                    .lineLimit(1)
                } else if let message = viewModel.printerQueryMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: Basic settings

    private var basicSection: some View {
        bandGroup("Film") {
            HStack(alignment: .center, spacing: 12) {
                Picker("Layout mode", selection: $viewModel.layoutMode) {
                    ForEach(PrintViewModel.LayoutMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)

                switch viewModel.layoutMode {
                case .matchViewer, .automatic:
                    EmptyView()
                case .explicit:
                    labeledControl("Grid") {
                        Picker("Grid", selection: $viewModel.layoutOption) {
                            ForEach(PrintLayoutOption.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .labelsHidden()
                    }
                case .template:
                    labeledControl("Preset") {
                        Picker("Preset", selection: $viewModel.templatePreset) {
                            ForEach(PrintTemplatePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .labelsHidden()
                    }
                }

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

                labeledControl("Copies") {
                    Stepper(value: $viewModel.copies, in: 1...99) {
                        Text("\(viewModel.copies)")
                            .monospacedDigit()
                    }
                }
            }

            Text(layoutCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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

    /// A titled cluster of band controls — a GroupBox would stack the band too
    /// tall for the room the film needs.
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

    // MARK: Preview

    private var previewSection: some View {
        FilmPreviewView(plan: viewModel.plan, items: viewModel.selection.items)
            .padding(16)
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
                HStack(spacing: 8) {
                    Button("Show List…") { showImageList = true }
                        .popover(isPresented: $showImageList, arrowEdge: .bottom) {
                            imageListPopover
                        }
                    Button("Clear All", role: .destructive) {
                        viewModel.selection.clear()
                    }
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
            // Side by side and height-capped: expanding the advanced options
            // must not push the film off the bottom of the sheet.
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    filmAdvanced
                    imageAdvanced
                    renderingAdvanced
                    executionAdvanced
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)
        }
    }

    private var filmAdvanced: some View {
        GroupBox("Film session") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Priority")
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(PrintOptionCatalog.priorities, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Medium")
                    Picker("Medium", selection: $viewModel.mediumType) {
                        ForEach(PrintOptionCatalog.mediumTypes, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Destination")
                    Picker("Destination", selection: $viewModel.filmDestination) {
                        ForEach(PrintOptionCatalog.filmDestinations, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Session label")
                    TextField("Optional", text: $viewModel.sessionLabel)
                        .frame(width: 220)
                }
            }
            .padding(4)
        }
    }

    private var imageAdvanced: some View {
        GroupBox("Film box & image box") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Magnification")
                    Picker("Magnification", selection: $viewModel.magnificationType) {
                        ForEach(PrintOptionCatalog.magnificationTypes, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Trim")
                    Picker("Trim", selection: $viewModel.trimOption) {
                        ForEach(PrintOptionCatalog.trimOptions, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Border density")
                    Picker("Border density", selection: $viewModel.borderDensity) {
                        ForEach(PrintOptionCatalog.densities, id: \.self) { density in
                            Text(density.capitalized).tag(density)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Empty cells")
                    Picker("Empty image density", selection: $viewModel.emptyImageDensity) {
                        ForEach(PrintOptionCatalog.densities, id: \.self) { density in
                            Text(density.capitalized).tag(density)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Polarity")
                    Picker("Polarity", selection: $viewModel.polarity) {
                        ForEach(PrintOptionCatalog.polarities, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }.labelsHidden().frame(width: 220)
                }
                GridRow {
                    Text("Configuration info")
                    TextField("Printer-specific", text: $viewModel.configurationInformation)
                        .frame(width: 220)
                }
                GridRow {
                    Text("Annotation format ID")
                    TextField("Required for annotations", text: $viewModel.annotationDisplayFormatID)
                        .frame(width: 220)
                }
            }
            .padding(4)
        }
    }

    private var renderingAdvanced: some View {
        GroupBox("Rendering") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Auto-detect color mode from the printer", isOn: $viewModel.autoDetectColorMode)
                if !viewModel.autoDetectColorMode {
                    Picker("Color mode", selection: $viewModel.colorMode) {
                        ForEach(PrintOptionCatalog.colorModes, id: \.cliToken) { entry in
                            Text(entry.label).tag(entry.value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
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

                Picker("Grayscale bit depth", selection: $viewModel.bitDepth) {
                    ForEach(PrintOptionCatalog.bitDepths, id: \.self) { depth in
                        Text("\(depth)-bit").tag(depth)
                    }
                }
                .frame(width: 260)
                .disabled(viewModel.sendRawPixels)

                Picker("Presentation LUT", selection: $viewModel.presentationLUTShape) {
                    Text("None").tag(DICOMNetwork.PresentationLUTShape?.none)
                    ForEach(PrintOptionCatalog.presentationLUTShapes, id: \.cliToken) { entry in
                        Text(entry.label).tag(Optional(entry.value))
                    }
                }
                .frame(width: 300)

                Toggle("Send stored pixels unprocessed (raw)", isOn: $viewModel.sendRawPixels)
                    .help("No rescale, window, or inversion. Compressed sources are still decoded.")
            }
            .padding(4)
        }
    }

    private var executionAdvanced: some View {
        GroupBox("Execution") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Check printer status before printing", isOn: $viewModel.checkStatusBeforePrinting)
                    .help("Aborts on FAILURE, warns on WARNING")
                Toggle("Verify with C-ECHO before printing", isOn: $viewModel.verifyBeforePrinting)
                Toggle("Dry run (build the film plan, send nothing)", isOn: $viewModel.dryRun)
                Stepper(value: $viewModel.retries, in: 0...5) {
                    Text("Retries on connection failure: \(viewModel.retries)")
                }
                .frame(width: 320)
            }
            .padding(4)
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
