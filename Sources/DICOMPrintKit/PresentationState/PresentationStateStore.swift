// PresentationStateStore.swift
// DICOMPrintKit
//
// Where saved views live, and how a viewer finds the ones belonging to an image.
//
// The arrangement is one shared presentation-state series per study, holding one
// object per image per saved view. A study that has been read three ways at
// three windows carries one extra series and three objects per image:
//
//   Study 1.2.3
//   └── Series (PR)  ← one, for the life of the study
//       ├── GSPS → image 42, "Lung window"
//       ├── GSPS → image 42, "Bone window"
//       └── GSPS → image 45, "Lung window"
//
// What ties several objects into one *saved view* is therefore the label, not
// the series: a save that spans five images writes five objects carrying the
// same label. That is the trade this arrangement makes — the container stays a
// single series, and grouping rests on a string the user typed. `SavedView`
// exists so the rest of the app never has to do that grouping by hand.
//
// Objects are written as conformant GSPS files even though they stay inside the
// app. The cost is the same either way, and it means exporting a study later is
// a matter of copying files rather than converting them.

import Foundation
import DICOMCore
import DICOMKit

/// One saved view: every presentation state written under a single label.
public struct SavedView: Sendable, Equatable, Identifiable {

    /// Stable across launches — the label is what the user named the view, and
    /// what groups its objects.
    public var id: String { label }

    /// What the reader called it. Shown in the picker.
    public let label: String

    /// When the view was saved.
    public let created: Date?

    /// The presentation states making up this view, one per image.
    public let states: [StoredPresentationState]

    public init(label: String, created: Date?, states: [StoredPresentationState]) {
        self.label = label
        self.created = created
        self.states = states
    }

    /// The state covering a given image, if this view has one.
    ///
    /// A view saved over three images has nothing to say about a fourth; the
    /// caller shows the default view for it.
    public func state(forImage sopInstanceUID: String) -> StoredPresentationState? {
        states.first { $0.referencedImageUIDs.contains(sopInstanceUID) }
    }

    /// Whether this view says anything about a given image.
    public func covers(image sopInstanceUID: String) -> Bool {
        state(forImage: sopInstanceUID) != nil
    }
}

/// A presentation state as it sits on disk, with the file it came from.
public struct StoredPresentationState: Sendable, Equatable {

    /// The parsed state.
    public let state: GrayscalePresentationState

    /// Where it lives, so it can be deleted or rewritten.
    public let url: URL

    /// The text and arrows the reader drew on this image.
    ///
    /// Read from the sidecar beside the object rather than from the object
    /// itself — see ``AnnotationSidecar`` for why they are not written as a
    /// Graphic Annotation Sequence. Empty for the ordinary saved view, which
    /// records a window and a zoom and nothing drawn.
    public let annotations: [PrintOverlayAnnotation]

    /// The reader's own wording, kept unfolded.
    ///
    /// Presentation Label is CS-valued and was uppercased on the way out, so the
    /// name shown in the picker comes from Content Description instead.
    private let displayLabel: String?

    public init(
        state: GrayscalePresentationState,
        url: URL,
        displayLabel: String? = nil,
        annotations: [PrintOverlayAnnotation] = []
    ) {
        self.state = state
        self.url = url
        self.displayLabel = displayLabel
        self.annotations = annotations
    }

    /// Every image this state applies to.
    public var referencedImageUIDs: [String] {
        state.referencedSeries.flatMap { $0.referencedImages.map(\.sopInstanceUID) }
    }

    /// The label the reader gave the view, falling back to the coded one.
    public var label: String {
        displayLabel ?? state.presentationLabel ?? "Saved view"
    }

    /// Compared by identity: a presentation state is a SOP Instance, so two
    /// values are the same state exactly when they carry the same UID and came
    /// from the same file. (`GrayscalePresentationState` is not `Equatable` —
    /// `DisplayedArea` holds tuples, which blocks synthesis.)
    public static func == (
        lhs: StoredPresentationState, rhs: StoredPresentationState
    ) -> Bool {
        lhs.url == rhs.url && lhs.state.sopInstanceUID == rhs.state.sopInstanceUID
    }
}

/// Reads and writes saved views for a study.
///
/// Storage is per study, under the app's own directory: one folder per Study
/// Instance UID, one file per presentation state.
public struct PresentationStateStore: Sendable {

    /// Root directory holding one subdirectory per study.
    public let root: URL

    /// `FileManager.default` is reached through a computed property rather than
    /// stored: it is not `Sendable`, and the store is.
    private var fileManager: FileManager { .default }

    /// - Parameter root: Where to keep saved views. Callers normally pass the
    ///   app-support directory; tests pass a temporary one.
    public init(root: URL) {
        self.root = root
    }

