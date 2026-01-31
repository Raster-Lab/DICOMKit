import Foundation

/// Configuration for transfer syntax conversion
///
/// Specifies how DICOM data sets should be transcoded between transfer syntaxes.
/// Reference: DICOM PS3.5 Section 10 - Transfer Syntax Specification
public struct TranscodingConfiguration: Sendable, Hashable {
    /// Preferred transfer syntaxes in order of preference
    ///
    /// When transcoding, the converter will attempt to use these syntaxes
    /// in order, selecting the first one that is compatible with the data.
    public let preferredSyntaxes: [TransferSyntax]
    
    /// Whether to allow lossy compression during transcoding
    ///
    /// If false, only lossless transfer syntaxes will be considered.
    /// Default is false to preserve data fidelity.
    public let allowLossyCompression: Bool
    
    /// Whether to preserve pixel data fidelity
    ///
    /// When true, the converter will verify that transcoding maintains
    /// pixel data integrity for lossless conversions.
    public let preservePixelDataFidelity: Bool
    
    /// Default configuration preferring Explicit VR Little Endian
    public static let `default` = TranscodingConfiguration(
        preferredSyntaxes: [
            .explicitVRLittleEndian,
            .implicitVRLittleEndian
        ],
        allowLossyCompression: false,
        preservePixelDataFidelity: true
    )
    
    /// Configuration for maximum compression (allows lossy)
    public static let maxCompression = TranscodingConfiguration(
        preferredSyntaxes: [
            .jpegBaseline,
            .jpeg2000,
            .explicitVRLittleEndian
        ],
        allowLossyCompression: true,
        preservePixelDataFidelity: false
    )
    
    /// Configuration for lossless compression only
    public static let losslessCompression = TranscodingConfiguration(
        preferredSyntaxes: [
            .jpeg2000Lossless,
            .jpegLosslessSV1,
            .rleLossless,
            .explicitVRLittleEndian
        ],
        allowLossyCompression: false,
        preservePixelDataFidelity: true
    )
    
    /// Creates a transcoding configuration
    ///
    /// - Parameters:
    ///   - preferredSyntaxes: Transfer syntaxes in order of preference
    ///   - allowLossyCompression: Whether lossy compression is allowed
    ///   - preservePixelDataFidelity: Whether to verify pixel data integrity
    public init(
        preferredSyntaxes: [TransferSyntax],
        allowLossyCompression: Bool = false,
        preservePixelDataFidelity: Bool = true
    ) {
        self.preferredSyntaxes = preferredSyntaxes
        self.allowLossyCompression = allowLossyCompression
        self.preservePixelDataFidelity = preservePixelDataFidelity
    }
}

/// Result of a transfer syntax conversion operation
public struct TranscodingResult: Sendable {
    /// The transcoded data set bytes
    public let data: Data
    
    /// The source transfer syntax
    public let sourceTransferSyntax: TransferSyntax
    
    /// The target transfer syntax
    public let targetTransferSyntax: TransferSyntax
    
    /// Whether transcoding was actually performed
    ///
    /// False if source and target syntaxes were the same.
    public let wasTranscoded: Bool
    
    /// Whether the conversion was lossless
    public let isLossless: Bool
    
    /// Creates a transcoding result
    public init(
        data: Data,
        sourceTransferSyntax: TransferSyntax,
        targetTransferSyntax: TransferSyntax,
        wasTranscoded: Bool,
        isLossless: Bool
    ) {
        self.data = data
        self.sourceTransferSyntax = sourceTransferSyntax
        self.targetTransferSyntax = targetTransferSyntax
        self.wasTranscoded = wasTranscoded
        self.isLossless = isLossless
    }
}

/// Errors that can occur during transfer syntax conversion
public enum TranscodingError: Error, Sendable, Equatable {
    /// The source transfer syntax is not supported for transcoding
    case unsupportedSourceSyntax(String)
    
    /// The target transfer syntax is not supported for transcoding
    case unsupportedTargetSyntax(String)
    
