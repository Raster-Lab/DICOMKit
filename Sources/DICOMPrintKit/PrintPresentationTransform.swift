// PrintPresentationTransform.swift
// DICOMPrintKit
//
// DICOM Print — applying the viewer's arrangement to film pixels.
//
// Every operation here is exact: cropping selects pixels, rotation and flipping
// permute them, inversion negates P-values. Nothing resamples, so a zoomed print
// is full modality resolution over the region the user chose rather than an
// upscaled copy of what the monitor showed.

import Foundation
import DICOMNetwork

public enum PrintPresentationTransform {

    /// Applies a viewer presentation to already-prepared film pixels.
    ///
    /// - Parameters:
    ///   - image: Prepared, uncompressed image-box pixels (8- or 16-bit,
    ///     1 or 3 samples per pixel).
    ///   - presentation: The viewer arrangement to bake in.
    /// - Returns: The transformed image, or `image` unchanged when the
    ///   presentation is an identity or the pixel layout is not one this can
    ///   safely permute.
    public static func apply(
        _ presentation: ViewerPresentation,
        to image: PrintImageData
    ) -> PrintImageData {
        guard !presentation.isIdentity else { return image }

        let width = Int(image.columns)
        let height = Int(image.rows)
        let samples = Int(image.samplesPerPixel)
        let bytesPerSample = Int(image.bitsAllocated) / 8

        // Planar or sub-byte layouts would need a different addressing scheme;
        // the preparer never emits them, and silently mangling pixels would be
        // far worse than printing the untransformed frame.
        guard width > 0, height > 0,
              samples == 1 || samples == 3,
              bytesPerSample == 1 || bytesPerSample == 2,
              image.pixelData.count >= width * height * samples * bytesPerSample
        else { return image }

        let pixelStride = samples * bytesPerSample
        var pixels = [UInt8](image.pixelData.prefix(width * height * pixelStride))

        // 1. Crop to the region the viewport was showing.
        var currentWidth = width
        var currentHeight = height
        if let region = presentation.visibleRegion(imageWidth: width, imageHeight: height) {
            pixels = crop(pixels, width: currentWidth, region: region, pixelStride: pixelStride)
            currentWidth = region.width
            currentHeight = region.height
        }

        // 2. Rotate, then flip — the order the viewer composes them in.
        if presentation.quarterTurns != 0 {
            pixels = rotate(
                pixels, width: currentWidth, height: currentHeight,
                quarterTurns: presentation.quarterTurns, pixelStride: pixelStride)
            if presentation.quarterTurns % 2 == 1 {
                swap(&currentWidth, &currentHeight)
            }
        }
        if presentation.flipHorizontal {
            pixels = flipHorizontally(
                pixels, width: currentWidth, height: currentHeight, pixelStride: pixelStride)
        }
        if presentation.flipVertical {
            pixels = flipVertically(
                pixels, width: currentWidth, height: currentHeight, pixelStride: pixelStride)
        }

        // 3. Invert P-values.
        if presentation.invert {
            invert(&pixels, bitsStored: Int(image.bitsStored), bytesPerSample: bytesPerSample)
        }

        guard currentWidth <= Int(UInt16.max), currentHeight <= Int(UInt16.max) else {
            return image
        }

        return PrintImageData(
            pixelData: Data(pixels),
            rows: UInt16(currentHeight),
            columns: UInt16(currentWidth),
            bitsAllocated: image.bitsAllocated,
            bitsStored: image.bitsStored,
            highBit: image.highBit,
            samplesPerPixel: image.samplesPerPixel,
            pixelRepresentation: image.pixelRepresentation,
            photometricInterpretation: image.photometricInterpretation
        )
    }

    // MARK: - Pixel operations
    //
    // (Implementation below; see `apply(_:to:)` for the order they run in.)

    private static func crop(
        _ pixels: [UInt8], width: Int, region: PixelRegion, pixelStride: Int
    ) -> [UInt8] {
        let rowBytes = region.width * pixelStride
        var out = [UInt8](repeating: 0, count: rowBytes * region.height)
        let sourceRowBytes = width * pixelStride
        for row in 0..<region.height {
            let sourceStart = (region.y + row) * sourceRowBytes + region.x * pixelStride
            let destStart = row * rowBytes
            out[destStart..<(destStart + rowBytes)] =
                pixels[sourceStart..<(sourceStart + rowBytes)]
        }
        return out
    }

