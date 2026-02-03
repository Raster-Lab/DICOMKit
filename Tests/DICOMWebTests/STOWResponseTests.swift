import Testing
import Foundation
@testable import DICOMWeb

// MARK: - STOWResponse Tests

@Suite("STOWResponse Tests")
struct STOWResponseTests {
    
    // MARK: - Initialization Tests
    
    @Test("Empty response initialization")
    func testEmptyResponse() {
        let response = STOWResponse()
        
        #expect(response.storedInstances.isEmpty)
        #expect(response.failedInstances.isEmpty)
        #expect(response.warnings.isEmpty)
        #expect(response.retrieveURL == nil)
    }
    
    @Test("Response with stored instances")
    func testResponseWithStoredInstances() {
        let instance1 = STOWResponse.InstanceResult(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8",
            retrieveURL: "https://example.com/studies/1.2.3/series/1.2.3.4/instances/1.2.3.4.5.6.7.8"
        )
        let instance2 = STOWResponse.InstanceResult(
            sopInstanceUID: "1.2.3.4.5.6.7.9"
        )
        
        let response = STOWResponse(
            storedInstances: [instance1, instance2],
            retrieveURL: "https://example.com/studies/1.2.3"
        )
        
        #expect(response.storedInstances.count == 2)
        #expect(response.successCount == 2)
        #expect(response.failureCount == 0)
        #expect(response.totalCount == 2)
        #expect(response.isFullSuccess)
        #expect(!response.isPartialSuccess)
        #expect(!response.isFullFailure)
    }
    
    @Test("Response with failures")
    func testResponseWithFailures() {
        let failure = STOWResponse.InstanceFailure(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            failureReason: 0x0111,
            failureDescription: "Duplicate SOP Instance"
        )
        
        let response = STOWResponse(failedInstances: [failure])
        
        #expect(response.failedInstances.count == 1)
        #expect(response.failureCount == 1)
        #expect(response.successCount == 0)
        #expect(response.isFullFailure)
        #expect(!response.isFullSuccess)
        #expect(!response.isPartialSuccess)
    }
    
    @Test("Response with partial success")
    func testPartialSuccess() {
        let stored = STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")
        let failed = STOWResponse.InstanceFailure(sopInstanceUID: "1.2.4")
        
        let response = STOWResponse(
            storedInstances: [stored],
            failedInstances: [failed]
        )
        
        #expect(response.isPartialSuccess)
        #expect(!response.isFullSuccess)
        #expect(!response.isFullFailure)
        #expect(response.successCount == 1)
        #expect(response.failureCount == 1)
        #expect(response.totalCount == 2)
    }
    
    @Test("Response with warnings")
    func testResponseWithWarnings() {
        let warning = STOWResponse.Warning(code: "W001", message: "Data coerced")
        
        let response = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")],
            warnings: [warning]
        )
        
