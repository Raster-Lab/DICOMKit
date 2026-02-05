import Foundation

/// Options for controlling DICOM file parsing behavior
public struct ParsingOptions: Sendable {
    /// Parsing mode that determines which elements are parsed
    public enum Mode: Sendable {
        /// Parse all elements including pixel data (default)
        case full
        
        /// Parse metadata only, skip pixel data entirely
        /// Significantly faster for queries and metadata extraction
        case metadataOnly
        
        /// Parse tags up to pixel data, but don't load pixel data value
        /// Allows accessing pixel data attributes without loading the actual pixels
        case lazyPixelData
    }
    
    /// The parsing mode to use
    public let mode: Mode
    
    /// Stop parsing after encountering the specified tag
    /// Useful for partial file parsing when only specific attributes are needed
    public let stopAfterTag: Tag?
    
    /// Maximum number of elements to parse
    /// Useful for limiting memory usage on very large files
    public let maxElements: Int?
    
    /// Whether to use memory-mapped file access for large files
    /// More memory-efficient for files > 100MB
    public let useMemoryMapping: Bool
    
    /// Default parsing options (full parsing)
    public static let `default` = ParsingOptions()
    
    /// Metadata-only parsing options
    public static let metadataOnly = ParsingOptions(mode: .metadataOnly)
    
    /// Lazy pixel data parsing options
    public static let lazyPixelData = ParsingOptions(mode: .lazyPixelData)
    
    /// Memory-mapped parsing options for large files
    public static let memoryMapped = ParsingOptions(useMemoryMapping: true)
    
    public init(
        mode: Mode = .full,
        stopAfterTag: Tag? = nil,
        maxElements: Int? = nil,
        useMemoryMapping: Bool = false
    ) {
        self.mode = mode
        self.stopAfterTag = stopAfterTag
        self.maxElements = maxElements
        self.useMemoryMapping = useMemoryMapping
    }
}
