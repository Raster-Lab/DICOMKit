/// DICOM Print Management Service
///
/// Implements the DICOM Print Management Service Class as defined in PS3.4 Annex H.
/// Provides data models, SOP Class UIDs, and service operations for DICOM printing.
///
/// Reference: PS3.4 Annex H - Print Management Service Class

import Foundation
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#else
// Define CGSize for platforms without CoreGraphics
public struct CGSize: Sendable {
    public let width: Double
    public let height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}
#endif

// MARK: - Print Management SOP Class UIDs

/// Basic Film Session SOP Class UID (PS3.4 H.4.1)
public let basicFilmSessionSOPClassUID = "1.2.840.10008.5.1.1.1"
/// Basic Film Box SOP Class UID (PS3.4 H.4.2)
public let basicFilmBoxSOPClassUID = "1.2.840.10008.5.1.1.2"
/// Basic Grayscale Image Box SOP Class UID (PS3.4 H.4.3)
public let basicGrayscaleImageBoxSOPClassUID = "1.2.840.10008.5.1.1.4"
/// Basic Color Image Box SOP Class UID (PS3.4 H.4.4)
public let basicColorImageBoxSOPClassUID = "1.2.840.10008.5.1.1.4.1"
/// Basic Grayscale Print Management Meta SOP Class UID
public let basicGrayscalePrintManagementMetaSOPClassUID = "1.2.840.10008.5.1.1.9"
/// Basic Color Print Management Meta SOP Class UID
public let basicColorPrintManagementMetaSOPClassUID = "1.2.840.10008.5.1.1.18"
/// Printer SOP Class UID (PS3.4 H.4.7)
public let printerSOPClassUID = "1.2.840.10008.5.1.1.16"
/// Printer SOP Instance UID (Well-Known)
public let printerSOPInstanceUID = "1.2.840.10008.5.1.1.17"
/// Print Job SOP Class UID (PS3.4 H.4.8)
public let printJobSOPClassUID = "1.2.840.10008.5.1.1.14"

// MARK: - Print-specific DICOM Tags

extension Tag {
    // Film Session tags (PS3.3 C.13.1)
    /// Number of Copies (2000,0010)
    public static let numberOfCopies = Tag(group: 0x2000, element: 0x0010)
    /// Print Priority (2000,0020)
    public static let printPriority = Tag(group: 0x2000, element: 0x0020)
    /// Medium Type (2000,0030)
    public static let mediumType = Tag(group: 0x2000, element: 0x0030)
    /// Film Destination (2000,0040)
    public static let filmDestination = Tag(group: 0x2000, element: 0x0040)
    /// Film Session Label (2000,0050)
    public static let filmSessionLabel = Tag(group: 0x2000, element: 0x0050)
    /// Memory Allocation (2000,0060)
    public static let memoryAllocation = Tag(group: 0x2000, element: 0x0060)
    /// Referenced Film Box Sequence (2000,0500)
    public static let referencedFilmBoxSequence = Tag(group: 0x2000, element: 0x0500)
    
    // Film Box tags (PS3.3 C.13.3)
    /// Image Display Format (2010,0010)
    public static let imageDisplayFormat = Tag(group: 0x2010, element: 0x0010)
    /// Annotation Display Format ID (2010,0030)
    public static let annotationDisplayFormatID = Tag(group: 0x2010, element: 0x0030)
    /// Film Orientation (2010,0040)
    public static let filmOrientation = Tag(group: 0x2010, element: 0x0040)
    /// Film Size ID (2010,0050)
    public static let filmSizeID = Tag(group: 0x2010, element: 0x0050)
    /// Magnification Type (2010,0060)
    public static let magnificationType = Tag(group: 0x2010, element: 0x0060)
    /// Smoothing Type (2010,0080)
    public static let smoothingType = Tag(group: 0x2010, element: 0x0080)
    /// Border Density (2010,0100)
    public static let borderDensity = Tag(group: 0x2010, element: 0x0100)
    /// Empty Image Density (2010,0110)
    public static let emptyImageDensity = Tag(group: 0x2010, element: 0x0110)
    /// Min Density (2010,0120)
    public static let minDensity = Tag(group: 0x2010, element: 0x0120)
    /// Max Density (2010,0130)
    public static let maxDensity = Tag(group: 0x2010, element: 0x0130)
    /// Trim (2010,0140)
    public static let trim = Tag(group: 0x2010, element: 0x0140)
    /// Configuration Information (2010,0150)
    public static let configurationInformation = Tag(group: 0x2010, element: 0x0150)
    /// Referenced Film Session Sequence (2010,0500)
    public static let referencedFilmSessionSequence = Tag(group: 0x2010, element: 0x0500)
    /// Referenced Image Box Sequence (2010,0510)
    public static let referencedImageBoxSequence = Tag(group: 0x2010, element: 0x0510)
    
    // Image Box tags (PS3.3 C.13.5)
    /// Image Box Position (2020,0010)
    public static let imageBoxPosition = Tag(group: 0x2020, element: 0x0010)
    /// Polarity (2020,0020)
    public static let polarity = Tag(group: 0x2020, element: 0x0020)
    /// Requested Image Size (2020,0030)
    public static let requestedImageSize = Tag(group: 0x2020, element: 0x0030)
    /// Requested Decimate/Crop Behavior (2020,0040)
    public static let requestedDecimateCropBehavior = Tag(group: 0x2020, element: 0x0040)
    /// Preformatted Grayscale Image Sequence (2020,0110)
    public static let preformattedGrayscaleImageSequence = Tag(group: 0x2020, element: 0x0110)
    /// Preformatted Color Image Sequence (2020,0111)
    public static let preformattedColorImageSequence = Tag(group: 0x2020, element: 0x0111)
    /// Referenced Image Overlay Box Sequence (2020,0130)
    public static let referencedImageOverlayBoxSequence = Tag(group: 0x2020, element: 0x0130)
    
    // Printer tags (PS3.3 C.13.9)
    /// Printer Status (2110,0010)
    public static let printerStatus = Tag(group: 0x2110, element: 0x0010)
    /// Printer Status Info (2110,0020)
    public static let printerStatusInfo = Tag(group: 0x2110, element: 0x0020)
    /// Printer Name (2110,0030)
    public static let printerName = Tag(group: 0x2110, element: 0x0030)
    
    // Print Job tags (PS3.3 C.13.8)
    /// Execution Status (2100,0020)
    public static let executionStatus = Tag(group: 0x2100, element: 0x0020)
    /// Execution Status Info (2100,0030)
    public static let executionStatusInfo = Tag(group: 0x2100, element: 0x0030)
    /// Creation Date (2100,0040)
    public static let creationDate = Tag(group: 0x2100, element: 0x0040)
    /// Creation Time (2100,0050)
    public static let creationTime = Tag(group: 0x2100, element: 0x0050)
    /// Originating Print Management (2100,0070)
    public static let originatingPrintManagement = Tag(group: 0x2100, element: 0x0070)
}

// MARK: - Print Configuration

/// Configuration for DICOM Print operations
public struct PrintConfiguration: Sendable {
    public let host: String
    public let port: UInt16
    public let callingAETitle: String
    public let calledAETitle: String
    public let timeout: TimeInterval
    public let colorMode: PrintColorMode
    
    public init(host: String, port: UInt16, callingAETitle: String, calledAETitle: String,
                timeout: TimeInterval = 30, colorMode: PrintColorMode = .grayscale) {
        self.host = host
        self.port = port
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.colorMode = colorMode
    }
}

/// Print color mode
public enum PrintColorMode: String, Sendable {
    case grayscale = "GRAYSCALE"
    case color = "COLOR"
}

// MARK: - Film Session

/// Film session parameters (PS3.4 H.4.1)
public struct FilmSession: Sendable {
    public let sopInstanceUID: String
    public var numberOfCopies: Int
    public var printPriority: PrintPriority
    public var mediumType: MediumType
    public var filmDestination: FilmDestination
    public var filmSessionLabel: String?
    
    public init(sopInstanceUID: String = "",
                numberOfCopies: Int = 1,
                printPriority: PrintPriority = .medium,
                mediumType: MediumType = .paper,
                filmDestination: FilmDestination = .processor,
                filmSessionLabel: String? = nil) {
        self.sopInstanceUID = sopInstanceUID
        self.numberOfCopies = numberOfCopies
        self.printPriority = printPriority
        self.mediumType = mediumType
        self.filmDestination = filmDestination
        self.filmSessionLabel = filmSessionLabel
    }
}

/// Print priority levels
public enum PrintPriority: String, Sendable {
    case high = "HIGH"
    case medium = "MED"
    case low = "LOW"
}

/// Film medium types
public enum MediumType: String, Sendable {
    case paper = "PAPER"
    case clearFilm = "CLEAR FILM"
    case blueFilm = "BLUE FILM"
    case mammoFilmClearBase = "MAMMO CLEAR"
    case mammoFilmBlueBase = "MAMMO BLUE"
}

/// Film destination
public enum FilmDestination: String, Sendable {
    case magazine = "MAGAZINE"
    case processor = "PROCESSOR"
    case bin1 = "BIN_1"
    case bin2 = "BIN_2"
}

// MARK: - Film Box

/// Film box parameters (PS3.4 H.4.2)
public struct FilmBox: Sendable {
    public let sopInstanceUID: String
    public var imageDisplayFormat: String
    public var filmOrientation: FilmOrientation
    public var filmSizeID: FilmSize
    public var magnificationType: MagnificationType
    public var borderDensity: String
    public var emptyImageDensity: String
    public var trimOption: TrimOption
    public var configurationInformation: String?
    public let imageBoxSOPInstanceUIDs: [String]
    
    public init(sopInstanceUID: String = "",
                imageDisplayFormat: String = "STANDARD\\1,1",
                filmOrientation: FilmOrientation = .portrait,
                filmSizeID: FilmSize = .size8InX10In,
                magnificationType: MagnificationType = .replicate,
                borderDensity: String = "BLACK",
                emptyImageDensity: String = "BLACK",
                trimOption: TrimOption = .no,
                configurationInformation: String? = nil,
                imageBoxSOPInstanceUIDs: [String] = []) {
        self.sopInstanceUID = sopInstanceUID
        self.imageDisplayFormat = imageDisplayFormat
        self.filmOrientation = filmOrientation
        self.filmSizeID = filmSizeID
        self.magnificationType = magnificationType
        self.borderDensity = borderDensity
        self.emptyImageDensity = emptyImageDensity
        self.trimOption = trimOption
        self.configurationInformation = configurationInformation
        self.imageBoxSOPInstanceUIDs = imageBoxSOPInstanceUIDs
    }
}

/// Film orientation
public enum FilmOrientation: String, Sendable {
    case portrait = "PORTRAIT"
    case landscape = "LANDSCAPE"
}

/// Film size identifiers (PS3.3 C.13.6)
public enum FilmSize: String, Sendable {
    case size8InX10In = "8INX10IN"
    case size8_5InX11In = "8_5INX11IN"
    case size10InX12In = "10INX12IN"
    case size10InX14In = "10INX14IN"
    case size11InX14In = "11INX14IN"
    case size11InX17In = "11INX17IN"
    case size14InX14In = "14INX14IN"
    case size14InX17In = "14INX17IN"
    case size24CmX24Cm = "24CMX24CM"
    case size24CmX30Cm = "24CMX30CM"
    case a4 = "A4"
    case a3 = "A3"
}

/// Magnification type
public enum MagnificationType: String, Sendable {
    case replicate = "REPLICATE"
    case bilinear = "BILINEAR"
    case cubic = "CUBIC"
    case none = "NONE"
}

/// Trim option
public enum TrimOption: String, Sendable {
    case yes = "YES"
    case no = "NO"
}

// MARK: - Image Box