        #expect(response.hasWarnings)
        #expect(response.warnings.count == 1)
        #expect(response.warnings[0].message == "Data coerced")
    }
    
    // MARK: - Instance Result Tests
    
    @Test("InstanceResult with all fields")
    func testInstanceResultAllFields() {
        let result = STOWResponse.InstanceResult(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            retrieveURL: "https://example.com/instance"
        )
        
        #expect(result.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(result.sopInstanceUID == "1.2.3.4.5")
        #expect(result.retrieveURL == "https://example.com/instance")
    }
    
    @Test("InstanceResult with minimal fields")
    func testInstanceResultMinimal() {
        let result = STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")
        
        #expect(result.sopClassUID == nil)
        #expect(result.sopInstanceUID == "1.2.3")
        #expect(result.retrieveURL == nil)
    }
    
    // MARK: - Instance Failure Tests
    
    @Test("InstanceFailure with known reason code")
    func testInstanceFailureKnownReason() {
        let failure = STOWResponse.InstanceFailure(
            sopInstanceUID: "1.2.3",
            failureReason: 0x0111
        )
        
        #expect(failure.knownFailureReason == .duplicateSOPInstance)
    }
    
    @Test("InstanceFailure with unknown reason code")
    func testInstanceFailureUnknownReason() {
        let failure = STOWResponse.InstanceFailure(
            sopInstanceUID: "1.2.3",
            failureReason: 0xFFFF
        )
        
        #expect(failure.knownFailureReason == nil)
    }
    
    @Test("All known failure reason codes")
    func testAllKnownFailureReasons() {
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.processingFailure.rawValue == 0x0110)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.duplicateSOPInstance.rawValue == 0x0111)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.noSuchObjectInstance.rawValue == 0x0112)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.mandatoryAttributeMissing.rawValue == 0x0120)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.sopClassNotSupported.rawValue == 0x0122)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.transferSyntaxNotSupported.rawValue == 0x0124)
        #expect(STOWResponse.InstanceFailure.FailureReasonCode.outOfResources.rawValue == 0xA700)
    }
    
    @Test("InstanceFailure description")
    func testInstanceFailureDescription() {
        let failure = STOWResponse.InstanceFailure(
            sopInstanceUID: "1.2.3.4.5",
            failureReason: 0x0111,
            failureDescription: "Already exists"
        )
        
        let description = failure.description
        #expect(description.contains("1.2.3.4.5"))
        #expect(description.contains("0x0111"))
        #expect(description.contains("Already exists"))
    }
    
    // MARK: - JSON Parsing Tests
    
    @Test("Parse empty JSON response")
    func testParseEmptyJSON() throws {
        let json: [String: Any] = [:]
        let response = try STOWResponse.parse(json: json)
        
        #expect(response.storedInstances.isEmpty)
        #expect(response.failedInstances.isEmpty)
    }
    
    @Test("Parse JSON with stored instances")
    func testParseJSONWithStoredInstances() throws {
        let json: [String: Any] = [
            "00081199": [
                "vr": "SQ",
                "Value": [
                    [
                        "00081150": ["vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.2"]],
                        "00081155": ["vr": "UI", "Value": ["1.2.3.4.5.6.7.8"]],
                        "00081190": ["vr": "UR", "Value": ["https://example.com/instance"]]
                    ]
                ]
            ],
            "00081190": ["vr": "UR", "Value": ["https://example.com/study"]]
        ]
        
        let response = try STOWResponse.parse(json: json)
        
        #expect(response.storedInstances.count == 1)
        #expect(response.storedInstances[0].sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(response.storedInstances[0].sopInstanceUID == "1.2.3.4.5.6.7.8")
        #expect(response.storedInstances[0].retrieveURL == "https://example.com/instance")
        #expect(response.retrieveURL == "https://example.com/study")
    }
    
    @Test("Parse JSON with failed instances")
    func testParseJSONWithFailedInstances() throws {
        let json: [String: Any] = [
            "00081198": [
                "vr": "SQ",
                "Value": [
                    [
                        "00081150": ["vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.2"]],
                        "00081155": ["vr": "UI", "Value": ["1.2.3.4.5"]],
                        "00081197": ["vr": "US", "Value": [273]]
                    ]
                ]
            ]
        ]
        
        let response = try STOWResponse.parse(json: json)
        
        #expect(response.failedInstances.count == 1)
        #expect(response.failedInstances[0].sopInstanceUID == "1.2.3.4.5")
        #expect(response.failedInstances[0].failureReason == 273)
        #expect(response.failedInstances[0].knownFailureReason == .duplicateSOPInstance)
    }
    
    @Test("Parse JSON with mixed results")
    func testParseJSONWithMixedResults() throws {
        let json: [String: Any] = [
            "00081199": [
                "vr": "SQ",
                "Value": [
                    ["00081155": ["vr": "UI", "Value": ["1.2.3.success"]]]
                ]
            ],
            "00081198": [
                "vr": "SQ",
                "Value": [
                    ["00081155": ["vr": "UI", "Value": ["1.2.3.failure"]]]
                ]
            ]
        ]
        
        let response = try STOWResponse.parse(json: json)
        
        #expect(response.storedInstances.count == 1)
        #expect(response.failedInstances.count == 1)
        #expect(response.isPartialSuccess)
    }
    
    // MARK: - Description Tests
    
    @Test("Full success description")
    func testFullSuccessDescription() {
        let response = STOWResponse(
            storedInstances: [
                STOWResponse.InstanceResult(sopInstanceUID: "1"),
                STOWResponse.InstanceResult(sopInstanceUID: "2")
            ]
        )
        
        #expect(response.description.contains("Success"))
        #expect(response.description.contains("2"))
    }
    
    @Test("Partial success description")
    func testPartialSuccessDescription() {
        let response = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1")],
            failedInstances: [STOWResponse.InstanceFailure(sopInstanceUID: "2")]
        )
        
        #expect(response.description.contains("Partial"))
    }
    
    @Test("Full failure description")
    func testFullFailureDescription() {
        let response = STOWResponse(
            failedInstances: [STOWResponse.InstanceFailure(sopInstanceUID: "1")]
        )
        
        #expect(response.description.contains("Failed"))
    }
    
    @Test("Empty response description")
    func testEmptyResponseDescription() {
        let response = STOWResponse()
        #expect(response.description.contains("Empty"))
    }
    
    @Test("Description with warnings")
    func testDescriptionWithWarnings() {
        let response = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1")],
            warnings: [STOWResponse.Warning(message: "Test warning")]
        )
        
        #expect(response.description.contains("warning"))
    }
    
    // MARK: - Equality Tests
    
    @Test("STOWResponse equality")
    func testResponseEquality() {
        let response1 = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")],
            retrieveURL: "https://example.com"
        )
        let response2 = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")],
            retrieveURL: "https://example.com"
        )
        
        #expect(response1 == response2)
    }
    
    @Test("InstanceResult equality")
    func testInstanceResultEquality() {
        let result1 = STOWResponse.InstanceResult(
            sopClassUID: "1.2.3",
            sopInstanceUID: "1.2.3.4",
            retrieveURL: "https://example.com"
        )
        let result2 = STOWResponse.InstanceResult(
            sopClassUID: "1.2.3",
            sopInstanceUID: "1.2.3.4",
            retrieveURL: "https://example.com"
        )
        
        #expect(result1 == result2)
    }
    
    @Test("InstanceFailure equality")
    func testInstanceFailureEquality() {
        let failure1 = STOWResponse.InstanceFailure(
            sopInstanceUID: "1.2.3",
            failureReason: 0x0111
        )
        let failure2 = STOWResponse.InstanceFailure(
            sopInstanceUID: "1.2.3",
            failureReason: 0x0111
        )
        
        #expect(failure1 == failure2)
    }
    
    @Test("Warning equality")
    func testWarningEquality() {
        let warning1 = STOWResponse.Warning(code: "W001", message: "Test")
        let warning2 = STOWResponse.Warning(code: "W001", message: "Test")
        
        #expect(warning1 == warning2)
    }
}

