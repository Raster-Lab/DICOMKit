import Foundation

/// Canonical registry of DICOM Storage SOP Class UIDs.
///
/// This is the **single source of truth** for "which SOP Classes are storage
/// objects" across the DICOMKit package. Every component that negotiates
/// storage presentation contexts MUST derive its list from here rather than
/// maintaining its own copy, so the SCU, the SCP and the validator can never
/// drift apart:
///
/// - `DICOMRetrieveService` (C-GET SCU) proposes one storage presentation
///   context per UID so the SCP has somewhere to send each instance.
/// - `StorageSCP` (C-STORE / C-MOVE destination) accepts these abstract
///   syntaxes during association negotiation.
/// - `DICOMValidator` recognises these as known storage objects.
///
/// ## Why this matters
///
/// C-GET and C-MOVE deliver images as C-STORE sub-operations whose abstract
/// syntax must be negotiated up front. If a study's SOP Class is missing from
/// the proposed/accepted set, the peer has no presentation context to send it
/// on and silently transfers **zero** instances (e.g. an X-Ray Angiographic
/// study returning "0 files" while reporting success). Keeping this list broad
/// and shared prevents that class of bug.
///
/// Reference: DICOM PS3.4 Annex B (Storage Service Class), PS3.6 Annex A
/// (Registry of DICOM UIDs).
public enum StorageSOPClass {

