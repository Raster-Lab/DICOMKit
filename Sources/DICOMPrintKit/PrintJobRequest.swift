// PrintJobRequest.swift
// DICOMPrintKit
//
// One value type describing a complete DICOM print job, shared by the
// dicom-print CLI and DICOMStudio so both surfaces expose the same knobs
// with the same defaults and the same validation messages.

import Foundation
import DICOMKit
import DICOMNetwork

// MARK: - Errors

/// A print request that cannot be executed as specified.
///
/// The CLI re-throws these as `ValidationError` with the message unchanged, so
/// the wording here **is** the CLI's user-visible contract.
public struct PrintRequestError: Error, CustomStringConvertible, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
    public var localizedDescription: String { message }
}

// MARK: - Frame Selection

/// Which frame(s) of a multi-frame source become image boxes.
public enum PrintFrameSelection: Sendable, Equatable {
    /// A single 1-based frame number.
    case single(Int)
    /// Every frame of the file, one image box per frame.
    case all

    /// The default: the first frame.
    public static let first = PrintFrameSelection.single(1)
}

// MARK: - Layout Selection

/// How the film layout (rows × columns) is chosen.
public enum PrintLayoutSelection: Sendable, Equatable {
    /// Let the print service pick an optimal grid for the image count.
    case automatic
    /// An explicit rows × columns grid.
    case explicit(PrintLayoutOption)
    /// A preset that also fixes film size and orientation.
    case template(PrintTemplatePreset)
    /// Any rows × columns grid, for layouts ``PrintLayoutOption`` does not name.
    ///
    /// The viewer offers every grid from 1×1 to 4×4 so the film can mirror what
    /// is on screen; most of those have no catalogue entry.
    case custom(PrintLayout)

    /// The resolved layout, or `nil` for `.automatic` (the service decides).
    public var layout: PrintLayout? {
        switch self {
        case .automatic:            return nil
        case .explicit(let option): return option.layout
        case .template(let preset): return preset.layout
        case .custom(let layout):   return layout
        }
    }
}

// MARK: - Print Job Request

/// A complete, validated description of a print job.
///
/// Holds every option the `dicom-print send` command exposes. Construct it,
/// call ``validate()``, then feed it to ``PrintImagePreparer`` (for the pixel
/// side) and ``PrintWorkflow`` (for the DIMSE side).
public struct PrintJobRequest: Sendable {

    // MARK: Film session

    /// Number of copies of each film.
    public var copies: Int
    /// Print priority (LOW / MED / HIGH).
    public var priority: PrintPriority
    /// Medium the printer should use.
    public var mediumType: MediumType
    /// Where finished film is delivered.
    public var filmDestination: FilmDestination
    /// Optional Film Session Label (2000,0050).
    public var sessionLabel: String?

    // MARK: Film box

    /// Layout selection (auto, explicit grid, or preset).
    public var layoutSelection: PrintLayoutSelection
    /// Film size — overridden by a `.template` layout selection.
    public var filmSize: FilmSize
    /// Film orientation — overridden by a `.template` layout selection.
    public var filmOrientation: FilmOrientation
    /// Interpolation the printer applies when scaling images to cells.
    public var magnificationType: MagnificationType
    /// Border density between cells ("BLACK", "WHITE", or a density value).
    public var borderDensity: String
    /// Density of unfilled cells.
    public var emptyImageDensity: String
    /// Whether the printer draws a trim box around each cell.
    public var trimOption: TrimOption
    /// Printer-specific Configuration Information (2010,0150).
    public var configurationInformation: String?

    // MARK: Image box

    /// Image polarity (NORMAL / REVERSE).
    public var polarity: ImagePolarity
    /// Presentation LUT shape to create and reference, if any.
    public var presentationLUTShape: PresentationLUTShape?
    /// Film annotations. Only sent when ``annotationDisplayFormatID`` is set.
    public var annotations: [DICOMNetwork.PrintAnnotation]
    /// Printer-configured Annotation Display Format ID (2010,0030).
    public var annotationDisplayFormatID: String?

    // MARK: Pixel preparation

    /// Grayscale or color print management.
    public var colorMode: DICOMNetwork.PrintColorMode
    /// Which frames of multi-frame sources to print.
    public var frameSelection: PrintFrameSelection
    /// Send stored pixel values with no rescale / window / inversion applied.
    public var raw: Bool
    /// Explicit VOI window overriding the data set's own window.
    public var windowSettings: WindowSettings?
    /// Grayscale output bit depth: 8, 12, or 16.
    public var bitDepth: Int

    // MARK: Execution

