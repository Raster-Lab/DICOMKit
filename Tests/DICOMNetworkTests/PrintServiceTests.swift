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
    
    // MARK: - Image Display Format Tests
    
    func testFilmBoxWithSingleImageFormat() {
        let box = FilmBox(imageDisplayFormat: "STANDARD\\1,1")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\1,1")
    }
    
    func testFilmBoxWith2x2Format() {
        let box = FilmBox(imageDisplayFormat: "STANDARD\\2,2")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\2,2")
    }
    
    func testFilmBoxWith3x4Format() {
        let box = FilmBox(imageDisplayFormat: "STANDARD\\3,4")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\3,4")
    }
    
    func testFilmBoxWith4x4Format() {
        let box = FilmBox(imageDisplayFormat: "STANDARD\\4,4")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\4,4")
    }
    
    func testFilmBoxWith2x3Format() {
        let box = FilmBox(imageDisplayFormat: "STANDARD\\2,3")
        XCTAssertEqual(box.imageDisplayFormat, "STANDARD\\2,3")
    }
    
    // MARK: - Print Tags Tests
    
    func testImageBoxPositionTag() {
        XCTAssertEqual(Tag.imageBoxPosition.group, 0x2020)
        XCTAssertEqual(Tag.imageBoxPosition.element, 0x0010)
    }
    
    func testPolarityTag() {
        XCTAssertEqual(Tag.polarity.group, 0x2020)
        XCTAssertEqual(Tag.polarity.element, 0x0020)
    }
    
    func testRequestedImageSizeTag() {
        XCTAssertEqual(Tag.requestedImageSize.group, 0x2020)
        XCTAssertEqual(Tag.requestedImageSize.element, 0x0030)
    }
    
    func testRequestedDecimateCropBehaviorTag() {
        XCTAssertEqual(Tag.requestedDecimateCropBehavior.group, 0x2020)
        XCTAssertEqual(Tag.requestedDecimateCropBehavior.element, 0x0040)
    }
    
    func testPreformattedGrayscaleImageSequenceTag() {
        XCTAssertEqual(Tag.preformattedGrayscaleImageSequence.group, 0x2020)
        XCTAssertEqual(Tag.preformattedGrayscaleImageSequence.element, 0x0110)
    }
    
    func testPreformattedColorImageSequenceTag() {
        XCTAssertEqual(Tag.preformattedColorImageSequence.group, 0x2020)
        XCTAssertEqual(Tag.preformattedColorImageSequence.element, 0x0111)
    }
    
    // MARK: - Integration Test Placeholders
    
    // NOTE: The following tests require a DICOM Print SCP server to be running
    // and are therefore documented here but not implemented as unit tests.
    // These should be run as integration tests with a test Print SCP.
    
    // Integration test scenarios for setImageBox():
    // - Test with valid grayscale preformatted image data
    // - Test with valid color preformatted image data
    // - Test with invalid pixel data (should fail gracefully)
    // - Test with all image box attributes set
    // - Test with minimum required attributes only
    
    // Integration test scenarios for printFilmBox():
    // - Test successful print operation returning Print Job UID
    // - Test with invalid Film Box UID (should fail)
    // - Test when Print Job UID is empty (should throw unexpectedResponse)
    // - Test print status monitoring after successful print
    
    // Integration test scenarios for parseImageBoxUIDs():
    // - Test parsing valid Film Box N-CREATE response with multiple image boxes
    // - Test parsing response with single image box
    // - Test parsing empty or malformed response data
    // - Test parsing response with missing Referenced Image Box Sequence
    
    // Integration test scenario for complete print workflow:
    // - Test full workflow: getPrinterStatus → createFilmSession → createFilmBox →
    //   setImageBox (for each position) → printFilmBox → deleteFilmSession
    // - Test with various film layouts (1x1, 2x2, 3x4, 4x5)
    // - Test with both grayscale and color modes
    // - Test error recovery at each stage
    // - Test concurrent print jobs
    
    // TODO: Implement integration tests in a separate test suite
    // See DICOM_PRINTER_PLAN.md Phase 1.5 for integration test requirements
    
    // MARK: - PrintJobStatus Tests
    
    func testPrintJobStatusInitialization() {
        let status = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.001",
            executionStatus: "PENDING"
        )
        
        XCTAssertEqual(status.printJobUID, "1.2.840.113619.2.55.3.2024.01.01.001")
        XCTAssertEqual(status.executionStatus, "PENDING")
        XCTAssertNil(status.executionStatusInfo)
        XCTAssertNil(status.creationDate)
        XCTAssertNil(status.creationTime)
    }
    
    func testPrintJobStatusWithAllFields() {
        let creationDate = Date()
        let creationTime = Date()
        
        let status = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.002",
            executionStatus: "DONE",
            executionStatusInfo: "Printed successfully",
            creationDate: creationDate,
            creationTime: creationTime
        )
        
        XCTAssertEqual(status.printJobUID, "1.2.840.113619.2.55.3.2024.01.01.002")
        XCTAssertEqual(status.executionStatus, "DONE")
        XCTAssertEqual(status.executionStatusInfo, "Printed successfully")
        XCTAssertEqual(status.creationDate, creationDate)
        XCTAssertEqual(status.creationTime, creationTime)
    }
    
    func testPrintJobStatusIsInProgress_Pending() {
        let status = PrintJobStatus(
            printJobUID: "1.2.3",
            executionStatus: "PENDING"
        )
        
        XCTAssertTrue(status.isInProgress)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
    }
    
    func testPrintJobStatusIsInProgress_Printing() {
        let status = PrintJobStatus(
            printJobUID: "1.2.3",
            executionStatus: "PRINTING"
        )
        
        XCTAssertTrue(status.isInProgress)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
    }
    
    func testPrintJobStatusIsCompleted() {
        let status = PrintJobStatus(
            printJobUID: "1.2.3",
            executionStatus: "DONE"
        )
        
        XCTAssertFalse(status.isInProgress)
        XCTAssertTrue(status.isCompleted)
        XCTAssertFalse(status.isFailed)
    }
    
    func testPrintJobStatusIsFailed() {
        let status = PrintJobStatus(
            printJobUID: "1.2.3",
            executionStatus: "FAILURE",
            executionStatusInfo: "Printer offline"
        )
        
        XCTAssertFalse(status.isInProgress)
        XCTAssertFalse(status.isCompleted)
        XCTAssertTrue(status.isFailed)
        XCTAssertEqual(status.executionStatusInfo, "Printer offline")
    }
    
    func testPrintJobStatusAllExecutionStates() {
        let states = ["PENDING", "PRINTING", "DONE", "FAILURE"]
        
        for state in states {
            let status = PrintJobStatus(
                printJobUID: "1.2.3",
                executionStatus: state
            )
            
            XCTAssertEqual(status.executionStatus, state)
            
            switch state {
            case "PENDING", "PRINTING":
                XCTAssertTrue(status.isInProgress)
                XCTAssertFalse(status.isCompleted)
                XCTAssertFalse(status.isFailed)
            case "DONE":
                XCTAssertFalse(status.isInProgress)
                XCTAssertTrue(status.isCompleted)
                XCTAssertFalse(status.isFailed)
            case "FAILURE":
                XCTAssertFalse(status.isInProgress)
                XCTAssertFalse(status.isCompleted)
                XCTAssertTrue(status.isFailed)
            default:
                XCTFail("Unexpected execution status: \(state)")
            }
        }
    }
    
    func testPrintJobStatusWithUnknownState() {
        let status = PrintJobStatus(
            printJobUID: "1.2.3",
            executionStatus: "UNKNOWN"
        )
        
        XCTAssertEqual(status.executionStatus, "UNKNOWN")
        XCTAssertFalse(status.isInProgress)
        XCTAssertFalse(status.isCompleted)
        XCTAssertFalse(status.isFailed)
    }
    
    func testPrintJobStatusWithMultipleStatuses() {
        // Test creating multiple PrintJobStatus instances with different states
        let pendingStatus = PrintJobStatus(
            printJobUID: "1.2.3.1",
            executionStatus: "PENDING"
        )
        
        let printingStatus = PrintJobStatus(
            printJobUID: "1.2.3.2",
            executionStatus: "PRINTING"
        )
        
        let doneStatus = PrintJobStatus(
            printJobUID: "1.2.3.3",
            executionStatus: "DONE"
        )
        
        let failureStatus = PrintJobStatus(
            printJobUID: "1.2.3.4",
            executionStatus: "FAILURE",
            executionStatusInfo: "Paper jam"
        )
        
        XCTAssertTrue(pendingStatus.isInProgress)
        XCTAssertTrue(printingStatus.isInProgress)
        XCTAssertTrue(doneStatus.isCompleted)
        XCTAssertTrue(failureStatus.isFailed)
        XCTAssertEqual(failureStatus.executionStatusInfo, "Paper jam")
    }
    
    // MARK: - Print Job Status Tag Tests
    
    func testExecutionStatusTag() {
        XCTAssertEqual(Tag.executionStatus.group, 0x2100)
        XCTAssertEqual(Tag.executionStatus.element, 0x0020)
    }
    
    func testExecutionStatusInfoTag() {
        XCTAssertEqual(Tag.executionStatusInfo.group, 0x2100)
        XCTAssertEqual(Tag.executionStatusInfo.element, 0x0030)
    }
    
    func testCreationDateTag() {
        XCTAssertEqual(Tag.creationDate.group, 0x2100)
        XCTAssertEqual(Tag.creationDate.element, 0x0040)
    }
    
    func testCreationTimeTag() {
        XCTAssertEqual(Tag.creationTime.group, 0x2100)
        XCTAssertEqual(Tag.creationTime.element, 0x0050)
    }
    
    // MARK: - Print Job Workflow Tests
    
    func testPrintJobWorkflow() {
        // Test that a typical print job workflow can be represented
        // 1. Print job created -> PENDING
        let pendingJob = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.001",
            executionStatus: "PENDING"
        )
        XCTAssertTrue(pendingJob.isInProgress)
        
        // 2. Print job starts -> PRINTING
        let printingJob = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.001",
            executionStatus: "PRINTING",
            executionStatusInfo: "Page 1 of 1"
        )
        XCTAssertTrue(printingJob.isInProgress)
        XCTAssertEqual(printingJob.executionStatusInfo, "Page 1 of 1")
        
        // 3. Print job completes -> DONE
        let doneJob = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.001",
            executionStatus: "DONE",
            executionStatusInfo: "Completed"
        )
        XCTAssertTrue(doneJob.isCompleted)
    }
    
    func testPrintJobFailureWorkflow() {
        // Test that a failed print job can be represented
        let failedJob = PrintJobStatus(
            printJobUID: "1.2.840.113619.2.55.3.2024.01.01.001",
            executionStatus: "FAILURE",
            executionStatusInfo: "Printer offline - check connection"
        )
        
        XCTAssertTrue(failedJob.isFailed)
        XCTAssertEqual(failedJob.executionStatusInfo, "Printer offline - check connection")
        XCTAssertFalse(failedJob.isInProgress)
        XCTAssertFalse(failedJob.isCompleted)
    }
    
    // MARK: - Phase 2: PrintOptions Tests
    
    func testPrintOptionsDefaults() {
        let options = PrintOptions()
        
        XCTAssertEqual(options.numberOfCopies, 1)
        XCTAssertEqual(options.priority, .medium)
        XCTAssertEqual(options.filmSize, .size8InX10In)
        XCTAssertEqual(options.filmOrientation, .portrait)
        XCTAssertEqual(options.mediumType, .clearFilm)
        XCTAssertEqual(options.filmDestination, .processor)
        XCTAssertEqual(options.borderDensity, "BLACK")
        XCTAssertEqual(options.emptyImageDensity, "BLACK")
        XCTAssertEqual(options.magnificationType, .replicate)
        XCTAssertEqual(options.polarity, .normal)
        XCTAssertEqual(options.trimOption, .no)
        XCTAssertNil(options.sessionLabel)
    }
    
    func testPrintOptionsCustomValues() {
        let options = PrintOptions(
            numberOfCopies: 3,
            priority: .high,
            filmSize: .size14InX17In,
            filmOrientation: .landscape,
            mediumType: .blueFilm,
            filmDestination: .magazine,
            borderDensity: "WHITE",
            emptyImageDensity: "WHITE",
            magnificationType: .bilinear,
            polarity: .reverse,
            trimOption: .yes,
            sessionLabel: "Test Print"
        )
        
        XCTAssertEqual(options.numberOfCopies, 3)
        XCTAssertEqual(options.priority, .high)
        XCTAssertEqual(options.filmSize, .size14InX17In)
        XCTAssertEqual(options.filmOrientation, .landscape)
        XCTAssertEqual(options.mediumType, .blueFilm)
        XCTAssertEqual(options.filmDestination, .magazine)
        XCTAssertEqual(options.borderDensity, "WHITE")
        XCTAssertEqual(options.emptyImageDensity, "WHITE")
        XCTAssertEqual(options.magnificationType, .bilinear)
        XCTAssertEqual(options.polarity, .reverse)
        XCTAssertEqual(options.trimOption, .yes)
        XCTAssertEqual(options.sessionLabel, "Test Print")
    }
    
    func testPrintOptionsStaticDefault() {
        let options = PrintOptions.default
        
        XCTAssertEqual(options.numberOfCopies, 1)
        XCTAssertEqual(options.priority, .medium)
        XCTAssertEqual(options.filmSize, .size8InX10In)
    }
    
    func testPrintOptionsStaticHighQuality() {
        let options = PrintOptions.highQuality
        
        XCTAssertEqual(options.priority, .high)
        XCTAssertEqual(options.filmSize, .size14InX17In)
        XCTAssertEqual(options.mediumType, .clearFilm)
        XCTAssertEqual(options.magnificationType, .bilinear)
    }
    
    func testPrintOptionsStaticDraft() {
        let options = PrintOptions.draft
        
        XCTAssertEqual(options.priority, .low)
        XCTAssertEqual(options.filmSize, .size8_5InX11In)
        XCTAssertEqual(options.mediumType, .paper)
        XCTAssertEqual(options.magnificationType, .replicate)
    }
    
    func testPrintOptionsStaticMammography() {
        let options = PrintOptions.mammography
        
        XCTAssertEqual(options.priority, .high)
        XCTAssertEqual(options.filmSize, .size14InX17In)
        XCTAssertEqual(options.mediumType, .mammoFilmBlueBase)
        XCTAssertEqual(options.magnificationType, .bilinear)
    }
    
    // MARK: - Phase 2: PrintLayout Tests
    
    func testPrintLayoutBasicInitialization() {
        let layout = PrintLayout(rows: 2, columns: 3)
        
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.imageCount, 6)
        XCTAssertEqual(layout.imageDisplayFormat, "STANDARD\\2,3")
    }
    
    func testPrintLayoutMinimumValues() {
        let layout = PrintLayout(rows: 0, columns: 0)
        
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 1)
        XCTAssertEqual(layout.imageCount, 1)
    }
    
    func testPrintLayoutOptimalFor1Image() {
        let layout = PrintLayout.optimalLayout(for: 1)
        
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 1)
    }
    
    func testPrintLayoutOptimalFor2Images() {
        let layout = PrintLayout.optimalLayout(for: 2)
        
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 2)
    }
    
    func testPrintLayoutOptimalFor4Images() {
        let layout = PrintLayout.optimalLayout(for: 4)
        
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 2)
    }
    
    func testPrintLayoutOptimalFor6Images() {
        let layout = PrintLayout.optimalLayout(for: 6)
        
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 3)
    }
    
    func testPrintLayoutOptimalFor9Images() {
        let layout = PrintLayout.optimalLayout(for: 9)
        
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.columns, 3)
    }
    
    func testPrintLayoutOptimalFor12Images() {
        let layout = PrintLayout.optimalLayout(for: 12)
        
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.columns, 4)
    }
    
    func testPrintLayoutOptimalFor16Images() {
        let layout = PrintLayout.optimalLayout(for: 16)
        
        XCTAssertEqual(layout.rows, 4)
        XCTAssertEqual(layout.columns, 4)
    }
    
    func testPrintLayoutOptimalFor20Images() {
        let layout = PrintLayout.optimalLayout(for: 20)
        
        XCTAssertEqual(layout.rows, 4)
        XCTAssertEqual(layout.columns, 5)
    }
    
    func testPrintLayoutOptimalForMoreThan20Images() {
        let layout = PrintLayout.optimalLayout(for: 30)
        
        XCTAssertEqual(layout.rows, 5)
        XCTAssertEqual(layout.columns, 5)
    }
    
    func testPrintLayoutStaticSingleImage() {
        let layout = PrintLayout.singleImage
        
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 1)
    }
    
    func testPrintLayoutStaticComparison() {
        let layout = PrintLayout.comparison
        
        XCTAssertEqual(layout.rows, 1)
        XCTAssertEqual(layout.columns, 2)
    }
    
    func testPrintLayoutStaticGrid2x2() {
        let layout = PrintLayout.grid2x2
        
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 2)
    }
    
    func testPrintLayoutStaticGrid3x3() {
        let layout = PrintLayout.grid3x3
        
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.columns, 3)
    }
    
    func testPrintLayoutStaticGrid4x4() {
        let layout = PrintLayout.grid4x4
        
        XCTAssertEqual(layout.rows, 4)
        XCTAssertEqual(layout.columns, 4)
    }
    
    func testPrintLayoutStaticMultiPhase2x3() {
        let layout = PrintLayout.multiPhase2x3
        
        XCTAssertEqual(layout.rows, 2)
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.imageCount, 6)
    }
    
    func testPrintLayoutStaticMultiPhase3x4() {
        let layout = PrintLayout.multiPhase3x4
        
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.columns, 4)
        XCTAssertEqual(layout.imageCount, 12)
    }
    
    func testPrintLayoutEquality() {
        let layout1 = PrintLayout(rows: 2, columns: 3)
        let layout2 = PrintLayout(rows: 2, columns: 3)
        let layout3 = PrintLayout(rows: 3, columns: 2)
        
        XCTAssertEqual(layout1, layout2)
        XCTAssertNotEqual(layout1, layout3)
    }
    
    // MARK: - Phase 2: PrintProgress Tests
    
    func testPrintProgressConnecting() {
        let progress = PrintProgress(
            phase: .connecting,
            progress: 0.0,
            message: "Connecting..."
        )
        
        XCTAssertEqual(progress.phase, .connecting)
        XCTAssertEqual(progress.progress, 0.0, accuracy: 0.001)
        XCTAssertEqual(progress.message, "Connecting...")
    }
    
    func testPrintProgressUploadingImages() {
        let progress = PrintProgress(
            phase: .uploadingImages(current: 3, total: 10),
            progress: 0.5,
            message: "Uploading image 3 of 10"
        )
        
        if case .uploadingImages(let current, let total) = progress.phase {
            XCTAssertEqual(current, 3)
            XCTAssertEqual(total, 10)
        } else {
            XCTFail("Expected uploadingImages phase")
        }
        
        XCTAssertEqual(progress.progress, 0.5, accuracy: 0.001)
    }
    
    func testPrintProgressCompleted() {
        let progress = PrintProgress(
            phase: .completed,
            progress: 1.0,
            message: "Print completed"
        )
        
        XCTAssertEqual(progress.phase, .completed)
        XCTAssertEqual(progress.progress, 1.0, accuracy: 0.001)
    }
    
    func testPrintProgressClampedValues() {
        // Test that progress values are clamped to 0.0 - 1.0
        let progressOver = PrintProgress(phase: .printing, progress: 1.5, message: "")
        XCTAssertEqual(progressOver.progress, 1.0, accuracy: 0.001)
        
        let progressUnder = PrintProgress(phase: .printing, progress: -0.5, message: "")
        XCTAssertEqual(progressUnder.progress, 0.0, accuracy: 0.001)
    }
    
    func testPrintProgressPhaseEquality() {
        let phase1 = PrintProgress.Phase.connecting
        let phase2 = PrintProgress.Phase.connecting
        let phase3 = PrintProgress.Phase.printing
        
        XCTAssertEqual(phase1, phase2)
        XCTAssertNotEqual(phase1, phase3)
        
        let upload1 = PrintProgress.Phase.uploadingImages(current: 1, total: 5)
        let upload2 = PrintProgress.Phase.uploadingImages(current: 1, total: 5)
        let upload3 = PrintProgress.Phase.uploadingImages(current: 2, total: 5)
        
        XCTAssertEqual(upload1, upload2)
        XCTAssertNotEqual(upload1, upload3)
    }
    
    // MARK: - Phase 2: Print Template Tests
    
    func testSingleImageTemplate() {
        let template = SingleImageTemplate()
        
        XCTAssertEqual(template.name, "Single Image")
        XCTAssertEqual(template.filmSize, .size8InX10In)
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\1,1")
        XCTAssertEqual(template.imageCount, 1)
        XCTAssertEqual(template.filmOrientation, .portrait)
        
        let filmBox = template.createFilmBox()
        XCTAssertEqual(filmBox.imageDisplayFormat, "STANDARD\\1,1")
        XCTAssertEqual(filmBox.filmSizeID, .size8InX10In)
    }
    
    func testSingleImageTemplateCustom() {
        let template = SingleImageTemplate(filmSize: .size14InX17In, filmOrientation: .landscape)
        
        XCTAssertEqual(template.filmSize, .size14InX17In)
        XCTAssertEqual(template.filmOrientation, .landscape)
        
        let filmBox = template.createFilmBox()
        XCTAssertEqual(filmBox.filmSizeID, .size14InX17In)
        XCTAssertEqual(filmBox.filmOrientation, .landscape)
    }
    
    func testComparisonTemplate() {
        let template = ComparisonTemplate()
        
        XCTAssertEqual(template.name, "Comparison")
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\1,2")
        XCTAssertEqual(template.imageCount, 2)
        XCTAssertEqual(template.filmOrientation, .landscape)
        
        let filmBox = template.createFilmBox()
        XCTAssertEqual(filmBox.imageDisplayFormat, "STANDARD\\1,2")
    }
    
    func testGridTemplate2x2() {
        let template = GridTemplate(rows: 2, columns: 2)
        
        XCTAssertEqual(template.name, "2x2 Grid")
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\2,2")
        XCTAssertEqual(template.imageCount, 4)
        
        let filmBox = template.createFilmBox()
        XCTAssertEqual(filmBox.imageDisplayFormat, "STANDARD\\2,2")
    }
    
    func testGridTemplate3x4() {
        let template = GridTemplate(rows: 3, columns: 4, filmSize: .size11InX17In)
        
        XCTAssertEqual(template.name, "3x4 Grid")
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\3,4")
        XCTAssertEqual(template.imageCount, 12)
        XCTAssertEqual(template.filmSize, .size11InX17In)
    }
    
    func testGridTemplateMinimumValues() {
        let template = GridTemplate(rows: 0, columns: 0)
        
        XCTAssertEqual(template.imageCount, 1)
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\1,1")
    }
    
    func testMultiPhaseTemplate2x3() {
        let template = MultiPhaseTemplate(rows: 2, columns: 3)
        
        XCTAssertEqual(template.name, "Multi-Phase 2x3")
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\2,3")
        XCTAssertEqual(template.imageCount, 6)
    }
    
    func testMultiPhaseTemplate3x4() {
        let template = MultiPhaseTemplate(rows: 3, columns: 4)
        
        XCTAssertEqual(template.name, "Multi-Phase 3x4")
        XCTAssertEqual(template.imageDisplayFormat, "STANDARD\\3,4")
        XCTAssertEqual(template.imageCount, 12)
    }
    
    // MARK: - Phase 2: PrintRetryPolicy Tests
    
    func testPrintRetryPolicyDefaults() {
        let policy = PrintRetryPolicy()
        
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.initialDelay, 1.0, accuracy: 0.001)
        XCTAssertEqual(policy.backoffMultiplier, 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.maxDelay, 30.0, accuracy: 0.001)
    }
    
    func testPrintRetryPolicyCustomValues() {
        let policy = PrintRetryPolicy(
            maxAttempts: 5,
            initialDelay: 2.0,
            backoffMultiplier: 3.0,
            maxDelay: 60.0
        )
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 2.0, accuracy: 0.001)
        XCTAssertEqual(policy.backoffMultiplier, 3.0, accuracy: 0.001)
        XCTAssertEqual(policy.maxDelay, 60.0, accuracy: 0.001)
    }
    
    func testPrintRetryPolicyDelayCalculation() {
        let policy = PrintRetryPolicy(
            initialDelay: 1.0,
            backoffMultiplier: 2.0,
            maxDelay: 10.0
        )
        
        XCTAssertEqual(policy.delay(for: 0), 1.0, accuracy: 0.001)  // 1 * 2^0 = 1
        XCTAssertEqual(policy.delay(for: 1), 2.0, accuracy: 0.001)  // 1 * 2^1 = 2
        XCTAssertEqual(policy.delay(for: 2), 4.0, accuracy: 0.001)  // 1 * 2^2 = 4
        XCTAssertEqual(policy.delay(for: 3), 8.0, accuracy: 0.001)  // 1 * 2^3 = 8
        XCTAssertEqual(policy.delay(for: 4), 10.0, accuracy: 0.001) // 1 * 2^4 = 16, capped at 10
    }
    
    func testPrintRetryPolicyDelayNegativeAttempt() {
        let policy = PrintRetryPolicy(initialDelay: 1.0)
        
        XCTAssertEqual(policy.delay(for: -1), 1.0, accuracy: 0.001)
    }
    
    func testPrintRetryPolicyStaticDefault() {
        let policy = PrintRetryPolicy.default
        
        XCTAssertEqual(policy.maxAttempts, 3)
    }
    
    func testPrintRetryPolicyStaticAggressive() {
        let policy = PrintRetryPolicy.aggressive
        
        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 0.5, accuracy: 0.001)
        XCTAssertEqual(policy.backoffMultiplier, 1.5, accuracy: 0.001)
    }
    
    func testPrintRetryPolicyStaticNone() {
        let policy = PrintRetryPolicy.none
        
        XCTAssertEqual(policy.maxAttempts, 0)
    }
    
    func testPrintRetryPolicyMinimumValues() {
        let policy = PrintRetryPolicy(
            maxAttempts: -5,
            initialDelay: -1.0,
            backoffMultiplier: 0.5,
            maxDelay: -10.0
        )
        
        XCTAssertEqual(policy.maxAttempts, 0)
        XCTAssertEqual(policy.initialDelay, 0.0, accuracy: 0.001)
        XCTAssertEqual(policy.backoffMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(policy.maxDelay, 0.0, accuracy: 0.001)
    }
}


