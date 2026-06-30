// ProgressiveImageView.swift
// DICOMStudio
//
// DICOM Studio — Progressive JPEG 2000 image viewer (Phase 8)
//
// A SwiftUI Canvas-based view that displays DICOM images at progressively
// higher resolution levels as they arrive from `ImageDecodingService`.
// Shows a quality-level badge while decoding is in progress.

#if canImport(SwiftUI)
import SwiftUI

// MARK: - ProgressiveImageView

/// A SwiftUI `Canvas`-based image viewer that renders DICOM images progressively.
///
/// When `viewModel.progressiveDecodeState` is `.decoding(level:)`, the canvas
/// displays the latest received CGImage (which may be at 1/4 or 1/2 resolution)
/// and overlays a "Refining…" badge. Once the state reaches `.complete(_:)`, the
/// full-resolution image is shown without any badge.
///
/// For non-J2K files (`progressiveDecodeState == .unavailable`), callers should
/// use the standard `ImageViewerView` path instead.
///
/// Requires macOS 14+ / iOS 17+ (for `@Observable`-compatible `@Bindable` binding).
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct ProgressiveImageView: View {

    @Bindable var viewModel: ImageViewerViewModel

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            progressiveCanvas
            if let badge = ProgressiveDecodeHelpers.badgeText(for: viewModel.progressiveDecodeState) {
                qualityBadge(text: badge)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            ProgressiveDecodeHelpers.accessibilityLabel(for: viewModel.progressiveDecodeState)
        )
    }

    // MARK: - Canvas

    @ViewBuilder
    private var progressiveCanvas: some View {
        #if canImport(CoreGraphics)
        if let cgImage = viewModel.progressiveImage ?? viewModel.currentImage {
            // Render through a plain resizable `Image`, identical to the standard
            // (uncompressed) viewer path in ImageViewerView. The previous
            // `Canvas { context.draw(...) }` implementation blanked J2K/HTJ2K
            // previews: a `Canvas` has no intrinsic size, so combined with
            // `.aspectRatio` its closure `size` could resolve to zero and nothing
            // was drawn — producing an empty image for *every* progressively-decoded
            // (encapsulated J2K) file while uncompressed files rendered fine.
            // `Image(decorative:)` derives its size from the CGImage, so it draws
            // reliably. Reference: matches ImageViewerView.imageContent.
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(viewModel.zoomLevel)
                .offset(
                    x: viewModel.panOffsetX,
                    y: viewModel.panOffsetY
                )
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .scaleEffect(
                    x: viewModel.isFlippedHorizontal ? -1 : 1,
                    y: viewModel.isFlippedVertical   ? -1 : 1
                )
        } else {
            Color.black
        }
        #else
        Color.black
        #endif
    }

    // MARK: - Badge Overlay

    private func qualityBadge(text: String) -> some View {
        HStack(spacing: 4) {
            if ProgressiveDecodeHelpers.isProgressSpinnerVisible(for: viewModel.progressiveDecodeState) {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(.black.opacity(0.65))
        )
        .padding(8)
        .transition(.opacity.animation(.easeOut(duration: 0.3)))
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }

}

// MARK: - Preview Support

#if DEBUG
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
#Preview("Idle") {
    ProgressiveImageView(viewModel: ImageViewerViewModel())
        .frame(width: 400, height: 400)
        .background(.black)
}
#endif

#endif // canImport(SwiftUI)
