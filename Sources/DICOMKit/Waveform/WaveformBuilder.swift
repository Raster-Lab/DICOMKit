//
// WaveformBuilder.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Builder for creating DICOM Waveform objects
///
/// WaveformBuilder provides a fluent API for constructing Waveform IODs,
/// enabling ECG, hemodynamic, audio, and other physiological signal data
/// to be wrapped as DICOM objects for storage and transmission.
///
/// Example - Creating a simple ECG waveform:
/// ```swift
/// let waveform = try WaveformBuilder(
///     waveformType: .twelveLeadECG,
///     studyInstanceUID: "1.2.3.4.5",
///     seriesInstanceUID: "1.2.3.4.5.6"
/// )
/// .setPatientName("Smith^John")
/// .setPatientID("12345")
/// .addMultiplexGroup(
///     samplingFrequency: 500.0,
///     bitsAllocated: 16,
///     sampleInterpretation: .signedInteger,
///     channels: [
///         WaveformChannel(channelLabel: "Lead I",
///                        channelSource: WaveformCodedConcept(
///                            codeValue: "5.6.3-9-1",
///                            codingSchemeDesignator: "SCPECG",
///                            codeMeaning: "Lead I"))
///     ],
///     waveformData: ecgData
/// )
/// .build()
/// ```
///
/// Reference: PS3.3 A.34 - Waveform IODs
/// Reference: PS3.3 C.10.9 - Waveform Module
public final class WaveformBuilder {

    // MARK: - Required Configuration

    private let waveformType: WaveformType
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
    private var contentDate: DICOMDate?
    private var contentTime: DICOMTime?
    private var multiplexGroups: [WaveformMultiplexGroup] = []
    private var annotations: [WaveformAnnotation] = []

    // MARK: - Initialization

