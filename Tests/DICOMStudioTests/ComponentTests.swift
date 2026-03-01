// ComponentTests.swift
// DICOMStudioTests
//
// Tests for platform-independent component helpers:
// ModalityMapping, VRDescriptions, DICOMTagFormatter

import Testing
@testable import DICOMStudio
import Foundation

// MARK: - ModalityMapping Tests

@Suite("ModalityMapping Tests")
struct ModalityMappingTests {

    // MARK: - systemImage(for:)

    @Test("CT maps to cylinder symbol")
    func testSystemImageCT() {
        #expect(ModalityMapping.systemImage(for: "CT") == "cylinder.split.1x2")
    }

    @Test("MR maps to brain symbol")
    func testSystemImageMR() {
        #expect(ModalityMapping.systemImage(for: "MR") == "brain.head.profile")
    }

    @Test("MRI alias maps to brain symbol")
    func testSystemImageMRI() {
        #expect(ModalityMapping.systemImage(for: "MRI") == "brain.head.profile")
    }

    @Test("US maps to waveform symbol")
    func testSystemImageUS() {
        #expect(ModalityMapping.systemImage(for: "US") == "waveform.path.ecg")
    }

    @Test("CR maps to xray symbol")
    func testSystemImageCR() {
        #expect(ModalityMapping.systemImage(for: "CR") == "xray")
    }

    @Test("DX maps to xray symbol")
    func testSystemImageDX() {
        #expect(ModalityMapping.systemImage(for: "DX") == "xray")
    }

    @Test("NM maps to atom symbol")
    func testSystemImageNM() {
        #expect(ModalityMapping.systemImage(for: "NM") == "atom")
    }

    @Test("PT maps to sparkles symbol")
    func testSystemImagePT() {
        #expect(ModalityMapping.systemImage(for: "PT") == "sparkles")
    }

    @Test("PET alias maps to sparkles symbol")
    func testSystemImagePET() {
        #expect(ModalityMapping.systemImage(for: "PET") == "sparkles")
    }

    @Test("MG maps to rectangle symbol")
    func testSystemImageMG() {
        #expect(ModalityMapping.systemImage(for: "MG") == "rectangle.compress.vertical")
    }

    @Test("RF maps to film symbol")
    func testSystemImageRF() {
        #expect(ModalityMapping.systemImage(for: "RF") == "film")
    }

    @Test("XA maps to heart symbol")
    func testSystemImageXA() {
        #expect(ModalityMapping.systemImage(for: "XA") == "heart")
    }

    @Test("SC maps to camera symbol")
    func testSystemImageSC() {
        #expect(ModalityMapping.systemImage(for: "SC") == "camera")
    }

    @Test("OT maps to questionmark symbol")
    func testSystemImageOT() {
        #expect(ModalityMapping.systemImage(for: "OT") == "questionmark.square")
    }

    @Test("SR maps to doc.text symbol")
    func testSystemImageSR() {
        #expect(ModalityMapping.systemImage(for: "SR") == "doc.text")
    }

    @Test("PR maps to paintbrush symbol")
    func testSystemImagePR() {
        #expect(ModalityMapping.systemImage(for: "PR") == "paintbrush")
    }

    @Test("KO maps to key symbol")
    func testSystemImageKO() {
        #expect(ModalityMapping.systemImage(for: "KO") == "key")
    }

    @Test("SEG maps to dashed square symbol")
    func testSystemImageSEG() {
        #expect(ModalityMapping.systemImage(for: "SEG") == "square.on.square.dashed")
    }

    @Test("RT modalities map to target symbol")
    func testSystemImageRT() {
        let rtModalities = ["RT", "RTPLAN", "RTDOSE", "RTSTRUCT"]
        for mod in rtModalities {
            #expect(ModalityMapping.systemImage(for: mod) == "target", "Expected target for \(mod)")
        }
    }

    @Test("ECG maps to ecg rectangle symbol")
    func testSystemImageECG() {
        #expect(ModalityMapping.systemImage(for: "ECG") == "waveform.path.ecg.rectangle")
    }

    @Test("HD maps to waveform symbol")
    func testSystemImageHD() {
        #expect(ModalityMapping.systemImage(for: "HD") == "waveform")
    }

    @Test("IO maps to mouth symbol")
    func testSystemImageIO() {
        #expect(ModalityMapping.systemImage(for: "IO") == "mouth")
    }

