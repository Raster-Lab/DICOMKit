//
// PrintSCPTests.swift
// DICOMNetworkTests
//
// Tests for the Print SCP (printer emulator): the data-set walker, the
// attribute parser, the Image Display Format grammar, and — the strongest and
// cheapest check available — a loopback end-to-end run of the existing Print
// SCU against the new SCP in-process.
//

import XCTest
import DICOMCore
@testable import DICOMNetwork

final class PrintDatasetReaderTests: XCTestCase {

    /// Serializes elements the way the SCU does, for both negotiated VRs.
    private func serialize(_ elements: [DataElement], explicitVR: Bool) -> Data {
        PrintSCPEncoder.serialize(elements, explicitVR: explicitVR)
    }

    func testWalksFlatElementsExplicitVR() throws {
        let data = serialize([
            DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: "STANDARD\\2,3"),
            DataElement.string(tag: .filmSizeID, vr: .CS, value: "14INX17IN"),
            DataElement.uint16(tag: .imageBoxPosition, value: 4)
        ], explicitVR: true)

        let set = try PrintDatasetReader(explicitVR: true).parse(data)
        XCTAssertEqual(set.string(for: .imageDisplayFormat), "STANDARD\\2,3")
        XCTAssertEqual(set.string(for: .filmSizeID), "14INX17IN")
        XCTAssertEqual(set.uint16(for: .imageBoxPosition), 4)
        XCTAssertNil(set.string(for: .trim))
    }

    func testWalksFlatElementsImplicitVR() throws {
        let data = serialize([
            DataElement.string(tag: .filmOrientation, vr: .CS, value: "LANDSCAPE"),
            DataElement.uint16(tag: .imageBoxPosition, value: 2)
        ], explicitVR: false)

        let set = try PrintDatasetReader(explicitVR: false).parse(data)
        XCTAssertEqual(set.string(for: .filmOrientation), "LANDSCAPE")
        // Implicit VR resolves US from the dictionary, not from the wire.
        XCTAssertEqual(set.uint16(for: .imageBoxPosition), 2)
    }

    func testWalksSequencesInBothVRs() throws {
        for explicitVR in [true, false] {
            let element = PrintSCPEncoder.referenceSequence(
                tag: .referencedImageBoxSequence,
                sopClassUID: basicGrayscaleImageBoxSOPClassUID,
                sopInstanceUIDs: ["1.2.3.1", "1.2.3.2", "1.2.3.3"])
            let data = serialize([element], explicitVR: explicitVR)

            let set = try PrintDatasetReader(explicitVR: explicitVR).parse(data)
            let items = set.items(for: .referencedImageBoxSequence)
            XCTAssertEqual(items.count, 3, "explicitVR=\(explicitVR)")
            XCTAssertEqual(items.map { $0.string(for: .referencedSOPInstanceUID) },
                           ["1.2.3.1", "1.2.3.2", "1.2.3.3"])
            XCTAssertEqual(items.first?.string(for: .referencedSOPClassUID),
                           basicGrayscaleImageBoxSOPClassUID)
        }
    }

    func testWalksUndefinedLengthSequence() throws {
        // Hand-encode (2010,0510) SQ with undefined length and one undefined
        // length item — the encoding a strict SCU may send, and one DICOMWriter
        // never produces, so it has to be exercised by hand.
        func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

        var uidValue = Data("1.2.3.4".utf8)
        uidValue.append(0x00) // even-length padding
        var content = le16(0x0008) + le16(0x1155)
        content += Data("UI".utf8) + le16(UInt16(uidValue.count)) + uidValue

        var data = le16(0x2010) + le16(0x0510) + Data("SQ".utf8) + le16(0)
        data += le32(0xFFFF_FFFF)                                  // undefined-length SQ
        data += le16(0xFFFE) + le16(0xE000) + le32(0xFFFF_FFFF)    // undefined-length item
        data += content
        data += le16(0xFFFE) + le16(0xE00D) + le32(0)              // item delimitation
        data += le16(0xFFFE) + le16(0xE0DD) + le32(0)              // sequence delimitation

        let set = try PrintDatasetReader(explicitVR: true).parse(data)
        let items = set.items(for: .referencedImageBoxSequence)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.string(for: .referencedSOPInstanceUID), "1.2.3.4")
    }

    func testRejectsElementLengthPastEndOfDataSet() {
        func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        // (0008,1155) UI with a declared length of 200 but only 4 bytes present.
        var data = le16(0x0008) + le16(0x1155) + Data("UI".utf8) + le16(200)
        data += Data([0x31, 0x2E, 0x32, 0x00])

        XCTAssertThrowsError(try PrintDatasetReader(explicitVR: true).parse(data)) { error in
            guard case PrintDatasetError.valueOverrunsContainer = error else {
                return XCTFail("Expected valueOverrunsContainer, got \(error)")
            }
        }
    }

    func testReadsLargePixelDataValue() throws {
        let pixels = Data(repeating: 0xAB, count: 512 * 512 * 2)
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .rows, value: 512),
            DataElement.uint16(tag: .columns, value: 512),
            DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        ])
        let sequence = DataElement(
            tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
            valueData: Data(), sequenceItems: [item])

        let set = try PrintDatasetReader(explicitVR: true).parse(serialize([sequence], explicitVR: true))
        let parsedItem = try XCTUnwrap(set.firstItem(of: .preformattedGrayscaleImageSequence))
        XCTAssertEqual(parsedItem.bytes(for: .pixelData)?.count, pixels.count)
        XCTAssertEqual(parsedItem.uint16(for: .rows), 512)
    }
}

final class PrintImageDisplayFormatTests: XCTestCase {

    func testStandardIsColumnsThenRows() {
        // PS3.3 C.13.3: "STANDARD\C,R" — columns first.
        let format = PrintImageDisplayFormat.parse("STANDARD\\2,3")
        XCTAssertEqual(format.kind, .standard(rows: 3, columns: 2))
        XCTAssertEqual(format.imageBoxCount, 6)
        XCTAssertEqual(format.layout, PrintLayout(rows: 3, columns: 2))
    }

    func testRowAndColumnFormatsSumTheirCounts() {
        let row = PrintImageDisplayFormat.parse("ROW\\2,3")
        XCTAssertEqual(row.kind, .row(counts: [2, 3]))
        XCTAssertEqual(row.imageBoxCount, 5)

        let column = PrintImageDisplayFormat.parse("COL\\1,2,3")
        XCTAssertEqual(column.kind, .column(counts: [1, 2, 3]))
        XCTAssertEqual(column.imageBoxCount, 6)
    }

    func testSlideAndCustomFormats() {
        XCTAssertEqual(PrintImageDisplayFormat.parse("SLIDE").imageBoxCount, 1)
        XCTAssertEqual(PrintImageDisplayFormat.parse("SUPERSLIDE").imageBoxCount, 1)
        XCTAssertEqual(PrintImageDisplayFormat.parse("CUSTOM\\1").kind, .custom(id: "1"))
        XCTAssertEqual(PrintImageDisplayFormat.parse("CUSTOM\\1").imageBoxCount, 1)
    }

