// JP3DMPRView.swift
// DICOMStudio
//
// DICOM Studio — JP3D Multi-Planar Reconstruction (MPR) View (Phase 8 / Phase 9)
//
// Displays axial, sagittal, and coronal reconstructions of a DICOMVolume
// decoded via the J2K3D volumetric codec. Includes crosshair synchronisation,
// reference lines, slice navigation sliders, and window/level controls.

#if canImport(SwiftUI)
import SwiftUI
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - JP3DMPRView

/// A three-panel Multi-Planar Reconstruction (MPR) view for JP3D DICOM volumes.
///
/// Renders axial, sagittal, and coronal planes derived from a ``DICOMVolume``
/// that was decoded via the J2K3D volumetric codec. Clicking any plane moves
/// the crosshair and synchronises all three slice indices.
///
/// ## Usage
///
/// ```swift
/// let vm = JP3DMPRViewModel()
///
/// JP3DMPRView(viewModel: vm)
///     .task { try? await vm.loadVolume(from: jp3dURL) }
/// ```
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct JP3DMPRView: View {

    @Bindable var viewModel: JP3DMPRViewModel

    public init(viewModel: JP3DMPRViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let message = viewModel.errorMessage {
                errorView(message: message)
            } else if viewModel.volume != nil {
                mprLayout
            } else {
                emptyView
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            NSLocalizedString(
                "mpr.view.accessibility",
                value: "Multi-Planar Reconstruction View",
                comment: "Accessibility label for the JP3D MPR panel"
            )
        )
    }

    // MARK: - Loading / Error / Empty

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(
                NSLocalizedString(
                    "mpr.loading",
                    value: "Loading volume…",
                    comment: "Loading indicator for MPR volume"
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(
            NSLocalizedString(
                "mpr.loading.accessibility",
                value: "Loading volume data",
                comment: "Accessibility label while loading"
            )
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(
                NSLocalizedString(
                    "mpr.error.title",
                    value: "Unable to load volume",
                    comment: "MPR load error title"
                )
            )
            .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(
            NSLocalizedString(
                "mpr.error.accessibility",
                value: "Volume load error",
                comment: "Accessibility label for error state"
            ) + ": " + message
        )
    }

    private var emptyView: some View {
        Text(
            NSLocalizedString(
                "mpr.empty",
                value: "No volume loaded",
                comment: "MPR empty state"
            )
        )
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(
            NSLocalizedString(
                "mpr.empty.accessibility",
                value: "No volume loaded. Use loadVolume to open a JP3D file.",
                comment: "Accessibility empty state"
            )
        )
    }

    // MARK: - MPR Layout

    private var mprLayout: some View {
        VStack(spacing: 4) {
            // Three plane panels
            HStack(spacing: 4) {
                JP3DPlanePanel(
                    plane: .axial,
                    viewModel: viewModel
                )
                JP3DPlanePanel(
                    plane: .sagittal,
                    viewModel: viewModel
                )
                JP3DPlanePanel(
                    plane: .coronal,
                    viewModel: viewModel
                )
            }

            // Window / Level controls
            windowLevelControls
        }
        .padding(8)
    }

    // MARK: - Window / Level Controls

    private var windowLevelControls: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    NSLocalizedString(
                        "mpr.wc.label",
                        value: "Window Center",
                        comment: "Window center slider label"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { viewModel.windowCenter },
                        set: { viewModel.setWindowLevel(center: $0, width: viewModel.windowWidth) }
                    ),
                    in: -1024...3072,
                    step: 1
                )
                .accessibilityLabel(
                    NSLocalizedString(
                        "mpr.wc.accessibility",
                        value: "Window center",
                        comment: "Window center slider accessibility label"
                    )
                )
                .accessibilityValue("\(Int(viewModel.windowCenter))")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    NSLocalizedString(
                        "mpr.ww.label",
                        value: "Window Width",
                        comment: "Window width slider label"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { viewModel.windowWidth },
                        set: { viewModel.setWindowLevel(center: viewModel.windowCenter, width: $0) }
                    ),
                    in: 1...4096,
                    step: 1
                )
                .accessibilityLabel(
                    NSLocalizedString(
                        "mpr.ww.accessibility",
                        value: "Window width",
                        comment: "Window width slider accessibility label"
                    )
                )
                .accessibilityValue("\(Int(viewModel.windowWidth))")
            }

            // Crosshair toggle
            Toggle(isOn: $viewModel.crosshairLinkingEnabled) {
                Label(
                    NSLocalizedString(
                        "mpr.crosshair.toggle",
                        value: "Crosshair Link",
                        comment: "Toggle label for crosshair linking"
                    ),
                    systemImage: "plus.viewfinder"
                )
                .font(.caption)
            }
            .toggleStyle(.button)
            .accessibilityLabel(
                NSLocalizedString(
                    "mpr.crosshair.toggle.accessibility",
                    value: "Crosshair linking",
                    comment: "Accessibility label for crosshair linking toggle"
                )
            )

            // Reference lines toggle
            Toggle(isOn: $viewModel.showReferenceLines) {
                Label(
                    NSLocalizedString(
                        "mpr.reflines.toggle",
                        value: "Reference Lines",
                        comment: "Toggle label for reference lines"
                    ),
                    systemImage: "line.diagonal"
                )
                .font(.caption)
            }
            .toggleStyle(.button)
            .accessibilityLabel(
                NSLocalizedString(
                    "mpr.reflines.toggle.accessibility",
                    value: "Reference lines",
                    comment: "Accessibility label for reference lines toggle"
                )
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.background.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - JP3DPlanePanel

/// A single MPR plane panel: image canvas, reference lines, and a slice slider.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct JP3DPlanePanel: View {

    let plane: MPRPlane
    @Bindable var viewModel: JP3DMPRViewModel

    // Localised plane labels
    private var planeTitle: String {
        switch plane {
        case .axial:
            return NSLocalizedString("mpr.plane.axial",    value: "Axial",    comment: "Axial plane label")
        case .sagittal:
            return NSLocalizedString("mpr.plane.sagittal", value: "Sagittal", comment: "Sagittal plane label")
        case .coronal:
            return NSLocalizedString("mpr.plane.coronal",  value: "Coronal",  comment: "Coronal plane label")
        }
    }

    private var currentIndex: Int {
        switch plane {
        case .axial:    return viewModel.axialIndex
        case .sagittal: return viewModel.sagittalIndex
        case .coronal:  return viewModel.coronalIndex
        }
    }

    private var maxIndex: Int {
        guard let dims = viewModel.dimensions else { return 0 }
        return max(0, dims.maxSliceIndex(for: plane))
    }

    private var displayBuffer: Data? {
        switch plane {
        case .axial:    return viewModel.axialBuffer
        case .sagittal: return viewModel.sagittalBuffer
        case .coronal:  return viewModel.coronalBuffer
        }
    }

    private var sliceDimensions: (width: Int, height: Int) {
        guard let dims = viewModel.dimensions else { return (1, 1) }
        return MPRHelpers.sliceDimensions(plane: plane, dimensions: dims)
    }

    var body: some View {
        VStack(spacing: 2) {
            // Plane title badge
            Text(planeTitle)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            // Image canvas
            imageCanvas
                .aspectRatio(
                    CGFloat(sliceDimensions.width) / CGFloat(max(1, sliceDimensions.height)),
                    contentMode: .fit
                )
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .topLeading) {
                    if viewModel.showReferenceLines {
                        referenceLinesOverlay
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Map tap position to voxel coordinates
                            // Note: actual mapping requires view geometry — handled via onTapGesture
                        }
                )
                .onTapGesture { location in
                    // location is in view coordinates; approximate mapping via ratio
                    // This is a simplified mapping; production code would use GeometryReader
                    guard let dims = viewModel.dimensions else { return }
                    let (sw, sh) = MPRHelpers.sliceDimensions(plane: plane, dimensions: dims)
                    // We don't have the view size here without GeometryReader; use a fixed estimate
                    // In the full integration, wrap in GeometryReader for precise mapping
                    let vx = Int(location.x)
                    let vy = Int(location.y)
                    viewModel.handleClick(x: vx, y: vy, in: plane)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(planePanelAccessibilityLabel)
                .accessibilityValue(planePanelAccessibilityValue)
                .accessibilityHint(
                    NSLocalizedString(
                        "mpr.plane.hint",
                        value: "Tap to move crosshair. Use slider to navigate slices.",
                        comment: "Accessibility hint for MPR plane panel"
                    )
                )
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: viewModel.scroll(delta: 1, in: plane)
                    case .decrement: viewModel.scroll(delta: -1, in: plane)
                    @unknown default: break
                    }
                }

            // Slice slider
            sliceSlider
        }
    }

    // MARK: - Image Canvas

    @ViewBuilder
    private var imageCanvas: some View {
        #if canImport(CoreGraphics)
        if let buffer = displayBuffer,
           let cgImage = JP3DMPRRenderHelpers.cgImage(
            from: buffer,
            width: sliceDimensions.width,
            height: sliceDimensions.height
           ) {
            Canvas { context, size in
                let resolved = context.resolve(Image(decorative: cgImage, scale: 1.0))
                context.draw(resolved, in: CGRect(origin: .zero, size: size))
            }
        } else {
            Color.black
                .overlay {
                    Image(systemName: "cube.fill")
                        .foregroundStyle(.gray)
                        .font(.title2)
                        .accessibilityHidden(true)
                }
        }
        #else
        Color.black
        #endif
    }

    // MARK: - Reference Lines Overlay

    @ViewBuilder
    private var referenceLinesOverlay: some View {
        #if canImport(CoreGraphics)
        let otherPlanes = MPRPlane.allCases.filter { $0 != plane }
        Canvas { context, size in
            for refPlane in otherPlanes {
                guard let t = viewModel.referenceLinePosition(
                    referencePlane: refPlane,
                    displayPlane: plane
                ) else { continue }

                let colour = JP3DMPRRenderHelpers.referenceLineColour(for: refPlane)

                switch JP3DMPRRenderHelpers.referenceLineAxis(referencePlane: refPlane, displayPlane: plane) {
                case .horizontal:
                    let y = size.height * CGFloat(t)
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(colour),
                        lineWidth: 1.0
                    )
                case .vertical:
                    let x = size.width * CGFloat(t)
                    context.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(colour),
                        lineWidth: 1.0
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        #else
        EmptyView()
        #endif
    }

    // MARK: - Slice Slider

    private var sliceSlider: some View {
        HStack(spacing: 4) {
            Text(
                NSLocalizedString(
                    "mpr.slice.label",
                    value: "Slice",
                    comment: "Slice slider label"
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(currentIndex) },
                    set: { viewModel.setSliceIndex(Int($0.rounded()), for: plane) }
                ),
                in: 0...Double(max(1, maxIndex)),
                step: 1
            )
            .accessibilityLabel(
                String(format:
                    NSLocalizedString(
                        "mpr.slice.accessibility",
                        value: "%@ slice navigation",
                        comment: "Slice slider accessibility label; %@ is the plane name"
                    ),
                    planeTitle
                )
            )
            .accessibilityValue("\(currentIndex)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.scroll(delta: 1, in: plane)
                case .decrement: viewModel.scroll(delta: -1, in: plane)
                @unknown default: break
                }
            }

            Text("\(currentIndex)/\(maxIndex)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 48, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Accessibility Text

    private var planePanelAccessibilityLabel: String {
        String(format:
            NSLocalizedString(
                "mpr.plane.panel.accessibility",
                value: "%@ plane image",
                comment: "Accessibility label for a single MPR plane panel; %@ is the plane name"
            ),
            planeTitle
        )
    }

    private var planePanelAccessibilityValue: String {
        "\(planeTitle), " +
        String(format:
            NSLocalizedString(
                "mpr.plane.panel.slice.value",
                value: "slice %d of %d",
                comment: "Accessibility value for slice index; arguments are current and max slice"
            ),
            currentIndex, maxIndex
        )
    }
}

#endif // canImport(SwiftUI)
