import Foundation

/// Protocol for abstracting data source access
/// Allows for both in-memory and memory-mapped file access
protocol DataSource: Sendable {
    /// Total size of the data source in bytes
    var count: Int { get }
    
    /// Read a subsequence of bytes from the data source
    ///
    /// - Parameter range: The range of bytes to read
    /// - Returns: The requested bytes, or nil if range is out of bounds
    func subdata(in range: Range<Int>) -> Data?
    
    /// Read a single byte at the specified offset
    ///
    /// - Parameter offset: The byte offset
    /// - Returns: The byte value, or nil if offset is out of bounds
    func byte(at offset: Int) -> UInt8?
}

/// In-memory data source backed by Foundation Data
struct MemoryDataSource: DataSource {
    private let data: Data
    
    var count: Int {
        data.count
    }
    
    init(data: Data) {
        self.data = data
    }
    
    func subdata(in range: Range<Int>) -> Data? {
        guard range.lowerBound >= 0, range.upperBound <= data.count else {
            return nil
        }
        return data.subdata(in: range)
    }
    
    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else {
            return nil
        }
        return data[offset]
    }
}

/// Memory-mapped file data source for large files
/// Provides efficient random access without loading entire file into memory
final class MemoryMappedDataSource: DataSource, @unchecked Sendable {
    private let fileHandle: FileHandle
    private let fileSize: Int
    private let url: URL
    
    var count: Int {
        fileSize
    }
    
    init(url: URL) throws {
        self.url = url
        
        // Open file for reading
        self.fileHandle = try FileHandle(forReadingFrom: url)
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? Int else {
            throw DICOMError.parsingFailed("Could not determine file size")
        }
        self.fileSize = size
    }
    
    deinit {
        try? fileHandle.close()
    }
    
    func subdata(in range: Range<Int>) -> Data? {
        guard range.lowerBound >= 0, range.upperBound <= fileSize else {
            return nil
        }
        
        do {
            try fileHandle.seek(toOffset: UInt64(range.lowerBound))
            let length = range.upperBound - range.lowerBound
            
            guard let data = try fileHandle.read(upToCount: length),
                  data.count == length else {
                return nil
            }
            
            return data
        } catch {
            return nil
        }
    }
    
    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < fileSize else {
            return nil
        }
        
        do {
            try fileHandle.seek(toOffset: UInt64(offset))
            guard let data = try fileHandle.read(upToCount: 1),
                  data.count == 1 else {
                return nil
            }
            return data[0]
        } catch {
            return nil
        }
    }
}

/// Extensions to Data for ByteOrder-aware reading from DataSource
extension DataSource {
    /// Read UInt16 value at specified offset with given byte order
    func readUInt16(at offset: Int, byteOrder: ByteOrder) -> UInt16? {
        guard let data = subdata(in: offset..<offset + 2),
              data.count == 2 else {
            return nil
        }
        
        return byteOrder == .littleEndian ? data.readUInt16LE(at: 0) : data.readUInt16BE(at: 0)
    }
    
    /// Read UInt32 value at specified offset with given byte order
    func readUInt32(at offset: Int, byteOrder: ByteOrder) -> UInt32? {
        guard let data = subdata(in: offset..<offset + 4),
              data.count == 4 else {
            return nil
        }
        
        return byteOrder == .littleEndian ? data.readUInt32LE(at: 0) : data.readUInt32BE(at: 0)
    }
}