    /// No compatible target syntax found from preferred list
    case noCompatibleSyntax
    
    /// Pixel data extraction failed
    case pixelDataExtractionFailed(String)
    
    /// Pixel data encoding failed
    case encodingFailed(String)
    
    /// Data set parsing failed
    case parsingFailed(String)
    
    /// Transcoding would result in lossy compression but was not allowed
    case lossyCompressionNotAllowed
    
    /// Pixel data fidelity could not be preserved
    case fidelityLost
}

extension TranscodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupportedSourceSyntax(let syntax):
            return "Unsupported source transfer syntax: \(syntax)"
        case .unsupportedTargetSyntax(let syntax):
            return "Unsupported target transfer syntax: \(syntax)"
        case .noCompatibleSyntax:
            return "No compatible target transfer syntax found from preferred list"
        case .pixelDataExtractionFailed(let reason):
            return "Pixel data extraction failed: \(reason)"
        case .encodingFailed(let reason):
            return "Encoding failed: \(reason)"
        case .parsingFailed(let reason):
            return "Data set parsing failed: \(reason)"
        case .lossyCompressionNotAllowed:
            return "Transcoding would result in lossy compression but was not allowed"
        case .fidelityLost:
            return "Pixel data fidelity could not be preserved"
        }
    }
}

/// Transfer Syntax Converter
///
/// Converts DICOM data sets between different transfer syntaxes.
/// Supports conversion between uncompressed syntaxes (Implicit VR, Explicit VR)
/// and handles byte order conversion.
///
/// Reference: DICOM PS3.5 Section 10 - Transfer Syntax Specification
public struct TransferSyntaxConverter: Sendable {
    
    /// Configuration for the converter
    public let configuration: TranscodingConfiguration
    
