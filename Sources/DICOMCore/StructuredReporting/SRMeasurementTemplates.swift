/// DICOM SR Measurement Templates
///
/// Implementations of DICOM SR Templates for measurements and ROI analysis.
///
/// Reference: PS3.16 Annex A - DCMR Context Groups and Templates

import Foundation

// MARK: - TID 1400: Linear Measurements

/// TID 1400 - Linear Measurements Template
///
/// Container for one or more linear measurements (distances, lengths).
///
/// Reference: PS3.16 TID 1400
public struct TID1400LinearMeasurements: SRTemplate {
    public static let identifier = TemplateIdentifier.linearMeasurements
    public static let displayName = "Linear Measurements"
    public static let templateDescription = "Container for linear measurements like length and distance"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root (implicit)
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Tracking Identifier
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "112039",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Tracking Unique Identifier
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112040",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Unique Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Finding
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 5: Finding Site
        TemplateRow(
            rowID: "5",
            nestingLevel: 2,
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
        
        // Row 6: Length measurement using TID 300
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .baselineCID(
                contextGroupID: 7470,
                baseline: CodedConcept(
                    codeValue: "410668003",
                    codingSchemeDesignator: "SCT",
                    codeMeaning: "Length"
                )
            ),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm"
            )),
            requirementLevel: .mandatory,
            cardinality: .oneOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 7: Image reference
        TemplateRow(
            rowID: "7",
            nestingLevel: 2,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 8: Spatial coordinates
        TemplateRow(
            rowID: "8",
            nestingLevel: 3,
            relationshipType: .selectedFrom,
            valueType: .scoord,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
    ]
}

// MARK: - TID 1410: Planar ROI Measurements

