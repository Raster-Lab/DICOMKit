/// DICOMCode - DICOM Controlled Terminology (DCM) codes
///
/// Provides comprehensive support for DICOM Controlled Terminology codes
/// as defined in PS3.16. These codes are used extensively in Structured Reporting.
///
/// Reference: PS3.16 - Content Mapping Resource
/// Reference: PS3.16 Annex D - DICOM Controlled Terminology Definitions

/// A DICOM Controlled Terminology (DCM) code
///
/// DCM codes are numeric identifiers defined by the DICOM standard for
/// encoding concepts used in structured reporting and other DICOM contexts.
///
/// Example:
/// ```swift
/// let finding = DICOMCode.finding
/// print(finding.concept.description) // "(121071, DCM, "Finding")"
/// ```
public struct DICOMCode: Sendable, Equatable, Hashable {
    /// The coded concept representation
    public let concept: CodedConcept
    
    /// The DCM code value
    public var codeValue: String { concept.codeValue }
    
    /// The code meaning (description)
    public var codeMeaning: String { concept.codeMeaning }
    
    /// Creates a DCM code from a code value and meaning
    /// - Parameters:
    ///   - codeValue: The DCM code value (e.g., "121071")
    ///   - codeMeaning: The code meaning
    public init(codeValue: String, codeMeaning: String) {
        self.concept = CodedConcept(
            codeValue: codeValue,
            scheme: .DCM,
            codeMeaning: codeMeaning
        )
    }
    
    /// Creates a DCM code from an existing CodedConcept
    /// - Parameter concept: A coded concept using DCM designator
    /// - Returns: nil if the concept is not a DCM code
    public init?(concept: CodedConcept) {
        guard concept.isDICOMControlled else { return nil }
        self.concept = concept
    }
}

// MARK: - CustomStringConvertible

extension DICOMCode: CustomStringConvertible {
    public var description: String {
        concept.description
    }
}

// MARK: - SR Document Concepts

extension DICOMCode {
    // MARK: - Document Structure
    
    /// Report (121060)
    public static let report = DICOMCode(codeValue: "121060", codeMeaning: "Report")
    
    /// Finding (121071)
    public static let finding = DICOMCode(codeValue: "121071", codeMeaning: "Finding")
    
    /// Measurement (125007)
    public static let measurement = DICOMCode(codeValue: "125007", codeMeaning: "Measurement")
    
    /// Measurement Group (125007)
    public static let measurementGroup = DICOMCode(codeValue: "125007", codeMeaning: "Measurement Group")
    
    /// Procedure Reported (121058)
    public static let procedureReported = DICOMCode(codeValue: "121058", codeMeaning: "Procedure Reported")
    
    /// Imaging Measurements (126010)
    public static let imagingMeasurements = DICOMCode(codeValue: "126010", codeMeaning: "Imaging Measurements")
    
    /// Derived Imaging Measurements (126011)
    public static let derivedImagingMeasurements = DICOMCode(codeValue: "126011", codeMeaning: "Derived Imaging Measurements")
    
    /// Summary (121070)
    public static let summary = DICOMCode(codeValue: "121070", codeMeaning: "Summary")
    
    /// Conclusion (121076)
    public static let conclusion = DICOMCode(codeValue: "121076", codeMeaning: "Conclusion")
    
    /// Impression (121077)
    public static let impression = DICOMCode(codeValue: "121077", codeMeaning: "Impression")
    
    /// Recommendation (121074)
    public static let recommendation = DICOMCode(codeValue: "121074", codeMeaning: "Recommendation")
    
    /// Addendum (121078)
    public static let addendum = DICOMCode(codeValue: "121078", codeMeaning: "Addendum")
    
    /// Request (121062)
    public static let request = DICOMCode(codeValue: "121062", codeMeaning: "Request")
    
    /// Clinical History (121060)
    public static let clinicalHistory = DICOMCode(codeValue: "121060", codeMeaning: "Clinical History")
    
    /// Current Procedure Descriptions (121064)
    public static let currentProcedureDescriptions = DICOMCode(codeValue: "121064", codeMeaning: "Current Procedure Descriptions")
    
    /// Comparison Study (121068)
    public static let comparisonStudy = DICOMCode(codeValue: "121068", codeMeaning: "Comparison Study")
    
