// NetworkingHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Networking Helpers Tests")
struct NetworkingHelpersTests {

    // MARK: - AETitleHelpers

    @Test("AETitleHelpers valid AE title passes")
    func testAETitleValid() {
        #expect(AETitleHelpers.isValid("ORTHANC") == true)
    }

    @Test("AETitleHelpers empty AE title fails")
    func testAETitleEmptyFails() {
        #expect(AETitleHelpers.isValid("") == false)
    }

    @Test("AETitleHelpers AE title exceeding 16 chars fails")
    func testAETitleTooLongFails() {
        #expect(AETitleHelpers.isValid("ABCDEFGHIJKLMNOPQ") == false) // 17 chars
    }

    @Test("AETitleHelpers lowercase AE title fails")
    func testAETitleLowercaseFails() {
        #expect(AETitleHelpers.isValid("orthanc") == false)
    }

    @Test("AETitleHelpers all-spaces AE title fails")
    func testAETitleAllSpacesFails() {
        #expect(AETitleHelpers.isValid("    ") == false)
    }

    @Test("AETitleHelpers valid with digits and underscores passes")
    func testAETitleWithDigitsAndUnderscores() {
        #expect(AETitleHelpers.isValid("PACS_01") == true)
    }

    @Test("AETitleHelpers normalize uppercases and trims")
    func testAETitleNormalize() {
        #expect(AETitleHelpers.normalize("  orthanc  ") == "ORTHANC")
    }

    @Test("AETitleHelpers validationError returns nil for valid AE title")
    func testAETitleValidationErrorNilForValid() {
        #expect(AETitleHelpers.validationError(for: "DICOMSTUDIO") == nil)
    }

    @Test("AETitleHelpers validationError returns message for empty title")
    func testAETitleValidationErrorForEmpty() {
        #expect(AETitleHelpers.validationError(for: "") != nil)
    }

    @Test("AETitleHelpers validationError returns message for too-long title")
    func testAETitleValidationErrorForTooLong() {
        let longTitle = String(repeating: "A", count: 17)
        #expect(AETitleHelpers.validationError(for: longTitle) != nil)
    }

    @Test("AETitleHelpers validationError returns message for lowercase title")
    func testAETitleValidationErrorForLowercase() {
        #expect(AETitleHelpers.validationError(for: "pacs") != nil)
    }

    // MARK: - PortHelpers

    @Test("PortHelpers default DICOM port is 11112")
    func testPortHelpersDefaultPort() {
        #expect(PortHelpers.defaultDICOMPort == 11112)
    }

    @Test("PortHelpers default TLS port is 2762")
    func testPortHelpersDefaultTLSPort() {
        #expect(PortHelpers.defaultTLSPort == 2762)
    }

    @Test("PortHelpers valid port 1 is valid")
    func testPortHelpersPortOneValid() {
        #expect(PortHelpers.isValid(1) == true)
    }

    @Test("PortHelpers valid port 65535 is valid")
    func testPortHelpersPort65535Valid() {
        #expect(PortHelpers.isValid(65535) == true)
    }

    @Test("PortHelpers port 0 is invalid")
    func testPortHelpersPortZeroInvalid() {
        #expect(PortHelpers.isValid(0) == false)
    }

    @Test("PortHelpers port 65536 is invalid")
    func testPortHelpersPort65536Invalid() {
        #expect(PortHelpers.isValid(65536) == false)
    }

    @Test("PortHelpers displayName includes DICOM for 11112")
    func testPortHelpersDisplayNameKnownPort() {
        #expect(PortHelpers.displayName(for: 11112).contains("DICOM"))
    }

    @Test("PortHelpers displayName for unknown port returns number")
    func testPortHelpersDisplayNameUnknownPort() {
        #expect(PortHelpers.displayName(for: 9999) == "9999")
    }

    // MARK: - TransferSpeedHelpers

    @Test("TransferSpeedHelpers formats bytes correctly")
    func testTransferSpeedFormatsBytes() {
        #expect(TransferSpeedHelpers.formatted(bytesPerSecond: 500).contains("B/s"))
    }

    @Test("TransferSpeedHelpers formats kilobytes correctly")
    func testTransferSpeedFormatsKB() {
        let result = TransferSpeedHelpers.formatted(bytesPerSecond: 1536)
        #expect(result.contains("KB/s"))
    }

