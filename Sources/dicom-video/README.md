# dicom-video

Convert H.264/AVC, H.265/HEVC and MPEG-2 video to and from DICOM Video IODs.

`dicom-video` **remuxes**: it rewraps an already-conformant bitstream without
re-encoding it. This is lossless and fast. Non-conformant input is rejected with
the specific violated constraint and a copy-pasteable remedy, never silently
re-encoded — re-encoding degrades diagnostic pixel data on every pass.

`dicom-image` is the still-image counterpart; image sequences belong there.

## Commands

```
dicom-video convert <input> --output <out.dcm>
dicom-video batch   <input-dir> --output-dir <dir>
dicom-video extract <in.dcm> --output <out.mp4>
dicom-video probe   <input>
```

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Success |
| `1`  | I/O or usage error |
| `2`  | Conformance rejection — the input is readable but not DICOM-legal |

The split lets scripts tell "broken" from "not DICOM-legal".

## convert

```bash
dicom-video convert clip.mp4 --output clip.dcm \
    --patient-name "Doe^Jane" --patient-id MRN-1
```

The transfer syntax is detected from the bitstream. Level 4.1 (`…4.102`) is
preferred, falling back to Level 4.2 (`…4.104`) for 1080p60, which Level 4.1
cannot represent. Rows, Columns, Number of Frames, frame rate and bit depth are
all read from the bitstream, so the attributes cannot contradict the pixel data.

Useful flags:

- `--type endoscopic|microscopic|photographic` — selects the SOP class. Defaults
  to `endoscopic` (modality `ES`) and prints a notice when it does, because a
  wrong guess yields a valid but mislabelled object.
- `--dry-run` — probe and validate, write nothing.
- `--transfer-syntax <uid>` — override detection. The override is still
  validated; a mislabelled object is worse than a rejected one.
- `--frame-rate <fps>` — override the probed rate, then validate against it.
- `--trust-input` — encapsulate an MPEG-TS payload without validating it.
  Requires an explicit `--transfer-syntax`, since nothing was read.

## batch

```bash
dicom-video batch clips/ --output-dir out/ --patient-name "Doe^Jane"
```

Clips convert in natural-sort order, so `clip2` precedes `clip10`.

`--series-mode single` (the default) puts every clip in one series. IHE
Endoscopy Image Archiving §3.10.4.1.1.1 makes this correct rather than merely
convenient: one procedure step on one piece of equipment is one series, and that
holds even when the endoscope is swapped mid-procedure.

`--series-mode per-file` gives each clip its own series, for clips from
different procedure steps or different equipment, where IHE *requires* separate
series. Combining it with `--series-uid` is rejected as contradictory.

Failure is fail-fast by default, so a half-populated series is never left
behind. `--continue-on-error` converts what it can, prints a summary and exits
`2`; skipped clips leave no gaps in `InstanceNumber`.

## extract

```bash
dicom-video extract clip.dcm --output clip.mp4
```

Returns the encapsulated bitstream byte-for-byte. The payload keeps the
container it was encapsulated with, so an MP4 comes back an MP4; the suggested
extension follows the payload's own bytes.

## probe

```bash
dicom-video probe clip.mp4
```

Reports container, codec, profile, level, resolution, chroma, bit depth, frame
rate, frame count and the transfer syntax that fits — then the conformance
verdict. Exits `2` when the stream is not DICOM-legal, so `probe` answers "why
was this rejected?" without producing an object.

## What gets rejected, and why

Video DICOM is unusually strict. Each of these names the observed value, the
expected value and a remedy:

- **Profile** must match exactly. H.264 Baseline and Main are rejected.
- **Level** must not exceed the transfer syntax ceiling.
- **Chroma** must be 4:2:0. 4:2:2 and 4:4:4 are rejected.
- **Bit depth** must be 8 or 10, and must match the transfer syntax.
- **Pixels must be square.** DICOM cannot express anamorphic video, because
  Pixel Aspect Ratio (0028,0034) must be absent (PS3.5 §8.2.7).
- **Container** must be MP4 or MPEG-TS (PS3.5 §8.2.7). A `.mov` is not MP4.
- **BD-compatible** (`…4.103`) additionally requires a resolution and frame-rate
  combination from PS3.5 Table 8-4.

## References

- PS3.5 §8.2.5–8.2.11 — video encoding constraints, Table 8-4
- PS3.5 §A.4 — encapsulation of encoded pixel data
- PS3.3 §A.32.5 — Video Endoscopic Image IOD
- IHE Endoscopy Image Archiving (EIA) Rev. 1.1 §3.10.4.1.1.1 — series grouping
