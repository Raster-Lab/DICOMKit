# ``DICOMDictionary``

DICOM data element dictionary and UID registry for tag lookup and validation.

## Overview

DICOMDictionary provides comprehensive dictionaries for DICOM data elements and UIDs. It enables tag lookup, VR inference, and validation against the DICOM standard.

### Key Features

- **Data Element Dictionary**: Complete registry of standard DICOM tags
- **UID Dictionary**: Registry of SOP Classes, Transfer Syntaxes, and other UIDs
- **Tag Lookup**: Find tag information by group/element or keyword
- **VR Inference**: Determine Value Representation for tags

## Topics

### Data Element Dictionary

- ``DataElementDictionary``
- ``DictionaryEntry``

### UID Dictionary

- ``UIDDictionary``

## Example Usage

```swift
import DICOMDictionary

// Look up a tag
if let entry = DataElementDictionary.shared.lookup(group: 0x0010, element: 0x0010) {
    print("Tag: \(entry.keyword)")      // "PatientName"
    print("VR: \(entry.vr)")            // "PN"
    print("VM: \(entry.vm)")            // "1"
}

// Look up by keyword
if let entry = DataElementDictionary.shared.lookup(keyword: "StudyDescription") {
    print("Group: \(String(format: "0x%04X", entry.group))")
    print("Element: \(String(format: "0x%04X", entry.element))")
}

// Look up a UID
if let name = UIDDictionary.shared.name(for: "1.2.840.10008.5.1.4.1.1.2") {
    print("SOP Class: \(name)")  // "CT Image Storage"
}
```
