// DICOMComparer.swift
// DICOMCLITools
//
// Shared comparison logic for `dicom-diff`. Used by both the CLI executable
// and the DICOMStudio GUI's CLI Workshop so both produce identical output.

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary

/// Output format selector for `dicom-diff`.
public enum DiffOutputFormat: String, CaseIterable, Sendable {
    case text
    case json
    case summary
}

/// A single tag value modification between two files.
public struct TagModification: Sendable {
    public let tag: Tag
    public let value1: DataElement
    public let value2: DataElement

    public init(tag: Tag, value1: DataElement, value2: DataElement) {
        self.tag = tag
        self.value1 = value1
        self.value2 = value2
    }
}

/// Pixel-data difference statistics.
public struct PixelDifference: Sendable {
    public let maxDifference: Double
    public let meanDifference: Double
    public let differentPixelCount: Int
    public let totalPixels: Int

    public init(maxDifference: Double, meanDifference: Double, differentPixelCount: Int, totalPixels: Int) {
        self.maxDifference = maxDifference
        self.meanDifference = meanDifference
        self.differentPixelCount = differentPixelCount
        self.totalPixels = totalPixels
    }
}

/// Result of comparing two DICOM files.
public struct ComparisonResult: Sendable {
    public var totalTags: Int = 0
    public var differenceCount: Int = 0
    public var onlyInFile1: [Tag: DataElement] = [:]
    public var onlyInFile2: [Tag: DataElement] = [:]
    public var modified: [TagModification] = []
    public var identical: Set<Tag> = []
    public var pixelsCompared: Bool = false
    public var pixelsDifferent: Bool = false
    public var pixelDifference: PixelDifference?

    public var file1Data: [Tag: DataElement] = [:]
    public var file2Data: [Tag: DataElement] = [:]

    public var hasDifferences: Bool {
        return differenceCount > 0 || pixelsDifferent
    }

    public init() {}
}

/// Compares two DICOM files producing a `ComparisonResult`.
public struct DICOMComparer: Sendable {
    public let file1: DICOMFile
    public let file2: DICOMFile
    public let tagsToIgnore: Set<Tag>
    public let ignorePrivate: Bool
    public let comparePixels: Bool
    public let pixelTolerance: Double
    public let showIdentical: Bool

    public init(
        file1: DICOMFile,
        file2: DICOMFile,
        tagsToIgnore: Set<Tag> = [],
        ignorePrivate: Bool = false,
        comparePixels: Bool = false,
        pixelTolerance: Double = 0.0,
        showIdentical: Bool = false
    ) {
        self.file1 = file1
        self.file2 = file2
        self.tagsToIgnore = tagsToIgnore
        self.ignorePrivate = ignorePrivate
        self.comparePixels = comparePixels
        self.pixelTolerance = pixelTolerance
        self.showIdentical = showIdentical
    }

    public func compare() throws -> ComparisonResult {
        var result = ComparisonResult()

        let dataSet1 = file1.dataSet
        let dataSet2 = file2.dataSet

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
            if tagsToIgnore.contains(tag) {
                continue
            }
            if ignorePrivate && tag.isPrivate {
                continue
            }
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
        if elem1.vr != elem2.vr {
            return false
        }

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

        return elem1.valueData == elem2.valueData
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

// MARK: - Diff Output Formatter

/// Formats a `ComparisonResult` for display. Output is identical to what
/// `dicom-diff` emits to stdout.
public struct DiffOutputFormatter: Sendable {
    public let file1Path: String
    public let file2Path: String
    public let showIdentical: Bool

    public init(file1Path: String, file2Path: String, showIdentical: Bool = false) {
        self.file1Path = file1Path
        self.file2Path = file2Path
        self.showIdentical = showIdentical
    }

    public func format(_ result: ComparisonResult, format: DiffOutputFormat) throws -> String {
        switch format {
        case .text:    return formatText(result)
        case .json:    return try formatJSON(result)
        case .summary: return formatSummary(result)
        }
    }

    private func formatText(_ result: ComparisonResult) -> String {
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

        if !result.onlyInFile1.isEmpty {
            output += "\n--- Tags only in \(URL(fileURLWithPath: file1Path).lastPathComponent) ---\n"
            for tag in result.onlyInFile1.sorted(by: { $0.key < $1.key }) {
                output += formatTagValue(tag.key, tag.value)
            }
        }

        if !result.onlyInFile2.isEmpty {
            output += "\n--- Tags only in \(URL(fileURLWithPath: file2Path).lastPathComponent) ---\n"
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

    private func formatJSON(_ result: ComparisonResult) throws -> String {
        var json: [String: Any] = [
            "files": [
                "file1": URL(fileURLWithPath: file1Path).lastPathComponent,
                "file2": URL(fileURLWithPath: file2Path).lastPathComponent
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

    private func formatSummary(_ result: ComparisonResult) -> String {
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
