/// AI/ML Inference Result Integration
///
/// Provides protocols and types for converting AI/ML model outputs into DICOM Structured Reporting
/// documents. This enables seamless integration of machine learning detection and analysis results
/// with the DICOM ecosystem.
///
/// Reference: PS3.3 Section A.35 - CAD SR IODs
/// Reference: PS3.16 TID 4000 - CAD Analysis

import Foundation
import DICOMCore

// MARK: - Core Protocol

/// Protocol for AI/ML inference results that can be converted to DICOM SR documents
///
/// Conforming types represent the output of AI/ML models and provide the necessary
/// information to create properly formatted DICOM Structured Report documents.
///
/// Example:
/// ```swift
/// struct MyDetectionResult: AIInferenceResult {
///     var modelName: String { "YOLOv8-Medical" }
///     var modelVersion: String { "1.2.3" }
///     var manufacturer: String { "My AI Company" }
///     var processingTimestamp: Date { Date() }
///     var detections: [AIDetection] { ... }
/// }
/// ```
public protocol AIInferenceResult: Sendable {
    /// Name of the AI/ML model that produced this result
    var modelName: String { get }
    
    /// Version of the AI/ML model
    var modelVersion: String { get }
    
    /// Manufacturer or developer of the model
    var manufacturer: String { get }
    
    /// Timestamp when the inference was performed
    var processingTimestamp: Date { get }
    
    /// Detected findings from the AI analysis
    var detections: [AIDetection] { get }
    
    /// Optional additional metadata about the inference
    var metadata: [String: String]? { get }
}

// MARK: - Default Implementation

extension AIInferenceResult {
    public var metadata: [String: String]? { nil }
}

// MARK: - Detection Types

/// Represents a single detection from an AI model
public struct AIDetection: Sendable, Equatable {
    /// Type of the detected finding
    public let type: AIDetectionType
    
    /// Confidence score (0.0 to 1.0)
    public let confidence: Double
    
    /// Spatial location of the detection
    public let location: AIDetectionLocation
    
    /// Optional characteristics or attributes
    public let attributes: [String: String]?
    
    /// Creates a new AI detection
    /// - Parameters:
    ///   - type: Type of detection
    ///   - confidence: Confidence score (0.0-1.0)
    ///   - location: Spatial location
    ///   - attributes: Optional key-value attributes
    public init(
        type: AIDetectionType,
        confidence: Double,
        location: AIDetectionLocation,
        attributes: [String: String]? = nil
    ) {
        self.type = type
        self.confidence = confidence
        self.location = location
        self.attributes = attributes
    }
}

/// Types of detections that AI models can produce
public enum AIDetectionType: Sendable, Equatable {
    // MARK: - Anatomical Findings
    
    /// Lung nodule detection
    case lungNodule
    
    /// Mass or tumor detection
    case mass
    
    /// Calcification detection
    case calcification
    
    /// Lesion detection (general)
    case lesion
    
    /// Fracture detection
    case fracture
    
    /// Hemorrhage detection
    case hemorrhage
    
    /// Pneumonia or consolidation
    case pneumonia
    
    /// Pulmonary embolism
    case pulmonaryEmbolism
    
    // MARK: - Organ/Structure Detection
    
    /// Anatomical structure (organ, vessel, etc.)
    case anatomicalStructure(name: String)
    
    // MARK: - Custom Detection
    
    /// Custom detection type with coded concept
    case custom(CodedConcept)
    
    /// The coded concept representation for this detection type
    public var concept: CodedConcept {
        switch self {
        case .lungNodule:
            return CodedConcept(
                codeValue: "M-03010",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Nodule"
            )
        case .mass:
            return CodedConcept(
                codeValue: "F-01796",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Mass"
            )
        case .calcification:
            return CodedConcept(
                codeValue: "F-61769",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Calcification"
            )
        case .lesion:
            return CodedConcept(
                codeValue: "M-03000",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Lesion"
            )
        case .fracture:
            return CodedConcept(
                codeValue: "M-12000",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Fracture"
            )
        case .hemorrhage:
            return CodedConcept(
                codeValue: "M-37000",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Hemorrhage"
            )
        case .pneumonia:
            return CodedConcept(
                codeValue: "M-40000",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Pneumonia"
            )
        case .pulmonaryEmbolism:
            return CodedConcept(
                codeValue: "D3-81004",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Pulmonary embolism"
            )
        case .anatomicalStructure(let name):
            return CodedConcept(
                codeValue: "T-D0050",
                codingSchemeDesignator: "SRT",
                codeMeaning: name
            )
        case .custom(let concept):
            return concept
        }
    }
}

