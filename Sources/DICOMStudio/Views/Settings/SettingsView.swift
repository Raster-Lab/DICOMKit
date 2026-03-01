// SettingsView.swift
// DICOMStudio
//
// DICOM Studio — Settings view with tabbed sections

#if canImport(SwiftUI)
import SwiftUI

/// Root settings view with section navigation.
@available(macOS 14.0, iOS 17.0, *)
public struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        #if os(macOS)
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsSection.general)

            PrivacySettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }
                .tag(SettingsSection.privacy)

            PerformanceSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Performance", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(SettingsSection.performance)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsSection.about)
        }
        .frame(width: 500, height: 400)
        #else
        NavigationStack {
            List {
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink {
                        sectionView(for: section)
                    } label: {
                        Label(section.rawValue, systemImage: section.systemImage)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        #endif
    }

    @ViewBuilder
    private func sectionView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        case .privacy:
            PrivacySettingsView(viewModel: viewModel)
        case .performance:
            PerformanceSettingsView(viewModel: viewModel)
        case .about:
            AboutView()
        }
    }
}
#endif
