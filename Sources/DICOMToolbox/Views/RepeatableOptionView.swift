#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// A dynamic list for repeatable CLI options such as `--tag`
public struct RepeatableOptionView: View {
    let parameter: ParameterDefinition
    @Binding var parameterValues: [String: String]
    @State private var newValue = ""

    public init(
        parameter: ParameterDefinition,
        parameterValues: Binding<[String: String]>
    ) {
        self.parameter = parameter
        self._parameterValues = parameterValues
    }

    /// Current values parsed from the comma-separated storage string
    private var currentValues: [String] {
        guard let raw = parameterValues[parameter.id], !raw.isEmpty else { return [] }
        return raw.components(separatedBy: ",")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack(spacing: 2) {
                Text(parameter.label)
                    .font(.headline)
                if parameter.isRequired {
                    Text("*").foregroundStyle(.red)
                }
            }
            .accessibilityLabel(parameter.isRequired ? "\(parameter.label), required" : parameter.label)

            // List of added values
            if !currentValues.isEmpty {
                ForEach(Array(currentValues.enumerated()), id: \.offset) { index, value in
                    HStack {
                        Text(parameter.cliFlag)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            removeValue(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Remove this value")
                    }
                    .padding(.vertical, 2)
                }
            }

            // Add new value row
            HStack {
                TextField(parameter.help, text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addValue()
                    }
                Button("Add") {
                    addValue()
                }
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addValue() {
        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var values = currentValues
        values.append(trimmed)
        parameterValues[parameter.id] = values.joined(separator: ",")
        newValue = ""
    }

    private func removeValue(at index: Int) {
        var values = currentValues
        guard index < values.count else { return }
        values.remove(at: index)
        parameterValues[parameter.id] = values.isEmpty ? nil : values.joined(separator: ",")
    }
}
#endif
