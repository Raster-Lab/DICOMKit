// PresentationStateOverlayView.swift
// DICOMViewer iOS - Presentation State Overlay View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import DICOMKit
import DICOMCore

/// View for rendering GSPS annotations and shutters as an overlay
struct PresentationStateOverlayView: View {
    let presentationState: GrayscalePresentationState?
    let imageSize: CGSize
    let viewSize: CGSize
    let zoomScale: CGFloat
    let panOffset: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render shutters
                if let ps = presentationState, !ps.shutters.isEmpty {
                    ShutterOverlayView(
                        shutters: ps.shutters,
                        imageSize: imageSize,
                        viewSize: geometry.size,
                        zoomScale: zoomScale,
                        panOffset: panOffset
                    )
                }
                
                // Render annotations
                if let ps = presentationState {
                    AnnotationOverlayView(
                        annotations: ps.graphicAnnotations,
                        layers: ps.graphicLayers,
                        imageSize: imageSize,
                        viewSize: geometry.size,
                        zoomScale: zoomScale,
                        panOffset: panOffset
                    )
                }
            }
        }
    }
}

/// View for rendering display shutters
struct ShutterOverlayView: View {
    let shutters: [DisplayShutter]
    let imageSize: CGSize
    let viewSize: CGSize
    let zoomScale: CGFloat
    let panOffset: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Calculate the image frame within the view
            let imageFrame = calculateImageFrame()
            
