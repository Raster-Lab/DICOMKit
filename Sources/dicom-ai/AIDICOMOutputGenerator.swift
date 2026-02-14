import Foundation
import DICOMKit
import DICOMCore

// MARK: - AI DICOM Output Generator

/// Generates DICOM output objects from AI inference results.
///
/// Supports creating:
/// - DICOM Structured Reports (SR) from classification/detection predictions
/// - DICOM Segmentation objects from segmentation masks
/// - Grayscale Softcopy Presentation State (GSPS) with AI annotations
/// - Enhanced DICOM files with AI-processed pixel data
/// - Text/JSON/Markdown reports from predictions
struct AIDICOMOutputGenerator {

    // MARK: - DICOM SR from Predictions

    /// Creates a DICOM Structured Report from classification predictions.
    /// - Parameters:
    ///   - predictions: Classification predictions with labels and confidence scores
    ///   - sourceDataSet: The original DICOM DataSet for reference metadata
    ///   - modelName: Name of the AI model used
    /// - Returns: A serialized DataSet containing the SR
    static func createSRFromClassification(
        predictions: [Prediction],
        sourceDataSet: DataSet,
        modelName: String
    ) throws -> DataSet {
        let patientID = sourceDataSet.string(for: .patientID) ?? "UNKNOWN"
        let patientName = sourceDataSet.string(for: .patientName) ?? "UNKNOWN"
        let studyInstanceUID = sourceDataSet.string(for: .studyInstanceUID) ?? UIDGenerator.generateStudyInstanceUID().value
        let sopInstanceUID = sourceDataSet.string(for: .sopInstanceUID) ?? ""

        let builder = SRDocumentBuilder(documentType: .comprehensiveSR)
            .withPatientID(patientID)
            .withPatientName(patientName)
            .withStudyInstanceUID(studyInstanceUID)
            .withSeriesInstanceUID(UIDGenerator.generateSeriesInstanceUID().value)
            .withDocumentTitle(CodedConcept(
                codeValue: "129007",
                codingSchemeDesignator: "DCM",
                codeMeaning: "AI Classification Report"
            ))
            .withCompletionFlag(.complete)
            .withVerificationFlag(.unverified)
            .addText(
                conceptName: CodedConcept(
                    codeValue: "111001",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Algorithm Name"
                ),
                value: modelName,
                relationshipType: .contains
            )

        var current = builder
        for prediction in predictions {
            current = current.addText(
                conceptName: CodedConcept(
                    codeValue: "121071",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Finding"
                ),
                value: "\(prediction.label): \(String(format: "%.1f%%", prediction.confidence * 100))",
                relationshipType: .contains
            )
            current = current.addNumeric(
                conceptName: CodedConcept(
                    codeValue: "121072",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Confidence"
                ),
                value: prediction.confidence,
                units: CodedConcept(
                    codeValue: "%",
                    codingSchemeDesignator: "UCUM",
                    codeMeaning: "percent"
                ),
                relationshipType: .contains
            )
        }

        if !sopInstanceUID.isEmpty {
            let sopClassUID = sourceDataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2"
            current = current.addImageReference(
                conceptName: CodedConcept(
                    codeValue: "121191",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Referenced Image"
                ),
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                relationshipType: .contains
            )
        }

        let document = try current.build()
        let serializer = SRDocumentSerializer()
        return try serializer.serialize(document: document)
    }

