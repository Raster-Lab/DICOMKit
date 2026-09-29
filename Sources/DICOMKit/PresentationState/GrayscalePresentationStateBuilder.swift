// NEMA-verified: 2026a, checked 2026-09-29 — PS3.3 2026a A.33.1: Modality LUT (C.11.1), LUT sequences (C.11.6, C.11.8), Display Shutter (C.7.6.11), conditional Graphic Filled (C.10.5), CIELab layer colour (C.10.7.1.1), Type 2 Content Creator Name (Table 10-12)
// GrayscalePresentationStateBuilder.swift
// DICOMKit
//
// Writes a Grayscale Softcopy Presentation State (PS3.3 A.33.1) — the standard
// object that records *how* an image was being looked at, without touching the
// image itself.
//
// This is the write half of the pair whose read half is
// `GrayscalePresentationStateParser`. What one emits the other must be able to
// read back: the two are tested against each other, because a presentation
// state that cannot survive a round trip is not worth storing.
//
// Nothing here burns anything into pixels. A GSPS is a separate SOP Instance
// that *references* the image it describes, which is what lets one image carry
// several saved looks — a lung window and a bone window are two objects
// pointing at the same slice, not two copies of it.

import Foundation
import DICOMCore

/// Builds a conformant Grayscale Softcopy Presentation State data set.
///
/// The builder deliberately takes an already-composed
/// ``GrayscalePresentationState`` rather than loose parameters: composing the
/// model is the caller's job (and is testable without DICOM), while this type
/// is only responsible for turning it into tags.
public struct GrayscalePresentationStateBuilder: Sendable {

    /// SOP Class UID of the Grayscale Softcopy Presentation State Storage IOD.
    public static let sopClassUID = "1.2.840.10008.5.1.4.1.1.11.1"

    /// Modality of a presentation state series — fixed by PS3.3 C.11.10.
    public static let modality = Modality.pr.rawValue

    public init() {}

    // MARK: - Building

