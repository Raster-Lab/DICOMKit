// EnterpriseRenderHelpers.swift
// DICOMStudio
//
// Rendering helpers for the enterprise 3D viewer:
// thick-slab MIP/MinIP/AvgIP projection, buffer inversion,
// and color-LUT CGImage creation.

#if canImport(CoreGraphics)
import Foundation
import CoreGraphics
import DICOMKit

public enum EnterpriseRenderHelpers: Sendable {

    // MARK: - Thick Slab Projection

    /// Extracts a thick slab centred on `centerIndex` and projects it using MIP, MinIP, or AvgIP.
    ///
    /// Each slice in the slab is individually windowed to 8-bit, then the per-pixel max/min/avg
    /// is computed across all slices.  The result is a ready-to-display 8-bit grayscale buffer.
    public static func thickSlabBuffer(
        volume: DICOMVolume,
        plane: MPRPlane,
        centerIndex: Int,
        slabThicknessMM: Double,
        projectionMode: ProjectionMode,
        windowCenter: Double,
        windowWidth: Double,
        dimensions: VolumeDimensionsModel
    ) -> Data? {
        let (startIdx, endIdx) = MPRHelpers.slabRange(
            centerSlice: centerIndex,
            thicknessMM: slabThicknessMM,
            plane: plane,
            dimensions: dimensions
        )

        guard let firstSlice = JP3DMPRSliceExtractor.extractSlice(from: volume, plane: plane, at: startIdx) else {
            return nil
        }
        let pixelCount = firstSlice.pixelCount
        guard pixelCount > 0 else { return nil }

        var projMax = [UInt8](repeating: 0,   count: pixelCount)
        var projMin = [UInt8](repeating: 255, count: pixelCount)
        var projSum = [Int32](repeating: 0,   count: pixelCount)
        var sliceCount = 0

        for idx in startIdx...endIdx {
            guard let raw = JP3DMPRSliceExtractor.extractSlice(from: volume, plane: plane, at: idx) else { continue }
            let windowed = JP3DMPRSliceExtractor.applyWindowLevel(
                to: raw, windowCenter: windowCenter, windowWidth: windowWidth)
            windowed.withUnsafeBytes { ptr in
                let u8 = ptr.bindMemory(to: UInt8.self)
                let n  = min(pixelCount, u8.count)
                switch projectionMode {
                case .mip:
                    for i in 0..<n { if u8[i] > projMax[i] { projMax[i] = u8[i] } }
                case .minIP:
                    for i in 0..<n { if u8[i] < projMin[i] { projMin[i] = u8[i] } }
                case .avgIP:
                    for i in 0..<n { projSum[i] += Int32(u8[i]) }
                }
            }
            sliceCount += 1
        }

        guard sliceCount > 0 else { return nil }

        switch projectionMode {
        case .mip:   return Data(projMax)
        case .minIP: return Data(projMin)
        case .avgIP:
            let avg = projSum.map { UInt8(clamping: $0 / Int32(sliceCount)) }
            return Data(avg)
        }
    }

    // MARK: - Buffer Inversion

    /// Returns a copy of an 8-bit grayscale buffer with all values inverted (255 − v).
    public static func invertBuffer(_ buffer: Data) -> Data {
        var result = buffer
        result.withUnsafeMutableBytes { ptr in
            let p = ptr.bindMemory(to: UInt8.self)
            for i in 0..<p.count { p[i] = 255 &- p[i] }
        }
        return result
    }

    // MARK: - Color LUT CGImage

    /// Creates a 24-bit RGB `CGImage` from an 8-bit grayscale buffer by applying a colour LUT.
    ///
    /// - Parameters:
    ///   - buffer: 8-bit grayscale data (one byte per pixel, row-major).
    ///   - width:  Image width in pixels.
    ///   - height: Image height in pixels.
    ///   - lut:    256-entry colour lookup table.
    /// - Returns: A `CGImage`, or `nil` if the inputs are invalid.
    public static func cgImageWithLUT(
        buffer: Data,
        width: Int,
        height: Int,
        lut: [ColorEntry]
    ) -> CGImage? {
        guard width > 0, height > 0, !lut.isEmpty else { return nil }
        let pixelCount = width * height
        guard buffer.count >= pixelCount else { return nil }

        var rgb = Data(count: pixelCount * 3)
        buffer.withUnsafeBytes { src in
            let s = src.bindMemory(to: UInt8.self)
            rgb.withUnsafeMutableBytes { dst in
                let d = dst.bindMemory(to: UInt8.self)
                for i in 0..<pixelCount {
                    let entry = ColorLUTHelpers.applyLUT(grayValue: Double(s[i]) / 255.0, lut: lut)
                    d[i * 3    ] = entry.red
                    d[i * 3 + 1] = entry.green
                    d[i * 3 + 2] = entry.blue
                }
            }
        }

        // Bridge to CFData so CGDataProvider retains the bytes.
        let cfData = rgb as CFData
        guard let provider = CGDataProvider(data: cfData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

#endif // canImport(CoreGraphics)
