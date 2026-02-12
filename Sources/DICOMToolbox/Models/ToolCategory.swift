/// Tool category for tab grouping in DICOMToolbox
public enum ToolCategory: String, CaseIterable, Sendable, Identifiable {
    case fileInspection = "File Inspection"
    case fileProcessing = "File Processing"
    case fileOrganization = "File Organization"
    case dataExport = "Data Export"
    case networkOperations = "Network Operations"
    case automation = "Automation"

    public var id: String { rawValue }

    /// SF Symbol name for the tab icon
    public var iconName: String {
        switch self {
        case .fileInspection: return "doc.text.magnifyingglass"
        case .fileProcessing: return "gearshape.2"
        case .fileOrganization: return "folder.badge.gearshape"
        case .dataExport: return "square.and.arrow.up"
        case .networkOperations: return "network"
        case .automation: return "terminal"
        }
    }
}
