// VRBadge.swift
// DICOMStudio
//
// DICOM Studio — Value Representation badge component

#if canImport(SwiftUI)
import SwiftUI

/// Displays a DICOM Value Representation as a compact badge.
///
/// Usage:
/// ```swift
/// VRBadge(vr: "PN")
/// VRBadge(vr: "UI")
/// ```
@available(macOS 14.0, iOS 17.0, *)
public struct VRBadge: View {
    let vr: String

    public init(vr: String) {
        self.vr = vr.uppercased()
    }

    public var body: some View {
        Text(vr)
            .font(.system(size: StudioTypography.captionSize, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("Value Representation \(vrFullName)")
    }

    private var badgeColor: Color {
        switch vr {
        case "PN", "LO", "SH", "CS", "LT", "ST", "UT", "UC":
            return .blue
        case "UI", "AE":
            return .purple
        case "DA", "TM", "DT":
            return .orange
        case "IS", "DS", "US", "SS", "UL", "SL", "FL", "FD":
            return .green
        case "OB", "OW", "OF", "OD", "UN":
            return .red
        case "SQ":
            return .indigo
        default:
            return .gray
        }
    }

    private var vrFullName: String {
        switch vr {
        case "PN": return "Person Name"
        case "LO": return "Long String"
        case "SH": return "Short String"
        case "CS": return "Code String"
        case "UI": return "Unique Identifier"
        case "DA": return "Date"
        case "TM": return "Time"
        case "DT": return "Date Time"
        case "IS": return "Integer String"
        case "DS": return "Decimal String"
        case "US": return "Unsigned Short"
        case "SS": return "Signed Short"
        case "UL": return "Unsigned Long"
        case "SL": return "Signed Long"
        case "FL": return "Floating Point Single"
        case "FD": return "Floating Point Double"
        case "OB": return "Other Byte"
        case "OW": return "Other Word"
        case "SQ": return "Sequence"
        case "AE": return "Application Entity"
        case "LT": return "Long Text"
        case "ST": return "Short Text"
        case "UT": return "Unlimited Text"
        case "UC": return "Unlimited Characters"
        case "OF": return "Other Float"
        case "OD": return "Other Double"
        case "UN": return "Unknown"
        default: return vr
        }
    }
}
#endif
