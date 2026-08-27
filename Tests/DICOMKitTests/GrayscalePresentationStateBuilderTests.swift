//
// GrayscalePresentationStateBuilderTests.swift
// DICOMKit
//
// The builder's contract is that the parser can read back what it writes. Most
// of these tests are therefore round trips rather than tag assertions: a tag
// written in a form the parser does not accept is a bug even when the tag
// itself is correct.
//

import XCTest
import DICOMCore
@testable import DICOMKit

final class GrayscalePresentationStateBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private let imageSOPClassUID = "1.2.840.10008.5.1.4.1.1.2"

    private func context() -> PresentationStatePatientContext {
        PresentationStatePatientContext(
            patientName: "DOE^JANE",
            patientID: "12345",
            patientBirthDate: "19600101",
            patientSex: "F",
            studyInstanceUID: "1.2.3.4.5",
            studyDate: "20260101",
            studyTime: "120000",
            studyID: "S1",
            accessionNumber: "A1",
            seriesDescription: "Presentation States")
    }

    private func state(
        label: String? = "Lung window",
        voiLUT: VOILUT? = .window(center: -600, width: 1500, explanation: nil, function: .linear),
        spatial: SpatialTransformation? = SpatialTransformation(rotation: 90, horizontalFlip: true),
        area: DisplayedArea? = DisplayedArea(
            topLeft: (column: 10, row: 20),
            bottomRight: (column: 210, row: 220),
            sizeMode: .scaleToFit),
        presentationLUT: PresentationLUT? = .identity,
        images: [String] = ["1.2.3.4.5.6.1"]
    ) -> GrayscalePresentationState {
        GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.99.1",
            instanceNumber: 1,
            presentationLabel: label,
            presentationCreationDate: DICOMDate(year: 2026, month: 8, day: 18),
            presentationCreationTime: DICOMTime(hour: 14, minute: 30, second: 0),
            referencedSeries: [
                ReferencedSeries(
                    seriesInstanceUID: "1.2.3.4.5.6",
                    referencedImages: images.map {
                        ReferencedImage(sopClassUID: imageSOPClassUID, sopInstanceUID: $0)
                    })
            ],
            voiLUT: voiLUT,
            presentationLUT: presentationLUT,
            spatialTransformation: spatial,
            displayedArea: area)
    }

    private func roundTrip(
        _ state: GrayscalePresentationState
    ) throws -> GrayscalePresentationState {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state,
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)
        return try GrayscalePresentationStateParser().parse(dataSet: dataSet)
    }

    // MARK: - Identity and series attributes

    func test_build_writesGSPSSOPClassAndPRModality() {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state(),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)

        XCTAssertEqual(
            dataSet.string(for: .sopClassUID), "1.2.840.10008.5.1.4.1.1.11.1")
        XCTAssertEqual(dataSet.string(for: .modality), "PR")
        XCTAssertEqual(dataSet.string(for: .seriesInstanceUID), "1.2.3.4.5.900")
        XCTAssertEqual(dataSet.string(for: .seriesNumber), "900")
    }

    /// A presentation state is filed into the study it describes, so study-level
    /// identity must be copied, not regenerated.
    func test_build_keepsStudyIdentityOfSourceImage() {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state(),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)

        XCTAssertEqual(dataSet.string(for: .studyInstanceUID), "1.2.3.4.5")
        XCTAssertEqual(dataSet.string(for: .patientID), "12345")
        XCTAssertEqual(dataSet.string(for: .accessionNumber), "A1")
    }

    // MARK: - Round trips

    func test_roundTrip_preservesWindow() throws {
        let parsed = try roundTrip(state())

        guard case .window(let center, let width, _, let function)? = parsed.voiLUT else {
            return XCTFail("expected a window VOI LUT, got \(String(describing: parsed.voiLUT))")
        }
        XCTAssertEqual(center, -600)
        XCTAssertEqual(width, 1500)
        XCTAssertEqual(function, .linear)
    }

    func test_roundTrip_preservesRotationAndFlip() throws {
        let parsed = try roundTrip(state())

        XCTAssertEqual(parsed.spatialTransformation?.rotation, 90)
        XCTAssertEqual(parsed.spatialTransformation?.horizontalFlip, true)
    }

    func test_roundTrip_preservesDisplayedArea() throws {
        let parsed = try roundTrip(state())

        XCTAssertEqual(parsed.displayedArea?.topLeft.column, 10)
        XCTAssertEqual(parsed.displayedArea?.topLeft.row, 20)
        XCTAssertEqual(parsed.displayedArea?.bottomRight.column, 210)
        XCTAssertEqual(parsed.displayedArea?.bottomRight.row, 220)
        XCTAssertEqual(parsed.displayedArea?.sizeMode, .scaleToFit)
    }

    func test_roundTrip_preservesReferencedImages() throws {
        let parsed = try roundTrip(state(images: ["1.2.3.4.5.6.1", "1.2.3.4.5.6.2"]))

        XCTAssertEqual(parsed.referencedSeries.count, 1)
        XCTAssertEqual(parsed.referencedSeries.first?.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(
            parsed.referencedSeries.first?.referencedImages.map(\.sopInstanceUID),
            ["1.2.3.4.5.6.1", "1.2.3.4.5.6.2"])
    }

    /// A state that changes nothing spatially must not invent a transformation:
    /// the parser reports nil, and the viewer restores the default view.
    func test_roundTrip_omitsSpatialTransformationWhenUnchanged() throws {
        let parsed = try roundTrip(state(spatial: nil, area: nil))

        XCTAssertNil(parsed.spatialTransformation)
        XCTAssertNil(parsed.displayedArea)
    }

    func test_roundTrip_preservesInvertedPolarity() throws {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state(presentationLUT: .inverse),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)

        XCTAssertEqual(dataSet.string(for: .presentationLUTShape), "INVERSE")
    }

    func test_roundTrip_sigmoidFunctionSurvives() throws {
        let parsed = try roundTrip(state(
            voiLUT: .window(center: 40, width: 400, explanation: "Soft tissue", function: .sigmoid)))

        guard case .window(_, _, let explanation, let function)? = parsed.voiLUT else {
            return XCTFail("expected a window VOI LUT")
        }
        XCTAssertEqual(function, .sigmoid)
        XCTAssertEqual(explanation, "Soft tissue")
    }

    // MARK: - Annotations

    private func annotatedState() -> GrayscalePresentationState {
        GrayscalePresentationState(
            sopInstanceUID: "1.2.3.4.5.99.2",
            presentationLabel: "Marked up",
            referencedSeries: [
                ReferencedSeries(
                    seriesInstanceUID: "1.2.3.4.5.6",
                    referencedImages: [
                        ReferencedImage(
                            sopClassUID: imageSOPClassUID,
                            sopInstanceUID: "1.2.3.4.5.6.1")
                    ])
            ],
            graphicLayers: [
                GraphicLayer(
                    name: "DRAWINGS", order: 1,
                    description: "Reader-drawn text and arrows",
                    recommendedRGBValue: (red: 65535, green: 65535, blue: 0))
            ],
            graphicAnnotations: [
                GraphicAnnotation(
                    layer: "DRAWINGS",
                    referencedImages: [
                        ReferencedImage(
                            sopClassUID: imageSOPClassUID,
                            sopInstanceUID: "1.2.3.4.5.6.1")
                    ],
                    graphicObjects: [
                        GraphicObject(
                            type: .polyline,
                            data: [10.5, 20.5, 100, 200],
                            filled: false,
                            units: .pixel)
                    ],
                    textObjects: [
                        TextObject(
                            text: "Nodule",
                            boundingBoxTopLeft: (column: 30, row: 40),
                            boundingBoxBottomRight: (column: 130, row: 60),
                            anchorPoint: (column: 30, row: 40),
                            anchorPointVisible: false,
                            boundingBoxUnits: .pixel,
                            anchorPointUnits: .pixel)
                    ])
            ])
    }

    func test_roundTrip_preservesGraphicLayer() throws {
        let parsed = try roundTrip(annotatedState())

        XCTAssertEqual(parsed.graphicLayers.count, 1)
        let layer = try XCTUnwrap(parsed.graphicLayers.first)
        XCTAssertEqual(layer.name, "DRAWINGS")
        XCTAssertEqual(layer.order, 1)
        XCTAssertEqual(layer.description, "Reader-drawn text and arrows")
        XCTAssertEqual(layer.recommendedRGBValue?.red, 65535)
        XCTAssertEqual(layer.recommendedRGBValue?.blue, 0)
    }

    func test_roundTrip_preservesGraphicObject() throws {
        let parsed = try roundTrip(annotatedState())

        let annotation = try XCTUnwrap(parsed.graphicAnnotations.first)
        XCTAssertEqual(annotation.layer, "DRAWINGS")
        XCTAssertEqual(annotation.referencedImages.map(\.sopInstanceUID), ["1.2.3.4.5.6.1"])
        let graphic = try XCTUnwrap(annotation.graphicObjects.first)
        XCTAssertEqual(graphic.type, .polyline)
        XCTAssertEqual(graphic.data, [10.5, 20.5, 100, 200])
        XCTAssertEqual(graphic.units, .pixel)
        XCTAssertFalse(graphic.filled)
    }

    func test_roundTrip_preservesTextObject() throws {
        let parsed = try roundTrip(annotatedState())

        let text = try XCTUnwrap(parsed.graphicAnnotations.first?.textObjects.first)
        XCTAssertEqual(text.text, "Nodule")
        XCTAssertEqual(text.boundingBoxTopLeft.column, 30)
        XCTAssertEqual(text.boundingBoxBottomRight.row, 60)
        XCTAssertEqual(text.anchorPoint?.column, 30)
        XCTAssertFalse(text.anchorPointVisible)
        XCTAssertEqual(text.boundingBoxUnits, .pixel)
    }

    /// The words are written to the Text Object's own tag (0070,0006), not
    /// SR's Text Value — but files written while the parser read the wrong tag
    /// must keep parsing.
    func test_parse_fallsBackToLegacyTextValueTag() throws {
        var dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: annotatedState(),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)
        XCTAssertNotNil(dataSet[.graphicAnnotationSequence])

        // Rewrite the annotation's text object with the legacy tag only.
        let annotationItems = try XCTUnwrap(dataSet[.graphicAnnotationSequence]?.sequenceItems)
        let rebuilt = annotationItems.map { item -> SequenceItem in
            var elements = item.elements.values.filter { $0.tag != .textObjectSequence }
            elements.append(DataElement(
                tag: .textObjectSequence, vr: .SQ, length: 0, valueData: Data(),
                sequenceItems: [SequenceItem(elements: [
                    DataElement.string(tag: .unformattedTextValue, vr: .ST, value: "Legacy"),
                    DataElement.string(
                        tag: .boundingBoxTopLeftHandCorner, vr: .DS, value: "1\\2"),
                    DataElement.string(
                        tag: .boundingBoxBottomRightHandCorner, vr: .DS, value: "3\\4")
                ])]))
            return SequenceItem(elements: elements)
        }
        dataSet[.graphicAnnotationSequence] = DataElement(
            tag: .graphicAnnotationSequence, vr: .SQ, length: 0, valueData: Data(),
            sequenceItems: rebuilt)

        let parsed = try GrayscalePresentationStateParser().parse(dataSet: dataSet)
        XCTAssertEqual(parsed.graphicAnnotations.first?.textObjects.first?.text, "Legacy")
    }

    func test_build_omitsAnnotationSequencesWhenNothingIsDrawn() {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state(),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)

        XCTAssertNil(dataSet[.graphicLayerSequence])
        XCTAssertNil(dataSet[.graphicAnnotationSequence])
    }

    // MARK: - Content Label

    /// Content Label is type 1 and CS-valued. A reader typing an ordinary name
    /// must still produce a conformant object.
    func test_contentLabel_foldsUserTextToLegalCS() {
        XCTAssertEqual(
            GrayscalePresentationStateBuilder.contentLabel(from: "Lung window"),
            "LUNG WINDOW")
        XCTAssertEqual(
            GrayscalePresentationStateBuilder.contentLabel(from: "bone+zoom"),
            "BONE_ZOOM")
    }

    func test_contentLabel_truncatesToSixteenCharacters() {
        let label = GrayscalePresentationStateBuilder.contentLabel(
            from: "A very long presentation state name")
        XCTAssertLessThanOrEqual(label.count, 16)
    }

    func test_contentLabel_fallsBackWhenEmpty() {
        XCTAssertEqual(
            GrayscalePresentationStateBuilder.contentLabel(from: nil), "PRESENTATION")
        XCTAssertEqual(
            GrayscalePresentationStateBuilder.contentLabel(from: ""), "PRESENTATION")
        // Folds to underscores only, which would be a meaningless label.
        XCTAssertEqual(
            GrayscalePresentationStateBuilder.contentLabel(from: "   "), "PRESENTATION")
    }

    /// The human-readable name survives in full even when Content Label had to
    /// be folded, which is what the picker shows.
    func test_build_keepsUnfoldedLabelInContentDescription() {
        let dataSet = GrayscalePresentationStateBuilder().buildDataSet(
            from: state(label: "Lung window (thin)"),
            patient: context(),
            seriesInstanceUID: "1.2.3.4.5.900",
            seriesNumber: 900)

        XCTAssertEqual(dataSet.string(for: .contentDescription), "Lung window (thin)")
    }

    // MARK: - Decimal formatting

    func test_decimalString_writesWholeNumbersWithoutDecimalPoint() {
        XCTAssertEqual(GrayscalePresentationStateBuilder.decimalString(-600), "-600")
        XCTAssertEqual(GrayscalePresentationStateBuilder.decimalString(1500), "1500")
    }

    func test_decimalString_staysWithinDSLengthLimit() {
        let value = GrayscalePresentationStateBuilder.decimalString(1234.56789012345)
        XCTAssertLessThanOrEqual(value.count, 16)
    }
}
