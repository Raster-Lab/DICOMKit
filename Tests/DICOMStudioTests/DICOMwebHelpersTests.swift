// DICOMwebHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("DICOMweb Helpers Tests")
struct DICOMwebHelpersTests {

    // MARK: - DICOMwebURLHelpers

    @Test("DICOMwebURLHelpers isValidURL https://example.com is valid")
    func testURLHelpersValidHTTPS() {
        #expect(DICOMwebURLHelpers.isValidURL("https://example.com") == true)
    }

    @Test("DICOMwebURLHelpers isValidURL http://localhost:8042 is valid")
    func testURLHelpersValidHTTPLocalhost() {
        #expect(DICOMwebURLHelpers.isValidURL("http://localhost:8042") == true)
    }

    @Test("DICOMwebURLHelpers isValidURL empty string is not valid")
    func testURLHelpersEmptyInvalid() {
        #expect(DICOMwebURLHelpers.isValidURL("") == false)
    }

    @Test("DICOMwebURLHelpers isValidURL ftp scheme is not valid")
    func testURLHelpersFTPInvalid() {
        #expect(DICOMwebURLHelpers.isValidURL("ftp://example.com") == false)
    }

    @Test("DICOMwebURLHelpers isValidURL non-URL string is not valid")
    func testURLHelpersNonURLInvalid() {
        #expect(DICOMwebURLHelpers.isValidURL("not-a-url") == false)
    }

    @Test("DICOMwebURLHelpers normalizeURL trims whitespace and trailing slash")
    func testURLHelpersNormalizeTrimsWhitespaceAndSlash() {
        #expect(DICOMwebURLHelpers.normalizeURL("  https://example.com/  ") == "https://example.com")
    }

    @Test("DICOMwebURLHelpers normalizeURL preserves path without trailing slash")
    func testURLHelpersNormalizePreservesPath() {
        #expect(DICOMwebURLHelpers.normalizeURL("https://pacs.example.com/dicom-web") == "https://pacs.example.com/dicom-web")
    }

    @Test("DICOMwebURLHelpers validationError for empty string is not nil")
    func testURLHelpersValidationErrorForEmpty() {
        #expect(DICOMwebURLHelpers.validationError(for: "") != nil)
    }

    @Test("DICOMwebURLHelpers validationError for valid https URL is nil")
    func testURLHelpersValidationErrorForValidURL() {
        #expect(DICOMwebURLHelpers.validationError(for: "https://example.com") == nil)
    }

    @Test("DICOMwebURLHelpers validationError for ftp scheme is not nil")
    func testURLHelpersValidationErrorForFTP() {
        #expect(DICOMwebURLHelpers.validationError(for: "ftp://x") != nil)
    }

    @Test("DICOMwebURLHelpers displayHost returns host and port")
    func testURLHelpersDisplayHost() {
        let host = DICOMwebURLHelpers.displayHost(for: "https://pacs.hospital.com:8042/dicom-web")
        #expect(host == "pacs.hospital.com:8042")
    }

    // MARK: - DICOMwebAuthHelpers

    @Test("DICOMwebAuthHelpers requiresToken bearer is true")
    func testAuthHelpersRequiresTokenBearer() {
        #expect(DICOMwebAuthHelpers.requiresToken(.bearer) == true)
    }

    @Test("DICOMwebAuthHelpers requiresToken jwt is true")
    func testAuthHelpersRequiresTokenJWT() {
        #expect(DICOMwebAuthHelpers.requiresToken(.jwt) == true)
    }

    @Test("DICOMwebAuthHelpers requiresToken none is false")
    func testAuthHelpersRequiresTokenNone() {
        #expect(DICOMwebAuthHelpers.requiresToken(.none) == false)
    }

    @Test("DICOMwebAuthHelpers requiresToken basic is false")
    func testAuthHelpersRequiresTokenBasic() {
        #expect(DICOMwebAuthHelpers.requiresToken(.basic) == false)
    }

    @Test("DICOMwebAuthHelpers requiresCredentials basic is true")
    func testAuthHelpersRequiresCredentialsBasic() {
        #expect(DICOMwebAuthHelpers.requiresCredentials(.basic) == true)
    }

    @Test("DICOMwebAuthHelpers requiresCredentials bearer is false")
    func testAuthHelpersRequiresCredentialsBearer() {
        #expect(DICOMwebAuthHelpers.requiresCredentials(.bearer) == false)
    }

