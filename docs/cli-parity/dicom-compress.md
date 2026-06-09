# dicom-compress

_CLI binary:_ `dicom-compress` · _category:_ FILE_PROCESSING · _wired in Studio:_ yes · _network:_ no

**Input-contract parity:** 9/9 CLI flags matched · status **OK** (100%)

**Output behavior:** 61 scenario(s) — 61 success / 0 drift.

## Verified App↔CLI parity

- **Shared DICOMKit engine:** `CompressionManager` (`DICOMKit/Compression`) — both the CLI and DICOMStudio call it (all logic shared); flags with no golden still produce identical output **by construction**.
- **Verdict:** info/backends byte-identical (goldens); compress/decompress produced DICOM byte-identical; app adds a sandbox note under TCC.

> Full per-subcommand/flag detail: [`APP_CLI_PARITY_MATRIX.md`](../../APP_CLI_PARITY_MATRIX.md) · architecture: [`APP_CLI_SHARED_API.md`](../../APP_CLI_SHARED_API.md).

## Flags

| Flag | Kind | Input (UI ↔ CLI) | Type/Default | Output (UI vs CLI) |
|---|---|---|---|---|
| `--backend` | option | ✅ match | ✓ | ✅ success |
| `--codec` | option | ✅ match | ✓ | ✅ success |
| `--decompress` | flag | ✅ match | ✓ | ⊘ not covered (coverage gap — offline-testable, not yet templated) |
| `--json` | flag | ✅ match | ✓ | ✅ success |
| `--output` | option | ✅ match | ✓ | ✅ success |
| `--quality` | option | ✅ match | ✓ | ⊘ not covered (coverage gap — offline-testable, not yet templated) |
| `--recursive` | flag | ✅ match | ✓ | ⊘ not covered (coverage gap — offline-testable, not yet templated) |
| `--syntax` | option | ✅ match | ✓ | ✅ success |
| `--verbose` | flag | ✅ match | ✓ | ✅ success |

## Output scenarios

| Scenario | CLI args | Result |
|---|---|---|
| CT.dcm · auto-art-compress-backend-accelerate | `compress FIXTURE --output OUTPUT --codec rle --backend accelerate` | ✅ success |
| CT.dcm · auto-art-compress-backend-auto | `compress FIXTURE --output OUTPUT --codec rle --backend auto` | ✅ success |
| CT.dcm · auto-art-compress-backend-metal | `compress FIXTURE --output OUTPUT --codec rle --backend metal` | ✅ success |
| CT.dcm · auto-art-compress-backend-scalar | `compress FIXTURE --output OUTPUT --codec rle --backend scalar` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec- | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-deflate | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-explicit-le | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-htj2k | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-htj2k-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-htj2k-lossless-rpcl | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-htj2k-lossy | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-htj2k-rpcl | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-implicit-le | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-j2k | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-j2k-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-j2k-part2 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-j2k-part2-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg-baseline | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg-extended | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg-lossless-sv1 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg2000 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-jpeg2000-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-batchCodec-rle | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| CT.dcm · auto-art-compress-verbose | `compress FIXTURE --output OUTPUT --codec rle --verbose` | ✅ success |
| CT.dcm · compress-rle | `compress FIXTURE -c rle --output OUTPUT` | ✅ success |
| CT.dcm · info | `info FIXTURE` | ✅ success |
| CT.dcm · info-json | `info --json FIXTURE` | ✅ success |
| dicom-compress · backends | `backends` | ✅ success |
| dicom-compress · backends-json | `backends --json` | ✅ success |
| syn-ct-rle.dcm · decompress-rle | `decompress FIXTURE --output OUTPUT --syntax explicit-le` | ✅ success |
| syn-ct.dcm · auto-art-compress-backend-accelerate | `compress FIXTURE --output OUTPUT --codec rle --backend accelerate` | ✅ success |
| syn-ct.dcm · auto-art-compress-backend-auto | `compress FIXTURE --output OUTPUT --codec rle --backend auto` | ✅ success |
| syn-ct.dcm · auto-art-compress-backend-metal | `compress FIXTURE --output OUTPUT --codec rle --backend metal` | ✅ success |
| syn-ct.dcm · auto-art-compress-backend-scalar | `compress FIXTURE --output OUTPUT --codec rle --backend scalar` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec- | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-deflate | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-explicit-le | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-htj2k | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-htj2k-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-htj2k-lossless-rpcl | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-htj2k-lossy | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-htj2k-rpcl | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-implicit-le | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-j2k | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-j2k-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-j2k-part2 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-j2k-part2-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg-baseline | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg-extended | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg-lossless-sv1 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg2000 | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-jpeg2000-lossless | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-batchCodec-rle | `compress FIXTURE --output OUTPUT --codec rle` | ✅ success |
| syn-ct.dcm · auto-art-compress-verbose | `compress FIXTURE --output OUTPUT --codec rle --verbose` | ✅ success |
| syn-ct.dcm · compress-rle | `compress FIXTURE -c rle --output OUTPUT` | ✅ success |
| syn-ct.dcm · info | `info FIXTURE` | ✅ success |
| syn-ct.dcm · info-json | `info --json FIXTURE` | ✅ success |

---
_Legend — Input:_ ✅ match · ⚠️ missing in UI · ➕ extra in UI (drift). _Output:_ ✅ success · ❌ drift · ⊘ not covered *(reason: network · non-deterministic · coverage gap · no-write preview)* · — not wired. The **Verified App↔CLI parity** block above is the durable verdict for ALL flags (incl. uncovered). Generated by `swift run cli-parity-docs` (in-process, from bundled contracts + goldens)._
