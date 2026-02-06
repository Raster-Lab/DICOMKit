// DICOMKit Sample Code: RT Structure Sets
//
// This example demonstrates how to:
// - Load RT Structure Set files
// - Parse ROI contours
// - Render ROI contours on images
// - 3D ROI visualization
// - Calculate ROI statistics (volume, etc.)
// - Access structure set metadata
// - Manage ROI colors
// - Interpolate between contour slices

import DICOMKit
import DICOMCore
import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Example 1: Loading RT Structure Set Files

func example1_loadRTStructureSet() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let rtsFile = try DICOMFile.read(from: rtsURL)
    
    // Verify this is an RT Structure Set
    let sopClassUID = rtsFile.dataSet.string(for: .sopClassUID) ?? ""
    guard sopClassUID == "1.2.840.10008.5.1.4.1.1.481.3" else {
        print("Not an RT Structure Set")
        return
    }
    
    print("✅ RT Structure Set loaded")
    
    // Parse using RTStructureSetParser
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    print("Structure Set: \(structureSet.label ?? "Unnamed")")
    print("Description: \(structureSet.description ?? "N/A")")
    print("Frame of Reference: \(structureSet.frameOfReferenceUID ?? "N/A")")
    print("Number of ROIs: \(structureSet.rois.count)")
    
    // List all ROIs
    for roi in structureSet.rois {
        print("\nROI #\(roi.number): \(roi.name)")
        if let desc = roi.description {
            print("  Description: \(desc)")
        }
        if let algorithm = roi.generationAlgorithm {
            print("  Algorithm: \(algorithm)")
        }
    }
}

// MARK: - Example 2: Accessing ROI Contours

func example2_accessROIContours() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let rtsFile = try DICOMFile.read(from: rtsURL)
    
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    print("✅ ROI Contours:")
    
    for roiContour in structureSet.roiContours {
        // Find matching ROI definition
        guard let roi = structureSet.rois.first(where: { $0.number == roiContour.roiNumber }) else {
            continue
        }
        
        print("\n\(roi.name) (ROI #\(roi.number)):")
        print("  Total contours: \(roiContour.contours.count)")
        
        // Display color
        if let color = roiContour.displayColor {
            print("  Color: RGB(\(color.red), \(color.green), \(color.blue))")
        }
        
        // Analyze contours
        var totalPoints = 0
        var sliceCount: Set<String> = []
        
        for contour in roiContour.contours {
            totalPoints += contour.numberOfPoints
            
            // Track which slices have contours
            if let sopUID = contour.referencedSOPInstanceUID {
                sliceCount.insert(sopUID)
            }
            
            // Print geometric type
            if roiContour.contours.first === contour {
                print("  Geometric Type: \(contour.geometricType.rawValue)")
            }
        }
        
        print("  Total points: \(totalPoints)")
        print("  Slices with contours: \(sliceCount.count)")
        
        // Print sample contour data
        if let firstContour = roiContour.contours.first,
           let firstPoint = firstContour.points.first {
            print("  First point: (\(firstPoint.x), \(firstPoint.y), \(firstPoint.z)) mm")
        }
    }
}

// MARK: - Example 3: Rendering ROI Contours on Images

