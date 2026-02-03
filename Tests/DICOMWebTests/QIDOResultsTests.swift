import Testing
import Foundation
@testable import DICOMWeb

@Suite("QIDOResults Tests")
struct QIDOResultsTests {
    
    // MARK: - QIDOStudyResult Tests
    
    @Test("Parse study result with basic attributes")
    func testParseStudyResultBasic() {
        let json: [String: Any] = [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]],
            "00080020": ["vr": "DA", "Value": ["20240115"]],
            "00081030": ["vr": "LO", "Value": ["CT Head Study"]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.studyInstanceUID == "1.2.3.4.5")
        #expect(result.studyDate == "20240115")
        #expect(result.studyDescription == "CT Head Study")
    }
    
    @Test("Parse study result with patient name (PersonName format)")
    func testParseStudyResultPatientName() {
        let json: [String: Any] = [
            "00100010": ["vr": "PN", "Value": [["Alphabetic": "Smith^John"]]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.patientName == "Smith^John")
    }
    
    @Test("Parse study result with patient ID")
    func testParseStudyResultPatientID() {
        let json: [String: Any] = [
            "00100020": ["vr": "LO", "Value": ["PATIENT123"]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.patientID == "PATIENT123")
    }
    
    @Test("Parse study result with numeric counts")
    func testParseStudyResultNumericCounts() {
        let json: [String: Any] = [
            "00201206": ["vr": "IS", "Value": [5]],
            "00201208": ["vr": "IS", "Value": [150]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.numberOfStudyRelatedSeries == 5)
        #expect(result.numberOfStudyRelatedInstances == 150)
    }
    
    @Test("Parse study result with modalities in study")
    func testParseStudyResultModalitiesInStudy() {
        let json: [String: Any] = [
            "00080061": ["vr": "CS", "Value": ["CT", "MR", "US"]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.modalitiesInStudy == ["CT", "MR", "US"])
    }
    
    @Test("Parse study result with missing attributes")
    func testParseStudyResultMissingAttributes() {
        let json: [String: Any] = [:]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.studyInstanceUID == nil)
        #expect(result.studyDate == nil)
        #expect(result.patientName == nil)
        #expect(result.numberOfStudyRelatedSeries == nil)
    }
    
    @Test("Parse study result with all attributes")
    func testParseStudyResultAllAttributes() {
        let json: [String: Any] = [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]],
            "00080020": ["vr": "DA", "Value": ["20240115"]],
            "00080030": ["vr": "TM", "Value": ["143000"]],
            "00081030": ["vr": "LO", "Value": ["CT Head Study"]],
            "00080050": ["vr": "SH", "Value": ["ACC123"]],
            "00200010": ["vr": "SH", "Value": ["STUDY001"]],
            "00080090": ["vr": "PN", "Value": [["Alphabetic": "Jones^Robert"]]],
            "00100010": ["vr": "PN", "Value": [["Alphabetic": "Smith^John"]]],
            "00100020": ["vr": "LO", "Value": ["PAT123"]],
            "00100030": ["vr": "DA", "Value": ["19800101"]],
            "00100040": ["vr": "CS", "Value": ["M"]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.studyInstanceUID == "1.2.3.4.5")
        #expect(result.studyDate == "20240115")
        #expect(result.studyTime == "143000")
        #expect(result.studyDescription == "CT Head Study")
        #expect(result.accessionNumber == "ACC123")
        #expect(result.studyID == "STUDY001")
        #expect(result.referringPhysicianName == "Jones^Robert")
        #expect(result.patientName == "Smith^John")
        #expect(result.patientID == "PAT123")
        #expect(result.patientBirthDate == "19800101")
        #expect(result.patientSex == "M")
    }
    
    // MARK: - QIDOSeriesResult Tests
    
    @Test("Parse series result with basic attributes")
    func testParseSeriesResultBasic() {
        let json: [String: Any] = [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]],
            "00080060": ["vr": "CS", "Value": ["CT"]],
            "00200011": ["vr": "IS", "Value": [3]]
        ]
        
        let result = QIDOSeriesResult(attributes: json)
        
        #expect(result.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(result.modality == "CT")
        #expect(result.seriesNumber == 3)
    }
    
    @Test("Parse series result with description and body part")
    func testParseSeriesResultWithDescription() {
        let json: [String: Any] = [
            "0008103E": ["vr": "LO", "Value": ["Axial 5mm"]],
            "00180015": ["vr": "CS", "Value": ["CHEST"]]
        ]
        
        let result = QIDOSeriesResult(attributes: json)
        
        #expect(result.seriesDescription == "Axial 5mm")
        #expect(result.bodyPartExamined == "CHEST")
    }
    
    @Test("Parse series result with parent study UID")
    func testParseSeriesResultWithParentStudy() {
        let json: [String: Any] = [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]],
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ]
        
        let result = QIDOSeriesResult(attributes: json)
        
        #expect(result.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(result.studyInstanceUID == "1.2.3.4.5")
    }
    
    @Test("Parse series result with instance count")
    func testParseSeriesResultInstanceCount() {
        let json: [String: Any] = [
            "00201209": ["vr": "IS", "Value": [250]]
        ]
        
        let result = QIDOSeriesResult(attributes: json)
        
        #expect(result.numberOfSeriesRelatedInstances == 250)
    }
    
    // MARK: - QIDOInstanceResult Tests
    
    @Test("Parse instance result with basic attributes")
    func testParseInstanceResultBasic() {
        let json: [String: Any] = [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.7"]],
            "00080016": ["vr": "UI", "Value": ["1.2.840.10008.5.1.4.1.1.2"]],
            "00200013": ["vr": "IS", "Value": [10]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        #expect(result.sopInstanceUID == "1.2.3.4.5.6.7")
        #expect(result.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(result.instanceNumber == 10)
    }
    
    @Test("Parse instance result with image dimensions")
    func testParseInstanceResultDimensions() {
        let json: [String: Any] = [
            "00280010": ["vr": "US", "Value": [512]],
            "00280011": ["vr": "US", "Value": [512]],
            "00280008": ["vr": "IS", "Value": [100]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        #expect(result.rows == 512)
        #expect(result.columns == 512)
        #expect(result.numberOfFrames == 100)
    }
    
    @Test("Parse instance result with parent UIDs")
    func testParseInstanceResultWithParentUIDs() {
        let json: [String: Any] = [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.7"]],
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]],
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        #expect(result.sopInstanceUID == "1.2.3.4.5.6.7")
        #expect(result.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(result.studyInstanceUID == "1.2.3.4.5")
    }
    
    // MARK: - QIDOResult Protocol Tests
    
    @Test("String accessor for numeric value")
    func testStringAccessorForNumeric() {
        let json: [String: Any] = [
            "00200013": ["vr": "IS", "Value": [42]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        // Integer should be convertible to string
        #expect(result.string(forTag: "00200013") == "42")
    }
    
    @Test("Integer accessor for string value")
    func testIntegerAccessorForString() {
        let json: [String: Any] = [
            "00200013": ["vr": "IS", "Value": ["42"]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        // String number should be convertible to integer
        #expect(result.integer(forTag: "00200013") == 42)
    }
    
    @Test("Double accessor")
    func testDoubleAccessor() {
        let json: [String: Any] = [
            "00181050": ["vr": "DS", "Value": [1.5]]
        ]
        
        let result = QIDOInstanceResult(attributes: json)
        
        #expect(result.double(forTag: "00181050") == 1.5)
    }
    
    @Test("Strings accessor for multiple values")
    func testStringsAccessorMultipleValues() {
        let json: [String: Any] = [
            "00080061": ["vr": "CS", "Value": ["CT", "MR", "US"]]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        let modalities = result.strings(forTag: "00080061")
        #expect(modalities == ["CT", "MR", "US"])
    }
    
    @Test("Empty value array returns nil for single value")
    func testEmptyValueArrayReturnsNil() {
        let json: [String: Any] = [
            "00100010": ["vr": "PN", "Value": []]
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.patientName == nil)
    }
    
    @Test("Missing Value key returns nil")
    func testMissingValueKeyReturnsNil() {
        let json: [String: Any] = [
            "00100010": ["vr": "PN"]  // No Value key
        ]
        
        let result = QIDOStudyResult(attributes: json)
        
        #expect(result.patientName == nil)
    }
    
    // MARK: - QIDOResults Container Tests
    
    @Test("Results container basic properties")
    func testResultsContainerBasic() {
        let study1 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ])
        let study2 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.6"]]
        ])
        
        let results = QIDOResults(results: [study1, study2])
        
        #expect(results.count == 2)
        #expect(!results.isEmpty)
        #expect(results.results.count == 2)
    }
    
    @Test("Results container empty")
    func testResultsContainerEmpty() {
        let results = QIDOResults<QIDOStudyResult>(results: [])
        
        #expect(results.count == 0)
        #expect(results.isEmpty)
        #expect(!results.hasMore)
        #expect(results.nextOffset == nil)
    }
    
    @Test("Results container with total count - no more results")
    func testResultsContainerNoMoreResults() {
        let study1 = QIDOStudyResult(attributes: [:])
        let study2 = QIDOStudyResult(attributes: [:])
        
        let results = QIDOResults(
            results: [study1, study2],
            totalCount: 2,
            offset: 0
        )
        
        #expect(!results.hasMore)
        #expect(results.nextOffset == nil)
        #expect(results.totalCount == 2)
    }
    
    @Test("Results container with total count - has more results")
    func testResultsContainerHasMoreResults() {
        let studies = (0..<10).map { _ in QIDOStudyResult(attributes: [:]) }
        
        let results = QIDOResults(
            results: studies,
            totalCount: 50,
            offset: 0,
            limit: 10
        )
        
        #expect(results.hasMore)
        #expect(results.nextOffset == 10)
        #expect(results.totalCount == 50)
    }
    
    @Test("Results container with offset")
    func testResultsContainerWithOffset() {
        let studies = (0..<10).map { _ in QIDOStudyResult(attributes: [:]) }
        
        let results = QIDOResults(
            results: studies,
            totalCount: 50,
            offset: 20,
            limit: 10
        )
        
        #expect(results.hasMore)
        #expect(results.nextOffset == 30)  // 20 + 10
    }
    
    @Test("Results container without total count but with limit")
    func testResultsContainerWithoutTotalCountWithLimit() {
        let studies = (0..<10).map { _ in QIDOStudyResult(attributes: [:]) }
        
        // When total count is unknown but we got limit results, assume there might be more
        let results = QIDOResults(
            results: studies,
            totalCount: nil,
            offset: 0,
            limit: 10
        )
        
        #expect(results.hasMore)
        #expect(results.nextOffset == 10)
    }
    
    @Test("Results container without total count less than limit")
    func testResultsContainerLessThanLimit() {
        let studies = (0..<5).map { _ in QIDOStudyResult(attributes: [:]) }
        
        // When we got fewer results than limit, there are no more
        let results = QIDOResults(
            results: studies,
            totalCount: nil,
            offset: 0,
            limit: 10
        )
        
        #expect(!results.hasMore)
        #expect(results.nextOffset == nil)
    }
    
    // MARK: - Equatable Tests
    
    @Test("QIDOStudyResult equality by UID")
    func testStudyResultEquality() {
        let result1 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]],
            "00080020": ["vr": "DA", "Value": ["20240101"]]
        ])
        let result2 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]],
            "00080020": ["vr": "DA", "Value": ["20240202"]]  // Different date
        ])
        
        // Same Study Instance UID means equal
        #expect(result1 == result2)
    }
    
    @Test("QIDOStudyResult inequality by UID")
    func testStudyResultInequality() {
        let result1 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ])
        let result2 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.6"]]
        ])
        
        #expect(result1 != result2)
    }
    
    @Test("QIDOSeriesResult equality by UID")
    func testSeriesResultEquality() {
        let result1 = QIDOSeriesResult(attributes: [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]]
        ])
        let result2 = QIDOSeriesResult(attributes: [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]]
        ])
        
        #expect(result1 == result2)
    }
    
    @Test("QIDOInstanceResult equality by UID")
    func testInstanceResultEquality() {
        let result1 = QIDOInstanceResult(attributes: [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.7"]]
        ])
        let result2 = QIDOInstanceResult(attributes: [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.7"]]
        ])
        
        #expect(result1 == result2)
    }
    
    // MARK: - Hashable Tests
    
    @Test("QIDOStudyResult hashable in Set")
    func testStudyResultHashable() {
        let result1 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ])
        let result2 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.5"]]
        ])
        let result3 = QIDOStudyResult(attributes: [
            "0020000D": ["vr": "UI", "Value": ["1.2.3.4.6"]]
        ])
        
        let set: Set<QIDOStudyResult> = [result1, result2, result3]
        
        // result1 and result2 have same UID, so set should have 2 items
        #expect(set.count == 2)
    }
    
    @Test("QIDOSeriesResult hashable in Set")
    func testSeriesResultHashable() {
        let result1 = QIDOSeriesResult(attributes: [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]]
        ])
        let result2 = QIDOSeriesResult(attributes: [
            "0020000E": ["vr": "UI", "Value": ["1.2.3.4.5.6"]]
        ])
        
        let set: Set<QIDOSeriesResult> = [result1, result2]
        
        #expect(set.count == 1)
    }
    
    @Test("QIDOInstanceResult hashable in Set")
    func testInstanceResultHashable() {
        let result1 = QIDOInstanceResult(attributes: [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.7"]]
        ])
        let result2 = QIDOInstanceResult(attributes: [
            "00080018": ["vr": "UI", "Value": ["1.2.3.4.5.6.8"]]
        ])
        
        let set: Set<QIDOInstanceResult> = [result1, result2]
        
        #expect(set.count == 2)
    }
}

// MARK: - Type Alias Tests

@Suite("QIDO Type Alias Tests")
struct QIDOTypeAliasTests {
    
    @Test("QIDOStudyResults type alias")
    func testStudyResultsTypeAlias() {
        let results: QIDOStudyResults = QIDOResults(results: [])
        #expect(results.isEmpty)
    }
    
    @Test("QIDOSeriesResults type alias")
    func testSeriesResultsTypeAlias() {
        let results: QIDOSeriesResults = QIDOResults(results: [])
        #expect(results.isEmpty)
    }
    
    @Test("QIDOInstanceResults type alias")
    func testInstanceResultsTypeAlias() {
        let results: QIDOInstanceResults = QIDOResults(results: [])
        #expect(results.isEmpty)
    }
}
