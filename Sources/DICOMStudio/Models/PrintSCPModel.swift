// PrintSCPModel.swift
// DICOMStudio
//
// DICOM Studio — the Print SCP screen's own state: the films it retains and the
// icons its log rows draw.
//
// Everything the emulator *is* comes from DICOMPrintKit: `PrintSCPSettings` (the
// knobs), `PrintSCPService` (the assembly), `PrintSCPConsole` (the wording) and
// `FilmComposer` (the sheet), all shared with `dicom-printscp`. What stays here
// is the part only a window has — a retained film with a thumbnail, and an SF
// Symbol per severity.

import Foundation
import DICOMCore
import DICOMNetwork
import DICOMPrintKit

// MARK: - Log presentation

extension PrintSCPLogLevel {
    /// SF Symbol for the log row's leading icon.
    public var sfSymbol: String {
        switch self {
        case .info:         return "info.circle"
        case .connection:   return "link"
        case .filmReceived: return "doc.richtext"
        case .warning:      return "exclamationmark.triangle"
        case .error:        return "xmark.octagon"
        }
    }
}

// MARK: - Received film

/// A film the emulator received, composed and retained for review.
public struct ReceivedFilmRecord: Identifiable, Sendable {
    public let id: UUID

    /// The composed sheet at full rasterization resolution — what "Save…"
    /// writes and what the preview enlarges.
    public let film: ComposedFilm

    /// A small copy for the film list, so scrolling never rescales a 21 MP sheet.
    public let thumbnail: ComposedFilm

    /// Files this film has been exported to from the screen, in write order.
    ///
    /// Auto-saved copies are not listed here: the output sinks report a path
    /// without saying which film it came from, and the film may not have
    /// reached the list yet. Those land in the event log instead.
    public var savedFiles: [URL]

    public init(
        id: UUID = UUID(),
        film: ComposedFilm,
        thumbnail: ComposedFilm,
        savedFiles: [URL] = []
    ) {
        self.id = id
        self.film = film
        self.thumbnail = thumbnail
        self.savedFiles = savedFiles
    }

    /// Bytes the retained bitmaps occupy.
    public var byteCount: Int { film.pixels.count + thumbnail.pixels.count }

    /// One-line summary for the list row.
    public var summary: String { film.info.summary }

    /// When the film was received.
    public var receivedAt: Date { film.info.receivedAt }

    /// A default file name (without extension) for the save panel.
    public var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "film-\(formatter.string(from: receivedAt))"
    }
}
