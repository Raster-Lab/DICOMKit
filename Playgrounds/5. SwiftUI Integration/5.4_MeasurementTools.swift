// DICOMKit Sample Code: Interactive Measurement Tools
//
// This example demonstrates how to:
// - Draw measurements on DICOM images
// - Implement length measurements
// - Create angle measurements
// - Build ROI (Region of Interest) tools
// - Use gestures for measurement placement
// - Display measurement list
// - Convert between image and view coordinates
// - Calculate real-world measurements from pixel spacing

#if canImport(SwiftUI)
import SwiftUI
import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Measurement Models

enum MeasurementType: String, CaseIterable {
    case length = "Length"
    case angle = "Angle"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case freehand = "Freehand"
}

struct Measurement: Identifiable, Equatable {
    let id = UUID()
    let type: MeasurementType
    var points: [CGPoint]
    var label: String
    var value: Double?
    var unit: String?
    var color: Color = .yellow
    
    init(type: MeasurementType, points: [CGPoint] = [], label: String = "") {
        self.type = type
        self.points = points
        self.label = label
    }
}

// MARK: - Example 1: Basic Length Measurement

struct Example1_LengthMeasurement: View {
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var measurements: [Measurement] = []
    
    let imageSize: CGSize = CGSize(width: 512, height: 512)
    
    var body: some View {
        ZStack {
            // Image placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: imageSize.width, height: imageSize.height)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                }
            
            // Draw completed measurements
            ForEach(measurements) { measurement in
                if measurement.points.count == 2 {
                    LineMeasurementShape(
                        start: measurement.points[0],
                        end: measurement.points[1]
                    )
                    .stroke(measurement.color, lineWidth: 2)
                }
            }
            
            // Draw current measurement
            if let start = startPoint, let current = currentPoint {
                LineMeasurementShape(start: start, end: current)
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.location
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    if let start = startPoint {
                        let distance = start.distance(to: value.location)
                        var measurement = Measurement(
                            type: .length,
                            points: [start, value.location],
                            label: String(format: "%.1f px", distance)
                        )
                        measurement.value = distance
                        measurement.unit = "px"
                        measurements.append(measurement)
                    }
                    startPoint = nil
                    currentPoint = nil
                }
        )
        .frame(width: imageSize.width, height: imageSize.height)
    }
}

struct LineMeasurementShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        // Add endpoints
        path.addEllipse(in: CGRect(x: start.x - 3, y: start.y - 3,
                                   width: 6, height: 6))
        path.addEllipse(in: CGRect(x: end.x - 3, y: end.y - 3,
                                   width: 6, height: 6))
        
        return path
    }
}

// MARK: - Example 2: Angle Measurement

struct Example2_AngleMeasurement: View {
    @State private var points: [CGPoint] = []
    @State private var measurements: [Measurement] = []
    
    let imageSize: CGSize = CGSize(width: 512, height: 512)
    
    var body: some View {
        VStack {
            ZStack {
                // Image
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: imageSize.width, height: imageSize.height)
                
                // Draw measurements
                ForEach(measurements) { measurement in
                    if measurement.points.count == 3 {
                        AngleMeasurementShape(points: measurement.points)
                            .stroke(measurement.color, lineWidth: 2)
                    }
                }
                
                // Draw current points
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .position(point)
                }
                
                // Draw lines between points
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                }
            }
            .onTapGesture { location in
                points.append(location)
                
                if points.count == 3 {
                    // Calculate angle
                    let angle = calculateAngle(points: points)
                    var measurement = Measurement(
                        type: .angle,
                        points: points,
                        label: String(format: "%.1f°", angle)
                    )
                    measurement.value = angle
                    measurement.unit = "°"
                    measurements.append(measurement)
                    points.removeAll()
                }
            }
            .frame(width: imageSize.width, height: imageSize.height)
            
            Text(points.count == 0 ? "Tap to set first point" :
                 points.count == 1 ? "Tap to set vertex" :
                 "Tap to set third point")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func calculateAngle(points: [CGPoint]) -> Double {
        guard points.count == 3 else { return 0 }
        
        let p1 = points[0]
        let vertex = points[1]
        let p2 = points[2]
        
        // Vectors from vertex
        let v1 = CGPoint(x: p1.x - vertex.x, y: p1.y - vertex.y)
        let v2 = CGPoint(x: p2.x - vertex.x, y: p2.y - vertex.y)
        
        // Dot product and magnitudes
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        // Angle in radians, then degrees
        let angleRad = acos(dot / (mag1 * mag2))
        return angleRad * 180.0 / .pi
    }
}

