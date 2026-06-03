import Foundation
import DICOMCore
import DICOMDictionary

/// Formats binary data as a hexadecimal dump with optional DICOM annotations.
///
/// Shared by the `dicom-dump` CLI and DICOMStudio's CLI Workshop so both produce
/// the same dump from the same bytes (the app disables color and the parity
/// comparison strips ANSI, so the two match).
public final class HexDumper {
    let bytesPerLine: Int
    let useColor: Bool
    let annotate: Bool
    let verbose: Bool

    public init(bytesPerLine: Int = 16, useColor: Bool = true, annotate: Bool = true, verbose: Bool = false) {
        self.bytesPerLine = bytesPerLine
        self.useColor = useColor
        self.annotate = annotate
        self.verbose = verbose
    }

    /// Renders a single tag's dump (header + a hex dump of its value bytes),
    /// shared by the `dicom-dump` CLI (`--tag`) and DICOMStudio so both produce
    /// identical output. Uses the parsed element's value bytes (no raw-offset
    /// slicing), so it can't crash and the header reflects accurate metadata.
    /// Returns `nil` if the tag isn't present.
    public static func tagDump(
        tag: Tag,
        in file: DICOMFile,
        bytesPerLine: Int = 16,
        useColor: Bool = true,
        verbose: Bool = false
    ) -> String? {
        guard let element = file.dataSet[tag] ?? file.fileMetaInformation[tag] else { return nil }
        let name = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
        var out = "Tag: \(tag.description)  \(name)  VR=\(element.vr.rawValue)  Length=\(element.length)\n"
        if verbose {
            out += "Value: \(MetadataPresenter.formatElementValue(element))\n"
        }
        out += "\n"
        out += HexDumper(bytesPerLine: bytesPerLine, useColor: useColor, annotate: false, verbose: verbose)
            .dump(data: element.valueData, startOffset: 0, dicomFile: nil, highlightTag: nil)
        return out
    }

