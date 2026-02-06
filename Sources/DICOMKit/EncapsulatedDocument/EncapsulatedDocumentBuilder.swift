//
// EncapsulatedDocumentBuilder.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-06.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Builder for creating DICOM Encapsulated Document objects
///
/// EncapsulatedDocumentBuilder provides a fluent API for constructing Encapsulated Document
/// IODs, enabling PDF files, CDA documents, and other document types to be wrapped as DICOM
/// objects for storage and transmission.
///
/// Example - Encapsulating a PDF:
/// ```swift
/// let pdfData = try Data(contentsOf: pdfURL)
/// let document = try EncapsulatedDocumentBuilder(
///     documentData: pdfData,
///     mimeType: "application/pdf",
///     documentType: .pdf,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setDocumentTitle("Radiology Report")
/// .setPatientName("Smith^John")
/// .setPatientID("12345")
/// .setModality("DOC")
/// .build()
/// ```
///
/// Example - Encapsulating a CDA document:
/// ```swift
/// let cdaData = cdaXMLString.data(using: .utf8)!
/// let document = try EncapsulatedDocumentBuilder(
///     documentData: cdaData,
///     mimeType: "text/xml",
///     documentType: .cda,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setDocumentTitle("Discharge Summary")
/// .setHL7InstanceIdentifier("2.16.840.1.113883.19.999.1")
/// .build()
/// ```
///
/// Reference: PS3.3 A.45 - Encapsulated PDF IOD
/// Reference: PS3.3 A.45.2 - Encapsulated CDA IOD
/// Reference: PS3.3 C.24 - Encapsulated Document Module
public final class EncapsulatedDocumentBuilder {

    // MARK: - Required Configuration

    private let documentData: Data
    private let mimeType: String
    private let documentType: EncapsulatedDocumentType
    private let studyInstanceUID: String
    private let seriesInstanceUID: String

    // MARK: - Optional Metadata

    private var sopInstanceUID: String?
    private var instanceNumber: Int?
    private var patientName: String?
    private var patientID: String?
    private var documentTitle: String?
    private var modality: String?
    private var seriesDescription: String?
    private var seriesNumber: Int?
    private var contentDate: DICOMDate?
    private var contentTime: DICOMTime?
    private var conceptNameCode: ConceptNameCode?
    private var hl7InstanceIdentifier: String?
    private var sourceInstances: [SourceInstanceReference] = []

    // MARK: - Initialization

    /// Creates a new EncapsulatedDocumentBuilder
    ///
    /// - Parameters:
    ///   - documentData: The raw document data (e.g., PDF file contents)
    ///   - mimeType: The MIME type of the document (e.g., "application/pdf")
    ///   - documentType: The type of encapsulated document
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    public init(
        documentData: Data,
        mimeType: String,
        documentType: EncapsulatedDocumentType,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.documentData = documentData
        self.mimeType = mimeType
        self.documentType = documentType
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
    }

    // MARK: - Fluent Setters

    /// Sets the SOP Instance UID (auto-generated if not set)
    @discardableResult
    public func setSOPInstanceUID(_ uid: String) -> Self {
        self.sopInstanceUID = uid
        return self
    }

    /// Sets the Instance Number
    @discardableResult
    public func setInstanceNumber(_ number: Int) -> Self {
        self.instanceNumber = number
        return self
    }

    /// Sets the Patient Name
    @discardableResult
    public func setPatientName(_ name: String) -> Self {
        self.patientName = name
        return self
    }

    /// Sets the Patient ID
    @discardableResult
    public func setPatientID(_ id: String) -> Self {
        self.patientID = id
        return self
    }

    /// Sets the Document Title
    @discardableResult
    public func setDocumentTitle(_ title: String) -> Self {
        self.documentTitle = title
        return self
    }

    /// Sets the Modality (typically "DOC" for documents)
    @discardableResult
    public func setModality(_ modality: String) -> Self {
        self.modality = modality
        return self
    }

    /// Sets the Series Description
    @discardableResult
    public func setSeriesDescription(_ description: String) -> Self {
        self.seriesDescription = description
        return self
    }

    /// Sets the Series Number
    @discardableResult
    public func setSeriesNumber(_ number: Int) -> Self {
        self.seriesNumber = number
        return self
    }

    /// Sets the Content Date
    @discardableResult
    public func setContentDate(_ date: DICOMDate) -> Self {
        self.contentDate = date
        return self
    }

    /// Sets the Content Time
    @discardableResult
    public func setContentTime(_ time: DICOMTime) -> Self {
        self.contentTime = time
        return self
    }

    /// Sets the Concept Name Code Sequence
    @discardableResult
    public func setConceptNameCode(codeValue: String, codingSchemeDesignator: String, codeMeaning: String) -> Self {
        self.conceptNameCode = ConceptNameCode(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning
        )
        return self
    }

    /// Sets the HL7 Instance Identifier (for CDA documents)
    @discardableResult
    public func setHL7InstanceIdentifier(_ identifier: String) -> Self {
        self.hl7InstanceIdentifier = identifier
        return self
    }

    /// Adds a source instance reference
    @discardableResult
    public func addSourceInstance(sopClassUID: String, sopInstanceUID: String) -> Self {
        self.sourceInstances.append(SourceInstanceReference(
            referencedSOPClassUID: sopClassUID,
            referencedSOPInstanceUID: sopInstanceUID
        ))
        return self
    }

