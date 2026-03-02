// StructuredReportServiceTests.swift
// DICOMStudioTests
//
// Tests for StructuredReportService (Milestone 7)

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - StructuredReportService Tests

@Suite("StructuredReportService Tests")
struct StructuredReportServiceTests {

    // MARK: - Helpers

    private func makeDocument(type: SRDocumentType = .basicText, title: String = "Test") -> SRDocument {
        let titleConcept = CodedConcept(
            codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: title
        )
        return SRDocument(documentType: type, title: titleConcept)
    }

    private func makeEntry(code: String = "1", meaning: String = "Test") -> TerminologyEntry {
        TerminologyEntry(
            concept: CodedConcept(
                codeValue: code, codingSchemeDesignator: "SCT", codeMeaning: meaning
            )
        )
    }

    private func makeFinding(type: CADFindingType = .mass, confidence: Double = 0.8) -> CADFinding {
        CADFinding(findingType: type, confidence: confidence)
    }

    // MARK: - Document Management

    @Test("Initial state has no documents")
    func testInitialState() {
        let service = StructuredReportService()
        #expect(service.documents.isEmpty)
        #expect(service.selectedDocument == nil)
        #expect(service.selectedDocumentIndex == nil)
        #expect(service.documentCount == 0)
    }

    @Test("addDocument increases count")
    func testAddDocument() {
        let service = StructuredReportService()
        service.addDocument(makeDocument())
        #expect(service.documentCount == 1)
    }

    @Test("selectDocument sets index")
    func testSelectDocument() {
        let service = StructuredReportService()
        service.addDocument(makeDocument(title: "A"))
        service.addDocument(makeDocument(title: "B"))
        service.selectDocument(at: 1)
        #expect(service.selectedDocumentIndex == 1)
        #expect(service.selectedDocument?.title.codeMeaning == "B")
    }

    @Test("selectDocument out of bounds does nothing")
    func testSelectOutOfBounds() {
        let service = StructuredReportService()
        service.addDocument(makeDocument())
        service.selectDocument(at: 5)
        #expect(service.selectedDocumentIndex == nil)
    }

    @Test("removeDocument removes and adjusts selection")
    func testRemoveDocument() {
        let service = StructuredReportService()
        service.addDocument(makeDocument(title: "A"))
        service.addDocument(makeDocument(title: "B"))
        service.addDocument(makeDocument(title: "C"))
        service.selectDocument(at: 2)
        service.removeDocument(at: 0)
        #expect(service.documentCount == 2)
        #expect(service.selectedDocumentIndex == 1)
    }

    @Test("removeDocument clears selection when selected is removed")
    func testRemoveSelectedDocument() {
        let service = StructuredReportService()
        service.addDocument(makeDocument())
        service.selectDocument(at: 0)
        service.removeDocument(at: 0)
        #expect(service.selectedDocumentIndex == nil)
    }

    @Test("removeDocument out of bounds does nothing")
    func testRemoveOutOfBounds() {
        let service = StructuredReportService()
        service.addDocument(makeDocument())
        service.removeDocument(at: 5)
        #expect(service.documentCount == 1)
    }

    @Test("clearSelection clears index")
    func testClearSelection() {
        let service = StructuredReportService()
        service.addDocument(makeDocument())
        service.selectDocument(at: 0)
        service.clearSelection()
        #expect(service.selectedDocumentIndex == nil)
    }

    @Test("replaceDocument updates document")
    func testReplaceDocument() {
        let service = StructuredReportService()
        service.addDocument(makeDocument(title: "Old"))
        service.replaceDocument(at: 0, with: makeDocument(title: "New"))
        #expect(service.documents[0].title.codeMeaning == "New")
    }

    @Test("replaceDocument out of bounds does nothing")
    func testReplaceOutOfBounds() {
        let service = StructuredReportService()
        service.addDocument(makeDocument(title: "A"))
        service.replaceDocument(at: 5, with: makeDocument(title: "B"))
        #expect(service.documents[0].title.codeMeaning == "A")
    }

    // MARK: - Search

    @Test("setSearchQuery updates query")
    func testSetSearchQuery() {
        let service = StructuredReportService()
        service.setSearchQuery("test")
        #expect(service.searchQuery == "test")
    }

