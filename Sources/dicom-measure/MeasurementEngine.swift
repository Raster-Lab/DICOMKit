/// Measurement engine for DICOM images
///
/// Provides coordinate transforms, distance, area, angle, ROI statistics,
/// and Hounsfield Unit extraction from DICOM pixel data.

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Core measurement engine that reads pixel data and calibration from DICOM files
struct MeasurementEngine {
    let dicomFile: DICOMFile
    let dataSet: DataSet
    let rowSpacing: Double
    let columnSpacing: Double
    let rows: Int
    let columns: Int
    let rescaleSlope: Double
    let rescaleIntercept: Double
    let bitsAllocated: Int
    let bitsStored: Int
    let isSigned: Bool
    let pixelDataBytes: Data?
    let verbose: Bool

    init(options: CommonOptions) throws {
        let fileURL = URL(fileURLWithPath: options.filePath)

        guard FileManager.default.fileExists(atPath: options.filePath) else {
            throw MeasureError.fileNotFound(options.filePath)
        }

        let fileData = try Data(contentsOf: fileURL)
        self.dicomFile = try DICOMFile.read(from: fileData, force: options.force)
        self.dataSet = dicomFile.dataSet
        self.verbose = options.verbose

        // Image dimensions
        guard let r = dataSet.uint16(for: .rows), let c = dataSet.uint16(for: .columns) else {
            throw MeasureError.missingImageDimensions
        }
        self.rows = Int(r)
        self.columns = Int(c)

        // Pixel spacing (default to 1.0 mm if not present)
        if let spacings = dataSet.decimalStrings(for: .pixelSpacing), spacings.count >= 2 {
            self.rowSpacing = spacings[0].value
            self.columnSpacing = spacings[1].value
        } else {
            self.rowSpacing = 1.0
            self.columnSpacing = 1.0
            if verbose {
                print("Warning: Pixel Spacing not found, using 1.0 mm default")
            }
        }

        // Rescale slope/intercept
        self.rescaleSlope = dataSet.rescaleSlope()
        self.rescaleIntercept = dataSet.rescaleIntercept()

        // Bit depth
        if let ba = dataSet.uint16(for: .bitsAllocated) {
            self.bitsAllocated = Int(ba)
        } else {
            self.bitsAllocated = 16
        }
        if let bs = dataSet.uint16(for: .bitsStored) {
            self.bitsStored = Int(bs)
        } else {
            self.bitsStored = self.bitsAllocated
        }
        if let pr = dataSet.uint16(for: .pixelRepresentation) {
            self.isSigned = pr == 1
        } else {
            self.isSigned = false
        }

        // Pixel data
        if let pd = dataSet.pixelData() {
            self.pixelDataBytes = pd.data
        } else {
            self.pixelDataBytes = nil
        }

        if verbose {
            print("Image: \(columns)x\(rows), spacing: \(columnSpacing)x\(rowSpacing) mm")
            print("Bits: \(bitsAllocated) allocated, \(bitsStored) stored, signed: \(isSigned)")
            print("Rescale: slope=\(rescaleSlope), intercept=\(rescaleIntercept)")
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert pixel distance to physical distance in the specified unit
    func pixelToPhysical(dx: Double, dy: Double, unit: MeasurementUnit) -> Double {
        let physicalDx = dx * columnSpacing
        let physicalDy = dy * rowSpacing
        let distanceMM = sqrt(physicalDx * physicalDx + physicalDy * physicalDy)

        switch unit {
        case .mm: return distanceMM
        case .cm: return distanceMM / 10.0
        case .inches: return distanceMM / 25.4
        case .pixels: return sqrt(dx * dx + dy * dy)
        }
    }

    /// Convert pixel area to physical area in the specified unit
    func pixelAreaToPhysical(pixelArea: Double, unit: MeasurementUnit) -> Double {
        let physicalArea = pixelArea * columnSpacing * rowSpacing

        switch unit {
        case .mm: return physicalArea
        case .cm: return physicalArea / 100.0
        case .inches: return physicalArea / (25.4 * 25.4)
        case .pixels: return pixelArea
        }
    }

    /// Get the area unit label
    func areaUnitLabel(_ unit: MeasurementUnit) -> String {
        switch unit {
        case .mm: return "mm²"
        case .cm: return "cm²"
        case .inches: return "in²"
        case .pixels: return "px²"
        }
    }

    /// Get the distance unit label
    func distanceUnitLabel(_ unit: MeasurementUnit) -> String {
        switch unit {
        case .mm: return "mm"
        case .cm: return "cm"
        case .inches: return "in"
        case .pixels: return "px"
        }
    }

    // MARK: - Distance Measurement

    /// Measure distance between two points
    func measureDistance(from p1: PixelPoint, to p2: PixelPoint, unit: MeasurementUnit) -> MeasurementResult {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let distance = pixelToPhysical(dx: dx, dy: dy, unit: unit)

        return MeasurementResult(
            value: distance,
            unitLabel: distanceUnitLabel(unit),
            description: "Distance"
        )
    }

    // MARK: - Area Measurement

    /// Measure polygon area using the Shoelace formula
    func measurePolygonArea(vertices: [PixelPoint], unit: MeasurementUnit) -> MeasurementResult {
        let pixelArea = shoelaceArea(vertices: vertices)
        let area = pixelAreaToPhysical(pixelArea: pixelArea, unit: unit)

        return MeasurementResult(
            value: area,
            unitLabel: areaUnitLabel(unit),
            description: "Polygon area (\(vertices.count) vertices)"
        )
    }

    /// Measure ellipse area
    func measureEllipseArea(center: PixelPoint, radiusX: Double, radiusY: Double, unit: MeasurementUnit) -> MeasurementResult {
        let pixelArea = Double.pi * radiusX * radiusY
        let area = pixelAreaToPhysical(pixelArea: pixelArea, unit: unit)

        return MeasurementResult(
            value: area,
            unitLabel: areaUnitLabel(unit),
            description: "Ellipse area"
        )
    }

    /// Shoelace formula for polygon area
    private func shoelaceArea(vertices: [PixelPoint]) -> Double {
        guard vertices.count >= 3 else { return 0.0 }

        var area = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            area += vertices[i].x * vertices[j].y
            area -= vertices[j].x * vertices[i].y
        }
        return abs(area) / 2.0
    }

    // MARK: - Angle Measurement

    /// Measure angle between two lines sharing a vertex
    func measureAngle(vertex: PixelPoint, p1: PixelPoint, p2: PixelPoint) -> MeasurementResult {
        let v1x = p1.x - vertex.x
        let v1y = p1.y - vertex.y
        let v2x = p2.x - vertex.x
        let v2y = p2.y - vertex.y

        let dot = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)

        guard mag1 > 0 && mag2 > 0 else {
            return MeasurementResult(value: 0.0, unitLabel: "°", description: "Angle")
        }

        let cosAngle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        let angleRadians = acos(cosAngle)
        let angleDegrees = angleRadians * 180.0 / Double.pi

        return MeasurementResult(
            value: angleDegrees,
            unitLabel: "°",
            description: "Angle"
        )
    }