    /// Creates a DICOM Structured Report from detection results.
    static func createSRFromDetections(
        detections: [Detection],
        sourceDataSet: DataSet,
        modelName: String
    ) throws -> DataSet {
        let patientID = sourceDataSet.string(for: .patientID) ?? "UNKNOWN"
        let patientName = sourceDataSet.string(for: .patientName) ?? "UNKNOWN"
        let studyInstanceUID = sourceDataSet.string(for: .studyInstanceUID) ?? UIDGenerator.generateStudyInstanceUID().value

        var builder = SRDocumentBuilder(documentType: .comprehensiveSR)
            .withPatientID(patientID)
            .withPatientName(patientName)
            .withStudyInstanceUID(studyInstanceUID)
            .withSeriesInstanceUID(UIDGenerator.generateSeriesInstanceUID().value)
            .withDocumentTitle(CodedConcept(
                codeValue: "129008",
                codingSchemeDesignator: "DCM",
                codeMeaning: "AI Detection Report"
            ))
            .withCompletionFlag(.complete)
            .withVerificationFlag(.unverified)
            .addText(
                conceptName: CodedConcept(
                    codeValue: "111001",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Algorithm Name"
                ),
                value: modelName,
                relationshipType: .contains
            )

        for (index, detection) in detections.enumerated() {
            let findingText = "Detection \(index + 1): \(detection.label) " +
                "(confidence: \(String(format: "%.1f%%", detection.confidence * 100)), " +
                "bbox: [\(detection.bbox.x), \(detection.bbox.y), \(detection.bbox.width), \(detection.bbox.height)])"

            builder = builder.addText(
                conceptName: CodedConcept(
                    codeValue: "121071",
                    codingSchemeDesignator: "DCM",
                    codeMeaning: "Finding"
                ),
                value: findingText,
                relationshipType: .contains
            )
        }

        let document = try builder.build()
        let serializer = SRDocumentSerializer()
        return try serializer.serialize(document: document)
    }

    // MARK: - DICOM Segmentation Object

