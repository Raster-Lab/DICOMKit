// DICOMTagView.swift
// DICOMStudio
//
// DICOM Studio — Reusable DICOM tag display component

import Foundation

/// Platform-independent DICOM tag formatting utilities.
///
/// Provides string formatting for DICOM tags without requiring SwiftUI.
public enum DICOMTagFormatter: Sendable {

    /// Formats a DICOM tag as `(GGGG,EEEE)`.
    ///
    /// - Parameters:
    ///   - group: Tag group number.
    ///   - element: Tag element number.
    /// - Returns: Formatted tag string.
    public static func tagString(group: UInt16, element: UInt16) -> String {
        String(format: "(%04X,%04X)", group, element)
    }

    /// Returns an accessibility description for a DICOM tag.
    ///
    /// - Parameters:
    ///   - group: Tag group number.
    ///   - element: Tag element number.
    ///   - keyword: Optional tag keyword (e.g. "PatientName").
    /// - Returns: Accessibility-friendly description.
    public static func accessibilityText(group: UInt16, element: UInt16, keyword: String? = nil) -> String {
        let tag = String(format: "group %04X element %04X", group, element)
        if let keyword = keyword {
            return "\(keyword), tag \(tag)"
        }
        return "Tag \(tag)"
    }
}

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
            Text(DICOMTagFormatter.tagString(group: group, element: element))
                .font(.system(size: StudioTypography.monoSize, design: .monospaced))
                .foregroundStyle(.secondary)
            if let keyword = keyword {
                Text(keyword)
                    .font(.system(size: StudioTypography.captionSize))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DICOMTagFormatter.accessibilityText(group: group, element: element, keyword: keyword))
    }
}
#endif