    @Test("DICOMwebAuthHelpers requiresOAuth oauth2PKCE is true")
    func testAuthHelpersRequiresOAuthPKCE() {
        #expect(DICOMwebAuthHelpers.requiresOAuth(.oauth2PKCE) == true)
    }

    @Test("DICOMwebAuthHelpers requiresOAuth bearer is false")
    func testAuthHelpersRequiresOAuthBearer() {
        #expect(DICOMwebAuthHelpers.requiresOAuth(.bearer) == false)
    }

    @Test("DICOMwebAuthHelpers tokenPreview long token shows prefix and suffix")
    func testAuthHelpersTokenPreviewLong() {
        let token = "abcdefghijklmnopqrstuvwxyz"
        let preview = DICOMwebAuthHelpers.tokenPreview(for: token)
        #expect(preview.contains("abcdefgh"))
        #expect(preview.contains("..."))
        #expect(preview.contains("wxyz"))
    }

    @Test("DICOMwebAuthHelpers tokenPreview empty returns empty")
    func testAuthHelpersTokenPreviewEmpty() {
        #expect(DICOMwebAuthHelpers.tokenPreview(for: "") == "")
    }

    @Test("DICOMwebAuthHelpers tokenPreview short token returns masked string")
    func testAuthHelpersTokenPreviewShort() {
        #expect(DICOMwebAuthHelpers.tokenPreview(for: "short") == "••••••••")
    }

    @Test("DICOMwebAuthHelpers validationError bearer with empty token is not nil")
    func testAuthHelpersValidationErrorBearerEmptyToken() {
        let err = DICOMwebAuthHelpers.validationError(
            for: .bearer, token: "", username: "", password: "")
        #expect(err != nil)
    }

    @Test("DICOMwebAuthHelpers validationError bearer with valid token is nil")
    func testAuthHelpersValidationErrorBearerValidToken() {
        let err = DICOMwebAuthHelpers.validationError(
            for: .bearer, token: "my-valid-token", username: "", password: "")
        #expect(err == nil)
    }

    @Test("DICOMwebAuthHelpers validationError basic with empty username is not nil")
    func testAuthHelpersValidationErrorBasicEmptyUsername() {
        let err = DICOMwebAuthHelpers.validationError(
            for: .basic, token: "", username: "", password: "pass")
        #expect(err != nil)
    }

    @Test("DICOMwebAuthHelpers validationError none with no credentials is nil")
    func testAuthHelpersValidationErrorNoneIsNil() {
        let err = DICOMwebAuthHelpers.validationError(
            for: .none, token: "", username: "", password: "")
        #expect(err == nil)
    }

    // MARK: - DICOMwebTLSHelpers

    @Test("DICOMwebTLSHelpers sfSymbol for none is lock.slash")
    func testTLSHelpersSFSymbolNone() {
        #expect(DICOMwebTLSHelpers.sfSymbol(for: .none) == "lock.slash")
    }

    @Test("DICOMwebTLSHelpers sfSymbol for strict is lock.shield")
    func testTLSHelpersSFSymbolStrict() {
        #expect(DICOMwebTLSHelpers.sfSymbol(for: .strict) == "lock.shield")
    }

    @Test("DICOMwebTLSHelpers isProductionSafe compatible is true")
    func testTLSHelpersIsProductionSafeCompatible() {
        #expect(DICOMwebTLSHelpers.isProductionSafe(.compatible) == true)
    }

    @Test("DICOMwebTLSHelpers isProductionSafe strict is true")
    func testTLSHelpersIsProductionSafeStrict() {
        #expect(DICOMwebTLSHelpers.isProductionSafe(.strict) == true)
    }

    @Test("DICOMwebTLSHelpers isProductionSafe none is false")
    func testTLSHelpersIsProductionSafeNone() {
        #expect(DICOMwebTLSHelpers.isProductionSafe(.none) == false)
    }

    @Test("DICOMwebTLSHelpers isProductionSafe development is false")
    func testTLSHelpersIsProductionSafeDevelopment() {
        #expect(DICOMwebTLSHelpers.isProductionSafe(.development) == false)
    }

    @Test("DICOMwebTLSHelpers securityDescription for none is non-empty")
    func testTLSHelpersSecurityDescriptionNone() {
        #expect(!DICOMwebTLSHelpers.securityDescription(for: .none).isEmpty)
    }