#if canImport(CoreGraphics)
func example3_renderContoursOnImage(
    baseImage: CGImage,
    contours: [Contour],
    imagePositionPatient: (Double, Double, Double),
    pixelSpacing: (Double, Double),
    color: (r: CGFloat, g: CGFloat, b: CGFloat)
) -> CGImage? {
    let width = baseImage.width
    let height = baseImage.height
    
    // Create bitmap context
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        return nil
    }
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    
    // Draw base image
    context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Set contour drawing style
    context.setLineWidth(2.0)
    context.setStrokeColor(red: color.r, green: color.g, blue: color.b, alpha: 1.0)
    context.setFillColor(red: color.r, green: color.g, blue: color.b, alpha: 0.3)
    
    // Draw each contour on this slice
    for contour in contours {
        guard contour.points.count >= 2 else { continue }
        
        // Convert patient coordinates to pixel coordinates
        var pixelPoints: [CGPoint] = []
        
        for point in contour.points {
            // Convert from patient coordinates (mm) to pixel coordinates
            let pixelX = (point.x - imagePositionPatient.0) / pixelSpacing.0
            let pixelY = (point.y - imagePositionPatient.1) / pixelSpacing.1
            
            pixelPoints.append(CGPoint(x: pixelX, y: Double(height) - pixelY))  // Flip Y
        }
        
        // Draw contour
        if let firstPoint = pixelPoints.first {
            context.beginPath()
            context.move(to: firstPoint)
            
            for point in pixelPoints.dropFirst() {
                context.addLine(to: point)
            }
            
            // Close the contour
            context.closePath()
            
            // Fill and stroke
            context.drawPath(using: .fillStroke)
        }
    }
    
    return context.makeImage()
}
#endif

// MARK: - Example 4: Matching Contours to Image Slices

func example4_matchContoursToSlice() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let imageURL = URL(fileURLWithPath: "/path/to/image.dcm")
    
    let rtsFile = try DICOMFile.read(from: rtsURL)
    let imageFile = try DICOMFile.read(from: imageURL)
    
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    // Get image SOP Instance UID
    guard let imageSopUID = imageFile.dataSet.string(for: .sopInstanceUID) else {
        print("Image missing SOP Instance UID")
        return
    }
    
    print("Looking for contours on image: \(imageSopUID)")
    
    // Find contours on this image
    for roiContour in structureSet.roiContours {
        guard let roi = structureSet.rois.first(where: { $0.number == roiContour.roiNumber }) else {
            continue
        }
        
        // Filter contours that reference this image
        let contoursOnThisSlice = roiContour.contours.filter {
            $0.referencedSOPInstanceUID == imageSopUID
        }
        
        if !contoursOnThisSlice.isEmpty {
            print("\n\(roi.name): \(contoursOnThisSlice.count) contour(s)")
            
            for contour in contoursOnThisSlice {
                print("  \(contour.numberOfPoints) points")
            }
        }
    }
}

// MARK: - Example 5: Calculating ROI Volume

func example5_calculateROIVolume(
    roiContour: ROIContour,
    sliceThickness: Double
) -> Double {
    // Volume calculation using contour area × slice thickness
    var totalVolume: Double = 0.0
    
    // Group contours by Z position
    var contoursByZ: [Double: [Contour]] = [:]
    
    for contour in roiContour.contours {
        guard let firstPoint = contour.points.first else { continue }
        let zPosition = firstPoint.z
        
        if contoursByZ[zPosition] == nil {
            contoursByZ[zPosition] = []
        }
        contoursByZ[zPosition]?.append(contour)
    }
    
    // Calculate area for each slice
    for (_, contoursAtZ) in contoursByZ {
        for contour in contoursAtZ {
            let area = calculatePolygonArea(points: contour.points)
            totalVolume += area * sliceThickness
        }
    }
    
    print("ROI Volume: \(totalVolume / 1000.0) cc")  // Convert mm³ to cc
    return totalVolume
}

/// Calculate area of a polygon using the shoelace formula
func calculatePolygonArea(points: [Point3D]) -> Double {
    guard points.count >= 3 else { return 0.0 }
    
    var area: Double = 0.0
    
    for i in 0..<points.count {
        let j = (i + 1) % points.count
        area += points[i].x * points[j].y
        area -= points[j].x * points[i].y
    }
    
    return abs(area) / 2.0
}

// MARK: - Example 6: ROI Statistics with Dose Information