    /// Creates a new WaveformBuilder
    ///
    /// - Parameters:
    ///   - waveformType: The type of waveform to create
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    public init(
        waveformType: WaveformType,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.waveformType = waveformType
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

    /// Sets the Modality
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

    /// Adds a multiplex group with channel data
    ///
    /// - Parameters:
    ///   - samplingFrequency: Sampling frequency in Hz
    ///   - bitsAllocated: Bits allocated per sample (8 or 16)
    ///   - sampleInterpretation: How samples should be interpreted
    ///   - channels: Channel definitions
    ///   - waveformData: Raw interleaved waveform data
    ///   - originality: Whether the data is original or derived
    ///   - label: Label for the multiplex group
    /// - Returns: Self for method chaining
    @discardableResult
    public func addMultiplexGroup(
        samplingFrequency: Double,
        bitsAllocated: UInt16 = 16,
        sampleInterpretation: WaveformSampleInterpretation = .signedInteger,
        channels: [WaveformChannel],
        waveformData: Data,
        originality: WaveformOriginality? = .original,
        label: String? = nil
    ) -> Self {
        let bytesPerSample = Int(bitsAllocated) / 8
        let channelCount = channels.count
        let numberOfSamples: Int
        if channelCount > 0 && bytesPerSample > 0 {
            numberOfSamples = waveformData.count / (channelCount * bytesPerSample)
        } else {
            numberOfSamples = 0
        }

        let group = WaveformMultiplexGroup(
            samplingFrequency: samplingFrequency,
            numberOfSamples: numberOfSamples,
            waveformBitsAllocated: bitsAllocated,
            waveformBitsStored: bitsAllocated,
            waveformSampleInterpretation: sampleInterpretation,
            channels: channels,
            waveformData: waveformData,
            originality: originality,
            multiplexGroupLabel: label
        )
        self.multiplexGroups.append(group)
        return self
    }

    /// Adds a pre-configured multiplex group
    @discardableResult
    public func addMultiplexGroup(_ group: WaveformMultiplexGroup) -> Self {
        self.multiplexGroups.append(group)
        return self
    }

    /// Adds a waveform annotation
    @discardableResult
    public func addAnnotation(_ annotation: WaveformAnnotation) -> Self {
        self.annotations.append(annotation)
        return self
    }

    /// Adds a text annotation
    @discardableResult
    public func addTextAnnotation(
        text: String,
        groupNumber: UInt16? = nil,
        temporalRange: TemporalRangeType? = nil,
        samplePositions: [UInt32]? = nil
    ) -> Self {
        let annotation = WaveformAnnotation(
            textValue: text,
            annotationGroupNumber: groupNumber,
            temporalRangeType: temporalRange,
            referencedSamplePositions: samplePositions
        )
        self.annotations.append(annotation)
        return self
    }

    /// Adds a measurement annotation
    @discardableResult
    public func addMeasurementAnnotation(
        conceptCode: WaveformCodedConcept,
        value: Double,
        units: WaveformCodedConcept,
        groupNumber: UInt16? = nil,
        temporalRange: TemporalRangeType? = nil,
        samplePositions: [UInt32]? = nil
    ) -> Self {
        let annotation = WaveformAnnotation(
            conceptNameCode: conceptCode,
            numericValue: value,
            measurementUnits: units,
            annotationGroupNumber: groupNumber,
            temporalRangeType: temporalRange,
            referencedSamplePositions: samplePositions
        )
        self.annotations.append(annotation)
        return self
    }

    // MARK: - Build

    /// Builds the Waveform
    ///
    /// - Returns: The constructed Waveform
    /// - Throws: DICOMError if required data is invalid
    public func build() throws -> Waveform {
        guard !multiplexGroups.isEmpty else {
            throw DICOMError.parsingFailed("At least one multiplex group is required")
        }

        let instanceUID = sopInstanceUID ?? UIDGenerator.generateSOPInstanceUID().value

        return Waveform(
            sopInstanceUID: instanceUID,
            sopClassUID: waveformType.sopClassUID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            instanceNumber: instanceNumber,
            patientName: patientName,
            patientID: patientID,
            modality: modality ?? defaultModality(),
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            contentDate: contentDate,
            contentTime: contentTime,
            multiplexGroups: multiplexGroups,
            annotations: annotations
        )
    }

    /// Builds the Waveform and converts it to a DICOM DataSet
    ///
    /// - Returns: A DataSet ready for DICOM file creation
    /// - Throws: DICOMError if building fails
    public func buildDataSet() throws -> DataSet {
        let waveform = try build()
        return waveform.toDataSet()
    }

    /// Returns the default modality for the waveform type
    private func defaultModality() -> String {
        switch waveformType {
        case .twelveLeadECG, .generalECG, .ambulatoryECG:
            return "ECG"
        case .hemodynamic:
            return "HD"
        case .cardiacElectrophysiology:
            return "EPS"
        case .basicVoiceAudio, .generalAudio:
            return "AU"
        case .arterialPulse:
            return "HD"
        case .respiratoryWaveform:
            return "RESP"
        case .unknown:
            return "OT"
        }
    }
}

// MARK: - DataSet Conversion

extension Waveform {

    /// Converts the Waveform to a DICOM DataSet
    ///
    /// Creates a DataSet with all required and optional attributes for the
    /// Waveform IOD.
    ///
    /// - Returns: A DataSet representation of this waveform
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

        // Content Date/Time
        if let contentDate = contentDate {
            dataSet.setString(contentDate.dicomString, for: .contentDate, vr: .DA)
        }
        if let contentTime = contentTime {
            dataSet.setString(contentTime.dicomString, for: .contentTime, vr: .TM)
        }

        // Waveform Sequence
        if !multiplexGroups.isEmpty {
            let waveformItems = multiplexGroups.map { group -> SequenceItem in
                serializeMultiplexGroup(group)
            }
            dataSet.setSequence(waveformItems, for: .waveformSequence)
        }

        // Waveform Annotation Sequence
        if !annotations.isEmpty {
            let annotationItems = annotations.map { annotation -> SequenceItem in
                serializeAnnotation(annotation)
            }
            dataSet.setSequence(annotationItems, for: .waveformAnnotationSequence)
        }

        return dataSet
    }

