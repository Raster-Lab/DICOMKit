#if canImport(SwiftUI) && os(macOS)
import SwiftUI
import AppKit

/// A save-panel integration view for selecting output file paths
public struct OutputPathView: View {
    let parameterID: String
    let label: String
    let isRequired: Bool
    @Binding var parameterValues: [String: String]

    public init(
        parameterID: String,
        label: String,
        isRequired: Bool = false,
        parameterValues: Binding<[String: String]>
    ) {
        self.parameterID = parameterID
        self.label = label
        self.isRequired = isRequired
        self._parameterValues = parameterValues
    }

    private var selectedPath: String? {
        guard let path = parameterValues[parameterID], !path.isEmpty else { return nil }
        return path
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack(spacing: 2) {
                Text(label)
                    .font(.headline)
                if isRequired {
                    Text("*").foregroundStyle(.red)
                }
            }
            .accessibilityLabel(isRequired ? "\(label), required" : label)

            HStack {
                Image(systemName: selectedPath != nil ? "folder.fill" : "folder")
                    .foregroundStyle(selectedPath != nil ? .blue : .secondary)

                if let path = selectedPath {
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.head)
                } else {
                    Text("No output path selected")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedPath != nil {
                    Button {
                        parameterValues[parameterID] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear path")
                }

                Button("Choose...") {
                    presentSavePanel()
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.3))
            )
        }
    }

    /// Opens an NSSavePanel for choosing an output file path
    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.title = label
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "output.dcm"
        if panel.runModal() == .OK, let url = panel.url {
            parameterValues[parameterID] = url.path(percentEncoded: false)
        }
    }
}
#endif
