/// DICOM Print Management Service
///
/// Implements the DICOM Print Management Service Class as defined in PS3.4 Annex H.
/// Provides data models, SOP Class UIDs, and service operations for DICOM printing.
///
/// Reference: PS3.4 Annex H - Print Management Service Class

import Foundation
import DICOMCore

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
}

#endif