    @Test("TransferSpeedHelpers formats megabytes correctly")
    func testTransferSpeedFormatsMB() {
        let result = TransferSpeedHelpers.formatted(bytesPerSecond: 2 * 1024 * 1024)
        #expect(result.contains("MB/s"))
    }

    @Test("TransferSpeedHelpers formattedBytes returns B for small values")
    func testFormattedBytesSmall() {
        #expect(TransferSpeedHelpers.formattedBytes(512).contains("B"))
    }

    @Test("TransferSpeedHelpers formattedBytes returns KB for kilobytes")
    func testFormattedBytesKB() {
        #expect(TransferSpeedHelpers.formattedBytes(2048).contains("KB"))
    }

    @Test("TransferSpeedHelpers formattedLatency sub-second shows ms")
    func testFormattedLatencyMs() {
        #expect(TransferSpeedHelpers.formattedLatency(42.0).contains("ms"))
    }

    @Test("TransferSpeedHelpers formattedLatency over 1000ms shows s")
    func testFormattedLatencySeconds() {
        #expect(TransferSpeedHelpers.formattedLatency(2500.0).contains("s"))
    }

    // MARK: - QueryFilterHelpers

    @Test("QueryFilterHelpers summary returns no-filter message for empty filter")
    func testQueryFilterSummaryEmpty() {
        let filter = QueryFilter()
        #expect(QueryFilterHelpers.summary(for: filter).contains("No filter"))
    }

    @Test("QueryFilterHelpers summary includes patient name")
    func testQueryFilterSummaryIncludesPatientName() {
        let filter = QueryFilter(patientName: "SMITH*")
        let summary = QueryFilterHelpers.summary(for: filter)
        #expect(summary.contains("SMITH*"))
    }

    @Test("QueryFilterHelpers summary includes modality")
    func testQueryFilterSummaryIncludesModality() {
        let filter = QueryFilter(modality: "CT")
        let summary = QueryFilterHelpers.summary(for: filter)
        #expect(summary.contains("CT"))
    }

    @Test("QueryFilterHelpers isValidDICOMDate true for empty string")
    func testDICOMDateEmptyIsValid() {
        #expect(QueryFilterHelpers.isValidDICOMDate("") == true)
    }

    @Test("QueryFilterHelpers isValidDICOMDate true for valid date")
    func testDICOMDateValidFormat() {
        #expect(QueryFilterHelpers.isValidDICOMDate("20260101") == true)
    }

    @Test("QueryFilterHelpers isValidDICOMDate false for invalid format")
    func testDICOMDateInvalidFormat() {
        #expect(QueryFilterHelpers.isValidDICOMDate("2026-01-01") == false)
    }

    @Test("QueryFilterHelpers isValidDICOMDate false for invalid month")
    func testDICOMDateInvalidMonth() {
        #expect(QueryFilterHelpers.isValidDICOMDate("20261301") == false)
    }

    // MARK: - TransferItemHelpers

    @Test("TransferItemHelpers progressLabel shows percentage without instance count")
    func testTransferItemProgressLabelNoInstances() {
        let item = TransferItem(label: "Test", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID(), progress: 0.5)
        #expect(TransferItemHelpers.progressLabel(for: item).contains("50%"))
    }

    @Test("TransferItemHelpers progressLabel shows instance counts")
    func testTransferItemProgressLabelWithInstances() {
        let item = TransferItem(label: "Test", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID(), progress: 0.3,
                                instancesCompleted: 3, instancesTotal: 10)
        let label = TransferItemHelpers.progressLabel(for: item)
        #expect(label.contains("3"))
        #expect(label.contains("10"))
    }

    @Test("TransferItemHelpers estimatedTimeRemaining nil for zero speed")
    func testTransferItemNoETA() {
        let item = TransferItem(label: "Test", studyInstanceUID: "1.2.3",
                                serverProfileID: UUID(), progress: 0.5,
                                instancesTotal: 10, bytesPerSecond: 0)
        #expect(TransferItemHelpers.estimatedTimeRemaining(for: item) == nil)
    }

    // MARK: - SendQueueHelpers