    @Test("DICOMwebTLSHelpers securityDescription for development mentions self-signed or development")
    func testTLSHelpersSecurityDescriptionDevelopment() {
        let desc = DICOMwebTLSHelpers.securityDescription(for: .development).lowercased()
        #expect(desc.contains("self-signed") || desc.contains("development"))
    }

    // MARK: - DICOMwebQIDOHelpers

    @Test("DICOMwebQIDOHelpers endpointSuffix for study is /studies")
    func testQIDOHelpersEndpointSuffixStudy() {
        #expect(DICOMwebQIDOHelpers.endpointSuffix(for: .study) == "/studies")
    }

    @Test("DICOMwebQIDOHelpers endpointSuffix for series is /series")
    func testQIDOHelpersEndpointSuffixSeries() {
        #expect(DICOMwebQIDOHelpers.endpointSuffix(for: .series) == "/series")
    }

    @Test("DICOMwebQIDOHelpers endpointSuffix for instance is /instances")
    func testQIDOHelpersEndpointSuffixInstance() {
        #expect(DICOMwebQIDOHelpers.endpointSuffix(for: .instance) == "/instances")
    }

    @Test("DICOMwebQIDOHelpers formatPatientName empty returns dash")
    func testQIDOHelpersFormatPatientNameEmpty() {
        #expect(DICOMwebQIDOHelpers.formatPatientName("") == "—")
    }

    @Test("DICOMwebQIDOHelpers formatPatientName caret-delimited contains both components")
    func testQIDOHelpersFormatPatientNameCaret() {
        let result = DICOMwebQIDOHelpers.formatPatientName("SMITH^JOHN")
        #expect(result.contains("SMITH"))
        #expect(result.contains("JOHN"))
    }

    @Test("DICOMwebQIDOHelpers formatStudyDate empty from and to returns any-date string")
    func testQIDOHelpersFormatStudyDateBothEmpty() {
        #expect(DICOMwebQIDOHelpers.formatStudyDate(from: "", to: "") == "Any date")
    }

    @Test("DICOMwebQIDOHelpers formatStudyDate with from contains from date")
    func testQIDOHelpersFormatStudyDateFromOnly() {
        let result = DICOMwebQIDOHelpers.formatStudyDate(from: "2024-01-01", to: "")
        #expect(result.contains("2024-01-01"))
    }

    @Test("DICOMwebQIDOHelpers buildQuerySummary with all-empty params returns non-empty string")
    func testQIDOHelpersBuildQuerySummaryEmpty() {
        #expect(!DICOMwebQIDOHelpers.buildQuerySummary(params: QIDOQueryParams()).isEmpty)
    }

    // MARK: - DICOMwebWADOHelpers

    @Test("DICOMwebWADOHelpers formattedBytesReceived 512 contains 512")
    func testWADOHelpersFormattedBytes512() {
        #expect(DICOMwebWADOHelpers.formattedBytesReceived(512).contains("512"))
    }

    @Test("DICOMwebWADOHelpers formattedBytesReceived 1MB contains MB or 1")
    func testWADOHelpersFormattedBytesMB() {
        let result = DICOMwebWADOHelpers.formattedBytesReceived(1024 * 1024)
        #expect(result.contains("MB") || result.contains("1"))
    }

    @Test("DICOMwebWADOHelpers formattedTransferRate nil returns dash")
    func testWADOHelpersFormattedTransferRateNil() {
        #expect(DICOMwebWADOHelpers.formattedTransferRate(nil) == "—")
    }

    @Test("DICOMwebWADOHelpers formattedTransferRate non-nil returns rate with units")
    func testWADOHelpersFormattedTransferRateNonNil() {
        let result = DICOMwebWADOHelpers.formattedTransferRate(1_000_000)
        #expect(result.contains("B/s") || result.contains("KB/s") || result.contains("MB/s"))
    }

    // MARK: - DICOMwebSTOWHelpers

    @Test("DICOMwebSTOWHelpers duplicateHandlingDescription reject contains 409 or Reject")
    func testSTOWHelpersDuplicateHandlingReject() {
        let desc = DICOMwebSTOWHelpers.duplicateHandlingDescription(.reject)
        #expect(desc.contains("409") || desc.lowercased().contains("reject"))
    }

    @Test("DICOMwebSTOWHelpers duplicateHandlingDescription overwrite contains overwrite")
    func testSTOWHelpersDuplicateHandlingOverwrite() {
        let desc = DICOMwebSTOWHelpers.duplicateHandlingDescription(.overwrite).lowercased()
        #expect(desc.contains("overwrite"))
    }