    // MARK: - Build

    /// Builds the EncapsulatedDocument
    ///
    /// - Returns: The constructed EncapsulatedDocument
    /// - Throws: DICOMError if required data is invalid
    public func build() throws -> EncapsulatedDocument {
        guard !documentData.isEmpty else {
            throw DICOMError.parsingFailed("Document data cannot be empty")
        }

        guard !mimeType.isEmpty else {
            throw DICOMError.parsingFailed("MIME type cannot be empty")
        }

        let instanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().value

        return EncapsulatedDocument(
            sopInstanceUID: instanceUID,
            sopClassUID: documentType.sopClassUID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            patientName: patientName,
            patientID: patientID,
            mimeType: mimeType,
            documentTitle: documentTitle,
            documentData: documentData,
            modality: modality,
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            contentDate: contentDate,
            contentTime: contentTime,
            conceptNameCode: conceptNameCode,
            hl7InstanceIdentifier: hl7InstanceIdentifier,
            sourceInstances: sourceInstances
        )
    }

    /// Builds the EncapsulatedDocument and converts it to a DICOM DataSet
    ///
    /// - Returns: A DataSet ready for DICOM file creation
    /// - Throws: DICOMError if building fails
    public func buildDataSet() throws -> DataSet {
        let document = try build()
        return document.toDataSet()
    }
}

// MARK: - DataSet Conversion

extension EncapsulatedDocument {

    /// Converts the EncapsulatedDocument to a DICOM DataSet
    ///
    /// Creates a DataSet with all required and optional attributes for the
    /// Encapsulated Document IOD.
    ///
    /// - Returns: A DataSet representation of this document
    public func toDataSet() -> DataSet {
        var dataSet = DataSet()

        // SOP Common Module
        dataSet.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        dataSet.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)

        // Patient Module
        if let patientName = patientName {
            dataSet.setString(patientName, for: .patientName, vr: .PN)
        }
        if let patientID = patientID {
            dataSet.setString(patientID, for: .patientID, vr: .LO)
        }

        // General Study Module
        dataSet.setString(studyInstanceUID, for: .studyInstanceUID, vr: .UI)

        // Encapsulated Document Series Module
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)

        if let modality = modality {
            dataSet.setString(modality, for: .modality, vr: .CS)
        }
        if let seriesDescription = seriesDescription {
            dataSet.setString(seriesDescription, for: .seriesDescription, vr: .LO)
        }
        if let seriesNumber = seriesNumber {
            dataSet.setString(String(seriesNumber), for: .seriesNumber, vr: .IS)
        }

        // General Equipment Module - instance number
        if let instanceNumber = instanceNumber {
            dataSet.setString(String(instanceNumber), for: .instanceNumber, vr: .IS)
        }

        // Content Date/Time
        if let contentDate = contentDate {
            dataSet.setString(contentDate.dicomString, for: .contentDate, vr: .DA)
        }
        if let contentTime = contentTime {
            dataSet.setString(contentTime.dicomString, for: .contentTime, vr: .TM)
        }

        // Encapsulated Document Module
        dataSet.setString(mimeType, for: .mimeTypeOfEncapsulatedDocument, vr: .LO)

        if let documentTitle = documentTitle {
            dataSet.setString(documentTitle, for: .documentTitle, vr: .ST)
        }

        // Document data as OB
        dataSet[.encapsulatedDocument] = DataElement.data(
            tag: .encapsulatedDocument,
            vr: .OB,
            data: documentData
        )

        // Concept Name Code Sequence
        if let conceptNameCode = conceptNameCode {
            let codeItem = createCodeSequenceItem(conceptNameCode)
            dataSet.setSequence([codeItem], for: .conceptNameCodeSequence)
        }

        // HL7 Instance Identifier
        if let hl7InstanceIdentifier = hl7InstanceIdentifier {
            dataSet.setString(hl7InstanceIdentifier, for: .hl7InstanceIdentifier, vr: .ST)
        }

        // Source Instance Sequence
        if !sourceInstances.isEmpty {
            let items = sourceInstances.map { ref -> SequenceItem in
                var itemElements: [DataElement] = []
                itemElements.append(DataElement.string(
                    tag: .referencedSOPClassUID,
                    vr: .UI,
                    value: ref.referencedSOPClassUID
                ))
                itemElements.append(DataElement.string(
                    tag: .referencedSOPInstanceUID,
                    vr: .UI,
                    value: ref.referencedSOPInstanceUID
                ))
                return SequenceItem(elements: itemElements)
            }
            dataSet.setSequence(items, for: .sourceInstanceSequence)
        }

        return dataSet
    }

    /// Creates a SequenceItem for a coded concept
    private func createCodeSequenceItem(_ code: ConceptNameCode) -> SequenceItem {
        var elements: [DataElement] = []
        elements.append(DataElement.string(tag: .codeValue, vr: .SH, value: code.codeValue))
        elements.append(DataElement.string(tag: .codingSchemeDesignator, vr: .SH, value: code.codingSchemeDesignator))
        elements.append(DataElement.string(tag: .codeMeaning, vr: .LO, value: code.codeMeaning))
        return SequenceItem(elements: elements)
    }
}