    /// C-ECHO the printer AE before printing.
    public var verifyFirst: Bool
    /// N-GET printer status before printing; abort on FAILURE, warn on WARNING.
    public var checkStatus: Bool
    /// Retry count for connection/setup failures (0 = no retry).
    public var retries: Int
    /// Report what would be printed without contacting the printer.
    public var dryRun: Bool

    public init(
        copies: Int = 1,
        priority: PrintPriority = .medium,
        mediumType: MediumType = .paper,
        filmDestination: FilmDestination = .processor,
        sessionLabel: String? = nil,
        layoutSelection: PrintLayoutSelection = .automatic,
        filmSize: FilmSize = .size14InX17In,
        filmOrientation: FilmOrientation = .portrait,
        magnificationType: MagnificationType = .replicate,
        borderDensity: String = "BLACK",
        emptyImageDensity: String = "BLACK",
        trimOption: TrimOption = .no,
        configurationInformation: String? = nil,
        polarity: ImagePolarity = .normal,
        presentationLUTShape: PresentationLUTShape? = nil,
        annotations: [DICOMNetwork.PrintAnnotation] = [],
        annotationDisplayFormatID: String? = nil,
        colorMode: DICOMNetwork.PrintColorMode = .grayscale,
        frameSelection: PrintFrameSelection = .first,
        raw: Bool = false,
        windowSettings: WindowSettings? = nil,
        bitDepth: Int = 8,
        verifyFirst: Bool = false,
        checkStatus: Bool = false,
        retries: Int = 0,
        dryRun: Bool = false
    ) {
        self.copies = copies
        self.priority = priority
        self.mediumType = mediumType
        self.filmDestination = filmDestination
        self.sessionLabel = sessionLabel
        self.layoutSelection = layoutSelection
        self.filmSize = filmSize
        self.filmOrientation = filmOrientation
        self.magnificationType = magnificationType
        self.borderDensity = borderDensity
        self.emptyImageDensity = emptyImageDensity
        self.trimOption = trimOption
        self.configurationInformation = configurationInformation
        self.polarity = polarity
        self.presentationLUTShape = presentationLUTShape
        self.annotations = annotations
        self.annotationDisplayFormatID = annotationDisplayFormatID
        self.colorMode = colorMode
        self.frameSelection = frameSelection
        self.raw = raw
        self.windowSettings = windowSettings
        self.bitDepth = bitDepth
        self.verifyFirst = verifyFirst
        self.checkStatus = checkStatus
        self.retries = retries
        self.dryRun = dryRun
    }

    // MARK: Derived values

    /// The film size actually used (a template preset overrides the field).
    public var effectiveFilmSize: FilmSize {
        if case .template(let preset) = layoutSelection { return preset.filmSize }
        return filmSize
    }

    /// The orientation actually used (a template preset overrides the field).
    public var effectiveFilmOrientation: FilmOrientation {
        if case .template(let preset) = layoutSelection { return preset.filmOrientation }
        return filmOrientation
    }

    /// The resolved layout, or `nil` when the service should choose one.
    public var resolvedLayout: PrintLayout? { layoutSelection.layout }

    /// The DICOMKit-side color mode used by `ImagePreprocessor`.
    ///
    /// A distinct type from `DICOMNetwork.PrintColorMode`, mapped here so call
    /// sites never have to disambiguate.
    public var preprocessColorMode: DICOMKit.PrintColorMode {
        switch colorMode {
        case .grayscale: return .grayscale
        case .color:     return .color
        }
    }

    /// The `PrintOptions` this request maps to for the Print SCU.
    public var printOptions: PrintOptions {
        PrintOptions(
            numberOfCopies: copies,
            priority: priority,
            filmSize: effectiveFilmSize,
            filmOrientation: effectiveFilmOrientation,
            mediumType: mediumType,
            filmDestination: filmDestination,
            borderDensity: borderDensity,
            emptyImageDensity: emptyImageDensity,
            magnificationType: magnificationType,
            polarity: polarity,
            trimOption: trimOption,
            sessionLabel: sessionLabel,
            presentationLUTShape: presentationLUTShape,
            annotations: annotations,
            annotationDisplayFormatID: annotationDisplayFormatID,
            configurationInformation: configurationInformation
        )
    }

    /// How many physical films `imageCount` images produce under this request.
    ///
    /// Mirrors the film-box chunking in `DICOMPrintService`: images spill onto
    /// additional films whenever they exceed the layout's cell count. With an
    /// automatic layout the service sizes the grid to the image count, so the
    /// answer is always one film.
    public func filmCount(forImageCount imageCount: Int) -> Int {
        guard imageCount > 0 else { return 0 }
        guard let layout = resolvedLayout else {
            return PrintPlan.automaticFilmCount(forImageCount: imageCount)
        }
        let cells = max(1, layout.rows * layout.columns)
        return max(1, (imageCount + cells - 1) / cells)
    }