    @Test("OP maps to eye symbol")
    func testSystemImageOP() {
        #expect(ModalityMapping.systemImage(for: "OP") == "eye")
    }

    @Test("DOC maps to richtext symbol")
    func testSystemImageDOC() {
        #expect(ModalityMapping.systemImage(for: "DOC") == "doc.richtext")
    }

    @Test("PDF maps to richtext symbol")
    func testSystemImagePDF() {
        #expect(ModalityMapping.systemImage(for: "PDF") == "doc.richtext")
    }

    @Test("VL maps to video symbol")
    func testSystemImageVL() {
        #expect(ModalityMapping.systemImage(for: "VL") == "video")
    }

    @Test("Unknown modality returns grid symbol")
    func testSystemImageUnknown() {
        #expect(ModalityMapping.systemImage(for: "ZZ") == "square.grid.2x2")
    }

    @Test("Case insensitive mapping")
    func testSystemImageCaseInsensitive() {
        #expect(ModalityMapping.systemImage(for: "ct") == ModalityMapping.systemImage(for: "CT"))
        #expect(ModalityMapping.systemImage(for: "mr") == ModalityMapping.systemImage(for: "MR"))
        #expect(ModalityMapping.systemImage(for: "us") == ModalityMapping.systemImage(for: "US"))
    }

    @Test("All mapped modalities return non-empty strings")
    func testAllMappingsNonEmpty() {
        let modalities = ["CT", "MR", "MRI", "US", "CR", "DX", "NM", "PT", "PET",
                          "MG", "RF", "XA", "SC", "OT", "SR", "PR", "KO", "SEG",
                          "RT", "RTPLAN", "RTDOSE", "RTSTRUCT", "ECG", "HD", "IO",
                          "OP", "DOC", "PDF", "VL"]
        for mod in modalities {
            #expect(!ModalityMapping.systemImage(for: mod).isEmpty, "Empty image for \(mod)")
        }
    }

    // MARK: - fullName(for:)

    @Test("CT full name is Computed Tomography")
    func testFullNameCT() {
        #expect(ModalityMapping.fullName(for: "CT") == "Computed Tomography")
    }

    @Test("MR full name is Magnetic Resonance")
    func testFullNameMR() {
        #expect(ModalityMapping.fullName(for: "MR") == "Magnetic Resonance")
    }

    @Test("MRI alias full name is Magnetic Resonance")
    func testFullNameMRI() {
        #expect(ModalityMapping.fullName(for: "MRI") == "Magnetic Resonance")
    }

    @Test("US full name is Ultrasound")
    func testFullNameUS() {
        #expect(ModalityMapping.fullName(for: "US") == "Ultrasound")
    }

    @Test("CR full name is Computed Radiography")
    func testFullNameCR() {
        #expect(ModalityMapping.fullName(for: "CR") == "Computed Radiography")
    }

    @Test("DX full name is Digital Radiography")
    func testFullNameDX() {
        #expect(ModalityMapping.fullName(for: "DX") == "Digital Radiography")
    }

    @Test("NM full name is Nuclear Medicine")
    func testFullNameNM() {
        #expect(ModalityMapping.fullName(for: "NM") == "Nuclear Medicine")
    }

    @Test("PT full name is Positron Emission Tomography")
    func testFullNamePT() {
        #expect(ModalityMapping.fullName(for: "PT") == "Positron Emission Tomography")
    }

    @Test("PET alias full name is Positron Emission Tomography")
    func testFullNamePET() {
        #expect(ModalityMapping.fullName(for: "PET") == "Positron Emission Tomography")
    }

    @Test("All RT modalities return Radiation Therapy")
    func testFullNameRT() {
        let rtModalities = ["RT", "RTPLAN", "RTDOSE", "RTSTRUCT"]
        for mod in rtModalities {
            #expect(ModalityMapping.fullName(for: mod) == "Radiation Therapy", "Expected Radiation Therapy for \(mod)")
        }
    }

    @Test("Unknown modality returns uppercased code")
    func testFullNameUnknown() {
        #expect(ModalityMapping.fullName(for: "abc") == "ABC")
    }

    @Test("Full name case insensitive")
    func testFullNameCaseInsensitive() {
        #expect(ModalityMapping.fullName(for: "ct") == ModalityMapping.fullName(for: "CT"))
    }

