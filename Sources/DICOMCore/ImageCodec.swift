import Foundation

// MARK: - Compression Configuration

/// Quality preset for image compression
///
/// Controls the tradeoff between compression ratio and image quality.
/// Higher quality results in larger file sizes but better visual fidelity.
public enum CompressionQuality: Sendable, Hashable, Codable {
    /// Maximum quality, minimal compression (quality 0.98)
    case maximum
    
    /// High quality with good compression (quality 0.90)
    case high
    
    /// Medium quality for balanced results (quality 0.75)
    case medium
    
    /// Lower quality for maximum compression (quality 0.60)
    case low
    
    /// Custom quality value (0.0 to 1.0, where 1.0 is highest quality)
    case custom(Double)
    
    /// The numeric quality value (0.0 to 1.0)
    public var value: Double {
        switch self {
        case .maximum:
            return 0.98
        case .high:
            return 0.90
        case .medium:
            return 0.75
        case .low:
            return 0.60
        case .custom(let value):
            return max(0.0, min(1.0, value))
        }
    }
    
    /// Whether this quality setting produces lossless output (only for maximum with compatible formats)
    public var isLossless: Bool {
        switch self {
        case .maximum:
            return true
        case .custom(let value):
            return value >= 1.0
        default:
            return false
        }
    }
}

extension CompressionQuality: CustomStringConvertible {
    public var description: String {
        switch self {
        case .maximum:
            return "Maximum (lossless where supported)"
        case .high:
            return "High (~90%)"
        case .medium:
            return "Medium (~75%)"
        case .low:
            return "Low (~60%)"
        case .custom(let value):
            return "Custom (\(Int(value * 100))%)"
        }
    }
}

/// Speed preset for compression
///
/// Controls the tradeoff between compression speed and compression ratio.
/// Faster speeds may result in slightly larger file sizes.
public enum CompressionSpeed: Sendable, Hashable, Codable {
    /// Fastest compression, may sacrifice some compression ratio
    case fast
    
    /// Balanced speed and compression ratio
    case balanced
    
    /// Maximum compression ratio, slower processing
    case optimal
}

extension CompressionSpeed: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .optimal:
            return "Optimal"
        }
    }
}

/// Configuration for image compression operations
///
/// Specifies quality, speed, and format-specific options for encoding pixel data.
/// Reference: DICOM PS3.5 Annex A - Transfer Syntax Specifications
public struct CompressionConfiguration: Sendable, Hashable {
    /// Quality preset for compression
    public let quality: CompressionQuality
    
    /// Speed preset for compression
    public let speed: CompressionSpeed
    
    /// Whether to use progressive encoding (JPEG only)
    ///
    /// Progressive images load in multiple passes, showing a low-resolution
    /// version first then refining. Better for network streaming.
    public let progressive: Bool
    
    /// Whether to prefer lossless compression when available
    ///
    /// If true and the target format supports lossless mode, lossless
    /// compression will be used regardless of quality setting.
    public let preferLossless: Bool
    
    /// Maximum number of bits per sample (for formats that support variable bit depth)
    public let maxBitsPerSample: Int?
    
    /// Default configuration with high quality and balanced speed
    public static let `default` = CompressionConfiguration(
        quality: .high,
        speed: .balanced,
        progressive: false,
        preferLossless: false
    )
    
    /// Configuration optimized for network transfer (smaller files)
    public static let network = CompressionConfiguration(
        quality: .medium,
        speed: .fast,
        progressive: true,
        preferLossless: false
    )
    
    /// Configuration for archival (maximum quality, lossless when possible)
    public static let archival = CompressionConfiguration(
        quality: .maximum,
        speed: .optimal,
        progressive: false,
        preferLossless: true
    )
    
    /// Configuration for lossless compression
    public static let lossless = CompressionConfiguration(
        quality: .maximum,
        speed: .balanced,
        progressive: false,
        preferLossless: true
    )
    
    /// Creates a compression configuration
    ///
    /// - Parameters:
    ///   - quality: Quality preset (default: .high)
    ///   - speed: Speed preset (default: .balanced)
    ///   - progressive: Use progressive encoding for JPEG (default: false)
    ///   - preferLossless: Prefer lossless when available (default: false)
    ///   - maxBitsPerSample: Maximum bits per sample (default: nil, use source)
    public init(
        quality: CompressionQuality = .high,
        speed: CompressionSpeed = .balanced,
        progressive: Bool = false,
        preferLossless: Bool = false,
        maxBitsPerSample: Int? = nil
    ) {
        self.quality = quality
        self.speed = speed
        self.progressive = progressive
        self.preferLossless = preferLossless
        self.maxBitsPerSample = maxBitsPerSample
    }
}