    // MARK: - Pixel Value Access

    /// Get the raw stored pixel value at a given coordinate
    func rawPixelValue(at point: PixelPoint, frame: Int = 0) throws -> Double {
        guard let data = pixelDataBytes else {
            throw MeasureError.noPixelData
        }

        let x = Int(point.x)
        let y = Int(point.y)

        guard x >= 0, x < columns, y >= 0, y < rows else {
            throw MeasureError.pointOutOfBounds(x: x, y: y, columns: columns, rows: rows)
        }

        let bytesPerPixel = bitsAllocated / 8
        let pixelsPerFrame = rows * columns
        let frameOffset = frame * pixelsPerFrame * bytesPerPixel
        let pixelOffset = frameOffset + (y * columns + x) * bytesPerPixel

        guard pixelOffset + bytesPerPixel <= data.count else {
            throw MeasureError.pixelDataTooShort
        }

        if bytesPerPixel == 2 {
            let rawValue = data.withUnsafeBytes { buffer -> UInt16 in
                buffer.load(fromByteOffset: pixelOffset, as: UInt16.self)
            }
            if isSigned {
                return Double(Int16(bitPattern: rawValue))
            }
            return Double(rawValue)
        } else if bytesPerPixel == 1 {
            let rawValue = data[pixelOffset]
            if isSigned {
                return Double(Int8(bitPattern: rawValue))
            }
            return Double(rawValue)
        } else if bytesPerPixel == 4 {
            let rawValue = data.withUnsafeBytes { buffer -> UInt32 in
                buffer.load(fromByteOffset: pixelOffset, as: UInt32.self)
            }
            if isSigned {
                return Double(Int32(bitPattern: rawValue))
            }
            return Double(rawValue)
        }

        throw MeasureError.unsupportedBitDepth(bitsAllocated)
    }

