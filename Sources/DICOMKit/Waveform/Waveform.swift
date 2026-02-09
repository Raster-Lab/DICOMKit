//
// Waveform.swift
// DICOMKit
//
// Created by DICOMKit on 2026-02-09.
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Represents a DICOM Waveform IOD
///
/// Waveform objects store time-based physiological signals such as ECG, EEG, EMG,
/// hemodynamic waveforms, and audio data. Each waveform contains one or more
/// multiplex groups, each with one or more channels sharing a common sampling frequency.
///
/// Supported SOP Classes:
/// - 12-Lead ECG Waveform Storage (1.2.840.10008.5.1.4.1.1.9.1.1)
/// - General ECG Waveform Storage (1.2.840.10008.5.1.4.1.1.9.1.2)
/// - Ambulatory ECG Waveform Storage (1.2.840.10008.5.1.4.1.1.9.1.3)
/// - Hemodynamic Waveform Storage (1.2.840.10008.5.1.4.1.1.9.2.1)
/// - Cardiac Electrophysiology Waveform Storage (1.2.840.10008.5.1.4.1.1.9.3.1)
/// - Basic Voice Audio Waveform Storage (1.2.840.10008.5.1.4.1.1.9.4.1)
/// - General Audio Waveform Storage (1.2.840.10008.5.1.4.1.1.9.4.2)
/// - Arterial Pulse Waveform Storage (1.2.840.10008.5.1.4.1.1.9.5.1)
/// - Respiratory Waveform Storage (1.2.840.10008.5.1.4.1.1.9.6.1)
///
/// Reference: PS3.3 A.34 - Waveform IODs
/// Reference: PS3.3 C.10.9 - Waveform Module
public struct Waveform: Sendable {

    // MARK: - SOP Class UIDs

    /// 12-Lead ECG Waveform Storage
    public static let twelveLeadECGStorageUID = "1.2.840.10008.5.1.4.1.1.9.1.1"

    /// General ECG Waveform Storage
    public static let generalECGStorageUID = "1.2.840.10008.5.1.4.1.1.9.1.2"

    /// Ambulatory ECG Waveform Storage
    public static let ambulatoryECGStorageUID = "1.2.840.10008.5.1.4.1.1.9.1.3"

    /// Hemodynamic Waveform Storage
    public static let hemodynamicWaveformStorageUID = "1.2.840.10008.5.1.4.1.1.9.2.1"

    /// Cardiac Electrophysiology Waveform Storage
    public static let cardiacElectrophysiologyStorageUID = "1.2.840.10008.5.1.4.1.1.9.3.1"

    /// Basic Voice Audio Waveform Storage
    public static let basicVoiceAudioStorageUID = "1.2.840.10008.5.1.4.1.1.9.4.1"

    /// General Audio Waveform Storage
    public static let generalAudioStorageUID = "1.2.840.10008.5.1.4.1.1.9.4.2"

    /// Arterial Pulse Waveform Storage
    public static let arterialPulseWaveformStorageUID = "1.2.840.10008.5.1.4.1.1.9.5.1"

    /// Respiratory Waveform Storage
    public static let respiratoryWaveformStorageUID = "1.2.840.10008.5.1.4.1.1.9.6.1"

    // MARK: - Identification

    /// SOP Instance UID
    public let sopInstanceUID: String

    /// SOP Class UID
    public let sopClassUID: String

    /// Study Instance UID
    public let studyInstanceUID: String

    /// Series Instance UID
    public let seriesInstanceUID: String

    /// Instance Number
    public let instanceNumber: Int?

    // MARK: - Patient Information

    /// Patient Name
    public let patientName: String?

    /// Patient ID
    public let patientID: String?

    // MARK: - Series Information

    /// Modality (typically "ECG", "HD", "EPS", "AU")
    public let modality: String?

    /// Series Description
    public let seriesDescription: String?

    /// Series Number
    public let seriesNumber: Int?

    // MARK: - Content Date/Time

    /// Content Date
    public let contentDate: DICOMDate?

    /// Content Time
    public let contentTime: DICOMTime?

    // MARK: - Waveform Data

