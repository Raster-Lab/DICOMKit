/// TID 1500 Measurement Report Builder
///
/// Provides a specialized fluent API for creating DICOM TID 1500 Measurement Report
/// documents. These reports are used for quantitative imaging, AI/ML outputs, and
/// structured measurement data from imaging studies.
///
/// Reference: PS3.16 TID 1500 - Measurement Report
/// Reference: PS3.3 Section A.35.3 - Comprehensive SR (base IOD)

import Foundation
import DICOMCore

/// Specialized builder for creating DICOM TID 1500 Measurement Report documents
///
/// MeasurementReportBuilder provides an API for creating structured reports that contain
/// imaging measurements, image libraries, and qualitative evaluations. This template is
/// widely used for quantitative imaging workflows and AI/ML detection outputs.
///
/// Example:
/// ```swift
/// let report = try MeasurementReportBuilder()
///     .withPatientID("12345")
///     .withPatientName("Doe^John")
///     .withDocumentTitle(MeasurementReportDocumentTitle.imagingMeasurementReport)
///     .addImageLibraryEntry(
///         sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
///         sopInstanceUID: "1.2.3.4.5.6.7.8.9"
///     )
///     .addMeasurementGroup(
///         trackingIdentifier: "Lesion 1",
///         trackingUID: "1.2.3.4.5.6.7.8.10"
///     ) {
///         MeasurementGroupContentHelper.longAxisMM(value: 25.5)
///         MeasurementGroupContentHelper.shortAxisMM(value: 18.2)
///     }
///     .build()
/// ```
///
/// ## Supported Content
/// - Image Library: References to source images used for measurements
/// - Measurement Groups: Organized groups of related measurements with tracking
/// - Qualitative Evaluations: Coded assessments and findings
/// - Observation Context: Observer and subject context information
///
/// ## Base IOD
/// TID 1500 uses the Comprehensive SR IOD, supporting all its value types.
public struct MeasurementReportBuilder: Sendable {
    
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
    
    /// Document Title (Concept Name of root container)
    public private(set) var documentTitle: CodedConcept?
    
    /// Completion Flag
    public private(set) var completionFlag: CompletionFlag = .partial
    
    /// Verification Flag
    public private(set) var verificationFlag: VerificationFlag = .unverified
    
    /// Preliminary Flag
    public private(set) var preliminaryFlag: PreliminaryFlag?
    
    // MARK: - Procedure Information
    
    /// Procedure Reported codes
    public private(set) var proceduresReported: [CodedConcept] = []
    
    // MARK: - Language
    
    /// Language of content
    public private(set) var languageOfContent: CodedConcept?
    
    /// Country of language
    public private(set) var countryOfLanguage: CodedConcept?
    
    // MARK: - Content Structures
    
    /// Image library entries
    public private(set) var imageLibraryEntries: [ImageLibraryEntry] = []
    
    /// Measurement groups (TID 1501)
    public private(set) var measurementGroups: [MeasurementGroupData] = []
    
    /// Qualitative evaluations
    public private(set) var qualitativeEvaluations: [CodedConcept] = []
    
    // MARK: - Initialization
    
    /// Creates a new Measurement Report builder
    /// - Parameter validateOnBuild: Whether to validate the document during build (default: true)
    public init(validateOnBuild: Bool = true) {
        self.validateOnBuild = validateOnBuild
    }
    
    // MARK: - Document Identification Setters
    
    /// Sets the SOP Instance UID
    /// - Parameter uid: The SOP Instance UID
    /// - Returns: Updated builder
    public func withSOPInstanceUID(_ uid: String) -> MeasurementReportBuilder {
        var copy = self
        copy.sopInstanceUID = uid
        return copy
    }
    
    /// Sets the Study Instance UID
    /// - Parameter uid: The Study Instance UID
    /// - Returns: Updated builder
    public func withStudyInstanceUID(_ uid: String) -> MeasurementReportBuilder {
        var copy = self
        copy.studyInstanceUID = uid
        return copy
    }
    
    /// Sets the Series Instance UID
    /// - Parameter uid: The Series Instance UID
    /// - Returns: Updated builder
    public func withSeriesInstanceUID(_ uid: String) -> MeasurementReportBuilder {
        var copy = self
        copy.seriesInstanceUID = uid
        return copy
    }
    
