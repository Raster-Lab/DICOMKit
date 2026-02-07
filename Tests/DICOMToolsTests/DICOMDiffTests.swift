import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

// Test-local versions of dicom-diff types (since they're in executable target)

struct DICOMComparer {
    let file1: DICOMFile
    let file2: DICOMFile
    let tagsToIgnore: Set<Tag>
    let ignorePrivate: Bool
    let comparePixels: Bool
    let pixelTolerance: Double
    let showIdentical: Bool
    
    func compare() throws -> ComparisonResult {
        var result = ComparisonResult()
        
        let dataSet1 = file1.dataSet
        let dataSet2 = file2.dataSet
        
        // Build element dictionaries for result
        for tag in dataSet1.tags {
            if let element = dataSet1[tag] {
                result.file1Data[tag] = element
            }
        }
        for tag in dataSet2.tags {
            if let element = dataSet2[tag] {
                result.file2Data[tag] = element
            }
        }
        
        let allTags = Set(dataSet1.tags).union(Set(dataSet2.tags))
        
        for tag in allTags {
            // Skip ignored tags
            if tagsToIgnore.contains(tag) {
                continue
            }
            
            // Skip private tags if requested
            if ignorePrivate && tag.isPrivate {
                continue
            }
            
            // Skip pixel data tag (handled separately)
            if comparePixels && tag == Tag.pixelData {
                continue
            }
            
            result.totalTags += 1
            
            let elem1 = dataSet1[tag]
            let elem2 = dataSet2[tag]
            
            switch (elem1, elem2) {
            case (nil, let elem2?):
                result.onlyInFile2[tag] = elem2
                result.differenceCount += 1
                
            case (let elem1?, nil):
                result.onlyInFile1[tag] = elem1
                result.differenceCount += 1
                
            case (let elem1?, let elem2?):
                if !areElementsEqual(elem1, elem2) {
                    result.modified.append(TagModification(tag: tag, value1: elem1, value2: elem2))
                    result.differenceCount += 1
                } else {
                    result.identical.insert(tag)
                }
                
            case (nil, nil):
                break
            }
        }
        
        // Compare pixel data if requested
        if comparePixels {
            result.pixelsCompared = true
            if let pixelDiff = try comparePixelData(dataSet1, dataSet2) {
                result.pixelsDifferent = pixelDiff.maxDifference > pixelTolerance
                result.pixelDifference = pixelDiff
            }
        }
        
        return result
    }
    
    private func areElementsEqual(_ elem1: DataElement, _ elem2: DataElement) -> Bool {
        // VR must match
        if elem1.vr != elem2.vr {
            return false
        }
        
        // For sequences, compare recursively
        if elem1.vr == .SQ {
            guard let seq1 = elem1.sequenceItems,
                  let seq2 = elem2.sequenceItems,
                  seq1.count == seq2.count else {
                return false
            }
            
            for (item1, item2) in zip(seq1, seq2) {
                if !areSequenceItemsEqual(item1, item2) {
                    return false
                }
            }
            
            return true
        }
        
        // Compare data
        return elem1.valueData == elem2.valueData
    }
    
    private func areSequenceItemsEqual(_ item1: SequenceItem, _ item2: SequenceItem) -> Bool {
        let tags1 = Set(item1.elements.keys)
        let tags2 = Set(item2.elements.keys)
        
        guard tags1 == tags2 else {
            return false
        }
        
        for tag in tags1 {
            guard let elem1 = item1.elements[tag],
                  let elem2 = item2.elements[tag],
                  areElementsEqual(elem1, elem2) else {
                return false
            }
        }
        
        return true
    }
    