struct AngleMeasurementShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        guard points.count == 3 else { return Path() }
        
        var path = Path()
        
        // Draw lines
        path.move(to: points[0])
        path.addLine(to: points[1])
        path.addLine(to: points[2])
        
        // Draw arc at vertex
        let radius: CGFloat = 30
        let vertex = points[1]
        
        let angle1 = atan2(points[0].y - vertex.y, points[0].x - vertex.x)
        let angle2 = atan2(points[2].y - vertex.y, points[2].x - vertex.x)
        
        path.addArc(center: vertex,
                   radius: radius,
                   startAngle: Angle(radians: Double(angle1)),
                   endAngle: Angle(radians: Double(angle2)),
                   clockwise: false)
        
        // Draw points
        for point in points {
            path.addEllipse(in: CGRect(x: point.x - 3, y: point.y - 3,
                                      width: 6, height: 6))
        }
        
        return path
    }
}

// MARK: - Example 3: Rectangle ROI

struct Example3_RectangleROI: View {
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var rectangles: [Measurement] = []
    
    let imageSize: CGSize = CGSize(width: 512, height: 512)
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: imageSize.width, height: imageSize.height)
            
            // Draw completed rectangles
            ForEach(rectangles) { roi in
                if roi.points.count == 2 {
                    Rectangle()
                        .path(in: rectFromPoints(roi.points[0], roi.points[1]))
                        .stroke(roi.color, lineWidth: 2)
                        .overlay {
                            Text(roi.label)
                                .font(.caption)
                                .foregroundColor(roi.color)
                                .position(midPoint(roi.points[0], roi.points[1]))
                        }
                }
            }
            
            // Draw current rectangle
            if let start = startPoint, let current = currentPoint {
                Rectangle()
                    .path(in: rectFromPoints(start, current))
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.location
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    if let start = startPoint {
                        let rect = rectFromPoints(start, value.location)
                        let area = rect.width * rect.height
                        var measurement = Measurement(
                            type: .rectangle,
                            points: [start, value.location],
                            label: String(format: "%.0f px²", area)
                        )
                        measurement.value = area
                        measurement.unit = "px²"
                        rectangles.append(measurement)
                    }
                    startPoint = nil
                    currentPoint = nil
                }
        )
        .frame(width: imageSize.width, height: imageSize.height)
    }
    
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let width = abs(p2.x - p1.x)
        let height = abs(p2.y - p1.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func midPoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
}

// MARK: - Example 4: Ellipse ROI

struct Example4_EllipseROI: View {
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var ellipses: [Measurement] = []
    
    let imageSize: CGSize = CGSize(width: 512, height: 512)
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: imageSize.width, height: imageSize.height)
            
            // Draw ellipses
            ForEach(ellipses) { roi in
                if roi.points.count == 2 {
                    Ellipse()
                        .path(in: rectFromPoints(roi.points[0], roi.points[1]))
                        .stroke(roi.color, lineWidth: 2)
                }
            }
            
            // Draw current ellipse
            if let start = startPoint, let current = currentPoint {
                Ellipse()
                    .path(in: rectFromPoints(start, current))
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.location
                    }
                    currentPoint = value.location
                }
                .onEnded { value in
                    if let start = startPoint {
                        let rect = rectFromPoints(start, value.location)
                        let area = .pi * (rect.width / 2) * (rect.height / 2)
                        var measurement = Measurement(
                            type: .ellipse,
                            points: [start, value.location],
                            label: String(format: "%.0f px²", area)
                        )
                        measurement.value = area
                        measurement.unit = "px²"
                        ellipses.append(measurement)
                    }
                    startPoint = nil
                    currentPoint = nil
                }
        )
        .frame(width: imageSize.width, height: imageSize.height)
    }
    
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        let x = min(p1.x, p2.x)
        let y = min(p1.y, p2.y)
        let width = abs(p2.x - p1.x)
        let height = abs(p2.y - p1.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Example 5: Freehand Drawing

struct Example5_FreehandROI: View {
    @State private var currentPath: [CGPoint] = []
    @State private var paths: [Measurement] = []
    
    let imageSize: CGSize = CGSize(width: 512, height: 512)
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: imageSize.width, height: imageSize.height)
            
            // Draw completed paths
            ForEach(paths) { roi in
                FreehandPath(points: roi.points)
                    .stroke(roi.color, lineWidth: 2)
            }
            
            // Draw current path
            if !currentPath.isEmpty {
                FreehandPath(points: currentPath)
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    currentPath.append(value.location)
                }
                .onEnded { _ in
                    if !currentPath.isEmpty {
                        var measurement = Measurement(
                            type: .freehand,
                            points: currentPath,
                            label: "Freehand"
                        )
                        paths.append(measurement)
                        currentPath.removeAll()
                    }
                }
        )
        .frame(width: imageSize.width, height: imageSize.height)
    }
}

