// DICOMKit Sample Code: Basic SwiftUI Image Viewer
//
// This example demonstrates how to:
// - Display DICOM images in SwiftUI
// - Convert CGImage to SwiftUI Image
// - Implement window/level controls with sliders
// - Navigate multi-frame images
// - Add zoom and pan gestures
// - Manage state with @State and @Binding
// - Create reusable SwiftUI components

#if canImport(SwiftUI)
import SwiftUI
import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Basic Image Display

struct Example1_BasicImageView: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                ProgressView("Loading image...")
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let pixelData = dicomFile.pixelData else {
            errorMessage = "No pixel data in file"
            return
        }
        
        do {
            // Use default window/level from DICOM tags
            let dataSet = dicomFile.dataSet
            let windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
            let windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
            
            if let cgImage = try pixelData.createCGImage(
                frame: 0,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            } else {
                errorMessage = "Failed to create image"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Usage:
// let file = try DICOMFile.read(from: url)
// Example1_BasicImageView(dicomFile: file)

// MARK: - Example 2: Window/Level Sliders

struct Example2_WindowLevelControls: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var windowCenter: Double = 0.0
    @State private var windowWidth: Double = 4096.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Image display
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #endif
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 400)
                    .overlay(ProgressView())
            }
            
            // Window/Level controls
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Window Center:")
                    Spacer()
                    Text("\(Int(windowCenter))")
                        .monospacedDigit()
                }
                
                Slider(value: $windowCenter, in: -1024...1024, step: 1)
                    .onChange(of: windowCenter) { _, _ in
                        updateImage()
                    }
                
                HStack {
                    Text("Window Width:")
                    Spacer()
                    Text("\(Int(windowWidth))")
                        .monospacedDigit()
                }
                
                Slider(value: $windowWidth, in: 1...4096, step: 1)
                    .onChange(of: windowWidth) { _, _ in
                        updateImage()
                    }
            }
            .padding()
        }
        .task {
            initializeWindowLevel()
            updateImage()
        }
    }
    
    private func initializeWindowLevel() {
        let dataSet = dicomFile.dataSet
        windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
        windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
    }
    
    private func updateImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            if let cgImage = try? pixelData.createCGImage(
                frame: 0,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
}

// MARK: - Example 3: Multi-Frame Navigation

struct Example3_MultiFrameViewer: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var currentFrame: Int = 0
    @State private var totalFrames: Int = 1
    @State private var isPlaying: Bool = false
    
    private let playbackTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            // Image display
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #endif
            }
            
            // Frame controls
            VStack(spacing: 10) {
                HStack {
                    Text("Frame:")
                    Spacer()
                    Text("\(currentFrame + 1) / \(totalFrames)")
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { Double(currentFrame) },
                    set: { currentFrame = Int($0) }
                ), in: 0...Double(max(0, totalFrames - 1)), step: 1)
                .onChange(of: currentFrame) { _, _ in
                    updateImage()
                }
                
                HStack {
                    Button(action: previousFrame) {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .disabled(currentFrame == 0)
                    
                    Spacer()
                    
                    Button(action: { isPlaying.toggle() }) {
                        Label(isPlaying ? "Pause" : "Play",
                              systemImage: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .disabled(totalFrames <= 1)
                    
                    Spacer()
                    
                    Button(action: nextFrame) {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .disabled(currentFrame >= totalFrames - 1)
                }
            }
            .padding()
        }
        .task {
            initializeFrames()
        }
        .onReceive(playbackTimer) { _ in
            if isPlaying {
                nextFrame()
            }
        }
    }
    
    private func initializeFrames() {
        guard let pixelData = dicomFile.pixelData else { return }
        totalFrames = pixelData.numberOfFrames
        updateImage()
    }
    
    private func updateImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            let dataSet = dicomFile.dataSet
            let windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
            let windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
            
            if let cgImage = try? pixelData.createCGImage(
                frame: currentFrame,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
    
    private func nextFrame() {
        currentFrame = (currentFrame + 1) % totalFrames
    }
    
    private func previousFrame() {
        currentFrame = (currentFrame - 1 + totalFrames) % totalFrames
    }
}

// MARK: - Example 4: Zoom and Pan Gestures

struct Example4_ZoomableImageView: View {
    let cgImage: CGImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            #if os(macOS)
            Image(cgImage, scale: 1.0, label: Text("DICOM Image"))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnificationGesture)
                .gesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation {
                        resetTransform()
                    }
                }
            #else
            Image(uiImage: UIImage(cgImage: cgImage))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnificationGesture)
                .gesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation {
                        resetTransform()
                    }
                }
            #endif
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { value in
                lastScale = scale
                // Clamp scale
                scale = min(max(scale, 0.5), 10.0)
                lastScale = scale
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                lastOffset = offset
            }
    }
    
    private func resetTransform() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// Usage:
// if let image = displayImage {
//     Example4_ZoomableImageView(cgImage: image)
// }

// MARK: - Example 5: Window/Level with Drag Gesture

struct Example5_InteractiveWindowLevel: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var windowCenter: Double = 0.0
    @State private var windowWidth: Double = 400.0
    @State private var dragStart: CGPoint = .zero
    @State private var initialCenter: Double = 0.0
    @State private var initialWidth: Double = 400.0
    
    // Sensitivity for window/level adjustment
    private let sensitivity: Double = 2.0
    
    var body: some View {
        VStack {
            // Image with drag gesture for W/L adjustment
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .gesture(windowLevelGesture)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .gesture(windowLevelGesture)
                #endif
            }
            
            // Display current values
            HStack {
                Text("W: \(Int(windowWidth))")
                    .monospacedDigit()
                Spacer()
                Text("L: \(Int(windowCenter))")
                    .monospacedDigit()
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
        }
        .task {
            initializeWindowLevel()
            updateImage()
        }
    }
    
    private var windowLevelGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Horizontal drag: adjust width
                // Vertical drag: adjust center
                let deltaX = value.translation.width
                let deltaY = value.translation.height
                
                windowWidth = max(1.0, initialWidth + deltaX * sensitivity)
                windowCenter = initialCenter - deltaY * sensitivity
                
                updateImage()
            }
            .onEnded { _ in
                initialCenter = windowCenter
                initialWidth = windowWidth
            }
    }
    
    private func initializeWindowLevel() {
        let dataSet = dicomFile.dataSet
        windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
        windowWidth = dataSet.float64(for: .windowWidth) ?? 400.0
        initialCenter = windowCenter
        initialWidth = windowWidth
    }
    
    private func updateImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            if let cgImage = try? pixelData.createCGImage(
                frame: 0,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
}

// MARK: - Example 6: Window Presets Picker

struct WindowPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let center: Double
    let width: Double
    
    static let lung = WindowPreset(name: "Lung", center: -600, width: 1500)
    static let bone = WindowPreset(name: "Bone", center: 400, width: 1800)
    static let softTissue = WindowPreset(name: "Soft Tissue", center: 40, width: 400)
    static let brain = WindowPreset(name: "Brain", center: 40, width: 80)
    static let liver = WindowPreset(name: "Liver", center: 30, width: 150)
    static let abdomen = WindowPreset(name: "Abdomen", center: 60, width: 400)
    
    static let allPresets: [WindowPreset] = [
        .lung, .bone, .softTissue, .brain, .liver, .abdomen
    ]
}

struct Example6_WindowPresetPicker: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var selectedPreset: WindowPreset = .softTissue
    @State private var windowCenter: Double = 40.0
    @State private var windowWidth: Double = 400.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Image display
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                #endif
            }
            
            // Preset picker
            Picker("Window Preset", selection: $selectedPreset) {
                ForEach(WindowPreset.allPresets) { preset in
                    Text(preset.name).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPreset) { _, newValue in
                applyPreset(newValue)
            }
            
            // Current values
            HStack {
                VStack(alignment: .leading) {
                    Text("Window Width")
                        .font(.caption)
                    Text("\(Int(windowWidth))")
                        .font(.title2)
                        .monospacedDigit()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Window Center")
                        .font(.caption)
                    Text("\(Int(windowCenter))")
                        .font(.title2)
                        .monospacedDigit()
                }
            }
            .padding()
        }
        .task {
            updateImage()
        }
    }
    
    private func applyPreset(_ preset: WindowPreset) {
        windowCenter = preset.center
        windowWidth = preset.width
        updateImage()
    }
    
    private func updateImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            if let cgImage = try? pixelData.createCGImage(
                frame: 0,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
}

// MARK: - Example 7: Reusable DICOM Image View

struct DICOMImageView: View {
    let dicomFile: DICOMFile
    let frame: Int
    
    @Binding var windowCenter: Double
    @Binding var windowWidth: Double
    
    @State private var displayImage: CGImage?
    
    var body: some View {
        Group {
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ProgressView()
            }
        }
        .task(id: frame) {
            await loadImage()
        }
        .task(id: windowCenter) {
            await loadImage()
        }
        .task(id: windowWidth) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let pixelData = dicomFile.pixelData else { return }
        
        if let cgImage = try? pixelData.createCGImage(
            frame: frame,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        ) {
            displayImage = cgImage
        }
    }
}

// Usage:
// @State private var windowCenter: Double = 40.0
// @State private var windowWidth: Double = 400.0
//
// DICOMImageView(
//     dicomFile: file,
//     frame: 0,
//     windowCenter: $windowCenter,
//     windowWidth: $windowWidth
// )

