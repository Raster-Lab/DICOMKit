// ViewerProtocolLineTests.swift
// DICOMStudioTests
//
// The acquisition protocol shown in the viewer's patient banner.
//
// The bug this pins: Protocol Name (0018,1030) is Type 3 and often absent, and
// an absent value drew nothing at all — indistinguishable, to a reader, from the
// viewer not showing the protocol.

#if canImport(SwiftUI)
import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@MainActor
@Suite("Viewer Protocol Line Tests")
struct ViewerProtocolLineTests {

    private func viewModel(_ values: [(UInt16, UInt16, String)]) -> ImageViewerViewModel {
        let elements = values.map { group, element, value -> DataElement in
            let padded = value.count % 2 == 0 ? value : value + " "
            let data = Data(padded.utf8)
            return DataElement(tag: Tag(group: group, element: element),
                               vr: .LO, length: UInt32(data.count), valueData: data)
        }
        let model = ImageViewerViewModel()
        model.dicomFile = DICOMFile(fileMetaInformation: DataSet(),
                                    dataSet: DataSet(elements: elements))
        return model
    }

    @Test("Protocol Name is shown, labelled")
    func testProtocolName() {
        let model = viewModel([(0x0018, 0x1030, "HEAD ROUTINE")])
        #expect(model.protocolNameForOverlay == "HEAD ROUTINE")
        #expect(model.protocolLineForOverlay == "Protocol: HEAD ROUTINE")
    }

    @Test("Without Protocol Name the performed procedure step description stands in")
    func testPerformedProcedureFallback() {
        let model = viewModel([(0x0040, 0x0254, "CT BRAIN W/O CONTRAST")])
        #expect(model.protocolNameForOverlay == "CT BRAIN W/O CONTRAST")
    }

    @Test("The requested procedure description is the last resort")
    func testRequestedProcedureFallback() {
        let model = viewModel([(0x0032, 0x1060, "CT HEAD")])
        #expect(model.protocolNameForOverlay == "CT HEAD")
    }

    @Test("Protocol Name outranks the procedure descriptions")
    func testPrecedence() {
        let model = viewModel([(0x0018, 0x1030, "HEAD ROUTINE"),
                               (0x0040, 0x0254, "CT BRAIN"),
                               (0x0032, 0x1060, "CT HEAD")])
        #expect(model.protocolNameForOverlay == "HEAD ROUTINE")
    }

    @Test("A file that records no protocol says so rather than showing nothing")
    func testMissingProtocolIsStated() {
        let model = viewModel([(0x0010, 0x0020, "711794")])
        #expect(model.protocolNameForOverlay == nil)
        #expect(model.protocolLineForOverlay == "Protocol: not recorded")
    }

    @Test("A blank value counts as missing")
    func testBlankProtocol() {
        let model = viewModel([(0x0018, 0x1030, "  ")])
        #expect(model.protocolNameForOverlay == nil)
    }

    @Test("With no file open there is no protocol row at all")
    func testNoFile() {
        let model = ImageViewerViewModel()
        #expect(model.protocolLineForOverlay == nil)
    }
}
#endif
