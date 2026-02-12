import Foundation
import Testing
@testable import DICOMToolbox

// MARK: - File Drop Zone Tests

@Suite("FileDropZone Model Tests")
struct FileDropZoneTests {
    @Test("File path is stored in parameter values")
    func testFilePathStorage() {
        var values: [String: String] = [:]
        values["filePath"] = "/path/to/scan.dcm"
        #expect(values["filePath"] == "/path/to/scan.dcm")
    }

    @Test("File path can be cleared")
    func testFilePathClear() {
        var values: [String: String] = ["filePath": "/path/to/scan.dcm"]
        values["filePath"] = nil
        #expect(values["filePath"] == nil)
    }

    @Test("Multiple file paths stored as comma-separated")
    func testMultipleFilePaths() {
        var values: [String: String] = [:]
        let paths = ["/path/to/file1.dcm", "/path/to/file2.dcm"]
        values["files"] = paths.joined(separator: ",")
        let stored = values["files"]?.components(separatedBy: ",")
        #expect(stored?.count == 2)
        #expect(stored?.first == "/path/to/file1.dcm")
        #expect(stored?.last == "/path/to/file2.dcm")
    }

    @Test("Empty file path is treated as no selection")
    func testEmptyFilePath() {
        let values: [String: String] = ["filePath": ""]
        let path = values["filePath"]
        #expect(path?.isEmpty == true)
    }

    @Test("File path with spaces is preserved")
    func testFilePathWithSpaces() {
        var values: [String: String] = [:]
        values["filePath"] = "/path/to/my scan file.dcm"
        #expect(values["filePath"] == "/path/to/my scan file.dcm")
    }
}

// MARK: - dicom-info Command Generation Tests

@Suite("DicomInfo Command Generation Tests")
struct DicomInfoCommandTests {
    private var builder: CommandBuilder {
        CommandBuilder(tool: ToolRegistry.dicomInfo)
    }

    @Test("Basic dicom-info command with only required file")
    func testBasicCommand() {
        let command = builder.buildCommand(values: ["filePath": "scan.dcm"])
        #expect(command == "dicom-info scan.dcm")
    }

    @Test("dicom-info with format option")
    func testWithFormat() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "format": "json",
        ])
        #expect(command.contains("dicom-info"))
        #expect(command.contains("--format json"))
        #expect(command.contains("scan.dcm"))
    }

    @Test("dicom-info with CSV format")
    func testWithCSVFormat() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "format": "csv",
        ])
        #expect(command.contains("--format csv"))
    }

    @Test("dicom-info with all boolean flags")
    func testWithAllFlags() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "show-private": "true",
            "statistics": "true",
            "force": "true",
        ])
        #expect(command.contains("--show-private"))
        #expect(command.contains("--statistics"))
        #expect(command.contains("--force"))
    }

    @Test("dicom-info with tag filter")
    func testWithTagFilter() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "tag": "PatientName,PatientID",
        ])
        #expect(command.contains("--tag PatientName"))
        #expect(command.contains("--tag PatientID"))
    }

    @Test("dicom-info with single tag filter")
    func testWithSingleTag() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "tag": "Modality",
        ])
        #expect(command.contains("--tag Modality"))
    }

    @Test("dicom-info with all parameters")
    func testWithAllParameters() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "format": "json",
            "tag": "PatientName",
            "show-private": "true",
            "statistics": "true",
            "force": "true",
        ])
        #expect(command.contains("dicom-info"))
        #expect(command.contains("scan.dcm"))
        #expect(command.contains("--format json"))
        #expect(command.contains("--tag PatientName"))
        #expect(command.contains("--show-private"))
        #expect(command.contains("--statistics"))
        #expect(command.contains("--force"))
    }

    @Test("dicom-info empty optional values excluded")
    func testEmptyValuesExcluded() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "format": "",
            "tag": "",
            "show-private": "",
        ])
        #expect(!command.contains("--format"))
        #expect(!command.contains("--tag"))
        #expect(!command.contains("--show-private"))
    }
}

// MARK: - dicom-dump Command Generation Tests

