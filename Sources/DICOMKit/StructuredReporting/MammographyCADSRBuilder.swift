/// Mammography CAD SR Document Builder
///
/// Provides a specialized fluent API for creating DICOM Mammography Computer-Aided Detection (CAD)
/// Structured Report documents. These documents encode the results of CAD analysis algorithms
/// that detect and characterize potential findings in mammography images.
///
/// Reference: PS3.3 Section A.35.6 - Mammography CAD SR IOD
/// Reference: PS3.16 TID 4000 - CAD Analysis
/// Reference: PS3.16 TID 4019 - CAD Finding
/// Reference: PS3.16 TID 4001 - CAD Processing Summary

import Foundation
import DICOMCore

/// Specialized builder for creating DICOM Mammography CAD SR documents
///
/// MammographyCADSRBuilder provides a simplified API for creating documents that
/// contain computer-aided detection results for mammography images, including
/// detected findings with confidence scores and spatial locations.
///
/// Example:
/// ```swift
/// let document = try MammographyCADSRBuilder()
///     .withPatientID("12345")
///     .withPatientName("Doe^Jane")
///     .withCADProcessingSummary(
///         algorithmName: "MammoCAD v2.1",
///         algorithmVersion: "2.1.0",
///         manufacturer: "Example Medical Systems"
///     )
///     .addFinding(
///         type: .mass,
///         probability: 0.85,
///         location: .point2D(x: 128.5, y: 256.3, imageReference: imageRef)
///     )
///     .build()
/// ```
///
/// ## Finding Types
/// Mammography CAD findings typically include:
/// - Masses
/// - Calcifications
/// - Architectural distortions
/// - Asymmetries
///
/// ## Supported Content
/// Mammography CAD SR documents support:
/// - TEXT - Text descriptions
/// - CODE - Coded concepts
/// - NUM - Numeric measurements (confidence, size)
/// - DATETIME, DATE, TIME - Temporal information
/// - UIDREF - UID references
/// - PNAME - Person names
/// - COMPOSITE, IMAGE - References to mammography images
/// - SCOORD - 2D spatial coordinates for findings
/// - TCOORD - Temporal coordinates
/// - CONTAINER - Hierarchical structure
public struct MammographyCADSRBuilder: Sendable {
    
    // MARK: - Error Types
    
    /// Errors that can occur during building
    public enum BuildError: Error, Sendable, Equatable {
        /// Validation error
        case validationError(String)
    }
    
    // MARK: - Configuration
    
    /// Whether to validate during build
    public let validateOnBuild: Bool
    
    // MARK: - Document Identification
    
    /// SOP Instance UID (will be generated if not set)
    public private(set) var sopInstanceUID: String?
    
    /// Study Instance UID
    public private(set) var studyInstanceUID: String?
    
    /// Series Instance UID
    public private(set) var seriesInstanceUID: String?
    
    /// Instance Number
    public private(set) var instanceNumber: String?
    
    // MARK: - Patient Information
    
    /// Patient ID
    public private(set) var patientID: String?
    
    /// Patient Name
    public private(set) var patientName: String?
    
    /// Patient Birth Date
    public private(set) var patientBirthDate: String?
    
    /// Patient Sex
    public private(set) var patientSex: String?
    
    // MARK: - Study Information
    
    /// Study Date
    public private(set) var studyDate: String?
    
    /// Study Time
    public private(set) var studyTime: String?
    
    /// Study Description
    public private(set) var studyDescription: String?
    
    /// Accession Number
    public private(set) var accessionNumber: String?
    
    /// Referring Physician's Name
    public private(set) var referringPhysicianName: String?
    
    // MARK: - Series Information
    
    /// Series Number
    public private(set) var seriesNumber: String?
    
    /// Series Description
    public private(set) var seriesDescription: String?
    
    // MARK: - Document Information
    
    /// Content Date
    public private(set) var contentDate: String?
    
    /// Content Time
    public private(set) var contentTime: String?
    
    /// Completion Flag
    public private(set) var completionFlag: CompletionFlag = .complete
    
    /// Verification Flag
    public private(set) var verificationFlag: VerificationFlag = .unverified
    
    // MARK: - CAD Processing Information
    
    /// CAD algorithm name
    public private(set) var algorithmName: String?
    
    /// CAD algorithm version
    public private(set) var algorithmVersion: String?
    
    /// Manufacturer of the CAD system
    public private(set) var manufacturer: String?
    
