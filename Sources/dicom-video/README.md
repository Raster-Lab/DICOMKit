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
- `-v, --verbose` — explain each step: the container recognised, why that
  transfer syntax was chosen, where the frame count came from, the UIDs minted
  and how many bytes of the output are payload rather than DICOM overhead.

## Verbose

`-v` / `--verbose` is available on all four subcommands. It answers "why did it
decide that?" without a second run under a debugger:

```console
$ dicom-video convert clip.mp4 --output clip.dcm --verbose
verbose: read 376 bytes; container detected as MP4
verbose: transfer syntax 1.2.840.10008.1.2.4.102 selected from the bitstream's codec, profile and level
verbose: validated the stream against MPEG-4 AVC/H.264 HP @ Level 4.1: conformant
verbose: frame count 300 from sampleTable
verbose: SOP class Video Endoscopic Image Storage
verbose: Study Instance UID  1.2.276.0.7230010.3.1…  (generated)
verbose: encoded 1394 bytes: 376 bytes of bitstream carried unchanged, 1018 bytes of DICOM overhead
Wrote clip.dcm
```

Every verbose line is prefixed `verbose:` and written to **stderr**, so stdout
stays byte-for-byte what a non-verbose run prints and redirection keeps working:

```bash
dicom-video probe clip.mp4 --verbose > report.txt   # report.txt holds only the report
dicom-video batch clips/ --output-dir out/ -v 2>/dev/null   # just the converted list
```

It also explains rejections, which is where it earns its keep — the commentary
gathered before the failure is printed ahead of it, so a rejected clip still
says which container was read. Verbose never changes a message or an exit code.

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

`--verbose` reports the grouping and the series/instance number each clip
received, which is what to check when a series comes out wrong.

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

## Also in DICOMStudio

Everything above — the planning, the validation, the batch orchestration and
every line of console text — lives in `VideoWorkflow` and `VideoConsole` in
`DICOMKit/Video`. This file's `main.swift` is a thin ArgumentParser adapter over
them, and DICOMStudio's **CLI Workshop** is a second adapter over the same two
types, so the terminal and the app cannot drift. `VideoConsoleParityTests` pins
that.

The Studio **viewer** plays these objects directly: a video instance carries an
*image* SOP Class, so the transfer syntax is what identifies it, and the
extracted bit stream — the same passthrough `extract` performs — is handed to a
player, driven by the viewer's cine transport.

## References

- PS3.5 §8.2.5–8.2.11 — video encoding constraints, Table 8-4
- PS3.5 §A.4 — encapsulation of encoded pixel data
- PS3.3 §A.32.5 — Video Endoscopic Image IOD
- IHE Endoscopy Image Archiving (EIA) Rev. 1.1 §3.10.4.1.1.1 — series grouping