    /// Creates a DICOM Segmentation object from an AI segmentation mask.
    /// - Parameters:
    ///   - sourceDataSet: The original DICOM DataSet for reference metadata
    ///   - segmentationMask: The segmentation mask with class labels
    ///   - labels: Human-readable labels for each segment class
    ///   - modelName: Name of the AI model used
    /// - Returns: Serialized DICOM Segmentation binary data
    static func createSegmentationObject(
        sourceDataSet: DataSet,
        segmentationMask: SegmentationMask,
        labels: [String],
        modelName: String
    ) throws -> Data {
        let studyInstanceUID = sourceDataSet.string(for: .studyInstanceUID) ?? UIDGenerator.generateStudyInstanceUID().value
        let seriesInstanceUID = UIDGenerator.generateSeriesInstanceUID().value
        let sopClassUID = sourceDataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2"
        let sopInstanceUID = sourceDataSet.string(for: .sopInstanceUID) ?? ""

        let builder = SegmentationBuilder(
            rows: segmentationMask.height,
            columns: segmentationMask.width,
            segmentationType: .binary,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID
        )
        .setContentLabel("AI_SEGMENTATION")
        .setContentDescription("AI segmentation from \(modelName)")

        if !sopInstanceUID.isEmpty {
            builder.addSourceImage(
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID
            )
        }

        // Extract per-class binary masks and add as segments
        for classIndex in 0..<segmentationMask.numClasses {
            let label = classIndex < labels.count ? labels[classIndex] : "Class_\(classIndex)"
            let binaryMask = extractBinaryMask(
                from: segmentationMask,
                forClass: classIndex
            )

            try builder.addBinarySegment(
                number: classIndex + 1,
                label: label,
                mask: binaryMask,
                algorithmType: .automatic,
                algorithmName: modelName
            )
        }

        let (_, pixelData) = try builder.build()

        // Build a complete DICOM file with segmentation metadata
        var dataSet = DataSet()
        dataSet.setString("1.2.840.10008.5.1.4.1.1.66.4", for: .sopClassUID, vr: .UI)
        dataSet.setString(UIDGenerator.generateSOPInstanceUID().value, for: .sopInstanceUID, vr: .UI)
        dataSet.setString(studyInstanceUID, for: .studyInstanceUID, vr: .UI)
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("SEG", for: .modality, vr: .CS)
        dataSet.setUInt16(UInt16(segmentationMask.height), for: .rows)
        dataSet.setUInt16(UInt16(segmentationMask.width), for: .columns)
        dataSet.setUInt16(1, for: .bitsAllocated)
        dataSet.setUInt16(1, for: .bitsStored)
        dataSet.setUInt16(0, for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(1, for: .samplesPerPixel)

        // Copy patient info from source
        if let patientName = sourceDataSet.string(for: .patientName) {
            dataSet.setString(patientName, for: .patientName, vr: .PN)
        }
        if let patientID = sourceDataSet.string(for: .patientID) {
            dataSet.setString(patientID, for: .patientID, vr: .LO)
        }

        var result = dataSet.write()
        result.append(pixelData)
        return result
    }

    /// Extracts a binary mask for a specific class from the segmentation mask.
    private static func extractBinaryMask(from mask: SegmentationMask, forClass classIndex: Int) -> [UInt8] {
        let pixelCount = mask.width * mask.height
        var binaryMask = [UInt8](repeating: 0, count: pixelCount)

        for i in 0..<min(pixelCount, mask.data.count) {
            if mask.data[i] == UInt8(classIndex) {
                binaryMask[i] = 1
            }
        }

        return binaryMask
    }

    // MARK: - GSPS with AI Annotations

    /// Creates a Grayscale Softcopy Presentation State with AI annotations.
    /// - Parameters:
    ///   - detections: AI detection results with bounding boxes
    ///   - sourceDataSet: The original DICOM DataSet
    ///   - modelName: Name of the AI model used
    /// - Returns: Serialized DICOM GSPS DataSet
    static func createGSPSWithAnnotations(
        detections: [Detection],
        sourceDataSet: DataSet,
        modelName: String
    ) throws -> DataSet {
        let studyInstanceUID = sourceDataSet.string(for: .studyInstanceUID) ?? UIDGenerator.generateStudyInstanceUID().value
        let seriesInstanceUID = UIDGenerator.generateSeriesInstanceUID().value
        let sopInstanceUID = UIDGenerator.generateSOPInstanceUID().value
        let referencedSOPInstanceUID = sourceDataSet.string(for: .sopInstanceUID) ?? ""
        let referencedSOPClassUID = sourceDataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.2"

        var dataSet = DataSet()

        // SOP Common Module
        dataSet.setString("1.2.840.10008.5.1.4.1.1.11.1", for: .sopClassUID, vr: .UI)
        dataSet.setString(sopInstanceUID, for: .sopInstanceUID, vr: .UI)

        // General Study Module
        dataSet.setString(studyInstanceUID, for: .studyInstanceUID, vr: .UI)

        // General Series Module
        dataSet.setString(seriesInstanceUID, for: .seriesInstanceUID, vr: .UI)
        dataSet.setString("PR", for: .modality, vr: .CS)

        // Presentation State Module
        dataSet.setString("AI_ANNOTATIONS", for: .presentationLabel, vr: .CS)
        dataSet.setString("AI annotations from \(modelName)", for: .presentationDescription, vr: .LO)

        // Copy patient info from source
        if let patientName = sourceDataSet.string(for: .patientName) {
            dataSet.setString(patientName, for: .patientName, vr: .PN)
        }
        if let patientID = sourceDataSet.string(for: .patientID) {
            dataSet.setString(patientID, for: .patientID, vr: .LO)
        }

        // Build referenced series sequence
        if !referencedSOPInstanceUID.isEmpty {
            var refImageItem = DataSet()
            refImageItem.setString(referencedSOPClassUID, for: .referencedSOPClassUID, vr: .UI)
            refImageItem.setString(referencedSOPInstanceUID, for: .referencedSOPInstanceUID, vr: .UI)

            var refSeriesItem = DataSet()
            refSeriesItem.setString(
                sourceDataSet.string(for: .seriesInstanceUID) ?? "",
                for: .seriesInstanceUID,
                vr: .UI
            )
            refSeriesItem.setSequence(
                [SequenceItem(elements: refImageItem.allElements)],
                for: .referencedImageSequence
            )

            dataSet.setSequence(
                [SequenceItem(elements: refSeriesItem.allElements)],
                for: .referencedSeriesSequence
            )
        }

        // Build graphic annotation sequence from detections
        var annotationItems: [SequenceItem] = []

        // Define a graphic layer for AI annotations
        var layerItem = DataSet()
        layerItem.setString("AI_DETECTIONS", for: .graphicLayer, vr: .CS)
        layerItem.setUInt16(1, for: .graphicLayerOrder)
        layerItem.setString("AI Detection Results", for: .graphicLayerDescription, vr: .LO)
        dataSet.setSequence(
            [SequenceItem(elements: layerItem.allElements)],
            for: .graphicLayerSequence
        )

        for detection in detections {
            var annotationItem = DataSet()
            annotationItem.setString("AI_DETECTIONS", for: .graphicLayer, vr: .CS)

            // Create graphic object for bounding box (POLYLINE)
            var graphicItem = DataSet()
            graphicItem.setString("POLYLINE", for: Tag(group: 0x0070, element: 0x0023), vr: .CS)  // Graphic Type
            graphicItem.setUInt16(5, for: Tag(group: 0x0070, element: 0x0021))  // Number of Graphic Points

            // Bounding box as 5-point polyline (closed rectangle)
            let x = detection.bbox.x
            let y = detection.bbox.y
            let w = detection.bbox.width
            let h = detection.bbox.height
            let pointsString = "\(y)\\\(x)\\\(y)\\\(x + w)\\\(y + h)\\\(x + w)\\\(y + h)\\\(x)\\\(y)\\\(x)"
            graphicItem.setString(pointsString, for: Tag(group: 0x0070, element: 0x0022), vr: .FL)  // Graphic Data

            graphicItem.setString("PIXEL", for: Tag(group: 0x0070, element: 0x0005), vr: .CS)  // Annotation Units
            annotationItem.setSequence(
                [SequenceItem(elements: graphicItem.allElements)],
                for: .graphicObjectSequence
            )

            // Create text object for label
            var textItem = DataSet()
            textItem.setString(
                "\(detection.label) (\(String(format: "%.0f%%", detection.confidence * 100)))",
                for: Tag(group: 0x0070, element: 0x0006),
                vr: .ST
            )

            // Position text above the bounding box
            let topLeftString = "\(x)\\\(y - 10)"
            let bottomRightString = "\(x + w)\\\(y)"
            textItem.setString(topLeftString, for: .boundingBoxTopLeftHandCorner, vr: .FL)
            textItem.setString(bottomRightString, for: .boundingBoxBottomRightHandCorner, vr: .FL)
            textItem.setString("PIXEL", for: Tag(group: 0x0070, element: 0x0005), vr: .CS)

            annotationItem.setSequence(
                [SequenceItem(elements: textItem.allElements)],
                for: .textObjectSequence
            )

            annotationItems.append(SequenceItem(elements: annotationItem.allElements))
        }

        if !annotationItems.isEmpty {
            dataSet.setSequence(annotationItems, for: .graphicAnnotationSequence)
        }

        return dataSet
    }

    // MARK: - Enhanced DICOM File

    /// Creates an enhanced DICOM file by replacing pixel data with AI-processed data.
    /// - Parameters:
    ///   - sourceDataSet: The original DICOM DataSet
    ///   - enhancedImage: The AI-enhanced processed image
    ///   - frameIndex: The frame that was enhanced (for multi-frame images)
    /// - Returns: Serialized DICOM file data with enhanced pixel data
    static func createEnhancedDICOMFile(
        sourceDataSet: DataSet,
        enhancedImage: ProcessedImage,
        frameIndex: Int
    ) throws -> Data {
        // Create a new DataSet based on the source, replacing pixel data
        var dataSet = DataSet()

        // Copy essential metadata from source
        let metadataTags: [Tag] = [
            .sopClassUID, .sopInstanceUID, .studyInstanceUID, .seriesInstanceUID,
            .patientName, .patientID, .patientBirthDate, .patientSex,
            .modality, .studyDate, .studyTime,
            .photometricInterpretation
        ]

        for tag in metadataTags {
            if let value = sourceDataSet.string(for: tag) {
                let vr = sourceDataSet[tag]?.vr ?? .LO
                dataSet.setString(value, for: tag, vr: vr)
            }
        }

        // Generate new SOP Instance UID for the enhanced version
        dataSet.setString(UIDGenerator.generateSOPInstanceUID().value, for: .sopInstanceUID, vr: .UI)
        dataSet.setString(UIDGenerator.generateSeriesInstanceUID().value, for: .seriesInstanceUID, vr: .UI)

        // Set image dimensions
        dataSet.setUInt16(UInt16(enhancedImage.height), for: .rows)
        dataSet.setUInt16(UInt16(enhancedImage.width), for: .columns)
        dataSet.setUInt16(UInt16(enhancedImage.bitsPerPixel), for: .bitsAllocated)
        dataSet.setUInt16(UInt16(enhancedImage.bitsPerPixel), for: .bitsStored)
        dataSet.setUInt16(UInt16(enhancedImage.bitsPerPixel - 1), for: .highBit)
        dataSet.setUInt16(0, for: .pixelRepresentation)
        dataSet.setUInt16(UInt16(enhancedImage.samplesPerPixel), for: .samplesPerPixel)
        dataSet.setString(enhancedImage.photometricInterpretation, for: .photometricInterpretation, vr: .CS)

        // Add pixel data using subscript assignment
        let pixelVR: VR = enhancedImage.bitsPerPixel > 8 ? .OW : .OB
        dataSet[.pixelData] = DataElement.data(tag: .pixelData, vr: pixelVR, data: enhancedImage.pixelData)

        // Add image comments noting AI enhancement
        dataSet.setString("AI Enhanced Image", for: Tag(group: 0x0020, element: 0x4000), vr: .LT)

        return dataSet.write()
    }

    // MARK: - Report Generation

    /// Generates a text report from classification predictions.
    static func generateClassificationReport(
        predictions: [Prediction],
        filePath: String,
        modelName: String
    ) -> String {
        var report = """
        ═══════════════════════════════════════════════════
        AI Classification Report
        ═══════════════════════════════════════════════════
        Model: \(modelName)
        File:  \(filePath)
        Date:  \(ISO8601DateFormatter().string(from: Date()))
        ═══════════════════════════════════════════════════

        RESULTS:
        """

        if predictions.isEmpty {
            report += "\n  No predictions above confidence threshold.\n"
        } else {
            for (index, pred) in predictions.enumerated() {
                let bar = String(repeating: "█", count: Int(pred.confidence * 30))
                let space = String(repeating: "░", count: 30 - Int(pred.confidence * 30))
                report += "\n  \(index + 1). \(pred.label)"
                report += "\n     Confidence: \(String(format: "%.2f%%", pred.confidence * 100))"
                report += "\n     [\(bar)\(space)]"
                report += "\n"
            }
        }

        report += "\n═══════════════════════════════════════════════════\n"
        return report
    }

    /// Generates a text report from detection results.
    static func generateDetectionReport(
        detections: [Detection],
        filePath: String,
        modelName: String
    ) -> String {
        var report = """
        ═══════════════════════════════════════════════════
        AI Detection Report
        ═══════════════════════════════════════════════════
        Model:      \(modelName)
        File:       \(filePath)
        Date:       \(ISO8601DateFormatter().string(from: Date()))
        Detections: \(detections.count)
        ═══════════════════════════════════════════════════

        FINDINGS:
        """

        if detections.isEmpty {
            report += "\n  No detections above confidence threshold.\n"
        } else {
            for (index, det) in detections.enumerated() {
                report += "\n  \(index + 1). \(det.label)"
                report += "\n     Confidence: \(String(format: "%.2f%%", det.confidence * 100))"
                report += "\n     Location:   (x: \(String(format: "%.1f", det.bbox.x)), y: \(String(format: "%.1f", det.bbox.y)))"
                report += "\n     Size:       \(String(format: "%.1f", det.bbox.width)) × \(String(format: "%.1f", det.bbox.height))"
                report += "\n"
            }
        }

        report += "\n═══════════════════════════════════════════════════\n"
        return report
    }

    /// Generates a Markdown report from predictions.
    static func generateMarkdownReport(
        predictions: [Prediction],
        detections: [Detection],
        filePath: String,
        modelName: String
    ) -> String {
        var md = "# AI Analysis Report\n\n"
        md += "| Property | Value |\n|----------|-------|\n"
        md += "| Model | \(modelName) |\n"
        md += "| File | \(filePath) |\n"
        md += "| Date | \(ISO8601DateFormatter().string(from: Date())) |\n\n"

        if !predictions.isEmpty {
            md += "## Classifications\n\n"
            md += "| Rank | Label | Confidence |\n|------|-------|------------|\n"
            for (index, pred) in predictions.enumerated() {
                md += "| \(index + 1) | \(pred.label) | \(String(format: "%.2f%%", pred.confidence * 100)) |\n"
            }
            md += "\n"
        }

        if !detections.isEmpty {
            md += "## Detections\n\n"
            md += "| # | Label | Confidence | X | Y | Width | Height |\n"
            md += "|---|-------|------------|---|---|-------|--------|\n"
            for (index, det) in detections.enumerated() {
                md += "| \(index + 1) | \(det.label) | \(String(format: "%.2f%%", det.confidence * 100)) "
                md += "| \(String(format: "%.1f", det.bbox.x)) | \(String(format: "%.1f", det.bbox.y)) "
                md += "| \(String(format: "%.1f", det.bbox.width)) | \(String(format: "%.1f", det.bbox.height)) |\n"
            }
            md += "\n"
        }

        return md
    }
}
