// J2KBenchImageRenderer.swift
// DICOMStudio
//
// DICOM Studio — renders decoded J2K Test Bench frames into displayable
// images: small memory-bounded gallery thumbnails and full-resolution
// lightbox images, plus amplified difference maps.
//
// 16-bit frames are tone-mapped through a percentile window (0.5 %–99.5 %)
// so a few outlier pixels — padding, metal, sensor hot-spots — can't flatten
// the contrast of the whole image.

import Foundation
import CoreGraphics
import DICOMCore

/// Decoded-image previews for one test cell.
///
/// `@unchecked Sendable` because `CGImage` is immutable and thread-safe once
/// created, so an instance crosses actor boundaries safely.
public struct J2KBenchCellImages: @unchecked Sendable {
    public let preview: CGImage?
    public let difference: CGImage?
    public init(preview: CGImage?, difference: CGImage?) {
        self.preview = preview
        self.difference = difference
    }
}

/// Turns raw decoded pixel buffers into `CGImage`s for the bench UI.
public enum J2KBenchImageRenderer {

    /// Gallery thumbnail size — small, one kept per cell for a whole run.
    public static let thumbnailMaxDimension = 384
    /// Lightbox size — generous, only one decoded on demand at a time.
    public static let fullMaxDimension = 4096

    /// A small gallery-thumbnail preview of a decoded or original frame.
    public static func preview(pixels: Data, descriptor: PixelDataDescriptor) -> CGImage? {
        baseImage(pixels: pixels, descriptor: descriptor)
            .map { downscaled($0, maxDimension: thumbnailMaxDimension) }
    }

    /// A full-resolution image for the click-to-enlarge lightbox.
    public static func fullImage(pixels: Data, descriptor: PixelDataDescriptor) -> CGImage? {
        baseImage(pixels: pixels, descriptor: descriptor)
            .map { downscaled($0, maxDimension: fullMaxDimension) }
    }

    /// A full-resolution amplified difference map of a decode vs the original.
    /// A bit-exact decode renders as solid black.
    public static func fullDifference(decoded: Data, original: Data,
                                      descriptor: PixelDataDescriptor) -> CGImage? {
        differenceImage(decoded: decoded, original: original, descriptor: descriptor)
            .map { downscaled($0, maxDimension: fullMaxDimension) }
    }

    // MARK: - Base image (8-bit direct / 16-bit percentile tone-mapped)

    private static func baseImage(pixels: Data, descriptor: PixelDataDescriptor) -> CGImage? {
        let width = descriptor.columns
        let height = descriptor.rows
        let spp = descriptor.samplesPerPixel
        guard width > 0, height > 0, spp == 1 || spp == 3 else { return nil }

        if descriptor.bitsAllocated <= 8 {
            let needed = width * height * spp
            guard pixels.count >= needed else { return nil }
            let buffer = pixels.count == needed ? pixels : pixels.prefix(needed)
            return rawImage(Data(buffer), width: width, height: height, spp: spp)
        }

        // 16-bit — tone-map through a percentile window for real contrast.
        let pixelCount = width * height * spp
        guard pixels.count >= pixelCount * 2 else { return nil }
        let base = pixels.startIndex
        var values = [UInt16](repeating: 0, count: pixelCount)
        var histogram = [Int](repeating: 0, count: 65536)
        for i in 0..<pixelCount {
            let v = UInt16(pixels[base + i * 2]) | (UInt16(pixels[base + i * 2 + 1]) << 8)
            values[i] = v
            histogram[Int(v)] += 1
        }
        let window = percentileWindow(histogram: histogram, total: pixelCount)
        let span = Double(window.hi - window.lo)
        var out = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let clamped = min(max(Int(values[i]), window.lo), window.hi)
            out[i] = UInt8(clamping: Int((Double(clamped - window.lo) / span) * 255))
        }
        return rawImage(Data(out), width: width, height: height, spp: spp)
    }

    /// The 0.5 % / 99.5 % cumulative-histogram bounds. `hi` is always > `lo`.
    private static func percentileWindow(histogram: [Int], total: Int) -> (lo: Int, hi: Int) {
        guard total > 0 else { return (0, 65535) }
        let loTarget = Int(Double(total) * 0.005)
        let hiTarget = Int(Double(total) * 0.995)
        var cumulative = 0
        var lo = 0
        for value in 0..<histogram.count {
            cumulative += histogram[value]
            if cumulative >= loTarget { lo = value; break }
        }
        cumulative = 0
        var hi = histogram.count - 1
        for value in 0..<histogram.count {
            cumulative += histogram[value]
            if cumulative >= hiTarget { hi = value; break }
        }
        return hi > lo ? (lo, hi) : (lo, lo + 1)
    }

    // MARK: - Difference

    private static func differenceImage(decoded: Data, original: Data,
                                        descriptor: PixelDataDescriptor) -> CGImage? {
        let width = descriptor.columns
        let height = descriptor.rows
        let spp = max(1, descriptor.samplesPerPixel)
        guard width > 0, height > 0 else { return nil }

        let expected = descriptor.bytesPerFrame
        let reference: Data = original.count > expected ? original.prefix(expected) : original
        guard decoded.count == reference.count, decoded.count >= expected else { return nil }

        let dBase = decoded.startIndex
        let oBase = reference.startIndex
        var gray = [UInt8](repeating: 0, count: width * height)

        if descriptor.bitsAllocated <= 8 {
            for pixel in 0..<(width * height) {
                var worst = 0
                for sample in 0..<spp {
                    let i = pixel * spp + sample
                    let delta = abs(Int(decoded[dBase + i]) - Int(reference[oBase + i]))
                    if delta > worst { worst = delta }
                }
                gray[pixel] = UInt8(min(255, worst * 8))
            }
        } else {
            let range = max(1, (1 << max(1, descriptor.bitsStored)) - 1)
            for pixel in 0..<(width * height) {
                var worst = 0
                for sample in 0..<spp {
                    let i = (pixel * spp + sample) * 2
                    let dv = Int(decoded[dBase + i]) | (Int(decoded[dBase + i + 1]) << 8)
                    let ov = Int(reference[oBase + i]) | (Int(reference[oBase + i + 1]) << 8)
                    let delta = abs(dv - ov)
                    if delta > worst { worst = delta }
                }
                gray[pixel] = UInt8(min(255, worst * 255 * 32 / range))
            }
        }
        return rawImage(Data(gray), width: width, height: height, spp: 1)
    }

    // MARK: - CGImage helpers

    private static func rawImage(_ data: Data, width: Int, height: Int, spp: Int) -> CGImage? {
        guard !data.isEmpty, let provider = CGDataProvider(data: data as CFData) else { return nil }
        let space = spp == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
        return CGImage(width: width, height: height,
                       bitsPerComponent: 8, bitsPerPixel: 8 * spp,
                       bytesPerRow: width * spp, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func downscaled(_ image: CGImage, maxDimension: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxDimension else { return image }
        let scale = Double(maxDimension) / Double(longest)
        let w = max(1, Int((Double(image.width) * scale).rounded()))
        let h = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return context.makeImage() ?? image
    }
}
