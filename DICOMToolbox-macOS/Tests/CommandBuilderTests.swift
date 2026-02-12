import XCTest
@testable import DICOMToolbox

final class CommandBuilderTests: XCTestCase {

    let defaultPACS = PACSConfiguration()

    // MARK: - Basic Command Building

    func test_buildCommand_simpleToolNoValues() {
        let tool = ToolRegistry.dicomInfo
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: [:], pacsConfig: defaultPACS
        )
        XCTAssertEqual(command, "dicom-info")
    }

    func test_buildCommand_withPositionalArgument() {
        let tool = ToolRegistry.dicomInfo
        let values = ["": "scan.dcm"]
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(command.contains("scan.dcm"))
    }

    func test_buildCommand_withFlags() {
        let tool = ToolRegistry.dicomInfo
        let values: [String: String] = [
            "": "scan.dcm",
            "--show-private": "true",
            "--statistics": "true",
        ]
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(command.contains("--show-private"))
        XCTAssertTrue(command.contains("--statistics"))
    }

    func test_buildCommand_withOptions() {
        let tool = ToolRegistry.dicomInfo
        let values: [String: String] = [
            "": "scan.dcm",
            "--format": "json",
        ]
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(command.contains("--format json"))
    }

    func test_buildCommand_withSubcommand() {
        let tool = ToolRegistry.dicomCompress
        let sub = tool.subcommands!.first!
        let values: [String: String] = [
            "": "input.dcm",
            "--output": "output.dcm",
            "--codec": "jpeg",
        ]
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: sub, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(command.hasPrefix("dicom-compress compress"))
    }

    // MARK: - PACS Auto-fill

    func test_buildCommand_PACSAutoFill() {
        let tool = ToolRegistry.dicomEcho
        var pacs = PACSConfiguration()
        pacs.hostname = "myserver"
        pacs.port = 11112
        pacs.localAETitle = "MY_SCU"
        pacs.remoteAETitle = "MY_SCP"

        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: [:], pacsConfig: pacs
        )
        XCTAssertTrue(command.contains("pacs://myserver:11112"))
        XCTAssertTrue(command.contains("--aet MY_SCU"))
        XCTAssertTrue(command.contains("--called-aet MY_SCP"))
    }

    // MARK: - Validation

    func test_isValid_missingRequired() {
        let tool = ToolRegistry.dicomInfo
        let isValid = CommandBuilder.isValid(
            tool: tool, subcommand: nil, values: [:], pacsConfig: defaultPACS
        )
        XCTAssertFalse(isValid, "Should be invalid without required file path")
    }

    func test_isValid_withRequired() {
        let tool = ToolRegistry.dicomInfo
        // The positional file parameter has id derived from cliFlag ""
        let values = ["": "scan.dcm"]
        let isValid = CommandBuilder.isValid(
            tool: tool, subcommand: nil, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(isValid)
    }

    func test_missingRequired_returnsCorrectParams() {
        let tool = ToolRegistry.dicomInfo
        let missing = CommandBuilder.missingRequired(
            tool: tool, subcommand: nil, values: [:], pacsConfig: defaultPACS
        )
        XCTAssertFalse(missing.isEmpty)
        XCTAssertEqual(missing.first?.name, "File Path")
    }

    // MARK: - Shell Escaping

    func test_buildCommand_shellEscaping() {
        let tool = ToolRegistry.dicomInfo
        let values = ["": "/path/with spaces/file.dcm"]
        let command = CommandBuilder.buildCommand(
            tool: tool, subcommand: nil, values: values, pacsConfig: defaultPACS
        )
        XCTAssertTrue(command.contains("'/path/with spaces/file.dcm'"))
    }

    // MARK: - PACSConfiguration

    func test_PACSConfiguration_pacsURL() {
        var config = PACSConfiguration()
        config.hostname = "server.example.com"
        config.port = 11112
        XCTAssertEqual(config.pacsURL, "pacs://server.example.com:11112")
    }

    func test_PACSConfiguration_emptyURL() {
        let config = PACSConfiguration()
        XCTAssertEqual(config.pacsURL, "")
    }

    func test_PACSConfiguration_isValid() {
        var config = PACSConfiguration()
        XCTAssertFalse(config.isValid)

        config.hostname = "server"
        XCTAssertTrue(config.isValid)
    }
}