    // MARK: - Observer Context
    
    /// Observer Type (121005)
    public static let observerType = DICOMCode(codeValue: "121005", codeMeaning: "Observer Type")
    
    /// Person Observer Name (121008)
    public static let personObserverName = DICOMCode(codeValue: "121008", codeMeaning: "Person Observer Name")
    
    /// Device Observer UID (121012)
    public static let deviceObserverUID = DICOMCode(codeValue: "121012", codeMeaning: "Device Observer UID")
    
    /// Device Observer Name (121013)
    public static let deviceObserverName = DICOMCode(codeValue: "121013", codeMeaning: "Device Observer Name")
    
    /// Device Observer Manufacturer (121014)
    public static let deviceObserverManufacturer = DICOMCode(codeValue: "121014", codeMeaning: "Device Observer Manufacturer")
    
    /// Device Observer Model Name (121015)
    public static let deviceObserverModelName = DICOMCode(codeValue: "121015", codeMeaning: "Device Observer Model Name")
    
    /// Device Observer Serial Number (121016)
    public static let deviceObserverSerialNumber = DICOMCode(codeValue: "121016", codeMeaning: "Device Observer Serial Number")
    
    /// Person (121006)
    public static let person = DICOMCode(codeValue: "121006", codeMeaning: "Person")
    
    /// Device (121007)
    public static let device = DICOMCode(codeValue: "121007", codeMeaning: "Device")
    
    // MARK: - Subject Context
    
    /// Subject Name (121029)
    public static let subjectName = DICOMCode(codeValue: "121029", codeMeaning: "Subject Name")
    
    /// Subject ID (121030)
    public static let subjectID = DICOMCode(codeValue: "121030", codeMeaning: "Subject ID")
    
    /// Subject Birth Date (121031)
    public static let subjectBirthDate = DICOMCode(codeValue: "121031", codeMeaning: "Subject Birth Date")
    
    /// Subject Sex (121032)
    public static let subjectSex = DICOMCode(codeValue: "121032", codeMeaning: "Subject Sex")
    
    /// Subject Species (121024)
    public static let subjectSpecies = DICOMCode(codeValue: "121024", codeMeaning: "Subject Species")
    
    /// Subject Breed (121025)
    public static let subjectBreed = DICOMCode(codeValue: "121025", codeMeaning: "Subject Breed")
    
    // MARK: - Language Context
    
    /// Language of Content Item and Descendants (121049)
    public static let languageOfContentItemAndDescendants = DICOMCode(codeValue: "121049", codeMeaning: "Language of Content Item and Descendants")
    
    /// Country of Language (121046)
    public static let countryOfLanguage = DICOMCode(codeValue: "121046", codeMeaning: "Country of Language")
}

// MARK: - Measurement Concepts

extension DICOMCode {
    // MARK: - Measurement Types
    
    /// Diameter (131190)
    public static let diameter = DICOMCode(codeValue: "131190", codeMeaning: "Diameter")
    
    /// Long Axis (103340)
    public static let longAxis = DICOMCode(codeValue: "103340", codeMeaning: "Long Axis")
    
    /// Short Axis (103339)
    public static let shortAxis = DICOMCode(codeValue: "103339", codeMeaning: "Short Axis")
    
    /// Perpendicular Axis (103338)
    public static let perpendicularAxis = DICOMCode(codeValue: "103338", codeMeaning: "Perpendicular Axis")
    
    /// Area (131184)
    public static let area = DICOMCode(codeValue: "131184", codeMeaning: "Area")
    
    /// Volume (118565)
    public static let volume = DICOMCode(codeValue: "118565", codeMeaning: "Volume")
    
    /// Circumference (131183)
    public static let circumference = DICOMCode(codeValue: "131183", codeMeaning: "Circumference")
    
    /// Perimeter (131189)
    public static let perimeter = DICOMCode(codeValue: "131189", codeMeaning: "Perimeter")
    
    /// Length (118558)
    public static let length = DICOMCode(codeValue: "118558", codeMeaning: "Length")
    
    /// Width (118559)
    public static let width = DICOMCode(codeValue: "118559", codeMeaning: "Width")
    
