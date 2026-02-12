#if canImport(SwiftUI) && os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// A drag-and-drop file input zone for DICOM file parameters
public struct FileDropZoneView: View {
    let parameterID: String
    let label: String
    let isRequired: Bool
    let allowsMultipleFiles: Bool
    @Binding var parameterValues: [String: String]
    @State private var isDragOver = false
    @State private var isFileImporterPresented = false

    public init(
        parameterID: String,
        label: String,
        isRequired: Bool = false,
        allowsMultipleFiles: Bool = false,
        parameterValues: Binding<[String: String]>
    ) {
        self.parameterID = parameterID
        self.label = label
        self.isRequired = isRequired
        self.allowsMultipleFiles = allowsMultipleFiles
        self._parameterValues = parameterValues
    }

    private var selectedPath: String? {
        parameterValues[parameterID]
    }

    private var hasSelection: Bool {
        guard let path = selectedPath, !path.isEmpty else { return false }
        return true
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

            // Drop zone
            if hasSelection {
                selectedFileView
            } else {
                emptyDropZone
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: allowsMultipleFiles
        ) { result in
            switch result {
            case .success(let urls):
                storeFilePaths(urls)
            case .failure:
                break
            }
        }
    }

    /// Placeholder zone shown when no file is selected
    private var emptyDropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Drop DICOM file here")
                .foregroundStyle(.secondary)
            Button("Browse...") {
                isFileImporterPresented = true
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isDragOver ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDragOver ? Color.accentColor.opacity(0.07) : Color.clear)
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    /// View shown when a file is selected
    private var selectedFileView: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayFilename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(displayFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                parameterValues[parameterID] = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove file")
            Button("Browse...") {
                isFileImporterPresented = true
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3))
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    private var displayFilename: String {
        guard let path = selectedPath else { return "" }
        return (path as NSString).lastPathComponent
    }

    private var displayFileSize: String {
        guard let path = selectedPath else { return "" }
        let url = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)),
              let size = attrs[.size] as? UInt64 else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// Stores file paths from the given URLs into parameter values
    private func storeFilePaths(_ urls: [URL]) {
        if allowsMultipleFiles {
            let newPaths = urls.map { $0.path(percentEncoded: false) }
            if let existing = parameterValues[parameterID], !existing.isEmpty {
                parameterValues[parameterID] = existing + "," + newPaths.joined(separator: ",")
            } else {
                parameterValues[parameterID] = newPaths.joined(separator: ",")
            }
        } else if let url = urls.first {
            parameterValues[parameterID] = url.path(percentEncoded: false)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = allowsMultipleFiles ? providers : Array(providers.prefix(1))
        guard !fileProviders.isEmpty else { return false }
        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    storeFilePaths([url])
                }
            }
        }
        return true
    }
}
#endif
