import Foundation
import DICOMCore

/// Orchestrates the pixel side of `dicom-anon`: detection → planning → (dry-run gate)
/// → redaction, **before** header de-identification.
///
/// This is the one implementation of the option semantics in
/// PIXEL_ANONYMIZATION_PIPELINE.md §2.1, shared by the CLI so the contract is
/// library-testable rather than living in `main.swift`:
///
/// - `--redact-region` **implies** cleaning.
/// - `--detect-text` **does not** imply cleaning — it is a region *source*.
/// - Detection feeds the refusal contract: text that was detected but will not be
///   redacted is reported in ``Report/detectedButUnredacted`` and the caller must refuse
///   to write (unless the operator accepts the risk explicitly).
/// - Nothing is written on a dry run; the plan is still built so it can be printed.
public struct PixelCleaningWorkflow: Sendable {

    /// OCR mode. `classify` (default) redacts PHI and uncertain text and keeps only
    /// allowlisted clinical text; `all` redacts every detected region.
    public enum TextDetectionMode: String, Sendable, CaseIterable {
        case classify
        case all

        /// Parses `--detect-text[=classify|all]`; an empty value is the default.
        public static func parse(_ raw: String?) -> TextDetectionMode? {
            guard let raw = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty
            else { return .classify }
            return TextDetectionMode(rawValue: raw)
        }
    }

    public struct Options: Sendable, Equatable {
        /// `--clean-pixel-data`
        public var cleanPixelData: Bool
        /// `--redact-region` rectangles (already validated).
        public var explicitRegions: [PixelRedactionPlan.Region]
        /// `--detect-text`; `nil` when OCR is off.
        public var detectText: TextDetectionMode?
        /// `--ocr-all-frames`
        public var ocrAllFrames: Bool
        /// `--redact-fill`
        public var fillValue: Int?
        /// Safety margin around detected text.
        public var dilation: Int
        /// `--redact-style` / `--redact-label`
        public var style: PixelRedactor.Style
        /// Regions found on OTHER parts of the same concatenation (directory mode
        /// pre-pass, ``ConcatenationSweep``). Unioned in as text-detection regions so
        /// text found in part 2 is blanked in part 1 too.
        public var presetDetectedRegions: [PixelRedactionPlan.Region]
        /// True when every part of this file's concatenation was swept, so the
        /// single-part coverage warning is not needed.
        public var concatenationAnalyzedCompletely: Bool

        public init(
            cleanPixelData: Bool = false,
            explicitRegions: [PixelRedactionPlan.Region] = [],
            detectText: TextDetectionMode? = nil,
            ocrAllFrames: Bool = false,
            fillValue: Int? = nil,
            dilation: Int = TextRegionDetector.defaultDilation,
            style: PixelRedactor.Style = .blank,
            presetDetectedRegions: [PixelRedactionPlan.Region] = [],
            concatenationAnalyzedCompletely: Bool = false
        ) {
            self.cleanPixelData = cleanPixelData
            self.explicitRegions = explicitRegions
            self.detectText = detectText
            self.ocrAllFrames = ocrAllFrames
            self.fillValue = fillValue
            self.dilation = dilation
            self.style = style
            self.presetDetectedRegions = presetDetectedRegions
            self.concatenationAnalyzedCompletely = concatenationAnalyzedCompletely
        }

        /// Pixel modification is requested: `--clean-pixel-data`, or rectangles (which
        /// imply it). `--detect-text` alone never modifies pixels.
        public var cleaningRequested: Bool {
            cleanPixelData || !explicitRegions.isEmpty
        }

        /// True when *any* pixel work (detection or cleaning) is configured.
        public var isActive: Bool {
            cleaningRequested || detectText != nil
        }
    }

    /// What one run did (or, on a dry run, would do).
    public struct Report: Sendable {
        /// Every OCR detection on the sampled frames (empty when OCR was off).
        public let detections: [TextRegionDetector.Detection]
        /// One verdict per detection (parallel to `detections`). In `all` mode every
        /// verdict is redact.
        public let verdicts: [PHITextClassifier.Verdict]
        /// Frames OCR scanned.
        public let scannedFrames: [Int]
        /// The plan that was (or would be) executed; `nil` when cleaning was not requested.
        public let plan: PixelRedactionPlan?
        /// Set when pixels were actually redacted (never on a dry run).
        public let outcome: PixelRedactor.Outcome?
        /// File bytes to hand to the header pass — redacted when `outcome` is set,
        /// otherwise the input unchanged.
        public let data: Data
        /// Total frames in the object.
        public let frameCount: Int
        /// Non-refusing notes for the summary (e.g. incomplete concatenation coverage).
        public let warnings: [String]
        /// Detected text the run will **not** blank and that was not positively
        /// allowlisted. Non-empty means the caller must refuse to write an output file
        /// unless the operator accepted the risk.
        public var detectedButUnredacted: [TextRegionDetector.Detection] {
            guard !detections.isEmpty else { return [] }
            let wanted = zip(detections, verdicts).filter { $0.1.isRedact }.map(\.0)
            guard let plan, case .redact(let regions, _) = plan.decision else { return wanted }
            return wanted.filter { d in !regions.contains(d.region) }
        }