    /// Height (121211)
    public static let height = DICOMCode(codeValue: "121211", codeMeaning: "Height")
    
    /// Depth (121212)
    public static let depth = DICOMCode(codeValue: "121212", codeMeaning: "Depth")
    
    // MARK: - Image Measurements
    
    /// Mean Value (121401)
    public static let meanValue = DICOMCode(codeValue: "121401", codeMeaning: "Mean Value")
    
    /// Maximum Value (121403)
    public static let maximumValue = DICOMCode(codeValue: "121403", codeMeaning: "Maximum Value")
    
    /// Minimum Value (121402)
    public static let minimumValue = DICOMCode(codeValue: "121402", codeMeaning: "Minimum Value")
    
    /// Standard Deviation (121404)
    public static let standardDeviation = DICOMCode(codeValue: "121404", codeMeaning: "Standard Deviation")
    
    /// Median (121405)
    public static let median = DICOMCode(codeValue: "121405", codeMeaning: "Median")
    
    /// Mode (121406)
    public static let mode = DICOMCode(codeValue: "121406", codeMeaning: "Mode")
    
    /// Count (121407)
    public static let count = DICOMCode(codeValue: "121407", codeMeaning: "Count")
    
    /// Sum (121408)
    public static let sum = DICOMCode(codeValue: "121408", codeMeaning: "Sum")
    
    /// Attenuation Coefficient (112031)
    public static let attenuationCoefficient = DICOMCode(codeValue: "112031", codeMeaning: "Attenuation Coefficient")
    
    // MARK: - Measurement Properties
    
    /// Source of Measurement (121112)
    public static let sourceOfMeasurement = DICOMCode(codeValue: "121112", codeMeaning: "Source of Measurement")
    
    /// Derivation (121401)
    public static let derivation = DICOMCode(codeValue: "121401", codeMeaning: "Derivation")
    
    /// Derivation Parameter (121413)
    public static let derivationParameter = DICOMCode(codeValue: "121413", codeMeaning: "Derivation Parameter")
    
    /// Image Region (130488)
    public static let imageRegion = DICOMCode(codeValue: "130488", codeMeaning: "Image Region")
    
    /// Tracking Identifier (112039)
    public static let trackingIdentifier = DICOMCode(codeValue: "112039", codeMeaning: "Tracking Identifier")
    
    /// Tracking Unique Identifier (112040)
    public static let trackingUniqueIdentifier = DICOMCode(codeValue: "112040", codeMeaning: "Tracking Unique Identifier")
}

// MARK: - Reference Concepts

extension DICOMCode {
    /// Image Reference (121191)
    public static let imageReference = DICOMCode(codeValue: "121191", codeMeaning: "Image Reference")
    
    /// Composite Reference (121190)
    public static let compositeReference = DICOMCode(codeValue: "121190", codeMeaning: "Composite Reference")
    
    /// Waveform Reference (121192)
    public static let waveformReference = DICOMCode(codeValue: "121192", codeMeaning: "Waveform Reference")
    
    /// Source Image for Segmentation (121324)
    public static let sourceImageForSegmentation = DICOMCode(codeValue: "121324", codeMeaning: "Source Image for Segmentation")
    
    /// Source Series for Segmentation (121232)
    public static let sourceSeriesForSegmentation = DICOMCode(codeValue: "121232", codeMeaning: "Source Series for Segmentation")
}

// MARK: - Qualitative Evaluation

extension DICOMCode {
    // MARK: - Assessment Types
    
    /// Qualitative Evaluation (C0034375)
    public static let qualitativeEvaluation = DICOMCode(codeValue: "C0034375", codeMeaning: "Qualitative Evaluation")
    
    /// Assessment (121073)
    public static let assessment = DICOMCode(codeValue: "121073", codeMeaning: "Assessment")
    
    /// Probability of Cancer (121208)
    public static let probabilityOfCancer = DICOMCode(codeValue: "121208", codeMeaning: "Probability of Cancer")
    
    /// Abnormality (121072)
    public static let abnormality = DICOMCode(codeValue: "121072", codeMeaning: "Abnormality")
    
    // MARK: - Change Assessment
    
    /// No Change (121056)
    public static let noChange = DICOMCode(codeValue: "121056", codeMeaning: "No Change")
    