    func testUnknownFormatFallsBackToSingleBox() {
        let format = PrintImageDisplayFormat.parse("NONSENSE")
        XCTAssertEqual(format.imageBoxCount, 1)
        XCTAssertEqual(format.layout, PrintLayout(rows: 1, columns: 1))
    }
}

final class PrintSCPParserTests: XCTestCase {

    private let configuration = PrintSCPConfiguration(aeTitle: try! AETitle("DCMPRINT"), port: 0)

    private func parse(_ elements: [DataElement], explicitVR: Bool = true) throws -> PrintAttributeSet {
        try PrintDatasetReader(explicitVR: explicitVR)
            .parse(PrintSCPEncoder.serialize(elements, explicitVR: explicitVR))
    }

    func testFilmSessionAttributesRoundTrip() throws {
        // Exactly the elements the SCU emits for a film session N-CREATE.
        let attributes = try parse([
            DataElement.string(tag: .numberOfCopies, vr: .IS, value: "3"),
            DataElement.string(tag: .printPriority, vr: .CS, value: "HIGH"),
            DataElement.string(tag: .mediumType, vr: .CS, value: "BLUE FILM"),
            DataElement.string(tag: .filmDestination, vr: .CS, value: "MAGAZINE"),
            DataElement.string(tag: .filmSessionLabel, vr: .LO, value: "STUDY-42")
        ])

        var session = FilmSession(sopInstanceUID: "1.2.3")
        try PrintSCPParser.applyFilmSession(attributes, to: &session, configuration: configuration)

        XCTAssertEqual(session.numberOfCopies, 3)
        XCTAssertEqual(session.printPriority, .high)
        XCTAssertEqual(session.mediumType, .blueFilm)
        XCTAssertEqual(session.filmDestination, .magazine)
        XCTAssertEqual(session.filmSessionLabel, "STUDY-42")
    }

    func testFilmBoxAttributesRoundTrip() throws {
        let attributes = try parse([
            DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: "STANDARD\\2,2"),
            DataElement.string(tag: .filmOrientation, vr: .CS, value: "LANDSCAPE"),
            DataElement.string(tag: .filmSizeID, vr: .CS, value: "14INX17IN"),
            DataElement.string(tag: .magnificationType, vr: .CS, value: "BILINEAR"),
            DataElement.string(tag: .borderDensity, vr: .CS, value: "WHITE"),
            DataElement.string(tag: .emptyImageDensity, vr: .CS, value: "BLACK"),
            DataElement.string(tag: .trim, vr: .CS, value: "YES"),
            DataElement.uint16(tag: .minDensity, value: 20),
            DataElement.uint16(tag: .maxDensity, value: 300),
            DataElement.string(tag: .annotationDisplayFormatID, vr: .CS, value: "ANNO1")
        ])

        var box = PrintSCPParser.FilmBoxAttributes(filmBox: FilmBox(sopInstanceUID: "1.2.4"))
        try PrintSCPParser.applyFilmBox(attributes, to: &box, configuration: configuration)

        XCTAssertEqual(box.filmBox.filmOrientation, .landscape)
        XCTAssertEqual(box.filmBox.filmSizeID, .size14InX17In)
        XCTAssertEqual(box.filmBox.magnificationType, .bilinear)
        XCTAssertEqual(box.filmBox.borderDensity, "WHITE")
        XCTAssertEqual(box.filmBox.trimOption, .yes)
        XCTAssertEqual(box.minDensity, 20)
        XCTAssertEqual(box.maxDensity, 300)
        XCTAssertEqual(box.annotationDisplayFormatID, "ANNO1")
    }

    func testUnsupportedFilmSizeIsRejected() throws {
        let restricted = PrintSCPConfiguration(
            aeTitle: try AETitle("DCMPRINT"), port: 0, supportedFilmSizes: [.a4])
        let attributes = try parse([
            DataElement.string(tag: .filmSizeID, vr: .CS, value: "14INX17IN")
        ])

        var box = PrintSCPParser.FilmBoxAttributes(filmBox: FilmBox())
        XCTAssertThrowsError(
            try PrintSCPParser.applyFilmBox(attributes, to: &box, configuration: restricted)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .invalidAttributeValue)
        }
    }

    func testUnknownEnumeratedValueIsRejected() throws {
        let attributes = try parse([
            DataElement.string(tag: .polarity, vr: .CS, value: "SIDEWAYS")
        ])
        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.5", isColor: false,
                existing: ImageBoxContent(), configuration: configuration)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .invalidAttributeValue)
        }
    }

    /// The SCU builds `PrintImageData`; the SCP reads it back. The round trip
    /// must be lossless — this is the parser's core contract.
    func testImageBoxPixelModuleRoundTripsThroughBothVRs() throws {
        let descriptor = PrintImageData(
            pixelData: Data((0..<64).map { UInt8($0) }),
            rows: 8, columns: 8,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME1")

        for explicitVR in [true, false] {
            let item = SequenceItem(elements: [
                DataElement.uint16(tag: .samplesPerPixel, value: descriptor.samplesPerPixel),
                DataElement.string(tag: .photometricInterpretation, vr: .CS,
                                   value: descriptor.photometricInterpretation),
                DataElement.uint16(tag: .rows, value: descriptor.rows),
                DataElement.uint16(tag: .columns, value: descriptor.columns),
                DataElement.uint16(tag: .bitsAllocated, value: descriptor.bitsAllocated),
                DataElement.uint16(tag: .bitsStored, value: descriptor.bitsStored),
                DataElement.uint16(tag: .highBit, value: descriptor.highBit),
                DataElement.uint16(tag: .pixelRepresentation, value: descriptor.pixelRepresentation),
                DataElement.data(tag: .pixelData, vr: .OW, data: descriptor.pixelData)
            ])
            let attributes = try parse([
                DataElement.uint16(tag: .imageBoxPosition, value: 2),
                DataElement.string(tag: .polarity, vr: .CS, value: "REVERSE"),
                DataElement.string(tag: .requestedDecimateCropBehavior, vr: .CS, value: "CROP"),
                DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                            valueData: Data(), sequenceItems: [item])
            ], explicitVR: explicitVR)

            let parsed = try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.6", isColor: false,
                existing: ImageBoxContent(sopInstanceUID: "1.2.6"),
                configuration: configuration)

            XCTAssertEqual(parsed.image, descriptor, "explicitVR=\(explicitVR)")
            XCTAssertEqual(parsed.content.imagePosition, 2)
            XCTAssertEqual(parsed.content.polarity, .reverse)
            XCTAssertEqual(parsed.content.requestedDecimateCropBehavior, .crop)
        }
    }

    func testColorImageBoxAcceptsThreeSamples() throws {
        let pixels = Data(repeating: 0x7F, count: 4 * 4 * 3)
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .samplesPerPixel, value: 3),
            DataElement.string(tag: .photometricInterpretation, vr: .CS, value: "RGB"),
            DataElement.uint16(tag: .rows, value: 4),
            DataElement.uint16(tag: .columns, value: 4),
            DataElement.uint16(tag: .bitsAllocated, value: 8),
            DataElement.uint16(tag: .bitsStored, value: 8),
            DataElement.uint16(tag: .highBit, value: 7),
            DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedColorImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        let parsed = try PrintSCPParser.parseImageBox(
            attributes, sopInstanceUID: "1.2.7", isColor: true,
            existing: ImageBoxContent(), configuration: configuration)
        XCTAssertEqual(parsed.image?.samplesPerPixel, 3)
        XCTAssertEqual(parsed.image?.photometricInterpretation, "RGB")
    }

    func testGrayscaleImageBoxRejectsThreeSamples() throws {
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .samplesPerPixel, value: 3),
            DataElement.uint16(tag: .rows, value: 4),
            DataElement.uint16(tag: .columns, value: 4),
            DataElement.uint16(tag: .bitsAllocated, value: 8),
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 48))
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.8", isColor: false,
                existing: ImageBoxContent(), configuration: configuration)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .invalidAttributeValue)
        }
    }

    func testInvalidBitsAllocatedIsRejected() throws {
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .rows, value: 4),
            DataElement.uint16(tag: .columns, value: 4),
            DataElement.uint16(tag: .bitsAllocated, value: 12),
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 32))
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.9", isColor: false,
                existing: ImageBoxContent(), configuration: configuration)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .invalidAttributeValue)
        }
    }

    func testMissingRowsIsRejectedAsMissingAttribute() throws {
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .columns, value: 4),
            DataElement.uint16(tag: .bitsAllocated, value: 8),
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 16))
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.10", isColor: false,
                existing: ImageBoxContent(), configuration: configuration)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .missingAttribute)
        }
    }

    func testOversizedImageIsRejectedWithImageLargerThanImageBox() throws {
        let small = PrintSCPConfiguration(
            aeTitle: try AETitle("DCMPRINT"), port: 0, maxImageBoxPixelDimension: 16)
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .rows, value: 64),
            DataElement.uint16(tag: .columns, value: 64),
            DataElement.uint16(tag: .bitsAllocated, value: 8),
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 64 * 64))
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.11", isColor: false,
                existing: ImageBoxContent(), configuration: small)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .imageLargerThanImageBox)
        }
    }

    func testTruncatedPixelDataIsRejected() throws {
        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .rows, value: 8),
            DataElement.uint16(tag: .columns, value: 8),
            DataElement.uint16(tag: .bitsAllocated, value: 16),
            // 8×8×2 = 128 bytes required; only 64 supplied.
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0, count: 64))
        ])
        let attributes = try parse([
            DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                        valueData: Data(), sequenceItems: [item])
        ])

        XCTAssertThrowsError(
            try PrintSCPParser.parseImageBox(
                attributes, sopInstanceUID: "1.2.12", isColor: false,
                existing: ImageBoxContent(), configuration: configuration)
        ) { error in
            XCTAssertEqual((error as? PrintSCPFailure)?.status, .invalidAttributeValue)
        }
    }
}

