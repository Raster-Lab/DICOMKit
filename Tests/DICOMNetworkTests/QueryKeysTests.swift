import XCTest
import DICOMCore
@testable import DICOMNetwork

final class QueryKeysTests: XCTestCase {
    
    // MARK: - Basic Construction Tests
    
    func testEmptyQueryKeys() {
        let keys = QueryKeys(level: .study)
        
        XCTAssertEqual(keys.level, .study)
        XCTAssertTrue(keys.keys.isEmpty)
    }
    
    func testQueryKeyConstruction() {
        let key = QueryKey(tag: .patientName, value: "DOE^JOHN", vr: .PN)
        
        XCTAssertEqual(key.tag, Tag.patientName)
        XCTAssertEqual(key.value, "DOE^JOHN")
        XCTAssertEqual(key.vr, .PN)
    }
    
    // MARK: - Patient Level Keys Tests
    
    func testPatientNameKey() {
        let keys = QueryKeys(level: .patient)
            .patientName("DOE^JOHN*")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.patientName)
        XCTAssertEqual(keys.keys[0].value, "DOE^JOHN*")
        XCTAssertEqual(keys.keys[0].vr, .PN)
    }
    
    func testPatientIDKey() {
        let keys = QueryKeys(level: .patient)
            .patientID("12345678")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.patientID)
        XCTAssertEqual(keys.keys[0].value, "12345678")
        XCTAssertEqual(keys.keys[0].vr, .LO)
    }
    
    func testPatientBirthDateKey() {
        let keys = QueryKeys(level: .patient)
            .patientBirthDate("19800101")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.patientBirthDate)
        XCTAssertEqual(keys.keys[0].value, "19800101")
        XCTAssertEqual(keys.keys[0].vr, .DA)
    }
    
    func testPatientBirthDateRangeKey() {
        let keys = QueryKeys(level: .patient)
            .patientBirthDate("19800101-19901231")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].value, "19800101-19901231")
    }
    
    func testPatientSexKey() {
        let keys = QueryKeys(level: .patient)
            .patientSex("M")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.patientSex)
        XCTAssertEqual(keys.keys[0].value, "M")
        XCTAssertEqual(keys.keys[0].vr, .CS)
    }
    
    func testRequestPatientName() {
        let keys = QueryKeys(level: .patient)
            .requestPatientName()
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.patientName)
        XCTAssertEqual(keys.keys[0].value, "")
    }
    
    // MARK: - Study Level Keys Tests
    
    func testStudyInstanceUIDKey() {
        let keys = QueryKeys(level: .study)
            .studyInstanceUID("1.2.3.4.5.6.7.8.9")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.studyInstanceUID)
        XCTAssertEqual(keys.keys[0].value, "1.2.3.4.5.6.7.8.9")
        XCTAssertEqual(keys.keys[0].vr, .UI)
    }
    
    func testStudyDateKey() {
        let keys = QueryKeys(level: .study)
            .studyDate("20240101")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.studyDate)
        XCTAssertEqual(keys.keys[0].value, "20240101")
        XCTAssertEqual(keys.keys[0].vr, .DA)
    }
    
    func testStudyDateRangeKey() {
        let keys = QueryKeys(level: .study)
            .studyDate("20240101-20241231")
        
        XCTAssertEqual(keys.keys[0].value, "20240101-20241231")
    }
    
    func testStudyTimeKey() {
        let keys = QueryKeys(level: .study)
            .studyTime("080000-170000")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.studyTime)
        XCTAssertEqual(keys.keys[0].value, "080000-170000")
        XCTAssertEqual(keys.keys[0].vr, .TM)
    }
    
    func testAccessionNumberKey() {
        let keys = QueryKeys(level: .study)
            .accessionNumber("ACC12345")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.accessionNumber)
        XCTAssertEqual(keys.keys[0].value, "ACC12345")
        XCTAssertEqual(keys.keys[0].vr, .SH)
    }
    
    func testStudyDescriptionKey() {
        let keys = QueryKeys(level: .study)
            .studyDescription("*CHEST*")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.studyDescription)
        XCTAssertEqual(keys.keys[0].value, "*CHEST*")
        XCTAssertEqual(keys.keys[0].vr, .LO)
    }
    
    func testModalitiesInStudyKey() {
        let keys = QueryKeys(level: .study)
            .modalitiesInStudy("CT\\MR")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.modalitiesInStudy)
        XCTAssertEqual(keys.keys[0].value, "CT\\MR")
        XCTAssertEqual(keys.keys[0].vr, .CS)
    }
    
    // MARK: - Series Level Keys Tests
    
    func testSeriesInstanceUIDKey() {
        let keys = QueryKeys(level: .series)
            .seriesInstanceUID("1.2.3.4.5.6.7.8.9.10")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.seriesInstanceUID)
        XCTAssertEqual(keys.keys[0].value, "1.2.3.4.5.6.7.8.9.10")
        XCTAssertEqual(keys.keys[0].vr, .UI)
    }
    
    func testModalityKey() {
        let keys = QueryKeys(level: .series)
            .modality("CT")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.modality)
        XCTAssertEqual(keys.keys[0].value, "CT")
        XCTAssertEqual(keys.keys[0].vr, .CS)
    }
    
    func testSeriesNumberKey() {
        let keys = QueryKeys(level: .series)
            .seriesNumber("1")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.seriesNumber)
        XCTAssertEqual(keys.keys[0].value, "1")
        XCTAssertEqual(keys.keys[0].vr, .IS)
    }
    
    func testSeriesDescriptionKey() {
        let keys = QueryKeys(level: .series)
            .seriesDescription("AXIAL")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.seriesDescription)
        XCTAssertEqual(keys.keys[0].value, "AXIAL")
        XCTAssertEqual(keys.keys[0].vr, .LO)
    }
    
    func testBodyPartExaminedKey() {
        let keys = QueryKeys(level: .series)
            .bodyPartExamined("CHEST")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.bodyPartExamined)
        XCTAssertEqual(keys.keys[0].value, "CHEST")
        XCTAssertEqual(keys.keys[0].vr, .CS)
    }
    
    // MARK: - Instance Level Keys Tests
    
    func testSOPInstanceUIDKey() {
        let keys = QueryKeys(level: .image)
            .sopInstanceUID("1.2.3.4.5.6.7.8.9.10.11")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.sopInstanceUID)
        XCTAssertEqual(keys.keys[0].value, "1.2.3.4.5.6.7.8.9.10.11")
        XCTAssertEqual(keys.keys[0].vr, .UI)
    }
    
    func testInstanceNumberKey() {
        let keys = QueryKeys(level: .image)
            .instanceNumber("1")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.instanceNumber)
        XCTAssertEqual(keys.keys[0].value, "1")
        XCTAssertEqual(keys.keys[0].vr, .IS)
    }
    
    func testContentDateKey() {
        let keys = QueryKeys(level: .image)
            .contentDate("20240115")
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, Tag.contentDate)
        XCTAssertEqual(keys.keys[0].value, "20240115")
        XCTAssertEqual(keys.keys[0].vr, .DA)
    }
    
    // MARK: - Chaining Tests
    
    func testMultipleKeysChaining() {
        let keys = QueryKeys(level: .study)
            .patientName("DOE^JOHN*")
            .patientID("12345")
            .studyDate("20240101-20241231")
            .requestStudyDescription()
            .requestAccessionNumber()
        
        XCTAssertEqual(keys.keys.count, 5)
        XCTAssertEqual(keys.level, .study)
    }
    
    func testGenericMatchingKey() {
        let customTag = Tag(group: 0x0008, element: 0x0080)
        let keys = QueryKeys(level: .study)
            .matching(customTag, value: "TEST", vr: .LO)
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, customTag)
        XCTAssertEqual(keys.keys[0].value, "TEST")
        XCTAssertEqual(keys.keys[0].vr, .LO)
    }
    
    func testGenericReturningKey() {
        let customTag = Tag(group: 0x0008, element: 0x0090)
        let keys = QueryKeys(level: .study)
            .returning(customTag, vr: .PN)
        
        XCTAssertEqual(keys.keys.count, 1)
        XCTAssertEqual(keys.keys[0].tag, customTag)
        XCTAssertEqual(keys.keys[0].value, "")
        XCTAssertEqual(keys.keys[0].vr, .PN)
    }
    
    // MARK: - Default Keys Tests
    
    func testDefaultPatientKeys() {
        let keys = QueryKeys.defaultPatientKeys()
        
        XCTAssertEqual(keys.level, .patient)
        XCTAssertGreaterThan(keys.keys.count, 0)
        
        // Check that expected return keys are present
        let tags = keys.keys.map { $0.tag }
        XCTAssertTrue(tags.contains(.patientName))
        XCTAssertTrue(tags.contains(.patientID))
        XCTAssertTrue(tags.contains(.patientBirthDate))
        XCTAssertTrue(tags.contains(.patientSex))
    }
    
    func testDefaultStudyKeys() {
        let keys = QueryKeys.defaultStudyKeys()
        
        XCTAssertEqual(keys.level, .study)
        XCTAssertGreaterThan(keys.keys.count, 0)
        
        // Check that expected return keys are present
        let tags = keys.keys.map { $0.tag }
        XCTAssertTrue(tags.contains(.studyInstanceUID))
        XCTAssertTrue(tags.contains(.studyDate))
        XCTAssertTrue(tags.contains(.studyDescription))
        XCTAssertTrue(tags.contains(.accessionNumber))
        XCTAssertTrue(tags.contains(.patientName))
    }
    
    func testDefaultSeriesKeys() {
        let keys = QueryKeys.defaultSeriesKeys()
        
        XCTAssertEqual(keys.level, .series)
        XCTAssertGreaterThan(keys.keys.count, 0)
        
        // Check that expected return keys are present
        let tags = keys.keys.map { $0.tag }
        XCTAssertTrue(tags.contains(.seriesInstanceUID))
        XCTAssertTrue(tags.contains(.seriesNumber))
        XCTAssertTrue(tags.contains(.modality))
    }
    
    func testDefaultInstanceKeys() {
        let keys = QueryKeys.defaultInstanceKeys()
        
        XCTAssertEqual(keys.level, .image)
        XCTAssertGreaterThan(keys.keys.count, 0)
        
        // Check that expected return keys are present
        let tags = keys.keys.map { $0.tag }
        XCTAssertTrue(tags.contains(.sopInstanceUID))
        XCTAssertTrue(tags.contains(.sopClassUID))
        XCTAssertTrue(tags.contains(.instanceNumber))
    }
    
    // MARK: - Equality Tests
    
    func testQueryKeyEquality() {
        let key1 = QueryKey(tag: .patientName, value: "DOE", vr: .PN)
        let key2 = QueryKey(tag: .patientName, value: "DOE", vr: .PN)
        let key3 = QueryKey(tag: .patientName, value: "SMITH", vr: .PN)
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testQueryKeysEquality() {
        let keys1 = QueryKeys(level: .study).patientName("DOE")
        let keys2 = QueryKeys(level: .study).patientName("DOE")
        let keys3 = QueryKeys(level: .study).patientName("SMITH")
        let keys4 = QueryKeys(level: .series).patientName("DOE")
        
        XCTAssertEqual(keys1, keys2)
        XCTAssertNotEqual(keys1, keys3)
        XCTAssertNotEqual(keys1, keys4)
    }
    
    func testQueryKeyHashable() {
        let key1 = QueryKey(tag: .patientName, value: "DOE", vr: .PN)
        let key2 = QueryKey(tag: .patientID, value: "123", vr: .LO)
        
        var set = Set<QueryKey>()
        set.insert(key1)
        set.insert(key2)
        set.insert(key1) // Duplicate
        
        XCTAssertEqual(set.count, 2)
    }
}
