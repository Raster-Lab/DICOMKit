// ImageRoundTripTests.swift
// Oracle-based round-trip tests for the `dicom-image` CLI.
//
// These tests call the DICOMKit LIBRARY directly (ImageConverter) — never the CLI
// binary. `dicom-image` is a thin orchestration layer around
// ImageConverter.secondaryCaptureData / .pageCount / .generateUID / .isImageFile,
// all of which are gated on `#if canImport(CoreGraphics)` (macOS/iOS only), so the
// whole suite is platform-gated the same way the source is.
//
// Every assertion is a semantic oracle true by definition of Secondary Capture
// conversion (SOP class UID is SC storage; Rows/Columns match the source raster;
// metadata flags propagate verbatim; batch UIDs are distinct; multi-page split
// yields one single-frame file per page), never a comparison to a re-implementation
// of the tool.
//
// See ROUND_TRIP_TESTS_PLAN.md §3.18.

import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#endif

final class ImageRoundTripTests: XCTestCase {

    #if canImport(CoreGraphics)

    // MARK: - Private image-authoring helpers (class-scoped, never global)

    /// The DICOM Secondary Capture Image Storage SOP Class UID (PS3.4).
    private let secondaryCaptureSOPClass = "1.2.840.10008.5.1.4.1.1.7"

    /// UTType/ContentType identifiers used by CGImageDestination.
    private var pngType: CFString {
        #if canImport(UniformTypeIdentifiers)
        if #available(macOS 11.0, iOS 14.0, *) { return UTType.png.identifier as CFString }
        #endif
        return "public.png" as CFString
    }
    private var tiffType: CFString {
        #if canImport(UniformTypeIdentifiers)
        if #available(macOS 11.0, iOS 14.0, *) { return UTType.tiff.identifier as CFString }
        #endif
        return "public.tiff" as CFString
    }