    /// All Storage SOP Class UIDs, in a stable, grouped order.
    ///
    /// Ordering is significant only for presentation-context assignment (lower
    /// context IDs go to the more common modalities first); membership is what
    /// matters for negotiation and validation.
    public static let allUIDs: [String] = [
        // MARK: Projection X-Ray
        "1.2.840.10008.5.1.4.1.1.1",        // Computed Radiography Image Storage
        "1.2.840.10008.5.1.4.1.1.1.1",      // Digital X-Ray Image Storage - For Presentation
        "1.2.840.10008.5.1.4.1.1.1.1.1",    // Digital X-Ray Image Storage - For Processing
        "1.2.840.10008.5.1.4.1.1.1.2",      // Digital Mammography X-Ray Image Storage - For Presentation
        "1.2.840.10008.5.1.4.1.1.1.2.1",    // Digital Mammography X-Ray Image Storage - For Processing
        "1.2.840.10008.5.1.4.1.1.1.3",      // Digital Intra-Oral X-Ray - For Presentation
        "1.2.840.10008.5.1.4.1.1.1.3.1",    // Digital Intra-Oral X-Ray - For Processing

        // MARK: X-Ray Angiography & Radiofluoroscopy
        "1.2.840.10008.5.1.4.1.1.12.1",     // X-Ray Angiographic Image Storage
        "1.2.840.10008.5.1.4.1.1.12.1.1",   // Enhanced XA Image Storage
        "1.2.840.10008.5.1.4.1.1.12.2",     // X-Ray Radiofluoroscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.12.2.1",   // Enhanced XRF Image Storage
        "1.2.840.10008.5.1.4.1.1.13.1.1",   // X-Ray 3D Angiographic Image Storage
        "1.2.840.10008.5.1.4.1.1.13.1.2",   // X-Ray 3D Craniofacial Image Storage
        "1.2.840.10008.5.1.4.1.1.13.1.3",   // Breast Tomosynthesis Image Storage
        "1.2.840.10008.5.1.4.1.1.13.1.4",   // Breast Projection X-Ray - For Presentation
        "1.2.840.10008.5.1.4.1.1.13.1.5",   // Breast Projection X-Ray - For Processing

        // MARK: CT
        "1.2.840.10008.5.1.4.1.1.2",        // CT Image Storage
        "1.2.840.10008.5.1.4.1.1.2.1",      // Enhanced CT Image Storage
        "1.2.840.10008.5.1.4.1.1.2.2",      // Legacy Converted Enhanced CT Image Storage

        // MARK: MR
        "1.2.840.10008.5.1.4.1.1.4",        // MR Image Storage
        "1.2.840.10008.5.1.4.1.1.4.1",      // Enhanced MR Image Storage
        "1.2.840.10008.5.1.4.1.1.4.2",      // MR Spectroscopy Storage
        "1.2.840.10008.5.1.4.1.1.4.3",      // Enhanced MR Color Image Storage
        "1.2.840.10008.5.1.4.1.1.4.4",      // Legacy Converted Enhanced MR Image Storage

        // MARK: Ultrasound
        "1.2.840.10008.5.1.4.1.1.6.1",      // Ultrasound Image Storage
        "1.2.840.10008.5.1.4.1.1.6.2",      // Enhanced US Volume Storage
        "1.2.840.10008.5.1.4.1.1.3.1",      // Ultrasound Multi-frame Image Storage

        // MARK: Nuclear Medicine / PET
        "1.2.840.10008.5.1.4.1.1.20",       // Nuclear Medicine Image Storage
        "1.2.840.10008.5.1.4.1.1.128",      // Positron Emission Tomography Image Storage
        "1.2.840.10008.5.1.4.1.1.128.1",    // Legacy Converted Enhanced PET Image Storage
        "1.2.840.10008.5.1.4.1.1.130",      // Enhanced PET Image Storage

        // MARK: Secondary Capture
        "1.2.840.10008.5.1.4.1.1.7",        // Secondary Capture Image Storage
        "1.2.840.10008.5.1.4.1.1.7.1",      // Multi-frame Single Bit SC Image Storage
        "1.2.840.10008.5.1.4.1.1.7.2",      // Multi-frame Grayscale Byte SC Image Storage
        "1.2.840.10008.5.1.4.1.1.7.3",      // Multi-frame Grayscale Word SC Image Storage
        "1.2.840.10008.5.1.4.1.1.7.4",      // Multi-frame True Color SC Image Storage

        // MARK: Visible Light / Microscopy / Ophthalmic
        "1.2.840.10008.5.1.4.1.1.77.1.1",   // VL Endoscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.1.1", // Video Endoscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.2",   // VL Microscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.2.1", // Video Microscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.3",   // VL Slide-Coordinates Microscopic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.4",   // VL Photographic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.4.1", // Video Photographic Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.5.1", // Ophthalmic Photography 8 Bit Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.5.2", // Ophthalmic Photography 16 Bit Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.5.4", // Ophthalmic Tomography Image Storage
        "1.2.840.10008.5.1.4.1.1.77.1.6",   // VL Whole Slide Microscopy Image Storage

        // MARK: Radiotherapy
        "1.2.840.10008.5.1.4.1.1.481.1",    // RT Image Storage
        "1.2.840.10008.5.1.4.1.1.481.2",    // RT Dose Storage
        "1.2.840.10008.5.1.4.1.1.481.3",    // RT Structure Set Storage
        "1.2.840.10008.5.1.4.1.1.481.4",    // RT Beams Treatment Record Storage
        "1.2.840.10008.5.1.4.1.1.481.5",    // RT Plan Storage

        // MARK: Presentation States
        "1.2.840.10008.5.1.4.1.1.11.1",     // Grayscale Softcopy Presentation State Storage
        "1.2.840.10008.5.1.4.1.1.11.2",     // Color Softcopy Presentation State Storage

        // MARK: Structured Reporting & Documents
        "1.2.840.10008.5.1.4.1.1.88.11",    // Basic Text SR Storage
        "1.2.840.10008.5.1.4.1.1.88.22",    // Enhanced SR Storage
        "1.2.840.10008.5.1.4.1.1.88.33",    // Comprehensive SR Storage
        "1.2.840.10008.5.1.4.1.1.88.34",    // Comprehensive 3D SR Storage
        "1.2.840.10008.5.1.4.1.1.88.59",    // Key Object Selection Document Storage
        "1.2.840.10008.5.1.4.1.1.104.1",    // Encapsulated PDF Storage
        "1.2.840.10008.5.1.4.1.1.104.2",    // Encapsulated CDA Storage

        // MARK: Raw / Spatial / Segmentation
        "1.2.840.10008.5.1.4.1.1.66",       // Raw Data Storage
        "1.2.840.10008.5.1.4.1.1.66.1",     // Spatial Registration Storage
        "1.2.840.10008.5.1.4.1.1.66.2",     // Spatial Fiducials Storage
        "1.2.840.10008.5.1.4.1.1.66.3",     // Deformable Spatial Registration Storage
        "1.2.840.10008.5.1.4.1.1.66.4",     // Segmentation Storage
        "1.2.840.10008.5.1.4.1.1.66.5"      // Surface Segmentation Storage
    ]

    /// All Storage SOP Class UIDs as a set, for fast membership checks.
    public static let allUIDSet: Set<String> = Set(allUIDs)

    /// Returns `true` if the given UID is a known Storage SOP Class.
    public static func isStorage(_ uid: String) -> Bool {
        allUIDSet.contains(uid)
    }
}
