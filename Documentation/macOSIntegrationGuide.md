# macOS Integration Guide

Learn how to integrate DICOMKit into your macOS application for professional medical image viewing.

## Overview

This guide covers macOS-specific patterns and best practices for building professional DICOM viewing applications on Mac.

## Getting Started

### Adding DICOMKit

Add DICOMKit using Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["DICOMKit"])
]
```

Or via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/raster-image/DICOMKit.git`

## SwiftUI macOS Application

### Document-Based App

```swift
import SwiftUI
import UniformTypeIdentifiers
import DICOMKit

@main
struct DICOMViewerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: DICOMDocument()) { file in
            DICOMDocumentView(document: file.$document)
        }
        .commands {
            DICOMCommands()
        }
        
        Settings {
            SettingsView()
        }
    }
}

struct DICOMDocument: FileDocument {
    var dicomFile: DICOMFile?
    
    static var readableContentTypes: [UTType] { 
        [UTType(filenameExtension: "dcm") ?? .data] 
    }
    
    init() { }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        dicomFile = try DICOMFile.read(from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let file = dicomFile else {
            throw CocoaError(.fileWriteUnknown)
        }
        let data = try file.write()
        return FileWrapper(regularFileWithContents: data)
    }
}
```

### Multi-Window Viewing

```swift
struct DICOMDocumentView: View {
    @Binding var document: DICOMDocument
    @State private var selectedFrame = 0
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    @State private var showInspector = true
    
    var body: some View {
        NavigationSplitView {
            SeriesListView(document: document)
        } detail: {
            HSplitView {
                ImageView(
                    dicomFile: document.dicomFile,
                    frame: selectedFrame,
                    windowCenter: windowCenter,
                    windowWidth: windowWidth
                )
                
                if showInspector {
                    InspectorView(dicomFile: document.dicomFile)
                        .frame(width: 300)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                WindowLevelMenu(
                    windowCenter: $windowCenter,
                    windowWidth: $windowWidth
                )
                
                Toggle(isOn: $showInspector) {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }
}
```

### DICOM Tag Inspector

```swift
struct InspectorView: View {
    let dicomFile: DICOMFile?
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("DICOM Tags")
                .font(.headline)
            
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
            
            List {
                if let file = dicomFile {
                    ForEach(filteredElements(file.dataSet), id: \.tag) { element in
                        TagRow(element: element)
                    }
                }
            }
        }
        .padding()
    }
    
    private func filteredElements(_ dataSet: DataSet) -> [DataElement] {
        let elements = dataSet.elements.sorted { $0.tag < $1.tag }
        
        if searchText.isEmpty {
            return elements
        }
        
        return elements.filter { element in
            element.tagDescription.localizedCaseInsensitiveContains(searchText) ||
            element.stringValue?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
}

struct TagRow: View {
    let element: DataElement
    
    var body: some View {
        HStack {
            Text(element.tagDescription)
                .fontWeight(.medium)
            Spacer()
            Text(element.stringValue ?? "(no value)")
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
```

## AppKit Integration

### NSViewController for DICOM Viewing

```swift
import AppKit
import DICOMKit

class DICOMViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let imageView = NSImageView()
    
    private var dicomFile: DICOMFile?
    private var pixelData: PixelData?
    private var windowCenter: Double = 40
    private var windowWidth: Double = 400
    private var zoomLevel: CGFloat = 1.0
    
    override func loadView() {
        view = NSView()
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 8.0
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        
        view.addSubview(scrollView)
        scrollView.documentView = imageView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupGestures() {
        let panGesture = NSPanGestureRecognizer(
            target: self, 
            action: #selector(handlePan)
        )
        panGesture.buttonMask = 0x2  // Right mouse button
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        windowWidth = max(1, windowWidth + Double(translation.x))
        windowCenter -= Double(translation.y)
        
        gesture.setTranslation(.zero, in: view)
        
        renderImage()
    }
    
    func loadDICOMFile(_ file: DICOMFile) {
        dicomFile = file
        
        do {
            pixelData = try file.extractPixelData()
            
            if let wc = file.dataSet.windowCenter {
                windowCenter = wc
            }
            if let ww = file.dataSet.windowWidth {
                windowWidth = ww
            }
            
            renderImage()
        } catch {
            showError(error)
        }
    }
    
    private func renderImage() {
        guard let pixelData = pixelData else { return }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        if let cgImage = renderer.renderFrame(0, 
            windowCenter: windowCenter, 
            windowWidth: windowWidth) {
            
            let size = NSSize(
                width: CGFloat(pixelData.columns),
                height: CGFloat(pixelData.rows)
            )
            imageView.image = NSImage(cgImage: cgImage, size: size)
        }
    }
    
    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
```

## PACS Integration

### Query/Retrieve from PACS

