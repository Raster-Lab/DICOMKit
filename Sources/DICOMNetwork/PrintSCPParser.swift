//
// PrintSCPParser.swift
// DICOMNetwork
//
// Maps received Print Management data sets onto the existing print model
// (`FilmSession`, `FilmBox`, `ImageBoxContent`, `PrintImageData`). The SCU
// serializes these attributes; the SCP reads them back — the round trip is
// symmetric by construction, which makes it directly testable.
//
// Reference: PS3.3 C.13 (Print Management modules), PS3.4 Annex H.
//

import Foundation
import DICOMCore

/// Decodes Print Management attributes from a walked data set.
///
/// All entry points are "apply" style: an N-SET carries only the attributes the
/// SCU wants to change, so parsing merges into existing state rather than
/// building a value from scratch.
public enum PrintSCPParser {

    // MARK: - Film Session (PS3.3 C.13.1)

    /// Applies Basic Film Session attributes onto `session`.
    ///
    /// - Throws: ``PrintSCPFailure`` with 0x0106 for an unparseable enumerated
    ///   value, or with `invalidAttributeValue` for a medium type the printer
    ///   does not support.
    public static func applyFilmSession(
        _ attributes: PrintAttributeSet,
        to session: inout FilmSession,
        configuration: PrintSCPConfiguration
    ) throws {
        if let copies = attributes.integer(for: .numberOfCopies) {
            guard copies >= 1 else {
                throw PrintSCPFailure(.invalidAttributeValue, comment: "Number of Copies must be >= 1")
            }
            session.numberOfCopies = copies
        }
        if let priority = attributes.string(for: .printPriority) {
            session.printPriority = try enumeration(PrintPriority.self, priority, tag: "Print Priority")
        }
        if let medium = attributes.string(for: .mediumType) {
            let value = try enumeration(MediumType.self, medium, tag: "Medium Type")
            guard configuration.supportedMediumTypes.contains(value) else {
                throw PrintSCPFailure(.invalidAttributeValue, comment: "Unsupported Medium Type: \(medium)")
            }
            session.mediumType = value
        }
        if let destination = attributes.string(for: .filmDestination) {
            session.filmDestination = try enumeration(
                FilmDestination.self, destination, tag: "Film Destination")
        }
        if let label = attributes.string(for: .filmSessionLabel) {
            session.filmSessionLabel = label
        }
    }

    // MARK: - Film Box (PS3.3 C.13.3)

    /// Mutable film-box state: the public ``FilmBox`` plus the attributes the
    /// SCP tracks but the SCU-side value type does not carry.
    public struct FilmBoxAttributes: Sendable, Equatable {
        public var filmBox: FilmBox
        public var minDensity: UInt16?
        public var maxDensity: UInt16?
        public var smoothingType: String?
        public var annotationDisplayFormatID: String?
        /// SOP Instance UID of the Presentation LUT referenced by (2050,0500).
        public var referencedPresentationLUTUID: String?
        /// SOP Instance UIDs referenced by (2010,0520), in item order.
        public var referencedAnnotationBoxUIDs: [String]

        public init(
            filmBox: FilmBox,
            minDensity: UInt16? = nil,
            maxDensity: UInt16? = nil,
            smoothingType: String? = nil,
            annotationDisplayFormatID: String? = nil,
            referencedPresentationLUTUID: String? = nil,
            referencedAnnotationBoxUIDs: [String] = []
        ) {
            self.filmBox = filmBox
            self.minDensity = minDensity
            self.maxDensity = maxDensity
            self.smoothingType = smoothingType
            self.annotationDisplayFormatID = annotationDisplayFormatID
            self.referencedPresentationLUTUID = referencedPresentationLUTUID
            self.referencedAnnotationBoxUIDs = referencedAnnotationBoxUIDs
        }
    }

