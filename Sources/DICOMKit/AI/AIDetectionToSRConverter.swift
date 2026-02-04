/// AI Detection to Structured Report Converter
///
/// Provides utilities for converting AI/ML inference results into DICOM Structured Report documents.
/// Supports automatic selection of appropriate SR document type based on detection modality.
///
/// Reference: PS3.3 Section A.35 - CAD SR IODs
/// Reference: PS3.16 TID 4000 - CAD Analysis

import Foundation
import DICOMCore

// MARK: - Converter

/// Converts AI inference results to DICOM Structured Report documents
public struct AIDetectionToSRConverter: Sendable {
    
    // MARK: - Error Types
    
    /// Errors that can occur during conversion
    public enum ConversionError: Error, Sendable, Equatable {
        /// No detections to convert
        case noDetections
        
        /// Invalid confidence score (not in 0.0-1.0 range)
        case invalidConfidenceScore(Double)
        
        /// Missing required patient information
        case missingPatientInfo(String)
        
        /// Missing required study information
        case missingStudyInfo(String)
        
        /// Unsupported detection location type for the selected SR template
        case unsupportedLocationType(String)
        
        /// General conversion error
        case conversionFailed(String)
    }
    
    // MARK: - Configuration
    
    /// Configuration for SR document conversion
    public struct ConversionConfiguration: Sendable {
        /// Patient ID (required)
        public let patientID: String
        
        /// Patient name (optional)
        public let patientName: String?
        
        /// Patient birth date (optional, YYYYMMDD format)
        public let patientBirthDate: String?
        
        /// Patient sex (optional)
        public let patientSex: String?
        
        /// Study Instance UID (required)
        public let studyInstanceUID: String
        
        /// Study date (optional, YYYYMMDD format)
        public let studyDate: String?
        
        /// Study time (optional, HHMMSS format)
        public let studyTime: String?
        
        /// Study description (optional)
        public let studyDescription: String?
        
        /// Accession number (optional)
        public let accessionNumber: String?
        
        /// Series Instance UID (optional, will be generated if not provided)
        public let seriesInstanceUID: String?
        
        /// Series number (optional)
        public let seriesNumber: String?
        
        /// Instance number (optional)
        public let instanceNumber: String?
        
