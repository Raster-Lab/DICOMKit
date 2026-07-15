# DICOMKit v2.2.10

Feature release adding deterministic J2K GPU/CPU encode routing and a CharLS JPEG-LS
bench peer, plus a recompression correctness fix.

## J2K GPU/CPU Encode Route Planner

- Introduced `J2KRoutePlanner`, which resolves the three previously conflated encode
  choices — backend (`CPU`/`GPU`/`auto`), intent (`lossy`/`lossless`/`lossless-only`),
  and compression type (JPEG 2000 Part-1/Part-2/HTJ2K) — into a single deterministic
  J2KSwift API call instead of reverse-engineering them from the transfer-syntax UID.
  `auto` now genuinely selects the Metal GPU backend for lossy JPEG 2000/HTJ2K encodes
  where previously it never did. See `J2K_ROUTING_ARCHITECTURE.md`.
- JPEG 2000 Part-2 (`.92`/`.93`) *encoding* is explicitly rejected with a clear error —
  the pinned J2KSwift v11.0.2 cannot decode the Part-2 codestreams it encodes — while
  *decoding* existing Part-2 files remains fully supported; the real-Part-2 encode path
  is gated behind a flag for when the library gains decode support.
- Updated `CodecBackend`/`CompressionManager`/`CompressionConsole` wiring and added
  `J2KRoutePlannerTests` and `J2KGPUEncodeRoundTripTests` covering the new routing
  decisions and GPU round-trip correctness.

## CharLS (dcmdjpls) JPEG-LS Bench Peer, `repro12bit` Repro Tool

- Added `CharLSCLICodec` (macOS-only), a decode-only DICOMStudio bench peer that wraps
  DCMTK's `dcmdjpls` to cross-validate JLSwift-produced JPEG-LS codestreams against a
  CharLS-backed reference decoder, matching the existing `binaryPath`/`version`/
  `decodeFrame` surface used by the other CLI peers (djpeg/djxl/Kakadu/Grok).
- Wired `.charls` through the JPEG-LS bench family (`includeCharLS`), and
  `J2KBenchSyntax.all` is now derived entirely from `TransferSyntax.selectableEncodings`
  for every format (previously only JPEG 2000/HTJ2K rows were catalog-driven),
  excluding JPEG XL JPEG Recompression (`.111`) since the bench encodes raw frames
  rather than repacking an existing JPEG.
- Added `repro12bit`, a standalone executable target for reproducing/isolating 12-bit
  codec issues against J2KSwift, alongside `JLISWIFT_GAP_ANALYSIS.md` documenting a
  verified bit-depth, color/sampling, and gap audit of the JLISwift dependency (no
  critical/high findings).
- `CompressionQuality.expectedMinPSNRDb` gives each encode preset a conservative
  minimum-PSNR pass bar for lossy round-trip tests, so the bench's
  `lossyPSNRThresholdDb` default now tracks `J2KTestBenchService.lossyEncodeQuality`
  instead of a fixed 40 dB value a lower-quality preset could never clear.
- `ModalityMapping.StandardModality`/`allCodes` centralizes the canonical DICOM
  modality list; the CLI Workshop's modality pickers now draw their `allowedValues`
  from it instead of hand-maintained arrays.

## Fixed

- **Same-syntax lossy recompression silently dropped `--quality`.**
  `CompressionManager.isRecompression`/`compressData`/`compressDataWithMetrics` now
  treat a same-UID lossy target with an explicit `quality` as a genuine recompression
  (decode-to-native + re-encode) rather than a byte passthrough. Previously,
  re-compressing an already-JPEG-2000 (or other lossy-encapsulated) file into the
  *same* transfer syntax UID with a new `--quality` silently copied the existing
  codestream through unchanged (input size == output size, ~0 ms), discarding the
  requested quality. Lossless / no-quality same-syntax targets keep the passthrough.

No decoder output, ABI, or existing command behavior changed outside of the routing
and recompression fixes described above.

Validation used Swift 6.3.3 on macOS. The repository release workflow repeats the
release build and test gates with Swift 6.2 or newer before publishing artifacts.
