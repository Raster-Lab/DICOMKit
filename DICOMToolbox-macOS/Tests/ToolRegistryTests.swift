import XCTest
@testable import DICOMToolbox

final class ToolRegistryTests: XCTestCase {

    func test_allToolsNotEmpty() {
        XCTAssertFalse(ToolRegistry.allTools.isEmpty)
    }

    func test_allToolsHaveUniqueIDs() {
        let ids = ToolRegistry.allTools.map { $0.id }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All tool IDs should be unique")
    }

    func test_allToolsHaveUniqueCommands() {
        let commands = ToolRegistry.allTools.map { $0.command }
        let uniqueCommands = Set(commands)
        XCTAssertEqual(commands.count, uniqueCommands.count, "All tool commands should be unique")
    }

    func test_allCategoriesHaveTools() {
        for category in ToolCategory.allCases {
            let tools = ToolRegistry.tools(for: category)
            XCTAssertFalse(tools.isEmpty, "Category \(category.rawValue) should have at least one tool")
        }
    }

    func test_toolsGroupedByCategory() {
        let fileAnalysis = ToolRegistry.tools(for: .fileAnalysis)
        XCTAssertTrue(fileAnalysis.allSatisfy { $0.category == .fileAnalysis })

        let networking = ToolRegistry.tools(for: .networking)
        XCTAssertTrue(networking.allSatisfy { $0.category == .networking })
    }

    func test_toolDefinitionProperties() {
        let info = ToolRegistry.dicomInfo
        XCTAssertEqual(info.command, "dicom-info")
        XCTAssertEqual(info.category, .fileAnalysis)
        XCTAssertFalse(info.name.isEmpty)
        XCTAssertFalse(info.abstract.isEmpty)
        XCTAssertFalse(info.icon.isEmpty)
        XCTAssertFalse(info.parameters.isEmpty)
    }

    func test_networkToolsHavePACSParameters() {
        let networkTools = ToolRegistry.tools(for: .networking)
        for tool in networkTools {
            let params = tool.subcommands?.first?.parameters ?? tool.parameters
            let hasPACS = params.contains { $0.isPACSParameter }
            XCTAssertTrue(hasPACS, "Network tool \(tool.name) should have PACS parameters")
        }
    }

    func test_toolsWithSubcommands() {
        let compress = ToolRegistry.dicomCompress
        XCTAssertTrue(compress.hasSubcommands)
        XCTAssertNotNil(compress.subcommands)
        XCTAssertEqual(compress.subcommands?.count, 3)

        let info = ToolRegistry.dicomInfo
        XCTAssertFalse(info.hasSubcommands)
    }

    func test_requiredParametersExist() {
        let info = ToolRegistry.dicomInfo
        let required = info.parameters.filter { $0.isRequired }
        XCTAssertFalse(required.isEmpty, "dicom-info should have required parameters")

        // File path should be required
        let filePath = required.first
        XCTAssertNotNil(filePath)
        XCTAssertEqual(filePath?.name, "File Path")
    }
}
