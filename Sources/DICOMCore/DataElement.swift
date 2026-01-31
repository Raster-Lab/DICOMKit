import Foundation

/// DICOM Data Element
///
/// A data element is a unit of information as defined by a single entry in the data dictionary.
/// It consists of a tag, VR, length, and value field.
///
/// Reference: DICOM PS3.5 Section 7.1 - Data Element Structure
public struct DataElement: Sendable {
    /// Data element tag (group, element pair)
    public let tag: Tag
    
    /// Value Representation
    public let vr: VR
    
    /// Value length in bytes
    ///
    /// The value 0xFFFFFFFF (4294967295) indicates an undefined length.
    /// Reference: PS3.5 Section 7.1.2
    public let length: UInt32
    
    /// Raw value data
    public let valueData: Data
    
    /// Sequence items for SQ (Sequence) VR elements
    ///
    /// Contains the parsed sequence items when this element has VR of SQ.
    /// Each item in the array represents a single sequence item containing
    /// nested data elements.
    ///
    /// Reference: PS3.5 Section 7.5 - Nesting of Data Sets
    public let sequenceItems: [SequenceItem]?
    
    /// Encapsulated pixel data fragments for compressed pixel data
    ///
    /// When pixel data is encapsulated (compressed), the data is stored
    /// as a sequence of fragments. Each fragment is a separate Data block.
    ///
    /// Reference: PS3.5 Section A.4 - Transfer Syntaxes For Encapsulation
    public let encapsulatedFragments: [Data]?
    
    /// Basic Offset Table for encapsulated pixel data
    ///
    /// Contains byte offsets to each frame in the encapsulated pixel data.
    /// May be empty if the encoder did not provide offset information.
    ///
    /// Reference: PS3.5 Section A.4 - Table A.4-1
    public let encapsulatedOffsetTable: [UInt32]?
    
    /// Creates a new data element
    /// - Parameters:
    ///   - tag: Data element tag
    ///   - vr: Value Representation
    ///   - length: Value length (use 0xFFFFFFFF for undefined length)
    ///   - valueData: Raw value data
    public init(tag: Tag, vr: VR, length: UInt32, valueData: Data) {
        self.tag = tag
        self.vr = vr
        self.length = length
        self.valueData = valueData
        self.sequenceItems = nil
        self.encapsulatedFragments = nil
        self.encapsulatedOffsetTable = nil
    }
    
    /// Creates a new sequence data element
    /// - Parameters:
    ///   - tag: Data element tag
    ///   - vr: Value Representation (should be .SQ)
    ///   - length: Value length (use 0xFFFFFFFF for undefined length)
    ///   - valueData: Raw value data
    ///   - sequenceItems: Parsed sequence items
    public init(tag: Tag, vr: VR, length: UInt32, valueData: Data, sequenceItems: [SequenceItem]) {
        self.tag = tag
        self.vr = vr
        self.length = length
        self.valueData = valueData
        self.sequenceItems = sequenceItems
        self.encapsulatedFragments = nil
        self.encapsulatedOffsetTable = nil
    }
    
    /// Creates a new encapsulated pixel data element
    /// - Parameters:
    ///   - tag: Data element tag
    ///   - vr: Value Representation (should be .OB or .OW)
    ///   - length: Value length (typically 0xFFFFFFFF for undefined length)
    ///   - valueData: Raw value data (typically empty for encapsulated)
    ///   - encapsulatedFragments: Compressed pixel data fragments
    ///   - encapsulatedOffsetTable: Basic offset table
    public init(tag: Tag, vr: VR, length: UInt32, valueData: Data, encapsulatedFragments: [Data], encapsulatedOffsetTable: [UInt32]) {
        self.tag = tag
        self.vr = vr
        self.length = length
        self.valueData = valueData
        self.sequenceItems = nil
        self.encapsulatedFragments = encapsulatedFragments
        self.encapsulatedOffsetTable = encapsulatedOffsetTable
    }
    
    /// Indicates whether this data element has undefined length
    ///
    /// Reference: PS3.5 Section 7.1.2 - Data Element with Explicit Length
    public var hasUndefinedLength: Bool {
        return length == 0xFFFFFFFF
    }
    
    /// Indicates whether this data element is a sequence (SQ VR)
    ///
    /// Reference: PS3.5 Section 7.5 - Nesting of Data Sets
    public var isSequence: Bool {
        return vr == .SQ
    }
    