    /// Processing date/time
    public private(set) var processingDateTime: String?
    
    // MARK: - CAD Findings
    
    /// Detected CAD findings
    public private(set) var findings: [CADFinding] = []
    
    // MARK: - Initialization
    
    /// Creates a new Mammography CAD SR document builder
    /// - Parameter validateOnBuild: Whether to validate the document during build (default: true)
    public init(validateOnBuild: Bool = true) {
        self.validateOnBuild = validateOnBuild
    }
    
    // MARK: - Document Identification Setters
    
    /// Sets the SOP Instance UID
    /// - Parameter uid: The SOP Instance UID (or nil to auto-generate)
    /// - Returns: A new builder with the updated value
    public func withSOPInstanceUID(_ uid: String?) -> Self {
        var copy = self
        copy.sopInstanceUID = uid
        return copy
    }
    
    /// Sets the Study Instance UID
    /// - Parameter uid: The Study Instance UID
    /// - Returns: A new builder with the updated value
    public func withStudyInstanceUID(_ uid: String) -> Self {
        var copy = self
        copy.studyInstanceUID = uid
        return copy
    }
    
    /// Sets the Series Instance UID
    /// - Parameter uid: The Series Instance UID (or nil to auto-generate)
    /// - Returns: A new builder with the updated value
    public func withSeriesInstanceUID(_ uid: String?) -> Self {
        var copy = self
        copy.seriesInstanceUID = uid
        return copy
    }
    
    /// Sets the Instance Number
    /// - Parameter number: The instance number as string
    /// - Returns: A new builder with the updated value
    public func withInstanceNumber(_ number: String) -> Self {
        var copy = self
        copy.instanceNumber = number
        return copy
    }
    
    // MARK: - Patient Information Setters
    
    /// Sets the Patient ID
    /// - Parameter id: The patient ID
    /// - Returns: A new builder with the updated value
    public func withPatientID(_ id: String) -> Self {
        var copy = self
        copy.patientID = id
        return copy
    }
    
    /// Sets the Patient Name
    /// - Parameter name: The patient name
    /// - Returns: A new builder with the updated value
    public func withPatientName(_ name: String) -> Self {
        var copy = self
        copy.patientName = name
        return copy
    }
    
    /// Sets the Patient Birth Date
    /// - Parameter date: The birth date (YYYYMMDD format)
    /// - Returns: A new builder with the updated value
    public func withPatientBirthDate(_ date: String) -> Self {
        var copy = self
        copy.patientBirthDate = date
        return copy
    }
    
    /// Sets the Patient Sex
    /// - Parameter sex: The patient sex (M, F, O, or empty)
    /// - Returns: A new builder with the updated value
    public func withPatientSex(_ sex: String) -> Self {
        var copy = self
        copy.patientSex = sex
        return copy
    }
    
    // MARK: - Study Information Setters
    
    /// Sets the Study Date
    /// - Parameter date: The study date (YYYYMMDD format)
    /// - Returns: A new builder with the updated value
    public func withStudyDate(_ date: String) -> Self {
        var copy = self
        copy.studyDate = date
        return copy
    }
    
    /// Sets the Study Time
    /// - Parameter time: The study time (HHMMSS format)
    /// - Returns: A new builder with the updated value
    public func withStudyTime(_ time: String) -> Self {
        var copy = self
        copy.studyTime = time
        return copy
    }
    
    /// Sets the Study Description
    /// - Parameter description: The study description
    /// - Returns: A new builder with the updated value
    public func withStudyDescription(_ description: String) -> Self {
        var copy = self
        copy.studyDescription = description
        return copy
    }
    
    /// Sets the Accession Number
    /// - Parameter number: The accession number
    /// - Returns: A new builder with the updated value
    public func withAccessionNumber(_ number: String) -> Self {
        var copy = self
        copy.accessionNumber = number
        return copy
    }
    
    /// Sets the Referring Physician's Name
    /// - Parameter name: The referring physician's name
    /// - Returns: A new builder with the updated value
    public func withReferringPhysicianName(_ name: String) -> Self {
        var copy = self
        copy.referringPhysicianName = name
        return copy
    }
    
    // MARK: - Series Information Setters
    
    /// Sets the Series Number
    /// - Parameter number: The series number as string
    /// - Returns: A new builder with the updated value
    public func withSeriesNumber(_ number: String) -> Self {
        var copy = self
        copy.seriesNumber = number
        return copy
    }
    