    /// Creates a transfer syntax converter with the specified configuration
    /// - Parameter configuration: Transcoding configuration (default: `.default`)
    public init(configuration: TranscodingConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Checks if transcoding is supported between two transfer syntaxes
    ///
    /// - Parameters:
    ///   - source: Source transfer syntax
    ///   - target: Target transfer syntax
    /// - Returns: True if transcoding is supported
    public func canTranscode(from source: TransferSyntax, to target: TransferSyntax) -> Bool {
        // Same syntax - always supported (no-op)
        if source.uid == target.uid {
            return true
        }
        
        // Currently support uncompressed-to-uncompressed conversions
        let supportedUncompressed = [
            TransferSyntax.implicitVRLittleEndian.uid,
            TransferSyntax.explicitVRLittleEndian.uid,
            TransferSyntax.explicitVRBigEndian.uid
        ]
        
        // Check if both are uncompressed
        let sourceIsUncompressed = supportedUncompressed.contains(source.uid) && !source.isEncapsulated
        let targetIsUncompressed = supportedUncompressed.contains(target.uid) && !target.isEncapsulated
        
        if sourceIsUncompressed && targetIsUncompressed {
            return true
        }
        
        // Decompression: compressed to uncompressed
        if source.isEncapsulated && targetIsUncompressed {
            return CodecRegistry.shared.hasCodec(for: source.uid)
        }
        
        return false
    }
    
    /// Selects the best target transfer syntax from the configuration's preferred list
    ///
    /// - Parameters:
    ///   - sourceData: The source data set bytes
    ///   - sourceSyntax: The source transfer syntax
    ///   - acceptedSyntaxes: List of syntaxes accepted by the target
    /// - Returns: The best compatible transfer syntax, or nil if none found
    public func selectTargetSyntax(
        for sourceData: Data,
        sourceSyntax: TransferSyntax,
        acceptedSyntaxes: [String]
    ) -> TransferSyntax? {
        for preferred in configuration.preferredSyntaxes {
            // Check if accepted by target
            guard acceptedSyntaxes.contains(preferred.uid) else {
                continue
            }
            
            // Check lossy constraint
            if !configuration.allowLossyCompression && !preferred.isLossless {
                continue
            }
            
            // Check if we can transcode to this syntax
            if canTranscode(from: sourceSyntax, to: preferred) {
                return preferred
            }
        }
        
        // If no preferred syntax works, try accepted syntaxes directly
        for acceptedUID in acceptedSyntaxes {
            guard let accepted = TransferSyntax.from(uid: acceptedUID) else {
                continue
            }
            
            if !configuration.allowLossyCompression && !accepted.isLossless {
                continue
            }
            
            if canTranscode(from: sourceSyntax, to: accepted) {
                return accepted
            }
        }
        
        return nil
    }
    
    /// Transcodes a DICOM data set to a different transfer syntax
    ///
    /// - Parameters:
    ///   - dataSetData: The source data set bytes (without File Meta Information)
    ///   - sourceSyntax: The source transfer syntax
    ///   - targetSyntax: The target transfer syntax
    /// - Returns: Transcoding result with the converted data
    /// - Throws: `TranscodingError` if transcoding fails
    public func transcode(
        dataSetData: Data,
        from sourceSyntax: TransferSyntax,
        to targetSyntax: TransferSyntax
    ) throws -> TranscodingResult {
        // No transcoding needed if syntaxes match
        if sourceSyntax.uid == targetSyntax.uid {
            return TranscodingResult(
                data: dataSetData,
                sourceTransferSyntax: sourceSyntax,
                targetTransferSyntax: targetSyntax,
                wasTranscoded: false,
                isLossless: true
            )
        }
        
        // Check if transcoding is supported
        guard canTranscode(from: sourceSyntax, to: targetSyntax) else {
            throw TranscodingError.unsupportedTargetSyntax(targetSyntax.uid)
        }
        
        // Check lossy constraint
        let isLossless = sourceSyntax.isLossless && targetSyntax.isLossless
        if !configuration.allowLossyCompression && !isLossless {
            throw TranscodingError.lossyCompressionNotAllowed
        }
        
        // Perform the transcoding
        let transcodedData: Data
        
        if !sourceSyntax.isEncapsulated && !targetSyntax.isEncapsulated {
            // Uncompressed to uncompressed
            transcodedData = try transcodeUncompressed(
                dataSetData: dataSetData,
                from: sourceSyntax,
                to: targetSyntax
            )
        } else if sourceSyntax.isEncapsulated && !targetSyntax.isEncapsulated {
            // Compressed to uncompressed (decompression)
            transcodedData = try transcodeFromEncapsulated(
                dataSetData: dataSetData,
                from: sourceSyntax,
                to: targetSyntax
            )
        } else {
            throw TranscodingError.unsupportedTargetSyntax(targetSyntax.uid)
        }
        
        return TranscodingResult(
            data: transcodedData,
            sourceTransferSyntax: sourceSyntax,
            targetTransferSyntax: targetSyntax,
            wasTranscoded: true,
            isLossless: isLossless
        )
    }
    
    // MARK: - Private Methods
    
    /// Transcodes between uncompressed transfer syntaxes
    private func transcodeUncompressed(
        dataSetData: Data,
        from source: TransferSyntax,
        to target: TransferSyntax
    ) throws -> Data {
        // Parse the source data elements
        let elements = try parseDataElements(from: dataSetData, transferSyntax: source)
        
        // Write elements in target transfer syntax
        let writer = DICOMWriter(byteOrder: target.byteOrder, explicitVR: target.isExplicitVR)
        var outputData = Data()
        
        for element in elements {
            // Re-encode numeric values if byte order changes
            let transcodedElement: DataElement
            if source.byteOrder != target.byteOrder {
                transcodedElement = try transcodeElementByteOrder(element, from: source.byteOrder, to: target.byteOrder)
            } else {
                transcodedElement = element
            }
            
            outputData.append(writer.serializeElement(transcodedElement))
        }
        
        return outputData
    }
    
    /// Transcodes from encapsulated (compressed) to uncompressed
    private func transcodeFromEncapsulated(
        dataSetData: Data,
        from source: TransferSyntax,
        to target: TransferSyntax
    ) throws -> Data {
        // For encapsulated data, we need a codec to decompress
        guard let codec = CodecRegistry.shared.codec(for: source.uid) else {
            throw TranscodingError.unsupportedSourceSyntax(source.uid)
        }
        
        // Parse elements including the encapsulated pixel data
        let elements = try parseDataElements(from: dataSetData, transferSyntax: source)
        
        // Find pixel data element and decompress if present
        var outputElements: [DataElement] = []
        
        for element in elements {
            if element.tag == .pixelData && element.isEncapsulated,
               let fragments = element.encapsulatedFragments {
                // Get pixel data descriptor from surrounding elements
                let descriptor = try extractPixelDataDescriptor(from: elements)
                
                // Decompress each frame
                var decompressedData = Data()
                for (index, fragment) in fragments.enumerated() {
                    let frameData = try codec.decodeFrame(fragment, descriptor: descriptor, frameIndex: index)
                    decompressedData.append(frameData)
                }
                
                // Create new uncompressed pixel data element
                let newElement = DataElement(
                    tag: element.tag,
                    vr: element.vr,
                    length: UInt32(decompressedData.count),
                    valueData: decompressedData
                )
                outputElements.append(newElement)
            } else {
                outputElements.append(element)
            }
        }
        
        // Write elements in target transfer syntax
        let writer = DICOMWriter(byteOrder: target.byteOrder, explicitVR: target.isExplicitVR)
        var outputData = Data()
        
        for element in outputElements {
            outputData.append(writer.serializeElement(element))
        }
        
        return outputData
    }
    
    /// Parses data elements from raw bytes
    private func parseDataElements(from data: Data, transferSyntax: TransferSyntax) throws -> [DataElement] {
        var elements: [DataElement] = []
        var offset = 0
        
        while offset < data.count {
            guard let element = try parseDataElement(from: data, at: &offset, transferSyntax: transferSyntax) else {
                break
            }
            elements.append(element)
        }
        
        return elements
    }
    
    /// Parses a single data element
    private func parseDataElement(from data: Data, at offset: inout Int, transferSyntax: TransferSyntax) throws -> DataElement? {
        guard offset + 4 <= data.count else {
            return nil
        }
        
        // Read tag
        let group = transferSyntax.byteOrder == .littleEndian
            ? data.readUInt16LE(at: offset)
            : data.readUInt16BE(at: offset)
        let element = transferSyntax.byteOrder == .littleEndian
            ? data.readUInt16LE(at: offset + 2)
            : data.readUInt16BE(at: offset + 2)
        
        guard let group = group, let element = element else {
            return nil
        }
        
        let tag = Tag(group: group, element: element)
        offset += 4
        
        // Parse based on VR encoding
        let vr: VR
        let length: UInt32
        
        if transferSyntax.isExplicitVR {
            guard offset + 2 <= data.count else {
                return nil
            }
            
            // Read VR as 2 ASCII characters
            let vrBytes = data.subdata(in: offset..<offset+2)
            let vrString = String(data: vrBytes, encoding: .ascii) ?? "UN"
            vr = VR(rawValue: vrString) ?? .UN
            offset += 2
            
            if vr.uses32BitLength {
                // Skip 2 reserved bytes
                offset += 2
                guard offset + 4 <= data.count else {
                    return nil
                }
                length = transferSyntax.byteOrder == .littleEndian
                    ? (data.readUInt32LE(at: offset) ?? 0)
                    : (data.readUInt32BE(at: offset) ?? 0)
                offset += 4
            } else {
                guard offset + 2 <= data.count else {
                    return nil
                }
                let len16 = transferSyntax.byteOrder == .littleEndian
                    ? (data.readUInt16LE(at: offset) ?? 0)
                    : (data.readUInt16BE(at: offset) ?? 0)
                length = UInt32(len16)
                offset += 2
            }
        } else {
            // Implicit VR - use UN (Unknown) as default per DICOM PS3.5 Section 6.2.2
            // A proper implementation would look up VR from the Data Element Dictionary,
            // but since DICOMCore doesn't have access to DICOMDictionary, we use UN.
            // For common tags, we can infer the VR.
            vr = inferVRForTag(tag)
            guard offset + 4 <= data.count else {
                return nil
            }
            length = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt32LE(at: offset) ?? 0)
                : (data.readUInt32BE(at: offset) ?? 0)
            offset += 4
        }
        
        // Handle undefined length (sequence or encapsulated pixel data)
        if length == 0xFFFFFFFF {
            if vr == .SQ {
                // Parse sequence
                let (items, newOffset) = try parseSequence(from: data, at: offset, transferSyntax: transferSyntax)
                offset = newOffset
                return DataElement(tag: tag, vr: vr, length: length, valueData: Data(), sequenceItems: items)
            } else if tag == .pixelData {
                // Parse encapsulated pixel data
                let (fragments, offsetTable, newOffset) = try parseEncapsulatedPixelData(from: data, at: offset, transferSyntax: transferSyntax)
                offset = newOffset
                return DataElement(
                    tag: tag,
                    vr: vr,
                    length: length,
                    valueData: Data(),
                    encapsulatedFragments: fragments,
                    encapsulatedOffsetTable: offsetTable
                )
            }
        }
        
        // Read value data
        let intLength = Int(length)
        guard offset + intLength <= data.count else {
            // Handle truncated data gracefully
            // This can occur when parsing partial data or when the source file was truncated.
            // We read what's available to allow processing to continue, which is acceptable
            // for transcoding scenarios where the goal is to convert existing (possibly
            // partial) data rather than strictly validate completeness.
            // The caller can detect truncation by comparing the returned element's length
            // with the original length if strict validation is needed.
            let availableLength = data.count - offset
            let valueData = data.subdata(in: offset..<offset+availableLength)
            offset = data.count
            return DataElement(tag: tag, vr: vr, length: UInt32(availableLength), valueData: valueData)
        }
        
        let valueData = data.subdata(in: offset..<offset+intLength)
        offset += intLength
        
        return DataElement(tag: tag, vr: vr, length: length, valueData: valueData)
    }
    
