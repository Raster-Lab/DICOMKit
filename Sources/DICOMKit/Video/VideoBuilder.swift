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
    private var photometricInterpretation: String = Video.defaultPhotometricInterpretation
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
    private var imageType: [String] = Video.defaultImageType
    private var manufacturer: String?
    private var manufacturerModelName: String?
    private var deviceSerialNumber: String?
    private var softwareVersions: String?
    private var institutionName: String?
    private var acquisitionDate: DICOMDate?
    private var acquisitionTime: DICOMTime?
    private var patientOrientation: String?
    private var studyDate: DICOMDate?
    private var studyTime: DICOMTime?
    private var referringPhysicianName: String?
    private var studyID: String?
    private var accessionNumber: String?
    private var patientBirthDate: DICOMDate?
    private var patientSex: String?
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

    /// Sets the Photometric Interpretation
    ///
    /// Defaults to `YBR_PARTIAL_420`, which PS3.5 8.2.7 / 8.2.10 / 8.2.11 require of
    /// every DICOM video transfer syntax. Override only for a stream whose chroma
    /// format genuinely differs — and note that such a stream is not conformant.
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

    /// Sets the bit depth from a coded luma bit depth.
    ///
    /// Prefer this over ``setBitDepth(allocated:stored:highBit:)``: DICOM allocates
    /// on byte boundaries, so a 10-bit HEVC Main 10 stream is Bits Allocated **16**,
    /// Bits Stored 10, High Bit 9 — a triple that is easy to get wrong by hand.
    ///
    /// - Parameter lumaBitDepth: The coded luma bit depth (8 or 10)
    /// - Returns: self, or self unchanged if the depth is not representable
    ///
    /// Reference: PS3.5 Sections 8.2.7, 8.2.10, 8.2.11
    @discardableResult
    public func setBitDepthForLumaBitDepth(_ lumaBitDepth: Int) -> Self {
        guard let depth = VideoBitDepth.forLumaBitDepth(lumaBitDepth) else {
            return self
        }
        return setBitDepth(depth)
    }

    /// Sets the bit depth from a ``VideoBitDepth``.
    @discardableResult
    public func setBitDepth(_ depth: VideoBitDepth) -> Self {
        self.bitsAllocated = depth.bitsAllocated
        self.bitsStored = depth.bitsStored
        self.highBit = depth.highBit
        return self
    }

    /// Sets the Image Type (0008,0008), Type 1 in the VL Image Module.
    @discardableResult
    public func setImageType(_ value: [String]) -> Self {
        self.imageType = value
        return self
    }

    /// Sets the Manufacturer (0008,0070), Type 2 in the General Equipment Module.
    @discardableResult
    public func setManufacturer(_ value: String) -> Self {
        self.manufacturer = value
        return self
    }

    /// Sets the Manufacturer's Model Name (0008,1090).
    @discardableResult
    public func setManufacturerModelName(_ value: String) -> Self {
        self.manufacturerModelName = value
        return self
    }

    /// Sets the Device Serial Number (0018,1000).
    @discardableResult
    public func setDeviceSerialNumber(_ value: String) -> Self {
        self.deviceSerialNumber = value
        return self
    }

    /// Sets the Software Versions (0018,1020).
    @discardableResult
    public func setSoftwareVersions(_ value: String) -> Self {
        self.softwareVersions = value
        return self
    }

    /// Sets the Institution Name (0008,0080).
    @discardableResult
    public func setInstitutionName(_ value: String) -> Self {
        self.institutionName = value
        return self
    }

    /// Sets the Acquisition Date (0008,0022) and Time (0008,0032).
    @discardableResult
    public func setAcquisitionDateTime(date: DICOMDate, time: DICOMTime) -> Self {
        self.acquisitionDate = date
        self.acquisitionTime = time
        return self
    }

    /// Sets the Patient Orientation (0020,0020), Type 2C in the General Image Module.
    @discardableResult
    public func setPatientOrientation(_ value: String) -> Self {
        self.patientOrientation = value
        return self
    }

    /// Sets the Study Date (0008,0020) and Time (0008,0030).
    @discardableResult
    public func setStudyDateTime(date: DICOMDate, time: DICOMTime) -> Self {
        self.studyDate = date
        self.studyTime = time
        return self
    }

    /// Sets the Referring Physician's Name (0008,0090), Type 2.
    @discardableResult
    public func setReferringPhysicianName(_ value: String) -> Self {
        self.referringPhysicianName = value
        return self
    }

    /// Sets the Study ID (0020,0010), Type 2.
    @discardableResult
    public func setStudyID(_ value: String) -> Self {
        self.studyID = value
        return self
    }

    /// Sets the Accession Number (0008,0050), Type 2.
    @discardableResult
    public func setAccessionNumber(_ value: String) -> Self {
        self.accessionNumber = value
        return self
    }

    /// Sets the Patient's Birth Date (0010,0030), Type 2.
    @discardableResult
    public func setPatientBirthDate(_ value: DICOMDate) -> Self {
        self.patientBirthDate = value
        return self
    }

    /// Sets the Patient's Sex (0010,0040), Type 2.
    @discardableResult
    public func setPatientSex(_ value: String) -> Self {
        self.patientSex = value
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
            imageType: imageType,
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
    /// Emits every module the Video IODs mark mandatory in PS3.3 A.32.5.3 /
    /// A.32.6.3 / A.32.7.3: Patient, General Study, General Series, General
    /// Equipment, General Acquisition, General Image, Cine, Multi-frame,
    /// Image Pixel, Acquisition Context, VL Image and SOP Common.
    ///
    /// Type 2 attributes are always emitted, zero-length when the value is unknown.
    /// Pixel Data is written as **encapsulated** fragments, because every video
    /// transfer syntax is an encapsulated one (PS3.5 A.4).
    ///
    /// - Returns: A DataSet representation of this video
    public func toDataSet() -> DataSet {
        var dataSet = DataSet()

        // MARK: SOP Common Module (PS3.3 C.12.1)
        dataSet.setString(sopClassUID, for: .sopClassUID, vr: .UI)
        dataSet.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)

        // MARK: Patient Module (PS3.3 C.7.1.1)
        // PatientName and PatientID are Type 2 - always present, possibly empty.
        dataSet.setString(patientName ?? "", for: .patientName, vr: .PN)
        dataSet.setString(patientID ?? "", for: .patientID, vr: .LO)
        dataSet.setString(patientBirthDate?.dicomString ?? "", for: .patientBirthDate, vr: .DA)
        dataSet.setString(patientSex ?? "", for: .patientSex, vr: .CS)

        // MARK: General Study Module (PS3.3 C.7.2.1)
        dataSet.setString(studyInstanceUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(studyDate?.dicomString ?? "", for: .studyDate, vr: .DA)
        dataSet.setString(studyTime?.dicomString ?? "", for: .studyTime, vr: .TM)
        dataSet.setString(referringPhysicianName ?? "", for: .referringPhysicianName, vr: .PN)
        dataSet.setString(studyID ?? "", for: .studyID, vr: .SH)
        dataSet.setString(accessionNumber ?? "", for: .accessionNumber, vr: .SH)

        // MARK: General Series Module (PS3.3 C.7.3.1)
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        // Modality is Type 1 in General Series.
        dataSet.setString(modality ?? videoType.defaultModality, for: .modality, vr: .CS)
        // SeriesNumber is Type 2.
        dataSet.setString(seriesNumber.map(String.init) ?? "", for: .seriesNumber, vr: .IS)
        if let seriesDescription = seriesDescription {
            dataSet.setString(seriesDescription, for: .seriesDescription, vr: .LO)
        }

        // MARK: General Equipment Module (PS3.3 C.7.5.1)
        // Manufacturer is Type 2.
        dataSet.setString(manufacturer ?? "", for: .manufacturer, vr: .LO)
        if let institutionName = institutionName {
            dataSet.setString(institutionName, for: .institutionName, vr: .LO)
        }
        if let manufacturerModelName = manufacturerModelName {
            dataSet.setString(manufacturerModelName, for: .manufacturerModelName, vr: .LO)
        }
        if let deviceSerialNumber = deviceSerialNumber {
            dataSet.setString(deviceSerialNumber, for: .deviceSerialNumber, vr: .LO)
        }
        if let softwareVersions = softwareVersions {
            dataSet.setString(softwareVersions, for: .softwareVersions, vr: .LO)
        }

        // MARK: General Acquisition Module (PS3.3 C.7.10.1)
        if let acquisitionDate = acquisitionDate {
            dataSet.setString(acquisitionDate.dicomString, for: .acquisitionDate, vr: .DA)
        }
        if let acquisitionTime = acquisitionTime {
            dataSet.setString(acquisitionTime.dicomString, for: .acquisitionTime, vr: .TM)
        }

        // MARK: General Image Module (PS3.3 C.7.6.1)
        // InstanceNumber is Type 2; PatientOrientation is Type 2C and is emitted
        // zero-length, which is how the standard expects an unknown orientation.
        dataSet.setString(instanceNumber.map(String.init) ?? "", for: .instanceNumber, vr: .IS)
        dataSet.setString(patientOrientation ?? "", for: .patientOrientation, vr: .CS)

        // Content Date/Time (Type 2C in General Image; always emitted here)
        if let contentDate = contentDate {
            dataSet.setString(contentDate.dicomString, for: .contentDate, vr: .DA)
        }
        if let contentTime = contentTime {
            dataSet.setString(contentTime.dicomString, for: .contentTime, vr: .TM)
        }

        // MARK: VL Image Module (PS3.3 C.8.12)
        // ImageType (0008,0008) is Type 1 - it must be present with a value.
        dataSet.setStrings(imageType, for: .imageType, vr: .CS)
        // LossyImageCompression (0028,2110) is Type 2. Video is always lossy.
        dataSet.setString(lossyImageCompression ?? "01", for: .lossyImageCompression, vr: .CS)
        if let lossyImageCompressionRatio = lossyImageCompressionRatio {
            dataSet.setString(
                Video.decimalString(lossyImageCompressionRatio),
                for: .lossyImageCompressionRatio,
                vr: .DS
            )
        }
        if let lossyImageCompressionMethod = lossyImageCompressionMethod {
            dataSet.setString(lossyImageCompressionMethod, for: .lossyImageCompressionMethod, vr: .CS)
        }

        // MARK: Acquisition Context Module (PS3.3 C.7.6.14)
        // AcquisitionContextSequence (0040,0555) is Type 2 and may hold zero items.
        dataSet[.acquisitionContextSequence] = DataElement(
            tag: .acquisitionContextSequence,
            vr: .SQ,
            length: 0,
            valueData: Data(),
            sequenceItems: []
        )

        // MARK: Image Pixel Module (PS3.3 C.7.6.3)
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: UInt16(rows))
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: UInt16(columns))
        dataSet[.samplesPerPixel] = DataElement.uint16(tag: .samplesPerPixel, value: UInt16(samplesPerPixel))
        dataSet.setString(photometricInterpretation, for: .photometricInterpretation, vr: .CS)
        dataSet[.bitsAllocated] = DataElement.uint16(tag: .bitsAllocated, value: UInt16(bitsAllocated))
        dataSet[.bitsStored] = DataElement.uint16(tag: .bitsStored, value: UInt16(bitsStored))
        dataSet[.highBit] = DataElement.uint16(tag: .highBit, value: UInt16(highBit))
        dataSet[.pixelRepresentation] = DataElement.uint16(tag: .pixelRepresentation, value: UInt16(pixelRepresentation))
        // PlanarConfiguration is required (and "shall be 0") whenever
        // SamplesPerPixel > 1; default it rather than leaving it absent.
        if samplesPerPixel > 1 {
            dataSet[.planarConfiguration] = DataElement.uint16(
                tag: .planarConfiguration,
                value: UInt16(planarConfiguration ?? 0)
            )
        }
        // PixelAspectRatio (0028,0034) shall be ABSENT: the video transfer syntaxes
        // fix the Sampling Aspect Ratio at 1:1 (PS3.5 8.2.7). Never emitted.

        // MARK: Multi-frame Module (PS3.3 C.7.6.6)
        // NumberOfFrames and FrameIncrementPointer are both Type 1.
        dataSet.setString(String(numberOfFrames), for: .numberOfFrames, vr: .IS)
        dataSet[.frameIncrementPointer] = DataElement.attributeTag(
            tag: .frameIncrementPointer,
            value: .frameTime
        )

        // MARK: Cine Module (PS3.3 C.7.6.5)
        // FrameTime is Type 1C and required here, because FrameIncrementPointer
        // points at it. The remaining Cine attributes are Type 3.
        let effectiveFrameTime = frameTime ?? (1000.0 / effectiveFrameRate)
        dataSet.setString(Video.decimalString(effectiveFrameTime), for: .frameTime, vr: .DS)
        if let cineRate = cineRate {
            dataSet.setString(String(cineRate), for: .cineRate, vr: .IS)
        }
        if let recommendedDisplayFrameRate = recommendedDisplayFrameRate {
            dataSet.setString(String(recommendedDisplayFrameRate), for: .recommendedDisplayFrameRate, vr: .IS)
        }
        if let frameDelay = frameDelay {
            dataSet.setString(Video.decimalString(frameDelay), for: .frameDelay, vr: .DS)
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

        // MARK: Pixel Data (PS3.5 A.4)
        // Every video transfer syntax is encapsulated, so Pixel Data must be
        // written as undefined-length fragments, never as a native OB value.
        // One fragment holds the whole bit stream: MPEG-family streams are
        // inter-coded, so frame boundaries are not independently decodable and
        // splitting them would produce an undecodable object. The Basic Offset
        // Table carries a single zero entry rather than fabricated per-frame
        // offsets. DICOMWriter pads an odd-length fragment; do not pad here.
        if let pixelData = pixelData {
            dataSet[.pixelData] = DataElement(
                tag: .pixelData,
                vr: .OB,
                length: 0xFFFFFFFF,
                valueData: Data(),
                encapsulatedFragments: [pixelData],
                encapsulatedOffsetTable: [0]
            )
        }

        return dataSet
    }

    /// Formats a Double for a DICOM Decimal String (DS) value.
    ///
    /// DS is limited to 16 bytes, so the value is rendered with the most precision
    /// that fits, and trailing zeros are trimmed to keep round-tripped values
    /// readable (e.g. `33.366667`, not `33.36666666666667`).
    ///
    /// Reference: PS3.5 Table 6.2-1 (DS Value Representation)
    static func decimalString(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        for precision in stride(from: 12, through: 1, by: -1) {
            let formatted = String(format: "%.\(precision)f", value)
            let trimmed = Video.trimTrailingZeros(formatted)
            if trimmed.utf8.count <= 16 {
                return trimmed
            }
        }
        return String(format: "%.6G", value)
    }

    private static func trimTrailingZeros(_ string: String) -> String {
        guard string.contains(".") else { return string }
        var result = string
        while result.hasSuffix("0") { result.removeLast() }
        if result.hasSuffix(".") { result.removeLast() }
        return result
    }
}
