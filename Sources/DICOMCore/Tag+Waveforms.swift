/// DICOM Tag Extensions - Waveform Information
///
/// Tags specific to DICOM Waveform storage and data
/// Reference: DICOM PS3.3 - Waveform IODs
extension Tag {
    // MARK: - Waveform Identification Module
    
    /// Instance Number (0020,0013)
    /// Already defined in Tag+ImageInformation.swift
    
    /// Content Date (0008,0023)
    /// Already defined in Tag+ImageInformation.swift
    
    /// Content Time (0008,0033)
    /// Already defined in Tag+ImageInformation.swift
    
    /// Acquisition DateTime (0008,002A)
    /// Already defined in Tag+ImageInformation.swift
    
    // MARK: - Waveform Module
    
    /// Waveform Sequence (5400,0100)
    /// VR: SQ, VM: 1
    public static let waveformSequence = Tag(group: 0x5400, element: 0x0100)
    
    /// Multiplex Group Time Offset (0018,1068)
    /// VR: DS, VM: 1
    public static let multiplexGroupTimeOffset = Tag(group: 0x0018, element: 0x1068)
    
    /// Trigger Time Offset (0018,1069)
    /// VR: DS, VM: 1
    public static let triggerTimeOffset = Tag(group: 0x0018, element: 0x1069)
    
    /// Synchronization Trigger (0018,106A)
    /// VR: CS, VM: 1
    public static let synchronizationTrigger = Tag(group: 0x0018, element: 0x106A)
    
    /// Trigger Sample Position (0018,106C)
    /// VR: US, VM: 1
    public static let triggerSamplePosition = Tag(group: 0x0018, element: 0x106C)
    
    /// Waveform Originality (5400,0110)
    /// VR: CS, VM: 1
    public static let waveformOriginality = Tag(group: 0x5400, element: 0x0110)
    
    /// Number of Waveform Channels (5400,0105)
    /// VR: US, VM: 1
    public static let numberOfWaveformChannels = Tag(group: 0x5400, element: 0x0105)
    
    /// Number of Waveform Samples (5400,1010)
    /// VR: UL, VM: 1
    public static let numberOfWaveformSamples = Tag(group: 0x5400, element: 0x1010)
    
    /// Sampling Frequency (5400,101A)
    /// VR: DS, VM: 1
    public static let samplingFrequency = Tag(group: 0x5400, element: 0x101A)
    
    /// Multiplex Group Label (5400,0120)
    /// VR: SH, VM: 1
    public static let multiplexGroupLabel = Tag(group: 0x5400, element: 0x0120)
    
    /// Channel Definition Sequence (5400,0200)
    /// VR: SQ, VM: 1
    public static let channelDefinitionSequence = Tag(group: 0x5400, element: 0x0200)
    
    /// Waveform Channel Number (5400,0110)
    /// VR: IS, VM: 1
    /// NOTE: Conflicts with waveformOriginality - using different element
    public static let waveformChannelNumber = Tag(group: 0x5400, element: 0x0112)
    
    /// Channel Label (5400,0402)
    /// VR: SH, VM: 1
    public static let channelLabel = Tag(group: 0x5400, element: 0x0402)
    
    /// Channel Status (5400,0404)
    /// VR: CS, VM: 1-n
    public static let channelStatus = Tag(group: 0x5400, element: 0x0404)
    
    /// Channel Source Sequence (5400,0406)
    /// VR: SQ, VM: 1
    public static let channelSourceSequence = Tag(group: 0x5400, element: 0x0406)
    
    /// Channel Source Modifiers Sequence (5400,0407)
    /// VR: SQ, VM: 1
    public static let channelSourceModifiersSequence = Tag(group: 0x5400, element: 0x0407)
    
    /// Source Waveform Sequence (5400,0408)
    /// VR: SQ, VM: 1
    public static let sourceWaveformSequence = Tag(group: 0x5400, element: 0x0408)
    
    /// Channel Derivation Description (5400,0409)
    /// VR: LO, VM: 1
    public static let channelDerivationDescription = Tag(group: 0x5400, element: 0x0409)
    
    /// Channel Sensitivity (5400,100A)
    /// VR: DS, VM: 1
    public static let channelSensitivity = Tag(group: 0x5400, element: 0x100A)
    
    /// Channel Sensitivity Units Sequence (5400,100B)
    /// VR: SQ, VM: 1
    public static let channelSensitivityUnitsSequence = Tag(group: 0x5400, element: 0x100B)
    
    /// Channel Sensitivity Correction Factor (5400,100C)
    /// VR: DS, VM: 1
    public static let channelSensitivityCorrectionFactor = Tag(group: 0x5400, element: 0x100C)
    
    /// Channel Baseline (5400,100D)
    /// VR: DS, VM: 1
    public static let channelBaseline = Tag(group: 0x5400, element: 0x100D)
    
    /// Channel Time Skew (5400,100E)
    /// VR: DS, VM: 1
    public static let channelTimeSkew = Tag(group: 0x5400, element: 0x100E)
    
    /// Channel Sample Skew (5400,100F)
    /// VR: DS, VM: 1
    public static let channelSampleSkew = Tag(group: 0x5400, element: 0x100F)
    
    /// Channel Offset (5400,1012)
    /// VR: DS, VM: 1
    public static let channelOffset = Tag(group: 0x5400, element: 0x1012)
    
