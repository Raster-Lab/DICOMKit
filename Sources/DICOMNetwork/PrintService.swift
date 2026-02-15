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
}

#endif
