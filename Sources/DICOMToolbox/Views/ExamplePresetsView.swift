#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Popover view showing example command presets for a tool
public struct ExamplePresetsView: View {
    let toolID: String
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    let onDismiss: () -> Void

    public init(
        toolID: String,
        parameterValues: Binding<[String: String]>,
        subcommand: Binding<String?>,
        onDismiss: @escaping () -> Void
    ) {
        self.toolID = toolID
        self._parameterValues = parameterValues
        self._subcommand = subcommand
        self.onDismiss = onDismiss
    }

    private var presets: [ExamplePreset] {
        ExamplePresets.presets(for: toolID)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Example Commands", systemImage: "lightbulb")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if presets.isEmpty {
                Text("No examples available for this tool")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(presets) { preset in
                    Button(action: {
                        applyPreset(preset)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Apply example: \(preset.name)")
                    .accessibilityHint(preset.description)
                }
                .frame(width: 350, height: min(CGFloat(presets.count) * 65, 260))
            }
        }
    }

    private func applyPreset(_ preset: ExamplePreset) {
        parameterValues = preset.parameterValues
        subcommand = preset.subcommand
        onDismiss()
    }
}
#endif