    /// Sets the Series Description
    /// - Parameter description: The series description
    /// - Returns: A new builder with the updated value
    public func withSeriesDescription(_ description: String) -> Self {
        var copy = self
        copy.seriesDescription = description
        return copy
    }
    
    // MARK: - Document Information Setters
    
    /// Sets the Content Date
    /// - Parameter date: The content date (YYYYMMDD format, or nil for current date)
    /// - Returns: A new builder with the updated value
    public func withContentDate(_ date: String?) -> Self {
        var copy = self
        copy.contentDate = date
        return copy
    }
    
    /// Sets the Content Time
    /// - Parameter time: The content time (HHMMSS format, or nil for current time)
    /// - Returns: A new builder with the updated value
    public func withContentTime(_ time: String?) -> Self {
        var copy = self
        copy.contentTime = time
        return copy
    }
    
    /// Sets the Completion Flag
    /// - Parameter flag: The completion flag
    /// - Returns: A new builder with the updated value
    public func withCompletionFlag(_ flag: CompletionFlag) -> Self {
        var copy = self
        copy.completionFlag = flag
        return copy
    }
    
    /// Sets the Verification Flag
    /// - Parameter flag: The verification flag
    /// - Returns: A new builder with the updated value
    public func withVerificationFlag(_ flag: VerificationFlag) -> Self {
        var copy = self
        copy.verificationFlag = flag
        return copy
    }
    
    // MARK: - CAD Processing Setters
    
    /// Sets the CAD processing summary information
    /// - Parameters:
    ///   - algorithmName: Name of the CAD algorithm
    ///   - algorithmVersion: Version of the CAD algorithm
    ///   - manufacturer: Manufacturer of the CAD system
    ///   - processingDateTime: When the processing occurred (optional)
    /// - Returns: A new builder with the updated values
    public func withCADProcessingSummary(
        algorithmName: String,
        algorithmVersion: String,
        manufacturer: String,
        processingDateTime: String? = nil
    ) -> Self {
        var copy = self
        copy.algorithmName = algorithmName
        copy.algorithmVersion = algorithmVersion
        copy.manufacturer = manufacturer
        copy.processingDateTime = processingDateTime
        return copy
    }
    
    // MARK: - Finding Management
    
    /// Adds a CAD finding to the document
    /// - Parameter finding: The CAD finding to add
    /// - Returns: A new builder with the finding added
    public func addFinding(_ finding: CADFinding) -> Self {
        var copy = self
        copy.findings.append(finding)
        return copy
    }
    
    /// Adds a CAD finding with detailed parameters
    /// - Parameters:
    ///   - type: The type of finding
    ///   - probability: Confidence/probability score (0.0-1.0)
    ///   - location: Spatial location of the finding
    ///   - characteristics: Optional characteristics or descriptors
    /// - Returns: A new builder with the finding added
    public func addFinding(
        type: FindingType,
        probability: Double,
        location: FindingLocation,
        characteristics: [CodedConcept]? = nil
    ) -> Self {
        let finding = CADFinding(
            type: type,
            probability: probability,
            location: location,
            characteristics: characteristics
        )
        return addFinding(finding)
    }
    
    /// Removes all findings
    /// - Returns: A new builder with findings cleared
    public func clearFindings() -> Self {
        var copy = self
        copy.findings.removeAll()
        return copy
    }
    
    // MARK: - Build
    
    /// Builds the Mammography CAD SR document
    /// - Returns: The constructed SRDocument
    /// - Throws: BuildError if validation fails
    public func build() throws -> SRDocument {
        // Validate if required
        if validateOnBuild {
            try validate()
        }
        
        // Generate UIDs if needed
        let finalSOPInstanceUID = sopInstanceUID ?? UIDGenerator.generateUID().value
        let finalStudyInstanceUID = studyInstanceUID ?? UIDGenerator.generateUID().value
        let finalSeriesInstanceUID = seriesInstanceUID ?? UIDGenerator.generateUID().value
        
        // Build the root container
        let rootContainer = try buildRootContainer()
        
        // Document title for CAD report
        let documentTitle = CodedConcept(
            codeValue: "111036",
            codingSchemeDesignator: "DCM",
            codeMeaning: "Mammography CAD Report"
        )
        
        // Create the SR document
        let document = SRDocument(
            sopClassUID: SRDocumentType.mammographyCADSR.sopClassUID,
            sopInstanceUID: finalSOPInstanceUID,
            patientID: patientID,
            patientName: patientName,
            studyInstanceUID: finalStudyInstanceUID,
            studyDate: studyDate,
            studyTime: studyTime,
            accessionNumber: accessionNumber,
            seriesInstanceUID: finalSeriesInstanceUID,
            seriesNumber: seriesNumber,
            modality: "SR",
            contentDate: contentDate,
            contentTime: contentTime,
            instanceNumber: instanceNumber,
            completionFlag: completionFlag,
            verificationFlag: verificationFlag,
            preliminaryFlag: nil,
            documentTitle: documentTitle,
            rootContent: rootContainer
        )
        
        return document
    }
    
