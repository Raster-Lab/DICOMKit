// PresentationStateHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent presentation state transformation helpers

import Foundation

/// Platform-independent helpers for Presentation State transformations.
///
/// Implements VOI LUT, Modality LUT, Presentation LUT, and spatial transformation
/// calculations per DICOM PS3.3 C.11.
public enum PresentationStateHelpers: Sendable {

    // MARK: - VOI LUT

    /// Applies a linear VOI LUT transformation to a pixel value.
    ///
    /// Per DICOM PS3.3 C.11.2.1.2.1, the linear function maps pixel values
    /// to output values using window center and width.
    ///
    /// - Parameters:
    ///   - pixelValue: Input pixel value.
    ///   - center: Window center.
    ///   - width: Window width (must be > 0).
    /// - Returns: Output value in range [0, 1].
    public static func applyLinearVOI(pixelValue: Double, center: Double, width: Double) -> Double {
        guard width > 0 else { return 0.0 }

        if pixelValue <= center - width / 2.0 {
            return 0.0
        } else if pixelValue > center + width / 2.0 {
            return 1.0
        } else {
            return (pixelValue - (center - 0.5)) / (width - 1.0) + 0.5
        }
    }

    /// Applies a sigmoid VOI LUT transformation to a pixel value.
    ///
    /// - Parameters:
    ///   - pixelValue: Input pixel value.
    ///   - center: Window center.
    ///   - width: Window width (must be > 0).
    /// - Returns: Output value in range [0, 1].
    public static func applySigmoidVOI(pixelValue: Double, center: Double, width: Double) -> Double {
        guard width > 0 else { return 0.0 }
        let exponent = -4.0 * (pixelValue - center) / width
        return 1.0 / (1.0 + exp(exponent))
    }

    /// Applies a linear-exact VOI LUT transformation.
    ///
    /// - Parameters:
    ///   - pixelValue: Input pixel value.
    ///   - center: Window center.
    ///   - width: Window width (must be > 0).
    /// - Returns: Output value in range [0, 1].
    public static func applyLinearExactVOI(pixelValue: Double, center: Double, width: Double) -> Double {
        guard width > 0 else { return 0.0 }

        if pixelValue <= center - width / 2.0 {
            return 0.0
        } else if pixelValue > center + width / 2.0 {
            return 1.0
        } else {
            return (pixelValue - center) / width + 0.5
        }
    }

    /// Selects and applies the appropriate VOI LUT function.
    ///
    /// - Parameters:
    ///   - pixelValue: Input pixel value.
    ///   - transform: VOI LUT transform parameters.
    /// - Returns: Output value in range [0, 1].
    public static func applyVOILUT(pixelValue: Double, transform: VOILUTTransform) -> Double {
        switch transform.function.uppercased() {
        case "SIGMOID":
            return applySigmoidVOI(pixelValue: pixelValue, center: transform.windowCenter, width: transform.windowWidth)
        case "LINEAR_EXACT":
            return applyLinearExactVOI(pixelValue: pixelValue, center: transform.windowCenter, width: transform.windowWidth)
        default:
            return applyLinearVOI(pixelValue: pixelValue, center: transform.windowCenter, width: transform.windowWidth)
        }
    }

    // MARK: - Modality LUT

    /// Applies a modality LUT (rescale slope/intercept) transformation.
    ///
    /// output = slope * storedValue + intercept
    ///
    /// - Parameters:
    ///   - storedValue: Stored pixel value.
    ///   - transform: Modality LUT transform.
    /// - Returns: Transformed value.
    public static func applyModalityLUT(storedValue: Double, transform: ModalityLUTTransform) -> Double {
        transform.rescaleSlope * storedValue + transform.rescaleIntercept
    }

    // MARK: - Presentation LUT

    /// Applies a Presentation LUT shape transformation.
    ///
    /// - Parameters:
    ///   - value: Input value in range [0, 1].
    ///   - shape: Presentation LUT shape.
    /// - Returns: Transformed value in range [0, 1].
    public static func applyPresentationLUT(value: Double, shape: PresentationLUTShape) -> Double {
        switch shape {
        case .identity:
            return value
        case .inverse:
            return 1.0 - value
        }
    }

    // MARK: - Spatial Transformations

    /// Computes rotation angle in degrees for a spatial transformation.
    ///
    /// - Parameter transformation: The spatial transformation type.
    /// - Returns: Rotation angle in degrees.
    public static func rotationAngle(for transformation: SpatialTransformationType) -> Double {
        switch transformation {
        case .none: return 0.0
        case .rotate90, .rotate90FlipH: return 90.0
        case .rotate180: return 180.0
        case .rotate270, .rotate270FlipH: return 270.0
        case .flipHorizontal, .flipVertical: return 0.0
        }
    }

