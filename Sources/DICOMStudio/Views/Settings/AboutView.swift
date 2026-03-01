// AboutView.swift
// DICOMStudio
//
// DICOM Studio — About screen

#if canImport(SwiftUI)
import SwiftUI

/// About screen showing DICOMKit version, licenses, and acknowledgments.
@available(macOS 14.0, iOS 17.0, *)
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cross.case")
                .font(.system(size: 64))
                .foregroundStyle(StudioColors.primary)
                .accessibilityHidden(true)

            Text("DICOM Studio")
                .font(.system(size: StudioTypography.displaySize, weight: .bold))

            Text("A comprehensive DICOM medical imaging application")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("DICOMKit")
                        .font(.headline)
                    Text("v1.0.0")
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Platform")
                        .font(.headline)
                    Text("macOS 14+")
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Swift")
                        .font(.headline)
                    Text("6.2")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(width: 200)

            Text("Built with DICOMKit by Raster Lab")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("© 2026 Raster Lab. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}
#endif
