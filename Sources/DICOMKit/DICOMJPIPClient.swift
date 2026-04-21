// DICOMJPIPClient.swift
// DICOMKit — Phase 6: JPIP Streaming

import Foundation
import DICOMCore

#if canImport(JPIP)
import JPIP
import J2KCore
#endif

// MARK: - DICOMJPIPRegion

/// A rectangular region of interest for JPIP decoding.
public struct DICOMJPIPRegion: Sendable {
    /// X offset in pixels from the top-left corner.
    public var x: Int
    /// Y offset in pixels from the top-left corner.
    public var y: Int
    /// Region width in pixels.
    public var width: Int
    /// Region height in pixels.
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - DICOMJPIPQuality

/// Describes how much of a JPIP image has been retrieved.
public enum DICOMJPIPQuality: Sendable {
    /// Retrieve all quality layers (full quality).
    case full
    /// Retrieve only the first N quality layers.
    case layers(Int)
    /// Retrieve up to a specified resolution level (0 = full, higher = lower res).
    case resolutionLevel(Int)
}

// MARK: - DICOMJPIPError

/// Errors thrown by ``DICOMJPIPClient``.
public enum DICOMJPIPError: Error, Sendable, CustomStringConvertible {
    /// The transfer syntax stored in the DICOM dataset is not a JPIP reference.
    case notAJPIPTransferSyntax(String)
    /// The Pixel Data element is missing from the DICOM dataset.
    case missingPixelData
    /// The Pixel Data element does not contain a valid URI string.
    case invalidJPIPURI(String)
    /// The JPIP server returned an unexpected response.
    case serverError(Int, String)
    /// JPIP module is not available (compiled without JPIP support).
    case jpipModuleUnavailable

    public var description: String {
        switch self {
        case .notAJPIPTransferSyntax(let uid):
            return "Transfer syntax \(uid) is not a JPIP reference syntax"
        case .missingPixelData:
            return "DICOM dataset has no Pixel Data element"
        case .invalidJPIPURI(let raw):
            return "Pixel Data does not contain a valid JPIP URI: \(raw)"
        case .serverError(let code, let detail):
            return "JPIP server error \(code): \(detail)"
        case .jpipModuleUnavailable:
            return "JPIP module is not available in this build"
        }
    }
}

// MARK: - J2KImage → DICOMJPIPImage conversion

#if canImport(JPIP)
extension J2KImage {
    /// Converts a decoded J2KImage into a ``DICOMJPIPImage`` by interleaving
    /// component data into a single flat pixel buffer.
    ///
    /// For a single-component (grayscale) image the component's `data` bytes
    /// are used directly.  For multi-component images the component planes are
    /// interleaved sample-by-sample (RGBRGB… ordering).
    func toDICOMJPIPImage(sourceURI: URL, qualityLayers: Int) -> DICOMJPIPImage {
        let componentCount = components.count
        let pixelData: Data
        if componentCount == 1 {
            pixelData = components[0].data
        } else {
            // Interleave component planes into a packed pixel buffer.
            let samplesPerComponent = components.first.map { $0.data.count } ?? 0
            var buffer = Data(capacity: samplesPerComponent * componentCount)
            for sampleIndex in 0..<samplesPerComponent {
                for component in components {
                    if sampleIndex < component.data.count {
                        buffer.append(component.data[sampleIndex])
                    }
                }
            }
            pixelData = buffer
        }
        let bitDepth = components.first?.bitDepth ?? 8
        return DICOMJPIPImage(
            pixelData: pixelData,
            width: width,
            height: height,
            components: componentCount,
            bitDepth: bitDepth,
            sourceURI: sourceURI,
            qualityLayers: qualityLayers
        )
    }
}
#endif

// MARK: - DICOMJPIPImage

/// A decoded DICOM image retrieved via JPIP.
public struct DICOMJPIPImage: Sendable {
    /// Raw pixel bytes (decoded from the JPEG 2000 codestream).
    public let pixelData: Data
    /// Image width in pixels.
    public let width: Int
    /// Image height in pixels.
    public let height: Int
    /// Number of components (channels).
    public let components: Int
    /// Bits per component.
    public let bitDepth: Int
    /// JPIP URI that was used to retrieve this image.
    public let sourceURI: URL
    /// The number of quality layers that were fetched (0 = unknown).
    public let qualityLayers: Int

