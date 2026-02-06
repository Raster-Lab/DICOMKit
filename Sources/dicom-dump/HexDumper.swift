import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Formats binary data as hexadecimal dump with optional DICOM annotations
class HexDumper {
    let bytesPerLine: Int
    let useColor: Bool
    let annotate: Bool
    let verbose: Bool
    
    init(bytesPerLine: Int = 16, useColor: Bool = true, annotate: Bool = true, verbose: Bool = false) {
        self.bytesPerLine = bytesPerLine
        self.useColor = useColor
        self.annotate = annotate
        self.verbose = verbose
    }
    
    /// Dumps data as hexadecimal with ASCII representation
    func dump(
        data: Data,
        startOffset: Int,
        dicomFile: DICOMFile?,
        highlightTag: Tag?
    ) -> String {
        var output = ""
        
        // Build tag position map if annotating
        var tagPositions: [Int: TagInfo] = [:]
        if annotate, let file = dicomFile {
            tagPositions = buildTagPositionMap(fileData: data, dicomFile: file)
        }
        
        var currentOffset = startOffset
        var dataIndex = 0
        
        while dataIndex < data.count {
            let lineEnd = min(dataIndex + bytesPerLine, data.count)
            let lineData = data[dataIndex..<lineEnd]
            
            // Format offset
            let offsetStr = String(format: "%08X", currentOffset)
            output += useColor ? color(offsetStr, .cyan) : offsetStr
            output += "  "
            
            // Format hex bytes
            var hexPart = ""
            var asciiPart = ""
            
            for (idx, byte) in lineData.enumerated() {
                let byteOffset = currentOffset + idx
                
                // Check if this byte is part of a tag boundary
                let isTagStart = tagPositions[byteOffset] != nil
                let isHighlight = false // Will implement highlight detection
                
                let hexByte = String(format: "%02X", byte)
                
                if useColor {
                    if isTagStart {
                        hexPart += color(hexByte, .green)
                    } else if isHighlight {
                        hexPart += color(hexByte, .yellow)
                    } else {
                        hexPart += hexByte
                    }
                } else {
                    hexPart += hexByte
                }
                
                hexPart += " "
                
                // ASCII representation
                if byte >= 32 && byte <= 126 {
                    asciiPart += String(format: "%c", byte)
                } else {
                    asciiPart += "."
                }
            }
            
            // Pad hex part if line is short
            let paddingNeeded = bytesPerLine - lineData.count
            hexPart += String(repeating: "   ", count: paddingNeeded)
            
            output += hexPart
            output += " |"
            output += useColor ? color(asciiPart, .white) : asciiPart
            output += "|"
            
            // Add annotation if available
            if let tagInfo = tagPositions[currentOffset] {
                output += "  "
                output += useColor ? color("← ", .blue) : "<- "
                output += formatTagAnnotation(tagInfo)
            }
            
            output += "\n"
            
            currentOffset += lineData.count
            dataIndex = lineEnd
        }
        
        return output
    }
    