    /// Serializes a multiplex group to a SequenceItem
    private func serializeMultiplexGroup(_ group: WaveformMultiplexGroup) -> SequenceItem {
        var elements: [DataElement] = []

        // Sampling Frequency
        elements.append(DataElement.string(
            tag: .samplingFrequency,
            vr: .DS,
            value: String(group.samplingFrequency)
        ))

        // Number of Waveform Channels
        elements.append(DataElement.uint16(
            tag: .numberOfWaveformChannels,
            value: UInt16(group.channels.count)
        ))

        // Number of Waveform Samples
        elements.append(DataElement.string(
            tag: .numberOfWaveformSamples,
            vr: .UL,
            value: String(group.numberOfSamples)
        ))

        // Waveform Bits Allocated (5400,1004)
        elements.append(DataElement.uint16(
            tag: .waveformBitsAllocated,
            value: group.waveformBitsAllocated
        ))

        // Waveform Sample Interpretation (5400,1006)
        elements.append(DataElement.string(
            tag: .waveformSampleInterpretation,
            vr: .CS,
            value: group.waveformSampleInterpretation.rawValue
        ))

        // Waveform Originality
        if let originality = group.originality {
            elements.append(DataElement.string(
                tag: .waveformOriginality,
                vr: .CS,
                value: originality.rawValue
            ))
        }

        // Multiplex Group Label
        if let label = group.multiplexGroupLabel {
            elements.append(DataElement.string(
                tag: .multiplexGroupLabel,
                vr: .SH,
                value: label
            ))
        }

        // Multiplex Group Time Offset
        if let offset = group.multiplexGroupTimeOffset {
            elements.append(DataElement.string(
                tag: .multiplexGroupTimeOffset,
                vr: .DS,
                value: String(offset)
            ))
        }

        // Trigger Time Offset
        if let offset = group.triggerTimeOffset {
            elements.append(DataElement.string(
                tag: .triggerTimeOffset,
                vr: .DS,
                value: String(offset)
            ))
        }

        // Channel Definition Sequence
        if !group.channels.isEmpty {
            let channelItems = group.channels.map { channel -> SequenceItem in
                serializeChannel(channel)
            }
            // Serialize channel sequence
            let writer = DICOMWriter()
            var channelData = Data()
            for channelItem in channelItems {
                channelData.append(writer.serializeSequenceItem(channelItem))
            }
            elements.append(DataElement(
                tag: .channelDefinitionSequence,
                vr: .SQ,
                length: UInt32(channelData.count),
                valueData: channelData,
                sequenceItems: channelItems
            ))
        }

        // Waveform Data
        if !group.waveformData.isEmpty {
            elements.append(DataElement.data(
                tag: .waveformData,
                vr: .OW,
                data: group.waveformData
            ))
        }

        return SequenceItem(elements: elements)
    }

    /// Serializes a channel definition to a SequenceItem
    private func serializeChannel(_ channel: WaveformChannel) -> SequenceItem {
        var elements: [DataElement] = []

        if let label = channel.channelLabel {
            elements.append(DataElement.string(tag: .channelLabel, vr: .SH, value: label))
        }

        if let status = channel.channelStatus {
            elements.append(DataElement.string(tag: .channelStatus, vr: .CS, value: status.joined(separator: "\\")))
        }

        if let source = channel.channelSource {
            let sourceItem = createCodeSequenceItem(source)
            let writer = DICOMWriter()
            let itemData = writer.serializeSequenceItem(sourceItem)
            elements.append(DataElement(
                tag: .channelSourceSequence,
                vr: .SQ,
                length: UInt32(itemData.count),
                valueData: itemData,
                sequenceItems: [sourceItem]
            ))
        }

        if let modifiers = channel.channelSourceModifiers, !modifiers.isEmpty {
            let modifierItems = modifiers.map { createCodeSequenceItem($0) }
            let writer = DICOMWriter()
            var modData = Data()
            for modItem in modifierItems {
                modData.append(writer.serializeSequenceItem(modItem))
            }
            elements.append(DataElement(
                tag: .channelSourceModifiersSequence,
                vr: .SQ,
                length: UInt32(modData.count),
                valueData: modData,
                sequenceItems: modifierItems
            ))
        }

        if let sensitivity = channel.channelSensitivity {
            elements.append(DataElement.string(tag: .channelSensitivity, vr: .DS, value: String(sensitivity)))
        }

        if let units = channel.channelSensitivityUnits {
            let unitsItem = createCodeSequenceItem(units)
            let writer = DICOMWriter()
            let itemData = writer.serializeSequenceItem(unitsItem)
            elements.append(DataElement(
                tag: .channelSensitivityUnitsSequence,
                vr: .SQ,
                length: UInt32(itemData.count),
                valueData: itemData,
                sequenceItems: [unitsItem]
            ))
        }

        if let factor = channel.channelSensitivityCorrectionFactor {
            elements.append(DataElement.string(tag: .channelSensitivityCorrectionFactor, vr: .DS, value: String(factor)))
        }

        if let baseline = channel.channelBaseline {
            elements.append(DataElement.string(tag: .channelBaseline, vr: .DS, value: String(baseline)))
        }

        if let skew = channel.channelTimeSkew {
            elements.append(DataElement.string(tag: .channelTimeSkew, vr: .DS, value: String(skew)))
        }

        if let skew = channel.channelSampleSkew {
            elements.append(DataElement.string(tag: .channelSampleSkew, vr: .DS, value: String(skew)))
        }

        if let offset = channel.channelOffset {
            elements.append(DataElement.string(tag: .channelOffset, vr: .DS, value: String(offset)))
        }

        if let freq = channel.filterLowFrequency {
            elements.append(DataElement.string(tag: .filterLowFrequency, vr: .DS, value: String(freq)))
        }

        if let freq = channel.filterHighFrequency {
            elements.append(DataElement.string(tag: .filterHighFrequency, vr: .DS, value: String(freq)))
        }

        if let freq = channel.notchFilterFrequency {
            elements.append(DataElement.string(tag: .notchFilterFrequency, vr: .DS, value: String(freq)))
        }

        if let bandwidth = channel.notchFilterBandwidth {
            elements.append(DataElement.string(tag: .notchFilterBandwidth, vr: .DS, value: String(bandwidth)))
        }

        return SequenceItem(elements: elements)
    }

