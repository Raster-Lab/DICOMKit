//
// SecondaryCaptureParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for DICOM Secondary Capture Image objects
///
/// Parses Secondary Capture IODs from DICOM data sets, extracting
/// image metadata and pixel data.
///
/// Reference: PS3.3 A.8 - Secondary Capture Image IOD
/// Reference: PS3.3 A.8.1 - Multi-frame SC Image IODs
public struct SecondaryCaptureParser {

    /// Parse a SecondaryCaptureImage from a DICOM data set
    ///
    /// - Parameter dataSet: DICOM data set containing a Secondary Capture IOD
    /// - Returns: Parsed SecondaryCaptureImage
    /// - Throws: DICOMError if parsing fails
    public static func parse(from dataSet: DataSet) throws -> SecondaryCaptureImage {
        // Parse SOP Instance UID (required)
        guard let sopInstanceUID = dataSet.string(for: .sopInstanceUID) else {
            throw DICOMError.parsingFailed("Missing SOP Instance UID")
        }

        let sopClassUID = dataSet.string(for: .sopClassUID) ?? SecondaryCaptureImage.secondaryCaptureImageStorageUID

        // Parse Study and Series UIDs (required)
        guard let studyInstanceUID = dataSet.string(for: .studyInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Study Instance UID")
        }

        guard let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Series Instance UID")
        }

        // Parse Image Pixel Module (required)
        guard let rowsValue = dataSet[.rows]?.uint16Value else {
            throw DICOMError.parsingFailed("Missing Rows attribute")
        }

        guard let columnsValue = dataSet[.columns]?.uint16Value else {
            throw DICOMError.parsingFailed("Missing Columns attribute")
        }

        // Parse Number of Frames (optional, defaults to 1)
        let numberOfFrames: Int
        if let nfElement = dataSet[.numberOfFrames]?.integerStringValue {
            numberOfFrames = nfElement.value
        } else {
            numberOfFrames = 1
        }

        // Parse Image Pixel Module optional attributes
        let samplesPerPixel = dataSet[.samplesPerPixel]?.uint16Value.flatMap { Int($0) } ?? 1
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation) ?? "MONOCHROME2"
        let bitsAllocated = dataSet[.bitsAllocated]?.uint16Value.flatMap { Int($0) } ?? 8
        let bitsStored = dataSet[.bitsStored]?.uint16Value.flatMap { Int($0) } ?? 8
        let highBit = dataSet[.highBit]?.uint16Value.flatMap { Int($0) } ?? 7
        let pixelRepresentation = dataSet[.pixelRepresentation]?.uint16Value.flatMap { Int($0) } ?? 0
        let planarConfiguration = dataSet[.planarConfiguration]?.uint16Value.flatMap { Int($0) }

        // Parse Instance Number
        let instanceNumber = dataSet[.instanceNumber]?.integerStringValue?.value

        // Parse Patient Module
        let patientName = dataSet.string(for: .patientName)
        let patientID = dataSet.string(for: .patientID)

        // Parse Series Module
        let modality = dataSet.string(for: .modality)
        let seriesDescription = dataSet.string(for: .seriesDescription)
        let seriesNumber = dataSet[.seriesNumber]?.integerStringValue?.value

        // Parse SC Equipment Module
        let conversionTypeString = dataSet.string(for: .conversionType) ?? ""
        let conversionType = ConversionType(dicomValue: conversionTypeString)

        // Parse SC Image Module
        let dateOfSecondaryCapture = dataSet.date(for: .dateOfSecondaryCapture)
        let timeOfSecondaryCapture = dataSet.time(for: .timeOfSecondaryCapture)

        // Parse General Image Module
        let imageTypeString = dataSet.string(for: .imageType)
        let imageType = imageTypeString?.components(separatedBy: "\\")
        let derivationDescription = dataSet.string(for: .derivationDescription)
        let burnedInAnnotation = dataSet.string(for: .burnedInAnnotation)

        // Parse Content Date/Time
        let contentDate = dataSet.date(for: .contentDate)
        let contentTime = dataSet.time(for: .contentTime)

        // Parse Pixel Data
        let pixelData = dataSet[.pixelData]?.valueData

        return SecondaryCaptureImage(
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            patientName: patientName,
            patientID: patientID,
            modality: modality,
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            conversionType: conversionType,
            dateOfSecondaryCapture: dateOfSecondaryCapture,
            timeOfSecondaryCapture: timeOfSecondaryCapture,
            rows: Int(rowsValue),
            columns: Int(columnsValue),
            numberOfFrames: numberOfFrames,
            samplesPerPixel: samplesPerPixel,
            photometricInterpretation: photometricInterpretation,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit,
            pixelRepresentation: pixelRepresentation,
            planarConfiguration: planarConfiguration,
            imageType: imageType,
            derivationDescription: derivationDescription,
            burnedInAnnotation: burnedInAnnotation,
            contentDate: contentDate,
            contentTime: contentTime,
            pixelData: pixelData
        )
    }
}
