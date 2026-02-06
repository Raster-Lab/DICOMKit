import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMDump: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-dump",
        abstract: "Hexadecimal dump with DICOM structure visualization",
        discussion: """
            Displays hexadecimal dump of DICOM files with structure annotations.
            Useful for low-level debugging and format inspection.
            
            Examples:
              dicom-dump file.dcm
              dicom-dump file.dcm --tag 7FE0,0010
              dicom-dump file.dcm --offset 0x1000 --length 256
              dicom-dump file.dcm --no-color > dump.txt
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to DICOM file")
    var filePath: String
    
    @Option(name: .long, help: "Dump specific tag (format: 0010,0010)")
    var tag: String?
    
    @Option(name: .long, help: "Start offset in bytes (hex or decimal)")
    var offset: String?
    
    @Option(name: .long, help: "Number of bytes to dump")
    var length: Int?
    
    @Option(name: .long, help: "Bytes per line (default: 16)")
    var bytesPerLine: Int = 16
    
    @Option(name: .long, help: "Highlight specific tag")
    var highlight: String?
    
    @Flag(name: .long, help: "Disable color output")
    var noColor: Bool = false
    
    @Flag(name: .long, help: "Show tag annotations")
    var annotate: Bool = false
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    @Flag(name: .long, help: "Verbose output with VR and length details")
    var verbose: Bool = false
    
    mutating func run() throws {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }
        
        let fileData = try Data(contentsOf: fileURL)
        
        // If specific tag requested, find and dump it
        if let tagString = tag {
            try dumpTag(fileData: fileData, tagString: tagString)
            return
        }
        
        // Parse offset if provided
        let startOffset = try parseOffset()
        let dumpLength = length ?? (fileData.count - startOffset)
        
        // Ensure we don't go past end of file
        let endOffset = min(startOffset + dumpLength, fileData.count)
        let dataToShow = fileData[startOffset..<endOffset]
        
        // Create dumper
        let dumper = HexDumper(
            bytesPerLine: bytesPerLine,
            useColor: !noColor,
            annotate: annotate,
            verbose: verbose
        )
        
        // Parse DICOM structure for annotations
        var dicomFile: DICOMFile?
        do {
            dicomFile = try DICOMFile.read(from: fileData, force: force)
        } catch {
            if verbose {
                let warningMessage = "Warning: Could not parse DICOM structure: \(error.localizedDescription)\n"
                if let data = warningMessage.data(using: .utf8) {
                    FileHandle.standardError.write(data)
                }
                if let data = "Dumping raw bytes without annotations\n\n".data(using: .utf8) {
                    FileHandle.standardError.write(data)
                }
            }
        }
        
        // Dump the data
        let output = dumper.dump(
            data: dataToShow,
            startOffset: startOffset,
            dicomFile: dicomFile,
            highlightTag: try parseHighlightTag()
        )
        
        print(output)
    }
    
    private func parseOffset() throws -> Int {
        guard let offsetString = offset else {
            return 0
        }
        
        // Handle hex format (0x prefix)
        if offsetString.lowercased().hasPrefix("0x") {
            let hexString = String(offsetString.dropFirst(2))
            guard let value = Int(hexString, radix: 16) else {
                throw ValidationError("Invalid hex offset: \(offsetString)")
            }
            return value
        }
        
        // Handle decimal
        guard let value = Int(offsetString) else {
            throw ValidationError("Invalid offset: \(offsetString)")
        }
        
        return value
    }
    
    private func parseHighlightTag() throws -> Tag? {
        guard let highlightString = highlight else {
            return nil
        }
        
        return try parseTag(highlightString)
    }
    
    private func parseTag(_ string: String) throws -> Tag {
        // Try parsing as hex format (0010,0010) or 00100010
        let cleanString = string.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if cleanString.count == 8, let value = UInt32(cleanString, radix: 16) {
            let group = UInt16((value >> 16) & 0xFFFF)
            let element = UInt16(value & 0xFFFF)
            return Tag(group: group, element: element)
        }
        
        throw ValidationError("Invalid tag format: \(string). Use format: 0010,0010")
    }
    
    private func dumpTag(fileData: Data, tagString: String) throws {
        let targetTag = try parseTag(tagString)
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        
        // Find tag in dataset
        guard let element = dicomFile.dataSet[targetTag] else {
            throw ValidationError("Tag \(formatTag(targetTag)) not found in file")
        }
        
        // Calculate tag position in file
        // This is a simplified approach - finding the tag's byte range
        let tagInfo = findTagInRawData(fileData: fileData, tag: targetTag)
        
        guard let (tagOffset, tagLength) = tagInfo else {
            throw ValidationError("Could not locate tag \(formatTag(targetTag)) in raw file data")
        }
        
        print("Tag: \(formatTag(targetTag))")
        if let entry = DataElementDictionary.lookup(tag: targetTag) {
            print("Name: \(entry.keyword)")
        }
        print("VR: \(element.vr.rawValue)")
        print("Offset: 0x\(String(tagOffset, radix: 16, uppercase: true))")
        print("Length: \(tagLength) bytes")
        print()
        
        let dataToShow = fileData[tagOffset..<min(tagOffset + tagLength, fileData.count)]
        
        let dumper = HexDumper(
            bytesPerLine: bytesPerLine,
            useColor: !noColor,
            annotate: false,
            verbose: verbose
        )
        
        let output = dumper.dump(
            data: dataToShow,
            startOffset: tagOffset,
            dicomFile: dicomFile,
            highlightTag: targetTag
        )
        
        print(output)
    }
    
    private func findTagInRawData(fileData: Data, tag: Tag) -> (offset: Int, length: Int)? {
        // Search for tag in raw data
        // Tags are stored as group (2 bytes) + element (2 bytes)
        let groupBytes = withUnsafeBytes(of: tag.group.littleEndian) { Data($0) }
        let elementBytes = withUnsafeBytes(of: tag.element.littleEndian) { Data($0) }
        var searchData = Data()
        searchData.append(groupBytes)
        searchData.append(elementBytes)
        
        // Simple search for the tag
        if let range = fileData.range(of: searchData) {
            // Found the tag, now try to determine its length
            let tagStart = range.lowerBound
            
            // Assume explicit VR - skip tag (4 bytes) to read VR (2 bytes)
            if tagStart + 8 <= fileData.count {
                // Read length (varies by VR type)
                // Simplified: assume standard length field at offset +6
                let lengthStart = tagStart + 6
                if lengthStart + 2 <= fileData.count {
                    let lengthBytes = fileData[lengthStart..<lengthStart + 2]
                    let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt16.self) }
                    
                    // Total includes tag header (4) + VR (2) + length (2) + value
                    return (tagStart, Int(length) + 8)
                }
            }
            
            // Fallback: just return reasonable chunk
            return (tagStart, min(256, fileData.count - tagStart))
        }
        
        return nil
    }
    
    private func formatTag(_ tag: Tag) -> String {
        String(format: "(%04X,%04X)", tag.group, tag.element)
    }
}

struct ValidationError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        message
    }
}

DICOMDump.main()