extension CompressionConfiguration: CustomStringConvertible {
    public var description: String {
        var parts = ["quality=\(quality)", "speed=\(speed)"]
        if progressive { parts.append("progressive") }
        if preferLossless { parts.append("preferLossless") }
        if let maxBits = maxBitsPerSample { parts.append("maxBits=\(maxBits)") }
        return "CompressionConfiguration(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Image Codec Protocol

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

// MARK: - Image Encoder Protocol

/// Protocol for DICOM image compression encoders
///
/// Encoders compress uncompressed pixel data to a specific format.
/// Not all codecs support encoding - only those that implement this protocol.
/// Reference: DICOM PS3.5 Annex A - Transfer Syntax Specifications
public protocol ImageEncoder: Sendable {
    /// The transfer syntax UIDs this encoder can produce
    static var supportedEncodingTransferSyntaxes: [String] { get }
    
    /// Whether this encoder supports the given configuration
    /// - Parameters:
    ///   - configuration: Compression configuration
    ///   - descriptor: Pixel data descriptor
    /// - Returns: True if encoding is supported with these parameters
    func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool
    
    /// Encodes uncompressed pixel data to compressed format
    /// - Parameters:
    ///   - data: Uncompressed pixel data
    ///   - descriptor: Pixel data descriptor
    ///   - configuration: Compression configuration
    /// - Returns: Compressed pixel data as encapsulated fragments (one per frame)
    /// - Throws: DICOMError if encoding fails
    func encode(_ data: Data, descriptor: PixelDataDescriptor, configuration: CompressionConfiguration) throws -> [Data]
    
    /// Encodes a single frame to compressed format
    /// - Parameters:
    ///   - frameData: Uncompressed frame data
    ///   - descriptor: Pixel data descriptor
    ///   - frameIndex: Zero-based frame index
    ///   - configuration: Compression configuration
    /// - Returns: Compressed frame data
    /// - Throws: DICOMError if encoding fails
    func encodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int, configuration: CompressionConfiguration) throws -> Data
}

// MARK: - Default Encoder Implementation

extension ImageEncoder {
    /// Default implementation encodes each frame individually
    public func encode(_ data: Data, descriptor: PixelDataDescriptor, configuration: CompressionConfiguration) throws -> [Data] {
        let bytesPerFrame = descriptor.bytesPerFrame
        let numberOfFrames = descriptor.numberOfFrames
        
        var compressedFrames: [Data] = []
        compressedFrames.reserveCapacity(numberOfFrames)
        
        for frameIndex in 0..<numberOfFrames {
            let frameStart = frameIndex * bytesPerFrame
            let frameEnd = min(frameStart + bytesPerFrame, data.count)
            
            guard frameStart < data.count else {
                throw DICOMError.parsingFailed("Frame \(frameIndex) starts beyond data bounds")
            }
            
            let frameData = data.subdata(in: frameStart..<frameEnd)
            let compressedFrame = try encodeFrame(frameData, descriptor: descriptor, frameIndex: frameIndex, configuration: configuration)
            compressedFrames.append(compressedFrame)
        }
        
        return compressedFrames
    }
}

// MARK: - Default Implementation

extension ImageCodec {
    /// Default implementation decodes all data at once
    public func decode(_ data: Data, descriptor: PixelDataDescriptor) throws -> Data {
        // Default implementation for single-frame or when all frames can be decoded together
        return try decodeFrame(data, descriptor: descriptor, frameIndex: 0)
    }
}

/// Registry for managing image codecs and encoders
///
/// Provides access to codecs for different transfer syntaxes.
/// Uses platform-native codecs when available.
public struct CodecRegistry: Sendable {
    /// Shared codec registry instance
    public static let shared = CodecRegistry()
    
    /// Registered codecs (for decoding)
    private let codecs: [String: any ImageCodec]
    
    /// Registered encoders (for encoding)
    private let encoders: [String: any ImageEncoder]
    
    /// Creates a codec registry with default codecs
    private init() {
        var decoderRegistry: [String: any ImageCodec] = [:]
        var encoderRegistry: [String: any ImageEncoder] = [:]
        
        // Register platform-native codecs
        #if canImport(ImageIO)
        // JPEG codecs (decode and encode)
        let jpegCodec = NativeJPEGCodec()
        for uid in NativeJPEGCodec.supportedTransferSyntaxes {
            decoderRegistry[uid] = jpegCodec
        }
        for uid in NativeJPEGCodec.supportedEncodingTransferSyntaxes {
            encoderRegistry[uid] = jpegCodec
        }
        
        // JPEG 2000 codecs (decode and encode)
        let jpeg2000Codec = NativeJPEG2000Codec()
        for uid in NativeJPEG2000Codec.supportedTransferSyntaxes {
            decoderRegistry[uid] = jpeg2000Codec
        }
        for uid in NativeJPEG2000Codec.supportedEncodingTransferSyntaxes {
            encoderRegistry[uid] = jpeg2000Codec
        }
        #endif
        
        // RLE codec (pure Swift implementation - decode only for now)
        let rleCodec = RLECodec()
        for uid in RLECodec.supportedTransferSyntaxes {
            decoderRegistry[uid] = rleCodec
        }
        
        self.codecs = decoderRegistry
        self.encoders = encoderRegistry
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
    
    /// Returns an encoder for the specified transfer syntax
    /// - Parameter transferSyntaxUID: Transfer syntax UID
    /// - Returns: Encoder if available, nil otherwise
    public func encoder(for transferSyntaxUID: String) -> (any ImageEncoder)? {
        return encoders[transferSyntaxUID]
    }
    
    /// Checks if an encoder is available for the specified transfer syntax
    /// - Parameter transferSyntaxUID: Transfer syntax UID
    /// - Returns: True if an encoder is available
    public func hasEncoder(for transferSyntaxUID: String) -> Bool {
        return encoders[transferSyntaxUID] != nil
    }
    
    /// All supported transfer syntax UIDs for decoding
    public var supportedTransferSyntaxes: [String] {
        Array(codecs.keys)
    }
    
    /// All supported transfer syntax UIDs for encoding
    public var supportedEncodingTransferSyntaxes: [String] {
        Array(encoders.keys)
    }
}
