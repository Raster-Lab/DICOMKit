//
// SecondaryCaptureBuilder.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Builder for creating DICOM Secondary Capture Image objects
///
/// SecondaryCaptureBuilder provides a fluent API for constructing Secondary Capture IODs,
/// enabling captured images to be wrapped as DICOM objects for storage and transmission.
///
/// Example - Creating a single-frame grayscale Secondary Capture:
/// ```swift
/// let imageData = Data(repeating: 128, count: 512 * 512)
/// let sc = try SecondaryCaptureBuilder(
///     secondaryCaptureType: .singleFrame,
///     rows: 512,
///     columns: 512,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setConversionType(.workstation)
/// .setPatientName("Smith^John")
/// .setPatientID("12345")
/// .setPixelData(imageData)
/// .build()
/// ```
///
/// Example - Creating a multi-frame true color Secondary Capture:
/// ```swift
/// let colorData = Data(repeating: 0, count: 256 * 256 * 3 * 10)
/// let sc = try SecondaryCaptureBuilder(
///     secondaryCaptureType: .multiframeTrueColor,
///     rows: 256,
///     columns: 256,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setNumberOfFrames(10)
/// .setConversionType(.digitizedVideo)
/// .setPixelData(colorData)
/// .build()
/// ```
///
/// Reference: PS3.3 A.8 - Secondary Capture Image IOD
/// Reference: PS3.3 A.8.1 - Multi-frame SC Image IODs
public final class SecondaryCaptureBuilder {

    // MARK: - Required Configuration

    private let secondaryCaptureType: SecondaryCaptureType
    private let rows: Int
    private let columns: Int
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
    private var conversionType: ConversionType = .digitizedFilm
    private var dateOfSecondaryCapture: DICOMDate?
    private var timeOfSecondaryCapture: DICOMTime?
    private var numberOfFrames: Int = 1
    private var samplesPerPixel: Int?
    private var photometricInterpretation: String?
    private var bitsAllocated: Int?
    private var bitsStored: Int?
    private var highBit: Int?
    private var pixelRepresentation: Int = 0
    private var planarConfiguration: Int?
    private var imageType: [String]?
    private var derivationDescription: String?
    private var burnedInAnnotation: String?
    private var contentDate: DICOMDate?
    private var contentTime: DICOMTime?
    private var pixelData: Data?

    // MARK: - Initialization

