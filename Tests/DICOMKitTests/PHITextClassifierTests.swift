import XCTest
import Foundation
import DICOMCore
@testable import DICOMKit

/// Classifier pins (PIXEL_ANONYMIZATION_PIPELINE.md §10.5). The failure direction is
/// the point: anything not provably safe is redacted.
final class PHITextClassifierTests: XCTestCase {

    private func header() -> DataSet {
        var ds = DataSet()
        ds.setString("SMITH^JOHN", for: .patientName, vr: .PN)
        ds.setString("0012345", for: .patientID, vr: .LO)
        ds.setString("19611203", for: .patientBirthDate, vr: .DA)
        ds.setString("20240115", for: .studyDate, vr: .DA)
        ds.setString("ACC4521", for: .accessionNumber, vr: .SH)
        ds.setString("General Hospital", for: .institutionName, vr: .LO)
        ds.setString("DOE^JANE^M", for: .referringPhysicianName, vr: .PN)
        ds.setString("045Y", for: .patientAge, vr: .AS)
        return ds
    }

    private func classifier() -> PHITextClassifier {
        PHITextClassifier(terms: PHITextClassifier.harvestTerms(from: header()))
    }

    // MARK: - Harvest

    func testHarvestCoversNamesIDsDatesInstitutionAndAge() {
        let t = PHITextClassifier.harvestTerms(from: header())
        for expected in ["SMITH", "JOHN", "SMITHJOHN", "JOHNSMITH", "JSMITH", "0012345", "12345",
                         "ACC4521", "GENERALHOSPITAL", "GENERAL", "HOSPITAL", "DOE", "JANE"] {
            XCTAssertTrue(t.identifiers.contains(expected), "missing \(expected) in \(t.identifiers)")
        }
        for expected in ["19611203", "12031961", "03121961", "120361", "3DEC1961", "03DEC1961",
                         "20240115", "01152024", "15012024", "45Y", "045Y"] {
            XCTAssertTrue(t.derived.contains(expected), "missing \(expected) in \(t.derived)")
        }
        XCTAssertFalse(t.derived.contains("45"), "a bare age would match inside any ID")
    }

    func testHarvestIgnoresTooShortTermsThatWouldMatchEverything() {
        var ds = DataSet()
        ds.setString("LI^WU", for: .patientName, vr: .PN)
        ds.setString("7", for: .patientID, vr: .LO)
        let t = PHITextClassifier.harvestTerms(from: ds)
        XCTAssertFalse(t.identifiers.contains("LI"))
        XCTAssertFalse(t.identifiers.contains("7"))
        XCTAssertTrue(t.identifiers.contains("LIWU"), "the joined form still catches the full name")
    }

    // MARK: - Fuzz table

    func testNameVariantsAreRedacted() {
        let c = classifier()
        for text in ["SMITH^JOHN", "John Smith", "SMITH, JOHN", "J. Smith", "J SMITH", "Smith",
                     "SM1TH J0HN", "SMlTH", "SMITH JOHN 45Y", "JOHN SMITH 12/03/1961"] {
            XCTAssertTrue(c.classify(text, confidence: 0.99).isRedact, text)
        }
    }

    func testIDAndDateVariantsAreRedacted() {
        let c = classifier()
        for text in ["0012345", "12345", "MRN 0012345", "ACC4521", "ACC 4521", "12/03/1961", "1961-12-03",
                     "03-DEC-1961", "3 Dec 1961", "19611203", "15/01/2024", "45Y", "General Hospital", "GENERAL H0SPITAL"] {
            XCTAssertTrue(c.classify(text, confidence: 0.99).isRedact, text)
        }
    }

    func testPatternsFireWithoutAnyHeaderTerms() {
        let c = PHITextClassifier()   // no harvest
        for text in ["07/04/1985", "1985-07-04", "04-JUL-1985", "20200101", "987654", "AB123456", "12:34:56", "10:05"] {
            let v = c.classify(text, confidence: 0.99)
            XCTAssertTrue(v.isRedact, text)
            XCTAssertTrue(v.reason.hasPrefix("pattern:"), "\(text): \(v.reason)")
        }
    }

    func testKeywordProximityTaintsTheLine() {
        let c = PHITextClassifier()
        for text in ["Pt: R", "Name: cm", "DOB", "Acc# 12", "MRN", "Dr. L"] {
            let v = c.classify(text, confidence: 0.99)
            XCTAssertTrue(v.isRedact, text)
        }
    }

    // MARK: - Allowlist

    func testAllowlistedClinicalTextIsKept() {
        let c = classifier()
        for text in ["R", "L", "RT", "LT", "10 cm", "120 kVp", "2.5mm", "W 400 L 40", "AXIAL T2", "FOV 24 cm", "1.5T", "100"] {
            let v = c.classify(text, confidence: 0.95)
            XCTAssertFalse(v.isRedact, "\(text): \(v.reason)")
            XCTAssertTrue(v.reason.hasPrefix("allowlist:"), v.reason)
        }
    }

    func testUncertainTextIsRedactedNeverKept() {
        let c = classifier()
        XCTAssertTrue(c.classify("R", confidence: 0.2).isRedact, "low confidence never passes")
        XCTAssertTrue(c.classify("Zebra", confidence: 0.99).isRedact, "unknown word is uncertain")
        XCTAssertTrue(c.classify("", confidence: 0.99).isRedact)
        XCTAssertTrue(c.classify("R cm Zebra", confidence: 0.99).isRedact, "one unknown token taints")
        XCTAssertTrue(c.classify("SMITH R", confidence: 0.99).isRedact, "PHI beats the allowlist")
        XCTAssertTrue(c.classify("123456789", confidence: 0.99).isRedact, "long digit runs are IDs")
    }

    func testMatchedTagsReportEveryAttributeFoundInTextOrder() {
        let c = classifier()
        let r = c.classifyDetailed("SMITH JOHN MRN 0012345 12/03/1961", confidence: 0.99)
        XCTAssertTrue(r.verdict.isRedact)
        XCTAssertEqual(r.matchedTags, [.patientName, .patientID, .patientBirthDate])
        XCTAssertEqual(c.classifyDetailed("R 10 cm", confidence: 0.99).matchedTags, [])
        XCTAssertEqual(c.classifyDetailed("07/04/1985", confidence: 0.99).matchedTags, [], "a bare pattern has no attribute")
        XCTAssertEqual(c.classifyDetailed("SMITH", confidence: 0.1).matchedTags, [], "uncertain never carries a match")
    }

    func testFuzzyMatchingIsBoundedNotUnbounded() {
        // One substitution matches a 5-letter term; three do not.
        XCTAssertTrue(PHITextClassifier.fuzzyContains(haystack: "SMYTH", needle: "SMITH"))
        XCTAssertFalse(PHITextClassifier.fuzzyContains(haystack: "SXYZH", needle: "SMITH"))
        // Short terms need an exact substring.
        XCTAssertFalse(PHITextClassifier.fuzzyContains(haystack: "DOG", needle: "DOE"))
        XCTAssertTrue(PHITextClassifier.fuzzyContains(haystack: "JANEDOE", needle: "DOE"))
    }

    func testDateRenderings() {
        let forms = PHITextClassifier.renderedDateForms("19611203")
        for f in ["19611203", "12/03/1961", "03/12/1961", "1961-12-03", "03-DEC-1961", "3-DEC-1961", "12/3/61", "03.12.1961"] {
            XCTAssertTrue(forms.contains(f), f)
        }
        XCTAssertTrue(PHITextClassifier.renderedDateForms("1961").isEmpty)
    }
}
