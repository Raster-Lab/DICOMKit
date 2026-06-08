import Foundation
import DICOMCore
import DICOMDictionary

/// Compares two DICOM files and reports metadata (and optionally pixel-data)
/// differences.
///
/// Lives in the DICOMKit library so the `dicom-diff` CLI and DICOMStudio run the
/// exact same comparison code and cannot drift. Rendering is handled separately
/// by ``ComparisonReport``.
public struct DICOMComparer {
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
        tagsToIgnore: Set<Tag>,
        ignorePrivate: Bool,
        comparePixels: Bool,
        pixelTolerance: Double,
        showIdentical: Bool
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

/// The outcome of a ``DICOMComparer`` run.
public struct ComparisonResult {
    public var totalTags: Int = 0
    public var differenceCount: Int = 0
    public var onlyInFile1: [Tag: DataElement] = [:]
    public var onlyInFile2: [Tag: DataElement] = [:]
    public var modified: [TagModification] = []
    public var identical: Set<Tag> = []
    public var pixelsCompared: Bool = false
    public var pixelsDifferent: Bool = false
    public var pixelDifference: PixelDifference?

    // Full element maps, kept for detailed output.
    public var file1Data: [Tag: DataElement] = [:]
    public var file2Data: [Tag: DataElement] = [:]

    public var hasDifferences: Bool {
        return differenceCount > 0 || pixelsDifferent
    }

    public init() {}
}

/// A tag whose value differs between the two files.
public struct TagModification {
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
public struct PixelDifference {
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
