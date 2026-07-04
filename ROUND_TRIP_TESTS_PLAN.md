# CLI Round-Trip Test Plan

Oracle-based functional tests for all non-network `dicom-*` CLI tools.

Companion to [`APP_CLI_PARITY_MATRIX.md`](APP_CLI_PARITY_MATRIX.md) and the
parity harness at `Scripts/cli-parity.sh`.

---

## Why Round-Trip Tests

Parity tests (CLI vs Studio) verify that **two surfaces agree**. They cannot
catch bugs shared by both surfaces. The invert bug (`dicom-pixedit --invert`)
is the canonical example: parity was PASS because both CLI and Studio applied
the same wrong VOI-window update, yet the output image was semantically wrong.

Round-trip tests use an **oracle** — a mathematical invariant or semantic
predicate that is correct by definition — independent of any implementation:

| Bug type | Parity | Round-trip |
|---|---|---|
| Wrong math in `applyInvert` VOI window | PASS (both wrong) | **FAIL** `out+in ≠ maxValue` |
| `--invert` wired to wrong operation | PASS if studio also wired wrong | **FAIL** output not inverted |
| Crop doesn't update rows/columns tag | PASS if both forget | **FAIL** rows tag wrong |
| Lossless codec introduces pixel error | PASS if both corrupt | **FAIL** `decompress ≠ original` |
| Anonymize leaves PHI | PASS if studio also leaves it | **FAIL** PHI still present |

**Core rule: the oracle is a mathematical or semantic fact, never a comparison
to another code surface.**

---

## Implementation order

`dicom-compress` and `dicom-convert` are **implemented last**. They are under
active development (codec + transfer-syntax work), so their DICOMKit API surface
is still changing; pinning tests to it now would churn. All other tools are
implemented first against their stable API, then compress/convert are added once
their API settles. Live pass/fail status per tool is tracked in
[`ROUND_TRIP_TEST_DATA.md`](ROUND_TRIP_TEST_DATA.md).

---

## Scope

### Covered (this plan)

All local (non-network) tools:

| Tool | Category |
|---|---|
| `dicom-pixedit` | Pixel editing |
| `dicom-compress` | Compression |
| `dicom-convert` | Transfer syntax / image export |
| `dicom-anon` | Anonymization |
| `dicom-tags` | Tag editing |
| `dicom-merge` | File merge |
| `dicom-split` | File split |
| `dicom-json` | JSON serialization |
| `dicom-xml` | XML serialization |
| `dicom-info` / `dicom-dump` | Metadata display |
| `dicom-diff` | File comparison |
| `dicom-validate` | Conformance |
| `dicom-dcmdir` | DICOMDIR |
| `dicom-uid` | UID utilities |
| `dicom-pdf` | Encapsulated PDF |
| `dicom-archive` | Local archive |
| `dicom-export` | Image export |
| `dicom-image` | Image → Secondary Capture |
| `dicom-j2k` | J2K/HTJ2K codestream |
| `dicom-measure` | ROI measurements |
| `dicom-script` | Workflow scripting |
| `dicom-study` | Study organization |

### Explicitly skipped

Network tools require a live DICOM server and are covered by integration/parity
tests instead:

`dicom-echo`, `dicom-send`, `dicom-qr`, `dicom-query`, `dicom-retrieve`,
`dicom-server`, `dicom-mwl`, `dicom-mpps`, `dicom-print`, `dicom-gateway`,
`dicom-wado`, `dicom-cloud` (cloud credentials).

Removed from this plan (insufficient testable surface without external dependencies):

- `dicom-report` — SR report output is display-only; no re-parseable semantic artifact; output format correctness is a UI concern, not an oracle.
- `dicom-viewer` — terminal rendering output (`ascii`/`ansi`/iterm2/kitty/sixel) has no machine-verifiable oracle without a reference renderer.
- `dicom-3d` — MPR/MIP/surface/volume pipeline requires a valid volumetric series and a 3D rendering backend; output images have no pixel-exact oracle.
- `dicom-jpip` — only the `uri` subcommand is testable without a JPIP server, and that is a trivial string extraction with no semantic oracle beyond round-trip fidelity.
- `dicom-ai` — only the `registry` subcommand is testable without an external `.mlmodel`; registry list format is not a semantic oracle for inference correctness.

---

## Part 1 — Test Target Setup

### 1.1 Package.swift addition

Add to the `targets` array in `Package.swift`:

```swift
.testTarget(
    name: "DICOMRoundTripTests",
    dependencies: [
        "DICOMKit",
        "DICOMCore",
        "DICOMDictionary",
        "DICOMWeb",   // dicom-json / dicom-xml encoders live here
    ],
    // NOTE: path is singular "DICOMRoundTripTest" — the anonymized corpus was
    // uploaded there (Tests/DICOMRoundTripTest/Corpus/). Target name stays plural.
    // Corpus is resolved at runtime via #filePath (skip-if-absent), NOT bundled,
    // so it must be excluded from the compiled sources.
    path: "Tests/DICOMRoundTripTest",
    exclude: ["Corpus"]
),
```