    /// The default location: `~/Library/Application Support/DICOMStudio/PresentationStates`.
    public static func applicationSupport() throws -> PresentationStateStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return PresentationStateStore(
            root: base
                .appendingPathComponent("DICOMStudio", isDirectory: true)
                .appendingPathComponent("PresentationStates", isDirectory: true))
    }

    // MARK: - Layout

    /// The directory holding one study's saved views.
    public func directory(forStudy studyInstanceUID: String) -> URL {
        // The UID is used as a path component directly: DICOM UIDs are digits
        // and dots by definition (PS3.5 9.1), so there is nothing to escape.
        root.appendingPathComponent(studyInstanceUID, isDirectory: true)
    }

    // MARK: - Saving

    /// What a save needs to know about one image.
    public struct ImageToSave: Sendable, Equatable {

        /// SOP Class and Instance UID of the image being described.
        public let sopClassUID: String
        public let sopInstanceUID: String

        /// The series that image belongs to.
        public let seriesInstanceUID: String

        /// The view to record for it.
        public let display: ViewerPresentationStateBridge.CapturedDisplay

        /// What the reader drew on it, if anything.
        ///
        /// Defaulted so every existing caller that saves a window and a zoom
        /// keeps compiling and keeps writing no sidecar.
        public let annotations: [PrintOverlayAnnotation]

        public init(
            sopClassUID: String,
            sopInstanceUID: String,
            seriesInstanceUID: String,
            display: ViewerPresentationStateBridge.CapturedDisplay,
            annotations: [PrintOverlayAnnotation] = []
        ) {
            self.sopClassUID = sopClassUID
            self.sopInstanceUID = sopInstanceUID
            self.seriesInstanceUID = seriesInstanceUID
            self.display = display
            self.annotations = annotations
        }
    }

    /// Writes one saved view: one presentation state per image, all under the
    /// same label and the same study-wide series.
    ///
    /// Saving under a label that already exists replaces it, so a reader who
    /// adjusts a view and saves it again gets one entry in the picker rather
    /// than two.
    ///
    /// - Parameters:
    ///   - images: The images the reader had adjusted. An empty array writes
    ///     nothing.
    ///   - label: What to call the view.
    ///   - patient: Study and patient attributes, read from a source image.
    ///   - creator: Who saved it, if known.
    ///   - created: When — passed in rather than read from the clock so the
    ///     caller stays testable.
    /// - Returns: The saved view, or nil if there was nothing to save.
    @discardableResult
    public func save(
        images: [ImageToSave],
        label: String,
        patient: PresentationStatePatientContext,
        creator: DICOMPersonName? = nil,
        created: Date = Date()
    ) throws -> SavedView? {
        guard !images.isEmpty else { return nil }

        let directory = directory(forStudy: patient.studyInstanceUID)
        try fileManager.createDirectory(
            at: directory, withIntermediateDirectories: true)

        // The series UID has to be read *before* the replace below, or replacing
        // the only saved view of a study would take its series identity with it.
        let seriesInstanceUID = seriesUID(forStudy: patient.studyInstanceUID)

        // Replacing rather than appending: a second save under the same name is
        // the reader correcting the view, not adding another.
        try deleteView(label: label, studyInstanceUID: patient.studyInstanceUID)

        let builder = GrayscalePresentationStateBuilder()

        var context = patient
        context.seriesDescription = Self.seriesDescription

        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: created)
        let creationDate = DICOMDate(
            year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
        let creationTime = DICOMTime(
            hour: parts.hour ?? 0, minute: parts.minute ?? 0, second: parts.second ?? 0)

        var stored: [StoredPresentationState] = []

        for (index, image) in images.enumerated() {
            let sopInstanceUID = UIDGenerator.generateSOPInstanceUID().value

            let state = GrayscalePresentationState(
                sopInstanceUID: sopInstanceUID,
                instanceNumber: index + 1,
                presentationLabel: label,
                presentationCreationDate: creationDate,
                presentationCreationTime: creationTime,
                presentationCreatorsName: creator,
                referencedSeries: [
                    ReferencedSeries(
                        seriesInstanceUID: image.seriesInstanceUID,
                        referencedImages: [
                            ReferencedImage(
                                sopClassUID: image.sopClassUID,
                                sopInstanceUID: image.sopInstanceUID)
                        ])
                ],
                voiLUT: image.display.voiLUT,
                presentationLUT: image.display.presentationLUT,
                spatialTransformation: image.display.spatialTransformation,
                displayedArea: image.display.displayedArea)

            let dataSet = builder.buildDataSet(
                from: state,
                patient: context,
                seriesInstanceUID: seriesInstanceUID,
                seriesNumber: Self.presentationSeriesNumber)

            let url = directory.appendingPathComponent("\(sopInstanceUID).dcm")
            let file = DICOMFile.create(
                dataSet: dataSet,
                sopClassUID: GrayscalePresentationStateBuilder.sopClassUID,
                sopInstanceUID: sopInstanceUID,
                transferSyntaxUID: Self.transferSyntaxUID)
            try file.write().write(to: url, options: [.atomic])

            // Written after the object, and non-fatally: a saved view that keeps
            // its window and loses its arrows is a poor outcome, but losing the
            // whole view because a sidecar could not be written is a worse one.
            let drawn = image.annotations.filter { !$0.isBlank }
            try? AnnotationSidecar.write(drawn, forStateAt: url)

            stored.append(StoredPresentationState(
                state: state, url: url, annotations: drawn))
        }

        return SavedView(label: label, created: created, states: stored)
    }

    // MARK: - Loading

    /// Every saved view for a study, newest first.
    ///
    /// Unreadable files are skipped rather than thrown on: one corrupt object
    /// must not cost the reader the rest of their saved views.
    public func views(forStudy studyInstanceUID: String) -> [SavedView] {
        let directory = directory(forStudy: studyInstanceUID)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }

        let parser = GrayscalePresentationStateParser()
        var stored: [StoredPresentationState] = []

        for url in urls where url.pathExtension.lowercased() == "dcm" {
            guard let file = try? DICOMFile.read(from: url),
                  let state = try? parser.parse(dataSet: file.dataSet) else { continue }
            // Presentation Label (0070,0080) is CS-valued, so what the reader
            // typed was folded to uppercase when it was written. The unfolded
            // name lives in Content Description (0070,0081) — read it back, or
            // "Lung window" returns as "LUNG WINDOW" and no longer matches the
            // label a delete or a re-save is looking for.
            let displayLabel = file.dataSet.string(for: .presentationDescription)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            stored.append(StoredPresentationState(
                state: state,
                url: url,
                displayLabel: (displayLabel?.isEmpty == false) ? displayLabel : nil,
                annotations: AnnotationSidecar.read(forStateAt: url)))
        }

        // Grouping by label is what makes several objects one saved view. This
        // is the cost of a single shared series: the label carries the grouping.
        let grouped = Dictionary(grouping: stored) { $0.label }

        return grouped
            .map { label, states in
                SavedView(
                    label: label,
                    created: states.compactMap(Self.creationDate).max(),
                    states: states.sorted {
                        ($0.state.instanceNumber ?? 0) < ($1.state.instanceNumber ?? 0)
                    })
            }
            .sorted { lhs, rhs in
                // Newest first, with ties broken by name so the order is stable.
                switch (lhs.created, rhs.created) {
                case let (left?, right?) where left != right:
                    return left > right
                default:
                    return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
                }
            }
    }

    /// The saved views that say something about one image.
    ///
    /// This is what the viewer's picker lists: a view saved over other images
    /// has nothing to offer this one and is left out.
    public func views(
        forStudy studyInstanceUID: String, image sopInstanceUID: String
    ) -> [SavedView] {
        views(forStudy: studyInstanceUID).filter { $0.covers(image: sopInstanceUID) }
    }

    // MARK: - Deleting

    /// Removes one saved view, by label.
    public func deleteView(label: String, studyInstanceUID: String) throws {
        for view in views(forStudy: studyInstanceUID) where view.label == label {
            for state in view.states {
                try? fileManager.removeItem(at: state.url)
                // The sidecar goes with the object. Leaving one behind would
                // outlive its `.dcm` and be picked up by the next save that
                // happened to draw the same SOP Instance UID.
                AnnotationSidecar.delete(forStateAt: state.url)
            }
        }
    }

    /// Removes every saved view for a study.
    public func deleteAll(forStudy studyInstanceUID: String) throws {
        let directory = directory(forStudy: studyInstanceUID)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    // MARK: - Series identity

    /// The Series Instance UID this study's presentation states share.
    ///
    /// Recovered from the objects already on disk, so there is no side file to
    /// keep in step; a study with nothing saved yet gets a fresh one. This is
    /// what makes "one shared series per study" true however many views the
    /// reader accumulates.
    private func seriesUID(forStudy studyInstanceUID: String) -> String {
        let directory = directory(forStudy: studyInstanceUID)
        if let urls = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) {
            for url in urls where url.pathExtension.lowercased() == "dcm" {
                if let file = try? DICOMFile.read(from: url),
                   let uid = file.dataSet.string(for: .seriesInstanceUID),
                   !uid.isEmpty {
                    return uid
                }
            }
        }
        return UIDGenerator.generateSeriesInstanceUID().value
    }

    private static func creationDate(_ stored: StoredPresentationState) -> Date? {
        guard let date = stored.state.presentationCreationDate else { return nil }
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        if let time = stored.state.presentationCreationTime {
            components.hour = time.hour
            components.minute = time.minute
            components.second = time.second
        }
        return Calendar(identifier: .gregorian).date(from: components)
    }

    // MARK: - Constants

    /// Series Number of the presentation-state series. High enough not to
    /// collide with a modality's own numbering.
    static let presentationSeriesNumber = 9001

    static let seriesDescription = "Presentation States"

    /// Explicit VR Little Endian — what a GSPS is normally stored as, and what
    /// keeps the files readable by anything else.
    static let transferSyntaxUID = "1.2.840.10008.1.2.1"
}