// MARK: - Example 8: Image Metadata Overlay

struct Example8_MetadataOverlay: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var showMetadata: Bool = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Image
            if let image = displayImage {
                #if os(macOS)
                Image(image, scale: 1.0, label: Text("DICOM Image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: UIImage(cgImage: image))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            }
            
            // Metadata overlay
            if showMetadata {
                VStack(alignment: .leading, spacing: 5) {
                    metadataRow("Patient", value: patientName)
                    metadataRow("Study", value: studyDescription)
                    metadataRow("Series", value: seriesDescription)
                    metadataRow("Size", value: imageSizeString)
                }
                .padding(10)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .font(.caption)
                .padding()
            }
            
            // Toggle button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showMetadata.toggle() }) {
                        Image(systemName: showMetadata ? "eye.slash" : "eye")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .task {
            loadImage()
        }
    }
    
    private func metadataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .fontWeight(.semibold)
            Text(value)
        }
    }
    
    private var patientName: String {
        dicomFile.dataSet.string(for: .patientName) ?? "Unknown"
    }
    
    private var studyDescription: String {
        dicomFile.dataSet.string(for: .studyDescription) ?? "N/A"
    }
    
    private var seriesDescription: String {
        dicomFile.dataSet.string(for: .seriesDescription) ?? "N/A"
    }
    
    private var imageSizeString: String {
        guard let pixelData = dicomFile.pixelData else { return "N/A" }
        return "\(pixelData.width) × \(pixelData.height)"
    }
    
    private func loadImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            let dataSet = dicomFile.dataSet
            let windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
            let windowWidth = dataSet.float64(for: .windowWidth) ?? 4096.0
            
            if let cgImage = try? pixelData.createCGImage(
                frame: 0,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
}

// MARK: - Example 9: Complete Image Viewer Component

struct Example9_CompleteViewer: View {
    let dicomFile: DICOMFile
    