        /// PHI-safe audit lines: verdict, reason, confidence, rect, frame, truncated text.
        /// Never the full recognized string — the audit log must not become a PHI store.
        public var auditLines: [String] {
            zip(detections, verdicts).map { d, v in
                "OCR frame=\(d.frameIndex) rect=\(d.region.x),\(d.region.y),\(d.region.width),\(d.region.height) "
                + "verdict=\(v.name) reason=\"\(v.reason)\" conf=\(String(format: "%.2f", d.confidence)) "
                + "text=\(d.redactedForAudit)"
            }
        }
        /// Warnings in the same shape as `ConfidentialityEngine.residualPixelPHIWarnings`.
        public var residualWarnings: [String] {
            let leftover = detectedButUnredacted
            guard !leftover.isEmpty else { return [] }
            let frames = Set(leftover.map(\.frameIndex)).sorted()
            return ["OCR detected \(leftover.count) text region\(leftover.count == 1 ? "" : "s") "
                + "on frame\(frames.count == 1 ? "" : "s") \(frames.map(String.init).joined(separator: ",")) "
                + "that will not be redacted."]
        }
    }

    public init() {}

    // MARK: - Concatenations

    /// Concatenation bookkeeping of one instance, when it is a part.
    public struct ConcatenationInfo: Sendable, Equatable {
        public let uid: String
        public let number: Int?
        public let total: Int?
    }

    public static func concatenationInfo(of dataSet: DataSet) -> ConcatenationInfo? {
        guard MultiframeConcatenation.isPart(dataSet),
              let uid = dataSet.string(for: .concatenationUID)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        else { return nil }
        return ConcatenationInfo(
            uid: uid,
            number: dataSet.uint16(for: .inConcatenationNumber).map(Int.init),
            total: dataSet.uint16(for: .inConcatenationTotalNumber).map(Int.init))
    }

    static func concatenationCoverageWarning(_ info: ConcatenationInfo) -> String {
        let which: String
        if let n = info.number, let t = info.total { which = "part \(n) of \(t)" }
        else if let n = info.number { which = "part \(n)" }
        else { which = "a part" }
        return "Concatenation \(info.uid): this file is \(which) and was analyzed alone — "
            + "text that appears only in another part was not detected. Process the whole "
            + "concatenation in one directory run for cross-part coverage."
    }

    /// Detects (and classifies) text in one file without cleaning, for the batch
    /// pre-pass. Returns the redact-verdict regions and the concatenation info.
    public func sweep(fileData: Data, options: Options) throws -> (info: ConcatenationInfo?, regions: [PixelRedactionPlan.Region]) {
        let file = try DICOMFile.read(from: fileData)
        let info = Self.concatenationInfo(of: file.dataSet)
        var probe = options
        probe.cleanPixelData = false
        probe.explicitRegions = []
        probe.presetDetectedRegions = []
        probe.concatenationAnalyzedCompletely = true
        let report = try run(fileData: fileData, options: probe, dryRun: true)
        let regions = TextRegionDetector.unionedRegions(
            zip(report.detections, report.verdicts).filter { $0.1.isRedact }.map(\.0))
        return (info, regions)
    }

    /// Directory-mode pre-pass: unions detected regions across every part of each
    /// concatenation so the union can be applied to every part (§4.4).
    public struct ConcatenationSweep: Sendable {
        public private(set) var regions: [String: [PixelRedactionPlan.Region]] = [:]
        public private(set) var partsSeen: [String: Set<Int>] = [:]
        public private(set) var totals: [String: Int] = [:]

        public init() {}

        public mutating func add(_ info: ConcatenationInfo, regions found: [PixelRedactionPlan.Region]) {
            var union = regions[info.uid] ?? []
            for r in found where !union.contains(r) { union.append(r) }
            regions[info.uid] = union
            if let n = info.number { partsSeen[info.uid, default: []].insert(n) }
            if let t = info.total { totals[info.uid] = t }
        }

        public func regions(for uid: String) -> [PixelRedactionPlan.Region] { regions[uid] ?? [] }

        /// True when every declared part of the concatenation was swept.
        public func isComplete(_ uid: String) -> Bool {
            guard let total = totals[uid], let seen = partsSeen[uid] else { return false }
            return seen.count >= total && (1...total).allSatisfy { seen.contains($0) }
        }
    }

