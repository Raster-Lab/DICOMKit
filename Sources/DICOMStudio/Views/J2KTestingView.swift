// J2KTestingView.swift
// DICOMStudio
//
// DICOM Studio — J2KSwift implementation testing panel

#if canImport(SwiftUI)
import SwiftUI
import DICOMCore

// MARK: - J2KTestingView

/// A sheet panel for testing the J2KSwift codec implementation.
///
/// Sections:
/// 1. **Platform** — available backends and J2K/HTJ2K transfer syntax support matrix.
/// 2. **Current File** — codec inspector entry for the loaded image.
/// 3. **Decode Benchmark** — multi-iteration timing test on the loaded file.
/// 4. **Round-Trip Test** — J2K Lossless encode → decode correctness check.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct J2KTestingView: View {

    @Bindable var viewModel: ImageViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showComparison = false

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    platformSection
                    codecInspectorSection
                    benchmarkSection
                    roundTripSection
                }
                .padding()
            }
            .navigationTitle("J2KSwift Testing")
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 640)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    #if canImport(CoreGraphics)
                    Button {
                        showComparison = true
                    } label: {
                        Label("Compare Images", systemImage: "rectangle.split.3x1")
                    }
                    .disabled(viewModel.j2kTesting.rawImage == nil && viewModel.j2kTesting.encodedImages.isEmpty)
                    #endif
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                }
            }
            #if canImport(CoreGraphics)
            .sheet(isPresented: $showComparison) {
                CodecImageComparisonView(viewModel: viewModel.j2kTesting)
            }
            #endif
        }
    }

    // MARK: - Platform Section

    private var platformSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Backend availability
                ForEach(CodecBackend.allCases, id: \.self) { backend in
                    let available = CodecBackendProbe.isAvailable(backend)
                    let isBest = backend == viewModel.j2kTesting.bestBackend
                    HStack(spacing: 8) {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(available ? .green : .secondary)
                        Text(backend.displayName)
                            .font(.system(size: StudioTypography.captionSize + 1))
                        if isBest && available {
                            Text("ACTIVE")
                                .font(.system(size: StudioTypography.captionSize - 1, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.green)
                        }
                        Spacer()
                    }
                }

                Divider()

                // Transfer syntax support matrix
                Text("Transfer Syntax Support")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.j2kTesting.supportMatrix) { entry in
                    HStack(spacing: 4) {
                        Text(entry.shortName)
                            .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                            .frame(minWidth: 170, alignment: .leading)
                        supportBadge("DEC", active: entry.canDecode)
                        supportBadge("ENC", active: entry.canEncode)
                        Spacer()
                    }
                }
            }
        } label: {
            Label("Platform & Codec Support", systemImage: "cpu")
                .font(.headline)
        }
    }

    // MARK: - Codec Inspector Section

    private var codecInspectorSection: some View {
        GroupBox {
            if let entry = viewModel.codecInspector.entry {
                VStack(alignment: .leading, spacing: 6) {
                    inspectorRow("Codec",       value: entry.codecName)
                    inspectorRow("Backend",     value: CodecInspectorHelpers.backendDisplayName(entry.backend),
                                 icon: CodecInspectorHelpers.backendSFSymbol(entry.backend))
                    inspectorRow("Decode Time", value: CodecInspectorHelpers.formatDecodeTime(entry.decodeTimeMs))
                    inspectorRow("Frames",      value: "\(entry.frameCount)")
                    Divider()
                    Text(entry.transferSyntaxUID)
                        .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Label(viewModel.codecInspector.statusSummary, systemImage: "photo")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        } label: {
            Label("Current File — Codec Inspector", systemImage: "slider.horizontal.3")
                .font(.headline)
        }
    }

    // MARK: - Benchmark Section

    private var benchmarkSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("Iterations:")
                        .font(.callout)
                    Stepper("\(viewModel.j2kTesting.benchmarkIterations)",
                            value: Bindable(viewModel.j2kTesting).benchmarkIterations,
                            in: 1...100)
                    .frame(width: 120)

                    Spacer()

                    Button {
                        if let file = viewModel.dicomFile {
                            viewModel.j2kTesting.runBenchmark(file: file)
                        }
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    if !isIdle(viewModel.j2kTesting.benchmarkState) {
                        Button("Reset") { viewModel.j2kTesting.reset() }
                            .disabled(viewModel.j2kTesting.isRunning)
                    }
                }

                benchmarkResult
            }
        } label: {
            Label("Decode Benchmark", systemImage: "stopwatch")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var benchmarkResult: some View {
        switch viewModel.j2kTesting.benchmarkState {
        case .idle:
            if viewModel.dicomFile == nil {
                Text("Load a DICOM file to run the benchmark.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Benchmarking…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .complete(let r):
            VStack(alignment: .leading, spacing: 6) {
                resultRow("Codec",      value: r.codecName)
                resultRow("Backend",    value: r.backend.displayName)
                resultRow("Iterations", value: "\(r.iterations)")
                Divider()
                resultRow("Avg",  value: formatMs(r.avgMs), accent: true)
                resultRow("Min",  value: formatMs(r.minMs))
                resultRow("Max",  value: formatMs(r.maxMs))
                resultRow("Total", value: formatMs(r.totalMs))
            }
            .padding(.vertical, 4)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Round-Trip Section

    private var roundTripSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text("Encodes frame 0 with the selected codec then decodes it back and verifies the output size. \"Run All\" tests every encodable codec in parallel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Raw image — shown once at the top, shared by all codec runs
                #if canImport(CoreGraphics)
                if let raw = viewModel.j2kTesting.rawImage {
                    imageStrip(label: "Raw / Original", image: raw)
                }
                #endif

                // Codec picker + action buttons
                HStack(spacing: 10) {
                    Text("Target:")
                        .font(.callout)

                    Picker("", selection: Bindable(viewModel.j2kTesting).selectedRoundTripUID) {
                        ForEach(viewModel.j2kTesting.supportMatrix.filter(\.canEncode), id: \.uid) { entry in
                            Text(entry.shortName).tag(entry.uid)
                        }
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .frame(maxWidth: 180)
                    #endif

                    Spacer()

                    Button {
                        if let file = viewModel.dicomFile {
                            viewModel.j2kTesting.runSelectedRoundTrip(file: file)
                        }
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    Button {
                        if let file = viewModel.dicomFile {
                            viewModel.j2kTesting.runAllRoundTrips(file: file)
                        }
                    } label: {
                        Label("Run All", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    if !viewModel.j2kTesting.roundTripResults.isEmpty {
                        #if canImport(CoreGraphics)
                        let hasImages = viewModel.j2kTesting.rawImage != nil
                            || !viewModel.j2kTesting.encodedImages.isEmpty
                        if hasImages {
                            Button("Clear Images") { viewModel.j2kTesting.clearImages() }
                                .disabled(viewModel.j2kTesting.isRunning)
                        }
                        #endif
                        Button("Reset") { viewModel.j2kTesting.reset() }
                            .disabled(viewModel.j2kTesting.isRunning)
                    }
                }

                // Per-codec result cards
                if viewModel.j2kTesting.roundTripResults.isEmpty {
                    if viewModel.dicomFile == nil {
                        Text("Load a DICOM file to run the round-trip test.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.j2kTesting.roundTripResults) { entry in
                        roundTripEntryCard(entry)
                    }
                }
            }
        } label: {
            Label("Encode → Decode Round-Trip", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
        }
    }

    @ViewBuilder
    private func roundTripEntryCard(_ entry: J2KRoundTripEntry) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                switch entry.state {
                case .idle:
                    EmptyView()
                case .running:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Encoding and decoding…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                case .complete(let r):
                    // Status + notes
                    HStack(spacing: 8) {
                        Image(systemName: r.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(r.passed ? .green : .red)
                            .font(.title3)
                        Text(r.passed ? "PASS" : "FAIL")
                            .font(.subheadline.bold())
                            .foregroundStyle(r.passed ? .green : .red)
                        Spacer()
                        Text(r.notes)
                            .font(.system(size: StudioTypography.captionSize - 1))
                            .foregroundStyle(r.passed ? Color.secondary : Color.red)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                    // Metrics grid
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 4
                    ) {
                        resultRow("Original", value: formatBytes(r.originalBytes))
                        resultRow("Encoded",  value: formatBytes(r.encodedBytes))
                        resultRow("Ratio",    value: String(format: "%.2f×", r.compressionRatio))
                        resultRow("Encode",   value: formatMs(r.encodeMs))
                        resultRow("Decode",   value: formatMs(r.decodeMs))
                        resultRow("Total",    value: formatMs(r.encodeMs + r.decodeMs), accent: true)
                    }
                    // Encoded + decoded image previews
                    #if canImport(CoreGraphics)
                    let encImg = viewModel.j2kTesting.encodedImages[entry.uid]
                    let decImg = viewModel.j2kTesting.decodedImages[entry.uid]
                    if encImg != nil || decImg != nil {
                        Divider()
                        HStack(spacing: 12) {
                            if let img = encImg {
                                imageStrip(label: "Encoded (decoded preview)", image: img)
                            }
                            if let img = decImg {
                                imageStrip(label: "Decoded", image: img)
                            }
                        }
                    }
                    #endif
                case .failed(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.vertical, 2)
        } label: {
            Text(entry.shortName)
                .font(.system(size: StudioTypography.captionSize, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Image Preview Strip

    @ViewBuilder
    private func imageStrip(label: String, image: CGImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: StudioTypography.captionSize - 1))
                .foregroundStyle(.secondary)
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 140)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Row Helpers

    @ViewBuilder
    private func inspectorRow(_ label: String, value: String, icon: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 90, alignment: .leading)
            if let icon {
                Label(value, systemImage: icon).font(.caption.bold())
            } else {
                Text(value).font(.caption.bold())
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ label: String, value: String, accent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: StudioTypography.captionSize))
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .leading)
            Text(value)
                .font(.system(size: StudioTypography.captionSize, design: .monospaced)
                    .weight(accent ? .bold : .regular))
                .foregroundStyle(accent ? .primary : .primary)
        }
    }

    @ViewBuilder
    private func supportBadge(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.system(size: StudioTypography.captionSize - 1, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(active ? Color.green.opacity(0.2) : Color.secondary.opacity(0.15))
            .clipShape(Capsule())
            .foregroundStyle(active ? .green : .secondary)
    }

    // MARK: - Formatting

    private func formatMs(_ ms: Double) -> String {
        CodecInspectorHelpers.formatDecodeTime(ms)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }

    private func isIdle(_ state: J2KBenchmarkState) -> Bool {
        if case .idle = state { return true }
        return false
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("No File") {
    J2KTestingView(viewModel: ImageViewerViewModel())
}
#endif

#endif // canImport(SwiftUI)