    /// Sets the Instance Number
    /// - Parameter number: The instance number
    /// - Returns: Updated builder
    public func withInstanceNumber(_ number: String) -> MeasurementReportBuilder {
        var copy = self
        copy.instanceNumber = number
        return copy
    }
    
    // MARK: - Patient Information Setters
    
    /// Sets the Patient ID
    /// - Parameter id: The patient ID
    /// - Returns: Updated builder
    public func withPatientID(_ id: String) -> MeasurementReportBuilder {
        var copy = self
        copy.patientID = id
        return copy
    }
    
    /// Sets the Patient Name
    /// - Parameter name: The patient name in DICOM PN format (e.g., "Doe^John")
    /// - Returns: Updated builder
    public func withPatientName(_ name: String) -> MeasurementReportBuilder {
        var copy = self
        copy.patientName = name
        return copy
    }
    
    /// Sets the Patient Birth Date
    /// - Parameter date: The birth date in DICOM DA format (YYYYMMDD)
    /// - Returns: Updated builder
    public func withPatientBirthDate(_ date: String) -> MeasurementReportBuilder {
        var copy = self
        copy.patientBirthDate = date
        return copy
    }
    
    /// Sets the Patient Sex
    /// - Parameter sex: The patient sex (M, F, or O)
    /// - Returns: Updated builder
    public func withPatientSex(_ sex: String) -> MeasurementReportBuilder {
        var copy = self
        copy.patientSex = sex
        return copy
    }
    
    // MARK: - Study Information Setters
    
    /// Sets the Study Date
    /// - Parameter date: The study date in DICOM DA format (YYYYMMDD)
    /// - Returns: Updated builder
    public func withStudyDate(_ date: String) -> MeasurementReportBuilder {
        var copy = self
        copy.studyDate = date
        return copy
    }
    
    /// Sets the Study Time
    /// - Parameter time: The study time in DICOM TM format
    /// - Returns: Updated builder
    public func withStudyTime(_ time: String) -> MeasurementReportBuilder {
        var copy = self
        copy.studyTime = time
        return copy
    }
    
    /// Sets the Study Description
    /// - Parameter description: The study description
    /// - Returns: Updated builder
    public func withStudyDescription(_ description: String) -> MeasurementReportBuilder {
        var copy = self
        copy.studyDescription = description
        return copy
    }
    
    /// Sets the Accession Number
    /// - Parameter number: The accession number
    /// - Returns: Updated builder
    public func withAccessionNumber(_ number: String) -> MeasurementReportBuilder {
        var copy = self
        copy.accessionNumber = number
        return copy
    }
    
    /// Sets the Referring Physician's Name
    /// - Parameter name: The referring physician's name in DICOM PN format
    /// - Returns: Updated builder
    public func withReferringPhysicianName(_ name: String) -> MeasurementReportBuilder {
        var copy = self
        copy.referringPhysicianName = name
        return copy
    }
    
    // MARK: - Series Information Setters
    
    /// Sets the Series Number
    /// - Parameter number: The series number
    /// - Returns: Updated builder
    public func withSeriesNumber(_ number: String) -> MeasurementReportBuilder {
        var copy = self
        copy.seriesNumber = number
        return copy
    }
    
    /// Sets the Series Description
    /// - Parameter description: The series description
    /// - Returns: Updated builder
    public func withSeriesDescription(_ description: String) -> MeasurementReportBuilder {
        var copy = self
        copy.seriesDescription = description
        return copy
    }
    
    // MARK: - Document Information Setters
    
    /// Sets the Content Date
    /// - Parameter date: The content date in DICOM DA format (YYYYMMDD)
    /// - Returns: Updated builder
    public func withContentDate(_ date: String) -> MeasurementReportBuilder {
        var copy = self
        copy.contentDate = date
        return copy
    }
    
    /// Sets the Content Time
    /// - Parameter time: The content time in DICOM TM format
    /// - Returns: Updated builder
    public func withContentTime(_ time: String) -> MeasurementReportBuilder {
        var copy = self
        copy.contentTime = time
        return copy
    }
    
    /// Sets the Document Title using a coded concept
    /// - Parameter title: The document title as a coded concept (from CID 7021)
    /// - Returns: Updated builder
    public func withDocumentTitle(_ title: CodedConcept) -> MeasurementReportBuilder {
        var copy = self
        copy.documentTitle = title
        return copy
    }
    
