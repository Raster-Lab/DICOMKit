# visionOS Integration Guide

Learn how to integrate DICOMKit into your visionOS application for spatial medical imaging.

## Overview

This guide covers visionOS-specific patterns for building immersive medical imaging experiences using spatial computing.

## Getting Started

### Adding DICOMKit

Add DICOMKit to your visionOS project:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "1.0.0")
]
```

### Platform Requirements

- visionOS 1.0+
- Xcode 15+
- Apple Vision Pro (or simulator)

## SwiftUI for visionOS

### Basic DICOM Viewer

```swift
import SwiftUI
import DICOMKit

struct DICOMSpatialViewer: View {
    let dicomFile: DICOMFile
    @State private var renderedImage: Image?
    @State private var selectedFrame = 0
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = renderedImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(depth: 0, alignment: .center)
                } else {
                    ProgressView()
                }
                
                // Frame navigation
                if let pixelData = try? dicomFile.extractPixelData(),
                   pixelData.numberOfFrames > 1 {
                    FrameNavigator(
                        currentFrame: $selectedFrame,
                        totalFrames: pixelData.numberOfFrames
                    )
                    .onChange(of: selectedFrame) { _, newValue in
                        Task {
                            await renderFrame(newValue)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle(dicomFile.dataSet.patientName ?? "DICOM Image")
            .toolbar {
                ToolbarItem(placement: .bottomOrnament) {
                    WindowLevelControls(
                        windowCenter: $windowCenter,
                        windowWidth: $windowWidth
                    )
                }
            }
        }
        .task {
            await renderFrame(0)
        }
        .onChange(of: windowCenter) { _, _ in
            Task { await renderFrame(selectedFrame) }
        }
        .onChange(of: windowWidth) { _, _ in
            Task { await renderFrame(selectedFrame) }
        }
    }
    
    private func renderFrame(_ frame: Int) async {
        guard let pixelData = try? dicomFile.extractPixelData() else { return }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        if let cgImage = renderer.renderFrame(frame,
            windowCenter: windowCenter,
            windowWidth: windowWidth) {
            renderedImage = Image(cgImage, scale: 1.0, label: Text("DICOM"))
        }
    }
}

struct FrameNavigator: View {
    @Binding var currentFrame: Int
    let totalFrames: Int
    
    var body: some View {
        HStack {
            Button(action: { currentFrame = max(0, currentFrame - 1) }) {
                Image(systemName: "chevron.left")
            }
            
            Text("\(currentFrame + 1) / \(totalFrames)")
                .monospacedDigit()
            
            Button(action: { currentFrame = min(totalFrames - 1, currentFrame + 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }
}

struct WindowLevelControls: View {
    @Binding var windowCenter: Double
    @Binding var windowWidth: Double
    
    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("Center")
                Slider(value: $windowCenter, in: -1000...1000)
                    .frame(width: 150)
            }
            
            VStack {
                Text("Width")
                Slider(value: $windowWidth, in: 1...4000)
                    .frame(width: 150)
            }
        }
        .padding()
    }
}
```

## Immersive Experiences

### Immersive DICOM Viewer

```swift
import SwiftUI
import RealityKit
import DICOMKit

struct ImmersiveDICOMView: View {
    let dicomFile: DICOMFile
    @State private var imageEntity: ModelEntity?
    
    var body: some View {
        RealityView { content in
            // Create a floating panel for the image
            let panel = await createImagePanel()
            content.add(panel)
            
            // Add ambient lighting
            let light = DirectionalLight()
            content.add(light)
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    // Allow user to reposition the image
                    value.entity.position = value.convert(value.location3D, from: .local, to: .scene)
                }
        )
    }
    
