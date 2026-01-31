import Foundation

/// DICOM UID Generator
///
/// Generates unique identifiers (UIDs) for DICOM objects following
/// the DICOM PS3.5 Section 9 - Unique Identifiers specification.
///
/// UIDs are composed of numeric components separated by periods (dots).
/// The maximum total length is 64 characters.
///
/// Reference: DICOM PS3.5 Section 9 - Unique Identifiers (UIDs)
public struct UIDGenerator: Sendable {
    
    /// Default UID root for generated UIDs
    ///
    /// This is a private enterprise number root. In production, organizations
    /// should use their own registered UID root obtained from IANA.
    ///
    /// The default root "1.2.276.0.7230010.3" is used by various open-source
    /// DICOM implementations as a convention.
    ///
    /// Reference: PS3.5 Section 9.1 - UID Encoding Rules
    public static let defaultRoot = "1.2.276.0.7230010.3"
    
    /// The UID root prefix for generated UIDs
    public let root: String
    
    /// Creates a UID generator with the specified root
    /// - Parameter root: The UID root prefix to use for generated UIDs
    public init(root: String = UIDGenerator.defaultRoot) {
        self.root = root
    }
    
    /// Generates a unique UID based on timestamp and random components
    ///
    /// The generated UID format is:
    /// `{root}.{timestamp}.{random}`
    ///
    /// where:
    /// - root: The configured UID root
    /// - timestamp: Unix timestamp in microseconds
    /// - random: Random component for uniqueness
    ///
    /// Reference: PS3.5 Section 9.1 - UID Encoding Rules
    ///
    /// - Returns: A new unique DICOMUniqueIdentifier
    public func generate() -> DICOMUniqueIdentifier {
        // Get timestamp in microseconds
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        
        // Generate random component (0-999999)
        let random = UInt32.random(in: 0..<1_000_000)
        
        // Build UID ensuring it doesn't exceed 64 characters
        var uidString = "\(root).\(timestamp).\(random)"
        
        // Truncate if necessary to fit within 64 characters
        if uidString.count > DICOMUniqueIdentifier.maximumLength {
            uidString = String(uidString.prefix(DICOMUniqueIdentifier.maximumLength))
            // Ensure it doesn't end with a period
            while uidString.hasSuffix(".") {
                uidString = String(uidString.dropLast())
            }
        }
        
        // This should never fail with our controlled format
        guard let uid = DICOMUniqueIdentifier.parse(uidString) else {
            // Fallback: generate a simpler UID
            let fallbackString = "\(root).\(timestamp)"
            return DICOMUniqueIdentifier.parse(fallbackString)!
        }
        
        return uid
    }
    
    /// Generates a unique UID with a specific type suffix
    ///
    /// The generated UID format is:
    /// `{root}.{type}.{timestamp}.{random}`
    ///
    /// - Parameter type: A numeric identifier for the type of object (e.g., 1 for Study, 2 for Series, 3 for Instance)
    /// - Returns: A new unique DICOMUniqueIdentifier
    public func generate(type: UInt8) -> DICOMUniqueIdentifier {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let random = UInt32.random(in: 0..<1_000_000)
        
        var uidString = "\(root).\(type).\(timestamp).\(random)"
        
        if uidString.count > DICOMUniqueIdentifier.maximumLength {
            uidString = String(uidString.prefix(DICOMUniqueIdentifier.maximumLength))
            while uidString.hasSuffix(".") {
                uidString = String(uidString.dropLast())
            }
        }
        
        guard let uid = DICOMUniqueIdentifier.parse(uidString) else {
            let fallbackString = "\(root).\(type).\(timestamp)"
            return DICOMUniqueIdentifier.parse(fallbackString)!
        }
        
        return uid
    }
    
    /// Generates a Study Instance UID
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a study
    public func generateStudyInstanceUID() -> DICOMUniqueIdentifier {
        return generate(type: 1)
    }
    
    /// Generates a Series Instance UID
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a series
    public func generateSeriesInstanceUID() -> DICOMUniqueIdentifier {
        return generate(type: 2)
    }
    
    /// Generates a SOP Instance UID
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a SOP instance
    public func generateSOPInstanceUID() -> DICOMUniqueIdentifier {
        return generate(type: 3)
    }
}

// MARK: - Static Convenience Methods

extension UIDGenerator {
    /// Shared default UID generator using the default root
    public static let shared = UIDGenerator()
    
    /// Generates a unique UID using the default generator
    /// - Returns: A new unique DICOMUniqueIdentifier
    public static func generateUID() -> DICOMUniqueIdentifier {
        return shared.generate()
    }
    
    /// Generates a Study Instance UID using the default generator
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a study
    public static func generateStudyInstanceUID() -> DICOMUniqueIdentifier {
        return shared.generateStudyInstanceUID()
    }
    
    /// Generates a Series Instance UID using the default generator
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a series
    public static func generateSeriesInstanceUID() -> DICOMUniqueIdentifier {
        return shared.generateSeriesInstanceUID()
    }
    
    /// Generates a SOP Instance UID using the default generator
    /// - Returns: A new unique DICOMUniqueIdentifier suitable for a SOP instance
    public static func generateSOPInstanceUID() -> DICOMUniqueIdentifier {
        return shared.generateSOPInstanceUID()
    }
}
