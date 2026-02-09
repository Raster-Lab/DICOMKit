//
// VideoBuilder.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Builder for creating DICOM Video objects
///
/// VideoBuilder provides a fluent API for constructing Video IODs,
/// enabling video data to be wrapped as DICOM objects for storage and transmission.
///
/// Example - Creating a video endoscopic DICOM:
/// ```swift
/// let videoData = try Data(contentsOf: videoURL)
/// let video = try VideoBuilder(
///     videoType: .endoscopic,
///     rows: 1080,
///     columns: 1920,
///     numberOfFrames: 900,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setFrameRate(30)
/// .setPatientName("Smith^John")
/// .setPatientID("12345")
/// .setPixelData(videoData)
/// .build()
/// ```
///
/// Reference: PS3.3 A.32.5 - Video Endoscopic Image IOD
/// Reference: PS3.3 A.32.6 - Video Microscopic Image IOD
/// Reference: PS3.3 A.32.7 - Video Photographic Image IOD
public final class VideoBuilder {

    // MARK: - Required Configuration

    private let videoType: VideoType
    private let rows: Int
    private let columns: Int
    private let numberOfFrames: Int
    private let studyInstanceUID: String
    private let seriesInstanceUID: String

    // MARK: - Optional Metadata

    private var sopInstanceUID: String?
    private var instanceNumber: Int?
    private var patientName: String?
    private var patientID: String?
    private var modality: String?
    private var seriesDescription: String?
    private var seriesNumber: Int?
    private var samplesPerPixel: Int = 3
    private var photometricInterpretation: String = "YBR_FULL_422"
    private var bitsAllocated: Int = 8
    private var bitsStored: Int = 8
    private var highBit: Int = 7
    private var pixelRepresentation: Int = 0
    private var planarConfiguration: Int?
    private var frameTime: Double?
    private var cineRate: Int?
    private var recommendedDisplayFrameRate: Int?
    private var frameDelay: Double?
    private var actualFrameDuration: Int?
    private var startTrim: Int?
    private var stopTrim: Int?
    private var contentDate: DICOMDate?
    private var contentTime: DICOMTime?
    private var lossyImageCompression: String?
    private var lossyImageCompressionRatio: Double?
    private var lossyImageCompressionMethod: String?
    private var pixelData: Data?

    // MARK: - Initialization

    /// Creates a new VideoBuilder
    ///
    /// - Parameters:
    ///   - videoType: The type of video (endoscopic, microscopic, photographic)
    ///   - rows: Number of rows (height) in pixels
    ///   - columns: Number of columns (width) in pixels
    ///   - numberOfFrames: Number of frames in the video
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    public init(
        videoType: VideoType,
        rows: Int,
        columns: Int,
        numberOfFrames: Int,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.videoType = videoType
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = numberOfFrames
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
    }

    // MARK: - Fluent Setters

    /// Sets the SOP Instance UID (auto-generated if not set)
    @discardableResult
    public func setSOPInstanceUID(_ uid: String) -> Self {
        self.sopInstanceUID = uid
        return self
    }

    /// Sets the Instance Number
    @discardableResult
    public func setInstanceNumber(_ number: Int) -> Self {
        self.instanceNumber = number
        return self
    }

    /// Sets the Patient Name
    @discardableResult
    public func setPatientName(_ name: String) -> Self {
        self.patientName = name
        return self
    }

    /// Sets the Patient ID
    @discardableResult
    public func setPatientID(_ id: String) -> Self {
        self.patientID = id
        return self
    }

    /// Sets the Modality (auto-inferred from video type if not set)
    @discardableResult
    public func setModality(_ modality: String) -> Self {
        self.modality = modality
        return self
    }

    /// Sets the Series Description
    @discardableResult
    public func setSeriesDescription(_ description: String) -> Self {
        self.seriesDescription = description
        return self
    }

    /// Sets the Series Number
    @discardableResult
    public func setSeriesNumber(_ number: Int) -> Self {
        self.seriesNumber = number
        return self
    }

    /// Sets the Samples Per Pixel (default: 3)
    @discardableResult
    public func setSamplesPerPixel(_ value: Int) -> Self {
        self.samplesPerPixel = value
        return self
    }

    /// Sets the Photometric Interpretation (default: "YBR_FULL_422")
    @discardableResult
    public func setPhotometricInterpretation(_ value: String) -> Self {
        self.photometricInterpretation = value
        return self
    }

    /// Sets the bit depth parameters
    @discardableResult
    public func setBitDepth(allocated: Int, stored: Int, highBit: Int) -> Self {
        self.bitsAllocated = allocated
        self.bitsStored = stored
        self.highBit = highBit
        return self
    }

