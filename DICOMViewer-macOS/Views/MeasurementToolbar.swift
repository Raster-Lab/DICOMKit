//
//  MeasurementToolbar.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Toolbar for measurement tool selection and options
struct MeasurementToolbar: View {
    @Binding var selectedTool: MeasurementType?
    @Binding var showLabels: Bool
    @Binding var showValues: Bool
    let onClearAll: () -> Void
    let onExport: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tool selection buttons
            ForEach(MeasurementType.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    isSelected: selectedTool == tool
                ) {
                    if selectedTool == tool {
                        selectedTool = nil
                    } else {
                        selectedTool = tool
                    }
                }
            }
            
            Divider()
            
            // Display options
            Toggle(isOn: $showLabels) {
                Label("Labels", systemImage: "textformat")
            }
            .toggleStyle(.button)
            .help("Show measurement labels")
            
            Toggle(isOn: $showValues) {
                Label("Values", systemImage: "number")
            }
            .toggleStyle(.button)
            .help("Show measurement values")
            
            Divider()
            
            // Actions
            Button {
                onExport()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export measurements to JSON")
            
            Button {
                onImport()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .help("Import measurements from JSON")
            
            Button(role: .destructive) {
                onClearAll()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .help("Clear all measurements")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let tool: MeasurementType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: tool.symbolName)
                    .font(.system(size: 18))
                
                Text(tool.displayName)
                    .font(.caption2)
            }
            .frame(width: 60, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolButtonStyle(isSelected: isSelected))
        .help("\(tool.displayName) measurement tool")
    }
}

// MARK: - Button Style

private struct ToolButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MeasurementToolbar(
            selectedTool: .constant(.length),
            showLabels: .constant(true),
            showValues: .constant(true),
            onClearAll: {},
            onExport: {},
            onImport: {}
        )
        
        Divider()
        
        MeasurementToolbar(
            selectedTool: .constant(nil),
            showLabels: .constant(false),
            showValues: .constant(true),
            onClearAll: {},
            onExport: {},
            onImport: {}
        )
    }
    .frame(width: 800)
}
