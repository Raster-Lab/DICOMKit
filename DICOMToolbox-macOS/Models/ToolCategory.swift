import Foundation

/// Categories for grouping DICOM CLI tools into logical tabs
enum ToolCategory: String, CaseIterable, Identifiable, Sendable {
    case fileAnalysis = "File Analysis"
    case imaging = "Imaging"
    case networking = "Networking"
    case dicomweb = "DICOMweb"
    case advanced = "Advanced"
    case utilities = "Utilities"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fileAnalysis: return "doc.text.magnifyingglass"
        case .imaging: return "photo.stack"
        case .networking: return "network"
        case .dicomweb: return "globe"
        case .advanced: return "gearshape.2"
        case .utilities: return "wrench.and.screwdriver"
        }
    }

    var description: String {
        switch self {
        case .fileAnalysis:
            return "Inspect, validate, and examine DICOM file metadata and structure"
        case .imaging:
            return "Convert, compress, export, and manipulate DICOM images"
        case .networking:
            return "DICOM network operations: C-ECHO, C-FIND, C-MOVE, C-STORE"
        case .dicomweb:
            return "DICOMweb REST API operations: QIDO-RS, WADO-RS, STOW-RS"
        case .advanced:
            return "Anonymization, archiving, scripting, and study management"
        case .utilities:
            return "UID generation, tag editing, and other utilities"
        }
    }
}