// MARK: - STOW-RS Client Tests

@Suite("STOW-RS Client Tests")
struct STOWClientTests {
    
    let testURL = URL(string: "https://pacs.example.com/dicom-web")!
    
    // MARK: - StoreProgress Tests
    
    @Test("StoreProgress fraction with instance count")
    func testProgressFractionWithInstances() {
        let progress = DICOMwebClient.StoreProgress(
            instancesStored: 5,
            totalInstances: 10,
            bytesUploaded: 0,
            totalBytes: nil
        )
        
        #expect(progress.fractionCompleted == 0.5)
    }
    
    @Test("StoreProgress fraction with bytes")
    func testProgressFractionWithBytes() {
        let progress = DICOMwebClient.StoreProgress(
            instancesStored: 0,
            totalInstances: 0,
            bytesUploaded: 500,
            totalBytes: 1000
        )
        
        #expect(progress.fractionCompleted == 0.5)
    }
    
    @Test("StoreProgress prefers instances over bytes")
    func testProgressPrefersInstances() {
        let progress = DICOMwebClient.StoreProgress(
            instancesStored: 9,
            totalInstances: 10,
            bytesUploaded: 100,
            totalBytes: 1000
        )
        
        // Should use instances: 9/10 = 0.9, not bytes: 100/1000 = 0.1
        #expect(progress.fractionCompleted == 0.9)
    }
    
    @Test("StoreProgress with no totals")
    func testProgressWithNoTotals() {
        let progress = DICOMwebClient.StoreProgress(
            instancesStored: 0,
            totalInstances: 0,
            bytesUploaded: 100,
            totalBytes: nil
        )
        
        #expect(progress.fractionCompleted == 0)
    }
    
    // MARK: - StoreOptions Tests
    
    @Test("Default store options")
    func testDefaultStoreOptions() {
        let options = DICOMwebClient.StoreOptions.default
        
        #expect(options.batchSize == nil)
        #expect(options.continueOnError == true)
    }
    
    @Test("Custom store options")
    func testCustomStoreOptions() {
        let options = DICOMwebClient.StoreOptions(batchSize: 50, continueOnError: false)
        
        #expect(options.batchSize == 50)
        #expect(options.continueOnError == false)
    }
    
    // MARK: - URL Builder Tests
    
    @Test("Store URL without study UID")
    func testStoreURLWithoutStudy() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let builder = config.urlBuilder
        
        let url = builder.storeURL
        #expect(url.absoluteString == "https://pacs.example.com/dicom-web/studies")
    }
    
    @Test("Store URL with study UID")
    func testStoreURLWithStudy() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let builder = config.urlBuilder
        
        let url = builder.storeURL(studyUID: "1.2.3.4.5")
        #expect(url.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3.4.5")
    }
    
    // MARK: - Client Store Tests
    
    @Test("Store empty instances returns empty response")
    func testStoreEmptyInstances() async throws {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let response = try await client.storeInstances(instances: [])
        
        #expect(response.storedInstances.isEmpty)
        #expect(response.failedInstances.isEmpty)
    }
}

// MARK: - Store Event Tests

@Suite("Store Event Tests")
struct StoreEventTests {
    
    @Test("StoreEvent progress case")
    func testStoreEventProgress() {
        let progress = DICOMwebClient.StoreProgress(
            instancesStored: 1,
            totalInstances: 2,
            bytesUploaded: 100,
            totalBytes: 200
        )
        
        let event = DICOMwebClient.StoreEvent.progress(progress)
        
        if case .progress(let p) = event {
            #expect(p.instancesStored == 1)
            #expect(p.totalInstances == 2)
        } else {
            #expect(Bool(false), "Expected progress event")
        }
    }
    
    @Test("StoreEvent completed case")
    func testStoreEventCompleted() {
        let response = STOWResponse(
            storedInstances: [STOWResponse.InstanceResult(sopInstanceUID: "1.2.3")]
        )
        
        let event = DICOMwebClient.StoreEvent.completed(response)
        
        if case .completed(let r) = event {
            #expect(r.successCount == 1)
        } else {
            #expect(Bool(false), "Expected completed event")
        }
    }
}
