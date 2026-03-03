#!/usr/bin/env swift
// generate_app_icon.swift
// Generates a DICOM Studio app icon with a medical imaging theme

import AppKit
import CoreGraphics

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // --- Background: rounded rectangle with gradient ---
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: s * 0.02, dy: s * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)

    // Dark blue-to-teal gradient background
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0),
        CGColor(red: 0.05, green: 0.22, blue: 0.38, alpha: 1.0),
        CGColor(red: 0.02, green: 0.30, blue: 0.45, alpha: 1.0)
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 0.5, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: s),
                                   end: CGPoint(x: s, y: 0),
                                   options: [])
    }
    context.restoreGState()

    // --- Subtle grid pattern (DICOM pixel grid feel) ---
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.03))
    context.setLineWidth(s * 0.002)
    let gridStep = s / 16
    for i in 1..<16 {
        let pos = CGFloat(i) * gridStep
        context.move(to: CGPoint(x: pos, y: 0))
        context.addLine(to: CGPoint(x: pos, y: s))
        context.move(to: CGPoint(x: 0, y: pos))
        context.addLine(to: CGPoint(x: s, y: pos))
    }
    context.strokePath()
    context.restoreGState()

    // --- Central medical cross / DICOM element ---
    let centerX = s * 0.5
    let centerY = s * 0.52

    // Outer glow ring
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    let ringRadius = s * 0.28
    let glowColors = [
        CGColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 0.3),
        CGColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 0.0)
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        context.drawRadialGradient(glowGrad,
                                    startCenter: CGPoint(x: centerX, y: centerY),
                                    startRadius: ringRadius * 0.7,
                                    endCenter: CGPoint(x: centerX, y: centerY),
                                    endRadius: ringRadius * 1.5,
                                    options: [])
    }
    context.restoreGState()

    // Circle ring
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.3, green: 0.75, blue: 0.95, alpha: 0.8))
    context.setLineWidth(s * 0.018)
    context.addArc(center: CGPoint(x: centerX, y: centerY),
                   radius: ringRadius,
                   startAngle: 0, endAngle: .pi * 2, clockwise: false)
    context.strokePath()
    context.restoreGState()

    // Inner circle fill (subtle)
    context.saveGState()
    context.setFillColor(CGColor(red: 0.1, green: 0.25, blue: 0.4, alpha: 0.5))
    context.addArc(center: CGPoint(x: centerX, y: centerY),
                   radius: ringRadius * 0.85,
                   startAngle: 0, endAngle: .pi * 2, clockwise: false)
    context.fillPath()
    context.restoreGState()

    // Medical cross
    let crossWidth = s * 0.08
    let crossLength = s * 0.22
    context.saveGState()

    // Cross glow
    let crossGlowColor = CGColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 0.6)
    context.setShadow(offset: .zero, blur: s * 0.03, color: crossGlowColor)
    context.setFillColor(CGColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 0.95))

    // Vertical bar
    let vBar = CGRect(x: centerX - crossWidth / 2,
                      y: centerY - crossLength / 2,
                      width: crossWidth,
                      height: crossLength)
    let vBarPath = CGPath(roundedRect: vBar, cornerWidth: crossWidth * 0.3, cornerHeight: crossWidth * 0.3, transform: nil)
    context.addPath(vBarPath)

    // Horizontal bar
    let hBar = CGRect(x: centerX - crossLength / 2,
                      y: centerY - crossWidth / 2,
                      width: crossLength,
                      height: crossWidth)
    let hBarPath = CGPath(roundedRect: hBar, cornerWidth: crossWidth * 0.3, cornerHeight: crossWidth * 0.3, transform: nil)
    context.addPath(hBarPath)
    context.fillPath()
    context.restoreGState()

    // --- Corner scan lines (DICOM imagery feel) ---
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    // Top-left scan bracket
    let bracketLen = s * 0.12
    let bracketInset = s * 0.12
    let bracketWidth = s * 0.012
    context.setStrokeColor(CGColor(red: 0.3, green: 0.75, blue: 0.95, alpha: 0.5))
    context.setLineWidth(bracketWidth)
    context.setLineCap(.round)

    // Top-left
    context.move(to: CGPoint(x: bracketInset, y: bracketInset + bracketLen))
    context.addLine(to: CGPoint(x: bracketInset, y: bracketInset))
    context.addLine(to: CGPoint(x: bracketInset + bracketLen, y: bracketInset))
    context.strokePath()

    // Top-right
    context.move(to: CGPoint(x: s - bracketInset - bracketLen, y: bracketInset))
    context.addLine(to: CGPoint(x: s - bracketInset, y: bracketInset))
    context.addLine(to: CGPoint(x: s - bracketInset, y: bracketInset + bracketLen))
    context.strokePath()

    // Bottom-left
    context.move(to: CGPoint(x: bracketInset, y: s - bracketInset - bracketLen))
    context.addLine(to: CGPoint(x: bracketInset, y: s - bracketInset))
    context.addLine(to: CGPoint(x: bracketInset + bracketLen, y: s - bracketInset))
    context.strokePath()

    // Bottom-right
    context.move(to: CGPoint(x: s - bracketInset - bracketLen, y: s - bracketInset))
    context.addLine(to: CGPoint(x: s - bracketInset, y: s - bracketInset))
    context.addLine(to: CGPoint(x: s - bracketInset, y: s - bracketInset - bracketLen))
    context.strokePath()

    context.restoreGState()

    // --- "DS" text at bottom ---
    let fontSize = s * 0.09
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 0.7)
    ]
    let text = "DS" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textPoint = NSPoint(x: centerX - textSize.width / 2,
                            y: s * 0.12 - textSize.height / 2)
    text.draw(at: textPoint, withAttributes: attrs)

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    // Create a bitmap rep at exact pixel dimensions (1x scale, no Retina doubling)
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmapRep.size = NSSize(width: pixelSize, height: pixelSize)

    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
               from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for size \(pixelSize)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path) (\(pixelSize)x\(pixelSize))")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Main
let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: generate_app_icon.swift <output_directory>")
    exit(1)
}

let outputDir = args[1]

// Create output directory
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// Generate master icon at 1024x1024
let masterIcon = generateIcon(size: 1024)

// Required macOS icon sizes: (name, pixel size)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixelSize) in sizes {
    let path = (outputDir as NSString).appendingPathComponent(name)
    savePNG(masterIcon, to: path, pixelSize: pixelSize)
}

print("\nAll icon sizes generated successfully!")