    /// Turns a presentation state into a data set ready to be written.
    ///
    /// - Parameters:
    ///   - state: What to record. Its `sopInstanceUID` becomes the object's own
    ///     identity, and its `referencedSeries` the images it describes.
    ///   - patient: Patient/study attributes copied from the image the state was
    ///     made from. A presentation state lives in the *same study* as its
    ///     images, so these must match the source or the object will not filed
    ///     alongside it.
    ///   - seriesInstanceUID: The series the object belongs to. Callers that
    ///     group several states together pass the same UID for each.
    ///   - seriesNumber: Series Number of that series.
    /// - Returns: A data set carrying the full GSPS IOD.
    public func buildDataSet(
        from state: GrayscalePresentationState,
        patient: PresentationStatePatientContext,
        seriesInstanceUID: String,
        seriesNumber: Int
    ) -> DataSet {
        var dataSet = DataSet()

        // MARK: SOP Common
        dataSet.setString(Self.sopClassUID, for: .sopClassUID, vr: .UI)
        dataSet.setString(state.sopInstanceUID, for: .sopInstanceUID, vr: .UI)
        if let specificCharacterSet = patient.specificCharacterSet {
            dataSet.setString(specificCharacterSet, for: .specificCharacterSet, vr: .CS)
        }

        // MARK: Patient
        dataSet.setString(patient.patientName ?? "", for: .patientName, vr: .PN)
        dataSet.setString(patient.patientID ?? "", for: .patientID, vr: .LO)
        dataSet.setString(patient.patientBirthDate ?? "", for: .patientBirthDate, vr: .DA)
        dataSet.setString(patient.patientSex ?? "", for: .patientSex, vr: .CS)
        // Written only when the image has one: Issuer of Patient ID is part of
        // how a viewer keys the patient (Weasis: patientId + issuer + name), so
        // a PR that drops it while the image carries it files under a different
        // patient — badge on the series, no state on the image.
        if let issuerOfPatientID = patient.issuerOfPatientID {
            dataSet.setString(issuerOfPatientID, for: .issuerOfPatientID, vr: .LO)
        }

        // MARK: General Study
        //
        // Study-level identity is copied verbatim: the presentation state is a
        // new instance in an existing study, never a new study.
        dataSet.setString(patient.studyInstanceUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(patient.studyDate ?? "", for: .studyDate, vr: .DA)
        dataSet.setString(patient.studyTime ?? "", for: .studyTime, vr: .TM)
        dataSet.setString(patient.referringPhysicianName ?? "", for: .referringPhysicianName, vr: .PN)
        dataSet.setString(patient.studyID ?? "", for: .studyID, vr: .SH)
        dataSet.setString(patient.accessionNumber ?? "", for: .accessionNumber, vr: .SH)

        // MARK: Presentation Series
        //
        // Modality is "PR" by definition — a viewer uses it to tell presentation
        // states apart from the images they describe.
        dataSet.setString(Self.modality, for: .modality, vr: .CS)
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString(String(seriesNumber), for: .seriesNumber, vr: .IS)
        if let seriesDescription = patient.seriesDescription {
            dataSet.setString(seriesDescription, for: .seriesDescription, vr: .LO)
        }

        // MARK: General Equipment
        dataSet.setString(patient.manufacturer ?? "", for: .manufacturer, vr: .LO)

        // MARK: Presentation State Identification
        if let instanceNumber = state.instanceNumber {
            dataSet.setString(String(instanceNumber), for: .instanceNumber, vr: .IS)
        }
        // Content Label is type 1 — it must be present and must be CS-legal, so
        // it is derived from the human label rather than trusted from it.
        dataSet.setString(
            Self.contentLabel(from: state.presentationLabel),
            for: .contentLabel, vr: .CS)
        if let label = state.presentationLabel {
            dataSet.setString(label, for: .contentDescription, vr: .LO)
        }
        if let creationDate = state.presentationCreationDate {
            dataSet.setString(creationDate.dicomString, for: .presentationCreationDate, vr: .DA)
        }
        if let creationTime = state.presentationCreationTime {
            dataSet.setString(creationTime.dicomString, for: .presentationCreationTime, vr: .TM)
        }
        // Type 2 (PS3.3 Table 10-12): present, empty when unknown.
        dataSet.setString(state.presentationCreatorsName?.dicomString ?? "", for: .contentCreatorName, vr: .PN)

        // MARK: Presentation State Relationship
        dataSet[.referencedSeriesSequence] = Self.referencedSeriesElement(state.referencedSeries)

        // MARK: Modality LUT (C.11.1)
        //
        // PS3.4 N.2.1.1: a viewer applies only the Modality LUT carried by the
        // presentation state and never the image's own; a window written in
        // rescaled units without one is applied to stored values.
        switch state.modalityLUT {
        case .rescale(let slope, let intercept, let type)?:
            dataSet.setString(Self.decimalString(intercept), for: .rescaleIntercept, vr: .DS)
            dataSet.setString(Self.decimalString(slope), for: .rescaleSlope, vr: .DS)
            dataSet.setString(type ?? "US", for: .rescaleType, vr: .LO)   // Type 1C with the intercept
        case .lut(let lut)?:
            dataSet[.modalityLUTSequence] = Self.sequence(
                tag: .modalityLUTSequence,
                items: [Self.lutItem(lut, extra: [
                    // Modality LUT Type (0028,3004), Type 1; "US" is the unspecified type
                    DataElement.string(tag: Tag(group: 0x0028, element: 0x3004), vr: .LO, value: "US")
                ])])
        case nil:
            break
        }

        // MARK: Display transformations
        if let voiLUT = state.voiLUT {
            Self.applyVOILUT(voiLUT, to: &dataSet)
        }
        if let spatial = state.spatialTransformation {
            // The dictionary decides the encoding (US); the builder supplies
            // only the number.
            dataSet.setInteger(spatial.rotation, for: .imageRotation)
            dataSet.setString(spatial.horizontalFlip ? "Y" : "N", for: .imageHorizontalFlip, vr: .CS)
        }
        if let area = state.displayedArea {
            dataSet[.displayedAreaSelectionSequence] = Self.displayedAreaElement(area)
        }

        // MARK: Display Shutter (C.7.6.11, C.11.12)
        Self.applyShutters(state.shutters, to: &dataSet)

        // MARK: Annotations
        //
        // The reader's own text and arrows. A layer is required by C.10.5 for
        // every annotation, so states carrying annotations without layers would
        // be non-conformant — the caller composes both together.
        if !state.graphicLayers.isEmpty {
            dataSet[.graphicLayerSequence] = Self.graphicLayerElement(state.graphicLayers)
        }
        if !state.graphicAnnotations.isEmpty {
            dataSet[.graphicAnnotationSequence] =
                Self.graphicAnnotationElement(state.graphicAnnotations)
        }

        // MARK: Presentation LUT
        //
        // Written as a shape rather than a table: INVERSE is how a GSPS says
        // "this was being read inverted", which is the only case the viewer
        // produces.
        switch state.presentationLUT {
        case .inverse:
            dataSet.setString("INVERSE", for: .presentationLUTShape, vr: .CS)
        case .identity, .none:
            dataSet.setString("IDENTITY", for: .presentationLUTShape, vr: .CS)
        case .lut(let lut):
            // C.11.6: a table is carried in the Presentation LUT Sequence and
            // the Shape is then absent; replacing it with IDENTITY would change
            // what the state shows.
            dataSet[.presentationLUTSequence] = Self.sequence(
                tag: .presentationLUTSequence, items: [Self.lutItem(lut)])
        }

        return dataSet
    }

    // MARK: - LUT and shutter encoding

    /// One item of a Modality, VOI or Presentation LUT Sequence: LUT Descriptor
    /// (entries, first mapped value, bits per entry; 65536 entries are written as 0
    /// per C.11.1.1), LUT Data as 16-bit words, and the explanation when there is one.
    private static func lutItem(_ lut: LUTData, extra: [DataElement] = []) -> SequenceItem {
        let entries = lut.numberOfEntries >= 65536 ? 0 : lut.numberOfEntries
        var words = Data(capacity: lut.data.count * 2)
        for value in lut.data {
            let word = UInt16(truncatingIfNeeded: value)
            words.append(UInt8(word & 0xFF))
            words.append(UInt8(word >> 8))
        }
        var elements: [DataElement] = [
            Self.integers([entries, lut.firstValueMapped & 0xFFFF, lut.bitsPerEntry], for: .lutDescriptor),
            DataElement(tag: .lutData, vr: .OW, length: UInt32(words.count), valueData: words),
        ]
        if let explanation = lut.explanation {
            elements.append(DataElement.string(tag: .lutExplanation, vr: .LO, value: explanation))
        }
        return SequenceItem(elements: elements + extra)
    }

    /// Display Shutter module (C.7.6.11): geometry is row/column with origin 1,1;
    /// (0018,1610) and (0018,1620) are written row first.
    private static func applyShutters(_ shutters: [DisplayShutter], to dataSet: inout DataSet) {
        var shapes: [String] = []
        for shutter in shutters {
            switch shutter {
            case .rectangular(let left, let right, let top, let bottom, _):
                shapes.append("RECTANGULAR")
                dataSet.setInteger(left, for: .shutterLeftVerticalEdge)
                dataSet.setInteger(right, for: .shutterRightVerticalEdge)
                dataSet.setInteger(top, for: .shutterUpperHorizontalEdge)
                dataSet.setInteger(bottom, for: .shutterLowerHorizontalEdge)
            case .circular(let column, let row, let radius, _):
                shapes.append("CIRCULAR")
                _ = dataSet.setIntegers([row, column], for: .centerOfCircularShutter)
                dataSet.setInteger(radius, for: .radiusOfCircularShutter)
            case .polygonal(let vertices, _):
                shapes.append("POLYGONAL")
                _ = dataSet.setIntegers(vertices.flatMap { [$0.row, $0.column] },
                                        for: .verticesOfThePolygonalShutter)
            case .bitmap:
                // Bitmap Display Shutter (C.7.6.15) needs the overlay plane as well
                continue
            }
        }
        guard !shapes.isEmpty else { return }
        dataSet.setString(shapes.joined(separator: "\\"), for: .shutterShape, vr: .CS)
        // Shutter Presentation Value (0018,1622) is Type 1C in C.11.12: a P-Value
        dataSet.setInteger(shutters.first?.presentationValue ?? 0, for: .shutterPresentationValue)
    }

    // MARK: - Sequences

    private static func referencedSeriesElement(_ series: [ReferencedSeries]) -> DataElement {
        let items = series.map { entry -> SequenceItem in
            var elements: [DataElement] = [
                DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: entry.seriesInstanceUID)
            ]

            if !entry.referencedImages.isEmpty {
                let imageItems = entry.referencedImages.map { image -> SequenceItem in
                    var imageElements: [DataElement] = [
                        DataElement.string(
                            tag: .referencedSOPClassUID, vr: .UI, value: image.sopClassUID),
                        DataElement.string(
                            tag: .referencedSOPInstanceUID, vr: .UI, value: image.sopInstanceUID)
                    ]
                    // Frame numbers are written only for the multi-frame case;
                    // an absent value means "the whole instance".
                    if let frames = image.referencedFrameNumbers, !frames.isEmpty {
                        imageElements.append(DataElement.string(
                            tag: .referencedFrameNumber, vr: .IS,
                            value: frames.map(String.init).joined(separator: "\\")))
                    }
                    return SequenceItem(elements: imageElements)
                }
                elements.append(sequence(tag: .referencedImageSequence, items: imageItems))
            }

            return SequenceItem(elements: elements)
        }

        return sequence(tag: .referencedSeriesSequence, items: items)
    }

