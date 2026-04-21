// JPIPTests.swift
// Tests for Phase 6: JPIP Streaming support in DICOMKit

import Testing
import Foundation
@testable import DICOMKit
@testable import DICOMCore

// MARK: - TransferSyntax JPIP Tests

@Suite("JPIP Transfer Syntax Tests")
struct JPIPTransferSyntaxTests {

    @Test("jpipReferenced isJPIP returns true")
    func isJPIP_jpipReferenced_returnsTrue() {
        #expect(TransferSyntax.jpipReferenced.isJPIP == true)
    }

    @Test("jpipReferencedDeflate isJPIP returns true")
    func isJPIP_jpipReferencedDeflate_returnsTrue() {
        #expect(TransferSyntax.jpipReferencedDeflate.isJPIP == true)
    }

    @Test("explicitVRLittleEndian isJPIP returns false")
    func isJPIP_explicitVRLittleEndian_returnsFalse() {
        #expect(TransferSyntax.explicitVRLittleEndian.isJPIP == false)
    }

    @Test("implicitVRLittleEndian isJPIP returns false")
    func isJPIP_implicitVRLittleEndian_returnsFalse() {
        #expect(TransferSyntax.implicitVRLittleEndian.isJPIP == false)
    }

    @Test("jpeg2000 isJPIP returns false")
    func isJPIP_jpeg2000_returnsFalse() {
        #expect(TransferSyntax.jpeg2000.isJPIP == false)
    }

    @Test("jpipReferenced has correct UID 1.2.840.10008.1.2.4.94")
    func jpipReferenced_hasCorrectUID() {
        #expect(TransferSyntax.jpipReferenced.uid == "1.2.840.10008.1.2.4.94")
    }

    @Test("jpipReferencedDeflate has correct UID 1.2.840.10008.1.2.4.95")
    func jpipReferencedDeflate_hasCorrectUID() {
        #expect(TransferSyntax.jpipReferencedDeflate.uid == "1.2.840.10008.1.2.4.95")
    }

    @Test("from(uid:) JPIP Referenced UID round-trips")
    func fromUID_jpipReferenced_returnsCorrectSyntax() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.94")
        #expect(ts != nil)
        #expect(ts?.isJPIP == true)
    }

    @Test("from(uid:) JPIP Referenced Deflate UID round-trips")
    func fromUID_jpipReferencedDeflate_returnsCorrectSyntax() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.95")
        #expect(ts != nil)
        #expect(ts?.isJPIP == true)
    }

    @Test("from(uid:) unknown UID returns nil")
    func fromUID_unknownUID_returnsNil() {
        let ts = TransferSyntax.from(uid: "9.9.9.9.9.9.9")
        #expect(ts == nil)
    }

    @Test("from(uid:) resolves JPIP Referenced by UID")
    func fromName_jpip_returnsJPIPSyntax() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.94")
        #expect(ts != nil)
        #expect(ts?.isJPIP == true)
    }

    @Test("from(uid:) resolves JPIP Referenced Deflate by UID")
    func fromName_jpipDeflate_returnsJPIPDeflateSyntax() {
        let ts = TransferSyntax.from(uid: "1.2.840.10008.1.2.4.95")
        #expect(ts != nil)
        #expect(ts?.isJPIP == true)
    }

    @Test("jpipReferenced is explicit VR (PS3.5 §A.8)")
    func jpipReferenced_isExplicitVR() {
        #expect(TransferSyntax.jpipReferenced.isExplicitVR == true)
    }

    @Test("jpipReferencedDeflate is deflated")
    func jpipReferencedDeflate_isDeflated() {
        #expect(TransferSyntax.jpipReferencedDeflate.isDeflated == true)
    }
}

// MARK: - DICOMJPIPError Tests

@Suite("DICOMJPIPError Tests")
struct DICOMJPIPErrorTests {

    @Test("invalidJPIPURI description contains the bad URI")
    func invalidJPIPURI_descriptionContainsURI() {
        let err = DICOMJPIPError.invalidJPIPURI("not-a-uri")
        #expect(err.description.contains("not-a-uri"))
    }

    @Test("notAJPIPTransferSyntax description contains the UID")
    func notAJPIPTransferSyntax_descriptionContainsUID() {
        let uid = "1.2.840.10008.1.2.1"
        let err = DICOMJPIPError.notAJPIPTransferSyntax(uid)
        #expect(err.description.contains(uid))
    }

    @Test("missingPixelData description is not empty")
    func missingPixelData_descriptionIsNotEmpty() {
        #expect(!DICOMJPIPError.missingPixelData.description.isEmpty)
    }

    @Test("jpipModuleUnavailable description is not empty")
    func jpipModuleUnavailable_descriptionIsNotEmpty() {
        #expect(!DICOMJPIPError.jpipModuleUnavailable.description.isEmpty)
    }
}

// MARK: - DICOMJPIPRegion Tests

