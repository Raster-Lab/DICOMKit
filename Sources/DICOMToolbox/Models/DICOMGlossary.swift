import Foundation

/// A single DICOM glossary term with its definition and related standard reference
public struct GlossaryTerm: Identifiable, Sendable {
    public let id: String
    /// The term or acronym
    public let term: String
    /// A brief, plain-language definition
    public let definition: String
    /// DICOM standard section reference (e.g., "PS3.3 §C.7.1")
    public let standardReference: String?
    /// Related terms
    public let relatedTerms: [String]

    public init(
        id: String? = nil,
        term: String,
        definition: String,
        standardReference: String? = nil,
        relatedTerms: [String] = []
    ) {
        self.id = id ?? term.lowercased().replacingOccurrences(of: " ", with: "-")
        self.term = term
        self.definition = definition
        self.standardReference = standardReference
        self.relatedTerms = relatedTerms
    }
}

/// Searchable DICOM glossary database
public enum DICOMGlossary {
    /// All glossary terms
    public static let allTerms: [GlossaryTerm] = [
        GlossaryTerm(
            term: "AE Title",
            definition: "Application Entity Title – a unique identifier (max 16 ASCII characters) for a DICOM application on a network. Used to identify both the calling (SCU) and called (SCP) applications.",
            standardReference: "PS3.8 §9.3.2",
            relatedTerms: ["SCU", "SCP", "Association"]
        ),
        GlossaryTerm(
            term: "Association",
            definition: "A logical connection established between two DICOM Application Entities for communication. An association must be negotiated before any DICOM network operations can be performed.",
            standardReference: "PS3.7 §7",
            relatedTerms: ["AE Title", "SCU", "SCP"]
        ),
        GlossaryTerm(
            term: "C-ECHO",
            definition: "A DICOM verification service that tests network connectivity between two DICOM nodes. Similar to a network 'ping' but at the DICOM application level.",
            standardReference: "PS3.7 §9.1.5",
            relatedTerms: ["Association", "SCP", "SCU"]
        ),
        GlossaryTerm(
            term: "C-FIND",
            definition: "A DICOM query service used to search for patients, studies, series, or instances on a remote PACS. Returns matching records based on search criteria.",
            standardReference: "PS3.4 §C.4",
            relatedTerms: ["C-MOVE", "C-GET", "Query Level"]
        ),
        GlossaryTerm(
            term: "C-GET",
            definition: "A DICOM retrieve service where the SCP sends matching instances directly back over the existing association. Does not require the SCU to run its own SCP.",
            standardReference: "PS3.4 §C.4",
            relatedTerms: ["C-MOVE", "C-FIND", "C-STORE"]
        ),
        GlossaryTerm(
            term: "C-MOVE",
            definition: "A DICOM retrieve service where the SCP initiates a new association to send matching instances. Requires the requesting SCU to also be running an SCP to receive data.",
            standardReference: "PS3.4 §C.4",
            relatedTerms: ["C-GET", "C-FIND", "C-STORE"]
        ),
        GlossaryTerm(
            term: "C-STORE",
            definition: "A DICOM storage service used to transmit SOP Instances (e.g., images) from one node to another.",
            standardReference: "PS3.4 §B",
            relatedTerms: ["SOP Instance", "Transfer Syntax"]
        ),
        GlossaryTerm(
            term: "DICOM",
            definition: "Digital Imaging and Communications in Medicine – the international standard for medical imaging data exchange. Defines file formats, network protocols, and information models.",
            standardReference: "PS3.1",
            relatedTerms: ["PACS", "SOP Class"]
        ),
        GlossaryTerm(
            term: "DICOMDIR",
            definition: "A directory file that provides an index of DICOM files stored on removable media. Contains references to patients, studies, series, and instances.",
            standardReference: "PS3.10 §8",
            relatedTerms: ["Media Storage", "SOP Instance"]
        ),
        GlossaryTerm(
            term: "IOD",
            definition: "Information Object Definition – a specification that defines the attributes (data elements) that compose a particular type of DICOM object, such as a CT Image or Structured Report.",
            standardReference: "PS3.3 §A",
            relatedTerms: ["SOP Class", "Module", "Tag"]
        ),
        GlossaryTerm(
            term: "Module",
            definition: "A logical grouping of related DICOM attributes within an IOD. For example, the Patient Module contains Patient Name, Patient ID, and Birth Date.",
            standardReference: "PS3.3 §C",
            relatedTerms: ["IOD", "Tag", "VR"]
        ),
        GlossaryTerm(
            term: "MPPS",
            definition: "Modality Performed Procedure Step – a DICOM service that allows modalities to report the status of procedures being performed, including what was actually acquired.",
            standardReference: "PS3.4 §F.7",
            relatedTerms: ["MWL", "SCP"]
        ),
        GlossaryTerm(
            term: "MWL",
            definition: "Modality Worklist – a DICOM service that provides scheduled procedure information to modalities. Eliminates manual entry of patient demographics at the scanner.",
            standardReference: "PS3.4 §K",
            relatedTerms: ["MPPS", "C-FIND"]
        ),
        GlossaryTerm(
            term: "PACS",
            definition: "Picture Archiving and Communication System – a medical imaging system that stores, retrieves, distributes, and displays digital medical images using DICOM.",
            standardReference: nil,
            relatedTerms: ["DICOM", "AE Title", "C-STORE"]
        ),
        GlossaryTerm(
            term: "Patient ID",
            definition: "A unique identifier assigned to a patient within a healthcare facility. Stored in DICOM tag (0010,0020).",
            standardReference: "PS3.3 §C.2.2",
            relatedTerms: ["Tag", "Patient Module"]
        ),
        GlossaryTerm(
            term: "Pixel Data",
            definition: "The actual image data stored in a DICOM file, contained in tag (7FE0,0010). Can be uncompressed or encoded with various transfer syntaxes.",
            standardReference: "PS3.5 §8",
            relatedTerms: ["Transfer Syntax", "Tag", "VR"]
        ),
        GlossaryTerm(
            term: "Private Tag",
            definition: "A vendor-specific DICOM data element with an odd group number. Used to store proprietary information not defined in the DICOM standard.",
            standardReference: "PS3.5 §7.8",
            relatedTerms: ["Tag", "VR"]
        ),
        GlossaryTerm(
            term: "Query Level",
            definition: "The hierarchical level at which a DICOM query operates: PATIENT, STUDY, SERIES, or IMAGE (instance). Determines what type of records are returned.",
            standardReference: "PS3.4 §C.4.1",
            relatedTerms: ["C-FIND", "Study", "Series"]
        ),
        GlossaryTerm(
            term: "SCP",
            definition: "Service Class Provider – a DICOM application that provides services (e.g., a PACS server that accepts stored images or responds to queries).",
            standardReference: "PS3.7 §6",
            relatedTerms: ["SCU", "AE Title", "Association"]
        ),
        GlossaryTerm(
            term: "SCU",
            definition: "Service Class User – a DICOM application that requests services (e.g., a workstation that sends images or performs queries).",
            standardReference: "PS3.7 §6",
            relatedTerms: ["SCP", "AE Title", "Association"]
        ),
        GlossaryTerm(
            term: "Series",
            definition: "A collection of related DICOM instances within a study, typically representing a single acquisition (e.g., one MRI sequence or one set of CT slices).",
            standardReference: "PS3.3 §C.7.3",
            relatedTerms: ["Study", "SOP Instance", "Query Level"]
        ),
        GlossaryTerm(
            term: "SOP Class",
            definition: "Service-Object Pair Class – combines an IOD with a DICOM service (e.g., CT Image Storage SOP Class pairs a CT IOD with the C-STORE service).",
            standardReference: "PS3.4 §B.5",
            relatedTerms: ["IOD", "SOP Instance", "Transfer Syntax"]
        ),
        GlossaryTerm(
            term: "SOP Instance",
            definition: "A specific instance of a SOP Class, identified by a globally unique SOP Instance UID. Typically corresponds to one DICOM file (e.g., one CT slice).",
            standardReference: "PS3.3 §7",
            relatedTerms: ["SOP Class", "UID", "Study"]
        ),
        GlossaryTerm(
            term: "Study",
            definition: "A collection of DICOM series generated during a single examination visit. Identified by a unique Study Instance UID.",
            standardReference: "PS3.3 §C.7.2",
            relatedTerms: ["Series", "SOP Instance", "Query Level"]
        ),
        GlossaryTerm(
            term: "Tag",
            definition: "A unique identifier for a DICOM data element, expressed as a group and element number pair (e.g., (0010,0010) for Patient Name). Tags define what data is stored.",
            standardReference: "PS3.6",
            relatedTerms: ["VR", "IOD", "Module"]
        ),
        GlossaryTerm(
            term: "Transfer Syntax",
            definition: "Defines how DICOM data is encoded for storage or transmission. Specifies byte ordering (endianness), VR encoding (explicit/implicit), and pixel data compression.",
            standardReference: "PS3.5 §10",
            relatedTerms: ["Pixel Data", "VR", "UID"]
        ),
        GlossaryTerm(
            term: "UID",
            definition: "Unique Identifier – a globally unique string (based on OID notation) used to identify DICOM entities such as studies, series, instances, and transfer syntaxes.",
            standardReference: "PS3.5 §9",
            relatedTerms: ["SOP Instance", "Study", "Transfer Syntax"]
        ),
        GlossaryTerm(
            term: "VR",
            definition: "Value Representation – describes the data type of a DICOM attribute (e.g., DA for Date, PN for Person Name, UI for UID, OB for Other Byte).",
            standardReference: "PS3.5 §6.2",
            relatedTerms: ["Tag", "Transfer Syntax"]
        ),
        GlossaryTerm(
            term: "WADO",
            definition: "Web Access to DICOM Objects – a RESTful interface for retrieving DICOM objects via HTTP. Part of DICOMweb, the web-based alternative to traditional DICOM networking.",
            standardReference: "PS3.18",
            relatedTerms: ["DICOMweb", "STOW-RS", "QIDO-RS"]
        ),
        GlossaryTerm(
            term: "Window Center/Width",
            definition: "Display parameters that control how pixel values are mapped to grayscale. Window Center defines the midpoint and Window Width defines the range of values displayed.",
            standardReference: "PS3.3 §C.11.2",
            relatedTerms: ["Pixel Data", "VOI LUT"]
        ),
    ]

    /// Searches glossary terms by query string
    public static func search(_ query: String) -> [GlossaryTerm] {
        guard !query.isEmpty else { return allTerms }
        let lowered = query.lowercased()
        return allTerms.filter { term in
            term.term.lowercased().contains(lowered) ||
            term.definition.lowercased().contains(lowered) ||
            term.relatedTerms.contains { $0.lowercased().contains(lowered) }
        }
    }

    /// Looks up a glossary term by its exact name (case-insensitive)
    public static func term(named name: String) -> GlossaryTerm? {
        allTerms.first { $0.term.caseInsensitiveCompare(name) == .orderedSame }
    }
}