    /// Progression (121057)
    public static let progression = DICOMCode(codeValue: "121057", codeMeaning: "Progression")
    
    /// Improvement (121055)
    public static let improvement = DICOMCode(codeValue: "121055", codeMeaning: "Improvement")
}

// MARK: - Relationship Type Codes

extension DICOMCode {
    /// Contains (121311)
    public static let contains = DICOMCode(codeValue: "121311", codeMeaning: "Contains")
    
    /// Has Properties (121309)
    public static let hasProperties = DICOMCode(codeValue: "121309", codeMeaning: "Has Properties")
    
    /// Has Observation Context (121310)
    public static let hasObservationContext = DICOMCode(codeValue: "121310", codeMeaning: "Has Observation Context")
    
    /// Has Acquisition Context (121312)
    public static let hasAcquisitionContext = DICOMCode(codeValue: "121312", codeMeaning: "Has Acquisition Context")
    
    /// Inferred From (121307)
    public static let inferredFrom = DICOMCode(codeValue: "121307", codeMeaning: "Inferred From")
    
    /// Selected From (121308)
    public static let selectedFrom = DICOMCode(codeValue: "121308", codeMeaning: "Selected From")
    
    /// Has Concept Modifier (121313)
    public static let hasConceptModifier = DICOMCode(codeValue: "121313", codeMeaning: "Has Concept Modifier")
}

// MARK: - SR Document Title Codes

extension DICOMCode {
    /// Basic Diagnostic Imaging Report (126000)
    public static let basicDiagnosticImagingReport = DICOMCode(codeValue: "126000", codeMeaning: "Basic Diagnostic Imaging Report")
    
    /// Comprehensive SR (121181)
    public static let comprehensiveSR = DICOMCode(codeValue: "121181", codeMeaning: "Comprehensive SR")
    
    /// Mammography CAD Report (111001)
    public static let mammographyCADReport = DICOMCode(codeValue: "111001", codeMeaning: "Mammography CAD Report")
    
    /// Chest CAD Report (111002)
    public static let chestCADReport = DICOMCode(codeValue: "111002", codeMeaning: "Chest CAD Report")
    
    /// Colon CAD Report (111003)
    public static let colonCADReport = DICOMCode(codeValue: "111003", codeMeaning: "Colon CAD Report")
    
    /// Procedure Log (121184)
    public static let procedureLog = DICOMCode(codeValue: "121184", codeMeaning: "Procedure Log")
    
    /// X-Ray Radiation Dose Report (113701)
    public static let xRayRadiationDoseReport = DICOMCode(codeValue: "113701", codeMeaning: "X-Ray Radiation Dose Report")
    
    /// CT Dose Length Product Total (113813)
    public static let ctDoseLengthProductTotal = DICOMCode(codeValue: "113813", codeMeaning: "CT Dose Length Product Total")
    
    /// Measurement Report (126000)
    public static let measurementReport = DICOMCode(codeValue: "126000", codeMeaning: "Measurement Report")
}

// MARK: - Activity Codes

extension DICOMCode {
    /// Study (110180)
    public static let study = DICOMCode(codeValue: "110180", codeMeaning: "Study")
    
    /// Series (110181)
    public static let series = DICOMCode(codeValue: "110181", codeMeaning: "Series")
    
    /// Instance (110182)
    public static let instance = DICOMCode(codeValue: "110182", codeMeaning: "Instance")
    
    /// Image (121192)
    public static let image = DICOMCode(codeValue: "121192", codeMeaning: "Image")
    
    /// Composite Object (121193)
    public static let compositeObject = DICOMCode(codeValue: "121193", codeMeaning: "Composite Object")
}

// MARK: - CodedConcept Convenience

extension CodedConcept {
    /// Create a CodedConcept from a DICOMCode
    /// - Parameter dicomCode: The DCM code
    /// - Returns: A coded concept with DCM designator
    public init(dicomCode: DICOMCode) {
        self = dicomCode.concept
    }
    
    /// Attempt to convert this coded concept to a DICOMCode
    /// - Returns: A DICOMCode if this is a DCM concept, nil otherwise
    public var asDICOMCode: DICOMCode? {
        DICOMCode(concept: self)
    }
}
