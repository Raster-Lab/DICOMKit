import Foundation

/// RLE Lossless codec (pure Swift implementation)
///
/// Decodes Run-Length Encoded pixel data as specified in DICOM PS3.5 Annex G.
/// Reference: DICOM PS3.5 Annex G - RLE Transfer Syntax
public struct RLECodec: ImageCodec, Sendable {
    /// Supported RLE transfer syntax
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.rleLossless.uid  // 1.2.840.10008.1.2.5
    ]
    
    public init() {}
    
    /// Decodes an RLE-compressed frame
    /// - Parameters:
    ///   - frameData: RLE compressed data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Frame index (unused for single frame decode)
    /// - Returns: Uncompressed pixel data
    /// - Throws: DICOMError if decoding fails
    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        guard frameData.count >= 64 else {
            throw DICOMError.parsingFailed("RLE data too short for header")
        }
        
        // Parse RLE header (64 bytes)
        // First 4 bytes: number of segments
        // Next 60 bytes: 15 segment offset values (4 bytes each)
        let numberOfSegments = Int(frameData.readUInt32LE(at: 0) ?? 0)
        
        guard numberOfSegments >= 1 && numberOfSegments <= 15 else {
            throw DICOMError.parsingFailed("Invalid RLE segment count: \(numberOfSegments)")
        }
        
        // Read segment offsets
        var segmentOffsets: [Int] = []
        for i in 0..<numberOfSegments {
            let offset = Int(frameData.readUInt32LE(at: 4 + i * 4) ?? 0)
            segmentOffsets.append(offset)
        }
        
        // Calculate expected output size
        let bytesPerSample = descriptor.bytesPerSample
        let samplesPerPixel = descriptor.samplesPerPixel
        let pixelsPerFrame = descriptor.pixelsPerFrame
        let expectedSegments = bytesPerSample * samplesPerPixel
        
        guard numberOfSegments == expectedSegments else {
            throw DICOMError.parsingFailed("Unexpected number of RLE segments: \(numberOfSegments), expected \(expectedSegments)")
        }
        
        // Decode each segment
        var decodedSegments: [Data] = []
        for i in 0..<numberOfSegments {
            let segmentStart = segmentOffsets[i]
            let segmentEnd: Int
            
            if i + 1 < numberOfSegments {
                segmentEnd = segmentOffsets[i + 1]
            } else {
                segmentEnd = frameData.count
            }
            
            guard segmentStart < segmentEnd && segmentEnd <= frameData.count else {
                throw DICOMError.parsingFailed("Invalid RLE segment boundaries")
            }
            
            let segmentData = frameData.subdata(in: segmentStart..<segmentEnd)
            let decoded = try decodeRLESegment(segmentData, expectedLength: pixelsPerFrame)
            decodedSegments.append(decoded)
        }
        
        // Interleave segments to form output
        return interleaveSegments(decodedSegments, descriptor: descriptor)
    }
    
    /// Decodes a single RLE segment
    ///
    /// RLE encoding uses a control byte followed by data:
    /// - If n >= 0 and n <= 127: copy the next n+1 bytes literally
    /// - If n >= -127 and n <= -1: repeat the next byte -n+1 times
    /// - If n == -128: no operation (skip)
    ///
    /// Reference: PS3.5 Annex G.3
    private func decodeRLESegment(_ data: Data, expectedLength: Int) throws -> Data {
        var output = Data()
        output.reserveCapacity(expectedLength)
        
        var offset = 0
        
        while offset < data.count && output.count < expectedLength {
            let controlByte = Int8(bitPattern: data[offset])
            offset += 1
            
            if controlByte == -128 {
                // No operation - skip
                continue
            } else if controlByte >= 0 {
                // Literal run: copy next n+1 bytes
                let count = Int(controlByte) + 1
                guard offset + count <= data.count else {
                    throw DICOMError.parsingFailed("RLE literal run exceeds data bounds")
                }
                
                for i in 0..<count {
                    if output.count < expectedLength {
                        output.append(data[offset + i])
                    }
                }
                offset += count
            } else {
                // Repeat run: repeat next byte -n+1 times
                let count = Int(-controlByte) + 1
                guard offset < data.count else {
                    throw DICOMError.parsingFailed("RLE repeat run missing byte value")
                }
                
                let repeatByte = data[offset]
                offset += 1
                
                for _ in 0..<count {
                    if output.count < expectedLength {
                        output.append(repeatByte)
                    }
                }
            }
        }
        
        // Pad with zeros if needed
        while output.count < expectedLength {
            output.append(0)
        }
        
        return output
    }
    
    /// Interleaves decoded segments into the final pixel data
    ///
    /// For multi-byte samples, high-order bytes come first in separate segments.
    /// For multi-sample pixels (e.g., RGB), each sample component is in a separate segment.
    ///
    /// Reference: PS3.5 Annex G.2
    private func interleaveSegments(_ segments: [Data], descriptor: PixelDataDescriptor) -> Data {
        let bytesPerSample = descriptor.bytesPerSample
        let samplesPerPixel = descriptor.samplesPerPixel
        let pixelsPerFrame = descriptor.pixelsPerFrame
        let bytesPerFrame = descriptor.bytesPerFrame
        
        var output = Data(count: bytesPerFrame)
        
        for pixelIndex in 0..<pixelsPerFrame {
            for sampleIndex in 0..<samplesPerPixel {
                for byteIndex in 0..<bytesPerSample {
                    // Segment index: high-order bytes first within each sample
                    let segmentIndex = sampleIndex * bytesPerSample + (bytesPerSample - 1 - byteIndex)
                    
                    guard segmentIndex < segments.count else {
                        continue
                    }
                    
                    let segment = segments[segmentIndex]
                    guard pixelIndex < segment.count else {
                        continue
                    }
                    
                    // Output offset
                    let outputOffset: Int
                    if descriptor.planarConfiguration == 0 || samplesPerPixel == 1 {
                        // Color-by-pixel or monochrome
                        outputOffset = (pixelIndex * samplesPerPixel + sampleIndex) * bytesPerSample + byteIndex
                    } else {
                        // Color-by-plane
                        let planeSize = pixelsPerFrame * bytesPerSample
                        outputOffset = sampleIndex * planeSize + pixelIndex * bytesPerSample + byteIndex
                    }
                    
                    if outputOffset < output.count {
                        output[outputOffset] = segment[pixelIndex]
                    }
                }
            }
        }
        
        return output
    }
}
