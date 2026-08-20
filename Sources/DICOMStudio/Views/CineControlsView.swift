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
                // First frame
                Button {
                    viewModel.goToFrame(0)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .accessibilityLabel("First frame")
                .help("Go to first frame (Home)")
                .disabled(viewModel.playbackState == .playing)
                .keyboardShortcut(.home, modifiers: [])

                // Step backward
                Button {
                    viewModel.previousFrame()
                } label: {
                    Image(systemName: "backward.frame.fill")
                }
                .accessibilityLabel("Previous frame")
                .help("Previous frame (←)")
                .disabled(viewModel.playbackState == .playing)
                .keyboardShortcut(.leftArrow, modifiers: [])

                // Play/Pause
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: CinePlaybackHelpers.stateSystemImage(for: viewModel.playbackState))
                }
                .accessibilityLabel(viewModel.playbackState == .playing ? "Pause" : "Play")
                .help("Play/Pause (Space)")
                .keyboardShortcut(" ", modifiers: [])

                // Stop
                Button {
                    viewModel.stopPlayback()
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
                .help("Next frame (→)")
                .disabled(viewModel.playbackState == .playing)
                .keyboardShortcut(.rightArrow, modifiers: [])

                // Last frame
                Button {
                    viewModel.goToFrame(viewModel.numberOfFrames - 1)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .accessibilityLabel("Last frame")
                .help("Go to last frame (End)")
                .disabled(viewModel.playbackState == .playing)
                .keyboardShortcut(.end, modifiers: [])

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
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Playback mode")

                Divider()
                    .frame(height: 16)

                // FPS control
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("FPS:")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Slider(
                            value: Bindable(viewModel).playbackFPS,
                            in: CinePlaybackHelpers.minFPS...CinePlaybackHelpers.maxFPS,
                            step: 1
                        )
                        .frame(width: 80)
                        .accessibilityLabel("Playback speed")
                        TextField("FPS", value: Bindable(viewModel).playbackFPS, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                            .accessibilityLabel("Frames per second")
                    }
                    Text(String(format: "%.1fs", Double(viewModel.numberOfFrames) / viewModel.playbackFPS))
                        .font(.system(size: StudioTypography.captionSize).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // The timer follows the view model's state rather than the buttons that
        // used to own it. Playback can now start without a click — a multi-frame
        // file opens running — and that start has to drive the timer too.
        .onChange(of: viewModel.playbackState) { _, newValue in
            newValue == .playing ? updateTimer() : stopTimer()
        }
        // A file that opens already playing sets its state before this view
        // exists, so there is no change for `onChange` to see.
        .onAppear { if viewModel.playbackState == .playing { updateTimer() } }
        // Re-arms the running timer at the new interval. Watched on the value
        // rather than on the slider and the field, because the rate also
        // changes when a file that states its own frame rate is opened.
        .onChange(of: viewModel.playbackFPS) { _, _ in
            if viewModel.playbackState == .playing { updateTimer() }
        }
        .onDisappear { stopTimer() }
    }

    private func updateTimer() {
        stopTimer()
        guard viewModel.playbackState == .playing else { return }
        let interval = CinePlaybackHelpers.timerInterval(for: viewModel.playbackFPS)
        let viewModel = viewModel
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // Scheduled from the main actor, so the timer fires on the main run loop.
            MainActor.assumeIsolated {
                viewModel.advanceCineFrame()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
#endif