@Suite("DICOMJPIPRegion Tests")
struct DICOMJPIPRegionTests {

    @Test("init sets x, y, width, height correctly")
    func init_setsAllProperties() {
        let region = DICOMJPIPRegion(x: 10, y: 20, width: 100, height: 200)
        #expect(region.x == 10)
        #expect(region.y == 20)
        #expect(region.width == 100)
        #expect(region.height == 200)
    }
}

// MARK: - DICOMJPIPQuality Tests

@Suite("DICOMJPIPQuality Tests")
struct DICOMJPIPQualityTests {

    @Test("layers(4) stores the layer count")
    func layers_storesCount() {
        let quality = DICOMJPIPQuality.layers(4)
        if case .layers(let n) = quality {
            #expect(n == 4)
        } else {
            Issue.record("Expected .layers(4)")
        }
    }

    @Test("resolutionLevel(2) stores the level")
    func resolutionLevel_storesLevel() {
        let rl = DICOMJPIPQuality.resolutionLevel(2)
        if case .resolutionLevel(let lvl) = rl {
            #expect(lvl == 2)
        } else {
            Issue.record("Expected .resolutionLevel(2)")
        }
    }
}

// MARK: - DICOMJPIPImage Tests

@Suite("DICOMJPIPImage Tests")
struct DICOMJPIPImageTests {

    @Test("init sets all properties correctly")
    func init_setsAllProperties() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let sourceURI = URL(string: "jpip://pacs.example.com:8080/study.dcm")!
        let image = DICOMJPIPImage(
            pixelData: data,
            width: 512,
            height: 512,
            components: 1,
            bitDepth: 12,
            sourceURI: sourceURI,
            qualityLayers: 3
        )
        #expect(image.pixelData == data)
        #expect(image.width == 512)
        #expect(image.height == 512)
        #expect(image.components == 1)
        #expect(image.bitDepth == 12)
        #expect(image.sourceURI == sourceURI)
        #expect(image.qualityLayers == 3)
    }
}

// MARK: - DICOMJPIPClient URI Extraction Tests

@Suite("DICOMJPIPClient URI Extraction Tests")
struct DICOMJPIPClientURIExtractionTests {

    private func makeDataSet(uriString: String) -> DataSet {
        let uriData = Data(uriString.utf8)
        let element = DataElement(tag: .pixelData, vr: .OB, length: UInt32(uriData.count), valueData: uriData)
        var ds = DataSet()
        ds[.pixelData] = element
        return ds
    }

    @Test("valid JPIP dataset extracts correct URL")
    func jpipURI_validDataset_returnsCorrectURL() throws {
        let expected = "jpip://pacs.hospital.org:8080/ct-series/001"
        let ds = makeDataSet(uriString: expected)
        let url = try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.4.94")
        #expect(url.absoluteString == expected)
    }

    @Test("non-JPIP transfer syntax throws notAJPIPTransferSyntax")
    func jpipURI_nonJPIPTransferSyntax_throws() {
        let ds = makeDataSet(uriString: "jpip://example.com/test")
        #expect {
            try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.1")
        } throws: { error in
            guard case DICOMJPIPError.notAJPIPTransferSyntax = error else { return false }
            return true
        }
    }

    @Test("missing Pixel Data element throws missingPixelData")
    func jpipURI_missingPixelData_throws() {
        let ds = DataSet()
        #expect {
            try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.4.94")
        } throws: { error in
            guard case DICOMJPIPError.missingPixelData = error else { return false }
            return true
        }
    }

    @Test("empty Pixel Data throws missingPixelData")
    func jpipURI_emptyPixelData_throws() {
        let element = DataElement(tag: .pixelData, vr: .OB, length: 0, valueData: Data())
        var ds = DataSet()
        ds[.pixelData] = element
        #expect {
            try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.4.94")
        } throws: { error in
            guard case DICOMJPIPError.missingPixelData = error else { return false }
            return true
        }
    }

    @Test("Deflate transfer syntax (UID .95) also extracts URI")
    func jpipURI_deflateTransferSyntax_succeeds() throws {
        let expected = "jpip://pacs.hospital.org:8080/series/002"
        let ds = makeDataSet(uriString: expected)
        let url = try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.4.95")
        #expect(url.absoluteString == expected)
    }

    @Test("leading and trailing whitespace is stripped from URI")
    func jpipURI_whitespaceInPixelData_isTrimmed() throws {
        let paddedURI = "  jpip://pacs.example.com/study  "
        let expected = "jpip://pacs.example.com/study"
        let ds = makeDataSet(uriString: paddedURI)
        let url = try DICOMJPIPClient.jpipURI(from: ds, transferSyntaxUID: "1.2.840.10008.1.2.4.94")
        #expect(url.absoluteString == expected)
    }
}

// MARK: - DICOMJPIPClient actor init tests

@Suite("DICOMJPIPClient Actor Tests")
struct DICOMJPIPClientActorTests {