    /// Sets the Document Title to Imaging Measurement Report
    /// - Returns: Updated builder
    public func withImagingMeasurementReportTitle() -> MeasurementReportBuilder {
        withDocumentTitle(MeasurementReportDocumentTitle.imagingMeasurementReport)
    }
    
    /// Sets the Completion Flag
    /// - Parameter flag: The completion flag
    /// - Returns: Updated builder
    public func withCompletionFlag(_ flag: CompletionFlag) -> MeasurementReportBuilder {
        var copy = self
        copy.completionFlag = flag
        return copy
    }
    
    /// Sets the Verification Flag
    /// - Parameter flag: The verification flag
    /// - Returns: Updated builder
    public func withVerificationFlag(_ flag: VerificationFlag) -> MeasurementReportBuilder {
        var copy = self
        copy.verificationFlag = flag
        return copy
    }
    
    /// Sets the Preliminary Flag
    /// - Parameter flag: The preliminary flag
    /// - Returns: Updated builder
    public func withPreliminaryFlag(_ flag: PreliminaryFlag) -> MeasurementReportBuilder {
        var copy = self
        copy.preliminaryFlag = flag
        return copy
    }
    
    // MARK: - Procedure Reported
    
    /// Adds a procedure reported code
    /// - Parameter procedure: The procedure code
    /// - Returns: Updated builder
    public func addProcedureReported(_ procedure: CodedConcept) -> MeasurementReportBuilder {
        var copy = self
        copy.proceduresReported.append(procedure)
        return copy
    }
    
    // MARK: - Language Settings
    
    /// Sets the language of content
    /// - Parameters:
    ///   - language: The language code
    ///   - country: Optional country code
    /// - Returns: Updated builder
    public func withLanguage(_ language: CodedConcept, country: CodedConcept? = nil) -> MeasurementReportBuilder {
        var copy = self
        copy.languageOfContent = language
        copy.countryOfLanguage = country
        return copy
    }
    
    // MARK: - Image Library
    
    /// Adds an image library entry
    /// - Parameters:
    ///   - sopClassUID: The SOP Class UID of the referenced image
    ///   - sopInstanceUID: The SOP Instance UID of the referenced image
    ///   - frameNumbers: Optional specific frame numbers
    ///   - modality: Optional modality code
    ///   - targetRegion: Optional target region code
    ///   - laterality: Optional laterality code
    /// - Returns: Updated builder
    public func addImageLibraryEntry(
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil,
        modality: CodedConcept? = nil,
        targetRegion: CodedConcept? = nil,
        laterality: CodedConcept? = nil
    ) -> MeasurementReportBuilder {
        var copy = self
        let entry = ImageLibraryEntry(
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            frameNumbers: frameNumbers,
            modality: modality,
            targetRegion: targetRegion,
            laterality: laterality
        )
        copy.imageLibraryEntries.append(entry)
        return copy
    }
    
    /// Adds multiple image library entries
    /// - Parameter entries: The image library entries to add
    /// - Returns: Updated builder
    public func addImageLibraryEntries(_ entries: [ImageLibraryEntry]) -> MeasurementReportBuilder {
        var copy = self
        copy.imageLibraryEntries.append(contentsOf: entries)
        return copy
    }
    
    // MARK: - Measurement Groups
    
    /// Adds a measurement group with the builder pattern
    /// - Parameters:
    ///   - trackingIdentifier: The human-readable tracking identifier for this group
    ///   - trackingUID: The unique identifier for tracking across studies (generated if not provided)
    ///   - builder: A closure that configures the measurement group
    /// - Returns: Updated builder
    public func addMeasurementGroup(
        trackingIdentifier: String,
        trackingUID: String? = nil,
        @MeasurementGroupContentBuilder builder: () -> [MeasurementGroupContent]
    ) -> MeasurementReportBuilder {
        var copy = self
        let contents = builder()
        let group = MeasurementGroupData(
            trackingIdentifier: trackingIdentifier,
            trackingUID: trackingUID ?? UIDGenerator.generateUID().value,
            contents: contents
        )
        copy.measurementGroups.append(group)
        return copy
    }
    