### 1.2 Directory structure

```
Tests/
└── DICOMRoundTripTest/                   ← singular (corpus already lives here)
    ├── Corpus/                           ← 5 anonymized real DICOM files
    ├── RoundTripFixture.swift            ← shared helpers + corpus loader (Part 2)
    ├── PixelEditRoundTripTests.swift
    ├── CompressRoundTripTests.swift
    ├── ConvertRoundTripTests.swift
    ├── AnonRoundTripTests.swift
    ├── TagsRoundTripTests.swift
    ├── MergeRoundTripTests.swift
    ├── SplitRoundTripTests.swift
    ├── JSONRoundTripTests.swift
    ├── XMLRoundTripTests.swift
    ├── InfoDumpRoundTripTests.swift
    ├── DiffRoundTripTests.swift
    ├── ValidateRoundTripTests.swift
    ├── DcmdirRoundTripTests.swift
    ├── UIDRoundTripTests.swift
    ├── PDFRoundTripTests.swift
    ├── ArchiveRoundTripTests.swift
    ├── ExportRoundTripTests.swift
    ├── ImageRoundTripTests.swift
    ├── J2KRoundTripTests.swift
    ├── MeasureRoundTripTests.swift
    ├── ScriptRoundTripTests.swift
    └── StudyRoundTripTests.swift
```

---

## Part 2 — Shared Infrastructure

### 2.1 `RoundTripFixture.swift`

