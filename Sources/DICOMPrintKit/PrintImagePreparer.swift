// PrintImagePreparer.swift
// DICOMPrintKit
//
// Turns DICOM sources into the uncompressed, presentation-ready frames a Basic
// Grayscale/Color Image Box requires. Shared by the dicom-print CLI and
// DICOMStudio so both produce byte-identical film pixels from the same inputs.

import Foundation
import DICOMCore
import DICOMKit
import DICOMNetwork

// MARK: - Prepared Image

/// One frame ready to be sent as an image box: pixel bytes plus the mandatory
/// image-box attributes (PS3.3 C.13.5.1).
public struct PreparedPrintImage: Sendable {
    /// The pixel bytes to send.
    public var pixelData: Data { descriptor.pixelData }

    /// Rows/Columns/BitsAllocated/PhotometricInterpretation for the image box.
    public let descriptor: PrintImageData

    /// The source file path, when the frame came from a file on disk.
    public let sourcePath: String?

    /// 0-based frame index within the source.
    public let frameIndex: Int

    public init(descriptor: PrintImageData, sourcePath: String?, frameIndex: Int) {
        self.descriptor = descriptor
        self.sourcePath = sourcePath
        self.frameIndex = frameIndex
    }

    /// One-line summary, e.g. "512x512 MONOCHROME2 8-bit".
    public var summary: String {
        "\(descriptor.columns)x\(descriptor.rows) "
            + "\(descriptor.photometricInterpretation) \(descriptor.bitsStored)-bit"
    }
}

// MARK: - Preparer

/// Decodes and preprocesses DICOM sources into printable frames.
///
/// - Encapsulated sources (JPEG/J2K/JPEG-LS/RLE) are decoded to native frames
///   via `DICOMFile.tryPixelData()` — image boxes require uncompressed pixels
///   (PS3.3 C.13.5).
/// - The request's frame selection picks frames from multi-frame files; each
///   selected frame becomes one image box.
/// - Unless the request is `raw`, each frame runs through `ImagePreprocessor`
///   (rescale → VOI window → MONOCHROME1 inversion → 8-bit MONOCHROME2, or
///   8-bit RGB/grayscale for color sources) so the print matches clinical
///   presentation instead of raw stored values.
/// - The window is resolved the way the rest of the app resolves one: the
///   request's own window, else the data set's VOI, else the preprocessor's
///   auto-stretch (see ``resolvedWindow(_:dataSet:)``).
public struct PrintImagePreparer: Sendable {

    /// A progress/diagnostic line emitted while preparing (verbose output).
    public typealias ProgressHandler = @Sendable (String) -> Void

    private let preprocessor: ImagePreprocessor

    public init(preprocessor: ImagePreprocessor = ImagePreprocessor()) {
        self.preprocessor = preprocessor
    }

    /// Prepares every selected frame of every given file, in file order.
    ///
    /// - Parameters:
    ///   - paths: DICOM file paths, already gathered and ordered.
    ///   - request: The job whose frame selection and rendering options apply.
    ///   - onProgress: Optional per-frame diagnostic line.
    /// - Throws: ``PrintRequestError`` with the CLI's message text on unreadable
    ///   files, undecodable pixels, out-of-range frames, or oversized images.
    public func prepare(
        paths: [String],
        request: PrintJobRequest,
        onProgress: ProgressHandler? = nil
    ) async throws -> [PreparedPrintImage] {
        var prepared: [PreparedPrintImage] = []

        for path in paths {
            guard let data = FileManager.default.contents(atPath: path) else {
                throw PrintRequestError("Cannot read file: \(path)")
            }

            let file = try DICOMFile.read(from: data, force: true)
            let pixelData: PixelData
            do {
                pixelData = try file.tryPixelData()
            } catch {
                throw PrintRequestError(
                    "Cannot extract printable pixel data from \(path): \(error)")
            }

            let frames = try await prepare(
                pixelData: pixelData,
                dataSet: file.dataSet,
                request: request,
                sourcePath: path,
                onProgress: onProgress
            )
            prepared.append(contentsOf: frames)
        }

        return prepared
    }

