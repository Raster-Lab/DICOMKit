#!/usr/bin/env python3
"""
Generate DICOM Data Element Dictionary resource and Swift loader.

Produces:
  - Resources/DataElementDictionary.txt: pipe-delimited dictionary data (not compiled)
  - DataElementDictionary.swift: minimal Swift loader (~60 lines, compiles instantly)
  - Removes any old DataElementDictionary+DataN.swift chunk files

The resource-based approach eliminates compilation of dictionary data entirely.
"""

import sys
import os
import glob

try:
    from pydicom.datadict import DicomDictionary
except ImportError:
    print("Error: pydicom is required. Install with: pip3 install pydicom", file=sys.stderr)
    sys.exit(1)

# Map pydicom VR strings to Swift VR enum cases
VR_MAP = {
    "AE": "AE", "AS": "AS", "AT": "AT", "CS": "CS", "DA": "DA",
    "DS": "DS", "DT": "DT", "FL": "FL", "FD": "FD", "IS": "IS",
    "LO": "LO", "LT": "LT", "OB": "OB", "OD": "OD", "OF": "OF",
    "OL": "OL", "OW": "OW", "PN": "PN", "SH": "SH", "SL": "SL",
    "SQ": "SQ", "SS": "SS", "ST": "ST", "TM": "TM", "UC": "UC",
    "UI": "UI", "UL": "UL", "UN": "UN", "UR": "UR", "US": "US",
    "UT": "UT",
    # Multi-VR: pick first one
    "US or SS": "US", "OB or OW": "OB", "US or OW": "US",
    "US or SS or OW": "US", "OW or OB": "OW",
    # OV/SV/UV are newer VRs not yet in the Swift VR enum - map to compatible types
    "OV": "UN", "SV": "SL", "UV": "UL",
}

def to_keyword(keyword):
    """Use PascalCase keyword as-is from DICOM standard."""
    if not keyword:
        return "Unknown"
    return keyword

def main():
    base_dir = "Sources/DICOMDictionary"
    resource_dir = f"{base_dir}/Resources"
    os.makedirs(resource_dir, exist_ok=True)

    # Remove old chunk files from previous generator version
    for old_file in glob.glob(f"{base_dir}/DataElementDictionary+Data*.swift"):
        os.remove(old_file)
        print(f"Removed old file: {old_file}")

    # Collect all standard (non-repeating) tags
    data_lines = []
    for tag_int, (vr_str, vm, name, retired_str, keyword) in sorted(DicomDictionary.items()):
        group = (tag_int >> 16) & 0xFFFF
        element = tag_int & 0xFFFF

        # Skip repeating group tags
        if group % 2 == 1 and group >= 0x6001 and group <= 0x60FF:
            continue
        if group % 2 == 1 and group >= 0x5001 and group <= 0x50FF:
            continue

        swift_vr = VR_MAP.get(vr_str)
        if swift_vr is None:
            continue

        kw = to_keyword(keyword) if keyword else to_keyword(name.replace(" ", ""))
        data_lines.append(f"{group:04X}|{element:04X}|{name}|{kw}|{swift_vr}|{vm}")

    # Write resource file
    resource_path = f"{resource_dir}/DataElementDictionary.txt"
    with open(resource_path, "w") as f:
        f.write("\n".join(data_lines))
        f.write("\n")
    print(f"Generated {resource_path} ({len(data_lines)} entries)")

    # Generate minimal Swift loader
    swift_path = f"{base_dir}/DataElementDictionary.swift"
    swift_code = f'''import Foundation
import DICOMCore

/// Comprehensive DICOM Data Element Dictionary
///
/// Contains all standard DICOM data elements from PS3.6 2026a.
/// Total entries: {len(data_lines)}
///
/// Dictionary data is stored as a bundled resource file for zero compilation overhead.
/// Parsed once at first access and cached in a static dictionary.
public struct DataElementDictionary: Sendable {{

    // MARK: - Parsed Dictionary

    private static let entries: [Tag: DataElementEntry] = {{
        guard let url = Bundle.module.url(forResource: "DataElementDictionary", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {{
            return [:]
        }}
        var dict = [Tag: DataElementEntry](minimumCapacity: {len(data_lines)})
        for line in content.split(separator: "\\n") {{
            let fields = line.split(separator: "|", maxSplits: 5)
            guard fields.count == 6,
                  let group = UInt16(fields[0], radix: 16),
                  let element = UInt16(fields[1], radix: 16) else {{ continue }}
            let tag = Tag(group: group, element: element)
            let vr = VR(rawValue: String(fields[4])) ?? .UN
            dict[tag] = DataElementEntry(
                tag: tag,
                name: String(fields[2]),
                keyword: String(fields[3]),
                vr: vr,
                vm: String(fields[5])
            )
        }}
        return dict
    }}()

    /// Looks up a data element entry by tag
    /// - Parameter tag: The tag to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(tag: Tag) -> DataElementEntry? {{
        return entries[tag]
    }}

    /// Looks up a data element entry by keyword
    /// - Parameter keyword: The keyword to look up
    /// - Returns: The dictionary entry, or nil if not found
    public static func lookup(keyword: String) -> DataElementEntry? {{
        return entries.values.first {{ $0.keyword == keyword }}
    }}
}}
'''
    with open(swift_path, "w") as f:
        f.write(swift_code)
    print(f"Generated {swift_path} (loader)")

    print(f"\\nTotal: {len(data_lines)} entries — resource file + minimal Swift loader")

if __name__ == "__main__":
    main()

