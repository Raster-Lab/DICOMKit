import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMDiff: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-diff",
        abstract: "Compare two DICOM files and report differences",
        discussion: """
            Compares metadata tags and optionally pixel data between two DICOM files.
            Supports filtering, tolerance settings, and multiple output formats.
            
            Examples:
              dicom-diff file1.dcm file2.dcm
              dicom-diff --compare-pixels --tolerance 5 original.dcm processed.dcm
              dicom-diff --ignore-tag 0008,0012 --format json file1.dcm file2.dcm
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "First DICOM file to compare")
    var file1: String
    
    @Argument(help: "Second DICOM file to compare")
    var file2: String
    
    @Option(name: .shortAndLong, help: "Output format: text, json, summary")
    var format: OutputFormat = .text
    
    @Option(name: .long, help: "Tags to ignore (can be used multiple times, e.g. '0008,0012' or 'SOPInstanceUID')")
    var ignoreTag: [String] = []
    
    @Flag(name: .long, help: "Ignore all private tags")
    var ignorePrivate: Bool = false
    
    @Flag(name: .long, help: "Compare pixel data")
    var comparePixels: Bool = false
    
    @Option(name: .long, help: "Pixel value tolerance for comparison (default: 0)")
    var tolerance: Double = 0.0
    
    @Flag(name: .long, help: "Quick mode: metadata only, skip pixel data")
    var quick: Bool = false
    
    @Flag(name: .long, help: "Show identical tags in detailed mode")
    var showIdentical: Bool = false
    
    @Flag(name: .long, help: "Verbose output with detailed information")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Validate files exist
        guard FileManager.default.fileExists(atPath: file1) else {
            throw ValidationError("File not found: \(file1)")
        }
        
        guard FileManager.default.fileExists(atPath: file2) else {
            throw ValidationError("File not found: \(file2)")
        }
        
        // Read DICOM files
        let data1 = try Data(contentsOf: URL(fileURLWithPath: file1))
        let data2 = try Data(contentsOf: URL(fileURLWithPath: file2))
        
        let dicomFile1 = try DICOMFile.read(from: data1)
        let dicomFile2 = try DICOMFile.read(from: data2)
        
        if verbose {
            print("Comparing: \(URL(fileURLWithPath: file1).lastPathComponent)")
            print("     with: \(URL(fileURLWithPath: file2).lastPathComponent)")
            print()
        }
        
        // Parse ignore tags
        let tagsToIgnore = try parseIgnoreTags(ignoreTag)
        
        // Perform comparison
        let comparer = DICOMComparer(
            file1: dicomFile1,
            file2: dicomFile2,
            tagsToIgnore: tagsToIgnore,
            ignorePrivate: ignorePrivate,
            comparePixels: comparePixels && !quick,
            pixelTolerance: tolerance,
            showIdentical: showIdentical
        )
        
        let result = try comparer.compare()
        
        // Output results
        let output = try formatOutput(result, format: format)
        print(output)
        
        // Exit with appropriate code
        if result.hasDifferences {
            throw ExitCode(1)
        }
    }
    
    private func parseIgnoreTags(_ tags: [String]) throws -> Set<Tag> {
        var result = Set<Tag>()
        
        for tagStr in tags {
            if let tag = parseTag(tagStr) {
                result.insert(tag)
            } else {
                throw ValidationError("Invalid tag format: \(tagStr). Use format like '0008,0012' or tag keyword like 'SOPInstanceUID'")
            }
        }
        
        return result
    }
    
    private func parseTag(_ str: String) -> Tag? {
        // Try parsing as hex notation (0008,0012)
        let components = str.components(separatedBy: ",")
        if components.count == 2,
           let group = UInt16(components[0], radix: 16),
           let element = UInt16(components[1], radix: 16) {
            return Tag(group: group, element: element)
        }
        
        // Try looking up by keyword
        return DataElementDictionary.lookup(keyword: str)?.tag
    }
    
    private func formatOutput(_ result: ComparisonResult, format: OutputFormat) throws -> String {
        switch format {
        case .text:
            return formatTextOutput(result)
        case .json:
            return try formatJSONOutput(result)
        case .summary:
            return formatSummaryOutput(result)
        }
    }
    
    private func formatTextOutput(_ result: ComparisonResult) -> String {
        var output = ""
        
        // Summary
        output += "=== DICOM Comparison Results ===\n\n"
        output += "Total tags compared: \(result.totalTags)\n"
        output += "Differences found: \(result.differenceCount)\n"
        output += "Tags only in file 1: \(result.onlyInFile1.count)\n"
        output += "Tags only in file 2: \(result.onlyInFile2.count)\n"
        output += "Modified tags: \(result.modified.count)\n"
        
        if result.pixelsCompared {
            output += "\nPixel Data: \(result.pixelsDifferent ? "DIFFERENT" : "IDENTICAL")\n"
            if let diff = result.pixelDifference {
                output += "  Max difference: \(diff.maxDifference)\n"
                output += "  Mean difference: \(String(format: "%.2f", diff.meanDifference))\n"
                output += "  Different pixels: \(diff.differentPixelCount) / \(diff.totalPixels)\n"
            }
        }
        
        output += "\n"
        
        // Detailed differences
        if !result.onlyInFile1.isEmpty {
            output += "\n--- Tags only in \(URL(fileURLWithPath: file1).lastPathComponent) ---\n"
            for tag in result.onlyInFile1.sorted(by: { $0.key < $1.key }) {
                output += formatTagValue(tag.key, tag.value)
            }
        }
        
        if !result.onlyInFile2.isEmpty {
            output += "\n--- Tags only in \(URL(fileURLWithPath: file2).lastPathComponent) ---\n"
            for tag in result.onlyInFile2.sorted(by: { $0.key < $1.key }) {
                output += formatTagValue(tag.key, tag.value)
            }
        }
        
        if !result.modified.isEmpty {
            output += "\n--- Modified Tags ---\n"
            for modification in result.modified.sorted(by: { $0.tag < $1.tag }) {
                let tagName = DataElementDictionary.lookup(tag: modification.tag)?.name ?? "Unknown"
                output += "\n[\(modification.tag)] \(tagName)\n"
                output += "  File 1: \(formatValue(modification.value1))\n"
                output += "  File 2: \(formatValue(modification.value2))\n"
            }
        }
        
        if showIdentical && !result.identical.isEmpty {
            output += "\n--- Identical Tags (\(result.identical.count)) ---\n"
            for tag in result.identical.sorted() {
                if let elem = result.file1Data[tag] {
                    output += formatTagValue(tag, elem)
                }
            }
        }
        
        output += "\n=== End of Comparison ===\n"
        
        return output
    }
    
    private func formatJSONOutput(_ result: ComparisonResult) throws -> String {
        var json: [String: Any] = [
            "files": [
                "file1": URL(fileURLWithPath: file1).lastPathComponent,
                "file2": URL(fileURLWithPath: file2).lastPathComponent
            ],
            "summary": [
                "totalTags": result.totalTags,
                "differences": result.differenceCount,
                "hasDifferences": result.hasDifferences
            ],
            "onlyInFile1": result.onlyInFile1.map { ["tag": $0.key.description, "value": formatValue($0.value)] },
            "onlyInFile2": result.onlyInFile2.map { ["tag": $0.key.description, "value": formatValue($0.value)] },
            "modified": result.modified.map { [
                "tag": $0.tag.description,
                "tagName": DataElementDictionary.lookup(tag: $0.tag)?.name ?? "Unknown",
                "value1": formatValue($0.value1),
                "value2": formatValue($0.value2)
            ]}
        ]
        
        if result.pixelsCompared {
            json["pixelData"] = [
                "compared": true,
                "different": result.pixelsDifferent,
                "maxDifference": result.pixelDifference?.maxDifference as Any,
                "meanDifference": result.pixelDifference?.meanDifference as Any,
                "differentPixelCount": result.pixelDifference?.differentPixelCount as Any,
                "totalPixels": result.pixelDifference?.totalPixels as Any
            ] as [String : Any]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func formatSummaryOutput(_ result: ComparisonResult) -> String {
        var output = ""
        output += "Files: \(result.hasDifferences ? "DIFFERENT" : "IDENTICAL")\n"
        output += "Differences: \(result.differenceCount)\n"
        output += "  Only in file 1: \(result.onlyInFile1.count)\n"
        output += "  Only in file 2: \(result.onlyInFile2.count)\n"
        output += "  Modified: \(result.modified.count)\n"
        
        if result.pixelsCompared {
            output += "Pixel data: \(result.pixelsDifferent ? "DIFFERENT" : "IDENTICAL")\n"
        }
        
        return output
    }
    
    private func formatTagValue(_ tag: Tag, _ element: DataElement) -> String {
        let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
        let value = formatValue(element)
        return "[\(tag)] \(tagName): \(value)\n"
    }
    
    private func formatValue(_ element: DataElement) -> String {
        // Handle different value representations
        if element.vr == .SQ {
            return "<Sequence with \(element.sequenceItems?.count ?? 0) items>"
        }
        
        if element.vr == .OB || element.vr == .OW || element.vr == .OF || element.vr == .OD {
            let byteCount = element.valueData.count
            return "<Binary data, \(byteCount) bytes>"
        }
        
        return element.stringValue ?? "<empty>"
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
    case summary
}

// MARK: - Comparer

struct DICOMComparer {
    let file1: DICOMFile
    let file2: DICOMFile
    let tagsToIgnore: Set<Tag>
    let ignorePrivate: Bool
    let comparePixels: Bool
    let pixelTolerance: Double
    let showIdentical: Bool
    
    func compare() throws -> ComparisonResult {
        var result = ComparisonResult()
        
        let dataSet1 = file1.dataSet
        let dataSet2 = file2.dataSet
        
        // Build element dictionaries for result
        for tag in dataSet1.tags {
            if let element = dataSet1[tag] {
                result.file1Data[tag] = element
            }
        }
        for tag in dataSet2.tags {
            if let element = dataSet2[tag] {
                result.file2Data[tag] = element
            }
        }
        
        let allTags = Set(dataSet1.tags).union(Set(dataSet2.tags))
        
        for tag in allTags {
            // Skip ignored tags
            if tagsToIgnore.contains(tag) {
                continue
            }
            
            // Skip private tags if requested
            if ignorePrivate && tag.isPrivate {
                continue
            }
            
            // Skip pixel data tag (handled separately)
            if comparePixels && tag == Tag.pixelData {
                continue
            }
            
            result.totalTags += 1
            
            let elem1 = dataSet1[tag]
            let elem2 = dataSet2[tag]
            
            switch (elem1, elem2) {
            case (nil, let elem2?):
                result.onlyInFile2[tag] = elem2
                result.differenceCount += 1
                
            case (let elem1?, nil):
                result.onlyInFile1[tag] = elem1
                result.differenceCount += 1
                
            case (let elem1?, let elem2?):
                if !areElementsEqual(elem1, elem2) {
                    result.modified.append(TagModification(tag: tag, value1: elem1, value2: elem2))
                    result.differenceCount += 1
                } else {
                    result.identical.insert(tag)
                }
                
            case (nil, nil):
                break
            }
        }
        
        // Compare pixel data if requested
        if comparePixels {
            result.pixelsCompared = true
            if let pixelDiff = try comparePixelData(dataSet1, dataSet2) {
                result.pixelsDifferent = pixelDiff.maxDifference > pixelTolerance
                result.pixelDifference = pixelDiff
            }
        }
        
        return result
    }
    
    private func areElementsEqual(_ elem1: DataElement, _ elem2: DataElement) -> Bool {
        // VR must match
        if elem1.vr != elem2.vr {
            return false
        }
        
        // For sequences, compare recursively
        if elem1.vr == .SQ {
            guard let seq1 = elem1.sequenceItems,
                  let seq2 = elem2.sequenceItems,
                  seq1.count == seq2.count else {
                return false
            }
            
            for (item1, item2) in zip(seq1, seq2) {
                if !areSequenceItemsEqual(item1, item2) {
                    return false
                }
            }
            
            return true
        }
        
        // Compare data
        return elem1.valueData == elem2.valueData
    }
    
    private func areDataSetsEqual(_ ds1: DataSet, _ ds2: DataSet) -> Bool {
        let tags1 = Set(ds1.tags)
        let tags2 = Set(ds2.tags)
        
        guard tags1 == tags2 else {
            return false
        }
        
        for tag in tags1 {
            guard let elem1 = ds1[tag],
                  let elem2 = ds2[tag],
                  areElementsEqual(elem1, elem2) else {
                return false
            }
        }
        
        return true
    }
    
    private func areSequenceItemsEqual(_ item1: SequenceItem, _ item2: SequenceItem) -> Bool {
        let tags1 = Set(item1.elements.keys)
        let tags2 = Set(item2.elements.keys)
        
        guard tags1 == tags2 else {
            return false
        }
        
        for tag in tags1 {
            guard let elem1 = item1.elements[tag],
                  let elem2 = item2.elements[tag],
                  areElementsEqual(elem1, elem2) else {
                return false
            }
        }
        
        return true
    }
    
    private func comparePixelData(_ ds1: DataSet, _ ds2: DataSet) throws -> PixelDifference? {
        guard let pixelElem1 = ds1[Tag.pixelData],
              let pixelElem2 = ds2[Tag.pixelData] else {
            return nil
        }
        
        let pixelData1 = pixelElem1.valueData
        let pixelData2 = pixelElem2.valueData
        
        // Simple byte comparison for now
        let minLength = min(pixelData1.count, pixelData2.count)
        
        var maxDiff: Double = 0
        var totalDiff: Double = 0
        var diffCount = 0
        
        for i in 0..<minLength {
            let diff = abs(Double(pixelData1[i]) - Double(pixelData2[i]))
            if diff > 0 {
                maxDiff = max(maxDiff, diff)
                totalDiff += diff
                diffCount += 1
            }
        }
        
        // Account for different lengths
        if pixelData1.count != pixelData2.count {
            diffCount += abs(pixelData1.count - pixelData2.count)
        }
        
        let totalPixels = max(pixelData1.count, pixelData2.count)
        let meanDiff = diffCount > 0 ? totalDiff / Double(diffCount) : 0
        
        return PixelDifference(
            maxDifference: maxDiff,
            meanDifference: meanDiff,
            differentPixelCount: diffCount,
            totalPixels: totalPixels
        )
    }
}

// MARK: - Results

struct ComparisonResult {
    var totalTags: Int = 0
    var differenceCount: Int = 0
    var onlyInFile1: [Tag: DataElement] = [:]
    var onlyInFile2: [Tag: DataElement] = [:]
    var modified: [TagModification] = []
    var identical: Set<Tag> = []
    var pixelsCompared: Bool = false
    var pixelsDifferent: Bool = false
    var pixelDifference: PixelDifference?
    
    // Keep references for detailed output
    var file1Data: [Tag: DataElement] = [:]
    var file2Data: [Tag: DataElement] = [:]
    
    var hasDifferences: Bool {
        return differenceCount > 0 || pixelsDifferent
    }
}

struct TagModification {
    let tag: Tag
    let value1: DataElement
    let value2: DataElement
}

struct PixelDifference {
    let maxDifference: Double
    let meanDifference: Double
    let differentPixelCount: Int
    let totalPixels: Int
}

DICOMDiff.main()
