/// DICOM Data Element Tag
///
/// A tag uniquely identifies a data element and consists of an ordered pair
/// of 16-bit unsigned integers: group number and element number.
///
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Structure
public struct Tag: Sendable, Hashable, Comparable {
    /// Group number (16-bit unsigned integer)
    public let group: UInt16
    
    /// Element number (16-bit unsigned integer)
    public let element: UInt16
    
    /// Creates a new DICOM tag
    /// - Parameters:
    ///   - group: Group number
    ///   - element: Element number
    public init(group: UInt16, element: UInt16) {
        self.group = group
        self.element = element
    }
    
    /// Indicates whether this is a private tag
    ///
    /// Private tags have odd group numbers.
    /// Reference: PS3.5 Section 7.8 - Private Data Elements
    public var isPrivate: Bool {
        return (group & 0x0001) != 0
    }
    
    /// Comparable conformance - tags are ordered by group, then element
    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        if lhs.group != rhs.group {
            return lhs.group < rhs.group
        }
        return lhs.element < rhs.element
    }
}

// MARK: - CustomStringConvertible
extension Tag: CustomStringConvertible {
    /// Formatted string representation in (GGGG,EEEE) format
    public var description: String {
        return String(format: "(%04X,%04X)", group, element)
    }
}