    private func comparePixelData(_ ds1: DataSet, _ ds2: DataSet) throws -> PixelDifference? {
        guard let pixelElem1 = ds1[Tag.pixelData],
              let pixelElem2 = ds2[Tag.pixelData] else {
            return nil
        }
        
        let pixelData1 = pixelElem1.valueData
        let pixelData2 = pixelElem2.valueData
        
        // Simple byte comparison
        let minLength = min(pixelData1.count, pixelData2.count)
        
        var maxDiff: Double = 0
        var totalDiff: Double = 0
        var diffCount = 0
        
        for i in 0..<minLength {
            let diff = abs(Double(pixelData1[i]) - Double(pixelData2[i]))
            if diff > 0 {
                maxDiff = max(maxDiff, diff)
                totalDiff += diff
                diffCount += 1
            }
        }
        
        // Account for different lengths
        if pixelData1.count != pixelData2.count {
            diffCount += abs(pixelData1.count - pixelData2.count)
        }
        
        let totalPixels = max(pixelData1.count, pixelData2.count)
        let meanDiff = diffCount > 0 ? totalDiff / Double(diffCount) : 0
        
        return PixelDifference(
            maxDifference: maxDiff,
            meanDifference: meanDiff,
            differentPixelCount: diffCount,
            totalPixels: totalPixels
        )
    }
}

struct ComparisonResult {
    var totalTags: Int = 0
    var differenceCount: Int = 0
    var onlyInFile1: [Tag: DataElement] = [:]
    var onlyInFile2: [Tag: DataElement] = [:]
    var modified: [TagModification] = []
    var identical: Set<Tag> = []
    var pixelsCompared: Bool = false
    var pixelsDifferent: Bool = false
    var pixelDifference: PixelDifference?
    
    // Keep references for detailed output
    var file1Data: [Tag: DataElement] = [:]
    var file2Data: [Tag: DataElement] = [:]
    
    var hasDifferences: Bool {
        return differenceCount > 0 || pixelsDifferent
    }
}

struct TagModification {
    let tag: Tag
    let value1: DataElement
    let value2: DataElement
}

struct PixelDifference {
    let maxDifference: Double
    let meanDifference: Double
    let differentPixelCount: Int
    let totalPixels: Int
}