/// Image box content (PS3.4 H.4.3)
public struct ImageBoxContent: Sendable {
    public let sopInstanceUID: String
    public var imagePosition: UInt16
    public var polarity: ImagePolarity
    public var requestedImageSize: String?
    public var requestedDecimateCropBehavior: DecimateCropBehavior
    
    public init(sopInstanceUID: String = "",
                imagePosition: UInt16 = 1,
                polarity: ImagePolarity = .normal,
                requestedImageSize: String? = nil,
                requestedDecimateCropBehavior: DecimateCropBehavior = .decimate) {
        self.sopInstanceUID = sopInstanceUID
        self.imagePosition = imagePosition
        self.polarity = polarity
        self.requestedImageSize = requestedImageSize
        self.requestedDecimateCropBehavior = requestedDecimateCropBehavior
    }
}

/// Image polarity
public enum ImagePolarity: String, Sendable {
    case normal = "NORMAL"
    case reverse = "REVERSE"
}

/// Decimate/crop behavior
public enum DecimateCropBehavior: String, Sendable {
    case decimate = "DECIMATE"
    case crop = "CROP"
    case failOver = "FAIL"
}

// MARK: - Printer Status

/// Printer status information
public struct PrinterStatus: Sendable {
    public let status: String
    public let statusInfo: String?
    public let printerName: String?
    
    public init(status: String, statusInfo: String? = nil, printerName: String? = nil) {
        self.status = status
        self.statusInfo = statusInfo
        self.printerName = printerName
    }
    
    /// Whether the printer is in a normal operational state
    public var isNormal: Bool {
        status == "NORMAL"
    }
}

// MARK: - Print Result

/// Result of a print operation
public struct PrintResult: Sendable {
    public let success: Bool
    public let status: DIMSEStatus
    public let filmSessionUID: String?
    public let filmBoxUID: String?
    public let printJobUID: String?
    public let errorMessage: String?
    
    public init(success: Bool, status: DIMSEStatus, filmSessionUID: String? = nil,
                filmBoxUID: String? = nil, printJobUID: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.status = status
        self.filmSessionUID = filmSessionUID
        self.filmBoxUID = filmBoxUID
        self.printJobUID = printJobUID
        self.errorMessage = errorMessage
    }
}

// MARK: - Film Box Result

/// Result of Film Box creation (PS3.4 H.4.2)
public struct FilmBoxResult: Sendable {
    /// The assigned Film Box SOP Instance UID
    public let filmBoxUID: String
    
    /// Array of Image Box SOP Instance UIDs created for this Film Box
    public let imageBoxUIDs: [String]
    
    /// Number of image boxes (calculated from Image Display Format)
    public let imageCount: Int
    
    public init(filmBoxUID: String, imageBoxUIDs: [String], imageCount: Int) {
        self.filmBoxUID = filmBoxUID
        self.imageBoxUIDs = imageBoxUIDs
        self.imageCount = imageCount
    }
}

// MARK: - Print Job Status

/// Status of a print job (PS3.4 H.4.8)
public struct PrintJobStatus: Sendable {
    /// Print Job SOP Instance UID
    public let printJobUID: String
    
    /// Execution status (PENDING, PRINTING, DONE, FAILURE)
    public let executionStatus: String
    
    /// Additional status information (optional)
    public let executionStatusInfo: String?
    
    /// Date when the print job was created
    public let creationDate: Date?
    
    /// Time when the print job was created
    public let creationTime: Date?
    
    public init(printJobUID: String,
                executionStatus: String,
                executionStatusInfo: String? = nil,
                creationDate: Date? = nil,
                creationTime: Date? = nil) {
        self.printJobUID = printJobUID
        self.executionStatus = executionStatus
        self.executionStatusInfo = executionStatusInfo
        self.creationDate = creationDate
        self.creationTime = creationTime
    }
    
    /// Whether the print job is still pending or printing
    public var isInProgress: Bool {
        executionStatus == "PENDING" || executionStatus == "PRINTING"
    }
    
    /// Whether the print job completed successfully
    public var isCompleted: Bool {
        executionStatus == "DONE"
    }
    
    /// Whether the print job failed
    public var isFailed: Bool {
        executionStatus == "FAILURE"
    }
}

// MARK: - Print Options

/// Options for print operations
///
/// Provides configuration options for print jobs including number of copies,
/// priority, film size, orientation, and other print parameters.
public struct PrintOptions: Sendable {
    /// Number of copies to print
    public let numberOfCopies: Int
    
    /// Print priority
    public let priority: PrintPriority
    
    /// Film size
    public let filmSize: FilmSize
    
    /// Film orientation (portrait or landscape)
    public let filmOrientation: FilmOrientation
    
    /// Medium type (paper, film, etc.)
    public let mediumType: MediumType
    
    /// Film destination
    public let filmDestination: FilmDestination
    
    /// Border density (e.g., "BLACK", "WHITE")
    public let borderDensity: String
    
    /// Empty image density
    public let emptyImageDensity: String
    
    /// Magnification type
    public let magnificationType: MagnificationType
    
    /// Image polarity
    public let polarity: ImagePolarity
    
    /// Trim option
    public let trimOption: TrimOption
    
    /// Optional session label
    public let sessionLabel: String?
    
    /// Creates print options with specified parameters
    public init(
        numberOfCopies: Int = 1,
        priority: PrintPriority = .medium,
        filmSize: FilmSize = .size8InX10In,
        filmOrientation: FilmOrientation = .portrait,
        mediumType: MediumType = .clearFilm,
        filmDestination: FilmDestination = .processor,
        borderDensity: String = "BLACK",
        emptyImageDensity: String = "BLACK",
        magnificationType: MagnificationType = .replicate,
        polarity: ImagePolarity = .normal,
        trimOption: TrimOption = .no,
        sessionLabel: String? = nil
    ) {
        self.numberOfCopies = numberOfCopies
        self.priority = priority
        self.filmSize = filmSize
        self.filmOrientation = filmOrientation
        self.mediumType = mediumType
        self.filmDestination = filmDestination
        self.borderDensity = borderDensity
        self.emptyImageDensity = emptyImageDensity
        self.magnificationType = magnificationType
        self.polarity = polarity
        self.trimOption = trimOption
        self.sessionLabel = sessionLabel
    }
    
    /// Default print options for general use
    ///
    /// Uses standard settings suitable for most print jobs:
    /// - Single copy
    /// - Medium priority
    /// - 8x10 inch film
    /// - Portrait orientation
    /// - Clear film medium
    public static let `default` = PrintOptions()
    
    /// High quality print options
    ///
    /// Uses settings optimized for best print quality:
    /// - Bilinear magnification
    /// - Clear film medium
    /// - High priority
    public static let highQuality = PrintOptions(
        priority: .high,
        filmSize: .size14InX17In,
        mediumType: .clearFilm,
        magnificationType: .bilinear
    )
    
    /// Draft print options for quick previews
    ///
    /// Uses settings optimized for fast printing:
    /// - Paper medium
    /// - Low priority
    /// - Smaller film size
    public static let draft = PrintOptions(
        priority: .low,
        filmSize: .size8_5InX11In,
        mediumType: .paper,
        magnificationType: .replicate
    )
    
    /// Mammography print options
    ///
    /// Uses settings suitable for mammography:
    /// - Mammography blue film
    /// - High priority
    /// - Large film size
    public static let mammography = PrintOptions(
        priority: .high,
        filmSize: .size14InX17In,
        mediumType: .mammoFilmBlueBase,
        magnificationType: .bilinear
    )
}

// MARK: - Print Layout

/// Represents a print layout (rows x columns)
public struct PrintLayout: Sendable, Equatable {
    /// Number of rows in the layout
    public let rows: Int
    
    /// Number of columns in the layout
    public let columns: Int
    
    /// Total number of image positions
    public var imageCount: Int {
        rows * columns
    }
    
    /// Image display format string for DICOM
    public var imageDisplayFormat: String {
        "STANDARD\\\(rows),\(columns)"
    }
    
    /// Creates a print layout with the specified dimensions
    public init(rows: Int, columns: Int) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
    }
    
    /// Determines the optimal layout for a given number of images
    ///
    /// - Parameter imageCount: Number of images to fit
    /// - Returns: The optimal layout
    public static func optimalLayout(for imageCount: Int) -> PrintLayout {
        switch imageCount {
        case 1:
            return PrintLayout(rows: 1, columns: 1)
        case 2:
            return PrintLayout(rows: 1, columns: 2)
        case 3, 4:
            return PrintLayout(rows: 2, columns: 2)
        case 5, 6:
            return PrintLayout(rows: 2, columns: 3)
        case 7, 8, 9:
            return PrintLayout(rows: 3, columns: 3)
        case 10, 11, 12:
            return PrintLayout(rows: 3, columns: 4)
        case 13, 14, 15, 16:
            return PrintLayout(rows: 4, columns: 4)
        case 17...20:
            return PrintLayout(rows: 4, columns: 5)
        default:
            // For more than 20 images, use 5x5 layout
            return PrintLayout(rows: 5, columns: 5)
        }
    }
    
    /// Standard single image layout (1x1)
    public static let singleImage = PrintLayout(rows: 1, columns: 1)
    
    /// Standard comparison layout (1x2)
    public static let comparison = PrintLayout(rows: 1, columns: 2)
    
    /// Standard 2x2 grid layout
    public static let grid2x2 = PrintLayout(rows: 2, columns: 2)
    
    /// Standard 3x3 grid layout
    public static let grid3x3 = PrintLayout(rows: 3, columns: 3)
    
    /// Standard 4x4 grid layout
    public static let grid4x4 = PrintLayout(rows: 4, columns: 4)
    
    /// Multi-phase layout (2x3)
    public static let multiPhase2x3 = PrintLayout(rows: 2, columns: 3)
    
    /// Multi-phase layout (3x4)
    public static let multiPhase3x4 = PrintLayout(rows: 3, columns: 4)
}

// MARK: - Print Progress

/// Progress information for print operations
public struct PrintProgress: Sendable {
    /// Phase of the print operation
    public enum Phase: Sendable, Equatable {
        /// Connecting to print server
        case connecting
        /// Querying printer status
        case queryingPrinter
        /// Creating print session
        case creatingSession
        /// Preparing images for printing
        case preparingImages
        /// Uploading images to printer
        case uploadingImages(current: Int, total: Int)
        /// Sending print command
        case printing
        /// Cleaning up session
        case cleanup
        /// Print operation completed
        case completed
    }
    
    /// Current phase of the operation
    public let phase: Phase
    
    /// Progress value from 0.0 to 1.0
    public let progress: Double
    
    /// Human-readable progress message
    public let message: String
    
    /// Creates a progress update
    public init(phase: Phase, progress: Double, message: String) {
        self.phase = phase
        self.progress = max(0.0, min(1.0, progress))
        self.message = message
    }
}

// MARK: - Print Template Protocol

/// Protocol for defining reusable print layouts
///
/// Print templates encapsulate common print configurations that can be
/// reused across different print jobs. Templates define the layout,
/// film size, and other parameters.
public protocol PrintTemplate: Sendable {
    /// Template name
    var name: String { get }
    
    /// Template description
    var description: String { get }
    
    /// Preferred film size for this template
    var filmSize: FilmSize { get }
    
    /// Image display format (e.g., "STANDARD\\2,2")
    var imageDisplayFormat: String { get }
    
    /// Number of images this template can hold
    var imageCount: Int { get }
    
    /// Preferred film orientation
    var filmOrientation: FilmOrientation { get }
    
    /// Creates a FilmBox configured with this template's settings
    func createFilmBox() -> FilmBox
}

// MARK: - Built-in Print Templates

