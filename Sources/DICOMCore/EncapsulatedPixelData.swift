import Foundation

/// DICOM Encapsulated Pixel Data
///
/// Represents compressed/encapsulated pixel data extracted from a DICOM file.
/// Encapsulated pixel data consists of fragments stored in an Item/Delimiter structure.
///
/// Reference: DICOM PS3.5 Section A.4 - Transfer Syntaxes For Encapsulation of Encoded Pixel Data
public struct EncapsulatedPixelData: Sendable, Equatable {
    /// The Basic Offset Table containing byte offsets to each frame
    ///
    /// The offset table is stored in the first Item of the encapsulated pixel data.
    /// Each offset is a 4-byte little-endian unsigned integer.
    /// May be empty if the encoder did not provide offset information.
    ///
    /// Reference: PS3.5 Section A.4 - Table A.4-1
    public let offsetTable: [UInt32]
    
    /// The pixel data fragments
    ///
    /// Each fragment contains a portion of the compressed image data.
    /// For single-frame images, there is typically one fragment.
    /// For multi-frame images, there may be one or more fragments per frame.
    ///
    /// Reference: PS3.5 Section A.4
    public let fragments: [Data]
    
    /// Descriptor containing pixel data attributes
    public let descriptor: PixelDataDescriptor
    
    /// Creates a new EncapsulatedPixelData instance
    /// - Parameters:
    ///   - offsetTable: Byte offsets to each frame (may be empty)
    ///   - fragments: Compressed pixel data fragments
    ///   - descriptor: Pixel data descriptor
    public init(offsetTable: [UInt32], fragments: [Data], descriptor: PixelDataDescriptor) {
        self.offsetTable = offsetTable
        self.fragments = fragments
        self.descriptor = descriptor
    }
    
    // MARK: - Frame Access
    
    /// Returns the fragment data for a specific frame
    ///
    /// When an offset table is present, uses it to locate frame boundaries.
    /// When no offset table is present and there's one fragment per frame, 
    /// returns the corresponding fragment.
    /// For single-frame images with multiple fragments, concatenates all fragments.
    ///
    /// - Parameter frameIndex: Zero-based frame index
    /// - Returns: Data for the specified frame, or nil if index is out of bounds
    public func frameData(at frameIndex: Int) -> Data? {
        guard frameIndex >= 0 && frameIndex < descriptor.numberOfFrames else {
            return nil
        }
        
        // Case 1: Using a complete Basic Offset Table. A non-empty but
        // incomplete table is invalid and must not fall through to guessing.
        if !offsetTable.isEmpty {
            guard offsetTable.count == descriptor.numberOfFrames else {
                return nil
            }
            return extractFrameUsingOffsetTable(at: frameIndex)
        }
        
        // Case 2: One fragment per frame
        if fragments.count == descriptor.numberOfFrames {
            return fragments[frameIndex]
        }
        
        // Case 3: Single-frame image - concatenate all fragments
        if descriptor.numberOfFrames == 1 && !fragments.isEmpty {
            var combined = Data()
            for fragment in fragments {
                combined.append(fragment)
            }
            return combined
        }
        
        // Multi-frame data with neither a usable offset table nor exactly one
        // fragment per frame is ambiguous. Fail closed instead of guessing.
        return nil
    }
    
    /// Returns all fragments as a single concatenated Data
    ///
    /// Useful for codecs that need the complete compressed stream.
    public var allFragmentData: Data {
        var combined = Data()
        for fragment in fragments {
            combined.append(fragment)
        }
        return combined
    }
    
    /// The total number of fragments
    public var fragmentCount: Int {
        fragments.count
    }
    
    /// Whether an offset table is present
    public var hasOffsetTable: Bool {
        !offsetTable.isEmpty
    }
    
    // MARK: - Private Helpers
    
    /// Extracts frame data using the offset table
    private func extractFrameUsingOffsetTable(at frameIndex: Int) -> Data? {
        guard frameIndex < offsetTable.count, offsetTable.first == 0 else {
            return nil
        }

        // BOT offsets point to Item tags, so every frame must begin exactly at
        // a fragment boundary. Build that boundary map with UInt64 arithmetic
        // to avoid overflow while validating UInt32 BOT entries.
        var fragmentIndexByOffset: [UInt64: Int] = [:]
        var currentOffset: UInt64 = 0
        for (index, fragment) in fragments.enumerated() {
            fragmentIndexByOffset[currentOffset] = index
            let paddedLength = fragment.count + (fragment.count.isMultiple(of: 2) ? 0 : 1)
            currentOffset += 8 + UInt64(paddedLength)
        }

        var frameStartIndices: [Int] = []
        frameStartIndices.reserveCapacity(offsetTable.count)
        var previousIndex = -1
        for offset in offsetTable {
            guard let fragmentIndex = fragmentIndexByOffset[UInt64(offset)],
                  fragmentIndex > previousIndex else {
                return nil
            }
            frameStartIndices.append(fragmentIndex)
            previousIndex = fragmentIndex
        }

        let startIndex = frameStartIndices[frameIndex]
        let endIndex = frameIndex + 1 < frameStartIndices.count
            ? frameStartIndices[frameIndex + 1]
            : fragments.count
        guard startIndex < endIndex else {
            return nil
        }

        var frameData = Data()
        for fragment in fragments[startIndex..<endIndex] {
            frameData.append(fragment)
        }
        return frameData.isEmpty ? nil : frameData
    }
}

// MARK: - Encapsulated Pixel Data Fragment

/// A single fragment of encapsulated pixel data
///
/// Reference: PS3.5 Section A.4
public struct PixelDataFragment: Sendable, Equatable {
    /// The raw fragment data
    public let data: Data
    
    /// Creates a new fragment
    /// - Parameter data: The fragment data
    public init(data: Data) {
        self.data = data
    }
}