    /// Applies Basic Film Box attributes onto `box`.
    ///
    /// `Image Display Format` is deliberately *not* applied here on N-SET: the
    /// image box count is fixed at N-CREATE time, so a later change would
    /// invalidate the UIDs already handed to the SCU. The caller reads it from
    /// the N-CREATE data set via ``imageDisplayFormat(in:)``.
    public static func applyFilmBox(
        _ attributes: PrintAttributeSet,
        to box: inout FilmBoxAttributes,
        configuration: PrintSCPConfiguration
    ) throws {
        if let orientation = attributes.string(for: .filmOrientation) {
            box.filmBox.filmOrientation = try enumeration(
                FilmOrientation.self, orientation, tag: "Film Orientation")
        }
        if let size = attributes.string(for: .filmSizeID) {
            let value = try enumeration(FilmSize.self, size, tag: "Film Size ID")
            guard configuration.supportedFilmSizes.contains(value) else {
                throw PrintSCPFailure(.invalidAttributeValue, comment: "Unsupported Film Size ID: \(size)")
            }
            box.filmBox.filmSizeID = value
        }
        if let magnification = attributes.string(for: .magnificationType) {
            box.filmBox.magnificationType = try enumeration(
                MagnificationType.self, magnification, tag: "Magnification Type")
        }
        if let border = attributes.string(for: .borderDensity) {
            box.filmBox.borderDensity = border
        }
        if let empty = attributes.string(for: .emptyImageDensity) {
            box.filmBox.emptyImageDensity = empty
        }
        if let trim = attributes.string(for: .trim) {
            box.filmBox.trimOption = try enumeration(TrimOption.self, trim, tag: "Trim")
        }
        if let configuration = attributes.string(for: .configurationInformation) {
            box.filmBox.configurationInformation = configuration
        }
        if let smoothing = attributes.string(for: .smoothingType) {
            box.smoothingType = smoothing
        }
        if let minDensity = attributes.uint16(for: .minDensity) {
            box.minDensity = minDensity
        }
        if let maxDensity = attributes.uint16(for: .maxDensity) {
            box.maxDensity = maxDensity
        }
        if let annotationFormat = attributes.string(for: .annotationDisplayFormatID) {
            box.annotationDisplayFormatID = annotationFormat
        }
        if let lutItem = attributes.firstItem(of: .referencedPresentationLUTSequence) {
            box.referencedPresentationLUTUID = lutItem.string(for: .referencedSOPInstanceUID)
        }
        let annotationItems = attributes.items(for: .referencedBasicAnnotationBoxSequence)
        if !annotationItems.isEmpty {
            box.referencedAnnotationBoxUIDs = annotationItems.compactMap {
                $0.string(for: .referencedSOPInstanceUID)
            }
        }
    }

    /// Reads Image Display Format (2010,0010) from a film-box N-CREATE.
    ///
    /// - Throws: ``PrintSCPFailure`` 0x0120 when the mandatory attribute is absent.
    public static func imageDisplayFormat(in attributes: PrintAttributeSet) throws -> String {
        guard let format = attributes.string(for: .imageDisplayFormat) else {
            throw PrintSCPFailure(.missingAttribute, comment: "Image Display Format (2010,0010) is required")
        }
        return format
    }

    // MARK: - Image Box (PS3.3 C.13.5)

    /// The result of parsing a Basic Grayscale/Color Image Box N-SET.
    public struct ParsedImageBox: Sendable, Equatable {
        public var content: ImageBoxContent
        public var image: PrintImageData?

        public init(content: ImageBoxContent, image: PrintImageData?) {
            self.content = content
            self.image = image
        }
    }

    /// Parses an image-box N-SET data set.
    ///
    /// - Parameters:
    ///   - attributes: the walked N-SET data set.
    ///   - sopInstanceUID: the image box UID the SCP allocated.
    ///   - isColor: whether the request came on the Basic Color Image Box SOP Class.
    ///   - existing: current box content, so a partial N-SET merges.
    /// - Throws: ``PrintSCPFailure`` for missing or invalid pixel-module attributes.
    public static func parseImageBox(
        _ attributes: PrintAttributeSet,
        sopInstanceUID: String,
        isColor: Bool,
        existing: ImageBoxContent,
        configuration: PrintSCPConfiguration
    ) throws -> ParsedImageBox {
        var content = existing

        if let position = attributes.uint16(for: .imageBoxPosition) {
            guard position >= 1 else {
                throw PrintSCPFailure(.invalidAttributeValue, comment: "Image Box Position must be >= 1")
            }
            content.imagePosition = position
        }
        if let polarity = attributes.string(for: .polarity) {
            content.polarity = try enumeration(ImagePolarity.self, polarity, tag: "Polarity")
        }
        if let size = attributes.string(for: .requestedImageSize) {
            content.requestedImageSize = size
        }
        if let behavior = attributes.string(for: .requestedDecimateCropBehavior) {
            content.requestedDecimateCropBehavior = try enumeration(
                DecimateCropBehavior.self, behavior, tag: "Requested Decimate/Crop Behavior")
        }

        // The pixels live in a one-item Preformatted Grayscale/Color Image
        // Sequence. Accept either sequence regardless of the negotiated SOP
        // class — some SCUs send the grayscale sequence on a color association.
        let item = attributes.firstItem(of: .preformattedGrayscaleImageSequence)
            ?? attributes.firstItem(of: .preformattedColorImageSequence)
        guard let item else {
            return ParsedImageBox(content: content, image: nil)
        }

        let image = try parsePixelModule(item, isColor: isColor, configuration: configuration)
        return ParsedImageBox(content: content, image: image)
    }

