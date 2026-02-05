import XCTest
@testable import DICOMKit

final class ParsingOptionsTests: XCTestCase {
    func testDefaultOptions() {
        let options = ParsingOptions.default
        
        XCTAssertEqual(options.mode, .full)
        XCTAssertNil(options.stopAfterTag)
        XCTAssertNil(options.maxElements)
        XCTAssertFalse(options.useMemoryMapping)
    }
    
    func testMetadataOnlyOptions() {
        let options = ParsingOptions.metadataOnly
        
        XCTAssertEqual(options.mode, .metadataOnly)
        XCTAssertNil(options.stopAfterTag)
        XCTAssertNil(options.maxElements)
    }
    
    func testLazyPixelDataOptions() {
        let options = ParsingOptions.lazyPixelData
        
        XCTAssertEqual(options.mode, .lazyPixelData)
        XCTAssertNil(options.stopAfterTag)
        XCTAssertNil(options.maxElements)
    }
    
    func testMemoryMappedOptions() {
        let options = ParsingOptions.memoryMapped
        
        XCTAssertTrue(options.useMemoryMapping)
    }
    
    func testCustomOptions() {
        let customTag = Tag(group: 0x0010, element: 0x0010) // Patient Name
        let options = ParsingOptions(
            mode: .metadataOnly,
            stopAfterTag: customTag,
            maxElements: 100,
            useMemoryMapping: true
        )
        
        XCTAssertEqual(options.mode, .metadataOnly)
        XCTAssertEqual(options.stopAfterTag, customTag)
        XCTAssertEqual(options.maxElements, 100)
        XCTAssertTrue(options.useMemoryMapping)
    }
    
    func testParsingModeEquality() {
        XCTAssertEqual(ParsingOptions.Mode.full, ParsingOptions.Mode.full)
        XCTAssertEqual(ParsingOptions.Mode.metadataOnly, ParsingOptions.Mode.metadataOnly)
        XCTAssertEqual(ParsingOptions.Mode.lazyPixelData, ParsingOptions.Mode.lazyPixelData)
        
        XCTAssertNotEqual(ParsingOptions.Mode.full, ParsingOptions.Mode.metadataOnly)
        XCTAssertNotEqual(ParsingOptions.Mode.full, ParsingOptions.Mode.lazyPixelData)
        XCTAssertNotEqual(ParsingOptions.Mode.metadataOnly, ParsingOptions.Mode.lazyPixelData)
    }
}
