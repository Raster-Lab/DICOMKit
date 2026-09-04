import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMAnon: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-anon",
        abstract: "Anonymize DICOM files by removing or replacing patient identifiers",
        discussion: """
            Anonymizes DICOM files according to various profiles to protect patient privacy.
            Supports multiple anonymization strategies and batch processing.
            
            Examples:
              dicom-anon file.dcm --output anon.dcm --profile basic
              dicom-anon file.dcm --output anon.dcm --profile basic --shift-dates 100
              dicom-anon input_dir/ --output anon_dir/ --profile clinical-trial --recursive
              dicom-anon file.dcm --output anon.dcm --remove 0010,0010 --replace 0010,0030=19700101
              dicom-anon file.dcm --profile basic --dry-run
              dicom-anon file.dcm --output anon.dcm --profile basic --audit-log anonymization.log
              dicom-anon file.dcm --detect-text                       (OCR inspection only)
              dicom-anon file.dcm --output anon.dcm --profile ps315 --clean-pixel-data --detect-text
              dicom-anon file.dcm --dry-run --clean-pixel-data --detect-text --redact-region 0,0,1024,90
            """,
        version: "1.0.0"
    )
    
    @Argument(help: "Path to DICOM file or directory")
    var inputPath: String
    
    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String?
    
    @Option(name: .long, help: "Anonymization profile: basic, clinical-trial, research, ps315 (PS3.15 Annex E)")
    var profile: String = "basic"

    // PS3.15 Annex E retention options (only apply to --profile ps315).
    @Flag(name: .long, help: "PS3.15: Retain Longitudinal Temporal Information (keep/shift dates)")
    var retainDates: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Patient Characteristics (age/sex/size/weight)")
    var retainCharacteristics: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Device Identity")
    var retainDevice: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain Institution Identity")
    var retainInstitution: Bool = false

    @Flag(name: .long, help: "PS3.15: Retain UIDs (do not regenerate)")
    var retainUids: Bool = false

    @Flag(name: .long, help: "PS3.15: Clean Descriptors (retain free-text rather than remove)")
    var cleanDescriptors: Bool = false

    @Flag(name: .long, help: """
        PS3.15: Clean Pixel Data — blank burned-in identifiers out of the image itself. \
        Chooses the region automatically (declared clinical region, else device template) \
        and REFUSES rather than guessing when it cannot. Records code 113101 and sets \
        Burned In Annotation = NO only when pixels were actually blanked.
        """)
    var cleanPixelData: Bool = false

    @Option(name: .long, help: """
        Region to blank as x,y,width,height (repeatable). Implies --clean-pixel-data; \
        unioned with automatic region selection and OCR (no source shrinks another).
        """)
    var redactRegion: [String] = []

    @Option(name: .long, help: "Fill value for blanked pixels (default: 0 = black)")
    var redactFill: Int?

    @Option(name: .long, help: """
        What a cleaned region shows: blank (fill value only, default), label (a fixed \
        stamp drawn INTO the already-blanked box, so reviewers see it was cleaned \
        deliberately), or replace (the header engine's own anonymized value for the \
        matched attribute — name, ID, shifted date — so pixels and header tell one \
        story; needs --detect-text classify; uncertain regions and attributes the header \
        policy removes get the label instead). The region is always blanked first.
        """)
    var redactStyle: String = "blank"

    @Option(name: .long, help: "Stamp text for --redact-style label (default: REDACTED)")
    var redactLabel: String?

    @Option(name: .long, help: """
        Re-encode the CLEAN pixels after redaction: 'source' mirrors the input transfer \
        syntax (lossless sources round-trip exactly outside the redacted regions; lossy \
        sources are re-quantized — second-generation loss, header ratio/method updated), \
        or any dicom-compress codec name (jpeg-ls, rle, jpeg2000-lossless, …). Without \
        this the output is Explicit VR Little Endian, universally readable but larger for \
        a compressed cine. Syntaxes this toolkit cannot encode fall back to Explicit VR LE \
        with a console note. The redacted regions are re-verified blank after re-encoding.
        """)
    var recompress: String?

    @Flag(name: .long, help: """
        Detect burned-in text with on-device OCR (Apple Vision) as a region source. \
        Does NOT imply cleaning: alone (no --output) it inspects and reports; with \
        --output but without --clean-pixel-data the run is REFUSED because the tool \
        now knows the pixels carry text. With --clean-pixel-data every detected region \
        is blanked on every frame. Accepts --detect-text=classify|all as a shorthand \
        for --detect-text-mode.
        """)
    var detectText: Bool = false

    @Option(name: .long, help: """
        OCR mode: classify (default) redacts text matching the file's own PHI (names, \
        IDs, dates, institution), PHI-shaped patterns and anything uncertain, keeping \
        only positively allowlisted clinical text (laterality, units, technique); all \
        blanks every detected region.
        """)
    var detectTextMode: String = "classify"

    @Flag(name: .long, help: "OCR every frame instead of the first/middle/last sample")
    var ocrAllFrames: Bool = false

    @Option(name: .long, help: "Number of days to shift dates (preserves intervals)")
    var shiftDates: Int?
    
    @Flag(name: .long, help: "Regenerate UIDs while preserving references")
    var regenerateUids: Bool = false
    
    @Option(name: .long, help: "Tags to remove (format: 0010,0010 or name)")
    var remove: [String] = []
    
    @Option(name: .long, help: "Tags to replace (format: 0010,0010=VALUE)")
    var replace: [String] = []
    
    @Option(name: .long, help: "Tags to keep (preserve from anonymization)")
    var keep: [String] = []
    
    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Preview changes without modifying files")
    var dryRun: Bool = false
    
    @Flag(name: .long, help: "Create backup of original files")
    var backup: Bool = false
    
    @Option(name: .long, help: "Path to audit log file")
    var auditLog: String?
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false

    @Flag(name: .long, help: """
        Proceed even when the pixels may still carry PHI (Burned In Annotation = YES, \
        overlay planes present, or OCR-detected text this run leaves unredacted). \
        Without this, such files are refused unwritten. The output is marked \
        Patient Identity Removed = NO.
        """)
    var allowBurnedInPHI: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Every input in the CLI's own vocabulary; parsing, validation, the
        // pixel-first ordering, the refusal contract and every console line live
        // in the shared workflow so DICOMStudio's CLI Workshop runs the same code.
        var request = AnonymizationWorkflow.Request(inputPath: inputPath)
        request.output = output
        request.profile = profile
        request.retainDates = retainDates
        request.retainCharacteristics = retainCharacteristics
        request.retainDevice = retainDevice
        request.retainInstitution = retainInstitution
        request.retainUids = retainUids
        request.cleanDescriptors = cleanDescriptors
        request.cleanPixelData = cleanPixelData
        request.redactRegion = redactRegion
        request.redactFill = redactFill
        request.redactStyle = redactStyle
        request.redactLabel = redactLabel
        request.recompress = recompress
        request.detectText = detectText
        request.detectTextMode = detectTextMode
        request.ocrAllFrames = ocrAllFrames
        request.shiftDates = shiftDates
        request.regenerateUids = regenerateUids
        request.remove = remove
        request.replace = replace
        request.keep = keep
        request.recursive = recursive
        request.dryRun = dryRun
        request.backup = backup
        request.auditLog = auditLog
        request.force = force
        request.allowBurnedInPHI = allowBurnedInPHI
        request.verbose = verbose

        let outcome = try AnonymizationWorkflow().run(request) { print($0, terminator: "") }

        // Exit with error if any failures
        if outcome.exitCode != 0 {
            throw ExitCode.failure
        }
    }
}

// `--detect-text=classify|all` is the documented shorthand; ArgumentParser flags take
// no value, so rewrite it into the flag + mode pair before parsing.
DICOMAnon.main(AnonArguments.expandDetectText(Array(CommandLine.arguments.dropFirst())))
