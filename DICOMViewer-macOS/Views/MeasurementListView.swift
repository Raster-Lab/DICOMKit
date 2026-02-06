//
//  MeasurementListView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Sidebar view for managing measurements
struct MeasurementListView: View {
    let measurements: [Measurement]
    let selectedIDs: Set<UUID>
    let onToggleVisibility: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onSelect: (UUID, Bool) -> Void
    let onUpdateLabel: (UUID, String?) -> Void
    
    @State private var editingID: UUID?
    @State private var editingLabel: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Measurements")
                    .font(.headline)
                
                Spacer()
                
                Text("\(measurements.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Measurement list
            if measurements.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(measurements) { measurement in
                            MeasurementRow(
                                measurement: measurement,
                                isSelected: selectedIDs.contains(measurement.id),
                                isEditing: editingID == measurement.id,
                                editingLabel: $editingLabel,
                                onToggleVisibility: {
                                    onToggleVisibility(measurement.id)
                                },
                                onDelete: {
                                    onDelete(measurement.id)
                                },
                                onSelect: { addToSelection in
                                    onSelect(measurement.id, addToSelection)
                                },
                                onStartEdit: {
                                    editingID = measurement.id
                                    editingLabel = measurement.label ?? ""
                                },
                                onEndEdit: {
                                    if let id = editingID {
                                        let trimmed = editingLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                        onUpdateLabel(id, trimmed.isEmpty ? nil : trimmed)
                                        editingID = nil
                                        editingLabel = ""
                                    }
                                }
                            )
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Measurements")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Select a tool to add measurements")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Measurement Row

private struct MeasurementRow: View {
    let measurement: Measurement
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingLabel: String
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void
    let onSelect: (Bool) -> Void
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Visibility toggle
            Button {
                onToggleVisibility()
            } label: {
                Image(systemName: measurement.isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(measurement.isVisible ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help(measurement.isVisible ? "Hide" : "Show")
            
            // Icon
            Image(systemName: measurement.type.symbolName)
                .foregroundColor(colorFromHex(measurement.colorHex))
                .frame(width: 20)
            
            // Label and value
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Label", text: $editingLabel, onCommit: onEndEdit)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                } else {
                    if let label = measurement.label, !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Text(measurement.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(measurement.formattedValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions (shown on hover or selection)
            if isHovering || isSelected {
                HStack(spacing: 4) {
                    if !isEditing {
                        Button {
                            onStartEdit()
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .help("Edit label")
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(false)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Edit Label") {
                onStartEdit()
            }
            
            Button("Toggle Visibility") {
                onToggleVisibility()
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview

#Preview {
    let measurements = [
        Measurement(
            type: .length,
            points: [
                ImagePoint(x: 100, y: 100),
                ImagePoint(x: 200, y: 150)
            ],
            pixelSpacing: (row: 0.5, column: 0.5),
            label: "Lesion diameter"
        ),
        Measurement(
            type: .angle,
            points: [
                ImagePoint(x: 150, y: 200),
                ImagePoint(x: 200, y: 250),
                ImagePoint(x: 250, y: 200)
            ],
            label: "Cobb angle"
        ),
        Measurement(
            type: .ellipse,
            points: [
                ImagePoint(x: 300, y: 100),
                ImagePoint(x: 400, y: 200)
            ],
            label: nil,
            isVisible: false
        ),
        Measurement(
            type: .rectangle,
            points: [
                ImagePoint(x: 50, y: 300),
                ImagePoint(x: 150, y: 400)
            ],
            label: "ROI 1"
        )
    ]
    
    MeasurementListView(
        measurements: measurements,
        selectedIDs: [measurements[0].id],
        onToggleVisibility: { _ in },
        onDelete: { _ in },
        onSelect: { _, _ in },
        onUpdateLabel: { _, _ in }
    )
}
