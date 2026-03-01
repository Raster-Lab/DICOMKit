// PrivacySettingsView.swift
// DICOMStudio
//
// DICOM Studio — Privacy settings tab

#if canImport(SwiftUI)
import SwiftUI

/// Privacy settings for anonymization and audit logging.
@available(macOS 14.0, iOS 17.0, *)
struct PrivacySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Anonymization") {
                Toggle("Enable Anonymization by Default", isOn: $viewModel.anonymizationEnabled)
                    .accessibilityLabel("Enable default anonymization for exported files")

                Toggle("Remove Private Tags", isOn: $viewModel.removePrivateTags)
                    .accessibilityLabel("Remove private DICOM tags during anonymization")
                    .disabled(!viewModel.anonymizationEnabled)
            }

            Section("Audit Logging") {
                Toggle("Enable Audit Logging", isOn: $viewModel.auditLoggingEnabled)
                    .accessibilityLabel("Enable audit logging for all operations")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy")
    }
}
#endif
