import XCTest
import DICOMCore
@testable import DICOMKit

/// Tests for Phase 3 Image Preparation Pipeline components:
/// - ImagePreprocessor (Phase 3.1)
/// - ImageResizer (Phase 3.2)
/// - AnnotationRenderer (Phase 3.3)
final class ImagePreparationTests: XCTestCase {
    
    // MARK: - ImagePreprocessor Tests (Phase 3.1)
    
    func test_preparedImage_initialization() {
        let data = Data([0, 1, 2, 3])
        let prepared = PreparedImage(
            pixelData: data,
            width: 2,
            height: 2,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2"
        )
        
        XCTAssertEqual(prepared.pixelData.count, 4)
        XCTAssertEqual(prepared.width, 2)
        XCTAssertEqual(prepared.height, 2)
        XCTAssertEqual(prepared.bitsAllocated, 8)
        XCTAssertEqual(prepared.samplesPerPixel, 1)
        XCTAssertEqual(prepared.photometricInterpretation, "MONOCHROME2")
    }
    
    func test_imagePreprocessor_initialization() async {
        let preprocessor = ImagePreprocessor()
        // Should not throw
        XCTAssertNotNil(preprocessor)
    }
    
    func test_imagePreprocessingError_descriptions() {
        XCTAssertEqual(
            ImagePreprocessingError.missingPixelData.description,
            "Missing pixel data in dataset"
        )
        XCTAssertEqual(
            ImagePreprocessingError.invalidPixelData.description,
            "Invalid pixel data format"
        )
        XCTAssertEqual(
            ImagePreprocessingError.invalidFrameData.description,
            "Invalid frame data"
        )
        XCTAssertEqual(
            ImagePreprocessingError.insufficientPixelData.description,
            "Insufficient pixel data for image dimensions"
        )
        XCTAssertEqual(
            ImagePreprocessingError.unsupportedPhotometricInterpretation("TEST").description,
            "Unsupported photometric interpretation: TEST"
        )
        XCTAssertEqual(
            ImagePreprocessingError.unsupportedBitsAllocated(32).description,
            "Unsupported bits allocated: 32"
        )
        XCTAssertEqual(
            ImagePreprocessingError.invalidSamplesPerPixel(5).description,
            "Invalid samples per pixel: 5"
        )
        XCTAssertEqual(
            ImagePreprocessingError.missingPaletteLUT.description,
            "Missing palette color lookup table"
        )
    }
    
    func test_imagePreprocessor_requiresValidDataSet() async {
        let preprocessor = ImagePreprocessor()
        let emptyDataSet = DataSet()
        
        do {
            _ = try await preprocessor.prepareForPrint(
                dataSet: emptyDataSet,
                colorMode: .grayscale
            )
            XCTFail("Should have thrown missing pixel data error")
        } catch let error as ImagePreprocessingError {
            switch error {
            case .missingPixelData, .invalidPixelData:
                // Expected
                break
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func test_imagePreprocessor_handlesMonochrome2() async throws {
        // Create a minimal valid grayscale dataset
        let dataSet = createTestDataSet(
            width: 4,
            height: 4,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2"
        )
        
        let preprocessor = ImagePreprocessor()
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dataSet,
            colorMode: .grayscale
        )
        
        XCTAssertEqual(prepared.width, 4)
        XCTAssertEqual(prepared.height, 4)
        XCTAssertEqual(prepared.bitsAllocated, 8)
        XCTAssertEqual(prepared.samplesPerPixel, 1)
        XCTAssertEqual(prepared.photometricInterpretation, "MONOCHROME2")
    }
    
    func test_imagePreprocessor_handlesMonochrome1_invertsPolarity() async throws {
        // Create MONOCHROME1 dataset (inverted polarity)
        let dataSet = createTestDataSet(
            width: 2,
            height: 2,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME1"
        )
        
        let preprocessor = ImagePreprocessor()
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dataSet,
            colorMode: .grayscale
        )
        
        // Should convert to MONOCHROME2
        XCTAssertEqual(prepared.photometricInterpretation, "MONOCHROME2")
    }
    
    func test_imagePreprocessor_appliesWindowSettings() async throws {
        let dataSet = createTestDataSet(
            width: 4,
            height: 4,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            photometricInterpretation: "MONOCHROME2"
        )
        
        let window = WindowSettings(center: 128, width: 256)
        let preprocessor = ImagePreprocessor()
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dataSet,
            colorMode: .grayscale,
            windowSettings: window
        )
        
        XCTAssertEqual(prepared.width, 4)
        XCTAssertEqual(prepared.height, 4)
    }
    