    private static func displayedAreaElement(_ area: DisplayedArea) -> DataElement {
        // Encodings come from the dictionary (SL here). The parser accepts the
        // IS form older builds wrote, so existing states still read back.
        let item = SequenceItem(elements: [
            Self.integers([area.topLeft.column, area.topLeft.row],
                          for: .displayedAreaTopLeftHandCorner),
            Self.integers([area.bottomRight.column, area.bottomRight.row],
                          for: .displayedAreaBottomRightHandCorner),
            DataElement.string(
                tag: .presentationSizeMode, vr: .CS, value: area.sizeMode.rawValue),
            // Type 1C: C.10.4 requires one of Presentation Pixel Spacing
            // (0070,0101) or Presentation Pixel Aspect Ratio (0070,0102) in
            // every item — dcmpschk fails the object outright when both are
            // absent. Physical spacing is not something this builder knows, so
            // the aspect ratio is written instead: 1\\1, the square pixels the
            // viewer already assumes when it composes the displayed area.
            DataElement.string(
                tag: .presentationPixelAspectRatio, vr: .IS, value: "1\\1")
        ])
        return sequence(tag: .displayedAreaSelectionSequence, items: [item])
    }

    private static func applyVOILUT(_ voiLUT: VOILUT, to dataSet: inout DataSet) {
        switch voiLUT {
        case .window(let center, let width, let explanation, let function):
            // The window lives in the Softcopy VOI LUT Sequence (C.11.8) —
            // the module the presentation state IODs actually contain. Viewers
            // read a PR's window from inside this sequence only; the years
            // this builder wrote the values top-level, every conforming viewer
            // displayed the state with no window at all.
            var itemElements: [DataElement] = [
                DataElement.string(
                    tag: .windowCenter, vr: .DS, value: Self.decimalString(center)),
                DataElement.string(
                    tag: .windowWidth, vr: .DS, value: Self.decimalString(width)),
            ]
            if let explanation {
                itemElements.append(DataElement.string(
                    tag: .windowCenterWidthExplanation, vr: .LO, value: explanation))
            }
            // LINEAR is the default and is left implicit, matching what the
            // parser assumes when the tag is absent.
            if function != .linear {
                itemElements.append(DataElement.string(
                    tag: .voiLUTFunction, vr: .CS, value: function.rawValue))
            }
            // No Referenced Image Sequence in the item: absent, the window
            // applies to every referenced image (C.11.8.1), which is exactly
            // this object's meaning — one state per image.
            dataSet[.softcopyVOILUTSequence] = sequence(
                tag: .softcopyVOILUTSequence,
                items: [SequenceItem(elements: itemElements)])

            // The same values top-level as well. Not part of the IOD, but a
            // legal extension — and it is what our own parser read before the
            // sequence existed, so files written now stay readable by builds
            // from before it.
            dataSet.setString(Self.decimalString(center), for: .windowCenter, vr: .DS)
            dataSet.setString(Self.decimalString(width), for: .windowWidth, vr: .DS)
            if let explanation {
                dataSet.setString(explanation, for: .windowCenterWidthExplanation, vr: .LO)
            }
            if function != .linear {
                dataSet.setString(function.rawValue, for: .voiLUTFunction, vr: .CS)
            }
        case .lut(let lut):
            // A table lives in the VOI LUT Sequence inside the Softcopy VOI LUT
            // Sequence item (C.11.8); dropping it would change the shown contrast.
            let item = SequenceItem(elements: [
                sequence(tag: .voiLUTSequence, items: [Self.lutItem(lut)])
            ])
            dataSet[.softcopyVOILUTSequence] = sequence(
                tag: .softcopyVOILUTSequence, items: [item])
        }
    }