    /// Adds a pre-built measurement group
    /// - Parameter group: The measurement group data
    /// - Returns: Updated builder
    public func addMeasurementGroup(_ group: MeasurementGroupData) -> MeasurementReportBuilder {
        var copy = self
        copy.measurementGroups.append(group)
        return copy
    }
    
    // MARK: - Qualitative Evaluations
    
    /// Adds a qualitative evaluation
    /// - Parameters:
    ///   - conceptName: The evaluation concept name
    ///   - value: The evaluation value (coded)
    /// - Returns: Updated builder
    public func addQualitativeEvaluation(
        conceptName: CodedConcept,
        value: CodedConcept
    ) -> MeasurementReportBuilder {
        var copy = self
        // Store as a pair encoded in the evaluations array
        copy.qualitativeEvaluations.append(value)
        return copy
    }
    
    // MARK: - Build
    
    /// Builds the TID 1500 Measurement Report document
    /// - Returns: The constructed SR document
    /// - Throws: `BuildError` if validation fails
    public func build() throws -> SRDocument {
        // Validate if requested
        if validateOnBuild {
            try validate()
        }
        
        // Generate UIDs if not provided
        let finalSOPInstanceUID = sopInstanceUID ?? UIDGenerator.generateUID().value
        let finalStudyInstanceUID = studyInstanceUID ?? UIDGenerator.generateUID().value
        let finalSeriesInstanceUID = seriesInstanceUID ?? UIDGenerator.generateUID().value
        
        // Build content tree according to TID 1500 structure
        var rootContentItems: [AnyContentItem] = []
        
        // Add Language of Content (Row 2 of TID 1500)
        if let language = languageOfContent {
            rootContentItems.append(AnyContentItem(CodeContentItem(
                conceptName: CodedConcept(
                    codeValue: "121049",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Language of Content Item and Descendants"
                ),
                conceptCode: language,
                relationshipType: .hasConceptMod
            )))
            
            if let country = countryOfLanguage {
                rootContentItems.append(AnyContentItem(CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "121046",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Country of Language"
                    ),
                    conceptCode: country,
                    relationshipType: .hasConceptMod
                )))
            }
        }
        
        // Add Procedure Reported (Row 4 of TID 1500)
        for procedure in proceduresReported {
            rootContentItems.append(AnyContentItem(CodeContentItem(
                conceptName: CodedConcept(
                    codeValue: "121058",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Procedure Reported"
                ),
                conceptCode: procedure,
                relationshipType: .hasConceptMod
            )))
        }
        
        // Add Image Library (Row 5 of TID 1500)
        if !imageLibraryEntries.isEmpty {
            let imageLibraryItems = buildImageLibraryItems()
            let imageLibraryContainer = ContainerContentItem(
                conceptName: CodedConcept(
                    codeValue: "111028",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Image Library"
                ),
                continuityOfContent: .separate,
                contentItems: imageLibraryItems,
                relationshipType: .contains
            )
            rootContentItems.append(AnyContentItem(imageLibraryContainer))
        }
        
        // Add Imaging Measurements container (Row 6 of TID 1500)
        if !measurementGroups.isEmpty {
            let measurementGroupItems = buildMeasurementGroupItems()
            let imagingMeasurementsContainer = ContainerContentItem(
                conceptName: CodedConcept(
                    codeValue: "126010",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Imaging Measurements"
                ),
                continuityOfContent: .separate,
                contentItems: measurementGroupItems,
                relationshipType: .contains
            )
            rootContentItems.append(AnyContentItem(imagingMeasurementsContainer))
        }
        
        // Add Qualitative Evaluations container (Row 9 of TID 1500)
        if !qualitativeEvaluations.isEmpty {
            let evaluationItems = qualitativeEvaluations.map { evaluation in
                AnyContentItem(CodeContentItem(
                    conceptName: nil,
                    conceptCode: evaluation,
                    relationshipType: .contains
                ))
            }
            let evaluationsContainer = ContainerContentItem(
                conceptName: CodedConcept(
                    codeValue: "C0034375",
                    codingSchemeDesignator: "UMLS",
                    codeMeaning: "Qualitative Evaluations"
                ),
                continuityOfContent: .separate,
                contentItems: evaluationItems,
                relationshipType: .contains
            )
            rootContentItems.append(AnyContentItem(evaluationsContainer))
        }
        
        // Determine document title (default to Imaging Measurement Report)
        let finalDocumentTitle = documentTitle ?? MeasurementReportDocumentTitle.imagingMeasurementReport
        
        // Create the root container
        let rootContent = ContainerContentItem(
            conceptName: finalDocumentTitle,
            continuityOfContent: .separate,
            contentItems: rootContentItems
        )
        
        return SRDocument(
            sopClassUID: SRDocumentType.comprehensiveSR.sopClassUID,
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
            preliminaryFlag: preliminaryFlag,
            documentTitle: finalDocumentTitle,
            rootContent: rootContent
        )
    }
    
    // MARK: - Build Helpers
    
    /// Builds the image library content items
    private func buildImageLibraryItems() -> [AnyContentItem] {
        imageLibraryEntries.flatMap { entry -> [AnyContentItem] in
            var items: [AnyContentItem] = []
            
            let imageRef = ImageReference(
                sopClassUID: entry.sopClassUID,
                sopInstanceUID: entry.sopInstanceUID,
                frameNumbers: entry.frameNumbers
            )
            
            items.append(AnyContentItem(ImageContentItem(
                conceptName: nil,
                imageReference: imageRef,
                relationshipType: .contains
            )))
            
            // Add acquisition context as sibling items (not nested)
            if let modality = entry.modality {
                items.append(AnyContentItem(CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "121139",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Modality"
                    ),
                    conceptCode: modality,
                    relationshipType: .hasAcqContext
                )))
            }
            
            if let targetRegion = entry.targetRegion {
                items.append(AnyContentItem(CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "123014",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Target Region"
                    ),
                    conceptCode: targetRegion,
                    relationshipType: .hasAcqContext
                )))
            }
            
            if let laterality = entry.laterality {
                items.append(AnyContentItem(CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "111027",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Image Laterality"
                    ),
                    conceptCode: laterality,
                    relationshipType: .hasAcqContext
                )))
            }
            
            return items
        }
    }
    
    /// Builds the measurement group content items
    private func buildMeasurementGroupItems() -> [AnyContentItem] {
        measurementGroups.map { group in
            var groupItems: [AnyContentItem] = []
            
            // Tracking Identifier (Row 2 of TID 1501)
            groupItems.append(AnyContentItem(TextContentItem(
                conceptName: CodedConcept(
                    codeValue: "112039",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Tracking Identifier"
                ),
                textValue: group.trackingIdentifier,
                relationshipType: .hasObsContext
            )))
            
            // Tracking Unique Identifier (Row 3 of TID 1501)
            groupItems.append(AnyContentItem(UIDRefContentItem(
                conceptName: CodedConcept(
                    codeValue: "112040",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Tracking Unique Identifier"
                ),
                uidValue: group.trackingUID,
                relationshipType: .hasObsContext
            )))
            
            // Activity Session (Row 4 of TID 1501)
            if let activitySession = group.activitySession {
                groupItems.append(AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(
                        codeValue: "C67447",
                        codingSchemeDesignator: "NCIt",
                        codeMeaning: "Activity Session"
                    ),
                    textValue: activitySession,
                    relationshipType: .hasObsContext
                )))
            }
            
            // Time Point (Row 5 of TID 1501)
            if let timePoint = group.timePoint {
                groupItems.append(AnyContentItem(TextContentItem(
                    conceptName: CodedConcept(
                        codeValue: "C2348792",
                        codingSchemeDesignator: "UMLS",
                        codeMeaning: "Time Point"
                    ),
                    textValue: timePoint,
                    relationshipType: .hasObsContext
                )))
            }
            
            // Finding (Row 7 of TID 1501)
            if let finding = group.finding {
                groupItems.append(AnyContentItem(CodeContentItem(
                    conceptName: CodedConcept(
                        codeValue: "121071",
                        codingSchemeDesignator: "DCM",
                        codeMeaning: "Finding"
                    ),
                    conceptCode: finding,
                    relationshipType: .contains
                )))
                
                // Finding Site (Row 8 of TID 1501)
                if let findingSite = group.findingSite {
                    groupItems.append(AnyContentItem(CodeContentItem(
                        conceptName: CodedConcept(
                            codeValue: "363698007",
                            codingSchemeDesignator: "SCT",
                            codeMeaning: "Finding Site"
                        ),
                        conceptCode: findingSite,
                        relationshipType: .hasConceptMod
                    )))
                    
                    // Laterality (Row 9 of TID 1501)
                    if let laterality = group.laterality {
                        groupItems.append(AnyContentItem(CodeContentItem(
                            conceptName: CodedConcept(
                                codeValue: "272741003",
                                codingSchemeDesignator: "SCT",
                                codeMeaning: "Laterality"
                            ),
                            conceptCode: laterality,
                            relationshipType: .hasConceptMod
                        )))
                    }
                }
            }
            
            // Add measurements and other content from builder
            for content in group.contents {
                groupItems.append(content.toContentItem())
            }
            
            // Create the measurement group container
            return AnyContentItem(ContainerContentItem(
                conceptName: CodedConcept(
                    codeValue: "125007",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Measurement Group"
                ),
                continuityOfContent: .separate,
                contentItems: groupItems,
                relationshipType: .contains
            ))
        }
    }
    
    // MARK: - Validation
    
    /// Validation errors for Measurement Report documents
    public enum BuildError: Error, Sendable, Equatable {
        /// Measurement group is missing required tracking identifier
        case missingTrackingIdentifier
        
        /// Measurement group is missing required tracking UID
        case missingTrackingUID
        
        /// Description of the error
        public var localizedDescription: String {
            switch self {
            case .missingTrackingIdentifier:
                return "Measurement group is missing required tracking identifier"
            case .missingTrackingUID:
                return "Measurement group is missing required tracking UID"
            }
        }
    }
    
    /// Validates the builder configuration
    /// - Throws: `BuildError` if validation fails
    private func validate() throws {
        // Validate measurement groups have required tracking information
        for group in measurementGroups {
            if group.trackingIdentifier.isEmpty {
                throw BuildError.missingTrackingIdentifier
            }
            if group.trackingUID.isEmpty {
                throw BuildError.missingTrackingUID
            }
        }
    }
}