```swift
import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore
@testable import DICOMDictionary

// MARK: - Synthetic DICOM builders

/// 8-bit MONOCHROME2, pixel[i] = fillPattern(i).
func makeGrayscale8(
    rows: UInt16, cols: UInt16,
    fillPattern: (Int) -> UInt8 = { UInt8($0 % 256) }
) -> DICOMFile {
    var ds = DataSet()
    ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
    ds.setString(generateUID(), for: .sopInstanceUID, vr: .UI)
    ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
    ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
    ds.setString("CT", for: .modality, vr: .CS)
    ds.setString("RoundTrip^Patient", for: .patientName, vr: .PN)
    ds.setString("RT001", for: .patientID, vr: .LO)
    ds.setUInt16(rows, for: .rows)
    ds.setUInt16(cols, for: .columns)
    ds.setUInt16(8, for: .bitsAllocated)
    ds.setUInt16(8, for: .bitsStored)
    ds.setUInt16(7, for: .highBit)
    ds.setUInt16(0, for: .pixelRepresentation)
    ds.setUInt16(1, for: .samplesPerPixel)
    ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
    let count = Int(rows) * Int(cols)
    let pixels = Data((0..<count).map { fillPattern($0) })
    ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
    return DICOMFile.create(dataSet: ds)
}

/// 16-bit MONOCHROME2, unsigned (pixelRepresentation=0) or signed (=1).
func makeGrayscale16(
    rows: UInt16, cols: UInt16,
    fillPattern: (Int) -> UInt16 = { UInt16($0 % 65536) },
    signed: Bool = false
) -> DICOMFile {
    var ds = DataSet()
    ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
    ds.setString(generateUID(), for: .sopInstanceUID, vr: .UI)
    ds.setString("1.2.3.4.5.100", for: .studyInstanceUID, vr: .UI)
    ds.setString("1.2.3.4.5.200", for: .seriesInstanceUID, vr: .UI)
    ds.setString("CT", for: .modality, vr: .CS)
    ds.setString("RoundTrip^Patient", for: .patientName, vr: .PN)
    ds.setString("RT001", for: .patientID, vr: .LO)
    ds.setUInt16(rows, for: .rows)
    ds.setUInt16(cols, for: .columns)
    ds.setUInt16(16, for: .bitsAllocated)
    ds.setUInt16(16, for: .bitsStored)
    ds.setUInt16(15, for: .highBit)
    ds.setUInt16(signed ? 1 : 0, for: .pixelRepresentation)
    ds.setUInt16(1, for: .samplesPerPixel)
    ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
    let count = Int(rows) * Int(cols)
    var pixels = Data(count: count * 2)
    for i in 0..<count {
        let v = fillPattern(i)
        pixels[i * 2]     = UInt8(v & 0xFF)
        pixels[i * 2 + 1] = UInt8(v >> 8)
    }
    ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OW, data: pixels)
    return DICOMFile.create(dataSet: ds)
}

/// 3-sample RGB, 8-bit.
func makeRGB8(rows: UInt16, cols: UInt16) -> DICOMFile {
    var ds = DataSet()
    ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
    ds.setString(generateUID(), for: .sopInstanceUID, vr: .UI)
    ds.setUInt16(rows, for: .rows)
    ds.setUInt16(cols, for: .columns)
    ds.setUInt16(8, for: .bitsAllocated)
    ds.setUInt16(8, for: .bitsStored)
    ds.setUInt16(7, for: .highBit)
    ds.setUInt16(0, for: .pixelRepresentation)
    ds.setUInt16(3, for: .samplesPerPixel)
    ds.setString("RGB", for: .photometricInterpretation, vr: .CS)
    let count = Int(rows) * Int(cols) * 3
    let pixels = Data((0..<count).map { UInt8($0 % 256) })
    ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
    return DICOMFile.create(dataSet: ds)
}

/// Multi-frame 8-bit, each frame filled with its frame index (0, 1, ...).
func makeMultiFrame(rows: UInt16, cols: UInt16, frames: Int) -> DICOMFile {
    var ds = DataSet()
    ds.setString("1.2.840.10008.5.1.4.1.1.2", for: .sopClassUID, vr: .UI)
    ds.setString(generateUID(), for: .sopInstanceUID, vr: .UI)
    ds.setUInt16(rows, for: .rows)
    ds.setUInt16(cols, for: .columns)
    ds.setUInt16(8, for: .bitsAllocated)
    ds.setUInt16(8, for: .bitsStored)
    ds.setUInt16(7, for: .highBit)
    ds.setUInt16(0, for: .pixelRepresentation)
    ds.setUInt16(1, for: .samplesPerPixel)
    ds.setString("MONOCHROME2", for: .photometricInterpretation, vr: .CS)
    ds.setString("\(frames)", for: .numberOfFrames, vr: .IS)
    let frameSize = Int(rows) * Int(cols)
    var pixels = Data(count: frameSize * frames)
    for f in 0..<frames {
        let fill = UInt8(f % 256)
        for i in 0..<frameSize { pixels[f * frameSize + i] = fill }
    }
    ds[.pixelData] = DataElement.data(tag: .pixelData, vr: .OB, data: pixels)
    return DICOMFile.create(dataSet: ds)
}

// MARK: - I/O helpers

func writeTempDICOM(_ file: DICOMFile, name: String = "tmp.dcm") throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("DICOMRoundTrip-\(UUID().uuidString)")
        .appendingPathComponent(name)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try file.write()
    try data.write(to: url)
    return url
}

func writeTempFile(_ data: Data, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("DICOMRoundTrip-\(UUID().uuidString)-\(name)")
    try data.write(to: url)
    return url
}

func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("DICOMRoundTrip-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func readJSON(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
}

func countFiles(in dir: URL, extension ext: String) -> Int {
    (try? FileManager.default.contentsOfDirectory(at: dir,
        includingPropertiesForKeys: nil))?.filter { $0.pathExtension == ext }.count ?? 0
}

// MARK: - Pixel access

/// Raw pixel bytes of the native (non-encapsulated) pixel data element.
func pixelBytes(_ file: DICOMFile) -> Data {
    file.dataSet[.pixelData]?.valueData ?? Data()
}

func readU8(_ data: Data, at i: Int) -> UInt8 { data[i] }

func readU16(_ data: Data, at i: Int) -> UInt16 {
    UInt16(data[i * 2]) | (UInt16(data[i * 2 + 1]) << 8)
}

func readI16(_ data: Data, at i: Int) -> Int16 {
    Int16(bitPattern: readU16(data, at: i))
}

// MARK: - UID

private func generateUID() -> String {
    "2.25.\(UInt64.random(in: 1_000_000_000_000_000_000...UInt64.max))"
}
```

---

## Part 3 — Per-Tool Test Specifications

Each section lists: the **DICOMKit API** to call, and for every test case:
the **setup**, the **operation**, and the **oracle** — the assertion that proves
the output is semantically correct.

---

### 3.1 dicom-pixedit

**API**: `PixelEditor(verbose: false).processData(_:operations:)` in `DICOMKit`

#### Invert — 8-bit unsigned

Setup: 1×5 image, pixels `[0, 50, 100, 200, 255]`.  
Op: `.invert`  
Oracle 1: `∀i: output[i] + input[i] == 255`  
Oracle 2 (double-invert): `invert(invert(x)) == x` — pixel-exact original

#### Invert — 16-bit unsigned

Setup: known values `[0, 1000, 32767, 65535]`.  
Oracle: `∀i: output[i] + input[i] == 65535`

#### Invert — 16-bit signed (pixelRepresentation=1)

