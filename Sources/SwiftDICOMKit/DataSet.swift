import Foundation

/// DICOM Data Set
///
/// A collection of data elements, representing either a File Meta Information or main data set.
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Structure
public struct DataSet: Sendable {
    private var elements: [Tag: DataElement]
    
    /// Creates an empty data set
    public init() {
        self.elements = [:]
    }
    
    /// Creates a data set from an array of data elements
    /// - Parameter elements: Array of data elements
    public init(elements: [DataElement]) {
        self.elements = Dictionary(uniqueKeysWithValues: elements.map { ($0.tag, $0) })
    }
    
    /// Accesses a data element by tag
    ///
    /// Use this subscript to get or set data elements in the data set.
    /// Setting a value to nil removes the element.
    public subscript(tag: Tag) -> DataElement? {
        get { elements[tag] }
        set {
            if let newValue = newValue {
                elements[tag] = newValue
            } else {
                elements.removeValue(forKey: tag)
            }
        }
    }
    
    /// Returns the string value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: String value or nil
    public func string(for tag: Tag) -> String? {
        return elements[tag]?.stringValue
    }
    
    /// Returns the string values for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of string values or nil
    public func strings(for tag: Tag) -> [String]? {
        return elements[tag]?.stringValues
    }
    
    /// Returns the UInt16 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: UInt16 value or nil
    public func uint16(for tag: Tag) -> UInt16? {
        return elements[tag]?.uint16Value
    }
    
    /// Returns the UInt32 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: UInt32 value or nil
    public func uint32(for tag: Tag) -> UInt32? {
        return elements[tag]?.uint32Value
    }
    
    /// Returns the UInt16 values array for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of UInt16 values or nil
    public func uint16s(for tag: Tag) -> [UInt16]? {
        return elements[tag]?.uint16Values
    }
    
    /// Returns the UInt32 values array for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of UInt32 values or nil
    public func uint32s(for tag: Tag) -> [UInt32]? {
        return elements[tag]?.uint32Values
    }
    
    /// Returns the Int16 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Int16 value or nil
    public func int16(for tag: Tag) -> Int16? {
        return elements[tag]?.int16Value
    }
    
    /// Returns the Int32 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Int32 value or nil
    public func int32(for tag: Tag) -> Int32? {
        return elements[tag]?.int32Value
    }
    
    /// Returns the Float32 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Float32 value or nil
    public func float32(for tag: Tag) -> Float32? {
        return elements[tag]?.float32Value
    }
    
    /// Returns the Float64 value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Float64 value or nil
    public func float64(for tag: Tag) -> Float64? {
        return elements[tag]?.float64Value
    }
    
    /// Returns the Float32 values array for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of Float32 values or nil
    public func float32s(for tag: Tag) -> [Float32]? {
        return elements[tag]?.float32Values
    }
    
    /// Returns the Float64 values array for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of Float64 values or nil
    public func float64s(for tag: Tag) -> [Float64]? {
        return elements[tag]?.float64Values
    }
    
    /// Number of elements in the data set
    public var count: Int {
        return elements.count
    }
    
    /// All tags in the data set
    public var tags: [Tag] {
        return Array(elements.keys).sorted()
    }
    
    /// All data elements in tag order
    public var allElements: [DataElement] {
        let sortedTags = tags
        return sortedTags.compactMap { elements[$0] }
    }
}

// MARK: - Sequence
extension DataSet: Sequence {
    public func makeIterator() -> IndexingIterator<[DataElement]> {
        return allElements.makeIterator()
    }
}
