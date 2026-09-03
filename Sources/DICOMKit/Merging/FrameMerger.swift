import Foundation
import DICOMCore
import DICOMDictionary

/// Output container format for a merge.
public enum MergeFormat: String, Sendable, CaseIterable {
    /// Keep the template's SOP Class and just stack the frames (legacy behaviour;
    /// only conformant when the source IOD is itself multi-frame).
    case standard
    /// Pick the multi-frame class from the source SOP Class (CT/MR/PET → Legacy
    /// Converted Enhanced, US → US Multi-frame, SC → Multi-frame SC).
    case auto
    case enhancedCt = "enhanced-ct"
    case enhancedMr = "enhanced-mr"
    case enhancedPet = "enhanced-pet"
    case enhancedXa = "enhanced-xa"
    case enhancedXrf = "enhanced-xrf"
    case legacyConvertedCt = "legacy-converted-ct"
    case legacyConvertedMr = "legacy-converted-mr"
    case legacyConvertedPet = "legacy-converted-pet"
    case scMultiframe = "sc-multiframe"
    case usMultiframe = "us-multiframe"

    /// The multi-frame SOP Class UID for this format (nil for standard/auto).
    public var enhancedSOPClassUID: String? {
        typealias U = MultiframeSOPClassMap.UID
        switch self {
        case .standard, .auto: return nil
        case .enhancedCt: return U.enhancedCT
        case .enhancedMr: return U.enhancedMR
        case .enhancedPet: return U.enhancedPET
        case .enhancedXa: return U.enhancedXA
        case .enhancedXrf: return U.enhancedXRF
        case .legacyConvertedCt: return U.legacyConvertedEnhancedCT
        case .legacyConvertedMr: return U.legacyConvertedEnhancedMR
        case .legacyConvertedPet: return U.legacyConvertedEnhancedPET
        case .scMultiframe: return U.multiframeGrayscaleByteSC   // refined by bit depth at merge time
        case .usMultiframe: return U.usMultiframe
        }
    }

    public var isLegacyConverted: Bool {
        switch self {
        case .legacyConvertedCt, .legacyConvertedMr, .legacyConvertedPet: return true
        default: return false
        }
    }
}

/// How input files are grouped into outputs.
public enum MergeLevel: String, Sendable {
    case file
    case series
    case study
}

/// Frame ordering criteria.
public enum MergeSortCriteria: String, Sendable {
    case instanceNumber = "InstanceNumber"
    case imagePositionPatient = "ImagePositionPatient"
    case acquisitionTime = "AcquisitionTime"
    case none
}

/// Frame ordering direction.
public enum MergeSortOrder: String, Sendable {
    case ascending
    case descending
}

/// Enhanced-multiframe options for a merge.
public struct MergeOptions: Sendable {
    public var pixelHandling: MultiframePixelHandling = .preserve
    /// Group frames into stacks by orientation.
    public var makeStacks: Bool = false
    /// Derive Temporal Position Index from Trigger Time / Acquisition Time.
    public var temporalPositions: Bool = false
    /// Mint a new Series Instance UID for the merged object.
    public var newSeries: Bool = false
    /// Skip the source-SOP-class gate for Enhanced targets.
    public var allowAnySource: Bool = false

    public init() {}
}

/// Merges single-frame DICOM files into multi-frame files.
///
/// Lives in the DICOMKit library so the `dicom-merge` CLI and DICOMStudio run the
/// exact same merge code. Verbose progress is emitted through the injected `log`
/// closure (the CLI routes it to stderr, the app to its console string) so the
/// wording comes from one place. Group iteration is sorted by UID so multi-output
/// (series/study) runs are deterministic.
///
/// Enhanced targets get their Shared / Per-frame Functional Groups and the
/// Multi-frame Dimension module from ``FunctionalGroupBuilder``; pixel bytes are
/// assembled by ``MultiframePixelAssembler`` (native concatenation or one
/// encapsulated fragment per frame with a Basic Offset Table).
public struct FrameMerger {
    public let format: MergeFormat
    public let level: MergeLevel
    public let sortBy: MergeSortCriteria
    public let order: MergeSortOrder
    public let validate: Bool
    public let verbose: Bool
    public let options: MergeOptions

    /// Progress sink. Verbose lines are gated on `verbose`; warnings always flow.
    private let log: (String) -> Void

    private let fileManager = FileManager.default

    public init(
        format: MergeFormat,
        level: MergeLevel,
        sortBy: MergeSortCriteria,
        order: MergeSortOrder,
        validate: Bool,
        verbose: Bool,
        options: MergeOptions = MergeOptions(),
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.format = format
        self.level = level
        self.sortBy = sortBy
        self.order = order
        self.validate = validate
        self.verbose = verbose
        self.options = options
        self.log = log
    }

    // MARK: - Entry points