    /// Get rescaled pixel value (applies rescale slope/intercept)
    func rescaledPixelValue(at point: PixelPoint, frame: Int = 0) throws -> Double {
        let raw = try rawPixelValue(at: point, frame: frame)
        return rescaleSlope * raw + rescaleIntercept
    }

    // MARK: - Pixel Value Extraction

    /// Measure raw pixel value at a point
    func measurePixelValue(at point: PixelPoint, frame: Int = 0) throws -> MeasurementResult {
        let raw = try rawPixelValue(at: point, frame: frame)
        let rescaled = rescaleSlope * raw + rescaleIntercept

        let description: String
        if rescaleSlope != 1.0 || rescaleIntercept != 0.0 {
            description = "Pixel value (raw=\(formatValue(raw)), rescaled)"
        } else {
            description = "Pixel value"
        }

        return MeasurementResult(
            value: rescaled,
            unitLabel: "",
            description: description
        )
    }

    // MARK: - Hounsfield Unit Measurement

    /// Measure Hounsfield Unit at a point (CT images)
    func measureHU(at point: PixelPoint) throws -> MeasurementResult {
        let hu = try rescaledPixelValue(at: point)

        return MeasurementResult(
            value: hu,
            unitLabel: "HU",
            description: "Hounsfield Unit"
        )
    }

    // MARK: - ROI Analysis

    /// Analyze a region of interest
    func analyzeROI(
        roi: ROIDefinition,
        includeStatistics: Bool,
        includeHistogram: Bool,
        histogramBins: Int,
        unit: MeasurementUnit
    ) throws -> ROIAnalysisResult {
        // Collect pixel values within the ROI
        let (values, pixelCount, pixelArea) = try collectROIValues(roi: roi)

        let physicalArea = pixelAreaToPhysical(pixelArea: pixelArea, unit: unit)

        var mean: Double?
        var std: Double?
        var minVal: Double?
        var maxVal: Double?
        var histogram: [HistogramBin]?

        if includeStatistics && !values.isEmpty {
            let sum = values.reduce(0.0, +)
            mean = sum / Double(values.count)
            minVal = values.min()
            maxVal = values.max()

            let variance = values.reduce(0.0) { $0 + ($1 - mean!) * ($1 - mean!) } / Double(values.count)
            std = sqrt(variance)
        }

        if includeHistogram && !values.isEmpty {
            histogram = generateHistogram(values: values, bins: histogramBins)
        }

        return ROIAnalysisResult(
            pixelCount: pixelCount,
            areaValue: physicalArea,
            areaUnit: areaUnitLabel(unit),
            mean: mean,
            standardDeviation: std,
            minimum: minVal,
            maximum: maxVal,
            histogram: histogram,
            roiDescription: roiDescription(roi)
        )
    }

