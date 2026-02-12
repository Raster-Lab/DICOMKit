import Foundation

/// Registry of all available DICOM CLI tools with their parameter definitions
enum ToolRegistry {

    /// All tool definitions grouped and ordered
    static let allTools: [ToolDefinition] = [
        // MARK: - File Analysis
        dicomInfo,
        dicomDump,
        dicomTags,
        dicomValidate,
        dicomDiff,

        // MARK: - Imaging
        dicomConvert,
        dicomImage,
        dicomCompress,
        dicomExport,
        dicomSplit,
        dicomMerge,
        dicomPixedit,
        dicomPdf,

        // MARK: - Networking
        dicomEcho,
        dicomQuery,
        dicomRetrieve,
        dicomSend,
        dicomQr,
        dicomMwl,
        dicomMpps,

        // MARK: - DICOMweb
        dicomWado,
        dicomJson,
        dicomXml,

        // MARK: - Advanced
        dicomAnon,
        dicomArchive,
        dicomDcmdir,
        dicomStudy,
        dicomScript,

        // MARK: - Utilities
        dicomUid,
    ]

    /// Tools grouped by category
    static func tools(for category: ToolCategory) -> [ToolDefinition] {
        allTools.filter { $0.category == category }
    }
}