    /// Waveform Bits Stored (5400,1006)
    /// VR: US, VM: 1
    public static let waveformBitsStored = Tag(group: 0x5400, element: 0x1006)
    
    /// Filter Low Frequency (5400,1018)
    /// VR: DS, VM: 1
    public static let filterLowFrequency = Tag(group: 0x5400, element: 0x1018)
    
    /// Filter High Frequency (5400,101A)
    /// VR: DS, VM: 1
    public static let filterHighFrequency = Tag(group: 0x5400, element: 0x101A)
    
    /// Notch Filter Frequency (5400,101C)
    /// VR: DS, VM: 1
    public static let notchFilterFrequency = Tag(group: 0x5400, element: 0x101C)
    
    /// Notch Filter Bandwidth (5400,101E)
    /// VR: DS, VM: 1
    public static let notchFilterBandwidth = Tag(group: 0x5400, element: 0x101E)
    
    /// Waveform Data Display Scale (5400,1014)
    /// VR: DS, VM: 1
    public static let waveformDataDisplayScale = Tag(group: 0x5400, element: 0x1014)
    
    /// Waveform Display Background CIELab Value (5400,1015)
    /// VR: US, VM: 3
    public static let waveformDisplayBackgroundCIELabValue = Tag(group: 0x5400, element: 0x1015)
    
    /// Waveform Presentation Group Sequence (5400,0207)
    /// VR: SQ, VM: 1
    public static let waveformPresentationGroupSequence = Tag(group: 0x5400, element: 0x0207)
    
    /// Presentation Group Number (5400,0208)
    /// VR: US, VM: 1
    public static let presentationGroupNumber = Tag(group: 0x5400, element: 0x0208)
    
    /// Channel Display Sequence (5400,0209)
    /// VR: SQ, VM: 1
    public static let channelDisplaySequence = Tag(group: 0x5400, element: 0x0209)
    
    /// Channel Recommended Display CIELab Value (5400,0205)
    /// VR: US, VM: 3
    public static let channelRecommendedDisplayCIELabValue = Tag(group: 0x5400, element: 0x0205)
    
    /// Channel Position (5400,020A)
    /// VR: FD, VM: 1
    public static let channelPosition = Tag(group: 0x5400, element: 0x020A)
    
    /// Display Shading Flag (5400,020B)
    /// VR: CS, VM: 1
    public static let displayShadingFlag = Tag(group: 0x5400, element: 0x020B)
    
    /// Fractional Channel Display Scale (5400,020C)
    /// VR: FL, VM: 1
    public static let fractionalChannelDisplayScale = Tag(group: 0x5400, element: 0x020C)
    
    /// Absolute Channel Display Scale (5400,020D)
    /// VR: FL, VM: 1
    public static let absoluteChannelDisplayScale = Tag(group: 0x5400, element: 0x020D)
    
    /// Waveform Data (5400,1010)
    /// VR: OB or OW, VM: 1
    /// Note: Same element as numberOfWaveformSamples - they describe the same data element
    /// Use numberOfWaveformSamples for the count, waveformData for the actual data
    public static let waveformData = Tag(group: 0x5400, element: 0x1010)
    
    // MARK: - Waveform Annotation Module
    
    /// Waveform Annotation Sequence (0040,B020)
    /// VR: SQ, VM: 1
    public static let waveformAnnotationSequence = Tag(group: 0x0040, element: 0xB020)
    
    /// Unformatted Text Value (0040,A160)
    /// VR: UT, VM: 1
    /// Note: This is the same as textValue in SR module
    public static let unformattedTextValue = Tag(group: 0x0040, element: 0xA160)
    
    /// Annotation Group Number (0040,A180)
    /// VR: US, VM: 1
    public static let annotationGroupNumber = Tag(group: 0x0040, element: 0xA180)
    
    /// Temporal Range Type (0040,A130)
    /// VR: CS, VM: 1
    public static let temporalRangeType = Tag(group: 0x0040, element: 0xA130)
    
    /// Referenced Sample Positions (0040,A132)
    /// VR: UL, VM: 1-n
    public static let referencedSamplePositions = Tag(group: 0x0040, element: 0xA132)
    
    /// Referenced Time Offsets (0040,A138)
    /// VR: DS, VM: 1-n
    public static let referencedTimeOffsets = Tag(group: 0x0040, element: 0xA138)
    
    /// Referenced DateTime (0040,A13A)
    /// VR: DT, VM: 1-n
    public static let referencedDateTime = Tag(group: 0x0040, element: 0xA13A)
    
    // MARK: - Synchronization Module
    
    /// Synchronization Frame of Reference UID (0020,0200)
    /// Already defined in Tag+SeriesInformation.swift
    
    /// Acquisition Time Synchronized (0018,1800)
    /// VR: CS, VM: 1
    public static let acquisitionTimeSynchronized = Tag(group: 0x0018, element: 0x1800)
    
    /// Time Source (0018,1801)
    /// VR: SH, VM: 1
    public static let timeSource = Tag(group: 0x0018, element: 0x1801)
    
    /// Time Distribution Protocol (0018,1802)
    /// VR: CS, VM: 1
    public static let timeDistributionProtocol = Tag(group: 0x0018, element: 0x1802)
    
    /// NTP Source Address (0018,1803)
    /// VR: LO, VM: 1
    public static let ntpSourceAddress = Tag(group: 0x0018, element: 0x1803)
}
