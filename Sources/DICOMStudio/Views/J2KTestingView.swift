// J2KTestingView.swift
// DICOMStudio
//
// DICOM Studio — J2KSwift implementation testing panel (tabbed layout)

#if canImport(SwiftUI)
import SwiftUI
import DICOMCore

// MARK: - J2KTestingView

/// Tabbed panel for testing the J2KSwift codec implementation.
///
/// Four tabs:
/// 1. **Platform** — backends, transfer syntax support matrix, codec inspector.
/// 2. **Benchmark** — multi-iteration decode timing.
/// 3. **Round-Trip** — encode → decode correctness tests with image previews.
/// 4. **Compare** — J2KSwift vs OpenJPEG side-by-side.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct J2KTestingView: View {

    @Bindable var viewModel: ImageViewerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showComparison = false
    @State private var selectedTab: Tab = .platform

    enum Tab: String, CaseIterable {
        case platform   = "Platform"
        case benchmark  = "Benchmark"
        case roundTrip  = "Round-Trip"
        case compare    = "Compare"

        var icon: String {
            switch self {
            case .platform:  return "cpu"
            case .benchmark: return "stopwatch"
            case .roundTrip: return "arrow.triangle.2.circlepath"
            case .compare:   return "chart.bar.xaxis"
            }
        }
    }

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                platformTab.tabItem { Label(Tab.platform.rawValue,  systemImage: Tab.platform.icon)  }.tag(Tab.platform)
                benchmarkTab.tabItem { Label(Tab.benchmark.rawValue, systemImage: Tab.benchmark.icon) }.tag(Tab.benchmark)
                roundTripTab.tabItem { Label(Tab.roundTrip.rawValue, systemImage: Tab.roundTrip.icon) }.tag(Tab.roundTrip)
                compareTab.tabItem   { Label(Tab.compare.rawValue,   systemImage: Tab.compare.icon)   }.tag(Tab.compare)
            }
            .navigationTitle("J2KSwift Testing — \(selectedTab.rawValue)")
            #if os(macOS)
            .frame(minWidth: 780, minHeight: 560)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
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

    // MARK: - Platform Tab

    private var platformTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backendsSection
                syntaxMatrixSection
                Divider()
                codecInspectorSection
            }
            .padding()
        }
    }

    private var backendsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
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
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundStyle(.green)
                        }
                        Spacer()
                    }
                }
            }
        } label: {
            Label("Codec Backends", systemImage: "cpu").font(.headline)
        }
    }

    private var syntaxMatrixSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("Transfer Syntax").frame(minWidth: 180, alignment: .leading)
                    supportBadge("DEC", active: true).opacity(0)   // header spacer
                    supportBadge("ENC", active: true).opacity(0)
                    Spacer()
                }
                .font(.system(size: StudioTypography.captionSize - 1, weight: .semibold))
                .foregroundStyle(.secondary)

                Divider()

                ForEach(viewModel.j2kTesting.supportMatrix) { entry in
                    HStack(spacing: 4) {
                        Text(entry.shortName)
                            .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                            .frame(minWidth: 180, alignment: .leading)
                        supportBadge("DEC", active: entry.canDecode)
                        supportBadge("ENC", active: entry.canEncode)
                        Spacer()
                    }
                }
            }
        } label: {
            Label("Transfer Syntax Support", systemImage: "list.bullet.rectangle").font(.headline)
        }
    }

    private var codecInspectorSection: some View {
        GroupBox {
            if let entry = viewModel.codecInspector.entry {
                VStack(alignment: .leading, spacing: 6) {
                    inspRow("Codec",       value: entry.codecName)
                    inspRow("Backend",     value: CodecInspectorHelpers.backendDisplayName(entry.backend),
                            icon: CodecInspectorHelpers.backendSFSymbol(entry.backend))
                    inspRow("Decode Time", value: CodecInspectorHelpers.formatDecodeTime(entry.decodeTimeMs))
                    inspRow("Frames",      value: "\(entry.frameCount)")
                    Divider()
                    Text(entry.transferSyntaxUID)
                        .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Label(viewModel.codecInspector.statusSummary, systemImage: "photo")
                    .foregroundStyle(.secondary).font(.callout)
            }
        } label: {
            Label("Current File — Codec Inspector", systemImage: "slider.horizontal.3").font(.headline)
        }
    }

    // MARK: - Benchmark Tab

    private var benchmarkTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
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
                            } label: { Label("Run", systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                            if !isIdle(viewModel.j2kTesting.benchmarkState) {
                                Button("Reset") { viewModel.j2kTesting.reset() }
                                    .disabled(viewModel.j2kTesting.isRunning)
                            }
                        }
                        benchmarkResultView
                    }
                } label: {
                    Label("Decode Benchmark", systemImage: "stopwatch").font(.headline)
                }

                #if DEBUG
                debugWarning
                #endif
            }
            .padding()
        }
    }

    @ViewBuilder
    private var benchmarkResultView: some View {
        switch viewModel.j2kTesting.benchmarkState {
        case .idle:
            if viewModel.dicomFile == nil {
                Text("Load a DICOM file to run the benchmark.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Benchmarking…").font(.caption).foregroundStyle(.secondary)
            }
        case .complete(let r):
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                statRow("Codec",      value: r.codecName)
                statRow("Backend",    value: r.backend.displayName)
                statRow("Iterations", value: "\(r.iterations)")
                statRow("Avg",        value: formatMs(r.avgMs), accent: true)
                statRow("Min",        value: formatMs(r.minMs))
                statRow("Max",        value: formatMs(r.maxMs))
                statRow("Total",      value: formatMs(r.totalMs))
            }
            .padding(.vertical, 4)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Round-Trip Tab

    private var roundTripTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Encodes frame 0 with the selected codec then decodes it back and verifies the output size.")
                    .font(.caption).foregroundStyle(.secondary)

                #if canImport(CoreGraphics)
                if let raw = viewModel.j2kTesting.rawImage {
                    imageStrip(label: "Raw / Original", image: raw)
                }
                #endif

                HStack(spacing: 10) {
                    Text("Target:").font(.callout)
                    Picker("", selection: Bindable(viewModel.j2kTesting).selectedRoundTripUID) {
                        ForEach(viewModel.j2kTesting.supportMatrix.filter(\.canEncode), id: \.uid) { e in
                            Text(e.shortName).tag(e.uid)
                        }
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .frame(maxWidth: 180)
                    #endif
                    Spacer()
                    Button { if let f = viewModel.dicomFile { viewModel.j2kTesting.runSelectedRoundTrip(file: f) } } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    Button { if let f = viewModel.dicomFile { viewModel.j2kTesting.runAllRoundTrips(file: f) } } label: {
                        Label("Run All", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    if !viewModel.j2kTesting.roundTripResults.isEmpty {
                        #if canImport(CoreGraphics)
                        if viewModel.j2kTesting.rawImage != nil || !viewModel.j2kTesting.encodedImages.isEmpty {
                            Button("Clear Images") { viewModel.j2kTesting.clearImages() }
                                .disabled(viewModel.j2kTesting.isRunning)
                        }
                        #endif
                        Button("Reset") { viewModel.j2kTesting.reset() }
                            .disabled(viewModel.j2kTesting.isRunning)
                    }
                }

                #if DEBUG
                debugWarning
                #endif

                if viewModel.j2kTesting.roundTripResults.isEmpty {
                    if viewModel.dicomFile == nil {
                        Text("Load a DICOM file to run the round-trip test.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.j2kTesting.roundTripResults) { entry in
                        roundTripCard(entry)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func roundTripCard(_ entry: J2KRoundTripEntry) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                switch entry.state {
                case .idle: EmptyView()
                case .running:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Encoding and decoding…").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                case .complete(let r):
                    HStack(spacing: 8) {
                        Image(systemName: r.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(r.passed ? .green : .red).font(.title3)
                        Text(r.passed ? "PASS" : "FAIL")
                            .font(.subheadline.bold()).foregroundStyle(r.passed ? .green : .red)
                        Spacer()
                        Text(r.notes)
                            .font(.system(size: StudioTypography.captionSize - 1))
                            .foregroundStyle(r.passed ? Color.secondary : Color.red)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                    statRow("Dimensions",
                            value: "\(r.imageWidth) × \(r.imageHeight) · \(r.bitsAllocated)-bit · \(r.samplesPerPixel == 1 ? "grayscale" : "RGB")")
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                              alignment: .leading, spacing: 4) {
                        statRow("Raw",     value: formatBytes(r.originalBytes))
                        statRow("Encoded", value: formatBytes(r.encodedBytes))
                        statRow("Ratio",   value: String(format: "%.2f×", r.compressionRatio))
                        statRow("Decoded", value: formatBytes(r.decodedBytes),
                                statusColor: r.passed ? .green : .red)
                        statRow("Encode",  value: formatMs(r.encodeMs))
                        statRow("Decode",  value: formatMs(r.decodeMs))
                        statRow("Total",   value: formatMs(r.encodeMs + r.decodeMs), accent: true)
                    }
                    #if canImport(CoreGraphics)
                    let encImg = viewModel.j2kTesting.encodedImages[entry.uid]
                    let decImg = viewModel.j2kTesting.decodedImages[entry.uid]
                    if encImg != nil || decImg != nil {
                        Divider()
                        HStack(spacing: 12) {
                            if let img = encImg { imageStrip(label: "Encoded preview", image: img) }
                            if let img = decImg { imageStrip(label: "Decoded",          image: img) }
                        }
                    }
                    #endif
                case .failed(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }
            }
            .padding(.vertical, 2)
        } label: {
            Text(entry.shortName)
                .font(.system(size: StudioTypography.captionSize, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Compare Tab

    private var compareTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Encodes frame 0 with J2KSwift using the target codec, then decodes with both J2KSwift and OpenJPEG side by side.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text("Target:").font(.callout)
                    Picker("", selection: Bindable(viewModel.j2kTesting).selectedRoundTripUID) {
                        ForEach(viewModel.j2kTesting.supportMatrix.filter(\.canEncode), id: \.uid) { e in
                            Text(e.shortName).tag(e.uid)
                        }
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .frame(maxWidth: 180)
                    #endif
                    Spacer()
                    Button { if let f = viewModel.dicomFile { viewModel.j2kTesting.runCodecComparison(file: f) } } label: {
                        Label("Compare", systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.dicomFile == nil || viewModel.j2kTesting.isRunning)

                    if !viewModel.j2kTesting.comparisonResults.isEmpty {
                        Button("Reset") { viewModel.j2kTesting.reset() }
                            .disabled(viewModel.j2kTesting.isRunning)
                    }
                }

                #if DEBUG
                debugWarning
                #endif

                if viewModel.j2kTesting.comparisonResults.isEmpty {
                    if viewModel.dicomFile == nil {
                        Text("Load a DICOM file to compare codecs.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    compareTableView
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var compareTableView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("Codec").frame(minWidth: 180, alignment: .leading)
                Text("Decode").frame(minWidth: 80, alignment: .trailing)
                Text("Bytes").frame(minWidth: 80, alignment: .trailing)
                Text("vs J2KSwift").frame(minWidth: 90, alignment: .trailing)
                Spacer()
            }
            .font(.system(size: StudioTypography.captionSize - 1, weight: .semibold))
            .foregroundStyle(.secondary)
            Divider()

            ForEach(viewModel.j2kTesting.comparisonResults) { entry in
                compareRow(entry)
            }

            #if canImport(CoreGraphics)
            if !viewModel.j2kTesting.comparisonImages.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.j2kTesting.comparisonResults, id: \.id) { entry in
                            if let img = viewModel.j2kTesting.comparisonImages[entry.codecName] {
                                imageStrip(label: entry.codecName, image: img).frame(width: 200)
                            }
                        }
                    }
                }
            }
            #endif
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func compareRow(_ entry: CodecComparisonEntry) -> some View {
        HStack(spacing: 0) {
            Text(entry.codecName)
                .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                .lineLimit(1).frame(minWidth: 180, alignment: .leading)

            switch entry.state {
            case .idle: EmptyView()
            case .running:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Decoding…").font(.caption).foregroundStyle(.secondary)
                }.frame(minWidth: 250, alignment: .leading)
            case .complete(let r):
                Text(formatMs(r.decodeMs))
                    .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                    .frame(minWidth: 80, alignment: .trailing)
                Text(formatBytes(r.outputBytes))
                    .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                    .frame(minWidth: 80, alignment: .trailing)
                HStack(spacing: 4) {
                    if entry.codecName.hasPrefix("J2KSwift") {
                        Text("reference").font(.system(size: StudioTypography.captionSize - 1)).foregroundStyle(.secondary)
                    } else if let psnr = r.psnrDb {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(String(format: "%.1f dB", psnr))
                            .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                    } else if r.matchesReference {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("identical").font(.system(size: StudioTypography.captionSize - 1))
                    } else {
                        Image(systemName: "xmark.circle").foregroundStyle(.red)
                        Text("size mismatch").font(.system(size: StudioTypography.captionSize - 1)).foregroundStyle(.red)
                    }
                }.frame(minWidth: 90, alignment: .trailing)
                Spacer()
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red).frame(minWidth: 250, alignment: .leading)
            }
        }
    }

    // MARK: - Shared Sub-Views

    @ViewBuilder
    private func imageStrip(label: String, image: CGImage) -> some View {
        #if canImport(CoreGraphics)
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: StudioTypography.captionSize - 1))
                .foregroundStyle(.secondary)
            Image(decorative: image, scale: 1.0)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 140)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        #endif
    }

    private var debugWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Debug build — J2KSwift runs unoptimized. Use Release for accurate benchmarks.")
                .font(.system(size: StudioTypography.captionSize - 1))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Row Helpers

    @ViewBuilder
    private func inspRow(_ label: String, value: String, icon: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(minWidth: 90, alignment: .leading)
            if let icon { Label(value, systemImage: icon).font(.caption.bold()) }
            else        { Text(value).font(.caption.bold()) }
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, value: String, accent: Bool = false, statusColor: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: StudioTypography.captionSize))
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .leading)
            Text(value)
                .font(.system(size: StudioTypography.captionSize, design: .monospaced)
                    .weight(accent ? .bold : .regular))
                .foregroundStyle(statusColor ?? (accent ? Color.primary : Color.primary))
            if let color = statusColor {
                Image(systemName: color == .green ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(color).font(.system(size: StudioTypography.captionSize))
            }
        }
    }

    @ViewBuilder
    private func supportBadge(_ label: String, active: Bool) -> some View {
        Text(label)
            .font(.system(size: StudioTypography.captionSize - 1, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(active ? Color.green.opacity(0.2) : Color.secondary.opacity(0.15))
            .clipShape(Capsule())
            .foregroundStyle(active ? .green : .secondary)
    }

    // MARK: - Formatters

    private func formatMs(_ ms: Double) -> String { CodecInspectorHelpers.formatDecodeTime(ms) }
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

#if DEBUG && !SWIFT_PACKAGE
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("No File") {
    J2KTestingView(viewModel: ImageViewerViewModel())
}
#endif

#endif // canImport(SwiftUI)