    private static func graphicLayerElement(_ layers: [GraphicLayer]) -> DataElement {
        let items = layers.map { layer -> SequenceItem in
            var elements: [DataElement] = [
                DataElement.string(tag: .graphicLayer, vr: .CS, value: layer.name),
                DataElement.string(
                    tag: .graphicLayerOrder, vr: .IS, value: String(layer.order))
            ]
            if let description = layer.description {
                elements.append(DataElement.string(
                    tag: .graphicLayerDescription, vr: .LO, value: description))
            }
            if let grayscale = layer.recommendedGrayscaleValue {
                elements.append(Self.integers(
                    [grayscale], for: .graphicLayerRecommendedDisplayGrayscaleValue))
            }
            if let rgb = layer.recommendedRGBValue {
                // (0070,0067) Graphic Layer Recommended Display RGB Value is retired;
                // C.10.7 replaced it with the CIELab value (0070,0401), encoded per
                // C.10.7.1.1: L* over 0...0xFFFF, a* and b* offset so 0x8080 is 0.
                elements.append(Self.integers(
                    Self.cieLabEncoded(from: rgb),
                    for: Tag(group: 0x0070, element: 0x0401)))
            }
            return SequenceItem(elements: elements)
        }
        return sequence(tag: .graphicLayerSequence, items: items)
    }

