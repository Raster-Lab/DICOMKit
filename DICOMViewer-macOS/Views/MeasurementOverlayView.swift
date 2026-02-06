//
//  MeasurementOverlayView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI
import AppKit

/// View for rendering measurement annotations on top of DICOM images
struct MeasurementOverlayView: View {
    let measurements: [Measurement]
    let selectedIDs: Set<UUID>
    let showLabels: Bool
    let showValues: Bool
    let imageSize: CGSize
    let viewSize: CGSize
    let zoom: CGFloat
    let offset: CGSize
    
    var body: some View {
        Canvas { context, size in
            for measurement in measurements where measurement.isVisible {
                let isSelected = selectedIDs.contains(measurement.id)
                drawMeasurement(context: context, measurement: measurement, isSelected: isSelected)
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Drawing Methods
    
    private func drawMeasurement(context: GraphicsContext, measurement: Measurement, isSelected: Bool) {
        let color = colorFromHex(measurement.colorHex)
        let strokeWidth: CGFloat = isSelected ? 3.0 : 2.0
        
        switch measurement.type {
        case .length:
            drawLength(context: context, measurement: measurement, color: color, strokeWidth: strokeWidth)
        case .angle:
            drawAngle(context: context, measurement: measurement, color: color, strokeWidth: strokeWidth)
        case .ellipse:
            drawEllipse(context: context, measurement: measurement, color: color, strokeWidth: strokeWidth)
        case .rectangle:
            drawRectangle(context: context, measurement: measurement, color: color, strokeWidth: strokeWidth)
        case .polygon:
            drawPolygon(context: context, measurement: measurement, color: color, strokeWidth: strokeWidth)
        }
    }
    
    private func drawLength(context: GraphicsContext, measurement: Measurement, color: Color, strokeWidth: CGFloat) {
        guard measurement.points.count >= 2 else { return }
        
        let p1 = imageToScreen(measurement.points[0])
        let p2 = imageToScreen(measurement.points[1])
        
        // Draw line
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw endpoints
        drawCircle(context: context, at: p1, color: color, strokeWidth: strokeWidth)
        drawCircle(context: context, at: p2, color: color, strokeWidth: strokeWidth)
        
        // Draw arrows at endpoints
        drawArrowHead(context: context, from: p2, to: p1, color: color, strokeWidth: strokeWidth)
        drawArrowHead(context: context, from: p1, to: p2, color: color, strokeWidth: strokeWidth)
        
        // Draw value label at midpoint
        if showValues || showLabels {
            let midpoint = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            var labelText = ""
            if let label = measurement.label, showLabels {
                labelText = label + ": "
            }
            if showValues {
                labelText += measurement.formattedValue
            }
            drawText(context: context, text: labelText, at: midpoint, color: color)
        }
    }
    
    private func drawAngle(context: GraphicsContext, measurement: Measurement, color: Color, strokeWidth: CGFloat) {
        guard measurement.points.count >= 3 else { return }
        
        let p1 = imageToScreen(measurement.points[0])
        let vertex = imageToScreen(measurement.points[1])
        let p2 = imageToScreen(measurement.points[2])
        
        // Draw lines from vertex to points
        var path = Path()
        path.move(to: vertex)
        path.addLine(to: p1)
        path.move(to: vertex)
        path.addLine(to: p2)
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw points
        drawCircle(context: context, at: p1, color: color, strokeWidth: strokeWidth)
        drawCircle(context: context, at: vertex, color: color, strokeWidth: strokeWidth)
        drawCircle(context: context, at: p2, color: color, strokeWidth: strokeWidth)
        
        // Draw angle arc
        let radius: CGFloat = 30
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)
        let startAngle = atan2(v1.dy, v1.dx)
        let endAngle = atan2(v2.dy, v2.dx)
        
        var arcPath = Path()
        arcPath.addArc(
            center: vertex,
            radius: radius,
            startAngle: Angle(radians: Double(startAngle)),
            endAngle: Angle(radians: Double(endAngle)),
            clockwise: false
        )
        
        context.stroke(
            arcPath,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw value label near vertex
        if showValues || showLabels {
            var labelText = ""
            if let label = measurement.label, showLabels {
                labelText = label + ": "
            }
            if showValues {
                labelText += measurement.formattedValue
            }
            let labelPos = CGPoint(
                x: vertex.x + radius * 1.5 * cos(CGFloat((startAngle + endAngle) / 2)),
                y: vertex.y + radius * 1.5 * sin(CGFloat((startAngle + endAngle) / 2))
            )
            drawText(context: context, text: labelText, at: labelPos, color: color)
        }
    }
    
    private func drawEllipse(context: GraphicsContext, measurement: Measurement, color: Color, strokeWidth: CGFloat) {
        guard measurement.points.count >= 2 else { return }
        
        let p1 = imageToScreen(measurement.points[0])
        let p2 = imageToScreen(measurement.points[1])
        
        let rect = CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
        
        let path = Path(ellipseIn: rect)
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw corner handles
        drawCircle(context: context, at: p1, color: color, strokeWidth: strokeWidth)
        drawCircle(context: context, at: p2, color: color, strokeWidth: strokeWidth)
        
        // Draw value label at center
        if showValues || showLabels {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var labelText = ""
            if let label = measurement.label, showLabels {
                labelText = label + ": "
            }
            if showValues {
                labelText += measurement.formattedValue
            }
            drawText(context: context, text: labelText, at: center, color: color)
        }
    }
    
    private func drawRectangle(context: GraphicsContext, measurement: Measurement, color: Color, strokeWidth: CGFloat) {
        guard measurement.points.count >= 2 else { return }
        
        let p1 = imageToScreen(measurement.points[0])
        let p2 = imageToScreen(measurement.points[1])
        
        let rect = CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
        
        let path = Path(rect)
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw corner handles
        drawCircle(context: context, at: p1, color: color, strokeWidth: strokeWidth)
        drawCircle(context: context, at: p2, color: color, strokeWidth: strokeWidth)
        
        // Draw value label at center
        if showValues || showLabels {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var labelText = ""
            if let label = measurement.label, showLabels {
                labelText = label + ": "
            }
            if showValues {
                labelText += measurement.formattedValue
            }
            drawText(context: context, text: labelText, at: center, color: color)
        }
    }
    
    private func drawPolygon(context: GraphicsContext, measurement: Measurement, color: Color, strokeWidth: CGFloat) {
        guard measurement.points.count >= 2 else { return }
        
        var path = Path()
        let firstPoint = imageToScreen(measurement.points[0])
        path.move(to: firstPoint)
        
        for i in 1..<measurement.points.count {
            let point = imageToScreen(measurement.points[i])
            path.addLine(to: point)
        }
        
        // Close the polygon if there are 3+ points
        if measurement.points.count >= 3 {
            path.closeSubpath()
        }
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
        
        // Draw vertex points
        for point in measurement.points {
            let screenPoint = imageToScreen(point)
            drawCircle(context: context, at: screenPoint, color: color, strokeWidth: strokeWidth)
        }
        
        // Draw value label at centroid
        if (showValues || showLabels) && measurement.points.count >= 3 {
            let centroid = calculateCentroid(measurement.points)
            let screenCentroid = imageToScreen(centroid)
            var labelText = ""
            if let label = measurement.label, showLabels {
                labelText = label + ": "
            }
            if showValues {
                labelText += measurement.formattedValue
            }
            drawText(context: context, text: labelText, at: screenCentroid, color: color)
        }
    }
    
    // MARK: - Helper Drawing Methods
    
    private func drawCircle(context: GraphicsContext, at point: CGPoint, color: Color, strokeWidth: CGFloat) {
        let radius: CGFloat = 4
        let circle = Path(ellipseIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        
        context.fill(circle, with: .color(color))
        context.stroke(circle, with: .color(.black), lineWidth: 1)
    }
    
    private func drawArrowHead(context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color, strokeWidth: CGFloat) {
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let angle = atan2(dy, dx)
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var path = Path()
        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)
        
        context.stroke(
            path,
            with: .color(color),
            lineWidth: strokeWidth
        )
    }
    
    private func drawText(context: GraphicsContext, text: String, at point: CGPoint, color: Color) {
        var attributedText = AttributedString(text)
        attributedText.font = .system(size: 12, weight: .medium)
        attributedText.foregroundColor = color
        
        let textSize = text.boundingRect(
            with: CGSize(width: 200, height: 50),
            options: .usesLineFragmentOrigin,
            attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)],
            context: nil
        ).size
        
        // Draw background
        let padding: CGFloat = 4
        let bgRect = CGRect(
            x: point.x - textSize.width / 2 - padding,
            y: point.y - textSize.height / 2 - padding,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        
        context.fill(
            Path(roundedRect: bgRect, cornerRadius: 4),
            with: .color(.black.opacity(0.7))
        )
        
        // Draw text
        context.draw(
            Text(attributedText),
            at: point,
            anchor: .center
        )
    }
    
    // MARK: - Coordinate Transformation
    
    private func imageToScreen(_ imagePoint: ImagePoint) -> CGPoint {
        let cgPoint = imagePoint.cgPoint
        
        // Apply zoom and offset
        let scaledX = cgPoint.x * zoom + offset.width
        let scaledY = cgPoint.y * zoom + offset.height
        
        return CGPoint(x: scaledX, y: scaledY)
    }
    
    private func calculateCentroid(_ points: [ImagePoint]) -> ImagePoint {
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        let count = Double(points.count)
        return ImagePoint(x: sumX / count, y: sumY / count)
    }
    
    // MARK: - Color Utilities
    
    private func colorFromHex(_ hex: String) -> Color {
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview

#Preview {
    let measurements = [
        Measurement(
            type: .length,
            points: [
                ImagePoint(x: 100, y: 100),
                ImagePoint(x: 200, y: 150)
            ],
            pixelSpacing: (row: 0.5, column: 0.5)
        ),
        Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 150, y: 200),
                ImagePoint(x: 200, y: 250),
                ImagePoint(x: 250, y: 200)
            ]
        ),
        Measurement(
            type: .ellipse,
            points: [
                ImagePoint(x: 300, y: 100),
                ImagePoint(x: 400, y: 200)
            ]
        )
    ]
    
    MeasurementOverlayView(
        measurements: measurements,
        selectedIDs: [],
        showLabels: true,
        showValues: true,
        imageSize: CGSize(width: 512, height: 512),
        viewSize: CGSize(width: 600, height: 600),
        zoom: 1.0,
        offset: .zero
    )
    .frame(width: 600, height: 600)
    .background(Color.gray.opacity(0.3))
}