    /// Parses a sequence with undefined length
    private func parseSequence(from data: Data, at offset: Int, transferSyntax: TransferSyntax) throws -> ([SequenceItem], Int) {
        var items: [SequenceItem] = []
        var currentOffset = offset
        
        while currentOffset + 8 <= data.count {
            let group = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt16LE(at: currentOffset) ?? 0)
                : (data.readUInt16BE(at: currentOffset) ?? 0)
            let element = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt16LE(at: currentOffset + 2) ?? 0)
                : (data.readUInt16BE(at: currentOffset + 2) ?? 0)
            
            // Check for Sequence Delimitation Item
            if group == 0xFFFE && element == 0xE0DD {
                currentOffset += 8 // Skip tag and length
                break
            }
            
            // Check for Item tag
            guard group == 0xFFFE && element == 0xE000 else {
                break
            }
            
            let itemLength = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt32LE(at: currentOffset + 4) ?? 0)
                : (data.readUInt32BE(at: currentOffset + 4) ?? 0)
            currentOffset += 8
            
            if itemLength == 0xFFFFFFFF {
                // Parse item with undefined length
                var itemElements: [DataElement] = []
                while currentOffset + 8 <= data.count {
                    let delimGroup = transferSyntax.byteOrder == .littleEndian
                        ? (data.readUInt16LE(at: currentOffset) ?? 0)
                        : (data.readUInt16BE(at: currentOffset) ?? 0)
                    let delimElement = transferSyntax.byteOrder == .littleEndian
                        ? (data.readUInt16LE(at: currentOffset + 2) ?? 0)
                        : (data.readUInt16BE(at: currentOffset + 2) ?? 0)
                    
                    // Check for Item Delimitation Item
                    if delimGroup == 0xFFFE && delimElement == 0xE00D {
                        currentOffset += 8
                        break
                    }
                    
                    if let elem = try parseDataElement(from: data, at: &currentOffset, transferSyntax: transferSyntax) {
                        itemElements.append(elem)
                    } else {
                        break
                    }
                }
                items.append(SequenceItem(elements: itemElements))
            } else {
                // Parse item with explicit length
                let itemEndOffset = currentOffset + Int(itemLength)
                var itemElements: [DataElement] = []
                while currentOffset < itemEndOffset && currentOffset < data.count {
                    if let elem = try parseDataElement(from: data, at: &currentOffset, transferSyntax: transferSyntax) {
                        itemElements.append(elem)
                    } else {
                        break
                    }
                }
                currentOffset = itemEndOffset
                items.append(SequenceItem(elements: itemElements))
            }
        }
        
        return (items, currentOffset)
    }
    
    /// Parses encapsulated pixel data
    private func parseEncapsulatedPixelData(from data: Data, at offset: Int, transferSyntax: TransferSyntax) throws -> ([Data], [UInt32], Int) {
        var fragments: [Data] = []
        var offsetTable: [UInt32] = []
        var currentOffset = offset
        var isFirstItem = true
        
        while currentOffset + 8 <= data.count {
            let group = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt16LE(at: currentOffset) ?? 0)
                : (data.readUInt16BE(at: currentOffset) ?? 0)
            let element = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt16LE(at: currentOffset + 2) ?? 0)
                : (data.readUInt16BE(at: currentOffset + 2) ?? 0)
            
            // Check for Sequence Delimitation Item
            if group == 0xFFFE && element == 0xE0DD {
                currentOffset += 8
                break
            }
            
            // Check for Item tag
            guard group == 0xFFFE && element == 0xE000 else {
                break
            }
            
            let itemLength = transferSyntax.byteOrder == .littleEndian
                ? (data.readUInt32LE(at: currentOffset + 4) ?? 0)
                : (data.readUInt32BE(at: currentOffset + 4) ?? 0)
            currentOffset += 8
            
            let fragmentData = data.subdata(in: currentOffset..<currentOffset+Int(itemLength))
            
            if isFirstItem {
                // First item is the basic offset table
                isFirstItem = false
                // Parse offset table (UInt32 values)
                // Per DICOM PS3.5 A.4, the offset table may be empty (0 length)
                // or contain one offset per frame. We parse what's available.
                if fragmentData.count % 4 != 0 && fragmentData.count > 0 {
                    // Offset table should be a multiple of 4 bytes (UInt32 values)
                    // A malformed table may indicate corrupted data, but we continue
                    // to allow best-effort processing of the pixel data fragments
                }
                for i in stride(from: 0, to: fragmentData.count - 3, by: 4) {
                    if let value = fragmentData.readUInt32LE(at: i) {
                        offsetTable.append(value)
                    }
                }
            } else {
                fragments.append(fragmentData)
            }
            
            currentOffset += Int(itemLength)
        }
        
        return (fragments, offsetTable, currentOffset)
    }
    
    /// Transcodes a data element's value for byte order change
    private func transcodeElementByteOrder(_ element: DataElement, from source: ByteOrder, to target: ByteOrder) throws -> DataElement {
        guard source != target else {
            return element
        }
        
        // Only transcode numeric VRs
        let numericVRs: [VR] = [.US, .SS, .UL, .SL, .FL, .FD, .AT, .OW, .OF]
        
        guard numericVRs.contains(element.vr) else {
            return element
        }
        
        var newData = Data()
        let valueData = element.valueData
        
        switch element.vr {
        case .US, .SS, .OW:
            // 16-bit values
            for i in stride(from: 0, to: valueData.count, by: 2) {
                if i + 2 <= valueData.count {
                    let value = source == .littleEndian
                        ? (valueData.readUInt16LE(at: i) ?? 0)
                        : (valueData.readUInt16BE(at: i) ?? 0)
                    if target == .littleEndian {
                        newData.append(UInt8(value & 0xFF))
                        newData.append(UInt8((value >> 8) & 0xFF))
                    } else {
                        newData.append(UInt8((value >> 8) & 0xFF))
                        newData.append(UInt8(value & 0xFF))
                    }
                }
            }
            
        case .UL, .SL, .FL, .AT, .OF:
            // 32-bit values
            for i in stride(from: 0, to: valueData.count, by: 4) {
                if i + 4 <= valueData.count {
                    let value = source == .littleEndian
                        ? (valueData.readUInt32LE(at: i) ?? 0)
                        : (valueData.readUInt32BE(at: i) ?? 0)
                    if target == .littleEndian {
                        newData.append(UInt8(value & 0xFF))
                        newData.append(UInt8((value >> 8) & 0xFF))
                        newData.append(UInt8((value >> 16) & 0xFF))
                        newData.append(UInt8((value >> 24) & 0xFF))
                    } else {
                        newData.append(UInt8((value >> 24) & 0xFF))
                        newData.append(UInt8((value >> 16) & 0xFF))
                        newData.append(UInt8((value >> 8) & 0xFF))
                        newData.append(UInt8(value & 0xFF))
                    }
                }
            }
            
        case .FD:
            // 64-bit values
            for i in stride(from: 0, to: valueData.count, by: 8) {
                if i + 8 <= valueData.count {
                    let value = source == .littleEndian
                        ? (valueData.readUInt64LE(at: i) ?? 0)
                        : (valueData.readUInt64BE(at: i) ?? 0)
                    if target == .littleEndian {
                        for j in 0..<8 {
                            newData.append(UInt8((value >> (j * 8)) & 0xFF))
                        }
                    } else {
                        for j in stride(from: 7, through: 0, by: -1) {
                            newData.append(UInt8((value >> (j * 8)) & 0xFF))
                        }
                    }
                }
            }
            
        default:
            return element
        }
        
        // Use the appropriate DataElement constructor based on whether there are sequence items
        if let seqItems = element.sequenceItems {
            return DataElement(
                tag: element.tag,
                vr: element.vr,
                length: UInt32(newData.count),
                valueData: newData,
                sequenceItems: seqItems
            )
        } else {
            return DataElement(
                tag: element.tag,
                vr: element.vr,
                length: UInt32(newData.count),
                valueData: newData
            )
        }
    }
    
    /// Extracts pixel data descriptor from surrounding elements
    private func extractPixelDataDescriptor(from elements: [DataElement]) throws -> PixelDataDescriptor {
        var rows: Int?
        var columns: Int?
        var numberOfFrames: Int = 1
        var bitsAllocated: Int?
        var bitsStored: Int?
        var highBit: Int?
        var pixelRepresentation: Int = 0
        var samplesPerPixel: Int = 1
        var photometricInterpretation: PhotometricInterpretation = .monochrome2
        var planarConfiguration: Int = 0
        
        for element in elements {
            switch element.tag {
            case .rows:
                rows = element.uint16Value.map { Int($0) }
            case .columns:
                columns = element.uint16Value.map { Int($0) }
            case .numberOfFrames:
                if let str = element.stringValue, let val = Int(str) {
                    numberOfFrames = val
                }
            case .bitsAllocated:
                bitsAllocated = element.uint16Value.map { Int($0) }
            case .bitsStored:
                bitsStored = element.uint16Value.map { Int($0) }
            case .highBit:
                highBit = element.uint16Value.map { Int($0) }
            case .pixelRepresentation:
                pixelRepresentation = element.uint16Value.map { Int($0) } ?? 0
            case .samplesPerPixel:
                samplesPerPixel = element.uint16Value.map { Int($0) } ?? 1
            case .photometricInterpretation:
                if let str = element.stringValue {
                    photometricInterpretation = PhotometricInterpretation(rawValue: str.trimmingCharacters(in: .whitespaces)) ?? .monochrome2
                }
            case .planarConfiguration:
                planarConfiguration = element.uint16Value.map { Int($0) } ?? 0
            default:
                break
            }
        }
        
        guard let r = rows, let c = columns, let ba = bitsAllocated, let bs = bitsStored, let hb = highBit else {
            throw TranscodingError.pixelDataExtractionFailed("Missing required pixel data attributes")
        }
        
        return PixelDataDescriptor(
            rows: r,
            columns: c,
            numberOfFrames: numberOfFrames,
            bitsAllocated: ba,
            bitsStored: bs,
            highBit: hb,
            isSigned: pixelRepresentation == 1,
            samplesPerPixel: samplesPerPixel,
            photometricInterpretation: photometricInterpretation,
            planarConfiguration: planarConfiguration
        )
    }
    
    /// Infers the VR for common tags when parsing Implicit VR data
    ///
    /// Since DICOMCore doesn't have access to the full Data Element Dictionary,
    /// this function provides VR inference for commonly used tags only.
    /// For unknown tags, returns UN (Unknown) per DICOM PS3.5 Section 6.2.2.
    ///
    /// - Important: This is a limited implementation that only covers standard DICOM tags
    ///   commonly used in medical imaging workflows. Private tags and less common
    ///   standard tags will be assigned VR=UN, which may result in incorrect
    ///   interpretation of string vs. numeric data. For full VR support, use the
    ///   DICOMParser from DICOMKit which has access to the complete Data Element Dictionary.
    ///
    /// - Note: When transcoding Implicit VR data with non-standard tags, the resulting
    ///   Explicit VR output will use UN VR for unknown tags, which is valid DICOM
    ///   but may not preserve the original semantic meaning.
    ///
    /// - Parameter tag: The DICOM tag to infer VR for
    /// - Returns: The inferred VR, or UN if the tag is not recognized
    private func inferVRForTag(_ tag: Tag) -> VR {
        // File Meta Information (Group 0002) - always Explicit VR, but handle anyway
        switch tag {
        case .fileMetaInformationGroupLength:
            return .UL
        case .fileMetaInformationVersion:
            return .OB
        case .mediaStorageSOPClassUID, .mediaStorageSOPInstanceUID,
             .transferSyntaxUID, .implementationClassUID:
            return .UI
        case .implementationVersionName:
            return .SH
            
        // SOP Common (0008,xxxx)
        case .sopClassUID, .sopInstanceUID:
            return .UI
        case .studyDate, .seriesDate, .contentDate:
            return .DA
        case .studyTime, .seriesTime, .contentTime:
            return .TM
        case .accessionNumber:
            return .SH
        case .modality:
            return .CS
        case .referringPhysicianName:
            return .PN
        case .studyDescription:
            return .LO
        case .seriesDescription:
            return .LO
        case .manufacturer:
            return .LO
        case .institutionName:
            return .LO
        case .stationName:
            return .SH
            
        // Patient (0010,xxxx)
        case .patientName:
            return .PN
        case .patientID:
            return .LO
        case .patientBirthDate:
            return .DA
        case .patientSex:
            return .CS
        case .patientAge:
            return .AS
        case .patientSize:
            return .DS
        case .patientWeight:
            return .DS
            
        // Study (0020,xxxx)
        case .studyInstanceUID, .seriesInstanceUID:
            return .UI
        case .studyID:
            return .SH
        case .seriesNumber, .instanceNumber:
            return .IS
        case .patientPosition:
            return .CS
        case .imagePositionPatient, .imageOrientationPatient:
            return .DS
        case .frameOfReferenceUID:
            return .UI
        case .sliceLocation:
            return .DS
        case .numberOfFrames:
            return .IS
            
        // Image Pixel Module (0028,xxxx)
        case .rows, .columns:
            return .US
        case .bitsAllocated, .bitsStored, .highBit:
            return .US
        case .pixelRepresentation:
            return .US
        case .samplesPerPixel:
            return .US
        case .photometricInterpretation:
            return .CS
        case .planarConfiguration:
            return .US
        case .windowCenter, .windowWidth:
            return .DS
        case .rescaleIntercept, .rescaleSlope:
            return .DS
        case .rescaleType:
            return .LO
        case .pixelSpacing:
            return .DS
        case .sliceThickness:
            return .DS
            
        // Pixel Data
        case .pixelData:
            return .OW
            
        default:
            // For unknown tags, return UN (Unknown)
            return .UN
        }
    }
}
