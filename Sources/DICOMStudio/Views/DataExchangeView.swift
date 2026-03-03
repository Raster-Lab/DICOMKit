// DataExchangeView.swift
// DICOMStudio
//
// DICOM Studio — Data exchange, conversion, and developer tools view

#if canImport(SwiftUI)
import SwiftUI

/// Data exchange view providing JSON/XML conversion, image export,
/// transfer syntax conversion, DICOMDIR creation, PDF encapsulation,
/// and batch operations.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct DataExchangeView: View {
    @Bindable var viewModel: DataExchangeViewModel

    public init(viewModel: DataExchangeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Processing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DataExchangeTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.activeTab = tab
                    } label: {
                        Label(tab.displayName, systemImage: tab.sfSymbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.activeTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.displayName)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .jsonConversion:
            jsonConversionContent
        case .xmlConversion:
            xmlConversionContent
        case .imageExport:
            imageExportContent
        case .transferSyntax:
            transferSyntaxContent
        case .dicomdir:
            dicomdirContent
        case .pdfEncapsulation:
            pdfContent
        case .batchOperations:
            batchContent
        }
    }

    // MARK: - JSON Conversion

    private var jsonConversionContent: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("DICOM → JSON")
                    .font(.headline)

                GroupBox("Input") {
                    HStack {
                        TextField("DICOM file path", text: $viewModel.jsonInputFilePath)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("DICOM input file path")
                        Button("Browse…") {
                            viewModel.isJSONExportSheetPresented = true
                        }
                        .accessibilityLabel("Browse for DICOM file")
                    }
                }

                GroupBox("Settings") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Format", selection: $viewModel.jsonSettings.outputFormat) {
                            Text("Standard").tag(JSONOutputFormat.standard)
                            Text("Pretty").tag(JSONOutputFormat.pretty)
                            Text("Compact").tag(JSONOutputFormat.compact)
                        }
                        .accessibilityLabel("JSON output format")

                        Toggle("Include bulk data URIs", isOn: $viewModel.jsonSettings.includeBulkDataURIs)
                            .accessibilityLabel("Include bulk data URIs in JSON output")
                        Toggle("Metadata only", isOn: $viewModel.jsonSettings.metadataOnly)
                            .accessibilityLabel("Export metadata only")
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 250)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output")
                        .font(.headline)
                    Spacer()
                    Button("Clear") {
                        viewModel.clearJSONOutput()
                    }
                    .disabled(viewModel.jsonOutput.isEmpty)
                    .accessibilityLabel("Clear JSON output")
                }

                if viewModel.jsonOutput.isEmpty {
                    ContentUnavailableView(
                        "No Output",
                        systemImage: "doc.text",
                        description: Text("Select a DICOM file and convert to see JSON output.")
                    )
                } else {
                    ScrollView {
                        Text(viewModel.jsonOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding()
        }
    }

    // MARK: - XML Conversion

    private var xmlConversionContent: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("DICOM → XML")
                    .font(.headline)

                GroupBox("Input") {
                    HStack {
                        TextField("DICOM file path", text: $viewModel.xmlInputFilePath)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("DICOM input file path for XML")
                        Button("Browse…") {
                            viewModel.isXMLExportSheetPresented = true
                        }
                        .accessibilityLabel("Browse for DICOM file")
                    }
                }

                GroupBox("Settings") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Format", selection: $viewModel.xmlSettings.outputFormat) {
                            Text("Standard").tag(XMLOutputFormat.standard)
                            Text("Pretty").tag(XMLOutputFormat.pretty)
                            Text("No Keywords").tag(XMLOutputFormat.noKeywords)
                        }
                        .accessibilityLabel("XML output format")

                        Toggle("Include bulk data URIs", isOn: $viewModel.xmlSettings.includeBulkDataURIs)
                        Toggle("Metadata only", isOn: $viewModel.xmlSettings.metadataOnly)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 250)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output")
                        .font(.headline)
                    Spacer()
                    Button("Clear") { viewModel.clearXMLOutput() }
                        .disabled(viewModel.xmlOutput.isEmpty)
                }

                if viewModel.xmlOutput.isEmpty {
                    ContentUnavailableView(
                        "No Output",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        description: Text("Select a DICOM file to convert to XML.")
                    )
                } else {
                    ScrollView {
                        Text(viewModel.xmlOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding()
        }
    }

    // MARK: - Image Export

    private var imageExportContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Image Export")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Source") {
                        HStack {
                            TextField("DICOM file path", text: $viewModel.imageInputFilePath)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("DICOM image source path")
                            Button("Browse…") {
                                viewModel.isImageExportSheetPresented = true
                            }
                        }
                    }

                    GroupBox("Export Settings") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Format", selection: $viewModel.imageExportSettings.format) {
                                Text("PNG").tag(ImageExportFormat.png)
                                Text("JPEG").tag(ImageExportFormat.jpeg)
                                Text("TIFF").tag(ImageExportFormat.tiff)
                            }
                            .accessibilityLabel("Export image format")

                            Picker("Resolution", selection: $viewModel.imageExportSettings.resolution) {
                                Text("Original").tag(ImageExportResolution.original)
                                Text("Half").tag(ImageExportResolution.half)
                                Text("Quarter").tag(ImageExportResolution.quarter)
                            }
                            .accessibilityLabel("Export resolution")

                            Toggle("Burn in window/level", isOn: $viewModel.imageExportSettings.burnInWindowLevel)
                            Toggle("Burn in annotations", isOn: $viewModel.imageExportSettings.burnInAnnotations)
                            Toggle("Export all frames", isOn: $viewModel.imageExportSettings.exportAllFrames)
                        }
                    }

                    Spacer()
                }
                .frame(minWidth: 250, maxWidth: 300)
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Exported Images")
                        .font(.headline)

                    if viewModel.exportedImagePaths.isEmpty {
                        ContentUnavailableView(
                            "No Exports",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text("Export images from a DICOM file to view them here.")
                        )
                    } else {
                        List(viewModel.exportedImagePaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                                Text(path)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Transfer Syntax

    private var transferSyntaxContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transfer Syntax Conversion")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddConversionJobSheetPresented = true
                } label: {
                    Label("Add Job", systemImage: "plus")
                }
                .accessibilityLabel("Add conversion job")
            }
            .padding()

            Divider()

            if viewModel.conversionJobs.isEmpty {
                ContentUnavailableView(
                    "No Conversion Jobs",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Add transfer syntax conversion jobs to convert between DICOM encoding formats.")
                )
            } else {
                List(viewModel.conversionJobs, id: \.id) { job in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.sourceFilePath)
                                .font(.body)
                                .lineLimit(1)
                            HStack {
                                Text("→")
                                    .font(.caption)
                                Text(job.targetTransferSyntaxUID)
                                    .font(.caption.monospaced())
                            }
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(job.status.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - DICOMDIR

    private var dicomdirContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DICOMDIR Creation")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddDICOMDIREntrySheetPresented = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .accessibilityLabel("Add DICOMDIR entry")
            }
            .padding()

            GroupBox("Output Path") {
                TextField("DICOMDIR output path", text: $viewModel.dicomdirOutputPath)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("DICOMDIR output directory path")
            }
            .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            if viewModel.dicomdirEntries.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "folder.badge.plus",
                    description: Text("Add DICOM files to create a DICOMDIR media directory.")
                )
            } else {
                List(viewModel.dicomdirEntries, id: \.id) { entry in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.patientName)
                                .font(.body)
                            Text("\(entry.modalities.joined(separator: ", ")) • \(entry.seriesCount) series • \(entry.instanceCount) instances")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - PDF Encapsulation

    private var pdfContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PDF Encapsulation")
                    .font(.headline)
                Spacer()

                Picker("Mode", selection: $viewModel.pdfMode) {
                    ForEach(PDFEncapsulationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 200)
                .accessibilityLabel("PDF encapsulation mode")
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("PDF File") {
                        HStack {
                            TextField("PDF file path", text: $viewModel.pdfInputPath)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("PDF input file path")
                        }
                    }

                    GroupBox("DICOM Output") {
                        HStack {
                            TextField("Output DICOM path", text: $viewModel.pdfOutputPath)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("DICOM output file path")
                        }
                    }

                    GroupBox("Patient Information") {
                        VStack(spacing: 8) {
                            TextField("Patient Name", text: $viewModel.pdfPatientName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Patient name for PDF encapsulation")
                            TextField("Patient ID", text: $viewModel.pdfPatientID)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Patient ID for PDF encapsulation")
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Batch Operations

    private var batchContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Batch Operations")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.isAddBatchJobSheetPresented = true
                } label: {
                    Label("New Batch", systemImage: "plus")
                }
                .accessibilityLabel("Create new batch job")
            }
            .padding()

            Divider()

            if viewModel.batchJobs.isEmpty {
                ContentUnavailableView(
                    "No Batch Jobs",
                    systemImage: "square.stack.3d.up",
                    description: Text("Create batch jobs to process multiple DICOM files simultaneously.")
                )
            } else {
                List(viewModel.batchJobs, id: \.id) { job in
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.operationType.rawValue)
                                .font(.body)
                            Text("\(job.totalCount) files • \(job.operationType.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if job.totalCount > 0 {
                            let progress = Double(job.processedCount) / Double(job.totalCount)
                            if progress > 0 && progress < 1.0 {
                                ProgressView(value: progress)
                                    .frame(width: 80)
                            }
                        }
                        Text(job.status.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
#endif