    @Test("SendQueueHelpers retryLabel shows no retries for count 0")
    func testSendQueueNoRetries() {
        let item = SendItem(label: "CT.dcm", sourceIdentifier: "UID", serverProfileID: UUID())
        let label = SendQueueHelpers.retryLabel(for: item, config: .default)
        #expect(label.contains("No retries"))
    }

    @Test("SendQueueHelpers retryLabel shows retry count")
    func testSendQueueRetryCount() {
        var item = SendItem(label: "CT.dcm", sourceIdentifier: "UID",
                            serverProfileID: UUID(), retryCount: 2)
        let config = SendRetryConfig(maxRetries: 3)
        let label = SendQueueHelpers.retryLabel(for: item, config: config)
        #expect(label.contains("2"))
        #expect(label.contains("3"))
        _ = item
    }

    @Test("SendQueueHelpers nextRetryDelay fixed strategy returns constant")
    func testNextRetryDelayFixed() {
        let config = SendRetryConfig(initialDelaySeconds: 2.0, backoffStrategy: .fixed)
        let d1 = SendQueueHelpers.nextRetryDelay(attempt: 0, config: config)
        let d2 = SendQueueHelpers.nextRetryDelay(attempt: 3, config: config)
        #expect(abs(d1 - 2.0) < 0.001)
        #expect(abs(d2 - 2.0) < 0.001)
    }

    @Test("SendQueueHelpers nextRetryDelay exponential grows")
    func testNextRetryDelayExponential() {
        let config = SendRetryConfig(initialDelaySeconds: 1.0, backoffStrategy: .exponential)
        let d0 = SendQueueHelpers.nextRetryDelay(attempt: 0, config: config)
        let d1 = SendQueueHelpers.nextRetryDelay(attempt: 1, config: config)
        #expect(d1 > d0)
    }

    @Test("SendQueueHelpers nextRetryDelay exponential is capped at maxDelay")
    func testNextRetryDelayExponentialCapped() {
        let config = SendRetryConfig(initialDelaySeconds: 1.0, maxDelaySeconds: 5.0,
                                     backoffStrategy: .exponential)
        let d = SendQueueHelpers.nextRetryDelay(attempt: 100, config: config)
        #expect(d <= 5.0)
    }

    // MARK: - AuditLogHelpers

    @Test("AuditLogHelpers summary includes event type and outcome")
    func testAuditLogHelpersSummary() {
        let entry = AuditLogEntry(eventType: .echo, outcome: .success,
                                  remoteEntity: "PACS", localAETitle: "DS")
        let summary = AuditLogHelpers.summary(for: entry)
        #expect(summary.contains("C-ECHO"))
        #expect(summary.contains("Success"))
    }

    @Test("AuditLogHelpers csvExport includes header row")
    func testAuditLogCSVExportHeader() {
        let csv = AuditLogHelpers.csvExport(entries: [])
        #expect(csv.contains("Timestamp"))
        #expect(csv.contains("Event Type"))
        #expect(csv.contains("Outcome"))
    }

    @Test("AuditLogHelpers csvExport includes entry data")
    func testAuditLogCSVExportEntryData() {
        let entry = AuditLogEntry(eventType: .store, outcome: .failure,
                                  remoteEntity: "REMOTE_PACS", localAETitle: "DS",
                                  detail: "Connection refused")
        let csv = AuditLogHelpers.csvExport(entries: [entry])
        #expect(csv.contains("REMOTE_PACS"))
        #expect(csv.contains("Connection refused"))
    }

    // MARK: - ServerProfileValidation

    @Test("ServerProfileValidation valid profile passes")
    func testServerProfileValidationValid() {
        let profile = PACSServerProfile(name: "PACS1", host: "pacs.hospital.com",
                                        remoteAETitle: "PACS", localAETitle: "DS")
        #expect(ServerProfileValidation.isValid(profile) == true)
    }