final class PrintSCPEncoderTests: XCTestCase {

    /// What the encoder writes, the reader must read — in both VRs.
    func testFilmBoxCreateResponseRoundTrips() throws {
        for explicitVR in [true, false] {
            let data = PrintSCPEncoder.filmBoxCreateResponse(
                filmSessionUID: "1.2.100",
                imageBoxSOPClassUID: basicGrayscaleImageBoxSOPClassUID,
                imageBoxUIDs: ["1.2.101", "1.2.102"],
                explicitVR: explicitVR)

            let set = try PrintDatasetReader(explicitVR: explicitVR).parse(data)
            XCTAssertEqual(
                set.items(for: .referencedFilmSessionSequence)
                    .compactMap { $0.string(for: .referencedSOPInstanceUID) },
                ["1.2.100"])
            XCTAssertEqual(
                set.items(for: .referencedImageBoxSequence)
                    .compactMap { $0.string(for: .referencedSOPInstanceUID) },
                ["1.2.101", "1.2.102"])
        }
    }

    /// The SCU's own printer-status parser must understand what we emit —
    /// otherwise the loopback path silently reports "UNKNOWN".
    func testPrinterAttributesAreReadableByTheSCUParser() throws {
        let configuration = PrintSCPConfiguration(
            aeTitle: try AETitle("DCMPRINT"), port: 0,
            printerName: "EMULATOR-1", manufacturer: "DICOMKit",
            manufacturerModelName: "Print Emulator")
        let data = PrintSCPEncoder.printerAttributes(
            configuration: configuration,
            status: PrinterStatus(status: "NORMAL", statusInfo: "READY"),
            explicitVR: true)

        let status = DICOMPrintService.parsePrinterStatus(from: data, explicitVR: true)
        XCTAssertEqual(status.status, "NORMAL")
        XCTAssertEqual(status.statusInfo, "READY")
        XCTAssertEqual(status.printerName, "EMULATOR-1")
        XCTAssertEqual(status.manufacturer, "DICOMKit")
        XCTAssertEqual(status.manufacturerModelName, "Print Emulator")
    }

    func testPrintJobAttributesRoundTrip() throws {
        let job = PrintSCPJobRecord(
            printJobUID: "1.2.200", filmBoxUID: "1.2.201", filmSessionUID: "1.2.202",
            executionStatus: "DONE", executionStatusInfo: "NORMAL",
            printPriority: .high, numberOfCopies: 2)
        let data = PrintSCPEncoder.printJobAttributes(
            job, printerName: "EMULATOR-1", explicitVR: true)

        let set = try PrintDatasetReader(explicitVR: true).parse(data)
        XCTAssertEqual(set.string(for: .executionStatus), "DONE")
        XCTAssertEqual(set.string(for: .executionStatusInfo), "NORMAL")
        XCTAssertEqual(set.string(for: .printPriority), "HIGH")
        XCTAssertEqual(set.integer(for: .numberOfCopies), 2)
        XCTAssertEqual(set.string(for: .printerName), "EMULATOR-1")
    }
}

#if canImport(Network)

/// Loopback end-to-end: the shipped Print SCU driving the new Print SCP
/// in-process. This is the checkpoint the plan calls for after Milestones A+B.
final class PrintSCPLoopbackTests: XCTestCase {

    private var server: DICOMPrintServer!
    private var handler: CollectingPrintHandler!
    private var port: UInt16 = 0

    private static let calledAE = "DCMPRINT"