    /// Builds a map of byte offsets to tag information
    private func buildTagPositionMap(fileData: Data, dicomFile: DICOMFile) -> [Int: TagInfo] {
        var positions: [Int: TagInfo] = [:]
        
        // Scan for DICOM tag patterns in the data
        // Tags are 4 bytes: group (2) + element (2)
        // Followed by VR (explicit VR) or length (implicit VR)
        
        var offset = 0
        let data = fileData
        
        // Skip preamble and DICM prefix
        if data.count > 132 {
            offset = 132
        }
        
        while offset + 8 <= data.count {
            // Read potential tag
            let groupBytes = data[offset..<offset + 2]
            let elementBytes = data[offset + 2..<offset + 4]
            
            let group = groupBytes.withUnsafeBytes { $0.load(as: UInt16.self) }
            let element = elementBytes.withUnsafeBytes { $0.load(as: UInt16.self) }
            
            let tag = Tag(group: group, element: element)
            
            // Check if this looks like a valid DICOM tag
            if isValidTagPattern(group: group, element: element) {
                // Read VR
                let vrBytes = data[offset + 4..<offset + 6]
                let vrString = String(data: vrBytes, encoding: .ascii) ?? "??"
                
                // Try to parse as VR
                let vr = VR(rawValue: vrString) ?? .UN
                
                // Determine length
                var valueLength: UInt32 = 0
                var headerLength = 8 // tag + VR + length
                
                // Check if explicit VR with special length encoding
                if ["OB", "OD", "OF", "OL", "OW", "SQ", "UC", "UR", "UT", "UN"].contains(vrString) {
                    // 4-byte length field
                    if offset + 12 <= data.count {
                        let lengthBytes = data[offset + 8..<offset + 12]
                        valueLength = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
                        headerLength = 12
                    }
                } else {
                    // 2-byte length field
                    if offset + 8 <= data.count {
                        let lengthBytes = data[offset + 6..<offset + 8]
                        valueLength = UInt32(lengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) })
                    }
                }
                
                // Store tag info
                let entry = DataElementDictionary.lookup(tag: tag)
                let tagInfo = TagInfo(
                    tag: tag,
                    vr: vr,
                    length: valueLength,
                    keyword: entry?.keyword
                )
                positions[offset] = tagInfo
                
                // Skip to next potential tag
                // If length is undefined (0xFFFFFFFF), skip header only
                if valueLength == 0xFFFFFFFF {
                    offset += headerLength
                } else {
                    offset += headerLength + Int(valueLength)
                }
            } else {
                offset += 1
            }
        }
        
        return positions
    }
    
    /// Checks if group/element looks like a valid DICOM tag
    private func isValidTagPattern(group: UInt16, element: UInt16) -> Bool {
        // Group 0000 is only valid for specific command elements
        if group == 0x0000 {
            return [0x0000, 0x0002, 0x0100, 0x0120, 0x0900, 0x0901, 0x0902].contains(element)
        }

        // Group 0002 is file meta information
        if group == 0x0002 {
            return true
        }

        // Reject any other groups below 0008 – there are no standard data element
        // groups defined here, so accepting them tends to create false positives.
        if group < 0x0008 {
            return false
        }

        // Element 0000 is a (retired) group length element and should not normally
        // appear in regular datasets; treat it as invalid for heuristic purposes.
        if element == 0x0000 {
            return false
        }

        // Elements 0001–000F are generally reserved and rarely used in practice.
        // Requiring element >= 0010 significantly reduces random matches when
        // scanning arbitrary byte sequences for plausible tags.
        if element < 0x0010 {
            return false
        }

        // For all other cases (standard even groups and private odd groups with
        // reasonably sized element numbers), consider the pattern plausible.
        return true
    }
    
    /// Formats tag annotation for display
    private func formatTagAnnotation(_ tagInfo: TagInfo) -> String {
        let tagStr = String(format: "(%04X,%04X)", tagInfo.tag.group, tagInfo.tag.element)
        
        var annotation = tagStr
        
        if verbose {
            annotation += " VR=\(tagInfo.vr.rawValue)"
            
            if tagInfo.length == 0xFFFFFFFF {
                annotation += " Len=undefined"
            } else {
                annotation += " Len=\(tagInfo.length)"
            }
        }
        
        if let keyword = tagInfo.keyword {
            annotation += " \(keyword)"
        }
        
        return annotation
    }
    
    /// ANSI color codes
    enum Color: String {
        case black = "30"
        case red = "31"
        case green = "32"
        case yellow = "33"
        case blue = "34"
        case magenta = "35"
        case cyan = "36"
        case white = "37"
        case reset = "0"
    }
    
    /// Applies ANSI color to string
    private func color(_ string: String, _ color: Color) -> String {
        "\u{001B}[\(color.rawValue)m\(string)\u{001B}[0m"
    }
}

/// Information about a DICOM tag found in raw data
struct TagInfo {
    let tag: Tag
    let vr: VR
    let length: UInt32
    let keyword: String?
}