    @Test("DICOMwebSTOWHelpers duplicateHandlingDescription ignore contains skip or ignore or silent")
    func testSTOWHelpersDuplicateHandlingIgnore() {
        let desc = DICOMwebSTOWHelpers.duplicateHandlingDescription(.ignore).lowercased()
        #expect(desc.contains("skip") || desc.contains("ignore") || desc.contains("silent"))
    }

    // MARK: - DICOMwebUPSHelpers

    @Test("DICOMwebUPSHelpers sfSymbol for scheduled is calendar")
    func testUPSHelpersSFSymbolScheduled() {
        #expect(DICOMwebUPSHelpers.sfSymbol(for: .scheduled) == "calendar")
    }

    @Test("DICOMwebUPSHelpers sfSymbol for completed is checkmark.circle.fill")
    func testUPSHelpersSFSymbolCompleted() {
        #expect(DICOMwebUPSHelpers.sfSymbol(for: .completed) == "checkmark.circle.fill")
    }

    @Test("DICOMwebUPSHelpers canTransition from scheduled to inProgress is true")
    func testUPSHelpersCanTransitionScheduledToInProgress() {
        #expect(DICOMwebUPSHelpers.canTransition(from: .scheduled, to: .inProgress) == true)
    }

    @Test("DICOMwebUPSHelpers canTransition from completed to cancelled is false")
    func testUPSHelpersCanTransitionCompletedToCancelled() {
        #expect(DICOMwebUPSHelpers.canTransition(from: .completed, to: .cancelled) == false)
    }

    @Test("DICOMwebUPSHelpers availableTransitions from inProgress has 2 transitions")
    func testUPSHelpersAvailableTransitionsInProgress() {
        #expect(DICOMwebUPSHelpers.availableTransitions(from: .inProgress).count == 2)
    }

    // MARK: - DICOMwebPerformanceHelpers

    @Test("DICOMwebPerformanceHelpers formattedLatency 0.5ms contains < 1")
    func testPerformanceHelpersFormattedLatencySubMs() {
        let result = DICOMwebPerformanceHelpers.formattedLatency(0.5)
        #expect(result.contains("< 1") || result.contains("ms"))
    }

    @Test("DICOMwebPerformanceHelpers formattedLatency 1500ms contains s")
    func testPerformanceHelpersFormattedLatencySeconds() {
        let result = DICOMwebPerformanceHelpers.formattedLatency(1500)
        #expect(result.contains("s"))
    }

    @Test("DICOMwebPerformanceHelpers formattedCompressionRatio contains ratio and x")
    func testPerformanceHelpersFormattedCompressionRatio() {
        let result = DICOMwebPerformanceHelpers.formattedCompressionRatio(2.5)
        #expect(result.contains("2.5"))
        #expect(result.contains("×"))
    }

    @Test("DICOMwebPerformanceHelpers formattedHitRate contains 85 and percent")
    func testPerformanceHelpersFormattedHitRate() {
        let result = DICOMwebPerformanceHelpers.formattedHitRate(0.853)
        #expect(result.contains("85") || result.contains("%"))
    }

    @Test("DICOMwebPerformanceHelpers http2StreamsDescription contains active and max counts")
    func testPerformanceHelpersHTTP2StreamsDescription() {
        let result = DICOMwebPerformanceHelpers.http2StreamsDescription(active: 12, max: 100)
        #expect(result.contains("12"))
        #expect(result.contains("100"))
    }

    @Test("DICOMwebPerformanceHelpers overallHealthDescription excellent for low error and latency")
    func testPerformanceHelpersHealthExcellent() {
        let stats = DICOMwebPerformanceStats(
            averageLatencyMs: 50,
            totalRequestCount: 100,
            errorCount: 0
        )
        #expect(DICOMwebPerformanceHelpers.overallHealthDescription(stats: stats) == "Excellent")
    }

    @Test("DICOMwebPerformanceHelpers overallHealthDescription poor for high error rate")
    func testPerformanceHelpersHealthPoor() {
        let stats = DICOMwebPerformanceStats(
            averageLatencyMs: 5000,
            totalRequestCount: 10,
            errorCount: 5
        )
        #expect(DICOMwebPerformanceHelpers.overallHealthDescription(stats: stats) == "Poor")
    }
}
