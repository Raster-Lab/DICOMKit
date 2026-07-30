// PrintOverlayColor+SwiftUI.swift
// DICOMStudio
//
// Turning what a colour picker returns into the three numbers the print path
// burns.
//
// ``PrintOverlayColor`` holds plain sRGB components because the burner writes
// into pixel buffers and the command-line tools have no UI framework loaded.
// This is the one place that bridges the two, so a failure to read a colour's
// components is handled once: the picker can return a colour from any colour
// space, including patterns and system colours that have no fixed components at
// all, and an annotation with a colour nobody can resolve should keep the colour
// it already had rather than turn black.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

#if canImport(AppKit)
import AppKit
#endif

extension PrintOverlayColor {

    /// The components of a SwiftUI colour, or `nil` if they cannot be resolved.
    init?(_ color: Color) {
        #if canImport(AppKit)
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(srgb.redComponent),
                  green: Double(srgb.greenComponent),
                  blue: Double(srgb.blueComponent))
        #else
        guard let components = color.cgColor?.components, components.count >= 3 else { return nil }
        self.init(red: Double(components[0]),
                  green: Double(components[1]),
                  blue: Double(components[2]))
        #endif
    }

    /// This colour as SwiftUI expresses it.
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }
}
#endif
