import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop target zone for DICOM files
struct FileDropTarget: View {

    @Binding var value: String
    let allowedTypes: [String]
    @Binding var isDragTargeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isDragTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isDragTargeted
                            ? Color.accentColor.opacity(0.08)
                            : Color(nsColor: .controlBackgroundColor).opacity(0.3))
                )

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc")
                    .font(.caption)
                    .foregroundStyle(isDragTargeted ? .accent : .secondary)

                Text(value.isEmpty ? "Drop file here" : URL(fileURLWithPath: value).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(value.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: 300, minHeight: 32, maxHeight: 32)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url else { return }
            let ext = url.pathExtension.lowercased()
            if allowedTypes.isEmpty || allowedTypes.contains(ext) {
                DispatchQueue.main.async {
                    self.value = url.path
                }
            }
        }

        return true
    }
}
