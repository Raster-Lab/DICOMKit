#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// A reusable section wrapper with expandable help text for tool parameters
public struct ParameterSectionView<Content: View>: View {
    let title: String
    let help: String?
    let isRequired: Bool
    @ViewBuilder let content: () -> Content
    @State private var isHelpExpanded = false

    public init(
        title: String,
        help: String? = nil,
        isRequired: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.help = help
        self.isRequired = isRequired
        self.content = content
    }

    public var body: some View {
        Section {
            content()

            if let help, !help.isEmpty {
                DisclosureGroup("Help", isExpanded: $isHelpExpanded) {
                    Text(help)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } header: {
            HStack(spacing: 2) {
                Text(title)
                if isRequired {
                    Text("*").foregroundStyle(.red)
                }
            }
        }
    }
}
#endif
