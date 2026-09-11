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
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation)
            ?? Video.defaultPhotometricInterpretation
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

        // Parse pixel data.
        //
        // Every video transfer syntax is encapsulated (PS3.5 A.4), so a conformant
        // file carries the bit stream in fragments and leaves `valueData` empty.
        // Fragments are concatenated in order: for the non-fragmentable UIDs there
        // is exactly one, and for the "….1" fragmentable variants the bit stream is
        // the concatenation of them all. The `valueData` branch is a fallback for
        // legacy files that (incorrectly) stored the stream as a native OB value.
        let pixelData: Data?
        if let pixelElement = dataSet[.pixelData] {
            if let fragments = pixelElement.encapsulatedFragments, !fragments.isEmpty {
                var combined = Data()
                for fragment in fragments {
                    combined.append(fragment)
                }
                pixelData = combined
            } else if !pixelElement.valueData.isEmpty {
                pixelData = pixelElement.valueData
            } else {
                pixelData = nil
            }
        } else {
            pixelData = nil
        }

        // Parse VL Image / General Equipment / General Acquisition / General Image
        // and the Type 2 study and patient identifiers. Zero-length Type 2 values
        // read back as empty strings; normalize those to nil so a round trip does
        // not turn "absent" into "present and empty" at the model level.
        let imageType = dataSet[.imageType]?.stringValues?.filter { !$0.isEmpty }
        let manufacturer = Self.nonEmpty(dataSet.string(for: .manufacturer))
        let manufacturerModelName = Self.nonEmpty(dataSet.string(for: .manufacturerModelName))
        let deviceSerialNumber = Self.nonEmpty(dataSet.string(for: .deviceSerialNumber))
        let softwareVersions = Self.nonEmpty(dataSet.string(for: .softwareVersions))
        let institutionName = Self.nonEmpty(dataSet.string(for: .institutionName))
        let acquisitionDate = dataSet.date(for: .acquisitionDate)
        let acquisitionTime = dataSet.time(for: .acquisitionTime)
        let patientOrientation = Self.nonEmpty(dataSet.string(for: .patientOrientation))
        let studyDate = dataSet.date(for: .studyDate)
        let studyTime = dataSet.time(for: .studyTime)
        let referringPhysicianName = Self.nonEmpty(dataSet.string(for: .referringPhysicianName))
        let studyID = Self.nonEmpty(dataSet.string(for: .studyID))
        let accessionNumber = Self.nonEmpty(dataSet.string(for: .accessionNumber))
        let patientBirthDate = dataSet.date(for: .patientBirthDate)
        let patientSex = Self.nonEmpty(dataSet.string(for: .patientSex))

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
            imageType: imageType ?? Video.defaultImageType,
            manufacturer: manufacturer,
            manufacturerModelName: manufacturerModelName,
            deviceSerialNumber: deviceSerialNumber,
            softwareVersions: softwareVersions,
            institutionName: institutionName,
            acquisitionDate: acquisitionDate,
            acquisitionTime: acquisitionTime,
            patientOrientation: patientOrientation,
            studyDate: studyDate,
            studyTime: studyTime,
            referringPhysicianName: referringPhysicianName,
            studyID: studyID,
            accessionNumber: accessionNumber,
            patientBirthDate: patientBirthDate,
            patientSex: patientSex,
            pixelData: pixelData
        )
    }

    /// Maps an empty or whitespace-only string to nil.
    ///
    /// Type 2 attributes are written zero-length when unknown; reading one back as
    /// `""` would misrepresent "not supplied" as "supplied as empty".
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return value
    }
}
