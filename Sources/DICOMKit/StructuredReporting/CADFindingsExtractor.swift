/// CAD Findings Extraction API
///
/// Provides high-level extraction of Computer-Aided Detection (CAD) findings from
/// Mammography CAD SR and Chest CAD SR documents.
///
/// Reference: PS3.3 Section A.35.6 - Mammography CAD SR IOD
/// Reference: PS3.3 Section A.35.7 - Chest CAD SR IOD  
/// Reference: PS3.16 TID 4000 - CAD Analysis
/// Reference: PS3.16 TID 4019 - CAD Finding

import Foundation
import DICOMCore

/// Represents extracted CAD findings from a CAD SR document
///
/// Provides structured access to CAD processing information and detected findings
/// with confidence scores, locations, and characteristics.
///
/// Example:
/// ```swift
/// let parser = SRDocumentParser()
/// let document = try parser.parse(dataSet: dataSet)
/// let findings = try CADFindings.extract(from: document)
/// 
/// print("Algorithm: \(findings.processingInfo.algorithmName ?? "Unknown")")
/// for finding in findings.findings {
///     print("Finding: \(finding.findingType?.codeMeaning ?? "Unknown")")
///     print("  Confidence: \(finding.probability ?? 0)")
/// }
/// ```
public struct CADFindings: Sendable, Equatable {
    
    // MARK: - Document Information
    
    /// The original SR document
    public let document: SRDocument
    
    /// CAD document type
    public var cadType: CADType {
        if let docType = document.documentType {
            switch docType.sopClassUID {
            case SRDocumentType.mammographyCADSR.sopClassUID:
                return .mammography
            case SRDocumentType.chestCADSR.sopClassUID:
                return .chest
            default:
                return .unknown
            }
        }
        return .unknown
    }
    
    // MARK: - CAD Processing Information
    
    /// CAD processing summary information
    public let processingInfo: CADProcessingInfo
    
    /// Detected findings
    public let findings: [ExtractedCADFinding]
    
    // MARK: - Extraction API
    
    /// Extracts CAD findings from a CAD SR document
    /// - Parameter document: The SR document to extract from
    /// - Returns: Extracted CAD findings
    /// - Throws: `ExtractionError` if the document is not a valid CAD SR
    public static func extract(from document: SRDocument) throws -> CADFindings {
        // Validate document type
        guard let docType = document.documentType else {
            throw ExtractionError.invalidDocumentType("Document type could not be determined")
        }
        
        let isCADDocument = docType.sopClassUID == SRDocumentType.mammographyCADSR.sopClassUID ||
                           docType.sopClassUID == SRDocumentType.chestCADSR.sopClassUID
        
        guard isCADDocument else {
            throw ExtractionError.invalidDocumentType(
                "Document must be Mammography CAD SR or Chest CAD SR, got: \(document.sopClassUID)"
            )
        }
        
        // Extract processing information
        let processingInfo = extractProcessingInfo(from: document.rootContent)
        
        // Extract findings
        let findings = extractFindings(from: document.rootContent)
        
        return CADFindings(
            document: document,
            processingInfo: processingInfo,
            findings: findings
        )
    }
    
    // MARK: - Private Extraction Helpers
    
    private static func extractProcessingInfo(from container: ContainerContentItem) -> CADProcessingInfo {
        var algorithmName: String?
        var algorithmVersion: String?
        var manufacturer: String?
        
        // Look for CAD Processing Summary container (TID 4001)
        for item in container.contentItems {
            if let summaryContainer = item.asContainer,
               summaryContainer.conceptName?.codeValue == "111001" { // Algorithm Name
                
                for summaryItem in summaryContainer.contentItems {
                    if let textItem = summaryItem.asText {
                        if textItem.conceptName?.codeValue == "111001" { // Algorithm Name
                            algorithmName = textItem.textValue
                        } else if textItem.conceptName?.codeValue == "111003" { // Algorithm Version
                            algorithmVersion = textItem.textValue
                        }
                    } else if let codeItem = summaryItem.asCode,
                              codeItem.conceptName?.codeValue == "113878" { // Device Manufacturer
                        manufacturer = codeItem.conceptCode.codeMeaning
                    }
                }
            }
            
            // Also check for algorithm name/version directly in root
            if let textItem = item.asText {
                if textItem.conceptName?.codeValue == "111001" { // Algorithm Name
                    algorithmName = textItem.textValue
                } else if textItem.conceptName?.codeValue == "111003" { // Algorithm Version
                    algorithmVersion = textItem.textValue
                }
            }
        }
        
        return CADProcessingInfo(
            algorithmName: algorithmName,
            algorithmVersion: algorithmVersion,
            manufacturer: manufacturer
        )
    }
    
