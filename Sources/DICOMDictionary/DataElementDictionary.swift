import Foundation
import DICOMCore

enum DICOMDictionaryResourceBundle {
    static let bundleName = "DICOMKit_DICOMDictionary.bundle"

    static func packagedBundle(mainResourceURL: URL?) -> Bundle? {
        guard let mainResourceURL else { return nil }
        return Bundle(url: mainResourceURL.appendingPathComponent(bundleName, isDirectory: true))
    }

    static var resolved: Bundle {
        // SwiftPM's generated Bundle.module accessor looks beside Bundle.main's
        // bundle URL. A conventionally signed macOS app must instead place
        // nested resource bundles in Contents/Resources, so prefer that
        // production location and retain Bundle.module for package tools/tests.
        packagedBundle(mainResourceURL: Bundle.main.resourceURL) ?? Bundle.module
    }
}

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
        guard let url = DICOMDictionaryResourceBundle.resolved.url(
            forResource: "DataElementDictionary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }
        var dict = [Tag: DataElementEntry](minimumCapacity: 5036)
        for line in content.split(separator: "\n") {
            // Keep empty subsequences so a blank field (e.g. an empty Name)
            // doesn't collapse the column count and drop/misalign the row.
            let fields = line.split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
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
