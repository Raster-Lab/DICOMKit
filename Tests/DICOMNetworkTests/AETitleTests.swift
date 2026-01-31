import Testing
@testable import DICOMNetwork

@Suite("AE Title Tests")
struct AETitleTests {
    
    @Test("Valid AE Title creation")
    func testValidAETitle() throws {
        let aeTitle = try AETitle("PACS_SERVER")
        #expect(aeTitle.value == "PACS_SERVER")
    }
    
    @Test("AE Title trims whitespace")
    func testAETitleTrimsWhitespace() throws {
        let aeTitle = try AETitle("  MYSERVER  ")
        #expect(aeTitle.value == "MYSERVER")
    }
    
    @Test("AE Title padded value")
    func testAETitlePaddedValue() throws {
        let aeTitle = try AETitle("TEST")
        #expect(aeTitle.paddedValue.count == 16)
        #expect(aeTitle.paddedValue == "TEST            ")
    }
    
    @Test("AE Title data is 16 bytes")
    func testAETitleData() throws {
        let aeTitle = try AETitle("DICOMKIT")
        #expect(aeTitle.data.count == 16)
    }
    
    @Test("Maximum length AE Title")
    func testMaxLengthAETitle() throws {
        let aeTitle = try AETitle("1234567890123456")
        #expect(aeTitle.value == "1234567890123456")
        #expect(aeTitle.value.count == 16)
    }
    
    @Test("AE Title too long throws error")
    func testAETitleTooLong() throws {
        // Use a variable to avoid string literal initialization
        let tooLongString = "12345678901234567" // 17 characters
        #expect(throws: DICOMNetworkError.self) {
            _ = try AETitle(tooLongString)
        }
    }
    
    @Test("Empty AE Title throws error")
    func testEmptyAETitle() throws {
        // Use a variable to avoid string literal initialization
        let emptyString = ""
        #expect(throws: DICOMNetworkError.self) {
            _ = try AETitle(emptyString)
        }
    }
    
    @Test("Whitespace only AE Title throws error")
    func testWhitespaceOnlyAETitle() throws {
        // Use a variable to avoid string literal initialization
        let whitespaceString = "   "
        #expect(throws: DICOMNetworkError.self) {
            _ = try AETitle(whitespaceString)
        }
    }
    
    @Test("AE Title from data")
    func testAETitleFromData() throws {
        let data = Data("TEST_AE         ".utf8)
        let aeTitle = AETitle.from(data: data)
        
        #expect(aeTitle != nil)
        #expect(aeTitle?.value == "TEST_AE")
    }
    
    @Test("AE Title from invalid data returns nil")
    func testAETitleFromInvalidData() {
        let data = Data("SHORT".utf8)  // Less than 16 bytes
        let aeTitle = AETitle.from(data: data)
        
        #expect(aeTitle == nil)
    }
    
    @Test("AE Title string literal")
    func testAETitleStringLiteral() {
        let aeTitle: AETitle = "MYSERVER"
        #expect(aeTitle.value == "MYSERVER")
    }
    
    @Test("AE Title description")
    func testAETitleDescription() throws {
        let aeTitle = try AETitle("DICOMKIT")
        #expect(aeTitle.description == "DICOMKIT")
    }
    
    @Test("AE Title equality")
    func testAETitleEquality() throws {
        let ae1 = try AETitle("TEST")
        let ae2 = try AETitle("TEST")
        let ae3 = try AETitle("OTHER")
        
        #expect(ae1 == ae2)
        #expect(ae1 != ae3)
    }
    
    @Test("AE Title hashable")
    func testAETitleHashable() throws {
        var set: Set<AETitle> = []
        set.insert(try AETitle("SERVER1"))
        set.insert(try AETitle("SERVER2"))
        set.insert(try AETitle("SERVER1"))  // Duplicate
        
        #expect(set.count == 2)
    }
}