    private func createImagePanel() async -> ModelEntity {
        guard let pixelData = try? dicomFile.extractPixelData(),
              let cgImage = PixelDataRenderer(pixelData: pixelData).renderFrame(0) else {
            return ModelEntity()
        }
        
        // Create texture from DICOM image
        let width = pixelData.columns
        let height = pixelData.rows
        
        // Create a plane mesh for the image
        let mesh = MeshResource.generatePlane(
            width: Float(width) / 500.0,
            height: Float(height) / 500.0
        )
        
        // Create material with the DICOM image
        var material = UnlitMaterial()
        if let texture = try? await TextureResource(image: cgImage, options: .init(semantic: nil)) {
            material.color = .init(texture: .init(texture))
        }
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [0, 1.5, -2]  // Position in front of user
        
        // Add interaction component
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateBox(size: [Float(width)/500, Float(height)/500, 0.01])]))
        
        return entity
    }
}
```

### Volume Window

```swift
struct VolumeViewerScene: Scene {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        WindowGroup(id: "dicom-volume") {
            DICOMVolumeView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.5, height: 0.5, depth: 0.5, in: .meters)
    }
}

struct DICOMVolumeView: View {
    @State private var dicomFiles: [DICOMFile] = []
    @State private var volumeEntity: ModelEntity?
    
    var body: some View {
        RealityView { content in
            if let volume = volumeEntity {
                content.add(volume)
            }
        }
        .task {
            await loadVolume()
        }
    }
    
    private func loadVolume() async {
        // Load a series of DICOM slices
        // For demonstration - in practice load from files
        
        // Create a 3D representation from the slices
        // This is a simplified example - full volume rendering
        // would use Metal compute shaders
        
        let box = MeshResource.generateBox(size: 0.3)
        var material = SimpleMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.5))
        
        volumeEntity = ModelEntity(mesh: box, materials: [material])
        volumeEntity?.position = [0, 0, 0]
    }
}
```

## Hand Tracking

### Gesture-Based Window/Level

```swift
import SwiftUI
import ARKit

struct HandGestureDICOMViewer: View {
    let dicomFile: DICOMFile
    @State private var windowCenter: Double = 40
    @State private var windowWidth: Double = 400
    @State private var renderedImage: Image?
    
    var body: some View {
        ZStack {
            if let image = renderedImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            
            // Gesture instruction overlay
            VStack {
                Spacer()
                Text("Pinch and drag to adjust window/level")
                    .font(.caption)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    windowWidth = max(1, windowWidth + value.translation.width)
                    windowCenter += value.translation.height
                    Task {
                        await renderImage()
                    }
                }
        )
        .task {
            await renderImage()
        }
    }
    
    private func renderImage() async {
        guard let pixelData = try? dicomFile.extractPixelData() else { return }
        
        let renderer = PixelDataRenderer(pixelData: pixelData)
        if let cgImage = renderer.renderFrame(0,
            windowCenter: windowCenter,
            windowWidth: windowWidth) {
            renderedImage = Image(cgImage, scale: 1.0, label: Text("DICOM"))
        }
    }
}
```

## Multi-View Comparison

### Side-by-Side Comparison

```swift
struct ComparisonView: View {
    let files: [DICOMFile]
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(Array(files.prefix(4).enumerated()), id: \.offset) { index, file in
                DICOMImageCard(dicomFile: file)
                    .frame(width: 400, height: 400)
            }
        }
        .padding()
    }
}

struct DICOMImageCard: View {
    let dicomFile: DICOMFile
    @State private var image: Image?
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            ZStack {
                if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.gray.opacity(0.2)
                    ProgressView()
                }
            }
            .frame(height: 350)
            .cornerRadius(12)
            .hoverEffect(.highlight)
            
            Text(dicomFile.dataSet.seriesDescription ?? "Unknown Series")
                .font(.caption)
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let pixelData = try? dicomFile.extractPixelData(),
              let cgImage = PixelDataRenderer(pixelData: pixelData).renderFrame(0) else {
            return
        }
        image = Image(cgImage, scale: 1.0, label: Text("DICOM"))
    }
}
```

## Ornaments and Controls

### Bottom Ornament for Tools

```swift
struct DICOMViewerWithOrnaments: View {
    let dicomFile: DICOMFile
    @State private var selectedTool: MeasurementTool = .none
    @State private var windowPreset: WindowPreset = .softTissue
    
