// FloatingMenu.swift
// DICOMViewer visionOS - Floating Context Menu
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Floating context menu for visionOS
struct FloatingMenu: View {
    let items: [MenuItem]
    let onSelect: (MenuItem) -> Void
    
    struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(items) { item in
                Button(action: { onSelect(item) }) {
                    Label(item.title, systemImage: item.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .glassBackgroundEffect()
    }
}