@Suite("DicomDump Command Generation Tests")
struct DicomDumpCommandTests {
    private var builder: CommandBuilder {
        CommandBuilder(tool: ToolRegistry.dicomDump)
    }

    @Test("Basic dicom-dump command")
    func testBasicCommand() {
        let command = builder.buildCommand(values: ["filePath": "scan.dcm"])
        #expect(command == "dicom-dump scan.dcm")
    }

    @Test("dicom-dump with tag filter")
    func testWithTagFilter() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "tag": "0010,0010",
        ])
        #expect(command.contains("--tag 0010,0010"))
    }

    @Test("dicom-dump with offset and length")
    func testWithOffsetAndLength() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "offset": "0x100",
            "length": "256",
        ])
        #expect(command.contains("--offset 0x100"))
        #expect(command.contains("--length 256"))
    }

    @Test("dicom-dump with bytes per line")
    func testWithBytesPerLine() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "bytes-per-line": "32",
        ])
        #expect(command.contains("--bytes-per-line 32"))
    }

    @Test("dicom-dump with annotate and no-color")
    func testWithDisplayFlags() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "annotate": "true",
            "no-color": "true",
        ])
        #expect(command.contains("--annotate"))
        #expect(command.contains("--no-color"))
    }

    @Test("dicom-dump with all parameters")
    func testWithAllParameters() {
        let command = builder.buildCommand(values: [
            "filePath": "scan.dcm",
            "tag": "7FE0,0010",
            "offset": "0x80",
            "length": "512",
            "bytes-per-line": "16",
            "annotate": "true",
            "no-color": "true",
            "force": "true",
        ])
        #expect(command.contains("dicom-dump"))
        #expect(command.contains("scan.dcm"))
        #expect(command.contains("--tag 7FE0,0010"))
        #expect(command.contains("--offset 0x80"))
        #expect(command.contains("--length 512"))
        #expect(command.contains("--bytes-per-line 16"))
        #expect(command.contains("--annotate"))
        #expect(command.contains("--no-color"))
        #expect(command.contains("--force"))
    }
}

// MARK: - dicom-tags Command Generation Tests

@Suite("DicomTags Command Generation Tests")
struct DicomTagsCommandTests {
    private var builder: CommandBuilder {
        CommandBuilder(tool: ToolRegistry.dicomTags)
    }

    @Test("Basic dicom-tags command")
    func testBasicCommand() {
        let command = builder.buildCommand(values: ["input": "scan.dcm"])
        #expect(command == "dicom-tags scan.dcm")
    }

    @Test("dicom-tags with output file")
    func testWithOutput() {
        let command = builder.buildCommand(values: [
            "input": "scan.dcm",
            "output": "modified.dcm",
        ])
        #expect(command.contains("--output modified.dcm"))
    }

    @Test("dicom-tags with set tags")
    func testWithSetTags() {
        let command = builder.buildCommand(values: [
            "input": "scan.dcm",
            "set": "0010,0010=Anonymous,0010,0020=ANON001",
        ])
        #expect(command.contains("--set 0010,0010=Anonymous"))
        #expect(command.contains("--set 0010,0020=ANON001"))
    }

    @Test("dicom-tags with delete tags")
    func testWithDeleteTags() {
        let command = builder.buildCommand(values: [
            "input": "scan.dcm",
            "delete": "0010,0010,0010,0020",
        ])
        #expect(command.contains("--delete 0010,0010"))
        #expect(command.contains("--delete 0010,0020"))
    }

    @Test("dicom-tags with delete-private and dry-run")
    func testWithFlags() {
        let command = builder.buildCommand(values: [
            "input": "scan.dcm",
            "delete-private": "true",
            "dry-run": "true",
        ])
        #expect(command.contains("--delete-private"))
        #expect(command.contains("--dry-run"))
    }

    @Test("dicom-tags with copy-from source")
    func testWithCopyFrom() {
        let command = builder.buildCommand(values: [
            "input": "scan.dcm",
            "copy-from": "reference.dcm",
        ])
        #expect(command.contains("--copy-from reference.dcm"))
    }
}

// MARK: - dicom-diff Command Generation Tests

