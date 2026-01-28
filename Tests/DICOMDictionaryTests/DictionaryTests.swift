import Testing
@testable import DICOMDictionary
@testable import DICOMCore

@Suite("Dictionary Tests")
struct DictionaryTests {
    
    @Test("Data element dictionary lookup by tag")
    func testDataElementLookupByTag() {
        let entry = DataElementDictionary.lookup(tag: .patientName)
        #expect(entry != nil)
        #expect(entry?.name == "Patient's Name")
        #expect(entry?.keyword == "PatientName")
        #expect(entry?.vr.contains(.PN) == true)
    }
    
    @Test("Data element dictionary lookup by keyword")
    func testDataElementLookupByKeyword() {
        let entry = DataElementDictionary.lookup(keyword: "PatientName")
        #expect(entry != nil)
        #expect(entry?.tag == .patientName)
        #expect(entry?.name == "Patient's Name")
    }
    
    @Test("File Meta Information elements")
    func testFileMetaInformationElements() {
        let transferSyntax = DataElementDictionary.lookup(tag: .transferSyntaxUID)
        #expect(transferSyntax != nil)
        #expect(transferSyntax?.keyword == "TransferSyntaxUID")
        #expect(transferSyntax?.vr.contains(.UI) == true)
        
        let sopClassUID = DataElementDictionary.lookup(tag: .mediaStorageSOPClassUID)
        #expect(sopClassUID != nil)
        #expect(sopClassUID?.keyword == "MediaStorageSOPClassUID")
    }
    
    @Test("UID dictionary lookup by UID")
    func testUIDLookupByUID() {
        let entry = UIDDictionary.lookup(uid: "1.2.840.10008.1.2.1")
        #expect(entry != nil)
        #expect(entry?.name == "Explicit VR Little Endian")
        #expect(entry?.keyword == "ExplicitVRLittleEndian")
        #expect(entry?.type == .transferSyntax)
    }
    
    @Test("UID dictionary lookup by keyword")
    func testUIDLookupByKeyword() {
        let entry = UIDDictionary.lookup(keyword: "ExplicitVRLittleEndian")
        #expect(entry != nil)
        #expect(entry?.uid == "1.2.840.10008.1.2.1")
        #expect(entry?.type == .transferSyntax)
    }
    
    @Test("Transfer Syntax UIDs")
    func testTransferSyntaxUIDs() {
        let transferSyntaxes = UIDDictionary.transferSyntaxes
        #expect(transferSyntaxes.count >= 3)
        
        let explicitVRLE = transferSyntaxes.first { $0.uid == "1.2.840.10008.1.2.1" }
        #expect(explicitVRLE != nil)
    }
    
    @Test("SOP Class UIDs")
    func testSOPClassUIDs() {
        let sopClasses = UIDDictionary.sopClasses
        #expect(sopClasses.count >= 1)
        
        let ctImage = UIDDictionary.lookup(uid: "1.2.840.10008.5.1.4.1.1.2")
        #expect(ctImage != nil)
        #expect(ctImage?.name == "CT Image Storage")
        #expect(ctImage?.type == .sopClass)
    }
}