    /// Multiplex groups containing the waveform data
    public let multiplexGroups: [WaveformMultiplexGroup]

    /// Waveform annotations
    public let annotations: [WaveformAnnotation]

    // MARK: - Initialization

    /// Creates a Waveform
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        instanceNumber: Int? = nil,
        patientName: String? = nil,
        patientID: String? = nil,
        modality: String? = nil,
        seriesDescription: String? = nil,
        seriesNumber: Int? = nil,
        contentDate: DICOMDate? = nil,
        contentTime: DICOMTime? = nil,
        multiplexGroups: [WaveformMultiplexGroup] = [],
        annotations: [WaveformAnnotation] = []
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.instanceNumber = instanceNumber
        self.patientName = patientName
        self.patientID = patientID
        self.modality = modality
        self.seriesDescription = seriesDescription
        self.seriesNumber = seriesNumber
        self.contentDate = contentDate
        self.contentTime = contentTime
        self.multiplexGroups = multiplexGroups
        self.annotations = annotations
    }

    /// The waveform type inferred from the SOP Class UID
    public var waveformType: WaveformType {
        return WaveformType(sopClassUID: sopClassUID)
    }

    /// Total number of channels across all multiplex groups
    public var totalChannelCount: Int {
        return multiplexGroups.reduce(0) { $0 + $1.channels.count }
    }

    /// Total number of samples across all multiplex groups
    public var totalSampleCount: Int {
        return multiplexGroups.reduce(0) { $0 + $1.numberOfSamples }
    }
}

// MARK: - Waveform Type

/// Type of waveform based on SOP Class UID
public enum WaveformType: String, Sendable, CaseIterable {
    case twelveLeadECG
    case generalECG
    case ambulatoryECG
    case hemodynamic
    case cardiacElectrophysiology
    case basicVoiceAudio
    case generalAudio
    case arterialPulse
    case respiratoryWaveform
    case unknown

    /// Creates a waveform type from a SOP Class UID
    public init(sopClassUID: String) {
        switch sopClassUID {
        case Waveform.twelveLeadECGStorageUID:
            self = .twelveLeadECG
        case Waveform.generalECGStorageUID:
            self = .generalECG
        case Waveform.ambulatoryECGStorageUID:
            self = .ambulatoryECG
        case Waveform.hemodynamicWaveformStorageUID:
            self = .hemodynamic
        case Waveform.cardiacElectrophysiologyStorageUID:
            self = .cardiacElectrophysiology
        case Waveform.basicVoiceAudioStorageUID:
            self = .basicVoiceAudio
        case Waveform.generalAudioStorageUID:
            self = .generalAudio
        case Waveform.arterialPulseWaveformStorageUID:
            self = .arterialPulse
        case Waveform.respiratoryWaveformStorageUID:
            self = .respiratoryWaveform
        default:
            self = .unknown
        }
    }

    /// The SOP Class UID for this waveform type
    public var sopClassUID: String {
        switch self {
        case .twelveLeadECG: return Waveform.twelveLeadECGStorageUID
        case .generalECG: return Waveform.generalECGStorageUID
        case .ambulatoryECG: return Waveform.ambulatoryECGStorageUID
        case .hemodynamic: return Waveform.hemodynamicWaveformStorageUID
        case .cardiacElectrophysiology: return Waveform.cardiacElectrophysiologyStorageUID
        case .basicVoiceAudio: return Waveform.basicVoiceAudioStorageUID
        case .generalAudio: return Waveform.generalAudioStorageUID
        case .arterialPulse: return Waveform.arterialPulseWaveformStorageUID
        case .respiratoryWaveform: return Waveform.respiratoryWaveformStorageUID
        case .unknown: return ""
        }
    }