func example6_calculateROIStatistics() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let rtsFile = try DICOMFile.read(from: rtsURL)
    
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    // For each ROI, look at observations
    for roiObs in structureSet.roiObservations {
        guard let roi = structureSet.rois.first(where: { $0.number == roiObs.observationNumber }) else {
            continue
        }
        
        print("\n\(roi.name) (ROI #\(roi.number)):")
        print("  Interpreted Type: \(roiObs.interpretedType ?? "N/A")")
        print("  Interpreter: \(roiObs.interpreter ?? "N/A")")
        
        if let rtType = roiObs.rtRoiInterpretedType {
            print("  RT ROI Type: \(rtType)")
        }
        
        // Physical properties
        if let physicalProps = roiObs.roiPhysicalProperties {
            for prop in physicalProps {
                print("  Property: \(prop.propertyType ?? "N/A") = \(prop.propertyValue ?? "N/A")")
            }
        }
    }
}

// MARK: - Example 7: Color Management for ROIs

struct ROIColorPalette {
    static let defaultColors: [(r: Int, g: Int, b: Int)] = [
        (255, 0, 0),      // Red - Target
        (0, 255, 0),      // Green - Organs at risk
        (0, 0, 255),      // Blue - External
        (255, 255, 0),    // Yellow
        (255, 0, 255),    // Magenta
        (0, 255, 255),    // Cyan
        (255, 128, 0),    // Orange
        (128, 0, 255),    // Purple
        (255, 192, 203),  // Pink
        (165, 42, 42),    // Brown
    ]
    
    static func color(for roiNumber: Int, customColor: DisplayColor? = nil) -> (r: Int, g: Int, b: Int) {
        if let custom = customColor {
            return (r: custom.red, g: custom.green, b: custom.blue)
        }
        
        let index = (roiNumber - 1) % defaultColors.count
        return defaultColors[index]
    }
}

func example7_assignROIColors() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let rtsFile = try DICOMFile.read(from: rtsURL)
    
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    print("✅ ROI Color Assignments:")
    
    for roiContour in structureSet.roiContours {
        guard let roi = structureSet.rois.first(where: { $0.number == roiContour.roiNumber }) else {
            continue
        }
        
        let color = ROIColorPalette.color(for: roi.number, customColor: roiContour.displayColor)
        
        print("\(roi.name): RGB(\(color.r), \(color.g), \(color.b))")
    }
}

// MARK: - Example 8: Contour Interpolation

#if canImport(CoreGraphics)
func example8_interpolateContours(
    contour1: Contour,
    contour2: Contour,
    zPosition: Double
) -> Contour? {
    // Get Z positions of both contours
    guard let z1 = contour1.points.first?.z,
          let z2 = contour2.points.first?.z,
          z1 != z2 else {
        return nil
    }
    
    // Calculate interpolation factor
    let t = (zPosition - z1) / (z2 - z1)
    
    // Ensure we're interpolating between the contours, not extrapolating
    guard t >= 0.0 && t <= 1.0 else {
        return nil
    }
    
    // Match contour point counts (use the smaller count)
    let pointCount = min(contour1.numberOfPoints, contour2.numberOfPoints)
    
    var interpolatedPoints: [Point3D] = []
    
    for i in 0..<pointCount {
        let p1 = contour1.points[i]
        let p2 = contour2.points[i]
        
        // Linear interpolation
        let x = p1.x + (p2.x - p1.x) * t
        let y = p1.y + (p2.y - p1.y) * t
        let z = zPosition
        
        interpolatedPoints.append(Point3D(x: x, y: y, z: z))
    }
    
    return Contour(
        geometricType: .closedPlanar,
        numberOfPoints: interpolatedPoints.count,
        points: interpolatedPoints,
        referencedSOPInstanceUID: nil,
        slabThickness: nil,
        offsetVector: nil
    )
}
#endif

// MARK: - Example 9: 3D ROI Visualization Data

struct ROI3DVisualization {
    let roiNumber: Int
    let name: String
    let color: (r: Float, g: Float, b: Float)
    let triangles: [Triangle3D]  // Mesh for 3D rendering
}

struct Triangle3D {
    let p1: Point3D
    let p2: Point3D
    let p3: Point3D
}