    /// Indicates whether this data element contains encapsulated pixel data
    ///
    /// Reference: PS3.5 Section A.4 - Transfer Syntaxes For Encapsulation
    public var isEncapsulated: Bool {
        return encapsulatedFragments != nil && !(encapsulatedFragments?.isEmpty ?? true)
    }
    
    /// Number of items in the sequence
    ///
    /// Returns 0 if this element is not a sequence or has no items.
    public var sequenceItemCount: Int {
        return sequenceItems?.count ?? 0
    }
    
    /// Number of fragments in encapsulated pixel data
    ///
    /// Returns 0 if this element does not contain encapsulated data.
    public var encapsulatedFragmentCount: Int {
        return encapsulatedFragments?.count ?? 0
    }
    
    /// Extracts the value as a string (for string-based VRs)
    ///
    /// Returns nil if the VR doesn't support string values or if decoding fails.
    /// Trims leading/trailing whitespace and null padding per DICOM conventions.
    ///
    /// Reference: PS3.5 Section 6.2 - Value padding uses space (0x20) for most
    /// string VRs and null (0x00) for UI.
    public var stringValue: String? {
        guard vr.characterRepertoire != nil else {
            return nil
        }
        
        guard let string = String(data: valueData, encoding: .utf8) else {
            return nil
        }
        
        // Create a character set containing whitespace, newlines, and null characters
        // DICOM pads UI with null (0x00) and other string VRs with space (0x20)
        var trimmingSet = CharacterSet.whitespacesAndNewlines
        trimmingSet.insert(charactersIn: "\0")
        
        return string.trimmingCharacters(in: trimmingSet)
    }
    
