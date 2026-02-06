//
// EncapsulatedDocumentTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-06.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class EncapsulatedDocumentTests: XCTestCase {

    // MARK: - EncapsulatedDocumentType Tests

    func test_documentType_pdf_fromSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.840.10008.5.1.4.1.1.104.1")
        XCTAssertEqual(type, .pdf)
        XCTAssertEqual(type.expectedMIMEType, "application/pdf")
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.104.1")
    }

    func test_documentType_cda_fromSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.840.10008.5.1.4.1.1.104.2")
        XCTAssertEqual(type, .cda)
        XCTAssertEqual(type.expectedMIMEType, "text/xml")
    }

    func test_documentType_stl_fromSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.840.10008.5.1.4.1.1.104.3")
        XCTAssertEqual(type, .stl)
        XCTAssertEqual(type.expectedMIMEType, "application/sla")
    }

    func test_documentType_obj_fromSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.840.10008.5.1.4.1.1.104.4")
        XCTAssertEqual(type, .obj)
        XCTAssertEqual(type.expectedMIMEType, "model/obj")
    }

    func test_documentType_mtl_fromSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.840.10008.5.1.4.1.1.104.5")
        XCTAssertEqual(type, .mtl)
        XCTAssertEqual(type.expectedMIMEType, "model/mtl")
    }

    func test_documentType_unknown_fromInvalidSOPClassUID() {
        let type = EncapsulatedDocumentType(sopClassUID: "1.2.3.4.5")
        XCTAssertEqual(type, .unknown)
        XCTAssertEqual(type.expectedMIMEType, "application/octet-stream")
        XCTAssertEqual(type.sopClassUID, "")
    }

    // MARK: - EncapsulatedDocument Property Tests

    func test_document_isPDF_returnsTrue() {
        let doc = makeDocument(sopClassUID: EncapsulatedDocument.encapsulatedPDFStorageUID)
        XCTAssertTrue(doc.isPDF)
        XCTAssertFalse(doc.isCDA)
        XCTAssertEqual(doc.documentType, .pdf)
    }

    func test_document_isCDA_returnsTrue() {
        let doc = makeDocument(sopClassUID: EncapsulatedDocument.encapsulatedCDAStorageUID)
        XCTAssertTrue(doc.isCDA)
        XCTAssertFalse(doc.isPDF)
        XCTAssertEqual(doc.documentType, .cda)
    }

    func test_document_documentSize_returnsCorrectSize() {
        let data = Data(repeating: 0x25, count: 1024)
        let doc = makeDocument(documentData: data)
        XCTAssertEqual(doc.documentSize, 1024)
    }

    // MARK: - ConceptNameCode Tests

    func test_conceptNameCode_initialization() {
        let code = ConceptNameCode(
            codeValue: "18782-3",
            codingSchemeDesignator: "LN",
            codeMeaning: "Radiology Study observation"
        )
        XCTAssertEqual(code.codeValue, "18782-3")
        XCTAssertEqual(code.codingSchemeDesignator, "LN")
        XCTAssertEqual(code.codeMeaning, "Radiology Study observation")
    }

    // MARK: - SourceInstanceReference Tests

    func test_sourceInstanceReference_initialization() {
        let ref = SourceInstanceReference(
            referencedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            referencedSOPInstanceUID: "1.2.3.4.5.6.7"
        )
        XCTAssertEqual(ref.referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(ref.referencedSOPInstanceUID, "1.2.3.4.5.6.7")
    }

    // MARK: - SOP Class UID Constants Tests

    func test_sopClassUID_constants() {
        XCTAssertEqual(EncapsulatedDocument.encapsulatedPDFStorageUID, "1.2.840.10008.5.1.4.1.1.104.1")
        XCTAssertEqual(EncapsulatedDocument.encapsulatedCDAStorageUID, "1.2.840.10008.5.1.4.1.1.104.2")
        XCTAssertEqual(EncapsulatedDocument.encapsulatedSTLStorageUID, "1.2.840.10008.5.1.4.1.1.104.3")
        XCTAssertEqual(EncapsulatedDocument.encapsulatedOBJStorageUID, "1.2.840.10008.5.1.4.1.1.104.4")
        XCTAssertEqual(EncapsulatedDocument.encapsulatedMTLStorageUID, "1.2.840.10008.5.1.4.1.1.104.5")
    }

    // MARK: - Parser Tests

    func test_parser_parsesMinimalDataSet() throws {
        let dataSet = makeMinimalDataSet()
        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertEqual(doc.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(doc.sopClassUID, EncapsulatedDocument.encapsulatedPDFStorageUID)
        XCTAssertEqual(doc.studyInstanceUID, "1.2.3")
        XCTAssertEqual(doc.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(doc.mimeType, "application/pdf")
        XCTAssertFalse(doc.documentData.isEmpty)
    }

    func test_parser_parsesFullDataSet() throws {
        let dataSet = makeFullDataSet()
        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertEqual(doc.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(doc.studyInstanceUID, "1.2.3")
        XCTAssertEqual(doc.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(doc.mimeType, "application/pdf")
        XCTAssertEqual(doc.documentTitle, "Radiology Report")
        XCTAssertEqual(doc.patientName, "Smith^John")
        XCTAssertEqual(doc.patientID, "12345")
        XCTAssertEqual(doc.modality, "DOC")
        XCTAssertEqual(doc.seriesDescription, "Reports")
    }

    func test_parser_failsWithMissingSOPInstanceUID() {
        var dataSet = DataSet()
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: Data([0x25]))

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_failsWithMissingStudyInstanceUID() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: Data([0x25]))

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_failsWithMissingSeriesInstanceUID() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: Data([0x25]))

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_failsWithMissingMIMEType() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: Data([0x25]))

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_failsWithMissingDocumentData() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_failsWithEmptyDocumentData() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: Data())

        XCTAssertThrowsError(try EncapsulatedDocumentParser.parse(from: dataSet))
    }

    func test_parser_parsesConceptNameCodeSequence() throws {
        var dataSet = makeMinimalDataSet()

        // Add Concept Name Code Sequence
        let codeItem = SequenceItem(elements: [
            DataElement.string(tag: .codeValue, vr: .SH, value: "18782-3"),
            DataElement.string(tag: .codingSchemeDesignator, vr: .SH, value: "LN"),
            DataElement.string(tag: .codeMeaning, vr: .LO, value: "Radiology Study observation")
        ])
        dataSet.setSequence([codeItem], for: .conceptNameCodeSequence)

        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)
        XCTAssertNotNil(doc.conceptNameCode)
        XCTAssertEqual(doc.conceptNameCode?.codeValue, "18782-3")
        XCTAssertEqual(doc.conceptNameCode?.codingSchemeDesignator, "LN")
        XCTAssertEqual(doc.conceptNameCode?.codeMeaning, "Radiology Study observation")
    }

    func test_parser_parsesSourceInstanceSequence() throws {
        var dataSet = makeMinimalDataSet()

        // Add Source Instance Sequence
        let refItem = SequenceItem(elements: [
            DataElement.string(tag: .referencedSOPClassUID, vr: .UI, value: "1.2.840.10008.5.1.4.1.1.2"),
            DataElement.string(tag: .referencedSOPInstanceUID, vr: .UI, value: "1.2.3.4.5.6.7")
        ])
        dataSet.setSequence([refItem], for: .sourceInstanceSequence)

        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)
        XCTAssertEqual(doc.sourceInstances.count, 1)
        XCTAssertEqual(doc.sourceInstances[0].referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(doc.sourceInstances[0].referencedSOPInstanceUID, "1.2.3.4.5.6.7")
    }

    func test_parser_parsesHL7InstanceIdentifier() throws {
        var dataSet = makeMinimalDataSet()
        dataSet.setString("2.16.840.1.113883.19.999.1", for: .hl7InstanceIdentifier, vr: .ST)

        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)
        XCTAssertEqual(doc.hl7InstanceIdentifier, "2.16.840.1.113883.19.999.1")
    }

    func test_parser_parsesCDADocument() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedCDAStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("text/xml", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        let cdaData = "<ClinicalDocument/>".data(using: .utf8)!
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: cdaData)

        let doc = try EncapsulatedDocumentParser.parse(from: dataSet)
        XCTAssertTrue(doc.isCDA)
        XCTAssertEqual(doc.mimeType, "text/xml")
        XCTAssertEqual(doc.documentType, .cda)
    }

    // MARK: - Builder Tests

    func test_builder_buildsMinimalDocument() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        ).build()

        XCTAssertFalse(doc.sopInstanceUID.isEmpty)
        XCTAssertEqual(doc.sopClassUID, EncapsulatedDocument.encapsulatedPDFStorageUID)
        XCTAssertEqual(doc.studyInstanceUID, "1.2.3")
        XCTAssertEqual(doc.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(doc.mimeType, "application/pdf")
        XCTAssertEqual(doc.documentData, pdfData)
        XCTAssertTrue(doc.isPDF)
    }

    func test_builder_buildsFullDocument() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5.99")
        .setInstanceNumber(1)
        .setPatientName("Doe^Jane")
        .setPatientID("67890")
        .setDocumentTitle("Chest X-Ray Report")
        .setModality("DOC")
        .setSeriesDescription("Clinical Reports")
        .setSeriesNumber(1)
        .setConceptNameCode(
            codeValue: "18782-3",
            codingSchemeDesignator: "LN",
            codeMeaning: "Radiology Study observation"
        )
        .addSourceInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6"
        )
        .build()

        XCTAssertEqual(doc.sopInstanceUID, "1.2.3.4.5.99")
        XCTAssertEqual(doc.instanceNumber, 1)
        XCTAssertEqual(doc.patientName, "Doe^Jane")
        XCTAssertEqual(doc.patientID, "67890")
        XCTAssertEqual(doc.documentTitle, "Chest X-Ray Report")
        XCTAssertEqual(doc.modality, "DOC")
        XCTAssertEqual(doc.seriesDescription, "Clinical Reports")
        XCTAssertEqual(doc.seriesNumber, 1)
        XCTAssertNotNil(doc.conceptNameCode)
        XCTAssertEqual(doc.conceptNameCode?.codeValue, "18782-3")
        XCTAssertEqual(doc.sourceInstances.count, 1)
    }

    func test_builder_failsWithEmptyDocumentData() {
        XCTAssertThrowsError(try EncapsulatedDocumentBuilder(
            documentData: Data(),
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        ).build())
    }

    func test_builder_failsWithEmptyMIMEType() {
        XCTAssertThrowsError(try EncapsulatedDocumentBuilder(
            documentData: Data([0x25]),
            mimeType: "",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        ).build())
    }

    func test_builder_buildsCDADocument() throws {
        let cdaData = "<ClinicalDocument/>".data(using: .utf8)!
        let doc = try EncapsulatedDocumentBuilder(
            documentData: cdaData,
            mimeType: "text/xml",
            documentType: .cda,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setHL7InstanceIdentifier("2.16.840.1.113883.19.999.1")
        .build()

        XCTAssertTrue(doc.isCDA)
        XCTAssertEqual(doc.hl7InstanceIdentifier, "2.16.840.1.113883.19.999.1")
        XCTAssertEqual(doc.mimeType, "text/xml")
    }

    func test_builder_generatesUniqueSOPInstanceUID() throws {
        let data = Data([0x25])
        let doc1 = try EncapsulatedDocumentBuilder(
            documentData: data,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        ).build()

        let doc2 = try EncapsulatedDocumentBuilder(
            documentData: data,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        ).build()

        XCTAssertNotEqual(doc1.sopInstanceUID, doc2.sopInstanceUID)
    }

    // MARK: - DataSet Conversion (toDataSet) Tests

    func test_toDataSet_containsRequiredAttributes() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5")
        .build()

        let dataSet = doc.toDataSet()

        XCTAssertEqual(dataSet.string(for: .sopClassUID), EncapsulatedDocument.encapsulatedPDFStorageUID)
        XCTAssertEqual(dataSet.string(for: .sopInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), "1.2.3")
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), "1.2.3.4")
        XCTAssertEqual(dataSet.string(for: .mimeTypeOfEncapsulatedDocument), "application/pdf")

        // Check document data element exists
        let docElement = dataSet[.encapsulatedDocument]
        XCTAssertNotNil(docElement)
        XCTAssertFalse(docElement!.valueData.isEmpty)
    }

    func test_toDataSet_containsOptionalAttributes() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setPatientName("Doe^Jane")
        .setPatientID("12345")
        .setDocumentTitle("Report")
        .setModality("DOC")
        .setSeriesDescription("Reports")
        .build()

        let dataSet = doc.toDataSet()

        XCTAssertEqual(dataSet.string(for: .patientName), "Doe^Jane")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(dataSet.string(for: .documentTitle), "Report")
        XCTAssertEqual(dataSet.string(for: .modality), "DOC")
        XCTAssertEqual(dataSet.string(for: .seriesDescription), "Reports")
    }

    func test_toDataSet_containsConceptNameCodeSequence() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setConceptNameCode(
            codeValue: "18782-3",
            codingSchemeDesignator: "LN",
            codeMeaning: "Radiology Study observation"
        )
        .build()

        let dataSet = doc.toDataSet()

        let items = dataSet.sequence(for: .conceptNameCodeSequence)
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 1)
    }

    func test_toDataSet_containsSourceInstanceSequence() throws {
        let pdfData = makeSamplePDFData()
        let doc = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .addSourceInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6"
        )
        .build()

        let dataSet = doc.toDataSet()

        let items = dataSet.sequence(for: .sourceInstanceSequence)
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 1)
    }

    // MARK: - Round-Trip Tests

    func test_roundTrip_buildParseProducesEquivalentDocument() throws {
        let pdfData = makeSamplePDFData()
        let original = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5")
        .setPatientName("Smith^John")
        .setPatientID("12345")
        .setDocumentTitle("Test Report")
        .setModality("DOC")
        .build()

        // Convert to DataSet, then parse back
        let dataSet = original.toDataSet()
        let parsed = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertEqual(parsed.sopInstanceUID, original.sopInstanceUID)
        XCTAssertEqual(parsed.sopClassUID, original.sopClassUID)
        XCTAssertEqual(parsed.studyInstanceUID, original.studyInstanceUID)
        XCTAssertEqual(parsed.seriesInstanceUID, original.seriesInstanceUID)
        XCTAssertEqual(parsed.mimeType, original.mimeType)
        XCTAssertEqual(parsed.patientName, original.patientName)
        XCTAssertEqual(parsed.patientID, original.patientID)
        XCTAssertEqual(parsed.documentTitle, original.documentTitle)
        XCTAssertEqual(parsed.modality, original.modality)
        // Document data may have padding byte due to DICOM even-length rule
        XCTAssertTrue(parsed.documentData.starts(with: original.documentData))
    }

    func test_roundTrip_cdaDocument() throws {
        let cdaData = "<ClinicalDocument xmlns='urn:hl7-org:v3'></ClinicalDocument>".data(using: .utf8)!
        let original = try EncapsulatedDocumentBuilder(
            documentData: cdaData,
            mimeType: "text/xml",
            documentType: .cda,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5.cda")
        .setHL7InstanceIdentifier("2.16.840.1.113883.19.999.1")
        .build()

        let dataSet = original.toDataSet()
        let parsed = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertEqual(parsed.sopClassUID, EncapsulatedDocument.encapsulatedCDAStorageUID)
        XCTAssertEqual(parsed.mimeType, "text/xml")
        XCTAssertEqual(parsed.hl7InstanceIdentifier, "2.16.840.1.113883.19.999.1")
        XCTAssertTrue(parsed.isCDA)
    }

    func test_roundTrip_withConceptNameCode() throws {
        let pdfData = makeSamplePDFData()
        let original = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5.code")
        .setConceptNameCode(
            codeValue: "18782-3",
            codingSchemeDesignator: "LN",
            codeMeaning: "Radiology Study observation"
        )
        .build()

        let dataSet = original.toDataSet()
        let parsed = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertNotNil(parsed.conceptNameCode)
        XCTAssertEqual(parsed.conceptNameCode?.codeValue, "18782-3")
        XCTAssertEqual(parsed.conceptNameCode?.codingSchemeDesignator, "LN")
        XCTAssertEqual(parsed.conceptNameCode?.codeMeaning, "Radiology Study observation")
    }

    func test_roundTrip_withSourceInstances() throws {
        let pdfData = makeSamplePDFData()
        let original = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5.src")
        .addSourceInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7"
        )
        .addSourceInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.4",
            sopInstanceUID: "1.2.3.4.5.6.8"
        )
        .build()

        let dataSet = original.toDataSet()
        let parsed = try EncapsulatedDocumentParser.parse(from: dataSet)

        XCTAssertEqual(parsed.sourceInstances.count, 2)
        XCTAssertEqual(parsed.sourceInstances[0].referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(parsed.sourceInstances[0].referencedSOPInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertEqual(parsed.sourceInstances[1].referencedSOPClassUID, "1.2.840.10008.5.1.4.1.1.4")
        XCTAssertEqual(parsed.sourceInstances[1].referencedSOPInstanceUID, "1.2.3.4.5.6.8")
    }

    // MARK: - BuildDataSet Tests

    func test_builder_buildDataSet() throws {
        let pdfData = makeSamplePDFData()
        let dataSet = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setDocumentTitle("Direct DataSet Test")
        .buildDataSet()

        XCTAssertEqual(dataSet.string(for: .sopClassUID), EncapsulatedDocument.encapsulatedPDFStorageUID)
        XCTAssertEqual(dataSet.string(for: .mimeTypeOfEncapsulatedDocument), "application/pdf")
        XCTAssertEqual(dataSet.string(for: .documentTitle), "Direct DataSet Test")
    }

    // MARK: - DICOM File Creation Test

    func test_createDICOMFile_withEncapsulatedPDF() throws {
        let pdfData = makeSamplePDFData()
        let dataSet = try EncapsulatedDocumentBuilder(
            documentData: pdfData,
            mimeType: "application/pdf",
            documentType: .pdf,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        .setSOPInstanceUID("1.2.3.4.5.file")
        .buildDataSet()

        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: EncapsulatedDocument.encapsulatedPDFStorageUID,
            sopInstanceUID: "1.2.3.4.5.file"
        )

        // Verify the DICOM file has correct meta information
        XCTAssertEqual(
            dicomFile.fileMetaInformation.string(for: .mediaStorageSOPClassUID),
            EncapsulatedDocument.encapsulatedPDFStorageUID
        )

        // Verify it can be serialized
        let fileData = try dicomFile.write()
        XCTAssertFalse(fileData.isEmpty)
        XCTAssertTrue(fileData.count > 132) // At least preamble + prefix
    }

    // MARK: - Tag Tests

    func test_tags_encapsulatedDocument() {
        XCTAssertEqual(Tag.encapsulatedDocument.group, 0x0042)
        XCTAssertEqual(Tag.encapsulatedDocument.element, 0x0011)
    }

    func test_tags_mimeTypeOfEncapsulatedDocument() {
        XCTAssertEqual(Tag.mimeTypeOfEncapsulatedDocument.group, 0x0042)
        XCTAssertEqual(Tag.mimeTypeOfEncapsulatedDocument.element, 0x0012)
    }

    func test_tags_documentTitle() {
        XCTAssertEqual(Tag.documentTitle.group, 0x0042)
        XCTAssertEqual(Tag.documentTitle.element, 0x0010)
    }

    func test_tags_sourceInstanceSequence() {
        XCTAssertEqual(Tag.sourceInstanceSequence.group, 0x0042)
        XCTAssertEqual(Tag.sourceInstanceSequence.element, 0x0013)
    }

    func test_tags_hl7InstanceIdentifier() {
        XCTAssertEqual(Tag.hl7InstanceIdentifier.group, 0x0040)
        XCTAssertEqual(Tag.hl7InstanceIdentifier.element, 0xE001)
    }

    // MARK: - Helpers

    private func makeDocument(
        sopClassUID: String = EncapsulatedDocument.encapsulatedPDFStorageUID,
        documentData: Data = Data([0x25, 0x50, 0x44, 0x46])
    ) -> EncapsulatedDocument {
        EncapsulatedDocument(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: sopClassUID,
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            mimeType: "application/pdf",
            documentData: documentData
        )
    }

    private func makeSamplePDFData() -> Data {
        // Minimal PDF-like data (starts with %PDF)
        return "%PDF-1.4 test document".data(using: .utf8)!
    }

    private func makeMinimalDataSet() -> DataSet {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(EncapsulatedDocument.encapsulatedPDFStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4", for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("application/pdf", for: .mimeTypeOfEncapsulatedDocument, vr: .LO)
        let pdfData = makeSamplePDFData()
        dataSet[.encapsulatedDocument] = DataElement.data(tag: .encapsulatedDocument, vr: .OB, data: pdfData)
        return dataSet
    }

    private func makeFullDataSet() -> DataSet {
        var dataSet = makeMinimalDataSet()
        dataSet.setString("Smith^John", for: .patientName, vr: .PN)
        dataSet.setString("12345", for: .patientID, vr: .LO)
        dataSet.setString("Radiology Report", for: .documentTitle, vr: .ST)
        dataSet.setString("DOC", for: .modality, vr: .CS)
        dataSet.setString("Reports", for: .seriesDescription, vr: .LO)
        return dataSet
    }
}
