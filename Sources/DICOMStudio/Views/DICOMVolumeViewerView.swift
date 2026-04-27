// DICOMVolumeViewerView.swift
// DICOMStudio — Enterprise 3D MPR Viewer

#if canImport(SwiftUI) && canImport(CoreGraphics)
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - Enterprise Volume Viewer

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct DICOMVolumeViewerView: View {

    @Bindable var vm: DICOMVolumeViewerViewModel
    @State private var isDropTargeted = false

    public init(viewModel: DICOMVolumeViewerViewModel) { self.vm = viewModel }

    public var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            if vm.hasVolume {
                VStack(spacing: 0) {
                    enterpriseToolbar
                    mainContent
                    controlStrip
                }
            } else if vm.isLoading {
                loadingView
            } else {
                dropZone
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .overlay(dropBorder)
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle().fill(Color(white: 0.08)).frame(width: 130, height: 130)
                Image(systemName: "cube.transparent")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(Color(white: 0.28))
            }
            VStack(spacing: 8) {
                Text("Enterprise 3D Viewer")
                    .font(.title.weight(.semibold)).foregroundStyle(.primary)
                Text("Drop a DICOM series folder or JP3D file")
                    .font(.callout).foregroundStyle(.secondary)
                if let err = vm.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            }
            openButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView().scaleEffect(1.5)
            Text("Loading volume…").font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var dropBorder: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .background(Color.accentColor.opacity(0.07).ignoresSafeArea())
                .allowsHitTesting(false)
        }
    }

    // MARK: - Enterprise Toolbar

    private var enterpriseToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // --- File
                openButton.padding(.horizontal, 6)
                toolbarDivider

                // --- Volume info
                if let meta = vm.metadata {
                    Text("\(meta.modality) · \(meta.dimensions) · \(meta.spacing)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1)
                        .padding(.horizontal, 8)
                    toolbarDivider
                }

                // --- Layout
                toolbarGroup {
                    ForEach(ViewerLayout.allCases) { layout in
                        toolbarToggle(
                            symbol: layout.symbol,
                            tooltip: layout.rawValue,
                            isOn: vm.layout == layout
                        ) { vm.layout = layout }
                    }
                }
                toolbarDivider

                // --- Tool
                toolbarGroup {
                    ForEach(ViewerTool.allCases) { tool in
                        toolbarToggle(
                            symbol: tool.symbol,
                            tooltip: tool.rawValue,
                            isOn: vm.activeTool == tool
                        ) { vm.activeTool = tool; vm.cancelMeasurement() }
                    }
                    if vm.activeTool != .navigate && !vm.measurements.isEmpty {
                        Button { vm.clearMeasurements() } label: {
                            Image(systemName: "xmark.circle").font(.system(size: 12))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Clear all measurements")
                        .padding(.horizontal, 4)
                    }
                }
                toolbarDivider

                // --- LUT
                Picker("", selection: $vm.lut) {
                    ForEach(ViewerLUT.allCases) { l in Text(l.rawValue).tag(l) }
                }
                .labelsHidden().frame(maxWidth: 110).padding(.horizontal, 4)
                toolbarDivider

                // --- Slab / MIP
                HStack(spacing: 6) {
                    Text("Slab").font(.system(size: 10)).foregroundStyle(.secondary)
                    Stepper(value: $vm.slabThicknessMM, in: 0...80, step: 2) {
                        Text(vm.slabThicknessMM == 0
                             ? "Off"
                             : String(format: "%.0f mm", vm.slabThicknessMM))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 40)
                    }
                    if vm.slabThicknessMM > 0 {
                        Picker("", selection: $vm.projectionMode) {
                            Text("MIP").tag(ProjectionMode.mip)
                            Text("MinIP").tag(ProjectionMode.minIP)
                            Text("AvgIP").tag(ProjectionMode.avgIP)
                        }
                        .labelsHidden().frame(maxWidth: 80)
                    }
                }
                .padding(.horizontal, 6)
                toolbarDivider

                // --- Cine
                HStack(spacing: 4) {
                    // Step back
                    Button { vm.stepCine(delta: -1) } label: {
                        Image(systemName: "backward.frame").font(.system(size: 11))
                    }
                    .buttonStyle(.plain).disabled(!vm.hasVolume)

                    // Play / Pause
                    Button { vm.toggleCine() } label: {
                        Image(systemName: vm.cineState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(vm.cineState == .playing ? Color(red: 0.3, green: 0.85, blue: 0.5) : .primary)
                    }
                    .buttonStyle(.plain).disabled(!vm.hasVolume)

                    // Step forward
                    Button { vm.stepCine(delta: 1) } label: {
                        Image(systemName: "forward.frame").font(.system(size: 11))
                    }
                    .buttonStyle(.plain).disabled(!vm.hasVolume)

                    // FPS stepper
                    Stepper(value: Binding(
                        get: { vm.cineFPS },
                        set: { vm.setCineFPS($0) }
                    ), in: 1...60, step: 5) {
                        Text(String(format: "%.0ffps", vm.cineFPS))
                            .font(.system(size: 10, design: .monospaced)).frame(width: 36)
                    }

                    // Cine plane
                    Picker("", selection: $vm.cinePlane) {
                        Text("AX").tag(MPRPlane.axial)
                        Text("SAG").tag(MPRPlane.sagittal)
                        Text("COR").tag(MPRPlane.coronal)
                    }
                    .labelsHidden().frame(maxWidth: 68)

                    // Cine mode
                    Picker("", selection: $vm.cineMode) {
                        Text("Loop").tag(PlaybackMode.loop)
                        Text("Bounce").tag(PlaybackMode.bounce)
                        Text("Once").tag(PlaybackMode.once)
                    }
                    .labelsHidden().frame(maxWidth: 74)
                }
                .padding(.horizontal, 6)
                toolbarDivider

                // --- Overlay / Sync / Reset
                HStack(spacing: 4) {
                    toolbarToggle(symbol: "text.bubble", tooltip: "DICOM Overlay",
                                  isOn: vm.showDICOMOverlay) { vm.showDICOMOverlay.toggle() }
                    toolbarToggle(symbol: "link", tooltip: "Sync Zoom / Pan across panels",
                                  isOn: vm.syncZoom) { vm.syncZoom.toggle() }
                    Button { vm.resetPanZoom() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain).help("Reset zoom / pan").padding(.horizontal, 4)
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 6)
            .background(Color(white: 0.09))
        }
        .frame(height: 40)
        .background(Color(white: 0.09))
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 20).padding(.horizontal, 2)
    }

    private func toolbarGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2) { content() }.padding(.horizontal, 4)
    }

    private func toolbarToggle(
        symbol: String, tooltip: String, isOn: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(isOn ? Color(red: 0.2, green: 0.75, blue: 0.95) : Color(white: 0.55))
                .frame(width: 26, height: 26)
                .background(isOn ? Color(red: 0.2, green: 0.75, blue: 0.95).opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Main Content (layout-adaptive)

    @ViewBuilder private var mainContent: some View {
        switch vm.layout {
        case .quad:       quadLayout
        case .triplanar:  triplanarLayout
        case .axialFocus: axialFocusLayout
        case .single:     singleLayout
        }
    }

    // 2×2 grid: Axial | Sagittal / Coronal | Info Panel
    private var quadLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width / 2
            let h = geo.size.height / 2
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    EnterpriseMPRPanel(plane: .axial,    vm: vm, size: CGSize(width: w, height: h))
                    EnterpriseMPRPanel(plane: .sagittal, vm: vm, size: CGSize(width: w, height: h))
                }
                HStack(spacing: 1) {
                    EnterpriseMPRPanel(plane: .coronal,  vm: vm, size: CGSize(width: w, height: h))
                    infoPanel.frame(width: w, height: h)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.06))
    }

    // 3 equal columns: Axial | Sagittal | Coronal
    private var triplanarLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width / 3
            HStack(spacing: 1) {
                EnterpriseMPRPanel(plane: .axial,    vm: vm, size: CGSize(width: w, height: geo.size.height))
                EnterpriseMPRPanel(plane: .sagittal, vm: vm, size: CGSize(width: w, height: geo.size.height))
                EnterpriseMPRPanel(plane: .coronal,  vm: vm, size: CGSize(width: w, height: geo.size.height))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.06))
    }

    // Axial large (left 2/3) + sagittal/coronal stacked (right 1/3)
    private var axialFocusLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                EnterpriseMPRPanel(plane: .axial, vm: vm,
                                   size: CGSize(width: geo.size.width * 2/3, height: geo.size.height))
                VStack(spacing: 1) {
                    EnterpriseMPRPanel(plane: .sagittal, vm: vm,
                                       size: CGSize(width: geo.size.width / 3, height: geo.size.height / 2))
                    EnterpriseMPRPanel(plane: .coronal, vm: vm,
                                       size: CGSize(width: geo.size.width / 3, height: geo.size.height / 2))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.06))
    }

    // Single maximized plane + plane picker strip
    private var singleLayout: some View {
        VStack(spacing: 0) {
            // Plane selector strip
            HStack(spacing: 4) {
                ForEach(MPRPlane.allCases, id: \.self) { plane in
                    Button {
                        vm.singlePlane = plane
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(planeColor(plane)).frame(width: 6, height: 6)
                            Text(planeShort(plane))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(vm.singlePlane == plane ? planeColor(plane) : Color(white: 0.45))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(vm.singlePlane == plane
                                    ? planeColor(plane).opacity(0.15)
                                    : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(white: 0.085))

            GeometryReader { geo in
                EnterpriseMPRPanel(plane: vm.singlePlane, vm: vm, size: geo.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Info Panel (bottom-right in quad layout)

    private var infoPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                metadataSection
                huSection
                presetsGrid
                wlReadout
            }
            .padding(12)
        }
        .background(Color(white: 0.07))
        .overlay(alignment: .topLeading) {
            Text("INFO").font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.28)).padding(6)
        }
    }

    @ViewBuilder private var metadataSection: some View {
        if let m = vm.metadata {
            VStack(alignment: .leading, spacing: 4) {
                sectionLabel("VOLUME")
                infoRow("Modality",   m.modality)
                infoRow("Dims",       m.dimensions)
                infoRow("Spacing",    m.spacing)
                infoRow("Physical",   m.physicalSize)
                infoRow("Memory",     m.memorySize)
            }
        }
    }

    @ViewBuilder private var huSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("CROSSHAIR")
            HStack(spacing: 0) {
                if let hu = vm.crosshairHUValue {
                    Text("\(hu)")
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                        .foregroundStyle(huColor(hu))
                    Text(" HU").font(.system(size: 11)).foregroundStyle(.tertiary).padding(.top, 12)
                } else {
                    Text("—").font(.system(size: 28, weight: .thin)).foregroundStyle(Color(white: 0.28))
                }
            }
            infoRow("Voxel", "(\(vm.sagittalIndex), \(vm.coronalIndex), \(vm.axialIndex))")
        }
    }

    private var presetsGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("WINDOW PRESETS")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(DICOMVolumeViewerViewModel.viewerPresets, id: \.id) { preset in
                    Button { vm.applyPreset(preset) } label: {
                        VStack(spacing: 2) {
                            Text(preset.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                            Text("C:\(Int(preset.center)) W:\(Int(preset.width))")
                                .font(.system(size: 8, design: .monospaced)).opacity(0.65)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .foregroundStyle(vm.selectedPreset == preset ? Color.black : Color(white: 0.75))
                        .background(vm.selectedPreset == preset
                                    ? Color(red: 0.15, green: 0.75, blue: 0.90)
                                    : Color(white: 0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(vm.selectedPreset == preset
                                          ? Color.clear : Color(white: 0.22), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var wlReadout: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("WINDOW / LEVEL")
            HStack(spacing: 12) {
                readoutCell(String(format: "%.0f", vm.windowCenter), "Center",
                            Color(red: 0.40, green: 0.85, blue: 0.55))
                Divider().frame(height: 30)
                readoutCell(String(format: "%.0f", vm.windowWidth), "Width",
                            Color(red: 0.85, green: 0.65, blue: 0.25))
            }
        }
    }

    // MARK: - Control Strip

    private var controlStrip: some View {
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
            }.frame(minWidth: 200)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(white: 0.085))
    }

    private func planeSlider(_ plane: MPRPlane, idx: Int, max maxIdx: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Circle().fill(planeColor(plane)).frame(width: 7, height: 7)
            Text(planeShort(plane))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(planeColor(plane)).frame(width: 26, alignment: .leading)
            Slider(value: Binding(get: { Double(idx) }, set: { onChange(Int($0.rounded())) }),
                   in: 0...Double(max(1, maxIdx)), step: 1)
            Text("\(idx + 1)/\(maxIdx + 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.40)).frame(width: 56, alignment: .trailing)
        }
    }

    private func wlSlider(_ label: String, value: Double, range: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.45)).frame(width: 26, alignment: .leading)
            Slider(value: Binding(get: { value }, set: onChange), in: range, step: 1)
            Text(String(format: "%.0f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.40)).frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Open Button

    private var openButton: some View {
        Button { openPicker() } label: {
            Label("Open Volume", systemImage: "folder.badge.plus").font(.system(size: 12))
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Drop & Picker

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
        panel.canChooseFiles = true; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a DICOM series folder or JP3D file"
        if panel.runModal() == .OK, let url = panel.url {
            Task { try? await vm.loadVolume(from: url) }
        }
        #endif
    }

    // MARK: - Style Helpers

    func planeColor(_ plane: MPRPlane) -> Color {
        switch plane {
        case .axial:    return Color(red: 0.0,  green: 0.90, blue: 0.90)
        case .sagittal: return Color(red: 1.0,  green: 0.85, blue: 0.0)
        case .coronal:  return Color(red: 0.25, green: 0.85, blue: 0.35)
        }
    }

    func planeShort(_ plane: MPRPlane) -> String {
        switch plane { case .axial: "AX"; case .sagittal: "SAG"; case .coronal: "COR" }
    }

    private func huColor(_ hu: Int) -> Color {
        switch hu {
        case ..<(-500):  return Color(red: 0.30, green: 0.70, blue: 1.00)
        case -500..<0:   return Color(red: 0.70, green: 0.85, blue: 0.70)
        case 0..<400:    return Color(red: 0.95, green: 0.90, blue: 0.80)
        default:         return Color(red: 1.00, green: 0.95, blue: 0.60)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(white: 0.30)).tracking(1.5)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundStyle(Color(white: 0.38))
                .frame(width: 64, alignment: .leading)
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(white: 0.80))
        }
    }

    private func readoutCell(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .thin, design: .monospaced)).foregroundStyle(color)
            Text(title).font(.system(size: 9)).foregroundStyle(.tertiary)
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Enterprise MPR Panel (sub-view with zoom/pan/overlays/measurements)

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct EnterpriseMPRPanel: View {

    let plane: MPRPlane
    let vm: DICOMVolumeViewerViewModel
    let size: CGSize

    @GestureState private var magnifyDelta: CGFloat = 1.0
    @GestureState private var panDelta: CGSize      = .zero
    @State private var wlDragOrigin: CGPoint?       = nil

    var body: some View {
        ZStack {
            Color(white: 0.06)

            // Zoomable / pannable content layer
            ZStack {
                if let img = vm.cgImage(for: plane) {
                    Image(decorative: img, scale: 1.0)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    placeholderIcon
                }
                referenceLinesCanvas
                measurementCanvas
            }
            .scaleEffect(vm.zoom(for: plane) * magnifyDelta)
            .offset(panOffset)

            // Fixed-position overlays (don't scale)
            planeBadge
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(7)
            sliceLabel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(7)
            spacingLabel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(7)
            if vm.showDICOMOverlay { dicomOverlay }

            // Pending measurement dot(s)
            if vm.pendingPlane == plane {
                pendingMeasurementHints
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        // Zoom (pinch / trackpad magnify)
        .gesture(
            MagnificationGesture()
                .updating($magnifyDelta) { value, state, _ in state = value }
                .onEnded { value in
                    vm.setZoom(vm.zoom(for: plane) * value, for: plane)
                }
        )
        // Pan (2-finger drag)
        .gesture(
            DragGesture(minimumDistance: 8)
                .updating($panDelta) { value, state, _ in state = value.translation }
                .onEnded { value in
                    vm.adjustPan(value.translation, for: plane)
                }
        )
        // Tap — crosshair (navigate) or measurement placement
        .onTapGesture { loc in
            switch vm.activeTool {
            case .navigate:
                vm.handleClick(x: loc.x, y: loc.y, in: plane, viewSize: size)
            case .distance, .angle:
                vm.placeMeasurementPoint(at: loc, in: plane, viewSize: size)
            }
        }
        // Double-tap → reset zoom/pan for this panel
        .onTapGesture(count: 2) { vm.resetPanZoom(for: plane) }
        // Right-drag (or Ctrl+drag) → W/L adjustment: horizontal = width, vertical = center
        .gesture(
            DragGesture(minimumDistance: 2)
                .modifiers(.control)
                .onChanged { value in
                    if wlDragOrigin == nil { wlDragOrigin = value.startLocation }
                    if let origin = wlDragOrigin {
                        let dx = Double(value.location.x - origin.x)
                        let dy = Double(value.location.y - origin.y)
                        vm.adjustWindowLevel(dx: dx * 0.03, dy: dy * 0.03)
                        wlDragOrigin = value.location
                    }
                }
                .onEnded { _ in wlDragOrigin = nil }
        )
        // Scroll-wheel / two-finger swipe → advance or retreat one slice
        #if os(macOS)
        .onScrollWheel { delta in
            let step = delta > 0 ? -1 : 1   // scroll-down = next (deeper) slice
            switch plane {
            case .axial:    vm.setAxialIndex(vm.axialIndex       + step)
            case .sagittal: vm.setSagittalIndex(vm.sagittalIndex + step)
            case .coronal:  vm.setCoronalIndex(vm.coronalIndex   + step)
            }
        }
        #endif
    }

    private var panOffset: CGSize {
        CGSize(width:  vm.pan(for: plane).width  + panDelta.width,
               height: vm.pan(for: plane).height + panDelta.height)
    }

    // MARK: - Image Placeholder

    private var placeholderIcon: some View {
        VStack(spacing: 6) {
            Image(systemName: planeSymbol).font(.system(size: 24)).foregroundStyle(Color(white: 0.20))
            Text(planeUpperName).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(white: 0.22))
        }
    }

    // MARK: - Reference Lines

    private var referenceLinesCanvas: some View {
        Canvas { ctx, sz in
            for refPlane in MPRPlane.allCases where refPlane != plane {
                guard let t = vm.refLineT(refPlane: refPlane, displayPlane: plane) else { continue }
                let color = JP3DMPRRenderHelpers.referenceLineColour(for: refPlane)
                let axis  = JP3DMPRRenderHelpers.referenceLineAxis(referencePlane: refPlane, displayPlane: plane)
                let path = Path { p in
                    if axis == .horizontal {
                        let y = sz.height * CGFloat(t)
                        p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: sz.width, y: y))
                    } else {
                        let x = sz.width * CGFloat(t)
                        p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: sz.height))
                    }
                }
                ctx.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Measurement Canvas

    private var measurementCanvas: some View {
        Canvas { ctx, sz in
            let idx = vm.sliceIndex(for: plane)
            for m in vm.measurements(in: plane, at: idx) {
                if m.isMeasureAngle { drawAngle(ctx, sz: sz, m: m) }
                else                { drawDistance(ctx, sz: sz, m: m) }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawDistance(_ ctx: GraphicsContext, sz: CGSize, m: PanelMeasurement) {
        guard m.points.count >= 2 else { return }
        let p1 = denorm(m.points[0], sz); let p2 = denorm(m.points[1], sz)
        var line = Path(); line.move(to: p1); line.addLine(to: p2)
        ctx.stroke(line, with: .color(.yellow), style: StrokeStyle(lineWidth: 1.5))
        dot(ctx, at: p1); dot(ctx, at: p2)
        let mid = CGPoint(x: (p1.x + p2.x) / 2 + 4, y: (p1.y + p2.y) / 2 - 8)
        ctx.draw(Text(m.label)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.yellow), at: mid)
    }

    private func drawAngle(_ ctx: GraphicsContext, sz: CGSize, m: PanelMeasurement) {
        guard m.points.count >= 3 else { return }
        let v = denorm(m.points[0], sz); let p1 = denorm(m.points[1], sz); let p2 = denorm(m.points[2], sz)
        var arm1 = Path(); arm1.move(to: v); arm1.addLine(to: p1)
        var arm2 = Path(); arm2.move(to: v); arm2.addLine(to: p2)
        ctx.stroke(arm1, with: .color(.yellow), style: StrokeStyle(lineWidth: 1.5))
        ctx.stroke(arm2, with: .color(.yellow), style: StrokeStyle(lineWidth: 1.5))
        dot(ctx, at: v); dot(ctx, at: p1); dot(ctx, at: p2)
        ctx.draw(Text(m.label)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.yellow),
            at: CGPoint(x: v.x + 6, y: v.y - 10))
    }

    private func dot(_ ctx: GraphicsContext, at pt: CGPoint) {
        ctx.fill(Circle().path(in: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)), with: .color(.yellow))
    }

    private func denorm(_ p: CGPoint, _ sz: CGSize) -> CGPoint {
        CGPoint(x: p.x * sz.width, y: p.y * sz.height)
    }

    // MARK: - Pending Measurement Hints

    @ViewBuilder private var pendingMeasurementHints: some View {
        ForEach(vm.pendingPoints.indices, id: \.self) { i in
            let pt = vm.pendingPoints[i]
            Circle()
                .fill(Color.green.opacity(0.85))
                .frame(width: 8, height: 8)
                .position(x: pt.x * size.width, y: pt.y * size.height)
        }
    }

    // MARK: - DICOM Overlay (4-corner text)

    @ViewBuilder private var dicomOverlay: some View {
        // Top-left: modality + series
        if let meta = vm.metadata {
            VStack(alignment: .leading, spacing: 2) {
                overlayText(meta.modality)
                overlayText(meta.dimensions)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(6)
        }

        // Top-right: W/C + W/W
        VStack(alignment: .trailing, spacing: 2) {
            overlayText(String(format: "W/C %.0f", vm.windowCenter))
            overlayText(String(format: "W/W %.0f", vm.windowWidth))
            if let p = vm.selectedPreset { overlayText(p.name) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(6)

        // Bottom-right: zoom + slab + W/L hint
        VStack(alignment: .trailing, spacing: 2) {
            overlayText(String(format: "×%.1f", vm.zoom(for: plane)))
            if vm.slabThicknessMM > 0 {
                overlayText(String(format: "%@ %.0fmm", vm.projectionMode.rawValue, vm.slabThicknessMM))
            }
            overlayText("⌃drag W/L")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(6)

        // Bottom-left: slice position
        VStack(alignment: .leading, spacing: 2) {
            overlayText(String(format: "%.1f mm", vm.slicePositionMM(for: plane)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 6).padding(.bottom, 24)
    }

    private func overlayText(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color(white: 0.70))
            .shadow(color: .black, radius: 1)
    }

    // MARK: - Fixed Badges

    private var planeBadge: some View {
        HStack(spacing: 4) {
            Circle().fill(planeColorLocal).frame(width: 6, height: 6)
            Text(planeUpperName)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(planeColorLocal)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Color.black.opacity(0.60))
        .clipShape(Capsule())
    }

    private var sliceLabel: some View {
        let cur = vm.sliceIndex(for: plane)
        let mx  = vm.maxIndex(for: plane)
        return Text("\(cur + 1) / \(mx + 1)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color(white: 0.50))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var spacingLabel: some View {
        let s = vm.pixelSpacingMM(for: plane)
        return Text(String(format: "%.2f×%.2f mm", s.x, s.y))
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(Color(white: 0.35))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.black.opacity(0.40))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Helpers

    private var planeColorLocal: Color {
        switch plane {
        case .axial:    return Color(red: 0.0,  green: 0.90, blue: 0.90)
        case .sagittal: return Color(red: 1.0,  green: 0.85, blue: 0.0)
        case .coronal:  return Color(red: 0.25, green: 0.85, blue: 0.35)
        }
    }

    private var planeUpperName: String {
        switch plane { case .axial: "AXIAL"; case .sagittal: "SAGITTAL"; case .coronal: "CORONAL" }
    }

    private var planeSymbol: String {
        switch plane { case .axial: "square.split.1x2"; case .sagittal: "square.split.2x1"; case .coronal: "square.grid.2x2" }
    }
}

// MARK: - ViewModel helper extension (needed by panel)

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension DICOMVolumeViewerViewModel {
    func maxIndex(for plane: MPRPlane) -> Int {
        switch plane { case .axial: maxAxialIndex; case .sagittal: maxSagittalIndex; case .coronal: maxCoronalIndex }
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("Drop Zone") {
    DICOMVolumeViewerView(viewModel: DICOMVolumeViewerViewModel())
        .frame(width: 1200, height: 900)
}
#endif

#endif // canImport(SwiftUI) && canImport(CoreGraphics)
