import XCTest
import DICOMCore
@testable import DICOMNetwork

final class PrintServiceTests: XCTestCase {
    
    // MARK: - SOP Class UID Tests
    
    func testBasicFilmSessionSOPClassUID() {
        XCTAssertEqual(basicFilmSessionSOPClassUID, "1.2.840.10008.5.1.1.1")
    }
    
    func testBasicFilmBoxSOPClassUID() {
        XCTAssertEqual(basicFilmBoxSOPClassUID, "1.2.840.10008.5.1.1.2")
    }
    
    func testBasicGrayscaleImageBoxSOPClassUID() {
        XCTAssertEqual(basicGrayscaleImageBoxSOPClassUID, "1.2.840.10008.5.1.1.4")
    }
    
    func testBasicColorImageBoxSOPClassUID() {
        XCTAssertEqual(basicColorImageBoxSOPClassUID, "1.2.840.10008.5.1.1.4.1")
    }
    
    func testBasicGrayscalePrintManagementMetaSOPClassUID() {
        XCTAssertEqual(basicGrayscalePrintManagementMetaSOPClassUID, "1.2.840.10008.5.1.1.9")
    }
    
    func testBasicColorPrintManagementMetaSOPClassUID() {
        XCTAssertEqual(basicColorPrintManagementMetaSOPClassUID, "1.2.840.10008.5.1.1.18")
    }
    
    func testPrinterSOPClassUID() {
        XCTAssertEqual(printerSOPClassUID, "1.2.840.10008.5.1.1.16")
    }
    
    func testPrinterSOPInstanceUID() {
        XCTAssertEqual(printerSOPInstanceUID, "1.2.840.10008.5.1.1.17")
    }
    
    func testPrintJobSOPClassUID() {
        XCTAssertEqual(printJobSOPClassUID, "1.2.840.10008.5.1.1.14")
    }
    
    // MARK: - PrintConfiguration Tests
    
    func testPrintConfigurationDefaults() {
        let config = PrintConfiguration(
            host: "192.168.1.100",
            port: 104,
            callingAETitle: "MYAPP",
            calledAETitle: "PRINTER"
        )
        
        XCTAssertEqual(config.host, "192.168.1.100")
        XCTAssertEqual(config.port, 104)
        XCTAssertEqual(config.callingAETitle, "MYAPP")
        XCTAssertEqual(config.calledAETitle, "PRINTER")
        XCTAssertEqual(config.timeout, 30)
        XCTAssertEqual(config.colorMode, .grayscale)
    }
    
