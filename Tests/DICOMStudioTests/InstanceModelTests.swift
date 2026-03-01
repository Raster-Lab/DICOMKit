// InstanceModelTests.swift
// DICOMStudioTests
//
// Tests for InstanceModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("InstanceModel Tests")
struct InstanceModelTests {

    @Test("Instance creation with all fields")
    func testInstanceCreation() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3.4.5.6.7",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.4.5.6",
            instanceNumber: 42,
            filePath: "/tmp/test.dcm",
            fileSize: 1048576,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            rows: 512,
            columns: 512,
            bitsAllocated: 16,
            numberOfFrames: 1,
            photometricInterpretation: "MONOCHROME2"
        )

        #expect(instance.sopInstanceUID == "1.2.3.4.5.6.7")
        #expect(instance.sopClassUID == "1.2.840.10008.5.1.4.1.1.2")
        #expect(instance.seriesInstanceUID == "1.2.3.4.5.6")
        #expect(instance.instanceNumber == 42)
        #expect(instance.filePath == "/tmp/test.dcm")
        #expect(instance.fileSize == 1048576)
        #expect(instance.transferSyntaxUID == "1.2.840.10008.1.2.1")
        #expect(instance.rows == 512)
        #expect(instance.columns == 512)
        #expect(instance.bitsAllocated == 16)
        #expect(instance.numberOfFrames == 1)
        #expect(instance.photometricInterpretation == "MONOCHROME2")
    }

    @Test("Instance creation with defaults")
    func testInstanceDefaults() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesInstanceUID: "1.2.3.4",
            filePath: "/tmp/test.dcm"
        )

        #expect(instance.instanceNumber == nil)
        #expect(instance.fileSize == 0)
        #expect(instance.rows == nil)
        #expect(instance.columns == nil)
        #expect(instance.bitsAllocated == nil)
        #expect(instance.numberOfFrames == nil)
    }

    @Test("Display file size formatting")
    func testDisplayFileSize() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm",
            fileSize: 1048576
        )
        // Should format as approximately 1 MB
        let display = instance.displayFileSize
        #expect(display.contains("MB") || display.contains("1"))
    }

    @Test("Display file size zero bytes")
    func testDisplayFileSizeZero() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm",
            fileSize: 0
        )
        let display = instance.displayFileSize
        #expect(!display.isEmpty)
    }

    @Test("Display title with instance number")
    func testDisplayTitleWithNumber() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            instanceNumber: 10,
            filePath: "/tmp/test.dcm"
        )
        #expect(instance.displayTitle == "Instance 10")
    }

    @Test("Display title without instance number")
    func testDisplayTitleWithoutNumber() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm"
        )
        #expect(instance.displayTitle == "Instance")
    }

    @Test("Display dimensions")
    func testDisplayDimensions() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm",
            rows: 512,
            columns: 256
        )
        #expect(instance.displayDimensions == "256 × 512")
    }

    @Test("Display dimensions when nil")
    func testDisplayDimensionsNil() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm"
        )
        #expect(instance.displayDimensions == nil)
    }

    @Test("Multi-frame detection true")
    func testIsMultiFrameTrue() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm",
            numberOfFrames: 100
        )
        #expect(instance.isMultiFrame == true)
    }

    @Test("Multi-frame detection false for single frame")
    func testIsMultiFrameFalseSingle() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm",
            numberOfFrames: 1
        )
        #expect(instance.isMultiFrame == false)
    }

    @Test("Multi-frame detection false when nil")
    func testIsMultiFrameFalseNil() {
        let instance = InstanceModel(
            sopInstanceUID: "1.2.3",
            sopClassUID: "",
            seriesInstanceUID: "1.2",
            filePath: "/tmp/test.dcm"
        )
        #expect(instance.isMultiFrame == false)
    }

    @Test("Instance is Identifiable")
    func testInstanceIdentifiable() {
        let i1 = InstanceModel(sopInstanceUID: "1.2.3", sopClassUID: "", seriesInstanceUID: "1.2", filePath: "/tmp/a.dcm")
        let i2 = InstanceModel(sopInstanceUID: "1.2.3", sopClassUID: "", seriesInstanceUID: "1.2", filePath: "/tmp/b.dcm")
        #expect(i1.id != i2.id)
    }
}