    /// Serializes an annotation to a SequenceItem
    private func serializeAnnotation(_ annotation: WaveformAnnotation) -> SequenceItem {
        var elements: [DataElement] = []

        if let text = annotation.textValue {
            elements.append(DataElement.string(tag: .unformattedTextValue, vr: .UT, value: text))
        }

        if let concept = annotation.conceptNameCode {
            let conceptItem = createCodeSequenceItem(concept)
            let writer = DICOMWriter()
            let itemData = writer.serializeSequenceItem(conceptItem)
            elements.append(DataElement(
                tag: .conceptNameCodeSequence,
                vr: .SQ,
                length: UInt32(itemData.count),
                valueData: itemData,
                sequenceItems: [conceptItem]
            ))
        }

        if let value = annotation.numericValue {
            elements.append(DataElement.string(tag: .numericValue, vr: .DS, value: String(value)))
        }

        if let units = annotation.measurementUnits {
            let unitsItem = createCodeSequenceItem(units)
            let writer = DICOMWriter()
            let itemData = writer.serializeSequenceItem(unitsItem)
            elements.append(DataElement(
                tag: .measurementUnitsCodeSequence,
                vr: .SQ,
                length: UInt32(itemData.count),
                valueData: itemData,
                sequenceItems: [unitsItem]
            ))
        }

        if let groupNumber = annotation.annotationGroupNumber {
            elements.append(DataElement.uint16(tag: .annotationGroupNumber, value: groupNumber))
        }

        if let rangeType = annotation.temporalRangeType {
            elements.append(DataElement.string(tag: .temporalRangeType, vr: .CS, value: rangeType.rawValue))
        }

        if let positions = annotation.referencedSamplePositions, !positions.isEmpty {
            // Serialize as UL (unsigned long) values
            var data = Data()
            for pos in positions {
                var value = pos.littleEndian
                data.append(Data(bytes: &value, count: MemoryLayout<UInt32>.size))
            }
            elements.append(DataElement.data(tag: .referencedSamplePositions, vr: .UL, data: data))
        }

        if let offsets = annotation.referencedTimeOffsets, !offsets.isEmpty {
            let offsetStr = offsets.map { String($0) }.joined(separator: "\\")
            elements.append(DataElement.string(tag: .referencedTimeOffsets, vr: .DS, value: offsetStr))
        }

        return SequenceItem(elements: elements)
    }

    /// Creates a SequenceItem for a coded concept
    private func createCodeSequenceItem(_ code: WaveformCodedConcept) -> SequenceItem {
        var elements: [DataElement] = []
        elements.append(DataElement.string(tag: .codeValue, vr: .SH, value: code.codeValue))
        elements.append(DataElement.string(tag: .codingSchemeDesignator, vr: .SH, value: code.codingSchemeDesignator))
        elements.append(DataElement.string(tag: .codeMeaning, vr: .LO, value: code.codeMeaning))
        return SequenceItem(elements: elements)
    }
}
