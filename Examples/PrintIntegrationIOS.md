# DICOM Print Integration - iOS Example

A complete example showing how to integrate DICOM printing in an iOS application using SwiftUI.

## Overview

This example demonstrates a production-ready DICOM print implementation for iOS, including:
- Print configuration management
- Image selection and preparation
- Progress tracking
- Error handling
- User interface design

## Complete iOS Print View

```swift
import SwiftUI
import DICOMKit
import DICOMNetwork

// MARK: - Print Configuration Manager

@MainActor
class PrintConfigurationManager: ObservableObject {
    @Published var printers: [SavedPrinter] = []
    @Published var selectedPrinter: SavedPrinter?
    
    init() {
        loadPrinters()
    }
    
    func loadPrinters() {
        // Load from UserDefaults or Keychain
        if let data = UserDefaults.standard.data(forKey: "saved_printers"),
           let decoded = try? JSONDecoder().decode([SavedPrinter].self, from: data) {
            printers = decoded
            selectedPrinter = printers.first { $0.isDefault }
        }
    }
    
    func savePrinter(_ printer: SavedPrinter) {
        if let index = printers.firstIndex(where: { $0.id == printer.id }) {
            printers[index] = printer
        } else {
            printers.append(printer)
        }
        
        if let data = try? JSONEncoder().encode(printers) {
            UserDefaults.standard.set(data, forKey: "saved_printers")
        }
    }
    
    func deletePrinter(_ printer: SavedPrinter) {
        printers.removeAll { $0.id == printer.id }
        if let data = try? JSONEncoder().encode(printers) {
            UserDefaults.standard.set(data, forKey: "saved_printers")
        }
    }
}

struct SavedPrinter: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: UInt16
    var calledAETitle: String
    var isDefault: Bool
    
    var configuration: PrintConfiguration {
        PrintConfiguration(
            host: host,
            port: port,
            callingAETitle: "IOS_APP",
            calledAETitle: calledAETitle
        )
    }
}

// MARK: - Print View Model

@MainActor
class PrintViewModel: ObservableObject {
    @Published var dicomFiles: [DICOMFile] = []
    @Published var selectedImages: Set<UUID> = []
    @Published var printOptions = PrintOptions.default
    @Published var isShowingPrintSheet = false
    @Published var isPrinting = false
    @Published var printProgress: PrintProgress?
    @Published var printError: PrintError?
    @Published var printResult: PrintResult?
    
    func loadDICOMFile(from url: URL) async throws {
        let file = try DICOMFile(path: url.path)
        dicomFiles.append(file)
    }
    
    func print(
        selectedFiles: [DICOMFile],
        configuration: PrintConfiguration,
        options: PrintOptions
    ) async {
        isPrinting = true
        printError = nil
        printResult = nil
        
        do {
            // Extract pixel data
            let images = try selectedFiles.map { file in
                try file.extractPixelData().data
            }
            
            // Print with progress tracking
            for try await progress in DICOMPrintService.printImagesWithProgress(
                configuration: configuration,
                images: images,
                options: options
            ) {
                printProgress = progress
            }
            
            printProgress = nil
            isPrinting = false
            
            // Success - show confirmation
            
        } catch let error as PrintError {
            printError = error
            isPrinting = false
        } catch {
            printError = PrintError.unknown(message: error.localizedDescription)
            isPrinting = false
        }
    }
}

// MARK: - Main Print View

struct DICOMPrintView: View {
    @StateObject private var viewModel = PrintViewModel()
    @StateObject private var configManager = PrintConfigurationManager()
    @State private var isShowingFilePicker = false
    @State private var isShowingPrinterSettings = false
    @State private var isShowingOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image List
                if viewModel.dicomFiles.isEmpty {
                    emptyStateView
                } else {
                    imageListView
                }
                
                // Action Bar
                actionBarView
            }
            .navigationTitle("DICOM Print")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Settings") {
                        isShowingPrinterSettings = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingFilePicker) {
                DocumentPicker(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingPrinterSettings) {
                PrinterSettingsView(manager: configManager)
            }
            .sheet(isPresented: $isShowingOptions) {
                PrintOptionsView(options: $viewModel.printOptions)
            }
            .overlay {
                if viewModel.isPrinting {
                    PrintProgressView(progress: viewModel.printProgress)
                }
            }
            .alert("Print Error", isPresented: .constant(viewModel.printError != nil)) {
                Button("OK") {
                    viewModel.printError = nil
                }
            } message: {
                if let error = viewModel.printError {
                    Text("\(error.description)\n\n\(error.recoverySuggestion)")
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "printer")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Images to Print")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Tap + to add DICOM images")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Add Images") {
                isShowingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Image List
    
    private var imageListView: some View {
        List {
            ForEach(viewModel.dicomFiles.indices, id: \.self) { index in
                DICOMImageRow(
                    file: viewModel.dicomFiles[index],
                    isSelected: viewModel.selectedImages.contains(
                        viewModel.dicomFiles[index].id ?? UUID()
                    )
                )
                .onTapGesture {
                    toggleSelection(at: index)
                }
            }
            .onDelete { indexSet in
                viewModel.dicomFiles.remove(atOffsets: indexSet)
            }
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBarView: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 16) {
                // Printer Selection
                Menu {
                    ForEach(configManager.printers) { printer in
                        Button(printer.name) {
                            configManager.selectedPrinter = printer
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "printer")
                        Text(configManager.selectedPrinter?.name ?? "No Printer")
                        Image(systemName: "chevron.down")
                    }
                }
                .disabled(configManager.printers.isEmpty)
                
                Spacer()
                
                // Options Button
                Button {
                    isShowingOptions = true
                } label: {
                    Image(systemName: "gear")
                }
                
                // Print Button
                Button {
                    printImages()
                } label: {
                    Label("Print", systemImage: "printer.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPrint)
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    // MARK: - Helpers
    
    private var canPrint: Bool {
        !viewModel.dicomFiles.isEmpty &&
        !viewModel.selectedImages.isEmpty &&
        configManager.selectedPrinter != nil
    }
    
    private func toggleSelection(at index: Int) {
        guard let id = viewModel.dicomFiles[index].id else { return }
        
        if viewModel.selectedImages.contains(id) {
            viewModel.selectedImages.remove(id)
        } else {
            viewModel.selectedImages.insert(id)
        }
    }
    
    private func printImages() {
        guard let printer = configManager.selectedPrinter else { return }
        
        let selectedFiles = viewModel.dicomFiles.filter {
            guard let id = $0.id else { return false }
            return viewModel.selectedImages.contains(id)
        }
        
        Task {
            await viewModel.print(
                selectedFiles: selectedFiles,
                configuration: printer.configuration,
                options: viewModel.printOptions
            )
        }
    }
}

// MARK: - DICOM Image Row

struct DICOMImageRow: View {
    let file: DICOMFile
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            // Thumbnail
            if let pixelData = try? file.extractPixelData(),
               let cgImage = pixelData.cgImage {
                Image(cgImage, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(file.dataSet.string(for: .patientName) ?? "Unknown Patient")
                    .font(.headline)
                
                if let modality = file.dataSet.string(for: .modality) {
                    Text(modality)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let studyDate = file.dataSet.string(for: .studyDate) {
                    Text(studyDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Print Progress View

struct PrintProgressView: View {
    let progress: PrintProgress?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress?.progress ?? 0)
                    .progressViewStyle(.circular)
                    .scaleEffect(2.0)
                
                VStack(spacing: 8) {
                    Text(phaseDescription)
                        .font(.headline)
                    
                    if let message = progress?.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let current = progress?.current,
                   let total = progress?.total {
                    Text("\(current) of \(total) images")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(radius: 20)
            }
            .padding(40)
        }
    }
    
    private var phaseDescription: String {
        guard let phase = progress?.phase else { return "Preparing..." }
        
        switch phase {
        case .connecting: return "Connecting to Printer"
        case .queryingPrinter: return "Checking Printer Status"
        case .creatingSession: return "Starting Print Session"
        case .preparingImages: return "Preparing Images"
        case .uploadingImages: return "Uploading to Printer"
        case .printing: return "Printing..."
        case .cleanup: return "Finishing Up"
        case .completed: return "Print Completed"
        }
    }
}

// MARK: - Print Options View

struct PrintOptionsView: View {
    @Binding var options: PrintOptions
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Film Size") {
                    Picker("Size", selection: $options.filmSize) {
                        Text("8×10\"").tag(FilmSize.size8InX10In)
                        Text("11×14\"").tag(FilmSize.size11InX14In)
                        Text("14×17\"").tag(FilmSize.size14InX17In)
                        Text("A4").tag(FilmSize.a4)
                    }
                }
                
                Section("Orientation") {
                    Picker("Orientation", selection: $options.filmOrientation) {
                        Text("Portrait").tag(FilmOrientation.portrait)
                        Text("Landscape").tag(FilmOrientation.landscape)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Quality") {
                    Picker("Medium", selection: $options.mediumType) {
                        Text("Paper").tag(MediumType.paper)
                        Text("Clear Film").tag(MediumType.clearFilm)
                        Text("Blue Film").tag(MediumType.blueFilm)
                    }
                    
                    Picker("Priority", selection: $options.priority) {
                        Text("Low").tag(PrintPriority.low)
                        Text("Medium").tag(PrintPriority.medium)
                        Text("High").tag(PrintPriority.high)
                    }
                }
                
                Section("Copies") {
                    Stepper("Copies: \(options.numberOfCopies)",
                            value: $options.numberOfCopies,
                            in: 1...10)
                }
                
                Section {
                    Button("Use High Quality Preset") {
                        options = .highQuality
                    }
                    
                    Button("Use Draft Preset") {
                        options = .draft
                    }
                }
            }
            .navigationTitle("Print Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Printer Settings View

struct PrinterSettingsView: View {
    @ObservedObject var manager: PrintConfigurationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingPrinter = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.printers) { printer in
                    PrinterRow(printer: printer, manager: manager)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        manager.deletePrinter(manager.printers[index])
                    }
                }
                
                Button {
                    isAddingPrinter = true
                } label: {
                    Label("Add Printer", systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle("Printers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAddingPrinter) {
                AddPrinterView(manager: manager)
            }
        }
    }
}

struct PrinterRow: View {
    let printer: SavedPrinter
    @ObservedObject var manager: PrintConfigurationManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(printer.name)
                    .font(.headline)
                
                Text("\(printer.host):\(printer.port)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("AE: \(printer.calledAETitle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if printer.isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .onTapGesture {
            setAsDefault()
        }
    }
    
    private func setAsDefault() {
        // Update all printers
        for index in manager.printers.indices {
            var updated = manager.printers[index]
            updated.isDefault = (updated.id == printer.id)
            manager.printers[index] = updated
        }
        
        manager.selectedPrinter = printer
        
        // Save changes
        if let data = try? JSONEncoder().encode(manager.printers) {
            UserDefaults.standard.set(data, forKey: "saved_printers")
        }
    }
}

// MARK: - Add Printer View

struct AddPrinterView: View {
    @ObservedObject var manager: PrintConfigurationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "11112"
    @State private var calledAETitle = "PRINT_SCP"
    @State private var setAsDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Printer Details") {
                    TextField("Name", text: $name)
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    
                    TextField("Called AE Title", text: $calledAETitle)
                        .autocapitalization(.allCharacters)
                }
                
                Section {
                    Toggle("Set as Default", isOn: $setAsDefault)
                }
            }
            .navigationTitle("Add Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPrinter()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        !host.isEmpty &&
        !port.isEmpty &&
        !calledAETitle.isEmpty &&
        UInt16(port) != nil
    }
    
    private func addPrinter() {
        let printer = SavedPrinter(
            id: UUID(),
            name: name,
            host: host,
            port: UInt16(port) ?? 11112,
            calledAETitle: calledAETitle,
            isDefault: setAsDefault
        )
        
        manager.savePrinter(printer)
        
        if setAsDefault {
            manager.selectedPrinter = printer
        }
        
        dismiss()
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PrintViewModel
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.data],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let viewModel: PrintViewModel
        
        init(viewModel: PrintViewModel) {
            self.viewModel = viewModel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
                for url in urls {
                    do {
                        try await viewModel.loadDICOMFile(from: url)
                    } catch {
                        print("Failed to load \(url): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Usage

// In your app's main view:
struct ContentView: View {
    var body: some View {
        DICOMPrintView()
    }
}
```