/// Single image print template (1x1)
public struct SingleImageTemplate: PrintTemplate {
    public let name = "Single Image"
    public let description = "Single image fills entire film"
    public let filmSize: FilmSize
    public let imageDisplayFormat = "STANDARD\\1,1"
    public let imageCount = 1
    public let filmOrientation: FilmOrientation
    
    public init(filmSize: FilmSize = .size8InX10In, filmOrientation: FilmOrientation = .portrait) {
        self.filmSize = filmSize
        self.filmOrientation = filmOrientation
    }
    
    public func createFilmBox() -> FilmBox {
        FilmBox(
            imageDisplayFormat: imageDisplayFormat,
            filmOrientation: filmOrientation,
            filmSizeID: filmSize
        )
    }
}

/// Comparison template (1x2) for side-by-side comparison
public struct ComparisonTemplate: PrintTemplate {
    public let name = "Comparison"
    public let description = "Two images side by side for comparison"
    public let filmSize: FilmSize
    public let imageDisplayFormat = "STANDARD\\1,2"
    public let imageCount = 2
    public let filmOrientation: FilmOrientation
    
    public init(filmSize: FilmSize = .size11InX14In, filmOrientation: FilmOrientation = .landscape) {
        self.filmSize = filmSize
        self.filmOrientation = filmOrientation
    }
    
    public func createFilmBox() -> FilmBox {
        FilmBox(
            imageDisplayFormat: imageDisplayFormat,
            filmOrientation: filmOrientation,
            filmSizeID: filmSize
        )
    }
}

/// Grid template for configurable row/column layouts
public struct GridTemplate: PrintTemplate {
    public let name: String
    public let description: String
    public let filmSize: FilmSize
    public let imageDisplayFormat: String
    public let imageCount: Int
    public let filmOrientation: FilmOrientation
    private let rows: Int
    private let columns: Int
    
    public init(rows: Int, columns: Int, filmSize: FilmSize = .size14InX17In, filmOrientation: FilmOrientation = .portrait) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.name = "\(self.rows)x\(self.columns) Grid"
        self.description = "\(self.rows * self.columns) images in a \(self.rows)x\(self.columns) grid"
        self.filmSize = filmSize
        self.imageDisplayFormat = "STANDARD\\\(self.rows),\(self.columns)"
        self.imageCount = self.rows * self.columns
        self.filmOrientation = filmOrientation
    }
    
    public func createFilmBox() -> FilmBox {
        FilmBox(
            imageDisplayFormat: imageDisplayFormat,
            filmOrientation: filmOrientation,
            filmSizeID: filmSize
        )
    }
}

/// Multi-phase template for temporal series (e.g., 3x4 for multi-phase CT)
public struct MultiPhaseTemplate: PrintTemplate {
    public let name: String
    public let description: String
    public let filmSize: FilmSize
    public let imageDisplayFormat: String
    public let imageCount: Int
    public let filmOrientation: FilmOrientation
    private let rows: Int
    private let columns: Int
    
    public init(rows: Int, columns: Int, filmSize: FilmSize = .size14InX17In, filmOrientation: FilmOrientation = .portrait) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.name = "Multi-Phase \(self.rows)x\(self.columns)"
        self.description = "Multi-phase layout with \(self.rows * self.columns) images (\(self.rows) rows × \(self.columns) columns)"
        self.filmSize = filmSize
        self.imageDisplayFormat = "STANDARD\\\(self.rows),\(self.columns)"
        self.imageCount = self.rows * self.columns
        self.filmOrientation = filmOrientation
    }
    
    public func createFilmBox() -> FilmBox {
        FilmBox(
            imageDisplayFormat: imageDisplayFormat,
            filmOrientation: filmOrientation,
            filmSizeID: filmSize
        )
    }
}

// MARK: - Convenience Template Extensions

extension PrintTemplate where Self == SingleImageTemplate {
    /// Single image template with default settings
    public static var singleImage: SingleImageTemplate {
        SingleImageTemplate()
    }
}

extension PrintTemplate where Self == ComparisonTemplate {
    /// Comparison template with default settings
    public static var comparison: ComparisonTemplate {
        ComparisonTemplate()
    }
}

extension PrintTemplate where Self == GridTemplate {
    /// 2x2 grid template
    public static var grid2x2: GridTemplate {
        GridTemplate(rows: 2, columns: 2)
    }
    
    /// 3x3 grid template
    public static var grid3x3: GridTemplate {
        GridTemplate(rows: 3, columns: 3)
    }
    
    /// 4x4 grid template
    public static var grid4x4: GridTemplate {
        GridTemplate(rows: 4, columns: 4)
    }
}

extension PrintTemplate where Self == MultiPhaseTemplate {
    /// Multi-phase 2x3 template
    public static var multiPhase2x3: MultiPhaseTemplate {
        MultiPhaseTemplate(rows: 2, columns: 3)
    }
    
    /// Multi-phase 3x4 template
    public static var multiPhase3x4: MultiPhaseTemplate {
        MultiPhaseTemplate(rows: 3, columns: 4)
    }
    
    /// Multi-phase 4x5 template
    public static var multiPhase4x5: MultiPhaseTemplate {
        MultiPhaseTemplate(rows: 4, columns: 5)
    }
}

// MARK: - Print Retry Policy

/// Policy for retrying print operations
public struct PrintRetryPolicy: Sendable {
    /// Maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Initial delay before first retry (in seconds)
    public let initialDelay: TimeInterval
    
    /// Multiplier for exponential backoff
    public let backoffMultiplier: Double
    
    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval
    
    /// Creates a retry policy with specified parameters
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.maxAttempts = max(0, maxAttempts)
        self.initialDelay = max(0, initialDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.maxDelay = max(max(0, maxDelay), self.initialDelay)
    }
    
    /// Calculates the delay for a given attempt number
    /// - Parameter attempt: The attempt number (0-based)
    /// - Returns: The delay in seconds
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt >= 0 else { return initialDelay }
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
        return min(delay, maxDelay)
    }
    
    /// Default retry policy
    public static let `default` = PrintRetryPolicy()
    
    /// Aggressive retry policy for critical prints
    public static let aggressive = PrintRetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 10.0
    )
    
    /// No retry policy
    public static let none = PrintRetryPolicy(maxAttempts: 0)
}

// MARK: - Phase 4: Print Job

/// Represents a print job in the queue
///
/// Print jobs contain all information needed to execute a print operation,
/// including the printer configuration, images to print, and options.
public struct PrintJob: Sendable, Identifiable {
    /// Unique identifier for this job
    public let id: UUID
    
    /// Printer configuration
    public let configuration: PrintConfiguration
    
    /// File URLs for images to print
    public let imageURLs: [URL]
    
    /// Print options
    public let options: PrintOptions
    
    /// Job priority
    public let priority: PrintPriority
    
    /// Date when job was created
    public let createdAt: Date
    
    /// Optional label for the job
    public let label: String?
    
    /// Creates a new print job
    public init(
        id: UUID = UUID(),
        configuration: PrintConfiguration,
        imageURLs: [URL],
        options: PrintOptions = .default,
        priority: PrintPriority = .medium,
        createdAt: Date = Date(),
        label: String? = nil
    ) {
        self.id = id
        self.configuration = configuration
        self.imageURLs = imageURLs
        self.options = options
        self.priority = priority
        self.createdAt = createdAt
        self.label = label
    }
}

// MARK: - Print Job Record

/// Record of a completed print job for history tracking
public struct PrintJobRecord: Sendable, Identifiable {
    /// Unique identifier (matches the original job)
    public let id: UUID
    
    /// Job label
    public let label: String?
    
    /// Number of images printed
    public let imageCount: Int
    
    /// Date when job was submitted
    public let submittedAt: Date
    
    /// Date when job completed
    public let completedAt: Date
    
    /// Whether the job completed successfully
    public let success: Bool
    
    /// Error message if the job failed
    public let errorMessage: String?
    
    /// Printer name that processed the job
    public let printerName: String?
    
    public init(
        id: UUID,
        label: String?,
        imageCount: Int,
        submittedAt: Date,
        completedAt: Date,
        success: Bool,
        errorMessage: String? = nil,
        printerName: String? = nil
    ) {
        self.id = id
        self.label = label
        self.imageCount = imageCount
        self.submittedAt = submittedAt
        self.completedAt = completedAt
        self.success = success
        self.errorMessage = errorMessage
        self.printerName = printerName
    }
}

// MARK: - Print Queue Status

/// Status of a job in the print queue
public enum PrintQueueJobStatus: Sendable, Equatable {
    /// Job is waiting to be processed
    case queued(position: Int)
    
    /// Job is currently being processed
    case processing
    
    /// Job completed successfully
    case completed
    
    /// Job failed with an error
    case failed(message: String)
    
    /// Job was cancelled
    case cancelled
}

// MARK: - Print Queue