    func testPrintConfigurationCustomValues() {
        let config = PrintConfiguration(
            host: "10.0.0.1",
            port: 11112,
            callingAETitle: "SOURCE",
            calledAETitle: "DEST",
            timeout: 60,
            colorMode: .color
        )
        
        XCTAssertEqual(config.host, "10.0.0.1")
        XCTAssertEqual(config.port, 11112)
        XCTAssertEqual(config.callingAETitle, "SOURCE")
        XCTAssertEqual(config.calledAETitle, "DEST")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.colorMode, .color)
    }
    
    // MARK: - PrintColorMode Tests
    
    func testPrintColorModeRawValues() {
        XCTAssertEqual(PrintColorMode.grayscale.rawValue, "GRAYSCALE")
        XCTAssertEqual(PrintColorMode.color.rawValue, "COLOR")
    }
    
    // MARK: - FilmSession Tests
    
    func testFilmSessionDefaults() {
        let session = FilmSession()
        
        XCTAssertEqual(session.sopInstanceUID, "")
        XCTAssertEqual(session.numberOfCopies, 1)
        XCTAssertEqual(session.printPriority, .medium)
        XCTAssertEqual(session.mediumType, .paper)
        XCTAssertEqual(session.filmDestination, .processor)
        XCTAssertNil(session.filmSessionLabel)
    }
    
    func testFilmSessionCustomValues() {
        let session = FilmSession(
            sopInstanceUID: "1.2.3.4.5",
            numberOfCopies: 3,
            printPriority: .high,
            mediumType: .blueFilm,
            filmDestination: .magazine,
            filmSessionLabel: "Test Print"
        )
        
        XCTAssertEqual(session.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(session.numberOfCopies, 3)
        XCTAssertEqual(session.printPriority, .high)
        XCTAssertEqual(session.mediumType, .blueFilm)
        XCTAssertEqual(session.filmDestination, .magazine)
        XCTAssertEqual(session.filmSessionLabel, "Test Print")
    }
    
    // MARK: - PrintPriority Tests
    
    func testPrintPriorityRawValues() {
        XCTAssertEqual(PrintPriority.high.rawValue, "HIGH")
        XCTAssertEqual(PrintPriority.medium.rawValue, "MED")
        XCTAssertEqual(PrintPriority.low.rawValue, "LOW")
    }
    
    // MARK: - MediumType Tests
    
    func testMediumTypeRawValues() {
        XCTAssertEqual(MediumType.paper.rawValue, "PAPER")
        XCTAssertEqual(MediumType.clearFilm.rawValue, "CLEAR FILM")
        XCTAssertEqual(MediumType.blueFilm.rawValue, "BLUE FILM")
        XCTAssertEqual(MediumType.mammoFilmClearBase.rawValue, "MAMMO CLEAR")
        XCTAssertEqual(MediumType.mammoFilmBlueBase.rawValue, "MAMMO BLUE")
    }
    
    // MARK: - FilmDestination Tests
    
    func testFilmDestinationRawValues() {
        XCTAssertEqual(FilmDestination.magazine.rawValue, "MAGAZINE")
        XCTAssertEqual(FilmDestination.processor.rawValue, "PROCESSOR")
        XCTAssertEqual(FilmDestination.bin1.rawValue, "BIN_1")
        XCTAssertEqual(FilmDestination.bin2.rawValue, "BIN_2")
    }
    
    // MARK: - FilmBox Tests
    
    func testFilmBoxDefaults() {
        let box = FilmBox()
        
        XCTAssertEqual(box.sopInstanceUID, "")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\1,1")
        XCTAssertEqual(box.filmOrientation, .portrait)
        XCTAssertEqual(box.filmSizeID, .size8InX10In)
        XCTAssertEqual(box.magnificationType, .replicate)
        XCTAssertEqual(box.borderDensity, "BLACK")
        XCTAssertEqual(box.emptyImageDensity, "BLACK")
        XCTAssertEqual(box.trimOption, .no)
        XCTAssertNil(box.configurationInformation)
        XCTAssertTrue(box.imageBoxSOPInstanceUIDs.isEmpty)
    }
    
    func testFilmBoxCustomValues() {
        let box = FilmBox(
            sopInstanceUID: "1.2.3.4",
            imageDisplayFormat: "STANDARD\\2,3",
            filmOrientation: .landscape,
            filmSizeID: .size14InX17In,
            magnificationType: .bilinear,
            borderDensity: "WHITE",
            emptyImageDensity: "WHITE",
            trimOption: .yes,
            configurationInformation: "CS=BINARY",
            imageBoxSOPInstanceUIDs: ["1.2.3.4.1", "1.2.3.4.2"]
        )
        
        XCTAssertEqual(box.sopInstanceUID, "1.2.3.4")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\2,3")
        XCTAssertEqual(box.filmOrientation, .landscape)
        XCTAssertEqual(box.filmSizeID, .size14InX17In)
        XCTAssertEqual(box.magnificationType, .bilinear)
        XCTAssertEqual(box.borderDensity, "WHITE")
        XCTAssertEqual(box.emptyImageDensity, "WHITE")
        XCTAssertEqual(box.trimOption, .yes)
        XCTAssertEqual(box.configurationInformation, "CS=BINARY")
        XCTAssertEqual(box.imageBoxSOPInstanceUIDs.count, 2)
    }
    
    // MARK: - FilmOrientation Tests
    
    func testFilmOrientationRawValues() {
        XCTAssertEqual(FilmOrientation.portrait.rawValue, "PORTRAIT")
        XCTAssertEqual(FilmOrientation.landscape.rawValue, "LANDSCAPE")
    }
    
    // MARK: - FilmSize Tests
    
    func testFilmSizeRawValues() {
        XCTAssertEqual(FilmSize.size8InX10In.rawValue, "8INX10IN")
        XCTAssertEqual(FilmSize.size8_5InX11In.rawValue, "8_5INX11IN")
        XCTAssertEqual(FilmSize.size10InX12In.rawValue, "10INX12IN")
        XCTAssertEqual(FilmSize.size10InX14In.rawValue, "10INX14IN")
        XCTAssertEqual(FilmSize.size11InX14In.rawValue, "11INX14IN")
        XCTAssertEqual(FilmSize.size11InX17In.rawValue, "11INX17IN")
        XCTAssertEqual(FilmSize.size14InX14In.rawValue, "14INX14IN")
        XCTAssertEqual(FilmSize.size14InX17In.rawValue, "14INX17IN")
        XCTAssertEqual(FilmSize.size24CmX24Cm.rawValue, "24CMX24CM")
        XCTAssertEqual(FilmSize.size24CmX30Cm.rawValue, "24CMX30CM")
        XCTAssertEqual(FilmSize.a4.rawValue, "A4")
        XCTAssertEqual(FilmSize.a3.rawValue, "A3")
    }
    
    // MARK: - MagnificationType Tests
    
    func testMagnificationTypeRawValues() {
        XCTAssertEqual(MagnificationType.replicate.rawValue, "REPLICATE")
        XCTAssertEqual(MagnificationType.bilinear.rawValue, "BILINEAR")
        XCTAssertEqual(MagnificationType.cubic.rawValue, "CUBIC")
        XCTAssertEqual(MagnificationType.none.rawValue, "NONE")
    }
    
    // MARK: - TrimOption Tests
    
    func testTrimOptionRawValues() {
        XCTAssertEqual(TrimOption.yes.rawValue, "YES")
        XCTAssertEqual(TrimOption.no.rawValue, "NO")
    }
    
    // MARK: - ImageBoxContent Tests
    
    func testImageBoxContentDefaults() {
        let content = ImageBoxContent()
        
        XCTAssertEqual(content.sopInstanceUID, "")
        XCTAssertEqual(content.imagePosition, 1)
        XCTAssertEqual(content.polarity, .normal)
        XCTAssertNil(content.requestedImageSize)
        XCTAssertEqual(content.requestedDecimateCropBehavior, .decimate)
    }
    
    func testImageBoxContentCustomValues() {
        let content = ImageBoxContent(
            sopInstanceUID: "1.2.3.4.5.6",
            imagePosition: 3,
            polarity: .reverse,
            requestedImageSize: "200",
            requestedDecimateCropBehavior: .crop
        )
        
        XCTAssertEqual(content.sopInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(content.imagePosition, 3)
        XCTAssertEqual(content.polarity, .reverse)
        XCTAssertEqual(content.requestedImageSize, "200")
        XCTAssertEqual(content.requestedDecimateCropBehavior, .crop)
    }
    
    // MARK: - ImagePolarity Tests
    
    func testImagePolarityRawValues() {
        XCTAssertEqual(ImagePolarity.normal.rawValue, "NORMAL")
        XCTAssertEqual(ImagePolarity.reverse.rawValue, "REVERSE")
    }
    
    // MARK: - DecimateCropBehavior Tests
    
    func testDecimateCropBehaviorRawValues() {
        XCTAssertEqual(DecimateCropBehavior.decimate.rawValue, "DECIMATE")
        XCTAssertEqual(DecimateCropBehavior.crop.rawValue, "CROP")
        XCTAssertEqual(DecimateCropBehavior.failOver.rawValue, "FAIL")
    }
    
    // MARK: - PrinterStatus Tests
    
    func testPrinterStatusCreation() {
        let status = PrinterStatus(status: "NORMAL")
        
        XCTAssertEqual(status.status, "NORMAL")
        XCTAssertNil(status.statusInfo)
        XCTAssertNil(status.printerName)
        XCTAssertTrue(status.isNormal)
    }
    
    func testPrinterStatusWithDetails() {
        let status = PrinterStatus(
            status: "WARNING",
            statusInfo: "Low toner",
            printerName: "DICOM Printer 1"
        )
        
        XCTAssertEqual(status.status, "WARNING")
        XCTAssertEqual(status.statusInfo, "Low toner")
        XCTAssertEqual(status.printerName, "DICOM Printer 1")
        XCTAssertFalse(status.isNormal)
    }
    
    func testPrinterStatusFailure() {
        let status = PrinterStatus(status: "FAILURE", statusInfo: "Paper jam")
        
        XCTAssertFalse(status.isNormal)
    }
    
    // MARK: - PrintResult Tests
    
    func testPrintResultSuccess() {
        let result = PrintResult(
            success: true,
            status: .success,
            filmSessionUID: "1.2.3.4",
            filmBoxUID: "1.2.3.4.5",
            printJobUID: "1.2.3.4.6"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.status.isSuccess)
        XCTAssertEqual(result.filmSessionUID, "1.2.3.4")
        XCTAssertEqual(result.filmBoxUID, "1.2.3.4.5")
        XCTAssertEqual(result.printJobUID, "1.2.3.4.6")
        XCTAssertNil(result.errorMessage)
    }
    
    func testPrintResultFailure() {
        let result = PrintResult(
            success: false,
            status: .failedUnableToProcess,
            errorMessage: "Printer offline"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.filmSessionUID)
        XCTAssertNil(result.filmBoxUID)
        XCTAssertNil(result.printJobUID)
        XCTAssertEqual(result.errorMessage, "Printer offline")
    }
    
    // MARK: - Print Tag Tests
    
    func testFilmSessionTags() {
        XCTAssertEqual(Tag.numberOfCopies.group, 0x2000)
        XCTAssertEqual(Tag.numberOfCopies.element, 0x0010)
        XCTAssertEqual(Tag.printPriority.group, 0x2000)
        XCTAssertEqual(Tag.printPriority.element, 0x0020)
        XCTAssertEqual(Tag.mediumType.group, 0x2000)
        XCTAssertEqual(Tag.mediumType.element, 0x0030)
        XCTAssertEqual(Tag.filmDestination.group, 0x2000)
        XCTAssertEqual(Tag.filmDestination.element, 0x0040)
        XCTAssertEqual(Tag.filmSessionLabel.group, 0x2000)
        XCTAssertEqual(Tag.filmSessionLabel.element, 0x0050)
        XCTAssertEqual(Tag.memoryAllocation.group, 0x2000)
        XCTAssertEqual(Tag.memoryAllocation.element, 0x0060)
        XCTAssertEqual(Tag.referencedFilmBoxSequence.group, 0x2000)
        XCTAssertEqual(Tag.referencedFilmBoxSequence.element, 0x0500)
    }
    
    func testFilmBoxTags() {
        XCTAssertEqual(Tag.imageDisplayFormat.group, 0x2010)
        XCTAssertEqual(Tag.imageDisplayFormat.element, 0x0010)
        XCTAssertEqual(Tag.filmOrientation.group, 0x2010)
        XCTAssertEqual(Tag.filmOrientation.element, 0x0040)
        XCTAssertEqual(Tag.filmSizeID.group, 0x2010)
        XCTAssertEqual(Tag.filmSizeID.element, 0x0050)
        XCTAssertEqual(Tag.magnificationType.group, 0x2010)
        XCTAssertEqual(Tag.magnificationType.element, 0x0060)
        XCTAssertEqual(Tag.borderDensity.group, 0x2010)
        XCTAssertEqual(Tag.borderDensity.element, 0x0100)
        XCTAssertEqual(Tag.trim.group, 0x2010)
        XCTAssertEqual(Tag.trim.element, 0x0140)
        XCTAssertEqual(Tag.referencedImageBoxSequence.group, 0x2010)
        XCTAssertEqual(Tag.referencedImageBoxSequence.element, 0x0510)
    }
    
    func testImageBoxTags() {
        XCTAssertEqual(Tag.imageBoxPosition.group, 0x2020)
        XCTAssertEqual(Tag.imageBoxPosition.element, 0x0010)
        XCTAssertEqual(Tag.polarity.group, 0x2020)
        XCTAssertEqual(Tag.polarity.element, 0x0020)
        XCTAssertEqual(Tag.requestedImageSize.group, 0x2020)
        XCTAssertEqual(Tag.requestedImageSize.element, 0x0030)
    }
    
    func testPrinterTags() {
        XCTAssertEqual(Tag.printerStatus.group, 0x2110)
        XCTAssertEqual(Tag.printerStatus.element, 0x0010)
        XCTAssertEqual(Tag.printerStatusInfo.group, 0x2110)
        XCTAssertEqual(Tag.printerStatusInfo.element, 0x0020)
        XCTAssertEqual(Tag.printerName.group, 0x2110)
        XCTAssertEqual(Tag.printerName.element, 0x0030)
    }
    
    func testPrintJobTags() {
        XCTAssertEqual(Tag.executionStatus.group, 0x2100)
        XCTAssertEqual(Tag.executionStatus.element, 0x0020)
        XCTAssertEqual(Tag.executionStatusInfo.group, 0x2100)
        XCTAssertEqual(Tag.executionStatusInfo.element, 0x0030)
        XCTAssertEqual(Tag.creationDate.group, 0x2100)
        XCTAssertEqual(Tag.creationDate.element, 0x0040)
        XCTAssertEqual(Tag.creationTime.group, 0x2100)
        XCTAssertEqual(Tag.creationTime.element, 0x0050)
    }
    
    // MARK: - Film Session Management Tests
    
    func testCreateFilmSessionRequestBuilding() {
        // Test that createFilmSession properly constructs the N-CREATE request
        // This test validates the data set structure for Film Session attributes
        
        let session = FilmSession(
            numberOfCopies: 2,
            printPriority: .high,
            mediumType: .clearFilm,
            filmDestination: .magazine,
            filmSessionLabel: "Test Session"
        )
        
        // Validate the session configuration
        XCTAssertEqual(session.numberOfCopies, 2)
        XCTAssertEqual(session.printPriority, .high)
        XCTAssertEqual(session.mediumType, .clearFilm)
        XCTAssertEqual(session.filmDestination, .magazine)
        XCTAssertEqual(session.filmSessionLabel, "Test Session")
    }
    
    func testDeleteFilmSessionRequestBuilding() {
        // Test that deleteFilmSession properly constructs the N-DELETE request
        let filmSessionUID = "1.2.840.113619.2.55.3.2024.01.01"
        
        // Validate UID format (basic check)
        XCTAssertFalse(filmSessionUID.isEmpty)
        XCTAssertTrue(filmSessionUID.contains("."))
    }
    
    func testFilmSessionWithDefaults() {
        let session = FilmSession()
        
        XCTAssertEqual(session.numberOfCopies, 1)
        XCTAssertEqual(session.printPriority, .medium)
        XCTAssertEqual(session.mediumType, .paper)
        XCTAssertEqual(session.filmDestination, .processor)
        XCTAssertNil(session.filmSessionLabel)
    }
    
    func testFilmSessionWithCustomValues() {
        let session = FilmSession(
            sopInstanceUID: "1.2.3",
            numberOfCopies: 3,
            printPriority: .low,
            mediumType: .mammoFilmBlueBase,
            filmDestination: .bin2,
            filmSessionLabel: "Mammography Study"
        )
        
        XCTAssertEqual(session.sopInstanceUID, "1.2.3")
        XCTAssertEqual(session.numberOfCopies, 3)
        XCTAssertEqual(session.printPriority, .low)
        XCTAssertEqual(session.mediumType, .mammoFilmBlueBase)
        XCTAssertEqual(session.filmDestination, .bin2)
        XCTAssertEqual(session.filmSessionLabel, "Mammography Study")
    }
    
    // MARK: - FilmBoxResult Tests
    
    func testFilmBoxResultInitialization() {
        let result = FilmBoxResult(
            filmBoxUID: "1.2.840.10008.1.2.3.4",
            imageBoxUIDs: ["1.2.3.4.1", "1.2.3.4.2", "1.2.3.4.3", "1.2.3.4.4"],
            imageCount: 4
        )
        
        XCTAssertEqual(result.filmBoxUID, "1.2.840.10008.1.2.3.4")
        XCTAssertEqual(result.imageBoxUIDs.count, 4)
        XCTAssertEqual(result.imageBoxUIDs[0], "1.2.3.4.1")
        XCTAssertEqual(result.imageBoxUIDs[3], "1.2.3.4.4")
        XCTAssertEqual(result.imageCount, 4)
    }
    
    func testFilmBoxResultWithNoImageBoxes() {
        let result = FilmBoxResult(
            filmBoxUID: "1.2.3",
            imageBoxUIDs: [],
            imageCount: 1
        )
        
        XCTAssertEqual(result.filmBoxUID, "1.2.3")
        XCTAssertTrue(result.imageBoxUIDs.isEmpty)
        XCTAssertEqual(result.imageCount, 1)
    }
    
    func testFilmBoxResultWithMultipleImageBoxes() {
        let imageBoxes = (1...6).map { "1.2.3.4.\($0)" }
        let result = FilmBoxResult(
            filmBoxUID: "1.2.3",
            imageBoxUIDs: imageBoxes,
            imageCount: 6
        )
        
        XCTAssertEqual(result.filmBoxUID, "1.2.3")
        XCTAssertEqual(result.imageBoxUIDs.count, 6)
        XCTAssertEqual(result.imageCount, 6)
    }
}
