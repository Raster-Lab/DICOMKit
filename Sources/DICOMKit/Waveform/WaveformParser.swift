//
// WaveformParser.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Parser for DICOM Waveform objects
///
/// Parses Waveform IODs from DICOM data sets, extracting multiplex groups,
/// channel definitions, waveform data, and annotations.
///
/// Reference: PS3.3 A.34 - Waveform IODs
/// Reference: PS3.3 C.10.9 - Waveform Module
/// Reference: PS3.3 C.10.10 - Waveform Annotation Module
public struct WaveformParser {

    /// Parse a Waveform from a DICOM data set
    ///
    /// - Parameter dataSet: DICOM data set containing a Waveform IOD
    /// - Returns: Parsed Waveform
    /// - Throws: DICOMError if parsing fails
    public static func parse(from dataSet: DataSet) throws -> Waveform {
        // Parse SOP Instance UID (required)
        guard let sopInstanceUID = dataSet.string(for: .sopInstanceUID) else {
            throw DICOMError.parsingFailed("Missing SOP Instance UID")
        }

        let sopClassUID = dataSet.string(for: .sopClassUID) ?? Waveform.generalECGStorageUID

        // Parse Study and Series UIDs (required)
        guard let studyInstanceUID = dataSet.string(for: .studyInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Study Instance UID")
        }

        guard let seriesInstanceUID = dataSet.string(for: .seriesInstanceUID) else {
            throw DICOMError.parsingFailed("Missing Series Instance UID")
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

        // Parse content date/time
        let contentDate = dataSet.date(for: .contentDate)
        let contentTime = dataSet.time(for: .contentTime)

        // Parse Waveform Sequence (required)
        let multiplexGroups = try parseWaveformSequence(from: dataSet)

        // Parse Waveform Annotation Sequence (optional)
        let annotations = parseAnnotations(from: dataSet)

        return Waveform(
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
            contentDate: contentDate,
            contentTime: contentTime,
            multiplexGroups: multiplexGroups,
            annotations: annotations
        )
    }

    // MARK: - Waveform Sequence Parsing

    /// Parse the Waveform Sequence into multiplex groups
    private static func parseWaveformSequence(from dataSet: DataSet) throws -> [WaveformMultiplexGroup] {
        guard let items = dataSet.sequence(for: .waveformSequence) else {
            return []
        }

        return try items.map { item in
            try parseMultiplexGroup(from: item)
        }
    }

    /// Parse a single multiplex group from a sequence item
    private static func parseMultiplexGroup(from item: SequenceItem) throws -> WaveformMultiplexGroup {
        // Sampling Frequency (required)
        guard let samplingFreqStr = item.elements[.samplingFrequency]?.stringValue,
              let samplingFrequency = Double(samplingFreqStr.trimmingCharacters(in: .whitespaces)) else {
            throw DICOMError.parsingFailed("Missing or invalid Sampling Frequency")
        }

        // Number of Waveform Channels (required)
        guard let numberOfChannels = item.elements[.numberOfWaveformChannels]?.uint16Value else {
            throw DICOMError.parsingFailed("Missing Number of Waveform Channels")
        }

        // Number of Waveform Samples (required)
        guard let numberOfSamplesStr = item.elements[.numberOfWaveformSamples]?.stringValue,
              let numberOfSamples = Int(numberOfSamplesStr.trimmingCharacters(in: .whitespaces)) else {
            // Try as UInt32
            if let sampleCount = item.elements[.numberOfWaveformSamples]?.uint16Value {
                let numberOfSamples = Int(sampleCount)
                // Continue with the rest of parsing below
                return try parseMultiplexGroupContinued(
                    item: item,
                    samplingFrequency: samplingFrequency,
                    numberOfChannels: numberOfChannels,
                    numberOfSamples: numberOfSamples
                )
            }
            throw DICOMError.parsingFailed("Missing Number of Waveform Samples")
        }

        return try parseMultiplexGroupContinued(
            item: item,
            samplingFrequency: samplingFrequency,
            numberOfChannels: numberOfChannels,
            numberOfSamples: numberOfSamples
        )
    }

    private static func parseMultiplexGroupContinued(
        item: SequenceItem,
        samplingFrequency: Double,
        numberOfChannels: UInt16,
        numberOfSamples: Int
    ) throws -> WaveformMultiplexGroup {
        // Waveform Sample Interpretation (required)
        let sampleInterpretation: WaveformSampleInterpretation
        if let interpStr = item.elements[Tag(group: 0x5400, element: 0x1006)]?.stringValue {
            // Check if it's actually stored in waveformBitsStored tag (common)
            sampleInterpretation = .signedInteger
            _ = interpStr // consumed
        } else {
            sampleInterpretation = .signedInteger
        }

        // Try to read actual sample interpretation from a dedicated element
        let actualInterpretation: WaveformSampleInterpretation
        // DICOM tag for Waveform Sample Interpretation is (5400,1006) but stored as CS
        // This is actually Waveform Bits Stored per the standard
        // The actual sample interpretation is encoded differently
        if let interpValue = item.elements[.waveformBitsStored]?.stringValue,
           let interp = WaveformSampleInterpretation(dicomValue: interpValue) {
            actualInterpretation = interp
        } else {
            actualInterpretation = sampleInterpretation
        }

        // Waveform Bits Allocated (required) - typically 8 or 16
        let waveformBitsAllocated: UInt16
        // Try to read from the Waveform Bits Allocated attribute
        // In many implementations this is stored alongside channel data
        if let bitsAlloc = item.elements[.waveformBitsStored]?.uint16Value {
            waveformBitsAllocated = bitsAlloc
        } else {
            waveformBitsAllocated = 16 // Default to 16-bit
        }

        let waveformBitsStored = item.elements[.waveformBitsStored]?.uint16Value ?? waveformBitsAllocated

        // Waveform Data (required)
        let waveformData = item.elements[.waveformData]?.valueData ?? Data()

        // Waveform Originality (optional)
        let originality: WaveformOriginality?
        if let origStr = item.elements[.waveformOriginality]?.stringValue {
            originality = WaveformOriginality(dicomValue: origStr)
        } else {
            originality = nil
        }

        // Multiplex Group Label (optional)
        let multiplexGroupLabel = item.elements[.multiplexGroupLabel]?.stringValue

        // Multiplex Group Time Offset (optional)
        let multiplexGroupTimeOffset: Double?
        if let offsetStr = item.elements[.multiplexGroupTimeOffset]?.stringValue {
            multiplexGroupTimeOffset = Double(offsetStr.trimmingCharacters(in: .whitespaces))
        } else {
            multiplexGroupTimeOffset = nil
        }

        // Trigger Time Offset (optional)
        let triggerTimeOffset: Double?
        if let triggerStr = item.elements[.triggerTimeOffset]?.stringValue {
            triggerTimeOffset = Double(triggerStr.trimmingCharacters(in: .whitespaces))
        } else {
            triggerTimeOffset = nil
        }

        // Parse Channel Definition Sequence
        let channels = parseChannels(from: item, count: Int(numberOfChannels))

        return WaveformMultiplexGroup(
            samplingFrequency: samplingFrequency,
            numberOfSamples: numberOfSamples,
            waveformBitsAllocated: waveformBitsAllocated,
            waveformBitsStored: waveformBitsStored,
            waveformSampleInterpretation: actualInterpretation,
            channels: channels,
            waveformData: waveformData,
            originality: originality,
            multiplexGroupLabel: multiplexGroupLabel,
            multiplexGroupTimeOffset: multiplexGroupTimeOffset,
            triggerTimeOffset: triggerTimeOffset
        )
    }

    // MARK: - Channel Parsing

    /// Parse channel definitions from a waveform sequence item
    private static func parseChannels(from item: SequenceItem, count: Int) -> [WaveformChannel] {
        guard let channelItems = item.elements[.channelDefinitionSequence]?.sequenceItems else {
            return []
        }

        return channelItems.prefix(count).map { channelItem in
            parseChannel(from: channelItem)
        }
    }

    /// Parse a single channel definition
    private static func parseChannel(from item: SequenceItem) -> WaveformChannel {
        let channelLabel = item.elements[.channelLabel]?.stringValue

        let channelStatus: [String]?
        if let statusStr = item.elements[.channelStatus]?.stringValue {
            channelStatus = statusStr.split(separator: "\\").map { String($0).trimmingCharacters(in: .whitespaces) }
        } else {
            channelStatus = nil
        }

        let channelSource = parseCodedConcept(from: item, tag: .channelSourceSequence)
        let channelSourceModifiers = parseCodedConceptList(from: item, tag: .channelSourceModifiersSequence)

        let channelSensitivity = parseDouble(from: item, tag: .channelSensitivity)
        let channelSensitivityUnits = parseCodedConcept(from: item, tag: .channelSensitivityUnitsSequence)
        let channelSensitivityCorrectionFactor = parseDouble(from: item, tag: .channelSensitivityCorrectionFactor)
        let channelBaseline = parseDouble(from: item, tag: .channelBaseline)
        let channelTimeSkew = parseDouble(from: item, tag: .channelTimeSkew)
        let channelSampleSkew = parseDouble(from: item, tag: .channelSampleSkew)
        let channelOffset = parseDouble(from: item, tag: .channelOffset)
        let filterLowFrequency = parseDouble(from: item, tag: .filterLowFrequency)
        let filterHighFrequency = parseDouble(from: item, tag: .filterHighFrequency)
        let notchFilterFrequency = parseDouble(from: item, tag: .notchFilterFrequency)
        let notchFilterBandwidth = parseDouble(from: item, tag: .notchFilterBandwidth)

        return WaveformChannel(
            channelLabel: channelLabel,
            channelStatus: channelStatus,
            channelSource: channelSource,
            channelSourceModifiers: channelSourceModifiers,
            channelSensitivity: channelSensitivity,
            channelSensitivityUnits: channelSensitivityUnits,
            channelSensitivityCorrectionFactor: channelSensitivityCorrectionFactor,
            channelBaseline: channelBaseline,
            channelTimeSkew: channelTimeSkew,
            channelSampleSkew: channelSampleSkew,
            channelOffset: channelOffset,
            filterLowFrequency: filterLowFrequency,
            filterHighFrequency: filterHighFrequency,
            notchFilterFrequency: notchFilterFrequency,
            notchFilterBandwidth: notchFilterBandwidth
        )
    }

    // MARK: - Annotation Parsing

    /// Parse waveform annotations
    private static func parseAnnotations(from dataSet: DataSet) -> [WaveformAnnotation] {
        guard let items = dataSet.sequence(for: .waveformAnnotationSequence) else {
            return []
        }

        return items.map { item in
            parseAnnotation(from: item)
        }
    }

    /// Parse a single annotation
    private static func parseAnnotation(from item: SequenceItem) -> WaveformAnnotation {
        let textValue = item.elements[.unformattedTextValue]?.stringValue

        let conceptNameCode = parseCodedConceptDirect(from: item, tag: .conceptNameCodeSequence)

        let numericValue: Double?
        if let numStr = item.elements[.numericValue]?.stringValue {
            numericValue = Double(numStr.trimmingCharacters(in: .whitespaces))
        } else {
            numericValue = nil
        }

        let measurementUnits = parseCodedConceptDirect(from: item, tag: .measurementUnitsCodeSequence)

        let annotationGroupNumber = item.elements[.annotationGroupNumber]?.uint16Value

        let temporalRangeType: TemporalRangeType?
        if let rangeStr = item.elements[.temporalRangeType]?.stringValue {
            temporalRangeType = TemporalRangeType(rawValue: rangeStr.trimmingCharacters(in: .whitespaces))
        } else {
            temporalRangeType = nil
        }

        let referencedSamplePositions: [UInt32]?
        if let posValues = item.elements[.referencedSamplePositions]?.uint16Values {
            referencedSamplePositions = posValues.map { UInt32($0) }
        } else {
            referencedSamplePositions = nil
        }

        let referencedTimeOffsets: [Double]?
        if let offsetStr = item.elements[.referencedTimeOffsets]?.stringValue {
            referencedTimeOffsets = offsetStr.split(separator: "\\").compactMap {
                Double(String($0).trimmingCharacters(in: .whitespaces))
            }
        } else {
            referencedTimeOffsets = nil
        }

        return WaveformAnnotation(
            textValue: textValue,
            conceptNameCode: conceptNameCode,
            numericValue: numericValue,
            measurementUnits: measurementUnits,
            annotationGroupNumber: annotationGroupNumber,
            temporalRangeType: temporalRangeType,
            referencedSamplePositions: referencedSamplePositions,
            referencedTimeOffsets: referencedTimeOffsets
        )
    }

    // MARK: - Helpers

    /// Parse a Double from a DS (Decimal String) element
    private static func parseDouble(from item: SequenceItem, tag: Tag) -> Double? {
        guard let str = item.elements[tag]?.stringValue else { return nil }
        return Double(str.trimmingCharacters(in: .whitespaces))
    }

    /// Parse a coded concept from a sequence element within a sequence item
    private static func parseCodedConcept(from item: SequenceItem, tag: Tag) -> WaveformCodedConcept? {
        guard let seqItems = item.elements[tag]?.sequenceItems,
              let firstItem = seqItems.first else {
            return nil
        }

        guard let codeValue = firstItem.elements[.codeValue]?.stringValue,
              let codingSchemeDesignator = firstItem.elements[.codingSchemeDesignator]?.stringValue,
              let codeMeaning = firstItem.elements[.codeMeaning]?.stringValue else {
            return nil
        }

        return WaveformCodedConcept(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning
        )
    }

    /// Parse a list of coded concepts from a sequence element
    private static func parseCodedConceptList(from item: SequenceItem, tag: Tag) -> [WaveformCodedConcept]? {
        guard let seqItems = item.elements[tag]?.sequenceItems else {
            return nil
        }

        let concepts = seqItems.compactMap { seqItem -> WaveformCodedConcept? in
            guard let codeValue = seqItem.elements[.codeValue]?.stringValue,
                  let codingSchemeDesignator = seqItem.elements[.codingSchemeDesignator]?.stringValue,
                  let codeMeaning = seqItem.elements[.codeMeaning]?.stringValue else {
                return nil
            }
            return WaveformCodedConcept(
                codeValue: codeValue,
                codingSchemeDesignator: codingSchemeDesignator,
                codeMeaning: codeMeaning
            )
        }

        return concepts.isEmpty ? nil : concepts
    }

    /// Parse a coded concept from a sequence item's direct sub-sequence
    private static func parseCodedConceptDirect(from item: SequenceItem, tag: Tag) -> WaveformCodedConcept? {
        guard let seqItems = item.elements[tag]?.sequenceItems,
              let firstItem = seqItems.first else {
            return nil
        }

        guard let codeValue = firstItem.elements[.codeValue]?.stringValue,
              let codingSchemeDesignator = firstItem.elements[.codingSchemeDesignator]?.stringValue,
              let codeMeaning = firstItem.elements[.codeMeaning]?.stringValue else {
            return nil
        }

        return WaveformCodedConcept(
            codeValue: codeValue,
            codingSchemeDesignator: codingSchemeDesignator,
            codeMeaning: codeMeaning
        )
    }
}
