// FileOperationsViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for File Operations & Drag-and-Drop (Milestone 22)

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class FileOperationsViewModel {
    private let service: FileOperationsService

    // 22.1 File Input Controls
    public var dropZone: FileDropZoneState = FileDropZoneState()

    // 22.2 Output Path Controls
    public var outputPath: OutputPathConfig = OutputPathConfig()
    public var outputDirectory: OutputDirectoryConfig = OutputDirectoryConfig()

    // 22.3 File Validation & Preview
    public var filePreview: FilePreviewInfo? = nil

    // 22.4 Directory Input Support
    public var directoryDrop: DirectoryDropState = DirectoryDropState()

    // General
    public var selectedTab: FileOperationsTab = .fileInput
    public var associatedToolName: String = ""

    public init(service: FileOperationsService = FileOperationsService()) {
        self.service = service
        loadFromService()
    }

    /// Loads all state from the backing service into observable properties.
    public func loadFromService() {
        let state = service.getState()
        dropZone          = state.dropZone
        outputPath        = state.outputPath
        outputDirectory   = state.outputDirectory
        filePreview       = state.filePreview
        directoryDrop     = state.directoryDrop
        selectedTab       = state.selectedTab
        associatedToolName = state.associatedToolName
    }

    // MARK: - 22.1 File Input Controls

    /// Sets the drop zone mode (single or multiple).
    public func setDropMode(_ mode: FileDropMode) {
        service.setDropMode(mode)
        dropZone = service.getDropZone()
    }

    /// Called when a drag enters the drop zone.
    public func dragEntered() {
        service.setDropHighlight(.active)
        dropZone = service.getDropZone()
    }

    /// Called when a drag leaves the drop zone without dropping.
    public func dragExited() {
        service.setDropHighlight(.idle)
        dropZone = service.getDropZone()
    }

    /// Handles a file drop at the given URL.
    ///
    /// Returns `true` if the file was accepted, `false` if rejected.
    @discardableResult
    public func dropFile(url: URL) -> Bool {
        let result = service.addFile(url: url)
        loadFromService()
        return result != nil
    }

    /// Adds a pre-validated file directly (e.g. from the file picker).
    public func addFile(_ file: DroppedFile) {
        service.addDroppedFile(file)
        loadFromService()
    }

    /// Removes the file at the given index from the drop zone list.
    public func removeFile(at index: Int) {
        service.removeFile(at: index)
        dropZone    = service.getDropZone()
        filePreview = service.getFilePreview()
    }

    /// Moves a file within the list for reorder support.
    public func moveFile(fromIndex: Int, toIndex: Int) {
        service.moveFile(fromIndex: fromIndex, toIndex: toIndex)
        dropZone = service.getDropZone()
    }

    /// Clears all selected files.
    public func clearFiles() {
        service.clearFiles()
        loadFromService()
    }

    /// Rejects a drop and shows an appropriate message.
    public func rejectDrop(reason: String = "Only DICOM files are accepted.") {
        service.rejectDrop(reason: reason)
        dropZone = service.getDropZone()
    }

    // MARK: - 22.2 Output Path Controls

    /// Sets the CLI tool name associated with this panel (drives suggested filenames).
    public func setTool(_ toolName: String) {
        service.setTool(toolName)
        loadFromService()
    }

    /// Saves a user-selected custom output file URL.
    public func setCustomOutputURL(_ url: URL) {
        service.setCustomOutputURL(url)
        outputPath = service.getOutputPath()
    }

    /// Saves a user-selected custom output directory URL.
    public func setCustomOutputDirectory(_ url: URL) {
        service.setCustomOutputDirectory(url)
        outputDirectory = service.getOutputDirectory()
    }

    /// Resets the output path to the default derived from the current input.
    public func resetOutputPath() {
        service.resetOutputPath()
        outputPath = service.getOutputPath()
    }

    /// Whether an overwrite warning should be shown for the current output path.
    public var showOverwriteWarning: Bool { outputPath.overwriteWarning }

    /// The CLI command string for multi-file tools, using the current drop zone files.
    public var multiFileCommandArguments: String {
        OutputPathHelpers.fileArguments(for: dropZone.files.map(\.url))
    }

    // MARK: - 22.3 File Validation & Preview

    /// Updates the file preview manually (used when metadata is available asynchronously).
    public func setFilePreview(_ preview: FilePreviewInfo?) {
        service.setFilePreview(preview)
        filePreview = service.getFilePreview()
    }

    /// Human-readable file size for the currently previewed file.
    public var previewFileSizeDescription: String? {
        filePreview.map { DICOMFileDropHelpers.formattedFileSize($0.fileSizeBytes) }
    }

    /// Formatted study date for the currently previewed file.
    public var previewFormattedStudyDate: String? {
        guard let date = filePreview?.studyDate else { return nil }
        return FileValidationHelpers.formattedStudyDate(date)
    }

    /// Formatted patient name for the currently previewed file.
    public var previewFormattedPatientName: String? {
        guard let name = filePreview?.patientName else { return nil }
        return FileValidationHelpers.formattedPatientName(name)
    }

    /// SF Symbol name for the modality icon of the currently previewed file.
    public var previewModalitySymbol: String {
        DICOMFileDropHelpers.symbolName(for: filePreview?.modality)
    }

    // MARK: - 22.4 Directory Input Support

    /// Called when a drag enters the directory drop zone.
    public func directoryDragEntered() {
        service.setDirectoryDropHighlight(.active)
        directoryDrop = service.getDirectoryDrop()
    }

    /// Called when a drag exits the directory drop zone.
    public func directoryDragExited() {
        service.setDirectoryDropHighlight(.idle)
        directoryDrop = service.getDirectoryDrop()
    }

    /// Handles a directory drop at the given URL.
    public func dropDirectory(url: URL) {
        service.setDirectory(url)
        directoryDrop = service.getDirectoryDrop()
        // Sync output directory with the selected input directory.
        if directoryDrop.directoryURL != nil {
            service.setCustomOutputDirectory(
                url.appendingPathComponent("DICOMStudio Output", isDirectory: true)
            )
            outputDirectory = service.getOutputDirectory()
        }
    }

    /// Changes the directory scan mode.
    public func setScanMode(_ mode: DirectoryScanMode) {
        service.setScanMode(mode)
        directoryDrop = service.getDirectoryDrop()
    }

    /// Clears the selected directory.
    public func clearDirectory() {
        service.clearDirectory()
        directoryDrop = service.getDirectoryDrop()
    }

    /// The CLI argument string for the selected directory.
    public var directoryCliArgument: String {
        guard let url = directoryDrop.directoryURL else { return "" }
        return DirectoryInputHelpers.cliArgument(for: url, scanMode: directoryDrop.scanMode)
    }

    // MARK: - Tab Selection

    /// Selects the given tab.
    public func selectTab(_ tab: FileOperationsTab) {
        service.selectTab(tab)
        selectedTab = tab
    }
}