    override func setUp() async throws {
        try await super.setUp()
        handler = CollectingPrintHandler()
        server = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle(Self.calledAE),
                port: 0, // ephemeral: no port races between tests
                maxPDUSize: 65536),
            delegate: handler)
        try await server.start()
        port = await server.boundPort
        XCTAssertNotEqual(port, 0)
    }

    override func tearDown() async throws {
        await server?.stop()
        server = nil
        handler = nil
        try await super.tearDown()
    }

    private func configuration(colorMode: PrintColorMode = .grayscale) -> PrintConfiguration {
        PrintConfiguration(
            host: "127.0.0.1", port: port,
            callingAETitle: "TEST_SCU", calledAETitle: Self.calledAE,
            timeout: 15, colorMode: colorMode)
    }

    /// A gradient image whose bytes are distinctive enough to assert on.
    private func makeImage(size: UInt16 = 8) -> (Data, PrintImageData) {
        let count = Int(size) * Int(size)
        let pixels = Data((0..<count).map { UInt8($0 % 256) })
        return (pixels, PrintImageData(
            pixelData: pixels, rows: size, columns: size,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 1, pixelRepresentation: 0,
            photometricInterpretation: "MONOCHROME2"))
    }

    func testPrinterStatusQuery() async throws {
        await handler.setStatus(PrinterStatus(status: "NORMAL", statusInfo: "READY"))
        let status = try await DICOMPrintService.getPrinterStatus(configuration: configuration())
        XCTAssertEqual(status.status, "NORMAL")
        XCTAssertEqual(status.statusInfo, "READY")
        XCTAssertTrue(status.isNormal)
    }

    func testSingleImagePrintDeliversTheFilm() async throws {
        let (pixels, descriptor) = makeImage()
        let result = try await DICOMPrintService.printImages(
            configuration: configuration(),
            images: [pixels],
            options: PrintOptions(numberOfCopies: 2, filmSize: .size14InX17In,
                                  filmOrientation: .landscape, sessionLabel: "LOOPBACK"),
            imageDescriptors: [descriptor])

        XCTAssertTrue(result.success, result.errorMessage ?? "")
        XCTAssertNotNil(result.printJobUID)

        let films = await handler.films
        XCTAssertEqual(films.count, 1)
        let film = try XCTUnwrap(films.first)
        XCTAssertEqual(film.callingAETitle, "TEST_SCU")
        XCTAssertEqual(film.filmSession.numberOfCopies, 2)
        XCTAssertEqual(film.filmSession.filmSessionLabel, "LOOPBACK")
        XCTAssertEqual(film.filmBox.filmSizeID, .size14InX17In)
        XCTAssertEqual(film.filmBox.filmOrientation, .landscape)
        XCTAssertEqual(film.imageBoxes.count, 1)
        XCTAssertEqual(film.filledImageBoxes.count, 1)
        // The pixels the SCU sent are exactly the pixels the SCP hands over.
        XCTAssertEqual(film.imageBoxes.first?.image, descriptor)
        XCTAssertEqual(film.printJobUID, result.printJobUID)
    }

    func testMultiImageLayoutAllocatesOneBoxPerImage() async throws {
        let images = (0..<4).map { _ in makeImage(size: 4) }
        let result = try await DICOMPrintService.printImages(
            configuration: configuration(),
            images: images.map { $0.0 },
            options: .default,
            imageDescriptors: images.map { $0.1 },
            layout: PrintLayout(rows: 2, columns: 2))

        XCTAssertTrue(result.success, result.errorMessage ?? "")
        let films = await handler.films
        XCTAssertEqual(films.count, 1)
        let film = try XCTUnwrap(films.first)
        XCTAssertEqual(film.imageBoxes.count, 4)
        XCTAssertEqual(film.filledImageBoxes.count, 4)
        XCTAssertEqual(film.imageBoxes.map { $0.content.imagePosition }, [1, 2, 3, 4])
    }

    func testColorPrintUsesTheColorImageBoxSOPClass() async throws {
        let pixels = Data(repeating: 0x40, count: 4 * 4 * 3)
        let descriptor = PrintImageData(
            pixelData: pixels, rows: 4, columns: 4,
            bitsAllocated: 8, bitsStored: 8, highBit: 7,
            samplesPerPixel: 3, pixelRepresentation: 0,
            photometricInterpretation: "RGB")

        let result = try await DICOMPrintService.printImages(
            configuration: configuration(colorMode: .color),
            images: [pixels], options: .default, imageDescriptors: [descriptor])

        XCTAssertTrue(result.success, result.errorMessage ?? "")
        let films = await handler.films
        let film = try XCTUnwrap(films.first)
        XCTAssertEqual(film.imageBoxes.first?.sopClassUID, basicColorImageBoxSOPClassUID)
        XCTAssertTrue(film.imageBoxes.first?.isColor ?? false)
        XCTAssertEqual(film.imageBoxes.first?.image, descriptor)
    }

    func testPresentationLUTShapeReachesTheFilm() async throws {
        let (pixels, descriptor) = makeImage(size: 4)
        let result = try await DICOMPrintService.printImages(
            configuration: configuration(),
            images: [pixels],
            options: PrintOptions(presentationLUTShape: .inverse),
            imageDescriptors: [descriptor])

        XCTAssertTrue(result.success, result.errorMessage ?? "")
        let films = await handler.films
        let film = try XCTUnwrap(films.first)
        XCTAssertEqual(film.presentationLUTShape, .inverse)
    }

    func testAnnotationsReachTheFilm() async throws {
        let (pixels, descriptor) = makeImage(size: 4)
        let result = try await DICOMPrintService.printImages(
            configuration: configuration(),
            images: [pixels],
            options: PrintOptions(
                annotations: [PrintAnnotation(position: 1, text: "DOE^JANE")],
                annotationDisplayFormatID: "ANNO1"),
            imageDescriptors: [descriptor])

        XCTAssertTrue(result.success, result.errorMessage ?? "")
        let films = await handler.films
        let film = try XCTUnwrap(films.first)
        XCTAssertEqual(film.annotationDisplayFormatID, "ANNO1")
        XCTAssertEqual(film.annotations, [PrintAnnotation(position: 1, text: "DOE^JANE")])
    }

    func testDelegateFailurePropagatesToTheSCU() async throws {
        let failing = FailingPrintHandler()
        let failingServer = DICOMPrintServer(
            configuration: PrintSCPConfiguration(aeTitle: try AETitle("FAILSCP"), port: 0),
            delegate: failing)
        try await failingServer.start()
        defer { Task { await failingServer.stop() } }
        let failingPort = await failingServer.boundPort

        let (pixels, descriptor) = makeImage(size: 4)
        do {
            _ = try await DICOMPrintService.printImages(
                configuration: PrintConfiguration(
                    host: "127.0.0.1", port: failingPort,
                    callingAETitle: "TEST_SCU", calledAETitle: "FAILSCP", timeout: 15),
                images: [pixels], options: .default, imageDescriptors: [descriptor])
            XCTFail("Expected the N-ACTION failure to surface to the SCU")
        } catch DICOMNetworkError.printOperationFailed(let status, let detail) {
            // The delegate's refusal must arrive as 0x0110 with the SCP's
            // Error Comment attached, not as a generic transport error.
            XCTAssertEqual(status.rawValue, PrintSCPStatus.processingFailure.rawValue)
            XCTAssertEqual(detail?.contains("SinkError") ?? false, true, detail ?? "no detail")
        }
    }

    func testAssociationIsRejectedForUnknownCalledAE() async throws {
        let (pixels, descriptor) = makeImage(size: 4)
        do {
            _ = try await DICOMPrintService.printImages(
                configuration: PrintConfiguration(
                    host: "127.0.0.1", port: port,
                    callingAETitle: "TEST_SCU", calledAETitle: "WRONG_AE", timeout: 10),
                images: [pixels], options: .default, imageDescriptors: [descriptor])
            XCTFail("Expected the association to be rejected")
        } catch {
            // Any association-level failure is acceptable; what matters is that
            // no film was produced.
            let films = await handler.films
            XCTAssertTrue(films.isEmpty)
        }
    }

    func testCallingAEBlacklistRejectsTheAssociation() async throws {
        let blocked = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle("BLOCKSCP"), port: 0,
                callingAEBlacklist: ["TEST_SCU"]),
            delegate: CollectingPrintHandler())
        try await blocked.start()
        defer { Task { await blocked.stop() } }
        let blockedPort = await blocked.boundPort

        let (pixels, descriptor) = makeImage(size: 4)
        do {
            _ = try await DICOMPrintService.printImages(
                configuration: PrintConfiguration(
                    host: "127.0.0.1", port: blockedPort,
                    callingAETitle: "TEST_SCU", calledAETitle: "BLOCKSCP", timeout: 10),
                images: [pixels], options: .default, imageDescriptors: [descriptor])
            XCTFail("Expected the blacklisted calling AE to be rejected")
        } catch {
            // Expected.
        }
    }
}