// MARK: - Supporting Types

/// Document title codes for measurement reports (CID 7021)
public enum MeasurementReportDocumentTitle {
    /// Imaging Measurement Report (126000)
    public static let imagingMeasurementReport = CodedConcept(
        codeValue: "126000",
        codingSchemeDesignator: "DCM",
        codeMeaning: "Imaging Measurement Report"
    )
    
    /// Lesion Measurement Report (126002)
    public static let lesionMeasurementReport = CodedConcept(
        codeValue: "126002",
        codingSchemeDesignator: "DCM",
        codeMeaning: "Lesion Measurement Report"
    )
    
    /// CT Perfusion Analysis Report (126003)
    public static let ctPerfusionReport = CodedConcept(
        codeValue: "126003",
        codingSchemeDesignator: "DCM",
        codeMeaning: "CT Perfusion Analysis Report"
    )
    
    /// PET Measurement Report (126010)
    public static let petMeasurementReport = CodedConcept(
        codeValue: "126010",
        codingSchemeDesignator: "DCM",
        codeMeaning: "PET Measurement Report"
    )
}

/// Entry in an image library (TID 320/1600)
public struct ImageLibraryEntry: Sendable, Equatable {
    /// SOP Class UID of the referenced image
    public let sopClassUID: String
    
    /// SOP Instance UID of the referenced image
    public let sopInstanceUID: String
    