            for shutter in shutters {
                let shutterColor = Color.black // Shutters are typically black
                
                switch shutter {
                case .rectangular(let left, let right, let top, let bottom, _):
                    // Draw rectangle shutter (the shuttered area is INSIDE the rectangle)
                    let rect = transformRect(
                        left: left, right: right, top: top, bottom: bottom,
                        imageFrame: imageFrame
                    )
                    context.fill(Path(rect), with: .color(shutterColor))
                    
                case .circular(let centerColumn, let centerRow, let radius, _):
                    // Draw circular shutter (the area INSIDE the circle is shuttered)
                    let center = transformPoint(
                        column: Double(centerColumn),
                        row: Double(centerRow),
                        imageFrame: imageFrame
                    )
                    let scaledRadius = CGFloat(radius) * imageFrame.width / imageSize.width * zoomScale
                    
                    let circleRect = CGRect(
                        x: center.x - scaledRadius,
                        y: center.y - scaledRadius,
                        width: scaledRadius * 2,
                        height: scaledRadius * 2
                    )
                    context.fill(Path(ellipseIn: circleRect), with: .color(shutterColor))
                    
                case .polygonal(let vertices, _):
                    // Draw polygonal shutter
                    if vertices.count >= 3 {
                        var path = Path()
                        let firstPoint = transformPoint(
                            column: Double(vertices[0].column),
                            row: Double(vertices[0].row),
                            imageFrame: imageFrame
                        )
                        path.move(to: firstPoint)
                        
                        for i in 1..<vertices.count {
                            let point = transformPoint(
                                column: Double(vertices[i].column),
                                row: Double(vertices[i].row),
                                imageFrame: imageFrame
                            )
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                        context.fill(path, with: .color(shutterColor))
                    }
                    
                case .bitmap:
                    // Bitmap shutters require overlay data - skip for now
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func calculateImageFrame() -> CGRect {
        // Calculate how the image is displayed (aspect fit)
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let x = (viewSize.width - scaledWidth) / 2
        let y = (viewSize.height - scaledHeight) / 2
        
        return CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }
    
    private func transformPoint(column: Double, row: Double, imageFrame: CGRect) -> CGPoint {
        // Transform pixel coordinates to view coordinates
        let normalizedX = CGFloat(column) / imageSize.width
        let normalizedY = CGFloat(row) / imageSize.height
        
        let x = imageFrame.origin.x + normalizedX * imageFrame.width * zoomScale + panOffset.width
        let y = imageFrame.origin.y + normalizedY * imageFrame.height * zoomScale + panOffset.height
        
        return CGPoint(x: x, y: y)
    }
    
    private func transformRect(left: Int, right: Int, top: Int, bottom: Int, imageFrame: CGRect) -> CGRect {
        let topLeft = transformPoint(column: Double(left), row: Double(top), imageFrame: imageFrame)
        let bottomRight = transformPoint(column: Double(right), row: Double(bottom), imageFrame: imageFrame)
        
        return CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }
}

/// View for rendering graphic and text annotations
struct AnnotationOverlayView: View {
    let annotations: [GraphicAnnotation]
    let layers: [GraphicLayer]
    let imageSize: CGSize
    let viewSize: CGSize
    let zoomScale: CGFloat
    let panOffset: CGSize
    
    var body: some View {
        Canvas { context, size in
            let imageFrame = calculateImageFrame()
            
            // Sort layers by order
            let sortedLayers = layers.sorted { $0.order < $1.order }
            let layerNames = sortedLayers.map { $0.name }
            
            // Get layer colors
            let layerColors = Dictionary(uniqueKeysWithValues: sortedLayers.map { layer in
                (layer.name, getLayerColor(layer))
            })
            
            // Draw annotations by layer order
            for layerName in layerNames {
                let layerAnnotations = annotations.filter { $0.layer == layerName }
                let color = layerColors[layerName] ?? .yellow
                
                for annotation in layerAnnotations {
                    drawAnnotation(annotation, color: color, context: &context, imageFrame: imageFrame)
                }
            }
            
            // Draw annotations that don't have a matching layer
            let unlayeredAnnotations = annotations.filter { ann in
                !layerNames.contains(ann.layer)
            }
            for annotation in unlayeredAnnotations {
                drawAnnotation(annotation, color: .yellow, context: &context, imageFrame: imageFrame)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func calculateImageFrame() -> CGRect {
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let x = (viewSize.width - scaledWidth) / 2
        let y = (viewSize.height - scaledHeight) / 2
        
        return CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    }
    
    private func getLayerColor(_ layer: GraphicLayer) -> Color {
        if let rgb = layer.recommendedRGBValue {
            return Color(
                red: Double(rgb.red) / 65535.0,
                green: Double(rgb.green) / 65535.0,
                blue: Double(rgb.blue) / 65535.0
            )
        } else if let gray = layer.recommendedGrayscaleValue {
            let value = Double(gray) / 65535.0
            return Color(red: value, green: value, blue: value)
        }
        return .yellow // Default annotation color
    }
    
    private func drawAnnotation(
        _ annotation: GraphicAnnotation,
        color: Color,
        context: inout GraphicsContext,
        imageFrame: CGRect
    ) {
        // Draw graphic objects
        for graphic in annotation.graphicObjects {
            drawGraphic(graphic, color: color, context: &context, imageFrame: imageFrame)
        }
        
        // Draw text objects
        for textObj in annotation.textObjects {
            drawText(textObj, color: color, context: &context, imageFrame: imageFrame)
        }
    }
    
    private func drawGraphic(
        _ graphic: GraphicObject,
        color: Color,
        context: inout GraphicsContext,
        imageFrame: CGRect
    ) {
        let strokeStyle = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        
        switch graphic.type {
        case .point:
            guard let point = graphic.point(at: 0) else { return }
            let screenPoint = transformPoint(column: point.column, row: point.row, imageFrame: imageFrame, units: graphic.units)
            
            // Draw a small circle for points
            let pointRect = CGRect(x: screenPoint.x - 4, y: screenPoint.y - 4, width: 8, height: 8)
            if graphic.filled {
                context.fill(Path(ellipseIn: pointRect), with: .color(color))
            } else {
                context.stroke(Path(ellipseIn: pointRect), with: .color(color), style: strokeStyle)
            }
            
        case .polyline:
            guard graphic.pointCount >= 2 else { return }
            var path = Path()
            
            if let firstPoint = graphic.point(at: 0) {
                let screenPoint = transformPoint(column: firstPoint.column, row: firstPoint.row, imageFrame: imageFrame, units: graphic.units)
                path.move(to: screenPoint)
            }
            
            for i in 1..<graphic.pointCount {
                if let point = graphic.point(at: i) {
                    let screenPoint = transformPoint(column: point.column, row: point.row, imageFrame: imageFrame, units: graphic.units)
                    path.addLine(to: screenPoint)
                }
            }
            
            if graphic.filled {
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(0.3)))
                context.stroke(path, with: .color(color), style: strokeStyle)
            } else {
                context.stroke(path, with: .color(color), style: strokeStyle)
            }
            
        case .interpolated:
            // For interpolated curves, we'd need a spline algorithm
            // For now, draw as polyline
            guard graphic.pointCount >= 2 else { return }
            var path = Path()
            
            if let firstPoint = graphic.point(at: 0) {
                let screenPoint = transformPoint(column: firstPoint.column, row: firstPoint.row, imageFrame: imageFrame, units: graphic.units)
                path.move(to: screenPoint)
            }
            
            for i in 1..<graphic.pointCount {
                if let point = graphic.point(at: i) {
                    let screenPoint = transformPoint(column: point.column, row: point.row, imageFrame: imageFrame, units: graphic.units)
                    path.addLine(to: screenPoint)
                }
            }
            
            context.stroke(path, with: .color(color), style: strokeStyle)
            
        case .circle:
            // Circle is defined by center point and a point on the circumference
            guard graphic.pointCount >= 2,
                  let center = graphic.point(at: 0),
                  let edge = graphic.point(at: 1) else { return }
            
            let screenCenter = transformPoint(column: center.column, row: center.row, imageFrame: imageFrame, units: graphic.units)
            let screenEdge = transformPoint(column: edge.column, row: edge.row, imageFrame: imageFrame, units: graphic.units)
            
            let dx = screenEdge.x - screenCenter.x
            let dy = screenEdge.y - screenCenter.y
            let radius = sqrt(dx * dx + dy * dy)
            
            let circleRect = CGRect(
                x: screenCenter.x - radius,
                y: screenCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            if graphic.filled {
                context.fill(Path(ellipseIn: circleRect), with: .color(color.opacity(0.3)))
                context.stroke(Path(ellipseIn: circleRect), with: .color(color), style: strokeStyle)
            } else {
                context.stroke(Path(ellipseIn: circleRect), with: .color(color), style: strokeStyle)
            }
            
        case .ellipse:
            // Ellipse is defined by 4 points: major axis endpoints and minor axis endpoints
            guard graphic.pointCount >= 4,
                  let majorStart = graphic.point(at: 0),
                  let majorEnd = graphic.point(at: 1),
                  let minorStart = graphic.point(at: 2),
                  let minorEnd = graphic.point(at: 3) else { return }
            
            let screenMajorStart = transformPoint(column: majorStart.column, row: majorStart.row, imageFrame: imageFrame, units: graphic.units)
            let screenMajorEnd = transformPoint(column: majorEnd.column, row: majorEnd.row, imageFrame: imageFrame, units: graphic.units)
            let screenMinorStart = transformPoint(column: minorStart.column, row: minorStart.row, imageFrame: imageFrame, units: graphic.units)
            let screenMinorEnd = transformPoint(column: minorEnd.column, row: minorEnd.row, imageFrame: imageFrame, units: graphic.units)
            
            // Calculate center and radii
            let centerX = (screenMajorStart.x + screenMajorEnd.x) / 2
            let centerY = (screenMajorStart.y + screenMajorEnd.y) / 2
            
            let majorRadius = sqrt(pow(screenMajorEnd.x - screenMajorStart.x, 2) + pow(screenMajorEnd.y - screenMajorStart.y, 2)) / 2
            let minorRadius = sqrt(pow(screenMinorEnd.x - screenMinorStart.x, 2) + pow(screenMinorEnd.y - screenMinorStart.y, 2)) / 2
            
            // Calculate rotation angle
            let angle = atan2(screenMajorEnd.y - screenMajorStart.y, screenMajorEnd.x - screenMajorStart.x)
            
            var path = Path()
            path.addEllipse(in: CGRect(x: -majorRadius, y: -minorRadius, width: majorRadius * 2, height: minorRadius * 2))
            
            // Apply rotation first, then translation to correctly position the rotated ellipse
            let transform = CGAffineTransform(rotationAngle: angle)
                .translatedBy(x: centerX / cos(angle != 0 ? angle : 1), y: centerY / sin(angle != 0 ? angle : 1))
            // Simpler approach: concatenate transforms
            let rotationTransform = CGAffineTransform(rotationAngle: angle)
            let translationTransform = CGAffineTransform(translationX: centerX, y: centerY)
            let combinedTransform = rotationTransform.concatenating(translationTransform)
            path = path.applying(combinedTransform)
            
            if graphic.filled {
                context.fill(path, with: .color(color.opacity(0.3)))
                context.stroke(path, with: .color(color), style: strokeStyle)
            } else {
                context.stroke(path, with: .color(color), style: strokeStyle)
            }
        }
    }
    
    private func drawText(
        _ textObj: TextObject,
        color: Color,
        context: inout GraphicsContext,
        imageFrame: CGRect
    ) {
        let topLeft = transformPoint(
            column: textObj.boundingBoxTopLeft.column,
            row: textObj.boundingBoxTopLeft.row,
            imageFrame: imageFrame,
            units: textObj.boundingBoxUnits
        )
        let bottomRight = transformPoint(
            column: textObj.boundingBoxBottomRight.column,
            row: textObj.boundingBoxBottomRight.row,
            imageFrame: imageFrame,
            units: textObj.boundingBoxUnits
        )
        
        // Draw text background
        let textRect = CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
        
        context.fill(Path(textRect), with: .color(.black.opacity(0.5)))
        
        // Draw text
        let text = Text(textObj.text)
            .font(.caption)
            .foregroundColor(Color(uiColor: UIColor(color)))
        
        context.draw(text, at: CGPoint(x: topLeft.x + 4, y: topLeft.y + 4), anchor: .topLeading)
        
        // Draw anchor point if visible
        if textObj.anchorPointVisible, let anchor = textObj.anchorPoint {
            let anchorPoint = transformPoint(
                column: anchor.column,
                row: anchor.row,
                imageFrame: imageFrame,
                units: textObj.anchorPointUnits
            )
            
            // Draw line from anchor to text box
            var linePath = Path()
            linePath.move(to: anchorPoint)
            linePath.addLine(to: CGPoint(x: topLeft.x, y: (topLeft.y + bottomRight.y) / 2))
            context.stroke(linePath, with: .color(color), style: StrokeStyle(lineWidth: 1))
            
            // Draw anchor point marker
            let anchorRect = CGRect(x: anchorPoint.x - 3, y: anchorPoint.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: anchorRect), with: .color(color))
        }
    }
    
    private func transformPoint(column: Double, row: Double, imageFrame: CGRect, units: AnnotationUnits) -> CGPoint {
        switch units {
        case .pixel:
            let normalizedX = CGFloat(column) / imageSize.width
            let normalizedY = CGFloat(row) / imageSize.height
            
            let x = imageFrame.origin.x + normalizedX * imageFrame.width * zoomScale + panOffset.width
            let y = imageFrame.origin.y + normalizedY * imageFrame.height * zoomScale + panOffset.height
            
            return CGPoint(x: x, y: y)
            
        case .display:
            // Display coordinates are normalized 0.0-1.0
            let x = imageFrame.origin.x + CGFloat(column) * imageFrame.width * zoomScale + panOffset.width
            let y = imageFrame.origin.y + CGFloat(row) * imageFrame.height * zoomScale + panOffset.height
            
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    PresentationStateOverlayView(
        presentationState: nil,
        imageSize: CGSize(width: 512, height: 512),
        viewSize: CGSize(width: 400, height: 400),
        zoomScale: 1.0,
        panOffset: .zero
    )
}