/// A delegate that always refuses the film, to exercise the failure path.
private struct FailingPrintHandler: PrintSCPDelegate {
    struct SinkError: Error {}
    func didReceiveFilm(_ film: ReceivedFilm) async throws { throw SinkError() }
}

#endif

#if canImport(Network)

/// A minimal raw-DIMSE Print SCU used to drive the SCP into states the shipped
/// ``DICOMPrintService`` never produces (unknown UIDs, duplicate sessions,
/// printing an empty film box). One association, one presentation context.
private actor RawPrintSCU {
    private let association: Association
    private var negotiated: NegotiatedAssociation!
    private var messageID: UInt16 = 1

    init(port: UInt16, calledAE: String, callingAE: String = "RAW_SCU") throws {
        association = Association(configuration: AssociationConfiguration(
            callingAETitle: try AETitle(callingAE),
            calledAETitle: try AETitle(calledAE),
            host: "127.0.0.1",
            port: port,
            implementationClassUID: PrintSCPConfiguration.defaultImplementationClassUID,
            implementationVersionName: "RAW_TEST_SCU",
            timeout: 15))
    }

    func connect() async throws {
        let context = try PresentationContext(
            id: 1,
            abstractSyntax: basicGrayscalePrintManagementMetaSOPClassUID,
            transferSyntaxes: [explicitVRLittleEndianTransferSyntaxUID])
        negotiated = try await association.request(presentationContexts: [context])
    }

    func release() async {
        try? await association.release()
    }

    /// Sends one N-service request and returns the response command set.
    func send(_ commandSet: CommandSet, dataSet: Data? = nil) async throws -> AssembledMessage {
        let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
        for pdu in fragmenter.fragmentMessage(
            commandSet: commandSet, dataSet: dataSet, presentationContextID: 1) {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        var assembler = MessageAssembler()
        while true {
            let pdu = try await association.receive()
            if let message = try assembler.addPDVs(from: pdu) { return message }
        }
    }

    private func nextMessageID() -> UInt16 {
        defer { messageID += 1 }
        return messageID
    }

    func nCreate(sopClass: String, elements: [DataElement] = []) async throws -> AssembledMessage {
        let dataSet = elements.isEmpty ? nil : PrintSCPEncoder.serialize(elements, explicitVR: true)
        var command = CommandSet()
        command.setCommand(.nCreateRequest)
        command.setMessageID(nextMessageID())
        command.setAffectedSOPClassUID(sopClass)
        command.setHasDataSet(dataSet != nil)
        return try await send(command, dataSet: dataSet)
    }

    func nSet(sopClass: String, sopInstance: String, elements: [DataElement]) async throws -> AssembledMessage {
        let dataSet = PrintSCPEncoder.serialize(elements, explicitVR: true)
        var command = CommandSet()
        command.setCommand(.nSetRequest)
        command.setMessageID(nextMessageID())
        command.setRequestedSOPClassUID(sopClass)
        command.setRequestedSOPInstanceUID(sopInstance)
        command.setHasDataSet(true)
        return try await send(command, dataSet: dataSet)
    }

    func nAction(sopClass: String, sopInstance: String, actionTypeID: UInt16 = 1) async throws -> AssembledMessage {
        var command = CommandSet()
        command.setCommand(.nActionRequest)
        command.setMessageID(nextMessageID())
        command.setRequestedSOPClassUID(sopClass)
        command.setRequestedSOPInstanceUID(sopInstance)
        command.setActionTypeID(actionTypeID)
        command.setHasDataSet(false)
        return try await send(command)
    }

    func nDelete(sopClass: String, sopInstance: String) async throws -> AssembledMessage {
        var command = CommandSet()
        command.setCommand(.nDeleteRequest)
        command.setMessageID(nextMessageID())
        command.setRequestedSOPClassUID(sopClass)
        command.setRequestedSOPInstanceUID(sopInstance)
        command.setHasDataSet(false)
        return try await send(command)
    }

    func nGet(sopClass: String, sopInstance: String) async throws -> AssembledMessage {
        var command = CommandSet()
        command.setCommand(.nGetRequest)
        command.setMessageID(nextMessageID())
        command.setRequestedSOPClassUID(sopClass)
        command.setRequestedSOPInstanceUID(sopInstance)
        command.setHasDataSet(false)
        return try await send(command)
    }
}

/// PS3.4 H.4 status-code matrix — the cases the high-level SCU cannot produce.
final class PrintSCPStatusMatrixTests: XCTestCase {

    private var server: DICOMPrintServer!
    private var scu: RawPrintSCU!
    private static let calledAE = "DCMPRINT"

    override func setUp() async throws {
        try await super.setUp()
        server = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle(Self.calledAE), port: 0,
                supportedFilmSizes: [.a4, .size8InX10In],
                maxImageBoxesPerFilm: 8),
            delegate: CollectingPrintHandler())
        try await server.start()
        scu = try RawPrintSCU(port: await server.boundPort, calledAE: Self.calledAE)
        try await scu.connect()
    }

    override func tearDown() async throws {
        await scu?.release()
        scu = nil
        await server?.stop()
        server = nil
        try await super.tearDown()
    }

    private func status(_ message: AssembledMessage) -> UInt16 {
        message.commandSet.status?.rawValue ?? 0xFFFF
    }

    private func createSession() async throws -> String {
        let response = try await scu.nCreate(sopClass: basicFilmSessionSOPClassUID)
        XCTAssertEqual(status(response), PrintSCPStatus.success.rawValue)
        return try XCTUnwrap(response.commandSet.affectedSOPInstanceUID)
    }

    private func createFilmBox(format: String = "STANDARD\\1,1") async throws -> (String, [String]) {
        let response = try await scu.nCreate(
            sopClass: basicFilmBoxSOPClassUID,
            elements: [DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: format)])
        XCTAssertEqual(status(response), PrintSCPStatus.success.rawValue)
        let uid = try XCTUnwrap(response.commandSet.affectedSOPInstanceUID)
        let set = try PrintDatasetReader(explicitVR: true).parse(try XCTUnwrap(response.dataSet))
        let boxes = set.items(for: .referencedImageBoxSequence)
            .compactMap { $0.string(for: .referencedSOPInstanceUID) }
        return (uid, boxes)
    }

    func testSecondFilmSessionIsRejectedAsDuplicate() async throws {
        _ = try await createSession()
        let second = try await scu.nCreate(sopClass: basicFilmSessionSOPClassUID)
        XCTAssertEqual(status(second), PrintSCPStatus.duplicateSOPInstance.rawValue)
    }

    func testFilmBoxBeforeFilmSessionIsRejected() async throws {
        let response = try await scu.nCreate(
            sopClass: basicFilmBoxSOPClassUID,
            elements: [DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: "STANDARD\\1,1")])
        XCTAssertEqual(status(response), PrintSCPStatus.unableToProcess.rawValue)
    }

    func testMissingImageDisplayFormatIsRejected() async throws {
        _ = try await createSession()
        let response = try await scu.nCreate(
            sopClass: basicFilmBoxSOPClassUID,
            elements: [DataElement.string(tag: .filmSizeID, vr: .CS, value: "A4")])
        XCTAssertEqual(status(response), PrintSCPStatus.missingAttribute.rawValue)
    }

    func testUnsupportedFilmSizeIsRejected() async throws {
        _ = try await createSession()
        let response = try await scu.nCreate(
            sopClass: basicFilmBoxSOPClassUID,
            elements: [
                DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: "STANDARD\\1,1"),
                DataElement.string(tag: .filmSizeID, vr: .CS, value: "14INX17IN")
            ])
        XCTAssertEqual(status(response), PrintSCPStatus.invalidAttributeValue.rawValue)
    }

    func testTooManyImageBoxesIsRejected() async throws {
        _ = try await createSession()
        let response = try await scu.nCreate(
            sopClass: basicFilmBoxSOPClassUID,
            elements: [DataElement.string(tag: .imageDisplayFormat, vr: .ST, value: "STANDARD\\4,4")])
        XCTAssertEqual(status(response), PrintSCPStatus.unableToProcess.rawValue)
    }

    func testNSetOnUnknownImageBoxIsNoSuchSOPInstance() async throws {
        _ = try await createSession()
        _ = try await createFilmBox()
        let response = try await scu.nSet(
            sopClass: basicGrayscaleImageBoxSOPClassUID,
            sopInstance: "1.2.826.0.1.99.does.not.exist",
            elements: [DataElement.uint16(tag: .imageBoxPosition, value: 1)])
        XCTAssertEqual(status(response), PrintSCPStatus.noSuchSOPInstance.rawValue)
    }

    func testPrintingAFilmBoxWithNoImagesIsRejected() async throws {
        _ = try await createSession()
        let (filmBoxUID, _) = try await createFilmBox()
        let response = try await scu.nAction(
            sopClass: basicFilmBoxSOPClassUID, sopInstance: filmBoxUID)
        XCTAssertEqual(status(response), PrintSCPStatus.unableToProcess.rawValue)
    }

    func testUnsupportedActionTypeIsRejected() async throws {
        _ = try await createSession()
        let (filmBoxUID, _) = try await createFilmBox()
        let response = try await scu.nAction(
            sopClass: basicFilmBoxSOPClassUID, sopInstance: filmBoxUID, actionTypeID: 7)
        XCTAssertEqual(status(response), PrintSCPStatus.invalidAttributeValue.rawValue)
    }

    func testDeletingAFilmBoxTwiceReportsNoSuchSOPInstance() async throws {
        _ = try await createSession()
        let (filmBoxUID, imageBoxUIDs) = try await createFilmBox()

        let first = try await scu.nDelete(
            sopClass: basicFilmBoxSOPClassUID, sopInstance: filmBoxUID)
        XCTAssertEqual(status(first), PrintSCPStatus.success.rawValue)

        let second = try await scu.nDelete(
            sopClass: basicFilmBoxSOPClassUID, sopInstance: filmBoxUID)
        XCTAssertEqual(status(second), PrintSCPStatus.noSuchSOPInstance.rawValue)

        // The delete cascades: the film box's image boxes are gone too.
        let orphan = try await scu.nSet(
            sopClass: basicGrayscaleImageBoxSOPClassUID,
            sopInstance: try XCTUnwrap(imageBoxUIDs.first),
            elements: [DataElement.uint16(tag: .imageBoxPosition, value: 1)])
        XCTAssertEqual(status(orphan), PrintSCPStatus.noSuchSOPInstance.rawValue)
    }

    func testPrintJobNGetReturnsExecutionStatus() async throws {
        _ = try await createSession()
        let (filmBoxUID, imageBoxUIDs) = try await createFilmBox()

        let item = SequenceItem(elements: [
            DataElement.uint16(tag: .samplesPerPixel, value: 1),
            DataElement.string(tag: .photometricInterpretation, vr: .CS, value: "MONOCHROME2"),
            DataElement.uint16(tag: .rows, value: 4),
            DataElement.uint16(tag: .columns, value: 4),
            DataElement.uint16(tag: .bitsAllocated, value: 8),
            DataElement.uint16(tag: .bitsStored, value: 8),
            DataElement.uint16(tag: .highBit, value: 7),
            DataElement.uint16(tag: .pixelRepresentation, value: 0),
            DataElement.data(tag: .pixelData, vr: .OW, data: Data(repeating: 0x20, count: 16))
        ])
        let setResponse = try await scu.nSet(
            sopClass: basicGrayscaleImageBoxSOPClassUID,
            sopInstance: try XCTUnwrap(imageBoxUIDs.first),
            elements: [
                DataElement.uint16(tag: .imageBoxPosition, value: 1),
                DataElement(tag: .preformattedGrayscaleImageSequence, vr: .SQ, length: 0,
                            valueData: Data(), sequenceItems: [item])
            ])
        XCTAssertEqual(status(setResponse), PrintSCPStatus.success.rawValue)

        let printResponse = try await scu.nAction(
            sopClass: basicFilmBoxSOPClassUID, sopInstance: filmBoxUID)
        XCTAssertEqual(status(printResponse), PrintSCPStatus.success.rawValue)
        XCTAssertEqual(printResponse.commandSet.affectedSOPClassUID, printJobSOPClassUID)
        let jobUID = try XCTUnwrap(printResponse.commandSet.affectedSOPInstanceUID)

        let jobResponse = try await scu.nGet(sopClass: printJobSOPClassUID, sopInstance: jobUID)
        XCTAssertEqual(status(jobResponse), PrintSCPStatus.success.rawValue)
        let attributes = try PrintDatasetReader(explicitVR: true)
            .parse(try XCTUnwrap(jobResponse.dataSet))
        XCTAssertEqual(attributes.string(for: .executionStatus), "DONE")

        let unknownJob = try await scu.nGet(
            sopClass: printJobSOPClassUID, sopInstance: "1.2.826.0.1.99.no.such.job")
        XCTAssertEqual(status(unknownJob), PrintSCPStatus.noSuchSOPInstance.rawValue)
    }

    func testPrinterNGetReturnsStatus() async throws {
        let response = try await scu.nGet(
            sopClass: printerSOPClassUID, sopInstance: printerSOPInstanceUID)
        XCTAssertEqual(status(response), PrintSCPStatus.success.rawValue)
        let attributes = try PrintDatasetReader(explicitVR: true)
            .parse(try XCTUnwrap(response.dataSet))
        XCTAssertEqual(attributes.string(for: .printerStatus), "NORMAL")
    }

    func testUnsupportedSOPClassForNCreateIsRejected() async throws {
        let response = try await scu.nCreate(sopClass: "1.2.840.10008.5.1.4.1.1.7")
        XCTAssertEqual(status(response), PrintSCPStatus.sopClassNotSupported.rawValue)
    }
}

