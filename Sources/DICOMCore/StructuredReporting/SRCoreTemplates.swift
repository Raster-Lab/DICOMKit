/// DICOM SR Core Templates
///
/// Implementations of core DICOM SR Templates from PS3.16.
/// These templates define common patterns used in structured reports.
///
/// Reference: PS3.16 Annex A - DCMR Context Groups and Templates

import Foundation

// MARK: - TID 300: Measurement

/// TID 300 - Measurement Template
///
/// Provides a generic container for numeric measurements with associated
/// concept, derivation method, and reference to source data.
///
/// Reference: PS3.16 TID 300
public struct TID300Measurement: SRTemplate {
    public static let identifier = TemplateIdentifier.measurement
    public static let displayName = "Measurement"
    public static let templateDescription = "Generic measurement with value, units, and derivation"
    public static let rootValueType: ContentItemValueType = .num
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: The numeric measurement itself (root)
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .any, // Concept from calling template
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Modifier for measurement method
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "370129005",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Measurement Method"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 6147),
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 3: Derivation (how the measurement was derived)
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121401",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Derivation"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 7464),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Finding Site (anatomical location)
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "363698007",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Finding Site"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 4021),
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 5: Laterality
        TemplateRow(
            rowID: "5",
            nestingLevel: 2,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "272741003",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Laterality"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 244),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifPresent(concept: CodedConcept(
                codeValue: "363698007",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Finding Site"
            ))
        ),
        
        // Row 6: Image reference (source of measurement)
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 7: Spatial coordinates (region of measurement)
        TemplateRow(
            rowID: "7",
            nestingLevel: 2,
            relationshipType: .selectedFrom,
            valueType: .scoord,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifPresent(concept: CodedConcept(
                codeValue: "121191",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Referenced Image"
            ))
        )
    ]
}

// MARK: - TID 320: Image Library Entry

/// TID 320 - Image Library Entry Template
///
/// Describes an image included in an image library for reference.
///
/// Reference: PS3.16 TID 320
public struct TID320ImageLibraryEntry: SRTemplate {
    public static let identifier = TemplateIdentifier.imageLibraryEntry
    public static let displayName = "Image Library Entry"
    public static let templateDescription = "Entry in an image library referencing a DICOM image"
    public static let rootValueType: ContentItemValueType = .image
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Image reference (root)
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Modality
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasAcqContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121139",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Modality"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 29),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Target Region
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasAcqContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "123014",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Target Region"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 4031),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Image Laterality
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .hasAcqContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "111027",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Image Laterality"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 244),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
    ]
}

// MARK: - TID 1001: Observation Context

/// TID 1001 - Observation Context Template
///
/// Provides context about when and where an observation was made.
///
/// Reference: PS3.16 TID 1001
public struct TID1001ObservationContext: SRTemplate {
    public static let identifier = TemplateIdentifier.observationContext
    public static let displayName = "Observation Context"
    public static let templateDescription = "Context for observations including observer and subject"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Observer Context (included template)
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .container,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .oneOrMore,
            includedTemplate: .observerContext
        ),
        
        // Row 2: Observation DateTime
        TemplateRow(
            rowID: "2",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .datetime,
            conceptName: .exact(CodedConcept(
                codeValue: "111060",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Study Date"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Subject Class
        TemplateRow(
            rowID: "3",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121024",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Subject Class"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 271),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Subject UID
        TemplateRow(
            rowID: "4",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "121030",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Subject UID"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
    ]
}

// MARK: - TID 1002: Observer Context

/// TID 1002 - Observer Context Template
///
/// Identifies the observer (person or device) who made the observation.
///
/// Reference: PS3.16 TID 1002
public struct TID1002ObserverContext: SRTemplate {
    public static let identifier = TemplateIdentifier.observerContext
    public static let displayName = "Observer Context"
    public static let templateDescription = "Identifies the observer (person or device)"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = false
    
    public static let rows: [TemplateRow] = [
        // Row 1: Observer Type
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121005",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Observer Type"
            )),
            valueConstraint: .oneOfCodes([
                CodedConcept(codeValue: "121006", codingSchemeDesignator: "DCM", codeMeaning: "Person"),
                CodedConcept(codeValue: "121007", codingSchemeDesignator: "DCM", codeMeaning: "Device")
            ]),
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Person Observer Name (for Person)
        TemplateRow(
            rowID: "2",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .pname,
            conceptName: .exact(CodedConcept(
                codeValue: "121008",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Person Observer Name"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatoryConditional,
            cardinality: .one,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121006", codingSchemeDesignator: "DCM", codeMeaning: "Person")
            )
        ),
        
        // Row 3: Person Observer Organization
        TemplateRow(
            rowID: "3",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "121009",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Person Observer's Organization Name"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121006", codingSchemeDesignator: "DCM", codeMeaning: "Person")
            )
        ),
        
        // Row 4: Person Observer Role
        TemplateRow(
            rowID: "4",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121010",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Person Observer's Role in this Organization"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 7452),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121006", codingSchemeDesignator: "DCM", codeMeaning: "Person")
            )
        ),
        
        // Row 5: Device Observer UID (for Device)
        TemplateRow(
            rowID: "5",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "121012",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Device Observer UID"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatoryConditional,
            cardinality: .one,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121007", codingSchemeDesignator: "DCM", codeMeaning: "Device")
            )
        ),
        
        // Row 6: Device Observer Name
        TemplateRow(
            rowID: "6",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "121013",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Device Observer Name"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121007", codingSchemeDesignator: "DCM", codeMeaning: "Device")
            )
        ),
        
        // Row 7: Device Observer Manufacturer
        TemplateRow(
            rowID: "7",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "121014",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Device Observer Manufacturer"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121007", codingSchemeDesignator: "DCM", codeMeaning: "Device")
            )
        ),
        
        // Row 8: Device Observer Model Name
        TemplateRow(
            rowID: "8",
            nestingLevel: 0,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "121015",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Device Observer Model Name"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            condition: .ifEquals(
                concept: CodedConcept(codeValue: "121005", codingSchemeDesignator: "DCM", codeMeaning: "Observer Type"),
                value: CodedConcept(codeValue: "121007", codingSchemeDesignator: "DCM", codeMeaning: "Device")
            )
        )
    ]
}

// MARK: - TID 1204: Language of Content

/// TID 1204 - Language of Content Item and Descendants Template
///
/// Specifies the language used in text content items.
///
/// Reference: PS3.16 TID 1204
public struct TID1204LanguageOfContent: SRTemplate {
    public static let identifier = TemplateIdentifier.languageOfContent
    public static let displayName = "Language of Content"
    public static let templateDescription = "Specifies the language used in content items"
    public static let rootValueType: ContentItemValueType = .code
    public static let isExtensible = false
    
    public static let rows: [TemplateRow] = [
        // Row 1: Language
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121049",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Language of Content Item and Descendants"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 5000),
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Country of Language
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121046",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Country of Language"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 5001),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
    ]
}