    @Test("ServerProfileValidation empty name fails")
    func testServerProfileValidationEmptyName() {
        let profile = PACSServerProfile(name: "  ", host: "pacs.hospital.com",
                                        remoteAETitle: "PACS", localAETitle: "DS")
        let errors = ServerProfileValidation.validate(profile)
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("name") })
    }

    @Test("ServerProfileValidation empty host fails")
    func testServerProfileValidationEmptyHost() {
        let profile = PACSServerProfile(name: "PACS1", host: "  ",
                                        remoteAETitle: "PACS", localAETitle: "DS")
        let errors = ServerProfileValidation.validate(profile)
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("Hostname") })
    }

    @Test("ServerProfileValidation invalid remote AE title fails")
    func testServerProfileValidationInvalidAETitle() {
        let profile = PACSServerProfile(name: "P", host: "h",
                                        remoteAETitle: "lowercase", localAETitle: "DS")
        let errors = ServerProfileValidation.validate(profile)
        #expect(!errors.isEmpty)
    }

    @Test("ServerProfileValidation zero timeout fails")
    func testServerProfileValidationZeroTimeout() {
        let profile = PACSServerProfile(name: "P", host: "h",
                                        remoteAETitle: "PACS", localAETitle: "DS",
                                        timeoutSeconds: 0)
        let errors = ServerProfileValidation.validate(profile)
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("Timeout") })
    }

    // MARK: - MPPSHelpers

    @Test("MPPSHelpers formattedDose returns N/A for nil")
    func testMPPSHelpersDoseNil() {
        #expect(MPPSHelpers.formattedDose(nil) == "N/A")
    }

    @Test("MPPSHelpers formattedDose includes mGy for non-nil")
    func testMPPSHelpersDoseValue() {
        #expect(MPPSHelpers.formattedDose(25.5).contains("mGy"))
    }

    @Test("MPPSHelpers formattedExposure returns N/A for nil")
    func testMPPSHelpersExposureNil() {
        #expect(MPPSHelpers.formattedExposure(nil) == "N/A")
    }

    @Test("MPPSHelpers formattedExposure includes mAs for non-nil")
    func testMPPSHelpersExposureValue() {
        #expect(MPPSHelpers.formattedExposure(100.0).contains("mAs"))
    }

    @Test("MPPSHelpers elapsedTime returns seconds for short duration")
    func testMPPSHelpersElapsedTimeShort() {
        let item = MPPSItem(patientName: "P", patientID: "P1",
                            performedProcedureStepID: "PPS1",
                            performedProcedureStepDescription: "CT",
                            performedStationAETitle: "CT1", modality: "CT",
                            startDateTime: Date(timeIntervalSinceNow: -30),
                            endDateTime: Date())
        let elapsed = MPPSHelpers.elapsedTime(for: item)
        #expect(elapsed.contains("sec"))
    }

    // MARK: - PrintHelpers

    @Test("PrintHelpers dicomTagValue returns raw layout value")
    func testPrintHelpersDICOMTagValue() {
        #expect(PrintHelpers.dicomTagValue(for: .standard2x2) == "STANDARD\\2,2")
    }

    @Test("PrintHelpers allLayouts returns sorted by cell count")
    func testPrintHelpersAllLayoutsSorted() {
        let layouts = PrintHelpers.allLayouts()
        for i in 0..<(layouts.count - 1) {
            #expect(layouts[i].cellCount <= layouts[i + 1].cellCount)
        }
    }

    @Test("PrintHelpers description includes layout and copy count")
    func testPrintHelpersDescription() {
        let job = PrintJob(label: "Test", printerServerProfileID: UUID(),
                           numberOfCopies: 2, filmLayout: .standard2x2)
        let desc = PrintHelpers.description(for: job)
        #expect(desc.contains("2×2"))
        #expect(desc.contains("2"))
    }

    // MARK: - MonitoringHelpers

    @Test("MonitoringHelpers successRateLabel shows 100.0% for no operations")
    func testMonitoringSuccessRateLabelEmpty() {
        let stats = NetworkMonitoringStats()
        #expect(MonitoringHelpers.successRateLabel(stats).contains("100.0%"))
    }

    @Test("MonitoringHelpers successRateLabel shows 50.0% for half failed")
    func testMonitoringSuccessRateLabelHalf() {
        let stats = NetworkMonitoringStats(totalOperations: 10, totalFailedOperations: 5)
        #expect(MonitoringHelpers.successRateLabel(stats).contains("50.0%"))
    }

    @Test("MonitoringHelpers summary contains connection info")
    func testMonitoringHelpersSummary() {
        let stats = NetworkMonitoringStats(pooledConnectionCount: 4, activeAssociationCount: 2)
        let summary = MonitoringHelpers.summary(stats)
        #expect(summary.contains("4"))
        #expect(summary.contains("2"))
    }
}
