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

    /// OCR mode. Until the classifier ships (Phase 3), `classify` behaves as `all`
    /// — over-redaction is the safe direction.
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

        public init(
            cleanPixelData: Bool = false,
            explicitRegions: [PixelRedactionPlan.Region] = [],
            detectText: TextDetectionMode? = nil,
            ocrAllFrames: Bool = false,
            fillValue: Int? = nil,
            dilation: Int = TextRegionDetector.defaultDilation
        ) {
            self.cleanPixelData = cleanPixelData
            self.explicitRegions = explicitRegions
            self.detectText = detectText
            self.ocrAllFrames = ocrAllFrames
            self.fillValue = fillValue
            self.dilation = dilation
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
        /// Detected text the run will **not** blank. Non-empty means the caller must
        /// refuse to write an output file unless the operator accepted the risk.
        public var detectedButUnredacted: [TextRegionDetector.Detection] {
            guard !detections.isEmpty else { return [] }
            guard let plan, case .redact(let regions, _) = plan.decision else { return detections }
            return detections.filter { d in !regions.contains(d.region) }
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

        // [4d] OCR detection — a region source, never a cleaning decision.
        var detections: [TextRegionDetector.Detection] = []
        var scanned: [Int] = []
        if options.detectText != nil {
            guard TextRegionDetector.isAvailable else { throw TextDetectionError.unavailable }
            scanned = TextRegionDetector.sampledFrameIndices(
                frameCount: frameCount, allFrames: options.ocrAllFrames)
            detections = try TextRegionDetector(dilation: options.dilation)
                .detect(in: file, frameIndices: scanned)
        }

        guard options.cleaningRequested else {
            return Report(detections: detections, scannedFrames: scanned, plan: nil,
                          outcome: nil, data: fileData, frameCount: frameCount)
        }

        // [4] Plan: union of every enabled source. Interim (Phases 1–2): every detected
        // region is redacted regardless of mode; the classifier will refine `classify`.
        let detected = TextRegionDetector.unionedRegions(detections)
        let plan = PixelRedactionPlan.plan(
            for: file.dataSet, explicitRegions: options.explicitRegions, detectedRegions: detected)

        // [5] Dry-run gate: plan built, nothing executed. An unresolved plan is still
        // surfaced as the error it would be, so a dry run predicts the real run.
        if dryRun {
            if case .unresolved(let reason) = plan.decision {
                throw PixelRedactionError.unresolvedRegion(reason)
            }
            return Report(detections: detections, scannedFrames: scanned, plan: plan,
                          outcome: nil, data: fileData, frameCount: frameCount)
        }

        // [6]–[10] Decode, mask every frame, strip side channels, attest.
        if let (redacted, outcome) = try PixelRedactor().redact(
            fileData: fileData, plan: plan, fillValue: options.fillValue) {
            return Report(detections: detections, scannedFrames: scanned, plan: plan,
                          outcome: outcome, data: redacted, frameCount: frameCount)
        }
        return Report(detections: detections, scannedFrames: scanned, plan: plan,
                      outcome: nil, data: fileData, frameCount: frameCount)
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