    /// The three unsigned shorts of a Graphic Layer Recommended Display CIELab
    /// Value (C.10.7.1.1) for a 16-bit-per-channel sRGB colour.
    static func cieLabEncoded(from rgb: (red: Int, green: Int, blue: Int)) -> [Int] {
        let linear = (
            red: ColorTransform.sRGBToLinear(Double(rgb.red) / 65535),
            green: ColorTransform.sRGBToLinear(Double(rgb.green) / 65535),
            blue: ColorTransform.sRGBToLinear(Double(rgb.blue) / 65535))
        let lab = ColorTransform.rgbToLAB(linear)
        return [lab.l / 100 * 65535, (lab.a + 128) * 257, (lab.b + 128) * 257]
            .map { min(65535, max(0, Int($0.rounded()))) }
    }

    /// The inverse of ``cieLabEncoded(from:)``, for reading (0070,0401) back.
    static func rgb(fromCIELabEncoded encoded: [Int]) -> (red: Int, green: Int, blue: Int)? {
        guard encoded.count == 3 else { return nil }
        let l = Double(encoded[0]) / 65535 * 100
        let a = Double(encoded[1]) / 257 - 128
        let b = Double(encoded[2]) / 257 - 128
        // CIELab -> XYZ (same D65 reference as ColorTransform.xyzToLAB) -> linear RGB -> sRGB
        let fy = (l + 16) / 116
        let fx = fy + a / 500
        let fz = fy - b / 200
        func finv(_ t: Double) -> Double {
            let delta = 6.0 / 29.0
            return t > delta ? t * t * t : 3 * delta * delta * (t - 4.0 / 29.0)
        }
        let xyz = (x: 0.95047 * finv(fx), y: 1.0 * finv(fy), z: 1.08883 * finv(fz))
        let linear = ColorTransform.xyzToRGB(xyz)
        func channel(_ v: Double) -> Int {
            min(65535, max(0, Int((ColorTransform.linearToSRGB(v) * 65535).rounded())))
        }
        return (red: channel(linear.red), green: channel(linear.green), blue: channel(linear.blue))
    }