    @Test("All standard modality full names are non-empty")
    func testAllFullNamesNonEmpty() {
        let modalities = ["CT", "MR", "US", "CR", "DX", "NM", "PT", "MG", "RF",
                          "XA", "SC", "OT", "SR", "PR", "KO", "SEG", "RT", "ECG",
                          "HD", "IO", "OP", "DOC", "PDF", "VL"]
        for mod in modalities {
            #expect(!ModalityMapping.fullName(for: mod).isEmpty, "Empty name for \(mod)")
        }
    }
}

// MARK: - VRDescriptions Tests

@Suite("VRDescriptions Tests")
struct VRDescriptionsTests {

    // MARK: - fullName(for:)

    @Test("String VR full names")
    func testStringVRFullNames() {
        #expect(VRDescriptions.fullName(for: "PN") == "Person Name")
        #expect(VRDescriptions.fullName(for: "LO") == "Long String")
        #expect(VRDescriptions.fullName(for: "SH") == "Short String")
        #expect(VRDescriptions.fullName(for: "CS") == "Code String")
        #expect(VRDescriptions.fullName(for: "LT") == "Long Text")
        #expect(VRDescriptions.fullName(for: "ST") == "Short Text")
        #expect(VRDescriptions.fullName(for: "UT") == "Unlimited Text")
        #expect(VRDescriptions.fullName(for: "UC") == "Unlimited Characters")
    }

    @Test("Identifier VR full names")
    func testIdentifierVRFullNames() {
        #expect(VRDescriptions.fullName(for: "UI") == "Unique Identifier")
        #expect(VRDescriptions.fullName(for: "AE") == "Application Entity")
    }

    @Test("Date/time VR full names")
    func testDateTimeVRFullNames() {
        #expect(VRDescriptions.fullName(for: "DA") == "Date")
        #expect(VRDescriptions.fullName(for: "TM") == "Time")
        #expect(VRDescriptions.fullName(for: "DT") == "Date Time")
    }

    @Test("Numeric VR full names")
    func testNumericVRFullNames() {
        #expect(VRDescriptions.fullName(for: "IS") == "Integer String")
        #expect(VRDescriptions.fullName(for: "DS") == "Decimal String")
        #expect(VRDescriptions.fullName(for: "US") == "Unsigned Short")
        #expect(VRDescriptions.fullName(for: "SS") == "Signed Short")
        #expect(VRDescriptions.fullName(for: "UL") == "Unsigned Long")
        #expect(VRDescriptions.fullName(for: "SL") == "Signed Long")
        #expect(VRDescriptions.fullName(for: "FL") == "Floating Point Single")
        #expect(VRDescriptions.fullName(for: "FD") == "Floating Point Double")
    }

    @Test("Binary VR full names")
    func testBinaryVRFullNames() {
        #expect(VRDescriptions.fullName(for: "OB") == "Other Byte")
        #expect(VRDescriptions.fullName(for: "OW") == "Other Word")
        #expect(VRDescriptions.fullName(for: "OF") == "Other Float")
        #expect(VRDescriptions.fullName(for: "OD") == "Other Double")
        #expect(VRDescriptions.fullName(for: "UN") == "Unknown")
    }

    @Test("Sequence VR full name")
    func testSequenceVRFullName() {
        #expect(VRDescriptions.fullName(for: "SQ") == "Sequence")
    }

    @Test("Unknown VR returns uppercased code")
    func testUnknownVRFullName() {
        #expect(VRDescriptions.fullName(for: "xx") == "XX")
        #expect(VRDescriptions.fullName(for: "ZZ") == "ZZ")
    }

    @Test("VR full name is case insensitive")
    func testFullNameCaseInsensitive() {
        #expect(VRDescriptions.fullName(for: "pn") == VRDescriptions.fullName(for: "PN"))
        #expect(VRDescriptions.fullName(for: "ui") == VRDescriptions.fullName(for: "UI"))
    }

    // MARK: - category(for:)

    @Test("String VRs have string category")
    func testStringCategory() {
        let stringVRs = ["PN", "LO", "SH", "CS", "LT", "ST", "UT", "UC"]
        for vr in stringVRs {
            #expect(VRDescriptions.category(for: vr) == "string", "Expected string for \(vr)")
        }
    }

