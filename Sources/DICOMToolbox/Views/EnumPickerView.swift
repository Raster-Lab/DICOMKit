#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// A picker for enum-type parameters, adapting style based on option count
public struct EnumPickerView: View {
    let parameter: ParameterDefinition
    @Binding var parameterValues: [String: String]

    public init(
        parameter: ParameterDefinition,
        parameterValues: Binding<[String: String]>
    ) {
        self.parameter = parameter
        self._parameterValues = parameterValues
    }

    private var selection: Binding<String> {
        Binding(
            get: { parameterValues[parameter.id] ?? parameter.defaultValue ?? "" },
            set: { parameterValues[parameter.id] = $0 }
        )
    }

    private var values: [EnumValue] {
        parameter.enumValues ?? []
    }

    private var useSegmentedStyle: Bool {
        values.count <= 4
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack(spacing: 2) {
                Text(parameter.label)
                if parameter.isRequired {
                    Text("*").foregroundStyle(.red)
                }
            }
            .accessibilityLabel(parameter.isRequired ? "\(parameter.label), required" : parameter.label)

            if useSegmentedStyle {
                segmentedPicker
            } else {
                menuPicker
            }

            // Show description for the currently selected value
            if let selected = values.first(where: { $0.value == selection.wrappedValue }),
               !selected.description.isEmpty {
                Text(selected.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Segmented picker used when there are 4 or fewer options
    private var segmentedPicker: some View {
        Picker(parameter.label, selection: selection) {
            ForEach(values) { enumValue in
                Text(enumValue.label).tag(enumValue.value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// Menu picker used when there are more than 4 options
    private var menuPicker: some View {
        Picker(parameter.label, selection: selection) {
            ForEach(values) { enumValue in
                VStack(alignment: .leading) {
                    Text(enumValue.label)
                    if !enumValue.description.isEmpty {
                        Text(enumValue.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(enumValue.value)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}
#endif
