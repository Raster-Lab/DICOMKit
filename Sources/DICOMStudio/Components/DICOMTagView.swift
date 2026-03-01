// DICOMTagView.swift
// DICOMStudio
//
// DICOM Studio — Reusable DICOM tag display component

#if canImport(SwiftUI)
import SwiftUI

/// Displays a DICOM tag in (GGGG,EEEE) format with optional keyword.
///
/// Usage:
/// ```swift
/// DICOMTagView(group: 0x0010, element: 0x0010, keyword: "PatientName")
/// ```
@available(macOS 14.0, iOS 17.0, *)
public struct DICOMTagView: View {
    let group: UInt16
    let element: UInt16
    let keyword: String?

    public init(group: UInt16, element: UInt16, keyword: String? = nil) {
        self.group = group
        self.element = element
        self.keyword = keyword
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(tagString)
                .font(.system(size: StudioTypography.monoSize, design: .monospaced))
                .foregroundStyle(.secondary)
            if let keyword = keyword {
                Text(keyword)
                    .font(.system(size: StudioTypography.captionSize))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var tagString: String {
        String(format: "(%04X,%04X)", group, element)
    }

    private var accessibilityText: String {
        let tag = String(format: "group %04X element %04X", group, element)
        if let keyword = keyword {
            return "\(keyword), tag \(tag)"
        }
        return "Tag \(tag)"
    }
}
#endif
