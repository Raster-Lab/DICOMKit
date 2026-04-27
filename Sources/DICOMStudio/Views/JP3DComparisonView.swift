// JP3DComparisonView.swift
// DICOMStudio
//
// JP3D volumetric comparison viewer.
// Shows raw volume vs JP3D-decoded volume side-by-side.
// JP3D = true 3D wavelet compression (full volume at once), NOT per-frame 2D.

#if canImport(SwiftUI) && canImport(CoreGraphics)
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct JP3DComparisonView: View {

    @Bindable var vm: JP3DComparisonViewModel
    @State private var isDropTargeted = false

    public init(viewModel: JP3DComparisonViewModel) {
        self.vm = viewModel
    }

    public var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            if vm.hasVolume {
                mainLayout
            } else if vm.isLoadingVolume {
                loadingOverlay
            } else {
                dropZone
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .overlay(dropBorder)
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color(white: 0.08)).frame(width: 120, height: 120)
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(Color(white: 0.28))
            }

            VStack(spacing: 8) {
                Text("JP3D Volumetric Comparison")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("True 3D wavelet compression — entire volume encoded at once")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Drop a DICOM series folder or JP3D file")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            openButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Loading volume…").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var dropBorder: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .background(Color.accentColor.opacity(0.07).ignoresSafeArea())
                .allowsHitTesting(false)
        }
    }

    // MARK: - Main Layout

    private var mainLayout: some View {
        VStack(spacing: 0) {
            headerBar
            if vm.hasVolume { jp3dInfoStrip }
            columnHeaders
            planeGrid
            controlPanel
            metricsBar
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            openButton

            if !vm.volumeInfo.isEmpty {
                Divider().frame(height: 16)
                Text(vm.volumeInfo)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Mode picker
            Picker("", selection: $vm.selectedMode) {
                ForEach(JP3DModeSelection.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            #if os(macOS)
            .frame(maxWidth: 180)
            #endif

            // PSNR target for lossy modes
            if vm.selectedMode.isLossy {
                HStack(spacing: 4) {
                    Text("PSNR")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Stepper(value: $vm.lossyPSNRTarget, in: 20...80, step: 5) {
                        Text(String(format: "%.0f dB", vm.lossyPSNRTarget))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 48)
                    }
                }
            }

            compressButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(white: 0.09))
    }

    @ViewBuilder private var compressButton: some View {
        switch vm.compressionState {
        case .idle:
            Button { vm.runCompression() } label: {
                Label("Compress (JP3D)", systemImage: "waveform.path.ecg.rectangle")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)

        case .compressing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Encoding volume…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

        case .complete:
            Button { vm.runCompression() } label: {
                Label("Re-compress", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

        case .failed:
            Button { vm.runCompression() } label: {
                Label("Retry", systemImage: "exclamationmark.arrow.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    // MARK: - JP3D Info Strip

    private var jp3dInfoStrip: some View {
        HStack(spacing: 16) {
            Image(systemName: "cube.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.95))

            Text("JP3D — Volumetric 3D Wavelet")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.95))

            if let info = vm.decompositionInfo {
                Divider().frame(height: 12)
                infoChip("Levels X", "\(info.levelsX)")
                infoChip("Levels Y", "\(info.levelsY)")
                infoChip("Levels Z", "\(info.levelsZ)")
                infoChip("Quality Layers", "\(info.qualityLayers)")
                infoChip("Progression", info.progressionOrder)
            }

            Spacer()

            Text(vm.selectedMode.isLossy ? "LOSSY" : "LOSSLESS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(vm.selectedMode.isLossy
                    ? Color(red: 1.0, green: 0.65, blue: 0.15)
                    : Color(red: 0.25, green: 0.80, blue: 0.50))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    vm.selectedMode.isLossy
                        ? Color(red: 1.0, green: 0.65, blue: 0.15).opacity(0.15)
                        : Color(red: 0.25, green: 0.80, blue: 0.50).opacity(0.15)
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.55, green: 0.40, blue: 0.95).opacity(0.08))
        .overlay(alignment: .bottom) {
            Color(red: 0.55, green: 0.40, blue: 0.95).opacity(0.25).frame(height: 1)
        }
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Color(white: 0.38))
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.72))
        }
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 1) {
            columnHeader(
                title: "RAW VOLUME",
                subtitle: "Uncompressed original",
                color: Color(red: 0.20, green: 0.55, blue: 0.90),
                icon: "waveform.path"
            )
            columnHeader(
                title: "JP3D DECODED",
                subtitle: decodedSubtitle,
                color: decodedHeaderColor,
                icon: "waveform.path.ecg.rectangle"
            )
        }
        .frame(height: 40)
    }

    private func columnHeader(title: String, subtitle: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color).tracking(0.8)
                Text(subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(color.opacity(0.65))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10))
        .overlay(alignment: .bottom) { color.opacity(0.35).frame(height: 1) }
    }

    private var decodedSubtitle: String {
        switch vm.compressionState {
        case .idle:
            return vm.hasVolume ? "Tap Compress (JP3D) to encode the full volume at once" : ""
        case .compressing:
            return "Encoding entire volume via 3D wavelet transform…"
        case .complete(_, _, let ratio, _, let enc, let psnr):
            let psnrStr = psnr.isInfinite
                ? "∞ dB (lossless)"
                : String(format: "%.1f dB", psnr)
            return "\(vm.selectedMode.rawValue) · \(String(format: "%.2f×", ratio)) · \(formatBytes(enc)) · PSNR \(psnrStr)"
        case .failed(let msg):
            return "Error: \(msg)"
        }
    }

    private var decodedHeaderColor: Color {
        switch vm.compressionState {
        case .idle:        return Color(white: 0.40)
        case .compressing: return Color(red: 0.55, green: 0.40, blue: 0.95)
        case .complete:    return Color(red: 0.25, green: 0.80, blue: 0.50)
        case .failed:      return Color(red: 0.90, green: 0.30, blue: 0.30)
        }
    }

    // MARK: - 3-Row × 2-Column Plane Grid

    private var planeGrid: some View {
        VStack(spacing: 1) {
            ForEach([MPRPlane.axial, .sagittal, .coronal], id: \.self) { plane in
                HStack(spacing: 1) {
                    mprCell(plane: plane, childVM: vm.rawVM, isDecoded: false)
                    mprCell(plane: plane, childVM: vm.decodedVM, isDecoded: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.07))
    }

    private func mprCell(plane: MPRPlane, childVM: JP3DMPRViewModel, isDecoded: Bool) -> some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.06)

                if let img = cgImage(plane: plane, from: childVM) {
                    Image(decorative: img, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    emptyPlaceholder(plane)
                }

                if childVM.volume != nil {
                    referenceLinesCanvas(plane: plane, size: geo.size)
                }

                planeBadge(plane, isDecoded: isDecoded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)

                sliceCounter(plane)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }
            .contentShape(Rectangle())
            .onTapGesture { loc in
                vm.handleClick(x: loc.x, y: loc.y, in: plane, viewSize: geo.size)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        vm.handleClick(x: v.location.x, y: v.location.y, in: plane, viewSize: geo.size)
                    }
            )
            #if os(macOS)
            .onScrollWheel { delta in
                let step = delta > 0 ? -1 : 1
                switch plane {
                case .axial:    vm.setAxialIndex(vm.axialIndex       + step)
                case .sagittal: vm.setSagittalIndex(vm.sagittalIndex + step)
                case .coronal:  vm.setCoronalIndex(vm.coronalIndex   + step)
                }
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func emptyPlaceholder(_ plane: MPRPlane) -> some View {
        VStack(spacing: 6) {
            Image(systemName: planeSymbol(plane))
                .font(.system(size: 22)).foregroundStyle(Color(white: 0.20))
            Text(planeName(plane))
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(white: 0.23))
        }
    }

    // MARK: - Reference Lines

    private func referenceLinesCanvas(plane: MPRPlane, size: CGSize) -> some View {
        Canvas { ctx, _ in
            for refPlane in MPRPlane.allCases where refPlane != plane {
                guard let t = refLineT(refPlane: refPlane, displayPlane: plane) else { continue }
                let color = JP3DMPRRenderHelpers.referenceLineColour(for: refPlane)
                let axis  = JP3DMPRRenderHelpers.referenceLineAxis(referencePlane: refPlane, displayPlane: plane)
                let path = Path { p in
                    switch axis {
                    case .horizontal:
                        let y = size.height * CGFloat(t)
                        p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                    case .vertical:
                        let x = size.width * CGFloat(t)
                        p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                    }
                }
                ctx.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func planeBadge(_ plane: MPRPlane, isDecoded: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(planeColor(plane)).frame(width: 6, height: 6)
            Text(planeName(plane))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(planeColor(plane))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private func sliceCounter(_ plane: MPRPlane) -> some View {
        let (cur, mx) = sliceInfo(plane)
        return Text("\(cur + 1) / \(mx + 1)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color(white: 0.50))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.black.opacity(0.50))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 5) {
                planeSlider(.axial,    idx: vm.axialIndex,    max: vm.maxAxialIndex)    { vm.setAxialIndex($0) }
                planeSlider(.sagittal, idx: vm.sagittalIndex, max: vm.maxSagittalIndex) { vm.setSagittalIndex($0) }
                planeSlider(.coronal,  idx: vm.coronalIndex,  max: vm.maxCoronalIndex)  { vm.setCoronalIndex($0) }
            }
            Divider().frame(height: 60)
            VStack(spacing: 5) {
                wlSlider("W/C", value: vm.windowCenter, range: -1024...3072) { v in
                    vm.setWindowLevel(center: v, width: vm.windowWidth)
                }
                wlSlider("W/W", value: vm.windowWidth, range: 1...4096) { v in
                    vm.setWindowLevel(center: vm.windowCenter, width: v)
                }
            }
            .frame(minWidth: 220)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(white: 0.09))
    }

    private func planeSlider(
        _ plane: MPRPlane, idx: Int, max maxIdx: Int,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Circle().fill(planeColor(plane)).frame(width: 7, height: 7)
            Text(planeShort(plane))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(planeColor(plane))
                .frame(width: 28, alignment: .leading)
            Slider(
                value: Binding(get: { Double(idx) }, set: { onChange(Int($0.rounded())) }),
                in: 0...Double(max(1, maxIdx)), step: 1
            )
            Text("\(idx + 1)/\(maxIdx + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.40))
                .frame(width: 58, alignment: .trailing)
        }
    }

    private func wlSlider(
        _ label: String, value: Double, range: ClosedRange<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .frame(width: 28, alignment: .leading)
            Slider(value: Binding(get: { value }, set: onChange), in: range, step: 1)
            Text(String(format: "%.0f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.40))
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Metrics Bar

    @ViewBuilder private var metricsBar: some View {
        HStack(spacing: 14) {
            switch vm.compressionState {
            case .idle:
                Text(vm.hasVolume ? "Select a mode and tap Compress (JP3D) to encode the entire volume." : "")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .compressing:
                ProgressView().scaleEffect(0.7)
                Text("JP3D volumetric encode in progress…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.95))

            case .complete(let encMs, let decMs, let ratio, let rawB, let encB, let psnr):
                metricPill("Ratio",   value: String(format: "%.2f×", ratio),
                           accent: ratio >= 2 ? .green : .yellow)
                metricPill("Raw",     value: formatBytes(rawB))
                metricPill("Encoded", value: formatBytes(encB))
                metricPill("Encode",  value: formatMs(encMs))
                metricPill("Decode",  value: formatMs(decMs))
                metricPill("Total",   value: formatMs(encMs + decMs), accent: .primary)
                Divider().frame(height: 14)
                psnrPill(psnr)
                Spacer()
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.system(size: 11))
                Text("Complete").font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)

            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(msg).font(.system(size: 10)).foregroundStyle(.red)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Color(white: 0.08))
    }

    private func metricPill(_ label: String, value: String, accent: Color = .secondary) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 9)).foregroundStyle(Color(white: 0.38))
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(accent)
        }
    }

    private func psnrPill(_ psnr: Double) -> some View {
        HStack(spacing: 3) {
            Text("PSNR").font(.system(size: 9)).foregroundStyle(Color(white: 0.38))
            if psnr.isInfinite {
                Text("∞ dB")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.25, green: 0.80, blue: 0.50))
                Text("(lossless)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.38))
            } else {
                Text(String(format: "%.1f dB", psnr))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(psnr >= 45 ? .green : psnr >= 35 ? .yellow : .orange)
            }
        }
    }

    // MARK: - Open Button

    private var openButton: some View {
        Button { openPicker() } label: {
            Label("Open Volume", systemImage: "folder.badge.plus")
                .font(.system(size: 12))
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Rendering Helpers

    private func cgImage(plane: MPRPlane, from childVM: JP3DMPRViewModel) -> CGImage? {
        guard let dims = childVM.dimensions else { return nil }
        let buf: Data?
        switch plane {
        case .axial:    buf = childVM.axialBuffer
        case .sagittal: buf = childVM.sagittalBuffer
        case .coronal:  buf = childVM.coronalBuffer
        }
        guard let data = buf else { return nil }
        let (w, h) = MPRHelpers.sliceDimensions(plane: plane, dimensions: dims)
        return JP3DMPRRenderHelpers.cgImage(from: data, width: w, height: h)
    }

    private func refLineT(refPlane: MPRPlane, displayPlane: MPRPlane) -> Double? {
        guard let dims = vm.rawVM.dimensions else { return nil }
        let idx: Int
        switch refPlane {
        case .axial:    idx = vm.axialIndex
        case .sagittal: idx = vm.sagittalIndex
        case .coronal:  idx = vm.coronalIndex
        }
        return MPRHelpers.referenceLinePosition(
            referencePlane: refPlane, referenceSlice: idx,
            displayPlane: displayPlane, dimensions: dims
        )
    }

    private func sliceInfo(_ plane: MPRPlane) -> (Int, Int) {
        switch plane {
        case .axial:    return (vm.axialIndex,    vm.maxAxialIndex)
        case .sagittal: return (vm.sagittalIndex, vm.maxSagittalIndex)
        case .coronal:  return (vm.coronalIndex,  vm.maxCoronalIndex)
        }
    }

    // MARK: - Style

    private func planeColor(_ plane: MPRPlane) -> Color {
        switch plane {
        case .axial:    return Color(red: 0.0,  green: 0.90, blue: 0.90)
        case .sagittal: return Color(red: 1.0,  green: 0.85, blue: 0.0)
        case .coronal:  return Color(red: 0.25, green: 0.85, blue: 0.35)
        }
    }

    private func planeName(_ plane: MPRPlane) -> String {
        switch plane {
        case .axial: return "AXIAL"; case .sagittal: return "SAGITTAL"; case .coronal: return "CORONAL"
        }
    }

    private func planeShort(_ plane: MPRPlane) -> String {
        switch plane {
        case .axial: return "AX"; case .sagittal: return "SAG"; case .coronal: return "COR"
        }
    }

    private func planeSymbol(_ plane: MPRPlane) -> String {
        switch plane {
        case .axial: return "square.split.1x2"; case .sagittal: return "square.split.2x1"
        case .coronal: return "square.grid.2x2"
        }
    }

    // MARK: - Drop + Picker

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in try? await self.vm.loadVolume(from: url) }
        }
        return true
    }

    private func openPicker() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a DICOM series folder or JP3D file"
        if panel.runModal() == .OK, let url = panel.url {
            Task { try? await vm.loadVolume(from: url) }
        }
        #endif
    }

    // MARK: - Formatters

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func formatMs(_ ms: Double) -> String {
        ms < 1_000 ? String(format: "%.0f ms", ms) : String(format: "%.2f s", ms / 1_000)
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("Drop Zone") {
    JP3DComparisonView(viewModel: JP3DComparisonViewModel())
        .frame(width: 1100, height: 820)
}
#endif

#endif // canImport(SwiftUI) && canImport(CoreGraphics)