    private static func rotate(
        _ pixels: [UInt8], width: Int, height: Int, quarterTurns: Int, pixelStride: Int
    ) -> [UInt8] {
        let outWidth = quarterTurns % 2 == 1 ? height : width
        let outHeight = quarterTurns % 2 == 1 ? width : height
        var out = [UInt8](repeating: 0, count: width * height * pixelStride)

        for y in 0..<height {
            for x in 0..<width {
                let destX: Int
                let destY: Int
                switch quarterTurns {
                case 1:  destX = outWidth - 1 - y; destY = x
                case 2:  destX = width - 1 - x;    destY = height - 1 - y
                default: destX = y;                destY = outHeight - 1 - x
                }
                let source = (y * width + x) * pixelStride
                let dest = (destY * outWidth + destX) * pixelStride
                for byte in 0..<pixelStride {
                    out[dest + byte] = pixels[source + byte]
                }
            }
        }
        return out
    }

    private static func flipHorizontally(
        _ pixels: [UInt8], width: Int, height: Int, pixelStride: Int
    ) -> [UInt8] {
        var out = pixels
        for y in 0..<height {
            let rowStart = y * width * pixelStride
            for x in 0..<width {
                let source = rowStart + x * pixelStride
                let dest = rowStart + (width - 1 - x) * pixelStride
                for byte in 0..<pixelStride {
                    out[dest + byte] = pixels[source + byte]
                }
            }
        }
        return out
    }

    private static func flipVertically(
        _ pixels: [UInt8], width: Int, height: Int, pixelStride: Int
    ) -> [UInt8] {
        let rowBytes = width * pixelStride
        var out = [UInt8](repeating: 0, count: pixels.count)
        for y in 0..<height {
            let source = y * rowBytes
            let dest = (height - 1 - y) * rowBytes
            out[dest..<(dest + rowBytes)] = pixels[source..<(source + rowBytes)]
        }
        return out
    }

    /// Negates P-values against the stored-bit maximum.
    ///
    /// Prepared film pixels are always unsigned MONOCHROME2 or RGB, so the
    /// maximum is `2^bitsStored − 1` and inversion needs no rescale lookup.
    private static func invert(_ pixels: inout [UInt8], bitsStored: Int, bytesPerSample: Int) {
        if bytesPerSample == 1 {
            let maxValue = UInt8(clamping: (1 << max(1, min(8, bitsStored))) - 1)
            for index in pixels.indices {
                pixels[index] = maxValue &- min(pixels[index], maxValue)
            }
        } else {
            let maxValue = UInt16(clamping: (1 << max(1, min(16, bitsStored))) - 1)
            // Prepared 16-bit film pixels are little-endian, as sent on the wire.
            for index in stride(from: 0, to: pixels.count - 1, by: 2) {
                let value = UInt16(pixels[index]) | (UInt16(pixels[index + 1]) << 8)
                let inverted = maxValue &- min(value, maxValue)
                pixels[index] = UInt8(inverted & 0xFF)
                pixels[index + 1] = UInt8(inverted >> 8)
            }
        }
    }
}

// MARK: - Prepared image

public extension PreparedPrintImage {
    /// A copy with the viewer's arrangement baked into its pixels.
    func applying(
        _ presentation: ViewerPresentation,
        onProgress: PrintImagePreparer.ProgressHandler? = nil
    ) -> PreparedPrintImage {
        let transformed = PrintPresentationTransform.apply(presentation, to: descriptor)
        guard transformed != descriptor else { return self }
        onProgress?(
            "Applied viewer presentation: "
            + "\(descriptor.columns)x\(descriptor.rows) → "
            + "\(transformed.columns)x\(transformed.rows)"
            + (presentation.quarterTurns != 0 ? ", rotated \(presentation.quarterTurns * 90)°" : "")
            + (presentation.flipHorizontal ? ", flipped horizontally" : "")
            + (presentation.flipVertical ? ", flipped vertically" : "")
            + (presentation.invert ? ", inverted" : ""))
        return PreparedPrintImage(
            descriptor: transformed,
            sourcePath: sourcePath,
            frameIndex: frameIndex
        )
    }
}