    /// Human-readable description of the waveform type
    public var description: String {
        switch self {
        case .twelveLeadECG: return "12-Lead ECG"
        case .generalECG: return "General ECG"
        case .ambulatoryECG: return "Ambulatory ECG"
        case .hemodynamic: return "Hemodynamic"
        case .cardiacElectrophysiology: return "Cardiac Electrophysiology"
        case .basicVoiceAudio: return "Basic Voice Audio"
        case .generalAudio: return "General Audio"
        case .arterialPulse: return "Arterial Pulse"
        case .respiratoryWaveform: return "Respiratory"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Waveform Multiplex Group

/// A multiplex group containing one or more channels sharing a common sampling frequency
///
/// Reference: PS3.3 C.10.9.1 - Waveform Module Attributes
public struct WaveformMultiplexGroup: Sendable {

    /// Sampling frequency in Hz
    public let samplingFrequency: Double

    /// Number of samples per channel
    public let numberOfSamples: Int

    /// Number of bits allocated per sample (8 or 16)
    public let waveformBitsAllocated: UInt16

    /// Number of bits stored per sample
    public let waveformBitsStored: UInt16

    /// Sample interpretation (signed or unsigned)
    public let waveformSampleInterpretation: WaveformSampleInterpretation

    /// Channel definitions
    public let channels: [WaveformChannel]

    /// Raw waveform data (interleaved channel samples)
    public let waveformData: Data

    /// Waveform originality (ORIGINAL or DERIVED)
    public let originality: WaveformOriginality?

    /// Multiplex group label
    public let multiplexGroupLabel: String?

    /// Multiplex group time offset in seconds
    public let multiplexGroupTimeOffset: Double?

    /// Trigger time offset in seconds
    public let triggerTimeOffset: Double?

    /// Creates a WaveformMultiplexGroup
    public init(
        samplingFrequency: Double,
        numberOfSamples: Int,
        waveformBitsAllocated: UInt16,
        waveformBitsStored: UInt16,
        waveformSampleInterpretation: WaveformSampleInterpretation,
        channels: [WaveformChannel],
        waveformData: Data,
        originality: WaveformOriginality? = nil,
        multiplexGroupLabel: String? = nil,
        multiplexGroupTimeOffset: Double? = nil,
        triggerTimeOffset: Double? = nil
    ) {
        self.samplingFrequency = samplingFrequency
        self.numberOfSamples = numberOfSamples
        self.waveformBitsAllocated = waveformBitsAllocated
        self.waveformBitsStored = waveformBitsStored
        self.waveformSampleInterpretation = waveformSampleInterpretation
        self.channels = channels
        self.waveformData = waveformData
        self.originality = originality
        self.multiplexGroupLabel = multiplexGroupLabel
        self.multiplexGroupTimeOffset = multiplexGroupTimeOffset
        self.triggerTimeOffset = triggerTimeOffset
    }

    /// Extracts sample values for a specific channel
    ///
    /// - Parameter channelIndex: The zero-based index of the channel
    /// - Returns: Array of sample values as Doubles, applying sensitivity and baseline corrections
    public func channelSamples(at channelIndex: Int) -> [Double] {
        guard channelIndex >= 0 && channelIndex < channels.count else {
            return []
        }

        let channel = channels[channelIndex]
        let channelCount = channels.count
        let bytesPerSample = Int(waveformBitsAllocated) / 8

        var samples: [Double] = []
        samples.reserveCapacity(numberOfSamples)

        for sampleIndex in 0..<numberOfSamples {
            let byteOffset = (sampleIndex * channelCount + channelIndex) * bytesPerSample
            guard byteOffset + bytesPerSample <= waveformData.count else { break }

            let rawValue: Double
            switch (waveformBitsAllocated, waveformSampleInterpretation) {
            case (8, .unsignedInteger):
                rawValue = Double(waveformData[byteOffset])
            case (8, .signedInteger):
                rawValue = Double(Int8(bitPattern: waveformData[byteOffset]))
            case (16, .unsignedInteger):
                let value = UInt16(waveformData[byteOffset]) | (UInt16(waveformData[byteOffset + 1]) << 8)
                rawValue = Double(value)
            case (16, .signedInteger):
                let value = UInt16(waveformData[byteOffset]) | (UInt16(waveformData[byteOffset + 1]) << 8)
                rawValue = Double(Int16(bitPattern: value))
            default:
                rawValue = 0
            }

            // Apply channel sensitivity and baseline correction
            let correctedValue = channel.applyCalibration(rawValue: rawValue)
            samples.append(correctedValue)
        }

        return samples
    }

    /// Duration of the waveform in seconds
    public var duration: Double {
        guard samplingFrequency > 0 else { return 0 }
        return Double(numberOfSamples) / samplingFrequency
    }
}

// MARK: - Waveform Channel

/// Definition of a single waveform channel within a multiplex group
///
/// Reference: PS3.3 C.10.9.1 - Channel Definition Sequence
public struct WaveformChannel: Sendable {

    /// Channel label (e.g., "Lead I", "Lead II")
    public let channelLabel: String?

    /// Channel status
    public let channelStatus: [String]?

    /// Channel source - coded description of the signal source
    public let channelSource: WaveformCodedConcept?

    /// Channel source modifiers
    public let channelSourceModifiers: [WaveformCodedConcept]?

    /// Channel sensitivity (units per raw value)
    public let channelSensitivity: Double?

    /// Channel sensitivity units
    public let channelSensitivityUnits: WaveformCodedConcept?

    /// Channel sensitivity correction factor
    public let channelSensitivityCorrectionFactor: Double?

    /// Channel baseline value
    public let channelBaseline: Double?

    /// Channel time skew in seconds
    public let channelTimeSkew: Double?

    /// Channel sample skew
    public let channelSampleSkew: Double?

    /// Channel offset
    public let channelOffset: Double?

    /// Filter low frequency in Hz
    public let filterLowFrequency: Double?

    /// Filter high frequency in Hz
    public let filterHighFrequency: Double?

    /// Notch filter frequency in Hz
    public let notchFilterFrequency: Double?

    /// Notch filter bandwidth in Hz
    public let notchFilterBandwidth: Double?

    /// Creates a WaveformChannel
    public init(
        channelLabel: String? = nil,
        channelStatus: [String]? = nil,
        channelSource: WaveformCodedConcept? = nil,
        channelSourceModifiers: [WaveformCodedConcept]? = nil,
        channelSensitivity: Double? = nil,
        channelSensitivityUnits: WaveformCodedConcept? = nil,
        channelSensitivityCorrectionFactor: Double? = nil,
        channelBaseline: Double? = nil,
        channelTimeSkew: Double? = nil,
        channelSampleSkew: Double? = nil,
        channelOffset: Double? = nil,
        filterLowFrequency: Double? = nil,
        filterHighFrequency: Double? = nil,
        notchFilterFrequency: Double? = nil,
        notchFilterBandwidth: Double? = nil
    ) {
        self.channelLabel = channelLabel
        self.channelStatus = channelStatus
        self.channelSource = channelSource
        self.channelSourceModifiers = channelSourceModifiers
        self.channelSensitivity = channelSensitivity
        self.channelSensitivityUnits = channelSensitivityUnits
        self.channelSensitivityCorrectionFactor = channelSensitivityCorrectionFactor
        self.channelBaseline = channelBaseline
        self.channelTimeSkew = channelTimeSkew
        self.channelSampleSkew = channelSampleSkew
        self.channelOffset = channelOffset
        self.filterLowFrequency = filterLowFrequency
        self.filterHighFrequency = filterHighFrequency
        self.notchFilterFrequency = notchFilterFrequency
        self.notchFilterBandwidth = notchFilterBandwidth
    }

    /// Applies calibration to convert a raw sample value to physical units
    ///
    /// The formula is: value = (rawValue + baseline) * sensitivity * correctionFactor + offset
    ///
    /// Reference: PS3.3 C.10.9.1.4.3 - Waveform Sample Value Transformation
    ///
    /// - Parameter rawValue: Raw integer sample value
    /// - Returns: Calibrated value in physical units
    public func applyCalibration(rawValue: Double) -> Double {
        let baseline = channelBaseline ?? 0
        let sensitivity = channelSensitivity ?? 1
        let correctionFactor = channelSensitivityCorrectionFactor ?? 1
        let offset = channelOffset ?? 0
        return (rawValue + baseline) * sensitivity * correctionFactor + offset
    }
}

// MARK: - Waveform Annotation

/// Annotation associated with a waveform
///
/// Reference: PS3.3 C.10.10 - Waveform Annotation Module
public struct WaveformAnnotation: Sendable {

    /// Unformatted text value of the annotation
    public let textValue: String?

    /// Coded concept for the annotation
    public let conceptNameCode: WaveformCodedConcept?

    /// Numeric value associated with the annotation
    public let numericValue: Double?

    /// Units for the numeric value
    public let measurementUnits: WaveformCodedConcept?

    /// Annotation group number
    public let annotationGroupNumber: UInt16?

    /// Temporal range type (POINT, MULTIPOINT, SEGMENT, MULTISEGMENT, BEGIN, END)
    public let temporalRangeType: TemporalRangeType?

    /// Referenced sample positions within the waveform data
    public let referencedSamplePositions: [UInt32]?

    /// Referenced time offsets in seconds
    public let referencedTimeOffsets: [Double]?

    /// Creates a WaveformAnnotation
    public init(
        textValue: String? = nil,
        conceptNameCode: WaveformCodedConcept? = nil,
        numericValue: Double? = nil,
        measurementUnits: WaveformCodedConcept? = nil,
        annotationGroupNumber: UInt16? = nil,
        temporalRangeType: TemporalRangeType? = nil,
        referencedSamplePositions: [UInt32]? = nil,
        referencedTimeOffsets: [Double]? = nil
    ) {
        self.textValue = textValue
        self.conceptNameCode = conceptNameCode
        self.numericValue = numericValue
        self.measurementUnits = measurementUnits
        self.annotationGroupNumber = annotationGroupNumber
        self.temporalRangeType = temporalRangeType
        self.referencedSamplePositions = referencedSamplePositions
        self.referencedTimeOffsets = referencedTimeOffsets
    }
}

// MARK: - Supporting Types

/// Sample interpretation for waveform data
///
/// Reference: PS3.3 C.10.9.1.4 - Waveform Sample Interpretation
public enum WaveformSampleInterpretation: String, Sendable {
    /// Unsigned 8-bit or 16-bit integer
    case unsignedInteger = "SB"
    /// Signed 8-bit or 16-bit integer
    case signedInteger = "SS"
    /// Unsigned byte (8-bit)
    case unsignedByte = "UB"
    /// Signed short (16-bit)
    case signedShort = "US"
    /// Mu-law compressed audio
    case muLaw = "MB"
    /// A-law compressed audio
    case aLaw = "AB"

    /// Creates from a DICOM code string value
    public init?(dicomValue: String) {
        let trimmed = dicomValue.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "SB": self = .unsignedInteger
        case "SS": self = .signedInteger
        case "UB": self = .unsignedByte
        case "US": self = .signedShort
        case "MB": self = .muLaw
        case "AB": self = .aLaw
        default: return nil
        }
    }

    /// Whether this interpretation represents signed values
    public var isSigned: Bool {
        switch self {
        case .signedInteger, .signedShort: return true
        case .unsignedInteger, .unsignedByte, .muLaw, .aLaw: return false
        }
    }
}

/// Waveform originality
///
/// Reference: PS3.3 C.10.9.1.2 - Waveform Originality
public enum WaveformOriginality: String, Sendable {
    case original = "ORIGINAL"
    case derived = "DERIVED"

    /// Creates from a DICOM code string value
    public init?(dicomValue: String) {
        let trimmed = dicomValue.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "ORIGINAL": self = .original
        case "DERIVED": self = .derived
        default: return nil
        }
    }
}

// TemporalRangeType is defined in DICOMCore.StructuredReporting.ContentItem
// and is reused here for waveform annotations

/// Coded concept used in waveform channel source and annotations
///
/// Reference: PS3.3 Section 8 - Code Sequence Macro
public struct WaveformCodedConcept: Sendable, Equatable {
    /// Code Value (0008,0100)
    public let codeValue: String

    /// Coding Scheme Designator (0008,0102)
    public let codingSchemeDesignator: String

    /// Code Meaning (0008,0104)
    public let codeMeaning: String

    public init(codeValue: String, codingSchemeDesignator: String, codeMeaning: String) {
        self.codeValue = codeValue
        self.codingSchemeDesignator = codingSchemeDesignator
        self.codeMeaning = codeMeaning
    }
}
