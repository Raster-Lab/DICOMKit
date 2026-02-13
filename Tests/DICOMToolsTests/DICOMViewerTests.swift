import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

/// Tests for dicom-viewer CLI tool functionality
/// These tests validate terminal rendering, image scaling, ASCII art generation,
/// ANSI color output, terminal protocol encoding, and information overlay.
///
/// The rendering logic is duplicated here for unit testing since CLI executable
/// targets cannot be imported as test dependencies.
final class DICOMViewerTests: XCTestCase {

    // MARK: - Test Helpers

    /// Creates a minimal DICOM file with pixel data for viewer testing
    private func createTestDICOMFile(
        rows: UInt16 = 8,
        columns: UInt16 = 8,
        pixelValues: [UInt16]? = nil,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        patientName: String? = nil,
        modality: String? = nil,
        studyDescription: String? = nil
    ) throws -> Data {
        var data = Data()

        // 128-byte preamble
        data.append(Data(count: 128))

        // DICM prefix
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])

        // File Meta Information Group Length (0002,0000) - UL
        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C]) // VR = UL
        data.append(contentsOf: [0x04, 0x00]) // Length = 4
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00])

        // Transfer Syntax UID (0002,0010) - UI
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49]) // VR = UI
        let transferSyntax = "1.2.840.10008.1.2.1"
        let tsLength = UInt16(transferSyntax.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(transferSyntax.data(using: .utf8)!)

        // SOP Class UID (0008,0016) - UI
        data.append(contentsOf: [0x08, 0x00, 0x16, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopClass = "1.2.840.10008.5.1.4.1.1.2" // CT Image Storage
        let scLength = UInt16(sopClass.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: scLength.littleEndian) { Data($0) })
        data.append(sopClass.data(using: .utf8)!)

        // SOP Instance UID (0008,0018) - UI
        data.append(contentsOf: [0x08, 0x00, 0x18, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let sopInstance = "1.2.3.4.5.6.7.8.9.10"
        let siPadded = sopInstance.utf8.count % 2 != 0 ? sopInstance + "\0" : sopInstance
        let siLength = UInt16(siPadded.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: siLength.littleEndian) { Data($0) })
        data.append(siPadded.data(using: .utf8)!)

        // Modality (0008,0060) - CS
        if let mod = modality {
            data.append(contentsOf: [0x08, 0x00, 0x60, 0x00])
            data.append(contentsOf: [0x43, 0x53]) // VR = CS
            let modPadded = mod.utf8.count % 2 != 0 ? mod + " " : mod
            let modLen = UInt16(modPadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: modLen.littleEndian) { Data($0) })
            data.append(modPadded.data(using: .utf8)!)
        }

        // Study Description (0008,1030) - LO
        if let desc = studyDescription {
            data.append(contentsOf: [0x08, 0x00, 0x30, 0x10])
            data.append(contentsOf: [0x4C, 0x4F]) // VR = LO
            let descPadded = desc.utf8.count % 2 != 0 ? desc + " " : desc
            let descLen = UInt16(descPadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: descLen.littleEndian) { Data($0) })
            data.append(descPadded.data(using: .utf8)!)
        }

        // Patient Name (0010,0010) - PN
        if let name = patientName {
            data.append(contentsOf: [0x10, 0x00, 0x10, 0x00])
            data.append(contentsOf: [0x50, 0x4E]) // VR = PN
            let namePadded = name.utf8.count % 2 != 0 ? name + " " : name
            let nameLen = UInt16(namePadded.utf8.count)
            data.append(contentsOf: withUnsafeBytes(of: nameLen.littleEndian) { Data($0) })
            data.append(namePadded.data(using: .utf8)!)
        }

        // Rows (0028,0010) - US
        data.append(contentsOf: [0x28, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: rows.littleEndian) { Data($0) })

        // Columns (0028,0011) - US
        data.append(contentsOf: [0x28, 0x00, 0x11, 0x00])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: columns.littleEndian) { Data($0) })

        // Bits Allocated (0028,0100) - US
        let bitsAllocated: UInt16 = 16
        data.append(contentsOf: [0x28, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: bitsAllocated.littleEndian) { Data($0) })

        // Bits Stored (0028,0101) - US
        data.append(contentsOf: [0x28, 0x00, 0x01, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: bitsAllocated.littleEndian) { Data($0) })

        // High Bit (0028,0102) - US
        let highBit = bitsAllocated - 1
        data.append(contentsOf: [0x28, 0x00, 0x02, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: highBit.littleEndian) { Data($0) })

        // Pixel Representation (0028,0103) - US
        let pixelRep: UInt16 = 0
        data.append(contentsOf: [0x28, 0x00, 0x03, 0x01])
        data.append(contentsOf: [0x55, 0x53])
        data.append(contentsOf: [0x02, 0x00])
        data.append(contentsOf: withUnsafeBytes(of: pixelRep.littleEndian) { Data($0) })

        // Pixel Spacing (0028,0030) - DS
        let pixelSpacingStr = "1.0\\1.0"
        let psData = pixelSpacingStr.data(using: .utf8)!
        var psLen = UInt16(psData.count)
        if psLen % 2 != 0 { psLen += 1 }
        data.append(contentsOf: [0x28, 0x00, 0x30, 0x00])
        data.append(contentsOf: [0x44, 0x53]) // VR = DS
        data.append(contentsOf: withUnsafeBytes(of: psLen.littleEndian) { Data($0) })
        data.append(psData)
        if psData.count % 2 != 0 { data.append(0x20) }

        // Window Center (0028,1050) - DS
        if let wc = windowCenter {
            let wcStr = "\(wc)"
            let wcData = wcStr.data(using: .utf8)!
            var wcLen = UInt16(wcData.count)
            if wcLen % 2 != 0 { wcLen += 1 }
            data.append(contentsOf: [0x28, 0x00, 0x50, 0x10])
            data.append(contentsOf: [0x44, 0x53]) // VR = DS
            data.append(contentsOf: withUnsafeBytes(of: wcLen.littleEndian) { Data($0) })
            data.append(wcData)
            if wcData.count % 2 != 0 { data.append(0x20) }
        }

        // Window Width (0028,1051) - DS
        if let ww = windowWidth {
            let wwStr = "\(ww)"
            let wwData = wwStr.data(using: .utf8)!
            var wwLen = UInt16(wwData.count)
            if wwLen % 2 != 0 { wwLen += 1 }
            data.append(contentsOf: [0x28, 0x00, 0x51, 0x10])
            data.append(contentsOf: [0x44, 0x53]) // VR = DS
            data.append(contentsOf: withUnsafeBytes(of: wwLen.littleEndian) { Data($0) })
            data.append(wwData)
            if wwData.count % 2 != 0 { data.append(0x20) }
        }

        // Pixel Data (7FE0,0010) - OW
        let totalPixels = Int(rows) * Int(columns)
        let values: [UInt16]
        if let provided = pixelValues {
            values = provided
        } else {
            values = (0..<totalPixels).map { i in
                UInt16(i * 65535 / max(totalPixels - 1, 1))
            }
        }

        let bytesPerPixel = Int(bitsAllocated) / 8
        let pixelDataLength = UInt32(totalPixels * bytesPerPixel)
        data.append(contentsOf: [0xE0, 0x7F, 0x10, 0x00])
        data.append(contentsOf: [0x4F, 0x57]) // VR = OW
        data.append(contentsOf: [0x00, 0x00]) // Reserved
        data.append(contentsOf: withUnsafeBytes(of: pixelDataLength.littleEndian) { Data($0) })

        for value in values {
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }

        return data
    }

    // MARK: - Duplicated Rendering Logic for Unit Testing

    // ASCII character ramps
    private let lowQualityRamp: [Character] = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
    private let highQualityRamp: [Character] = [
        " ", ".", "'", "`", "^", "\"", ",", ":", ";", "I",
        "l", "!", "i", ">", "<", "~", "+", "_", "-", "?",
        "]", "[", "}", "{", "1", ")", "(", "|", "\\", "/",
        "t", "f", "j", "r", "x", "n", "u", "v", "c", "z",
        "X", "Y", "U", "J", "C", "L", "Q", "0", "O", "Z",
        "m", "w", "q", "p", "d", "b", "k", "h", "a", "o",
        "*", "#", "M", "W", "&", "8", "%", "B", "@", "$"
    ]

    /// Render ASCII art from normalized pixel values
    private func renderASCII(pixels: [Double], width: Int, height: Int, quality: String = "high") -> String {
        let ramp = quality == "high" ? highQualityRamp : lowQualityRamp
        let rampCount = ramp.count
        var output = ""
        for y in 0..<height {
            for x in 0..<width {
                let value = pixels[y * width + x]
                let index = min(Int(value * Double(rampCount - 1)), rampCount - 1)
                output.append(ramp[index])
            }
            output.append("\n")
        }
        return output
    }

    /// Scale image using nearest-neighbor interpolation
    private func scaleImage(
        pixels: [Double], srcWidth: Int, srcHeight: Int,
        dstWidth: Int, dstHeight: Int
    ) -> [Double] {
        guard dstWidth > 0 && dstHeight > 0 else { return pixels }
        let scaleX = Double(srcWidth) / Double(dstWidth)
        let scaleY = Double(srcHeight) / Double(dstHeight)
        var result = [Double](repeating: 0, count: dstWidth * dstHeight)
        for y in 0..<dstHeight {
            for x in 0..<dstWidth {
                let srcX = min(Int(Double(x) * scaleX), srcWidth - 1)
                let srcY = min(Int(Double(y) * scaleY), srcHeight - 1)
                result[y * dstWidth + x] = pixels[srcY * srcWidth + srcX]
            }
        }
        return result
    }

    /// Calculate dimensions to fit image in terminal while maintaining aspect ratio
    private func fitToTerminal(
        imageWidth: Int, imageHeight: Int,
        terminalWidth: Int, terminalHeight: Int,
        customWidth: Int? = nil, customHeight: Int? = nil
    ) -> (width: Int, height: Int) {
        let targetW = customWidth ?? terminalWidth
        let targetH = customHeight ?? (terminalHeight - 2)
        let aspectRatio = Double(imageWidth) / Double(imageHeight)
        let charAspect = 2.0
        var fitWidth = targetW
        var fitHeight = Int(Double(fitWidth) / (aspectRatio * charAspect))
        if fitHeight > targetH {
            fitHeight = targetH
            fitWidth = Int(Double(fitHeight) * aspectRatio * charAspect)
        }
        return (width: max(fitWidth, 1), height: max(fitHeight, 1))
    }

    /// Generate ANSI true color escape sequence for a pixel pair
    private func ansiTruecolorBlock(topValue: Double, bottomValue: Double) -> String {
        let topGray = Int(topValue * 255.0)
        let bottomGray = Int(bottomValue * 255.0)
        return "\u{1B}[38;2;\(topGray);\(topGray);\(topGray)m" +
               "\u{1B}[48;2;\(bottomGray);\(bottomGray);\(bottomGray)m" +
               "▀"
    }

    /// Generate ANSI 256-color escape sequence
    private func ansi256Block(topValue: Double, bottomValue: Double) -> String {
        let topIndex = 232 + Int(topValue * 23.0)
        let bottomIndex = 232 + Int(bottomValue * 23.0)
        return "\u{1B}[38;5;\(topIndex)m\u{1B}[48;5;\(bottomIndex)m▀"
    }

    /// Create PGM data from normalized pixels
    private func createPGMData(pixels: [Double], width: Int, height: Int) -> Data {
        let pgm = "P5\n\(width) \(height)\n255\n"
        var data = pgm.data(using: .ascii) ?? Data()
        for pixel in pixels {
            data.append(UInt8(max(0, min(255, Int(pixel * 255.0)))))
        }
        return data
    }

    /// Apply window/level normalization to pixel values
    private func normalizePixels(
        values: [Int], slope: Double, intercept: Double,
        windowCenter: Double, windowWidth: Double, invert: Bool = false
    ) -> [Double] {
        let minValue = windowCenter - windowWidth / 2.0
        let maxValue = windowCenter + windowWidth / 2.0
        return values.map { val in
            let rescaled = slope * Double(val) + intercept
            var normalized = (rescaled - minValue) / (maxValue - minValue)
            normalized = max(0.0, min(1.0, normalized))
            if invert { normalized = 1.0 - normalized }
            return normalized
        }
    }

    // MARK: - Image Scaling Tests

    func testFitToTerminalLandscapeImage() {
        let (w, h) = fitToTerminal(
            imageWidth: 200, imageHeight: 100,
            terminalWidth: 80, terminalHeight: 24
        )
        XCTAssertGreaterThan(w, 0)
        XCTAssertGreaterThan(h, 0)
        XCTAssertLessThanOrEqual(w, 80)
        XCTAssertLessThanOrEqual(h, 22)
    }

    func testFitToTerminalPortraitImage() {
        let (w, h) = fitToTerminal(
            imageWidth: 100, imageHeight: 200,
            terminalWidth: 80, terminalHeight: 24
        )
        XCTAssertGreaterThan(w, 0)
        XCTAssertGreaterThan(h, 0)
        XCTAssertLessThanOrEqual(w, 80)
        XCTAssertLessThanOrEqual(h, 22)
    }

    func testFitToTerminalSquareImage() {
        let (w, h) = fitToTerminal(
            imageWidth: 512, imageHeight: 512,
            terminalWidth: 80, terminalHeight: 24
        )
        XCTAssertGreaterThan(w, 0)
        XCTAssertGreaterThan(h, 0)
        XCTAssertLessThanOrEqual(w, 80)
        XCTAssertLessThanOrEqual(h, 22)
    }

    func testFitToTerminalCustomDimensions() {
        let (w, h) = fitToTerminal(
            imageWidth: 512, imageHeight: 512,
            terminalWidth: 80, terminalHeight: 24,
            customWidth: 40, customHeight: 20
        )
        XCTAssertLessThanOrEqual(w, 40)
        XCTAssertLessThanOrEqual(h, 20)
    }

    func testScaleImageDownscale() {
        let original: [Double] = [
            0.0, 0.25, 0.5, 0.75,
            0.1, 0.35, 0.6, 0.85,
            0.2, 0.45, 0.7, 0.95,
            0.3, 0.55, 0.8, 1.0
        ]
        let scaled = scaleImage(pixels: original, srcWidth: 4, srcHeight: 4, dstWidth: 2, dstHeight: 2)
        XCTAssertEqual(scaled.count, 4)
        // Top-left pixel should match source (0,0)
        XCTAssertEqual(scaled[0], 0.0, accuracy: 0.001)
    }

    func testScaleImageUpscale() {
        let original: [Double] = [0.0, 1.0, 0.5, 0.75]
        let scaled = scaleImage(pixels: original, srcWidth: 2, srcHeight: 2, dstWidth: 4, dstHeight: 4)
        XCTAssertEqual(scaled.count, 16)
    }

    func testScaleImageIdentity() {
        let original: [Double] = [0.0, 0.5, 1.0, 0.75]
        let scaled = scaleImage(pixels: original, srcWidth: 2, srcHeight: 2, dstWidth: 2, dstHeight: 2)
        XCTAssertEqual(scaled.count, 4)
        for i in 0..<4 {
            XCTAssertEqual(scaled[i], original[i], accuracy: 0.001)
        }
    }

    // MARK: - ASCII Art Rendering Tests

    func testASCIIRenderLowQuality() {
        let pixels: [Double] = [0.0, 0.5, 1.0,
                                0.25, 0.75, 0.0]
        let output = renderASCII(pixels: pixels, width: 3, height: 2, quality: "low")
        let lines = output.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].count, 3)
    }

    func testASCIIRenderHighQuality() {
        let pixels: [Double] = [0.0, 0.5, 1.0,
                                0.25, 0.75, 0.0]
        let output = renderASCII(pixels: pixels, width: 3, height: 2, quality: "high")
        let lines = output.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
    }

    func testASCIIBlackPixel() {
        let output = renderASCII(pixels: [0.0], width: 1, height: 1, quality: "low")
        XCTAssertTrue(output.hasPrefix(" "), "Black pixel should be rendered as space")
    }

    func testASCIIWhitePixelLowQuality() {
        let output = renderASCII(pixels: [1.0], width: 1, height: 1, quality: "low")
        XCTAssertTrue(output.contains("@"), "White pixel should be '@' in low quality")
    }

    func testASCIIWhitePixelHighQuality() {
        let output = renderASCII(pixels: [1.0], width: 1, height: 1, quality: "high")
        XCTAssertTrue(output.contains("$"), "White pixel should be '$' in high quality")
    }

    func testASCIIRampOrder() {
        XCTAssertEqual(lowQualityRamp.first, " ")
        XCTAssertEqual(lowQualityRamp.last, "@")
        XCTAssertEqual(lowQualityRamp.count, 10)

        XCTAssertEqual(highQualityRamp.first, " ")
        XCTAssertEqual(highQualityRamp.last, "$")
        XCTAssertEqual(highQualityRamp.count, 70)
    }

    // MARK: - ANSI Color Rendering Tests

    func testANSITruecolorBlock() {
        let block = ansiTruecolorBlock(topValue: 0.0, bottomValue: 1.0)
        XCTAssertTrue(block.contains("\u{1B}[38;2;0;0;0m"))
        XCTAssertTrue(block.contains("\u{1B}[48;2;255;255;255m"))
        XCTAssertTrue(block.contains("▀"))
    }

    func testANSI256Block() {
        let block = ansi256Block(topValue: 0.0, bottomValue: 1.0)
        XCTAssertTrue(block.contains("\u{1B}[38;5;232m"))
        XCTAssertTrue(block.contains("\u{1B}[48;5;255m"))
    }

    func testANSIGrayscaleRange() {
        // 256-color grayscale runs from 232 (dark) to 255 (bright)
        let darkIndex = 232 + Int(0.0 * 23.0)
        XCTAssertEqual(darkIndex, 232)

        let brightIndex = 232 + Int(1.0 * 23.0)
        XCTAssertEqual(brightIndex, 255)
    }

    // MARK: - iTerm2 Protocol Tests

    func testITerm2ProtocolFormat() {
        let pgmData = createPGMData(pixels: [0.0, 0.5, 1.0, 0.75], width: 2, height: 2)
        let base64 = pgmData.base64EncodedString()
        let output = "\u{1B}]1337;File=inline=1;preserveAspectRatio=1:\(base64)\u{07}"

        XCTAssertTrue(output.hasPrefix("\u{1B}]1337;File="))
        XCTAssertTrue(output.contains("inline=1"))
        XCTAssertTrue(output.hasSuffix("\u{07}"))
    }

    func testITerm2WithCustomDimensions() {
        let params = "inline=1;width=40;height=20;preserveAspectRatio=1"
        let output = "\u{1B}]1337;File=\(params):AAAA\u{07}"
        XCTAssertTrue(output.contains("width=40"))
        XCTAssertTrue(output.contains("height=20"))
    }

    // MARK: - Kitty Graphics Protocol Tests

    func testKittyProtocolFormat() {
        var rawData = Data(capacity: 4)
        for pixel in [0.0, 0.5, 1.0, 0.75] {
            rawData.append(UInt8(max(0, min(255, Int(pixel * 255.0)))))
        }
        let base64 = rawData.base64EncodedString()
        let output = "\u{1B}_Gf=8,s=2,v=2,a=T,m=0;\(base64)\u{1B}\\"

        XCTAssertTrue(output.hasPrefix("\u{1B}_G"))
        XCTAssertTrue(output.contains("f=8"))
        XCTAssertTrue(output.contains("s=2"))
        XCTAssertTrue(output.contains("v=2"))
        XCTAssertTrue(output.contains("a=T"))
        XCTAssertTrue(output.hasSuffix("\u{1B}\\"))
    }

    // MARK: - Sixel Graphics Protocol Tests

    func testSixelProtocolFormat() {
        // Build a minimal sixel
        var output = "\u{1B}Pq"
        let paletteSize = 64
        for i in 0..<paletteSize {
            let level = i * 100 / (paletteSize - 1)
            output += "#\(i);2;\(level);\(level);\(level)"
        }
        output += "\u{1B}\\"

        XCTAssertTrue(output.hasPrefix("\u{1B}Pq"))
        XCTAssertTrue(output.hasSuffix("\u{1B}\\"))
        XCTAssertTrue(output.contains("#0;2;0;0;0"))
    }

    // MARK: - PGM Data Creation Tests

    func testPGMDataFormat() {
        let pgmData = createPGMData(pixels: [0.0, 0.5, 1.0, 0.75], width: 2, height: 2)
        let headerString = String(data: pgmData.prefix(20), encoding: .ascii) ?? ""
        XCTAssertTrue(headerString.hasPrefix("P5\n"))
        XCTAssertTrue(headerString.contains("2 2"))
        XCTAssertTrue(headerString.contains("255"))
        // Header + 4 pixel bytes
        let headerEnd = headerString.range(of: "255\n")
        XCTAssertNotNil(headerEnd)
    }

    func testPGMDataPixelValues() {
        let pixels: [Double] = [0.0, 1.0]
        let pgmData = createPGMData(pixels: pixels, width: 2, height: 1)

        // The last two bytes should be the pixel values
        let lastTwo = Array(pgmData.suffix(2))
        XCTAssertEqual(lastTwo[0], 0)   // 0.0 -> 0
        XCTAssertEqual(lastTwo[1], 255) // 1.0 -> 255
    }

    // MARK: - Pixel Normalization Tests

    func testNormalizePixelsBasic() {
        let values = [0, 128, 255]
        let normalized = normalizePixels(
            values: values, slope: 1.0, intercept: 0.0,
            windowCenter: 128.0, windowWidth: 256.0
        )
        XCTAssertEqual(normalized[0], 0.0, accuracy: 0.01)
        XCTAssertEqual(normalized[1], 0.5, accuracy: 0.01)
        XCTAssertEqual(normalized[2], 1.0, accuracy: 0.01)
    }

    func testNormalizePixelsWithRescale() {
        let values = [1024]
        let normalized = normalizePixels(
            values: values, slope: 1.0, intercept: -1024.0,
            windowCenter: 0.0, windowWidth: 2048.0
        )
        // Rescaled = 1024 - 1024 = 0 HU
        // Window: center=0, width=2048, min=-1024, max=1024
        // Normalized = (0 - (-1024)) / 2048 = 0.5
        XCTAssertEqual(normalized[0], 0.5, accuracy: 0.01)
    }

    func testNormalizePixelsWithInvert() {
        let values = [0, 255]
        let normal = normalizePixels(
            values: values, slope: 1.0, intercept: 0.0,
            windowCenter: 128.0, windowWidth: 256.0
        )
        let inverted = normalizePixels(
            values: values, slope: 1.0, intercept: 0.0,
            windowCenter: 128.0, windowWidth: 256.0,
            invert: true
        )
        // Normal + inverted should equal 1.0
        for i in 0..<values.count {
            XCTAssertEqual(normal[i] + inverted[i], 1.0, accuracy: 0.001)
        }
    }

    func testNormalizePixelsClamping() {
        // Values outside the window should be clamped to 0 and 1
        let values = [0, 1000]
        let normalized = normalizePixels(
            values: values, slope: 1.0, intercept: 0.0,
            windowCenter: 500.0, windowWidth: 100.0
        )
        // 0 is well below window minimum (450), should be clamped to 0
        XCTAssertEqual(normalized[0], 0.0, accuracy: 0.001)
        // 1000 is well above window maximum (550), should be clamped to 1
        XCTAssertEqual(normalized[1], 1.0, accuracy: 0.001)
    }

    // MARK: - DICOM File Pixel Data Tests

    func testDICOMFilePixelDataPresence() throws {
        let testData = try createTestDICOMFile()
        let dicomFile = try DICOMFile.read(from: testData)
        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNotNil(pixelData)
    }

    func testDICOMFileImageDimensions() throws {
        let testData = try createTestDICOMFile(rows: 16, columns: 32)
        let dicomFile = try DICOMFile.read(from: testData)
        let rows = dicomFile.dataSet.uint16(for: .rows)
        let cols = dicomFile.dataSet.uint16(for: .columns)
        XCTAssertEqual(rows, 16)
        XCTAssertEqual(cols, 32)
    }

    func testDICOMFilePixelValues() throws {
        let values: [UInt16] = [100, 200, 300, 400]
        let testData = try createTestDICOMFile(rows: 2, columns: 2, pixelValues: values)
        let dicomFile = try DICOMFile.read(from: testData)
        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNotNil(pixelData)
        if let pd = pixelData {
            XCTAssertEqual(pd.data.count, 8) // 4 pixels * 2 bytes
        }
    }

    func testDICOMFileWindowSettings() throws {
        let testData = try createTestDICOMFile(
            windowCenter: 40.0,
            windowWidth: 400.0
        )
        let dicomFile = try DICOMFile.read(from: testData)
        let ws = dicomFile.dataSet.windowSettings()
        XCTAssertNotNil(ws)
        if let ws = ws {
            XCTAssertEqual(ws.center, 40.0, accuracy: 0.1)
            XCTAssertEqual(ws.width, 400.0, accuracy: 0.1)
        }
    }

    func testDICOMFilePatientInfo() throws {
        let testData = try createTestDICOMFile(
            patientName: "SMITH^JOHN",
            modality: "CT",
            studyDescription: "CHEST PA"
        )
        let dicomFile = try DICOMFile.read(from: testData)
        let ds = dicomFile.dataSet

        let name = ds.string(for: .patientName)
        XCTAssertNotNil(name)
        XCTAssertTrue(name?.contains("SMITH") ?? false)

        let mod = ds.string(for: .modality)
        XCTAssertNotNil(mod)
        XCTAssertTrue(mod?.contains("CT") ?? false)
    }

    func testDICOMFileNoPixelData() throws {
        var data = Data()
        data.append(Data(count: 128))
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D])

        data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
        data.append(contentsOf: [0x55, 0x4C])
        data.append(contentsOf: [0x04, 0x00])
        data.append(contentsOf: [0x54, 0x00, 0x00, 0x00])

        let transferSyntax = "1.2.840.10008.1.2.1"
        data.append(contentsOf: [0x02, 0x00, 0x10, 0x00])
        data.append(contentsOf: [0x55, 0x49])
        let tsLength = UInt16(transferSyntax.utf8.count)
        data.append(contentsOf: withUnsafeBytes(of: tsLength.littleEndian) { Data($0) })
        data.append(transferSyntax.data(using: .utf8)!)

        let dicomFile = try DICOMFile.read(from: data)
        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNil(pixelData)
    }

    // MARK: - Window/Level Auto-Detection Tests

    func testAutoWindowFromPixelRange() throws {
        // With uniform known values, auto-window should work
        let values: [UInt16] = [0, 100, 200, 300]
        let testData = try createTestDICOMFile(rows: 2, columns: 2, pixelValues: values)
        let dicomFile = try DICOMFile.read(from: testData)
        let pixelData = dicomFile.dataSet.pixelData()
        XCTAssertNotNil(pixelData)

        if let pd = pixelData, let range = pd.pixelRange(forFrame: 0) {
            XCTAssertEqual(range.min, 0)
            XCTAssertEqual(range.max, 300)
            let autoCenter = Double(range.min + range.max) / 2.0
            let autoWidth = max(Double(range.max - range.min), 1.0)
            XCTAssertEqual(autoCenter, 150.0, accuracy: 0.1)
            XCTAssertEqual(autoWidth, 300.0, accuracy: 0.1)
        }
    }

    // MARK: - Edge Case Tests

    func testSinglePixelImage() {
        let output = renderASCII(pixels: [0.5], width: 1, height: 1, quality: "high")
        XCTAssertEqual(output.split(separator: "\n").count, 1)
    }

    func testAllBlackImage() {
        let pixels = [Double](repeating: 0.0, count: 9)
        let output = renderASCII(pixels: pixels, width: 3, height: 3, quality: "low")
        // All pixels should be spaces
        for char in output.replacingOccurrences(of: "\n", with: "") {
            XCTAssertEqual(char, " ")
        }
    }

    func testAllWhiteImage() {
        let pixels = [Double](repeating: 1.0, count: 9)
        let output = renderASCII(pixels: pixels, width: 3, height: 3, quality: "low")
        for char in output.replacingOccurrences(of: "\n", with: "") {
            XCTAssertEqual(char, "@")
        }
    }
}