    private static func extractFindings(from container: ContainerContentItem) -> [ExtractedCADFinding] {
        var findings: [ExtractedCADFinding] = []
        
        // Look for finding containers (each finding is a CONTAINER)
        for item in container.contentItems {
            if let findingContainer = item.asContainer {
                // Check if this looks like a CAD finding container
                let hasFindingContent = findingContainer.contentItems.contains { contentItem in
                    if let numItem = contentItem.asNumeric,
                       numItem.conceptName?.codeValue == "111023" { // CAD Probability
                        return true
                    }
                    return false
                }
                
                if hasFindingContent {
                    if let finding = extractSingleFinding(from: findingContainer) {
                        findings.append(finding)
                    }
                }
            }
        }
        
        return findings
    }
    
    private static func extractSingleFinding(from container: ContainerContentItem) -> ExtractedCADFinding? {
        var findingType: CodedConcept?
        var probability: Double?
        var location: CADFindingLocation?
        var characteristics: [CodedConcept] = []
        var imageReference: ImageReference?
        
        for item in container.contentItems {
            // Extract finding type from concept name or CODE items
            if findingType == nil, let conceptName = container.conceptName {
                findingType = conceptName
            }
            
            // Extract probability
            if let numItem = item.asNumeric,
               numItem.conceptName?.codeValue == "111023" { // CAD Probability
                probability = numItem.numericValues.first
            }
            
            // Extract finding type from CODE items  
            else if let codeItem = item.asCode,
                    codeItem.conceptName?.codeValue == "121071" { // Finding
                findingType = codeItem.conceptCode
            }
            
            // Extract spatial coordinates (location)
            else if let scoordItem = item.asSpatialCoordinates {
                location = extractLocation(from: scoordItem, container: container)
            }
            
            // Extract image reference
            else if let imageItem = item.asImage {
                imageReference = imageItem.imageReference
            }
            
            // Extract characteristics (other CODE items)
            else if let codeItem = item.asCode {
                characteristics.append(codeItem.conceptCode)
            }
        }
        
        // Require at least a finding type or probability
        guard findingType != nil || probability != nil else {
            return nil
        }
        
        return ExtractedCADFinding(
            findingType: findingType,
            probability: probability,
            location: location,
            characteristics: characteristics,
            imageReference: imageReference
        )
    }
    