#endif

// MARK: - Interoperability hardening

/// Presentation-context negotiation: the SCU has to work with printers that
/// accept only the meta SOP Class, only the individual ones, or a subset.
final class PrintPresentationContextTests: XCTestCase {

    private func negotiate(accepting acceptedIDs: Set<UInt8>,
                           transferSyntax: String = explicitVRLittleEndianTransferSyntaxUID,
                           colorMode: PrintColorMode = .grayscale) throws -> PrintContextResolver {
        let proposed = try PrintPresentationContexts.propose(colorMode: colorMode)
        let accepted = proposed.map { context in
            acceptedIDs.contains(context.id)
                ? AcceptedPresentationContext(id: context.id, result: .acceptance,
                                              transferSyntax: transferSyntax)
                : AcceptedPresentationContext(id: context.id, result: .abstractSyntaxNotSupported)
        }
        let acceptPDU = AssociateAcceptPDU(
            calledAETitle: try AETitle("PRINTER"),
            callingAETitle: try AETitle("SCU"),
            presentationContexts: accepted,
            maxPDUSize: 16384,
            implementationClassUID: "1.2.3",
            implementationVersionName: nil)
        let negotiated = NegotiatedAssociation(acceptPDU: acceptPDU, localMaxPDUSize: 16384)
        return try PrintContextResolver(
            negotiated: negotiated, proposed: proposed, colorMode: colorMode)
    }