    /// Prepares the selected frames of one already-open data set.
    ///
    /// The in-app path: the viewer already holds a decoded `PixelData`, so this
    /// avoids re-reading and re-decoding the file.
    public func prepare(
        pixelData: PixelData,
        dataSet: DataSet,
        request: PrintJobRequest,
        sourcePath: String? = nil,
        onProgress: ProgressHandler? = nil
    ) async throws -> [PreparedPrintImage] {
        let sourceDescriptor = pixelData.descriptor
        let label = sourcePath ?? "data set"

        let frameIndices: [Int]
        switch request.frameSelection {
        case .all:
            frameIndices = Array(0..<sourceDescriptor.numberOfFrames)
        case .single(let frameNumber):
            guard frameNumber <= sourceDescriptor.numberOfFrames else {
                throw PrintRequestError(
                    "--frame \(frameNumber) is out of range "
                    + "(file has \(sourceDescriptor.numberOfFrames) frame(s)): \(label)")
            }
            frameIndices = [frameNumber - 1]
        }

        var prepared: [PreparedPrintImage] = []
        for frameIndex in frameIndices {
            let descriptor: PrintImageData
            if request.raw {
                guard let frameBytes = pixelData.frameData(at: frameIndex) else {
                    throw PrintRequestError(
                        "Frame \(frameIndex + 1) of \(label) is truncated or missing")
                }
                guard sourceDescriptor.rows <= Int(UInt16.max),
                      sourceDescriptor.columns <= Int(UInt16.max) else {
                    throw PrintRequestError("Image dimensions out of range in: \(label)")
                }
                descriptor = PrintImageData(
                    pixelData: frameBytes,
                    rows: UInt16(sourceDescriptor.rows),
                    columns: UInt16(sourceDescriptor.columns),
                    bitsAllocated: UInt16(sourceDescriptor.bitsAllocated),
                    bitsStored: UInt16(sourceDescriptor.bitsStored),
                    highBit: UInt16(sourceDescriptor.highBit),
                    samplesPerPixel: UInt16(sourceDescriptor.samplesPerPixel),
                    pixelRepresentation: sourceDescriptor.isSigned ? 1 : 0,
                    photometricInterpretation: sourceDescriptor.photometricInterpretation.rawValue
                )
            } else {
                let image = try await preprocessor.prepareForPrint(
                    pixelData: pixelData,
                    dataSet: dataSet,
                    frameIndex: frameIndex,
                    colorMode: request.preprocessColorMode,
                    windowSettings: Self.resolvedWindow(request, dataSet: dataSet),
                    outputBitDepth: request.bitDepth
                )
                guard image.width <= Int(UInt16.max),
                      image.height <= Int(UInt16.max) else {
                    throw PrintRequestError("Image dimensions out of range in: \(label)")
                }
                let stored = UInt16(image.bitsStored)
                // Whatever the modality drew *over* the image goes on the film
                // too. Some Secondary Captures — a Siemens Patient Protocol —
                // have all-zero Pixel Data and put their whole content in a
                // 1-bit overlay plane, and the preview shows it; a film printed
                // without it is a black sheet that disagrees with the screen it
                // was approved on. Not for `--raw`, which sends stored pixels
                // untouched by definition.
                let samples = OverlayPlaneRenderer.burningOverlays(
                    of: dataSet,
                    into: image.pixelData,
                    width: image.width,
                    height: image.height,
                    bitsAllocated: image.bitsAllocated,
                    bitsStored: image.bitsStored,
                    samplesPerPixel: image.samplesPerPixel,
                    photometricInterpretation: image.photometricInterpretation,
                    frameIndex: frameIndex)
                descriptor = PrintImageData(
                    pixelData: samples,
                    rows: UInt16(image.height),
                    columns: UInt16(image.width),
                    bitsAllocated: UInt16(image.bitsAllocated),
                    bitsStored: stored,
                    highBit: stored > 0 ? stored - 1 : 0,
                    samplesPerPixel: UInt16(image.samplesPerPixel),
                    pixelRepresentation: 0,
                    photometricInterpretation: image.photometricInterpretation
                )
                onProgress?(
                    "Prepared \(label) frame \(frameIndex + 1): "
                    + "\(image.width)x\(image.height) "
                    + "\(image.photometricInterpretation) \(image.bitsStored)-bit")
            }

            prepared.append(PreparedPrintImage(
                descriptor: descriptor,
                sourcePath: sourcePath,
                frameIndex: frameIndex
            ))
        }

        return prepared
    }

    // MARK: - Window resolution

    /// The window a frame is printed with, in the units ``ImagePreprocessor``
    /// windows in (output units — HU on CT).
    ///
    /// Three rungs, in the order the rest of the app resolves a window
    /// (`DICOMImageExporter.determineWindowSettings`): the request's own window,
    /// then the data set's VOI, then nothing — which leaves the preprocessor to
    /// stretch the frame's full pixel range.
    ///
    /// The middle rung is why this exists. A mark made without opening the file
    /// — marking a whole series, or printing straight from the library — carries
    /// no window, and auto-stretching a CT from air to bone leaves soft tissue
    /// in a handful of indistinguishable greys. The viewer, the tiles and export
    /// all fall back to the VOI the scanner recorded; film that does not is film
    /// that disagrees with the screen it was approved on.
    ///
    /// A multi-valued VOI (`-600\50` / `1200\350`, a lung and a soft-tissue
    /// window in one element) resolves to its first pair, which PS3.3 C.11.2
    /// makes the default presentation.
    static func resolvedWindow(
        _ request: PrintJobRequest,
        dataSet: DataSet
    ) -> WindowSettings? {
        if request.windowSettings != nil {
            return windowInOutputUnits(request, dataSet: dataSet)
        }
        // Header VOI values are already in output units — that is the space the
        // attribute is defined in — so this rung needs no conversion.
        return dataSet.allWindowSettings().first ?? dataSet.windowSettings()
    }

    /// The request's window in the units ``ImagePreprocessor`` windows in.
    ///
    /// The preprocessor rescales before it windows, so it expects output units.
    /// A window taken off the viewer is in stored values — the space the
    /// renderer works in — and has to be put back through the rescale pair, or
    /// the window sits nowhere near the pixels and the frame prints as a flat
    /// black (or white) cell. See ``PrintWindowSpace``.
    static func windowInOutputUnits(
        _ request: PrintJobRequest,
        dataSet: DataSet
    ) -> WindowSettings? {
        guard let window = request.windowSettings else { return nil }
        guard request.windowSpace == .storedValues else { return window }

        let slope = dataSet.rescaleSlope()
        guard slope != 0 else { return window }
        let intercept = dataSet.rescaleIntercept()
        return WindowSettings(
            center: window.center * slope + intercept,
            width: window.width * abs(slope),
            explanation: window.explanation,
            function: window.function)
    }
}

// MARK: - Convenience

public extension Array where Element == PreparedPrintImage {
    /// The pixel payloads, in order, for `DICOMPrintService.printImages`.
    var pixelPayloads: [Data] { map(\.pixelData) }

    /// The image-box descriptors, in order.
    var imageDescriptors: [PrintImageData] { map(\.descriptor) }
}