@Suite("DicomDiff Command Generation Tests")
struct DicomDiffCommandTests {
    private var builder: CommandBuilder {
        CommandBuilder(tool: ToolRegistry.dicomDiff)
    }

    @Test("Basic dicom-diff command with two files")
    func testBasicCommand() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
        ])
        #expect(command.contains("dicom-diff"))
        #expect(command.contains("scan1.dcm"))
        #expect(command.contains("scan2.dcm"))
    }

    @Test("dicom-diff with format option")
    func testWithFormat() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
            "format": "json",
        ])
        #expect(command.contains("--format json"))
    }

    @Test("dicom-diff with summary format")
    func testWithSummaryFormat() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
            "format": "summary",
        ])
        #expect(command.contains("--format summary"))
    }

    @Test("dicom-diff with ignore tags")
    func testWithIgnoreTags() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
            "ignore-tag": "0010,0010,0008,0018",
        ])
        #expect(command.contains("--ignore-tag 0010,0010"))
        #expect(command.contains("--ignore-tag 0008,0018"))
    }

    @Test("dicom-diff with comparison options")
    func testWithComparisonOptions() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
            "tolerance": "0.001",
            "ignore-private": "true",
            "compare-pixels": "true",
            "quick": "true",
            "show-identical": "true",
        ])
        #expect(command.contains("--tolerance 0.001"))
        #expect(command.contains("--ignore-private"))
        #expect(command.contains("--compare-pixels"))
        #expect(command.contains("--quick"))
        #expect(command.contains("--show-identical"))
    }

    @Test("dicom-diff with all parameters")
    func testWithAllParameters() {
        let command = builder.buildCommand(values: [
            "file1": "scan1.dcm",
            "file2": "scan2.dcm",
            "format": "json",
            "ignore-tag": "InstanceUID",
            "tolerance": "0.01",
            "ignore-private": "true",
            "compare-pixels": "true",
            "quick": "true",
            "show-identical": "true",
        ])
        #expect(command.contains("dicom-diff"))
        #expect(command.contains("scan1.dcm"))
        #expect(command.contains("scan2.dcm"))
        #expect(command.contains("--format json"))
        #expect(command.contains("--ignore-tag InstanceUID"))
        #expect(command.contains("--tolerance 0.01"))
        #expect(command.contains("--ignore-private"))
        #expect(command.contains("--compare-pixels"))
        #expect(command.contains("--quick"))
        #expect(command.contains("--show-identical"))
    }
}

// MARK: - Required Parameter Validation Tests

@Suite("Required Parameter Validation Tests")
struct RequiredParameterValidationTests {
    @Test("dicom-info requires filePath")
    func testInfoRequiresFile() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomInfo)
        #expect(!builder.isValid(values: [:]))
        #expect(!builder.isValid(values: ["filePath": ""]))
        #expect(builder.isValid(values: ["filePath": "scan.dcm"]))
    }

    @Test("dicom-dump requires filePath")
    func testDumpRequiresFile() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomDump)
        #expect(!builder.isValid(values: [:]))
        #expect(builder.isValid(values: ["filePath": "scan.dcm"]))
    }

    @Test("dicom-tags requires input file")
    func testTagsRequiresFile() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomTags)
        #expect(!builder.isValid(values: [:]))
        #expect(builder.isValid(values: ["input": "scan.dcm"]))
    }

    @Test("dicom-diff requires both files")
    func testDiffRequiresBothFiles() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomDiff)
        #expect(!builder.isValid(values: [:]))
        #expect(!builder.isValid(values: ["file1": "scan1.dcm"]))
        #expect(!builder.isValid(values: ["file2": "scan2.dcm"]))
        #expect(builder.isValid(values: ["file1": "scan1.dcm", "file2": "scan2.dcm"]))
    }
}

// MARK: - Help Content and Parameter Definition Tests

@Suite("Help Content and Parameter Definition Tests")
struct HelpContentTests {
    @Test("dicom-info has discussion text")
    func testInfoDiscussion() {
        let tool = ToolRegistry.dicomInfo
        #expect(!tool.discussion.isEmpty)
    }

    @Test("dicom-dump has discussion text")
    func testDumpDiscussion() {
        let tool = ToolRegistry.dicomDump
        #expect(!tool.discussion.isEmpty)
    }