```swift
import DICOMNetwork

class PACSConnection: ObservableObject {
    @Published var studies: [StudyResult] = []
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var client: DICOMClient?
    
    func connect(host: String, port: Int, callingAE: String, calledAE: String) async {
        do {
            client = DICOMClient(
                host: host,
                port: port,
                callingAETitle: callingAE,
                calledAETitle: calledAE
            )
            
            try await client?.associate()
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func searchStudies(patientName: String?, modality: String?, dateRange: ClosedRange<Date>?) async {
        guard let client = client else { return }
        
        let queryService = QueryService(client: client)
        
        var queryKeys = QueryKeys.study()
        
        if let name = patientName {
            queryKeys = queryKeys.with(patientName: "\(name)*")
        }
        if let mod = modality {
            queryKeys = queryKeys.with(modality: mod)
        }
        
        do {
            studies = try await queryService.findStudies(queryKeys)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func retrieveStudy(_ study: StudyResult) async throws -> [DICOMFile] {
        guard let client = client else { throw PACSError.notConnected }
        
        let retrieveService = RetrieveService(client: client)
        return try await retrieveService.getStudy(
            studyInstanceUID: study.studyInstanceUID
        )
    }
    
    func disconnect() async {
        try? await client?.release()
        isConnected = false
        client = nil
    }
}

enum PACSError: Error {
    case notConnected
}
```

### PACS Browser View

```swift
struct PACSBrowserView: View {
    @StateObject private var pacs = PACSConnection()
    @State private var searchText = ""
    @State private var selectedModality = "CT"
    
    var body: some View {
        HSplitView {
            // Search Panel
            VStack(alignment: .leading) {
                Text("PACS Query")
                    .font(.headline)
                
                TextField("Patient Name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Modality", selection: $selectedModality) {
                    Text("CT").tag("CT")
                    Text("MR").tag("MR")
                    Text("CR").tag("CR")
                    Text("DX").tag("DX")
                    Text("US").tag("US")
                }
                
                Button("Search") {
                    Task {
                        await pacs.searchStudies(
                            patientName: searchText.isEmpty ? nil : searchText,
                            modality: selectedModality,
                            dateRange: nil
                        )
                    }
                }
                .disabled(!pacs.isConnected)
                
                Spacer()
            }
            .frame(width: 250)
            .padding()
            
            // Results
            Table(pacs.studies) {
                TableColumn("Patient Name") { study in
                    Text(study.patientName ?? "Unknown")
                }
                TableColumn("Study Date") { study in
                    Text(study.studyDate ?? "")
                }
                TableColumn("Modality") { study in
                    Text(study.modality ?? "")
                }
                TableColumn("Description") { study in
                    Text(study.studyDescription ?? "")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(pacs.isConnected ? "Disconnect" : "Connect") {
                    Task {
                        if pacs.isConnected {
                            await pacs.disconnect()
                        } else {
                            await pacs.connect(
                                host: "pacs.local",
                                port: 11112,
                                callingAE: "VIEWER",
                                calledAE: "PACS"
                            )
                        }
                    }
                }
            }
        }
    }
}
```

## Print Support

### DICOM Printing

```swift
import AppKit

class DICOMPrintController {
    func printDICOMImage(_ dicomFile: DICOMFile) {
        guard let pixelData = try? dicomFile.extractPixelData(),
              let cgImage = PixelDataRenderer(pixelData: pixelData).renderFrame(0) else {
            return
        }
        
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 11 * 72, height: 17 * 72)  // 11x17"
        printInfo.orientation = .landscape
        printInfo.scalingFactor = 1.0
        
        let printView = DICOMPrintView(cgImage: cgImage, dicomFile: dicomFile)
        let printOperation = NSPrintOperation(view: printView)
        printOperation.printInfo = printInfo
        
        printOperation.runModal(for: NSApplication.shared.mainWindow!, 
                               delegate: nil, 
                               didRun: nil, 
                               contextInfo: nil)
    }
}

class DICOMPrintView: NSView {
    let cgImage: CGImage
    let dicomFile: DICOMFile
    
    init(cgImage: CGImage, dicomFile: DICOMFile) {
        self.cgImage = cgImage
        self.dicomFile = dicomFile
        super.init(frame: NSRect(x: 0, y: 0, width: 792, height: 1224))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw image
        let imageRect = CGRect(x: 50, y: 200, width: bounds.width - 100, height: bounds.height - 300)
        context.draw(cgImage, in: imageRect)
        
        // Draw patient info
        let patientInfo = """
        Patient: \(dicomFile.dataSet.patientName ?? "Unknown")
        ID: \(dicomFile.dataSet.patientID ?? "Unknown")
        Study: \(dicomFile.dataSet.studyDescription ?? "")
        Date: \(dicomFile.dataSet.studyDate ?? "")
        """
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        
        patientInfo.draw(at: NSPoint(x: 50, y: bounds.height - 100), 
                        withAttributes: attributes)
    }
}
```

## Drag and Drop

### Accepting DICOM Files

```swift
struct DICOMDropZone: View {
    @Binding var dicomFiles: [DICOMFile]
    @State private var isTargeted = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary,
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                )
            
            VStack {
                Image(systemName: "square.and.arrow.down")
                    .font(.largeTitle)
                Text("Drop DICOM files here")
            }
            .foregroundColor(.secondary)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    loadDICOMFile(url)
                }
            }
        }
    }
    
    private func loadDICOMFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let file = try DICOMFile.read(from: data)
            dicomFiles.append(file)
        } catch {
            print("Error loading DICOM: \(error)")
        }
    }
}
```

## See Also

- <doc:GettingStarted>
- <doc:NetworkingGuide>
- ``DICOMFile``
- ``DICOMClient``