/// Actor for managing a queue of print jobs
///
/// The print queue provides:
/// - Priority-based scheduling
/// - Concurrent job processing (for multiple printers)
/// - Job history tracking
/// - Automatic retry on failure
public actor PrintQueue {
    /// Queued jobs sorted by priority and creation time
    private var queue: [PrintJob] = []
    
    /// Currently processing job IDs
    private var processing: Set<UUID> = []
    
    /// Completed job records
    private var history: [PrintJobRecord] = []
    
    /// Maximum number of history records to keep
    private let maxHistorySize: Int
    
    /// Retry policy for failed jobs
    private let retryPolicy: PrintRetryPolicy
    
    /// Retry counts for jobs
    private var retryCounts: [UUID: Int] = [:]
    
    /// Creates a new print queue
    /// - Parameters:
    ///   - maxHistorySize: Maximum history records (default 100)
    ///   - retryPolicy: Policy for retrying failed jobs
    public init(maxHistorySize: Int = 100, retryPolicy: PrintRetryPolicy = .default) {
        self.maxHistorySize = maxHistorySize
        self.retryPolicy = retryPolicy
    }
    
    // MARK: - Queue Operations
    
    /// Adds a job to the queue
    /// - Parameter job: The job to enqueue
    /// - Returns: The job ID
    @discardableResult
    public func enqueue(job: PrintJob) -> UUID {
        queue.append(job)
        sortQueue()
        return job.id
    }
    
    /// Retrieves and removes the next job from the queue
    /// - Returns: The next job to process, or nil if queue is empty
    public func dequeue() -> PrintJob? {
        guard !queue.isEmpty else { return nil }
        let job = queue.removeFirst()
        processing.insert(job.id)
        return job
    }
    
    /// Peeks at the next job without removing it
    /// - Returns: The next job, or nil if queue is empty
    public func peek() -> PrintJob? {
        queue.first
    }
    
    /// Cancels a queued job
    /// - Parameter jobID: ID of the job to cancel
    /// - Returns: True if the job was found and cancelled
    @discardableResult
    public func cancel(jobID: UUID) -> Bool {
        if let index = queue.firstIndex(where: { $0.id == jobID }) {
            let job = queue.remove(at: index)
            
            // Record as cancelled
            let record = PrintJobRecord(
                id: job.id,
                label: job.label,
                imageCount: job.imageURLs.count,
                submittedAt: job.createdAt,
                completedAt: Date(),
                success: false,
                errorMessage: "Cancelled by user"
            )
            addToHistory(record)
            
            return true
        }
        return false
    }
    
    /// Reports that a job completed successfully
    /// - Parameters:
    ///   - jobID: ID of the completed job
    ///   - printerName: Name of the printer that processed the job
    public func markCompleted(jobID: UUID, printerName: String? = nil) {
        processing.remove(jobID)
        retryCounts.removeValue(forKey: jobID)
        
        // Find job details for history (might be nil if already removed)
        // Create a record with available information
        let record = PrintJobRecord(
            id: jobID,
            label: nil,
            imageCount: 0,
            submittedAt: Date(),
            completedAt: Date(),
            success: true,
            printerName: printerName
        )
        addToHistory(record)
    }
    
    /// Reports that a job failed
    /// - Parameters:
    ///   - jobID: ID of the failed job
    ///   - error: The error that caused the failure
    ///   - job: The original job (for retry)
    /// - Returns: True if the job will be retried
    @discardableResult
    public func markFailed(jobID: UUID, error: Error, job: PrintJob? = nil) -> Bool {
        processing.remove(jobID)
        
        let retryCount = retryCounts[jobID] ?? 0
        
        // Check if we should retry
        if retryCount < retryPolicy.maxAttempts, let job = job {
            retryCounts[jobID] = retryCount + 1
            // Re-queue the job
            queue.append(job)
            sortQueue()
            return true
        }
        
        // No more retries - record as failed
        retryCounts.removeValue(forKey: jobID)
        
        let record = PrintJobRecord(
            id: jobID,
            label: job?.label,
            imageCount: job?.imageURLs.count ?? 0,
            submittedAt: job?.createdAt ?? Date(),
            completedAt: Date(),
            success: false,
            errorMessage: error.localizedDescription
        )
        addToHistory(record)
        
        return false
    }
    
    // MARK: - Queue Status
    
    /// Gets the status of a specific job
    /// - Parameter jobID: ID of the job
    /// - Returns: The job status, or nil if not found
    public func status(jobID: UUID) -> PrintQueueJobStatus? {
        if processing.contains(jobID) {
            return .processing
        }
        
        if let position = queue.firstIndex(where: { $0.id == jobID }) {
            return .queued(position: position + 1)
        }
        
        if let record = history.first(where: { $0.id == jobID }) {
            if record.success {
                return .completed
            } else if record.errorMessage == "Cancelled by user" {
                return .cancelled
            } else {
                return .failed(message: record.errorMessage ?? "Unknown error")
            }
        }
        
        return nil
    }
    
    /// Number of jobs in the queue
    public var queuedCount: Int {
        queue.count
    }
    
    /// Number of jobs currently being processed
    public var processingCount: Int {
        processing.count
    }
    
    /// Whether the queue is empty
    public var isEmpty: Bool {
        queue.isEmpty
    }
    
    /// Gets a copy of all queued jobs
    public func allQueuedJobs() -> [PrintJob] {
        queue
    }
    
    // MARK: - History
    
    /// Gets print history
    /// - Parameter limit: Maximum number of records to return
    /// - Returns: Recent print job records (most recent first)
    public func getHistory(limit: Int = 50) -> [PrintJobRecord] {
        let count = min(limit, history.count)
        return Array(history.prefix(count))
    }
    
    /// Clears the print history
    public func clearHistory() {
        history.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func sortQueue() {
        // Sort by priority (high first) then by creation time (oldest first)
        queue.sort { job1, job2 in
            if job1.priority != job2.priority {
                return priorityValue(job1.priority) > priorityValue(job2.priority)
            }
            return job1.createdAt < job2.createdAt
        }
    }
    
    private func priorityValue(_ priority: PrintPriority) -> Int {
        switch priority {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }
    
    private func addToHistory(_ record: PrintJobRecord) {
        history.insert(record, at: 0)
        
        // Trim history if needed
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }
    }
}

// MARK: - Printer Capabilities

/// Capabilities of a DICOM printer
public struct PrinterCapabilities: Sendable, Equatable {
    /// Supported film sizes
    public let supportedFilmSizes: [FilmSize]
    
    /// Whether the printer supports color
    public let supportsColor: Bool
    
    /// Maximum number of copies per print job
    public let maxCopies: Int
    
    /// Supported medium types
    public let supportedMediumTypes: [MediumType]
    
    /// Supported magnification types
    public let supportedMagnificationTypes: [MagnificationType]
    
    /// Maximum images per film box
    public let maxImagesPerFilmBox: Int
    
    public init(
        supportedFilmSizes: [FilmSize] = FilmSize.allCases,
        supportsColor: Bool = true,
        maxCopies: Int = 99,
        supportedMediumTypes: [MediumType] = MediumType.allCases,
        supportedMagnificationTypes: [MagnificationType] = MagnificationType.allCases,
        maxImagesPerFilmBox: Int = 25
    ) {
        self.supportedFilmSizes = supportedFilmSizes
        self.supportsColor = supportsColor
        self.maxCopies = maxCopies
        self.supportedMediumTypes = supportedMediumTypes
        self.supportedMagnificationTypes = supportedMagnificationTypes
        self.maxImagesPerFilmBox = maxImagesPerFilmBox
    }
    
    /// Default capabilities (assumes full feature support)
    public static let `default` = PrinterCapabilities()
}

// MARK: - FilmSize CaseIterable

extension FilmSize: CaseIterable {
    public static let allCases: [FilmSize] = [
        .size8InX10In, .size8_5InX11In, .size10InX12In, .size10InX14In,
        .size11InX14In, .size11InX17In, .size14InX14In, .size14InX17In,
        .size24CmX24Cm, .size24CmX30Cm, .a4, .a3
    ]
}

// MARK: - MediumType CaseIterable

extension MediumType: CaseIterable {
    public static let allCases: [MediumType] = [
        .paper, .clearFilm, .blueFilm, .mammoFilmClearBase, .mammoFilmBlueBase
    ]
}

// MARK: - MagnificationType CaseIterable

extension MagnificationType: CaseIterable {
    public static let allCases: [MagnificationType] = [
        .replicate, .bilinear, .cubic, .none
    ]
}

// MARK: - Printer Info

/// Information about a configured DICOM printer
public struct PrinterInfo: Sendable, Identifiable, Equatable {
    /// Unique identifier for this printer
    public let id: UUID
    
    /// Human-readable printer name
    public let name: String
    
    /// Connection configuration
    public let configuration: PrintConfiguration
    
    /// Printer capabilities
    public let capabilities: PrinterCapabilities
    
    /// Whether this is the default printer
    public var isDefault: Bool
    
    /// Whether the printer is currently available
    public var isAvailable: Bool
    
    /// Last time the printer was successfully contacted
    public var lastSeenAt: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        configuration: PrintConfiguration,
        capabilities: PrinterCapabilities = .default,
        isDefault: Bool = false,
        isAvailable: Bool = true,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
        self.capabilities = capabilities
        self.isDefault = isDefault
        self.isAvailable = isAvailable
        self.lastSeenAt = lastSeenAt
    }
    
    public static func == (lhs: PrinterInfo, rhs: PrinterInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Printer Registry

/// Actor for managing multiple DICOM printers
///
/// The printer registry provides:
/// - Printer discovery and registration
/// - Health checks and availability tracking
/// - Default printer selection
/// - Load balancing across printers
public actor PrinterRegistry {
    /// Registered printers
    private var printers: [UUID: PrinterInfo] = [:]
    
    /// ID of the default printer
    private var defaultPrinterID: UUID?
    
    /// Creates a new printer registry
    public init() {}
    
    // MARK: - Printer Management
    
    /// Adds a printer to the registry
    /// - Parameter printer: Printer information
    /// - Throws: PrinterRegistryError if a printer with the same ID exists
    public func addPrinter(_ printer: PrinterInfo) throws {
        guard printers[printer.id] == nil else {
            throw PrinterRegistryError.printerAlreadyExists(id: printer.id)
        }
        
        var info = printer
        
        // If this is the first printer or marked as default, set as default
        if printers.isEmpty || printer.isDefault {
            // Clear previous default
            if let prevDefaultID = defaultPrinterID {
                printers[prevDefaultID]?.isDefault = false
            }
            defaultPrinterID = printer.id
            info.isDefault = true
        }
        
        printers[printer.id] = info
    }
    
    /// Removes a printer from the registry
    /// - Parameter id: ID of the printer to remove
    /// - Returns: The removed printer info, or nil if not found
    @discardableResult
    public func removePrinter(id: UUID) -> PrinterInfo? {
        let removed = printers.removeValue(forKey: id)
        
        // If we removed the default, select a new default
        if id == defaultPrinterID {
            defaultPrinterID = printers.keys.first
            if let newDefaultID = defaultPrinterID {
                printers[newDefaultID]?.isDefault = true
            }
        }
        
        return removed
    }
    
    /// Updates a printer in the registry
    /// - Parameter printer: Updated printer information
    /// - Throws: PrinterRegistryError if printer not found
    public func updatePrinter(_ printer: PrinterInfo) throws {
        guard printers[printer.id] != nil else {
            throw PrinterRegistryError.printerNotFound(id: printer.id)
        }
        
        var info = printer
        
        // Handle default printer logic
        if printer.isDefault && defaultPrinterID != printer.id {
            // Clear previous default
            if let prevDefaultID = defaultPrinterID {
                printers[prevDefaultID]?.isDefault = false
            }
            defaultPrinterID = printer.id
        } else if !printer.isDefault && defaultPrinterID == printer.id {
            // Can't unset default without setting another - keep it default
            info.isDefault = true
        }
        
        printers[printer.id] = info
    }
    
    /// Gets a printer by ID
    /// - Parameter id: Printer ID
    /// - Returns: Printer info, or nil if not found
    public func printer(id: UUID) -> PrinterInfo? {
        printers[id]
    }
    
    /// Gets a printer by name
    /// - Parameter name: Printer name
    /// - Returns: Printer info, or nil if not found
    public func printer(named name: String) -> PrinterInfo? {
        printers.values.first { $0.name == name }
    }
    
    // MARK: - Listing
    
    /// Lists all registered printers
    /// - Returns: Array of printer info
    public func listPrinters() -> [PrinterInfo] {
        Array(printers.values)
    }
    
    /// Lists available printers (currently online)
    /// - Returns: Array of available printer info
    public func listAvailablePrinters() -> [PrinterInfo] {
        printers.values.filter { $0.isAvailable }
    }
    
    /// Number of registered printers
    public var count: Int {
        printers.count
    }
    
    // MARK: - Default Printer
    
    /// Gets the default printer
    /// - Returns: Default printer info, or nil if no printers registered
    public func defaultPrinter() -> PrinterInfo? {
        guard let id = defaultPrinterID else { return nil }
        return printers[id]
    }
    
    /// Sets the default printer
    /// - Parameter id: ID of the printer to set as default
    /// - Throws: PrinterRegistryError if printer not found
    public func setDefaultPrinter(id: UUID) throws {
        guard printers[id] != nil else {
            throw PrinterRegistryError.printerNotFound(id: id)
        }
        
        // Clear previous default
        if let prevDefaultID = defaultPrinterID {
            printers[prevDefaultID]?.isDefault = false
        }
        
        printers[id]?.isDefault = true
        defaultPrinterID = id
    }
    
    // MARK: - Availability
    
    /// Updates the availability status of a printer
    /// - Parameters:
    ///   - id: Printer ID
    ///   - isAvailable: Whether the printer is available
    public func updateAvailability(id: UUID, isAvailable: Bool) {
        printers[id]?.isAvailable = isAvailable
        if isAvailable {
            printers[id]?.lastSeenAt = Date()
        }
    }
    
    /// Marks a printer as seen (updates lastSeenAt)
    /// - Parameter id: Printer ID
    public func markSeen(id: UUID) {
        printers[id]?.lastSeenAt = Date()
        printers[id]?.isAvailable = true
    }
    
    // MARK: - Load Balancing
    
    /// Selects the best available printer for a job
    ///
    /// Selection criteria:
    /// 1. Must be available
    /// 2. Must support required capabilities
    /// 3. Prefers default printer if available
    ///
    /// - Parameters:
    ///   - requiresColor: Whether the job requires color printing
    ///   - filmSize: Required film size
    /// - Returns: Best printer for the job, or nil if none suitable
    public func selectPrinter(requiresColor: Bool = false, filmSize: FilmSize? = nil) -> PrinterInfo? {
        let available = printers.values.filter { $0.isAvailable }
        
        guard !available.isEmpty else { return nil }
        
        // Filter by capabilities
        let suitable = available.filter { printer in
            // Check color support
            if requiresColor && !printer.capabilities.supportsColor {
                return false
            }
            
            // Check film size support
            if let size = filmSize, !printer.capabilities.supportedFilmSizes.contains(size) {
                return false
            }
            
            return true
        }
        
        // Prefer default printer if it's suitable
        if let defaultID = defaultPrinterID,
           let defaultPrinter = suitable.first(where: { $0.id == defaultID }) {
            return defaultPrinter
        }
        
        // Return first suitable printer
        return suitable.first
    }
}

// MARK: - Printer Registry Error

/// Errors that can occur in printer registry operations
public enum PrinterRegistryError: Error, CustomStringConvertible, Equatable {
    /// Printer with the specified ID already exists
    case printerAlreadyExists(id: UUID)
    
    /// Printer with the specified ID was not found
    case printerNotFound(id: UUID)
    
    /// No suitable printer available for the job
    case noPrinterAvailable
    
    public var description: String {
        switch self {
        case .printerAlreadyExists(let id):
            return "Printer already exists: \(id)"
        case .printerNotFound(let id):
            return "Printer not found: \(id)"
        case .noPrinterAvailable:
            return "No suitable printer available"
        }
    }
}

// MARK: - Print Error (Phase 4.3)

/// Detailed error types for print operations
public enum PrintError: Error, CustomStringConvertible, Equatable {
    /// Printer is unavailable or offline
    case printerUnavailable(message: String)
    
    /// Failed to create film session
    case filmSessionCreationFailed(statusCode: UInt16)
    
    /// Failed to create film box
    case filmBoxCreationFailed(statusCode: UInt16)
    
    /// Failed to set image box content
    case imageBoxSetFailed(position: Int, statusCode: UInt16)
    
    /// Print job execution failed
    case printJobFailed(status: String, info: String?)
    
    /// Operation timed out
    case timeout(operation: String)
    
    /// Invalid configuration
    case invalidConfiguration(reason: String)
    
    /// Image preparation failed
    case imagePreparationFailed(reason: String)
    
    /// Network error
    case networkError(message: String)
    
    /// Queue is full
    case queueFull(maxSize: Int)
    
    public var description: String {
        switch self {
        case .printerUnavailable(let message):
            return "Printer unavailable: \(message)"
        case .filmSessionCreationFailed(let statusCode):
            return "Failed to create film session (status: 0x\(String(statusCode, radix: 16, uppercase: true)))"
        case .filmBoxCreationFailed(let statusCode):
            return "Failed to create film box (status: 0x\(String(statusCode, radix: 16, uppercase: true)))"
        case .imageBoxSetFailed(let position, let statusCode):
            return "Failed to set image at position \(position) (status: 0x\(String(statusCode, radix: 16, uppercase: true)))"
        case .printJobFailed(let status, let info):
            if let info = info {
                return "Print job failed: \(status) - \(info)"
            }
            return "Print job failed: \(status)"
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .imagePreparationFailed(let reason):
            return "Image preparation failed: \(reason)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .queueFull(let maxSize):
            return "Print queue is full (maximum \(maxSize) jobs)"
        }
    }
    
    /// Suggested recovery action for this error
    public var recoverySuggestion: String {
        switch self {
        case .printerUnavailable:
            return "Check that the printer is powered on and connected to the network. Verify the printer address and port."
        case .filmSessionCreationFailed:
            return "The printer may be busy or have insufficient resources. Try again later or check printer status."
        case .filmBoxCreationFailed:
            return "Verify that the film size and layout are supported by the printer."
        case .imageBoxSetFailed:
            return "Check that the image format is compatible with the printer. Try reducing image complexity."
        case .printJobFailed:
            return "Check the printer status for paper/film jams or other hardware issues."
        case .timeout:
            return "Increase the timeout value or check network connectivity."
        case .invalidConfiguration:
            return "Review and correct the printer configuration settings."
        case .imagePreparationFailed:
            return "Verify that the DICOM image is valid and contains pixel data."
        case .networkError:
            return "Check network connectivity and firewall settings."
        case .queueFull:
            return "Wait for current jobs to complete or cancel pending jobs."
        }
    }
}

// MARK: - Partial Print Result

/// Result of a print operation that may have partially succeeded
public struct PartialPrintResult: Sendable {
    /// Number of images that printed successfully
    public let successCount: Int
    
    /// Number of images that failed to print
    public let failureCount: Int
    
    /// Positions of images that failed (1-based)
    public let failedPositions: [Int]
    
    /// Errors that occurred during printing
    public let errors: [PrintError]
    
    /// Film session UID (if created)
    public let filmSessionUID: String?
    
    /// Print job UID (if created)
    public let printJobUID: String?
    
    /// Overall success status
    public var isFullySuccessful: Bool {
        failureCount == 0
    }
    
    /// Overall failure status
    public var isFullyFailed: Bool {
        successCount == 0 && failureCount > 0
    }
    
    /// Partial success status
    public var isPartiallySuccessful: Bool {
        successCount > 0 && failureCount > 0
    }
    
    public init(
        successCount: Int,
        failureCount: Int,
        failedPositions: [Int] = [],
        errors: [PrintError] = [],
        filmSessionUID: String? = nil,
        printJobUID: String? = nil
    ) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.failedPositions = failedPositions
        self.errors = errors
        self.filmSessionUID = filmSessionUID
        self.printJobUID = printJobUID
    }
    
    /// Creates a successful result
    public static func success(count: Int, filmSessionUID: String? = nil, printJobUID: String? = nil) -> PartialPrintResult {
        PartialPrintResult(
            successCount: count,
            failureCount: 0,
            filmSessionUID: filmSessionUID,
            printJobUID: printJobUID
        )
    }
    
    /// Creates a failed result
    public static func failure(count: Int, error: PrintError) -> PartialPrintResult {
        PartialPrintResult(
            successCount: 0,
            failureCount: count,
            failedPositions: Array(1...count),
            errors: [error]
        )
    }
}

#if canImport(Network)

// MARK: - DICOM Print Service

/// DICOM Print Management Service (PS3.4 Annex H)
///
/// Provides print management operations using DIMSE-N services:
/// - N-CREATE: Create Film Session, Film Box
/// - N-SET: Set Image Box content
/// - N-GET: Get Printer status
/// - N-ACTION: Print Film Box/Session
/// - N-DELETE: Delete Film Session/Box
///
/// Typical workflow:
/// 1. Get printer status (N-GET on Printer SOP)
/// 2. Create Film Session (N-CREATE)
/// 3. Create Film Box (N-CREATE, returns Image Box UIDs)
/// 4. Set Image Box content (N-SET for each image)
/// 5. Print Film Box (N-ACTION)
/// 6. Delete Film Session (N-DELETE, cleanup)
///
/// Reference: PS3.4 Annex H - Print Management Service Class
public enum DICOMPrintService {
    
    /// Default Implementation Class UID for Print Service
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.2"
    
    /// Default Implementation Version Name for Print Service
    public static let defaultImplementationVersionName = "DICOMKIT_PRT"
    
    /// Gets the printer status using N-GET
    ///
    /// Sends N-GET to the well-known Printer SOP Instance to retrieve status.
    ///
    /// - Parameter configuration: Print connection configuration
    /// - Returns: The printer status
    /// - Throws: `DICOMNetworkError` if the operation fails
    public static func getPrinterStatus(
        configuration: PrintConfiguration
    ) async throws -> PrinterStatus {
        let sopClassUID = configuration.colorMode == .color
            ? basicColorPrintManagementMetaSOPClassUID
            : basicGrayscalePrintManagementMetaSOPClassUID
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: try AETitle(configuration.callingAETitle),
            calledAETitle: try AETitle(configuration.calledAETitle),
            host: configuration.host,
            port: configuration.port,
            implementationClassUID: defaultImplementationClassUID,
            implementationVersionName: defaultImplementationVersionName,
            timeout: configuration.timeout
        )
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Send N-GET request for Printer SOP Instance
            let request = NGetRequest(
                messageID: 1,
                requestedSOPClassUID: printerSOPClassUID,
                requestedSOPInstanceUID: printerSOPInstanceUID,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: nil,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-GET response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NGetResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.queryFailed(response.status)
                }
                
                // Parse printer attributes from response data set
                if let dataSetData = message.dataSet {
                    let printerStatus = parsePrinterStatus(from: dataSetData)
                    try await association.release()
                    return printerStatus
                }
                
                try await association.release()
                return PrinterStatus(status: "NORMAL")
            }
            
            try await association.release()
            return PrinterStatus(status: "UNKNOWN")
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Parses printer status from response data
    private static func parsePrinterStatus(from data: Data) -> PrinterStatus {
        // Parse the data set for printer status attributes
        // This is a simplified implementation - full parsing would decode
        // the DICOM data set to extract Printer Status (2110,0010),
        // Printer Status Info (2110,0020), and Printer Name (2110,0030)
        return PrinterStatus(status: "NORMAL", statusInfo: nil, printerName: nil)
    }
    
    /// Helper: Selects the appropriate Print Management Meta SOP Class UID based on color mode
    private static func selectPrintSOPClassUID(for colorMode: PrintColorMode) -> String {
        return colorMode == .color
            ? basicColorPrintManagementMetaSOPClassUID
            : basicGrayscalePrintManagementMetaSOPClassUID
    }
    
    /// Helper: Creates an association configuration for print operations
    private static func createPrintAssociationConfiguration(
        _ configuration: PrintConfiguration
    ) throws -> AssociationConfiguration {
        return AssociationConfiguration(
            callingAETitle: try AETitle(configuration.callingAETitle),
            calledAETitle: try AETitle(configuration.calledAETitle),
            host: configuration.host,
            port: configuration.port,
            implementationClassUID: defaultImplementationClassUID,
            implementationVersionName: defaultImplementationVersionName,
            timeout: configuration.timeout
        )
    }
    
    /// Helper: Parses Image Display Format to calculate number of image boxes
    /// Format is typically "STANDARD\rows,columns" or "STANDARD\R,C"
    /// - Parameter format: Image Display Format string (e.g., "STANDARD\2,3")
    /// - Returns: Number of image boxes (rows × columns), or 1 if parsing fails
    private static func parseImageDisplayFormat(_ format: String) -> Int {
        // Format examples:
        // "STANDARD\1,1" -> 1 image box
        // "STANDARD\2,2" -> 4 image boxes
        // "STANDARD\2,3" -> 6 image boxes
        
        let components = format.components(separatedBy: "\\")
        guard components.count == 2 else {
            return 1 // Default to 1 if format is invalid
        }
        
        let dimensions = components[1].components(separatedBy: ",")
        guard dimensions.count == 2,
              let rows = Int(dimensions[0]),
              let columns = Int(dimensions[1]),
              rows > 0, columns > 0 else {
            return 1 // Default to 1 if dimensions are invalid
        }
        
        return rows * columns
    }
    
    /// Creates a film session using N-CREATE
    ///
    /// Sends N-CREATE to the Print SCP to create a new Film Session SOP Instance.
    /// The SCP assigns a unique SOP Instance UID which is returned.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - session: Film session parameters
    /// - Returns: The assigned Film Session SOP Instance UID
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.1 - Basic Film Session SOP Class
    public static func createFilmSession(
        configuration: PrintConfiguration,
        session: FilmSession
    ) async throws -> String {
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Build data set with Film Session attributes
            var dataSet = DICOMKit.DataSet()
            
            // Number of Copies (2000,0010) - IS
            dataSet[.numberOfCopies] = DataElement(
                tag: .numberOfCopies,
                vr: .integerString,
                values: [String(session.numberOfCopies)]
            )
            
            // Print Priority (2000,0020) - CS
            dataSet[.printPriority] = DataElement(
                tag: .printPriority,
                vr: .codeString,
                values: [session.printPriority.rawValue]
            )
            
            // Medium Type (2000,0030) - CS
            dataSet[.mediumType] = DataElement(
                tag: .mediumType,
                vr: .codeString,
                values: [session.mediumType.rawValue]
            )
            
            // Film Destination (2000,0040) - CS
            dataSet[.filmDestination] = DataElement(
                tag: .filmDestination,
                vr: .codeString,
                values: [session.filmDestination.rawValue]
            )
            
            // Film Session Label (2000,0050) - LO (optional)
            if let label = session.filmSessionLabel {
                dataSet[.filmSessionLabel] = DataElement(
                    tag: .filmSessionLabel,
                    vr: .longString,
                    values: [label]
                )
            }
            
            // Encode data set
            let dataSetData = dataSet.write()
            
            // Send N-CREATE request for Film Session
            let request = NCreateRequest(
                messageID: 1,
                affectedSOPClassUID: basicFilmSessionSOPClassUID,
                affectedSOPInstanceUID: nil, // Let SCP assign the UID
                hasDataSet: true,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: dataSetData,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-CREATE response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NCreateResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.printOperationFailed(response.status)
                }
                
                // Extract assigned SOP Instance UID
                let filmSessionUID = response.affectedSOPInstanceUID
                
                try await association.release()
                return filmSessionUID
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Creates a film box using N-CREATE
    ///
    /// Sends N-CREATE to the Print SCP to create a new Film Box SOP Instance within
    /// an existing Film Session. The SCP assigns a unique Film Box UID and creates
    /// Image Box SOP Instances based on the Image Display Format.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - filmSessionUID: The Film Session SOP Instance UID to reference
    ///   - filmBox: Film box parameters (layout, size, orientation, etc.)
    /// - Returns: FilmBoxResult containing Film Box UID and Image Box UIDs
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.2 - Basic Film Box SOP Class
    public static func createFilmBox(
        configuration: PrintConfiguration,
        filmSessionUID: String,
        filmBox: FilmBox
    ) async throws -> FilmBoxResult {
        let sopClassUID = selectPrintSOPClassUID(for: configuration.colorMode)
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Build data set with Film Box attributes
            var dataSet = DICOMKit.DataSet()
            
            // Image Display Format (2010,0010) - ST
            dataSet[.imageDisplayFormat] = DataElement(
                tag: .imageDisplayFormat,
                vr: .shortText,
                values: [filmBox.imageDisplayFormat]
            )
            
            // Film Orientation (2010,0040) - CS
            dataSet[.filmOrientation] = DataElement(
                tag: .filmOrientation,
                vr: .codeString,
                values: [filmBox.filmOrientation.rawValue]
            )
            
            // Film Size ID (2010,0050) - CS
            dataSet[.filmSizeID] = DataElement(
                tag: .filmSizeID,
                vr: .codeString,
                values: [filmBox.filmSizeID.rawValue]
            )
            
            // Magnification Type (2010,0060) - CS
            dataSet[.magnificationType] = DataElement(
                tag: .magnificationType,
                vr: .codeString,
                values: [filmBox.magnificationType.rawValue]
            )
            
            // Border Density (2010,0100) - CS
            dataSet[.borderDensity] = DataElement(
                tag: .borderDensity,
                vr: .codeString,
                values: [filmBox.borderDensity]
            )
            
            // Empty Image Density (2010,0110) - CS
            dataSet[.emptyImageDensity] = DataElement(
                tag: .emptyImageDensity,
                vr: .codeString,
                values: [filmBox.emptyImageDensity]
            )
            
            // Trim (2010,0140) - CS
            dataSet[.trim] = DataElement(
                tag: .trim,
                vr: .codeString,
                values: [filmBox.trimOption.rawValue]
            )
            
            // Configuration Information (2010,0150) - ST (optional)
            if let config = filmBox.configurationInformation {
                dataSet[.configurationInformation] = DataElement(
                    tag: .configurationInformation,
                    vr: .shortText,
                    values: [config]
                )
            }
            
            // Referenced Film Session Sequence (2010,0500) - SQ
            // This references the parent Film Session
            var sessionItem = DICOMKit.DataSet()
            sessionItem[.referencedSOPClassUID] = DataElement(
                tag: .referencedSOPClassUID,
                vr: .uniqueIdentifier,
                values: [basicFilmSessionSOPClassUID]
            )
            sessionItem[.referencedSOPInstanceUID] = DataElement(
                tag: .referencedSOPInstanceUID,
                vr: .uniqueIdentifier,
                values: [filmSessionUID]
            )
            
            let sessionSequence = SequenceItem(dataSet: sessionItem)
            dataSet[.referencedFilmSessionSequence] = DataElement(
                tag: .referencedFilmSessionSequence,
                vr: .sequence,
                items: [sessionSequence]
            )
            
            // Encode data set
            let dataSetData = dataSet.write()
            
            // Send N-CREATE request for Film Box
            let request = NCreateRequest(
                messageID: 1,
                affectedSOPClassUID: basicFilmBoxSOPClassUID,
                affectedSOPInstanceUID: nil, // Let SCP assign the UID
                hasDataSet: true,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: dataSetData,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-CREATE response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NCreateResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.printOperationFailed(response.status)
                }
                
                // Extract assigned Film Box SOP Instance UID
                let filmBoxUID = response.affectedSOPInstanceUID
                
                // Parse Image Box UIDs from response data set
                var imageBoxUIDs: [String] = []
                if let dataSetData = message.dataSet {
                    imageBoxUIDs = parseImageBoxUIDs(from: dataSetData)
                }
                
                // Calculate expected number of image boxes from format
                let imageCount = parseImageDisplayFormat(filmBox.imageDisplayFormat)
                
                try await association.release()
                return FilmBoxResult(
                    filmBoxUID: filmBoxUID,
                    imageBoxUIDs: imageBoxUIDs,
                    imageCount: imageCount
                )
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Helper: Parses Image Box UIDs from N-CREATE response data set
    /// - Parameter data: Response data set containing Referenced Image Box Sequence
    /// - Returns: Array of Image Box SOP Instance UIDs
    private static func parseImageBoxUIDs(from data: Data) -> [String] {
        // Parse the data set to extract Referenced Image Box Sequence (2010,0510)
        guard !data.isEmpty else {
            return []
        }
        
        do {
            // Parse the DICOM data set (response data sets are typically raw data sets
            // without File Meta Information, so we'll try force reading)
            let file = try DICOMFile.read(from: data, force: true)
            let dataSet = file.dataSet
            
            // Extract Referenced Image Box Sequence (2010,0510)
            guard let sequence = dataSet[.referencedImageBoxSequence],
                  case .sequence(let items) = sequence.value else {
                return []
            }
            
            // Extract Referenced SOP Instance UID from each item
            var imageBoxUIDs: [String] = []
            for item in items {
                if let uid = item.dataSet[.referencedSOPInstanceUID]?.stringValue {
                    imageBoxUIDs.append(uid)
                }
            }
            
            return imageBoxUIDs
        } catch {
            // If parsing fails, return empty array
            return []
        }
    }
    
    /// Sets the content of an image box using N-SET
    ///
    /// Sends N-SET to the Print SCP to set the pixel data and attributes of an Image Box
    /// SOP Instance. This is called after creating a Film Box to populate each image position.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - imageBoxUID: The Image Box SOP Instance UID to set
    ///   - imageBox: Image box content (position, polarity, pixel data)
    ///   - pixelData: The pixel data to send (uncompressed)
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.3 - Basic Grayscale/Color Image Box SOP Class
    public static func setImageBox(
        configuration: PrintConfiguration,
        imageBoxUID: String,
        imageBox: ImageBoxContent,
        pixelData: Data
    ) async throws {
        let sopClassUID = configuration.colorMode == .color
            ? basicColorImageBoxSOPClassUID
            : basicGrayscaleImageBoxSOPClassUID
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Build data set with Image Box attributes
            var dataSet = DICOMKit.DataSet()
            
            // Image Position (2020,0010) - US
            dataSet[.imageBoxPosition] = DataElement(
                tag: .imageBoxPosition,
                vr: .unsignedShort,
                values: [imageBox.imagePosition]
            )
            
            // Polarity (2020,0020) - CS
            dataSet[.polarity] = DataElement(
                tag: .polarity,
                vr: .codeString,
                values: [imageBox.polarity.rawValue]
            )
            
            // Requested Image Size (2020,0030) - DS (optional)
            if let requestedSize = imageBox.requestedImageSize {
                dataSet[.requestedImageSize] = DataElement(
                    tag: .requestedImageSize,
                    vr: .decimalString,
                    values: [requestedSize]
                )
            }
            
            // Requested Decimate/Crop Behavior (2020,0040) - CS
            dataSet[.requestedDecimateCropBehavior] = DataElement(
                tag: .requestedDecimateCropBehavior,
                vr: .codeString,
                values: [imageBox.requestedDecimateCropBehavior.rawValue]
            )
            
            // Add pixel data based on color mode
            if configuration.colorMode == .grayscale {
                // Preformatted Grayscale Image Sequence (2020,0110) - SQ
                var imageItem = DICOMKit.DataSet()
                
                // Add pixel data to the sequence item
                // NOTE: This is a Phase 1 simplified implementation that assumes the pixelData
                // parameter contains a complete preformatted image with embedded attributes.
                // Future enhancement: Accept a PixelDataDescriptor parameter containing:
                // - Photometric Interpretation (0028,0004)
                // - Rows (0028,0010), Columns (0028,0011)
                // - Bits Allocated (0028,0100), Bits Stored (0028,0101), High Bit (0028,0102)
                // - Samples Per Pixel (0028,0002)
                // - Pixel Representation (0028,0103)
                // - Pixel Aspect Ratio (0028,0034) if applicable
                imageItem[.pixelData] = DataElement(
                    tag: .pixelData,
                    vr: .otherByteString,
                    data: pixelData
                )
                
                let sequenceItem = SequenceItem(dataSet: imageItem)
                dataSet[.preformattedGrayscaleImageSequence] = DataElement(
                    tag: .preformattedGrayscaleImageSequence,
                    vr: .sequence,
                    items: [sequenceItem]
                )
            } else {
                // Preformatted Color Image Sequence (2020,0111) - SQ
                var imageItem = DICOMKit.DataSet()
                
                // NOTE: Same as grayscale - assumes preformatted image data
                imageItem[.pixelData] = DataElement(
                    tag: .pixelData,
                    vr: .otherByteString,
                    data: pixelData
                )
                
                let sequenceItem = SequenceItem(dataSet: imageItem)
                dataSet[.preformattedColorImageSequence] = DataElement(
                    tag: .preformattedColorImageSequence,
                    vr: .sequence,
                    items: [sequenceItem]
                )
            }
            
            // Encode data set
            let dataSetData = dataSet.write()
            
            // Send N-SET request for Image Box
            let request = NSetRequest(
                messageID: 1,
                requestedSOPClassUID: sopClassUID,
                requestedSOPInstanceUID: imageBoxUID,
                hasDataSet: true,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: dataSetData,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-SET response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NSetResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.printOperationFailed(response.status)
                }
                
                try await association.release()
                return
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Prints a film box using N-ACTION
    ///
    /// Sends N-ACTION (Action Type ID = 1) to the Print SCP to execute printing of a
    /// Film Box SOP Instance. The SCP creates a Print Job SOP Instance and returns its UID.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - filmBoxUID: The Film Box SOP Instance UID to print
    /// - Returns: Print Job SOP Instance UID
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.2.2.4 - Film Box Print Action
    public static func printFilmBox(
        configuration: PrintConfiguration,
        filmBoxUID: String
    ) async throws -> String {
        let sopClassUID = selectPrintSOPClassUID(for: configuration.colorMode)
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Send N-ACTION request for Film Box with Action Type ID = 1 (Print)
            // Note: N-ACTION Print typically does not include a data set
            let request = NActionRequest(
                messageID: 1,
                requestedSOPClassUID: basicFilmBoxSOPClassUID,
                requestedSOPInstanceUID: filmBoxUID,
                actionTypeID: 1, // Action Type ID = 1 means "Print"
                hasDataSet: false,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: nil,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-ACTION response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NActionResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.printOperationFailed(response.status)
                }
                
                // Extract Print Job SOP Instance UID from the response
                // Per PS3.4 H.4.2.2.4, the N-ACTION response includes the Affected SOP Instance UID
                // of the created Print Job SOP Instance
                let printJobUID = response.affectedSOPInstanceUID
                
                // Validate that a Print Job UID was returned
                guard !printJobUID.isEmpty else {
                    try await association.abort()
                    throw DICOMNetworkError.unexpectedResponse
                }
                
                try await association.release()
                return printJobUID
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Deletes a film session using N-DELETE
    ///
    /// Sends N-DELETE to the Print SCP to delete a Film Session SOP Instance.
    /// This should be called after printing is complete to cleanup resources.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - filmSessionUID: The Film Session SOP Instance UID to delete
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.1 - Basic Film Session SOP Class
    public static func deleteFilmSession(
        configuration: PrintConfiguration,
        filmSessionUID: String
    ) async throws {
        let sopClassUID = selectPrintSOPClassUID(for: configuration.colorMode)
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Send N-DELETE request for Film Session
            let request = NDeleteRequest(
                messageID: 1,
                requestedSOPClassUID: basicFilmSessionSOPClassUID,
                requestedSOPInstanceUID: filmSessionUID,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: nil,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-DELETE response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NDeleteResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.printOperationFailed(response.status)
                }
                
                try await association.release()
                return
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Gets the status of a print job using N-GET
    ///
    /// Sends N-GET to the Print SCP to retrieve the status of a Print Job SOP Instance.
    /// This can be used to monitor the progress of a print operation.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - printJobUID: The Print Job SOP Instance UID to query
    /// - Returns: The print job status
    /// - Throws: `DICOMNetworkError` if the operation fails
    ///
    /// Reference: PS3.4 H.4.8 - Print Job SOP Class
    public static func getPrintJobStatus(
        configuration: PrintConfiguration,
        printJobUID: String
    ) async throws -> PrintJobStatus {
        let sopClassUID = selectPrintSOPClassUID(for: configuration.colorMode)
        
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: sopClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Create association configuration
        let associationConfig = try createPrintAssociationConfiguration(configuration)
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify presentation context was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(sopClassUID)
            }
            
            // Send N-GET request for Print Job SOP Instance
            let request = NGetRequest(
                messageID: 1,
                requestedSOPClassUID: printJobSOPClassUID,
                requestedSOPInstanceUID: printJobUID,
                presentationContextID: 1
            )
            
            let fragmenter = MessageFragmenter(maxPDUSize: negotiated.maxPDUSize)
            let pdus = fragmenter.fragmentMessage(
                commandSet: request.commandSet,
                dataSet: nil,
                presentationContextID: request.presentationContextID
            )
            
            for pdu in pdus {
                for pdv in pdu.presentationDataValues {
                    try await association.send(pdv: pdv)
                }
            }
            
            // Receive N-GET response
            let assembler = MessageAssembler()
            let responsePDU = try await association.receive()
            
            if let message = try assembler.addPDVs(from: responsePDU) {
                let responseCommandSet = message.commandSet
                let response = NGetResponse(commandSet: responseCommandSet, presentationContextID: 1)
                
                guard response.status.isSuccess else {
                    try await association.abort()
                    throw DICOMNetworkError.queryFailed(response.status)
                }
                
                // Parse print job attributes from response data set
                if let dataSetData = message.dataSet {
                    let printJobStatus = parsePrintJobStatus(from: dataSetData, printJobUID: printJobUID)
                    try await association.release()
                    return printJobStatus
                }
                
                // If no data set returned, return a default status
                try await association.release()
                return PrintJobStatus(
                    printJobUID: printJobUID,
                    executionStatus: "UNKNOWN"
                )
            }
            
            throw DICOMNetworkError.unexpectedResponse
        } catch {
            try? await association.abort()
            throw error
        }
    }
    
    /// Parses print job status from response data
    private static func parsePrintJobStatus(from data: Data, printJobUID: String) -> PrintJobStatus {
        do {
            // Parse the DICOM data set to extract Print Job attributes
            let dataSet = try DICOMKit.DataSet(data: data)
            
            // Extract Execution Status (2100,0020) - CS
            let executionStatus = dataSet[.executionStatus]?.stringValue ?? "UNKNOWN"
            
            // Extract Execution Status Info (2100,0030) - AE (optional)
            let executionStatusInfo = dataSet[.executionStatusInfo]?.stringValue
            
            // Extract Creation Date (2100,0040) - DA (optional)
            var creationDate: Date? = nil
            if let dateString = dataSet[.creationDate]?.stringValue {
                creationDate = parseDICOMDate(dateString)
            }
            
            // Extract Creation Time (2100,0050) - TM (optional)
            var creationTime: Date? = nil
            if let timeString = dataSet[.creationTime]?.stringValue {
                creationTime = parseDICOMTime(timeString)
            }
            
            return PrintJobStatus(
                printJobUID: printJobUID,
                executionStatus: executionStatus,
                executionStatusInfo: executionStatusInfo,
                creationDate: creationDate,
                creationTime: creationTime
            )
        } catch {
            // If parsing fails, return a default status
            return PrintJobStatus(
                printJobUID: printJobUID,
                executionStatus: "UNKNOWN"
            )
        }
    }
    
    /// Parses DICOM Date (DA) format: YYYYMMDD
    private static func parseDICOMDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }
    
    /// Parses DICOM Time (TM) format: HHMMSS.FFFFFF
    private static func parseDICOMTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        // Handle various TM formats: HHMMSS, HHMMSS.F, HHMMSS.FFFFFF
        let cleanedTime = timeString.components(separatedBy: ".").first ?? timeString
        formatter.dateFormat = "HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: cleanedTime)
    }
    
    // MARK: - High-Level Print API (Phase 2)
    
    /// Prints a single image using the complete print workflow
    ///
    /// This is a convenience method that handles the complete print workflow:
    /// 1. Creates a film session
    /// 2. Creates a film box with single image layout
    /// 3. Sets the image box content with the provided pixel data
    /// 4. Prints the film box
    /// 5. Cleans up by deleting the film session
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - imageData: The pixel data to print (should be properly formatted)
    ///   - options: Print options (defaults to `.default`)
    /// - Returns: The print result
    /// - Throws: `DICOMNetworkError` if any step of the workflow fails
    ///
    /// Example:
    /// ```swift
    /// let result = try await DICOMPrintService.printImage(
    ///     configuration: printConfig,
    ///     imageData: pixelData,
    ///     options: .highQuality
    /// )
    /// ```
    public static func printImage(
        configuration: PrintConfiguration,
        imageData: Data,
        options: PrintOptions = .default
    ) async throws -> PrintResult {
        // Create film session
        let filmSession = FilmSession(
            numberOfCopies: options.numberOfCopies,
            printPriority: options.priority,
            mediumType: options.mediumType,
            filmDestination: options.filmDestination,
            filmSessionLabel: options.sessionLabel
        )
        
        let filmSessionUID = try await createFilmSession(configuration: configuration, session: filmSession)
        
        do {
            // Create film box with single image layout
            let filmBox = FilmBox(
                imageDisplayFormat: "STANDARD\\1,1",
                filmOrientation: options.filmOrientation,
                filmSizeID: options.filmSize,
                magnificationType: options.magnificationType,
                borderDensity: options.borderDensity,
                emptyImageDensity: options.emptyImageDensity,
                trimOption: options.trimOption
            )
            
            let filmBoxResult = try await createFilmBox(
                configuration: configuration,
                filmSessionUID: filmSessionUID,
                filmBox: filmBox
            )
            
            // Set image box content
            guard !filmBoxResult.imageBoxUIDs.isEmpty else {
                throw DICOMNetworkError.unexpectedResponse
            }
            
            let imageBox = ImageBoxContent(
                sopInstanceUID: filmBoxResult.imageBoxUIDs[0],
                imagePosition: 1,
                polarity: options.polarity
            )
            
            try await setImageBox(
                configuration: configuration,
                imageBoxUID: filmBoxResult.imageBoxUIDs[0],
                imageBox: imageBox,
                pixelData: imageData
            )
            
            // Print the film box
            let printJobUID = try await printFilmBox(
                configuration: configuration,
                filmBoxUID: filmBoxResult.filmBoxUID
            )
            
            // Cleanup: delete film session
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            
            return PrintResult(
                success: true,
                status: .success,
                filmSessionUID: filmSessionUID,
                filmBoxUID: filmBoxResult.filmBoxUID,
                printJobUID: printJobUID
            )
        } catch {
            // Cleanup on error
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            throw error
        }
    }
    
    /// Prints multiple images using the complete print workflow with automatic layout
    ///
    /// This is a convenience method that handles the complete print workflow:
    /// 1. Creates a film session
    /// 2. Automatically determines the optimal layout based on image count
    /// 3. Creates film box(es) as needed
    /// 4. Sets image box content for each image
    /// 5. Prints all film boxes
    /// 6. Cleans up by deleting the film session
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - images: Array of pixel data to print
    ///   - options: Print options (defaults to `.default`)
    /// - Returns: The print result
    /// - Throws: `DICOMNetworkError` if any step of the workflow fails
    ///
    /// Example:
    /// ```swift
    /// let result = try await DICOMPrintService.printImages(
    ///     configuration: printConfig,
    ///     images: [image1Data, image2Data, image3Data, image4Data],
    ///     options: PrintOptions(filmSize: .size14InX17In)
    /// )
    /// ```
    public static func printImages(
        configuration: PrintConfiguration,
        images: [Data],
        options: PrintOptions = .default
    ) async throws -> PrintResult {
        guard !images.isEmpty else {
            return PrintResult(
                success: false,
                status: .failedUnableToProcess,
                errorMessage: "No images provided"
            )
        }
        
        // Single image: use printImage
        if images.count == 1 {
            return try await printImage(
                configuration: configuration,
                imageData: images[0],
                options: options
            )
        }
        
        // Multiple images: determine optimal layout
        let layout = PrintLayout.optimalLayout(for: images.count)
        
        // Create film session
        let filmSession = FilmSession(
            numberOfCopies: options.numberOfCopies,
            printPriority: options.priority,
            mediumType: options.mediumType,
            filmDestination: options.filmDestination,
            filmSessionLabel: options.sessionLabel
        )
        
        let filmSessionUID = try await createFilmSession(configuration: configuration, session: filmSession)
        
        do {
            var allPrintJobUIDs: [String] = []
            var lastFilmBoxUID: String?
            
            // Calculate how many film boxes we need
            let imagesPerFilm = layout.rows * layout.columns
            let filmBoxCount = (images.count + imagesPerFilm - 1) / imagesPerFilm
            
            for filmIndex in 0..<filmBoxCount {
                // Create film box with the layout
                let filmBox = FilmBox(
                    imageDisplayFormat: "STANDARD\\\(layout.rows),\(layout.columns)",
                    filmOrientation: options.filmOrientation,
                    filmSizeID: options.filmSize,
                    magnificationType: options.magnificationType,
                    borderDensity: options.borderDensity,
                    emptyImageDensity: options.emptyImageDensity,
                    trimOption: options.trimOption
                )
                
                let filmBoxResult = try await createFilmBox(
                    configuration: configuration,
                    filmSessionUID: filmSessionUID,
                    filmBox: filmBox
                )
                lastFilmBoxUID = filmBoxResult.filmBoxUID
                
                // Set image box contents for this film box
                let startIndex = filmIndex * imagesPerFilm
                let endIndex = min(startIndex + imagesPerFilm, images.count)
                
                for (imageIndex, globalIndex) in (startIndex..<endIndex).enumerated() {
                    let position = UInt16(imageIndex + 1)
                    
                    guard imageIndex < filmBoxResult.imageBoxUIDs.count else {
                        continue
                    }
                    
                    let imageBox = ImageBoxContent(
                        sopInstanceUID: filmBoxResult.imageBoxUIDs[imageIndex],
                        imagePosition: position,
                        polarity: options.polarity
                    )
                    
                    try await setImageBox(
                        configuration: configuration,
                        imageBoxUID: filmBoxResult.imageBoxUIDs[imageIndex],
                        imageBox: imageBox,
                        pixelData: images[globalIndex]
                    )
                }
                
                // Print the film box
                let printJobUID = try await printFilmBox(
                    configuration: configuration,
                    filmBoxUID: filmBoxResult.filmBoxUID
                )
                allPrintJobUIDs.append(printJobUID)
            }
            
            // Cleanup: delete film session
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            
            return PrintResult(
                success: true,
                status: .success,
                filmSessionUID: filmSessionUID,
                filmBoxUID: lastFilmBoxUID,
                printJobUID: allPrintJobUIDs.last
            )
        } catch {
            // Cleanup on error
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            throw error
        }
    }
    
    /// Prints images using a specific print template
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - images: Array of pixel data to print
    ///   - template: The print template to use for layout
    ///   - options: Print options (defaults to `.default`)
    /// - Returns: The print result
    /// - Throws: `DICOMNetworkError` if any step of the workflow fails
    ///
    /// Example:
    /// ```swift
    /// let result = try await DICOMPrintService.printWithTemplate(
    ///     configuration: printConfig,
    ///     images: multiPhaseImages,
    ///     template: .multiPhase3x4
    /// )
    /// ```
    public static func printWithTemplate(
        configuration: PrintConfiguration,
        images: [Data],
        template: PrintTemplate,
        options: PrintOptions = .default
    ) async throws -> PrintResult {
        guard !images.isEmpty else {
            return PrintResult(
                success: false,
                status: .failedUnableToProcess,
                errorMessage: "No images provided"
            )
        }
        
        // Create film session
        let filmSession = FilmSession(
            numberOfCopies: options.numberOfCopies,
            printPriority: options.priority,
            mediumType: options.mediumType,
            filmDestination: options.filmDestination,
            filmSessionLabel: options.sessionLabel
        )
        
        let filmSessionUID = try await createFilmSession(configuration: configuration, session: filmSession)
        
        do {
            var allPrintJobUIDs: [String] = []
            var lastFilmBoxUID: String?
            
            // Calculate how many film boxes we need
            let imagesPerFilm = template.imageCount
            let filmBoxCount = (images.count + imagesPerFilm - 1) / imagesPerFilm
            
            for filmIndex in 0..<filmBoxCount {
                // Create film box from template
                var filmBox = template.createFilmBox()
                
                // Apply options' film orientation if it differs from template's default
                if options.filmOrientation != template.filmOrientation {
                    filmBox = FilmBox(
                        sopInstanceUID: filmBox.sopInstanceUID,
                        imageDisplayFormat: filmBox.imageDisplayFormat,
                        filmOrientation: options.filmOrientation,
                        filmSizeID: filmBox.filmSizeID,
                        magnificationType: filmBox.magnificationType,
                        borderDensity: filmBox.borderDensity,
                        emptyImageDensity: filmBox.emptyImageDensity,
                        trimOption: filmBox.trimOption,
                        configurationInformation: filmBox.configurationInformation,
                        imageBoxSOPInstanceUIDs: filmBox.imageBoxSOPInstanceUIDs
                    )
                }
                
                let filmBoxResult = try await createFilmBox(
                    configuration: configuration,
                    filmSessionUID: filmSessionUID,
                    filmBox: filmBox
                )
                lastFilmBoxUID = filmBoxResult.filmBoxUID
                
                // Set image box contents for this film box
                let startIndex = filmIndex * imagesPerFilm
                let endIndex = min(startIndex + imagesPerFilm, images.count)
                
                for (imageIndex, globalIndex) in (startIndex..<endIndex).enumerated() {
                    let position = UInt16(imageIndex + 1)
                    
                    guard imageIndex < filmBoxResult.imageBoxUIDs.count else {
                        continue
                    }
                    
                    let imageBox = ImageBoxContent(
                        sopInstanceUID: filmBoxResult.imageBoxUIDs[imageIndex],
                        imagePosition: position,
                        polarity: options.polarity
                    )
                    
                    try await setImageBox(
                        configuration: configuration,
                        imageBoxUID: filmBoxResult.imageBoxUIDs[imageIndex],
                        imageBox: imageBox,
                        pixelData: images[globalIndex]
                    )
                }
                
                // Print the film box
                let printJobUID = try await printFilmBox(
                    configuration: configuration,
                    filmBoxUID: filmBoxResult.filmBoxUID
                )
                allPrintJobUIDs.append(printJobUID)
            }
            
            // Cleanup: delete film session
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            
            return PrintResult(
                success: true,
                status: .success,
                filmSessionUID: filmSessionUID,
                filmBoxUID: lastFilmBoxUID,
                printJobUID: allPrintJobUIDs.last
            )
        } catch {
            // Cleanup on error
            try? await deleteFilmSession(configuration: configuration, filmSessionUID: filmSessionUID)
            throw error
        }
    }
    
    /// Prints images with progress reporting via AsyncThrowingStream
    ///
    /// Provides progress updates during the print workflow, allowing UI updates
    /// and cancellation support.
    ///
    /// - Parameters:
    ///   - configuration: Print connection configuration
    ///   - images: Array of pixel data to print
    ///   - options: Print options (defaults to `.default`)
    /// - Returns: An AsyncThrowingStream that yields PrintProgress updates
    ///
    /// Example:
    /// ```swift
    /// for try await progress in DICOMPrintService.printImagesWithProgress(
    ///     configuration: printConfig,
    ///     images: images
    /// ) {
    ///     print("Progress: \(progress.phase) - \(Int(progress.progress * 100))%")
    /// }
    /// ```
    public static func printImagesWithProgress(
        configuration: PrintConfiguration,
        images: [Data],
        options: PrintOptions = .default
    ) -> AsyncThrowingStream<PrintProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !images.isEmpty else {
                        continuation.finish(throwing: DICOMNetworkError.unexpectedResponse)
                        return
                    }
                    
                    // Report: connecting
                    continuation.yield(PrintProgress(
                        phase: .connecting,
                        progress: 0.0,
                        message: "Connecting to print server..."
                    ))
                    
                    // Report: querying printer
                    continuation.yield(PrintProgress(
                        phase: .queryingPrinter,
                        progress: 0.05,
                        message: "Querying printer status..."
                    ))
                    
                    _ = try await getPrinterStatus(configuration: configuration)
                    
                    // Report: creating session
                    continuation.yield(PrintProgress(
                        phase: .creatingSession,
                        progress: 0.1,
                        message: "Creating print session..."
                    ))
                    
                    let filmSession = FilmSession(
                        numberOfCopies: options.numberOfCopies,
                        printPriority: options.priority,
                        mediumType: options.mediumType,
                        filmDestination: options.filmDestination,
                        filmSessionLabel: options.sessionLabel
                    )
                    
                    let filmSessionUID = try await createFilmSession(
                        configuration: configuration,
                        session: filmSession
                    )
                    
                    do {
                        // Report: preparing images
                        continuation.yield(PrintProgress(
                            phase: .preparingImages,
                            progress: 0.15,
                            message: "Preparing images for printing..."
                        ))
                        
                        let layout = images.count == 1
                            ? PrintLayout(rows: 1, columns: 1)
                            : PrintLayout.optimalLayout(for: images.count)
                        
                        let imagesPerFilm = layout.rows * layout.columns
                        let filmBoxCount = (images.count + imagesPerFilm - 1) / imagesPerFilm
                        
                        let uploadStartProgress: Double = 0.2
                        let uploadEndProgress: Double = 0.85
                        let uploadProgressRange = uploadEndProgress - uploadStartProgress
                        
                        var totalImagesUploaded = 0
                        
                        for filmIndex in 0..<filmBoxCount {
                            let filmBox = FilmBox(
                                imageDisplayFormat: "STANDARD\\\(layout.rows),\(layout.columns)",
                                filmOrientation: options.filmOrientation,
                                filmSizeID: options.filmSize,
                                magnificationType: options.magnificationType,
                                borderDensity: options.borderDensity,
                                emptyImageDensity: options.emptyImageDensity,
                                trimOption: options.trimOption
                            )
                            
                            let filmBoxResult = try await createFilmBox(
                                configuration: configuration,
                                filmSessionUID: filmSessionUID,
                                filmBox: filmBox
                            )
                            
                            let startIndex = filmIndex * imagesPerFilm
                            let endIndex = min(startIndex + imagesPerFilm, images.count)
                            
                            for (imageIndex, globalIndex) in (startIndex..<endIndex).enumerated() {
                                // Report: uploading image
                                totalImagesUploaded += 1
                                let imageProgress = Double(totalImagesUploaded) / Double(images.count)
                                let overallProgress = uploadStartProgress + (uploadProgressRange * imageProgress)
                                
                                continuation.yield(PrintProgress(
                                    phase: .uploadingImages(current: totalImagesUploaded, total: images.count),
                                    progress: overallProgress,
                                    message: "Uploading image \(totalImagesUploaded) of \(images.count)..."
                                ))
                                
                                let position = UInt16(imageIndex + 1)
                                
                                guard imageIndex < filmBoxResult.imageBoxUIDs.count else {
                                    continue
                                }
                                
                                let imageBox = ImageBoxContent(
                                    sopInstanceUID: filmBoxResult.imageBoxUIDs[imageIndex],
                                    imagePosition: position,
                                    polarity: options.polarity
                                )
                                
                                try await setImageBox(
                                    configuration: configuration,
                                    imageBoxUID: filmBoxResult.imageBoxUIDs[imageIndex],
                                    imageBox: imageBox,
                                    pixelData: images[globalIndex]
                                )
                            }
                            
                            // Report: printing
                            continuation.yield(PrintProgress(
                                phase: .printing,
                                progress: 0.9,
                                message: "Sending print command..."
                            ))
                            
                            _ = try await printFilmBox(
                                configuration: configuration,
                                filmBoxUID: filmBoxResult.filmBoxUID
                            )
                        }
                        
                        // Report: cleanup
                        continuation.yield(PrintProgress(
                            phase: .cleanup,
                            progress: 0.95,
                            message: "Cleaning up session..."
                        ))
                        
                        try? await deleteFilmSession(
                            configuration: configuration,
                            filmSessionUID: filmSessionUID
                        )
                        
                        // Report: complete
                        continuation.yield(PrintProgress(
                            phase: .completed,
                            progress: 1.0,
                            message: "Print job completed successfully"
                        ))
                        
                        continuation.finish()
                    } catch {
                        // Cleanup on error
                        try? await deleteFilmSession(
                            configuration: configuration,
                            filmSessionUID: filmSessionUID
                        )
                        continuation.finish(throwing: error)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

#endif
