# iOS Integration Guide

Learn how to integrate DICOMKit into your iOS application for medical image viewing.

## Overview

This guide covers iOS-specific patterns and best practices for integrating DICOMKit into your mobile medical imaging application.

## Getting Started

### Adding DICOMKit

Add DICOMKit to your Xcode project:

1. File → Add Package Dependencies
2. Enter: `https://github.com/raster-image/DICOMKit.git`
3. Select version 1.0.0 or later

### Import Statement

```swift
import DICOMKit

// For network operations
import DICOMNetwork

// For DICOMweb
import DICOMWeb
```

## SwiftUI Integration

### Basic Image Viewer

```swift
import SwiftUI
import DICOMKit

struct DICOMImageViewer: View {
    let dicomFile: DICOMFile
    
    @State private var renderedImage: CGImage?
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = renderedImage {
                    Image(image, scale: 1.0, label: Text("DICOM"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .gesture(windowLevelGesture)
                } else if isLoading {
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private var windowLevelGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Horizontal: Window Width
                windowWidth = max(1, windowWidth + value.translation.width)
                // Vertical: Window Center
                windowCenter += value.translation.height
                
                Task {
                    await renderImage()
                }
            }
    }
    
    private func loadImage() async {
        do {
            let pixelData = try dicomFile.extractPixelData()
            
            // Use window settings from file if available
            if let wc = dicomFile.dataSet.windowCenter {
                windowCenter = wc
            }
            if let ww = dicomFile.dataSet.windowWidth {
                windowWidth = ww
            }
            
            await renderImage()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func renderImage() async {
        guard let pixelData = try? dicomFile.extractPixelData() else { return }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        renderedImage = renderer.renderFrame(0, 
            windowCenter: windowCenter, 
            windowWidth: windowWidth)
    }
}
```

### Multi-Frame Viewer

```swift
struct MultiFrameViewer: View {
    let dicomFile: DICOMFile
    
    @State private var currentFrame = 0
    @State private var images: [CGImage] = []
    @State private var isPlaying = false
    
    private let timer = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if currentFrame < images.count {
                Image(images[currentFrame], scale: 1.0, label: Text("Frame"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            HStack {
                Button(action: previousFrame) {
                    Image(systemName: "backward.frame")
                }
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause" : "play")
                }
                
                Button(action: nextFrame) {
                    Image(systemName: "forward.frame")
                }
                
                Text("\(currentFrame + 1) / \(images.count)")
                    .monospacedDigit()
            }
            
            Slider(value: Binding(
                get: { Double(currentFrame) },
                set: { currentFrame = Int($0) }
            ), in: 0...Double(max(0, images.count - 1)))
        }
        .onReceive(timer) { _ in
            if isPlaying {
                nextFrame()
            }
        }
        .task {
            await loadFrames()
        }
    }
    
    private func loadFrames() async {
        guard let pixelData = try? dicomFile.extractPixelData() else { return }
        let renderer = PixelDataRenderer(pixelData: pixelData)
        
        var loadedImages: [CGImage] = []
        for frame in 0..<pixelData.numberOfFrames {
            if let image = renderer.renderFrame(frame) {
                loadedImages.append(image)
            }
        }
        images = loadedImages
    }
    
    private func nextFrame() {
        currentFrame = (currentFrame + 1) % max(1, images.count)
    }
    
    private func previousFrame() {
        currentFrame = currentFrame > 0 ? currentFrame - 1 : max(0, images.count - 1)
    }
}
```

## UIKit Integration

### UIViewController for DICOM Viewing

```swift
import UIKit
import DICOMKit

class DICOMViewController: UIViewController {
    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    
    private var dicomFile: DICOMFile?
    private var pixelData: PixelData?
    private var windowCenter: Double = 40
    private var windowWidth: Double = 400
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        
        imageView.contentMode = .scaleAspectFit
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        windowWidth = max(1, windowWidth + Double(translation.x))
        windowCenter += Double(translation.y)
        
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
            imageView.image = UIImage(cgImage: cgImage)
        }
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension DICOMViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
```

## File Import

### Document Picker

```swift
import UniformTypeIdentifiers

struct DICOMDocumentPicker: UIViewControllerRepresentable {
    @Binding var dicomFile: DICOMFile?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType(filenameExtension: "dcm") ?? .data,
            .data
        ])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DICOMDocumentPicker
        
        init(_ parent: DICOMDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                parent.dicomFile = try DICOMFile.read(from: data)
            } catch {
                print("Error loading DICOM: \(error)")
            }
        }
    }
}
```

## Memory Management

### Handling Large Studies

```swift
class StudyLoader {
    private let cache = ImageCache(configuration: .lowMemory)
    
    func loadStudy(urls: [URL]) async throws -> [DICOMFile] {
        var files: [DICOMFile] = []
        
        // Use metadata-only parsing first
        let options = ParsingOptions(mode: .metadataOnly)
        
        for url in urls {
            let data = try Data(contentsOf: url)
            let file = try DICOMFile.read(from: data, options: options)
            files.append(file)
        }
        
        // Sort by instance number
        files.sort { 
            ($0.dataSet.instanceNumber ?? 0) < ($1.dataSet.instanceNumber ?? 0)
        }
        
        return files
    }
    
    func renderFrame(from file: DICOMFile, frame: Int) async -> CGImage? {
        let cacheKey = "\(file.dataSet.sopInstanceUID ?? "")_\(frame)"
        
        // Check cache first
        if let cached = cache.get(key: cacheKey) {
            return cached
        }
        
        // Load and render
        guard let pixelData = try? file.extractPixelData() else { return nil }
        let renderer = PixelDataRenderer(pixelData: pixelData)
        
        if let image = renderer.renderFrame(frame) {
            cache.set(image, for: cacheKey)
            return image
        }
        
        return nil
    }
}
```

### Responding to Memory Pressure

```swift
import UIKit

class MemoryAwareImageCache {
    static let shared = MemoryAwareImageCache()
    
    private let cache = ImageCache(configuration: .lowMemory)
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func didReceiveMemoryWarning() {
        cache.clear()
    }
}
```

## Background Processing

### Processing DICOM in the Background

```swift
import BackgroundTasks

class DICOMBackgroundProcessor {
    static let shared = DICOMBackgroundProcessor()
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.app.dicom.process",
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.app.dicom.process")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            // Handle expiration
        }
        
        Task {
            do {
                // Process DICOM files
                await processQueuedFiles()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func processQueuedFiles() async {
        // Process queued DICOM files
    }
}
```

## See Also

- <doc:GettingStarted>
- <doc:RenderingImages>
- ``DICOMFile``
- ``PixelDataRenderer``
