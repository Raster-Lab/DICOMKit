// JP3DMPRRenderHelpers.swift
// DICOMStudio
//
// Platform-independent rendering helpers for JP3DMPRView.
// Contains CGImage construction from 8-bit buffers, reference-line colours,
// and axis determination — all testable without SwiftUI.

import Foundation

// MARK: - Reference Line Axis

/// Display axis for a reference line.
public enum MPRReferenceLineAxis: Sendable, Equatable {
    /// Horizontal line across the display plane.
    case horizontal
    /// Vertical line across the display plane.
    case vertical
}

// MARK: - JP3DMPRRenderHelpers

/// Platform-independent rendering helpers for the JP3D MPR view.
public enum JP3DMPRRenderHelpers: Sendable {

    // MARK: - Reference Line Colour

    /// Returns a SwiftUI-compatible `Color`-like RGBA tuple for a reference plane's line.
    ///
    /// Convention:
    /// - Axial lines are rendered in **cyan**.
    /// - Sagittal lines are rendered in **yellow**.
    /// - Coronal lines are rendered in **green**.
    ///
    /// - Parameter plane: The plane whose line colour is needed.
    /// - Returns: `(red, green, blue)` components in `[0, 1]`.
    public static func referenceLineRGB(for plane: MPRPlane) -> (Double, Double, Double) {
        switch plane {
        case .axial:    return (0.0, 1.0, 1.0)  // cyan
        case .sagittal: return (1.0, 1.0, 0.0)  // yellow
        case .coronal:  return (0.0, 1.0, 0.0)  // green
        }
    }

    // MARK: - Reference Line Axis

    /// Determines whether a reference line for `referencePlane` should be drawn
    /// as a horizontal or vertical line in the `displayPlane`.
    ///
    /// Reference line axis table:
    ///
    /// | Displayed in ↓ / Reference → | Axial | Sagittal | Coronal |
    /// |-------------------------------|-------|----------|---------|
    /// | Axial                         | —     | vertical | horiz.  |
    /// | Sagittal                      | horiz.| —        | horiz.  |
    /// | Coronal                       | horiz.| vertical | —       |
    ///
    /// - Parameters:
    ///   - referencePlane: The plane whose slice position is being indicated.
    ///   - displayPlane: The plane on which the line is drawn.
    /// - Returns: `.horizontal` or `.vertical`.
    public static func referenceLineAxis(
        referencePlane: MPRPlane,
        displayPlane: MPRPlane
    ) -> MPRReferenceLineAxis {
        switch (displayPlane, referencePlane) {
        case (.axial, .sagittal):   return .vertical
        case (.axial, .coronal):    return .horizontal
        case (.sagittal, .axial):   return .horizontal
        case (.sagittal, .coronal): return .horizontal
        case (.coronal, .axial):    return .horizontal
        case (.coronal, .sagittal): return .vertical
        default:                    return .horizontal
        }
    }

    // MARK: - CGImage from 8-bit Buffer

    /// Creates a `CGImage` from an 8-bit grayscale display buffer.
    ///
    /// - Parameters:
    ///   - buffer: 8-bit grayscale pixel data (one byte per pixel, row-major).
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: A `CGImage`, or `nil` if the buffer size or parameters are invalid.
    public static func cgImage(
        from buffer: Data,
        width: Int,
        height: Int
    ) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let expectedSize = width * height
        guard buffer.count >= expectedSize else { return nil }

        return buffer.withUnsafeBytes { rawPtr -> CGImage? in
            guard let baseAddr = rawPtr.baseAddress else { return nil }

            let colorSpace = CGColorSpaceCreateDeviceGray()
            guard let provider = CGDataProvider(
                dataInfo: nil,
                data: baseAddr,
                size: expectedSize,
                releaseData: { _, _, _ in }
            ) else { return nil }

            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }
}

// MARK: - SwiftUI Colour Extension (SwiftUI-only)

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 12.0, iOS 15.0, visionOS 1.0, *)
extension JP3DMPRRenderHelpers {
    /// Returns a SwiftUI `Color` for a reference plane's line.
    ///
    /// - Parameter plane: The plane whose line colour is needed.
    /// - Returns: A `Color` matching the standard reference-line convention.
    public static func referenceLineColour(for plane: MPRPlane) -> Color {
        let (r, g, b) = referenceLineRGB(for: plane)
        return Color(red: r, green: g, blue: b)
    }
}
#endif
