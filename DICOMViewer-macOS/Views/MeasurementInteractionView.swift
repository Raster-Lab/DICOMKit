//
//  MeasurementInteractionView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI
import AppKit

/// View for handling mouse interactions for drawing measurements
struct MeasurementInteractionView: NSViewRepresentable {
    @Binding var selectedTool: MeasurementType?
    let imageSize: CGSize
    let zoom: CGFloat
    let offset: CGSize
    let onAddPoint: (ImagePoint) -> Void
    let onComplete: () -> Void
    
    func makeNSView(context: Context) -> MeasurementInteractionNSView {
        let view = MeasurementInteractionNSView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: MeasurementInteractionNSView, context: Context) {
        context.coordinator.selectedTool = selectedTool
        context.coordinator.imageSize = imageSize
        context.coordinator.zoom = zoom
        context.coordinator.offset = offset
        context.coordinator.onAddPoint = onAddPoint
        context.coordinator.onComplete = onComplete
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedTool: selectedTool,
            imageSize: imageSize,
            zoom: zoom,
            offset: offset,
            onAddPoint: onAddPoint,
            onComplete: onComplete
        )
    }
    
    class Coordinator: MeasurementInteractionDelegate {
        var selectedTool: MeasurementType?
        var imageSize: CGSize
        var zoom: CGFloat
        var offset: CGSize
        var onAddPoint: (ImagePoint) -> Void
        var onComplete: () -> Void
        
        init(
            selectedTool: MeasurementType?,
            imageSize: CGSize,
            zoom: CGFloat,
            offset: CGSize,
            onAddPoint: @escaping (ImagePoint) -> Void,
            onComplete: @escaping () -> Void
        ) {
            self.selectedTool = selectedTool
            self.imageSize = imageSize
            self.zoom = zoom
            self.offset = offset
            self.onAddPoint = onAddPoint
            self.onComplete = onComplete
        }
        
        func handleClick(at point: CGPoint) {
            guard selectedTool != nil else { return }
            
            // Convert screen point to image coordinates
            let imagePoint = screenToImage(point)
            onAddPoint(imagePoint)
        }
        
        func handleRightClick(at point: CGPoint) {
            // Right-click completes polygon measurements
            if selectedTool == .polygon {
                onComplete()
            }
        }
        
        private func screenToImage(_ screenPoint: CGPoint) -> ImagePoint {
            // Reverse the transformation from imageToScreen
            let imageX = (screenPoint.x - offset.width) / zoom
            let imageY = (screenPoint.y - offset.height) / zoom
            return ImagePoint(x: Double(imageX), y: Double(imageY))
        }
    }
}

// MARK: - Protocol

protocol MeasurementInteractionDelegate: AnyObject {
    func handleClick(at point: CGPoint)
    func handleRightClick(at point: CGPoint)
}

// MARK: - NSView Implementation

class MeasurementInteractionNSView: NSView {
    weak var delegate: MeasurementInteractionDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInKeyWindow
        ]
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        addTrackingArea(trackingArea)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        setupTrackingArea()
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.handleClick(at: locationInView)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        delegate?.handleRightClick(at: locationInView)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

// MARK: - Preview

#Preview {
    MeasurementInteractionView(
        selectedTool: .constant(.length),
        imageSize: CGSize(width: 512, height: 512),
        zoom: 1.0,
        offset: .zero,
        onAddPoint: { point in
            print("Point added: \(point)")
        },
        onComplete: {
            print("Measurement complete")
        }
    )
    .frame(width: 600, height: 600)
}