    /// Decodes the pixel module of a Preformatted Image Sequence item.
    static func parsePixelModule(
        _ item: PrintAttributeSet,
        isColor: Bool,
        configuration: PrintSCPConfiguration
    ) throws -> PrintImageData {
        guard let rows = item.uint16(for: .rows), rows > 0 else {
            throw PrintSCPFailure(.missingAttribute, comment: "Rows (0028,0010) is required")
        }
        guard let columns = item.uint16(for: .columns), columns > 0 else {
            throw PrintSCPFailure(.missingAttribute, comment: "Columns (0028,0011) is required")
        }
        guard rows <= configuration.maxImageBoxPixelDimension,
              columns <= configuration.maxImageBoxPixelDimension else {
            throw PrintSCPFailure(
                .imageLargerThanImageBox,
                comment: "Image \(columns)x\(rows) exceeds the printer's maximum of "
                    + "\(configuration.maxImageBoxPixelDimension) pixels per side")
        }
        guard let bitsAllocated = item.uint16(for: .bitsAllocated) else {
            throw PrintSCPFailure(.missingAttribute, comment: "Bits Allocated (0028,0100) is required")
        }
        guard bitsAllocated == 8 || bitsAllocated == 16 else {
            throw PrintSCPFailure(
                .invalidAttributeValue,
                comment: "Bits Allocated must be 8 or 16, got \(bitsAllocated)")
        }
        let samplesPerPixel = item.uint16(for: .samplesPerPixel) ?? (isColor ? 3 : 1)
        if !isColor && samplesPerPixel != 1 {
            throw PrintSCPFailure(
                .invalidAttributeValue,
                comment: "Samples per Pixel must be 1 on the Basic Grayscale Image Box, got \(samplesPerPixel)")
        }
        guard samplesPerPixel == 1 || samplesPerPixel == 3 else {
            throw PrintSCPFailure(
                .invalidAttributeValue,
                comment: "Samples per Pixel must be 1 or 3, got \(samplesPerPixel)")
        }
        guard let pixelData = item.bytes(for: .pixelData) else {
            throw PrintSCPFailure(.missingAttribute, comment: "Pixel Data (7FE0,0010) is required")
        }

        let bitsStored = item.uint16(for: .bitsStored) ?? bitsAllocated
        let highBit = item.uint16(for: .highBit) ?? (bitsStored - 1)
        let photometric = item.string(for: .photometricInterpretation)
            ?? (isColor ? "RGB" : "MONOCHROME2")
        let pixelRepresentation = item.uint16(for: .pixelRepresentation) ?? 0

        // The declared geometry must actually be covered by the bytes received;
        // a short value means a truncated or mis-declared image, not a warning.
        //
        // Subsampled YBR (PS3.5 8.7.4) is packed two pixels per four bytes —
        // Y1 Y2 Cb Cr — so it carries 2 bytes per pixel despite declaring three
        // samples. Our own SCU converts to RGB before sending, but third-party
        // SCUs do send packed 4:2:2, and rejecting it here would be wrong.
        let isSubsampled = photometric.hasSuffix("_422") || photometric.hasSuffix("_420")
        let bytesPerPixel = isSubsampled
            ? 2 * Int(bitsAllocated) / 8
            : Int(samplesPerPixel) * Int(bitsAllocated) / 8
        let expected = Int(rows) * Int(columns) * bytesPerPixel
        guard pixelData.count >= expected else {
            throw PrintSCPFailure(
                .invalidAttributeValue,
                comment: "Pixel Data is \(pixelData.count) bytes; \(expected) required for "
                    + "\(columns)x\(rows)x\(samplesPerPixel) at \(bitsAllocated) bits")
        }

        return PrintImageData(
            pixelData: pixelData,
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit,
            samplesPerPixel: samplesPerPixel,
            pixelRepresentation: pixelRepresentation,
            photometricInterpretation: photometric
        )
    }

    // MARK: - Presentation LUT / Annotation Box

    /// Reads Presentation LUT Shape (2050,0020) from a Presentation LUT N-CREATE.
    ///
    /// LUT *data* tables (2050,0010 Presentation LUT Sequence) are a documented
    /// gap: we accept the instance so the association proceeds, but only the
    /// shape is honored during composition.
    public static func presentationLUTShape(in attributes: PrintAttributeSet) throws -> PresentationLUTShape? {
        guard let shape = attributes.string(for: .presentationLUTShape) else { return nil }
        return try enumeration(PresentationLUTShape.self, shape, tag: "Presentation LUT Shape")
    }

    /// Reads an annotation from a Basic Annotation Box N-CREATE / N-SET.
    public static func annotation(in attributes: PrintAttributeSet) -> PrintAnnotation? {
        guard let text = attributes.string(for: .textString) else { return nil }
        let position = attributes.uint16(for: .annotationPosition) ?? 1
        return PrintAnnotation(position: position, text: text)
    }

    // MARK: - Helpers

    /// Decodes an enumerated CS value, failing with 0x0106 when unrecognized.
    private static func enumeration<T: RawRepresentable>(
        _ type: T.Type,
        _ raw: String,
        tag: String
    ) throws -> T where T.RawValue == String {
        let normalized = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        guard let value = T(rawValue: normalized) else {
            throw PrintSCPFailure(.invalidAttributeValue, comment: "Invalid \(tag) value: \(raw)")
        }
        return value
    }
}