## Key Features

1. **Printer Management**
   - Save multiple printers
   - Select default printer
   - Easy switching between printers

2. **Image Selection**
   - Import DICOM files
   - Visual thumbnails
   - Multi-select support

3. **Print Options**
   - Film size selection
   - Orientation control
   - Quality presets
   - Copy count

4. **Progress Tracking**
   - Real-time progress updates
   - Phase-by-phase feedback
   - Cancellation support

5. **Error Handling**
   - User-friendly error messages
   - Recovery suggestions
   - Retry capability

## Testing

```swift
import XCTest
@testable import YourApp

class PrintIntegrationTests: XCTestCase {
    func testPrinterConfiguration() {
        let manager = PrintConfigurationManager()
        
        let printer = SavedPrinter(
            id: UUID(),
            name: "Test Printer",
            host: "192.168.1.100",
            port: 11112,
            calledAETitle: "PRINT_SCP",
            isDefault: true
        )
        
        manager.savePrinter(printer)
        
        XCTAssertEqual(manager.printers.count, 1)
        XCTAssertEqual(manager.selectedPrinter?.id, printer.id)
    }
}
```

## Production Considerations

1. **Background Execution**
   - Request background time for long print jobs
   - Handle app suspension gracefully

2. **Network Reachability**
   - Check network before printing
   - Show offline indicator

3. **Error Recovery**
   - Implement retry logic
   - Save failed prints for later

4. **User Preferences**
   - Remember last printer selection
   - Store print options presets

5. **Accessibility**
   - VoiceOver labels
   - Dynamic Type support
   - Reduce Motion compliance

## See Also

- [Getting Started with DICOM Printing](GettingStartedWithPrinting.md)
- [Print Workflow Best Practices](PrintWorkflowBestPractices.md)
- [macOS Integration Example](PrintIntegrationMacOS.md)
