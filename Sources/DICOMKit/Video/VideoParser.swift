//
// VideoParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for DICOM Video objects
///
/// Parses Video IODs from DICOM data sets, extracting video metadata
/// and encapsulated pixel data.
///
/// Reference: PS3.3 A.32.5 - Video Endoscopic Image IOD
/// Reference: PS3.3 A.32.6 - Video Microscopic Image IOD
/// Reference: PS3.3 A.32.7 - Video Photographic Image IOD
public struct VideoParser {

    /// Parse a Video from a DICOM data set
    ///
    /// - Parameter dataSet: DICOM data set containing a Video IOD
    /// - Returns: Parsed Video
    /// - Throws: DICOMError if parsing fails
    public static func parse(from dataSet: DataSet) throws -> Video {
        // Parse SOP Instance UID (required)
        guard let sopInstanceUID = dataSet.string(for: .sopInstanceUID) else {
            throw DICOMError.parsingFailed("Missing SOP Instance UID")
        }

        let sopClassUID = dataSet.string(for: .sopClassUID) ?? Video.videoEndoscopicImageStorageUID

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

        // Parse Number of Frames (required for video)
        let numberOfFrames: Int
        if let nfElement = dataSet[.numberOfFrames]?.integerStringValue {
            numberOfFrames = nfElement.value
        } else {
            throw DICOMError.parsingFailed("Missing Number of Frames attribute")
        }

        // Parse optional identification
        let instanceNumber = dataSet[.instanceNumber]?.integerStringValue?.value

        // Parse optional patient information
        let patientName = dataSet.string(for: .patientName)
        let patientID = dataSet.string(for: .patientID)

        // Parse optional series information
        let modality = dataSet.string(for: .modality)
        let seriesDescription = dataSet.string(for: .seriesDescription)
        let seriesNumber: Int?
        if let seriesNumElement = dataSet[.seriesNumber]?.integerStringValue {
            seriesNumber = seriesNumElement.value
        } else {
            seriesNumber = nil
        }

        // Parse Image Pixel Module attributes
        let samplesPerPixel = Int(dataSet[.samplesPerPixel]?.uint16Value ?? 3)
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation) ?? "YBR_FULL_422"
        let bitsAllocated = Int(dataSet[.bitsAllocated]?.uint16Value ?? 8)
        let bitsStored = Int(dataSet[.bitsStored]?.uint16Value ?? 8)
        let highBit = Int(dataSet[.highBit]?.uint16Value ?? 7)
        let pixelRepresentation = Int(dataSet[.pixelRepresentation]?.uint16Value ?? 0)
        let planarConfiguration: Int?
        if let pc = dataSet[.planarConfiguration]?.uint16Value {
            planarConfiguration = Int(pc)
        } else {
            planarConfiguration = nil
        }

        // Parse Cine Module attributes
        let frameTime = dataSet[.frameTime]?.decimalStringValue?.value
        let cineRate = dataSet[.cineRate]?.integerStringValue?.value
        let recommendedDisplayFrameRate = dataSet[.recommendedDisplayFrameRate]?.integerStringValue?.value
        let frameDelay = dataSet[.frameDelay]?.decimalStringValue?.value
        let actualFrameDuration = dataSet[.actualFrameDuration]?.integerStringValue?.value

        // Parse trim points
        let startTrim = dataSet[.startTrim]?.integerStringValue?.value
        let stopTrim = dataSet[.stopTrim]?.integerStringValue?.value

        // Parse content date/time
        let contentDate = dataSet.date(for: .contentDate)
        let contentTime = dataSet.time(for: .contentTime)

        // Parse compression information
        let lossyImageCompression = dataSet.string(for: .lossyImageCompression)
        let lossyImageCompressionRatio = dataSet[.lossyImageCompressionRatio]?.decimalStringValue?.value
        let lossyImageCompressionMethod = dataSet.string(for: .lossyImageCompressionMethod)

        // Parse pixel data
        let pixelData = dataSet[.pixelData]?.valueData

        return Video(
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
            frameTime: frameTime,
            cineRate: cineRate,
            recommendedDisplayFrameRate: recommendedDisplayFrameRate,
            frameDelay: frameDelay,
            actualFrameDuration: actualFrameDuration,
            startTrim: startTrim,
            stopTrim: stopTrim,
            contentDate: contentDate,
            contentTime: contentTime,
            lossyImageCompression: lossyImageCompression,
            lossyImageCompressionRatio: lossyImageCompressionRatio,
            lossyImageCompressionMethod: lossyImageCompressionMethod,
            pixelData: pixelData
        )
    }
}
