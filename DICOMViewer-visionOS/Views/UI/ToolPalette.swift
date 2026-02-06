// ToolPalette.swift
// DICOMViewer visionOS - Tool Palette
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Tool palette for measurement and annotation tools
struct ToolPalette: View {
    @Binding var selectedTool: MeasurementViewModel.Tool?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Tools")
                .font(.headline)
            
            ToolButton(
                title: "Length",
                icon: "ruler",
                isSelected: selectedTool == .length
            ) {
                selectedTool = .length
            }
            
            ToolButton(
                title: "Angle",
                icon: "angle",
                isSelected: selectedTool == .angle
            ) {
                selectedTool = .angle
            }
            
            ToolButton(
                title: "ROI",
                icon: "cube",
                isSelected: selectedTool == .volumeROI
            ) {
                selectedTool = .volumeROI
            }
            
            ToolButton(
                title: "Annotate",
                icon: "text.bubble",
                isSelected: selectedTool == .annotation
            ) {
                selectedTool = .annotation
            }
            
            Divider()
            
            Button("Clear All") {
                selectedTool = nil
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 200)
    }
}

struct ToolButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.borderless)
    }
}
