// HexDumper.swift
// DICOMCLITools
//
// Shared hex-dump renderer for `dicom-dump`. Used by both the CLI and the
// DICOMStudio GUI's CLI Workshop so the rendered output is identical.

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Information about a DICOM tag found in raw data.
public struct TagInfo: Sendable {
    public let tag: Tag
    public let vr: VR
    public let length: UInt32
    public let keyword: String?

    public init(tag: Tag, vr: VR, length: UInt32, keyword: String?) {
        self.tag = tag
        self.vr = vr
        self.length = length
        self.keyword = keyword
    }
}

/// Formats binary data as hexadecimal dump with optional DICOM annotations.
public final class HexDumper: @unchecked Sendable {
    public let bytesPerLine: Int
    public let useColor: Bool
    public let annotate: Bool
    public let verbose: Bool

    public init(bytesPerLine: Int = 16, useColor: Bool = true, annotate: Bool = true, verbose: Bool = false) {
        self.bytesPerLine = bytesPerLine
        self.useColor = useColor
        self.annotate = annotate
        self.verbose = verbose
    }

    /// Dumps data as hexadecimal with ASCII representation.
    ///
    /// - Parameters:
    ///   - data: The bytes to render. May be a slice of a larger file.
    ///   - startOffset: The absolute byte offset (in the original file) of
    ///     the first byte of `data`. This is used both for the printed
    ///     "OFFSET" column and for translating absolute tag/highlight
    ///     positions into positions relative to `data`.
    ///   - dicomFile: Parsed file used for tag-position lookups when
    ///     `annotate` is enabled.
    ///   - highlightTag: Optional tag whose entire on-disk byte range
    ///     (header + value) should be marked. Highlight resolution scans
    ///     `fileBytes` (or `data` if not provided) so it works for any
    ///     element, not just the ones the linear position-map walker
    ///     happens to reach.
    ///   - fileBytes: The complete file bytes, used to resolve
    ///     `highlightTag` and to build the annotation map. When `nil`,
    ///     `data` is used (caller is dumping the whole file).
    public func dump(
        data: Data,
        startOffset: Int,
        dicomFile: DICOMFile?,
        highlightTag: Tag?,
        fileBytes: Data? = nil
    ) -> String {
        var output = ""

        // Treat `data` as a 0-based buffer regardless of whether the caller
        // passed a Data slice (which retains the original buffer's indices).
        // Re-base into a fresh Data so all internal arithmetic uses
        // 0..<data.count without crashing.
        let buffer: Data = data.startIndex == 0 ? data : Data(data)
        let referenceBytes = fileBytes ?? buffer

        // Build tag position map. Both annotate and highlight benefit from
        // it; we only build when at least one feature is enabled.
        var tagPositions: [Int: TagInfo] = [:]
        if let file = dicomFile, (annotate || highlightTag != nil) {
            tagPositions = buildTagPositionMap(fileData: referenceBytes, dicomFile: file)
        }

        // Resolve `highlightTag` to an absolute byte range. Try the
        // position map first; if it didn't reach the target tag (e.g. the
        // walker drifted on an SQ with undefined length), fall back to a
        // direct on-bytes search so highlight is reliable for any element.
        var highlightRangeAbs: Range<Int>? = nil
        if let target = highlightTag {
            if let info = tagPositions.first(where: { $0.value.tag == target }) {
                let headerLen = HexDumper.headerLength(for: info.value.vr)
                let valueLen = info.value.length == 0xFFFFFFFF ? 0 : Int(info.value.length)
                highlightRangeAbs = info.key..<(info.key + headerLen + valueLen)
            } else if let range = HexDumper.findElementRange(in: referenceBytes, tag: target) {
                highlightRangeAbs = range
            }
        }

        var currentOffset = startOffset
        var dataIndex = 0

        while dataIndex < buffer.count {
            let lineEnd = min(dataIndex + bytesPerLine, buffer.count)
            let lineData = buffer[dataIndex..<lineEnd]

            // Format offset
            let offsetStr = String(format: "%08X", currentOffset)
            output += useColor ? color(offsetStr, .cyan) : offsetStr
            output += "  "

            // Format hex bytes
            var hexPart = ""
            var asciiPart = ""
            var lineHasBracket = false

            for (idx, byte) in lineData.enumerated() {
                let byteOffset = currentOffset + idx

                let isTagStart = tagPositions[byteOffset] != nil
                let isHighlight = highlightRangeAbs?.contains(byteOffset) ?? false

                let hexByte = String(format: "%02X", byte)

                if useColor {
                    if isHighlight {
                        hexPart += color(hexByte, .yellow)
                    } else if isTagStart {
                        hexPart += color(hexByte, .green)
                    } else {
                        hexPart += hexByte
                    }
                } else if isHighlight {
                    hexPart += "[\(hexByte)]"
                    lineHasBracket = true
                } else {
                    hexPart += hexByte
                }

                hexPart += " "

                if byte >= 32 && byte <= 126 {
                    asciiPart += String(format: "%c", byte)
                } else {
                    asciiPart += "."
                }
            }

            // Pad hex column so the ASCII gutter aligns even when the line
            // is shorter than `bytesPerLine` or when highlight brackets
            // make some bytes wider.
            let perByteWidth = lineHasBracket ? 5 : 3
            let paddingNeeded = bytesPerLine - lineData.count
            hexPart += String(repeating: String(repeating: " ", count: perByteWidth), count: paddingNeeded)

            output += hexPart
            output += " |"
            output += useColor ? color(asciiPart, .white) : asciiPart
            output += "|"

            // Show an annotation arrow whenever any tag starts inside this
            // line (not only at the line boundary). Multiple annotations
            // are joined so a 16-byte line containing several short
            // elements still shows them all.
            if annotate {
                let lineRange = currentOffset..<(currentOffset + lineData.count)
                let annotationsOnLine = tagPositions
                    .filter { lineRange.contains($0.key) }
                    .sorted { $0.key < $1.key }
                if !annotationsOnLine.isEmpty {
                    output += "  "
                    output += useColor ? color("← ", .blue) : "<- "
                    output += annotationsOnLine
                        .map { formatTagAnnotation($0.value) }
                        .joined(separator: " · ")
                }
            }

            output += "\n"

            currentOffset += lineData.count
            dataIndex = lineEnd
        }

        return output
    }

