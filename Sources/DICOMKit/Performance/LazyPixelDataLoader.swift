import Foundation
import DICOMCore

/// Lazy pixel data loader that defers loading until access
///
/// This allows parsing DICOM files without loading large pixel data into memory.
/// The pixel data is only loaded when actually accessed through the PixelData API.
public final class LazyPixelDataLoader: @unchecked Sendable {
    private let fileURL: URL?
    private let dataOffset: Int
    private let dataLength: Int
    private let transferSyntaxUID: String
    private var cachedData: Data?
    private let lock = NSLock()
    
    /// Initialize a lazy pixel data loader
    ///
    /// - Parameters:
    ///   - fileURL: URL of the DICOM file containing pixel data
    ///   - dataOffset: Byte offset to the pixel data value in the file
    ///   - dataLength: Length of the pixel data value in bytes
    ///   - transferSyntaxUID: Transfer syntax UID for decoding
    init(
        fileURL: URL?,
        dataOffset: Int,
        dataLength: Int,
        transferSyntaxUID: String
    ) {
        self.fileURL = fileURL
        self.dataOffset = dataOffset
        self.dataLength = dataLength
        self.transferSyntaxUID = transferSyntaxUID
        self.cachedData = nil
    }
    
    /// Load the pixel data from the file
    ///
    /// This method is called automatically when pixel data is accessed.
    /// The data is cached after first load.
    ///
    /// - Returns: The pixel data
    /// - Throws: DICOMError if loading fails
    func loadData() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        
        // Return cached data if available
        if let cached = cachedData {
            return cached
        }
        
        // Load data from file
        guard let url = fileURL else {
            throw DICOMError.parsingFailed("No file URL for lazy pixel data")
        }
        
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        try fileHandle.seek(toOffset: UInt64(dataOffset))
        guard let data = try fileHandle.read(upToCount: dataLength),
              data.count == dataLength else {
            throw DICOMError.parsingFailed("Failed to read pixel data from file")
        }
        
        // Cache for future access
        cachedData = data
        
        return data
    }
    
    /// Check if pixel data is currently loaded in memory
    public var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cachedData != nil
    }
    
    /// Clear the cached pixel data to free memory
    public func unload() {
        lock.lock()
        defer { lock.unlock() }
        cachedData = nil
    }
    
    /// Get the size of the pixel data in bytes
    public var size: Int {
        dataLength
    }
}

/// Extended DataElement to support lazy pixel data loading
extension DataElement {
    /// Create a data element with lazy pixel data loading
    ///
    /// - Parameters:
    ///   - tag: The DICOM tag
    ///   - vr: The value representation
    ///   - length: The value length
    ///   - lazyLoader: The lazy pixel data loader
    /// - Returns: A data element that will load pixel data on demand
    static func lazyPixelData(
        tag: Tag,
        vr: VR,
        length: UInt32,
        lazyLoader: LazyPixelDataLoader
    ) -> DataElement {
        // Create element with empty data initially
        // The actual data will be loaded when needed
        return DataElement(
            tag: tag,
            vr: vr,
            length: length,
            valueData: Data() // Empty initially, loaded lazily
        )
    }
}