    /// A film-by-film plan for `imageCount` images, for previews and dry runs.
    public func plan(forImageCount imageCount: Int) -> PrintPlan {
        PrintPlan(request: self, imageCount: imageCount)
    }

    // MARK: Validation

    /// Validates the request, throwing the first problem found.
    ///
    /// The messages match the `dicom-print send` validation text exactly.
    public func validate() throws {
        if retries < 0 {
            throw PrintRequestError("--retries must be zero or greater")
        }
        if case .single(let frame) = frameSelection, frame < 1 {
            throw PrintRequestError("--frame is 1-based and must be 1 or greater")
        }
        if let width = windowSettings?.width, width < 1 {
            throw PrintRequestError("--window-width must be 1 or greater")
        }
        guard [8, 12, 16].contains(bitDepth) else {
            throw PrintRequestError("--bit-depth must be 8, 12, or 16")
        }
        if raw && (windowSettings != nil || bitDepth != 8) {
            throw PrintRequestError(
                "--raw bypasses preprocessing; it cannot be combined with "
                + "--window-center/--window-width or --bit-depth")
        }
        if !annotations.isEmpty && annotationDisplayFormatID == nil {
            throw PrintRequestError(
                "--annotate requires --annotation-format "
                + "(the printer-configured Annotation Display Format ID)")
        }
        if copies < 1 {
            throw PrintRequestError("--copies must be 1 or greater")
        }
    }
}

// MARK: - Print Plan

/// The film-by-film breakdown of a job — what a preview or dry run reports.
public struct PrintPlan: Sendable, Equatable {
    /// Number of images to be placed.
    public let imageCount: Int
    /// Rows × columns actually used (resolved, never `nil`).
    public let layout: (rows: Int, columns: Int)
    /// Number of physical films.
    public let filmCount: Int
    /// Cells per film.
    public let cellsPerFilm: Int
    /// Copies of each film.
    public let copies: Int
    /// Film size in use.
    public let filmSize: FilmSize
    /// Orientation in use.
    public let filmOrientation: FilmOrientation

    /// Total sheets consumed: films × copies.
    public var totalSheets: Int { filmCount * copies }

    /// The 0-based image indices placed on `filmIndex`, in cell order.
    public func imageIndices(onFilm filmIndex: Int) -> Range<Int> {
        let start = min(filmIndex * cellsPerFilm, imageCount)
        let end = min(start + cellsPerFilm, imageCount)
        return start..<end
    }

    init(request: PrintJobRequest, imageCount: Int) {
        self.imageCount = imageCount
        let resolved = request.resolvedLayout ?? PrintPlan.automaticLayout(forImageCount: imageCount)
        self.layout = (resolved.rows, resolved.columns)
        self.cellsPerFilm = max(1, resolved.rows * resolved.columns)
        self.filmCount = imageCount > 0
            ? max(1, (imageCount + self.cellsPerFilm - 1) / self.cellsPerFilm)
            : 0
        self.copies = request.copies
        self.filmSize = request.effectiveFilmSize
        self.filmOrientation = request.effectiveFilmOrientation
    }

    public static func == (lhs: PrintPlan, rhs: PrintPlan) -> Bool {
        lhs.imageCount == rhs.imageCount
            && lhs.layout == rhs.layout
            && lhs.filmCount == rhs.filmCount
            && lhs.cellsPerFilm == rhs.cellsPerFilm
            && lhs.copies == rhs.copies
            && lhs.filmSize == rhs.filmSize
            && lhs.filmOrientation == rhs.filmOrientation
    }

    /// The grid `DICOMPrintService` picks when no layout is given.
    ///
    /// A single image is always 1×1; otherwise it is `PrintLayout.optimalLayout`.
    public static func automaticLayout(forImageCount imageCount: Int) -> PrintLayout {
        guard imageCount > 1 else { return PrintLayout(rows: 1, columns: 1) }
        return PrintLayout.optimalLayout(for: imageCount)
    }

    /// Film count under an automatic layout (25 cells is the largest auto grid).
    public static func automaticFilmCount(forImageCount imageCount: Int) -> Int {
        guard imageCount > 0 else { return 0 }
        let layout = automaticLayout(forImageCount: imageCount)
        let cells = max(1, layout.rows * layout.columns)
        return max(1, (imageCount + cells - 1) / cells)
    }
}
