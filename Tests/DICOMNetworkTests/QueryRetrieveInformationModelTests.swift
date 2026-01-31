import XCTest
import DICOMCore
@testable import DICOMNetwork

final class QueryRetrieveInformationModelTests: XCTestCase {
    
    // MARK: - SOP Class UID Tests
    
    func testPatientRootFindSOPClassUID() {
        XCTAssertEqual(patientRootQueryRetrieveFindSOPClassUID, "1.2.840.10008.5.1.4.1.2.1.1")
    }
    
    func testStudyRootFindSOPClassUID() {
        XCTAssertEqual(studyRootQueryRetrieveFindSOPClassUID, "1.2.840.10008.5.1.4.1.2.2.1")
    }
    
    func testPatientStudyOnlyFindSOPClassUID() {
        XCTAssertEqual(patientStudyOnlyQueryRetrieveFindSOPClassUID, "1.2.840.10008.5.1.4.1.2.3.1")
    }
    
    // MARK: - Information Model Tests
    
    func testPatientRootFindSOPClass() {
        let model = QueryRetrieveInformationModel.patientRoot
        XCTAssertEqual(model.findSOPClassUID, patientRootQueryRetrieveFindSOPClassUID)
    }
    
    func testStudyRootFindSOPClass() {
        let model = QueryRetrieveInformationModel.studyRoot
        XCTAssertEqual(model.findSOPClassUID, studyRootQueryRetrieveFindSOPClassUID)
    }
    
    // MARK: - Supported Levels Tests
    
    func testPatientRootSupportedLevels() {
        let model = QueryRetrieveInformationModel.patientRoot
        let supportedLevels = model.supportedLevels
        
        XCTAssertEqual(supportedLevels.count, 4)
        XCTAssertTrue(supportedLevels.contains(.patient))
        XCTAssertTrue(supportedLevels.contains(.study))
        XCTAssertTrue(supportedLevels.contains(.series))
        XCTAssertTrue(supportedLevels.contains(.image))
    }
    
    func testStudyRootSupportedLevels() {
        let model = QueryRetrieveInformationModel.studyRoot
        let supportedLevels = model.supportedLevels
        
        XCTAssertEqual(supportedLevels.count, 3)
        XCTAssertFalse(supportedLevels.contains(.patient))
        XCTAssertTrue(supportedLevels.contains(.study))
        XCTAssertTrue(supportedLevels.contains(.series))
        XCTAssertTrue(supportedLevels.contains(.image))
    }
    
    func testPatientRootSupportsLevel() {
        let model = QueryRetrieveInformationModel.patientRoot
        
        XCTAssertTrue(model.supportsLevel(.patient))
        XCTAssertTrue(model.supportsLevel(.study))
        XCTAssertTrue(model.supportsLevel(.series))
        XCTAssertTrue(model.supportsLevel(.image))
    }
    
    func testStudyRootSupportsLevel() {
        let model = QueryRetrieveInformationModel.studyRoot
        
        XCTAssertFalse(model.supportsLevel(.patient))
        XCTAssertTrue(model.supportsLevel(.study))
        XCTAssertTrue(model.supportsLevel(.series))
        XCTAssertTrue(model.supportsLevel(.image))
    }
    
    // MARK: - Equatable and Hashable Tests
    
    func testInformationModelEquality() {
        XCTAssertEqual(QueryRetrieveInformationModel.patientRoot, QueryRetrieveInformationModel.patientRoot)
        XCTAssertEqual(QueryRetrieveInformationModel.studyRoot, QueryRetrieveInformationModel.studyRoot)
        XCTAssertNotEqual(QueryRetrieveInformationModel.patientRoot, QueryRetrieveInformationModel.studyRoot)
    }
    
    func testInformationModelHashable() {
        let set: Set<QueryRetrieveInformationModel> = [.patientRoot, .studyRoot]
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - Description Tests
    
    func testPatientRootDescription() {
        XCTAssertEqual(QueryRetrieveInformationModel.patientRoot.description, "Patient Root")
    }
    
    func testStudyRootDescription() {
        XCTAssertEqual(QueryRetrieveInformationModel.studyRoot.description, "Study Root")
    }
}