    @Test("search with selected document finds results")
    func testSearchWithDocument() {
        let service = StructuredReportService()
        let child = SRContentItem(valueType: .text, textValue: "Pneumonia finding")
        let root = SRContentItem(
            valueType: .container,
            continuityOfContent: .separate,
            children: [child]
        )
        let title = CodedConcept(codeValue: "1", codingSchemeDesignator: "DCM", codeMeaning: "Report")
        let doc = SRDocument(documentType: .basicText, title: title, rootContentItem: root)
        service.addDocument(doc)
        service.selectDocument(at: 0)
        service.setSearchQuery("pneumonia")
        #expect(!service.searchResults.isEmpty)
    }

    @Test("search without selected document returns empty")
    func testSearchNoDocument() {
        let service = StructuredReportService()
        service.setSearchQuery("test")
        #expect(service.searchResults.isEmpty)
    }

    // MARK: - Terminology Management

    @Test("recordRecentTerm adds to recent list")
    func testRecordRecentTerm() {
        let service = StructuredReportService()
        let entry = makeEntry()
        service.recordRecentTerm(entry)
        #expect(service.recentTerms.count == 1)
    }

    @Test("recordRecentTerm avoids duplicates")
    func testRecordRecentTermNoDuplicates() {
        let service = StructuredReportService()
        let entry = makeEntry(code: "1", meaning: "Test")
        service.recordRecentTerm(entry)
        service.recordRecentTerm(entry)
        #expect(service.recentTerms.count == 1)
    }

    @Test("recordRecentTerm moves to front")
    func testRecordRecentTermMovesToFront() {
        let service = StructuredReportService()
        let entry1 = makeEntry(code: "1", meaning: "First")
        let entry2 = makeEntry(code: "2", meaning: "Second")
        service.recordRecentTerm(entry1)
        service.recordRecentTerm(entry2)
        #expect(service.recentTerms[0].concept.codeValue == "2")
    }

    @Test("toggleFavorite adds and removes")
    func testToggleFavorite() {
        let service = StructuredReportService()
        let entry = makeEntry()
        service.toggleFavorite(entry)
        #expect(service.favoriteTerms.count == 1)
        #expect(service.isFavorite(entry.concept))

        service.toggleFavorite(entry)
        #expect(service.favoriteTerms.isEmpty)
        #expect(!service.isFavorite(entry.concept))
    }

    // MARK: - CAD Findings

    @Test("setCADFindings sets findings")
    func testSetCADFindings() {
        let service = StructuredReportService()
        let findings = [makeFinding(), makeFinding(type: .nodule)]
        service.setCADFindings(findings)
        #expect(service.cadFindings.count == 2)
    }

    @Test("selectCADFinding sets selection")
    func testSelectCADFinding() {
        let service = StructuredReportService()
        let finding = makeFinding()
        service.setCADFindings([finding])
        service.selectCADFinding(finding.id)
        #expect(service.selectedCADFindingID == finding.id)
        #expect(service.selectedCADFinding?.findingType == .mass)
    }

    @Test("updateCADFindingStatus changes status")
    func testUpdateCADFindingStatus() {
        let service = StructuredReportService()
        let finding = makeFinding()
        service.setCADFindings([finding])
        service.updateCADFindingStatus(finding.id, status: .accepted)
        #expect(service.cadFindings[0].status == .accepted)
    }

    @Test("setCADFindings clears selection")
    func testSetFindingsClearsSelection() {
        let service = StructuredReportService()
        let finding = makeFinding()
        service.setCADFindings([finding])
        service.selectCADFinding(finding.id)
        service.setCADFindings([])
        #expect(service.selectedCADFindingID == nil)
    }

    // MARK: - Builder State

    @Test("Default builder state")
    func testDefaultBuilderState() {
        let service = StructuredReportService()
        #expect(service.builderDocumentType == .basicText)
        #expect(service.builderTemplate == nil)
        #expect(service.builderMode == .template)
    }

    @Test("setBuilderDocumentType changes type")
    func testSetBuilderDocumentType() {
        let service = StructuredReportService()
        service.setBuilderDocumentType(.mammographyCAD)
        #expect(service.builderDocumentType == .mammographyCAD)
    }

    @Test("setBuilderTemplate changes template")
    func testSetBuilderTemplate() {
        let service = StructuredReportService()
        service.setBuilderTemplate(.radiologyReport)
        #expect(service.builderTemplate == .radiologyReport)
    }

    @Test("setBuilderMode changes mode")
    func testSetBuilderMode() {
        let service = StructuredReportService()
        service.setBuilderMode(.freeForm)
        #expect(service.builderMode == .freeForm)
    }
}
