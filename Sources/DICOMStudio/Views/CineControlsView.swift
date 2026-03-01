// CineControlsView.swift
// DICOMStudio
//
// DICOM Studio — Cine playback controls

#if canImport(SwiftUI)
import SwiftUI

/// Controls for multi-frame cine playback.
///
/// Provides play/pause/stop buttons, frame slider, FPS control,
/// and playback mode selection.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct CineControlsView: View {
    @Bindable var viewModel: ImageViewerViewModel

    @State private var timer: Timer?

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Frame slider
            HStack(spacing: 8) {
                Text(viewModel.frameText)
                    .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(minWidth: 100)
                    .accessibilityLabel("Frame position")
                    .accessibilityValue("\(viewModel.currentFrameIndex + 1) of \(viewModel.numberOfFrames)")

                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentFrameIndex) },
                        set: { viewModel.goToFrame(Int($0)) }
                    ),
                    in: 0...Double(max(1, viewModel.numberOfFrames - 1)),
                    step: 1
                )
                .accessibilityLabel("Frame scrubber")
                .accessibilityValue("Frame \(viewModel.currentFrameIndex + 1) of \(viewModel.numberOfFrames)")
            }

            // Transport controls
            HStack(spacing: 12) {
                // Step backward
                Button {
                    viewModel.previousFrame()
                } label: {
                    Image(systemName: "backward.frame.fill")
                }
                .accessibilityLabel("Previous frame")
                .help("Previous frame (Left arrow)")
                .disabled(viewModel.playbackState == .playing)

                // Play/Pause
                Button {
                    viewModel.togglePlayback()
                    updateTimer()
                } label: {
                    Image(systemName: CinePlaybackHelpers.stateSystemImage(for: viewModel.playbackState))
                }
                .accessibilityLabel(viewModel.playbackState == .playing ? "Pause" : "Play")
                .help("Play/Pause (Space)")

                // Stop
                Button {
                    viewModel.stopPlayback()
                    stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .accessibilityLabel("Stop playback")
                .help("Stop and reset to first frame")

                // Step forward
                Button {
                    viewModel.nextFrame()
                } label: {
                    Image(systemName: "forward.frame.fill")
                }
                .accessibilityLabel("Next frame")
                .help("Next frame (Right arrow)")
                .disabled(viewModel.playbackState == .playing)

                Divider()
                    .frame(height: 16)

                // Playback mode
                Picker("Mode", selection: Bindable(viewModel).playbackMode) {
                    ForEach(PlaybackMode.allCases, id: \.self) { mode in
                        Label(
                            CinePlaybackHelpers.modeLabel(for: mode),
                            systemImage: CinePlaybackHelpers.modeSystemImage(for: mode)
                        ).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .accessibilityLabel("Playback mode")

                Divider()
                    .frame(height: 16)

                // FPS control
                HStack(spacing: 4) {
                    Text("FPS:")
                        .font(.caption)
                        .foregroundStyle(.white)
                    TextField("FPS", value: Bindable(viewModel).playbackFPS, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .accessibilityLabel("Frames per second")
                        .onSubmit { updateTimer() }
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: viewModel.playbackState) { _, newValue in
            if newValue != .playing {
                stopTimer()
            }
        }
    }

    private func updateTimer() {
        stopTimer()
        guard viewModel.playbackState == .playing else { return }
        let interval = CinePlaybackHelpers.timerInterval(for: viewModel.playbackFPS)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            viewModel.advanceCineFrame()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
#endif