    /// Dumps data as hexadecimal with ASCII representation.
    public func dump(
        data: Data,
        startOffset: Int,
        dicomFile: DICOMFile?,
        highlightTag: Tag?
    ) -> String {
        var output = ""

        // Build the tag position map when annotating OR highlighting. The scan is
        // raw (operates on the bytes), so a parsed DICOMFile isn't required.
        var tagPositions: [Int: TagInfo] = [:]
        if annotate || highlightTag != nil {
            tagPositions = buildTagPositionMap(fileData: data)
        }
        // The element (in data-index space) to highlight, if requested.
        let highlightInfo: TagInfo? = highlightTag.flatMap { ht in
            tagPositions.values.first(where: { $0.tag == ht })
        }
        let highlightRange = highlightInfo?.range

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
                let dataByteIndex = dataIndex + idx

                // Is this byte a tag boundary, or part of the highlighted element?
                let isTagStart = tagPositions[dataByteIndex] != nil
                let isHighlight = highlightRange?.contains(dataByteIndex) ?? false

                let hexByte = String(format: "%02X", byte)

                if useColor {
                    if isHighlight {
                        hexPart += color(hexByte, .yellow)
                    } else if isTagStart {
                        hexPart += color(hexByte, .green)
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

            // Tag-boundary annotation (annotate mode). Same "← " glyph in both
            // color modes so colored and plain output match once ANSI is stripped.
            if annotate, let tagInfo = tagPositions[dataIndex] {
                output += "  "
                output += useColor ? color("← ", .blue) : "← "
                output += formatTagAnnotation(tagInfo)
            }
            // Highlighted-tag marker on its first line — a plain-text label so
            // --highlight is visible even in no-color output (e.g. the in-app
            // console), not just as colored bytes in a terminal.
            if let info = highlightInfo, info.range.lowerBound >= dataIndex, info.range.lowerBound < lineEnd {
                output += "  "
                output += useColor ? color("◀ HIGHLIGHT ", .yellow) : "◀ HIGHLIGHT "
                output += formatTagAnnotation(info)
            }

            output += "\n"

            currentOffset += lineData.count
            dataIndex = lineEnd
        }

        return output
    }

    /// Walks the DICOM stream element-by-element (deterministic, with per-element
    /// explicit/implicit VR detection) and records each element's offset → TagInfo
    /// with its full byte range. This replaces the old heuristic byte-scan, which
    /// byte-walked and misaligned — missing main-dataset tags (e.g. (0008,0060)),
    /// so --highlight / --annotate only found early group-0002 tags.
    private func buildTagPositionMap(fileData: Data) -> [Int: TagInfo] {
        var positions: [Int: TagInfo] = [:]
        let data = fileData
        let base = data.startIndex
        let undefinedLength = 0xFFFF_FFFF

        // Skip the 128-byte preamble + "DICM" if present.
        var offset = (data.count > 132) ? 132 : 0

        let knownVRs: Set<String> = [
            "AE","AS","AT","CS","DA","DS","DT","FL","FD","IS","LO","LT","OB","OD","OF",
            "OL","OW","PN","SH","SL","SQ","SS","ST","TM","UC","UI","UL","UN","UR","US","UT"
        ]
        let extendedVRs: Set<String> = ["OB","OD","OF","OL","OW","SQ","UC","UR","UT","UN"]

        func byteAt(_ i: Int) -> UInt8 { data[data.index(base, offsetBy: i)] }

        while offset + 8 <= data.count {
            let group = readUInt16LE(data, at: offset)
            let element = readUInt16LE(data, at: offset + 2)

            // Item / sequence delimiters (FFFE,xxxx): 4-byte length, no VR. Skip the
            // item content by its length (descend only for undefined-length items).
            if group == 0xFFFE {
                let len = Int(readUInt32LE(data, at: offset + 4))
                offset += (len == undefinedLength) ? 8 : 8 + max(0, len)
                continue
            }

            // Detect explicit vs implicit VR from the two bytes after the tag.
            let vrCandidate = String(bytes: [byteAt(offset + 4), byteAt(offset + 5)], encoding: .ascii) ?? ""
            let vr: VR
            let headerLength: Int
            let valueLength: Int

            if knownVRs.contains(vrCandidate) {
                vr = VR(rawValue: vrCandidate) ?? .UN
                if extendedVRs.contains(vrCandidate) {
                    guard offset + 12 <= data.count else { break }
                    valueLength = Int(readUInt32LE(data, at: offset + 8))
                    headerLength = 12
                } else {
                    valueLength = Int(readUInt16LE(data, at: offset + 6))
                    headerLength = 8
                }
            } else {
                // Implicit VR: 4-byte length; VR taken from the dictionary.
                vr = DataElementDictionary.lookup(tag: Tag(group: group, element: element))?.vr.first ?? .UN
                valueLength = Int(readUInt32LE(data, at: offset + 4))
                headerLength = 8
            }

            let tag = Tag(group: group, element: element)
            let entry = DataElementDictionary.lookup(tag: tag)
            let undefined = (valueLength == undefinedLength)
            let span = undefined ? headerLength : headerLength + max(0, valueLength)
            let elementEnd = min(offset + span, data.count)
            positions[offset] = TagInfo(
                tag: tag,
                vr: vr,
                length: UInt32(truncatingIfNeeded: valueLength),
                keyword: entry?.keyword,
                range: offset..<max(offset + 1, elementEnd)
            )

            // Advance. Defined-length values (including defined-length sequences)
            // are skipped wholesale; undefined-length (SQ / encapsulated pixel data)
            // descends by the header — the FFFE handling above steps over item data.
            offset += undefined ? headerLength : headerLength + max(0, valueLength)
        }

        return positions
    }

    /// Reads a little-endian UInt16 at a byte offset without alignment assumptions.
    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        let base = data.startIndex
        let b0 = UInt16(data[data.index(base, offsetBy: offset)])
        let b1 = UInt16(data[data.index(base, offsetBy: offset + 1)])
        return b0 | (b1 << 8)
    }

    /// Reads a little-endian UInt32 at a byte offset without alignment assumptions.
    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex
        let b0 = UInt32(data[data.index(base, offsetBy: offset)])
        let b1 = UInt32(data[data.index(base, offsetBy: offset + 1)])
        let b2 = UInt32(data[data.index(base, offsetBy: offset + 2)])
        let b3 = UInt32(data[data.index(base, offsetBy: offset + 3)])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
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
    /// Byte range of the whole element (header + value) in the dumped data's index space.
    let range: Range<Int>
}
