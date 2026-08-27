// PrintColorDetectionTests.swift
// DICOMStudioTests
//
// Whether a job prints in colour.
//
// The sheet's colour mode decides which Print Management SOP class the job goes
// out on, and getting it wrong is not cosmetic: a colour study sent grayscale
// prints as greys, and colour pixels sent on a Basic Grayscale Image Box are
// rejected outright. Auto-detect therefore has to read the *images*, with the
// printer as the constraint — which is what these tests pin.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMNetwork
import DICOMKit
import DICOMCore
import DICOMPrintKit

@MainActor
@Suite("Print colour detection")
struct PrintColorDetectionTests {

    // MARK: Fixtures

    /// A throwaway directory holding real DICOM files, since detection reads
    /// Samples per Pixel off disk rather than trusting the mark.
    private func makeFixtureDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-colour-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes a minimal image whose photometric module says colour or grey.
    @discardableResult
    private func writeImage(
        named name: String, in directory: URL, color: Bool
    ) throws -> String {
        var dataSet = DataSet()
        dataSet.setString("Doe^John", for: .patientName, vr: .PN)
        dataSet.setUInt16(4, for: .rows)
        dataSet.setUInt16(4, for: .columns)
        dataSet.setUInt16(8, for: .bitsAllocated)
        dataSet.setUInt16(8, for: .bitsStored)
        dataSet.setUInt16(7, for: .highBit)
        dataSet.setUInt16(color ? 3 : 1, for: .samplesPerPixel)
        dataSet.setString(color ? "RGB" : "MONOCHROME2",
                          for: .photometricInterpretation, vr: .CS)

        let url = directory.appendingPathComponent(name)
        try DICOMFile.create(dataSet: dataSet).write().write(to: url)
        return url.path
    }

    /// A sheet holding `items`, with one printer of the given capability selected.
    private func makeViewModel(
        items: [PrintSelectionItem], printerColor: PrinterColorMode
    ) throws -> (PrintViewModel, URL) {
        let storageDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("print-colour-store-\(UUID().uuidString)", isDirectory: true)
        let storageService = StorageService(baseDirectory: storageDirectory)
        let selection = PrintSelectionModel()
        selection.add(contentsOf: items)
        let model = PrintViewModel(
            selection: selection,
            printerStorage: PrinterProfileStorageService(storageService: storageService))
        model.save(PrinterProfile(
            name: "Printer", host: "127.0.0.1", remoteAETitle: "PRINT_SCP",
            colorMode: printerColor))
        return (model, storageDirectory)
    }

    // MARK: Reading the source

