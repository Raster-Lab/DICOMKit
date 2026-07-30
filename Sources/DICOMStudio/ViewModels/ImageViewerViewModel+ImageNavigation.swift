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
    /// Unlike ``nextFrame()`` this does not wrap *within* a multi-frame file —
    /// it steps into the next file instead. At the end of the series it wraps
    /// round to the first image when ``isRepeatNavigationEnabled`` is on, which
    /// is what makes scrolling a tile loop rather than stick.
    @discardableResult
    public func navigateToNextImage() -> Bool {
        guard canGoNextImage else { return isRepeatNavigationEnabled ? wrapToFirstImage() : false }
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
        guard canGoPreviousImage else {
            return isRepeatNavigationEnabled ? wrapToLastImage() : false
        }
        stopPlaybackForManualStep()
        if currentFrameIndex > 0 {
            goToFrame(currentFrameIndex - 1)
        } else {
            navigateToPreviousFile()
        }
        return true
    }

    // MARK: - Wrapping

    /// Jumps to the first image of the series (or of this file, if standalone).
    @discardableResult
    private func wrapToFirstImage() -> Bool {
        stopPlaybackForManualStep()
        if seriesFiles.count > 1, currentFileIndex != 0 {
            currentFileIndex = 0
            loadFileInternal(at: seriesFiles[0], securityScopedParent: seriesSecurityScopedParent)
            return true
        }
        guard currentFrameIndex != 0 else { return false }
        goToFrame(0)
        return true
    }

    /// Jumps to the last image of the series.
    ///
    /// Lands on the last file's first frame for the same reason stepping back
    /// does: the frame count is not known until the file has loaded.
    @discardableResult
    private func wrapToLastImage() -> Bool {
        stopPlaybackForManualStep()
        if seriesFiles.count > 1, currentFileIndex != seriesFiles.count - 1 {
            currentFileIndex = seriesFiles.count - 1
            loadFileInternal(at: seriesFiles[currentFileIndex],
                             securityScopedParent: seriesSecurityScopedParent)
            return true
        }
        guard numberOfFrames > 1, currentFrameIndex != numberOfFrames - 1 else { return false }
        goToFrame(numberOfFrames - 1)
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