func example9_prepare3DVisualization() throws {
    let rtsURL = URL(fileURLWithPath: "/path/to/rtstruct.dcm")
    let rtsFile = try DICOMFile.read(from: rtsURL)
    
    let parser = RTStructureSetParser()
    let structureSet = try parser.parse(from: rtsFile)
    
    var visualizations: [ROI3DVisualization] = []
    
    for roiContour in structureSet.roiContours {
        guard let roi = structureSet.rois.first(where: { $0.number == roiContour.roiNumber }) else {
            continue
        }
        
        // Get color
        let colorRGB = ROIColorPalette.color(for: roi.number, customColor: roiContour.displayColor)
        let color = (
            r: Float(colorRGB.r) / 255.0,
            g: Float(colorRGB.g) / 255.0,
            b: Float(colorRGB.b) / 255.0
        )
        
        // Create mesh from contours (simplified - real implementation would use marching cubes or similar)
        var triangles: [Triangle3D] = []
        
        // Sort contours by Z position
        let sortedContours = roiContour.contours.sorted {
            ($0.points.first?.z ?? 0) < ($1.points.first?.z ?? 0)
        }
        
        // Generate triangles by connecting adjacent slices
        for i in 0..<(sortedContours.count - 1) {
            let contour1 = sortedContours[i]
            let contour2 = sortedContours[i + 1]
            
            // Connect corresponding points between slices
            let pointCount = min(contour1.numberOfPoints, contour2.numberOfPoints)
            
            for j in 0..<pointCount {
                let k = (j + 1) % pointCount
                
                let p1 = contour1.points[j]
                let p2 = contour1.points[k]
                let p3 = contour2.points[j]
                let p4 = contour2.points[k]
                
                // Create two triangles for this quad
                triangles.append(Triangle3D(p1: p1, p2: p2, p3: p3))
                triangles.append(Triangle3D(p1: p2, p2: p4, p3: p3))
            }
        }
        
        let visualization = ROI3DVisualization(
            roiNumber: roi.number,
            name: roi.name,
            color: color,
            triangles: triangles
        )
        
        visualizations.append(visualization)
        
        print("✅ \(roi.name): \(triangles.count) triangles")
    }
    
    print("\nTotal ROIs prepared for 3D visualization: \(visualizations.count)")
}

// MARK: - Helper: ROI Information Summary

struct ROISummary {
    let number: Int
    let name: String
    let description: String?
    let color: DisplayColor?
    let numberOfContours: Int
    let numberOfSlices: Int
    let totalPoints: Int
    let volume: Double?  // in cc
    let interpretedType: String?
}