Setup: `Int16` values `[-32768, -100, 0, 100, 32767]`.  
Oracle 1: `invert(invert(x)) == x`  
Oracle 2: for signed, `output[i] == -(input[i] + 1)` (two's complement NOT)

#### Invert + VOI window update ← the original bug

Setup: 16-bit file with `WindowCenter=500`, `WindowWidth=1000`.  
Op: `.invert`  
Oracle: read `(0028,1050)` from output DataSet; it must NOT equal 500 (must be
updated to reflect the inverted mapping). For unsigned 16-bit with no
slope/intercept: `newCenter == 65535 - 500 == 65035`.  
**This test must fail if PixelEditor does not update the VOI tags.**

#### Mask (fill=0)

Setup: 4×4 image, all pixels=128.  
Op: `.mask(x:1, y:1, width:2, height:2, fillValue:0)`  
Oracle: pixels at (col=1,row=1),(2,1),(1,2),(2,2) == 0; all others == 128

#### Mask — clamp at border (no crash)

Op: mask region extending beyond image boundary.  
Oracle: no throw; result is a valid DICOM; unaffected pixels unchanged.

#### Crop

Setup: 8×8 sequential image (`pixel[i] = i`).  
Op: `.crop(x:2, y:3, width:4, height:2)`  
Oracle: output rows==2, columns==4; `output[0,0] == input[2,3]`;
`output[3,1] == input[5,4]`; DICOM tags `Rows=2`, `Columns=4`.

#### Window/Level bake

Setup: 16-bit, pixels `[0, 500, 1000, 1500, 2000]` (1×5).  
Op: `.windowLevel(center:1000, width:2000)`  
Oracle: `BitsAllocated==8`; `output[0]==0`; `output[4]==255`; `output[2]≈127`

#### Multi-frame invert

Setup: 3-frame 16-bit; frame 0 all=100, frame 1 all=500, frame 2 all=1000.  
Oracle: frame 0 all=65435, frame 1 all=65035, frame 2 all=64535.

---

### 3.2 dicom-compress

**API**: `CompressionManager` in `DICOMKit`

#### Lossless compress → decompress pixel identity

For each lossless codec (JPEG-LS lossless `1.2.840.10008.1.2.4.80`, J2K
lossless `1.2.840.10008.1.2.4.90`, RLE `1.2.840.10008.1.2.5`):  
Op: compress → decompress back to Explicit VR LE  
Oracle: decompressed pixel bytes == original pixel bytes (bit-exact)

#### Lossy compress → PSNR threshold

For JPEG Baseline, JPEGLI, J2K lossy:  
Oracle: PSNR ≥ 40 dB; output rows/columns/bitsAllocated match input

#### Compress preserves non-pixel tags

Input with `PatientName`, `StudyInstanceUID`, `Modality`.  
Oracle: all three tags identical in output; `TransferSyntaxUID` == target TS UID

#### Decompress removes encapsulation

Decompress a JPEG-LS file.  
Oracle: output `TransferSyntaxUID == "1.2.840.10008.1.2.1"`; pixel data is
native (no items/delimiters)

#### Batch: each file gets correct output TS

3 synthetic files → batch compress to JPEG-LS lossless.  
Oracle: all 3 outputs have correct TS; each losslessly round-trips

---

### 3.3 dicom-convert

**API**: `DICOMConverter`, `DICOMImageExporter` in `DICOMKit`

#### Transcode: Implicit VR → Explicit VR LE

Oracle: `TransferSyntaxUID == "1.2.840.10008.1.2.1"`; pixel bytes unchanged

#### Transcode: Explicit VR LE → DEFLATED

TS `1.2.840.10008.1.2.1.99`.  
Oracle: output parseable by `DICOMFile.read(from:)`; pixel bytes match after
re-reading

#### All supported TS round-trips (lossless)

Enumerate `DICOMConverter.supportedTransferSyntaxes`.  
For lossless syntaxes: transcode in → transcode back → pixel-exact

#### Image export: PNG dimensions

Oracle: PNG `pixelWidth == Columns`, `pixelHeight == Rows`

#### Window settings honored in export

16-bit with `WindowCenter=1000, WindowWidth=2000`.  
Oracle: exported PNG differs from a raw (no-window) export; pixel at stored
value=1000 maps to gray≈128

---

### 3.4 dicom-anon

**API**: `DICOMAnonymizer` in `DICOMKit`

#### PHI tags removed / replaced

Input: `PatientName="John^Smith"`, `PatientBirthDate="19800101"`, `PatientID="MRN-123"`.  
Oracle: output PatientName ≠ "John^Smith"; DOB absent or zeroed; PatientID
replaced; SOPInstanceUID ≠ original

#### Non-PHI tags preserved

`Modality`, `Rows`, `BitsAllocated`.  
Oracle: unchanged after anonymization

#### Pixel data unchanged

Oracle: pixel bytes identical to input

#### Retain-UID option

Oracle: SOPInstanceUID == original

---

### 3.5 dicom-tags

**API**: `DICOMTagEditor` (or equivalent) in `DICOMKit`

#### Set a string tag

`PatientName = "Round^Trip^Test"`.  
Oracle: output `PatientName == "Round^Trip^Test"`

#### Delete a tag

Input has `StudyDescription="Original"`.  
Oracle: output has no `StudyDescription` element

#### Set a numeric tag

`SeriesNumber = 42`.  
Oracle: output `SeriesNumber == 42`

---

### 3.6 dicom-merge

**API**: `DICOMFileMerger` (or equivalent) in `DICOMKit`

#### Merge two single-frame files

File A: all-zero pixels. File B: all-255 pixels.  
Oracle: output `NumberOfFrames == 2`; frame 0 all-zero, frame 1 all-255

#### Merge preserves common metadata

Both files: same `PatientName`, same `StudyInstanceUID`.  
Oracle: output has those tags unchanged

---

### 3.7 dicom-split

**API**: `DICOMFileSplitter` (or equivalent) in `DICOMKit`

#### Split multi-frame into single frames

3-frame file; frame N fill=N×10.  
Oracle: 3 output files; each `NumberOfFrames==1`; pixel values match correct frame

#### Merge → split → merge round-trip

Oracle: final pixel bytes == original pixel bytes

---

### 3.8 dicom-json

**API**: `DICOMJSONEncoder` in `DICOMKit`

#### JSON contains known tags

`Modality="MR"`, `Rows=128`.  
Oracle: JSON key `"00080060": { "vr": "CS", "Value": ["MR"] }` present;
Rows value == 128 (DICOM JSON model)

#### Round-trip: JSON → DICOM → JSON

Oracle: all tags preserved after both conversions

---

### 3.9 dicom-xml

**API**: `DICOMXMLEncoder` in `DICOMKit`

#### XML is valid and contains known tags

Oracle: parses with `XMLParser`; Modality element present with correct value

---

### 3.10 dicom-info / dicom-dump

**API**: `DICOMInfoFormatter` / dump formatter in `DICOMKit`

The oracle is `DICOMFile.read(from:)` — parse the same file independently and
compare values.

#### info output matches DICOMCore parsed values

Known `PatientName`, `Modality`, `Rows`, `TransferSyntaxUID`.  
Oracle: output text contains each value; values match what `DICOMFile.read`
returns

#### All required tags appear in dump

File with 20+ tags.  
Oracle: every tag's hex code `(GGGG,EEEE)` appears in dump output; no tag
silently missing

---

### 3.11 dicom-diff

**API**: `DICOMDiff` (or equivalent) in `DICOMKit`

#### Identical files → zero diffs

Diff A against A.  
Oracle: diff count == 0

#### Single tag changed → one diff

A: `PatientName="Original"`, B: same file with `PatientName="Changed"`.  
Oracle: exactly one diff mentioning `PatientName`

#### Added tag

B has extra `StudyDescription` A lacks.  
Oracle: diff reports `StudyDescription` as added

---

### 3.12 dicom-validate

**API**: `DICOMValidator` in `DICOMKit`

#### Valid conformant file → no errors

Oracle: validation returns zero errors

#### Deliberately broken file → error detected

File missing required `SOPClassUID`.  
Oracle: validation reports error mentioning `SOPClassUID`

---

### 3.13 dicom-dcmdir

**API**: `DICOMDIRWorkflow` in `DICOMKit`

#### Create then dump → all input files listed

3 synthetic files → create DICOMDIR → dump.  
Oracle: all 3 SOP Instance UIDs appear in dump output

#### Create then validate → no errors

Oracle: validation passes

---

### 3.14 dicom-uid

**API**: `DICOMUIDGenerator` (or equivalent) in `DICOMKit`

#### Generated UID is syntactically valid

Oracle: matches `^[0-9]+(\.[0-9]+)+$`; length ≤ 64

#### 100 generated UIDs are all unique

Oracle: `Set` count == 100

---

### 3.15 dicom-pdf

**API**: `EncapsulatedDocumentWorkflow` in `DICOMKit`

#### Wrap PDF → valid encapsulated DICOM

Minimal PDF bytes (`%PDF-1.4\n%%EOF`).  
Oracle: `SOPClassUID == "1.2.840.10008.5.1.4.1.1.104.1"`; encapsulated element
starts with `%PDF`; output parseable by `DICOMFile.read`

#### Extract PDF → bytes match original

Wrap then extract.  
Oracle: extracted bytes == original PDF bytes

---

### 3.16 dicom-archive

**API**: `ArchiveStore` in `DICOMKit`

#### init → index file created

Oracle: archive directory exists; index file present; no throw

#### import → list returns correct count

3 files with distinct SOP Instance UIDs → import.  
Oracle: `list()` returns 3 entries with matching UIDs

#### import deduplication

Import same file twice.  
Oracle: `list()` returns exactly 1 entry for that UID

#### import `--skip-duplicates`

Without flag: second import throws.  
With flag: succeeds silently, count stays 1.

#### query by PatientName wildcard

Import "JONES^ALICE", "JONES^BOB", "SMITH^CAROL".  
`query(patientName: "JONES*")`  
Oracle: exactly 2 results; "SMITH^CAROL" not included

#### query by Modality

Import CT + MR files.  
Oracle: `query(modality: "CT")` returns only CT entries

#### export by StudyUID → output files correct

2 files from StudyUID A, 1 from StudyUID B.  
Export StudyUID A.  
Oracle: output dir has exactly 2 `.dcm` files; both have `StudyInstanceUID==A`

#### export → import round-trip: pixel-exact

Oracle: re-imported pixel bytes == original pixel bytes

#### check integrity: valid archive → no errors

Oracle: `check()` returns no errors

#### check integrity: corrupt file detected

Overwrite a stored `.dcm` with garbage.  
Oracle: `check(verifyReadability: true)` flags that file

#### stats counts match imports

3 files across 2 patients.  
Oracle: `stats()` reports `instances: 3`, `patients: 2`

---

### 3.17 dicom-export

**API**: `DICOMImageExporter` in `DICOMKit`

#### single export: PNG dimensions match DICOM

128×64 DICOM → PNG.  
Oracle: PNG `pixelWidth==64`, `pixelHeight==128`

#### single export: JPEG quality affects file size

Quality=10 vs quality=95 export.  
Oracle: `size(quality=10) < size(quality=95)`

#### single export: apply-window vs raw differ

`applyWindow=true` vs `applyWindow=false`.  
Oracle: output byte streams differ

#### single export: embed-metadata adds EXIF

`embedMetadata=true`.  
Oracle: EXIF dictionary from `CGImageSourceCopyPropertiesAtIndex` contains
`PatientName` or `Modality`

#### bulk export: all files exported

4 input files → bulk export.  
Oracle: output dir contains 4 image files; all readable

#### bulk export: organize-by-patient creates subdirs

2 files PatientID="P1", 1 file PatientID="P2".  
Oracle: 2 subdirectories; P1 has 2 files, P2 has 1

#### contact sheet: correct output dimensions

6 DICOM files 32×32, `columns=3`.  
Oracle: output PNG width ≈ 96px, height ≈ 64px; valid PNG

#### animate: valid animated GIF

4-frame DICOM → animated GIF.  
Oracle: file starts with `GIF89a`; `CGImageSourceGetCount` == 4

#### multi-frame: frame index respected

3 frames: fill 0, 128, 255. Export frame 1.  
Oracle: PNG mean pixel ≈ 128

---

### 3.18 dicom-image

**API**: `ImageConverter` in `DICOMKit`

#### PNG → DICOM SC → correct SOP class + dimensions

4×4 synthetic PNG.  
Oracle: `SOPClassUID == "1.2.840.10008.5.1.4.1.1.7"`; `Rows==4`, `Columns==4`

#### metadata flags written to tags

`patientName="ROUND^TRIP"`, `patientID="RT001"`.  
Oracle: output DICOM has `PatientName=="ROUND^TRIP"`, `PatientID=="RT001"`

#### EXIF date mapped to DICOM tag

JPEG with EXIF date `2024:01:15 10:30:00`, `useExif=true`.  
Oracle: output `StudyDate` or `ContentDate` contains "20240115"

#### batch: N images → N DICOM files

3 PNGs → convert.  
Oracle: output dir has 3 `.dcm` files; all readable as DICOM SC

#### auto-generated UIDs unique across batch

5 PNGs, no `--study-uid`.  
Oracle: all 5 output `SOPInstanceUID` values are distinct

#### split-pages: multi-page TIFF → one file per page

3-page TIFF, `splitPages=true`.  
Oracle: 3 output files; each `NumberOfFrames==1`

---

### 3.19 dicom-j2k

**API**: `J2KCore` / `J2KCodec` via the shared path `dicom-j2k` uses

#### info: codestream properties returned

Compress a synthetic image to J2K lossless first.  
Oracle: info output contains width, height, number of decomposition levels
matching original DICOM dimensions

#### info --json: valid JSON with expected keys

Oracle: JSON parses; keys include `width`, `height`, `transferSyntax`;
values match DICOM tags

#### validate: conformant file → no errors

Oracle: no validation errors returned

#### validate: truncated codestream → error detected

Truncate pixel data element at 50% length.  
Oracle: validation reports codestream error; no crash

#### transcode: J2K lossless → HTJ2K lossless (pixel identity)

Compress → transcode → decompress both.  
Oracle: both decompressed pixel sets are identical (lossless throughout)

#### transcode: preserves metadata across hops

Oracle: `Rows`, `Columns`, `BitsAllocated`, `PhotometricInterpretation`
unchanged after J2K→HTJ2K→J2K

#### reduce: fewer decomposition levels in output

5-level J2K → `reduce --levels 3`.  
Oracle: info on output reports 3 levels; dimensions unchanged

#### roi: output has correct dimensions

256×256 J2K, `roi --region 0,0,128,128`.  
Oracle: output `Rows==128`, `Columns==128`

#### compare: identical files → zero error

Oracle: PSNR reported as `inf` or very large; MSE == 0

#### compare: lossy vs original → PSNR > 30 dB, MSE > 0

Oracle: PSNR > 30, MSE > 0

---

### 3.20 dicom-measure

**API**: `MeasurementEngine` in `DICOMKit`

Use `PixelSpacing="1.0\1.0"` throughout so pixel distance == mm distance.

#### distance: Pythagorean theorem

Points (0,0) → (3,4), `unit=.mm`.  
Oracle: result == 5.0 mm (√9+16 × 1.0)

#### distance: pixel unit

Same points, `unit=.pixels`.  
Oracle: result == 5.0 pixels

#### distance: cm unit

Oracle: result == 0.5 cm

#### distance: no PixelSpacing → pixel fallback

File with no `PixelSpacing`.  
Oracle: result in pixels; warning present; no crash

#### area: rectangle

Polygon (0,0)→(10,0)→(10,5)→(0,5).  
Oracle: area == 50.0 mm²

#### area: right triangle

Vertices (0,0), (6,0), (0,8).  
Oracle: area == 24.0 mm²

#### angle: straight line → 180°

Vertex (50,50), p1 (0,50), p2 (100,50).  
Oracle: angle == 180.0°

#### angle: right angle → 90°

Vertex (0,0), p1 (-1,0), p2 (0,1).  
Oracle: angle == 90.0°

#### roi statistics: uniform region

4×4 ROI, all pixels=100.  
Oracle: `mean==100.0`, `min==100`, `max==100`, `stddev==0.0`

#### roi statistics: gradient values

5-pixel ROI: `[0, 50, 100, 150, 200]`.  
Oracle: `mean==100.0`, `min==0`, `max==200`, `stddev≈70.7`

#### hu: slope/intercept applied

`RescaleSlope=1.0`, `RescaleIntercept=-1024.0`; pixel at (5,5) stored=1124.  
Oracle: HU == 100

#### hu: non-CT file → error or note, no crash

MR file, no RescaleSlope.  
Oracle: output mentions "HU not applicable" or equivalent

#### pixel: raw stored value, no slope applied

Pixel at (3,3) == stored 42.  
Oracle: output contains 42; NOT HU-adjusted

#### output format: json

Oracle: JSON parses; contains numeric result

#### output format: csv

Oracle: first row is header; second row contains the result; parseable as CSV

---

### 3.21 dicom-script

**API**: `ScriptEngine` in `DICOMKit`

Inject a **mock command runner** `(String, [String]) throws -> (String, Int32)`
for all tests — do NOT spawn real `dicom-*` processes.

```swift
var callLog: [(tool: String, args: [String])] = []
let mockRunner: (String, [String]) throws -> (String, Int32) = { tool, args in
    callLog.append((tool, args))
    return ("mock output", 0)
}
```

#### validate: well-formed script → no errors

```
LOAD INPUT /tmp/test.dcm
RUN dicom-info /tmp/test.dcm
```
Oracle: `validate()` returns no errors

#### validate: syntax error → error with line info

Unknown keyword.  
Oracle: error mentions the bad keyword or line number

#### template: generates a runnable script

Oracle: non-empty; contains `RUN` or `LOAD`; re-validating produces no errors

#### run: variable substitution works

Script: `VAR PATIENT_ID=12345`, `RUN dicom-info /data/${PATIENT_ID}/scan.dcm`.  
Oracle: mock runner received arg containing "12345", not "${PATIENT_ID}"

#### run: steps execute in order

3 steps.  
Oracle: `callLog` order == [step1, step2, step3]

#### run: step failure stops execution

Mock throws on step 2.  
Oracle: step 3 never called; error reported

#### run `--dry-run`: no commands executed

Oracle: `callLog` is empty after run

#### variable override from CLI

Script: `VAR ENV=staging`. Override: `--var ENV=production`.  
Oracle: mock runner sees "production"

---

### 3.22 dicom-study

**API**: `StudyOrganizer`, `StudySummarizer`, `StudyChecker` in `DICOMKit`

#### organize: Patient/Study/Series hierarchy created

3 files, patient "JONES", study UID "1.2.3", series UID "1.2.3.1".  
`pattern: "descriptive"`  
Oracle: output dir has nested subdirs; all 3 files under the same series leaf;
a subdirectory name contains "JONES"

#### organize: uid pattern uses UIDs as dir names

`pattern: "uid"`  
Oracle: subdir names are UID strings

#### organize `--copy`: source files still exist

Oracle: original files present in input dir after organize

#### organize (move): source files gone

Oracle: input dir empty after organize

#### summary: correct counts

2 studies: A has 2 series × 3 files, B has 1 series × 2 files.  
`format: .json`  
Oracle: 2 studies; A `seriesCount=2, instanceCount=6`; B `seriesCount=1, instanceCount=2`

#### summary: series descriptions in table output

Each series has `SeriesDescription`.  
Oracle: text output contains each description

#### check: all series present → clean

`expectedSeriesCount: 2`; dir has 2 series.  
Oracle: no missing series reported

#### check: missing series detected

`expectedSeriesCount: 5`; dir has 2.  
Oracle: reports 3 missing; mentions expected vs actual count

#### stats: counts match imports

Oracle: output contains instance/series/study counts matching what was imported

#### compare: identical studies → no differences

Oracle: diff is empty

#### compare: added file detected

B has one extra SOP Instance UID.  
Oracle: reports 1 extra instance in B; names its UID

---

## Part 4 — Running the Tests

```bash
# All round-trip tests
swift test --filter DICOMRoundTripTests

# Single tool
swift test --filter DICOMRoundTripTests.PixelEditRoundTripTests

# Single test case
swift test --filter "DICOMRoundTripTests.PixelEditRoundTripTests/testInvertVOIWindowUpdated"
```

Requires a release build of the DICOMKit package (tests call into the library,
not the CLIs directly). Tests that call into `J2KCore`/`J2KCodec` require those
SPM targets to be resolved.

---

## Part 5 — Implementation Checklist

**Status:** all 23 tools implemented and green (**340 tool cases + 3 smoke = 343
executed, 0 failures**), including `dicom-compress` and `dicom-convert` (done last).
Live per-tool status, case counts, and the 2 real bugs found live in
[`ROUND_TRIP_TEST_DATA.md`](ROUND_TRIP_TEST_DATA.md). `dicom-info` and `dicom-dump`
are split into separate files (`InfoRoundTripTests` / `DumpRoundTripTests`).

### Setup
- [x] Add `DICOMRoundTripTests` target to `Package.swift` (path `Tests/DICOMRoundTripTest`)
- [x] Create `Tests/DICOMRoundTripTest/RoundTripFixture.swift` (+ `ScaffoldSmokeTests`)

### Pixel / Image operations
- [ ] `PixelEditRoundTripTests.swift` — 9 test cases including invert+VOI
- [ ] `CompressRoundTripTests.swift` — 5 test cases
- [ ] `ConvertRoundTripTests.swift` — 5 test cases
- [ ] `ExportRoundTripTests.swift` — 8 test cases
- [ ] `ImageRoundTripTests.swift` — 6 test cases
- [ ] `J2KRoundTripTests.swift` — 10 test cases

### Metadata operations
- [ ] `AnonRoundTripTests.swift` — 4 test cases
- [ ] `TagsRoundTripTests.swift` — 3 test cases
- [ ] `JSONRoundTripTests.swift` — 2 test cases
- [ ] `XMLRoundTripTests.swift` — 1 test case
- [ ] `InfoDumpRoundTripTests.swift` — 2 test cases
- [ ] `DiffRoundTripTests.swift` — 3 test cases
- [ ] `ValidateRoundTripTests.swift` — 2 test cases

### Structural operations
- [ ] `MergeRoundTripTests.swift` — 2 test cases
- [ ] `SplitRoundTripTests.swift` — 2 test cases
- [ ] `DcmdirRoundTripTests.swift` — 2 test cases
- [ ] `PDFRoundTripTests.swift` — 2 test cases
- [ ] `UIDRoundTripTests.swift` — 2 test cases
- [ ] `ArchiveRoundTripTests.swift` — 11 test cases

### Analysis / reporting
- [ ] `MeasureRoundTripTests.swift` — 13 test cases

### Workflow / organization
- [ ] `ScriptRoundTripTests.swift` — 8 test cases (mock runner)
- [ ] `StudyRoundTripTests.swift` — 11 test cases

**Implemented: 320 tool cases across 21 files (+3 smoke) — all green.**
(Case counts grew from the ~109 estimate after covering every flag/subcommand
with a real oracle, per the expanded scope. compress/convert added last.)

---

## Part 6 — What This Adds Over Parity Tests

| Bug type | Parity catches? | Round-trip catches? |
|---|---|---|
| Wrong math in any operation (e.g. invert VOI) | No — both surfaces share bug | Yes — oracle fails |
| Flag wired to wrong operation | No | Yes — oracle fails |
| Structural tag not updated (rows/columns after crop) | No | Yes — tag check |
| Lossless codec introduces pixel change | No | Yes — byte comparison |
| Archive deduplication broken | No | Yes — count check |
| Measurement unit conversion wrong | No | Yes — math oracle |
| SR report omits content items | No | Yes — text presence |
| Split produces wrong frame order | No | Yes — pixel comparison |
| Anonymizer leaves PHI | No | Yes — tag value check |
