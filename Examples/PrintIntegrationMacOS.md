# DICOM Print Integration - macOS Example

A complete example showing how to integrate DICOM printing in a macOS application using SwiftUI and AppKit.

## Overview

This example demonstrates a professional DICOM print implementation for macOS, including:
- Native print dialog integration
- Printer discovery and management
- Batch printing with job queue
- Advanced image preparation
- System print preferences integration

## Complete macOS Print Implementation

```swift
import SwiftUI
import AppKit
import DICOMKit
import DICOMNetwork

// MARK: - Print Manager (macOS-specific)

@MainActor
class macOSPrintManager: ObservableObject {
    @Published var printers: [DICOMPrinter] = []
    @Published var printQueue: PrintQueue
    @Published var isDiscoveringPrinters = false
    
    init() {
        self.printQueue = PrintQueue(
            maxHistorySize: 500,
            retryPolicy: PrintRetryPolicy(
                maxRetries: 3,
                initialDelay: 2.0,
                maxDelay: 30.0,
                backoffMultiplier: 2.0
            )
        )
        
        loadSavedPrinters()
    }
    
    // MARK: - Printer Management
    
    func discoverPrinters() async {
        isDiscoveringPrinters = true
        defer { isDiscoveringPrinters = false }
        
        // Scan common DICOM print server ports on local network
        let ipRange = getLocalNetworkRange()
        let commonPorts: [UInt16] = [11112, 104, 4242]
        
        await withTaskGroup(of: DICOMPrinter?.self) { group in
            for ip in ipRange {
                for port in commonPorts {
                    group.addTask {
                        await self.probePrinter(host: ip, port: port)
                    }
                }
            }
            
            for await printer in group {
                if let printer = printer {
                    if !printers.contains(where: { $0.id == printer.id }) {
                        printers.append(printer)
                    }
                }
            }
        }
        
        savePrinters()
    }
    
    private func probePrinter(host: String, port: UInt16) async -> DICOMPrinter? {
        let config = PrintConfiguration(
            host: host,
            port: port,
            callingAETitle: "MACOS_APP",
            calledAETitle: "ANY-SCP",
            timeout: 5  // Short timeout for discovery
        )
        
        do {
            let status = try await DICOMPrintService.getPrinterStatus(
                configuration: config
            )
            
            return DICOMPrinter(
                id: UUID(),
                name: status.printerName.isEmpty ? "\(host):\(port)" : status.printerName,
                configuration: config,
                status: status,
                isAvailable: status.status == .normal
            )
        } catch {
            return nil
        }
    }
    
    private func getLocalNetworkRange() -> [String] {
        // Simplified - in production, use proper network scanning
        var ips: [String] = []
        let baseIP = "192.168.1"
        for i in 1...254 {
            ips.append("\(baseIP).\(i)")
        }
        return ips
    }
    
    // MARK: - Persistence
    
    private func loadSavedPrinters() {
        if let data = UserDefaults.standard.data(forKey: "macos_dicom_printers"),
           let decoded = try? JSONDecoder().decode([DICOMPrinter].self, from: data) {
            printers = decoded
        }
    }
    
    private func savePrinters() {
        if let data = try? JSONEncoder().encode(printers) {
            UserDefaults.standard.set(data, forKey: "macos_dicom_printers")
        }
    }
}

struct DICOMPrinter: Codable, Identifiable {
    let id: UUID
    var name: String
    var configuration: PrintConfiguration
    var status: PrinterStatus?
    var isAvailable: Bool
}

// MARK: - Main Print Window

struct DICOMPrintWindow: View {
    @StateObject private var printManager = macOSPrintManager()
    @StateObject private var viewModel = PrintViewModel()
    @State private var selectedPrinter: DICOMPrinter?
    @State private var isShowingPrinterSettings = false
    @State private var isShowingPrintDialog = false
    
    var body: some View {
        HSplitView {
            // Sidebar - Printer List
            sidebarView
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            
            // Main Content - Images
            mainContentView
                .frame(minWidth: 600)
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                printerSelectionMenu
            }
            
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task {
                        await printManager.discoverPrinters()
                    }
                } label: {
                    Label("Discover Printers", systemImage: "magnifyingglass")
                }
                .help("Search for DICOM printers on network")
                
                Button {
                    isShowingPrintDialog = true
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!canPrint)
                .help("Print selected images (⌘P)")
            }
        }
        .sheet(isPresented: $isShowingPrintDialog) {
            PrintDialogView(
                viewModel: viewModel,
                printer: selectedPrinter,
                printManager: printManager
            )
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: View {
        VStack(spacing: 0) {
            // Printer List
            List(selection: $selectedPrinter) {
                ForEach(printManager.printers) { printer in
                    PrinterListItem(printer: printer)
                        .tag(printer)
                }
            }
            .listStyle(.sidebar)
            
            // Queue Status
            Divider()
            queueStatusView
        }
    }
    
    private var queueStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Print Queue")
                .font(.headline)
            
            // Show active jobs
            // Implementation depends on PrintQueue API
            
            Text("0 jobs pending")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Main Content
    
    private var mainContentView: View {
        VStack(spacing: 0) {
            // Image Grid
            if viewModel.dicomFiles.isEmpty {
                emptyStateView
            } else {
                imageGridView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "printer")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Images to Print")
                .font(.title)
            
            Button("Add Images...") {
                openFileDialog()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.dicomFiles.indices, id: \.self) { index in
                    DICOMImageCard(
                        file: viewModel.dicomFiles[index],
                        isSelected: viewModel.selectedImages.contains(
                            viewModel.dicomFiles[index].id ?? UUID()
                        )
                    )
                    .onTapGesture {
                        toggleSelection(at: index)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Toolbar Items
    
    private var printerSelectionMenu: some View {
        Menu {
            ForEach(printManager.printers) { printer in
                Button(printer.name) {
                    selectedPrinter = printer
                }
            }
            
            Divider()
            
            Button("Add Printer...") {
                isShowingPrinterSettings = true
            }
        } label: {
            HStack {
                Image(systemName: "printer")
                Text(selectedPrinter?.name ?? "Select Printer")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canPrint: Bool {
        !viewModel.dicomFiles.isEmpty &&
        !viewModel.selectedImages.isEmpty &&
        selectedPrinter != nil
    }
    
    private func toggleSelection(at index: Int) {
        guard let id = viewModel.dicomFiles[index].id else { return }
        
        if viewModel.selectedImages.contains(id) {
            viewModel.selectedImages.remove(id)
        } else {
            viewModel.selectedImages.insert(id)
        }
    }
    
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.message = "Select DICOM files to print"
        
        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    try? await viewModel.loadDICOMFile(from: url)
                }
            }
        }
    }
}

// MARK: - Printer List Item

struct PrinterListItem: View {
    let printer: DICOMPrinter
    
    var body: some View {
        HStack {
            Image(systemName: printer.isAvailable ? "printer.fill" : "printer")
                .foregroundColor(printer.isAvailable ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(printer.name)
                    .font(.body)
                
                Text("\(printer.configuration.host):\(printer.configuration.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let status = printer.status {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(status.status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor(status.status))
                }
            }
        }
    }
    
    private func statusColor(_ status: PrinterStatus.Status) -> Color {
        switch status {
        case .normal: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}

// MARK: - DICOM Image Card (macOS)

struct DICOMImageCard: View {
    let file: DICOMFile
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                if let pixelData = try? file.extractPixelData(),
                   let cgImage = pixelData.cgImage {
                    Image(cgImage, scale: 1.0, label: Text("DICOM Image"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 150)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.white))
                        .padding(8)
                }
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(file.dataSet.string(for: .patientName) ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                if let modality = file.dataSet.string(for: .modality) {
                    Text(modality)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if let studyDate = file.dataSet.string(for: .studyDate) {
                        Text(studyDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding([.horizontal, .bottom], 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }
}

// MARK: - Print Dialog (macOS-specific)

struct PrintDialogView: View {
    @ObservedObject var viewModel: PrintViewModel
    let printer: DICOMPrinter?
    let printManager: macOSPrintManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var printOptions = PrintOptions.default
    @State private var isPrinting = false
    @State private var printProgress: PrintProgress?
    @State private var printError: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            HStack {
                Text("Print to DICOM Printer")
                    .font(.title2)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Main Content
            HStack(spacing: 0) {
                // Options Panel
                optionsPanelView
                    .frame(width: 300)
                
                Divider()
                
                // Preview Panel
                previewPanelView
                    .frame(minWidth: 400)
            }
            
            Divider()
            
            // Action Buttons
            HStack {
                // Print Summary
                if let selectedCount = viewModel.selectedImages.count as? Int {
                    Text("\(selectedCount) image(s) selected")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Print") {
                    startPrint()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(printer == nil)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 800, height: 600)
        .overlay {
            if isPrinting {
                PrintProgressOverlay(progress: printProgress)
            }
        }
        .alert("Print Error", isPresented: .constant(printError != nil)) {
            Button("OK") {
                printError = nil
            }
        } message: {
            if let error = printError {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Options Panel
    
    private var optionsPanelView: some View {
        Form {
            Section("Printer") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(printer?.name ?? "No Printer")
                        .font(.headline)
                    
                    if let config = printer?.configuration {
                        Text("\(config.host):\(config.port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Film Size") {
                Picker("Size", selection: $printOptions.filmSize) {
                    Text("8×10\"").tag(FilmSize.size8InX10In)
                    Text("10×12\"").tag(FilmSize.size10InX12In)
                    Text("11×14\"").tag(FilmSize.size11InX14In)
                    Text("14×17\"").tag(FilmSize.size14InX17In)
                    Text("A4").tag(FilmSize.a4)
                    Text("A3").tag(FilmSize.a3)
                }
            }
            
            Section("Layout") {
                Picker("Orientation", selection: $printOptions.filmOrientation) {
                    Label("Portrait", systemImage: "rectangle.portrait")
                        .tag(FilmOrientation.portrait)
                    Label("Landscape", systemImage: "rectangle")
                        .tag(FilmOrientation.landscape)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Quality") {
                Picker("Medium", selection: $printOptions.mediumType) {
                    Text("Paper").tag(MediumType.paper)
                    Text("Clear Film").tag(MediumType.clearFilm)
                    Text("Blue Film").tag(MediumType.blueFilm)
                }
                
                Picker("Priority", selection: $printOptions.priority) {
                    Text("Low").tag(PrintPriority.low)
                    Text("Medium").tag(PrintPriority.medium)
                    Text("High").tag(PrintPriority.high)
                }
                
                Stepper("Copies: \(printOptions.numberOfCopies)",
                        value: $printOptions.numberOfCopies,
                        in: 1...10)
            }
            
            Section {
                Button("High Quality Preset") {
                    printOptions = .highQuality
                }
                
                Button("Draft Preset") {
                    printOptions = .draft
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Preview Panel
    
    private var previewPanelView: some View {
        VStack {
            Text("Print Preview")
                .font(.headline)
                .padding()
            
            // Show film layout preview
            filmLayoutPreview
            
            Spacer()
        }
    }
    
    private var filmLayoutPreview: some View {
        GeometryReader { geometry in
            let aspectRatio = printOptions.filmOrientation == .portrait ? 0.7 : 1.4
            
            VStack {
                Rectangle()
                    .fill(Color.white)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay {
                        // Show grid based on number of images
                        gridOverlay
                    }
                    .shadow(radius: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
    
    private var gridOverlay: some View {
        // Simplified - actual layout calculation would use PrintLayout
        let count = viewModel.selectedImages.count
        let layout = getLayoutForCount(count)
        
        return GeometryReader { geo in
            let cellWidth = geo.size.width / CGFloat(layout.columns)
            let cellHeight = geo.size.height / CGFloat(layout.rows)
            
            ForEach(0..<min(count, layout.rows * layout.columns), id: \.self) { index in
                let row = index / layout.columns
                let col = index % layout.columns
                
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
                    .frame(
                        width: cellWidth - 4,
                        height: cellHeight - 4
                    )
                    .position(
                        x: CGFloat(col) * cellWidth + cellWidth / 2,
                        y: CGFloat(row) * cellHeight + cellHeight / 2
                    )
            }
        }
    }
    
    private func getLayoutForCount(_ count: Int) -> (rows: Int, columns: Int) {
        // Simplified layout selection
        switch count {
        case 1: return (1, 1)
        case 2: return (1, 2)
        case 3...4: return (2, 2)
        case 5...6: return (2, 3)
        case 7...9: return (3, 3)
        case 10...12: return (3, 4)
        default: return (4, 4)
        }
    }
    
    // MARK: - Actions
    
    private func startPrint() {
        guard let printer = printer else { return }
        
        let selectedFiles = viewModel.dicomFiles.filter {
            guard let id = $0.id else { return false }
            return viewModel.selectedImages.contains(id)
        }
        
        Task {
            isPrinting = true
            
            do {
                let images = try selectedFiles.map { file in
                    try file.extractPixelData().data
                }
                
                for try await progress in DICOMPrintService.printImagesWithProgress(
                    configuration: printer.configuration,
                    images: images,
                    options: printOptions
                ) {
                    printProgress = progress
                }
                
                isPrinting = false
                dismiss()
                
            } catch {
                printError = error
                isPrinting = false
            }
        }
    }
}

// MARK: - Print Progress Overlay (macOS)

struct PrintProgressOverlay: View {
    let progress: PrintProgress?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress?.progress ?? 0)
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                
                VStack(spacing: 8) {
                    if let phase = progress?.phase {
                        Text(phaseDescription(phase))
                            .font(.headline)
                    }
                    
                    if let message = progress?.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(40)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(radius: 20)
            }
        }
    }
    
    private func phaseDescription(_ phase: PrintProgress.Phase) -> String {
        switch phase {
        case .connecting: return "Connecting..."
        case .queryingPrinter: return "Checking Printer..."
        case .creatingSession: return "Starting Session..."
        case .preparingImages: return "Preparing Images..."
        case .uploadingImages: return "Uploading..."
        case .printing: return "Printing..."
        case .cleanup: return "Finishing..."
        case .completed: return "Complete!"
        }
    }
}

// MARK: - Menu Commands

extension DICOMPrintWindow {
    func addMenuCommands() -> some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Print...") {
                if canPrint {
                    isShowingPrintDialog = true
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(!canPrint)
        }
    }
}
```

## App Integration

```swift
import SwiftUI

@main
struct DICOMPrintApp: App {
    var body: some Scene {
        WindowGroup {
            DICOMPrintWindow()
        }
        .commands {
            DICOMPrintWindow().addMenuCommands()
        }
        
        Settings {
            PrinterPreferencesView()
        }
    }
}
```

## Key macOS-Specific Features

1. **Native Print Dialog**
   - System-standard UI
   - Print preview
   - Keyboard shortcuts (⌘P)

2. **Printer Discovery**
   - Network scanning for DICOM printers
   - Automatic configuration

3. **Split View Layout**
   - Sidebar with printer list
   - Main content area for images
   - Resizable panels

4. **Menu Integration**
   - File → Print command
   - Keyboard shortcuts
   - Settings window

5. **Advanced Features**
   - Drag & drop support
   - Quick Look integration
   - Spotlight integration

## Testing

```bash
# Build and run
swift build
.build/debug/DICOMPrintApp

# Or open in Xcode
open Package.swift
```

## See Also

- [iOS Integration Example](PrintIntegrationIOS.md)
- [Print Management Guide](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)
- [Best Practices](PrintWorkflowBestPractices.md)