    // MARK: - Private Helpers
    
    private func buildRootContainer() throws -> ContainerContentItem {
        var contentItems: [AnyContentItem] = []
        
        // Add CAD Processing Summary (TID 4001)
        if let processingSummary = buildProcessingSummary() {
            contentItems.append(AnyContentItem(processingSummary))
        }
        
        // Add each CAD finding (TID 4019)
        for finding in findings {
            let findingContainer = try buildFinding(finding)
            contentItems.append(AnyContentItem(findingContainer))
        }
        
        // Create the root container
        let rootContainer = ContainerContentItem(
            conceptName: CodedConcept(
                codeValue: "111036",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Mammography CAD Report"
            ),
            continuityOfContent: .separate,
            contentItems: contentItems
        )
        
        return rootContainer
    }
    
    private func buildProcessingSummary() -> ContainerContentItem? {
        guard algorithmName != nil || algorithmVersion != nil || manufacturer != nil else {
            return nil
        }
        
        var contentItems: [AnyContentItem] = []
        
        // Algorithm Name
        if let name = algorithmName {
            let nameItem = TextContentItem(
                conceptName: CodedConcept(
                    codeValue: "111001",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Algorithm Name"
                ),
                textValue: name,
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(nameItem))
        }
        
        // Algorithm Version
        if let version = algorithmVersion {
            let versionItem = TextContentItem(
                conceptName: CodedConcept(
                    codeValue: "111003",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Algorithm Version"
                ),
                textValue: version,
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(versionItem))
        }
        
        // Manufacturer
        if let mfr = manufacturer {
            let mfrItem = TextContentItem(
                conceptName: CodedConcept(
                    codeValue: "113878",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Manufacturer"
                ),
                textValue: mfr,
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(mfrItem))
        }
        
        // Processing Date/Time
        if let dateTime = processingDateTime {
            let dateTimeItem = DateTimeContentItem(
                conceptName: CodedConcept(
                    codeValue: "111005",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Processing Date Time"
                ),
                dateTimeValue: dateTime,
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(dateTimeItem))
        }
        
        return ContainerContentItem(
            conceptName: CodedConcept(
                codeValue: "111001",
                codingSchemeDesignator: "DCM",
                codeMeaning: "CAD Processing Summary"
            ),
            continuityOfContent: .separate,
            contentItems: contentItems,
            relationshipType: .contains
        )
    }
    
    private func buildFinding(_ finding: CADFinding) throws -> ContainerContentItem {
        var contentItems: [AnyContentItem] = []
        
        // Finding type
        let typeItem = CodeContentItem(
            conceptName: CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            ),
            conceptCode: finding.type.concept,
            relationshipType: .contains
        )
        contentItems.append(AnyContentItem(typeItem))
        
        // Probability/confidence
        let probabilityItem = NumericContentItem(
            conceptName: CodedConcept(
                codeValue: "111047",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Probability"
            ),
            value: finding.probability,
            units: CodedConcept(
                codeValue: "1",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "no units"
            ),
            relationshipType: .contains
        )
        contentItems.append(AnyContentItem(probabilityItem))
        
