import Foundation
import DICOMCore

/// Comprehensive DICOM Data Element Dictionary
///
/// Contains all standard DICOM data elements from PS3.6 2026a.
/// Total entries: 5036
///
/// Dictionary data is stored as a bundled resource file for zero compilation overhead.
/// Parsed once at first access and cached in a static dictionary.
public struct DataElementDictionary: Sendable {

    // MARK: - Parsed Dictionary

    private static let entries: [Tag: DataElementEntry] = {
        guard let url = Bundle.module.url(forResource: "DataElementDictionary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }
        var dict = [Tag: DataElementEntry](minimumCapacity: 5036)
        for line in content.split(separator: "\n") {
            let fields = line.split(separator: "|", maxSplits: 5)
            guard fields.count == 6,
                  let group = UInt16(fields[0], radix: 16),
                  let element = UInt16(fields[1], radix: 16) else { continue }
            let tag = Tag(group: group, element: element)
            let vr = VR(rawValue: String(fields[4])) ?? .UN
            dict[tag] = DataElementEntry(
                tag: tag,
                name: String(fields[2]),
                keyword: String(fields[3]),
                vr: vr,
                vm: String(fields[5])
            )
        }
        return dict
    }()

    /// Looks up a data element entry by tag
    /// - Parameter tag: The tag to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(tag: Tag) -> DataElementEntry? {
        return entries[tag]
    }

    /// Looks up a data element entry by keyword
    /// - Parameter keyword: The keyword to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(keyword: String) -> DataElementEntry? {
        return entries.values.first { $0.keyword == keyword }
    }
}
