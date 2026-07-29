// ImageViewerViewModel+ImageNavigation.swift
// DICOMStudio
//
// DICOM Studio — moving to the next/previous *image* in the viewer.
//
// "Image" here is what the user sees on screen, which is not always a file: a
// multi-frame file holds many images. Arrow-key navigation therefore walks
// frames first and rolls onto the neighbouring file when it runs out, so a
// series of single-frame files and a cine loop both traverse continuously.

import Foundation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
extension ImageViewerViewModel {

    // MARK: - Availability

    /// Whether there is another image after the one on screen.
    public var canGoNextImage: Bool {
        currentFrameIndex < numberOfFrames - 1 || canGoNextFile
    }

    /// Whether there is another image before the one on screen.
    public var canGoPreviousImage: Bool {
        currentFrameIndex > 0 || canGoPreviousFile
    }

    // MARK: - Stepping

    /// Advances one image: the next frame of this file, or the next file.
    ///
    /// Unlike ``nextFrame()`` this does not wrap at the end of a multi-frame
    /// file — it steps into the next file instead, and stops at the end of the
    /// series. Wrapping is cine behaviour; arrow keys are for traversal.
    @discardableResult
    public func navigateToNextImage() -> Bool {
        guard canGoNextImage else { return false }
        stopPlaybackForManualStep()
        if currentFrameIndex < numberOfFrames - 1 {
            goToFrame(currentFrameIndex + 1)
        } else {
            navigateToNextFile()
        }
        return true
    }

    /// Goes back one image: the previous frame of this file, or the previous file.
    ///
    /// Stepping back into a previous file lands on its first frame rather than
    /// its last: the file is loaded asynchronously and its frame count is not
    /// known until then, so seeking to the end here would race the load.
    @discardableResult
    public func navigateToPreviousImage() -> Bool {
        guard canGoPreviousImage else { return false }
        stopPlaybackForManualStep()
        if currentFrameIndex > 0 {
            goToFrame(currentFrameIndex - 1)
        } else {
            navigateToPreviousFile()
        }
        return true
    }

    // MARK: - Helpers

    /// Pauses cine playback when the user steps by hand, so the timer does not
    /// immediately move the image out from under them.
    ///
    /// Pauses rather than stops: ``stopPlayback()`` rewinds to frame 0, which
    /// would throw away the position the user is stepping through.
    private func stopPlaybackForManualStep() {
        if playbackState == .playing {
            playbackState = .paused
        }
    }
}
