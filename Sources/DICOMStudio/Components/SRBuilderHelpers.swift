// SRBuilderHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent SR document builder helpers
// Reference: DICOM PS3.16 (Content Mapping Resources), TID 1500, TID 2000

import Foundation

/// Platform-independent helpers for building DICOM SR documents.
///
/// Provides template generation, content item construction, and validation
/// for all 8 SR document types.
public enum SRBuilderHelpers: Sendable {

    // MARK: - Common Coded Concepts

    /// Coded concept for a measurement group (TID 1500).
    public static let measurementGroupConcept = CodedConcept(
        codeValue: "125007", codingSchemeDesignator: "DCM",
        codeMeaning: "Measurement Group"
    )

    /// Coded concept for tracking identifier.
    public static let trackingIdentifierConcept = CodedConcept(
        codeValue: "112039", codingSchemeDesignator: "DCM",
        codeMeaning: "Tracking Identifier"
    )

    /// Coded concept for tracking unique identifier.
    public static let trackingUIDConcept = CodedConcept(
        codeValue: "112040", codingSchemeDesignator: "DCM",
        codeMeaning: "Tracking Unique Identifier"
    )

    /// Coded concept for finding.
    public static let findingConcept = CodedConcept(
        codeValue: "121071", codingSchemeDesignator: "DCM",
        codeMeaning: "Finding"
    )

    /// Coded concept for finding site.
    public static let findingSiteConcept = CodedConcept(
        codeValue: "G-C0E3", codingSchemeDesignator: "SRT",
        codeMeaning: "Finding Site"
    )

    /// Coded concept for image reference purpose.
    public static let imageReferenceConcept = CodedConcept(
        codeValue: "121200", codingSchemeDesignator: "DCM",
        codeMeaning: "Image Reference"
    )

    /// Coded concept for Key Object Selection title.
    public static let keyObjectSelectionTitle = CodedConcept(
        codeValue: "113000", codingSchemeDesignator: "DCM",
        codeMeaning: "Key Object Selection"
    )

    // MARK: - UCUM Unit Concepts

    /// UCUM millimeter unit.
    public static let ucumMillimeter = CodedConcept(
        codeValue: "mm", codingSchemeDesignator: "UCUM", codeMeaning: "mm"
    )

    /// UCUM centimeter unit.
    public static let ucumCentimeter = CodedConcept(
        codeValue: "cm", codingSchemeDesignator: "UCUM", codeMeaning: "cm"
    )

    /// UCUM square millimeter unit.
    public static let ucumSquareMillimeter = CodedConcept(
        codeValue: "mm2", codingSchemeDesignator: "UCUM", codeMeaning: "mm2"
    )

    /// UCUM milliliter unit.
    public static let ucumMilliliter = CodedConcept(
        codeValue: "ml", codingSchemeDesignator: "UCUM", codeMeaning: "ml"
    )

    /// UCUM Hounsfield unit.
    public static let ucumHounsfieldUnit = CodedConcept(
        codeValue: "[hnsf'U]", codingSchemeDesignator: "UCUM", codeMeaning: "HU"
    )

    /// UCUM no units (dimensionless).
    public static let ucumNoUnits = CodedConcept(
        codeValue: "1", codingSchemeDesignator: "UCUM", codeMeaning: "{ratio}"
    )

    // MARK: - Content Item Builders

    /// Creates a container content item.
    public static func containerItem(
        conceptName: CodedConcept,
        relationship: SRRelationshipType = .contains,
        continuity: ContinuityOfContent = .separate,
        children: [SRContentItem] = []
    ) -> SRContentItem {
        SRContentItem(
            valueType: .container,
            conceptName: conceptName,
            relationshipType: relationship,
            continuityOfContent: continuity,
            children: children
        )
    }

