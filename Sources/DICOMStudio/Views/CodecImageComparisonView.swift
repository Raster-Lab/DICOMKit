// CodecImageComparisonView.swift
// DICOMStudio
//
// DICOM Studio — IDE-style 3-panel image comparison: Raw | Encoded | Decoded

#if canImport(SwiftUI) && canImport(CoreGraphics)
import SwiftUI
import CoreGraphics

// MARK: - CodecImageComparisonView

/// Full-screen side-by-side comparison of the raw, encoded-preview, and decoded images
/// produced by the J2K round-trip test.  Shared zoom and pan keep all three panels
/// in sync so artefacts can be compared at any magnification.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CodecImageComparisonView: View {

    @Bindable var viewModel: J2KTestingViewModel
    @Environment(\.dismiss) private var dismiss

    /// The transfer-syntax UID whose images are currently being shown.
    @State private var selectedUID: String = ""

    // Shared zoom / pan state (affects all panels simultaneously)
    @State private var zoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var magnifyBy: CGFloat = 1.0

    public init(viewModel: J2KTestingViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Derived

    private var encodedImage: CGImage? { viewModel.encodedImages[selectedUID] }
    private var decodedImage: CGImage? { viewModel.decodedImages[selectedUID] }

    private var selectedEntry: J2KRoundTripEntry? {
        viewModel.roundTripResults.first(where: { $0.uid == selectedUID })
    }

    private var passedStatus: Bool? {
        if case .complete(let r) = selectedEntry?.state { return r.passed }
        return nil
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.10).ignoresSafeArea()
                VStack(spacing: 0) {
                    codecPicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.13))

                    panelsRow
                }
            }
            .navigationTitle("Codec Image Comparison")
            #if os(macOS)
            .frame(minWidth: 960, minHeight: 600)
            .navigationSubtitle(selectedEntry?.shortName ?? "")
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button { zoom = max(0.1, zoom / 1.5) } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom out")
                    Button { zoom = 1.0; panOffset = .zero } label: {
                        Image(systemName: "1.magnifyingglass")
                    }
                    .help("Actual size")
                    Button { zoom = min(16.0, zoom * 1.5) } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom in")
                }
            }
        }
        .onAppear { selectInitialUID() }
        .onChange(of: viewModel.roundTripResults.count) { _, _ in selectInitialUID() }
    }

    // MARK: - Codec Picker Bar

    private var codecPicker: some View {
        HStack(spacing: 16) {
            Text("Codec:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.7))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.roundTripResults) { entry in
                        codecTab(entry: entry)
                    }
                }
            }

            Spacer()

            if let passed = passedStatus {
                HStack(spacing: 5) {
                    Image(systemName: passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(passed ? .green : .red)
                    Text(passed ? "PASS" : "FAIL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(passed ? .green : .red)
                }
            }
        }
    }

    @ViewBuilder
    private func codecTab(entry: J2KRoundTripEntry) -> some View {
        let isSelected = entry.uid == selectedUID
        let isRunning: Bool = { if case .running = entry.state { return true }; return false }()

        Button {
            selectedUID = entry.uid
        } label: {
            HStack(spacing: 5) {
                if isRunning {
                    ProgressView().controlSize(.mini).tint(.white)
                } else if case .complete(let r) = entry.state {
                    Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(r.passed ? .green : .red)
                }
                Text(entry.shortName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color(white: 0.20))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(isSelected ? .primary : Color(white: 0.65))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Three-Panel Row

    private var panelsRow: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                imagePanel(
                    title: "RAW / ORIGINAL",
                    subtitle: nil,
                    image: viewModel.rawImage,
                    geo: geo
                )

                Color(white: 0.08).frame(width: 1)

                imagePanel(
                    title: "ENCODED PREVIEW",
                    subtitle: encodedSubtitle,
                    image: encodedImage,
                    geo: geo
                )

                Color(white: 0.08).frame(width: 1)

                imagePanel(
                    title: "DECODED",
                    subtitle: decodedSubtitle,
                    image: decodedImage,
                    geo: geo
                )
            }
        }
    }

    private var encodedSubtitle: String? {
        guard case .complete(let r) = selectedEntry?.state else { return nil }
        return "\(formatBytes(r.encodedBytes))  ·  \(String(format: "%.2f×", r.compressionRatio)) ratio  ·  \(formatMs(r.encodeMs))"
    }

    private var decodedSubtitle: String? {
        guard case .complete(let r) = selectedEntry?.state else { return nil }
        return "\(formatBytes(r.originalBytes))  ·  \(formatMs(r.decodeMs))  ·  \(r.notes)"
    }

    // MARK: - Single Panel

    @ViewBuilder
    private func imagePanel(
        title: String,
        subtitle: String?,
        image: CGImage?,
        geo: GeometryProxy
    ) -> some View {
        VStack(spacing: 0) {
            // Panel header
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.55))
                    .tracking(1.0)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.40))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.16))

            // Image canvas
            ZStack {
                Color(white: 0.07)

                if let img = image {
                    Image(decorative: img, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoom * magnifyBy)
                        .offset(
                            x: panOffset.width + dragOffset.width,
                            y: panOffset.height + dragOffset.height
                        )
                        .accessibilityLabel(title)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(white: 0.25))
                        Text("No image")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.30))
                    }
                }
            }
            .gesture(panGesture)
            .gesture(magnificationGesture)
            #if os(macOS)
            .background(
                ScrollWheelZoomHandler { delta in
                    let factor = 1.0 + delta * 0.04
                    zoom = min(16.0, max(0.1, zoom * factor))
                }
            )
            #endif

            // Status bar
            panelStatusBar(image)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private func panelStatusBar(_ image: CGImage?) -> some View {
        HStack {
            if let img = image {
                Text("\(img.width) × \(img.height)  ·  \(img.bitsPerComponent)bpc")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
            }
            Spacer()
            Text(String(format: "%.0f%%", zoom * 100))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.30))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(white: 0.13))
    }

    // MARK: - Shared Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                magnifyBy = value.magnification
            }
            .onEnded { value in
                zoom = min(16.0, max(0.1, zoom * value.magnification))
                magnifyBy = 1.0
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                panOffset.width  += value.translation.width
                panOffset.height += value.translation.height
                dragOffset = .zero
            }
    }

    // MARK: - Helpers

    private func selectInitialUID() {
        guard !viewModel.roundTripResults.isEmpty else { return }
        if !viewModel.roundTripResults.contains(where: { $0.uid == selectedUID }) {
            selectedUID = viewModel.roundTripResults[0].uid
        }
    }

    private func formatMs(_ ms: Double) -> String {
        CodecInspectorHelpers.formatDecodeTime(ms)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}

// MARK: - Scroll-Wheel Zoom (macOS only)

#if os(macOS)
@available(macOS 14.0, *)
private struct ScrollWheelZoomHandler: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            onScroll(event.deltaY)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var monitor: Any?
        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}
#endif

// MARK: - Preview

#if DEBUG
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("Empty") {
    CodecImageComparisonView(viewModel: J2KTestingViewModel())
}
#endif

#endif // canImport(SwiftUI) && canImport(CoreGraphics)