    /// Returns the on-disk header length (tag + VR + length field) for an
    /// Explicit-VR Little Endian element of the given VR. Used by highlight
    /// to color the right number of bytes.
    private static func headerLength(for vr: VR) -> Int {
        switch vr {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UR, .UT, .UN:
            return 12  // 4 (tag) + 2 (VR) + 2 (reserved) + 4 (length)
        default:
            return 8   // 4 (tag) + 2 (VR) + 2 (length)
        }
    }

    /// Locates the byte range of an Explicit-VR Little Endian element by
    /// linearly scanning the file. Used as a fallback for `--highlight` and
    /// `--tag` when the element is in the main dataset and the position
    /// map didn't reach it.
    public static func findElementRange(in fileData: Data, tag: Tag) -> Range<Int>? {
        let target = (tag.group, tag.element)
        // Skip preamble + DICM magic when present.
        var offset = (fileData.count > 132 && fileData[128..<132] == Data("DICM".utf8)) ? 132 : 0

        while offset + 8 <= fileData.count {
            let group = fileData[offset..<offset + 2].withUnsafeBytes {
                $0.loadUnaligned(as: UInt16.self)
            }
            let element = fileData[offset + 2..<offset + 4].withUnsafeBytes {
                $0.loadUnaligned(as: UInt16.self)
            }
            let vrBytes = fileData[offset + 4..<offset + 6]
            let vrString = String(data: vrBytes, encoding: .ascii) ?? "??"

            // Long-form VRs use a 4-byte length at offset+8 (with 2 reserved bytes).
            let isLongForm = ["OB", "OD", "OF", "OL", "OW", "SQ", "UC", "UR", "UT", "UN"]
                .contains(vrString)
            var headerLen = 8
            var valueLen: UInt32 = 0

            if isLongForm {
                guard offset + 12 <= fileData.count else { return nil }
                valueLen = fileData[offset + 8..<offset + 12]
                    .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                headerLen = 12
            } else {
                let len16 = fileData[offset + 6..<offset + 8]
                    .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
                valueLen = UInt32(len16)
            }

            if (group, element) == target {
                let total = valueLen == 0xFFFFFFFF
                    ? headerLen
                    : headerLen + Int(valueLen)
                return offset..<min(offset + total, fileData.count)
            }

            // Skip element. SQ / undefined-length elements don't contribute a
            // straightforward "skip past" amount — we step by header only and
            // continue, which lets the scan recover at the next element start.
            if valueLen == 0xFFFFFFFF {
                offset += headerLen
            } else {
                offset += headerLen + Int(valueLen)
            }
        }

        return nil
    }