    /// Optional specific frame numbers
    public let frameNumbers: [Int]?
    
    /// Optional modality code
    public let modality: CodedConcept?
    
    /// Optional target region code
    public let targetRegion: CodedConcept?
    
    /// Optional laterality code
    public let laterality: CodedConcept?
    
    /// Creates an image library entry
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil,
        modality: CodedConcept? = nil,
        targetRegion: CodedConcept? = nil,
        laterality: CodedConcept? = nil
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.frameNumbers = frameNumbers
        self.modality = modality
        self.targetRegion = targetRegion
        self.laterality = laterality
    }
}

/// Data for a measurement group (TID 1501)
public struct MeasurementGroupData: Sendable {
    /// Human-readable tracking identifier
    public let trackingIdentifier: String
    
    /// Unique tracking identifier (UID)
    public let trackingUID: String
    
    /// Optional activity session
    public var activitySession: String?
    
    /// Optional time point
    public var timePoint: String?
    
    /// Optional finding code
    public var finding: CodedConcept?
    
    /// Optional finding site
    public var findingSite: CodedConcept?
    
    /// Optional laterality
    public var laterality: CodedConcept?
    
    /// Content items (measurements, coordinates, etc.)
    public let contents: [MeasurementGroupContent]
    
    /// Creates a measurement group data structure
    public init(
        trackingIdentifier: String,
        trackingUID: String,
        activitySession: String? = nil,
        timePoint: String? = nil,
        finding: CodedConcept? = nil,
        findingSite: CodedConcept? = nil,
        laterality: CodedConcept? = nil,
        contents: [MeasurementGroupContent] = []
    ) {
        self.trackingIdentifier = trackingIdentifier
        self.trackingUID = trackingUID
        self.activitySession = activitySession
        self.timePoint = timePoint
        self.finding = finding
        self.findingSite = findingSite
        self.laterality = laterality
        self.contents = contents
    }
}