/// TID 1410 - Planar ROI Measurements Template
///
/// Measurements derived from a 2D region of interest (ROI).
///
/// Reference: PS3.16 TID 1410
public struct TID1410PlanarROIMeasurements: SRTemplate {
    public static let identifier = TemplateIdentifier.planarROIMeasurements
    public static let displayName = "Planar ROI Measurements"
    public static let templateDescription = "Measurements from a 2D region of interest"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Tracking Identifier
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "112039",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Tracking Unique Identifier
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112040",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Unique Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Finding
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 5: Finding Site
        TemplateRow(
            rowID: "5",
            nestingLevel: 2,
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
        
        // Row 6: Area measurement
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "42798000",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Area"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm2",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm2"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 7: Long Axis (major axis)
        TemplateRow(
            rowID: "7",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "103339001",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Long Axis"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 8: Short Axis (minor axis)
        TemplateRow(
            rowID: "8",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "103340004",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Short Axis"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 9: Mean attenuation (CT)
        TemplateRow(
            rowID: "9",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "112031",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Attenuation Coefficient"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "[hnsf'U]",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Hounsfield unit"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 10: Image reference
        TemplateRow(
            rowID: "10",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 11: Spatial coordinates (ROI outline)
        TemplateRow(
            rowID: "11",
            nestingLevel: 2,
            relationshipType: .selectedFrom,
            valueType: .scoord,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        )
    ]
}

// MARK: - TID 1411: Volumetric ROI Measurements

/// TID 1411 - Volumetric ROI Measurements Template
///
/// Measurements derived from a 3D volumetric region of interest.
///
/// Reference: PS3.16 TID 1411
public struct TID1411VolumetricROIMeasurements: SRTemplate {
    public static let identifier = TemplateIdentifier.volumetricROIMeasurements
    public static let displayName = "Volumetric ROI Measurements"
    public static let templateDescription = "Measurements from a 3D volumetric region of interest"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Tracking Identifier
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "112039",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Tracking Unique Identifier
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112040",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Unique Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Finding
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 5: Finding Site
        TemplateRow(
            rowID: "5",
            nestingLevel: 2,
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
        
        // Row 6: Volume measurement
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "118565006",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Volume"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm3",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm3"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 7: Maximum 3D Diameter
        TemplateRow(
            rowID: "7",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "121217",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Maximum 3D Diameter"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "mm",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "mm"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 8: Mean attenuation
        TemplateRow(
            rowID: "8",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "112031",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Attenuation Coefficient"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "[hnsf'U]",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "Hounsfield unit"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .measurement
        ),
        
        // Row 9: Referenced segment
        TemplateRow(
            rowID: "9",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .exact(CodedConcept(
                codeValue: "121233",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Referenced Segment"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 10: 3D Spatial coordinates
        TemplateRow(
            rowID: "10",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .scoord3D,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        )
    ]
}

// MARK: - TID 1419: ROI Measurements

/// TID 1419 - ROI Measurements Template
///
/// Generic template for ROI-based measurements that can include both
/// planar and volumetric measurements.
///
/// Reference: PS3.16 TID 1419
public struct TID1419ROIMeasurements: SRTemplate {
    public static let identifier = TemplateIdentifier.roiMeasurements
    public static let displayName = "ROI Measurements"
    public static let templateDescription = "Generic ROI-based measurements"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Tracking Identifier
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "112039",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Tracking Unique Identifier
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112040",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Unique Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Activity Session
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "C67447",
                codingSchemeDesignator: "NCIt",
                codeMeaning: "Activity Session"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 5: Finding
        TemplateRow(
            rowID: "5",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 6: Finding Site
        TemplateRow(
            rowID: "6",
            nestingLevel: 2,
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
        
        // Row 7: Numeric measurements (any from TID 300)
        TemplateRow(
            rowID: "7",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 8: Qualitative evaluation
        TemplateRow(
            rowID: "8",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .fromContextGroup(contextGroupID: 6164),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 9: Image reference
        TemplateRow(
            rowID: "9",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 10: 2D coordinates
        TemplateRow(
            rowID: "10",
            nestingLevel: 2,
            relationshipType: .selectedFrom,
            valueType: .scoord,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 11: 3D coordinates
        TemplateRow(
            rowID: "11",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .scoord3D,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        )
    ]
}

// MARK: - TID 1420: Measurements Derived from Multiple ROI Measurements

/// TID 1420 - Measurements Derived from Multiple ROI Measurements Template
///
/// Aggregated measurements derived from multiple ROIs, such as total volume,
/// mean/max/min across multiple lesions, etc.
///
/// Reference: PS3.16 TID 1420
public struct TID1420MultipleROIMeasurements: SRTemplate {
    public static let identifier = TemplateIdentifier.multipleROIMeasurements
    public static let displayName = "Measurements from Multiple ROIs"
    public static let templateDescription = "Aggregated measurements derived from multiple ROI measurements"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "126010",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Imaging Measurements"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Measurement Method
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
            cardinality: .zeroOrOne
        ),
        
        // Row 3: Source of measurement
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121405",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Source of Measurement"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 7462),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 4: Sum of measurements
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "276825003",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Sum"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 5: Mean value
        TemplateRow(
            rowID: "5",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "373098007",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Mean Value"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 6: Standard Deviation
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "386136009",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Standard Deviation"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 7: Minimum value
        TemplateRow(
            rowID: "7",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "255605001",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Minimum"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 8: Maximum value
        TemplateRow(
            rowID: "8",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "56851009",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Maximum"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 9: Lesion count
        TemplateRow(
            rowID: "9",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .exact(CodedConcept(
                codeValue: "246205007",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Quantity"
            )),
            valueConstraint: .numericUnits(unitCode: CodedConcept(
                codeValue: "1",
                codingSchemeDesignator: "UCUM",
                codeMeaning: "no units"
            )),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 10: Reference to ROI measurements this was derived from
        TemplateRow(
            rowID: "10",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .container,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .roiMeasurements
        )
    ]
}

// MARK: - TID 1500: Measurement Report

/// TID 1500 - Measurement Report Template
///
/// Root template for measurement reports containing imaging measurements,
/// image library, and qualitative evaluations. This is the primary template
/// for quantitative imaging reports and AI/ML measurement outputs.
///
/// Reference: PS3.16 TID 1500
public struct TID1500MeasurementReport: SRTemplate {
    public static let identifier = TemplateIdentifier.measurementReport
    public static let displayName = "Measurement Report"
    public static let templateDescription = "Root template for measurement reports with imaging measurements and image library"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Document title (root container)
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .fromContextGroup(contextGroupID: 7021),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Language of Content Item and Descendants (TID 1204)
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121049",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Language of Content Item and Descendants"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 5000),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .languageOfContent
        ),
        
        // Row 3: Observation Context (TID 1001)
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .container,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .observationContext
        ),
        
        // Row 4: Procedure Reported
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121058",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Procedure Reported"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 100),
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 5: Image Library (TID 1600)
        TemplateRow(
            rowID: "5",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "111028",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Image Library"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne,
            includedTemplate: .imageLibrary
        ),
        
        // Row 6: Imaging Measurements container
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "126010",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Imaging Measurements"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 7: Measurement Group (TID 1501) within Imaging Measurements
        TemplateRow(
            rowID: "7",
            nestingLevel: 2,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurementGroup
        ),
        
        // Row 8: Derived Imaging Measurements (TID 1420)
        TemplateRow(
            rowID: "8",
            nestingLevel: 2,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .multipleROIMeasurements
        ),
        
        // Row 9: Qualitative Evaluations container
        TemplateRow(
            rowID: "9",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "C0034375",
                codingSchemeDesignator: "UMLS",
                codeMeaning: "Qualitative Evaluations"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 10: Qualitative evaluation items
        TemplateRow(
            rowID: "10",
            nestingLevel: 2,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        )
    ]
}

// MARK: - TID 1501: Measurement Group

/// TID 1501 - Measurement Group Template
///
/// Container for a group of related measurements, typically associated with
/// a single finding or anatomical structure. Includes tracking identifiers
/// for longitudinal studies.
///
/// Reference: PS3.16 TID 1501
public struct TID1501MeasurementGroup: SRTemplate {
    public static let identifier = TemplateIdentifier.measurementGroup
    public static let displayName = "Measurement Group"
    public static let templateDescription = "Container for related measurements with tracking identifiers"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "125007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Measurement Group"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Tracking Identifier
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "112039",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 3: Tracking Unique Identifier
        TemplateRow(
            rowID: "3",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112040",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Tracking Unique Identifier"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 4: Activity Session
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "C67447",
                codingSchemeDesignator: "NCIt",
                codeMeaning: "Activity Session"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 5: Time Point
        TemplateRow(
            rowID: "5",
            nestingLevel: 1,
            relationshipType: .hasObsContext,
            valueType: .text,
            conceptName: .exact(CodedConcept(
                codeValue: "C2348792",
                codingSchemeDesignator: "UMLS",
                codeMeaning: "Time Point"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 6: Finding Category
        TemplateRow(
            rowID: "6",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "276214006",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Finding category"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 7: Finding
        TemplateRow(
            rowID: "7",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "121071",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Finding"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 8: Finding Site
        TemplateRow(
            rowID: "8",
            nestingLevel: 2,
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
        
        // Row 9: Laterality modifier
        TemplateRow(
            rowID: "9",
            nestingLevel: 3,
            relationshipType: .hasConceptMod,
            valueType: .code,
            conceptName: .exact(CodedConcept(
                codeValue: "272741003",
                codingSchemeDesignator: "SCT",
                codeMeaning: "Laterality"
            )),
            valueConstraint: .fromContextGroup(contextGroupID: 244),
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        ),
        
        // Row 10: Numeric measurements (TID 300)
        TemplateRow(
            rowID: "10",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .num,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .measurement
        ),
        
        // Row 11: Qualitative evaluation
        TemplateRow(
            rowID: "11",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .code,
            conceptName: .fromContextGroup(contextGroupID: 6147),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 12: Image reference
        TemplateRow(
            rowID: "12",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 13: Spatial coordinates
        TemplateRow(
            rowID: "13",
            nestingLevel: 2,
            relationshipType: .selectedFrom,
            valueType: .scoord,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 14: 3D Spatial coordinates
        TemplateRow(
            rowID: "14",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .scoord3D,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 15: Referenced segment
        TemplateRow(
            rowID: "15",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .image,
            conceptName: .exact(CodedConcept(
                codeValue: "121233",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Referenced Segment"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 16: Real World Value Map reference
        TemplateRow(
            rowID: "16",
            nestingLevel: 1,
            relationshipType: .inferredFrom,
            valueType: .composite,
            conceptName: .exact(CodedConcept(
                codeValue: "126100",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Real World Value Map used for measurement"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        )
    ]
}

// MARK: - TID 1600: Image Library

/// TID 1600 - Image Library Template
///
/// Container for references to images used in the measurement report.
/// Provides context about the images that measurements were derived from.
///
/// Reference: PS3.16 TID 1600
public struct TID1600ImageLibrary: SRTemplate {
    public static let identifier = TemplateIdentifier.imageLibrary
    public static let displayName = "Image Library"
    public static let templateDescription = "Container for image references used in measurements"
    public static let rootValueType: ContentItemValueType = .container
    public static let isExtensible = true
    
    public static let rows: [TemplateRow] = [
        // Row 1: Container root
        TemplateRow(
            rowID: "1",
            nestingLevel: 0,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "111028",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Image Library"
            )),
            valueConstraint: .any,
            requirementLevel: .mandatory,
            cardinality: .one
        ),
        
        // Row 2: Image Library Group (for grouping images)
        TemplateRow(
            rowID: "2",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .container,
            conceptName: .exact(CodedConcept(
                codeValue: "126200",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Image Library Group"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore
        ),
        
        // Row 3: Image Library Entry (TID 320) within group
        TemplateRow(
            rowID: "3",
            nestingLevel: 2,
            relationshipType: .contains,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .imageLibraryEntry
        ),
        
        // Row 4: Image Library Entry directly in library (without group)
        TemplateRow(
            rowID: "4",
            nestingLevel: 1,
            relationshipType: .contains,
            valueType: .image,
            conceptName: .any,
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrMore,
            includedTemplate: .imageLibraryEntry
        ),
        
        // Row 5: Common acquisition context for group
        TemplateRow(
            rowID: "5",
            nestingLevel: 2,
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
        
        // Row 6: Frame of Reference UID for group
        TemplateRow(
            rowID: "6",
            nestingLevel: 2,
            relationshipType: .hasAcqContext,
            valueType: .uidref,
            conceptName: .exact(CodedConcept(
                codeValue: "112227",
                codingSchemeDesignator: "DCM",
                codeMeaning: "Frame of Reference UID"
            )),
            valueConstraint: .any,
            requirementLevel: .userConditional,
            cardinality: .zeroOrOne
        )
    ]
}
