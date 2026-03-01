// PerformanceSettingsView.swift
// DICOMStudio
//
// DICOM Studio — Performance settings tab

#if canImport(SwiftUI)
import SwiftUI

/// Performance settings for cache, memory, and threading.
@available(macOS 14.0, iOS 17.0, *)
struct PerformanceSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Cache") {
                Stepper("Max Cache Size: \(viewModel.maxCacheSizeMB) MB",
                        value: $viewModel.maxCacheSizeMB, in: 128...4096, step: 128)
                    .accessibilityLabel("Maximum cache size: \(viewModel.maxCacheSizeMB) megabytes")
            }

            Section("Memory") {
                Stepper("Max Memory Usage: \(viewModel.maxMemoryUsageMB) MB",
                        value: $viewModel.maxMemoryUsageMB, in: 512...8192, step: 256)
                    .accessibilityLabel("Maximum memory usage: \(viewModel.maxMemoryUsageMB) megabytes")
            }

            Section("Thumbnails") {
                HStack {
                    Text("Quality")
                    Slider(value: $viewModel.thumbnailQuality, in: 0.1...1.0, step: 0.1)
                        .accessibilityLabel("Thumbnail quality")
                        .accessibilityValue("\(Int(viewModel.thumbnailQuality * 100)) percent")
                    Text("\(Int(viewModel.thumbnailQuality * 100))%")
                        .frame(width: 40)
                        .monospacedDigit()
                }
            }

            Section("Processing") {
                Toggle("Enable Image Prefetch", isOn: $viewModel.prefetchEnabled)
                    .accessibilityLabel("Enable image prefetching for faster browsing")

                Stepper("Thread Pool Size: \(viewModel.threadPoolSize)",
                        value: $viewModel.threadPoolSize, in: 1...16)
                    .accessibilityLabel("Thread pool size: \(viewModel.threadPoolSize) threads")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Performance")
    }
}
#endif
