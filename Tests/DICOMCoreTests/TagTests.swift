import Testing
@testable import DICOMCore

@Suite("Tag Tests")
struct TagTests {
    
    @Test("Tag creation")
    func testTagCreation() {
        let tag = Tag(group: 0x0010, element: 0x0010)
        #expect(tag.group == 0x0010)
        #expect(tag.element == 0x0010)
    }
    
    @Test("Tag description format")
    func testTagDescription() {
        let tag = Tag(group: 0x0010, element: 0x0010)
        #expect(tag.description == "(0010,0010)")
        
        let tag2 = Tag(group: 0x0008, element: 0x0018)
        #expect(tag2.description == "(0008,0018)")
    }
    
    @Test("Private tag detection")
    func testPrivateTagDetection() {
        // Odd group numbers are private (PS3.5 Section 7.8)
        let privateTag = Tag(group: 0x0011, element: 0x0010)
        #expect(privateTag.isPrivate == true)
        
        let privateTag2 = Tag(group: 0x0009, element: 0x0001)
        #expect(privateTag2.isPrivate == true)
        
        // Even group numbers are standard
        let standardTag = Tag(group: 0x0010, element: 0x0010)
        #expect(standardTag.isPrivate == false)
        
        let standardTag2 = Tag(group: 0x0008, element: 0x0018)
        #expect(standardTag2.isPrivate == false)
    }
    
    @Test("Tag comparison")
    func testTagComparison() {
        let tag1 = Tag(group: 0x0008, element: 0x0010)
        let tag2 = Tag(group: 0x0008, element: 0x0020)
        let tag3 = Tag(group: 0x0010, element: 0x0010)
        
        #expect(tag1 < tag2)
        #expect(tag2 < tag3)
        #expect(tag1 < tag3)
    }
    
    @Test("Tag equality")
    func testTagEquality() {
        let tag1 = Tag(group: 0x0010, element: 0x0010)
        let tag2 = Tag(group: 0x0010, element: 0x0010)
        let tag3 = Tag(group: 0x0010, element: 0x0020)
        
        #expect(tag1 == tag2)
        #expect(tag1 != tag3)
    }
    
    @Test("Common tag constants")
    func testCommonTags() {
        #expect(Tag.patientName.group == 0x0010)
        #expect(Tag.patientName.element == 0x0010)
        
        #expect(Tag.sopInstanceUID.group == 0x0008)
        #expect(Tag.sopInstanceUID.element == 0x0018)
        
        #expect(Tag.transferSyntaxUID.group == 0x0002)
        #expect(Tag.transferSyntaxUID.element == 0x0010)
    }
}
