import Foundation

/// Protocol for DICOM image compression codecs
///
/// Codecs decode compressed pixel data to uncompressed format.
/// Reference: DICOM PS3.5 Annex A - Transfer Syntax Specifications
public protocol ImageCodec: Sendable {
    /// The transfer syntax UIDs this codec supports
    static var supportedTransferSyntaxes: [String] { get }
    
    /// Decodes compressed pixel data to uncompressed format
    /// - Parameters:
    ///   - data: Compressed pixel data
    ///   - descriptor: Pixel data descriptor
    /// - Returns: Uncompressed pixel data
    /// - Throws: DICOMError if decoding fails
    func decode(_ data: Data, descriptor: PixelDataDescriptor) throws -> Data
    
    /// Decodes a single frame from compressed pixel data
    /// - Parameters:
    ///   - frameData: Compressed frame data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Zero-based frame index
    /// - Returns: Uncompressed frame data
    /// - Throws: DICOMError if decoding fails
    func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data
}

// MARK: - Default Implementation

extension ImageCodec {
    /// Default implementation decodes all data at once
    public func decode(_ data: Data, descriptor: PixelDataDescriptor) throws -> Data {
        // Default implementation for single-frame or when all frames can be decoded together
        return try decodeFrame(data, descriptor: descriptor, frameIndex: 0)
    }
}

/// Registry for managing image codecs
///
/// Provides access to codecs for different transfer syntaxes.
/// Uses platform-native codecs when available.
public struct CodecRegistry: Sendable {
    /// Shared codec registry instance
    public static let shared = CodecRegistry()
    
    /// Registered codecs
    private let codecs: [String: any ImageCodec]
    
    /// Creates a codec registry with default codecs
    private init() {
        var registry: [String: any ImageCodec] = [:]
        
        // Register platform-native codecs
        #if canImport(ImageIO)
        // JPEG codecs
        let jpegCodec = NativeJPEGCodec()
        for uid in NativeJPEGCodec.supportedTransferSyntaxes {
            registry[uid] = jpegCodec
        }
        
        // JPEG 2000 codecs
        let jpeg2000Codec = NativeJPEG2000Codec()
        for uid in NativeJPEG2000Codec.supportedTransferSyntaxes {
            registry[uid] = jpeg2000Codec
        }
        #endif
        
        // RLE codec (pure Swift implementation)
        let rleCodec = RLECodec()
        for uid in RLECodec.supportedTransferSyntaxes {
            registry[uid] = rleCodec
        }
        
        self.codecs = registry
    }
    
    /// Returns a codec for the specified transfer syntax
    /// - Parameter transferSyntaxUID: Transfer syntax UID
    /// - Returns: Codec if available, nil otherwise
    public func codec(for transferSyntaxUID: String) -> (any ImageCodec)? {
        return codecs[transferSyntaxUID]
    }
    
    /// Checks if a codec is available for the specified transfer syntax
    /// - Parameter transferSyntaxUID: Transfer syntax UID
    /// - Returns: True if a codec is available
    public func hasCodec(for transferSyntaxUID: String) -> Bool {
        return codecs[transferSyntaxUID] != nil
    }
    
    /// All supported transfer syntax UIDs
    public var supportedTransferSyntaxes: [String] {
        Array(codecs.keys)
    }
}
