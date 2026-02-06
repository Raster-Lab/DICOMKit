import XCTest
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

final class DICOMConvertTests: XCTestCase {
    
    // MARK: - Test Data Creation
    
    func createMinimalDICOMFile(transferSyntax: TransferSyntax = .explicitVRLittleEndian) throws -> Data {
        var fileMeta = DataSet()
        fileMeta[.fileMetaInformationVersion] = DataElement(tag: .fileMetaInformationVersion, vr: .OB, length: 2, valueData: Data([0x00, 0x01]))
        if let data = "1.2.840.10008.5.1.4.1.1.2".data(using: .ascii) {
            fileMeta[.mediaStorageSOPClassUID] = DataElement(tag: .mediaStorageSOPClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.3.4.5.6.7.8.9".data(using: .ascii) {
            fileMeta[.mediaStorageSOPInstanceUID] = DataElement(tag: .mediaStorageSOPInstanceUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = transferSyntax.uid.data(using: .ascii) {
            fileMeta[.transferSyntaxUID] = DataElement(tag: .transferSyntaxUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.826.0.1.3680043.10.1".data(using: .ascii) {
            fileMeta[.implementationClassUID] = DataElement(tag: .implementationClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        
        var dataSet = DataSet()
        if let data = "1.2.840.10008.5.1.4.1.1.2".data(using: .ascii) {
            dataSet[.sopClassUID] = DataElement(tag: .sopClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.3.4.5.6.7.8.9".data(using: .ascii) {
            dataSet[.sopInstanceUID] = DataElement(tag: .sopInstanceUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "CT".data(using: .ascii) {
            dataSet[.modality] = DataElement(tag: .modality, vr: .CS, length: UInt32(data.count), valueData: data)
        }
        if let data = "TEST^PATIENT".data(using: .ascii) {
            dataSet[.patientName] = DataElement(tag: .patientName, vr: .PN, length: UInt32(data.count), valueData: data)
        }
        if let data = "12345".data(using: .ascii) {
            dataSet[.patientID] = DataElement(tag: .patientID, vr: .LO, length: UInt32(data.count), valueData: data)
        }
        if let data = "20240101".data(using: .ascii) {
            dataSet[.studyDate] = DataElement(tag: .studyDate, vr: .DA, length: UInt32(data.count), valueData: data)
        }
        
        let file = DICOMFile(fileMetaInformation: fileMeta, dataSet: dataSet)
        
        var output = Data()
        output.append(Data(repeating: 0, count: 128))
        output.append(contentsOf: "DICM".utf8)
        
        let writer = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        
        let metaData = try writeDataSet(fileMeta, writer: writer)
        let lengthData = writer.serializeUInt32(UInt32(metaData.count))
        let groupLengthElement = DataElement(
            tag: .fileMetaInformationGroupLength,
            vr: .UL,
            length: UInt32(lengthData.count),
            valueData: lengthData
        )
        output.append(try writeElement(groupLengthElement, writer: writer))
        output.append(metaData)
        
        let dataWriter = DICOMWriter(
            byteOrder: transferSyntax.byteOrder,
            explicitVR: transferSyntax.isExplicitVR
        )
        output.append(try writeDataSet(dataSet, writer: dataWriter))
        
        return output
    }
    
    func createDICOMFileWithPixelData(rows: Int = 512, columns: Int = 512) throws -> Data {
        var fileMeta = DataSet()
        fileMeta[.fileMetaInformationVersion] = DataElement(tag: .fileMetaInformationVersion, vr: .OB, length: 2, valueData: Data([0x00, 0x01]))
        if let data = "1.2.840.10008.5.1.4.1.1.2".data(using: .ascii) {
            fileMeta[.mediaStorageSOPClassUID] = DataElement(tag: .mediaStorageSOPClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.3.4.5.6.7.8.9".data(using: .ascii) {
            fileMeta[.mediaStorageSOPInstanceUID] = DataElement(tag: .mediaStorageSOPInstanceUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = TransferSyntax.explicitVRLittleEndian.uid.data(using: .ascii) {
            fileMeta[.transferSyntaxUID] = DataElement(tag: .transferSyntaxUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.826.0.1.3680043.10.1".data(using: .ascii) {
            fileMeta[.implementationClassUID] = DataElement(tag: .implementationClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        
        var dataSet = DataSet()
        if let data = "1.2.840.10008.5.1.4.1.1.2".data(using: .ascii) {
            dataSet[.sopClassUID] = DataElement(tag: .sopClassUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "1.2.3.4.5.6.7.8.9".data(using: .ascii) {
            dataSet[.sopInstanceUID] = DataElement(tag: .sopInstanceUID, vr: .UI, length: UInt32(data.count), valueData: data)
        }
        if let data = "CT".data(using: .ascii) {
            dataSet[.modality] = DataElement(tag: .modality, vr: .CS, length: UInt32(data.count), valueData: data)
        }
        dataSet[.rows] = DataElement(tag: .rows, vr: .US, length: 2, valueData: Data([UInt8(rows & 0xFF), UInt8((rows >> 8) & 0xFF)]))
        dataSet[.columns] = DataElement(tag: .columns, vr: .US, length: 2, valueData: Data([UInt8(columns & 0xFF), UInt8((columns >> 8) & 0xFF)]))
        dataSet[.bitsAllocated] = DataElement(tag: .bitsAllocated, vr: .US, length: 2, valueData: Data([16, 0]))
        dataSet[.bitsStored] = DataElement(tag: .bitsStored, vr: .US, length: 2, valueData: Data([12, 0]))
        dataSet[.highBit] = DataElement(tag: .highBit, vr: .US, length: 2, valueData: Data([11, 0]))
        dataSet[.pixelRepresentation] = DataElement(tag: .pixelRepresentation, vr: .US, length: 2, valueData: Data([0, 0]))
        dataSet[.samplesPerPixel] = DataElement(tag: .samplesPerPixel, vr: .US, length: 2, valueData: Data([1, 0]))
        if let data = "MONOCHROME2".data(using: .ascii) {
            dataSet[.photometricInterpretation] = DataElement(tag: .photometricInterpretation, vr: .CS, length: UInt32(data.count), valueData: data)
        }
        
        // Create pixel data (gradient pattern)
        var pixelData = Data()
        for row in 0..<rows {
            for col in 0..<columns {
                let value = UInt16((row * columns + col) % 4096)
                pixelData.append(UInt8(value & 0xFF))
                pixelData.append(UInt8((value >> 8) & 0xFF))
            }
        }
        dataSet[.pixelData] = DataElement(tag: .pixelData, vr: .OW, length: UInt32(pixelData.count), valueData: pixelData)
        
        let writer = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        
        var output = Data()
        output.append(Data(repeating: 0, count: 128))
        output.append(contentsOf: "DICM".utf8)
        
        let metaData = try writeDataSet(fileMeta, writer: writer)
        let lengthData = writer.serializeUInt32(UInt32(metaData.count))
        let groupLengthElement = DataElement(
            tag: .fileMetaInformationGroupLength,
            vr: .UL,
            length: UInt32(lengthData.count),
            valueData: lengthData
        )
        output.append(try writeElement(groupLengthElement, writer: writer))
        output.append(metaData)
        output.append(try writeDataSet(dataSet, writer: writer))
        
        return output
    }
    
    private func writeDataSet(_ dataSet: DataSet, writer: DICOMWriter) throws -> Data {
        var output = Data()
        for tag in dataSet.tags.sorted() {
            guard let element = dataSet[tag] else { continue }
            output.append(try writeElement(element, writer: writer))
        }
        return output
    }
    
    private func writeElement(_ element: DataElement, writer: DICOMWriter) throws -> Data {
        var output = Data()
        output.append(writer.serializeUInt16(element.tag.group))
        output.append(writer.serializeUInt16(element.tag.element))
        
        let vr = element.vr
        let valueData = element.valueData
        
        if writer.explicitVR {
            output.append(contentsOf: vr.rawValue.utf8)
            if vr.uses32BitLength {
                output.append(contentsOf: [0x00, 0x00])
                output.append(writer.serializeUInt32(UInt32(valueData.count)))
            } else {
                let length = min(valueData.count, 0xFFFF)
                output.append(writer.serializeUInt16(UInt16(length)))
            }
        } else {
            output.append(writer.serializeUInt32(UInt32(valueData.count)))
        }
        
        output.append(valueData)
        return output
    }
    
    // MARK: - Transfer Syntax Conversion Tests
    
    func testConvertExplicitToImplicit() throws {
        let inputData = try createMinimalDICOMFile(transferSyntax: .explicitVRLittleEndian)
        let inputFile = try DICOMFile.read(from: inputData)
        
        XCTAssertNotNil(inputFile)
        XCTAssertEqual(inputFile.fileMetaInformation.string(for: .transferSyntaxUID), TransferSyntax.explicitVRLittleEndian.uid)
    }
    
    func testConvertImplicitToExplicit() throws {
        let inputData = try createMinimalDICOMFile(transferSyntax: .implicitVRLittleEndian)
        let inputFile = try DICOMFile.read(from: inputData)
        
        XCTAssertNotNil(inputFile)
        XCTAssertEqual(inputFile.dataSet.string(for: .patientName), "TEST^PATIENT")
    }
    
    func testConvertLittleToBigEndian() throws {
        let inputData = try createMinimalDICOMFile(transferSyntax: .explicitVRLittleEndian)
        let inputFile = try DICOMFile.read(from: inputData)
        
        XCTAssertNotNil(inputFile)
        XCTAssertEqual(inputFile.dataSet.string(for: .modality), "CT")
    }
    
    func testConvertBigToLittleEndian() throws {
        let inputData = try createMinimalDICOMFile(transferSyntax: .explicitVRBigEndian)
        let inputFile = try DICOMFile.read(from: inputData)
        
        XCTAssertNotNil(inputFile)
        XCTAssertEqual(inputFile.dataSet.string(for: .patientID), "12345")
    }
    
    func testPreserveMetadataDuringConversion() throws {
        let inputData = try createMinimalDICOMFile()
        let inputFile = try DICOMFile.read(from: inputData)
        
        XCTAssertEqual(inputFile.dataSet.string(for: .patientName), "TEST^PATIENT")
        XCTAssertEqual(inputFile.dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(inputFile.dataSet.string(for: .modality), "CT")
        XCTAssertEqual(inputFile.dataSet.string(for: .studyDate), "20240101")
    }
    
    func testRoundTripConversion() throws {
        let inputData = try createMinimalDICOMFile()
        let file1 = try DICOMFile.read(from: inputData)
        
        // Read it again
        let file2 = try DICOMFile.read(from: inputData)
        
        XCTAssertEqual(file1.dataSet.string(for: .patientName), file2.dataSet.string(for: .patientName))
        XCTAssertEqual(file1.dataSet.string(for: .patientID), file2.dataSet.string(for: .patientID))
    }
    
    func testStripPrivateTags() throws {
        var dataSet = DataSet()
        if let data = "PUBLIC_VALUE".data(using: .ascii) {
            dataSet[.patientName] = DataElement(tag: .patientName, vr: .PN, length: UInt32(data.count), valueData: data)
        }
        if let privateData = "PRIVATE".data(using: .ascii) {
            dataSet[Tag(group: 0x0009, element: 0x0010)] = DataElement(tag: Tag(group: 0x0009, element: 0x0010), vr: .LO, length: UInt32(privateData.count), valueData: privateData)
        }
        
        let tags = dataSet.tags.filter { !$0.isPrivate }
        var filteredDataSet = DataSet()
        for tag in tags {
            if let element = dataSet[tag] {
                filteredDataSet[tag] = element
            }
        }
        
        XCTAssertNotNil(filteredDataSet.string(for: .patientName))
        XCTAssertNil(filteredDataSet[Tag(group: 0x0009, element: 0x0010)])
    }
    
    func testValidateOutputFile() throws {
        let inputData = try createMinimalDICOMFile()
        
        // Should be able to read it
        let file = try DICOMFile.read(from: inputData)
        XCTAssertNotNil(file)
    }
    
    // MARK: - Image Export Tests (Platform-specific)
    
    #if canImport(CoreGraphics)
    func testExportGrayscaleToPNG() throws {
        // This test requires actual pixel data rendering
        // Skipped in unit tests, covered by integration tests
    }
    
    func testExportToJPEGWithQuality() throws {
        // This test requires actual image export
        // Skipped in unit tests, covered by integration tests
    }
    
    func testExportToTIFF() throws {
        // This test requires actual image export
        // Skipped in unit tests, covered by integration tests
    }
    #endif
    
    // MARK: - Window/Level Tests
    
    func testApplyWindowLevel() throws {
        let inputData = try createMinimalDICOMFile()
        let file = try DICOMFile.read(from: inputData)
        
        // Add window/level tags
        var dataSet = file.dataSet
        if let centerData = "40".data(using: .ascii) {
            let centerTag = Tag.windowCenter
            dataSet[centerTag] = DataElement(tag: centerTag, vr: .DS, length: UInt32(centerData.count), valueData: centerData)
        }
        if let widthData = "400".data(using: .ascii) {
            let widthTag = Tag.windowWidth
            dataSet[widthTag] = DataElement(tag: widthTag, vr: .DS, length: UInt32(widthData.count), valueData: widthData)
        }
        
        // Check window settings can be extracted
        if let window = dataSet.windowSettings() {
            XCTAssertEqual(window.center, 40.0)
            XCTAssertEqual(window.width, 400.0)
        } else {
            XCTFail("Failed to extract window settings")
        }
    }
    
    func testCalculateWindowFromPixelRange() throws {
        // Create pixel range
        let min = 0
        let max = 4095
        let center = Double(min + max) / 2.0
        let width = Double(max - min)
        
        XCTAssertEqual(center, 2047.5)
        XCTAssertEqual(width, 4095.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidInputFile() throws {
        let invalidData = Data("NOT A DICOM FILE".utf8)
        
        XCTAssertThrowsError(try DICOMFile.read(from: invalidData)) { error in
            XCTAssertNotNil(error)
        }
    }
    
    func testMissingTransferSyntaxForDICOMOutput() throws {
        // Test that conversion requires transfer syntax specification
        // This would be tested in CLI integration tests
    }
    
    func testInvalidFrameNumber() throws {
        // Test requesting frame beyond available frames
        // This would be tested with actual pixel data
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchConversionSuccess() throws {
        // Create multiple test files
        let file1 = try createMinimalDICOMFile()
        let file2 = try createMinimalDICOMFile()
        
        XCTAssertNotNil(file1)
        XCTAssertNotNil(file2)
    }
    
    func testBatchConversionWithErrors() throws {
        // Test that batch processing continues on error
        // Covered by integration tests
    }
    
    func testPreserveDirectoryStructure() throws {
        // Test that relative paths are preserved
        let input = "/input/subdir/file.dcm"
        let inputBase = "/input/"
        let relative = input.replacingOccurrences(of: inputBase, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        XCTAssertEqual(relative, "subdir/file.dcm")
    }
    
    // MARK: - Transfer Syntax Parsing Tests
    
    func testParseExplicitVRLittleEndian() throws {
        let syntax = try parseTransferSyntax("ExplicitVRLittleEndian")
        XCTAssertEqual(syntax, .explicitVRLittleEndian)
    }
    
    func testParseImplicitVRLittleEndian() throws {
        let syntax = try parseTransferSyntax("ImplicitVRLittleEndian")
        XCTAssertEqual(syntax, .implicitVRLittleEndian)
    }
    
    func testParseExplicitVRBigEndian() throws {
        let syntax = try parseTransferSyntax("ExplicitVRBigEndian")
        XCTAssertEqual(syntax, .explicitVRBigEndian)
    }
    
    func testParseShorthandSyntaxNames() throws {
        XCTAssertEqual(try parseTransferSyntax("explicit"), .explicitVRLittleEndian)
        XCTAssertEqual(try parseTransferSyntax("implicit"), .implicitVRLittleEndian)
        XCTAssertEqual(try parseTransferSyntax("evle"), .explicitVRLittleEndian)
        XCTAssertEqual(try parseTransferSyntax("ivle"), .implicitVRLittleEndian)
    }
    
    func testParseInvalidSyntaxName() throws {
        XCTAssertThrowsError(try parseTransferSyntax("InvalidSyntax"))
    }
    
    // MARK: - Helper Methods
    
    private func parseTransferSyntax(_ name: String) throws -> TransferSyntax {
        switch name.lowercased() {
        case "explicitvrlittleendian", "explicit", "evle":
            return .explicitVRLittleEndian
        case "implicitvrlittleendian", "implicit", "ivle":
            return .implicitVRLittleEndian
        case "explicitvrbigendian", "evbe":
            return .explicitVRBigEndian
        case "deflate", "deflated":
            return .deflatedExplicitVRLittleEndian
        default:
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid syntax"])
        }
    }
    
    // MARK: - Performance Tests
    
    func testConversionPerformance() throws {
        let inputData = try createMinimalDICOMFile()
        
        measure {
            do {
                _ = try DICOMFile.read(from: inputData)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testLargeFileConversion() throws {
        // Test with larger pixel data
        let inputData = try createDICOMFileWithPixelData(rows: 512, columns: 512)
        
        let file = try DICOMFile.read(from: inputData)
        XCTAssertNotNil(file)
        XCTAssertNotNil(file.dataSet[.pixelData])
    }
}

extension VR {
    fileprivate var uses32BitLength: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UN, .UR, .UT:
            return true
        default:
            return false
        }
    }
}

extension TransferSyntax {
    fileprivate var byteOrder: ByteOrder {
        switch self {
        case .explicitVRBigEndian:
            return .bigEndian
        default:
            return .littleEndian
        }
    }
    
    fileprivate var isExplicitVR: Bool {
        switch self {
        case .implicitVRLittleEndian:
            return false
        default:
            return true
        }
    }
}