    @Test("dicom-tags has discussion text")
    func testTagsDiscussion() {
        let tool = ToolRegistry.dicomTags
        #expect(!tool.discussion.isEmpty)
    }

    @Test("dicom-diff has discussion text")
    func testDiffDiscussion() {
        let tool = ToolRegistry.dicomDiff
        #expect(!tool.discussion.isEmpty)
    }

    @Test("dicom-info format parameter has enum values with descriptions")
    func testInfoFormatEnumValues() {
        let tool = ToolRegistry.dicomInfo
        let formatParam = tool.parameters.first { $0.id == "format" }
        #expect(formatParam != nil)
        #expect(formatParam?.enumValues?.count == 3)

        let textValue = formatParam?.enumValues?.first { $0.value == "text" }
        #expect(textValue != nil)
        #expect(!textValue!.description.isEmpty)
    }

    @Test("dicom-diff format parameter has 3 options")
    func testDiffFormatOptions() {
        let tool = ToolRegistry.dicomDiff
        let formatParam = tool.parameters.first { $0.id == "format" }
        #expect(formatParam?.enumValues?.count == 3)
        let values = formatParam?.enumValues?.map(\.value) ?? []
        #expect(values.contains("text"))
        #expect(values.contains("json"))
        #expect(values.contains("summary"))
    }

    @Test("All file inspection tools have parameters with help text")
    func testAllParamsHaveHelp() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        for tool in tools {
            for param in tool.parameters {
                #expect(!param.help.isEmpty, "Parameter \(param.id) in \(tool.id) should have help text")
            }
        }
    }

    @Test("All file inspection tools have SF Symbol icons")
    func testToolIcons() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        for tool in tools {
            #expect(!tool.icon.isEmpty, "Tool \(tool.id) should have an icon")
        }
    }
}

// MARK: - Missing Parameter Labels Tests

@Suite("Missing Parameter Label Tests")
struct MissingParameterTests {
    @Test("dicom-info missing file shows label")
    func testInfoMissingFile() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomInfo)
        let missing = builder.missingRequiredParameters(values: [:])
        #expect(missing.contains("Input File"))
    }

    @Test("dicom-diff missing second file shows label")
    func testDiffMissingSecondFile() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomDiff)
        let missing = builder.missingRequiredParameters(values: ["file1": "scan1.dcm"])
        #expect(missing.contains("File 2"))
        #expect(!missing.contains("File 1"))
    }

    @Test("dicom-diff missing both files shows both labels")
    func testDiffMissingBothFiles() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomDiff)
        let missing = builder.missingRequiredParameters(values: [:])
        #expect(missing.contains("File 1"))
        #expect(missing.contains("File 2"))
    }

    @Test("dicom-tags no missing when file provided")
    func testTagsNoMissing() {
        let builder = CommandBuilder(tool: ToolRegistry.dicomTags)
        let missing = builder.missingRequiredParameters(values: ["input": "scan.dcm"])
        #expect(missing.isEmpty)
    }
}

// MARK: - Tool Tab Routing Tests

@Suite("File Inspection Tool Routing Tests")
struct FileInspectionToolRoutingTests {
    @Test("File Inspection category has exactly 4 tools")
    func testFileInspectionToolCount() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        #expect(tools.count == 4)
    }

    @Test("File Inspection tools are in correct order")
    func testFileInspectionToolOrder() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        #expect(tools[0].id == "dicom-info")
        #expect(tools[1].id == "dicom-dump")
        #expect(tools[2].id == "dicom-tags")
        #expect(tools[3].id == "dicom-diff")
    }

    @Test("File Inspection tools do not require network")
    func testNoNetworkRequired() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        for tool in tools {
            #expect(!tool.requiresNetwork, "Tool \(tool.id) should not require network")
        }
    }

    @Test("File Inspection tools have no subcommands")
    func testNoSubcommands() {
        let tools = ToolRegistry.tools(for: .fileInspection)
        for tool in tools {
            #expect(tool.subcommands == nil, "Tool \(tool.id) should have no subcommands")
        }
    }
}