    /// Sets the Pixel Representation (0 = unsigned, 1 = signed)
    @discardableResult
    public func setPixelRepresentation(_ value: Int) -> Self {
        self.pixelRepresentation = value
        return self
    }

    /// Sets the Planar Configuration (0 = interleaved, 1 = separate planes)
    @discardableResult
    public func setPlanarConfiguration(_ value: Int) -> Self {
        self.planarConfiguration = value
        return self
    }

    /// Sets the frame rate via frame time and recommended display frame rate
    ///
    /// - Parameter fps: Frames per second
    @discardableResult
    public func setFrameRate(_ fps: Int) -> Self {
        self.cineRate = fps
        self.recommendedDisplayFrameRate = fps
        self.frameTime = 1000.0 / Double(fps)
        return self
    }

    /// Sets the Frame Time in milliseconds
    @discardableResult
    public func setFrameTime(_ time: Double) -> Self {
        self.frameTime = time
        return self
    }

    /// Sets the Cine Rate (frames/second at acquisition)
    @discardableResult
    public func setCineRate(_ rate: Int) -> Self {
        self.cineRate = rate
        return self
    }

    /// Sets the Recommended Display Frame Rate
    @discardableResult
    public func setRecommendedDisplayFrameRate(_ rate: Int) -> Self {
        self.recommendedDisplayFrameRate = rate
        return self
    }

    /// Sets the Frame Delay in milliseconds
    @discardableResult
    public func setFrameDelay(_ delay: Double) -> Self {
        self.frameDelay = delay
        return self
    }

    /// Sets the Actual Frame Duration in milliseconds
    @discardableResult
    public func setActualFrameDuration(_ duration: Int) -> Self {
        self.actualFrameDuration = duration
        return self
    }

    /// Sets the Start Trim frame number
    @discardableResult
    public func setStartTrim(_ frame: Int) -> Self {
        self.startTrim = frame
        return self
    }

    /// Sets the Stop Trim frame number
    @discardableResult
    public func setStopTrim(_ frame: Int) -> Self {
        self.stopTrim = frame
        return self
    }

    /// Sets the Content Date
    @discardableResult
    public func setContentDate(_ date: DICOMDate) -> Self {
        self.contentDate = date
        return self
    }

    /// Sets the Content Time
    @discardableResult
    public func setContentTime(_ time: DICOMTime) -> Self {
        self.contentTime = time
        return self
    }

    /// Sets lossy compression information
    ///
    /// - Parameters:
    ///   - ratio: Compression ratio
    ///   - method: Compression method identifier (e.g., "ISO_14496_10" for H.264)
    @discardableResult
    public func setLossyCompression(ratio: Double, method: String) -> Self {
        self.lossyImageCompression = "01"
        self.lossyImageCompressionRatio = ratio
        self.lossyImageCompressionMethod = method
        return self
    }

    /// Sets lossy compression information from a video codec
    @discardableResult
    public func setLossyCompression(codec: VideoCodec, ratio: Double = 10.0) -> Self {
        self.lossyImageCompression = "01"
        self.lossyImageCompressionRatio = ratio
        self.lossyImageCompressionMethod = codec.compressionMethod
        return self
    }

    /// Sets the encapsulated video pixel data
    @discardableResult
    public func setPixelData(_ data: Data) -> Self {
        self.pixelData = data
        return self
    }

    // MARK: - Build

