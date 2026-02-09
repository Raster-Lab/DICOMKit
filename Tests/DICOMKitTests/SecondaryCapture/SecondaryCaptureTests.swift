//
// SecondaryCaptureTests.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import XCTest
@testable import DICOMKit
@testable import DICOMCore

final class SecondaryCaptureTests: XCTestCase {

    // MARK: - SecondaryCaptureType Tests

    func test_secondaryCaptureType_singleFrame_fromSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(type, .singleFrame)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(type.defaultModality, "OT")
        XCTAssertEqual(type.displayName, "Secondary Capture")
    }

    func test_secondaryCaptureType_multiframeSingleBit_fromSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.840.10008.5.1.4.1.1.7.1")
        XCTAssertEqual(type, .multiframeSingleBit)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.7.1")
        XCTAssertEqual(type.displayName, "Multi-frame Single Bit SC")
    }

    func test_secondaryCaptureType_multiframeGrayscaleByte_fromSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.840.10008.5.1.4.1.1.7.2")
        XCTAssertEqual(type, .multiframeGrayscaleByte)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.7.2")
        XCTAssertEqual(type.displayName, "Multi-frame Grayscale Byte SC")
    }

    func test_secondaryCaptureType_multiframeGrayscaleWord_fromSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.840.10008.5.1.4.1.1.7.3")
        XCTAssertEqual(type, .multiframeGrayscaleWord)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.7.3")
        XCTAssertEqual(type.displayName, "Multi-frame Grayscale Word SC")
    }

    func test_secondaryCaptureType_multiframeTrueColor_fromSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.840.10008.5.1.4.1.1.7.4")
        XCTAssertEqual(type, .multiframeTrueColor)
        XCTAssertEqual(type.sopClassUID, "1.2.840.10008.5.1.4.1.1.7.4")
        XCTAssertEqual(type.displayName, "Multi-frame True Color SC")
    }

    func test_secondaryCaptureType_unknown_fromInvalidSOPClassUID() {
        let type = SecondaryCaptureType(sopClassUID: "1.2.3.4.5")
        XCTAssertEqual(type, .unknown)
        XCTAssertEqual(type.sopClassUID, "")
        XCTAssertEqual(type.defaultModality, "OT")
        XCTAssertEqual(type.displayName, "Unknown SC")
    }

    func test_secondaryCaptureType_defaultPixelCharacteristics() {
        // Single frame - grayscale 8-bit
        let sfDefaults = SecondaryCaptureType.singleFrame.defaultPixelCharacteristics
        XCTAssertEqual(sfDefaults.samplesPerPixel, 1)
        XCTAssertEqual(sfDefaults.bitsAllocated, 8)
        XCTAssertEqual(sfDefaults.photometricInterpretation, "MONOCHROME2")

        // Multi-frame single bit
        let sbDefaults = SecondaryCaptureType.multiframeSingleBit.defaultPixelCharacteristics
        XCTAssertEqual(sbDefaults.samplesPerPixel, 1)
        XCTAssertEqual(sbDefaults.bitsAllocated, 1)

        // Multi-frame grayscale word - 16 bit
        let gwDefaults = SecondaryCaptureType.multiframeGrayscaleWord.defaultPixelCharacteristics
        XCTAssertEqual(gwDefaults.bitsAllocated, 16)
        XCTAssertEqual(gwDefaults.bitsStored, 16)
        XCTAssertEqual(gwDefaults.highBit, 15)

        // Multi-frame true color - RGB
        let tcDefaults = SecondaryCaptureType.multiframeTrueColor.defaultPixelCharacteristics
        XCTAssertEqual(tcDefaults.samplesPerPixel, 3)
        XCTAssertEqual(tcDefaults.photometricInterpretation, "RGB")
    }

    // MARK: - ConversionType Tests

    func test_conversionType_allTypes() {
        XCTAssertEqual(ConversionType.digitizedVideo.rawValue, "DV")
        XCTAssertEqual(ConversionType.digitalInterface.rawValue, "DI")
        XCTAssertEqual(ConversionType.digitizedFilm.rawValue, "DF")
        XCTAssertEqual(ConversionType.workstation.rawValue, "WSD")
        XCTAssertEqual(ConversionType.scannedDocument.rawValue, "SD")
        XCTAssertEqual(ConversionType.scannedImage.rawValue, "SI")
        XCTAssertEqual(ConversionType.synthesized.rawValue, "SYN")
    }

    func test_conversionType_fromDICOMValue() {
        XCTAssertEqual(ConversionType(dicomValue: "DV"), .digitizedVideo)
        XCTAssertEqual(ConversionType(dicomValue: "DI"), .digitalInterface)
        XCTAssertEqual(ConversionType(dicomValue: "DF"), .digitizedFilm)
        XCTAssertEqual(ConversionType(dicomValue: "WSD"), .workstation)
        XCTAssertEqual(ConversionType(dicomValue: "SD"), .scannedDocument)
        XCTAssertEqual(ConversionType(dicomValue: "SI"), .scannedImage)
        XCTAssertEqual(ConversionType(dicomValue: "SYN"), .synthesized)
        XCTAssertEqual(ConversionType(dicomValue: "UNKNOWN"), .unknown)
    }

    func test_conversionType_fromDICOMValue_withWhitespace() {
        XCTAssertEqual(ConversionType(dicomValue: "  DV  "), .digitizedVideo)
        XCTAssertEqual(ConversionType(dicomValue: " WSD "), .workstation)
    }

    func test_conversionType_displayName() {
        XCTAssertEqual(ConversionType.digitizedVideo.displayName, "Digitized Video")
        XCTAssertEqual(ConversionType.digitalInterface.displayName, "Digital Interface")
        XCTAssertEqual(ConversionType.digitizedFilm.displayName, "Digitized Film")
        XCTAssertEqual(ConversionType.workstation.displayName, "Workstation")
        XCTAssertEqual(ConversionType.scannedDocument.displayName, "Scanned Document")
        XCTAssertEqual(ConversionType.scannedImage.displayName, "Scanned Image")
        XCTAssertEqual(ConversionType.synthesized.displayName, "Synthesized Image")
        XCTAssertEqual(ConversionType.unknown.displayName, "Unknown")
    }

    // MARK: - SOP Class UID Constants

    func test_sopClassUIDs() {
        XCTAssertEqual(SecondaryCaptureImage.secondaryCaptureImageStorageUID, "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(SecondaryCaptureImage.multiframeSingleBitSCImageStorageUID, "1.2.840.10008.5.1.4.1.1.7.1")
        XCTAssertEqual(SecondaryCaptureImage.multiframeGrayscaleByteSCImageStorageUID, "1.2.840.10008.5.1.4.1.1.7.2")
        XCTAssertEqual(SecondaryCaptureImage.multiframeGrayscaleWordSCImageStorageUID, "1.2.840.10008.5.1.4.1.1.7.3")
        XCTAssertEqual(SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID, "1.2.840.10008.5.1.4.1.1.7.4")
    }

    // MARK: - SecondaryCaptureImage Property Tests

    func test_secondaryCaptureImage_singleFrame_properties() {
        let sc = SecondaryCaptureImage(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: SecondaryCaptureImage.secondaryCaptureImageStorageUID,
            studyInstanceUID: "1.2.3.4",
            seriesInstanceUID: "1.2.3.4.6",
            rows: 512,
            columns: 512
        )
        XCTAssertEqual(sc.secondaryCaptureType, .singleFrame)
        XCTAssertTrue(sc.isSingleFrame)
        XCTAssertFalse(sc.isMultiFrame)
        XCTAssertEqual(sc.resolution, "512x512")
        XCTAssertTrue(sc.isMonochrome)
        XCTAssertFalse(sc.isColor)
    }

    func test_secondaryCaptureImage_multiFrame_properties() {
        let sc = SecondaryCaptureImage(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID,
            studyInstanceUID: "1.2.3.4",
            seriesInstanceUID: "1.2.3.4.6",
            rows: 1024,
            columns: 768,
            numberOfFrames: 5,
            samplesPerPixel: 3,
            photometricInterpretation: "RGB"
        )
        XCTAssertEqual(sc.secondaryCaptureType, .multiframeTrueColor)
        XCTAssertFalse(sc.isSingleFrame)
        XCTAssertTrue(sc.isMultiFrame)
        XCTAssertEqual(sc.resolution, "768x1024")
        XCTAssertFalse(sc.isMonochrome)
        XCTAssertTrue(sc.isColor)
        XCTAssertEqual(sc.numberOfFrames, 5)
    }

    func test_secondaryCaptureImage_withMetadata() {
        let sc = SecondaryCaptureImage(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: SecondaryCaptureImage.secondaryCaptureImageStorageUID,
            studyInstanceUID: "1.2.3.4",
            seriesInstanceUID: "1.2.3.4.6",
            patientName: "Doe^John",
            patientID: "12345",
            modality: "OT",
            seriesDescription: "Clinical Photo",
            conversionType: .workstation,
            rows: 256,
            columns: 256,
            imageType: ["DERIVED", "SECONDARY"]
        )
        XCTAssertEqual(sc.patientName, "Doe^John")
        XCTAssertEqual(sc.patientID, "12345")
        XCTAssertEqual(sc.modality, "OT")
        XCTAssertEqual(sc.seriesDescription, "Clinical Photo")
        let expectedConversionType: ConversionType = .workstation
        XCTAssertEqual(sc.conversionType, expectedConversionType)
        XCTAssertEqual(sc.imageType, ["DERIVED", "SECONDARY"])
    }

    // MARK: - SecondaryCaptureBuilder Tests

    func test_builder_singleFrame_grayscale() throws {
        let pixelData = Data(repeating: 128, count: 256 * 256)
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 256,
            columns: 256,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setConversionType(.workstation)
        .setPatientName("Smith^John")
        .setPatientID("12345")
        .setPixelData(pixelData)
        .build()

        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.secondaryCaptureImageStorageUID)
        XCTAssertEqual(sc.rows, 256)
        XCTAssertEqual(sc.columns, 256)
        XCTAssertEqual(sc.conversionType, .workstation)
        XCTAssertEqual(sc.patientName, "Smith^John")
        XCTAssertEqual(sc.patientID, "12345")
        XCTAssertEqual(sc.samplesPerPixel, 1)
        XCTAssertEqual(sc.photometricInterpretation, "MONOCHROME2")
        XCTAssertEqual(sc.bitsAllocated, 8)
        XCTAssertEqual(sc.bitsStored, 8)
        XCTAssertEqual(sc.highBit, 7)
        XCTAssertNotNil(sc.pixelData)
        XCTAssertEqual(sc.pixelData?.count, 256 * 256)
        XCTAssertFalse(sc.sopInstanceUID.isEmpty)
        XCTAssertEqual(sc.modality, "OT")
        XCTAssertEqual(sc.imageType, ["DERIVED", "SECONDARY"])
    }

    func test_builder_multiframeTrueColor() throws {
        let pixelData = Data(repeating: 0, count: 128 * 128 * 3 * 5)
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeTrueColor,
            rows: 128,
            columns: 128,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setNumberOfFrames(5)
        .setConversionType(.digitizedVideo)
        .setPixelData(pixelData)
        .build()

        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID)
        XCTAssertEqual(sc.numberOfFrames, 5)
        XCTAssertEqual(sc.samplesPerPixel, 3)
        XCTAssertEqual(sc.photometricInterpretation, "RGB")
        XCTAssertEqual(sc.bitsAllocated, 8)
        XCTAssertEqual(sc.conversionType, .digitizedVideo)
    }

    func test_builder_multiframeGrayscaleWord() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeGrayscaleWord,
            rows: 64,
            columns: 64,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setNumberOfFrames(3)
        .build()

        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.multiframeGrayscaleWordSCImageStorageUID)
        XCTAssertEqual(sc.bitsAllocated, 16)
        XCTAssertEqual(sc.bitsStored, 16)
        XCTAssertEqual(sc.highBit, 15)
        XCTAssertEqual(sc.samplesPerPixel, 1)
    }

    func test_builder_multiframeSingleBit() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeSingleBit,
            rows: 100,
            columns: 100,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setNumberOfFrames(2)
        .build()

        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.multiframeSingleBitSCImageStorageUID)
        XCTAssertEqual(sc.bitsAllocated, 1)
        XCTAssertEqual(sc.bitsStored, 1)
        XCTAssertEqual(sc.highBit, 0)
    }

    func test_builder_multiframeGrayscaleByte() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeGrayscaleByte,
            rows: 200,
            columns: 200,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setNumberOfFrames(4)
        .build()

        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.multiframeGrayscaleByteSCImageStorageUID)
        XCTAssertEqual(sc.bitsAllocated, 8)
        XCTAssertEqual(sc.bitsStored, 8)
        XCTAssertEqual(sc.highBit, 7)
        XCTAssertEqual(sc.samplesPerPixel, 1)
        XCTAssertEqual(sc.photometricInterpretation, "MONOCHROME2")
    }

    func test_builder_withAllMetadata() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 512,
            columns: 512,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setSOPInstanceUID("1.2.3.4.5.7")
        .setInstanceNumber(1)
        .setPatientName("Doe^Jane")
        .setPatientID("54321")
        .setModality("OT")
        .setSeriesDescription("Screen Capture")
        .setSeriesNumber(1)
        .setConversionType(.workstation)
        .setImageType(["ORIGINAL", "PRIMARY"])
        .setDerivationDescription("Screen capture from PACS workstation")
        .setBurnedInAnnotation("YES")
        .build()

        XCTAssertEqual(sc.sopInstanceUID, "1.2.3.4.5.7")
        XCTAssertEqual(sc.instanceNumber, 1)
        XCTAssertEqual(sc.patientName, "Doe^Jane")
        XCTAssertEqual(sc.patientID, "54321")
        XCTAssertEqual(sc.modality, "OT")
        XCTAssertEqual(sc.seriesDescription, "Screen Capture")
        XCTAssertEqual(sc.seriesNumber, 1)
        XCTAssertEqual(sc.conversionType, .workstation)
        XCTAssertEqual(sc.imageType, ["ORIGINAL", "PRIMARY"])
        XCTAssertEqual(sc.derivationDescription, "Screen capture from PACS workstation")
        XCTAssertEqual(sc.burnedInAnnotation, "YES")
    }

    func test_builder_withCustomPixelCharacteristics() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 256,
            columns: 256,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setSamplesPerPixel(3)
        .setPhotometricInterpretation("RGB")
        .setBitDepth(allocated: 8, stored: 8, highBit: 7)
        .setPlanarConfiguration(0)
        .build()

        XCTAssertEqual(sc.samplesPerPixel, 3)
        XCTAssertEqual(sc.photometricInterpretation, "RGB")
        XCTAssertEqual(sc.bitsAllocated, 8)
        XCTAssertEqual(sc.planarConfiguration, 0)
    }

    // MARK: - Builder Validation Tests

    func test_builder_invalidRows_throws() {
        let builder = SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 0,
            columns: 256,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertTrue("\(error)".contains("Rows must be greater than 0"))
        }
    }

    func test_builder_invalidColumns_throws() {
        let builder = SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 256,
            columns: 0,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertTrue("\(error)".contains("Columns must be greater than 0"))
        }
    }

    func test_builder_unknownType_throws() {
        let builder = SecondaryCaptureBuilder(
            secondaryCaptureType: .unknown,
            rows: 256,
            columns: 256,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertTrue("\(error)".contains("Secondary Capture type cannot be unknown"))
        }
    }

    // MARK: - DataSet Conversion Tests

    func test_builder_buildDataSet_singleFrame() throws {
        let pixelData = Data(repeating: 200, count: 64 * 64)
        let dataSet = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 64,
            columns: 64,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setPatientName("Test^Patient")
        .setPatientID("TEST001")
        .setConversionType(.scannedImage)
        .setPixelData(pixelData)
        .buildDataSet()

        XCTAssertEqual(dataSet.string(for: .sopClassUID), SecondaryCaptureImage.secondaryCaptureImageStorageUID)
        XCTAssertNotNil(dataSet.string(for: .sopInstanceUID))
        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), "1.2.3.4.5.6")
        XCTAssertEqual(dataSet.string(for: .patientName), "Test^Patient")
        XCTAssertEqual(dataSet.string(for: .patientID), "TEST001")
        XCTAssertEqual(dataSet.string(for: .conversionType), "SI")
        XCTAssertEqual(dataSet[.rows]?.uint16Value, 64)
        XCTAssertEqual(dataSet[.columns]?.uint16Value, 64)
        XCTAssertEqual(dataSet[.samplesPerPixel]?.uint16Value, 1)
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "MONOCHROME2")
        XCTAssertNotNil(dataSet[.pixelData])
    }

    func test_builder_buildDataSet_multiframe() throws {
        let dataSet = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeTrueColor,
            rows: 128,
            columns: 128,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setNumberOfFrames(3)
        .buildDataSet()

        XCTAssertEqual(dataSet.string(for: .sopClassUID), SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID)
        XCTAssertEqual(dataSet[.samplesPerPixel]?.uint16Value, 3)
        XCTAssertEqual(dataSet.string(for: .photometricInterpretation), "RGB")
        // Should include numberOfFrames for multi-frame types
        XCTAssertNotNil(dataSet[.numberOfFrames])
    }

    func test_toDataSet_includesImageType() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 64,
            columns: 64,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setImageType(["DERIVED", "SECONDARY", "CAPTURE"])
        .build()

        let dataSet = sc.toDataSet()
        let imageTypeStr = dataSet.string(for: .imageType)
        XCTAssertEqual(imageTypeStr, "DERIVED\\SECONDARY\\CAPTURE")
    }

    func test_toDataSet_includesSCFields() throws {
        let sc = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 64,
            columns: 64,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setConversionType(.synthesized)
        .setBurnedInAnnotation("NO")
        .setDerivationDescription("AI-generated synthetic image")
        .build()

        let dataSet = sc.toDataSet()
        XCTAssertEqual(dataSet.string(for: .conversionType), "SYN")
        XCTAssertEqual(dataSet.string(for: .burnedInAnnotation), "NO")
        XCTAssertEqual(dataSet.string(for: .derivationDescription), "AI-generated synthetic image")
    }

    // MARK: - Parser Tests

    func test_parser_basicParsing() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(SecondaryCaptureImage.secondaryCaptureImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 512)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 512)
        dataSet[.samplesPerPixel] = DataElement.uint16(tag: .samplesPerPixel, value: 1)
        dataSet.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
        dataSet[.bitsAllocated] = DataElement.uint16(tag: .bitsAllocated, value: 8)
        dataSet[.bitsStored] = DataElement.uint16(tag: .bitsStored, value: 8)
        dataSet[.highBit] = DataElement.uint16(tag: .highBit, value: 7)
        dataSet[.pixelRepresentation] = DataElement.uint16(tag: .pixelRepresentation, value: 0)
        dataSet.setString("WSD", for: .conversionType, vr: .CS)

        let sc = try SecondaryCaptureParser.parse(from: dataSet)
        XCTAssertEqual(sc.sopInstanceUID, "1.2.3.4.5.6.7")
        XCTAssertEqual(sc.sopClassUID, SecondaryCaptureImage.secondaryCaptureImageStorageUID)
        XCTAssertEqual(sc.rows, 512)
        XCTAssertEqual(sc.columns, 512)
        XCTAssertEqual(sc.conversionType, .workstation)
        XCTAssertEqual(sc.samplesPerPixel, 1)
        XCTAssertEqual(sc.photometricInterpretation, "MONOCHROME2")
        XCTAssertEqual(sc.numberOfFrames, 1)
    }

    func test_parser_withPatientInfo() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(SecondaryCaptureImage.secondaryCaptureImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 256)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 256)
        dataSet.setString("Smith^Jane", for: .patientName, vr: .PN)
        dataSet.setString("98765", for: .patientID, vr: .LO)
        dataSet.setString("OT", for: .modality, vr: .CS)
        dataSet.setString("Diagnostic Photo", for: .seriesDescription, vr: .LO)

        let sc = try SecondaryCaptureParser.parse(from: dataSet)
        XCTAssertEqual(sc.patientName, "Smith^Jane")
        XCTAssertEqual(sc.patientID, "98765")
        XCTAssertEqual(sc.modality, "OT")
        XCTAssertEqual(sc.seriesDescription, "Diagnostic Photo")
    }

    func test_parser_withImageType() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(SecondaryCaptureImage.secondaryCaptureImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 128)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 128)
        dataSet.setString("DERIVED\\SECONDARY", for: .imageType, vr: .CS)
        dataSet.setString("YES", for: .burnedInAnnotation, vr: .CS)

        let sc = try SecondaryCaptureParser.parse(from: dataSet)
        XCTAssertEqual(sc.imageType, ["DERIVED", "SECONDARY"])
        XCTAssertEqual(sc.burnedInAnnotation, "YES")
    }

    func test_parser_multiframe() throws {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString(SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID, for: .sopClassUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 320)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 240)
        dataSet[.samplesPerPixel] = DataElement.uint16(tag: .samplesPerPixel, value: 3)
        dataSet.setString("RGB", for: .photometricInterpretation, vr: .CS)
        dataSet.setString("10", for: .numberOfFrames, vr: .IS)

        let sc = try SecondaryCaptureParser.parse(from: dataSet)
        XCTAssertEqual(sc.secondaryCaptureType, .multiframeTrueColor)
        XCTAssertEqual(sc.numberOfFrames, 10)
        XCTAssertEqual(sc.samplesPerPixel, 3)
        XCTAssertEqual(sc.photometricInterpretation, "RGB")
    }

    // MARK: - Parser Error Tests

    func test_parser_missingSOPInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 256)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 256)

        XCTAssertThrowsError(try SecondaryCaptureParser.parse(from: dataSet)) { error in
            XCTAssertTrue("\(error)".contains("Missing SOP Instance UID"))
        }
    }

    func test_parser_missingStudyInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 256)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 256)

        XCTAssertThrowsError(try SecondaryCaptureParser.parse(from: dataSet)) { error in
            XCTAssertTrue("\(error)".contains("Missing Study Instance UID"))
        }
    }

    func test_parser_missingSeriesInstanceUID_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 256)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 256)

        XCTAssertThrowsError(try SecondaryCaptureParser.parse(from: dataSet)) { error in
            XCTAssertTrue("\(error)".contains("Missing Series Instance UID"))
        }
    }

    func test_parser_missingRows_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: 256)

        XCTAssertThrowsError(try SecondaryCaptureParser.parse(from: dataSet)) { error in
            XCTAssertTrue("\(error)".contains("Missing Rows attribute"))
        }
    }

    func test_parser_missingColumns_throws() {
        var dataSet = DataSet()
        dataSet.setString("1.2.3.4.5.6.7", for: .sopInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5", for: .studyInstanceUID, vr: .UI)
        dataSet.setString("1.2.3.4.5.6", for: .seriesInstanceUID, vr: .UI)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: 256)

        XCTAssertThrowsError(try SecondaryCaptureParser.parse(from: dataSet)) { error in
            XCTAssertTrue("\(error)".contains("Missing Columns attribute"))
        }
    }

    // MARK: - Round-Trip Tests

    func test_roundTrip_singleFrame() throws {
        let originalSC = try SecondaryCaptureBuilder(
            secondaryCaptureType: .singleFrame,
            rows: 256,
            columns: 256,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setSOPInstanceUID("1.2.3.4.5.7")
        .setConversionType(.workstation)
        .setPatientName("Test^Patient")
        .setPatientID("TEST001")
        .setModality("OT")
        .setSeriesDescription("Screen Capture")
        .setImageType(["DERIVED", "SECONDARY"])
        .setBurnedInAnnotation("NO")
        .build()

        // Convert to DataSet
        let dataSet = originalSC.toDataSet()

        // Parse back
        let parsedSC = try SecondaryCaptureParser.parse(from: dataSet)

        // Verify round-trip
        XCTAssertEqual(parsedSC.sopInstanceUID, originalSC.sopInstanceUID)
        XCTAssertEqual(parsedSC.sopClassUID, originalSC.sopClassUID)
        XCTAssertEqual(parsedSC.studyInstanceUID, originalSC.studyInstanceUID)
        XCTAssertEqual(parsedSC.seriesInstanceUID, originalSC.seriesInstanceUID)
        XCTAssertEqual(parsedSC.rows, originalSC.rows)
        XCTAssertEqual(parsedSC.columns, originalSC.columns)
        XCTAssertEqual(parsedSC.conversionType, originalSC.conversionType)
        XCTAssertEqual(parsedSC.patientName, originalSC.patientName)
        XCTAssertEqual(parsedSC.patientID, originalSC.patientID)
        XCTAssertEqual(parsedSC.modality, originalSC.modality)
        XCTAssertEqual(parsedSC.seriesDescription, originalSC.seriesDescription)
        XCTAssertEqual(parsedSC.imageType, originalSC.imageType)
        XCTAssertEqual(parsedSC.burnedInAnnotation, originalSC.burnedInAnnotation)
    }

    func test_roundTrip_multiframeTrueColor() throws {
        let pixelData = Data(repeating: 100, count: 64 * 64 * 3 * 3)
        let originalSC = try SecondaryCaptureBuilder(
            secondaryCaptureType: .multiframeTrueColor,
            rows: 64,
            columns: 64,
            studyInstanceUID: "1.2.3.4.5",
            seriesInstanceUID: "1.2.3.4.5.6"
        )
        .setSOPInstanceUID("1.2.3.4.5.8")
        .setNumberOfFrames(3)
        .setConversionType(.digitizedVideo)
        .setPixelData(pixelData)
        .build()

        let dataSet = originalSC.toDataSet()
        let parsedSC = try SecondaryCaptureParser.parse(from: dataSet)

        XCTAssertEqual(parsedSC.sopClassUID, SecondaryCaptureImage.multiframeTrueColorSCImageStorageUID)
        XCTAssertEqual(parsedSC.numberOfFrames, 3)
        XCTAssertEqual(parsedSC.samplesPerPixel, 3)
        XCTAssertEqual(parsedSC.photometricInterpretation, "RGB")
        XCTAssertEqual(parsedSC.pixelData?.count, pixelData.count)
    }

    // MARK: - Tag Tests

    func test_secondaryCaptureTag_conversionType() {
        XCTAssertEqual(Tag.conversionType.group, 0x0008)
        XCTAssertEqual(Tag.conversionType.element, 0x0064)
    }

    func test_secondaryCaptureTag_dateOfSecondaryCapture() {
        XCTAssertEqual(Tag.dateOfSecondaryCapture.group, 0x0018)
        XCTAssertEqual(Tag.dateOfSecondaryCapture.element, 0x1012)
    }

    func test_secondaryCaptureTag_timeOfSecondaryCapture() {
        XCTAssertEqual(Tag.timeOfSecondaryCapture.group, 0x0018)
        XCTAssertEqual(Tag.timeOfSecondaryCapture.element, 0x1014)
    }

    func test_secondaryCaptureTag_pageNumberVector() {
        XCTAssertEqual(Tag.pageNumberVector.group, 0x0018)
        XCTAssertEqual(Tag.pageNumberVector.element, 0x2001)
    }
}