        // Location
        switch finding.location {
        case .point2D(let x, let y, let imageRef):
            let coordItem = SpatialCoordinatesContentItem(
                conceptName: CodedConcept(
                    codeValue: "111030",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Center"
                ),
                graphicType: .point,
                graphicData: [Float(x), Float(y)],
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(coordItem))
            
            // Add image reference
            let imageItem = ImageContentItem(
                conceptName: nil,
                imageReference: imageRef,
                relationshipType: .selectedFrom
            )
            contentItems.append(AnyContentItem(imageItem))
            
        case .roi2D(let points, let imageRef):
            let coordItem = SpatialCoordinatesContentItem(
                conceptName: CodedConcept(
                    codeValue: "111034",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "ROI"
                ),
                graphicType: .polyline,
                graphicData: points.map { Float($0) },
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(coordItem))
            
            // Add image reference
            let imageItem = ImageContentItem(
                conceptName: nil,
                imageReference: imageRef,
                relationshipType: .selectedFrom
            )
            contentItems.append(AnyContentItem(imageItem))
            
        case .circle2D(let centerX, let centerY, let radius, let imageRef):
            let coordItem = SpatialCoordinatesContentItem(
                conceptName: CodedConcept(
                    codeValue: "111034",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "ROI"
                ),
                graphicType: .circle,
                graphicData: [Float(centerX), Float(centerY), Float(radius)],
                relationshipType: .contains
            )
            contentItems.append(AnyContentItem(coordItem))
            
            // Add image reference
            let imageItem = ImageContentItem(
                conceptName: nil,
                imageReference: imageRef,
                relationshipType: .selectedFrom
            )
            contentItems.append(AnyContentItem(imageItem))
        }
        
        // Characteristics
        if let chars = finding.characteristics {
            for characteristic in chars {
                let charItem = CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "121071",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Finding"
                    ),
                    conceptCode: characteristic,
                    relationshipType: .contains
                )
                contentItems.append(AnyContentItem(charItem))
            }
        }
        
        return ContainerContentItem(
            conceptName: CodedConcept(
                codeValue: "111034",
                codingSchemeDesignator: "DCM",
                codeMeaning: "CAD Finding"
            ),
            continuityOfContent: .separate,
            contentItems: contentItems,
            relationshipType: .contains
        )
    }
    
    private func validate() throws {
        // Algorithm name should be present for meaningful CAD reports
        if algorithmName == nil {
            throw BuildError.validationError(
                "CAD algorithm name should be specified"
            )
        }
        
        // At least one finding should be present
        if findings.isEmpty {
            throw BuildError.validationError(
                "Mammography CAD SR document must contain at least one finding"
            )
        }
        
        // Validate probability values
        for finding in findings {
            if finding.probability < 0.0 || finding.probability > 1.0 {
                throw BuildError.validationError(
                    "Finding probability must be between 0.0 and 1.0, got \(finding.probability)"
                )
            }
        }
    }
}

// MARK: - Supporting Types

/// Represents a CAD finding in a Mammography CAD SR document
public struct CADFinding: Sendable, Equatable {
    /// Type of finding
    public let type: FindingType
    
    /// Confidence/probability score (0.0-1.0)
    public let probability: Double
    
    /// Spatial location of the finding
    public let location: FindingLocation
    
    /// Optional characteristics or descriptors
    public let characteristics: [CodedConcept]?
    
    /// Creates a new CAD finding
    public init(
        type: FindingType,
        probability: Double,
        location: FindingLocation,
        characteristics: [CodedConcept]? = nil
    ) {
        self.type = type
        self.probability = probability
        self.location = location
        self.characteristics = characteristics
    }
}

/// Types of findings in mammography CAD
public enum FindingType: Sendable, Equatable {
    /// Mass
    case mass
    
    /// Calcification
    case calcification
    
    /// Architectural distortion
    case architecturalDistortion
    
    /// Asymmetry
    case asymmetry
    
    /// Custom finding type
    case custom(CodedConcept)
    
    /// The coded concept for this finding type
    public var concept: CodedConcept {
        switch self {
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
        case .architecturalDistortion:
            return CodedConcept(
                codeValue: "F-01775",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Architectural Distortion"
            )
        case .asymmetry:
            return CodedConcept(
                codeValue: "F-01710",
                codingSchemeDesignator: "SRT",
                codeMeaning: "Asymmetry"
            )
        case .custom(let concept):
            return concept
        }
    }
}

/// Spatial location of a finding
public enum FindingLocation: Sendable, Equatable {
    /// Point location (x, y coordinates)
    case point2D(x: Double, y: Double, imageReference: ImageReference)
    
    /// Region of interest (polygon defined by points)
    case roi2D(points: [Double], imageReference: ImageReference)
    
    /// Circular region (center x, y, radius)
    case circle2D(centerX: Double, centerY: Double, radius: Double, imageReference: ImageReference)
}
