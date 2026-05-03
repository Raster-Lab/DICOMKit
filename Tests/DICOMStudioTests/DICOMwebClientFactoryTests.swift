// DICOMwebClientFactoryTests.swift
// DICOMStudioTests
//
// Tests for DICOMwebClientFactory — bridge between DICOMStudio profiles and DICOMWeb library.

import Testing
@testable import DICOMStudio
import DICOMWeb
import Foundation

@Suite("DICOMwebClientFactory Tests")
struct DICOMwebClientFactoryTests {

    // MARK: - makeClient

    @Test("makeClient with valid URL creates client")
    func testMakeClientWithValidURL() throws {
        let profile = DICOMwebServerProfile(
            name: "Test PACS",
            baseURL: "https://pacs.example.com/dicom-web"
        )
        // Verifies no error is thrown for a valid URL
        _ = try DICOMwebClientFactory.makeClient(from: profile)
    }

    @Test("makeClient with empty URL throws invalidURL")
    func testMakeClientWithEmptyURLThrows() {
        let profile = DICOMwebServerProfile(name: "Bad", baseURL: "")
        #expect(throws: DICOMwebError.self) {
            _ = try DICOMwebClientFactory.makeClient(from: profile)
        }
    }

    @Test("makeClient with malformed URL throws invalidURL")
    func testMakeClientWithMalformedURLThrows() {
        let profile = DICOMwebServerProfile(name: "Bad", baseURL: "://not a url")
        #expect(throws: DICOMwebError.self) {
            _ = try DICOMwebClientFactory.makeClient(from: profile)
        }
    }

    @Test("makeClient with bearer auth creates client")
    func testMakeClientWithBearerAuth() throws {
        let profile = DICOMwebServerProfile(
            name: "Secure PACS",
            baseURL: "https://pacs.hospital.com",
            authMethod: .bearer,
            bearerToken: "test-token-abc123"
        )
        // Verifies no error is thrown for bearer auth
        _ = try DICOMwebClientFactory.makeClient(from: profile)
    }

    @Test("makeClient with basic auth creates client")
    func testMakeClientWithBasicAuth() throws {
        let profile = DICOMwebServerProfile(
            name: "Basic PACS",
            baseURL: "https://pacs.hospital.com",
            authMethod: .basic,
            username: "admin",
            password: "secret"
        )
        // Verifies no error is thrown for basic auth
        _ = try DICOMwebClientFactory.makeClient(from: profile)
    }

    // MARK: - buildQIDOQuery

    // QIDOQuery stores parameters keyed by the DICOM tag UID (GGGGEEEE) per QIDO-RS,
    // not by attribute keyword — see QIDOQueryAttribute in DICOMWeb. The tests below
    // use those constants so they stay in sync if the underlying keying changes.

    @Test("buildQIDOQuery with default params emits only the default limit")
    func testBuildQIDOQueryEmptyParams() {
        // QIDOQueryParams() defaults limit to 100, so the resulting query is not
        // truly empty — it carries the default page size.
        let params = QIDOQueryParams()
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        #expect(query.toParameters() == ["limit": "100"])
    }

    @Test("buildQIDOQuery with patientName sets parameter")
    func testBuildQIDOQueryPatientName() {
        let params = QIDOQueryParams(patientName: "DOE^JOHN")
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.patientName] == "DOE^JOHN")
    }

    @Test("buildQIDOQuery with patientID sets parameter")
    func testBuildQIDOQueryPatientID() {
        let params = QIDOQueryParams(patientID: "PAT001")
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.patientID] == "PAT001")
    }

    @Test("buildQIDOQuery with modality sets parameter")
    func testBuildQIDOQueryModality() {
        let params = QIDOQueryParams(modality: "CT")
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.modalitiesInStudy] == "CT")
    }

    @Test("buildQIDOQuery with accessionNumber sets parameter")
    func testBuildQIDOQueryAccessionNumber() {
        let params = QIDOQueryParams(accessionNumber: "ACC123")
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.accessionNumber] == "ACC123")
    }

    @Test("buildQIDOQuery with studyDescription sets parameter")
    func testBuildQIDOQueryStudyDescription() {
        let params = QIDOQueryParams(studyDescription: "Chest CT")
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.studyDescription] == "Chest CT")
    }

    @Test("buildQIDOQuery with limit sets parameter")
    func testBuildQIDOQueryLimit() {
        var params = QIDOQueryParams()
        params.limit = 50
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters["limit"] == "50")
    }

    @Test("buildQIDOQuery with offset sets parameter")
    func testBuildQIDOQueryOffset() {
        var params = QIDOQueryParams()
        params.offset = 10
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters["offset"] == "10")
    }

    @Test("buildQIDOQuery with all fields sets multiple parameters")
    func testBuildQIDOQueryAllFields() {
        var params = QIDOQueryParams(
            patientName: "SMITH*",
            patientID: "12345",
            modality: "MR",
            accessionNumber: "A001",
            studyDescription: "Brain MRI"
        )
        params.limit = 25
        params.offset = 5
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters[QIDOQueryAttribute.patientName] == "SMITH*")
        #expect(parameters[QIDOQueryAttribute.patientID] == "12345")
        #expect(parameters[QIDOQueryAttribute.modalitiesInStudy] == "MR")
        #expect(parameters[QIDOQueryAttribute.accessionNumber] == "A001")
        #expect(parameters[QIDOQueryAttribute.studyDescription] == "Brain MRI")
        #expect(parameters["limit"] == "25")
        #expect(parameters["offset"] == "5")
    }

    @Test("buildQIDOQuery with zero limit omits limit")
    func testBuildQIDOQueryZeroLimitOmitted() {
        var params = QIDOQueryParams()
        params.limit = 0
        let query = DICOMwebClientFactory.buildQIDOQuery(from: params)
        let parameters = query.toParameters()
        #expect(parameters["limit"] == nil)
    }

    // MARK: - mapStudyResults

    @Test("mapStudyResults converts empty results to empty array")
    func testMapStudyResultsEmpty() {
        let results = QIDOStudyResults(results: [], totalCount: 0)
        let items = DICOMwebClientFactory.mapStudyResults(results)
        #expect(items.isEmpty)
    }

    @Test("mapStudyResults converts study attributes correctly")
    func testMapStudyResultsConvertsAttributes() {
        let study = QIDOStudyResult(attributes: [
            "0020000D": ["Value": ["1.2.840.001"]],
            "00100010": ["Value": [["Alphabetic": "DOE^JANE"]]],
            "00100020": ["Value": ["PAT001"]],
            "00080020": ["Value": ["20260318"]],
            "00081030": ["Value": ["Chest CT"]]
        ])
        let results = QIDOStudyResults(results: [study], totalCount: 1)
        let items = DICOMwebClientFactory.mapStudyResults(results)
        #expect(items.count == 1)
        #expect(items.first?.queryLevel == .study)
    }

    // MARK: - mapSeriesResults

    @Test("mapSeriesResults converts empty results to empty array")
    func testMapSeriesResultsEmpty() {
        let results = QIDOSeriesResults(results: [], totalCount: 0)
        let items = DICOMwebClientFactory.mapSeriesResults(results)
        #expect(items.isEmpty)
    }

    @Test("mapSeriesResults sets queryLevel to series")
    func testMapSeriesResultsSetsQueryLevel() {
        let series = QIDOSeriesResult(attributes: [:])
        let results = QIDOSeriesResults(results: [series], totalCount: 1)
        let items = DICOMwebClientFactory.mapSeriesResults(results)
        #expect(items.first?.queryLevel == .series)
    }

    // MARK: - mapInstanceResults

    @Test("mapInstanceResults converts empty results to empty array")
    func testMapInstanceResultsEmpty() {
        let results = QIDOInstanceResults(results: [], totalCount: 0)
        let items = DICOMwebClientFactory.mapInstanceResults(results)
        #expect(items.isEmpty)
    }

    @Test("mapInstanceResults sets queryLevel to instance")
    func testMapInstanceResultsSetsQueryLevel() {
        let instance = QIDOInstanceResult(attributes: [:])
        let results = QIDOInstanceResults(results: [instance], totalCount: 1)
        let items = DICOMwebClientFactory.mapInstanceResults(results)
        #expect(items.first?.queryLevel == .instance)
    }
}
