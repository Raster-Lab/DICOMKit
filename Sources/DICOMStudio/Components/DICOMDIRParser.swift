// DICOMDIRParser.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent DICOMDIR parsing helper

import Foundation

/// Platform-independent helper for parsing DICOMDIR (Media Storage Directory) files.
///
/// DICOMDIR files follow the DICOM PS3.10 standard and contain a directory
/// of DICOM files stored on removable media (CD/DVD). This helper extracts
/// the referenced file paths from the directory records.
///
/// Reference: DICOM PS3.3 F.3 (Basic Directory Information Object Definition)
public enum DICOMDIRParser: Sendable {

    /// A record in the DICOMDIR representing a referenced DICOM file or directory level.
    public struct DirectoryRecord: Sendable, Equatable {
        /// The type of directory record (PATIENT, STUDY, SERIES, IMAGE, etc.).
        public let recordType: String

        /// Referenced file ID components (path segments relative to DICOMDIR location).
        public let referencedFileID: [String]

        /// Patient name, if this is a PATIENT-level record.
        public let patientName: String?

        /// Patient ID, if this is a PATIENT-level record.
        public let patientID: String?

        /// Study Instance UID, if this is a STUDY-level record.
        public let studyInstanceUID: String?

        /// Study date string, if this is a STUDY-level record.
        public let studyDate: String?

        /// Study description, if this is a STUDY-level record.
        public let studyDescription: String?

        /// Series Instance UID, if this is a SERIES-level record.
        public let seriesInstanceUID: String?

        /// Modality, if this is a SERIES-level record.
        public let modality: String?

        /// SOP Instance UID, if this is an IMAGE-level record.
        public let sopInstanceUID: String?

        /// Creates a directory record.
        public init(
            recordType: String,
            referencedFileID: [String] = [],
            patientName: String? = nil,
            patientID: String? = nil,
            studyInstanceUID: String? = nil,
            studyDate: String? = nil,
            studyDescription: String? = nil,
            seriesInstanceUID: String? = nil,
            modality: String? = nil,
            sopInstanceUID: String? = nil
        ) {
            self.recordType = recordType
            self.referencedFileID = referencedFileID
            self.patientName = patientName
            self.patientID = patientID
            self.studyInstanceUID = studyInstanceUID
            self.studyDate = studyDate
            self.studyDescription = studyDescription
            self.seriesInstanceUID = seriesInstanceUID
            self.modality = modality
            self.sopInstanceUID = sopInstanceUID
        }
    }

    /// Known DICOMDIR record types per PS3.3 F.3.
    public static let knownRecordTypes: Set<String> = [
        "PATIENT", "STUDY", "SERIES", "IMAGE",
        "RT DOSE", "RT STRUCTURE SET", "RT PLAN",
        "PRESENTATION", "SR DOCUMENT", "KEY OBJECT DOC",
        "SPECTROSCOPY", "RAW DATA", "REGISTRATION",
        "FIDUCIAL", "HANGING PROTOCOL", "ENCAP DOC",
        "HL7 STRUC DOC", "VALUE MAP", "STEREOMETRIC",
        "PALETTE", "IMPLANT", "IMPLANT GROUP",
        "IMPLANT ASSY", "MEASUREMENT", "SURFACE",
        "SURFACE SCAN", "TRACT", "ASSESSMENT",
        "RADIOTHERAPY", "PRIVATE"
    ]

    /// Checks whether a file name matches the DICOMDIR naming convention.
    ///
    /// - Parameter fileName: The file name to check.
    /// - Returns: `true` if the file is named "DICOMDIR" (case-insensitive).
    public static func isDICOMDIR(fileName: String) -> Bool {
        fileName.uppercased() == "DICOMDIR"
    }

    /// Checks whether a URL points to a DICOMDIR file.
    ///
    /// - Parameter url: The file URL to check.
    /// - Returns: `true` if the URL's last path component is "DICOMDIR".
    public static func isDICOMDIR(url: URL) -> Bool {
        isDICOMDIR(fileName: url.lastPathComponent)
    }

    /// Resolves a referenced file ID to a file system path relative to the DICOMDIR location.
    ///
    /// DICOMDIR uses backslash-separated path components (per DICOM PS3.10).
    /// This method converts them to the native file system path.
    ///
    /// - Parameters:
    ///   - fileID: The referenced file ID components.
    ///   - dicomdirURL: The URL of the DICOMDIR file itself.
    /// - Returns: The resolved file URL, or nil if the file ID is empty.
    public static func resolveFileURL(
        fileID: [String],
        relativeTo dicomdirURL: URL
    ) -> URL? {
        guard !fileID.isEmpty else { return nil }
        let baseDir = dicomdirURL.deletingLastPathComponent()
        var resolved = baseDir
        for component in fileID {
            resolved = resolved.appendingPathComponent(component)
        }
        return resolved
    }

    /// Parses a raw referenced file ID string (backslash-separated) into path components.
    ///
    /// - Parameter rawFileID: The raw file ID string (e.g., "IMAGES\\CT001\\IM00001").
    /// - Returns: Array of path components.
    public static func parseFileID(_ rawFileID: String) -> [String] {
        rawFileID.split(separator: "\\").map { String($0) }
    }

    /// Validates that a record type is a known DICOMDIR record type.
    ///
    /// - Parameter recordType: The record type string.
    /// - Returns: `true` if the record type is recognized.
    public static func isKnownRecordType(_ recordType: String) -> Bool {
        knownRecordTypes.contains(recordType.uppercased())
    }

    /// Returns all image-level records from a collection of directory records.
    ///
    /// - Parameter records: The directory records to filter.
    /// - Returns: Records with type "IMAGE" that have referenced file IDs.
    public static func imageRecords(from records: [DirectoryRecord]) -> [DirectoryRecord] {
        records.filter { $0.recordType.uppercased() == "IMAGE" && !$0.referencedFileID.isEmpty }
    }

    /// Returns all unique file URLs referenced by the given directory records,
    /// resolved relative to the DICOMDIR location.
    ///
    /// - Parameters:
    ///   - records: The directory records.
    ///   - dicomdirURL: The URL of the DICOMDIR file.
    /// - Returns: Array of resolved file URLs.
    public static func resolveAllFileURLs(
        from records: [DirectoryRecord],
        relativeTo dicomdirURL: URL
    ) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        for record in records where !record.referencedFileID.isEmpty {
            if let url = resolveFileURL(fileID: record.referencedFileID, relativeTo: dicomdirURL) {
                let path = url.path
                if !seen.contains(path) {
                    seen.insert(path)
                    urls.append(url)
                }
            }
        }
        return urls
    }
}