struct FreehandPath: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        guard !points.isEmpty else { return Path() }
        
        var path = Path()
        path.move(to: points[0])
        
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        return path
    }
}

// MARK: - Example 6: Measurement List View

struct Example6_MeasurementList: View {
    @State private var measurements: [Measurement] = [
        Measurement(type: .length, points: [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)], label: "45.3 mm"),
        Measurement(type: .angle, points: [CGPoint(x: 50, y: 50), CGPoint(x: 100, y: 100), CGPoint(x: 150, y: 50)], label: "90.0°"),
        Measurement(type: .rectangle, points: [CGPoint(x: 20, y: 20), CGPoint(x: 80, y: 80)], label: "3600 px²")
    ]
    
    var body: some View {
        List {
            ForEach(measurements) { measurement in
                HStack {
                    Image(systemName: iconForType(measurement.type))
                        .foregroundColor(measurement.color)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(measurement.type.rawValue)
                            .font(.headline)
                        Text(measurement.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        deleteMeasurement(measurement)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Measurements")
    }
    
    private func iconForType(_ type: MeasurementType) -> String {
        switch type {
        case .length: return "ruler"
        case .angle: return "angle"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .freehand: return "scribble"
        }
    }
    
    private func deleteMeasurement(_ measurement: Measurement) {
        measurements.removeAll { $0.id == measurement.id }
    }
    
    private func delete(at offsets: IndexSet) {
        measurements.remove(atOffsets: offsets)
    }
}

// MARK: - Example 7: Real-World Measurements with Pixel Spacing

struct Example7_RealWorldMeasurements: View {
    let dicomFile: DICOMFile
    
    @State private var measurements: [Measurement] = []
    @State private var pixelSpacing: (Double, Double)?
    
    var body: some View {
        VStack {
            Text("Pixel Spacing: \(pixelSpacingText)")
                .font(.caption)
                .padding()
            
            // Measurement interface
            Text("Draw measurements here")
            
            List(measurements) { measurement in
                HStack {
                    Text(measurement.type.rawValue)
                    Spacer()
                    Text(measurement.label)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            loadPixelSpacing()
        }
    }
    
    private var pixelSpacingText: String {
        guard let spacing = pixelSpacing else {
            return "Not available"
        }
        return String(format: "%.2f × %.2f mm", spacing.0, spacing.1)
    }
    
    private func loadPixelSpacing() {
        let dataSet = dicomFile.dataSet
        
        // Try Pixel Spacing (0028,0030)
        if let spacingStrings = dataSet.strings(for: .pixelSpacing),
           spacingStrings.count == 2,
           let rowSpacing = Double(spacingStrings[0]),
           let colSpacing = Double(spacingStrings[1]) {
            pixelSpacing = (rowSpacing, colSpacing)
            return
        }
        
        // Try Imager Pixel Spacing (0018,1164)
        if let spacingStrings = dataSet.strings(for: .imagerPixelSpacing),
           spacingStrings.count == 2,
           let rowSpacing = Double(spacingStrings[0]),
           let colSpacing = Double(spacingStrings[1]) {
            pixelSpacing = (rowSpacing, colSpacing)
        }
    }
    
    private func calculateRealLength(pixelLength: Double) -> Double? {
        guard let spacing = pixelSpacing else { return nil }
        // Assuming isotropic or using average
        let avgSpacing = (spacing.0 + spacing.1) / 2.0
        return pixelLength * avgSpacing
    }
}

// MARK: - Example 8: Coordinate Conversion

struct CoordinateConverter {
    let imageSize: CGSize
    let viewSize: CGSize
    let scale: CGFloat
    let offset: CGSize
    
    /// Convert view coordinates to image coordinates
    func viewToImage(_ point: CGPoint) -> CGPoint {
        let x = (point.x - offset.width) / scale
        let y = (point.y - offset.height) / scale
        return CGPoint(x: x, y: y)
    }
    
    /// Convert image coordinates to view coordinates
    func imageToView(_ point: CGPoint) -> CGPoint {
        let x = point.x * scale + offset.width
        let y = point.y * scale + offset.height
        return CGPoint(x: x, y: y)
    }
    
    /// Convert pixel distance to real-world distance (mm)
    func pixelToMM(_ pixelDistance: Double, pixelSpacing: (Double, Double)) -> Double {
        let avgSpacing = (pixelSpacing.0 + pixelSpacing.1) / 2.0
        return pixelDistance * avgSpacing
    }
}

struct Example8_CoordinateConversion: View {
    @State private var imagePoint: CGPoint = .zero
    @State private var viewPoint: CGPoint = .zero
    
    let imageSize = CGSize(width: 512, height: 512)
    let viewSize = CGSize(width: 400, height: 400)
    let scale: CGFloat = 0.78  // viewSize / imageSize
    
    var converter: CoordinateConverter {
        CoordinateConverter(
            imageSize: imageSize,
            viewSize: viewSize,
            scale: scale,
            offset: .zero
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: viewSize.width, height: viewSize.height)
                .overlay {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(viewPoint)
                }
                .onTapGesture { location in
                    viewPoint = location
                    imagePoint = converter.viewToImage(location)
                }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("View Coordinates: (\(Int(viewPoint.x)), \(Int(viewPoint.y)))")
                Text("Image Coordinates: (\(Int(imagePoint.x)), \(Int(imagePoint.y)))")
            }
            .font(.caption)
            .monospacedDigit()
        }
    }
}

// MARK: - Example 9: Complete Measurement Tool

struct Example9_CompleteMeasurementTool: View {
    let dicomFile: DICOMFile
    let displayImage: CGImage
    
    @State private var selectedTool: MeasurementType = .length
    @State private var measurements: [Measurement] = []
    @State private var currentPoints: [CGPoint] = []
    @State private var pixelSpacing: (Double, Double)?
    @State private var showMeasurements = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                ForEach(MeasurementType.allCases, id: \.self) { tool in
                    Button(action: { selectTool(tool) }) {
                        VStack {
                            Image(systemName: iconForTool(tool))
                            Text(tool.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Image with measurements
            GeometryReader { geometry in
                ZStack {
                    // DICOM Image
                    #if os(macOS)
                    Image(displayImage, scale: 1.0, label: Text(""))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    #else
                    Image(uiImage: UIImage(cgImage: displayImage))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    #endif
                    
                    // Measurements overlay
                    if showMeasurements {
                        MeasurementOverlay(
                            measurements: measurements,
                            currentPoints: currentPoints,
                            currentTool: selectedTool
                        )
                    }
                }
                .gesture(measurementGesture(in: geometry.size))
            }
            
            Divider()
            
            // Measurement list
            ScrollView {
                LazyVStack {
                    ForEach(measurements) { measurement in
                        MeasurementRow(
                            measurement: measurement,
                            pixelSpacing: pixelSpacing
                        )
                        .onTapGesture {
                            // Highlight measurement
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .task {
            loadPixelSpacing()
        }
    }
    
    private func selectTool(_ tool: MeasurementType) {
        selectedTool = tool
        currentPoints.removeAll()
    }
    
    private func measurementGesture(in viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleDragChanged(value.location)
            }
            .onEnded { value in
                handleDragEnded(value.location)
            }
    }
    
    private func handleDragChanged(_ location: CGPoint) {
        switch selectedTool {
        case .length, .rectangle, .ellipse:
            if currentPoints.isEmpty {
                currentPoints.append(location)
            } else {
                currentPoints[currentPoints.count - 1] = location
            }
        case .freehand:
            currentPoints.append(location)
        case .angle:
            // Handle angle points separately
            break
        }
    }
    
    private func handleDragEnded(_ location: CGPoint) {
        switch selectedTool {
        case .length:
            if currentPoints.count >= 1 {
                let distance = currentPoints[0].distance(to: location)
                finalizeMeasurement(
                    type: .length,
                    points: [currentPoints[0], location],
                    value: distance
                )
            }
        case .rectangle, .ellipse:
            if currentPoints.count >= 1 {
                finalizeMeasurement(
                    type: selectedTool,
                    points: [currentPoints[0], location],
                    value: 0
                )
            }
        case .freehand:
            if !currentPoints.isEmpty {
                finalizeMeasurement(
                    type: .freehand,
                    points: currentPoints,
                    value: 0
                )
            }
        case .angle:
            // Handle angle completion
            break
        }
        
        currentPoints.removeAll()
    }
    
    private func finalizeMeasurement(type: MeasurementType, points: [CGPoint], value: Double) {
        var measurement = Measurement(type: type, points: points)
        
        if let spacing = pixelSpacing {
            let realValue = value * (spacing.0 + spacing.1) / 2.0
            measurement.label = String(format: "%.1f mm", realValue)
            measurement.value = realValue
            measurement.unit = "mm"
        } else {
            measurement.label = String(format: "%.1f px", value)
            measurement.value = value
            measurement.unit = "px"
        }
        
        measurements.append(measurement)
    }
    
    private func loadPixelSpacing() {
        let dataSet = dicomFile.dataSet
        if let spacingStrings = dataSet.strings(for: .pixelSpacing),
           spacingStrings.count == 2,
           let row = Double(spacingStrings[0]),
           let col = Double(spacingStrings[1]) {
            pixelSpacing = (row, col)
        }
    }
    
    private func iconForTool(_ tool: MeasurementType) -> String {
        switch tool {
        case .length: return "ruler"
        case .angle: return "angle"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .freehand: return "scribble"
        }
    }
}

struct MeasurementOverlay: View {
    let measurements: [Measurement]
    let currentPoints: [CGPoint]
    let currentTool: MeasurementType
    
    var body: some View {
        ZStack {
            // Draw completed measurements
            ForEach(measurements) { measurement in
                MeasurementShape(measurement: measurement)
                    .stroke(measurement.color, lineWidth: 2)
            }
            
            // Draw current measurement
            if !currentPoints.isEmpty {
                let current = Measurement(type: currentTool, points: currentPoints)
                MeasurementShape(measurement: current)
                    .stroke(Color.yellow, lineWidth: 2)
            }
        }
    }
}

struct MeasurementShape: Shape {
    let measurement: Measurement
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch measurement.type {
        case .length:
            if measurement.points.count == 2 {
                path.move(to: measurement.points[0])
                path.addLine(to: measurement.points[1])
            }
        case .rectangle:
            if measurement.points.count == 2 {
                let rect = rectFromPoints(measurement.points[0], measurement.points[1])
                path.addRect(rect)
            }
        case .ellipse:
            if measurement.points.count == 2 {
                let rect = rectFromPoints(measurement.points[0], measurement.points[1])
                path.addEllipse(in: rect)
            }
        case .freehand:
            if !measurement.points.isEmpty {
                path.move(to: measurement.points[0])
                for point in measurement.points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        case .angle:
            if measurement.points.count == 3 {
                path.move(to: measurement.points[0])
                path.addLine(to: measurement.points[1])
                path.addLine(to: measurement.points[2])
            }
        }
        
        return path
    }
    
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }
}

struct MeasurementRow: View {
    let measurement: Measurement
    let pixelSpacing: (Double, Double)?
    
    var body: some View {
        HStack {
            Image(systemName: iconForType(measurement.type))
                .foregroundColor(measurement.color)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(measurement.type.rawValue)
                    .font(.headline)
                Text(measurement.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func iconForType(_ type: MeasurementType) -> String {
        switch type {
        case .length: return "ruler"
        case .angle: return "angle"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .freehand: return "scribble"
        }
    }
}

// MARK: - Utility Extensions

extension CGPoint {
    func distance(to point: CGPoint) -> Double {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(Double(dx * dx + dy * dy))
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples in your app:
// Example1_LengthMeasurement()
// Example2_AngleMeasurement()
// Example3_RectangleROI()
// Example4_EllipseROI()
// Example5_FreehandROI()
// Example6_MeasurementList()

// MARK: - Quick Reference

/*
 SwiftUI Measurement Tools:
 
 Measurement Types:
 • Length         - Two-point distance
 • Angle          - Three-point angle
 • Rectangle ROI  - Rectangular region
 • Ellipse ROI    - Elliptical region
 • Freehand       - Custom drawn path
 
 Gestures for Drawing:
 • DragGesture    - Draw measurements
 • TapGesture     - Place points
 • onChanged      - Live preview
 • onEnded        - Finalize measurement
 
 Shape Drawing:
 • Path           - Custom shapes
 • .stroke()      - Outline shapes
 • .fill()        - Fill shapes
 • ZStack         - Layer measurements
 
 Coordinate Systems:
 • View coordinates   - Screen space
 • Image coordinates  - Pixel space
 • Real-world coords  - Physical units (mm)
 • Transform between  - Converter helper
 
 Pixel Spacing:
 • Tag (0028,0030)    - Pixel Spacing
 • Tag (0018,1164)    - Imager Pixel Spacing
 • Format: [row, col] - Two values in mm
 • Calculate real     - pixel × spacing
 
 Distance Calculation:
 • Pythagorean        - √(dx² + dy²)
 • Real distance      - pixel distance × spacing
 • Area (rectangle)   - width × height
 • Area (ellipse)     - π × (w/2) × (h/2)
 
 Angle Calculation:
 • Dot product        - v1 · v2
 • Magnitudes         - |v1| × |v2|
 • Cosine formula     - cos(θ) = dot / (mag1 × mag2)
 • Convert to degrees - radians × 180 / π
 
 State Management:
 • @State for points  - Current drawing
 • Array of measurements - Completed list
 • Selected tool      - Active tool
 • Current points     - In-progress drawing
 
 Common Patterns:
 
 Length Measurement:
 • Drag to set two points
 • Calculate distance
 • Display with line and endpoints
 • Convert to mm if pixel spacing available
 
 Angle Measurement:
 • Three tap/click points
 • First: line start
 • Second: vertex (angle point)
 • Third: second line end
 • Draw arc at vertex
 
 ROI Drawing:
 • Drag from corner to corner
 • Show preview during drag
 • Finalize on drag end
 • Calculate area
 
 Freehand Drawing:
 • Collect points during drag
 • Connect with lines
 • Optional smoothing
 • Close path if desired
 
 Best Practices:
 
 1. Convert coordinates properly
 2. Use pixel spacing for real measurements
 3. Provide visual feedback during drawing
 4. Allow deletion/editing of measurements
 5. Show measurement values clearly
 6. Support different measurement types
 7. Save measurements with image
 8. Export measurements to DICOM SR
 9. Handle zoom/pan transformations
 10. Validate measurement geometry
 
 Performance:
 
 1. Use Shape for efficient drawing
 2. Avoid redrawing all measurements
 3. Cache measurement paths
 4. Optimize freehand point count
 5. Use LazyVStack for measurement list
 
 DICOM Tags:
 • .pixelSpacing (0028,0030)
 • .imagerPixelSpacing (0018,1164)
 • .sliceThickness (0018,0050)
 • .spacingBetweenSlices (0018,0088)
 
 Real-World Conversions:
 • Length: pixels × spacing (mm)
 • Area: pixels² × spacing² (mm²)
 • Volume: pixels³ × spacing³ (mm³)
 • Angle: always in degrees
 
 Structured Reporting:
 • Export to DICOM SR
 • Use measurement templates
 • Include source image reference
 • Store in TID 1500 format
 • Link to image coordinates
 
 Tips:
 
 1. Always check for pixel spacing
 2. Handle missing spacing gracefully
 3. Show units (px vs mm) clearly
 4. Allow switching between units
 5. Validate measurement geometry
 6. Provide measurement templates
 7. Support measurement editing
 8. Enable copy/paste of values
 9. Export to clipboard/file
 10. Integrate with PACS reporting
 */

#endif // canImport(SwiftUI)
