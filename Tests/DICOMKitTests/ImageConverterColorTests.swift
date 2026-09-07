//
// ImageConverterColorTests.swift
// DICOMKit
//
// Regression: colour (RGB/RGBA) sources used to fail with
// "Failed to create graphics context" because Core Graphics has no packed
// 24-bit RGB bitmap layout. Colour must convert; alpha composites onto white.
//

import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import DICOMKit
import DICOMCore

final class ImageConverterColorTests: XCTestCase {

    private func writePNG(rgba: [UInt8], width: Int, height: Int) throws -> URL {
        let data = Data(rgba)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageConverterColorTests-\(UUID().uuidString).png")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    private var metadata: ImageConverter.Metadata {
        ImageConverter.Metadata(
            patientName: "DOE^John", patientID: "12345",
            studyUID: ImageConverter.generateUID(), seriesUID: ImageConverter.generateUID(),
            instanceNumber: 1
        )
    }

    func test_rgbaPNG_convertsToRGBSecondaryCapture_compositedOnWhite() throws {
        // Row 0: opaque red, opaque green. Row 1: opaque blue, fully transparent.
        let rgba: [UInt8] = [
            255, 0, 0, 255,   0, 255, 0, 255,
            0, 0, 255, 255,   0, 0, 0, 0,
        ]
        let url = try writePNG(rgba: rgba, width: 2, height: 2)
        defer { try? FileManager.default.removeItem(at: url) }

        let bytes = try ImageConverter.secondaryCaptureData(imageURL: url, metadata: metadata, useExif: false)
        let ds = try DICOMFile.read(from: bytes).dataSet

        XCTAssertEqual(ds.uint16(for: .samplesPerPixel), 3)
        XCTAssertEqual(ds.string(for: .photometricInterpretation), "RGB")
        XCTAssertEqual(ds.uint16(for: .rows), 2)
        XCTAssertEqual(ds.uint16(for: .columns), 2)

        let pixels = try XCTUnwrap(ds[.pixelData]?.valueData)
        XCTAssertEqual(pixels.count, 2 * 2 * 3, "packed 24-bit RGB, no padding byte")
        XCTAssertEqual([UInt8](pixels), [
            255, 0, 0,   0, 255, 0,
            0, 0, 255,   255, 255, 255,   // transparent → white
        ])
    }

    func test_grayscalePNG_stillConvertsAsMonochrome2() throws {
        let gray: [UInt8] = [0, 128, 255, 64]
        let provider = CGDataProvider(data: Data(gray) as CFData)!
        let image = CGImage(
            width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 2,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageConverterColorTests-gray-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))

        let bytes = try ImageConverter.secondaryCaptureData(imageURL: url, metadata: metadata, useExif: false)
        let ds = try DICOMFile.read(from: bytes).dataSet
        XCTAssertEqual(ds.uint16(for: .samplesPerPixel), 1)
        XCTAssertEqual(ds.string(for: .photometricInterpretation), "MONOCHROME2")
        XCTAssertEqual([UInt8](try XCTUnwrap(ds[.pixelData]?.valueData)), gray)
    }
}