func createROISummary(
    roi: RTRegionOfInterest,
    roiContour: ROIContour,
    observation: RTROIObservation?,
    sliceThickness: Double
) -> ROISummary {
    // Count unique slices
    let uniqueSlices = Set(roiContour.contours.compactMap { $0.referencedSOPInstanceUID })
    
    // Count total points
    let totalPoints = roiContour.contours.reduce(0) { $0 + $1.numberOfPoints }
    
    // Calculate volume
    let volumeMm3 = example5_calculateROIVolume(roiContour: roiContour, sliceThickness: sliceThickness)
    let volumeCc = volumeMm3 / 1000.0
    
    return ROISummary(
        number: roi.number,
        name: roi.name,
        description: roi.description,
        color: roiContour.displayColor,
        numberOfContours: roiContour.contours.count,
        numberOfSlices: uniqueSlices.count,
        totalPoints: totalPoints,
        volume: volumeCc,
        interpretedType: observation?.rtRoiInterpretedType
    )
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_loadRTStructureSet()
// try? example2_accessROIContours()
// try? example4_matchContoursToSlice()

// MARK: - Quick Reference

/*
 RT Structure Sets:
 
 SOP Class UID:
 • 1.2.840.10008.5.1.4.1.1.481.3 - RT Structure Set Storage
 
 Key Concepts:
 • RTStructureSet     - Collection of ROIs for radiation therapy
 • ROI                - Region of Interest (anatomical structure)
 • Contour            - 2D closed curve defining ROI on a slice
 • Structure Set      - Group of ROIs with metadata
 • Frame of Reference - Coordinate system for contours
 
 DICOM Tags (Structure Set Module):
 • (3006,0002) - Structure Set Label
 • (3006,0004) - Structure Set Name
 • (3006,0006) - Structure Set Description
 • (3006,0008) - Structure Set Date
 • (3006,0009) - Structure Set Time
 • (3006,0010) - Referenced Frame of Reference Sequence
 • (3006,0020) - Structure Set ROI Sequence
 
 DICOM Tags (ROI Contour Module):
 • (3006,0039) - ROI Contour Sequence
 • (3006,0040) - Contour Sequence
 • (3006,0042) - Contour Geometric Type
 • (3006,0046) - Number of Contour Points
 • (3006,0048) - Contour Number
 • (3006,0050) - Contour Data (x\y\z\x\y\z\...)
 • (3006,0084) - Referenced SOP Instance UID
 • (3006,002A) - ROI Display Color (R\G\B, 0-255)
 
 DICOM Tags (RT ROI Observations Module):
 • (3006,0080) - RT ROI Observations Sequence
 • (3006,0082) - Observation Number
 • (3006,0084) - Referenced ROI Number
 • (3006,0085) - ROI Observation Label
 • (3006,0086) - RT ROI Identification Code Sequence
 • (3006,00A4) - RT ROI Interpreted Type
 • (3006,00A6) - ROI Interpreter
 
 ROI Structure:
 1. RTRegionOfInterest - Metadata (number, name, description)
 2. ROIContour - Geometric definition (contours, display color)
 3. RTROIObservation - Clinical interpretation (type, properties)
 
 Contour Geometric Types:
 • CLOSED_PLANAR - Closed curve in a plane (most common)
 • OPEN_PLANAR   - Open curve in a plane
 • OPEN_NONPLANAR - Open 3D curve
 • POINT         - Single point
 
 Contour Data Format:
 • Sequence of (x, y, z) triplets in mm
 • Patient coordinate system (Frame of Reference)
 • Format: x1\y1\z1\x2\y2\z2\x3\y3\z3\...
 • All points in a contour typically have same Z (planar)
 
 RT ROI Interpreted Types:
 • EXTERNAL       - External body contour
 • PTV            - Planning Target Volume
 • CTV            - Clinical Target Volume
 • GTV            - Gross Tumor Volume
 • TREATED_VOLUME - Volume receiving prescribed dose
 • IRRAD_VOLUME   - Volume receiving significant dose
 • ORGAN          - Organ at Risk (OAR)
 • MARKER         - Fiducial marker
 • REGISTRATION   - Registration ROI
 • ISOCENTER      - Isocenter point
 • CONTRAST_AGENT - Contrast agent region
 • CAVITY         - Cavity (e.g., surgical bed)
 • BRACHY_CHANNEL - Brachytherapy channel
 • BRACHY_ACCESSORY - Brachytherapy accessory
 • BRACHY_SRC_APP - Brachytherapy source applicator
 
 Volume Calculation:
 • For each slice: Calculate contour area (shoelace formula)
 • Multiply area by slice thickness
 • Sum volumes across all slices
 • Formula: V = Σ(area_i × thickness)
 • Units: mm³ (convert to cc by dividing by 1000)
 
 Shoelace Formula (Polygon Area):
 • Area = ½ |Σ(x_i × y_{i+1} - x_{i+1} × y_i)|
 • For closed polygon with n vertices
 • Handles self-intersecting polygons
 
 Contour Rendering:
 1. Match contour to image by SOP Instance UID
 2. Convert patient coordinates (mm) to pixel coordinates
 3. Account for Image Position Patient and Pixel Spacing
 4. Draw polygon with ROI display color
 5. Fill with transparency for better visibility
 
 Coordinate Transformation:
 • Patient → Pixel: (x - imagePosition.x) / pixelSpacing.x
 • Y-axis may need flipping depending on coordinate system
 • Z-position determines which slice shows contour
 
 Color Management:
 • ROI Display Color tag: (3006,002A)
 • Format: R\G\B (0-255)
 • Use default color palette if not specified
 • Maintain consistent colors across sessions
 • Common scheme: Red for targets, green for organs
 
 Contour Interpolation:
 • Fill gaps between contour slices
 • Linear interpolation between corresponding points
 • Formula: P(t) = P1 + t × (P2 - P1), where 0 ≤ t ≤ 1
 • Requires point correspondence between slices
 • More advanced: shape-based interpolation
 
 3D Visualization:
 • Build surface mesh from contour stack
 • Connect contours on adjacent slices
 • Generate triangles between corresponding points
 • Use marching cubes for smoother results
 • Apply ROI color as material color
 • Support transparency for overlapping ROIs
 
 Mesh Generation:
 1. Sort contours by Z position
 2. For each pair of adjacent contours:
 3. Match corresponding points
 4. Create quad between point pairs
 5. Triangulate each quad (2 triangles)
 6. Generate normals for lighting
 
 ROI Statistics:
 • Volume (cc or cm³)
 • Number of slices
 • Number of contour points
 • Bounding box (min/max x, y, z)
 • Centroid position
 • Mean/min/max dose (if RT Dose available)
 • DVH metrics (if RT Dose available)
 
 Frame of Reference:
 • Coordinate system shared with image series
 • Must match for contours to align correctly
 • Frame of Reference UID links structure set to images
 • Verify match before rendering contours
 
 Referenced Images:
 • Contours reference specific image instances
 • Use SOP Instance UID for matching
 • Referenced Series Sequence lists all series
 • Check Referenced Frame Number for multi-frame
 
 Quality Checks:
 1. Verify Frame of Reference UID matches images
 2. Check contour geometric type (expect CLOSED_PLANAR)
 3. Validate contour points (minimum 3 for polygon)
 4. Ensure contours are planar (all Z values same)
 5. Check for self-intersecting contours
 6. Verify display colors are valid (0-255)
 7. Match referenced image UIDs to available images
 
 Common ROI Names (Conventions):
 • PTV_5000 - Planning target, 50.00 Gy
 • CTV_High - Clinical target, high dose
 • GTV - Gross tumor volume
 • Spinal_Cord - Organ at risk
 • Parotid_L, Parotid_R - Left/right parotids
 • Lung_Total - Combined lungs
 • Body - External contour
 
 Use Cases:
 • Radiation therapy planning
 • Dose calculation and optimization
 • Treatment plan evaluation (DVH)
 • Organ at risk delineation
 • Target volume definition
 • Auto-segmentation validation
 • Clinical trial compliance
 
 Workflow:
 1. Load RT Structure Set
 2. Load referenced image series
 3. Match Frame of Reference UIDs
 4. For each ROI, render contours on images
 5. Display in 2D (slice-by-slice) and/or 3D
 6. Calculate volumes and statistics
 7. Export for treatment planning system
 
 Integration with Other RT Objects:
 • RT Plan references Structure Set for target definition
 • RT Dose uses Structure Set for DVH calculation
 • Structure Set references Image Series for contouring
 • All share Frame of Reference UID
 
 Performance Tips:
 1. Cache rendered contours by slice
 2. Use spatial indexing for contour lookup
 3. Pre-calculate bounding boxes
 4. Downsample contours for preview
 5. Render visible ROIs only
 6. Use GPU for 3D mesh rendering
 7. Lazy load contour data
 8. Parallelize volume calculations
 
 Tips:
 
 1. Always verify Frame of Reference UID matches images
 2. Use ROI Display Color for consistent visualization
 3. Handle missing colors gracefully (use default palette)
 4. Support ROI visibility toggle in UI
 5. Calculate volumes for treatment planning validation
 6. Implement contour editing for clinical workflow
 7. Support export to RT Plan systems
 8. Interpolate between slices for smoother visualization
 9. Provide 2D and 3D viewing modes
 10. Validate contour integrity (closed, planar, non-self-intersecting)
 */