    private static func extractLocation(
        from scoordItem: SpatialCoordinatesContentItem,
        container: ContainerContentItem
    ) -> CADFindingLocation? {
        // Find associated image reference for the spatial coordinate
        var imageRef: ImageReference?
        for item in container.contentItems {
            if let imageItem = item.asImage {
                imageRef = imageItem.imageReference
                break
            }
        }
        
        switch scoordItem.graphicType {
        case .point:
            if scoordItem.graphicData.count >= 2 {
                return .point2D(
                    x: scoordItem.graphicData[0],
                    y: scoordItem.graphicData[1],
                    imageReference: imageRef
                )
            }
            
        case .polyline:
            let points = stride(from: 0, to: scoordItem.graphicData.count - 1, by: 2).map { i in
                (scoordItem.graphicData[i], scoordItem.graphicData[i + 1])
            }
            return .polyline(
                points: points,
                imageReference: imageRef
            )
            
        case .circle:
            if scoordItem.graphicData.count >= 4 {
                let centerX = scoordItem.graphicData[0]
                let centerY = scoordItem.graphicData[1]
                let radiusX = scoordItem.graphicData[2] - centerX
                let radiusY = scoordItem.graphicData[3] - centerY
                return .circle(
                    centerX: centerX,
                    centerY: centerY,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    imageReference: imageRef
                )
            }
            
        case .ellipse:
            if scoordItem.graphicData.count >= 8 {
                let maxIndex = min(8, scoordItem.graphicData.count) - 1
                let points = stride(from: 0, to: maxIndex, by: 2).map { i in
                    (scoordItem.graphicData[i], scoordItem.graphicData[i + 1])
                }
                return .ellipse(
                    points: points,
                    imageReference: imageRef
                )
            }
            
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Supporting Types

/// Type of CAD document
public enum CADType: Sendable, Equatable, Hashable {
    /// Mammography CAD
    case mammography
    
    /// Chest CAD
    case chest
    
    /// Unknown CAD type
    case unknown
}

/// CAD processing summary information
public struct CADProcessingInfo: Sendable, Equatable {
    /// Name of the CAD algorithm
    public let algorithmName: String?
    
    /// Version of the CAD algorithm
    public let algorithmVersion: String?
    
    /// Manufacturer of the CAD system
    public let manufacturer: String?
    
    /// Creates CAD processing info
    public init(
        algorithmName: String? = nil,
        algorithmVersion: String? = nil,
        manufacturer: String? = nil
    ) {
        self.algorithmName = algorithmName
        self.algorithmVersion = algorithmVersion
        self.manufacturer = manufacturer
    }
}

/// A single extracted CAD finding
public struct ExtractedCADFinding: Sendable, Equatable {
    /// Type of finding detected
    public let findingType: CodedConcept?
    
    /// Detection probability/confidence (0.0-1.0)
    public let probability: Double?
    
    /// Spatial location of the finding
    public let location: CADFindingLocation?
    
    /// Additional characteristics of the finding
    public let characteristics: [CodedConcept]
    
    /// Reference to the source image
    public let imageReference: ImageReference?
    
    /// Creates a CAD finding
    public init(
        findingType: CodedConcept? = nil,
        probability: Double? = nil,
        location: CADFindingLocation? = nil,
        characteristics: [CodedConcept] = [],
        imageReference: ImageReference? = nil
    ) {
        self.findingType = findingType
        self.probability = probability
        self.location = location
        self.characteristics = characteristics
        self.imageReference = imageReference
    }
}

/// Location information for a CAD finding
public enum CADFindingLocation: Sendable {
    /// 2D point location
    case point2D(x: Float, y: Float, imageReference: ImageReference?)
    
    /// Polyline/polygon region
    case polyline(points: [(Float, Float)], imageReference: ImageReference?)
    
    /// Circular region
    case circle(centerX: Float, centerY: Float, radiusX: Float, radiusY: Float, imageReference: ImageReference?)
    
    /// Elliptical region
    case ellipse(points: [(Float, Float)], imageReference: ImageReference?)
}

extension CADFindingLocation: Equatable {
    public static func == (lhs: CADFindingLocation, rhs: CADFindingLocation) -> Bool {
        switch (lhs, rhs) {
        case (.point2D(let lx, let ly, let lref), .point2D(let rx, let ry, let rref)):
            return lx == rx && ly == ry && lref == rref
        case (.polyline(let lpoints, let lref), .polyline(let rpoints, let rref)):
            guard lpoints.count == rpoints.count, lref == rref else { return false }
            return zip(lpoints, rpoints).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.circle(let lcx, let lcy, let lrx, let lry, let lref), .circle(let rcx, let rcy, let rrx, let rry, let rref)):
            return lcx == rcx && lcy == rcy && lrx == rrx && lry == rry && lref == rref
        case (.ellipse(let lpoints, let lref), .ellipse(let rpoints, let rref)):
            guard lpoints.count == rpoints.count, lref == rref else { return false }
            return zip(lpoints, rpoints).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default:
            return false
        }
    }
}

// Note: ImageReference type is defined in DICOMCore.ContentItem and is reused here