    enum MeasurementTool {
        case none, length, angle, area
    }
    
    enum WindowPreset: String, CaseIterable {
        case softTissue = "Soft Tissue"
        case bone = "Bone"
        case lung = "Lung"
        case brain = "Brain"
        
        var windowCenter: Double {
            switch self {
            case .softTissue: return 40
            case .bone: return 500
            case .lung: return -600
            case .brain: return 40
            }
        }
        
        var windowWidth: Double {
            switch self {
            case .softTissue: return 400
            case .bone: return 2000
            case .lung: return 1500
            case .brain: return 80
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            DICOMImageView(
                dicomFile: dicomFile,
                windowCenter: windowPreset.windowCenter,
                windowWidth: windowPreset.windowWidth
            )
            .toolbar {
                ToolbarItem(placement: .bottomOrnament) {
                    HStack(spacing: 24) {
                        // Measurement Tools
                        Picker("Tool", selection: $selectedTool) {
                            Image(systemName: "hand.point.up").tag(MeasurementTool.none)
                            Image(systemName: "ruler").tag(MeasurementTool.length)
                            Image(systemName: "angle").tag(MeasurementTool.angle)
                            Image(systemName: "square.dashed").tag(MeasurementTool.area)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        
                        Divider()
                            .frame(height: 30)
                        
                        // Window Presets
                        Picker("Window", selection: $windowPreset) {
                            ForEach(WindowPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .frame(width: 150)
                    }
                    .padding()
                }
            }
        }
    }
}

struct DICOMImageView: View {
    let dicomFile: DICOMFile
    let windowCenter: Double
    let windowWidth: Double
    @State private var image: Image?
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .task(id: windowCenter + windowWidth) {
            await renderImage()
        }
    }
    
    private func renderImage() async {
        guard let pixelData = try? dicomFile.extractPixelData(),
              let cgImage = PixelDataRenderer(pixelData: pixelData).renderFrame(0,
                  windowCenter: windowCenter,
                  windowWidth: windowWidth) else {
            return
        }
        image = Image(cgImage, scale: 1.0, label: Text("DICOM"))
    }
}
```

## Performance Considerations

### Memory Management on visionOS

```swift
class VisionOSImageCache {
    static let shared = VisionOSImageCache()
    
    // Lower memory limits for visionOS
    private let cache = ImageCache(configuration: ImageCacheConfiguration(
        maxImages: 50,
        maxMemory: 200 * 1024 * 1024  // 200 MB limit
    ))
    
    func getOrRender(
        dicomFile: DICOMFile,
        frame: Int,
        windowCenter: Double,
        windowWidth: Double
    ) async -> CGImage? {
        let key = "\(dicomFile.dataSet.sopInstanceUID ?? "")_\(frame)_\(windowCenter)_\(windowWidth)"
        
        if let cached = cache.get(key: key) {
            return cached
        }
        
        guard let pixelData = try? dicomFile.extractPixelData() else { return nil }
        let renderer = PixelDataRenderer(pixelData: pixelData)
        
        if let image = renderer.renderFrame(frame,
            windowCenter: windowCenter,
            windowWidth: windowWidth) {
            cache.set(image, for: key)
            return image
        }
        
        return nil
    }
    
    func clear() {
        cache.clear()
    }
}
```

### Efficient Texture Loading

```swift
extension TextureResource {
    static func fromDICOM(_ pixelData: PixelData, frame: Int = 0) async throws -> TextureResource {
        guard let cgImage = PixelDataRenderer(pixelData: pixelData).renderFrame(frame) else {
            throw DICOMError.renderingFailed
        }
        
        // Create texture optimized for visionOS
        return try await TextureResource(
            image: cgImage,
            options: .init(semantic: .color)
        )
    }
}
```

## See Also

- <doc:GettingStarted>
- <doc:RenderingImages>
- ``DICOMFile``
- ``PixelDataRenderer``