    /// Collect pixel values within a ROI
    private func collectROIValues(roi: ROIDefinition) throws -> (values: [Double], count: Int, pixelArea: Double) {
        guard pixelDataBytes != nil else {
            throw MeasureError.noPixelData
        }

        var values: [Double] = []

        switch roi {
        case .rect(let x, let y, let width, let height):
            let startX = max(0, Int(x))
            let startY = max(0, Int(y))
            let endX = min(columns, Int(x + width))
            let endY = min(rows, Int(y + height))

            for py in startY..<endY {
                for px in startX..<endX {
                    let val = try rescaledPixelValue(at: PixelPoint(x: Double(px), y: Double(py)))
                    values.append(val)
                }
            }
            let area = Double((endX - startX) * (endY - startY))
            return (values, values.count, area)

        case .circle(let cx, let cy, let radius):
            let startX = max(0, Int(cx - radius))
            let startY = max(0, Int(cy - radius))
            let endX = min(columns, Int(cx + radius) + 1)
            let endY = min(rows, Int(cy + radius) + 1)
            let r2 = radius * radius

            for py in startY..<endY {
                for px in startX..<endX {
                    let dx = Double(px) - cx
                    let dy = Double(py) - cy
                    if dx * dx + dy * dy <= r2 {
                        let val = try rescaledPixelValue(at: PixelPoint(x: Double(px), y: Double(py)))
                        values.append(val)
                    }
                }
            }
            let area = Double.pi * radius * radius
            return (values, values.count, area)

        case .polygon(let vertices):
            guard vertices.count >= 3 else {
                return ([], 0, 0.0)
            }

            // Get bounding box
            let minX = max(0, Int(vertices.map(\.x).min()!))
            let minY = max(0, Int(vertices.map(\.y).min()!))
            let maxX = min(columns, Int(vertices.map(\.x).max()!) + 1)
            let maxY = min(rows, Int(vertices.map(\.y).max()!) + 1)

            for py in minY..<maxY {
                for px in minX..<maxX {
                    if isPointInPolygon(point: PixelPoint(x: Double(px), y: Double(py)), polygon: vertices) {
                        let val = try rescaledPixelValue(at: PixelPoint(x: Double(px), y: Double(py)))
                        values.append(val)
                    }
                }
            }
            let area = shoelaceArea(vertices: vertices)
            return (values, values.count, area)
        }
    }

    /// Ray casting algorithm for point-in-polygon test
    private func isPointInPolygon(point: PixelPoint, polygon: [PixelPoint]) -> Bool {
        var inside = false
        let n = polygon.count
        var j = n - 1

        for i in 0..<n {
            let xi = polygon[i].x, yi = polygon[i].y
            let xj = polygon[j].x, yj = polygon[j].y

            if (yi > point.y) != (yj > point.y) {
                let intersectX = (xj - xi) * (point.y - yi) / (yj - yi) + xi
                if point.x < intersectX {
                    inside = !inside
                }
            }
            j = i
        }

        return inside
    }

    /// Generate a histogram from pixel values
    private func generateHistogram(values: [Double], bins: Int) -> [HistogramBin] {
        guard let minVal = values.min(), let maxVal = values.max(), minVal < maxVal else {
            return []
        }

        let range = maxVal - minVal
        let binWidth = range / Double(bins)
        var counts = [Int](repeating: 0, count: bins)

        for value in values {
            var binIndex = Int((value - minVal) / binWidth)
            if binIndex >= bins { binIndex = bins - 1 }
            counts[binIndex] += 1
        }

        return (0..<bins).map { i in
            HistogramBin(
                lowerBound: minVal + Double(i) * binWidth,
                upperBound: minVal + Double(i + 1) * binWidth,
                count: counts[i]
            )
        }
    }

    /// Get a description of the ROI
    private func roiDescription(_ roi: ROIDefinition) -> String {
        switch roi {
        case .rect(let x, let y, let w, let h):
            return "Rectangle (\(Int(x)),\(Int(y)) \(Int(w))x\(Int(h)))"
        case .circle(let cx, let cy, let r):
            return "Circle (center=\(Int(cx)),\(Int(cy)) r=\(Int(r)))"
        case .polygon(let vertices):
            return "Polygon (\(vertices.count) vertices)"
        }
    }
}

// MARK: - Errors

enum MeasureError: LocalizedError {
    case fileNotFound(String)
    case missingImageDimensions
    case noPixelData
    case pointOutOfBounds(x: Int, y: Int, columns: Int, rows: Int)
    case pixelDataTooShort
    case unsupportedBitDepth(Int)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .missingImageDimensions:
            return "DICOM file does not contain image dimensions (Rows/Columns tags)"
        case .noPixelData:
            return "DICOM file does not contain pixel data"
        case .pointOutOfBounds(let x, let y, let columns, let rows):
            return "Point (\(x),\(y)) is outside image bounds (\(columns)x\(rows))"
        case .pixelDataTooShort:
            return "Pixel data is shorter than expected for the given coordinates"
        case .unsupportedBitDepth(let bits):
            return "Unsupported bit depth: \(bits) bits allocated"
        }
    }
}