    @Test("Identifier VRs have identifier category")
    func testIdentifierCategory() {
        #expect(VRDescriptions.category(for: "UI") == "identifier")
        #expect(VRDescriptions.category(for: "AE") == "identifier")
    }

    @Test("Date/time VRs have datetime category")
    func testDatetimeCategory() {
        #expect(VRDescriptions.category(for: "DA") == "datetime")
        #expect(VRDescriptions.category(for: "TM") == "datetime")
        #expect(VRDescriptions.category(for: "DT") == "datetime")
    }

    @Test("Numeric VRs have numeric category")
    func testNumericCategory() {
        let numericVRs = ["IS", "DS", "US", "SS", "UL", "SL", "FL", "FD"]
        for vr in numericVRs {
            #expect(VRDescriptions.category(for: vr) == "numeric", "Expected numeric for \(vr)")
        }
    }

    @Test("Binary VRs have binary category")
    func testBinaryCategory() {
        let binaryVRs = ["OB", "OW", "OF", "OD", "UN"]
        for vr in binaryVRs {
            #expect(VRDescriptions.category(for: vr) == "binary", "Expected binary for \(vr)")
        }
    }

    @Test("Sequence VR has sequence category")
    func testSequenceCategory() {
        #expect(VRDescriptions.category(for: "SQ") == "sequence")
    }

    @Test("Unknown VR has other category")
    func testUnknownCategory() {
        #expect(VRDescriptions.category(for: "ZZ") == "other")
        #expect(VRDescriptions.category(for: "XX") == "other")
    }

    @Test("Category is case insensitive")
    func testCategoryCaseInsensitive() {
        #expect(VRDescriptions.category(for: "pn") == VRDescriptions.category(for: "PN"))
        #expect(VRDescriptions.category(for: "sq") == VRDescriptions.category(for: "SQ"))
    }
}

// MARK: - DICOMTagFormatter Tests

@Suite("DICOMTagFormatter Tests")
struct DICOMTagFormatterTests {

    // MARK: - tagString

    @Test("Format patient name tag")
    func testTagStringPatientName() {
        let result = DICOMTagFormatter.tagString(group: 0x0010, element: 0x0010)
        #expect(result == "(0010,0010)")
    }

    @Test("Format SOP Instance UID tag")
    func testTagStringSOPInstanceUID() {
        let result = DICOMTagFormatter.tagString(group: 0x0008, element: 0x0018)
        #expect(result == "(0008,0018)")
    }

    @Test("Format zero tag")
    func testTagStringZero() {
        let result = DICOMTagFormatter.tagString(group: 0x0000, element: 0x0000)
        #expect(result == "(0000,0000)")
    }

    @Test("Format max tag")
    func testTagStringMax() {
        let result = DICOMTagFormatter.tagString(group: 0xFFFF, element: 0xFFFF)
        #expect(result == "(FFFF,FFFF)")
    }

    @Test("Format pixel data tag")
    func testTagStringPixelData() {
        let result = DICOMTagFormatter.tagString(group: 0x7FE0, element: 0x0010)
        #expect(result == "(7FE0,0010)")
    }

    @Test("Format private tag")
    func testTagStringPrivate() {
        let result = DICOMTagFormatter.tagString(group: 0x0009, element: 0x1001)
        #expect(result == "(0009,1001)")
    }

    // MARK: - accessibilityText

    @Test("Accessibility text without keyword")
    func testAccessibilityTextNoKeyword() {
        let result = DICOMTagFormatter.accessibilityText(group: 0x0010, element: 0x0010)
        #expect(result == "Tag group 0010 element 0010")
    }

    @Test("Accessibility text with keyword")
    func testAccessibilityTextWithKeyword() {
        let result = DICOMTagFormatter.accessibilityText(group: 0x0010, element: 0x0010, keyword: "PatientName")
        #expect(result == "PatientName, tag group 0010 element 0010")
    }

    @Test("Accessibility text with nil keyword")
    func testAccessibilityTextNilKeyword() {
        let result = DICOMTagFormatter.accessibilityText(group: 0x0008, element: 0x0060, keyword: nil)
        #expect(result.hasPrefix("Tag group"))
    }

    @Test("Accessibility text for zero tag")
    func testAccessibilityTextZeroTag() {
        let result = DICOMTagFormatter.accessibilityText(group: 0x0000, element: 0x0000)
        #expect(result == "Tag group 0000 element 0000")
    }
}