    @State private var displayImage: CGImage?
    @State private var currentFrame: Int = 0
    @State private var totalFrames: Int = 1
    @State private var windowCenter: Double = 0.0
    @State private var windowWidth: Double = 400.0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showControls: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Image view with gestures
            ZStack {
                Color.black
                
                if let image = displayImage {
                    #if os(macOS)
                    Image(image, scale: 1.0, label: Text("DICOM Image"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                    #else
                    Image(uiImage: UIImage(cgImage: image))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                    #endif
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .onTapGesture {
                withAnimation {
                    showControls.toggle()
                }
            }
            
            // Controls
            if showControls {
                VStack(spacing: 15) {
                    // Frame control (if multi-frame)
                    if totalFrames > 1 {
                        HStack {
                            Text("Frame:")
                            Slider(value: Binding(
                                get: { Double(currentFrame) },
                                set: { currentFrame = Int($0) }
                            ), in: 0...Double(totalFrames - 1), step: 1)
                            .onChange(of: currentFrame) { _, _ in
                                updateImage()
                            }
                            Text("\(currentFrame + 1)/\(totalFrames)")
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    
                    // Window/Level controls
                    HStack {
                        Text("W/L:")
                        VStack(spacing: 5) {
                            Slider(value: $windowWidth, in: 1...4096, step: 1)
                                .onChange(of: windowWidth) { _, _ in
                                    updateImage()
                                }
                            Slider(value: $windowCenter, in: -1024...1024, step: 1)
                                .onChange(of: windowCenter) { _, _ in
                                    updateImage()
                                }
                        }
                        VStack(alignment: .trailing) {
                            Text("W:\(Int(windowWidth))")
                            Text("C:\(Int(windowCenter))")
                        }
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                        .font(.caption)
                    }
                    
                    // Reset button
                    Button("Reset View") {
                        withAnimation {
                            resetTransform()
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .task {
            initializeViewer()
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { _ in
                lastScale = scale
                scale = min(max(scale, 0.5), 10.0)
                lastScale = scale
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private func initializeViewer() {
        let dataSet = dicomFile.dataSet
        windowCenter = dataSet.float64(for: .windowCenter) ?? 0.0
        windowWidth = dataSet.float64(for: .windowWidth) ?? 400.0
        
        if let pixelData = dicomFile.pixelData {
            totalFrames = pixelData.numberOfFrames
        }
        
        updateImage()
    }
    
    private func updateImage() {
        Task {
            guard let pixelData = dicomFile.pixelData else { return }
            
            if let cgImage = try? pixelData.createCGImage(
                frame: currentFrame,
                windowCenter: windowCenter,
                windowWidth: windowWidth
            ) {
                displayImage = cgImage
            }
        }
    }
    
    private func resetTransform() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples in your app:
// let fileURL = URL(fileURLWithPath: "/path/to/file.dcm")
// let file = try DICOMFile.read(from: fileURL)
//
// Example1_BasicImageView(dicomFile: file)
// Example2_WindowLevelControls(dicomFile: file)
// Example3_MultiFrameViewer(dicomFile: file)
// Example6_WindowPresetPicker(dicomFile: file)
// Example8_MetadataOverlay(dicomFile: file)
// Example9_CompleteViewer(dicomFile: file)

// MARK: - Quick Reference

/*
 SwiftUI DICOM Image Display:
 
 CGImage to SwiftUI Image Conversion:
 • macOS:     Image(cgImage, scale: 1.0, label: Text(""))
 • iOS/visionOS: Image(uiImage: UIImage(cgImage: cgImage))
 
 State Management:
 • @State        - View-local state (private)
 • @Binding      - Two-way binding to parent state
 • @StateObject  - Observable object lifecycle owned by view
 • @ObservedObject - Observable object from parent
 • @Observable   - Swift 6 observation (preferred)
 
 Loading Images Asynchronously:
 • .task { }           - Async work when view appears
 • .task(id:) { }      - Re-run when value changes
 • Task { }            - Manual async task creation
 • await/async         - Modern concurrency
 
 Gestures:
 • MagnificationGesture()  - Pinch to zoom
 • DragGesture()           - Pan/drag
 • TapGesture()            - Single/double tap
 • LongPressGesture()      - Long press
 • SimultaneousGesture()   - Combine gestures
 
 Gesture State:
 • .onChanged { }     - During gesture
 • .onEnded { }       - Gesture completed
 • GestureState<T>    - Auto-reset state
 
 Image Transformations:
 • .scaleEffect(scale)        - Zoom
 • .offset(CGSize)            - Pan
 • .rotationEffect(.degrees)  - Rotate
 • .blur(radius:)             - Blur
 
 Window/Level Controls:
 • Slider(value:in:step:)     - Numeric input
 • .onChange(of:) { }         - React to changes
 • Picker with segments       - Preset selection
 • Custom drag gestures       - Interactive W/L
 
 Layout:
 • VStack    - Vertical stack
 • HStack    - Horizontal stack
 • ZStack    - Layered stack
 • Spacer()  - Flexible space
 • padding() - Spacing
 
 Common Modifiers:
 • .frame(width:height:)      - Size constraints
 • .aspectRatio(contentMode:) - Aspect fit/fill
 • .background()              - Background view
 • .overlay()                 - Overlay view
 • .opacity()                 - Transparency
 • .clipShape()               - Clipping
 
 Platform-Specific Code:
 • #if os(macOS)
 • #if os(iOS)
 • #if os(visionOS)
 • #if canImport(SwiftUI)
 
 Multi-Frame Navigation:
 • Timer.publish()           - Periodic events
 • .onReceive(timer)         - React to timer
 • currentFrame % total      - Wrap around
 
 Error Handling:
 • @State var errorMessage   - Store error
 • if let / guard let        - Optional binding
 • do-catch with Task        - Async errors
 
 Performance Tips:
 
 1. Use .task(id:) to reload only when needed
 2. Debounce rapid slider changes
 3. Generate images on background queue
 4. Cache CGImages when possible
 5. Use @MainActor for UI updates
 6. Minimize state changes
 7. Consider LazyVStack/LazyHStack for lists
 8. Profile with Instruments
 
 Best Practices:
 
 1. Separate views into reusable components
 2. Use @Binding for child view state
 3. Keep view bodies simple and readable
 4. Extract complex logic to functions/models
 5. Use ViewModels for business logic
 6. Handle all error cases gracefully
 7. Provide loading states
 8. Support accessibility
 9. Test on all target platforms
 10. Follow Apple Human Interface Guidelines
 
 Common Patterns:
 
 • View + ViewModel (MVVM)
 • Reusable components with @Binding
 • Async loading with .task
 • Gesture-based interactions
 • Overlay metadata on images
 • Toggle controls visibility
 • Preset values picker
 • Progressive disclosure
 
 Integration with DICOMKit:
 
 • DICOMFile.pixelData           - Access pixel data
 • pixelData.createCGImage()     - Generate CGImage
 • pixelData.numberOfFrames      - Frame count
 • dataSet.float64(for:)         - Read numeric tags
 • dataSet.string(for:)          - Read string tags
 • Window center/width from tags - Default W/L
 
 Testing SwiftUI Views:
 
 • SwiftUI previews              - Quick iteration
 • XCTest with ViewInspector     - Unit testing
 • UI tests with XCUITest        - Integration testing
 • Snapshot tests                - Visual regression
 */

#endif // canImport(SwiftUI)
