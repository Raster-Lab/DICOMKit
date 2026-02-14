#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Searchable DICOM glossary sidebar panel
public struct GlossaryView: View {
    @State private var searchText = ""
    @State private var selectedTermID: String?

    public init() {}

    private var filteredTerms: [GlossaryTerm] {
        DICOMGlossary.search(searchText)
    }

    public var body: some View {
        NavigationSplitView {
            List(filteredTerms, selection: $selectedTermID) { term in
                VStack(alignment: .leading, spacing: 2) {
                    Text(term.term)
                        .font(.headline)
                    Text(term.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .tag(term.id)
            }
            .searchable(text: $searchText, prompt: "Search glossary...")
            .navigationTitle("DICOM Glossary")
        } detail: {
            if let termID = selectedTermID,
               let term = filteredTerms.first(where: { $0.id == termID }) {
                glossaryDetail(for: term)
            } else {
                ContentUnavailableView(
                    "Select a Term",
                    systemImage: "character.book.closed",
                    description: Text("Choose a glossary term from the sidebar to see its full definition.")
                )
            }
        }
    }

    @ViewBuilder
    private func glossaryDetail(for term: GlossaryTerm) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Term header
                Text(term.term)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Definition
                GroupBox("Definition") {
                    Text(term.definition)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }

                // Standard reference
                if let reference = term.standardReference {
                    GroupBox("DICOM Standard Reference") {
                        Label(reference, systemImage: "book.closed")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    }
                }

                // Related terms
                if !term.relatedTerms.isEmpty {
                    GroupBox("Related Terms") {
                        FlowLayout(spacing: 8) {
                            ForEach(term.relatedTerms, id: \.self) { related in
                                Button(action: {
                                    selectedTermID = DICOMGlossary.term(named: related)?.id
                                }) {
                                    Text(related)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    }
                }
            }
            .padding()
        }
    }
}

/// Simple horizontal flow layout for related term badges
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(subviews: subviews, in: proposal.width ?? .infinity)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + maxHeight), positions)
    }
}
#endif
