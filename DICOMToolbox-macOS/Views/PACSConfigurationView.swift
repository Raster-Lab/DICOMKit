import SwiftUI

/// Always-visible PACS/network configuration bar displayed above the tab interface
struct PACSConfigurationView: View {

    @Binding var config: PACSConfiguration
    @Binding var isExpanded: Bool
    let isNetworkTool: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header bar
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(config.isValid ? .green : .secondary)

                Text("Network Configuration")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                if config.isValid {
                    Text("\(config.localAETitle) → \(config.remoteAETitle)@\(config.hostname):\(config.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .help(isExpanded ? "Collapse network settings" : "Expand network settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isNetworkTool && !config.isValid
                ? Color.orange.opacity(0.08)
                : Color.clear)

            // Expanded configuration form
            if isExpanded {
                Divider()
                expandedForm
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
    }

    private var expandedForm: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            // DICOM Network Settings
            GridRow {
                Text("DICOM Network")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .gridCellColumns(4)
            }

            GridRow {
                Text("Local AE Title:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("DICOMTOOLBOX", text: $config.localAETitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .help("Application Entity Title for this application")

                Text("Remote AE Title:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("ANY-SCP", text: $config.remoteAETitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .help("Application Entity Title of the remote PACS server")
            }

            GridRow {
                Text("Hostname:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("pacs.example.com", text: $config.hostname)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .help("PACS server hostname or IP address")

                Text("Port:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("11112", value: $config.port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .help("DICOM port (default: 11112)")
            }

            GridRow {
                Text("Timeout (s):")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("30", value: $config.timeout, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .help("Connection timeout in seconds")

                Text("Move Dest:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("STORAGE_SCP", text: $config.moveDestination)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .help("Move destination AE Title for C-MOVE operations")
            }

            Divider()
                .gridCellColumns(4)

            // DICOMweb Settings
            GridRow {
                Text("DICOMweb")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .gridCellColumns(4)
            }

            GridRow {
                Text("Base URL:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)

                TextField("https://server/dicomweb", text: $config.dicomwebBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .gridCellColumns(3)
                    .help("DICOMweb server base URL for QIDO-RS, WADO-RS, STOW-RS")
            }
        }
    }
}