    /// Creates a text content item.
    public static func textItem(
        conceptName: CodedConcept,
        text: String,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .text,
            conceptName: conceptName,
            relationshipType: relationship,
            textValue: text
        )
    }

    /// Creates a code content item.
    public static func codeItem(
        conceptName: CodedConcept,
        code: CodedConcept,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .code,
            conceptName: conceptName,
            relationshipType: relationship,
            codeValue: code
        )
    }

    /// Creates a numeric content item with UCUM units.
    public static func numericItem(
        conceptName: CodedConcept,
        value: Double,
        unit: CodedConcept,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .numeric,
            conceptName: conceptName,
            relationshipType: relationship,
            numericValue: value,
            measurementUnit: unit
        )
    }

    /// Creates a person name content item.
    public static func personNameItem(
        conceptName: CodedConcept,
        name: String,
        relationship: SRRelationshipType = .hasObsContext
    ) -> SRContentItem {
        SRContentItem(
            valueType: .personName,
            conceptName: conceptName,
            relationshipType: relationship,
            personName: name
        )
    }

    /// Creates a date content item.
    public static func dateItem(
        conceptName: CodedConcept,
        date: String,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .date,
            conceptName: conceptName,
            relationshipType: relationship,
            dateValue: date
        )
    }

    /// Creates a UID reference content item.
    public static func uidRefItem(
        conceptName: CodedConcept,
        uid: String,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .uidRef,
            conceptName: conceptName,
            relationshipType: relationship,
            uidValue: uid
        )
    }

    /// Creates an image reference content item.
    public static func imageItem(
        conceptName: CodedConcept,
        sopClassUID: String,
        sopInstanceUID: String,
        frameNumbers: [Int]? = nil,
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .image,
            conceptName: conceptName,
            relationshipType: relationship,
            referencedSOPClassUID: sopClassUID,
            referencedSOPInstanceUID: sopInstanceUID,
            referencedFrameNumbers: frameNumbers
        )
    }

    /// Creates a 2D spatial coordinate content item.
    public static func spatialCoordItem(
        conceptName: CodedConcept,
        graphicType: SpatialCoordGraphicType,
        graphicData: [Double],
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .spatialCoord,
            conceptName: conceptName,
            relationshipType: relationship,
            graphicType: graphicType,
            graphicData: graphicData
        )
    }

    /// Creates a 3D spatial coordinate content item.
    public static func spatialCoord3DItem(
        conceptName: CodedConcept,
        graphicType: SpatialCoord3DGraphicType,
        graphicData: [Double],
        relationship: SRRelationshipType = .contains
    ) -> SRContentItem {
        SRContentItem(
            valueType: .spatialCoord3D,
            conceptName: conceptName,
            relationshipType: relationship,
            graphicType3D: graphicType,
            graphicData3D: graphicData
        )
    }

    // MARK: - Template Builders

    /// Builds a Basic Text SR document from a template.
    ///
    /// - Parameters:
    ///   - template: The report template.
    ///   - sectionTexts: Text for each section (keyed by section name).
    /// - Returns: Root content item with template sections.
    public static func buildBasicTextSR(
        template: SRTemplate,
        sectionTexts: [String: String] = [:]
    ) -> SRContentItem {
        let titleConcept = CodedConcept(
            codeValue: "121070", codingSchemeDesignator: "DCM",
            codeMeaning: template.displayName
        )
        let sections = template.sections.map { sectionName in
            let sectionConcept = CodedConcept(
                codeValue: "121070", codingSchemeDesignator: "DCM",
                codeMeaning: sectionName
            )
            let text = sectionTexts[sectionName] ?? ""
            let textChild = textItem(
                conceptName: sectionConcept,
                text: text
            )
            return containerItem(
                conceptName: sectionConcept,
                continuity: .separate,
                children: text.isEmpty ? [] : [textChild]
            )
        }
        return containerItem(
            conceptName: titleConcept,
            continuity: .separate,
            children: sections
        )
    }

    /// Builds a Key Object Selection document.
    ///
    /// - Parameters:
    ///   - purpose: The selection purpose.
    ///   - description: Description text.
    ///   - imageReferences: Array of (sopClassUID, sopInstanceUID) pairs.
    /// - Returns: Root content item for Key Object Selection.
    public static func buildKeyObjectSelection(
        purpose: KeyObjectPurpose,
        description: String,
        imageReferences: [(String, String)] = []
    ) -> SRContentItem {
        var children: [SRContentItem] = []

        let purposeConcept = CodedConcept(
            codeValue: "113012", codingSchemeDesignator: "DCM",
            codeMeaning: "Key Object Description"
        )
        children.append(textItem(conceptName: purposeConcept, text: description))

        for (classUID, instanceUID) in imageReferences {
            children.append(imageItem(
                conceptName: imageReferenceConcept,
                sopClassUID: classUID,
                sopInstanceUID: instanceUID
            ))
        }

        return containerItem(
            conceptName: keyObjectSelectionTitle,
            continuity: .separate,
            children: children
        )
    }

    /// Builds a Measurement Report root item (TID 1500 skeleton).
    ///
    /// - Parameters:
    ///   - measurements: Tracked measurements to include.
    /// - Returns: Root content item for a measurement report.
    public static func buildMeasurementReport(
        measurements: [TrackedMeasurement] = []
    ) -> SRContentItem {
        let reportTitle = CodedConcept(
            codeValue: "126000", codingSchemeDesignator: "DCM",
            codeMeaning: "Imaging Measurement Report"
        )
        var groups: [SRContentItem] = []
        for measurement in measurements {
            let group = buildMeasurementGroup(for: measurement)
            groups.append(group)
        }
        return containerItem(
            conceptName: reportTitle,
            continuity: .separate,
            children: groups
        )
    }

    /// Builds a single measurement group for a tracked measurement.
    public static func buildMeasurementGroup(
        for measurement: TrackedMeasurement
    ) -> SRContentItem {
        var children: [SRContentItem] = []

        children.append(textItem(
            conceptName: trackingIdentifierConcept,
            text: measurement.trackingIdentifier,
            relationship: .hasObsContext
        ))

        if !measurement.trackingUID.isEmpty {
            children.append(uidRefItem(
                conceptName: trackingUIDConcept,
                uid: measurement.trackingUID,
                relationship: .hasObsContext
            ))
        }

        let measurementConcept = CodedConcept(
            codeValue: "410668003", codingSchemeDesignator: "SCT",
            codeMeaning: "Length"
        )
        children.append(numericItem(
            conceptName: measurementConcept,
            value: measurement.value,
            unit: measurement.unit
        ))

        if let site = measurement.findingSite {
            children.append(codeItem(
                conceptName: findingSiteConcept,
                code: site,
                relationship: .hasConceptMod
            ))
        }

        return containerItem(
            conceptName: measurementGroupConcept,
            continuity: .separate,
            children: children
        )
    }

    // MARK: - Validation

    /// Validates an SR document for completeness.
    ///
    /// - Parameter document: The SR document.
    /// - Returns: Array of validation error strings (empty if valid).
    public static func validateDocument(_ document: SRDocument) -> [String] {
        var errors: [String] = []

        if document.title.codeMeaning.isEmpty {
            errors.append("Document title is empty")
        }

        if document.rootContentItem.valueType != .container {
            errors.append("Root content item must be a CONTAINER")
        }

        if document.rootContentItem.children.isEmpty {
            errors.append("Document has no content items")
        }

        validateContentItems(document.rootContentItem, errors: &errors, path: "root")

        return errors
    }

    private static func validateContentItems(
        _ item: SRContentItem,
        errors: inout [String],
        path: String
    ) {
        switch item.valueType {
        case .text:
            if item.textValue == nil || item.textValue?.isEmpty == true {
                errors.append("Text item at \(path) has empty value")
            }
        case .code:
            if item.codeValue == nil {
                errors.append("Code item at \(path) has no coded value")
            }
        case .numeric:
            if item.numericValue == nil {
                errors.append("Numeric item at \(path) has no value")
            }
            if item.measurementUnit == nil {
                errors.append("Numeric item at \(path) has no unit")
            }
        case .personName:
            if item.personName == nil || item.personName?.isEmpty == true {
                errors.append("Person name item at \(path) has empty name")
            }
        case .image:
            if item.referencedSOPInstanceUID == nil || item.referencedSOPInstanceUID?.isEmpty == true {
                errors.append("Image item at \(path) has no referenced SOP Instance UID")
            }
        default:
            break
        }

        for (index, child) in item.children.enumerated() {
            validateContentItems(child, errors: &errors, path: "\(path)/\(index)")
        }
    }

    /// Returns the list of supported SR document types for a builder mode.
    ///
    /// - Parameter mode: The builder mode.
    /// - Returns: Array of supported document types.
    public static func supportedDocumentTypes(for mode: SRBuilderMode) -> [SRDocumentType] {
        switch mode {
        case .template:
            return [.basicText, .enhanced, .measurementReport, .keyObjectSelection]
        case .freeForm:
            return SRDocumentType.allCases
        case .importExisting:
            return SRDocumentType.allCases
        }
    }

    /// Returns the available templates for a document type.
    ///
    /// - Parameter documentType: The SR document type.
    /// - Returns: Array of available templates.
    public static func availableTemplates(for documentType: SRDocumentType) -> [SRTemplate] {
        switch documentType {
        case .basicText:
            return SRTemplate.allCases
        case .enhanced, .comprehensive, .comprehensive3D:
            return [.radiologyReport, .procedureReport]
        case .measurementReport:
            return [.radiologyReport]
        case .keyObjectSelection, .mammographyCAD, .chestCAD:
            return []
        }
    }
}