    /// Returns whether a spatial transformation includes a horizontal flip.
    ///
    /// - Parameter transformation: The spatial transformation type.
    /// - Returns: True if horizontally flipped.
    public static func isFlippedHorizontally(_ transformation: SpatialTransformationType) -> Bool {
        switch transformation {
        case .flipHorizontal, .rotate90FlipH, .rotate270FlipH:
            return true
        default:
            return false
        }
    }

    /// Returns whether a spatial transformation includes a vertical flip.
    ///
    /// - Parameter transformation: The spatial transformation type.
    /// - Returns: True if vertically flipped.
    public static func isFlippedVertically(_ transformation: SpatialTransformationType) -> Bool {
        transformation == .flipVertical
    }

    /// Transforms a point by a spatial transformation.
    ///
    /// - Parameters:
    ///   - point: Input point.
    ///   - transformation: Spatial transformation to apply.
    ///   - imageWidth: Image width in pixels.
    ///   - imageHeight: Image height in pixels.
    /// - Returns: Transformed point.
    public static func transformPoint(
        _ point: AnnotationPoint,
        transformation: SpatialTransformationType,
        imageWidth: Double,
        imageHeight: Double
    ) -> AnnotationPoint {
        var x = point.x
        var y = point.y

        // Apply flip first
        if isFlippedHorizontally(transformation) {
            x = imageWidth - x
        }
        if isFlippedVertically(transformation) {
            y = imageHeight - y
        }

        // Apply rotation
        let angle = rotationAngle(for: transformation)
        switch angle {
        case 90:
            let newX = imageHeight - y
            let newY = x
            return AnnotationPoint(x: newX, y: newY)
        case 180:
            return AnnotationPoint(x: imageWidth - x, y: imageHeight - y)
        case 270:
            let newX = y
            let newY = imageWidth - x
            return AnnotationPoint(x: newX, y: newY)
        default:
            return AnnotationPoint(x: x, y: y)
        }
    }

    // MARK: - Full Pipeline

    /// Applies the full GSPS rendering pipeline to a pixel value.
    ///
    /// Pipeline: Stored Value → Modality LUT → VOI LUT → Presentation LUT
    ///
    /// - Parameters:
    ///   - storedValue: Original stored pixel value.
    ///   - modalityLUT: Optional modality LUT transform.
    ///   - voiLUT: Optional VOI LUT transform.
    ///   - presentationLUTShape: Presentation LUT shape.
    /// - Returns: Output value in range [0, 1].
    public static func applyGSPSPipeline(
        storedValue: Double,
        modalityLUT: ModalityLUTTransform?,
        voiLUT: VOILUTTransform?,
        presentationLUTShape: PresentationLUTShape
    ) -> Double {
        // Step 1: Modality LUT
        var value = storedValue
        if let modLUT = modalityLUT {
            value = applyModalityLUT(storedValue: value, transform: modLUT)
        }

        // Step 2: VOI LUT
        if let voi = voiLUT {
            value = applyVOILUT(pixelValue: value, transform: voi)
        } else {
            // Normalize to [0, 1] if no VOI LUT
            value = max(0.0, min(1.0, value / 4095.0))
        }

        // Step 3: Presentation LUT
        value = applyPresentationLUT(value: value, shape: presentationLUTShape)

        return value
    }

    // MARK: - Display Text

    /// Returns a display label for a presentation state type.
    ///
    /// - Parameter type: Presentation state type.
    /// - Returns: Human-readable label.
    public static func typeLabel(for type: PresentationStateType) -> String {
        switch type {
        case .grayscale: return "Grayscale (GSPS)"
        case .color: return "Color"
        case .pseudoColor: return "Pseudo-Color"
        case .blending: return "Blending"
        }
    }

    /// Returns a display label for a spatial transformation.
    ///
    /// - Parameter transformation: Spatial transformation type.
    /// - Returns: Human-readable label.
    public static func transformLabel(for transformation: SpatialTransformationType) -> String {
        switch transformation {
        case .none: return "None"
        case .rotate90: return "Rotate 90°"
        case .rotate180: return "Rotate 180°"
        case .rotate270: return "Rotate 270°"
        case .flipHorizontal: return "Flip Horizontal"
        case .flipVertical: return "Flip Vertical"
        case .rotate90FlipH: return "Rotate 90° + Flip H"
        case .rotate270FlipH: return "Rotate 270° + Flip H"
        }
    }

    /// Returns a display label for a presentation LUT shape.
    ///
    /// - Parameter shape: Presentation LUT shape.
    /// - Returns: Human-readable label.
    public static func lutShapeLabel(for shape: PresentationLUTShape) -> String {
        switch shape {
        case .identity: return "Identity"
        case .inverse: return "Inverse"
        }
    }
}
