// EncapsulatedDocumentHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Encapsulated Document Helpers Tests")
struct EncapsulatedDocumentHelpersTests {

    // MARK: - documentType(for mimeType:)

    @Test("documentType PDF MIME maps to .pdf")
    func testDocumentTypePDFMime() {
        let type = EncapsulatedDocumentHelpers.documentType(for: "application/pdf")
        #expect(type == .pdf)
    }

    @Test("documentType STL MIME maps to .stl")
    func testDocumentTypeSTLMime() {
        let type = EncapsulatedDocumentHelpers.documentType(for: "model/stl")
        #expect(type == .stl)
    }

    @Test("documentType application/sla MIME maps to .stl")
    func testDocumentTypeSLAMime() {
        let type = EncapsulatedDocumentHelpers.documentType(for: "application/sla")
        #expect(type == .stl)
    }

    @Test("documentType XML MIME maps to .cda")
    func testDocumentTypeCDAMime() {
        let type = EncapsulatedDocumentHelpers.documentType(for: "text/xml")
        #expect(type == .cda)
    }

    @Test("documentType unknown MIME maps to .unknown")
    func testDocumentTypeUnknownMime() {
        let type = EncapsulatedDocumentHelpers.documentType(for: "application/zip")
        #expect(type == .unknown)
    }

    // MARK: - documentType(for sopClassUID:)

    @Test("documentType PDF SOP Class UID maps to .pdf")
    func testDocumentTypePDFSopClassUID() {
        let type = EncapsulatedDocumentHelpers.documentTypeForSopClassUID("1.2.840.10008.5.1.4.1.1.104.1")
        #expect(type == .pdf)
    }

    @Test("documentType STL SOP Class UID maps to .stl")
    func testDocumentTypeSTLSopClassUID() {
        let type = EncapsulatedDocumentHelpers.documentTypeForSopClassUID("1.2.840.10008.5.1.4.1.1.104.3")
        #expect(type == .stl)
    }

    @Test("documentType unknown SOP Class UID maps to .unknown")
    func testDocumentTypeUnknownSopClassUID() {
        let type = EncapsulatedDocumentHelpers.documentTypeForSopClassUID("1.2.3.4")
        #expect(type == .unknown)
    }

    // MARK: - formattedFileSize

    @Test("formattedFileSize for less than 1KB returns bytes")
    func testFormattedFileSizeBytes() {
        let s = EncapsulatedDocumentHelpers.formattedFileSize(512)
        #expect(s.contains("bytes"))
    }

    @Test("formattedFileSize for between 1KB and 1MB returns KB")
    func testFormattedFileSizeKB() {
        let s = EncapsulatedDocumentHelpers.formattedFileSize(10_240)
        #expect(s.contains("KB"))
    }

    @Test("formattedFileSize for 1MB and above returns MB")
    func testFormattedFileSizeMB() {
        let s = EncapsulatedDocumentHelpers.formattedFileSize(5_000_000)
        #expect(s.contains("MB"))
    }

    // MARK: - pageDescription

    @Test("pageDescription returns page 1 of 3 for page 0 with 3 pages")
    func testPageDescriptionFirstPage() {
        let desc = EncapsulatedDocumentHelpers.pageDescription(currentPage: 0, totalPages: 3)
        #expect(desc == "Page 1 of 3")
    }

    @Test("pageDescription returns No pages for zero total")
    func testPageDescriptionNoPages() {
        let desc = EncapsulatedDocumentHelpers.pageDescription(currentPage: 0, totalPages: 0)
        #expect(desc == "No pages")
    }

    // MARK: - canDisplay

    @Test("canDisplay returns true for PDF")
    func testCanDisplayPDF() {
        #expect(EncapsulatedDocumentHelpers.canDisplay(.pdf))
    }

    @Test("canDisplay returns false for unknown")
    func testCanDisplayUnknown() {
        #expect(!EncapsulatedDocumentHelpers.canDisplay(.unknown))
    }

    // MARK: - defaultZoom

    @Test("defaultZoom returns 1.0 for PDF")
    func testDefaultZoomPDF() {
        #expect(EncapsulatedDocumentHelpers.defaultZoom(for: .pdf) == 1.0)
    }

    @Test("defaultZoom returns 0.8 for STL")
    func testDefaultZoomSTL() {
        #expect(EncapsulatedDocumentHelpers.defaultZoom(for: .stl) == 0.8)
    }
}