    func test_imagePreprocessor_handlesRGBToGrayscaleConversion() async throws {
        let dataSet = createTestDataSet(
            width: 2,
            height: 2,
            bitsAllocated: 8,
            samplesPerPixel: 3,
            photometricInterpretation: "RGB"
        )
        
        let preprocessor = ImagePreprocessor()
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dataSet,
            colorMode: .grayscale
        )
        
        XCTAssertEqual(prepared.samplesPerPixel, 1)
        XCTAssertEqual(prepared.photometricInterpretation, "MONOCHROME2")
        XCTAssertEqual(prepared.pixelData.count, 4) // 2x2 grayscale
    }
    
    func test_imagePreprocessor_preservesRGBForColorPrinting() async throws {
        let dataSet = createTestDataSet(
            width: 2,
            height: 2,
            bitsAllocated: 8,
            samplesPerPixel: 3,
            photometricInterpretation: "RGB"
        )
        
        let preprocessor = ImagePreprocessor()
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dataSet,
            colorMode: .color
        )
        
        XCTAssertEqual(prepared.samplesPerPixel, 3)
        XCTAssertEqual(prepared.photometricInterpretation, "RGB")
        XCTAssertEqual(prepared.pixelData.count, 12) // 2x2x3
    }
    
    // MARK: - ImageResizer Tests (Phase 3.2)
    
    func test_resizeMode_enumValues() {
        _ = ResizeMode.fit
        _ = ResizeMode.fill
        _ = ResizeMode.stretch
        // Should compile without errors
    }
    
    func test_resizeQuality_enumValues() {
        _ = ResizeQuality.low
        _ = ResizeQuality.medium
        _ = ResizeQuality.high
        // Should compile without errors
    }
    
    func test_imageResizer_initialization() async {
        let resizer = ImageResizer()
        XCTAssertNotNil(resizer)
    }
    
    func test_imageResizer_noResizeWhenSizesMatch() async throws {
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        let resized = try await resizer.resize(
            pixelData: pixelData,
            from: CGSize(width: 2, height: 2),
            to: CGSize(width: 2, height: 2),
            mode: .fit,
            quality: .medium,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(resized, pixelData)
    }
    
    func test_imageResizer_upsamplesImage() async throws {
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        let resized = try await resizer.resize(
            pixelData: pixelData,
            from: CGSize(width: 2, height: 2),
            to: CGSize(width: 4, height: 4),
            mode: .stretch,
            quality: .low,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(resized.count, 16) // 4x4
    }
    
    func test_imageResizer_downsamplesImage() async throws {
        let pixelData = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        let resizer = ImageResizer()
        
        let resized = try await resizer.resize(
            pixelData: pixelData,
            from: CGSize(width: 4, height: 4),
            to: CGSize(width: 2, height: 2),
            mode: .stretch,
            quality: .low,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(resized.count, 4) // 2x2
    }
    
    func test_imageResizer_maintainsAspectRatio_fitMode() async throws {
        let pixelData = Data(repeating: 128, count: 4 * 4)
        let resizer = ImageResizer()
        
        // 4x4 image scaled to 8x16 container should be 8x8 with borders
        let resized = try await resizer.resize(
            pixelData: pixelData,
            from: CGSize(width: 4, height: 4),
            to: CGSize(width: 8, height: 16),
            mode: .fit,
            quality: .medium,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(resized.count, 8 * 16) // Full target size with borders
    }
    
    func test_imageResizer_handlesRGBData() async throws {
        let pixelData = Data(repeating: 128, count: 2 * 2 * 3)
        let resizer = ImageResizer()
        
        let resized = try await resizer.resize(
            pixelData: pixelData,
            from: CGSize(width: 2, height: 2),
            to: CGSize(width: 4, height: 4),
            mode: .stretch,
            quality: .medium,
            samplesPerPixel: 3
        )
        
        XCTAssertEqual(resized.count, 4 * 4 * 3)
    }
    
    func test_imageResizer_rejectsInvalidSamplesPerPixel() async {
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        do {
            _ = try await resizer.resize(
                pixelData: pixelData,
                from: CGSize(width: 2, height: 2),
                to: CGSize(width: 4, height: 4),
                mode: .fit,
                quality: .medium,
                samplesPerPixel: 0
            )
            XCTFail("Should have thrown invalid samples per pixel error")
        } catch ImageResizingError.invalidSamplesPerPixel(let samples) {
            XCTAssertEqual(samples, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_imageResizer_rotate90() async throws {
        // 2x3 image: [0,1,2,3,4,5]
        let pixelData = Data([0, 1, 2, 3, 4, 5])
        let resizer = ImageResizer()
        
        let (rotated, newWidth, newHeight) = try await resizer.rotate(
            pixelData: pixelData,
            width: 2,
            height: 3,
            by: .degrees90,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(newWidth, 3) // Swapped
        XCTAssertEqual(newHeight, 2)
        XCTAssertEqual(rotated.count, 6)
    }
    
    func test_imageResizer_rotate180() async throws {
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        let (rotated, newWidth, newHeight) = try await resizer.rotate(
            pixelData: pixelData,
            width: 2,
            height: 2,
            by: .degrees180,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(newWidth, 2) // Same dimensions
        XCTAssertEqual(newHeight, 2)
        XCTAssertEqual(rotated.count, 4)
        // Pixels should be reversed
        XCTAssertEqual(Array(rotated), [3, 2, 1, 0])
    }
    
    func test_imageResizer_rotate270() async throws {
        let pixelData = Data([0, 1, 2, 3, 4, 5])
        let resizer = ImageResizer()
        
        let (rotated, newWidth, newHeight) = try await resizer.rotate(
            pixelData: pixelData,
            width: 2,
            height: 3,
            by: .degrees270,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(newWidth, 3) // Swapped
        XCTAssertEqual(newHeight, 2)
        XCTAssertEqual(rotated.count, 6)
    }
    
    func test_imageResizer_flipHorizontal() async throws {
        // 2x2 image: [0,1,2,3]
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        let flipped = try await resizer.flipHorizontal(
            pixelData: pixelData,
            width: 2,
            height: 2,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(flipped.count, 4)
        // Each row should be reversed
        XCTAssertEqual(Array(flipped), [1, 0, 3, 2])
    }
    
    func test_imageResizer_flipVertical() async throws {
        // 2x2 image: [0,1,2,3]
        let pixelData = Data([0, 1, 2, 3])
        let resizer = ImageResizer()
        
        let flipped = try await resizer.flipVertical(
            pixelData: pixelData,
            width: 2,
            height: 2,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(flipped.count, 4)
        // Rows should be reversed
        XCTAssertEqual(Array(flipped), [2, 3, 0, 1])
    }
    
    func test_imageResizingError_descriptions() {
        XCTAssertEqual(
            ImageResizingError.invalidSourceSize.description,
            "Invalid source image size"
        )
        XCTAssertEqual(
            ImageResizingError.invalidTargetSize.description,
            "Invalid target image size"
        )
        XCTAssertEqual(
            ImageResizingError.invalidSamplesPerPixel(5).description,
            "Invalid samples per pixel: 5"
        )
        XCTAssertEqual(
            ImageResizingError.accelerateError(-123).description,
            "Accelerate framework error: -123"
        )
    }
    
    // MARK: - AnnotationRenderer Tests (Phase 3.3)
    
    func test_printAnnotation_initialization() {
        let annotation = PrintAnnotation(
            text: "Test",
            position: .topLeft,
            fontSize: 16,
            color: .white,
            backgroundOpacity: 0.7
        )
        
        XCTAssertEqual(annotation.text, "Test")
        XCTAssertEqual(annotation.fontSize, 16)
        XCTAssertEqual(annotation.backgroundOpacity, 0.7)
    }
    
    func test_printAnnotation_defaultValues() {
        let annotation = PrintAnnotation(
            text: "Test",
            position: .bottomRight
        )
        
        XCTAssertEqual(annotation.fontSize, 14)
        XCTAssertEqual(annotation.backgroundOpacity, 0.5)
    }
    
    func test_annotationColor_byteValues() {
        XCTAssertEqual(AnnotationColor.black.byteValue, 0)
        XCTAssertEqual(AnnotationColor.white.byteValue, 255)
        XCTAssertEqual(AnnotationColor.gray(value: 0.5).byteValue, 127)
        XCTAssertEqual(AnnotationColor.gray(value: 0.0).byteValue, 0)
        XCTAssertEqual(AnnotationColor.gray(value: 1.0).byteValue, 255)
    }
    
    func test_annotationPosition_allCases() {
        _ = AnnotationPosition.topLeft
        _ = AnnotationPosition.topRight
        _ = AnnotationPosition.topCenter
        _ = AnnotationPosition.bottomLeft
        _ = AnnotationPosition.bottomRight
        _ = AnnotationPosition.bottomCenter
        _ = AnnotationPosition.centerLeft
        _ = AnnotationPosition.centerRight
        _ = AnnotationPosition.center
        _ = AnnotationPosition.custom(x: 10, y: 20)
        // Should compile without errors
    }
    
    func test_annotationRenderer_initialization() async {
        let renderer = AnnotationRenderer()
        XCTAssertNotNil(renderer)
        
        let rendererWithMargin = AnnotationRenderer(margin: 20)
        XCTAssertNotNil(rendererWithMargin)
    }
    
    func test_annotationRenderer_returnsOriginalDataWhenNoAnnotations() async throws {
        let pixelData = Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])
        let renderer = AnnotationRenderer()
        
        let annotated = try await renderer.addAnnotations(
            to: pixelData,
            imageSize: CGSize(width: 4, height: 4),
            annotations: [],
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(annotated, pixelData)
    }
    
    func test_annotationRenderer_addsAnnotationsToGrayscaleImage() async throws {
        let pixelData = Data(repeating: 128, count: 100 * 100)
        let renderer = AnnotationRenderer()
        
        let annotation = PrintAnnotation(
            text: "Test",
            position: .topLeft,
            fontSize: 12,
            color: .white
        )
        
        let annotated = try await renderer.addAnnotations(
            to: pixelData,
            imageSize: CGSize(width: 100, height: 100),
            annotations: [annotation],
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(annotated.count, 100 * 100)
        // Should have modified some pixels
        XCTAssertNotEqual(annotated, pixelData)
    }
    
    func test_annotationRenderer_addsMultipleAnnotations() async throws {
        let pixelData = Data(repeating: 128, count: 100 * 100)
        let renderer = AnnotationRenderer()
        
        let annotations = [
            PrintAnnotation(text: "L", position: .topLeft),
            PrintAnnotation(text: "R", position: .topRight),
            PrintAnnotation(text: "Patient: John Doe", position: .bottomLeft)
        ]
        
        let annotated = try await renderer.addAnnotations(
            to: pixelData,
            imageSize: CGSize(width: 100, height: 100),
            annotations: annotations,
            samplesPerPixel: 1
        )
        
        XCTAssertEqual(annotated.count, 100 * 100)
    }
    
    func test_annotationRenderer_handlesRGBImages() async throws {
        let pixelData = Data(repeating: 128, count: 50 * 50 * 3)
        let renderer = AnnotationRenderer()
        
        let annotation = PrintAnnotation(
            text: "Color Test",
            position: .center,
            fontSize: 16,
            color: .white
        )
        
        let annotated = try await renderer.addAnnotations(
            to: pixelData,
            imageSize: CGSize(width: 50, height: 50),
            annotations: [annotation],
            samplesPerPixel: 3
        )
        
        XCTAssertEqual(annotated.count, 50 * 50 * 3)
    }
    
    func test_annotationRenderer_rejectsInvalidImageSize() async {
        let pixelData = Data([0, 1, 2, 3])
        let renderer = AnnotationRenderer()
        
        do {
            _ = try await renderer.addAnnotations(
                to: pixelData,
                imageSize: CGSize(width: 0, height: 0),
                annotations: [],
                samplesPerPixel: 1
            )
            XCTFail("Should have thrown invalid image size error")
        } catch AnnotationRenderingError.invalidImageSize {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_annotationRenderer_rejectsInvalidSamplesPerPixel() async {
        let pixelData = Data([0, 1, 2, 3])
        let renderer = AnnotationRenderer()
        
        do {
            _ = try await renderer.addAnnotations(
                to: pixelData,
                imageSize: CGSize(width: 2, height: 2),
                annotations: [],
                samplesPerPixel: 5
            )
            XCTFail("Should have thrown invalid samples per pixel error")
        } catch AnnotationRenderingError.invalidSamplesPerPixel(let samples) {
            XCTAssertEqual(samples, 5)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_annotationRenderingError_descriptions() {
        XCTAssertEqual(
            AnnotationRenderingError.invalidImageSize.description,
            "Invalid image size"
        )
        XCTAssertEqual(
            AnnotationRenderingError.invalidSamplesPerPixel(5).description,
            "Invalid samples per pixel: 5"
        )
        XCTAssertEqual(
            AnnotationRenderingError.colorSpaceCreationFailed.description,
            "Failed to create color space"
        )
        XCTAssertEqual(
            AnnotationRenderingError.contextCreationFailed.description,
            "Failed to create graphics context"
        )
        XCTAssertEqual(
            AnnotationRenderingError.textRenderingFailed.description,
            "Failed to render text"
        )
    }
    
    // MARK: - Helper Methods
    
    private func createTestDataSet(
        width: Int,
        height: Int,
        bitsAllocated: Int,
        samplesPerPixel: Int,
        photometricInterpretation: String
    ) -> DataSet {
        var dataSet = DataSet()
        
        // Add image dimensions
        dataSet.set(tag: .rows, value: UInt16(height))
        dataSet.set(tag: .columns, value: UInt16(width))
        dataSet.set(tag: .bitsAllocated, value: UInt16(bitsAllocated))
        dataSet.set(tag: .bitsStored, value: UInt16(bitsAllocated))
        dataSet.set(tag: .highBit, value: UInt16(bitsAllocated - 1))
        dataSet.set(tag: .samplesPerPixel, value: UInt16(samplesPerPixel))
        dataSet.set(tag: .photometricInterpretation, value: photometricInterpretation)
        dataSet.set(tag: .pixelRepresentation, value: UInt16(0))
        
        // Add pixel data
        let pixelCount = width * height * samplesPerPixel
        let pixelData = Data(repeating: 128, count: pixelCount)
        dataSet.set(tag: .pixelData, value: pixelData)
        
        // Add optional rescale parameters
        dataSet.set(tag: .rescaleSlope, value: "1.0")
        dataSet.set(tag: .rescaleIntercept, value: "0.0")
        
        return dataSet
    }
}
