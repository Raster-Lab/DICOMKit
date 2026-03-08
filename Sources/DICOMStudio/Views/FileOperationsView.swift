// FileOperationsView.swift
// DICOMStudio
//
// DICOM Studio — File Operations & Drag-and-Drop view (Milestone 22)

#if canImport(SwiftUI)
import SwiftUI

/// View for file operations including drag-and-drop input, output path configuration,
/// file validation and preview, and directory input support.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct FileOperationsView: View {
    @Bindable var viewModel: FileOperationsViewModel

    public init(viewModel: FileOperationsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            tabContent
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(FileOperationsTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.selectedTab = tab
                    } label: {
                        Label(tab.displayName, systemImage: tab.symbolName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
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

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .fileInput:
            fileInputTab
        case .outputPath:
            outputPathTab
        case .fileValidation:
            fileValidationTab
        case .directoryInput:
            directoryInputTab
        }
    }

    // MARK: - File Input Tab

    private var fileInputTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("File Input Controls")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)

                dropZoneView

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Drop Mode")
                        .font(.headline)
                    Picker("Drop Mode", selection: Binding(
                        get: { viewModel.dropZone.mode },
                        set: { viewModel.setDropMode($0) }
                    )) {
                        ForEach(FileDropMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Drop Mode Picker")
                }

                if !viewModel.dropZone.files.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dropped Files (\(viewModel.dropZone.files.count))")
                            .font(.headline)
                        ForEach(viewModel.dropZone.files) { file in
                            HStack {
                                Image(systemName: "doc")
                                Text(file.fileName)
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: file.fileSizeBytes, countStyle: .file))
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        Button("Clear Files") {
                            viewModel.clearFiles()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Clear all dropped files")
                    }
                }
            }
            .padding()
        }
    }

    private var dropZoneView: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                viewModel.dropZone.highlight == .active ? Color.accentColor : Color.secondary.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [6])
            )
            .frame(height: 160)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 36))
                        .foregroundStyle(viewModel.dropZone.highlight == .active ? Color.accentColor : Color.secondary)
                    Text("Drop DICOM files here")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("or use the file picker")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("DICOM file drop zone")
            .accessibilityHint("Drop DICOM files here to add them for processing")
    }

    // MARK: - Output Path Tab

    private var outputPathTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Output Path Configuration")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)

                GroupBox("Output File Path") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text(viewModel.outputPath.displayPath)
                                .foregroundStyle(viewModel.outputPath.resolvedURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if viewModel.outputPath.overwriteWarning {
                            Label("A file already exists at this path", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(4)
                }
                .accessibilityLabel("Output file path configuration")

                GroupBox("Output Directory") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder")
                            Text(viewModel.outputDirectory.displayPath)
                                .foregroundStyle(viewModel.outputDirectory.resolvedURL == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if let freeSpace = viewModel.outputDirectory.freeDiskSpaceBytes {
                            Label("Free space: \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))", systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }
                .accessibilityLabel("Output directory configuration")
            }
            .padding()
        }
    }

    // MARK: - File Validation Tab

    private var fileValidationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("File Validation & Preview")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)

                if let preview = viewModel.filePreview {
                    GroupBox("File Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("File Name", value: preview.fileName)
                            LabeledContent("File Size", value: ByteCountFormatter.string(fromByteCount: preview.fileSizeBytes, countStyle: .file))
                            if let modality = preview.modality {
                                LabeledContent("Modality", value: modality)
                            }
                            if let patientName = preview.patientName {
                                LabeledContent("Patient Name", value: patientName)
                            }
                            if let studyDate = preview.studyDate {
                                LabeledContent("Study Date", value: studyDate)
                            }
                            if !preview.warnings.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Warnings")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(preview.warnings) { warning in
                                        Label(warning.displayName, systemImage: "exclamationmark.triangle")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .padding(4)
                    }
                } else {
                    ContentUnavailableView(
                        "No File Selected",
                        systemImage: "doc.questionmark",
                        description: Text("Drop a DICOM file in the File Input tab to see validation details.")
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Directory Input Tab

    private var directoryInputTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Directory Input")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 4)

                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        viewModel.directoryDrop.highlight == .active ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.arrow.down")
                                .font(.system(size: 32))
                                .foregroundStyle(viewModel.directoryDrop.highlight == .active ? Color.accentColor : Color.secondary)
                            Text("Drop a folder here")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Directory drop zone")
                    .accessibilityHint("Drop a folder here to add all DICOM files it contains")

                if let dirURL = viewModel.directoryDrop.directoryURL {
                    GroupBox("Dropped Directory") {
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent("Path", value: dirURL.path)
                            LabeledContent("DICOM Files Found", value: "\(viewModel.directoryDrop.dicomFileCount)")
                            LabeledContent("Scan Mode", value: viewModel.directoryDrop.scanMode.displayName)
                        }
                        .padding(4)
                    }
                }
            }
            .padding()
        }
    }
}
#endif