    /// Builds the Video object
    ///
    /// - Returns: The constructed Video
    /// - Throws: DICOMError if required data is invalid
    public func build() throws -> Video {
        guard rows > 0 else {
            throw DICOMError.parsingFailed("Rows must be greater than 0")
        }

        guard columns > 0 else {
            throw DICOMError.parsingFailed("Columns must be greater than 0")
        }

        guard numberOfFrames > 0 else {
            throw DICOMError.parsingFailed("Number of frames must be greater than 0")
        }

        guard videoType != .unknown else {
            throw DICOMError.parsingFailed("Video type cannot be unknown")
        }

        let instanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().value
        let effectiveModality = modality ?? videoType.defaultModality

        return Video(
            sopInstanceUID: instanceUID,
            sopClassUID: videoType.sopClassUID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            patientName: patientName,
            patientID: patientID,
            modality: effectiveModality,
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            rows: rows,
            columns: columns,
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

    /// Builds the Video and converts it to a DICOM DataSet
    ///
    /// - Returns: A DataSet ready for DICOM file creation
    /// - Throws: DICOMError if building fails
    public func buildDataSet() throws -> DataSet {
        let video = try build()
        return video.toDataSet()
    }
}

// MARK: - DataSet Conversion

extension Video {

    /// Converts the Video to a DICOM DataSet
    ///
    /// Creates a DataSet with all required and optional attributes for the Video IOD.
    ///
    /// - Returns: A DataSet representation of this video
    public func toDataSet() -> DataSet {
        var dataSet = DataSet()

        // SOP Common Module
        dataSet.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        dataSet.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)

        // Patient Module
        if let patientName = patientName {
            dataSet.setString(patientName, for: .patientName, vr: .PN)
        }
        if let patientID = patientID {
            dataSet.setString(patientID, for: .patientID, vr: .LO)
        }

        // General Study Module
        dataSet.setString(studyInstanceUID, for: .studyInstanceUID, vr: .UI)

        // General Series Module
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)

        if let modality = modality {
            dataSet.setString(modality, for: .modality, vr: .CS)
        }
        if let seriesDescription = seriesDescription {
            dataSet.setString(seriesDescription, for: .seriesDescription, vr: .LO)
        }
        if let seriesNumber = seriesNumber {
            dataSet.setString(String(seriesNumber), for: .seriesNumber, vr: .IS)
        }

        // Instance Number
        if let instanceNumber = instanceNumber {
            dataSet.setString(String(instanceNumber), for: .instanceNumber, vr: .IS)
        }

        // Image Pixel Module
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: UInt16(rows))
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: UInt16(columns))
        dataSet.setString(String(numberOfFrames), for: .numberOfFrames, vr: .IS)
        dataSet[.samplesPerPixel] = DataElement.uint16(tag: .samplesPerPixel, value: UInt16(samplesPerPixel))
        dataSet.setString(photometricInterpretation, for: .photometricInterpretation, vr: .CS)
        dataSet[.bitsAllocated] = DataElement.uint16(tag: .bitsAllocated, value: UInt16(bitsAllocated))
        dataSet[.bitsStored] = DataElement.uint16(tag: .bitsStored, value: UInt16(bitsStored))
        dataSet[.highBit] = DataElement.uint16(tag: .highBit, value: UInt16(highBit))
        dataSet[.pixelRepresentation] = DataElement.uint16(tag: .pixelRepresentation, value: UInt16(pixelRepresentation))

        if let planarConfiguration = planarConfiguration {
            dataSet[.planarConfiguration] = DataElement.uint16(tag: .planarConfiguration, value: UInt16(planarConfiguration))
        }

        // Cine Module
        if let frameTime = frameTime {
            dataSet.setString(String(frameTime), for: .frameTime, vr: .DS)
        }
        if let cineRate = cineRate {
            dataSet.setString(String(cineRate), for: .cineRate, vr: .IS)
        }
        if let recommendedDisplayFrameRate = recommendedDisplayFrameRate {
            dataSet.setString(String(recommendedDisplayFrameRate), for: .recommendedDisplayFrameRate, vr: .IS)
        }
        if let frameDelay = frameDelay {
            dataSet.setString(String(frameDelay), for: .frameDelay, vr: .DS)
        }
        if let actualFrameDuration = actualFrameDuration {
            dataSet.setString(String(actualFrameDuration), for: .actualFrameDuration, vr: .IS)
        }
        if let startTrim = startTrim {
            dataSet.setString(String(startTrim), for: .startTrim, vr: .IS)
        }
        if let stopTrim = stopTrim {
            dataSet.setString(String(stopTrim), for: .stopTrim, vr: .IS)
        }

        // Content Date/Time
        if let contentDate = contentDate {
            dataSet.setString(contentDate.dicomString, for: .contentDate, vr: .DA)
        }
        if let contentTime = contentTime {
            dataSet.setString(contentTime.dicomString, for: .contentTime, vr: .TM)
        }

        // Compression Information
        if let lossyImageCompression = lossyImageCompression {
            dataSet.setString(lossyImageCompression, for: .lossyImageCompression, vr: .CS)
        }
        if let lossyImageCompressionRatio = lossyImageCompressionRatio {
            dataSet.setString(String(lossyImageCompressionRatio), for: .lossyImageCompressionRatio, vr: .DS)
        }
        if let lossyImageCompressionMethod = lossyImageCompressionMethod {
            dataSet.setString(lossyImageCompressionMethod, for: .lossyImageCompressionMethod, vr: .CS)
        }

        // Pixel Data
        if let pixelData = pixelData {
            dataSet[.pixelData] = DataElement.data(
                tag: .pixelData,
                vr: .OB,
                data: pixelData
            )
        }

        return dataSet
    }
}