    func testProposesMetaAndIndividualSOPClassesWithOddIDs() throws {
        let proposed = try PrintPresentationContexts.propose(colorMode: .grayscale)
        XCTAssertEqual(proposed.count, 8)
        XCTAssertTrue(proposed.allSatisfy { $0.id % 2 == 1 }, "PS3.8: context IDs must be odd")
        XCTAssertEqual(Set(proposed.map(\.id)).count, proposed.count, "IDs must be unique")

        let syntaxes = Set(proposed.map(\.abstractSyntax))
        XCTAssertTrue(syntaxes.contains(basicGrayscalePrintManagementMetaSOPClassUID))
        XCTAssertTrue(syntaxes.contains(basicFilmSessionSOPClassUID))
        XCTAssertTrue(syntaxes.contains(basicFilmBoxSOPClassUID))
        XCTAssertTrue(syntaxes.contains(basicGrayscaleImageBoxSOPClassUID))
        XCTAssertTrue(syntaxes.contains(printerSOPClassUID))
        XCTAssertTrue(syntaxes.contains(printJobSOPClassUID))
        XCTAssertTrue(syntaxes.contains(presentationLUTSOPClassUID))
        XCTAssertTrue(syntaxes.contains(basicAnnotationBoxSOPClassUID))

        XCTAssertTrue(proposed.allSatisfy {
            $0.transferSyntaxes.contains(explicitVRLittleEndianTransferSyntaxUID)
                && $0.transferSyntaxes.contains(implicitVRLittleEndianTransferSyntaxUID)
        })
    }

    func testColorModeProposesTheColorMetaAndImageBoxClasses() throws {
        let proposed = try PrintPresentationContexts.propose(colorMode: .color)
        let syntaxes = Set(proposed.map(\.abstractSyntax))
        XCTAssertTrue(syntaxes.contains(basicColorPrintManagementMetaSOPClassUID))
        XCTAssertTrue(syntaxes.contains(basicColorImageBoxSOPClassUID))
        XCTAssertFalse(syntaxes.contains(basicGrayscalePrintManagementMetaSOPClassUID))
    }

    /// A printer that takes only the meta class — the common case.
    func testMetaOnlyPrinterRoutesEverythingThroughTheMetaContext() throws {
        let contexts = try negotiate(accepting: [PrintPresentationContexts.ID.meta])
        let meta = PrintPresentationContexts.ID.meta
        for sopClass in [basicFilmSessionSOPClassUID, basicFilmBoxSOPClassUID,
                         basicGrayscaleImageBoxSOPClassUID, printerSOPClassUID,
                         printJobSOPClassUID, presentationLUTSOPClassUID,
                         basicAnnotationBoxSOPClassUID] {
            XCTAssertEqual(try contexts.contextID(for: sopClass), meta, sopClass)
        }
    }

    /// A printer that rejects the meta class and takes the individual ones —
    /// the case the old single-context SCU could not talk to at all.
    func testIndividualOnlyPrinterRoutesEachServiceToItsOwnContext() throws {
        let contexts = try negotiate(accepting: [
            PrintPresentationContexts.ID.filmSession,
            PrintPresentationContexts.ID.filmBox,
            PrintPresentationContexts.ID.imageBox,
            PrintPresentationContexts.ID.printer,
            PrintPresentationContexts.ID.printJob
        ])
        XCTAssertEqual(try contexts.contextID(for: basicFilmSessionSOPClassUID),
                       PrintPresentationContexts.ID.filmSession)
        XCTAssertEqual(try contexts.contextID(for: basicFilmBoxSOPClassUID),
                       PrintPresentationContexts.ID.filmBox)
        XCTAssertEqual(try contexts.contextID(for: basicGrayscaleImageBoxSOPClassUID),
                       PrintPresentationContexts.ID.imageBox)
        XCTAssertEqual(try contexts.contextID(for: printerSOPClassUID),
                       PrintPresentationContexts.ID.printer)

        // Presentation LUT was refused and there is no meta context to fall back
        // on, so the optional feature is reported unsupported rather than being
        // sent on a context that cannot carry it.
        XCTAssertFalse(contexts.supports(presentationLUTSOPClassUID))
        XCTAssertThrowsError(try contexts.contextID(for: presentationLUTSOPClassUID))
    }