    private func buildTagPositionMap(fileData: Data, dicomFile: DICOMFile) -> [Int: TagInfo] {
        var positions: [Int: TagInfo] = [:]

        let data = fileData
        // Skip preamble + DICM magic when present so the scan starts at the
        // first File Meta element. Otherwise begin at offset 0 (raw dataset).
        var offset = (data.count > 132 && data[128..<132] == Data("DICM".utf8)) ? 132 : 0

        // Set of valid VR strings (Explicit VR Little Endian). Used to
        // distinguish a real element header from random bytes inside an
        // SQ value or the pixel data, so the walker can re-synchronize
        // without accepting garbage as elements.
        let validVRs: Set<String> = [
            "AE","AS","AT","CS","DA","DS","DT","FL","FD","IS","LO","LT",
            "OB","OD","OF","OL","OW","PN","SH","SL","SQ","SS","ST","TM",
            "UC","UI","UL","UN","UR","US","UT"
        ]
        let longFormVRs: Set<String> = ["OB","OD","OF","OL","OW","SQ","UC","UR","UT","UN"]

        while offset + 8 <= data.count {
            let group = data[offset..<offset + 2]
                .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
            let element = data[offset + 2..<offset + 4]
                .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }

            // Skip item / item-delimitation / sequence-delimitation markers
            // (group 0xFFFE). They have a 4-byte length and no VR; treating
            // them as elements would mis-parse and break re-sync.
            if group == 0xFFFE {
                guard offset + 8 <= data.count else { break }
                let len = data[offset + 4..<offset + 8]
                    .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                if len == 0xFFFFFFFF {
                    offset += 8
                } else {
                    offset += 8  // step into the item content; nested elements
                                 // will be visited on subsequent iterations
                }
                continue
            }

            let vrBytes = data[offset + 4..<offset + 6]
            let vrString = String(data: vrBytes, encoding: .ascii) ?? "??"

            // Re-synchronize: if these two bytes aren't a real VR, the
            // walker drifted (e.g. into pixel data or padding). Advance
            // one byte and try again instead of mis-parsing.
            guard validVRs.contains(vrString) else {
                offset += 1
                continue
            }

            let vr = VR(rawValue: vrString) ?? .UN
            var headerLength = 8
            var valueLength: UInt32 = 0

            if longFormVRs.contains(vrString) {
                guard offset + 12 <= data.count else { break }
                valueLength = data[offset + 8..<offset + 12]
                    .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                headerLength = 12
            } else {
                let len16 = data[offset + 6..<offset + 8]
                    .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
                valueLength = UInt32(len16)
            }

            let tag = Tag(group: group, element: element)
            let entry = DataElementDictionary.lookup(tag: tag)
            positions[offset] = TagInfo(
                tag: tag,
                vr: vr,
                length: valueLength,
                keyword: entry?.keyword
            )

            if valueLength == 0xFFFFFFFF {
                // Undefined length (SQ or encapsulated pixel data): step
                // past the header so nested items / elements are visited.
                offset += headerLength
            } else {
                offset += headerLength + Int(valueLength)
            }
        }

        return positions
    }

    private func isValidTagPattern(group: UInt16, element: UInt16) -> Bool {
        if group == 0x0000 {
            return [0x0000, 0x0002, 0x0100, 0x0120, 0x0900, 0x0901, 0x0902].contains(element)
        }
        if group == 0x0002 {
            return true
        }
        if group < 0x0008 {
            return false
        }
        if element == 0x0000 {
            return false
        }
        if element < 0x0010 {
            return false
        }
        return true
    }

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

    private func color(_ string: String, _ color: Color) -> String {
        "\u{001B}[\(color.rawValue)m\(string)\u{001B}[0m"
    }
}