    /// Marks an output the operator chose to write **with detected text still in the
    /// pixels** (`--allow-burned-in-phi`). The header pass asserts Patient Identity
    /// Removed = YES for the data set alone; PS3.15 conditions YES on the whole object,
    /// so a file the tool *knows* carries burned-in text must say NO — and Burned In
    /// Annotation = YES, because that is now an observed fact, not a declaration.
    public static func markDetectedTextRetained(in dataSet: inout DataSet) {
        dataSet.setString("NO", for: Tag(group: 0x0012, element: 0x0062), vr: .CS)
        dataSet.setString("YES", for: .burnedInAnnotation, vr: .CS)
    }

    /// Runs detection and (unless `dryRun`) redaction over one file's bytes.
    ///
    /// - Throws: ``TextDetectionError`` when OCR was requested and cannot run;
    ///   ``PixelRedactionError/unresolvedRegion(_:)`` when cleaning was requested but
    ///   no source resolved a region; any read/decode error.
    public func run(fileData: Data, options: Options, dryRun: Bool) throws -> Report {
        let file = try DICOMFile.read(from: fileData)
        let frameCount = max(1, file.dataSet.numberOfFrames ?? 1)
        var notes: [String] = []

        // §4.4 A concatenation instance holds only part of the frame set. Alone, OCR
        // cannot see text that appears only in another part — say so, never claim
        // exhaustive cleaning.
        if options.detectText != nil, !options.concatenationAnalyzedCompletely,
           let info = Self.concatenationInfo(of: file.dataSet) {
            notes.append(Self.concatenationCoverageWarning(info))
        }

        // [3] Harvest PHI terms from the ORIGINAL header, before any scrubbing.
        // [4d] OCR detection — a region source, never a cleaning decision.
        var detections: [TextRegionDetector.Detection] = []
        var verdicts: [PHITextClassifier.Verdict] = []
        var scanned: [Int] = []
        if let mode = options.detectText {
            guard TextRegionDetector.isAvailable else { throw TextDetectionError.unavailable }
            scanned = TextRegionDetector.sampledFrameIndices(
                frameCount: frameCount, allFrames: options.ocrAllFrames)
            detections = try TextRegionDetector(dilation: options.dilation)
                .detect(in: file, frameIndices: scanned)
            switch mode {
            case .all:
                verdicts = detections.map { _ in .redact(reason: "all detected text is redacted") }
            case .classify:
                let classifier = PHITextClassifier(terms: PHITextClassifier.harvestTerms(from: file.dataSet))
                verdicts = classifier.classify(detections)
            }
        }

        guard options.cleaningRequested else {
            return Report(detections: detections, verdicts: verdicts, scannedFrames: scanned, plan: nil,
                          outcome: nil, data: fileData, frameCount: frameCount, warnings: notes)
        }

        // [4] Plan: union of every enabled source. Only redact verdicts contribute a
        // region; a keep verdict can never shrink another source's region. Regions
        // swept from sibling concatenation parts are unioned in as well.
        var detected = TextRegionDetector.unionedRegions(
            zip(detections, verdicts).filter { $0.1.isRedact }.map(\.0))
        for r in options.presetDetectedRegions where !detected.contains(r) { detected.append(r) }
        let plan = PixelRedactionPlan.plan(
            for: file.dataSet, explicitRegions: options.explicitRegions, detectedRegions: detected)

        // [5] Dry-run gate: plan built, nothing executed. An unresolved plan is still
        // surfaced as the error it would be, so a dry run predicts the real run.
        if dryRun {
            if case .unresolved(let reason) = plan.decision {
                throw PixelRedactionError.unresolvedRegion(reason)
            }
            return Report(detections: detections, verdicts: verdicts, scannedFrames: scanned, plan: plan,
                          outcome: nil, data: fileData, frameCount: frameCount, warnings: notes)
        }

        // [6]–[10] Decode, mask every frame, strip side channels, attest.
        if let (redacted, outcome) = try PixelRedactor().redact(
            fileData: fileData, plan: plan, fillValue: options.fillValue, style: options.style) {
            return Report(detections: detections, verdicts: verdicts, scannedFrames: scanned, plan: plan,
                          outcome: outcome, data: redacted, frameCount: frameCount, warnings: notes)
        }
        return Report(detections: detections, verdicts: verdicts, scannedFrames: scanned, plan: plan,
                      outcome: nil, data: fileData, frameCount: frameCount, warnings: notes)
    }
}

/// Argument pre-processing shared by the CLI (and any front end that mirrors it).
public enum AnonArguments {
    /// Rewrites `--detect-text=MODE` into `--detect-text --detect-text-mode MODE` so the
    /// documented shorthand parses; every other argument passes through unchanged.
    public static func expandDetectText(_ arguments: [String]) -> [String] {
        var out: [String] = []
        for arg in arguments {
            if arg.hasPrefix("--detect-text=") {
                out.append("--detect-text")
                out.append("--detect-text-mode")
                out.append(String(arg.dropFirst("--detect-text=".count)))
            } else {
                out.append(arg)
            }
        }
        return out
    }
}