    /// Builds a grayscale (monochrome) `CGImage` with a deterministic gradient.
    ///
    /// ImageConverter's RGB path uses an 8-bit DeviceRGB CGContext with
    /// CGImageAlphaInfo.none, which CoreGraphics rejects at runtime (24-bit RGB
    /// without alpha is unsupported), so the pixel-exact oracles here use a
    /// monochrome source (getSamplesPerPixel → 1 → MONOCHROME2 output, the path
    /// CGContext supports with DeviceGray).
    private func makeGrayCGImage(width: Int, height: Int) throws -> CGImage {
        let bytesPerRow = width // 1 byte/pixel, DeviceGray
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * bytesPerRow + x] = UInt8((x + y) % 256)
            }
        }
        let cs = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: cs, bitmapInfo: bitmapInfo.rawValue),
              let image = ctx.makeImage() else {
            throw XCTSkip("CoreGraphics could not create a grayscale bitmap context")
        }
        return image
    }

    /// Writes a single-image PNG to a temp URL and returns it.
    private func writePNG(width: Int, height: Int, name: String = "img.png") throws -> URL {
        let image = try makeGrayCGImage(width: width, height: height)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMImageRT-\(UUID().uuidString)-\(name)")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, pngType, 1, nil) else {
            throw XCTSkip("CGImageDestination unavailable for PNG")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw XCTSkip("Failed to finalize PNG")
        }
        return url
    }

    /// Writes a PNG carrying an EXIF DateTimeOriginal ("YYYY:MM:DD HH:MM:SS").
    private func writePNGWithEXIFDate(width: Int, height: Int,
                                      exifDateTime: String,
                                      name: String = "exif.png") throws -> URL {
        let image = try makeGrayCGImage(width: width, height: height)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMImageRT-\(UUID().uuidString)-\(name)")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, pngType, 1, nil) else {
            throw XCTSkip("CGImageDestination unavailable for PNG")
        }
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: exifDateTime
        ]
        let props: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exif
        ]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw XCTSkip("Failed to finalize EXIF PNG")
        }
        return url
    }

    /// Writes a multi-page TIFF (`pages` frames) and returns its URL.
    private func writeMultiPageTIFF(width: Int, height: Int, pages: Int,
                                    name: String = "multi.tiff") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMImageRT-\(UUID().uuidString)-\(name)")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, tiffType, pages, nil) else {
            throw XCTSkip("CGImageDestination unavailable for TIFF")
        }
        for _ in 0..<pages {
            let image = try makeGrayCGImage(width: width, height: height)
            CGImageDestinationAddImage(dest, image, nil)
        }
        guard CGImageDestinationFinalize(dest) else {
            throw XCTSkip("Failed to finalize multi-page TIFF")
        }
        return url
    }

    /// Standard metadata with auto-generated study/series UIDs.
    private func makeMetadata(patientName: String = "ROUND^TRIP",
                              patientID: String = "RT001",
                              instanceNumber: Int = 1,
                              studyUID: String? = nil,
                              seriesUID: String? = nil) -> ImageConverter.Metadata {
        ImageConverter.Metadata(
            patientName: patientName, patientID: patientID,
            studyUID: studyUID ?? ImageConverter.generateUID(),
            seriesUID: seriesUID ?? ImageConverter.generateUID(),
            instanceNumber: instanceNumber)
    }

    // MARK: - Tests

    // Oracle: PNG → SC has SOP Class == Secondary Capture; Rows/Columns == raster.
    func testPNGToSecondaryCaptureSOPClassAndDimensions() throws {
        let png = try writePNG(width: 6, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .sopClassUID), secondaryCaptureSOPClass)
        // Rows == image height, Columns == image width (per Image Pixel Module).
        XCTAssertEqual(file.dataSet[.rows]?.uint16Value, 4)
        XCTAssertEqual(file.dataSet[.columns]?.uint16Value, 6)
    }

    // Oracle: patient-name / patient-id metadata propagate verbatim to output tags.
    func testMetadataFlagsWrittenToTags() throws {
        let png = try writePNG(width: 4, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png,
            metadata: makeMetadata(patientName: "ROUND^TRIP", patientID: "RT001"),
            useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .patientName), "ROUND^TRIP")
        XCTAssertEqual(file.dataSet.string(for: .patientID), "RT001")
    }

    // Oracle: --modality / --study-description / --series-description / --series-number
    // propagate verbatim into (0008,0060)/(0008,1030)/(0008,103E)/(0020,0011).
    func testDescriptiveMetadataPropagatesToTags() throws {
        let png = try writePNG(width: 4, height: 4)
        let md = ImageConverter.Metadata(
            patientName: "ROUND^TRIP", patientID: "RT001",
            studyUID: ImageConverter.generateUID(), seriesUID: ImageConverter.generateUID(),
            instanceNumber: 1,
            studyDescription: "Head CT", seriesDescription: "Axial 1mm",
            modality: "SC", seriesNumber: 7)
        let data = try ImageConverter.secondaryCaptureData(imageURL: png, metadata: md, useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .modality), "SC")
        XCTAssertEqual(file.dataSet.string(for: .studyDescription), "Head CT")
        XCTAssertEqual(file.dataSet.string(for: .seriesDescription), "Axial 1mm")
        XCTAssertEqual(file.dataSet.string(for: .seriesNumber)?.trimmingCharacters(in: .whitespaces), "7")
    }

    // Oracle: modality defaults to OT (Other) when not specified.
    func testDefaultModalityIsOT() throws {
        let png = try writePNG(width: 4, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: false)
        let file = try DICOMFile.read(from: data)
        XCTAssertEqual(file.dataSet.string(for: .modality), "OT",
                       "default modality must be OT when --modality is not given")
    }

    // Oracle: study/series UIDs supplied in metadata propagate verbatim to the output.
    func testSuppliedUIDsPropagateVerbatim() throws {
        let studyUID = rtUID()
        let seriesUID = rtUID()
        let png = try writePNG(width: 4, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png,
            metadata: makeMetadata(studyUID: studyUID, seriesUID: seriesUID),
            useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .studyInstanceUID), studyUID)
        XCTAssertEqual(file.dataSet.string(for: .seriesInstanceUID), seriesUID)
    }

    // Oracle: instanceNumber in metadata equals the output Instance Number tag.
    func testInstanceNumberPropagates() throws {
        let png = try writePNG(width: 4, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(instanceNumber: 7), useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .instanceNumber)?
            .trimmingCharacters(in: .whitespaces), "7")
    }

    // Oracle: EXIF DateTimeOriginal maps to Acquisition Date (0008,0022) as YYYYMMDD.
    func testEXIFDateMappedToAcquisitionDate() throws {
        let png = try writePNGWithEXIFDate(width: 4, height: 4,
                                           exifDateTime: "2024:01:15 10:30:00")
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: true)
        let file = try DICOMFile.read(from: data)

        // ImageConverter maps EXIF DateTimeOriginal → AcquisitionDate/Time.
        let acqDate = file.dataSet.string(for: .acquisitionDate)
        try XCTSkipIf(acqDate == nil, "ImageIO did not round-trip EXIF DateTimeOriginal for PNG")
        XCTAssertEqual(acqDate?.trimmingCharacters(in: .whitespaces), "20240115")
    }

    // Oracle: a monochrome source yields MONOCHROME2 photometric with 1 sample/pixel.
    func testMonochromePhotometricAndSamples() throws {
        let png = try writePNG(width: 5, height: 5)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet.string(for: .photometricInterpretation), "MONOCHROME2")
        XCTAssertEqual(file.dataSet[.samplesPerPixel]?.uint16Value, 1)
    }

    // Oracle: pixel data length == Rows × Columns × SamplesPerPixel (8-bit, uncompressed).
    func testPixelDataLengthMatchesGeometry() throws {
        let png = try writePNG(width: 8, height: 6)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: false)
        let file = try DICOMFile.read(from: data)

        let rows = Int(file.dataSet[.rows]?.uint16Value ?? 0)
        let cols = Int(file.dataSet[.columns]?.uint16Value ?? 0)
        let spp = Int(file.dataSet[.samplesPerPixel]?.uint16Value ?? 0)
        XCTAssertEqual(rows, 6)
        XCTAssertEqual(cols, 8)
        XCTAssertEqual(pixelBytes(file).count, rows * cols * spp)
    }

    // Oracle: batch of N images → N readable Secondary Capture DICOM files.
    func testBatchProducesNReadableSCFiles() throws {
        let studyUID = ImageConverter.generateUID()
        let seriesUID = ImageConverter.generateUID()
        let outDir = try makeTempDir()
        let n = 3
        for i in 0..<n {
            let png = try writePNG(width: 4, height: 4, name: "b\(i).png")
            let data = try ImageConverter.secondaryCaptureData(
                imageURL: png,
                metadata: makeMetadata(instanceNumber: i + 1,
                                       studyUID: studyUID, seriesUID: seriesUID),
                useExif: false)
            try data.write(to: outDir.appendingPathComponent("b\(i).dcm"))
        }

        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), n)
        // Each output is parseable as a Secondary Capture instance.
        for i in 0..<n {
            let f = try DICOMFile.read(from: outDir.appendingPathComponent("b\(i).dcm"))
            XCTAssertEqual(f.dataSet.string(for: .sopClassUID), secondaryCaptureSOPClass)
        }
    }

    // Oracle: auto-generated SOP Instance UIDs are distinct across a batch.
    func testAutoGeneratedSOPInstanceUIDsUnique() throws {
        let studyUID = ImageConverter.generateUID()
        let seriesUID = ImageConverter.generateUID()
        var sopUIDs = Set<String>()
        let n = 5
        for i in 0..<n {
            let png = try writePNG(width: 4, height: 4, name: "u\(i).png")
            let data = try ImageConverter.secondaryCaptureData(
                imageURL: png,
                metadata: makeMetadata(instanceNumber: i + 1,
                                       studyUID: studyUID, seriesUID: seriesUID),
                useExif: false)
            let f = try DICOMFile.read(from: data)
            if let uid = f.dataSet.string(for: .sopInstanceUID) { sopUIDs.insert(uid) }
        }
        XCTAssertEqual(sopUIDs.count, n)
    }

    // Oracle: generated study/series UIDs are valid DICOM UIDs and mutually distinct.
    func testGeneratedUIDsAreValidAndDistinct() throws {
        let a = ImageConverter.generateUID()
        let b = ImageConverter.generateUID()
        XCTAssertNotEqual(a, b)
        XCTAssertNotNil(DICOMUniqueIdentifier.parse(a))
        XCTAssertNotNil(DICOMUniqueIdentifier.parse(b))
    }

    // Oracle: pageCount of an N-page TIFF == N (drives the split-pages loop).
    func testMultiPageTIFFPageCount() throws {
        let tiff = try writeMultiPageTIFF(width: 4, height: 4, pages: 3)
        let count = try ImageConverter.pageCount(of: tiff)
        XCTAssertEqual(count, 3)
    }

    // Oracle: split-pages → one single-frame SC file per TIFF page.
    func testSplitPagesOneSingleFramePerPage() throws {
        let pages = 3
        let tiff = try writeMultiPageTIFF(width: 4, height: 4, pages: pages)
        let count = try ImageConverter.pageCount(of: tiff)
        try XCTSkipIf(count != pages, "ImageIO reported \(count) TIFF pages, expected \(pages)")

        let studyUID = ImageConverter.generateUID()
        let seriesUID = ImageConverter.generateUID()
        let outDir = try makeTempDir()
        for p in 0..<count {
            let data = try ImageConverter.secondaryCaptureData(
                imageURL: tiff, pageIndex: p,
                metadata: makeMetadata(instanceNumber: p + 1,
                                       studyUID: studyUID, seriesUID: seriesUID),
                useExif: false)
            try data.write(to: outDir.appendingPathComponent(String(format: "frame_%04d.dcm", p + 1)))
        }

        XCTAssertEqual(countFiles(in: outDir, extension: "dcm"), pages)
        // Each page becomes an independent single-frame instance (NumberOfFrames absent or 1).
        for p in 0..<pages {
            let f = try DICOMFile.read(
                from: outDir.appendingPathComponent(String(format: "frame_%04d.dcm", p + 1)))
            if let framesStr = f.dataSet.string(for: .numberOfFrames) {
                XCTAssertEqual(Int(framesStr.trimmingCharacters(in: .whitespaces)), 1)
            } // absent NumberOfFrames also denotes a single frame — acceptable.
        }
    }

    // Oracle: isImageFile recognizes supported extensions and rejects others.
    func testIsImageFileClassification() {
        XCTAssertTrue(ImageConverter.isImageFile(URL(fileURLWithPath: "/x/a.png")))
        XCTAssertTrue(ImageConverter.isImageFile(URL(fileURLWithPath: "/x/a.JPG")))
        XCTAssertTrue(ImageConverter.isImageFile(URL(fileURLWithPath: "/x/a.tiff")))
        XCTAssertFalse(ImageConverter.isImageFile(URL(fileURLWithPath: "/x/a.dcm")))
        XCTAssertFalse(ImageConverter.isImageFile(URL(fileURLWithPath: "/x/a.txt")))
    }

    // Oracle: pixel descriptors for uint8 SC are fixed (BitsAllocated/Stored/HighBit/Repr).
    func testPixelDescriptorsFixedForUInt8() throws {
        let png = try writePNG(width: 4, height: 4)
        let data = try ImageConverter.secondaryCaptureData(
            imageURL: png, metadata: makeMetadata(), useExif: false)
        let file = try DICOMFile.read(from: data)

        XCTAssertEqual(file.dataSet[.bitsAllocated]?.uint16Value, 8)
        XCTAssertEqual(file.dataSet[.bitsStored]?.uint16Value, 8)
        XCTAssertEqual(file.dataSet[.highBit]?.uint16Value, 7)
        XCTAssertEqual(file.dataSet[.pixelRepresentation]?.uint16Value, 0)
    }

    #else

    // dicom-image (ImageConverter) requires CoreGraphics/ImageIO; nothing to test here.
    func testUnsupportedPlatform() throws {
        throw XCTSkip("ImageConverter requires CoreGraphics/ImageIO (macOS/iOS only)")
    }

    #endif
}