    public init(pixelData: Data, width: Int, height: Int, components: Int, bitDepth: Int,
                sourceURI: URL, qualityLayers: Int) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.components = components
        self.bitDepth = bitDepth
        self.sourceURI = sourceURI
        self.qualityLayers = qualityLayers
    }
}

// MARK: - DICOMJPIPClient

/// A high-level client for retrieving DICOM images from a JPIP server.
///
/// ``DICOMJPIPClient`` wraps J2KSwift's ``JPIPClient`` and maps DICOM WADO-URI
/// JPIP reference transfer syntaxes (`1.2.840.10008.1.2.4.94` and `.4.95`) to
/// interactive progressive image requests.
///
/// ## Usage
///
/// ```swift
/// // Connect to a JPIP server
/// let client = DICOMJPIPClient(serverURL: URL(string: "http://pacs.example.com:8080")!)
///
/// // Fetch the full image
/// let image = try await client.fetchImage(jpipURI: jpipURL)
///
/// // Or fetch a region at a specific quality
/// let roi = DICOMJPIPRegion(x: 256, y: 256, width: 512, height: 512)
/// let partial = try await client.fetchRegion(jpipURI: jpipURL, region: roi, quality: .layers(4))
/// ```
///
/// ## JPIP Transfer Syntaxes
///
/// | UID | Name |
/// |-----|------|
/// | `1.2.840.10008.1.2.4.94` | JPIP Referenced |
/// | `1.2.840.10008.1.2.4.95` | JPIP Referenced Deflate |
public actor DICOMJPIPClient {

    /// The JPIP server base URL.
    public nonisolated let serverURL: URL

    #if canImport(JPIP)
    private let jpipClient: JPIPClient
    #endif

    /// Creates a new DICOM JPIP client.
    ///
    /// - Parameter serverURL: The base URL of the JPIP server (e.g., `http://pacs.example.com:8080`).
    public init(serverURL: URL) {
        self.serverURL = serverURL
        #if canImport(JPIP)
        self.jpipClient = JPIPClient(serverURL: serverURL)
        #endif
    }

    // MARK: - Image Retrieval

    /// Fetches the full DICOM image from a JPIP server.
    ///
    /// - Parameter jpipURI: The JPIP target URI extracted from the DICOM Pixel Data element.
    /// - Returns: A ``DICOMJPIPImage`` containing decoded pixel data.
    /// - Throws: ``DICOMJPIPError`` if retrieval or decoding fails.
    public func fetchImage(jpipURI: URL) async throws -> DICOMJPIPImage {
        #if canImport(JPIP)
        let imageID = jpipURI.lastPathComponent
        let j2kImage = try await jpipClient.requestImage(imageID: imageID)
        return j2kImage.toDICOMJPIPImage(sourceURI: jpipURI, qualityLayers: 0)
        #else
        throw DICOMJPIPError.jpipModuleUnavailable
        #endif
    }

    /// Fetches a region of interest from a JPIP server.
    ///
    /// - Parameters:
    ///   - jpipURI: The JPIP target URI.
    ///   - region: The rectangular region to retrieve.
    ///   - quality: How many quality layers to fetch. Defaults to `.full`.
    /// - Returns: A ``DICOMJPIPImage`` for the requested region.
    public func fetchRegion(
        jpipURI: URL,
        region: DICOMJPIPRegion,
        quality: DICOMJPIPQuality = .full
    ) async throws -> DICOMJPIPImage {
        #if canImport(JPIP)
        let imageID = jpipURI.lastPathComponent
        let j2kImage = try await jpipClient.requestRegion(
            imageID: imageID,
            region: (x: region.x, y: region.y, width: region.width, height: region.height)
        )
        let fetchedLayers: Int
        switch quality {
        case .layers(let n): fetchedLayers = n
        default: fetchedLayers = 0
        }
        return j2kImage.toDICOMJPIPImage(sourceURI: jpipURI, qualityLayers: fetchedLayers)
        #else
        throw DICOMJPIPError.jpipModuleUnavailable
        #endif
    }

    /// Fetches a progressive quality preview.
    ///
    /// Use this to quickly display a low-quality thumbnail before fetching higher quality layers.
    ///
    /// - Parameters:
    ///   - jpipURI: The JPIP target URI.
    ///   - layers: Number of quality layers to retrieve (1 = fastest/lowest quality).
    /// - Returns: A ``DICOMJPIPImage`` at the requested quality level.
    public func fetchProgressiveQuality(jpipURI: URL, layers: Int) async throws -> DICOMJPIPImage {
        #if canImport(JPIP)
        let imageID = jpipURI.lastPathComponent
        let j2kImage = try await jpipClient.requestProgressiveQuality(imageID: imageID, upToLayers: layers)
        return j2kImage.toDICOMJPIPImage(sourceURI: jpipURI, qualityLayers: layers)
        #else
        throw DICOMJPIPError.jpipModuleUnavailable
        #endif
    }

    /// Fetches the image at a specific resolution level.
    ///
    /// Level 0 is full resolution; each subsequent level halves the resolution.
    ///
    /// - Parameters:
    ///   - jpipURI: The JPIP target URI.
    ///   - level: Resolution level (0 = full).
    ///   - layers: Optional quality layer limit.
    /// - Returns: A ``DICOMJPIPImage`` at the requested resolution.
    public func fetchResolutionLevel(jpipURI: URL, level: Int, layers: Int? = nil) async throws -> DICOMJPIPImage {
        #if canImport(JPIP)
        let imageID = jpipURI.lastPathComponent
        let j2kImage = try await jpipClient.requestResolutionLevel(imageID: imageID, level: level, layers: layers)
        return j2kImage.toDICOMJPIPImage(sourceURI: jpipURI, qualityLayers: layers ?? 0)
        #else
        throw DICOMJPIPError.jpipModuleUnavailable
        #endif
    }

    /// Closes the JPIP connection and frees server-side resources.
    public func close() async throws {
        #if canImport(JPIP)
        try await jpipClient.close()
        #endif
    }

    // MARK: - DICOM Integration

    /// Extracts the JPIP URI from a DICOM dataset's Pixel Data element.
    ///
    /// JPIP-referenced DICOM objects store the server URI in the Pixel Data
    /// element as a UTF-8 string rather than pixel bytes.
    ///
    /// - Parameters:
    ///   - dataset: The DICOM dataset.
    ///   - transferSyntaxUID: The transfer syntax UID of the dataset.
    /// - Returns: The parsed JPIP server URI.
    /// - Throws: ``DICOMJPIPError`` if the dataset is not a JPIP object or the URI is malformed.
    public static func jpipURI(from dataset: DataSet, transferSyntaxUID: String) throws -> URL {
        guard TransferSyntax.from(uid: transferSyntaxUID)?.isJPIP == true else {
            throw DICOMJPIPError.notAJPIPTransferSyntax(transferSyntaxUID)
        }
        guard let pixelDataElement = dataset[Tag.pixelData] else {
            throw DICOMJPIPError.missingPixelData
        }
        // Pixel Data for JPIP transfer syntaxes holds the URI as a byte string
        let rawBytes = pixelDataElement.valueData
        guard !rawBytes.isEmpty else {
            throw DICOMJPIPError.missingPixelData
        }
        guard let uriString = String(data: rawBytes, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !uriString.isEmpty,
              let url = URL(string: uriString)
        else {
            let raw = String(data: rawBytes, encoding: .utf8) ?? "<binary>"
            throw DICOMJPIPError.invalidJPIPURI(raw)
        }
        return url
    }
}