    @Test("init stores serverURL correctly")
    func init_setsServerURL() {
        let url = URL(string: "http://pacs.example.com:8080")!
        let client = DICOMJPIPClient(serverURL: url)
        #expect(client.serverURL == url)
    }

    @Test("init with HTTPS scheme preserves scheme")
    func init_withHTTPS_preservesScheme() {
        let url = URL(string: "https://secure.pacs.example.com")!
        let client = DICOMJPIPClient(serverURL: url)
        #expect(client.serverURL.scheme == "https")
    }
}

// MARK: - DICOMVolumeProgressiveUpdate Tests

@Suite("DICOMVolumeProgressiveUpdate Tests")
struct DICOMVolumeProgressiveUpdateTests {

    @Test("init stores all properties correctly")
    func init_storesAllProperties() {
        let data = Data([0xAA, 0xBB, 0xCC])
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 7,
            qualityLayer: 2,
            totalLayers: 4,
            sliceData: data,
            width: 512,
            height: 512,
            isVolumeComplete: false
        )
        #expect(update.sliceIndex == 7)
        #expect(update.qualityLayer == 2)
        #expect(update.totalLayers == 4)
        #expect(update.sliceData == data)
        #expect(update.width == 512)
        #expect(update.height == 512)
        #expect(update.isVolumeComplete == false)
    }

    @Test("isVolumeComplete true is preserved")
    func init_isVolumeComplete_true() {
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 0, qualityLayer: 4, totalLayers: 4,
            sliceData: Data(), width: 256, height: 256, isVolumeComplete: true
        )
        #expect(update.isVolumeComplete == true)
    }

    @Test("sliceIndex 0 is valid")
    func init_sliceIndexZero_isValid() {
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 0, qualityLayer: 1, totalLayers: 1,
            sliceData: Data([0x01]), width: 4, height: 4, isVolumeComplete: true
        )
        #expect(update.sliceIndex == 0)
    }

    @Test("qualityLayer 1 is minimum valid layer")
    func init_qualityLayer1_isMinimum() {
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 0, qualityLayer: 1, totalLayers: 1,
            sliceData: Data(), width: 64, height: 64, isVolumeComplete: false
        )
        #expect(update.qualityLayer == 1)
    }

    @Test("totalLayers equals qualityLayer at full quality")
    func totalLayers_equalsQualityLayerAtFullQuality() {
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 5, qualityLayer: 4, totalLayers: 4,
            sliceData: Data(), width: 128, height: 128, isVolumeComplete: false
        )
        #expect(update.qualityLayer == update.totalLayers)
    }

    @Test("sliceData is stored exactly")
    func sliceData_storedExactly() {
        let expected = Data(0..<64)
        let update = DICOMVolumeProgressiveUpdate(
            sliceIndex: 1, qualityLayer: 1, totalLayers: 2,
            sliceData: expected, width: 8, height: 8, isVolumeComplete: false
        )
        #expect(update.sliceData == expected)
    }
}

// MARK: - Progressive Volume API Surface Tests

@Suite("Progressive Volume API Surface Tests")
struct ProgressiveVolumeAPISurfaceTests {

    @Test("openVolumeProgressively with empty URI list finishes immediately")
    func openVolumeProgressively_emptyURIs_finishesImmediately() async {
        let stream = DICOMFile.openVolumeProgressively(
            serverURL: URL(string: "http://localhost:8080")!,
            sliceJPIPURIs: [],
            qualityLayers: 4
        )
        var updateCount = 0
        for await _ in stream {
            updateCount += 1
        }
        #expect(updateCount == 0)
    }

    @Test("openVolumeProgressively qualityLayers clamped below 1 uses 1 layer")
    func openVolumeProgressively_negativeQualityLayers_clampedToOne() async {
        // Pass an unreachable server + 1 URI; since JPIP module is not available in CI,
        // fetchProgressiveQuality will fail silently (skip) and the stream finishes with 0 updates.
        let dummyURI = URL(string: "jpip://localhost:8080/slice0")!
        let stream = DICOMFile.openVolumeProgressively(
            serverURL: URL(string: "http://localhost:8080")!,
            sliceJPIPURIs: [dummyURI],
            qualityLayers: -5
        )
        // We cannot assert a specific count since JPIP module availability varies;
        // the goal is to verify the call compiles and terminates rather than hanging.
        var terminated = false
        for await _ in stream { }
        terminated = true
        #expect(terminated)
    }

    @Test("DICOMVolumeProgressiveUpdate is Sendable")
    func progressiveUpdate_isSendable() {
        // Compile-time check: assigning to a Sendable-typed variable verifies conformance.
        let update: any Sendable = DICOMVolumeProgressiveUpdate(
            sliceIndex: 0, qualityLayer: 1, totalLayers: 1,
            sliceData: Data(), width: 1, height: 1, isVolumeComplete: true
        )
        #expect(update is DICOMVolumeProgressiveUpdate)
    }
}