/// Content that can be added to a measurement group
public enum MeasurementGroupContent: Sendable {
    /// Numeric measurement
    case measurement(conceptName: CodedConcept?, value: Double, units: CodedConcept?)
    
    /// Multiple numeric values
    case measurements(conceptName: CodedConcept?, values: [Double], units: CodedConcept?)
    
    /// Qualitative evaluation
    case qualitativeEvaluation(conceptName: CodedConcept?, value: CodedConcept)
    
    /// Image reference
    case imageReference(sopClassUID: String, sopInstanceUID: String, frameNumbers: [Int]?)
    
    /// 2D spatial coordinates
    case spatialCoordinates(conceptName: CodedConcept?, graphicType: GraphicType, graphicData: [Float])
    
    /// 3D spatial coordinates
    case spatialCoordinates3D(conceptName: CodedConcept?, graphicType: GraphicType3D, graphicData: [Float], frameOfReferenceUID: String)
    
    /// Text value
    case text(conceptName: CodedConcept?, value: String)
    
    /// Converts this content to a content item
    func toContentItem() -> AnyContentItem {
        switch self {
        case .measurement(let conceptName, let value, let units):
            return AnyContentItem(NumericContentItem(
                conceptName: conceptName,
                value: value,
                units: units,
                relationshipType: .contains
            ))
            
        case .measurements(let conceptName, let values, let units):
            return AnyContentItem(NumericContentItem(
                conceptName: conceptName,
                values: values,
                units: units,
                floatingPointValues: nil,
                qualifier: nil,
                relationshipType: .contains
            ))
            
        case .qualitativeEvaluation(let conceptName, let value):
            return AnyContentItem(CodeContentItem(
                conceptName: conceptName,
                conceptCode: value,
                relationshipType: .contains
            ))
            
        case .imageReference(let sopClassUID, let sopInstanceUID, let frameNumbers):
            let imageRef = ImageReference(
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                frameNumbers: frameNumbers
            )
            return AnyContentItem(ImageContentItem(
                conceptName: nil,
                imageReference: imageRef,
                relationshipType: .inferredFrom
            ))
            
        case .spatialCoordinates(let conceptName, let graphicType, let graphicData):
            return AnyContentItem(SpatialCoordinatesContentItem(
                conceptName: conceptName,
                graphicType: graphicType,
                graphicData: graphicData,
                relationshipType: .contains
            ))
            
        case .spatialCoordinates3D(let conceptName, let graphicType, let graphicData, let frameOfReferenceUID):
            return AnyContentItem(SpatialCoordinates3DContentItem(
                conceptName: conceptName,
                graphicType: graphicType,
                graphicData: graphicData,
                frameOfReferenceUID: frameOfReferenceUID,
                relationshipType: .contains
            ))
            
        case .text(let conceptName, let value):
            return AnyContentItem(TextContentItem(
                conceptName: conceptName,
                textValue: value,
                relationshipType: .contains
            ))
        }
    }
}

// MARK: - Measurement Group Content Builder

/// Result builder for constructing measurement group content
@resultBuilder
public struct MeasurementGroupContentBuilder {
    /// Builds an empty block
    public static func buildBlock() -> [MeasurementGroupContent] {
        []
    }
    
    /// Builds a block from arrays of content
    public static func buildBlock(_ components: [MeasurementGroupContent]...) -> [MeasurementGroupContent] {
        components.flatMap { $0 }
    }
    
