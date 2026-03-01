// ImportModelsTests.swift
// DICOMStudioTests
//
// Tests for import-related models

import Testing
@testable import DICOMStudio
import Foundation

@Suite("ImportResult Tests")
struct ImportResultTests {

    @Test("Successful import result")
    func testSuccessfulResult() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.4",
            filePath: "/tmp/test.dcm"
        )
        let result = ImportResult(
            sourceURL: URL(fileURLWithPath: "/tmp/test.dcm"),
            instance: instance
        )
        #expect(result.succeeded)
        #expect(!result.isDuplicate)
        #expect(result.validationIssues.isEmpty)
    }

    @Test("Failed import result")
    func testFailedResult() {
        let result = ImportResult(
            sourceURL: URL(fileURLWithPath: "/tmp/test.dcm"),
            validationIssues: [ValidationIssue(severity: .error, message: "Bad", rule: .fileSize)]
        )
        #expect(!result.succeeded)
        #expect(result.instance == nil)
    }

    @Test("Duplicate import result")
    func testDuplicateResult() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.4",
            filePath: "/tmp/test.dcm"
        )
        let result = ImportResult(
            sourceURL: URL(fileURLWithPath: "/tmp/test.dcm"),
            instance: instance,
            isDuplicate: true
        )
        #expect(result.succeeded)
        #expect(result.isDuplicate)
    }
}

@Suite("ValidationIssue Tests")
struct ValidationIssueTests {

    @Test("Issue creation and properties")
    func testIssueProperties() {
        let issue = ValidationIssue(severity: .error, message: "Test error", rule: .preamble)
        #expect(issue.severity == .error)
        #expect(issue.message == "Test error")
        #expect(issue.rule == .preamble)
    }

    @Test("Issue equality")
    func testIssueEquality() {
        let a = ValidationIssue(severity: .error, message: "msg", rule: .preamble)
        let b = ValidationIssue(severity: .error, message: "msg", rule: .preamble)
        #expect(a == b)
    }

    @Test("Issue inequality")
    func testIssueInequality() {
        let a = ValidationIssue(severity: .error, message: "msg", rule: .preamble)
        let b = ValidationIssue(severity: .warning, message: "msg", rule: .preamble)
        #expect(a != b)
    }

    @Test("All severity levels exist")
    func testSeverityLevels() {
        _ = ValidationSeverity.error
        _ = ValidationSeverity.warning
        _ = ValidationSeverity.info
    }

    @Test("All validation rules exist")
    func testValidationRules() {
        let rules: [ValidationRule] = [
            .preamble, .dicmMagic, .fileMetaInformation, .requiredTags,
            .transferSyntax, .sopClassUID, .fileSize, .duplicateDetection
        ]
        #expect(rules.count == 8)
    }
}

@Suite("ImportProgress Tests")
struct ImportProgressTests {

    @Test("Initial progress")
    func testInitialProgress() {
        let p = ImportProgress(totalFiles: 10)
        #expect(p.totalFiles == 10)
        #expect(p.processedFiles == 0)
        #expect(p.succeededFiles == 0)
        #expect(p.failedFiles == 0)
        #expect(p.duplicateFiles == 0)
        #expect(!p.isComplete)
        #expect(p.fractionComplete == 0.0)
    }

    @Test("Complete progress")
    func testCompleteProgress() {
        let p = ImportProgress(totalFiles: 5, processedFiles: 5, succeededFiles: 4, failedFiles: 1)
        #expect(p.isComplete)
        #expect(p.fractionComplete == 1.0)
    }

    @Test("Partial progress fraction")
    func testPartialFraction() {
        let p = ImportProgress(totalFiles: 10, processedFiles: 3)
        #expect(p.fractionComplete == 0.3)
    }

    @Test("Zero total files progress")
    func testZeroTotalFiles() {
        let p = ImportProgress(totalFiles: 0)
        #expect(p.fractionComplete == 0.0)
    }

    @Test("Status description when importing")
    func testStatusDescriptionImporting() {
        let p = ImportProgress(totalFiles: 10, processedFiles: 3)
        #expect(p.statusDescription.contains("3/10"))
    }

    @Test("Status description when complete")
    func testStatusDescriptionComplete() {
        let p = ImportProgress(totalFiles: 5, processedFiles: 5, succeededFiles: 3, failedFiles: 1, duplicateFiles: 1)
        #expect(p.statusDescription.contains("complete"))
        #expect(p.statusDescription.contains("3 imported"))
        #expect(p.statusDescription.contains("1 failed"))
        #expect(p.statusDescription.contains("1 duplicates"))
    }
}
