//
// WorkshopDicomImageOutputScopeTests.swift
// DICOMStudioTests
//
// Regression: the output Browse picker grants a FOLDER. When the user then
// types a filename inside it, dicom-image must write that file, not the folder
// URL itself ("The file "Test" couldn't be saved in the folder "Desktop"").
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DICOMStudio
@testable import DICOMKit

@MainActor
struct WorkshopDicomImageOutputScopeTests {

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkshopDicomImageOutputScope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeColourPNG(to url: URL) throws {
        let rgba: [UInt8] = [255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,  255, 255, 255, 255]
        let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
        let image = try #require(CGImage(
            width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, image, nil)
        #expect(CGImageDestinationFinalize(dest))
    }

    @Test("browsed output folder + typed filename writes the typed file inside the grant")
    func browsedFolderThenTypedFilename() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("shot.png")
        try writeColourPNG(to: input)
        let browsed = root.appendingPathComponent("Test", isDirectory: true)
        try FileManager.default.createDirectory(at: browsed, withIntermediateDirectories: true)
        let typed = browsed.appendingPathComponent("TEST2.dcm").path

        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-image")
        vm.updateParameterValue(parameterID: "input", value: input.path)
        // Browse grants the folder…
        vm.setSecurityScopedURL(browsed, forParameterID: "output")
        // …then the user appends a filename in the text field.
        vm.updateParameterValue(parameterID: "output", value: typed)
        vm.updateParameterValue(parameterID: "patient-name", value: "TEST")
        vm.updateParameterValue(parameterID: "patient-id", value: "123456")
        await vm.executeCommand()

        #expect(vm.consoleStatus == .success, "console: \(vm.consoleOutput)")
        #expect(FileManager.default.fileExists(atPath: typed), "expected \(typed); console: \(vm.consoleOutput)")
        #expect(vm.consoleOutput.contains(typed))
        #expect(!vm.consoleOutput.contains("couldn't be saved"))
        let ds = try DICOMFile.read(from: Data(contentsOf: URL(fileURLWithPath: typed))).dataSet
        #expect(ds.string(for: .photometricInterpretation) == "RGB")
    }

    @Test("browsed output folder alone still writes a file inside it, not onto the folder URL")
    func browsedFolderOnly() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("shot.png")
        try writeColourPNG(to: input)
        let browsed = root.appendingPathComponent("Out", isDirectory: true)
        try FileManager.default.createDirectory(at: browsed, withIntermediateDirectories: true)

        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-image")
        vm.updateParameterValue(parameterID: "input", value: input.path)
        vm.setSecurityScopedURL(browsed, forParameterID: "output")
        vm.updateParameterValue(parameterID: "patient-name", value: "TEST")
        vm.updateParameterValue(parameterID: "patient-id", value: "123456")
        await vm.executeCommand()

        #expect(vm.consoleStatus == .success, "console: \(vm.consoleOutput)")
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: browsed.path, isDirectory: &isDir) && isDir.boolValue,
                "the browsed folder must survive as a folder")
        let written = (try? FileManager.default.contentsOfDirectory(atPath: browsed.path)) ?? []
        #expect(written.contains { $0.hasSuffix(".dcm") || $0 == "output.dat" }, "wrote: \(written); console: \(vm.consoleOutput)")
    }
}
