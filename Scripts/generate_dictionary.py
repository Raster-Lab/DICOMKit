#!/usr/bin/env python3
"""Generate DataElementDictionary.swift from Tag+*.swift extension files."""

import re
import glob
import sys

files = sorted(glob.glob('Sources/DICOMCore/Tag+*.swift'))

entries = []
seen_tags = set()

for f in files:
    with open(f) as fh:
        lines = fh.readlines()

    for i, line in enumerate(lines):
        # Match doc comment: /// <Name> (GGGG,EEEE)
        m = re.match(r'\s*///\s+(.+?)\s+\(([0-9A-Fa-f]{4}),\s*([0-9A-Fa-f]{4})\)\s*$', line)
        if not m:
            continue

        tag_name = m.group(1).strip()
        group = m.group(2).upper()
        element = m.group(3).upper()
        tag_key = f"{group},{element}"

        if tag_key in seen_tags:
            continue
        seen_tags.add(tag_key)

        # Look at next line for VR
        vr = 'UN'
        vm = '1'
        if i + 1 < len(lines):
            vm_match = re.match(r'\s*///\s+VR:\s+(\w+),\s+VM:\s+([\S]+)', lines[i + 1])
            if vm_match:
                vr = vm_match.group(1)
                vm = vm_match.group(2)

        # Look for the static let to get the keyword
        keyword = ''
        for j in range(i + 1, min(i + 4, len(lines))):
            kw_match = re.match(r'\s*public\s+static\s+let\s+(\w+)\s*=', lines[j])
            if kw_match:
                keyword = kw_match.group(1)
                break

        if not keyword:
            keyword = tag_name.replace("'s ", "").replace("'", "").replace(" ", "")

        entries.append((group, element, tag_name, keyword, vr, vm))

# Sort by group then element
entries.sort(key=lambda e: (int(e[0], 16), int(e[1], 16)))

print(f"Found {len(entries)} unique tag entries from {len(files)} files", file=sys.stderr)

# Generate Swift code
print("import DICOMCore")
print()
print("/// Standard DICOM Data Element Dictionary")
print("///")
print("/// Provides lookup for standard DICOM data elements.")
print("/// Generated from Tag+*.swift extension files covering PS3.6 2026a.")
print("public struct DataElementDictionary {")
print()
print("    private static let entries: [Tag: DataElementEntry] = {")
print("        var dict: [Tag: DataElementEntry] = [:]")
print()

for group, element, name, keyword, vr, vm in entries:
    # Escape any quotes in name
    escaped_name = name.replace('"', '\\"')
    escaped_keyword = keyword.replace('"', '\\"')
    print(f'        dict[Tag(group: 0x{group}, element: 0x{element})] = DataElementEntry(')
    print(f'            tag: Tag(group: 0x{group}, element: 0x{element}),')
    print(f'            name: "{escaped_name}",')
    print(f'            keyword: "{escaped_keyword}",')
    print(f'            vr: .{vr},')
    print(f'            vm: "{vm}"')
    print(f'        )')
    print()

print("        return dict")
print("    }()")
print()
print("    /// Looks up a data element entry by tag")
print("    /// - Parameter tag: The tag to look up")
print("    /// - Returns: The dictionary entry, or nil if not found")
print("    public static func lookup(tag: Tag) -> DataElementEntry? {")
print("        return entries[tag]")
print("    }")
print()
print("    /// Looks up a data element entry by keyword")
print("    /// - Parameter keyword: The keyword to look up")
print("    /// - Returns: The dictionary entry, or nil if not found")
print("    public static func lookup(keyword: String) -> DataElementEntry? {")
print("        return entries.values.first { $0.keyword == keyword }")
print("    }")
print("}")
