//
// PrintSCPSimulator.swift
// DICOMPrintKit
//
// The composer dev loop: a film, composed exactly as the emulator would compose
// it, without a network in the way.
//
// The images go through the same `PrintImagePreparer` an SCU sends them through
// and the sheet comes out of the same `FilmComposer` the SCP composes with, so
// what this produces is what `dicom-print send` into `dicom-printscp serve`
// produces — minus the DIMSE round trip. That makes it useful for iterating on
// layout and density without standing up two processes, and it is the reason
// `dicom-printscp simulate` and any future in-app "preview a received film"
// share one implementation.
//

import Foundation
import DICOMCore
import DICOMNetwork

/// Composes films locally from DICOM files, bypassing the network.
public struct PrintSCPSimulator: Sendable {

    /// A diagnostic line emitted while preparing images.
    public typealias ProgressHandler = @Sendable (String) -> Void

    public init() {}

    /// Prepares `paths` and composes them into one or more film sheets.
    ///
    /// Films spill exactly as they do on the wire: images fill the layout's
    /// cells, and a new film box starts when the grid is full.
    ///
    /// - Parameters:
    ///   - paths: DICOM files, in the order they should be placed.
    ///   - request: The job whose layout, film size and pixel options apply —
    ///     the SCU-side request type, so a simulated film and a printed film are
    ///     described by the same values.
    ///   - settings: The emulator settings that drive composition.
    ///   - callingAETitle: The AE title recorded on the composed films.
    ///   - onProgress: Optional per-image diagnostic line.
    /// - Throws: `PrintRequestError` for unreadable or undecodable inputs, and
    ///   `FilmCompositionError` when a sheet cannot be rasterized.
    public func composeFilms(
        paths: [String],
        request: PrintJobRequest,
        settings: PrintSCPSettings,
        callingAETitle: String = "SIMULATE",
        onProgress: ProgressHandler? = nil
    ) async throws -> [ComposedFilm] {
        let images = try await PrintImagePreparer().prepare(
            paths: paths, request: request, onProgress: onProgress)
        return try composeFilms(
            images: images,
            request: request,
            settings: settings,
            callingAETitle: callingAETitle)
    }

    /// Composes already-prepared images, for callers that hold pixels rather
    /// than paths (the app's viewer selection).
    public func composeFilms(
        images: [PreparedPrintImage],
        request: PrintJobRequest,
        settings: PrintSCPSettings,
        callingAETitle: String = "SIMULATE"
    ) throws -> [ComposedFilm] {
        guard !images.isEmpty else { return [] }

        let plan = request.plan(forImageCount: images.count)
        let composer = FilmComposer(configuration: settings.makeComposerConfiguration())
        let sessionUID = UIDGenerator.generateSOPInstanceUID().value
        let session = FilmSession(
            sopInstanceUID: sessionUID,
            numberOfCopies: request.copies,
            printPriority: request.priority,
            mediumType: request.mediumType,
            filmDestination: request.filmDestination,
            filmSessionLabel: request.sessionLabel)
        let layout = PrintLayout(rows: plan.layout.rows, columns: plan.layout.columns)
        let sopClassUID = request.colorMode == .color
            ? basicColorImageBoxSOPClassUID
            : basicGrayscaleImageBoxSOPClassUID

        var films: [ComposedFilm] = []
        for filmIndex in 0..<plan.filmCount {
            let indices = plan.imageIndices(onFilm: filmIndex)
            let boxes = (0..<plan.cellsPerFilm).map { cell -> ReceivedImageBox in
                let imageIndex = indices.lowerBound + cell
                return ReceivedImageBox(
                    sopInstanceUID: UIDGenerator.generateSOPInstanceUID().value,
                    sopClassUID: sopClassUID,
                    content: ImageBoxContent(
                        imagePosition: UInt16(cell + 1),
                        polarity: request.polarity),
                    image: imageIndex < indices.upperBound ? images[imageIndex].descriptor : nil)
            }

            let filmBox = FilmBox(
                sopInstanceUID: UIDGenerator.generateSOPInstanceUID().value,
                imageDisplayFormat: layout.imageDisplayFormat,
                filmOrientation: plan.filmOrientation,
                filmSizeID: plan.filmSize,
                magnificationType: request.magnificationType,
                borderDensity: request.borderDensity,
                emptyImageDensity: request.emptyImageDensity,
                trimOption: request.trimOption,
                configurationInformation: request.configurationInformation,
                imageBoxSOPInstanceUIDs: boxes.map(\.sopInstanceUID))

            let received = ReceivedFilm(
                printJobUID: UIDGenerator.generateSOPInstanceUID().value,
                filmSession: session,
                filmBox: filmBox,
                layout: layout,
                imageBoxes: boxes,
                presentationLUTShape: request.presentationLUTShape,
                annotationDisplayFormatID: request.annotationDisplayFormatID,
                // Per film: a job spilling onto a second sheet can be a second
                // study, and each sheet has to name the patient it carries.
                annotations: request.printOptions.annotations(forFilm: filmIndex),
                callingAETitle: callingAETitle)

            films.append(try composer.compose(received))
        }
        return films
    }
}