    @Test("An RGB source is detected as colour")
    func detectsColorSource() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "colour.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.sourceIsColorByPath[path] == true)
        #expect(model.selectionHasColorImages)
    }

    @Test("A MONOCHROME2 source is detected as grey")
    func detectsMonochromeSource() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "grey.dcm", in: directory, color: false)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.sourceIsColorByPath[path] == false)
        #expect(!model.selectionHasColorImages)
    }

    // MARK: The bug this fixes

    /// The reported defect: a colour ultrasound marked onto a colour-capable
    /// printer printed grey, because auto-detect only ever asked the printer.
    @Test("A colour study on a colour printer resolves to colour")
    func colorStudyOnColorPrinterPrintsInColor() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        #expect(model.autoDetectColorMode)
        await model.refreshSourceColor()
        #expect(model.resolvedColorMode == .color)
        #expect(model.request.colorMode == .color)
    }

    // MARK: The printer no longer decides it

    /// The second half of the reported defect: colour survived only in raw mode.
    ///
    /// A printer profile left on Grayscale — the default — used to flatten the
    /// pixels while preparing them, so the processed job printed greys while a
    /// raw job of the same image printed colour. The pixels now keep their
    /// colour and the SOP class follows them onto the wire, so the profile's
    /// setting no longer silently discards it.
    @Test("A colour study keeps its colour on a grayscale-profiled printer")
    func colorSurvivesAGrayscaleProfiledPrinter() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .grayscale)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.request.preservesSourceColor)
        #expect(model.willPrintInColor)
    }

    /// Widening greys to RGB triples the bytes and changes nothing on the film.
    @Test("A monochrome study on a colour printer stays grey")
    func monochromeStudyOnColorPrinterStaysGrey() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "ct.dcm", in: directory, color: false)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.resolvedColorMode == .grayscale)
    }

    /// One colour image in a mixed selection carries the whole job: every box
    /// travels on one association, and grayscale cannot hold the colour one.
    @Test("One colour image among greys makes the job colour")
    func mixedSelectionResolvesToColor() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let grey = try writeImage(named: "ct.dcm", in: directory, color: false)
        let colour = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: grey),
                    PrintSelectionItem(filePath: colour)],
            printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.resolvedColorMode == .color)
    }

    // MARK: Manual override

    /// Auto-detect off means the user's choice stands, unexamined.
    @Test("Turning auto-detect off honours the chosen mode")
    func manualChoiceIsHonoured() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "ct.dcm", in: directory, color: false)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        model.autoDetectColorMode = false
        model.colorMode = .color
        #expect(model.resolvedColorMode == .color)
    }

    // MARK: Saying so

    /// Deliberately giving colour up is still said out loud.
    @Test("Flattening colour to greys says so")
    func downgradeIsAnnounced() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .grayscale)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        model.preservesSourceColor = false

        let notice = try #require(model.colorDowngradeNotice)
        #expect(notice.lowercased().contains("grey"))
        #expect(!model.willPrintInColor)
    }

    /// Nothing to warn about when the colour actually prints.
    @Test("A colour study that keeps its colour says nothing")
    func noNoticeWhenColorSurvives() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.colorDowngradeNotice == nil)
    }

    /// A monochrome study loses nothing by printing in greys.
    @Test("A monochrome study says nothing")
    func noNoticeForMonochromeStudy() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "ct.dcm", in: directory, color: false)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: path)], printerColor: .grayscale)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.colorDowngradeNotice == nil)
    }

    // MARK: Unreadable sources

    /// A file that cannot be read counts as monochrome rather than being
    /// guessed at: a wrong colour guess opens an association the printer refuses.
    @Test("An unreadable source counts as monochrome")
    func unreadableSourceCountsAsMonochrome() async throws {
        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: "/nonexistent/missing.dcm")],
            printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }

        await model.refreshSourceColor()
        #expect(model.resolvedColorMode == .grayscale)
        #expect(!model.selectionHasColorImages)
    }

    // MARK: What the preview must show per cell

    /// The switch the film obeys, the preview obeys: a colour cell flattens
    /// when asked, comes straight back on uncheck, and takes a film palette
    /// down with it — the same precedence the preparer applies.
    @Test("Flattening tracks the toggle and drops the palette with it")
    func flatteningTracksToggle() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = try writeImage(named: "us.dcm", in: directory, color: true)
        var mark = PrintSelectionItem(filePath: path)
        mark = mark.with(presentation: .some(ViewerPresentation(palette: .hotIron)))

        let (model, store) = try makeViewModel(items: [mark], printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }
        await model.refreshSourceColor()
        let item = try #require(model.printedItems.first)

        #expect(!model.cellIsFlattenedToGrey(item))
        #expect(model.cellPrintsInColor(item))
        #expect(model.previewItem(for: item).presentation?.palette == .hotIron)

        model.preservesSourceColor = false
        #expect(model.cellIsFlattenedToGrey(item))
        #expect(!model.cellPrintsInColor(item))
        #expect(model.previewItem(for: item).presentation?.palette == nil)

        // Raw sends stored pixels: no flatten, and the palette never applies.
        model.sendRawPixels = true
        #expect(!model.cellIsFlattenedToGrey(item))
        #expect(model.cellPrintsInColor(item))
        model.sendRawPixels = false

        model.preservesSourceColor = true
        #expect(!model.cellIsFlattenedToGrey(item))
        #expect(model.previewItem(for: item).presentation?.palette == .hotIron)
    }

    /// Polarity flips every cell; the rendered inverse only the grey ones —
    /// and the two compose, exactly as the composer draws the sheet.
    @Test("Film-wide inversion composes polarity with the rendered inverse")
    func filmWideInversionComposes() async throws {
        let directory = try makeFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let grey = try writeImage(named: "ct.dcm", in: directory, color: false)
        let colour = try writeImage(named: "us.dcm", in: directory, color: true)

        let (model, store) = try makeViewModel(
            items: [PrintSelectionItem(filePath: grey),
                    PrintSelectionItem(filePath: colour)],
            printerColor: .color)
        defer { try? FileManager.default.removeItem(at: store) }
        await model.refreshSourceColor()
        let greyItem = try #require(model.printedItems.first)
        let colourItem = try #require(model.printedItems.last)

        #expect(!model.filmWideInversion(for: greyItem))

        model.presentationLUTShape = .inverseRendered
        #expect(model.filmWideInversion(for: greyItem))
        // Colour keeps its polarity — inverting its luminance would change hue.
        #expect(!model.filmWideInversion(for: colourItem))
        // ...and that refusal is said out loud rather than left silent.
        #expect(model.presentationLUTNotice != nil)

        model.polarity = .reverse
        // The two inversions cancel on grey cells, compose on colour ones.
        #expect(!model.filmWideInversion(for: greyItem))
        #expect(model.filmWideInversion(for: colourItem))

        model.presentationLUTShape = nil
        #expect(model.filmWideInversion(for: greyItem))
        #expect(model.filmWideInversion(for: colourItem))

        // Flattened to greys, a colour cell is grey on the wire and the
        // rendered inverse reaches it again.
        model.polarity = .normal
        model.presentationLUTShape = .inverseRendered
        model.preservesSourceColor = false
        #expect(model.filmWideInversion(for: colourItem))

        // Raw: the inverse cannot be rendered into stored pixels, and says so.
        model.sendRawPixels = true
        #expect(!model.filmWideInversion(for: greyItem))
        #expect(model.presentationLUTNotice != nil)
    }
}