    /// Extracts multiple string values (for multi-valued string VRs)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2
    public var stringValues: [String]? {
        guard let value = stringValue else {
            return nil
        }
        
        return value.split(separator: "\\").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// Extracts the value as a 16-bit unsigned integer (for US VR)
    public var uint16Value: UInt16? {
        guard vr == .US && valueData.count >= 2 else {
            return nil
        }
        return valueData.readUInt16LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit unsigned integer (for UL VR)
    public var uint32Value: UInt32? {
        guard vr == .UL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readUInt32LE(at: 0)
    }
    
    /// Extracts the value as a 16-bit signed integer (for SS VR)
    public var int16Value: Int16? {
        guard vr == .SS && valueData.count >= 2 else {
            return nil
        }
        return valueData.readInt16LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit signed integer (for SL VR)
    public var int32Value: Int32? {
        guard vr == .SL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readInt32LE(at: 0)
    }
    
    /// Extracts the value as a 32-bit floating point (for FL VR)
    public var float32Value: Float32? {
        guard vr == .FL && valueData.count >= 4 else {
            return nil
        }
        return valueData.readFloat32LE(at: 0)
    }
    
    /// Extracts the value as a 64-bit floating point (for FD VR)
    public var float64Value: Float64? {
        guard vr == .FD && valueData.count >= 8 else {
            return nil
        }
        return valueData.readFloat64LE(at: 0)
    }
    
    /// Extracts multiple 16-bit unsigned integer values (for US VR with multiplicity)
    ///
    /// Many DICOM elements can have multiple values. This property returns all values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var uint16Values: [UInt16]? {
        guard vr == .US else {
            return nil
        }
        
        let count = valueData.count / 2
        guard count > 0 else {
            return []
        }
        
        var values: [UInt16] = []
        for i in 0..<count {
            if let value = valueData.readUInt16LE(at: i * 2) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Extracts multiple 32-bit unsigned integer values (for UL VR with multiplicity)
    public var uint32Values: [UInt32]? {
        guard vr == .UL else {
            return nil
        }
        
        let count = valueData.count / 4
        guard count > 0 else {
            return []
        }
        
        var values: [UInt32] = []
        for i in 0..<count {
            if let value = valueData.readUInt32LE(at: i * 4) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Extracts multiple 16-bit signed integer values (for SS VR with multiplicity)
    public var int16Values: [Int16]? {
        guard vr == .SS else {
            return nil
        }
        
        let count = valueData.count / 2
        guard count > 0 else {
            return []
        }
        
        var values: [Int16] = []
        for i in 0..<count {
            if let value = valueData.readInt16LE(at: i * 2) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Extracts multiple 32-bit signed integer values (for SL VR with multiplicity)
    public var int32Values: [Int32]? {
        guard vr == .SL else {
            return nil
        }
        
        let count = valueData.count / 4
        guard count > 0 else {
            return []
        }
        
        var values: [Int32] = []
        for i in 0..<count {
            if let value = valueData.readInt32LE(at: i * 4) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Extracts multiple 32-bit floating point values (for FL VR with multiplicity)
    public var float32Values: [Float32]? {
        guard vr == .FL else {
            return nil
        }
        
        let count = valueData.count / 4
        guard count > 0 else {
            return []
        }
        
        var values: [Float32] = []
        for i in 0..<count {
            if let value = valueData.readFloat32LE(at: i * 4) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    /// Extracts multiple 64-bit floating point values (for FD VR with multiplicity)
    public var float64Values: [Float64]? {
        guard vr == .FD else {
            return nil
        }
        
        let count = valueData.count / 8
        guard count > 0 else {
            return []
        }
        
        var values: [Float64] = []
        for i in 0..<count {
            if let value = valueData.readFloat64LE(at: i * 8) {
                values.append(value)
            }
        }
        
        return values.isEmpty ? nil : values
    }
    
    // MARK: - Date/Time Value Extraction
    
    /// Extracts the value as a DICOM Date (for DA VR)
    ///
    /// Parses the DICOM Date string (YYYYMMDD format) into a structured DICOMDate.
    /// Reference: PS3.5 Section 6.2 - DA Value Representation
    public var dateValue: DICOMDate? {
        guard vr == .DA, let string = stringValue else {
            return nil
        }
        return DICOMDate.parse(string)
    }
    
    /// Extracts the value as a DICOM Time (for TM VR)
    ///
    /// Parses the DICOM Time string (HHMMSS.FFFFFF format) into a structured DICOMTime.
    /// Reference: PS3.5 Section 6.2 - TM Value Representation
    public var timeValue: DICOMTime? {
        guard vr == .TM, let string = stringValue else {
            return nil
        }
        return DICOMTime.parse(string)
    }
    
    /// Extracts the value as a DICOM DateTime (for DT VR)
    ///
    /// Parses the DICOM DateTime string into a structured DICOMDateTime.
    /// Reference: PS3.5 Section 6.2 - DT Value Representation
    public var dateTimeValue: DICOMDateTime? {
        guard vr == .DT, let string = stringValue else {
            return nil
        }
        return DICOMDateTime.parse(string)
    }
    
    /// Extracts the value as a Foundation Date (for DA, TM, or DT VR)
    ///
    /// Converts DICOM date/time values to a Swift Date object.
    /// - For DA (Date): Returns date at midnight UTC
    /// - For TM (Time): Returns nil (time alone cannot be converted to Date)
    /// - For DT (DateTime): Returns full date and time
    ///
    /// Reference: PS3.5 Section 6.2
    public var foundationDateValue: Date? {
        switch vr {
        case .DA:
            return dateValue?.toDate()
        case .DT:
            return dateTimeValue?.toDate()
        default:
            return nil
        }
    }
    
    // MARK: - Age String Value Extraction
    
    /// Extracts the value as a DICOM Age String (for AS VR)
    ///
    /// Parses the DICOM Age String (nnnX format) into a structured DICOMAgeString.
    /// Reference: PS3.5 Section 6.2 - AS Value Representation
    public var ageValue: DICOMAgeString? {
        guard vr == .AS, let string = stringValue else {
            return nil
        }
        return DICOMAgeString.parse(string)
    }
    
    // MARK: - Decimal String Value Extraction
    
    /// Extracts the value as a DICOM Decimal String (for DS VR)
    ///
    /// Parses the DICOM Decimal String into a structured DICOMDecimalString.
    /// Reference: PS3.5 Section 6.2 - DS Value Representation
    public var decimalStringValue: DICOMDecimalString? {
        guard vr == .DS, let string = stringValue else {
            return nil
        }
        return DICOMDecimalString.parse(string)
    }
    
    /// Extracts multiple DICOM Decimal String values (for DS VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var decimalStringValues: [DICOMDecimalString]? {
        guard vr == .DS, let string = stringValue else {
            return nil
        }
        return DICOMDecimalString.parseMultiple(string)
    }
    
    // MARK: - Integer String Value Extraction
    
    /// Extracts the value as a DICOM Integer String (for IS VR)
    ///
    /// Parses the DICOM Integer String into a structured DICOMIntegerString.
    /// Reference: PS3.5 Section 6.2 - IS Value Representation
    public var integerStringValue: DICOMIntegerString? {
        guard vr == .IS, let string = stringValue else {
            return nil
        }
        return DICOMIntegerString.parse(string)
    }
    
    /// Extracts multiple DICOM Integer String values (for IS VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var integerStringValues: [DICOMIntegerString]? {
        guard vr == .IS, let string = stringValue else {
            return nil
        }
        return DICOMIntegerString.parseMultiple(string)
    }
    
    // MARK: - Person Name Value Extraction
    
    /// Extracts the value as a DICOM Person Name (for PN VR)
    ///
    /// Parses the DICOM Person Name string into a structured DICOMPersonName.
    /// Reference: PS3.5 Section 6.2 - PN Value Representation
    public var personNameValue: DICOMPersonName? {
        guard vr == .PN, let string = stringValue else {
            return nil
        }
        return DICOMPersonName.parse(string)
    }
    
    /// Extracts multiple DICOM Person Name values (for PN VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var personNameValues: [DICOMPersonName]? {
        guard vr == .PN, let strings = stringValues else {
            return nil
        }
        let names = strings.compactMap { DICOMPersonName.parse($0) }
        return names.isEmpty ? nil : names
    }
    
    // MARK: - Unique Identifier Value Extraction
    
    /// Extracts the value as a DICOM Unique Identifier (for UI VR)
    ///
    /// Parses the DICOM UID string into a structured DICOMUniqueIdentifier.
    /// Reference: PS3.5 Section 6.2 - UI Value Representation
    public var uidValue: DICOMUniqueIdentifier? {
        guard vr == .UI, let string = stringValue else {
            return nil
        }
        return DICOMUniqueIdentifier.parse(string)
    }
    
    /// Extracts multiple DICOM Unique Identifier values (for UI VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var uidValues: [DICOMUniqueIdentifier]? {
        guard vr == .UI, let string = stringValue else {
            return nil
        }
        return DICOMUniqueIdentifier.parseMultiple(string)
    }
    
    // MARK: - Application Entity Value Extraction
    
    /// Extracts the value as a DICOM Application Entity (for AE VR)
    ///
    /// Parses the DICOM AE Title string into a structured DICOMApplicationEntity.
    /// Reference: PS3.5 Section 6.2 - AE Value Representation
    public var applicationEntityValue: DICOMApplicationEntity? {
        guard vr == .AE, let string = stringValue else {
            return nil
        }
        return DICOMApplicationEntity.parse(string)
    }
    
    /// Extracts multiple DICOM Application Entity values (for AE VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var applicationEntityValues: [DICOMApplicationEntity]? {
        guard vr == .AE, let string = stringValue else {
            return nil
        }
        return DICOMApplicationEntity.parseMultiple(string)
    }
    
    // MARK: - Code String Value Extraction
    
    /// Extracts the value as a DICOM Code String (for CS VR)
    ///
    /// Parses the DICOM Code String into a structured DICOMCodeString.
    /// Reference: PS3.5 Section 6.2 - CS Value Representation
    public var codeStringValue: DICOMCodeString? {
        guard vr == .CS, let string = stringValue else {
            return nil
        }
        return DICOMCodeString.parse(string)
    }
    
    /// Extracts multiple DICOM Code String values (for CS VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var codeStringValues: [DICOMCodeString]? {
        guard vr == .CS, let string = stringValue else {
            return nil
        }
        return DICOMCodeString.parseMultiple(string)
    }
    
    // MARK: - Universal Resource Value Extraction
    
    /// Extracts the value as a DICOM Universal Resource (for UR VR)
    ///
    /// Parses the DICOM URI/URL string into a structured DICOMUniversalResource.
    /// Reference: PS3.5 Section 6.2 - UR Value Representation
    public var universalResourceValue: DICOMUniversalResource? {
        guard vr == .UR, let string = stringValue else {
            return nil
        }
        return DICOMUniversalResource.parse(string)
    }
    
    /// Extracts multiple DICOM Universal Resource values (for UR VR with multiplicity)
    ///
    /// DICOM uses backslash (\) as a delimiter for multiple values.
    /// Reference: PS3.5 Section 6.2 - Value Multiplicity
    public var universalResourceValues: [DICOMUniversalResource]? {
        guard vr == .UR, let string = stringValue else {
            return nil
        }
        return DICOMUniversalResource.parseMultiple(string)
    }
}
