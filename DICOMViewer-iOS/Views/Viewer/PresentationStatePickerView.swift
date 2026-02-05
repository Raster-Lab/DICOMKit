// PresentationStatePickerView.swift
// DICOMViewer iOS - Presentation State Picker View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import DICOMKit
import DICOMCore

/// View for selecting and managing presentation states
struct PresentationStatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Available presentation states
    let presentationStates: [PresentationStateInfo]
    
    /// Currently selected presentation state
    @Binding var selectedPresentationState: GrayscalePresentationState?
    
    /// Callback when a presentation state is selected
    var onSelect: ((GrayscalePresentationState?) -> Void)?
    
    var body: some View {
        NavigationStack {
            List {
                // Option to use no presentation state
                Section {
                    Button {
                        selectedPresentationState = nil
                        onSelect?(nil)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("None")
                                    .font(.headline)
                                Text("Use default display settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedPresentationState == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                
                // List available presentation states
                if !presentationStates.isEmpty {
                    Section("Available Presentation States") {
                        ForEach(presentationStates) { psInfo in
                            Button {
                                selectedPresentationState = psInfo.presentationState
                                onSelect?(psInfo.presentationState)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(psInfo.label)
                                            .font(.headline)
                                        
                                        if let description = psInfo.description {
                                            Text(description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            if let date = psInfo.creationDate {
                                                Label(date, systemImage: "calendar")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            PresentationStateFeatureBadges(presentationState: psInfo.presentationState)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPresentationState?.sopInstanceUID == psInfo.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "No Presentation States",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("No GSPS files are associated with this image.")
                        )
                    }
                }
            }
            .navigationTitle("Presentation States")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Badges showing features of a presentation state
struct PresentationStateFeatureBadges: View {
    let presentationState: GrayscalePresentationState
    
    var body: some View {
        HStack(spacing: 6) {
            // Show badge for VOI LUT
            if presentationState.voiLUT != nil {
                FeatureBadge(icon: "sun.max", label: "W/L")
            }
            
            // Show badge for annotations
            if !presentationState.graphicAnnotations.isEmpty {
                let count = presentationState.graphicAnnotations.reduce(0) { 
                    $0 + $1.graphicObjects.count + $1.textObjects.count 
                }
                FeatureBadge(icon: "pencil.tip.crop.circle", label: "\(count)")
            }
            
            // Show badge for shutters
            if !presentationState.shutters.isEmpty {
                FeatureBadge(icon: "square.dashed", label: "\(presentationState.shutters.count)")
            }
            
            // Show badge for spatial transform
            if let spatial = presentationState.spatialTransformation, spatial.hasTransformation {
                FeatureBadge(icon: "rotate.left", label: nil)
            }
        }
    }
}

/// Individual feature badge
struct FeatureBadge: View {
    let icon: String
    let label: String?
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            
            if let label = label {
                Text(label)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(4)
    }
}

/// View showing current presentation state info in the viewer
struct PresentationStateInfoView: View {
    let presentationState: GrayscalePresentationState?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: presentationState != nil ? "doc.text.fill" : "doc.text")
                    .font(.caption)
                
                Text(presentationState?.presentationLabel ?? "No PS")
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
        .foregroundStyle(presentationState != nil ? .primary : .secondary)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedPS: GrayscalePresentationState?
        
        var body: some View {
            PresentationStatePickerView(
                presentationStates: [],
                selectedPresentationState: $selectedPS
            )
        }
    }
    
    return PreviewWrapper()
}