/// Tests for dicom-diff CLI tool functionality
///
/// Tests the comparison functionality between two DICOM files including:
/// - Metadata tag comparison
/// - Pixel data comparison with tolerance
/// - Output format generation (text, JSON, summary)
/// - Tag filtering and ignore options
final class DICOMDiffTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    /// Creates a minimal DICOM file for testing with customizable parameters
    private func createTestDICOMFile(
        patientName: String = "Test^Patient",
        patientID: String = "12345",
        studyUID: String = "1.2.3.4.5.6.7.8.9.10",
        seriesUID: String = "1.2.3.4.5.6.7.8.9.11",
        instanceUID: String = "1.2.3.4.5.6.7.8.9.12",
        modality: String = "CT",
        studyDate: String = "20240101",
        manufacturerModelName: String? = nil,
        privateTag: Bool = false,
        pixelData: Data? = nil
    ) throws -> Data {
        var data = Data()
        
        // Add 128-byte preamble
        data.append(Data(count: 128))
        
        // Add DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        // File Meta Information Group Length (0002,0000) - UL, 4 bytes
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00]) // Value = 84 (placeholder)
        
        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntaxUID = "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        let transferSyntaxLength = UInt16(transferSyntaxUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: transferSyntaxLength.littleEndian) { Data($0) })
        data.append(transferSyntaxUID.data(using: .utf8)!)
        
        // SOP Class UID (0008,0016) - UI
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        let sopClassLength = UInt16(sopClassUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopClassLength.littleEndian) { Data($0) })
        data.append(sopClassUID.data(using: .utf8)!)
        
        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let sopInstanceLength = UInt16(instanceUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: sopInstanceLength.littleEndian) { Data($0) })
        data.append(instanceUID.data(using: .utf8)!)
        
        // Patient Name (0010,0010) - PN
        data.append(contentsOf: [0x10, 0x00, 0x10, 0x00]) // Tag
        data.append(contentsOf: [0x50, 0x4E]) // VR = PN
        let patientNameLength = UInt16(patientName.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: patientNameLength.littleEndian) { Data($0) })
        data.append(patientName.data(using: .utf8)!)
        
        // Patient ID (0010,0020) - LO
        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00]) // Tag
        data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
        let patientIDLength = UInt16(patientID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: patientIDLength.littleEndian) { Data($0) })
        data.append(patientID.data(using: .utf8)!)
        
        // Modality (0008,0060) - CS
        data.append(contentsOf: [0x08, 0x00, 0x60, 0x00]) // Tag
        data.append(contentsOf: [0x43, 0x53]) // VR = CS
        let modalityLength = UInt16(modality.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: modalityLength.littleEndian) { Data($0) })
        data.append(modality.data(using: .utf8)!)
        
        // Study Date (0008,0020) - DA
        data.append(contentsOf: [0x08, 0x00, 0x20, 0x00]) // Tag
        data.append(contentsOf: [0x44, 0x41]) // VR = DA
        let studyDateLength = UInt16(studyDate.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyDateLength.littleEndian) { Data($0) })
        data.append(studyDate.data(using: .utf8)!)
        
        // Study Instance UID (0020,000D) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0D, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let studyUIDLength = UInt16(studyUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: studyUIDLength.littleEndian) { Data($0) })
        data.append(studyUID.data(using: .utf8)!)
        
        // Series Instance UID (0020,000E) - UI
        data.append(contentsOf: [0x20, 0x00, 0x0E, 0x00]) // Tag
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let seriesUIDLength = UInt16(seriesUID.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: seriesUIDLength.littleEndian) { Data($0) })
        data.append(seriesUID.data(using: .utf8)!)
        
        // Optional: Manufacturer Model Name (0008,1090) - LO
        if let manufacturerModelName = manufacturerModelName {
            data.append(contentsOf: [0x08, 0x00, 0x90, 0x10]) // Tag
            data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
            let modelLength = UInt16(manufacturerModelName.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: modelLength.littleEndian) { Data($0) })
            data.append(manufacturerModelName.data(using: .utf8)!)
        }
        
        // Optional: Private tag (0009,0010) - LO (Private Creator)
        if privateTag {
            data.append(contentsOf: [0x09, 0x00, 0x10, 0x00]) // Tag
            data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
            let privateCreator = "TEST_PRIVATE"
            let privateLength = UInt16(privateCreator.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: privateLength.littleEndian) { Data($0) })
            data.append(privateCreator.data(using: .utf8)!)
        }
        
        // Optional: Pixel Data (7FE0,0010) - OW
        if let pixelData = pixelData {
            data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00]) // Tag
            data.append(contentsOf: [0x4F, 0x57]) // VR = OW
            let pixelLength = UInt16(pixelData.count)
            data.append(contentsOf: withUnsafeBytes(of: pixelLength.littleEndian) { Data($0) })
            data.append(pixelData)
        }
        
        return data
    }
    
    // MARK: - Basic Comparison Tests
    
    func testIdenticalFiles() throws {
        // Create two identical files
        let fileData = try createTestDICOMFile()
        
        let file1 = try DICOMFile.read(from: fileData)
        let file2 = try DICOMFile.read(from: fileData)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertFalse(result.hasDifferences, "Identical files should have no differences")
        XCTAssertEqual(result.differenceCount, 0)
        XCTAssertTrue(result.onlyInFile1.isEmpty)
        XCTAssertTrue(result.onlyInFile2.isEmpty)
        XCTAssertTrue(result.modified.isEmpty)
        XCTAssertGreaterThan(result.totalTags, 0, "Should have compared some tags")
    }
    
    func testDifferentPatientNames() throws {
        let file1Data = try createTestDICOMFile(patientName: "Smith^John")
        let file2Data = try createTestDICOMFile(patientName: "Doe^Jane")
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertEqual(result.differenceCount, 1)
        XCTAssertEqual(result.modified.count, 1)
        
        let modification = result.modified.first!
        XCTAssertEqual(modification.tag, Tag.patientName)
    }
    
    func testTagOnlyInFile1() throws {
        let file1Data = try createTestDICOMFile(manufacturerModelName: "Scanner XYZ")
        let file2Data = try createTestDICOMFile(manufacturerModelName: nil)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertGreaterThan(result.onlyInFile1.count, 0)
        XCTAssertTrue(result.onlyInFile1.keys.contains(Tag.manufacturerModelName))
    }
    
    func testTagOnlyInFile2() throws {
        let file1Data = try createTestDICOMFile(manufacturerModelName: nil)
        let file2Data = try createTestDICOMFile(manufacturerModelName: "Scanner ABC")
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertGreaterThan(result.onlyInFile2.count, 0)
        XCTAssertTrue(result.onlyInFile2.keys.contains(Tag.manufacturerModelName))
    }
    
    // MARK: - Tag Filtering Tests
    
    func testIgnoreSpecificTag() throws {
        let file1Data = try createTestDICOMFile(patientName: "Smith^John")
        let file2Data = try createTestDICOMFile(patientName: "Doe^Jane")
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        // Ignore patient name tag
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [Tag.patientName],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertFalse(result.hasDifferences, "Should ignore patient name difference")
        XCTAssertEqual(result.differenceCount, 0)
    }
    
    func testIgnorePrivateTags() throws {
        let file1Data = try createTestDICOMFile(privateTag: true)
        let file2Data = try createTestDICOMFile(privateTag: false)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        // Test without ignoring private tags - should see difference
        let comparerWithPrivate = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let resultWithPrivate = try comparerWithPrivate.compare()
        XCTAssertTrue(resultWithPrivate.hasDifferences, "Should detect private tag difference")
        
        // Test with ignoring private tags - should not see difference
        let comparerIgnorePrivate = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: true,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let resultIgnorePrivate = try comparerIgnorePrivate.compare()
        XCTAssertFalse(resultIgnorePrivate.hasDifferences, "Should ignore private tag difference")
    }
    
    func testIgnoreMultipleTags() throws {
        let file1Data = try createTestDICOMFile(
            patientName: "Smith^John",
            patientID: "12345",
            studyDate: "20240101"
        )
        let file2Data = try createTestDICOMFile(
            patientName: "Doe^Jane",
            patientID: "67890",
            studyDate: "20240202"
        )
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        // Ignore all three changed tags
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [Tag.patientName, Tag.patientID, Tag.studyDate],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertFalse(result.hasDifferences)
        XCTAssertEqual(result.differenceCount, 0)
    }
    
    // MARK: - Pixel Data Comparison Tests
    
    func testIdenticalPixelData() throws {
        let pixelData = Data([1, 2, 3, 4, 5, 6, 7, 8])
        let file1Data = try createTestDICOMFile(pixelData: pixelData)
        let file2Data = try createTestDICOMFile(pixelData: pixelData)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: true,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.pixelsCompared)
        XCTAssertFalse(result.pixelsDifferent)
        XCTAssertNotNil(result.pixelDifference)
        XCTAssertEqual(result.pixelDifference?.maxDifference, 0.0)
    }
    
    func testDifferentPixelData() throws {
        let pixelData1 = Data([1, 2, 3, 4, 5, 6, 7, 8])
        let pixelData2 = Data([1, 2, 3, 4, 6, 7, 8, 9])
        
        let file1Data = try createTestDICOMFile(pixelData: pixelData1)
        let file2Data = try createTestDICOMFile(pixelData: pixelData2)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: true,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.pixelsCompared)
        XCTAssertTrue(result.pixelsDifferent)
        XCTAssertNotNil(result.pixelDifference)
        XCTAssertGreaterThan(result.pixelDifference?.maxDifference ?? 0, 0)
    }
    
    func testPixelDataWithTolerance() throws {
        let pixelData1 = Data([100, 101, 102, 103, 104])
        let pixelData2 = Data([100, 102, 103, 104, 105])
        
        let file1Data = try createTestDICOMFile(pixelData: pixelData1)
        let file2Data = try createTestDICOMFile(pixelData: pixelData2)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        // With tolerance of 0, should be different
        let comparerNoTolerance = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: true,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let resultNoTolerance = try comparerNoTolerance.compare()
        XCTAssertTrue(resultNoTolerance.pixelsDifferent)
        
        // With tolerance of 2, should be within tolerance
        let comparerWithTolerance = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: true,
            pixelTolerance: 2.0,
            showIdentical: false
        )
        
        let resultWithTolerance = try comparerWithTolerance.compare()
        XCTAssertFalse(resultWithTolerance.pixelsDifferent)
    }
    
    func testSkipPixelDataComparison() throws {
        let pixelData1 = Data([1, 2, 3, 4])
        let pixelData2 = Data([5, 6, 7, 8])
        
        let file1Data = try createTestDICOMFile(pixelData: pixelData1)
        let file2Data = try createTestDICOMFile(pixelData: pixelData2)
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertFalse(result.pixelsCompared)
        XCTAssertNil(result.pixelDifference)
    }
    
    // MARK: - Multiple Differences Tests
    
    func testMultipleDifferences() throws {
        let file1Data = try createTestDICOMFile(
            patientName: "Smith^John",
            patientID: "12345",
            studyDate: "20240101",
            manufacturerModelName: "Scanner A"
        )
        let file2Data = try createTestDICOMFile(
            patientName: "Doe^Jane",
            patientID: "67890",
            studyDate: "20240101",
            manufacturerModelName: "Scanner B"
        )
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertEqual(result.differenceCount, 3, "Should find 3 differences (PatientName, PatientID, ManufacturerModelName)")
        XCTAssertEqual(result.modified.count, 3)
        
        let modifiedTags = Set(result.modified.map { $0.tag })
        XCTAssertTrue(modifiedTags.contains(Tag.patientName))
        XCTAssertTrue(modifiedTags.contains(Tag.patientID))
        XCTAssertTrue(modifiedTags.contains(Tag.manufacturerModelName))
    }
    
    func testCombinationOfDifferenceTypes() throws {
        let file1Data = try createTestDICOMFile(
            patientName: "Smith^John",
            manufacturerModelName: "Scanner A"
        )
        let file2Data = try createTestDICOMFile(
            patientName: "Doe^Jane",
            manufacturerModelName: nil
        )
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertEqual(result.differenceCount, 2)
        XCTAssertEqual(result.modified.count, 1, "PatientName is modified")
        XCTAssertEqual(result.onlyInFile1.count, 1, "ManufacturerModelName only in file1")
    }
    
    // MARK: - Show Identical Tags Tests
    
    func testShowIdenticalTags() throws {
        let fileData = try createTestDICOMFile()
        
        let file1 = try DICOMFile.read(from: fileData)
        let file2 = try DICOMFile.read(from: fileData)
        
        let comparerShowIdentical = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: true
        )
        
        let result = try comparerShowIdentical.compare()
        
        XCTAssertFalse(result.hasDifferences)
        XCTAssertGreaterThan(result.identical.count, 0, "Should track identical tags")
        XCTAssertTrue(result.identical.contains(Tag.patientName))
        XCTAssertTrue(result.identical.contains(Tag.modality))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFilesComparison() throws {
        // Create minimal files with just required meta info
        var data1 = Data()
        data1.append(Data(count: 128))
        data1.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        var data2 = Data()
        data2.append(Data(count: 128))
        data2.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        
        // These will fail to parse as valid DICOM, which is expected
        // Testing that the comparison handles this gracefully
        XCTAssertThrowsError(try DICOMFile.read(from: data1))
        XCTAssertThrowsError(try DICOMFile.read(from: data2))
    }
    
    func testComparisonWithDifferentModalities() throws {
        let file1Data = try createTestDICOMFile(modality: "CT")
        let file2Data = try createTestDICOMFile(modality: "MR")
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        XCTAssertTrue(result.hasDifferences)
        XCTAssertEqual(result.differenceCount, 1)
        
        let modifiedTag = result.modified.first!
        XCTAssertEqual(modifiedTag.tag, Tag.modality)
    }
    
    func testComparisonResultSummary() throws {
        let file1Data = try createTestDICOMFile(patientName: "Test^Patient1")
        let file2Data = try createTestDICOMFile(patientName: "Test^Patient2")
        
        let file1 = try DICOMFile.read(from: file1Data)
        let file2 = try DICOMFile.read(from: file2Data)
        
        let comparer = DICOMComparer(
            file1: file1,
            file2: file2,
            tagsToIgnore: [],
            ignorePrivate: false,
            comparePixels: false,
            pixelTolerance: 0.0,
            showIdentical: false
        )
        
        let result = try comparer.compare()
        
        // Verify summary statistics
        XCTAssertGreaterThan(result.totalTags, 0)
        XCTAssertEqual(result.differenceCount, result.onlyInFile1.count + result.onlyInFile2.count + result.modified.count)
        XCTAssertTrue(result.hasDifferences == (result.differenceCount > 0 || result.pixelsDifferent))
    }
}