    /// Creates a new SecondaryCaptureBuilder
    ///
    /// - Parameters:
    ///   - secondaryCaptureType: The type of Secondary Capture image
    ///   - rows: Number of rows (height) in pixels
    ///   - columns: Number of columns (width) in pixels
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    public init(
        secondaryCaptureType: SecondaryCaptureType,
        rows: Int,
        columns: Int,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.secondaryCaptureType = secondaryCaptureType
        self.rows = rows
        self.columns = columns
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

    /// Sets the Modality (defaults to "OT" if not set)
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

    /// Sets the Conversion Type describing how the image was captured
    @discardableResult
    public func setConversionType(_ type: ConversionType) -> Self {
        self.conversionType = type
        return self
    }

    /// Sets the date and time of secondary capture
    @discardableResult
    public func setCaptureDateTime(date: DICOMDate, time: DICOMTime) -> Self {
        self.dateOfSecondaryCapture = date
        self.timeOfSecondaryCapture = time
        return self
    }

    /// Sets the Date of Secondary Capture
    @discardableResult
    public func setDateOfSecondaryCapture(_ date: DICOMDate) -> Self {
        self.dateOfSecondaryCapture = date
        return self
    }

    /// Sets the Time of Secondary Capture
    @discardableResult
    public func setTimeOfSecondaryCapture(_ time: DICOMTime) -> Self {
        self.timeOfSecondaryCapture = time
        return self
    }

    /// Sets the Number of Frames (for multi-frame types)
    @discardableResult
    public func setNumberOfFrames(_ count: Int) -> Self {
        self.numberOfFrames = count
        return self
    }

    /// Sets the Samples Per Pixel (overrides type default)
    @discardableResult
    public func setSamplesPerPixel(_ value: Int) -> Self {
        self.samplesPerPixel = value
        return self
    }

    /// Sets the Photometric Interpretation (overrides type default)
    @discardableResult
    public func setPhotometricInterpretation(_ value: String) -> Self {
        self.photometricInterpretation = value
        return self
    }

    /// Sets the bit depth parameters (overrides type defaults)
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

    /// Sets the Image Type values
    @discardableResult
    public func setImageType(_ values: [String]) -> Self {
        self.imageType = values
        return self
    }

    /// Sets the Derivation Description
    @discardableResult
    public func setDerivationDescription(_ description: String) -> Self {
        self.derivationDescription = description
        return self
    }

    /// Sets the Burned In Annotation flag
    @discardableResult
    public func setBurnedInAnnotation(_ value: String) -> Self {
        self.burnedInAnnotation = value
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

    /// Sets the pixel data
    @discardableResult
    public func setPixelData(_ data: Data) -> Self {
        self.pixelData = data
        return self
    }

    // MARK: - Build

    /// Builds the SecondaryCaptureImage object
    ///
    /// - Returns: The constructed SecondaryCaptureImage
    /// - Throws: DICOMError if required data is invalid
    public func build() throws -> SecondaryCaptureImage {
        guard rows > 0 else {
            throw DICOMError.parsingFailed("Rows must be greater than 0")
        }

        guard columns > 0 else {
            throw DICOMError.parsingFailed("Columns must be greater than 0")
        }

        guard secondaryCaptureType != .unknown else {
            throw DICOMError.parsingFailed("Secondary Capture type cannot be unknown")
        }

        // For multi-frame types, validate frame count
        if secondaryCaptureType != .singleFrame && numberOfFrames < 1 {
            throw DICOMError.parsingFailed("Number of frames must be at least 1 for multi-frame types")
        }

        let defaults = secondaryCaptureType.defaultPixelCharacteristics
        let effectiveSamplesPerPixel = samplesPerPixel ?? defaults.samplesPerPixel
        let effectiveBitsAllocated = bitsAllocated ?? defaults.bitsAllocated
        let effectiveBitsStored = bitsStored ?? defaults.bitsStored
        let effectiveHighBit = highBit ?? defaults.highBit
        let effectivePhotometric = photometricInterpretation ?? defaults.photometricInterpretation

        let instanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().value
        let effectiveModality = modality ?? secondaryCaptureType.defaultModality

        // Default image type for SC
        let effectiveImageType = imageType ?? ["DERIVED", "SECONDARY"]

        return SecondaryCaptureImage(
            sopInstanceUID: instanceUID,
            sopClassUID: secondaryCaptureType.sopClassUID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            patientName: patientName,
            patientID: patientID,
            modality: effectiveModality,
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            conversionType: conversionType,
            dateOfSecondaryCapture: dateOfSecondaryCapture,
            timeOfSecondaryCapture: timeOfSecondaryCapture,
            rows: rows,
            columns: columns,
            numberOfFrames: numberOfFrames,
            samplesPerPixel: effectiveSamplesPerPixel,
            photometricInterpretation: effectivePhotometric,
            bitsAllocated: effectiveBitsAllocated,
            bitsStored: effectiveBitsStored,
            highBit: effectiveHighBit,
            pixelRepresentation: pixelRepresentation,
            planarConfiguration: planarConfiguration,
            imageType: effectiveImageType,
            derivationDescription: derivationDescription,
            burnedInAnnotation: burnedInAnnotation,
            contentDate: contentDate,
            contentTime: contentTime,
            pixelData: pixelData
        )
    }

    /// Builds the SecondaryCaptureImage and converts it to a DICOM DataSet
    ///
    /// - Returns: A DataSet ready for DICOM file creation
    /// - Throws: DICOMError if building fails
    public func buildDataSet() throws -> DataSet {
        let sc = try build()
        return sc.toDataSet()
    }
}

// MARK: - DataSet Conversion

extension SecondaryCaptureImage {

    /// Converts the SecondaryCaptureImage to a DICOM DataSet
    ///
    /// Creates a DataSet with all required and optional attributes for the SC IOD.
    ///
    /// - Returns: A DataSet representation of this Secondary Capture image
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

        // SC Equipment Module
        dataSet.setString(conversionType.rawValue, for: .conversionType, vr: .CS)

        // SC Image Module
        if let dateOfSecondaryCapture = dateOfSecondaryCapture {
            dataSet.setString(dateOfSecondaryCapture.dicomString, for: .dateOfSecondaryCapture, vr: .DA)
        }
        if let timeOfSecondaryCapture = timeOfSecondaryCapture {
            dataSet.setString(timeOfSecondaryCapture.dicomString, for: .timeOfSecondaryCapture, vr: .TM)
        }

        // General Image Module
        if let imageType = imageType, !imageType.isEmpty {
            dataSet.setString(imageType.joined(separator: "\\"), for: .imageType, vr: .CS)
        }
        if let derivationDescription = derivationDescription {
            dataSet.setString(derivationDescription, for: .derivationDescription, vr: .ST)
        }
        if let burnedInAnnotation = burnedInAnnotation {
            dataSet.setString(burnedInAnnotation, for: .burnedInAnnotation, vr: .CS)
        }

        // Image Pixel Module
        dataSet[.rows] = DataElement.uint16(tag: .rows, value: UInt16(rows))
        dataSet[.columns] = DataElement.uint16(tag: .columns, value: UInt16(columns))
        dataSet[.samplesPerPixel] = DataElement.uint16(tag: .samplesPerPixel, value: UInt16(samplesPerPixel))
        dataSet.setString(photometricInterpretation, for: .photometricInterpretation, vr: .CS)
        dataSet[.bitsAllocated] = DataElement.uint16(tag: .bitsAllocated, value: UInt16(bitsAllocated))
        dataSet[.bitsStored] = DataElement.uint16(tag: .bitsStored, value: UInt16(bitsStored))
        dataSet[.highBit] = DataElement.uint16(tag: .highBit, value: UInt16(highBit))
        dataSet[.pixelRepresentation] = DataElement.uint16(tag: .pixelRepresentation, value: UInt16(pixelRepresentation))

        if let planarConfiguration = planarConfiguration {
            dataSet[.planarConfiguration] = DataElement.uint16(tag: .planarConfiguration, value: UInt16(planarConfiguration))
        }

        // Number of Frames (for multi-frame)
        if numberOfFrames > 1 || secondaryCaptureType != .singleFrame {
            dataSet.setString(String(numberOfFrames), for: .numberOfFrames, vr: .IS)
        }

        // Content Date/Time
        if let contentDate = contentDate {
            dataSet.setString(contentDate.dicomString, for: .contentDate, vr: .DA)
        }
        if let contentTime = contentTime {
            dataSet.setString(contentTime.dicomString, for: .contentTime, vr: .TM)
        }

        // Pixel Data
        if let pixelData = pixelData {
            dataSet[.pixelData] = DataElement.data(
                tag: .pixelData,
                vr: .OW,
                data: pixelData
            )
        }

        return dataSet
    }
}