    /// Merges all files into a single multi-frame file.
    public func mergeToSingleFile(files: [String], outputPath: String) async throws {
        if verbose {
            log("Merging \(files.count) files into single multi-frame file")
        }

        // Load all DICOM files
        var dicomFiles: [(String, DICOMFile)] = []
        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)) {
                dicomFiles.append((path, file))
            } else if verbose {
                log("Warning: Skipping non-DICOM file: \(path)")
            }
        }

        guard !dicomFiles.isEmpty else {
            throw MergeError.noValidFiles
        }

        // Validate consistency if requested
        if validate {
            try validateConsistency(dicomFiles.map { $0.1 })
        }

        // Sort frames
        let sortedFiles = sortFrames(dicomFiles, by: sortBy, order: order)

        // Merge into multi-frame
        let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

        // Write output
        let data = try multiFrameFile.write()
        try data.write(to: URL(fileURLWithPath: outputPath))

        if verbose {
            log("Created multi-frame file with \(sortedFiles.count) frames: \(outputPath)")
        }
    }

    /// Merges files grouped by series.
    public func mergeBySeries(files: [String], outputDirectory: String) async throws {
        if verbose {
            log("Merging files by series")
        }

        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // Load and group by series
        var seriesGroups: [String: [(String, DICOMFile)]] = [:]

        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let seriesUID = file.dataSet.string(for: .seriesInstanceUID) {
                seriesGroups[seriesUID, default: []].append((path, file))
            } else if verbose {
                log("Warning: Skipping file without series UID: \(path)")
            }
        }

        if verbose {
            log("Found \(seriesGroups.count) series")
        }

        // Process each series (sorted by UID for deterministic output)
        for (seriesUID, seriesFiles) in seriesGroups.sorted(by: { $0.key < $1.key }) {
            let outputPath = (outputDirectory as NSString).appendingPathComponent("series_\(seriesUID).dcm")

            // Sort frames
            let sortedFiles = sortFrames(seriesFiles, by: sortBy, order: order)

            // Validate consistency if requested
            if validate {
                try validateConsistency(sortedFiles.map { $0.1 })
            }

            // Merge into multi-frame
            let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

            // Write output
            let data = try multiFrameFile.write()
            try data.write(to: URL(fileURLWithPath: outputPath))

            if verbose {
                log("  Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
            }
        }
    }

    /// Merges files grouped by study.
    public func mergeByStudy(files: [String], outputDirectory: String) async throws {
        if verbose {
            log("Merging files by study")
        }

        // Create output directory
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        // Load and group by study
        var studyGroups: [String: [(String, DICOMFile)]] = [:]

        for path in files.sorted() {
            if let file = try? DICOMFile.read(from: URL(fileURLWithPath: path)),
               let studyUID = file.dataSet.string(for: .studyInstanceUID) {
                studyGroups[studyUID, default: []].append((path, file))
            } else if verbose {
                log("Warning: Skipping file without study UID: \(path)")
            }
        }

        if verbose {
            log("Found \(studyGroups.count) studies")
        }

        // Process each study (sorted by UID for deterministic output)
        for (studyUID, studyFiles) in studyGroups.sorted(by: { $0.key < $1.key }) {
            let studyDir = (outputDirectory as NSString).appendingPathComponent("study_\(studyUID)")
            try fileManager.createDirectory(atPath: studyDir, withIntermediateDirectories: true)

            // Group by series within study
            var seriesGroups: [String: [(String, DICOMFile)]] = [:]

            for (path, file) in studyFiles {
                if let seriesUID = file.dataSet.string(for: .seriesInstanceUID) {
                    seriesGroups[seriesUID, default: []].append((path, file))
                }
            }

            if verbose {
                log("  Study \(studyUID): \(seriesGroups.count) series")
            }

            // Process each series (sorted by UID for deterministic output)
            for (seriesUID, seriesFiles) in seriesGroups.sorted(by: { $0.key < $1.key }) {
                let outputPath = (studyDir as NSString).appendingPathComponent("series_\(seriesUID).dcm")

                // Sort frames
                let sortedFiles = sortFrames(seriesFiles, by: sortBy, order: order)

                // Validate consistency if requested
                if validate {
                    try validateConsistency(sortedFiles.map { $0.1 })
                }

                // Merge into multi-frame
                let multiFrameFile = try createMultiFrameFile(from: sortedFiles)

                // Write output
                let data = try multiFrameFile.write()
                try data.write(to: URL(fileURLWithPath: outputPath))

                if verbose {
                    log("    Series \(seriesUID): \(sortedFiles.count) frames -> \(outputPath)")
                }
            }
        }
    }

    // MARK: - Target resolution

    /// The multi-frame SOP Class the merged object gets, or nil for `standard`.
    func resolveTargetSOPClass(template: DataSet) -> String? {
        let sourceUID = template.string(for: .sopClassUID).map(MultiframeSOPClassMap.normalize) ?? ""
        let bits = Int(template.uint16(for: .bitsAllocated) ?? 8)
        let samples = Int(template.uint16(for: .samplesPerPixel) ?? 1)
        switch format {
        case .standard:
            return nil
        case .auto:
            return MultiframeSOPClassMap.automaticMergeTarget(forSource: sourceUID, bitsAllocated: bits, samplesPerPixel: samples)
        case .scMultiframe:
            typealias U = MultiframeSOPClassMap.UID
            if samples == 3 { return U.multiframeTrueColorSC }
            if bits == 1 { return U.multiframeSingleBitSC }
            return bits > 8 ? U.multiframeGrayscaleWordSC : U.multiframeGrayscaleByteSC
        default:
            return format.enhancedSOPClassUID
        }
    }

    // MARK: - Assembly

    /// One input frame: the file it lives in, its index there, and its attributes
    /// as a single-frame data set (functional groups / vectors resolved).
    struct FrameSource {
        let file: DICOMFile
        let frame: Int
        let dataSet: DataSet
        /// The input path this frame came from, for diagnostics.
        let path: String

        /// "name.dcm" for a single-frame input, "name.dcm frame 3" otherwise.
        var description: String {
            let name = (path as NSString).lastPathComponent
            let total = file.dataSet.numberOfFrames ?? 1
            return total > 1 ? "\(name) frame \(frame)" : name
        }
    }

    /// Expands every input into its frames. Multi-frame inputs (Enhanced chunks,
    /// cine loops) contribute all their frames, each with the frame's own
    /// attributes so the functional-group factoring sees classic-like data sets.
    func frameSources(from files: [(String, DICOMFile)]) -> [FrameSource] {
        var sources: [FrameSource] = []
        for (path, file) in files {
            let ds = file.dataSet
            let n = ds.numberOfFrames ?? 1
            guard n > 1 else {
                sources.append(FrameSource(file: file, frame: 0, dataSet: ds, path: path))
                continue
            }
            let entry = MultiframeSOPClassMap.entry(for: ds.string(for: .sopClassUID))
            let hasFG = entry?.hasFunctionalGroups ?? (ds[.perFrameFunctionalGroupsSequence] != nil)
            let kind = entry?.legacyVectors ?? (ds[.frameIncrementPointer] != nil ? .cine : .none)
            for i in 0..<n {
                var frameDS: DataSet
                if hasFG {
                    frameDS = FunctionalGroupFlattener.flatten(ds, frameIndex: i, toClassic: true)
                } else {
                    frameDS = DataSet()
                    for element in ds.allElements where element.tag != .pixelData {
                        frameDS[element.tag] = element
                    }
                    LegacyVectorResolver.resolve(&frameDS, frameIndex: i, kind: kind, mode: .classic)
                }
                frameDS[.numberOfFrames] = nil
                frameDS[.extendedOffsetTable] = nil
                frameDS[.extendedOffsetTableLengths] = nil
                sources.append(FrameSource(file: file, frame: i, dataSet: frameDS, path: path))
            }
        }
        return sources
    }

    /// Concatenation parts (PS3.3 C.7.6.16.2.2.4) are put back together instead
    /// of merged: Per-frame items and pixels in In-concatenation Number order, the
    /// source SOP Instance UID restored, the part bookkeeping removed.
    private func reassembleConcatenation(from files: [(String, DICOMFile)]) throws -> DICOMFile {
        let reassembly: MultiframeConcatenation.Reassembly
        do {
            reassembly = try MultiframeConcatenation.reassemble(parts: files.map { $0.1.dataSet })
        } catch let error as MultiframeConcatenation.ReassemblyError {
            throw MergeError.concatenation(error.description)
        }

        var payloads: [FramePixelPayload] = []
        for idx in reassembly.partOrder {
            let file = files[idx].1
            let n = file.dataSet.numberOfFrames ?? 1
            for frame in 0..<n {
                do {
                    payloads.append(try MultiframePixelAssembler.extractFrame(from: file, frame: frame, handling: options.pixelHandling))
                } catch let error as MultiframePixelError {
                    throw MergeError.pixelAssembly(error.description)
                }
            }
        }
        let assembled: (element: DataElement, transferSyntaxUID: String)
        do {
            assembled = try MultiframePixelAssembler.assemble(payloads)
        } catch let error as MultiframePixelError {
            throw MergeError.pixelAssembly(error.description)
        }

        var merged = reassembly.dataSet
        var fileMeta = files[reassembly.partOrder[0]].1.fileMetaInformation
        merged[.pixelData] = assembled.element
        MultiframePixelAssembler.applyPixelDescription(payloads[0], to: &merged, fileMeta: &fileMeta)
        let sopUID = merged.string(for: .sopInstanceUID).map(MultiframeSOPClassMap.normalize) ?? UIDGenerator.generateSOPInstanceUID().value
        merged.setString(sopUID, for: .sopInstanceUID, vr: .UI)
        fileMeta.setString(sopUID, for: .mediaStorageSOPInstanceUID, vr: .UI)
        if let sopClass = merged.string(for: .sopClassUID).map(MultiframeSOPClassMap.normalize) {
            fileMeta.setString(sopClass, for: .mediaStorageSOPClassUID, vr: .UI)
        }
        if options.newSeries {
            merged.setString(UIDGenerator.generateSeriesInstanceUID().value, for: .seriesInstanceUID, vr: .UI)
        }
        if verbose {
            log(MergeConsole.concatenationReassembledLine(parts: files.count, frames: reassembly.frameCount, sopInstanceUID: sopUID))
        }
        return DICOMFile(fileMetaInformation: fileMeta, dataSet: merged)
    }

    /// Creates a multi-frame DICOM file from sorted single-frame files.
    private func createMultiFrameFile(from files: [(String, DICOMFile)]) throws -> DICOMFile {
        guard let firstFile = files.first else {
            throw MergeError.noValidFiles
        }

        // Concatenation parts are reassembled, whatever --format says.
        if files.allSatisfy({ MultiframeConcatenation.isPart($0.1.dataSet) }) {
            return try reassembleConcatenation(from: files)
        }

        let template = firstFile.1.dataSet
        let sources = frameSources(from: files)
        let dataSets = sources.map { $0.dataSet }

        // Core consistency (always on): the Image Pixel module must agree.
        try validateImagePixelModule(sources)
        try validateUniqueSOPInstances(files.map { $0.1.dataSet })

        // Target SOP class + source gate.
        let targetUID = resolveTargetSOPClass(template: template)
        let sourceUID = template.string(for: .sopClassUID).map(MultiframeSOPClassMap.normalize)
        if let targetUID {
            if !options.allowAnySource,
               let allowed = MultiframeSOPClassMap.allowedMergeSources(forTarget: targetUID) {
                for (_, file) in files {
                    let uid = file.dataSet.string(for: .sopClassUID).map(MultiframeSOPClassMap.normalize) ?? ""
                    guard allowed.contains(uid) else {
                        throw MergeError.unsupportedSourceSOPClass(
                            source: sopClassName(uid), target: sopClassName(targetUID))
                    }
                }
            }
        } else if let sourceUID, !MultiframeSOPClassMap.isMultiframeIOD(sourceUID) {
            log(MergeConsole.nonMultiframeSOPClassWarning(name: sopClassName(sourceUID)))
        }

        // Pixel data: per-frame payloads assembled with the right encapsulation.
        var payloads: [FramePixelPayload] = []
        payloads.reserveCapacity(sources.count)
        for source in sources {
            guard source.file.dataSet[.pixelData] != nil else {
                throw MergeError.missingPixelData(file: source.file.dataSet.string(for: .sopInstanceUID) ?? "unknown")
            }
            do {
                payloads.append(try MultiframePixelAssembler.extractFrame(from: source.file, frame: source.frame,
                                                                          handling: options.pixelHandling))
            } catch let error as MultiframePixelError {
                throw MergeError.pixelAssembly(error.description)
            }
        }
        let assembled: (element: DataElement, transferSyntaxUID: String)
        do {
            assembled = try MultiframePixelAssembler.assemble(payloads)
        } catch let error as MultiframePixelError {
            switch error {
            case .mixedTransferSyntaxes(let e, let f):
                throw MergeError.inconsistentAttribute(tag: "TransferSyntaxUID", expected: e, found: f)
            case .mixedFrameSize(let e, let f):
                throw MergeError.inconsistentPixelDataSize(expected: e, found: f)
            default:
                throw MergeError.pixelAssembly(error.description)
            }
        }

        // Use first file as template
        var mergedDataSet = template
        var fileMetaInformation = firstFile.1.fileMetaInformation

        let numberOfFrames = sources.count
        mergedDataSet.setString("\(numberOfFrames)", for: .numberOfFrames, vr: .IS)
        mergedDataSet[.pixelData] = assembled.element
        for tag in MultiframeConcatenation.partTags { mergedDataSet[tag] = nil }

        // Standard merge of multi-frame Enhanced inputs: keep the module intact by
        // concatenating their Per-frame items in frame order.
        if targetUID == nil, template[.perFrameFunctionalGroupsSequence] != nil {
            var items: [SequenceItem] = []
            for source in sources {
                if let item = FunctionalGroupFlattener.perFrameItem(of: source.file.dataSet, frameIndex: source.frame) {
                    items.append(item)
                }
            }
            if items.count == sources.count {
                mergedDataSet.setSequence(items, for: .perFrameFunctionalGroupsSequence)
            }
        }
        MultiframePixelAssembler.applyPixelDescription(payloads[0], to: &mergedDataSet, fileMeta: &fileMetaInformation)

        // Generate new SOP Instance UID for the merged file
        let newSOPInstanceUID = UIDGenerator.generateSOPInstanceUID()
        mergedDataSet.setString(newSOPInstanceUID.value, for: .sopInstanceUID, vr: .UI)
        fileMetaInformation.setString(newSOPInstanceUID.value, for: .mediaStorageSOPInstanceUID, vr: .UI)

        // Update instance number to 1 (multi-frame is a single instance)
        mergedDataSet.setString("1", for: .instanceNumber, vr: .IS)

        if options.newSeries {
            mergedDataSet.setString(UIDGenerator.generateSeriesInstanceUID().value, for: .seriesInstanceUID, vr: .UI)
        }

        if let targetUID {
            mergedDataSet.setString(targetUID, for: .sopClassUID, vr: .UI)
            fileMetaInformation.setString(targetUID, for: .mediaStorageSOPClassUID, vr: .UI)

            if MultiframeSOPClassMap.hasFunctionalGroups(targetUID) {
                try buildEnhancedModules(into: &mergedDataSet, frames: dataSets, targetUID: targetUID)
            } else {
                buildLegacyMultiframeModules(into: &mergedDataSet, frames: dataSets, targetUID: targetUID)
            }
        }

        return DICOMFile(fileMetaInformation: fileMetaInformation, dataSet: mergedDataSet)
    }

    /// Multi-frame Functional Groups + Dimension + Enhanced image/series modules.
    private func buildEnhancedModules(into ds: inout DataSet, frames: [DataSet], targetUID: String) throws {
        let modality = MultiframeSOPClassMap.modality(forTarget: targetUID)
            ?? ds.string(for: .modality)?.trimmingCharacters(in: .whitespaces) ?? ""
        let legacy = format.isLegacyConverted
        let builderOptions = FunctionalGroupBuilder.Options(
            targetSOPClassUID: targetUID, modality: modality, legacyConverted: legacy,
            makeStacks: options.makeStacks, temporalPositions: options.temporalPositions)
        let built = FunctionalGroupBuilder.build(frames: frames, options: builderOptions)

        for tag in built.liftedTags { ds[tag] = nil }

        ds.setSequence([built.shared], for: .sharedFunctionalGroupsSequence)
        var perFrame = built.perFrame
        if let unassigned = built.unassignedPerFrame {
            for i in perFrame.indices where !unassigned[i].allElements.isEmpty {
                var elements = perFrame[i].allElements
                elements.append(FunctionalGroupBuilder.sequenceElement(
                    .unassignedPerFrameConvertedAttributesSequence, items: [unassigned[i]], writer: DICOMWriter()))
                perFrame[i] = SequenceItem(elements: elements)
            }
        }
        ds.setSequence(perFrame, for: .perFrameFunctionalGroupsSequence)

        // Multi-frame Dimension module.
        ds.setSequence([SequenceItem(elements: [
            DataElement.string(tag: .dimensionOrganizationUID, vr: .UI, value: built.dimensionOrganizationUID)
        ])], for: .dimensionOrganizationSequence)
        ds.setSequence(built.dimensionIndexItems, for: .dimensionIndexSequence)
        if let type = built.dimensionOrganizationType {
            ds.setString(type, for: .dimensionOrganizationType, vr: .CS)
        } else {
            ds[.dimensionOrganizationType] = nil
        }

        // Enhanced image module attributes (top level).
        ds.setString(modality, for: .modality, vr: .CS)
        var imageType = (ds.strings(for: .imageType) ?? []).map { $0.trimmingCharacters(in: .whitespaces) }
        if imageType.isEmpty { imageType = ["ORIGINAL", "PRIMARY"] }
        while imageType.count < 4 { imageType.append(imageType.count == 2 ? "VOLUME" : "NONE") }
        ds.setStrings(Array(imageType.prefix(4)), for: .imageType, vr: .CS)
        if ["CT", "MR", "PT"].contains(modality) {
            let samples = ds.uint16(for: .samplesPerPixel) ?? 1
            ds.setString(samples > 1 ? "COLOR" : "MONOCHROME", for: .pixelPresentation, vr: .CS)
            ds.setString("VOLUME", for: .volumetricProperties, vr: .CS)
            ds.setString("NONE", for: .volumeBasedCalculationTechnique, vr: .CS)
            if ds[.presentationLUTShape] == nil, samples == 1 {
                ds.setString("IDENTITY", for: .presentationLUTShape, vr: .CS)
            }
        }
        if modality == "MR" {
            ds.setString("MAGNITUDE", for: .complexImageComponent, vr: .CS)
            ds.setString("UNKNOWN", for: .acquisitionContrast, vr: .CS)
        }
        if ds[.burnedInAnnotation] == nil { ds.setString("NO", for: .burnedInAnnotation, vr: .CS) }
        if ds[.lossyImageCompression] == nil { ds.setString("00", for: .lossyImageCompression, vr: .CS) }
        if ds[.contentQualification] == nil { ds.setString("PRODUCT", for: .contentQualification, vr: .CS) }

        // Frame of Reference (Type 1 for the Enhanced CT/MR/PET IODs).
        if ds.string(for: .frameOfReferenceUID)?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            ds.setString(UIDGenerator.generateUID().value, for: .frameOfReferenceUID, vr: .UI)
        }
        if ds[.positionReferenceIndicator] == nil {
            ds.setString("", for: .positionReferenceIndicator, vr: .LO)
        }

        // Content date/time.
        let now = Date()
        let dateFormatter = DateFormatter(); dateFormatter.dateFormat = "yyyyMMdd"
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "HHmmss"
        if ds[.contentDate] == nil { ds.setString(dateFormatter.string(from: now), for: .contentDate, vr: .DA) }
        if ds[.contentTime] == nil { ds.setString(timeFormatter.string(from: now), for: .contentTime, vr: .TM) }

        // Enhanced General Equipment (Type 1).
        for tag in [Tag.manufacturer, .manufacturerModelName, .deviceSerialNumber, .softwareVersions]
        where ds.string(for: tag)?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
            ds.setString("UNKNOWN", for: tag, vr: tag == .manufacturer || tag == .manufacturerModelName || tag == .softwareVersions ? .LO : .LO)
        }

        // Common Instance Reference / Conversion evidence for Legacy Converted.
        if legacy {
            ds.setSequence(referencedSeriesItems(frames), for: .referencedSeriesSequence)
        }

        if verbose {
            for line in MergeConsole.functionalGroupLines(
                target: sopClassName(targetUID), shared: built.sharedMacroCount,
                perFrame: built.perFrameMacroCount, stacks: built.stackCount,
                temporalPositions: options.temporalPositions ? built.temporalPositionCount : nil,
                dimensionOrganizationType: built.dimensionOrganizationType
            ) {
                log(line)
            }
        }
        if !built.droppedVaryingTags.isEmpty {
            log(MergeConsole.droppedAttributesWarning(
                tags: built.droppedVaryingTags.map { $0.description }))
        }
    }

    /// Cine / SC multi-frame modules for the legacy multi-frame targets.
    private func buildLegacyMultiframeModules(into ds: inout DataSet, frames: [DataSet], targetUID: String) {
        let writer = DICOMWriter()
        // Frame Time from the source cine attributes, else derived from acquisition times.
        if ds[.frameTime] == nil {
            let times = frames.compactMap { $0.string(for: .acquisitionTime).flatMap { FunctionalGroupBuilder.timeSeconds($0.trimmingCharacters(in: .whitespaces)) } }
            if times.count == frames.count, frames.count > 1 {
                let deltas = zip(times.dropFirst(), times).map { ($0 - $1) * 1000 }
                if deltas.allSatisfy({ $0 > 0 }) {
                    ds.setString(DataSet.defaultDecimalString(deltas.reduce(0, +) / Double(deltas.count)), for: .frameTime, vr: .DS)
                }
            }
        }
        if ds[.frameTime] != nil {
            ds[.frameIncrementPointer] = DataElement(tag: .frameIncrementPointer, vr: .AT, length: 4,
                                                     valueData: writer.serializeTag(.frameTime))
        }
        ds[.frameTimeVector] = nil
        if targetUID.hasPrefix(MultiframeSOPClassMap.UID.secondaryCapture) {
            if ds[.conversionType] == nil { ds.setString("WSD", for: .conversionType, vr: .CS) }
            if ds[.burnedInAnnotation] == nil { ds.setString("NO", for: .burnedInAnnotation, vr: .CS) }
        }
        if ds[.burnedInAnnotation] == nil { ds.setString("NO", for: .burnedInAnnotation, vr: .CS) }
        // Per-frame identity attributes that no longer describe the whole object.
        for tag in [Tag.imagePositionPatient, .sliceLocation] where frames.count > 1 {
            let first = frames[0][tag]
            if !frames.dropFirst().allSatisfy({ FunctionalGroupBuilder.sameElement($0[tag], first) }) { ds[tag] = nil }
        }
        if verbose {
            log(MergeConsole.legacyMultiframeLine(target: sopClassName(targetUID), frameTime: ds.string(for: .frameTime)))
        }
    }

    /// Referenced Series Sequence items grouping the source instances by series.
    private func referencedSeriesItems(_ frames: [DataSet]) -> [SequenceItem] {
        let writer = DICOMWriter()
        var bySeries: [String: [SequenceItem]] = [:]
        var order: [String] = []
        for frame in frames {
            let series = frame.string(for: .seriesInstanceUID).map(MultiframeSOPClassMap.normalize) ?? ""
            if bySeries[series] == nil { order.append(series) }
            bySeries[series, default: []].append(SequenceItem(elements: [
                DataElement.string(tag: .referencedSOPClassUID, vr: .UI,
                                   value: frame.string(for: .sopClassUID).map(MultiframeSOPClassMap.normalize) ?? ""),
                DataElement.string(tag: .referencedSOPInstanceUID, vr: .UI,
                                   value: frame.string(for: .sopInstanceUID).map(MultiframeSOPClassMap.normalize) ?? ""),
            ]))
        }
        return order.map { series in
            SequenceItem(elements: [
                DataElement.string(tag: .seriesInstanceUID, vr: .UI, value: series),
                FunctionalGroupBuilder.sequenceElement(.referencedInstanceSequence, items: bySeries[series] ?? [], writer: writer),
            ])
        }
    }

    private func sopClassName(_ uid: String) -> String {
        MultiframeSOPClassMap.entry(for: uid)?.name
            ?? UIDDictionary.lookup(uid: MultiframeSOPClassMap.normalize(uid))?.name
            ?? uid
    }

    // MARK: - Sorting

    /// Sorts frames based on specified criteria.
    private func sortFrames(
        _ files: [(String, DICOMFile)],
        by criteria: MergeSortCriteria,
        order: MergeSortOrder
    ) -> [(String, DICOMFile)] {
        guard criteria != .none else {
            return files
        }

        let keyed: [(Double, String, (String, DICOMFile))] = files.map { file in
            let ds = file.1.dataSet
            switch criteria {
            case .instanceNumber:
                // InstanceNumber (0020,0013) is VR=IS — an integer *string*; parse it.
                let n = ds.string(for: .instanceNumber).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
                return (Double(n), "", file)
            case .imagePositionPatient:
                // Distance along the slice normal when the orientation is known; Z otherwise.
                let info = FunctionalGroupFlattener.frameInfo(in: ds, frameIndex: 0)
                let pos = info.positionAlongNormal ?? (info.imagePositionPatient?.count == 3 ? info.imagePositionPatient![2] : 0)
                return (pos, "", file)
            case .acquisitionTime:
                return (0, ds.string(for: .acquisitionTime) ?? "", file)
            case .none:
                return (0, "", file)
            }
        }

        // Stable sort; descending is the reversed ascending order.
        let sorted = keyed.enumerated().sorted { a, b in
            if a.element.0 != b.element.0 { return a.element.0 < b.element.0 }
            if a.element.1 != b.element.1 { return a.element.1 < b.element.1 }
            return a.offset < b.offset
        }.map { $0.element.2 }
        return order == .ascending ? sorted : Array(sorted.reversed())
    }

    // MARK: - Validation

    /// Always-on: the Image Pixel module must agree across inputs.
    /// A comparable rendering of an element's value, whatever its VR.
    ///
    /// `DataSet.string(for:)` returns nil for every VR without a character
    /// repertoire (US, SS, OW, ...), so comparing Rows/Columns/BitsAllocated
    /// via strings compares nil to nil and passes for *any* pair of inputs.
    /// Binary VRs are read numerically instead.
    static func comparableValue(_ dataSet: DataSet, _ tag: Tag) -> String? {
        guard let element = dataSet[tag] else { return nil }
        if element.vr.characterRepertoire != nil { return element.stringValue }
        if let values = element.uint16Values, !values.isEmpty {
            return values.map(String.init).joined(separator: "\\")
        }
        if let value = element.uint32Value { return String(value) }
        return element.valueData.map { String(format: "%02x", $0) }.joined()
    }

    /// Identifies an input in a diagnostic when no path is at hand: the SOP
    /// Instance UID, which is unique per input.
    static func instanceLabel(_ dataSet: DataSet) -> String {
        dataSet.string(for: .sopInstanceUID).map(MultiframeSOPClassMap.normalize) ?? "unknown instance"
    }

    private func validateImagePixelModule(_ sources: [FrameSource]) throws {
        guard let first = sources.first else { return }
        let tags: [Tag] = [.rows, .columns, .bitsAllocated, .bitsStored, .highBit,
                           .pixelRepresentation, .samplesPerPixel, .photometricInterpretation]
        for tag in tags {
            let expected = FrameMerger.comparableValue(first.dataSet, tag)
            for source in sources.dropFirst() {
                let value = FrameMerger.comparableValue(source.dataSet, tag)
                if value != expected {
                    throw MergeError.inconsistentAttribute(
                        tag: tag.description,
                        expected: expected ?? "nil", found: value ?? "nil",
                        expectedFile: first.description, foundFile: source.description)
                }
            }
        }
    }

    private func validateUniqueSOPInstances(_ dataSets: [DataSet]) throws {
        var seen = Set<String>()
        for ds in dataSets {
            guard let uid = ds.string(for: .sopInstanceUID).map(MultiframeSOPClassMap.normalize) else { continue }
            if !seen.insert(uid).inserted { throw MergeError.duplicateSOPInstanceUID(uid) }
        }
    }

    /// `--validate`: identity attributes must match too.
    private func validateConsistency(_ files: [DICOMFile]) throws {
        guard let first = files.first else {
            return
        }

        let requiredMatchingTags: [Tag] = [
            .studyInstanceUID,
            .seriesInstanceUID,
            .modality,
            .frameOfReferenceUID,
            .rows,
            .columns,
            .bitsAllocated,
            .bitsStored,
            .highBit,
            .pixelRepresentation,
            .samplesPerPixel,
            .photometricInterpretation
        ]

        for tag in requiredMatchingTags {
            let firstValue = FrameMerger.comparableValue(first.dataSet, tag)

            for file in files.dropFirst() {
                let value = FrameMerger.comparableValue(file.dataSet, tag)
                if value != firstValue {
                    throw MergeError.inconsistentAttribute(
                        tag: tag.description,
                        expected: firstValue ?? "nil",
                        found: value ?? "nil",
                        expectedFile: FrameMerger.instanceLabel(first.dataSet),
                        foundFile: FrameMerger.instanceLabel(file.dataSet)
                    )
                }
            }
        }

        // Check pixel data size
        if let firstPixelData = first.dataSet[.pixelData]?.valueData {
            let firstSize = firstPixelData.count

            for file in files.dropFirst() {
                if let pixelData = file.dataSet[.pixelData]?.valueData {
                    if pixelData.count != firstSize {
                        throw MergeError.inconsistentPixelDataSize(
                            expected: firstSize,
                            found: pixelData.count
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Errors

public enum MergeError: Error, CustomStringConvertible {
    case noValidFiles
    case missingPixelData(file: String)
    case inconsistentAttribute(tag: String, expected: String, found: String,
                               expectedFile: String? = nil, foundFile: String? = nil)
    case inconsistentPixelDataSize(expected: Int, found: Int)
    case directoryEnumerationFailed(path: String)
    case unsupportedSourceSOPClass(source: String, target: String)
    case duplicateSOPInstanceUID(String)
    case pixelAssembly(String)
    case concatenation(String)

    public var description: String {
        switch self {
        case .noValidFiles:
            return "No valid DICOM files found"
        case .missingPixelData(let file):
            return "Missing pixel data in file: \(file)"
        case .inconsistentAttribute(let tag, let expected, let found, let expectedFile, let foundFile):
            var text = "Inconsistent \(tag): expected '\(expected)', found '\(found)'"
            if let expectedFile, let foundFile {
                text += " (\(expectedFile) vs \(foundFile))"
            }
            if tag == Tag.rows.description || tag == Tag.columns.description {
                text += "; all frames of a multi-frame object share one image size"
                text += " — merge with --level series to keep each series separate"
            }
            return text
        case .inconsistentPixelDataSize(let expected, let found):
            return "Inconsistent pixel data size: expected \(expected) bytes, found \(found) bytes"
        case .directoryEnumerationFailed(let path):
            return "Failed to enumerate directory: \(path)"
        case .unsupportedSourceSOPClass(let source, let target):
            return "Cannot merge \(source) into \(target) (use --allow-any-source to override)"
        case .duplicateSOPInstanceUID(let uid):
            return "Duplicate SOP Instance UID among inputs: \(uid)"
        case .pixelAssembly(let reason):
            return "Pixel data assembly failed: \(reason)"
        case .concatenation(let reason):
            return "Concatenation reassembly failed: \(reason)"
        }
    }
}

// MARK: - Shared input gathering (dicom-merge CLI ⇄ Workshop executor)

extension FrameMerger {
    /// True when the path looks like a DICOM file: a known extension
    /// (.dcm/.dicom/.dic) or the "DICM" magic at byte 128.
    public static func isDICOMFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ["dcm", "dicom", "dic"].contains(ext) {
            return true
        }
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 132) else {
            return false
        }
        if data.count >= 132 {
            let magic = data[128..<132]
            return magic == Data([0x44, 0x49, 0x43, 0x4D]) // "DICM"
        }
        return false
    }

    /// Gathers DICOM input files from a mix of file and directory paths.
    /// Directories are expanded (recursively when requested); non-existent paths
    /// are skipped. The result is sorted so the merge frame/instance order is
    /// deterministic and identical on the CLI and Workshop surfaces.
    public static func gatherInputFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default

        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                if recursive {
                    guard let enumerator = fileManager.enumerator(atPath: path) else {
                        throw MergeError.directoryEnumerationFailed(path: path)
                    }
                    for case let item as String in enumerator {
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        var itemIsDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDirectory),
                           !itemIsDirectory.boolValue,
                           isDICOMFile(fullPath) {
                            files.append(fullPath)
                        }
                    }
                } else {
                    let contents = try fileManager.contentsOfDirectory(atPath: path)
                    for item in contents {
                        let fullPath = (path as NSString).appendingPathComponent(item)
                        var itemIsDirectory: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &itemIsDirectory),
                           !itemIsDirectory.boolValue,
                           isDICOMFile(fullPath) {
                            files.append(fullPath)
                        }
                    }
                }
            } else if isDICOMFile(path) {
                files.append(path)
            }
        }

        return files.sorted()
    }
}