    /// Builds a block from arrays of content
    public static func buildArray(_ components: [[MeasurementGroupContent]]) -> [MeasurementGroupContent] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [MeasurementGroupContent]?) -> [MeasurementGroupContent] {
        component ?? []
    }
    
    public static func buildEither(first component: [MeasurementGroupContent]) -> [MeasurementGroupContent] {
        component
    }
    
    public static func buildEither(second component: [MeasurementGroupContent]) -> [MeasurementGroupContent] {
        component
    }
    
    /// Builds from a single content item
    public static func buildExpression(_ expression: MeasurementGroupContent) -> [MeasurementGroupContent] {
        [expression]
    }
}

// MARK: - Measurement Group Content Helpers

/// Helper functions for creating measurement group content
public enum MeasurementGroupContentHelper {
    /// Creates a numeric measurement
    /// - Parameters:
    ///   - conceptName: The concept name for this measurement
    ///   - value: The numeric value
    ///   - units: The measurement units
    /// - Returns: Measurement group content
    public static func measurement(
        conceptName: CodedConcept? = nil,
        value: Double,
        units: CodedConcept? = nil
    ) -> MeasurementGroupContent {
        .measurement(conceptName: conceptName, value: value, units: units)
    }
    
    /// Creates a length measurement in millimeters
    /// - Parameters:
    ///   - value: The measurement value in millimeters
    /// - Returns: Measurement group content
    public static func lengthMM(value: Double) -> MeasurementGroupContent {
        .measurement(
            conceptName: CodedConcept(
                codeValue: "410668003",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Length"
            ),
            value: value,
            units: UCUMUnit.millimeter.concept
        )
    }
    
    /// Creates a long axis measurement in millimeters
    /// - Parameter value: The measurement value in millimeters
    /// - Returns: Measurement group content
    public static func longAxisMM(value: Double) -> MeasurementGroupContent {
        .measurement(
            conceptName: CodedConcept(
                codeValue: "103339001",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Long Axis"
            ),
            value: value,
            units: UCUMUnit.millimeter.concept
        )
    }
    
    /// Creates a short axis measurement in millimeters
    /// - Parameter value: The measurement value in millimeters
    /// - Returns: Measurement group content
    public static func shortAxisMM(value: Double) -> MeasurementGroupContent {
        .measurement(
            conceptName: CodedConcept(
                codeValue: "103340004",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Short Axis"
            ),
            value: value,
            units: UCUMUnit.millimeter.concept
        )
    }
    
    /// Creates an area measurement in square millimeters
    /// - Parameter value: The measurement value in mm²
    /// - Returns: Measurement group content
    public static func areaMM2(value: Double) -> MeasurementGroupContent {
        .measurement(
            conceptName: CodedConcept(
                codeValue: "42798000",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Area"
            ),
            value: value,
            units: UCUMUnit.squareMillimeter.concept
        )
    }
    
    /// Creates a volume measurement in cubic millimeters
    /// - Parameter value: The measurement value in mm³
    /// - Returns: Measurement group content
    public static func volumeMM3(value: Double) -> MeasurementGroupContent {
        .measurement(
            conceptName: CodedConcept(
                codeValue: "118565006",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Volume"
            ),
            value: value,
            units: UCUMUnit.cubicMillimeter.concept
        )
    }
    
    /// Creates an image reference
    /// - Parameters:
    ///   - sopClassUID: The SOP Class UID
    ///   - sopInstanceUID: The SOP Instance UID
    ///   - frameNumbers: Optional frame numbers
    /// - Returns: Measurement group content
    public static func imageReference(
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil
    ) -> MeasurementGroupContent {
        .imageReference(sopClassUID: sopClassUID, sopInstanceUID: sopInstanceUID, frameNumbers: frameNumbers)
    }
    
    /// Creates 2D spatial coordinates
    /// - Parameters:
    ///   - graphicType: The type of graphic
    ///   - graphicData: The coordinate data
    /// - Returns: Measurement group content
    public static func coordinates(
        graphicType: GraphicType,
        graphicData: [Float]
    ) -> MeasurementGroupContent {
        .spatialCoordinates(conceptName: nil, graphicType: graphicType, graphicData: graphicData)
    }
}