    private static func graphicAnnotationElement(
        _ annotations: [GraphicAnnotation]
    ) -> DataElement {
        let items = annotations.map { annotation -> SequenceItem in
            var elements: [DataElement] = [
                DataElement.string(tag: .graphicLayer, vr: .CS, value: annotation.layer)
            ]

            if !annotation.referencedImages.isEmpty {
                let imageItems = annotation.referencedImages.map { image -> SequenceItem in
                    var imageElements: [DataElement] = [
                        DataElement.string(
                            tag: .referencedSOPClassUID, vr: .UI, value: image.sopClassUID),
                        DataElement.string(
                            tag: .referencedSOPInstanceUID, vr: .UI,
                            value: image.sopInstanceUID)
                    ]
                    if let frames = image.referencedFrameNumbers, !frames.isEmpty {
                        imageElements.append(DataElement.string(
                            tag: .referencedFrameNumber, vr: .IS,
                            value: frames.map(String.init).joined(separator: "\\")))
                    }
                    return SequenceItem(elements: imageElements)
                }
                elements.append(sequence(tag: .referencedImageSequence, items: imageItems))
            }

            if !annotation.graphicObjects.isEmpty {
                let graphicItems = annotation.graphicObjects.map(graphicObjectItem)
                elements.append(sequence(tag: .graphicObjectSequence, items: graphicItems))
            }
            if !annotation.textObjects.isEmpty {
                let textItems = annotation.textObjects.map(textObjectItem)
                elements.append(sequence(tag: .textObjectSequence, items: textItems))
            }

            return SequenceItem(elements: elements)
        }
        return sequence(tag: .graphicAnnotationSequence, items: items)
    }

    private static func graphicObjectItem(_ object: GraphicObject) -> SequenceItem {
        var elements: [DataElement] = [
            DataElement.string(
                tag: .graphicAnnotationUnits, vr: .CS, value: object.units.rawValue),
            // Always 2: Graphic Data here is (column, row) pairs.
            Self.integers([2], for: .graphicDimensions),
            Self.integers([object.pointCount], for: .numberOfGraphicPoints),
            Self.reals(object.data, for: .graphicData),
            DataElement.string(tag: .graphicType, vr: .CS, value: object.type.rawValue),
        ]
        // Graphic Filled (0070,0024) is Type 1C (C.10.5): only for CIRCLE, ELLIPSE, or
        // a POLYLINE / INTERPOLATED whose first point is also its last. PS3.5 7.4.4:
        // a 1C element whose condition is not met shall not be present.
        let d = object.data
        let closed = object.type == .circle || object.type == .ellipse
            || ((object.type == .polyline || object.type == .interpolated)
                && d.count >= 4 && d[0] == d[d.count - 2] && d[1] == d[d.count - 1])
        if closed {
            elements.append(DataElement.string(
                tag: .graphicFilled, vr: .CS, value: object.filled ? "Y" : "N"))
        }
        return SequenceItem(elements: elements)
    }

    private static func textObjectItem(_ text: TextObject) -> SequenceItem {
        var elements: [DataElement] = [
            DataElement.string(
                tag: .boundingBoxAnnotationUnits, vr: .CS,
                value: text.boundingBoxUnits.rawValue),
            DataElement.string(
                tag: .unformattedTextValue, vr: .ST, value: text.text),
            Self.reals([text.boundingBoxTopLeft.column, text.boundingBoxTopLeft.row],
                       for: .boundingBoxTopLeftHandCorner),
            Self.reals([text.boundingBoxBottomRight.column, text.boundingBoxBottomRight.row],
                       for: .boundingBoxBottomRightHandCorner),
            // Type 1C once a bounding box is present. LEFT because that is how
            // every renderer of this model draws — the anchor is the top-left.
            DataElement.string(
                tag: .boundingBoxTextHorizontalJustification, vr: .CS, value: "LEFT")
        ]
        if let anchor = text.anchorPoint {
            elements.append(Self.reals([anchor.column, anchor.row], for: .anchorPoint))
            elements.append(DataElement.string(
                tag: .anchorPointVisibility, vr: .CS,
                value: text.anchorPointVisible ? "Y" : "N"))
            elements.append(DataElement.string(
                tag: .anchorPointAnnotationUnits, vr: .CS,
                value: text.anchorPointUnits.rawValue))
        }
        return SequenceItem(elements: elements)
    }

    /// An integer-valued element encoded the way the data dictionary says.
    ///
    /// The builder names the tag and the numbers; DICOMKit's own
    /// `DataElementDictionary` supplies the VR, so a call site cannot pick one
    /// that disagrees with the standard. `.UN` is unreachable for these tags —
    /// every one is in the dictionary — and only guards the lookup.
    private static func integers(_ values: [Int], for tag: Tag) -> DataElement {
        var holder = DataSet()
        guard holder.setIntegers(values, for: tag), let element = holder[tag] else {
            return DataElement.strings(
                tag: tag, vr: .UN, values: values.map(String.init))
        }
        return element
    }