        /// Creates a new conversion configuration
        public init(
            patientID: String,
            patientName: String? = nil,
            patientBirthDate: String? = nil,
            patientSex: String? = nil,
            studyInstanceUID: String,
            studyDate: String? = nil,
            studyTime: String? = nil,
            studyDescription: String? = nil,
            accessionNumber: String? = nil,
            seriesInstanceUID: String? = nil,
            seriesNumber: String? = nil,
            instanceNumber: String? = nil
        ) {
            self.patientID = patientID
            self.patientName = patientName
            self.patientBirthDate = patientBirthDate
            self.patientSex = patientSex
            self.studyInstanceUID = studyInstanceUID
            self.studyDate = studyDate
            self.studyTime = studyTime
            self.studyDescription = studyDescription
            self.accessionNumber = accessionNumber
            self.seriesInstanceUID = seriesInstanceUID
            self.seriesNumber = seriesNumber
            self.instanceNumber = instanceNumber
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new AI detection to SR converter
    public init() {}
    
    // MARK: - Conversion Methods
    
    /// Converts AI inference result to a CAD SR document
    ///
    /// Automatically selects the appropriate SR document type based on the detections.
    /// For chest/lung findings, creates a Chest CAD SR. For mammography findings, creates
    /// a Mammography CAD SR. For other findings, creates an Enhanced SR with measurements.
    ///
    /// - Parameters:
    ///   - inferenceResult: The AI inference result to convert
    ///   - configuration: Configuration with patient and study information
    /// - Returns: DICOM DataSet containing the SR document
    /// - Throws: ConversionError if conversion fails
    public func convert(
        inferenceResult: AIInferenceResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        // Validate detections
        guard !inferenceResult.detections.isEmpty else {
            throw ConversionError.noDetections
        }
        
        // Validate confidence scores
        for detection in inferenceResult.detections {
            guard detection.confidence >= 0.0 && detection.confidence <= 1.0 else {
                throw ConversionError.invalidConfidenceScore(detection.confidence)
            }
        }
        
        // Determine the appropriate SR type based on detection types
        let srType = determineSRType(for: inferenceResult.detections)
        
        // Convert based on SR type
        switch srType {
        case .chestCAD:
            return try convertToChestCADSR(
                inferenceResult: inferenceResult,
                configuration: configuration
            )
        case .mammographyCAD:
            return try convertToMammographyCADSR(
                inferenceResult: inferenceResult,
                configuration: configuration
            )
        case .enhancedSR:
            return try convertToEnhancedSR(
                inferenceResult: inferenceResult,
                configuration: configuration
            )
        case .comprehensive3DSR:
            return try convertToComprehensive3DSR(
                inferenceResult: inferenceResult,
                configuration: configuration
            )
        }
    }
    
    // MARK: - Private Methods
    
    private enum SRType {
        case chestCAD
        case mammographyCAD
        case enhancedSR
        case comprehensive3DSR
    }
    
    private func determineSRType(for detections: [AIDetection]) -> SRType {
        // Check if any detections use 3D coordinates
        let has3DDetections = detections.contains { detection in
            switch detection.location {
            case .point3D, .boundingBox3D, .polygon3D, .ellipsoid3D:
                return true
            default:
                return false
            }
        }
        
        if has3DDetections {
            return .comprehensive3DSR
        }
        
        // Check for chest-specific findings
        let hasChestFindings = detections.contains { detection in
            switch detection.type {
            case .lungNodule, .pneumonia, .pulmonaryEmbolism:
                return true
            default:
                return false
            }
        }
        
        if hasChestFindings {
            return .chestCAD
        }
        
        // Check for mammography-specific findings
        let hasMammographyFindings = detections.contains { detection in
            switch detection.type {
            case .mass, .calcification:
                return true
            default:
                return false
            }
        }
        
        if hasMammographyFindings {
            return .mammographyCAD
        }
        
        // Default to Enhanced SR for general detections
        return .enhancedSR
    }
    
    private func convertToChestCADSR(
        inferenceResult: AIInferenceResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        var builder = ChestCADSRBuilder()
        
        // Set patient information
        builder = builder
            .withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        if let patientBirthDate = configuration.patientBirthDate {
            builder = builder.withPatientBirthDate(patientBirthDate)
        }
        if let patientSex = configuration.patientSex {
            builder = builder.withPatientSex(patientSex)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        if let studyDescription = configuration.studyDescription {
            builder = builder.withStudyDescription(studyDescription)
        }
        if let accessionNumber = configuration.accessionNumber {
            builder = builder.withAccessionNumber(accessionNumber)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let seriesNumber = configuration.seriesNumber {
            builder = builder.withSeriesNumber(seriesNumber)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Set CAD processing summary
        let dateFormatter = ISO8601DateFormatter()
        let processingDateTime = dateFormatter.string(from: inferenceResult.processingTimestamp)
        
        builder = builder.withCADProcessingSummary(
            algorithmName: inferenceResult.modelName,
            algorithmVersion: inferenceResult.modelVersion,
            manufacturer: inferenceResult.manufacturer,
            processingDateTime: processingDateTime
        )
        
        // Add detections as findings
        for detection in inferenceResult.detections {
            let findingType = convertToChestFindingType(detection.type)
            let findingLocation = try convertToChestFindingLocation(detection.location)
            
            builder = builder.addFinding(
                type: findingType,
                probability: detection.confidence,
                location: findingLocation,
                characteristics: nil
            )
        }
        
        return try builder.build()
    }
    
    private func convertToMammographyCADSR(
        inferenceResult: AIInferenceResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        var builder = MammographyCADSRBuilder()
        
        // Set patient information
        builder = builder
            .withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        if let patientBirthDate = configuration.patientBirthDate {
            builder = builder.withPatientBirthDate(patientBirthDate)
        }
        if let patientSex = configuration.patientSex {
            builder = builder.withPatientSex(patientSex)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        if let studyDescription = configuration.studyDescription {
            builder = builder.withStudyDescription(studyDescription)
        }
        if let accessionNumber = configuration.accessionNumber {
            builder = builder.withAccessionNumber(accessionNumber)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let seriesNumber = configuration.seriesNumber {
            builder = builder.withSeriesNumber(seriesNumber)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Set CAD processing summary
        let dateFormatter = ISO8601DateFormatter()
        let processingDateTime = dateFormatter.string(from: inferenceResult.processingTimestamp)
        
        builder = builder.withCADProcessingSummary(
            algorithmName: inferenceResult.modelName,
            algorithmVersion: inferenceResult.modelVersion,
            manufacturer: inferenceResult.manufacturer,
            processingDateTime: processingDateTime
        )
        
        // Add detections as findings
        for detection in inferenceResult.detections {
            let findingType = convertToMammographyFindingType(detection.type)
            let findingLocation = try convertToMammographyFindingLocation(detection.location)
            
            builder = builder.addFinding(
                type: findingType,
                probability: detection.confidence,
                location: findingLocation,
                characteristics: nil
            )
        }
        
        return try builder.build()
    }
    
    private func convertToEnhancedSR(
        inferenceResult: AIInferenceResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        var builder = EnhancedSRBuilder()
        
        // Set patient information
        builder = builder
            .withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        if let patientBirthDate = configuration.patientBirthDate {
            builder = builder.withPatientBirthDate(patientBirthDate)
        }
        if let patientSex = configuration.patientSex {
            builder = builder.withPatientSex(patientSex)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        if let studyDescription = configuration.studyDescription {
            builder = builder.withStudyDescription(studyDescription)
        }
        if let accessionNumber = configuration.accessionNumber {
            builder = builder.withAccessionNumber(accessionNumber)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let seriesNumber = configuration.seriesNumber {
            builder = builder.withSeriesNumber(seriesNumber)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Add AI analysis section
        builder = builder.addSection(
            heading: CodedConcept.commonSections.findings,
            content: {
                // Add processing information as text
                EnhancedSectionContent.text(
                    "AI Analysis: \(inferenceResult.modelName) v\(inferenceResult.modelVersion)"
                )
                
                EnhancedSectionContent.text(
                    "Manufacturer: \(inferenceResult.manufacturer)"
                )
                
                // Add each detection
                for (index, detection) in inferenceResult.detections.enumerated() {
                    EnhancedSectionContent.text(
                        "Finding \(index + 1): \(detection.type.concept.codeMeaning)"
                    )
                    
                    EnhancedSectionContent.measurement(
                        concept: CodedConcept(
                            codeValue: "C0237753",
                            codingSchemeDesignator: "UMLS",
                            codeMeaning: "Confidence"
                        ),
                        value: detection.confidence * 100.0,
                        unit: CodedConcept(
                            codeValue: "%",
                            codingSchemeDesignator: "UCUM",
                            codeMeaning: "Percent"
                        )
                    )
                }
            }
        )
        
        return try builder.build()
    }
    
    private func convertToComprehensive3DSR(
        inferenceResult: AIInferenceResult,
        configuration: ConversionConfiguration
    ) throws -> DataSet {
        var builder = Comprehensive3DSRBuilder()
        
        // Set patient information
        builder = builder
            .withPatientID(configuration.patientID)
        
        if let patientName = configuration.patientName {
            builder = builder.withPatientName(patientName)
        }
        if let patientBirthDate = configuration.patientBirthDate {
            builder = builder.withPatientBirthDate(patientBirthDate)
        }
        if let patientSex = configuration.patientSex {
            builder = builder.withPatientSex(patientSex)
        }
        
        // Set study information
        builder = builder.withStudyInstanceUID(configuration.studyInstanceUID)
        
        if let studyDate = configuration.studyDate {
            builder = builder.withStudyDate(studyDate)
        }
        if let studyTime = configuration.studyTime {
            builder = builder.withStudyTime(studyTime)
        }
        if let studyDescription = configuration.studyDescription {
            builder = builder.withStudyDescription(studyDescription)
        }
        if let accessionNumber = configuration.accessionNumber {
            builder = builder.withAccessionNumber(accessionNumber)
        }
        
        // Set series information
        if let seriesInstanceUID = configuration.seriesInstanceUID {
            builder = builder.withSeriesInstanceUID(seriesInstanceUID)
        }
        if let seriesNumber = configuration.seriesNumber {
            builder = builder.withSeriesNumber(seriesNumber)
        }
        if let instanceNumber = configuration.instanceNumber {
            builder = builder.withInstanceNumber(instanceNumber)
        }
        
        // Add AI analysis section with 3D coordinates
        builder = builder.addSection(
            heading: CodedConcept.commonSections.findings,
            content: {
                // Add processing information as text
                Comprehensive3DSectionContent.text(
                    "AI Analysis: \(inferenceResult.modelName) v\(inferenceResult.modelVersion)"
                )
                
                Comprehensive3DSectionContent.text(
                    "Manufacturer: \(inferenceResult.manufacturer)"
                )
                
                // Add each detection with 3D coordinates
                for (index, detection) in inferenceResult.detections.enumerated() {
                    Comprehensive3DSectionContent.text(
                        "Finding \(index + 1): \(detection.type.concept.codeMeaning)"
                    )
                    
                    Comprehensive3DSectionContent.measurement(
                        concept: CodedConcept(
                            codeValue: "C0237753",
                            codingSchemeDesignator: "UMLS",
                            codeMeaning: "Confidence"
                        ),
                        value: detection.confidence * 100.0,
                        unit: CodedConcept(
                            codeValue: "%",
                            codingSchemeDesignator: "UCUM",
                            codeMeaning: "Percent"
                        )
                    )
                    
                    // Add 3D location if available
                    if case .point3D(let x, let y, let z, let frameOfReferenceUID, _) = detection.location {
                        Comprehensive3DSectionContent.point3D(
                            x: x, y: y, z: z,
                            frameOfReferenceUID: frameOfReferenceUID
                        )
                    }
                }
            }
        )
        
        return try builder.build()
    }
    
    // MARK: - Type Conversion Helpers
    
    private func convertToChestFindingType(_ detectionType: AIDetectionType) -> ChestCADSRBuilder.FindingType {
        switch detectionType {
        case .lungNodule:
            return .nodule
        case .mass:
            return .mass
        case .pneumonia:
            return .consolidation
        case .custom(let concept):
            return .custom(concept)
        default:
            return .custom(detectionType.concept)
        }
    }
    
    private func convertToChestFindingLocation(_ location: AIDetectionLocation) throws -> ChestCADSRBuilder.FindingLocation {
        switch location {
        case .point2D(let x, let y, let imageRef):
            return .point2D(
                x: x,
                y: y,
                imageReference: ChestCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .polygon2D(let points, let imageRef):
            return .roi2D(
                points: points,
                imageReference: ChestCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .circle2D(let centerX, let centerY, let radius, let imageRef):
            return .circle2D(
                centerX: centerX,
                centerY: centerY,
                radius: radius,
                imageReference: ChestCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .boundingBox2D(let x, let y, let width, let height, let imageRef):
            // Convert bounding box to polygon (4 corners)
            let points = [
                x, y,
                x + width, y,
                x + width, y + height,
                x, y + height
            ]
            return .roi2D(
                points: points,
                imageReference: ChestCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        default:
            throw ConversionError.unsupportedLocationType("Chest CAD SR only supports 2D locations")
        }
    }
    
    private func convertToMammographyFindingType(_ detectionType: AIDetectionType) -> MammographyCADSRBuilder.FindingType {
        switch detectionType {
        case .mass:
            return .mass
        case .calcification:
            return .calcification
        case .custom(let concept):
            return .custom(concept)
        default:
            return .custom(detectionType.concept)
        }
    }
    
    private func convertToMammographyFindingLocation(_ location: AIDetectionLocation) throws -> MammographyCADSRBuilder.FindingLocation {
        switch location {
        case .point2D(let x, let y, let imageRef):
            return .point2D(
                x: x,
                y: y,
                imageReference: MammographyCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .polygon2D(let points, let imageRef):
            return .roi2D(
                points: points,
                imageReference: MammographyCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .circle2D(let centerX, let centerY, let radius, let imageRef):
            return .circle2D(
                centerX: centerX,
                centerY: centerY,
                radius: radius,
                imageReference: MammographyCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        case .boundingBox2D(let x, let y, let width, let height, let imageRef):
            // Convert bounding box to polygon (4 corners)
            let points = [
                x, y,
                x + width, y,
                x + width, y + height,
                x, y + height
            ]
            return .roi2D(
                points: points,
                imageReference: MammographyCADSRBuilder.ImageReference(
                    sopClassUID: imageRef.sopClassUID,
                    sopInstanceUID: imageRef.sopInstanceUID,
                    frameNumber: imageRef.frameNumber
                )
            )
        default:
            throw ConversionError.unsupportedLocationType("Mammography CAD SR only supports 2D locations")
        }
    }
}