    func testIndividualContextIsPreferredOverTheMetaContext() throws {
        let contexts = try negotiate(accepting: [
            PrintPresentationContexts.ID.meta, PrintPresentationContexts.ID.imageBox
        ])
        XCTAssertEqual(try contexts.contextID(for: basicGrayscaleImageBoxSOPClassUID),
                       PrintPresentationContexts.ID.imageBox)
        XCTAssertEqual(try contexts.contextID(for: basicFilmSessionSOPClassUID),
                       PrintPresentationContexts.ID.meta)
    }

    func testPrinterThatAcceptsNothingFailsTheAssociation() {
        XCTAssertThrowsError(try negotiate(accepting: [])) { error in
            guard case DICOMNetworkError.sopClassNotSupported = error else {
                return XCTFail("Expected sopClassNotSupported, got \(error)")
            }
        }
    }

    func testImplicitVRIsReportedPerContext() throws {
        let contexts = try negotiate(
            accepting: [PrintPresentationContexts.ID.meta],
            transferSyntax: implicitVRLittleEndianTransferSyntaxUID)
        XCTAssertFalse(contexts.usesExplicitVR(PrintPresentationContexts.ID.meta))
    }
}

#if canImport(Network)

/// Listener robustness against peers that misbehave or vanish.
final class PrintSCPRobustnessTests: XCTestCase {

    /// A peer that opens an association and then goes silent must not hold its
    /// slot forever — `maxConcurrentAssociations` dead peers would wedge the
    /// printer.
    func testIdleAssociationIsClosedAfterTheTimeout() async throws {
        let server = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle("IDLESCP"), port: 0,
                associationIdleTimeout: 0.5),
            delegate: CollectingPrintHandler())
        try await server.start()
        defer { Task { await server.stop() } }

        let events = await server.events
        let timedOut = Task { () -> Bool in
            for await event in events {
                if case .associationTimedOut = event { return true }
            }
            return false
        }

        let scu = try RawPrintSCU(port: await server.boundPort, calledAE: "IDLESCP")
        try await scu.connect()
        // Establish, then say nothing at all.
        let count = await server.activeAssociationCount
        XCTAssertEqual(count, 1)

        try await Task.sleep(nanoseconds: 1_500_000_000)
        let closed = await timedOut.value
        XCTAssertTrue(closed, "Expected the idle association to be closed")

        // Give the completion handler a turn, then confirm the slot is free.
        try await Task.sleep(nanoseconds: 200_000_000)
        let remaining = await server.activeAssociationCount
        XCTAssertEqual(remaining, 0, "the timed-out association must release its slot")
    }

    /// An idle timeout must not fire while a job is actually in progress.
    func testActiveAssociationIsNotClosedByTheIdleTimeout() async throws {
        let handler = CollectingPrintHandler()
        let server = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle("BUSYSCP"), port: 0,
                associationIdleTimeout: 1.0),
            delegate: handler)
        try await server.start()
        defer { Task { await server.stop() } }

        let scu = try RawPrintSCU(port: await server.boundPort, calledAE: "BUSYSCP")
        try await scu.connect()

        // Three requests spaced under the deadline: the clock resets each time.
        for _ in 0..<3 {
            try await Task.sleep(nanoseconds: 600_000_000)
            let response = try await scu.nGet(
                sopClass: printerSOPClassUID, sopInstance: printerSOPInstanceUID)
            XCTAssertEqual(response.commandSet.status?.rawValue,
                           PrintSCPStatus.success.rawValue)
        }
        await scu.release()
    }

    /// At capacity the SCP must answer A-ASSOCIATE-RJ, not drop the socket:
    /// a modality can act on a transient rejection.
    func testAssociationBeyondTheLimitIsRejectedNotDropped() async throws {
        let server = DICOMPrintServer(
            configuration: PrintSCPConfiguration(
                aeTitle: try AETitle("ONESCP"), port: 0,
                maxConcurrentAssociations: 1,
                associationIdleTimeout: 30),
            delegate: CollectingPrintHandler())
        try await server.start()
        defer { Task { await server.stop() } }
        let port = await server.boundPort

        let first = try RawPrintSCU(port: port, calledAE: "ONESCP", callingAE: "SCU_ONE")
        try await first.connect()

        let second = try RawPrintSCU(port: port, calledAE: "ONESCP", callingAE: "SCU_TWO")
        do {
            try await second.connect()
            XCTFail("Expected the second association to be rejected")
        } catch DICOMNetworkError.associationRejected(let result, let source, let reason) {
            XCTAssertEqual(result, .rejectedTransient)
            XCTAssertEqual(source, .serviceProviderPresentation)
            XCTAssertEqual(reason, 2, "local-limit-exceeded")
        }

        await first.release()
    }
}

#endif

/// PS3.7 Annex C status classification for the DIMSE-N block.
///
/// Regression cover for a defect found by running our SCU against DCMTK's
/// print SCP: 0x0106 (Invalid Attribute Value) was classified as a warning, so
/// the SCU treated a printer's outright rejection of a film-session attribute
/// as success and failed two operations later with a misleading code.
final class DIMSENStatusClassificationTests: XCTestCase {

    func testInvalidAttributeValueIsAFailure() {
        let status = DIMSEStatus.from(0x0106)
        XCTAssertTrue(status.isFailure, "0x0106 Invalid Attribute Value is a failure")
        XCTAssertFalse(status.isWarning)
        XCTAssertFalse(status.isSuccessOrWarning,
                       "an SCU must stop, not continue, when an attribute is rejected")
    }

    func testDIMSENWarningsAreWarnings() {
        for code: UInt16 in [0x0001, 0x0107, 0x0116] {
            let status = DIMSEStatus.from(code)
            XCTAssertTrue(status.isWarning, String(format: "0x%04X should be a warning", code))
            XCTAssertTrue(status.isSuccessOrWarning, String(format: "0x%04X", code))
            XCTAssertFalse(status.isFailure, String(format: "0x%04X", code))
        }
    }

    func testDIMSENFailureBlockIsClassifiedAsFailure() {
        // Every print-relevant DIMSE-N failure code.
        for code: UInt16 in [0x0105, 0x0106, 0x0110, 0x0111, 0x0112,
                             0x0117, 0x0118, 0x0119, 0x0120, 0x0121, 0x0122] {
            let status = DIMSEStatus.from(code)
            XCTAssertTrue(status.isFailure, String(format: "0x%04X should be a failure", code))
            XCTAssertFalse(status.isSuccessOrWarning, String(format: "0x%04X", code))
        }
    }

    func testPrintSCPStatusAgreesWithDIMSEClassification() {
        // The SCP's own table and the shared wire classification must not drift.
        for status in PrintSCPStatus.allCases {
            XCTAssertEqual(
                status.isSuccessOrWarning,
                status.dimseStatus.isSuccessOrWarning,
                String(format: "0x%04X (%@)", status.rawValue, status.explanation))
        }
    }

    func testWarningRangeStillClassifiesPrintWarnings() {
        for status in [PrintSCPStatus.warningMemoryAllocation,
                       .warningMinMaxDensityOutOfRange,
                       .warningImageDemagnified,
                       .warningImageCropped] {
            XCTAssertTrue(status.dimseStatus.isWarning, status.explanation)
        }
    }
}