    /// A real-valued element encoded the way the data dictionary says.
    /// See ``integers(_:for:)``.
    private static func reals(_ values: [Double], for tag: Tag) -> DataElement {
        var holder = DataSet()
        guard holder.setReals(values, for: tag, decimalStringFormatter: decimalString),
              let element = holder[tag] else {
            return DataElement.strings(
                tag: tag, vr: .UN, values: values.map(decimalString))
        }
        return element
    }

    private static func sequence(tag: Tag, items: [SequenceItem]) -> DataElement {
        DataElement(tag: tag, vr: .SQ, length: 0, valueData: Data(), sequenceItems: items)
    }

    // MARK: - Value formatting

    /// A DS value has 16 bytes to work with, so window values are written in the
    /// shortest form that keeps them exact.
    static func decimalString(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%.6g", value)
    }

    /// Derives a CS-legal Content Label from a user-typed name.
    ///
    /// CS permits uppercase letters, digits, space and underscore, up to 16
    /// characters. A reader typing "Lung window" must not produce a
    /// non-conformant object, so the label is folded rather than rejected.
    public static func contentLabel(from label: String?) -> String {
        let fallback = "PRESENTATION"
        guard let label, !label.isEmpty else { return fallback }

        let folded = label.uppercased().map { character -> Character in
            if character.isLetter, character.isASCII { return character }
            if character.isNumber, character.isASCII { return character }
            if character == " " || character == "_" { return character }
            return "_"
        }

        let trimmed = String(folded.prefix(16))
            .trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

/// The patient, study and equipment attributes a presentation state must repeat
/// from the image it describes.
///
/// A GSPS is filed into an existing study, so these are copied from the source
/// image rather than invented — a mismatch here is what makes a saved state
/// vanish from the study it belongs to.
public struct PresentationStatePatientContext: Sendable, Equatable {

    public var patientName: String?
    public var patientID: String?
    public var patientBirthDate: String?
    public var patientSex: String?
    /// Issuer of Patient ID (0010,0021). Copied because viewers fold it into
    /// the patient's identity key; see the write site for the failure it stops.
    public var issuerOfPatientID: String?

    public var studyInstanceUID: String
    public var studyDate: String?
    public var studyTime: String?
    public var studyID: String?
    public var accessionNumber: String?
    public var referringPhysicianName: String?

    public var specificCharacterSet: String?
    public var manufacturer: String?
    public var seriesDescription: String?

    public init(
        patientName: String? = nil,
        patientID: String? = nil,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        issuerOfPatientID: String? = nil,
        studyInstanceUID: String,
        studyDate: String? = nil,
        studyTime: String? = nil,
        studyID: String? = nil,
        accessionNumber: String? = nil,
        referringPhysicianName: String? = nil,
        specificCharacterSet: String? = nil,
        manufacturer: String? = nil,
        seriesDescription: String? = nil
    ) {
        self.patientName = patientName
        self.patientID = patientID
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.issuerOfPatientID = issuerOfPatientID
        self.studyInstanceUID = studyInstanceUID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyID = studyID
        self.accessionNumber = accessionNumber
        self.referringPhysicianName = referringPhysicianName
        self.specificCharacterSet = specificCharacterSet
        self.manufacturer = manufacturer
        self.seriesDescription = seriesDescription
    }

    /// Reads the context out of the image the state is being made from.
    public static func make(from dataSet: DataSet) -> PresentationStatePatientContext {
        func string(_ tag: Tag) -> String? {
            guard let value = dataSet.string(for: tag)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        return PresentationStatePatientContext(
            patientName: string(.patientName),
            patientID: string(.patientID),
            patientBirthDate: string(.patientBirthDate),
            patientSex: string(.patientSex),
            issuerOfPatientID: string(.issuerOfPatientID),
            studyInstanceUID: string(.studyInstanceUID) ?? "",
            studyDate: string(.studyDate),
            studyTime: string(.studyTime),
            studyID: string(.studyID),
            accessionNumber: string(.accessionNumber),
            referringPhysicianName: string(.referringPhysicianName),
            specificCharacterSet: string(.specificCharacterSet),
            manufacturer: string(.manufacturer))
    }
}
