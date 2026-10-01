import XCTest
import DICOMCore
import DICOMKit
@testable import dicom_info

/// `--tag` accepts PS3.6 2026a keywords exactly (the help example `--tag PatientName
/// --tag StudyDate` used to select nothing, because the shared presenter matches names
/// such as "Patient's Name" and tag text only).
final class InfoTagFilterTests: XCTestCase {

    func testKeywordContributesItsTag() {
        XCTAssertEqual(DICOMInfo.filterTerms(["PatientName", "Patient"]),
                       ["PatientName", "Patient", "(0010,0010)"])
        XCTAssertEqual(DICOMInfo.filterTerms(["patientname"]), ["patientname"], "keywords are exact")
    }

    func testHelpExampleSelectsBothAttributes() throws {
        var ds = DataSet()
        ds.setString("DOE^JOHN", for: Tag(group: 0x0010, element: 0x0010), vr: .PN)
        ds.setString("20200101", for: Tag(group: 0x0008, element: 0x0020), vr: .DA)
        ds.setString("CT", for: Tag(group: 0x0008, element: 0x0060), vr: .CS)
        let file = DICOMFile(fileMetaInformation: DataSet(), dataSet: ds)
        let out = try MetadataPresenter(file: file, filterTags: DICOMInfo.filterTerms(["PatientName", "StudyDate"]))
            .render(format: .csv)
        XCTAssertEqual(out, """
            Tag,Name,VR,Value
            "(0008,0020)","Study Date","DA","20200101"
            "(0010,0010)","Patient's Name","PN","DOE^JOHN"

            """)
    }
}