/// Spatial location of an AI detection
public enum AIDetectionLocation: Sendable, Equatable {
    // MARK: - 2D Locations
    
    /// Point location in 2D image space
    case point2D(x: Double, y: Double, imageReference: AIImageReference)
    
    /// Bounding box in 2D image space
    case boundingBox2D(x: Double, y: Double, width: Double, height: Double, imageReference: AIImageReference)
    
    /// Polygon region in 2D image space
    case polygon2D(points: [Double], imageReference: AIImageReference)
    
    /// Circle in 2D image space
    case circle2D(centerX: Double, centerY: Double, radius: Double, imageReference: AIImageReference)
    
    // MARK: - 3D Locations
    
    /// Point location in 3D patient coordinate space
    case point3D(x: Double, y: Double, z: Double, frameOfReferenceUID: String, imageReference: AIImageReference?)
    
    /// Bounding box in 3D patient coordinate space
    case boundingBox3D(
        x: Double, y: Double, z: Double,
        width: Double, height: Double, depth: Double,
        frameOfReferenceUID: String,
        imageReference: AIImageReference?
    )
    
    /// Polygon in 3D patient coordinate space
    case polygon3D(points: [Double], frameOfReferenceUID: String, imageReference: AIImageReference?)
    
    /// Ellipsoid in 3D patient coordinate space
    case ellipsoid3D(
        centerX: Double, centerY: Double, centerZ: Double,
        radiusX: Double, radiusY: Double, radiusZ: Double,
        frameOfReferenceUID: String,
        imageReference: AIImageReference?
    )
}

/// Reference to a DICOM image that the detection relates to
public struct AIImageReference: Sendable, Equatable {
    /// SOP Class UID of the referenced image
    public let sopClassUID: String
    
    /// SOP Instance UID of the referenced image
    public let sopInstanceUID: String
    
    /// Optional frame number for multi-frame images (1-based)
    public let frameNumber: Int?
    
    /// Creates a new image reference
    /// - Parameters:
    ///   - sopClassUID: SOP Class UID
    ///   - sopInstanceUID: SOP Instance UID
    ///   - frameNumber: Optional frame number (1-based)
    public init(sopClassUID: String, sopInstanceUID: String, frameNumber: Int? = nil) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.frameNumber = frameNumber
    }
}

// MARK: - Confidence Score Utilities

/// Utilities for encoding and interpreting AI confidence scores
public enum ConfidenceScore {
    /// Converts a 0.0-1.0 confidence score to a percentage string
    /// - Parameter score: Confidence score (0.0-1.0)
    /// - Returns: Percentage string (e.g., "85.5")
    public static func toPercentageString(_ score: Double) -> String {
        let percentage = score * 100.0
        return String(format: "%.1f", percentage)
    }
    
    /// Converts a 0.0-1.0 confidence score to a coded concept
    /// - Parameter score: Confidence score (0.0-1.0)
    /// - Returns: Coded concept representing confidence level
    public static func toCodedConcept(_ score: Double) -> CodedConcept {
        switch score {
        case 0.9...1.0:
            return CodedConcept(
                codeValue: "R-00339",
                codingSchemeDesignator: "SRT",
                codeMeaning: "High confidence"
            )
        case 0.7..<0.9:
            return CodedConcept(
                codeValue: "R-00340",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Medium confidence"
            )
        default:
            return CodedConcept(
                codeValue: "R-00341",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Low confidence"
            )
        }
    }
    
    /// Categorizes a confidence score
    /// - Parameter score: Confidence score (0.0-1.0)
    /// - Returns: Confidence category
    public static func categorize(_ score: Double) -> ConfidenceCategory {
        switch score {
        case 0.9...1.0:
            return .high
        case 0.7..<0.9:
            return .medium
        default:
            return .low
        }
    }
}

/// Confidence score categories
public enum ConfidenceCategory: String, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}
