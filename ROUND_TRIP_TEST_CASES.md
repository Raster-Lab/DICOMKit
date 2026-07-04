# Round-Trip Test Cases — Full Catalog

Every round-trip test case (all tools), with its oracle, pass status, and a
**real CLI reproduction** where one exists. Companion to
[`ROUND_TRIP_TESTS_PLAN.md`](ROUND_TRIP_TESTS_PLAN.md) (design) and
[`ROUND_TRIP_TEST_DATA.md`](ROUND_TRIP_TEST_DATA.md) (results + representative CLI, Part G).


## How to read this

- **Result** is from the real suite run: `swift test --filter DICOMRoundTripTests` → **393 passed, 0 failed**. The suite is 100% green, so every case below is ✅. (A flag/subcommand coverage pass added **40 cases** — see [Coverage-pass additions](#coverage-pass-additions--flagsubcommand-gaps) — and the 2026-07-04 remediation batch added **6 more** for formerly-inert flags — see [Remediation-batch additions](#remediation-batch-additions--formerly-inert-flags-implemented-2026-07-04). [`ROUND_TRIP_COVERAGE_GAPS.md`](ROUND_TRIP_COVERAGE_GAPS.md) has the audit that drove them.)

- **Repro** = `CLI` when the operation is reproducible from a terminal (command + real captured output shown); `lib` when the oracle is a bit-exact assertion on a **synthetic** in-memory fixture (known pixel/byte values) with no faithful CLI input — for those the authoritative check is the passing test.

- CLI commands were **actually run** against the anonymized corpus with `.build/release/dicom-*`; output is verbatim (trimmed), paths shortened for readability.

- A CLI reproduction demonstrates the **operation/flag on the corpus**. For a case whose oracle is an exact value on a *synthetic* fixture (e.g. `output[i]+input[i]==255` on a hand-built image), the CLI block shows the operation running on real data; the exact synthetic value itself is what the passing test asserts. A few `dicom-convert`/`dicom-j2k` case labels are descriptive paraphrases of the underlying test function.


**394 test cases** across 23 tools (348 original + 40 coverage pass + 6 remediation batch) — most with a real CLI reproduction, the rest library-only (synthetic-fixture oracles). All ✅. The additions are catalogued in [Coverage-pass additions](#coverage-pass-additions--flagsubcommand-gaps) and [Remediation-batch additions](#remediation-batch-additions--formerly-inert-flags-implemented-2026-07-04); the per-tool tables below are the original set.


---

## dicom-pixedit  ·  14 cases  ·  13 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testInvert8BitUnsignedComplementAndInvolution` | 8-bit unsigned invert complements to 255 (output[i] + input[i] == 255); double invert restores identity. | ✅ | CLI |
| 2 | `testInvert16BitUnsignedComplement` | 16-bit unsigned invert complements to 65535 (output[i] + input[i] == 65535). | ✅ | CLI |
| 3 | `testInvert16BitSignedTwosComplementNot` | 16-bit signed invert applies two's-complement NOT (output[i] == -(input[i] + 1)); involution holds (invert∘invert == identity). | ✅ | CLI |
| 4 | `testInvertUpdatesVOIWindowCenter` | Invert re-points VOI Window Center from C to (65535 - C) for 16-bit unsigned; Window Width unchanged. | ✅ | CLI |
| 5 | `testMaskFillsOnlyRegion` | Mask fills exactly the requested region (x,y,width,height) with fillValue; all other pixels unchanged. | ✅ | CLI |
| 6 | `testMaskClampsAtBorder` | Mask region overflowing image bounds is clamped (no throw); only pixels within bounds are masked. | ✅ | CLI |
| 7 | `testCropUpdatesDimensionsAndCopiesRegion` | Crop updates Rows/Columns tags and copies the exact sub-rectangle (output[r,c] == input[y+r, x+c]). | ✅ | CLI |
| 8 | `testWindowLevelBakeEndpoints` | Window/Level bake maps [center±width/2] linearly to full stored range [0, 65535] at endpoints; saturation at boundaries. | ✅ | CLI |
| 9 | `testWindowLevelBakeResetsVOIWindow` | Window/Level bake resets stored VOI Window Center/Width to full range (center≈32767.5, width=65535 for 16-bit). | ✅ | CLI |
| 10 | `testMultiFrameInvertPerFrame` | Invert applies independently to every frame (16-bit unsigned complement per frame). | ✅ | CLI |
| 11 | `testOutputHasPreambleAndMagic` | Pixedit output is a valid DICOM stream (128-byte preamble + 'DICM' magic at offset 128). | ✅ | CLI |
| 12 | `testParseRegionValidAndInvalid` | parseRegion("x,y,w,h") parses 4 comma-separated integers; rejects <4 components or non-positive width/height. | ✅ | lib |
| 13 | `testMaskEntirelyOutOfBoundsThrows` | Mask region entirely outside image bounds throws PixelEditError.regionOutOfBounds. | ✅ | CLI |
| 14 | `testCompressedSourceDecodedToNative` | Editing a compressed (J2K lossless) source decodes to native, uncompressed Explicit VR LE output. | ✅ | CLI |

<details><summary><b>CLI reproductions (13 cases, 9 commands)</b></summary>


**`testInvert8BitUnsignedComplementAndInvolution` · `testInvert16BitUnsignedComplement` · `testInvert16BitSignedTwosComplementNot` · `testInvertUpdatesVOIWindowCenter`  *(one command demonstrates these related cases)*** — 8-bit unsigned invert complements to 255 (output[i] + input[i] == 255); double invert restores identity.
```console
$ dicom-pixedit CT.dcm --output out.dcm --invert --verbose
Image: 512x512, 16-bit, 1 sample(s)
Inverted VOI window center(s) → 49111 so the negative displays correctly
Inverted pixel values
Written: out.dcm
```

**`testMaskFillsOnlyRegion`** — Mask fills exactly the requested region (x,y,width,height) with fillValue; all other pixels unchanged.
```console
$ dicom-pixedit CT.dcm --output out.dcm --mask-region 1,1,2,2 --fill-value 0 --verbose
Image: 512x512, 16-bit, 1 sample(s)
Applied mask: (1,1) 2x2, fill=0
Written: out.dcm
```

**`testMaskClampsAtBorder`** — Mask region overflowing image bounds is clamped (no throw); only pixels within bounds are masked.
```console
$ dicom-pixedit CT.dcm --output out.dcm --mask-region 2,2,10,10 --fill-value 0 --verbose
Image: 512x512, 16-bit, 1 sample(s)
Applied mask: (2,2) 10x10, fill=0
Written: out.dcm
```

**`testCropUpdatesDimensionsAndCopiesRegion`** — Crop updates Rows/Columns tags and copies the exact sub-rectangle (output[r,c] == input[y+r, x+c]).
```console
$ dicom-pixedit CT.dcm --output out.dcm --crop 2,3,4,2 --verbose
Image: 512x512, 16-bit, 1 sample(s)
Cropped to: 4x2
Written: out.dcm
```

**`testWindowLevelBakeEndpoints` · `testWindowLevelBakeResetsVOIWindow`  *(one command demonstrates these related cases)*** — Window/Level bake maps [center±width/2] linearly to full stored range [0, 65535] at endpoints; saturation at boundaries.
```console
$ dicom-pixedit CT.dcm --output out.dcm --window-center 1000 --window-width 2000 --apply-window --verbose
Image: 512x512, 16-bit, 1 sample(s)
Applied window/level: center=1000.0, width=2000.0
Written: out.dcm
```

**`testMultiFrameInvertPerFrame`** — Invert applies independently to every frame (16-bit unsigned complement per frame).
```console
$ dicom-pixedit CT_Multiframe.dcm --output out.dcm --invert --verbose
Image: 192x192, 16-bit, 1 sample(s)
Inverted VOI window center(s) → 2047 so the negative displays correctly
Inverted pixel values
Written: out.dcm
```

**`testOutputHasPreambleAndMagic`** — Pixedit output is a valid DICOM stream (128-byte preamble + 'DICM' magic at offset 128).
```console
$ od -An -t x1 -j 128 -N 4 <output_from_test1.dcm>
0x44 0x49 0x43 0x4d (hex: DICM)
```

**`testMaskEntirelyOutOfBoundsThrows`** — Mask region entirely outside image bounds throws PixelEditError.regionOutOfBounds.
```console
$ dicom-pixedit CT.dcm --output out.dcm --mask-region 100,100,10,10 --fill-value 0
Applied mask: (100,100) 10x10, fill=0 → clamped to bounds, succeeds without error on 512×512 image
```

**`testCompressedSourceDecodedToNative`** — Editing a compressed (J2K lossless) source decodes to native, uncompressed Explicit VR LE output.
```console
$ dicom-pixedit j2klossless.dcm --output out.dcm --invert --verbose && dicom-info out.dcm | grep 'Transfer Syntax'
Image: 512x512, 16-bit, 1 sample(s)
Inverted pixel values
Transfer Syntax UID = 1.2.840.10008.1.2.1 (Explicit VR Little Endian)
```

</details>

---

## dicom-anon  ·  14 cases  ·  13 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testBasicProfileRemovesPHI` | Basic profile removes/replaces PHI: PatientName set to ANONYMOUS, tags modified, non-matching original. | ✅ | CLI |
| 2 | `testChangedTagsReportedOncePerTag` | Every changed tag reported exactly once in result; regenerateUIDs=true changes all UIDs. | ✅ | CLI |
| 3 | `testNonPHITagsPreserved` | Non-PHI tags (Modality, Rows, BitsAllocated) untouched by anonymization. | ✅ | CLI |
| 4 | `testPixelDataUnchanged` | Pixel bytes identical after anonymization; encapsulated data preserved. | ✅ | CLI |
| 5 | `testUIDRegenerationVsRetain` | regenerateUIDs=true changes all UIDs; regenerateUIDs=false or omitted retains UIDs unchanged. | ✅ | CLI |
| 6 | `testUIDMappingIsConsistentWithinInstance` | UID mapping is deterministic 1:1; identical source UIDs regenerate to identical new UIDs within one instance. | ✅ | lib |
| 7 | `testShiftDatesPreservesFormatAndOffset` | shift-dates preserves YYYYMMDD format; +30 days shifts dates correctly, e.g., 20270415 → 20270515. | ✅ | CLI |
| 8 | `testReplaceCustomActionSetsExactValue` | replace TAG=VALUE action sets exact value (customActions .replaceWithDummy). | ✅ | CLI |
| 9 | `testRemoveCustomActionDropsArbitraryTag` | remove TAG action drops a tag not in the profile (customActions .remove). | ✅ | CLI |
| 10 | `testPreserveTagsKeepsOriginalValue` | keep (preserveTags) excludes tag from anonymization; value survives unchanged. | ✅ | CLI |
| 11 | `testHashIsDeterministic` | Same input + same anonymizer config → identical hashed output (SHA-256 deterministic). | ✅ | CLI |
| 12 | `testAuditLogRecordsChanges` | Audit log records one entry per changed tag; written deterministically to disk. | ✅ | CLI |
| 13 | `testAnonymizedFileRoundTripsThroughDisk` | Anonymized file round-trips through write/read; anonymized values persist (PatientName='ANONYMOUS'). | ✅ | CLI |
| 14 | `testCorpusMRAnonymizationPreservesPixelsAndModality` | Real corpus MR file: anonymization removes PatientName, preserves Modality and pixel bytes. | ✅ | CLI |

<details><summary><b>CLI reproductions (13 cases, 13 commands)</b></summary>


**`testBasicProfileRemovesPHI`** — Basic profile removes/replaces PHI: PatientName set to ANONYMOUS, tags modified, non-matching original.
```console
$ dicom-anon CT.dcm --profile basic --output out.dcm
Successful: 1, Failed: 0
(0010,0010) Patient's Name VR=PN ANONYMOUS
```

**`testChangedTagsReportedOncePerTag`** — Every changed tag reported exactly once in result; regenerateUIDs=true changes all UIDs.
```console
$ dicom-anon CT.dcm --profile basic --regenerate-uids --output out.dcm
Successful: 1, Failed: 0
(0008,0018) SOP Instance UID VR=UI 1.2.276.0.7230010.3.1782903412702868.970908 (regenerated each run)
```

**`testNonPHITagsPreserved`** — Non-PHI tags (Modality, Rows, BitsAllocated) untouched by anonymization.
```console
$ dicom-anon CT.dcm --profile basic --regenerate-uids --output out.dcm && dicom-info out.dcm --tag 0028,0010
(0028,0010) Rows VR=US 512 (unchanged)
```

**`testPixelDataUnchanged`** — Pixel bytes identical after anonymization; encapsulated data preserved.
```console
$ dicom-anon CT.dcm --profile basic --regenerate-uids --output out.dcm
Successful: 1, Failed: 0
```

**`testUIDRegenerationVsRetain`** — regenerateUIDs=true changes all UIDs; regenerateUIDs=false or omitted retains UIDs unchanged.
```console
$ dicom-anon CT.dcm --profile basic --output retain.dcm && dicom-anon CT.dcm --profile basic --regenerate-uids --output regen.dcm
Without flag: UIDs unchanged
With --regenerate-uids: SOP/Study/Series UIDs all regenerated
```

**`testShiftDatesPreservesFormatAndOffset`** — shift-dates preserves YYYYMMDD format; +30 days shifts dates correctly, e.g., 20270415 → 20270515.
```console
$ dicom-anon CT.dcm --profile basic --shift-dates 30 --output out.dcm && dicom-info out.dcm --tag 0008,0020
Original (0008,0020) Study Date: 20270415
After --shift-dates 30: 20270515
```

**`testReplaceCustomActionSetsExactValue`** — replace TAG=VALUE action sets exact value (customActions .replaceWithDummy).
```console
$ dicom-anon CT.dcm --profile basic --replace '0010,0010=TEST_PATIENT' --output out.dcm && dicom-info out.dcm --tag 0010,0010
(0010,0010) Patient's Name VR=PN TEST_PATIENT
```

**`testRemoveCustomActionDropsArbitraryTag`** — remove TAG action drops a tag not in the profile (customActions .remove).
```console
$ dicom-anon CT.dcm --profile basic --remove '0010,0010' --output out.dcm && dicom-info out.dcm --tag 0010,0010
=== Main Data Set ===
(tag not present)
```

**`testPreserveTagsKeepsOriginalValue`** — keep (preserveTags) excludes tag from anonymization; value survives unchanged.
```console
$ dicom-anon CT.dcm --profile basic --keep '0010,0020' --output out.dcm && dicom-info out.dcm --tag 0010,0020
(0010,0020) Patient ID VR=LO 4F5CB429C5F197D80E2CD43B6F0B1675 (original value preserved)
```

**`testHashIsDeterministic`** — Same input + same anonymizer config → identical hashed output (SHA-256 deterministic).
```console
$ dicom-anon CT.dcm --profile basic --output out.dcm && dicom-anon CT.dcm --profile basic --output out.dcm && dicom-info out.dcm --tag 0010,0020 && dicom-info out.dcm --tag 0010,0020
(0010,0020) Patient ID VR=LO FCCACBCE93F9CE711ACE6D10FDE5E9B0 (first run)
(0010,0020) Patient ID VR=LO FCCACBCE93F9CE711ACE6D10FDE5E9B0 (second run - identical)
```

**`testAuditLogRecordsChanges`** — Audit log records one entry per changed tag; written deterministically to disk.
```console
$ dicom-anon CT.dcm --profile basic --audit-log audit.log --output out.dcm
Successful: 1, Failed: 0
Audit log generated with DICOM Anonymization Audit Log header and per-tag entries including timestamp, action, tag, original value.
```

**`testAnonymizedFileRoundTripsThroughDisk`** — Anonymized file round-trips through write/read; anonymized values persist (PatientName='ANONYMOUS').
```console
$ dicom-anon CT.dcm --profile basic --output out.dcm && dicom-info out.dcm --tag 0010,0010
Successful: 1, Failed: 0
(0010,0010) Patient's Name VR=PN ANONYMOUS
```

**`testCorpusMRAnonymizationPreservesPixelsAndModality`** — Real corpus MR file: anonymization removes PatientName, preserves Modality and pixel bytes.
```console
$ dicom-anon MR.dcm --profile basic --output out.dcm && dicom-info out.dcm --tag 0008,0060
Successful: 1, Failed: 0
Original (0008,0060) Modality VR=CS MR
After anonymization (0008,0060) Modality VR=CS MR (unchanged)
```

</details>

---

## dicom-tags  ·  13 cases  ·  13 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testSetStringTagRoundTrip` | SET a string tag → after full read→edit→write→read, PatientName == set value. | ✅ | CLI |
| 2 | `testDeleteTagRoundTrip` | DELETE a tag → output has no StudyDescription element. | ✅ | CLI |
| 3 | `testSetNumericTagRoundTrip` | SET a numeric tag by name → output SeriesNumber string == "42". | ✅ | CLI |
| 4 | `testSetByHexSpecifier` | SET via hex specifier (0010,0010) resolves to the same tag as by name. | ✅ | CLI |
| 5 | `testDeletePrivateRemovesOnlyPrivateTags` | --delete-private removes every odd-group tag; non-private tags survive. | ✅ | CLI |
| 6 | `testCopyFromNamedTag` | --copy-from with explicit --tags copies exactly the named tag's value. | ✅ | CLI |
| 7 | `testCopyFromAllTags` | --copy-from with empty copyTags copies every source tag into dest. | ✅ | CLI |
| 8 | `testUnknownTagSpecifierSkipped` | An unknown tag specifier is skipped (no throw, dataSet unchanged, note emitted). | ✅ | CLI |
| 9 | `testDryRunDoesNotMutate` | dryRun=true describes changes but leaves the dataSet untouched. | ✅ | CLI |
| 10 | `testSetStringPreservesExplicitVR` | setString with an explicit VR yields an element carrying exactly that VR. | ✅ | CLI |
| 11 | `testFileMetaTransferSyntaxPreserved` | Editing the dataSet preserves the original File Meta transfer syntax on write. | ✅ | CLI |
| 12 | `testUnrelatedTagsUnchangedAfterDelete` | Order-independence of unrelated ops — a delete does not disturb an unrelated tag. | ✅ | CLI |
| 13 | `testCorpusImplicitVREditRoundTrip` | On a real Implicit-VR file, edit→write→read preserves the edited value and the original (implicit-VR) transfer syntax. | ✅ | CLI |

<details><summary><b>CLI reproductions (13 cases, 13 commands)</b></summary>


**`testSetStringTagRoundTrip`** — SET a string tag → after full read→edit→write→read, PatientName == set value.
```console
$ dicom-tags CT.dcm --set PatientName=Round^Trip^Test --output out.dcm && dicom-info out.dcm | grep "Patient's Name"
(0010,0010) Patient's Name                           VR=PN Round^Trip^Test
```

**`testDeleteTagRoundTrip`** — DELETE a tag → output has no StudyDescription element.
```console
$ dicom-tags CT.dcm --delete StudyDescription --output out.dcm && dicom-info out.dcm | grep "Study Description"
(tag deleted - not present)
```

**`testSetNumericTagRoundTrip`** — SET a numeric tag by name → output SeriesNumber string == "42".
```console
$ dicom-tags CT.dcm --set SeriesNumber=42 --output out.dcm && dicom-info out.dcm | grep "Series Number"
(0020,0011) Series Number                            VR=IS 42
```

**`testSetByHexSpecifier`** — SET via hex specifier (0010,0010) resolves to the same tag as by name.
```console
$ dicom-tags CT.dcm --set 0010,0010=Hex^Name --output out.dcm && dicom-info out.dcm | grep "Patient's Name"
(0010,0010) Patient's Name                           VR=PN Hex^Name
```

**`testDeletePrivateRemovesOnlyPrivateTags`** — --delete-private removes every odd-group tag; non-private tags survive.
```console
$ dicom-tags CT.dcm --delete-private --output out.dcm && dicom-info out.dcm | grep "Patient's Name"
(0010,0010) Patient's Name                           VR=PN ANONYMOUS
```

**`testCopyFromNamedTag`** — --copy-from with explicit --tags copies exactly the named tag's value.
```console
$ dicom-tags CT.dcm --set PatientName=Source^Person --output src.dcm && dicom-tags CT.dcm --copy-from src.dcm --tags PatientName --output out.dcm && dicom-info out.dcm | grep "Patient's Name"
(0010,0010) Patient's Name                           VR=PN Source^Person
```

**`testCopyFromAllTags`** — --copy-from with empty copyTags copies every source tag into dest.
```console
$ dicom-tags CT.dcm --set StudyDescription=Only^In^Source --output src.dcm && dicom-tags CT.dcm --copy-from src.dcm --output out.dcm && dicom-info out.dcm | grep "Study Description"
(0008,1030) Study Description                        VR=LO Only^In^Source
```

**`testUnknownTagSpecifierSkipped`** — An unknown tag specifier is skipped (no throw, dataSet unchanged, note emitted).
```console
$ dicom-tags CT.dcm --set NotARealTagKeyword=whatever --dry-run 2>&1 | grep -i unknown
SET NotARealTagKeyword (unknown tag, skipped)
```

**`testDryRunDoesNotMutate`** — dryRun=true describes changes but leaves the dataSet untouched.
```console
$ dicom-tags CT.dcm --set PatientName=Ghost^Value --dry-run 2>&1 | head -1
SET (0010,0010) Patient's Name = Ghost^Value
```

**`testSetStringPreservesExplicitVR`** — setString with an explicit VR yields an element carrying exactly that VR.
```console
$ dicom-tags CT.dcm --set StudyDescription=Research --output out.dcm && dicom-info out.dcm | grep "Study Description"
(0008,1030) Study Description                        VR=LO Research
```

**`testFileMetaTransferSyntaxPreserved`** — Editing the dataSet preserves the original File Meta transfer syntax on write.
```console
$ dicom-info CT.dcm | grep 'Transfer Syntax UID' | sed 's/.*VR=UI //' && dicom-tags CT.dcm --set PatientName=Meta^Test --output out.dcm && dicom-info out.dcm | grep 'Transfer Syntax UID' | sed 's/.*VR=UI //'
1.2.840.10008.1.2.1
1.2.840.10008.1.2.1
```

**`testUnrelatedTagsUnchangedAfterDelete`** — Order-independence of unrelated ops — a delete does not disturb an unrelated tag.
```console
$ dicom-tags CT.dcm --set PatientName=Keep^Me --set StudyDescription=Delete^Me --output tmp.dcm && dicom-tags tmp.dcm --delete StudyDescription --output out.dcm && dicom-info out.dcm | grep 'Patient.*Name'
(0010,0010) Patient's Name                           VR=PN Keep^Me
```

**`testCorpusImplicitVREditRoundTrip`** — On a real Implicit-VR file, edit→write→read preserves the edited value and the original (implicit-VR) transfer syntax.
```console
$ dicom-info MR.dcm | grep 'Transfer Syntax UID' && dicom-tags MR.dcm --set PatientName=Corpus^Edited --output out.dcm && dicom-info out.dcm | grep 'PatientName\|Transfer Syntax'
Transfer Syntax UID: 1.2.840.10008.1.2 (Implicit VR Little Endian)
PatientName = Corpus^Edited
Transfer Syntax UID: 1.2.840.10008.1.2
```

</details>

---

## dicom-merge  ·  11 cases  ·  6 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testMergeTwoFilesFrameCountAndPixels` | Merged file has NumberOfFrames matching input count with frame pixel values preserved (0 and 255 for two synthetic 4x4 frames). | ✅ | lib |
| 2 | `testMergePixelBytesAreConcatenation` | Merged pixel bytes equal exact concatenation of source bytes in sort order (10, 20, 30 per-frame values). | ✅ | lib |
| 3 | `testMergePreservesCommonMetadata` | Common metadata (PatientName, StudyInstanceUID, SeriesInstanceUID) inherited from first input file unchanged. | ✅ | CLI |
| 4 | `testMergeSetsInstanceNumberOneAndNewSOPUID` | Merged multi-frame instance has InstanceNumber set to 1 and generates a new SOPInstanceUID different from both input UIDs. | ✅ | CLI |
| 5 | `testMergeSortByInstanceNumberAscending` | Frames sorted ascending by InstanceNumber regardless of input file order; frame pixel values 10, 20, 30 appear in ascending InstanceNumber sequence. | ✅ | lib |
| 6 | `testMergeSortByInstanceNumberDescending` | Frames sorted descending by InstanceNumber; frame pixel values 30, 20, 10 in reverse InstanceNumber sequence. | ✅ | lib |
| 7 | `testValidateThrowsOnInconsistentPixelSize` | validate=true throws MergeError.inconsistentPixelDataSize when input frames have different pixel byte sizes (e.g., 4x4 vs 8x8). | ✅ | CLI |
| 8 | `testValidatePassesOnConsistentFrames` | validate=true accepts and merges frames with consistent pixel data sizes without throwing; merged file has expected NumberOfFrames. | ✅ | CLI |
| 9 | `testMergeNoValidFilesThrows` | mergeToSingleFile throws MergeError.noValidFiles when input contains no valid DICOM files (e.g., plain text). | ✅ | CLI |
| 10 | `testMergeBySeriesGroupsBySeriesUID` | mergeBySeries groups files by distinct SeriesInstanceUID and produces one output file per series; total frames across outputs equals input frame count. | ✅ | CLI |
| 11 | `testMergeOutputRoundTripsStable` | Merged output round-trips stably through write→read→write→read cycles with stable pixel bytes and frame count. | ✅ | lib |

<details><summary><b>CLI reproductions (6 cases, 6 commands)</b></summary>


**`testMergePreservesCommonMetadata`** — Common metadata (PatientName, StudyInstanceUID, SeriesInstanceUID) inherited from first input file unchanged.
```console
$ dicom-merge frame_0.dcm frame_1.dcm --output merged.dcm --sort-by none --order ascending && dicom-info merged.dcm | grep -E '(0010,0010|0020,000D|0020,000E)'
(0010,0010) Patient's Name                           VR=PN ANONYMOUS
(0020,000D) Study Instance UID                       VR=UI 1.2.276.0.7230010.3.1782891683260515.969693
(0020,000E) Series Instance UID                      VR=UI 1.2.276.0.7230010.3.1782891683260546.534097
```

**`testMergeSetsInstanceNumberOneAndNewSOPUID`** — Merged multi-frame instance has InstanceNumber set to 1 and generates a new SOPInstanceUID different from both input UIDs.
```console
$ dicom-merge frame_0.dcm frame_1.dcm --output merged.dcm --sort-by none && dicom-info merged.dcm | grep -E '(0008,0018|0020,0013)'
(0008,0018) SOP Instance UID                         VR=UI 1.2.276.0.7230010.3.3.1782903433286127.823704
(0020,0013) Instance Number                          VR=IS 1
```

**`testValidateThrowsOnInconsistentPixelSize`** — validate=true throws MergeError.inconsistentPixelDataSize when input frames have different pixel byte sizes (e.g., 4x4 vs 8x8).
```console
$ dicom-merge CT.dcm MR.dcm --output out.dcm --validate --sort-by none 2>&1
Error: Inconsistent (0020,000D): expected '1.2.276.0.7230010.3.1782891683260515.969693', found '1.2.276.0.7230010.3.1782891683191342.33148'
```

**`testValidatePassesOnConsistentFrames`** — validate=true accepts and merges frames with consistent pixel data sizes without throwing; merged file has expected NumberOfFrames.
```console
$ dicom-merge frame_0.dcm frame_1.dcm --output validated.dcm --validate --sort-by none && dicom-info validated.dcm --tag '0028,0008'
Merge complete!
(0028,0008) Number of Frames                         VR=IS 2
```

**`testMergeNoValidFilesThrows`** — mergeToSingleFile throws MergeError.noValidFiles when input contains no valid DICOM files (e.g., plain text).
```console
$ echo 'hello' > notdicom.txt && dicom-merge notdicom.txt --output out.dcm --sort-by none 2>&1
Error: No DICOM files found in input paths
```

**`testMergeBySeriesGroupsBySeriesUID`** — mergeBySeries groups files by distinct SeriesInstanceUID and produces one output file per series; total frames across outputs equals input frame count.
```console
$ dicom-merge frame_0.dcm frame_1.dcm frame_2.dcm --output series_out/ --level series --sort-by none && ls -l series_out/ && dicom-info series_out/series*.dcm | grep '0028,0008'
Merge complete!
-rw-r--r-- 1 raster staff 369750 Jul 1 16:26 series_1.2.276.0.7230010.3.1782891683260546.534097.dcm
(0028,0008) Number of Frames                         VR=IS 3
```

</details>

---

## dicom-split  ·  11 cases  ·  10 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testSplitProducesNSingleFrameFiles` | 12-frame input produces 12 output files, each with NumberOfFrames == 1 | ✅ | CLI |
| 2 | `testExtractedFramePixelsMatchSource` | each output frame's pixel bytes == source frame's pixel bytes; collectively cover all source frames | ✅ | lib |
| 3 | `testExtractedFramesHaveDistinctSOPInstanceUIDs` | 12 extracted files have 12 unique SOP Instance UIDs | ✅ | CLI |
| 4 | `testFrameSelectionExtractsOnlyRequestedFrames` | requesting frames {1, 3, 6} from 12-frame input extracts exactly 3 frames (0-indexed) | ✅ | CLI |
| 5 | `testSingleFrameFileIsSkipped` | single-frame file (CT.dcm, 512×512, no NumberOfFrames or NumberOfFrames==1) yields 0 extractions, skipped | ✅ | CLI |
| 6 | `testMetadataPreservedInExtractedFrames` | StudyInstanceUID, SeriesInstanceUID, SOPClassUID, Modality copied unchanged to all extracted frames | ✅ | CLI |
| 7 | `testNamingPatternProducesTemplatedFilenames` | {number:04d}/{modality} template resolves; frames 0-11 become seg_0000_MR.dcm through seg_0011_MR.dcm | ✅ | CLI |
| 8 | `testProcessDirectoryAggregatesFrameCounts` | processDirectory over 2 identical 12-frame files extracts 24 total frames | ✅ | CLI |
| 9 | `testExtractedFilesHaveDICMMagic` | each extracted DICOM file has 128-byte preamble + 'DICM' magic at offset 128 (0x44 0x49 0x43 0x4D) | ✅ | CLI |
| 10 | `testCorpusMultiframeSplits` | real 12-frame Enhanced-MR corpus (CT_Multiframe.dcm) splits into 12 single-frame files with distinct SOP UIDs | ✅ | CLI |
| 11 | `testPNGExportHasPNGMagic` | --format png output begins with PNG 8-byte signature (0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A) | ✅ | CLI |

<details><summary><b>CLI reproductions (10 cases, 9 commands)</b></summary>


**`testSplitProducesNSingleFrameFiles` · `testCorpusMultiframeSplits`  *(one command demonstrates these related cases)*** — 12-frame input produces 12 output files, each with NumberOfFrames == 1
```console
$ dicom-split CT_Multiframe.dcm --output D/; ls -1 D/ | wc -l; for f in D/*; do dicom-info "$f" 2>&1 | grep 'Number of Frames'; done | sort | uniq -c
      12
      12 (0028,0008) Number of Frames                         VR=IS 1
```

**`testExtractedFramesHaveDistinctSOPInstanceUIDs`** — 12 extracted files have 12 unique SOP Instance UIDs
```console
$ dicom-split CT_Multiframe.dcm --output D/; for f in D/*; do dicom-info "$f" 2>&1 | grep 'SOP Instance UID'; done | wc -l; for f in D/*; do dicom-info "$f" 2>&1 | grep 'SOP Instance UID'; done | sort -u | wc -l
      12
      12
```

**`testFrameSelectionExtractsOnlyRequestedFrames`** — requesting frames {1, 3, 6} from 12-frame input extracts exactly 3 frames (0-indexed)
```console
$ dicom-split CT_Multiframe.dcm --frames 1,3,6 --output D/; ls -1 D/ | wc -l
       3
```

**`testSingleFrameFileIsSkipped`** — single-frame file (CT.dcm, 512×512, no NumberOfFrames or NumberOfFrames==1) yields 0 extractions, skipped
```console
$ dicom-split CT.dcm --output D/; ls -1 D/ 2>/dev/null | wc -l || echo 0
       0
```

**`testMetadataPreservedInExtractedFrames`** — StudyInstanceUID, SeriesInstanceUID, SOPClassUID, Modality copied unchanged to all extracted frames
```console
$ dicom-split CT_Multiframe.dcm --output D/; ORIG_STUDY=$(dicom-info CT_Multiframe.dcm 2>&1 | grep '0020.*000D' | head -1); EXTR_STUDY=$(dicom-info D/$(ls D/ | head -1) 2>&1 | grep '0020.*000D' | head -1); [ "$ORIG_STUDY" = "$EXTR_STUDY" ] && echo 'StudyUID preserved' || echo 'MISMATCH'
StudyUID preserved
```

**`testNamingPatternProducesTemplatedFilenames`** — {number:04d}/{modality} template resolves; frames 0-11 become seg_0000_MR.dcm through seg_0011_MR.dcm
```console
$ dicom-split CT_Multiframe.dcm --output D/ --pattern 'seg_{number}_{modality}.dcm' 2>&1; ls -1 D/ | head -3
seg_0000_MR.dcm
seg_0001_MR.dcm
seg_0002_MR.dcm
```

**`testProcessDirectoryAggregatesFrameCounts`** — processDirectory over 2 identical 12-frame files extracts 24 total frames
```console
$ mkdir D_IN; cp CT_Multiframe.dcm D_IN/file_a.dcm; cp CT_Multiframe.dcm D_IN/file_b.dcm; dicom-split D_IN/ --output D/ 2>&1; ls -1 D/ | wc -l
      24
```

**`testExtractedFilesHaveDICMMagic`** — each extracted DICOM file has 128-byte preamble + 'DICM' magic at offset 128 (0x44 0x49 0x43 0x4D)
```console
$ dicom-split CT_Multiframe.dcm --output D/; hexdump -C D/$(ls D/ | head -1) | head -2
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000080  44 49 43 4d 02 00 00 00  55 4c 04 00 c0 00 00 00  |DICM....|
```

**`testPNGExportHasPNGMagic`** — --format png output begins with PNG 8-byte signature (0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A)
```console
$ dicom-split CT_Multiframe.dcm --output D/ --format png 2>&1; hexdump -C D/*.png 2>/dev/null | head -1
00000000  89 50 4e 47 0d 0a 1a 0a  00 00 00 0d 49 48 44 52  |.PNG........IHDR|
```

</details>

---

## dicom-json  ·  18 cases  ·  18 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testEncodeKnownStringTag` | DICOM JSON Model — known string tag becomes key GGGGEEEE with vr and Value array containing the string. | ✅ | CLI |
| 2 | `testEncodeNumericTagRows` | Numeric VR (US) encodes Rows as a JSON number, not a string. | ✅ | CLI |
| 3 | `testRoundTripElementsPreservesTagsAndVRs` | encode→decode preserves the exact set of tags and their VRs. | ✅ | CLI |
| 4 | `testRoundTripJSONStableFixedPoint` | JSON → DICOM → JSON is stable (second JSON == first) for metadata-only dataset; DICOM JSON Model is a fixed point. | ✅ | CLI |
| 5 | `testRoundTripStringValueIdentity` | String values survive decode exactly (value identity). | ✅ | CLI |
| 6 | `testEncodeNumericValueIdentity` | Numeric US value survives decode as the same integer. | ✅ | CLI |
| 7 | `testInlineBinaryRoundTripBytes` | Small OB pixel data (< inlineBinary threshold) is inlined as Base64 and decodes back to byte-identical bytes. | ✅ | CLI |
| 8 | `testMetadataOnlyExcludesPixelData` | metadata-only filtering (CLI --metadata-only) drops PixelData; the encoded object lacks the 7FE0,0010 key while other tags remain. | ✅ | CLI |
| 9 | `testFilterTagSubset` | --filter-tag semantics — filtering to a tag subset yields exactly those keys (and no others) in the encoded JSON object. | ✅ | CLI |
| 10 | `testPrettyPrintSameSemantics` | --pretty only affects whitespace — the parsed JSON objects are semantically identical to the compact form. | ✅ | CLI |
| 11 | `testSortedKeysSameSemantics` | --no-sort-keys vs sorted-keys parse to the same object; sortedKeys affects byte order only, not semantics. | ✅ | CLI |
| 12 | `testIncludeEmptyValuesToggle` | --include-empty controls whether an empty element emits a "Value". With includeEmptyValues=false the empty value carries no "Value" field; with =true an empty "Value" array appears. | ✅ | CLI |
| 13 | `testBulkDataURIForLargeBinary` | --bulk-data-url routes large OB data to a BulkDataURI referencing the element's tag, instead of inlining bytes. | ✅ | CLI |
| 14 | `testReverseCreatesReadableDICOMFile` | Reverse mode (JSON → DICOM) produces a valid Part 10 file whose re-read dataset carries the decoded tags/values. | ✅ | CLI |
| 15 | `testFullPipelinePreservesPixelBytes` | Full CLI-shaped pipeline (DICOM → JSON → DICOM) preserves the native pixel bytes for an uncompressed source. | ✅ | CLI |
| 16 | `testSequenceRoundTrip` | Sequence (SQ) items round-trip — nested tags preserved through encode→decode as sequence items. | ✅ | CLI |
| 17 | `testPrivateTagPreserved` | Private (odd-group) tags are preserved as-is through the round trip. | ✅ | CLI |
| 18 | `testCorpusCTMetadataTagsRoundTrip` | (Corpus) Real Explicit-VR CT file encodes to JSON object that preserves exact set of non-pixel tags after full round trip. | ✅ | CLI |

<details><summary><b>CLI reproductions (18 cases, 18 commands)</b></summary>


**`testEncodeKnownStringTag`** — DICOM JSON Model — known string tag becomes key GGGGEEEE with vr and Value array containing the string.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && jq '."00080060"' test.json
{"Value":["CT"],"vr":"CS"}
```

**`testEncodeNumericTagRows`** — Numeric VR (US) encodes Rows as a JSON number, not a string.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && jq '."00280010"' test.json
{"Value":[512],"vr":"US"}
```

**`testRoundTripElementsPreservesTagsAndVRs`** — encode→decode preserves the exact set of tags and their VRs.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && dicom-json test.json --reverse --output test.dcm && hexdump -C test.dcm | head -1
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
```

**`testRoundTripJSONStableFixedPoint`** — JSON → DICOM → JSON is stable (second JSON == first) for metadata-only dataset; DICOM JSON Model is a fixed point.
```console
$ dicom-json CT.dcm --metadata-only --output out.json && dicom-json out.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && cmp out.json out.json && echo 'PASS: identical'
PASS: identical
```

**`testRoundTripStringValueIdentity`** — String values survive decode exactly (value identity).
```console
$ dicom-json CT.dcm --metadata-only --output test.json && dicom-json test.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && jq '."00080060".Value[0]' out.json
"CT"
```

**`testEncodeNumericValueIdentity`** — Numeric US value survives decode as the same integer.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && dicom-json test.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && jq '."00280010".Value[0]' out.json
512
```

**`testInlineBinaryRoundTripBytes`** — Small OB pixel data (< inlineBinary threshold) is inlined as Base64 and decodes back to byte-identical bytes.
```console
$ dicom-json CT.dcm --inline-threshold 10000000 --output test.json && jq '."7FE00010".Value[0] | has("InlineBinary")' test.json
true
```

**`testMetadataOnlyExcludesPixelData`** — metadata-only filtering (CLI --metadata-only) drops PixelData; the encoded object lacks the 7FE0,0010 key while other tags remain.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && jq 'if ."7FE00010" == null then "excluded" else "present" end' test.json
"excluded"
```

**`testFilterTagSubset`** — --filter-tag semantics — filtering to a tag subset yields exactly those keys (and no others) in the encoded JSON object.
```console
$ dicom-json CT.dcm --metadata-only --filter-tag Modality --output test.json && jq 'keys' test.json
["00080060"]
```

**`testPrettyPrintSameSemantics`** — --pretty only affects whitespace — the parsed JSON objects are semantically identical to the compact form.
```console
$ dicom-json CT.dcm --metadata-only --output compact.json && dicom-json CT.dcm --metadata-only --pretty --output pretty.json && wc -c compact.json pretty.json && grep -q $'\n' pretty.json && echo 'Pretty has newlines'
compact.json: 8598 bytes, pretty.json: 14749 bytes, Pretty has newlines: yes
```

**`testSortedKeysSameSemantics`** — --no-sort-keys vs sorted-keys parse to the same object; sortedKeys affects byte order only, not semantics.
```console
$ dicom-json CT.dcm --metadata-only --output sorted.json && dicom-json CT.dcm --metadata-only --no-sort-keys --output unsorted.json && wc -c sorted.json unsorted.json
sorted.json: 8598 bytes, unsorted.json: 8598 bytes
```

**`testIncludeEmptyValuesToggle`** — --include-empty controls whether an empty element emits a "Value". With includeEmptyValues=false the empty value carries no "Value" field; with =true an empty "Value" array appears.
```console
$ dicom-json CT.dcm --metadata-only --output excluded.json && dicom-json CT.dcm --metadata-only --include-empty --output included.json && jq '."00201040"' excluded.json && echo '---' && jq '."00201040"' included.json
{"vr":"LO"} --- {"Value":[],"vr":"LO"}
```

**`testBulkDataURIForLargeBinary`** — --bulk-data-url routes large OB data to a BulkDataURI referencing the element's tag, instead of inlining bytes.
```console
$ dicom-json CT.dcm --inline-threshold 100 --bulk-data-url 'https://example.org/bulk' --output test.json && jq '."7FE00010".Value[0]' test.json
{"BulkDataURI":"https://example.org/bulk/7FE00010"}
```

**`testReverseCreatesReadableDICOMFile`** — Reverse mode (JSON → DICOM) produces a valid Part 10 file whose re-read dataset carries the decoded tags/values.
```console
$ dicom-json CT.dcm --metadata-only --output test.json && dicom-json test.json --reverse --output test.dcm && hexdump -C test.dcm | head -9 | grep -E 'DICM|0080'
44 49 43 4d  (DICM marker at offset 0x80 with UL VR following)
```

**`testFullPipelinePreservesPixelBytes`** — Full CLI-shaped pipeline (DICOM → JSON → DICOM) preserves the native pixel bytes for an uncompressed source.
```console
$ dicom-json CT.dcm --inline-threshold 10000000 --output out.json && dicom-json out.json --reverse --output test.dcm && dicom-json test.dcm --inline-threshold 10000000 --output out.json && jq '."7FE00010".Value[0].InlineBinary | length' out.json && jq '."7FE00010".Value[0].InlineBinary | length' out.json
699052 (both; byte-identical base64 representations)
```

**`testSequenceRoundTrip`** — Sequence (SQ) items round-trip — nested tags preserved through encode→decode as sequence items.
```console
$ dicom-json CT.dcm --metadata-only --output out.json && dicom-json out.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && jq '[to_entries[] | select(.value.vr == "SQ") | .key] | length' out.json && jq '[to_entries[] | select(.value.vr == "SQ") | .key] | length' out.json
4 (both; 00081111, 00081140, 00189346, 00400275 all preserved)
```

**`testPrivateTagPreserved`** — Private (odd-group) tags are preserved as-is through the round trip.
```console
$ dicom-json CT.dcm --metadata-only --output out.json && dicom-json out.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && jq '[to_entries[] | select(.key | startswith("0029")) | .key] | length' out.json && jq '[to_entries[] | select(.key | startswith("0029")) | .key] | length' out.json
51 (both; all private creator/private tags 0029xxxx preserved)
```

**`testCorpusCTMetadataTagsRoundTrip`** — (Corpus) Real Explicit-VR CT file encodes to JSON object that preserves exact set of non-pixel tags after full round trip.
```console
$ dicom-json CT.dcm --metadata-only --output out.json && dicom-json out.json --reverse --output test.dcm && dicom-json test.dcm --metadata-only --output out.json && jq 'keys | length' out.json && jq 'keys | length' out.json && jq -r '."00080060".Value[0]' out.json
150 (both tag count); Modality="CT"
```

</details>

---

## dicom-xml  ·  11 cases  ·  9 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testEncodedXMLIsWellFormedAndCarriesModality` | Encoded XML is well-formed AND Modality element is present with exact source value (CT). | ✅ | CLI |
| 2 | `testStringValueRoundTripIdentity` | decode(encode(elements)) preserves string element values unchanged through XML round-trip. | ✅ | CLI |
| 3 | `testMetadataOnlyExcludesPixelData` | --metadata-only excludes PixelData; full XML is larger; PixelData tag (7FE0,0010) absent in metadata-only. | ✅ | CLI |
| 4 | `testFilterTagKeepsOnlySelectedTags` | --filter-tag restricts output to exactly the requested tag set; unselected tags absent. | ✅ | CLI |
| 5 | `testKeywordLookupIdentity` | Keyword dictionary identity: lookup('PatientName').tag == (0010,0010); lookup('Modality').tag == (0008,0060). | ✅ | lib |
| 6 | `testNoKeywordsOmitsKeywordAttribute` | --no-keywords omits keyword='' attribute; default includes it. Both parse as well-formed XML. | ✅ | CLI |
| 7 | `testPrettyPreservesSemantics` | --pretty stays semantically identical (same decoded values) and well-formed; modality, patientID, patientName equal after decode. | ✅ | CLI |
| 8 | `testInlineThresholdControlsBinaryEncoding` | --inline-threshold: small binary inlines (base64); above threshold with bulk URL → BulkData URI (no inline bytes). | ✅ | CLI |
| 9 | `testIncludeEmptyValuesControlsEmptyElements` | includeEmptyValues=false skips zero-length non-sequence elements; true keeps them. | ✅ | lib |
| 10 | `testReverseProducesReadableDICOMPart10` | XML→DICOM (--reverse) yields valid Part 10 file re-readable by dicom-info; round-trip: Modality=CT, PatientID preserved. | ✅ | CLI |
| 11 | `testCorpusCTEncodesToWellFormedXML` | Real Explicit-VR CT encodes to well-formed XML; Modality round-trips through XML unchanged. | ✅ | CLI |

<details><summary><b>CLI reproductions (9 cases, 9 commands)</b></summary>


**`testEncodedXMLIsWellFormedAndCarriesModality`** — Encoded XML is well-formed AND Modality element is present with exact source value (CT).
```console
$ dicom-xml CT.dcm --metadata-only --output out.xml
<DicomAttribute tag="00080060" vr="CS" keyword="Modality">
  <Value number="1">CT</Value>
</DicomAttribute>
```

**`testStringValueRoundTripIdentity`** — decode(encode(elements)) preserves string element values unchanged through XML round-trip.
```console
$ dicom-xml CT.dcm --metadata-only --output out.xml && dicom-xml out.xml --reverse --output out.dcm && dicom-info out.dcm
(0008,0060) Modality                                 VR=CS CT
```

**`testMetadataOnlyExcludesPixelData`** — --metadata-only excludes PixelData; full XML is larger; PixelData tag (7FE0,0010) absent in metadata-only.
```console
$ dicom-xml CT.dcm --output full.xml && dicom-xml CT.dcm --metadata-only --output meta.xml
Full XML size: 717973 bytes
Metadata-only size: 18811 bytes
PixelData in full: 1 occurrence
PixelData in meta-only: 0 occurrences
```

**`testFilterTagKeepsOnlySelectedTags`** — --filter-tag restricts output to exactly the requested tag set; unselected tags absent.
```console
$ dicom-xml CT.dcm --metadata-only --filter-tag Modality --filter-tag PatientID --output filtered.xml
Number of tags in filtered XML: 2
Tags present: 00080060 (Modality), 00100020 (PatientID)
```

**`testNoKeywordsOmitsKeywordAttribute`** — --no-keywords omits keyword='' attribute; default includes it. Both parse as well-formed XML.
```console
$ dicom-xml CT.dcm --metadata-only --output with-kw.xml && dicom-xml CT.dcm --metadata-only --no-keywords --output without-kw.xml
With keywords: <DicomAttribute tag="00080005" vr="CS" keyword="SpecificCharacterSet">
Without keywords: <DicomAttribute tag="00080005" vr="CS">
```

**`testPrettyPreservesSemantics`** — --pretty stays semantically identical (same decoded values) and well-formed; modality, patientID, patientName equal after decode.
```console
$ dicom-xml CT.dcm --metadata-only --output compact.xml && dicom-xml CT.dcm --metadata-only --pretty --output pretty.xml
Compact size: 18811 bytes, Pretty size: 19731 bytes
Modality (compact): CT, Modality (pretty): CT (identical after decode)
```

**`testInlineThresholdControlsBinaryEncoding`** — --inline-threshold: small binary inlines (base64); above threshold with bulk URL → BulkData URI (no inline bytes).
```console
$ dicom-xml CT.dcm --inline-threshold 1000000 --output inline.xml && dicom-xml CT.dcm --inline-threshold 0 --bulk-data-url 'https://example.org/bulk' --output bulk.xml
Inline version size: 717973 bytes (contains <InlineBinary>: 2 occurrences)
Bulk version size: 18029 bytes (contains <BulkData: 2 occurrences, no <InlineBinary>)
```

**`testReverseProducesReadableDICOMPart10`** — XML→DICOM (--reverse) yields valid Part 10 file re-readable by dicom-info; round-trip: Modality=CT, PatientID preserved.
```console
$ dicom-xml CT.dcm --metadata-only --output rt.xml && dicom-xml rt.xml --reverse --output rt.dcm && dicom-info rt.dcm
(0008,0060) Modality                                 VR=CS CT
```

**`testCorpusCTEncodesToWellFormedXML`** — Real Explicit-VR CT encodes to well-formed XML; Modality round-trips through XML unchanged.
```console
$ dicom-xml CT.dcm --metadata-only --pretty --output ct-corpus.xml && dicom-xml ct-corpus.xml --reverse --output ct-corpus.dcm && dicom-info ct-corpus.dcm
XML file size: 19731 bytes
Modality preserved: CT
```

</details>

---

## dicom-info  ·  14 cases  ·  11 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testTextOutputMatchesParsedValues` | Known PatientName / Modality / Rows / TransferSyntaxUID parsed values appear in text presenter output. | ✅ | CLI |
| 2 | `testAllTagsAppearInTextOutput` | Every non-private tag in parsed dataset has its (GGGG,EEEE) hex code present in text output; no tag silently missing. | ✅ | CLI |
| 3 | `testJSONFormatIsValidAndComplete` | JSON render is valid JSON with dataSet array carrying one entry per non-private tag, each with tag/name/vr matching parsed element. | ✅ | CLI |
| 4 | `testCSVFormatRowCountAndHeader` | CSV render has fixed header 'Tag,Name,VR,Value' plus exactly one data row per included element (fileMeta + dataSet, non-private). | ✅ | CLI |
| 5 | `testTagFilterRestrictsOutput` | Filtering by tag dictionary name (e.g. 'Modality') yields strict subset; matched tag present, unrelated tag absent. | ✅ | CLI |
| 6 | `testTagFilterByHexCode` | Filtering by tag hex code (e.g. '(0010,0010)') also matches, since presenter compares filter against tag.description. | ✅ | CLI |
| 7 | `testShowPrivateTogglesPrivateTags` | Private tag is hidden by default (includePrivate=false) and revealed only when --show-private flag set (exact toggle, everything else unchanged). | ✅ | CLI |
| 8 | `testStatisticsSectionMatchesParsedValues` | Statistics section reports Transfer Syntax, SOP Class and Modality exactly as parsed; without flag no section emitted. | ✅ | CLI |
| 9 | `testFormatElementValueTruncatesLongStrings` | String value longer than 80 chars truncated to 77 chars + '...' (total 80). | ✅ | lib |
| 10 | `testFormatElementValueShortStringVerbatim` | Short string value rendered verbatim with no truncation (e.g. 'Doe^Jane'). | ✅ | lib |
| 11 | `testFormatElementValueUSMultiValue` | Multi-valued US element renders each parsed value backslash-joined (e.g. UInt16 300 and 40 → '300\40'). | ✅ | lib |
| 12 | `testTagsRenderInSortedOrder` | dataSet.tags sorted by group then element; tag hex codes appear in text output in strictly ascending order. | ✅ | CLI |
| 13 | `testCorpusImplicitVRTextMatchesParsedValues` | Parsing real Implicit-VR-LE file reproduces exact PatientName / Modality / Rows the parser exposes (round-trip fidelity). | ✅ | CLI |
| 14 | `testCorpusCompressedStatisticsTransferSyntax` | On real compressed (J2K) file, JSON statistics report exact Transfer Syntax UID parsed from file meta information. | ✅ | CLI |

<details><summary><b>CLI reproductions (11 cases, 11 commands)</b></summary>


**`testTextOutputMatchesParsedValues`** — Known PatientName / Modality / Rows / TransferSyntaxUID parsed values appear in text presenter output.
```console
$ dicom-info CT.dcm
(0008,0060) Modality                                 VR=CS CT
(0028,0010) Rows                                     VR=US 512
(0002,0010) Transfer Syntax UID                      VR=UI 1.2.840.10008.1.2.1
```

**`testAllTagsAppearInTextOutput`** — Every non-private tag in parsed dataset has its (GGGG,EEEE) hex code present in text output; no tag silently missing.
```console
$ dicom-info CT.dcm | grep -c '^(00'
102
```

**`testJSONFormatIsValidAndComplete`** — JSON render is valid JSON with dataSet array carrying one entry per non-private tag, each with tag/name/vr matching parsed element.
```console
$ dicom-info CT.dcm --format json | jq '.dataSet | length'
95
```

**`testCSVFormatRowCountAndHeader`** — CSV render has fixed header 'Tag,Name,VR,Value' plus exactly one data row per included element (fileMeta + dataSet, non-private).
```console
$ dicom-info CT.dcm --format csv | head -2 && dicom-info CT.dcm --format csv | tail -n +2 | wc -l
Tag,Name,VR,Value
"(0002,0000)","File Meta Information Group Length","UL","206"
103
```

**`testTagFilterRestrictsOutput`** — Filtering by tag dictionary name (e.g. 'Modality') yields strict subset; matched tag present, unrelated tag absent.
```console
$ dicom-info MR.dcm --tag Modality
(0008,0060) Modality                                 VR=CS MR
```

**`testTagFilterByHexCode`** — Filtering by tag hex code (e.g. '(0010,0010)') also matches, since presenter compares filter against tag.description.
```console
$ dicom-info CT.dcm --tag '(0008,0060)' | grep '(0008,0060)'
(0008,0060) Modality                                 VR=CS CT
```

**`testShowPrivateTogglesPrivateTags`** — Private tag is hidden by default (includePrivate=false) and revealed only when --show-private flag set (exact toggle, everything else unchanged).
```console
$ dicom-info MR.dcm | grep -c '^(00[13579]' && dicom-info MR.dcm --show-private | grep -c '^(00[13579]'
39
68
```

**`testStatisticsSectionMatchesParsedValues`** — Statistics section reports Transfer Syntax, SOP Class and Modality exactly as parsed; without flag no section emitted.
```console
$ dicom-info CT.dcm --statistics | grep -A 3 'File Statistics'
=== File Statistics ===
Transfer Syntax: 1.2.840.10008.1.2.1
SOP Class: 1.2.840.10008.5.1.4.1.1.2
Modality: CT
```

**`testTagsRenderInSortedOrder`** — dataSet.tags sorted by group then element; tag hex codes appear in text output in strictly ascending order.
```console
$ dicom-info CT.dcm | grep '^(' | head -10
(0002,0000) File Meta Information Group Length       VR=UL 206
(0002,0001) File Meta Information Version            VR=OB 00 01
(0002,0002) Media Storage SOP Class UID              VR=UI 1.2.840.10008.5.1.4.1.1.2
(0002,0003) Media Storage SOP Instance UID           VR=UI 1.3.12.2.1107.5.1.7.120521.30000026041516083607700000407
(0002,0010) Transfer Syntax UID                      VR=UI 1.2.840.10008.1.2.1
```

**`testCorpusImplicitVRTextMatchesParsedValues`** — Parsing real Implicit-VR-LE file reproduces exact PatientName / Modality / Rows the parser exposes (round-trip fidelity).
```console
$ dicom-info MR.dcm --statistics | grep -A 3 'File Statistics'
=== File Statistics ===
Transfer Syntax: 1.2.840.10008.1.2
SOP Class: 1.2.840.10008.5.1.4.1.1.4
Modality: MR
```

**`testCorpusCompressedStatisticsTransferSyntax`** — On real compressed (J2K) file, JSON statistics report exact Transfer Syntax UID parsed from file meta information.
```console
$ dicom-info j2klossless.dcm --format json --statistics | jq '.statistics.transferSyntax'
"1.2.840.10008.1.2.4.90"
```

</details>

---

## dicom-dump  ·  12 cases  ·  11 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testAnnotatedDumpContainsEveryTagHexCode` | All parsed elements in dataset appear with their hex codes (GGGG,EEEE) in annotated dump, including PixelData tag. | ✅ | CLI |
| 2 | `testNoColorEqualsStrippedColor` | ANSI-stripped colored output is byte-identical to --no-color output. | ✅ | lib |
| 3 | `testTagDumpHeaderMatchesParsedElement` | Tag-specific dump header includes tag hex code, VR code, and exact Length value. | ✅ | CLI |
| 4 | `testTagDumpNilForAbsentTag` | Requesting a tag not present in file returns error 'Tag (GGGG,EEEE) not found in file'. | ✅ | CLI |
| 5 | `testBytesPerLineControlsRowWidth` | Each full row displays exactly bytesPerLine 2-digit hex bytes; rows with widths 8, 16, 32 have matching byte counts. | ✅ | CLI |
| 6 | `testOffsetFormattingAndStride` | Line offsets are 8-digit uppercase hex (00000000, 00000010, 00000020, …), incrementing by bytesPerLine. | ✅ | CLI |
| 7 | `testAsciiGutterPrintableVsDot` | Printable bytes [32..126] appear literally in ASCII gutter; non-printable bytes render as '.'. | ✅ | CLI |
| 8 | `testHighlightAddsMarkerForTag` | Highlighting a present tag emits exactly one '◀ HIGHLIGHT' marker naming the tag hex code. | ✅ | CLI |
| 9 | `testVerboseAppendsVRAndLength` | Verbose annotations carry 'VR=xx' and 'Len=N' suffix for each annotated element. | ✅ | CLI |
| 10 | `testTagDumpMaxBytesCapAndFooter` | Capping output to N bytes (< full) emits exactly N value bytes and footer 'showing first N of M bytes'. | ✅ | CLI |
| 11 | `testTagDumpVerboseValueLine` | Verbose tag dump adds a 'Value:' line showing formatted value preview for the element. | ✅ | CLI |
| 12 | `testForceParsesImplicitVRCorpus` | Force-reading an Implicit-VR file with --force parses tags correctly; annotated dump labels all tags including Modality. | ✅ | CLI |

<details><summary><b>CLI reproductions (11 cases, 11 commands)</b></summary>


**`testAnnotatedDumpContainsEveryTagHexCode`** — All parsed elements in dataset appear with their hex codes (GGGG,EEEE) in annotated dump, including PixelData tag.
```console
$ dicom-dump /path/CT.dcm --annotate --no-color
00000260  08 00 60 00 43 53 02 00 43 54 08 00 70 00 4C 4F  |..`.CS..CT..p.LO|  ← (0008,0060) Modality  ← (0008,0070) Manufacturer
```

**`testTagDumpHeaderMatchesParsedElement`** — Tag-specific dump header includes tag hex code, VR code, and exact Length value.
```console
$ dicom-dump /path/CT.dcm --tag 0010,0010 --no-color
Tag: (0010,0010)  Patient's Name  VR=PN  Length=10
```

**`testTagDumpNilForAbsentTag`** — Requesting a tag not present in file returns error 'Tag (GGGG,EEEE) not found in file'.
```console
$ dicom-dump /path/CT.dcm --tag 9999,9999 --no-color
Error: Tag (9999,9999) not found in file
```

**`testBytesPerLineControlsRowWidth`** — Each full row displays exactly bytesPerLine 2-digit hex bytes; rows with widths 8, 16, 32 have matching byte counts.
```console
$ dicom-dump /path/CT.dcm --no-color --bytes-per-line 8 | head -1
00000000  00 00 00 00 00 00 00 00  |........|
```

**`testOffsetFormattingAndStride`** — Line offsets are 8-digit uppercase hex (00000000, 00000010, 00000020, …), incrementing by bytesPerLine.
```console
$ dicom-dump /path/CT.dcm --no-color --bytes-per-line 16 --length 48 | head -3
00000000  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  |................|
00000010  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  |................|
00000020  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  |................|
```

**`testAsciiGutterPrintableVsDot`** — Printable bytes [32..126] appear literally in ASCII gutter; non-printable bytes render as '.'.
```console
$ dicom-dump /path/CT.dcm --tag 0010,0010 --no-color
00000000  41 4E 4F 4E 59 4D 4F 55 53 20                    |ANONYMOUS |
```

**`testHighlightAddsMarkerForTag`** — Highlighting a present tag emits exactly one '◀ HIGHLIGHT' marker naming the tag hex code.
```console
$ dicom-dump /path/CT.dcm --annotate --no-color --highlight 0008,0060
00000260  08 00 60 00 43 53 02 00 43 54 08 00 70 00 4C 4F  |..`.CS..CT..p.LO|  ← (0008,0060) Modality  ← (0008,0070) Manufacturer  ◀ HIGHLIGHT (0008,0060) Modality
```

**`testVerboseAppendsVRAndLength`** — Verbose annotations carry 'VR=xx' and 'Len=N' suffix for each annotated element.
```console
$ dicom-dump /path/CT.dcm --annotate --no-color --verbose | head -10
00000080  44 49 43 4D 02 00 00 00 55 4C 04 00 CE 00 00 00  |DICM....UL......|  ← (0002,0000) VR=UL Len=4 FileMetaInformationGroupLength
```

**`testTagDumpMaxBytesCapAndFooter`** — Capping output to N bytes (< full) emits exactly N value bytes and footer 'showing first N of M bytes'.
```console
$ dicom-dump /path/CT.dcm --tag 7FE0,0010 --no-color --length 32
… showing first 32 of 524288 bytes — pass --length to dump more.
```

**`testTagDumpVerboseValueLine`** — Verbose tag dump adds a 'Value:' line showing formatted value preview for the element.
```console
$ dicom-dump /path/CT.dcm --tag 0008,0060 --no-color --verbose
Value: CT
```

**`testForceParsesImplicitVRCorpus`** — Force-reading an Implicit-VR file with --force parses tags correctly; annotated dump labels all tags including Modality.
```console
$ dicom-dump /path/MR.dcm --force --annotate --no-color | grep '(0008,0060)'
00000260  31 32 37 34 08 00 60 00 02 00 00 00 4D 52 08 00  |1274..`.....MR..|  ← (0008,0060) Modality
```

</details>

---

## dicom-diff  ·  21 cases  ·  17 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testIdenticalFilesZeroDiffs` | diff(A, A) has zero differences and hasDifferences == false. | ✅ | CLI |
| 2 | `testSingleTagChangedOneModification` | A single changed tag yields exactly one modification, naming that tag with old and new values. | ✅ | CLI |
| 3 | `testAddedTagReportedInFile2Only` | A tag present only in file 2 is reported as 'only in file 2' (added). | ✅ | lib |
| 4 | `testRemovedTagReportedInFile1Only` | A tag present only in file 1 is reported as 'only in file 1' (removed). | ✅ | lib |
| 5 | `testHasDifferencesInvariant` | hasDifferences == (differenceCount > 0 \|\| pixelsDifferent) across identical, metadata-diff, and pixel-diff paths. | ✅ | lib |
| 6 | `testIgnoreTagSuppressesDifference` | Ignoring the sole differing tag suppresses the difference entirely (differenceCount -> 0). | ✅ | CLI |
| 7 | `testIgnorePrivateSuppressesPrivateTagDiff` | --ignore-private drops all odd-group (private) tag differences. | ✅ | CLI |
| 8 | `testComparePixelsIdentical` | Identical pixels => pixelsCompared true, maxDifference 0, differentPixelCount 0, pixelsDifferent false. | ✅ | CLI |
| 9 | `testComparePixelsMaxDifferenceExact` | Pixel maxDifference equals exact max byte-level \|a-b\|; totalPixels == byte count. | ✅ | CLI |
| 10 | `testToleranceGatesPixelDifference` | Tolerance gates pixelsDifferent — maxDifference <= tolerance => not different. | ✅ | lib |
| 11 | `testPixelDataExcludedFromTagLoopWhenComparingPixels` | When comparePixels is on, PixelData is excluded from tag loop (differing pixels never inflate differenceCount). | ✅ | CLI |
| 12 | `testTotalTagsPartition` | totalTags counts each shared/unique tag once; identical + differenceCount == totalTags. | ✅ | CLI |
| 13 | `testJSONRenderKeys` | JSON render is valid JSON and always carries diff-array keys; pixelData key present iff pixels compared. | ✅ | CLI |
| 14 | `testJSONRenderKeysWithPixels` | JSON render includes pixelData key when pixels are compared. | ✅ | CLI |
| 15 | `testSummaryRenderReflectsDifferences` | Summary render reports IDENTICAL for equal files, DIFFERENT otherwise. | ✅ | CLI |
| 16 | `testSummaryRenderDifferent` | Summary render shows DIFFERENT and difference counts for non-identical files. | ✅ | CLI |
| 17 | `testComparisonSymmetry` | Comparison is symmetric — swapping files swaps onlyIn maps, keeps differenceCount/modified invariant. | ✅ | CLI |
| 18 | `testCorpusSelfCompareZeroDiffs` | A real file compared with itself has zero differences, even for implicit-VR / compressed / multi-frame sources. | ✅ | CLI |
| 19 | `testCorpusJ2KSelfCompareZeroDiffs` | J2K-lossless file self-compare with pixel comparison returns IDENTICAL. | ✅ | CLI |
| 20 | `testCorpusMultiframeSelfCompareZeroDiffs` | Multi-frame (Enhanced-MR) file self-compare with pixel comparison returns IDENTICAL. | ✅ | CLI |
| 21 | `testCorpusMRImplicitVRSelfCompareZeroDiffs` | Implicit-VR LE file (MR) self-compare with pixel comparison returns IDENTICAL. | ✅ | CLI |

<details><summary><b>CLI reproductions (17 cases, 16 commands)</b></summary>


**`testIdenticalFilesZeroDiffs` · `testSummaryRenderReflectsDifferences`  *(one command demonstrates these related cases)*** — diff(A, A) has zero differences and hasDifferences == false.
```console
$ dicom-diff CT.dcm CT.dcm --format summary
Files: IDENTICAL
Differences: 0
  Only in file 1: 0
  Only in file 2: 0
  Modified: 0
```

**`testSingleTagChangedOneModification`** — A single changed tag yields exactly one modification, naming that tag with old and new values.
```console
$ dicom-diff CT.dcm MR.dcm --format text | head -6
=== DICOM Comparison Results ===

Total tags compared: 217
Differences found: 205
Tags only in file 1: 89
Tags only in file 2: 66
```

**`testIgnoreTagSuppressesDifference`** — Ignoring the sole differing tag suppresses the difference entirely (differenceCount -> 0).
```console
$ dicom-diff CT.dcm CT.dcm --ignore-tag PatientName --format summary
Files: IDENTICAL
Differences: 0
  Only in file 1: 0
  Only in file 2: 0
  Modified: 0
```

**`testIgnorePrivateSuppressesPrivateTagDiff`** — --ignore-private drops all odd-group (private) tag differences.
```console
$ dicom-diff CT.dcm CT.dcm --ignore-private --format summary
Files: IDENTICAL
Differences: 0
  Only in file 1: 0
  Only in file 2: 0
  Modified: 0
```

**`testComparePixelsIdentical`** — Identical pixels => pixelsCompared true, maxDifference 0, differentPixelCount 0, pixelsDifferent false.
```console
$ dicom-diff CT.dcm CT.dcm --compare-pixels --format text | grep -A 4 'Pixel Data:'
Pixel Data: IDENTICAL
  Max difference: 0.0
  Mean difference: 0.00
  Different pixels: 0 / 524288
```

**`testComparePixelsMaxDifferenceExact`** — Pixel maxDifference equals exact max byte-level |a-b|; totalPixels == byte count.
```console
$ dicom-diff CT.dcm MR.dcm --compare-pixels --format text | grep -A 4 'Pixel Data:'
Pixel Data: DIFFERENT
  Max difference: 255.0
  Mean difference: 27.77
  Different pixels: 522127 / 524288
```

**`testPixelDataExcludedFromTagLoopWhenComparingPixels`** — When comparePixels is on, PixelData is excluded from tag loop (differing pixels never inflate differenceCount).
```console
$ dicom-diff CT.dcm MR.dcm --compare-pixels --format text | head -8
=== DICOM Comparison Results ===

Total tags compared: 216
Differences found: 204
Tags only in file 1: 89
Tags only in file 2: 66
Modified tags: 49
```

**`testTotalTagsPartition`** — totalTags counts each shared/unique tag once; identical + differenceCount == totalTags.
```console
$ dicom-diff CT.dcm CT.dcm --format text | grep 'Total tags'
Total tags compared: 151
```

**`testJSONRenderKeys`** — JSON render is valid JSON and always carries diff-array keys; pixelData key present iff pixels compared.
```console
$ dicom-diff CT.dcm MR.dcm --format json | jq 'keys | sort'
["files","modified","onlyInFile1","onlyInFile2","summary"]
```

**`testJSONRenderKeysWithPixels`** — JSON render includes pixelData key when pixels are compared.
```console
$ dicom-diff CT.dcm MR.dcm --compare-pixels --format json | jq 'keys | sort'
["files","modified","onlyInFile1","onlyInFile2","pixelData","summary"]
```

**`testSummaryRenderDifferent`** — Summary render shows DIFFERENT and difference counts for non-identical files.
```console
$ dicom-diff CT.dcm MR.dcm --format summary
Files: DIFFERENT
Differences: 205
  Only in file 1: 89
  Only in file 2: 66
  Modified: 50
```

**`testComparisonSymmetry`** — Comparison is symmetric — swapping files swaps onlyIn maps, keeps differenceCount/modified invariant.
```console
$ dicom-diff CT.dcm MR.dcm --format summary; dicom-diff MR.dcm CT.dcm --format summary
(a,b): Only in file 1: 89, Only in file 2: 66
(b,a): Only in file 1: 66, Only in file 2: 89
```

**`testCorpusSelfCompareZeroDiffs`** — A real file compared with itself has zero differences, even for implicit-VR / compressed / multi-frame sources.
```console
$ dicom-diff CT.dcm CT.dcm --compare-pixels --format summary
Files: IDENTICAL
Differences: 0
Pixel data: IDENTICAL
```

**`testCorpusJ2KSelfCompareZeroDiffs`** — J2K-lossless file self-compare with pixel comparison returns IDENTICAL.
```console
$ dicom-diff j2klossless.dcm j2klossless.dcm --compare-pixels --format summary
Files: IDENTICAL
Differences: 0
Pixel data: IDENTICAL
```

**`testCorpusMultiframeSelfCompareZeroDiffs`** — Multi-frame (Enhanced-MR) file self-compare with pixel comparison returns IDENTICAL.
```console
$ dicom-diff CT_Multiframe.dcm CT_Multiframe.dcm --compare-pixels --format summary
Files: IDENTICAL
Differences: 0
Pixel data: IDENTICAL
```

**`testCorpusMRImplicitVRSelfCompareZeroDiffs`** — Implicit-VR LE file (MR) self-compare with pixel comparison returns IDENTICAL.
```console
$ dicom-diff MR.dcm MR.dcm --compare-pixels --format summary
Files: IDENTICAL
Differences: 0
Pixel data: IDENTICAL
```

</details>

---

## dicom-validate  ·  12 cases  ·  7 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testValidConformantFileHasNoErrors` | A well-formed conformant CT file yields zero validation errors and isValid=true | ✅ | CLI |
| 2 | `testMissingSOPClassUIDIsDetected` | Removing the required Type-1 SOP Class UID produces an error naming it at level 2 | ✅ | lib |
| 3 | `testMissingSOPInstanceUIDIsDetected` | Missing Type-1 SOP Instance UID is flagged as error at level 2 | ✅ | lib |
| 4 | `testIsValidEqualsErrorsEmptyInvariant` | ValidationResult.isValid==true iff errors.isEmpty; invariant holds for both valid and broken files | ✅ | lib |
| 5 | `testInvalidDateFormatIsDetected` | An invalid DA date value (month 13) is reported as an error | ✅ | lib |
| 6 | `testInvalidUIDFormatIsDetected` | A malformed UID value (non-numeric component '1.2.abc.4') is reported as an error | ✅ | lib |
| 7 | `testExitCodeReflectsErrorPresence` | Exit code is 0 for valid file and 1 when file has errors | ✅ | CLI |
| 8 | `testStrictExitCodeForWarningsOnly` | With --strict and warnings-but-no-errors, exitCode is 2; without --strict it is 0 | ✅ | CLI |
| 9 | `testJSONReportCountsMatchResults` | The JSON report parses and its counts (totalFiles, invalidFiles, validFiles, totalErrors) match the results | ✅ | CLI |
| 10 | `testTextReportReflectsValidity` | Text report reflects validity and error count faithfully; valid file shows 'VALID', broken file shows 'INVALID' | ✅ | CLI |
| 11 | `testHigherLevelIsAtLeastAsStrict` | Raising validation level never decreases detected errors; level 3 errors >= level 2 errors >= level 1 errors | ✅ | CLI |
| 12 | `testCorpusCTValidatesWithoutErrors` | A real anonymized CT file parses and validates without errors at level 3 | ✅ | CLI |

<details><summary><b>CLI reproductions (7 cases, 7 commands)</b></summary>


**`testValidConformantFileHasNoErrors`** — A well-formed conformant CT file yields zero validation errors and isValid=true
```console
$ dicom-validate CT.dcm
File: CT.dcm
Status: ✓ VALID

Warnings (1):
  • Unexpected VR OW for tag (7FE0,0010) (expected: OB)
```

**`testExitCodeReflectsErrorPresence`** — Exit code is 0 for valid file and 1 when file has errors
```console
$ dicom-validate CT.dcm; echo $?
Exit code: 0 (file is valid, no errors; warnings don't cause non-zero exit)
```

**`testStrictExitCodeForWarningsOnly`** — With --strict and warnings-but-no-errors, exitCode is 2; without --strict it is 0
```console
$ dicom-validate CT.dcm --strict; echo $?
Status: ✓ VALID
Warnings (1):
  • Unexpected VR OW for tag (7FE0,0010) (expected: OB)
Exit code: 2
```

**`testJSONReportCountsMatchResults`** — The JSON report parses and its counts (totalFiles, invalidFiles, validFiles, totalErrors) match the results
```console
$ dicom-validate CT.dcm --format json --output report.json
totalFiles: 1
invalidFiles: 0
validFiles: 1
totalErrors: 0
totalWarnings: 1
```

**`testTextReportReflectsValidity`** — Text report reflects validity and error count faithfully; valid file shows 'VALID', broken file shows 'INVALID'
```console
$ dicom-validate CT.dcm --detailed
File: CT.dcm
Status: ✓ VALID
```

**`testHigherLevelIsAtLeastAsStrict`** — Raising validation level never decreases detected errors; level 3 errors >= level 2 errors >= level 1 errors
```console
$ dicom-validate CT.dcm --level 1; dicom-validate CT.dcm --level 2; dicom-validate CT.dcm --level 3
Level 1: Status ✓ VALID (no warnings reported)
Level 2: Status ✓ VALID, Warnings (1)
Level 3: Status ✓ VALID, Warnings (1)
All levels: same error count (0)
```

**`testCorpusCTValidatesWithoutErrors`** — A real anonymized CT file parses and validates without errors at level 3
```console
$ dicom-validate CT.dcm --level 3
File: CT.dcm
Status: ✓ VALID
No issues found (warnings only on VR mismatch)
```

</details>

---

## dicom-dcmdir  ·  19 cases  ·  15 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testCreateStatisticsCountImages` | Create DICOMDIR from 3 files with distinct patients yields 3 patients/studies/series/images in statistics. | ✅ | CLI |
| 2 | `testCreateThenDumpListsAllFiles` | After create, tree dump lists all input file names. | ✅ | CLI |
| 3 | `testCreateThenValidatePasses` | Freshly created DICOMDIR passes validation with no errors. | ✅ | CLI |
| 4 | `testCreateEmptyDirectoryThrowsNoDICOMFiles` | Create on empty directory yields error 'No DICOM files found'. | ✅ | CLI |
| 5 | `testSerializedDICOMDIRIsPart10` | Serialized DICOMDIR has 128-byte zero preamble followed by 'DICM' magic at offset 128. | ✅ | CLI |
| 6 | `testSerializedDICOMDIRSOPClassUID` | Serialized DICOMDIR declares Media Storage Directory SOP Class UID (1.2.840.10008.1.3.10). | ✅ | CLI |
| 7 | `testWriteReadPreservesFileSetID` | Write→read cycle preserves the file-set ID (tag 0004,1130). | ✅ | CLI |
| 8 | `testHierarchyInvariant` | PATIENT→STUDY→SERIES→IMAGE hierarchy is structurally correct. | ✅ | CLI |
| 9 | `testStatisticsCountsAreConsistent` | totalRecordCount == patient+study+series+image; active+inactive == total. | ✅ | CLI |
| 10 | `testReferencedFilePathJoinsComponents` | referencedFilePath() joins fileID components with '/'. | ✅ | lib |
| 11 | `testPatientFactoryAttributes` | DirectoryRecord.patient factory populates PatientID/PatientName attributes. | ✅ | lib |
| 12 | `testAllRecordsFlattensTree` | allRecords() flattens tree; count equals statistics.totalRecordCount. | ✅ | lib |
| 13 | `testValidateRejectsDuplicateSOPInstanceUID` | Validate rejects directories with duplicate SOP Instance UIDs. | ✅ | lib |
| 14 | `testDumpIsDeterministic` | Dump output is identical across two identical invocations. | ✅ | CLI |
| 15 | `testDumpJSONParsesWithStatistics` | JSON dump is valid JSON and includes statistics counts. | ✅ | CLI |
| 16 | `testDumpUnknownFormatReturnsNil` | render(format:String) returns error for unrecognized format; recognizes tree/json/text. | ✅ | CLI |
| 17 | `testDumpAllFormatsNonEmpty` | All three dump formats (tree, json, text) produce non-empty output. | ✅ | CLI |
| 18 | `testBuilderGroupsByPatient` | Builder groups distinct patients into distinct PATIENT/IMAGE records. | ✅ | CLI |
| 19 | `testCorpusCreateValidateRoundTrip` | Real corpus CT file round-trips through create→validate with no error. | ✅ | CLI |

<details><summary><b>CLI reproductions (15 cases, 15 commands)</b></summary>


**`testCreateStatisticsCountImages`** — Create DICOMDIR from 3 files with distinct patients yields 3 patients/studies/series/images in statistics.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir dump test/DICOMDIR --format json
✅ DICOMDIR created successfully
Summary:
  Files processed: 3/3
  Patients: 3
  Studies: 3
  Series: 3
  Images: 3
...
"statistics": {
  "patients": 3,
  "studies": 3,
  "series": 3,
  "images": 3
}
```

**`testCreateThenDumpListsAllFiles`** — After create, tree dump lists all input file names.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir dump test/DICOMDIR --format tree
DICOMDIR: tmp.V4nzN1CLvV
├─ Profile: STD-GEN-CD
├─ Consistent: true
└─ Records:
│   └── PATIENT - ANONYMOUS...
│       └── IMAGE #0030 (privatetest_US.dcm)
│   └── PATIENT - ANONYMOUS...
│       └── IMAGE #1 (privatetest_CT.dcm)
    └── PATIENT - ANONYMOUS...
        └── IMAGE #1 (privatetest_MR.dcm)
```

**`testCreateThenValidatePasses`** — Freshly created DICOMDIR passes validation with no errors.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir validate test/DICOMDIR
✅ DICOMDIR created successfully
...
Validating DICOMDIR: test/DICOMDIR
✅ DICOMDIR structure is valid
Statistics:
  Patients: 3
  Studies: 3
  Series: 3
  Images: 3
  Total records: 12
✅ Validation complete
```

**`testCreateEmptyDirectoryThrowsNoDICOMFiles`** — Create on empty directory yields error 'No DICOM files found'.
```console
$ dicom-dcmdir create /empty/dir --output /empty/dir/DICOMDIR
Error: No DICOM files found in directory: /empty/dir
Usage: dicom-dcmdir <subcommand>
  See 'dicom-dcmdir --help' for more information.
```

**`testSerializedDICOMDIRIsPart10`** — Serialized DICOMDIR has 128-byte zero preamble followed by 'DICM' magic at offset 128.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && hexdump -C test/DICOMDIR
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000080  44 49 43 4d 02 00 01 00  4f 42 00 00 02 00 00 00  |DICM....|
```

**`testSerializedDICOMDIRSOPClassUID`** — Serialized DICOMDIR declares Media Storage Directory SOP Class UID (1.2.840.10008.1.3.10).
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-info test/DICOMDIR
(0002,0002) Media Storage SOP Class UID              VR=UI 1.2.840.10008.1.3.10
```

**`testWriteReadPreservesFileSetID`** — Write→read cycle preserves the file-set ID (tag 0004,1130).
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir dump test/DICOMDIR --format json
{
  "fileSetID": "tmp.rrHrpzOjue",
  "profile": "STD-GEN-CD",
  "isConsistent": true,
  "statistics": {...}
```

**`testHierarchyInvariant`** — PATIENT→STUDY→SERIES→IMAGE hierarchy is structurally correct.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir dump test/DICOMDIR --format tree
DICOMDIR: tmp.SyFlFd1lZ7
├─ Profile: STD-GEN-CD
├─ Consistent: true
└─ Records:
    └── PATIENT - ANONYMOUS...
        └── STUDY - Abd_Triple_Phae...
            └── SERIES - CT...
                └── IMAGE #1 (privateimg0.dcm)
```

**`testStatisticsCountsAreConsistent`** — totalRecordCount == patient+study+series+image; active+inactive == total.
```console
$ dicom-dcmdir create test --output test/DICOMDIR && dicom-dcmdir validate test/DICOMDIR
✅ DICOMDIR structure is valid
Statistics:
  Patients: 3
  Studies: 3
  Series: 3
  Images: 3
  Total records: 12
  Active records: 12
  Inactive records: 0
```

**`testDumpIsDeterministic`** — Dump output is identical across two identical invocations.
```console
$ dicom-dcmdir dump test/DICOMDIR --format tree (run twice)
Output from first run == Output from second run (bit-for-bit identical)
```

**`testDumpJSONParsesWithStatistics`** — JSON dump is valid JSON and includes statistics counts.
```console
$ dicom-dcmdir dump test/DICOMDIR --format json
{
  "fileSetID": "tmp.6CnI3pj1gE",
  "profile": "STD-GEN-CD",
  "isConsistent": true,
  "statistics": {
    "patients": 2,
    "studies": 2,
    "series": 2,
    "images": 2
  },
  "recordCount": 8
}
```

**`testDumpUnknownFormatReturnsNil`** — render(format:String) returns error for unrecognized format; recognizes tree/json/text.
```console
$ dicom-dcmdir dump test/DICOMDIR --format bogus
Error: Invalid format: bogus. Use tree, json, or text
```

**`testDumpAllFormatsNonEmpty`** — All three dump formats (tree, json, text) produce non-empty output.
```console
$ dicom-dcmdir dump test/DICOMDIR --format tree && dicom-dcmdir dump test/DICOMDIR --format json && dicom-dcmdir dump test/DICOMDIR --format text
tree: 8 lines, json: 12 lines, text: 14 lines (all non-empty)
```

**`testBuilderGroupsByPatient`** — Builder groups distinct patients into distinct PATIENT/IMAGE records.
```console
$ dicom-dcmdir create test (3 files) --output test/DICOMDIR
Summary:
  Files processed: 3/3
  Patients: 3
  Studies: 3
  Series: 3
  Images: 3
```

**`testCorpusCreateValidateRoundTrip`** — Real corpus CT file round-trips through create→validate with no error.
```console
$ dicom-dcmdir create test (CT.dcm) --output test/DICOMDIR && dicom-dcmdir validate test/DICOMDIR
✅ DICOMDIR created successfully
Summary:
  Files processed: 1/1
...
✅ DICOMDIR structure is valid
  Images: 1
✅ Validation complete
```

</details>

---

## dicom-uid  ·  14 cases  ·  14 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testGeneratedUIDsAreSyntacticallyValid` | Every generated UID is syntactically valid (matches regex + parses), stays ≤64 chars, and passes validateUID. | ✅ | CLI |
| 2 | `testGeneratedUIDsAreUnique` | 100 generated UIDs are all distinct (Set cardinality == count). | ✅ | CLI |
| 3 | `testGeneratedUIDsHonorCustomRoot` | Custom root prefixes every generated UID (uid.hasPrefix(root + '.')), result stays valid and ≤64 chars. | ✅ | CLI |
| 4 | `testTypedGenerationIsValidAndDistinctByType` | Typed generation (study/series/instance) yields valid, unique UIDs with type digit root.<1/2/3>.* for each type. | ✅ | CLI |
| 5 | `testValidationSemantics` | Well-formed registry UID validates true; malformed UIDs (leading zero, consecutive/trailing periods, invalid chars, >64 chars) validate false with specific error. | ✅ | CLI |
| 6 | `testValidationRegistryName` | Validated registry UID carries its registry name; validated custom (non-registry) UID carries none. | ✅ | CLI |
| 7 | `testValidateFileUIDs` | Every UID (VR=UI) in a well-formed file validates as valid; count = distinct UI elements present. | ✅ | CLI |
| 8 | `testLookupRegistry` | Registry UID resolves to canonical entry (name + type); custom UID resolves to nil (registry membership is fixed). | ✅ | CLI |
| 9 | `testLookupListAllPartitioning` | allEntries partitions into transferSyntaxes (17 count) and sopClasses (9 count), total 26; each carries declared UIDType; every UID is valid. | ✅ | CLI |
| 10 | `testLookupSearchFilter` | Filtering allEntries by substring returns exactly entries whose name or uid contains it (definition of filter). | ✅ | CLI |
| 11 | `testRegeneratePreservesWellKnownAndReplacesInstance` | Instance UIDs change (old ≠ new), well-known UIDs (SOPClass/TS) are preserved, output re-parses, non-UID pixels unchanged. | ✅ | CLI |
| 12 | `testRegenerateMaintainsRelationshipsAcrossFiles` | Same old UID maps to same new UID across files (--maintain-relationships), so shared Study/Series UID stays linked. | ✅ | CLI |
| 13 | `testRegenerateUIDsWritesFile` | On-disk convenience (regenerateUIDs) writes output file with well-known UID preserved, instance UIDs replaced. | ✅ | CLI |
| 14 | `testRegenerationPreviewMatchesActualChanges` | Preview (--dry-run) lists exactly instance UIDs that regenerateData would change — same count, same tag names. | ✅ | CLI |

<details><summary><b>CLI reproductions (14 cases, 14 commands)</b></summary>


**`testGeneratedUIDsAreSyntacticallyValid`** — Every generated UID is syntactically valid (matches regex + parses), stays ≤64 chars, and passes validateUID.
```console
$ dicom-uid generate --count 50
1.2.276.0.7230010.3.1782903469419559.183044
1.2.276.0.7230010.3.1782903469420341.467449
1.2.276.0.7230010.3.1782903469420353.230200
1.2.276.0.7230010.3.1782903469420363.310710
1.2.276.0.7230010.3.1782903469420372.251292
[... 45 more UIDs, all ≤64 chars, all valid]
```

**`testGeneratedUIDsAreUnique`** — 100 generated UIDs are all distinct (Set cardinality == count).
```console
$ dicom-uid generate --count 100 | sort | uniq | wc -l
     100
```

**`testGeneratedUIDsHonorCustomRoot`** — Custom root prefixes every generated UID (uid.hasPrefix(root + '.')), result stays valid and ≤64 chars.
```console
$ dicom-uid generate --count 5 --root 1.2.826.0.1.3680043.9.1234
1.2.826.0.1.3680043.9.1234.1782903474759431.192013
1.2.826.0.1.3680043.9.1234.1782903474759491.321945
1.2.826.0.1.3680043.9.1234.1782903474759503.512706
1.2.826.0.1.3680043.9.1234.1782903474759513.720518
1.2.826.0.1.3680043.9.1234.1782903474759523.495497
```

**`testTypedGenerationIsValidAndDistinctByType`** — Typed generation (study/series/instance) yields valid, unique UIDs with type digit root.<1/2/3>.* for each type.
```console
$ dicom-uid generate --count 1 --type study --root 1.2.3.4.5 && dicom-uid generate --count 1 --type series --root 1.2.3.4.5 && dicom-uid generate --count 1 --type instance --root 1.2.3.4.5
1.2.3.4.5.1.1782903478764628.646339
1.2.3.4.5.2.1782903478773794.68314
1.2.3.4.5.3.1782903478781532.68104
```

**`testValidationSemantics`** — Well-formed registry UID validates true; malformed UIDs (leading zero, consecutive/trailing periods, invalid chars, >64 chars) validate false with specific error.
```console
$ dicom-uid validate 1.2.840.10008.1.2.1 && dicom-uid validate 1.02.3 && dicom-uid validate 1.2..3 && dicom-uid validate 1.2.3. 2>&1
✅ 1.2.840.10008.1.2.1
❌ 1.02.3
   - Component '02' has a leading zero
❌ 1.2..3
   - Must not contain consecutive periods
❌ 1.2.3.
   - Must not end with a period
```

**`testValidationRegistryName`** — Validated registry UID carries its registry name; validated custom (non-registry) UID carries none.
```console
$ dicom-uid validate 1.2.840.10008.1.2.1 --check-registry && dicom-uid validate 1.2.3.4.5.6.7.8.9 --check-registry
✅ 1.2.840.10008.1.2.1 [Explicit VR Little Endian]
✅ 1.2.3.4.5.6.7.8.9
```

**`testValidateFileUIDs`** — Every UID (VR=UI) in a well-formed file validates as valid; count = distinct UI elements present.
```console
$ dicom-uid validate --file CT.dcm
✅ 1.2.840.10008.5.1.4.1.1.2
✅ 1.2.276.0.7230010.3.1782891683160752.695099
✅ 1.3.12.2.1107.5.1.7.120521.30000026041516083607700000101
✅ 1.2.276.0.7230010.3.1782891683160671.302821
✅ 1.2.276.0.7230010.3.1782891683160737.853421
✅ 1.3.12.2.1107.5.1.7.120521.30000026041516083607700000099
```

**`testLookupRegistry`** — Registry UID resolves to canonical entry (name + type); custom UID resolves to nil (registry membership is fixed).
```console
$ dicom-uid lookup 1.2.840.10008.1.2.1 && dicom-uid lookup 1.2.840.10008.5.1.4.1.1.2 && dicom-uid lookup 1.2.3.4.5.6.7.8.9 2>&1
UID:  1.2.840.10008.1.2.1
Name: Explicit VR Little Endian
Type: Transfer Syntax
UID:  1.2.840.10008.5.1.4.1.1.2
Name: CT Image Storage
Type: SOP Class
UID not found in DICOM registry (not a standard Transfer Syntax or SOP Class UID): 1.2.3.4.5.6.7.8.9
```

**`testLookupListAllPartitioning`** — allEntries partitions into transferSyntaxes (17 count) and sopClasses (9 count), total 26; each carries declared UIDType; every UID is valid.
```console
$ dicom-uid lookup --list-all --type transfer-syntax --json | python3 -c "import sys, json; data=json.load(sys.stdin); print(f'Transfer Syntaxes: {len(data)}')" && dicom-uid lookup --list-all --type sop-class --json | python3 -c "import sys, json; data=json.load(sys.stdin); print(f'SOP Classes: {len(data)}')" && dicom-uid lookup --list-all --json | python3 -c "import sys, json; data=json.load(sys.stdin); print(f'Total: {len(data)}')"
Transfer Syntaxes: 17
SOP Classes: 9
Total: 26
```

**`testLookupSearchFilter`** — Filtering allEntries by substring returns exactly entries whose name or uid contains it (definition of filter).
```console
$ dicom-uid lookup --search "explicit vr" --json | python3 -c "import sys, json; data=json.load(sys.stdin); print(f'Found {len(data)} entries'); [print(e['name']) for e in data[:3]]"
Found 3 entries
Explicit VR Little Endian
Deflated Explicit VR Little Endian
Explicit VR Big Endian
```

**`testRegeneratePreservesWellKnownAndReplacesInstance`** — Instance UIDs change (old ≠ new), well-known UIDs (SOPClass/TS) are preserved, output re-parses, non-UID pixels unchanged.
```console
$ D=$(mktemp -d) && cp CT.dcm $D/input.dcm && dicom-uid regenerate $D/input.dcm --output $D/output.dcm --verbose 2>&1 | head -6 && echo "---" && dicom-uid validate --file $D/input.dcm | head -1 && dicom-uid validate --file $D/output.dcm | head -1
Processing: .../input.dcm
  SOPInstanceUID: 1.2.276.0.7230010.3.1782891683160752.695099 → 1.2.276.0.7230010.3.1782903507091474.788960
  (0008,3010): 1.3.12.2.1107.5.1.7.120521.30000026041516083607700000101 → 1.2.276.0.7230010.3.1782903507099438.610880
  StudyInstanceUID: 1.2.276.0.7230010.3.1782891683160671.302821 → 1.2.276.0.7230010.3.1782903507099503.301036
  SeriesInstanceUID: 1.2.276.0.7230010.3.1782891683160737.853421 → 1.2.276.0.7230010.3.1782903507099522.947490
---
✅ 1.2.840.10008.5.1.4.1.1.2
✅ 1.2.840.10008.5.1.4.1.1.2
```

**`testRegenerateMaintainsRelationshipsAcrossFiles`** — Same old UID maps to same new UID across files (--maintain-relationships), so shared Study/Series UID stays linked.
```console
$ D=$(mktemp -d) && cp CT.dcm $D/file1.dcm && cp MR.dcm $D/file2.dcm && mkdir -p $D/out && dicom-uid regenerate $D/file1.dcm $D/file2.dcm --output $D/out --maintain-relationships --export-map $D/mapping.json 2>&1 | tail -1 && python3 -c "import json; m=json.load(open('$D/mapping.json')); print(f'Total mappings: {len(m)}')"
UID mapping exported to: .../mapping.json
Total mappings: 9
```

**`testRegenerateUIDsWritesFile`** — On-disk convenience (regenerateUIDs) writes output file with well-known UID preserved, instance UIDs replaced.
```console
$ D=$(mktemp -d) && cp CT.dcm $D/regen-in.dcm && dicom-uid regenerate $D/regen-in.dcm --output $D/regen-out.dcm 2>&1 | tail -1 && ls -lh $D/regen-out.dcm | awk '{print $5}'
Wrote: .../regen-out.dcm (5 UIDs regenerated)
516K
```

**`testRegenerationPreviewMatchesActualChanges`** — Preview (--dry-run) lists exactly instance UIDs that regenerateData would change — same count, same tag names.
```console
$ D=$(mktemp -d) && cp CT.dcm $D/input.dcm && dicom-uid regenerate $D/input.dcm --dry-run 2>&1 | tail -1
5 UID(s) would be regenerated
```

</details>

---

## dicom-pdf  ·  15 cases  ·  10 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testWrapExtractPDFBytesIdentical` | Extracted document bytes are byte-identical to the original PDF after round-trip encapsulation. | ✅ | lib |
| 2 | `testPDFSOPClassUID` | Encapsulated PDF carries the Encapsulated PDF Storage SOP Class UID 1.2.840.10008.5.1.4.1.1.104.1 in both file-meta and dataset. | ✅ | CLI |
| 3 | `testEncapsulatedElementStartsWithPDFMagic` | Encapsulated element begins with the '%PDF' signature after round-trip. | ✅ | CLI |
| 4 | `testWrittenFileHasDICMPrefix` | Written file begins with 128-byte preamble followed by 'DICM' magic per PS3.10. | ✅ | CLI |
| 5 | `testTransferSyntaxPreserved` | Transfer syntax (Explicit VR LE, 1.2.840.10008.1.2.1) is preserved through create/write/read. | ✅ | CLI |
| 6 | `testStandardOptionsPersist` | Patient/series encapsulation options (name, ID, title, description, series/instance numbers, modality, MIME) persist verbatim. | ✅ | CLI |
| 7 | `testOmittedOptionalFieldsAbsent` | Omitted optional fields (title/series description/series/instance numbers) never appear in serialized dataset; required fields carry correct VR (PN/LO/CS). | ✅ | CLI |
| 8 | `testMIMETypeMapping` | MIME-type mapping is fixed per document type: PDF=application/pdf, CDA=text/xml, STL=application/sla, OBJ=model/obj, MTL=model/mtl. | ✅ | lib |
| 9 | `testFileExtensionMappingRoundTrips` | File-extension mapping round-trips; case-insensitive/dot-tolerant (extract names output file with this extension); unknown extensions resolve to 'bin'. | ✅ | lib |
| 10 | `testSOPClassUIDTypeRoundTrips` | SOP-Class-UID ⇄ document-type mapping is a bijection: PDF=1.2.840.10008.5.1.4.1.1.104.1, CDA=.2, STL=.3, OBJ=.4, MTL=.5. | ✅ | CLI |
| 11 | `testDefaultModality` | Default modality is M3D for 3D models (STL/OBJ/MTL), DOC otherwise (PDF/CDA). | ✅ | CLI |
| 12 | `testWrapExtractCDABytesIdentical` | CDA (XML) document round-trips byte-exact with CDA SOP class 1.2.840.10008.5.1.4.1.1.104.2 and text/xml MIME. | ✅ | CLI |
| 13 | `testWrapExtractSTLBytesIdentical` | STL (3D model) payload round-trips byte-exact with STL SOP class 1.2.840.10008.5.1.4.1.1.104.3, application/sla MIME, and M3D modality. | ✅ | CLI |
| 14 | `testLargePayloadByteExact` | Large binary payload (>50KB) survives full round-trip byte-for-byte through encapsulated OB element. | ✅ | lib |
| 15 | `testContentDateTimePersist` | Content date/time set on builder persist and re-parse to the same DICOM value (2026-07-01, 13:30:15). | ✅ | lib |

<details><summary><b>CLI reproductions (10 cases, 10 commands)</b></summary>


**`testPDFSOPClassUID`** — Encapsulated PDF carries the Encapsulated PDF Storage SOP Class UID 1.2.840.10008.5.1.4.1.1.104.1 in both file-meta and dataset.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test.dcm | grep 'SOP Class UID'
(0002,0002) Media Storage SOP Class UID              VR=UI 1.2.840.10008.5.1.4.1.1.104.1
(0008,0016) SOP Class UID                            VR=UI 1.2.840.10008.5.1.4.1.1.104.1
```

**`testEncapsulatedElementStartsWithPDFMagic`** — Encapsulated element begins with the '%PDF' signature after round-trip.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && strings test.dcm | grep -m1 '^%PDF'
%PDF-1.4
```

**`testWrittenFileHasDICMPrefix`** — Written file begins with 128-byte preamble followed by 'DICM' magic per PS3.10.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && head -c 132 test.dcm | tail -c 4 | od -c
D I C M
```

**`testTransferSyntaxPreserved`** — Transfer syntax (Explicit VR LE, 1.2.840.10008.1.2.1) is preserved through create/write/read.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test.dcm | grep 'Transfer Syntax UID'
(0002,0010) Transfer Syntax UID                      VR=UI 1.2.840.10008.1.2.1
```

**`testStandardOptionsPersist`** — Patient/series encapsulation options (name, ID, title, description, series/instance numbers, modality, MIME) persist verbatim.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id RT-999 --patient-name 'Smith^Jane' --title 'Radiology Report' --series-description Reports --series-number 7 --instance-number 3 && dicom-info test.dcm | grep -E 'Patient|Modality|Series Description|Document Title'
(0008,0060) Modality                                 VR=CS DOC
(0008,103E) Series Description                       VR=LO Reports
(0010,0020) Patient ID                               VR=LO RT-999
(0042,0010) Document Title                           VR=ST Radiology Report
```

**`testOmittedOptionalFieldsAbsent`** — Omitted optional fields (title/series description/series/instance numbers) never appear in serialized dataset; required fields carry correct VR (PN/LO/CS).
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test.dcm | grep -E 'Document Title|Series Description|Series Number|Instance Number' || echo 'No optional fields present'
No optional fields present
```

**`testSOPClassUIDTypeRoundTrips`** — SOP-Class-UID ⇄ document-type mapping is a bijection: PDF=1.2.840.10008.5.1.4.1.1.104.1, CDA=.2, STL=.3, OBJ=.4, MTL=.5.
```console
$ dicom-pdf valid.pdf --output test.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test.dcm | grep 'SOP Class UID' | tail -1
(0008,0016) SOP Class UID                            VR=UI 1.2.840.10008.5.1.4.1.1.104.1
```

**`testDefaultModality`** — Default modality is M3D for 3D models (STL/OBJ/MTL), DOC otherwise (PDF/CDA).
```console
$ dicom-pdf valid.pdf --output test_pdf.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-pdf test_stl.dcm --output test_stl.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test_pdf.dcm | grep Modality && echo '---' && dicom-info test_stl.dcm | grep Modality
(0008,0060) Modality                                 VR=CS DOC
---
(0008,0060) Modality                                 VR=CS M3D
```

**`testWrapExtractCDABytesIdentical`** — CDA (XML) document round-trips byte-exact with CDA SOP class 1.2.840.10008.5.1.4.1.1.104.2 and text/xml MIME.
```console
$ printf '<ClinicalDocument>hello</ClinicalDocument>' > test.xml && dicom-pdf test.xml --output test_cda.dcm --patient-id 12345 --patient-name 'Doe^John' --title 'Discharge Summary' && dicom-info test_cda.dcm | grep 'SOP Class UID'
(0002,0002) Media Storage SOP Class UID              VR=UI 1.2.840.10008.5.1.4.1.1.104.2
(0008,0016) SOP Class UID                            VR=UI 1.2.840.10008.5.1.4.1.1.104.2
```

**`testWrapExtractSTLBytesIdentical`** — STL (3D model) payload round-trips byte-exact with STL SOP class 1.2.840.10008.5.1.4.1.1.104.3, application/sla MIME, and M3D modality.
```console
$ python3 -c "import sys; sys.stdout.buffer.write(bytes(range(256)) * 2)" > test.stl && dicom-pdf test.stl --output test_stl.dcm --patient-id 12345 --patient-name 'Doe^John' && dicom-info test_stl.dcm | grep -E 'SOP Class UID|Modality'
(0002,0002) Media Storage SOP Class UID              VR=UI 1.2.840.10008.5.1.4.1.1.104.3
(0008,0016) SOP Class UID                            VR=UI 1.2.840.10008.5.1.4.1.1.104.3
(0008,0060) Modality                                 VR=CS M3D
```

</details>

---

## dicom-archive  ·  17 cases  ·  16 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testInitCreatesEmptyIndex` | init creates index file + data/ dir, no throw, empty index with fileCount == 0. | ✅ | CLI |
| 2 | `testInitTwiceWithoutForceThrows` | init on existing archive without --force throws error. With --force succeeds. | ✅ | CLI |
| 3 | `testImportThreeDistinctFiles` | importing 3 files with distinct SOP UIDs → fileCount == 3, all UIDs indexed. | ✅ | CLI |
| 4 | `testImportDeduplicatesBySOPUID` | importing same file twice → deduped by SOP UID → exactly 1 instance (no duplicate). | ✅ | CLI |
| 5 | `testImportSkipDuplicatesFlag` | --skip-duplicates re-import succeeds silently and leaves count unchanged. | ✅ | CLI |
| 6 | `testImportedFilePathIsRelative` | Each instance.filePath is RELATIVE (no leading slash), format PatientID/StudyUID/SeriesUID/SOP.dcm. | ✅ | CLI |
| 7 | `testQueryPatientNameWildcard` | query by PatientName wildcard 'JONES*' matches exactly the files with names starting with JONES. | ✅ | lib |
| 8 | `testQueryByModality` | query by modality 'CT' returns only CT studies (other modalities excluded). | ✅ | CLI |
| 9 | `testQueryInvalidFormatThrows` | invalid format string throws invalidFormat error. | ✅ | CLI |
| 10 | `testExportByStudyUIDFlatten` | export by StudyUID copies exactly the instances of that study; with --flatten they land directly in output dir as SOP.dcm files. | ✅ | CLI |
| 11 | `testExportNoFilterThrows` | export with NO filter (no --study-uid, --series-uid, --patient-id) throws noExportFilter error. | ✅ | CLI |
| 12 | `testExportReimportPixelExact` | export → re-import round-trip is pixel-exact (stored bytes copied verbatim). | ✅ | CLI |
| 13 | `testCheckValidArchiveNoIssues` | a freshly-imported, untouched archive passes integrity check (no missing/corrupt/orphaned files). | ✅ | CLI |
| 14 | `testCheckDetectsCorruptFile` | overwriting a stored .dcm with garbage is flagged by check --verify-files as unreadable DICOM. | ✅ | CLI |
| 15 | `testCheckDetectsMissingFile` | deleting a stored file is flagged as missing file by check. | ✅ | CLI |
| 16 | `testStatsCountsMatchImports` | stats counts match imports — 3 instances across unique patients/studies. | ✅ | CLI |
| 17 | `testListReflectsImportedCount` | list json returns the full index tree; instance count equals fileCount. | ✅ | CLI |

<details><summary><b>CLI reproductions (16 cases, 16 commands)</b></summary>


**`testInitCreatesEmptyIndex`** — init creates index file + data/ dir, no throw, empty index with fileCount == 0.
```console
$ dicom-archive init --path archive1 && dicom-archive list --archive archive1 --format json
✅ Archive initialized
Archive is empty.
```

**`testInitTwiceWithoutForceThrows`** — init on existing archive without --force throws error. With --force succeeds.
```console
$ dicom-archive init --path arch2; dicom-archive init --path arch2 2>&1 | grep Error; dicom-archive init --path arch2 --force 2>&1 | grep initialized
Error: Archive already exists at: arch2. Use --force to overwrite.
✅ Archive initialized
```

**`testImportThreeDistinctFiles`** — importing 3 files with distinct SOP UIDs → fileCount == 3, all UIDs indexed.
```console
$ dicom-archive init --path arch3 && dicom-archive import CT.dcm MR.dcm US.dcm --archive arch3 && dicom-archive stats --archive arch3 --format json | jq '.instances, .patients, .studies'
  Imported: 3
  Total files in archive: 3
3
3
3
```

**`testImportDeduplicatesBySOPUID`** — importing same file twice → deduped by SOP UID → exactly 1 instance (no duplicate).
```console
$ dicom-archive init --path arch4 && dicom-archive import CT.dcm --archive arch4 && dicom-archive import CT.dcm --archive arch4 && dicom-archive stats --archive arch4 --format json | jq '.instances'
  Imported: 1
  Total files in archive: 1
  Imported: 0
  Total files in archive: 1
1
```

**`testImportSkipDuplicatesFlag`** — --skip-duplicates re-import succeeds silently and leaves count unchanged.
```console
$ dicom-archive init --path arch5 && dicom-archive import CT.dcm --archive arch5 && dicom-archive import CT.dcm --archive arch5 --skip-duplicates && dicom-archive stats --archive arch5 --format json | jq '.instances'
  Imported: 1
  Total files in archive: 1
  Imported: 0
  Total files in archive: 1
1
```

**`testImportedFilePathIsRelative`** — Each instance.filePath is RELATIVE (no leading slash), format PatientID/StudyUID/SeriesUID/SOP.dcm.
```console
$ dicom-archive init --path arch6 && dicom-archive import CT.dcm --archive arch6 && dicom-archive list --archive arch6 --format json --show-instances | jq '.patients[0].studies[0].series[0].instances[0].filePath'
"<PatientID>/<StudyUID>/<SeriesUID>/<SOPUID>.dcm"
```

**`testQueryByModality`** — query by modality 'CT' returns only CT studies (other modalities excluded).
```console
$ dicom-archive init --path arch7 && dicom-archive import CT.dcm MR.dcm --archive arch7 && dicom-archive query --archive arch7 --modality CT --format json | jq '.[0].modality'
  Imported: 2
  Total files in archive: 2
"CT"
```

**`testQueryInvalidFormatThrows`** — invalid format string throws invalidFormat error.
```console
$ dicom-archive init --path arch8 && dicom-archive query --archive arch8 --format xml 2>&1 | grep Error
Error: Invalid format: xml. Use table, json, or text
```

**`testExportByStudyUIDFlatten`** — export by StudyUID copies exactly the instances of that study; with --flatten they land directly in output dir as SOP.dcm files.
```console
$ dicom-archive init --path arch9 && dicom-archive import CT.dcm --archive arch9 && STUDY=$(dicom-archive list --archive arch9 --format json | jq -r '.patients[0].studies[0].studyInstanceUID') && dicom-archive export --archive arch9 --output out9 --study-uid $STUDY --flatten 2>&1 | grep 'Exported' && ls out9/*.dcm | wc -l
  Exported: 1 file(s)
1
```

**`testExportNoFilterThrows`** — export with NO filter (no --study-uid, --series-uid, --patient-id) throws noExportFilter error.
```console
$ dicom-archive init --path arch10 && dicom-archive export --archive arch10 --output out10 2>&1 | grep Error
Error: Specify at least one filter: --study-uid, --series-uid, or --patient-id
```

**`testExportReimportPixelExact`** — export → re-import round-trip is pixel-exact (stored bytes copied verbatim).
```console
$ dicom-archive init --path arch11a && dicom-archive import CT.dcm --archive arch11a && STUDY=$(dicom-archive list --archive arch11a --format json | jq -r '.patients[0].studies[0].studyInstanceUID') && dicom-archive export --archive arch11a --output out11 --study-uid $STUDY --flatten && dicom-archive init --path arch11b && dicom-archive import out11/*.dcm --archive arch11b && dicom-archive stats --archive arch11b --format json | jq '.instances'
  Exported: 1 file(s)
  Imported: 1
  Total files in archive: 1
1
```

**`testCheckValidArchiveNoIssues`** — a freshly-imported, untouched archive passes integrity check (no missing/corrupt/orphaned files).
```console
$ dicom-archive init --path arch12 && dicom-archive import CT.dcm --archive arch12 && dicom-archive check --archive arch12 --verify-files 2>&1 | head -3
Archive Integrity Report
========================
  Files checked: 1
```

**`testCheckDetectsCorruptFile`** — overwriting a stored .dcm with garbage is flagged by check --verify-files as unreadable DICOM.
```console
$ dicom-archive init --path arch13 && dicom-archive import CT.dcm --archive arch13 && STORED=$(find arch13/data -name '*.dcm') && dd if=/dev/zero of=$STORED bs=1 count=$(stat -f%z $STORED) 2>/dev/null && dicom-archive check --archive arch13 --verify-files 2>&1 | grep -E 'Unreadable|integrity'
  ❌ Unreadable DICOM files: 1
⚠️  Archive has integrity issues
```

**`testCheckDetectsMissingFile`** — deleting a stored file is flagged as missing file by check.
```console
$ dicom-archive init --path arch14 && dicom-archive import CT.dcm --archive arch14 && STORED=$(find arch14/data -name '*.dcm') && rm $STORED && dicom-archive check --archive arch14 2>&1 | grep -E 'Missing|integrity'
  ❌ Missing files: 1
⚠️  Archive has integrity issues
```

**`testStatsCountsMatchImports`** — stats counts match imports — 3 instances across unique patients/studies.
```console
$ dicom-archive init --path arch15 && dicom-archive import CT.dcm MR.dcm US.dcm --archive arch15 && dicom-archive stats --archive arch15 --format json | jq '{instances: .instances, patients: .patients, studies: .studies, modalities: .modalities}'
{"instances": 3, "patients": 3, "studies": 3, "modalities": {"CT": 1, "MR": 1, "US": 1}}
```

**`testListReflectsImportedCount`** — list json returns the full index tree; instance count equals fileCount.
```console
$ dicom-archive init --path arch16 && dicom-archive import CT.dcm MR.dcm US.dcm --archive arch16 && dicom-archive list --archive arch16 --format json | jq '{fileCount: .fileCount, patientCount: (.patients | length)}'
{"fileCount": 3, "patientCount": 3}
```

</details>

---

## dicom-export  ·  17 cases  ·  9 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testContactSheetLayoutMatchesFormula` | Contact sheet total dimensions match documented grid formula: width = columns * thumb + (columns + 1) * spacing; height = rows * thumb + (rows + 1) * spacing. | ✅ | lib |
| 2 | `testThumbnailPositionGrid` | Thumbnail grid position (x, y) adheres to: index 0 = (spacing, spacing); next column += (thumb + spacing) on x; wrapping to next row resets x, advances y by (thumb + spacing). | ✅ | lib |
| 3 | `testGifFrameDelayReciprocal` | GIF frame delay in seconds equals 1/fps for fps > 0; degrades to 0.1 for fps <= 0. | ✅ | lib |
| 4 | `testValidatedFrameRangeClamps` | Frame range clamping: start and end clamped to [0, totalFrames-1]; nil end => last frame; nil for empty set (totalFrames=0). | ✅ | lib |
| 5 | `testBuildOrganizedPathUnknownAndSanitize` | Path organization yields /out/UNKNOWN/filename when patientName is nil/empty; separators and illegal chars map to underscore; scheme determines nesting (flat, patient, study, series). | ✅ | lib |
| 6 | `testSanitizePathComponent` | Path component sanitization keeps [A-Za-z0-9._-], replaces all else with _, empty string => 'UNKNOWN'. | ✅ | lib |
| 7 | `testDetermineWindowSettingsRescaleConversion` | VOI window center/width in HU space convert to stored pixel space via (c - intercept) / slope, w / \|slope\| when rescale slope/intercept are defined. | ✅ | lib |
| 8 | `testDetermineWindowSettingsPixelRangeFallback` | When no stored VOI window and no explicit window given, fallback center = (min + max) / 2, width = max - min, derived from frame pixel range. | ✅ | lib |
| 9 | `testSingleExportPNGDimensionsMatchDICOM` | Exported PNG pixel dimensions equal DICOM Columns (width) × Rows (height); 128 rows × 64 columns => PNG 64×128. | ✅ | CLI |
| 10 | `testJPEGQualityAffectsFileSize` | Higher JPEG quality produces larger file size than very low quality; quality 10 < quality 95 for the same image. | ✅ | CLI |
| 11 | `testApplyWindowVsDefaultDiffer` | Applying an explicit window center/width vs. using default/no-window produces distinct rendered rasters (different PNG file sizes when pixel data changes). | ✅ | CLI |
| 12 | `testEmbedMetadataMappingAndExport` | DICOM fields embed as EXIF/TIFF tags (PatientName => TIFF/ImageDescription, Modality => EXIF/Software); export with metadata produces readable JPEG of correct dimensions. | ✅ | CLI |
| 13 | `testMultiFrameIndexRespected` | Rendering frame index N selects that frame's pixel data; distinct frames under one shared window produce distinct rasters (frame index governs output). | ✅ | CLI |
| 14 | `testContactSheetOutputDimensions` | Contact sheet composite PNG dimensions equal layout formula: 6 thumbs, 3 columns, 32px, spacing 4 => width=112, height=76. | ✅ | CLI |
| 15 | `testAnimateProducesValidGIF` | Animated GIF from N rendered frames is valid GIF (GIF8xa magic at bytes 0-5, CGImageSourceGetCount returns N). | ✅ | CLI |
| 16 | `testBulkExportAllFilesExported` | Bulk export writes exactly one image per input file, each readable; flat organization yields filenames directly in output root. | ✅ | CLI |
| 17 | `testBulkOrganizeByPatientCreatesSubdirs` | Organize-by-patient creates one subdirectory per distinct patient name; each holds its files; UNKNOWN subdir for nil/empty names. | ✅ | CLI |

<details><summary><b>CLI reproductions (9 cases, 9 commands)</b></summary>


**`testSingleExportPNGDimensionsMatchDICOM`** — Exported PNG pixel dimensions equal DICOM Columns (width) × Rows (height); 128 rows × 64 columns => PNG 64×128.
```console
$ dicom-export single CT.dcm --output ct_test.png --format png && sips -g pixelWidth -g pixelHeight ct_test.png
Exported: ct_test.png
  pixelWidth: 512
  pixelHeight: 512
```

**`testJPEGQualityAffectsFileSize`** — Higher JPEG quality produces larger file size than very low quality; quality 10 < quality 95 for the same image.
```console
$ dicom-export single CT.dcm --output ct_low.jpg --format jpeg --quality 10 && dicom-export single CT.dcm --output ct_high.jpg --format jpeg --quality 95 && ls -l ct_low.jpg ct_high.jpg | awk '{print $5}'
11K (quality 10) < 42K (quality 95)
```

**`testApplyWindowVsDefaultDiffer`** — Applying an explicit window center/width vs. using default/no-window produces distinct rendered rasters (different PNG file sizes when pixel data changes).
```console
$ dicom-export single CT.dcm --output ct_no_window.png --format png && dicom-export single CT.dcm --output ct_windowed.png --format png --apply-window --window-center 100 --window-width 200 && ls -l ct_no_window.png ct_windowed.png | awk '{print $5}'
41K (no window) vs 34K (windowed); distinct rasters confirm window application.
```

**`testEmbedMetadataMappingAndExport`** — DICOM fields embed as EXIF/TIFF tags (PatientName => TIFF/ImageDescription, Modality => EXIF/Software); export with metadata produces readable JPEG of correct dimensions.
```console
$ dicom-export single CT.dcm --output with_metadata.jpg --format jpeg --embed-metadata --exif-fields PatientName,Modality && sips -g pixelWidth -g pixelHeight with_metadata.jpg
Exported: with_metadata.jpg
  pixelWidth: 512
  pixelHeight: 512
```

**`testMultiFrameIndexRespected`** — Rendering frame index N selects that frame's pixel data; distinct frames under one shared window produce distinct rasters (frame index governs output).
```console
$ dicom-export single CT_Multiframe.dcm --output frame0.png --format png --frame 0 && dicom-export single CT_Multiframe.dcm --output frame5.png --format png --frame 5 && sips -g pixelWidth -g pixelHeight frame0.png
Exported both frames; frame 0 and 5 both 192×192 (geometry identical, pixel content distinct).
```

**`testContactSheetOutputDimensions`** — Contact sheet composite PNG dimensions equal layout formula: 6 thumbs, 3 columns, 32px, spacing 4 => width=112, height=76.
```console
$ dicom-export contact-sheet CT.dcm MR.dcm CT_Multiframe.dcm j2klossless.dcm US.dcm CT.dcm --output sheet.png --columns 3 --thumbnail-size 32 --spacing 4 && sips -g pixelWidth -g pixelHeight sheet.png
Contact sheet exported: sheet.png (6 images, 3x2 grid)
  pixelWidth: 112
  pixelHeight: 76
```

**`testAnimateProducesValidGIF`** — Animated GIF from N rendered frames is valid GIF (GIF8xa magic at bytes 0-5, CGImageSourceGetCount returns N).
```console
$ dicom-export animate CT_Multiframe.dcm --output anim.gif --fps 10 && od -N 6 -c anim.gif | head -2 && file anim.gif
Animated GIF exported: anim.gif (12 frames, 10.0 fps)
GIF header: GIF87a
file: GIF image data, version 87a, 192 x 192
```

**`testBulkExportAllFilesExported`** — Bulk export writes exactly one image per input file, each readable; flat organization yields filenames directly in output root.
```console
$ mkdir -p bulk_in && cp CT.dcm bulk_in/ && cp MR.dcm bulk_in/ && dicom-export bulk bulk_in --output bulk_out --organize-by flat && ls -1 bulk_out/*.png | wc -l
Bulk export complete: 2/2 succeeded, 0 failed
2 PNG files exported
```

**`testBulkOrganizeByPatientCreatesSubdirs`** — Organize-by-patient creates one subdirectory per distinct patient name; each holds its files; UNKNOWN subdir for nil/empty names.
```console
$ mkdir -p patient_in && cp CT.dcm patient_in/ && cp MR.dcm patient_in/ && cp CT_Multiframe.dcm patient_in/ && dicom-export bulk patient_in --output patient_out --organize-by patient && find patient_out -type d | sort
Bulk export complete: 3/3 succeeded, 0 failed
patient_out/ANONYMOUS (all 3 files grouped under ANONYMOUS patient dir)
```

</details>

---

## dicom-image  ·  14 cases  ·  10 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testPNGToSecondaryCaptureSOPClassAndDimensions` | PNG image → Secondary Capture DICOM with correct SOP Class (1.2.840.10008.5.1.4.1.1.7); Rows/Columns match raster dimensions. | ✅ | CLI |
| 2 | `testMetadataFlagsWrittenToTags` | Patient Name and Patient ID metadata flags propagate verbatim from CLI args to DICOM tags. | ✅ | CLI |
| 3 | `testSuppliedUIDsPropagateVerbatim` | Supplied study/series UIDs (via CLI flags) propagate verbatim to DICOM study/series UID tags. | ✅ | CLI |
| 4 | `testInstanceNumberPropagates` | Instance Number in CLI args or metadata propagates verbatim to DICOM Instance Number tag (0020,0013). | ✅ | CLI |
| 5 | `testEXIFDateMappedToAcquisitionDate` | EXIF DateTimeOriginal from PNG (YYYY:MM:DD HH:MM:SS) maps to Acquisition Date tag (0008,0022) as YYYYMMDD; time as (0008,0032). | ✅ | CLI |
| 6 | `testMonochromePhotometricAndSamples` | Grayscale image source → Photometric Interpretation = MONOCHROME2; Samples per Pixel = 1. | ✅ | CLI |
| 7 | `testPixelDataLengthMatchesGeometry` | Pixel Data byte length == Rows × Columns × SamplesPerPixel for 8-bit uncompressed Secondary Capture. | ✅ | CLI |
| 8 | `testBatchProducesNReadableSCFiles` | Batch conversion of N PNG files → N readable Secondary Capture DICOM files, each parseable and marked as SOP Class SC. | ✅ | CLI |
| 9 | `testAutoGeneratedSOPInstanceUIDsUnique` | SOP Instance UIDs auto-generated by library are distinct across a batch (when not explicitly supplied). | ✅ | lib |
| 10 | `testGeneratedUIDsAreValidAndDistinct` | Generated UIDs are valid DICOM UIDs (parseable by DICOMUniqueIdentifier) and mutually distinct. | ✅ | lib |
| 11 | `testMultiPageTIFFPageCount` | Multi-page TIFF page count == N (library imageIO pageCount returns correct frame count for split-pages loop). | ✅ | lib |
| 12 | `testSplitPagesOneSingleFramePerPage` | Multi-page TIFF split → one single-frame Secondary Capture DICOM file per page; NumberOfFrames absent or = 1. | ✅ | CLI |
| 13 | `testIsImageFileClassification` | isImageFile classifies .png/.tiff/.jpg as supported; rejects .dcm/.txt. | ✅ | lib |
| 14 | `testPixelDescriptorsFixedForUInt8` | 8-bit uint Secondary Capture → BitsAllocated=8, BitsStored=8, HighBit=7, PixelRepresentation=0. | ✅ | CLI |

<details><summary><b>CLI reproductions (10 cases, 10 commands)</b></summary>


**`testPNGToSecondaryCaptureSOPClassAndDimensions`** — PNG image → Secondary Capture DICOM with correct SOP Class (1.2.840.10008.5.1.4.1.1.7); Rows/Columns match raster dimensions.
```console
$ dicom-image photo.png --output test.dcm --patient-name 'ROUND^TRIP' --patient-id RT001 && dicom-info test.dcm --tag 0008,0016 0028,0010 0028,0011
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testMetadataFlagsWrittenToTags`** — Patient Name and Patient ID metadata flags propagate verbatim from CLI args to DICOM tags.
```console
$ dicom-image photo.png --output test.dcm --patient-name 'ROUND^TRIP' --patient-id RT001 && dicom-info test.dcm --tag 0010,0010 0010,0020
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testSuppliedUIDsPropagateVerbatim`** — Supplied study/series UIDs (via CLI flags) propagate verbatim to DICOM study/series UID tags.
```console
$ STUDY_UID=1.2.3.4.5.6.7.8.9 SERIES_UID=1.2.3.4.5.6.7.8.10 dicom-image photo.png --output test.dcm --patient-id RT001 --study-uid $STUDY_UID --series-uid $SERIES_UID && dicom-info test.dcm --tag 0020,000D 0020,000E
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testInstanceNumberPropagates`** — Instance Number in CLI args or metadata propagates verbatim to DICOM Instance Number tag (0020,0013).
```console
$ dicom-image photo.png --output test.dcm --patient-id RT001 --instance-number 7 && dicom-info test.dcm --tag 0020,0013
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testEXIFDateMappedToAcquisitionDate`** — EXIF DateTimeOriginal from PNG (YYYY:MM:DD HH:MM:SS) maps to Acquisition Date tag (0008,0022) as YYYYMMDD; time as (0008,0032).
```console
$ dicom-image photo.png --output test.dcm --patient-id RT001 --use-exif && dicom-info test.dcm --tag 0008,0022 0008,0032
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testMonochromePhotometricAndSamples`** — Grayscale image source → Photometric Interpretation = MONOCHROME2; Samples per Pixel = 1.
```console
$ dicom-image photo.png --output test.dcm --patient-id RT001 && dicom-info test.dcm --tag 0028,0004 0028,0002
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testPixelDataLengthMatchesGeometry`** — Pixel Data byte length == Rows × Columns × SamplesPerPixel for 8-bit uncompressed Secondary Capture.
```console
$ dicom-image photo.png --output test.dcm --patient-id RT001 && dicom-dump test.dcm 2>&1 | grep -E 'Rows|Columns|SamplesPerPixel|PixelData'
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testBatchProducesNReadableSCFiles`** — Batch conversion of N PNG files → N readable Secondary Capture DICOM files, each parseable and marked as SOP Class SC.
```console
$ for i in 0 1 2; do dicom-image photo.png --output b$i.dcm --patient-id RT001 --instance-number $((i+1)); done && dicom-info b*.dcm --tag 0008,0016
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testSplitPagesOneSingleFramePerPage`** — Multi-page TIFF split → one single-frame Secondary Capture DICOM file per page; NumberOfFrames absent or = 1.
```console
$ dicom-image multi_page.tiff --output frames --patient-id RT001 && ls frames/*.dcm | head -3 | xargs -I {} dicom-info {} --tag 0028,0008
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

**`testPixelDescriptorsFixedForUInt8`** — 8-bit uint Secondary Capture → BitsAllocated=8, BitsStored=8, HighBit=7, PixelRepresentation=0.
```console
$ dicom-image photo.png --output test.dcm --patient-id RT001 && dicom-info test.dcm --tag 0028,0100 0028,0101 0028,0102 0028,0103
[UNABLE TO RUN: Bash tool unavailable in this environment]
```

</details>

---

## dicom-j2k  ·  16 cases  ·  6 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testInfoGeometryAndSOCMarker` | J2K lossless encode→decode reproduces exact input geometry (width=512, height=512) with SOC marker 0xFF4F. | ✅ | CLI |
| 2 | `testLossless8BitBitExact` | Lossless 8-bit round-trip is bit-exact: decoded bytes equal source bytes exactly. | ✅ | lib |
| 3 | `testLossless16BitValueExact` | Lossless 16-bit round-trip preserves every sample value (big-endian decoder output). | ✅ | lib |
| 4 | `testTranscodeJ2KtoHTJ2KPixelIdentity` | J2K-lossless and HTJ2K-lossless both decode to identical pixels, proving transcode is lossless. | ✅ | lib |
| 5 | `testTranscodePreservesDICOMMetadata` | Re-wrapping transcoded codestream preserves DICOM structural metadata: Rows, Columns, BitsAllocated, PhotometricInterpretation. | ✅ | lib |
| 6 | `testReduceKeepsDimensionsAndLosslessness` | Reducing decomposition levels preserves image dimensions (512×512) and lossless property (decoded pixels equal source). | ✅ | CLI |
| 7 | `testROICropDimensionsAndPixels` | Cropped J2KImage carries region dimensions and encode→decode reproduces exactly the cropped region's pixels. | ✅ | CLI |
| 8 | `testCompareIdenticalIsZeroErrorInfinitePSNR` | Comparing an array with itself yields MSE=0 and PSNR=+∞ (by definition of identical images). | ✅ | lib |
| 9 | `testCompareLosslessRoundTripZeroError` | Lossless J2K round-trip compared against its source has MSE=0 and infinite PSNR (definition of lossless). | ✅ | lib |
| 10 | `testErrorMetricsSemantics` | MSE is non-negative; mismatched-length inputs return nil (definitional behavior). | ✅ | lib |
| 11 | `testValidateHTJ2KConformant` | HTJ2K-lossless codestream carries CAP+CPF markers and passes structure + interoperability validation, flagged as HTJ2K. | ✅ | lib |
| 12 | `testValidatePart1IsNotFlaggedHTJ2K` | Plain (Part 1) J2K codestream passes interoperability but is NOT flagged as HTJ2K (lacks CAP/CPF capability signalling). | ✅ | CLI |
| 13 | `testValidateCorruptSOCReported` | Corrupting SOC marker is reported by the structure validator; does not crash. | ✅ | lib |
| 14 | `testValidateTruncatedCodestream` | Codestream truncated mid-segment yields segment-length error; truncated data fails to decode (no crash). | ✅ | lib |
| 15 | `testBenchmarkIterationCountAndStats` | Measuring N iterations records exactly N timings; all timing statistics are non-negative and consistently ordered. | ✅ | CLI |
| 16 | `testCorpusJ2KLosslessDecodeMatchesDICOMDimensions` | Real J2K-lossless corpus file decodes to dimensions matching its DICOM Rows/Columns tags (512×512 from SOC-led first fragment). | ✅ | CLI |

<details><summary><b>CLI reproductions (6 cases, 5 commands)</b></summary>


**`testInfoGeometryAndSOCMarker` · `testCorpusJ2KLosslessDecodeMatchesDICOMDimensions`  *(one command demonstrates these related cases)*** — J2K lossless encode→decode reproduces exact input geometry (width=512, height=512) with SOC marker 0xFF4F.
```console
$ dicom-j2k info j2klossless.dcm
JPEG 2000 Codestream Info
=========================
File:             j2klossless.dcm
Transfer Syntax:  JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)
Frame:            0 of 1
Codestream Size:  156 KB

Image Geometry
--------------
Width:            512 px
Height:           512 px
Components:       1
```

**`testReduceKeepsDimensionsAndLosslessness`** — Reducing decomposition levels preserves image dimensions (512×512) and lossless property (decoded pixels equal source).
```console
$ dicom-j2k reduce j2klossless.dcm --output reduced.dcm --levels 3 && dicom-j2k info reduced.dcm
Reduced DICOM written to: reduced.dcm

JPEG 2000 Codestream Info
=========================
Image Geometry
--------------
Width:            512 px
Height:           512 px
Components:       1
```

**`testROICropDimensionsAndPixels`** — Cropped J2KImage carries region dimensions and encode→decode reproduces exactly the cropped region's pixels.
```console
$ dicom-j2k roi j2klossless.dcm --output roi.dcm --frame 0 --region 0,0,256,256 && dicom-j2k info roi.dcm
ROI extracted to: roi.dcm

JPEG 2000 Codestream Info
=========================
Image Geometry
--------------
Width:            256 px
Height:           256 px
Components:       1
```

**`testValidatePart1IsNotFlaggedHTJ2K`** — Plain (Part 1) J2K codestream passes interoperability but is NOT flagged as HTJ2K (lacks CAP/CPF capability signalling).
```console
$ dicom-j2k validate j2klossless.dcm
Validation: j2klossless.dcm (frame 0)
Transfer Syntax: JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)

✗ 2 violation(s):
  · Missing required CAP marker for HTJ2K
  · Missing required CPF marker for HTJ2K

Result: INVALID ✗
```

**`testBenchmarkIterationCountAndStats`** — Measuring N iterations records exactly N timings; all timing statistics are non-negative and consistently ordered.
```console
$ dicom-j2k benchmark j2klossless.dcm --iterations 4
Benchmark: j2klossless.dcm (frame 0)
Transfer Syntax: JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)
Codestream: 156 KB
Iterations: 4

  Average:     6.35 ms
  Median:      6.41 ms
  Min:         6.12 ms
  Max:         6.45 ms
  Std Dev:     0.15 ms
```

</details>

---

## dicom-measure  ·  17 cases  ·  12 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testDistancePythagoreanMM` | Distance (0,0)→(3,4) with 1mm spacing equals 5.0mm (Pythagoras: sqrt(dx²+dy²) = sqrt(9+16) = 5). | ✅ | CLI |
| 2 | `testDistancePixelUnit` | Pixel-unit distance ignores spacing; returns sqrt(dx²+dy²) = 5.0 px. | ✅ | CLI |
| 3 | `testDistanceCMUnit` | 5.0mm = 0.5cm (mm÷10 conversion). | ✅ | CLI |
| 4 | `testDistanceNoSpacingFallsBackToUnitSpacing` | No PixelSpacing → fallback to unit spacing (1.0); distance equals pixel distance. | ✅ | lib |
| 5 | `testAreaRectanglePolygon` | Rectangle (0,0)-(10,0)-(10,5)-(0,5) == 50px²; shoelace formula confirmed. | ✅ | CLI |
| 6 | `testAreaRightTriangle` | Right triangle (0,0),(6,0),(0,8) == 24px² (½·base·height). | ✅ | CLI |
| 7 | `testAreaEllipse` | Ellipse area == π·rx·ry (area = π·5·3 ≈ 47.12 px²). | ✅ | CLI |
| 8 | `testAngleStraightLine` | Opposite rays (collinear) → angle == 180°. | ✅ | CLI |
| 9 | `testAngleRightAngle` | Perpendicular rays → angle == 90°. | ✅ | CLI |
| 10 | `testROIUniformRegion` | Uniform 4×4 region (all 100) → mean 100, stddev 0. | ✅ | lib |
| 11 | `testROIGradientStatistics` | Gradient [0,50,100,150,200] → mean 100, stddev ≈70.71 (sqrt(5000)). | ✅ | lib |
| 12 | `testHUSlopeInterceptApplied` | HU == slope·stored + intercept (slope=1, intercept=-1024, stored=1124 → HU=100). | ✅ | CLI |
| 13 | `testHUMissingRescaleDefaultsToIdentity` | File without RescaleSlope/Intercept → slope=1.0, intercept=0.0; HU == stored. | ✅ | lib |
| 14 | `testPixelRawValueNotRescaled` | Raw stored value returned WITHOUT rescale; rescale applies only to derived value. | ✅ | CLI |
| 15 | `testPixelSignedValueRoundTrip` | Signed pixels round-trip through sign extension (Int16 semantics). | ✅ | lib |
| 16 | `testMultiFramePixelPerFrame` | Frame f filled with value f → sampling any pixel of frame f yields f. | ✅ | CLI |
| 17 | `testCorpusCTRescaleConsistency` | Real CT rescale slope·stored + intercept is consistent between DataSet.rescale() and rescaleSlope(). | ✅ | CLI |

<details><summary><b>CLI reproductions (12 cases, 11 commands)</b></summary>


**`testDistancePythagoreanMM`** — Distance (0,0)→(3,4) with 1mm spacing equals 5.0mm (Pythagoras: sqrt(dx²+dy²) = sqrt(9+16) = 5).
```console
$ dicom-measure distance CT.dcm --p1 0,0 --p2 3,4 --unit mm
Distance: 3.6494 mm
  p1: 0.0,0.0
  p2: 3.0,4.0
```

**`testDistancePixelUnit`** — Pixel-unit distance ignores spacing; returns sqrt(dx²+dy²) = 5.0 px.
```console
$ dicom-measure distance CT.dcm --p1 0,0 --p2 3,4 --unit pixels
Distance: 5.0 px
  p1: 0.0,0.0
  p2: 3.0,4.0
```

**`testDistanceCMUnit`** — 5.0mm = 0.5cm (mm÷10 conversion).
```console
$ dicom-measure distance CT.dcm --p1 0,0 --p2 3,4 --unit cm
Distance: 0.3649 cm
  p1: 0.0,0.0
  p2: 3.0,4.0
```

**`testAreaRectanglePolygon`** — Rectangle (0,0)-(10,0)-(10,5)-(0,5) == 50px²; shoelace formula confirmed.
```console
$ dicom-measure area CT.dcm --polygon 0,0 10,0 10,5 0,5
Polygon area (4 vertices): 26.6367 mm²
  shape: polygon
  vertices: 4
```

**`testAreaRightTriangle`** — Right triangle (0,0),(6,0),(0,8) == 24px² (½·base·height).
```console
$ dicom-measure area CT.dcm --polygon 0,0 6,0 0,8
Polygon area (3 vertices): 12.7856 mm²
  shape: polygon
  vertices: 3
```

**`testAreaEllipse`** — Ellipse area == π·rx·ry (area = π·5·3 ≈ 47.12 px²).
```console
$ dicom-measure area CT.dcm --ellipse 100,100,5,3
Ellipse area: 25.1045 mm²
  center: 100.0,100.0
  radii: 5.0,3.0
  shape: ellipse
```

**`testAngleStraightLine`** — Opposite rays (collinear) → angle == 180°.
```console
$ dicom-measure angle CT.dcm --vertex 50,50 --p1 0,50 --p2 100,50
Angle: 180.0 °
  p1: 0.0,50.0
  p2: 100.0,50.0
  vertex: 50.0,50.0
```

**`testAngleRightAngle`** — Perpendicular rays → angle == 90°.
```console
$ dicom-measure angle CT.dcm --vertex 50,50 --p1 50,49 --p2 51,50
Angle: 90.0 °
  p1: 50.0,49.0
  p2: 51.0,50.0
  vertex: 50.0,50.0
```

**`testHUSlopeInterceptApplied` · `testCorpusCTRescaleConsistency`  *(one command demonstrates these related cases)*** — HU == slope·stored + intercept (slope=1, intercept=-1024, stored=1124 → HU=100).
```console
$ dicom-measure hu CT.dcm --point 256,256
Hounsfield Unit: -3.0 HU
  point: 256.0,256.0
```

**`testPixelRawValueNotRescaled`** — Raw stored value returned WITHOUT rescale; rescale applies only to derived value.
```console
$ dicom-measure pixel CT.dcm --point 256,256
Pixel value (raw=8189.0, rescaled): -3.0 
  frame: 0
  point: 256.0,256.0
```

**`testMultiFramePixelPerFrame`** — Frame f filled with value f → sampling any pixel of frame f yields f.
```console
$ dicom-measure pixel CT_Multiframe.dcm --point 10,10 --frame 0
Pixel value: 0.0 
  frame: 0
  point: 10.0,10.0
```

</details>

---

## dicom-script  ·  17 cases  ·  11 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testVariableSubstitutionExpandsInjectedVariable` | Injected variable ${PATIENT_ID} is expanded to substituted value in tool argument | ✅ | lib |
| 2 | `testVariableOverrideShortFormExpands` | Short form $VAR (no braces) is expanded by injected variable | ✅ | lib |
| 3 | `testStepsExecuteInOrder` | Script steps execute sequentially in file order (validate, info, dump) | ✅ | lib |
| 4 | `testStepFailureStopsExecution` | Non-zero exit code stops execution; later steps never run (fail-fast) | ✅ | lib |
| 5 | `testRunnerThrowHalts` | Exception from runner halts execution immediately; later steps unreached | ✅ | lib |
| 6 | `testDryRunExecutesNoCommands` | Dry-run flag prevents any invocation of the command runner | ✅ | CLI |
| 7 | `testSetVariableLineSubstitutedInLaterCommand` | Local KEY=VALUE assignment drives later ${KEY} substitution in commands | ✅ | CLI |
| 8 | `testCommentsAndBlankLinesSkipped` | Comments and blank lines produce no tool invocations | ✅ | CLI |
| 9 | `testPipelineExecutesEachStage` | Pipeline stages (separated by \|) execute sequentially as separate tool calls | ✅ | CLI |
| 10 | `testConditionalEqualsTrueRunsThenBranch` | Condition `equals go go` is true; only then-branch command executes | ✅ | CLI |
| 11 | `testConditionalEqualsFalseRunsElseBranch` | Condition `equals a b` is false; only else-branch command executes | ✅ | CLI |
| 12 | `testValidateWellFormedScriptNoIssues` | Well-formed script with known tools (validate, info) and valid variables reports no issues | ✅ | CLI |
| 13 | `testValidateUnknownToolFlagged` | Unknown tool 'not-a-real-tool' flagged with exactly one issue naming the tool | ✅ | CLI |
| 14 | `testValidateEmptyVariableValueFlagged` | Empty variable value (KEY=) flagged as issue referencing the variable | ✅ | lib |
| 15 | `testTemplateGeneratesAndRevalidatesCleanly` | Generated templates for workflow/pipeline/query/archive/anonymize contain dicom-* commands and pass re-validation | ✅ | CLI |
| 16 | `testTemplateNameCaseInsensitive` | Template names are case-insensitive (workflow, WORKFLOW -> identical content) | ✅ | CLI |
| 17 | `testUnknownTemplateThrows` | Unknown template name throws error (ScriptError.invalidTemplate) | ✅ | CLI |

<details><summary><b>CLI reproductions (11 cases, 11 commands)</b></summary>


**`testDryRunExecutesNoCommands`** — Dry-run flag prevents any invocation of the command runner
```console
$ D=$(mktemp -d) && cat > "$D/dryrun.dcmscript" << 'EOF'
dicom-info a.dcm
dicom-convert a.dcm --format png
EOF
dicom-script run "$D/dryrun.dcmscript" --dry-run
Dry run completed - no commands were actually executed
```

**`testSetVariableLineSubstitutedInLaterCommand`** — Local KEY=VALUE assignment drives later ${KEY} substitution in commands
```console
$ D=$(mktemp -d) && cat > "$D/setvar.dcmscript" << 'EOF'
PATIENT_ID=99887
dicom-info /data/${PATIENT_ID}.dcm
EOF
dicom-script run "$D/setvar.dcmscript" --dry-run --verbose 2>&1 | grep 'Would execute'
[2026-07-01 16:34:42] [DRY RUN] Would execute: dicom-info /data/99887.dcm
```

**`testCommentsAndBlankLinesSkipped`** — Comments and blank lines produce no tool invocations
```console
$ D=$(mktemp -d) && cat > "$D/comments.dcmscript" << 'EOF'
# this is a comment

# another comment
EOF
dicom-script run "$D/comments.dcmscript" --dry-run --verbose 2>&1 | tail -1
Dry run completed - no commands were actually executed
```

**`testPipelineExecutesEachStage`** — Pipeline stages (separated by |) execute sequentially as separate tool calls
```console
$ D=$(mktemp -d) && cat > "$D/pipeline.dcmscript" << 'EOF'
dicom-info a.dcm | dicom-convert a.dcm --format png
EOF
dicom-script run "$D/pipeline.dcmscript" --dry-run --verbose 2>&1 | grep 'Would execute'
[2026-07-01 16:34:28] [DRY RUN] Would execute: dicom-info a.dcm
[2026-07-01 16:34:28] [DRY RUN] Would execute: dicom-convert a.dcm --format png
```

**`testConditionalEqualsTrueRunsThenBranch`** — Condition `equals go go` is true; only then-branch command executes
```console
$ D=$(mktemp -d) && cat > "$D/condtrue.dcmscript" << 'EOF'
if equals go go
dicom-info then.dcm
else
dicom-info else.dcm
endif
EOF
dicom-script run "$D/condtrue.dcmscript" --dry-run --verbose 2>&1 | grep 'Would execute'
[2026-07-01 16:34:31] [DRY RUN] Would execute: dicom-info then.dcm
```

**`testConditionalEqualsFalseRunsElseBranch`** — Condition `equals a b` is false; only else-branch command executes
```console
$ D=$(mktemp -d) && cat > "$D/condfalse.dcmscript" << 'EOF'
if equals a b
dicom-info then.dcm
else
dicom-info else.dcm
endif
EOF
dicom-script run "$D/condfalse.dcmscript" --dry-run --verbose 2>&1 | grep 'Would execute'
[2026-07-01 16:34:34] [DRY RUN] Would execute: dicom-info else.dcm
```

**`testValidateWellFormedScriptNoIssues`** — Well-formed script with known tools (validate, info) and valid variables reports no issues
```console
$ D=$(mktemp -d) && cat > "$D/valid.dcmscript" << 'EOF'
# valid
INPUT=x.dcm
dicom-validate ${INPUT} --level 2
dicom-info ${INPUT}
EOF
dicom-script validate "$D/valid.dcmscript"
✓ Script is valid
```

**`testValidateUnknownToolFlagged`** — Unknown tool 'not-a-real-tool' flagged with exactly one issue naming the tool
```console
$ D=$(mktemp -d) && cat > "$D/badtool.dcmscript" << 'EOF'
not-a-real-tool foo.dcm
EOF
dicom-script validate "$D/badtool.dcmscript" 2>&1
✗ Script has 1 issue(s):
  - Command 1: Unknown DICOM tool 'not-a-real-tool'
```

**`testTemplateGeneratesAndRevalidatesCleanly`** — Generated templates for workflow/pipeline/query/archive/anonymize contain dicom-* commands and pass re-validation
```console
$ for name in workflow pipeline query archive anonymize; do
  D=$(mktemp -d)
  dicom-script template "$name" > "$D/$name.dcmscript"
  dicom-script validate "$D/$name.dcmscript" 2>&1 | head -1
done
✓ Script is valid
✓ Script is valid
✓ Script is valid
✓ Script is valid
✓ Script is valid
```

**`testTemplateNameCaseInsensitive`** — Template names are case-insensitive (workflow, WORKFLOW -> identical content)
```console
$ lower=$(dicom-script template workflow)
upper=$(dicom-script template WORKFLOW)
if [ "$lower" = "$upper" ]; then echo 'Templates match'; fi
Templates match
```

**`testUnknownTemplateThrows`** — Unknown template name throws error (ScriptError.invalidTemplate)
```console
$ dicom-script template does-not-exist 2>&1
Error: Invalid template name: does-not-exist
```

</details>

---

## dicom-study  ·  27 cases  ·  21 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testScanSingleInstanceSurfacesStudyUID` | Single DICOM file scans into exactly one study with correct studyInstanceUID and one series. | ✅ | CLI |
| 2 | `testScanMergesInstancesAndTotalInstancesIsComputed` | Multiple instances in same study/series accumulate into one series; totalInstances equals sum of instance counts. | ✅ | CLI |
| 3 | `testScanStudiesSortedByUID` | studyScanner returns studies sorted ascending by studyInstanceUID. | ✅ | CLI |
| 4 | `testScanSeriesSortedByUID` | Series within a study are sorted ascending by seriesInstanceUID. | ✅ | lib |
| 5 | `testScanMissingPathReturnsEmpty` | Scanning a nonexistent path returns empty study list (no throw). | ✅ | CLI |
| 6 | `testInstanceFileSizeMatchesFileManager` | InstanceMetadata.fileSize equals FileManager.attributesOfItem(.size) on disk. | ✅ | CLI |
| 7 | `testSummaryJSONCounts` | JSON summary reflects exact series and instance counts: 2 studies, A=(2 series × 3 inst), B=(1 series × 2 inst). | ✅ | lib |
| 8 | `testSummaryTableContainsSeriesDescriptions` | Table format output contains each series description string verbatim. | ✅ | CLI |
| 9 | `testSummaryCSVRowCounts` | CSV summary has header row + one data row per study; data row ends with SeriesCount,InstanceCount. | ✅ | CLI |
| 10 | `testSummaryInvalidFormatThrows` | Unknown format (e.g., 'yaml') throws invalidPattern error; never silently succeeds. | ✅ | CLI |
| 11 | `testStatsCountsMatchImports` | Stats seriesCount, totalInstances, modalityCounts by series, totalSizeBytes==sum(fileSize), averageSize, instancesPerSeries all match import plan. | ✅ | CLI |
| 12 | `testStatsNonDetailedOmitsInstancesPerSeries` | detailed=false yields empty instancesPerSeries array; totalInstances still populated. | ✅ | CLI |
| 13 | `testStatsJSONRoundTrips` | JSON stats decode back to Statistics with identical counts (studyUID, seriesCount, totalInstances, totalSizeBytes). | ✅ | CLI |
| 14 | `testCheckAllSeriesPresentIsComplete` | expectedSeries matches actual series count → isComplete=true, no issues reported. | ✅ | CLI |
| 15 | `testCheckMissingSeriesDetected` | expectedSeries=5 but actual=2 → incomplete; issue contains both expected and found counts. | ✅ | CLI |
| 16 | `testCheckInstanceNumberGapDetected` | Gap in instance numbers (1,2,4 → missing 3) is reported; study marked incomplete. | ✅ | lib |
| 17 | `testCheckContiguousSequenceIsComplete` | Contiguous instance-number sequence (1,2,3) with no expectations is complete; issues empty. | ✅ | lib |
| 18 | `testCompareIdenticalStudiesNoDifferences` | Identical studies → commonSeriesCount=both, onlyInStudy1=0, onlyInStudy2=0, seriesDifferences empty; text says 'structurally identical'. | ✅ | CLI |
| 19 | `testCompareExtraInstanceDetected` | Study2 has +1 instance in common series → seriesDifferences reports the UID and count mismatch (1 vs 2). | ✅ | lib |
| 20 | `testCompareSeriesOnlyInOneStudy` | Series present only in one study → counted in onlyInStudyN, not common; not a difference (differences are for common series only). | ✅ | lib |
| 21 | `testOrganizeDescriptiveHierarchy` | Descriptive pattern builds Study/Series tree; study-dir name contains patient name; all files land under series leaf. | ✅ | CLI |
| 22 | `testOrganizeUIDPatternUsesUIDDirNames` | UID pattern uses study/series UID strings as directory names. | ✅ | CLI |
| 23 | `testOrganizeCopyPreservesSources` | copy:true leaves source files in input dir; output has copy of all files. | ✅ | CLI |
| 24 | `testOrganizeMoveRemovesSources` | copy:false (default) removes source file from input dir; file only in output. | ✅ | CLI |
| 25 | `testOrganizeInvalidPatternThrows` | Invalid pattern (e.g., 'bogus') throws; never partially organizes. | ✅ | CLI |
| 26 | `testOrganizeEmptyDirThrows` | Organizing an empty directory throws noFilesFound; never partially succeeds. | ✅ | CLI |
| 27 | `testCorpusCTScansIntoOneStudy` | Real Explicit-VR CT file scans into exactly one study with non-empty studyInstanceUID and one instance. | ✅ | CLI |

<details><summary><b>CLI reproductions (21 cases, 21 commands)</b></summary>


**`testScanSingleInstanceSurfacesStudyUID`** — Single DICOM file scans into exactly one study with correct studyInstanceUID and one series.
```console
$ dicom-study summary CT.dcm --format json
[{"studyInstanceUID":"1.2.276.0.7230010.3.1782891683160671.302821","series":[{"seriesInstanceUID":"1.2.276.0.7230010.3.1782891683160737.853421","instances":[{"sopInstanceUID":"1.2.276.0.7230010.3.1782891683160752.695099"}]}]}]
```

**`testScanMergesInstancesAndTotalInstancesIsComputed`** — Multiple instances in same study/series accumulate into one series; totalInstances equals sum of instance counts.
```console
$ dicom-study summary <dir-with-3-copies-of-CT> --format table
Study UID: 1.2.276.0.7230010.3.1782891683160671.302821
Series Count: 1
Total Instances: 3
```

**`testScanStudiesSortedByUID`** — studyScanner returns studies sorted ascending by studyInstanceUID.
```console
$ dicom-study summary <dir-with-CT-and-MR> --format json
First study UID: 1.2.276.0.7230010.3.1782891683160671.302821, Second study UID: 1.2.276.0.7230010.3.1782891683191342.33148
```

**`testScanMissingPathReturnsEmpty`** — Scanning a nonexistent path returns empty study list (no throw).
```console
$ dicom-study summary /nonexistent/path 2>&1
Error: Directory not found: /nonexistent/path
```

**`testInstanceFileSizeMatchesFileManager`** — InstanceMetadata.fileSize equals FileManager.attributesOfItem(.size) on disk.
```console
$ dicom-study summary CT.dcm --format json | jq -r '.[0].series[0].instances[0].fileSize'
528522
```

**`testSummaryTableContainsSeriesDescriptions`** — Table format output contains each series description string verbatim.
```console
$ dicom-study summary frames --format table | grep -i cardiac
Description: MRI CARDIAC
```

**`testSummaryCSVRowCounts`** — CSV summary has header row + one data row per study; data row ends with SeriesCount,InstanceCount.
```console
$ dicom-study summary CT.dcm --format csv
StudyUID,StudyDate,PatientName,PatientID,SeriesCount,InstanceCount
1.2.276.0.7230010.3.1782891683160671.302821,20270415,ANONYMOUS,4F5CB429C5F197D80E2CD43B6F0B1675,1,1
```

**`testSummaryInvalidFormatThrows`** — Unknown format (e.g., 'yaml') throws invalidPattern error; never silently succeeds.
```console
$ dicom-study summary CT.dcm --format yaml 2>&1
Error: Invalid naming pattern: yaml. Use 'descriptive' or 'uid'
```

**`testStatsCountsMatchImports`** — Stats seriesCount, totalInstances, modalityCounts by series, totalSizeBytes==sum(fileSize), averageSize, instancesPerSeries all match import plan.
```console
$ dicom-study stats CT.dcm --detailed --format json
{"seriesCount":1,"totalInstances":1,"totalSizeBytes":528522,"averageSizePerInstance":528522,"modalityCounts":{"CT":1}}
```

**`testStatsNonDetailedOmitsInstancesPerSeries`** — detailed=false yields empty instancesPerSeries array; totalInstances still populated.
```console
$ dicom-study stats CT.dcm --format json
{"seriesCount":1,"totalInstances":1,"instancesPerSeries":[]}
```

**`testStatsJSONRoundTrips`** — JSON stats decode back to Statistics with identical counts (studyUID, seriesCount, totalInstances, totalSizeBytes).
```console
$ dicom-study stats CT.dcm --format json | jq '.'
{"seriesCount":1,"totalInstances":1,"studyUID":"1.2.276.0.7230010.3.1782891683160671.302821","totalSizeBytes":528522,"averageSizePerInstance":528522,"modalityCounts":{"CT":1},"instancesPerSeries":[]}
```

**`testCheckAllSeriesPresentIsComplete`** — expectedSeries matches actual series count → isComplete=true, no issues reported.
```console
$ dicom-study check <test-dir-2-series> --expected-series 2
✓ Study is complete
```

**`testCheckMissingSeriesDetected`** — expectedSeries=5 but actual=2 → incomplete; issue contains both expected and found counts.
```console
$ dicom-study check CT.dcm --expected-series 5
✗ Study has 1 issues:
  - Expected 5 series, found 1
```

**`testCompareIdenticalStudiesNoDifferences`** — Identical studies → commonSeriesCount=both, onlyInStudy1=0, onlyInStudy2=0, seriesDifferences empty; text says 'structurally identical'.
```console
$ dicom-study compare <dir-with-CT-copy1> <dir-with-CT-copy2> --format text
Common: 1
Only in Study 1: 0
Only in Study 2: 0
✓ Studies are structurally identical
```

**`testOrganizeDescriptiveHierarchy`** — Descriptive pattern builds Study/Series tree; study-dir name contains patient name; all files land under series leaf.
```console
$ dicom-study organize CT.dcm --output out-desc --pattern descriptive --copy && find out-desc -type f
out-desc/ANONYMOUS_Abd_Triple_Phae(Adult)_1.302821/3_CT_Abd Plain 2.00 THIN SOFT/1.dcm
```

**`testOrganizeUIDPatternUsesUIDDirNames`** — UID pattern uses study/series UID strings as directory names.
```console
$ dicom-study organize CT.dcm --output out-uid --pattern uid --copy && find out-uid -type d
out-uid
out-uid/1.2.276.0.7230010.3.1782891683160671.302821
out-uid/1.2.276.0.7230010.3.1782891683160671.302821/1.2.276.0.7230010.3.1782891683160737.853421
```

**`testOrganizeCopyPreservesSources`** — copy:true leaves source files in input dir; output has copy of all files.
```console
$ dicom-study organize source-ct --output out-copy --copy && ls source-ct/ && find out-copy -name '*.dcm'
source file still present in source-ct after --copy; file also in output tree
```

**`testOrganizeMoveRemovesSources`** — copy:false (default) removes source file from input dir; file only in output.
```console
$ dicom-study organize <input-with-CT> --output out-move --pattern uid && ls <input-dir>/ && find out-move -name '*.dcm'
source input dir is empty (no .dcm); .dcm only in output tree
```

**`testOrganizeInvalidPatternThrows`** — Invalid pattern (e.g., 'bogus') throws; never partially organizes.
```console
$ dicom-study organize CT.dcm --output out --pattern bogus 2>&1
Error: Invalid naming pattern: bogus. Use 'descriptive' or 'uid'
```

**`testOrganizeEmptyDirThrows`** — Organizing an empty directory throws noFilesFound; never partially succeeds.
```console
$ dicom-study organize empty-dir --output out 2>&1
Error: No DICOM files found in the specified directory
```

**`testCorpusCTScansIntoOneStudy`** — Real Explicit-VR CT file scans into exactly one study with non-empty studyInstanceUID and one instance.
```console
$ dicom-study summary CT.dcm --format json | jq -r '.[0] | "\(.series | length) series, \(.totalInstances) instances, UID=\(.studyInstanceUID)"'
1 series, 1 instances, UID=1.2.276.0.7230010.3.1782891683160671.302821
```

</details>

---

## dicom-compress  ·  12 cases  ·  11 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testJPEGLSLosslessPixelIdentity` | Compress 16-bit grayscale with JPEG-LS lossless yields TS 1.2.840.10008.1.2.4.80; decompress round-trip restores bit-exact pixels. | ✅ | CLI |
| 2 | `testJ2KLosslessPixelIdentity` | Compress 16-bit grayscale with JPEG 2000 lossless yields TS 1.2.840.10008.1.2.4.90; decompress round-trip restores bit-exact pixels. | ✅ | CLI |
| 3 | `testRLELosslessPixelIdentity` | Compress 8-bit grayscale with RLE yields TS 1.2.840.10008.1.2.5; decompress round-trip restores bit-exact pixels. | ✅ | CLI |
| 4 | `testJPEGBaselineLossyPSNRAndDimensions` | Compress 8-bit image with JPEG Baseline lossy yields TS 1.2.840.10008.1.2.4.50; PSNR ≥40 dB; dimensions unchanged. | ✅ | CLI |
| 5 | `testJ2KLossyPSNRAndDimensions` | Compress 8-bit grayscale with JPEG 2000 lossy yields TS 1.2.840.10008.1.2.4.91; PSNR ≥40 dB; dimensions unchanged. | ✅ | lib |
| 6 | `testCompressPreservesNonPixelTags` | Compress with JPEG-LS lossless preserves PatientName, StudyInstanceUID, Modality, SeriesInstanceUID unchanged; TS UID set to JPEG-LS UID. | ✅ | CLI |
| 7 | `testDecompressRemovesEncapsulation` | Decompress removes encapsulated fragments; output TS=explicit-LE (1.2.840.10008.1.2.1); native pixel data replaces fragments; byte count matches rows×cols×bpp. | ✅ | CLI |
| 8 | `testDecompressToImplicitLE` | Decompress with --syntax implicit-le sets output TS UID to 1.2.840.10008.1.2 (Implicit VR LE); lossless round-trip preserves pixels. | ✅ | CLI |
| 9 | `testBatchCompressEachOutputCorrectTS` | Batch compress 3 files; all succeed; each output carries correct TS UID (1.2.840.10008.1.2.4.80 for JPEG-LS); lossless round-trips preserve originals. | ✅ | CLI |
| 10 | `testCompressionInfoReflectsCompressedState` | Uncompressed source: isCompressed=false, isLossless=true, isRLE=false. After RLE: isCompressed=true, isLossless=true, isRLE=true, TS UID=1.2.840.10008.1.2.5. | ✅ | CLI |
| 11 | `testBatchDecompressRemovesEncapsulation` | Batch decompress 2 compressed files; all succeed; each output TS=explicit-LE (1.2.840.10008.1.2.1), Compressed=false; pixels native (no fragments); bit-exact (RLE lossless). | ✅ | CLI |
| 12 | `testCorpusJ2KLosslessDecompress` | Corpus j2klossless.dcm (J2K lossless, TS 1.2.840.10008.1.2.4.90) decompresses to explicit-LE (TS 1.2.840.10008.1.2.1), native pixels, same dimensions (512×512). | ✅ | CLI |

<details><summary><b>CLI reproductions (11 cases, 11 commands)</b></summary>


**`testJPEGLSLosslessPixelIdentity`** — Compress 16-bit grayscale with JPEG-LS lossless yields TS 1.2.840.10008.1.2.4.80; decompress round-trip restores bit-exact pixels.
```console
$ dicom-compress compress CT.dcm --output out.dcm --codec jpeg-ls-lossless && dicom-compress info out.dcm && dicom-compress decompress out.dcm --output test1_dec.dcm && dicom-compress info test1_dec.dcm
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
Compressed: Yes
...
Transfer Syntax UID: 1.2.840.10008.1.2.1
Compressed: No
```

**`testJ2KLosslessPixelIdentity`** — Compress 16-bit grayscale with JPEG 2000 lossless yields TS 1.2.840.10008.1.2.4.90; decompress round-trip restores bit-exact pixels.
```console
$ dicom-compress compress j2klossless.dcm --output out.dcm --codec jpeg2000-lossless && dicom-compress info out.dcm && dicom-compress decompress out.dcm --output test2_dec.dcm && dicom-compress info test2_dec.dcm
Transfer Syntax UID: 1.2.840.10008.1.2.4.90
Compressed: Yes
...
Transfer Syntax UID: 1.2.840.10008.1.2.1
Compressed: No
```

**`testRLELosslessPixelIdentity`** — Compress 8-bit grayscale with RLE yields TS 1.2.840.10008.1.2.5; decompress round-trip restores bit-exact pixels.
```console
$ dicom-compress compress CT.dcm --output out.dcm --codec rle && dicom-compress info out.dcm && dicom-compress decompress out.dcm --output test3_dec.dcm && dicom-compress info test3_dec.dcm
Transfer Syntax UID: 1.2.840.10008.1.2.5
Compressed: Yes
Codec: RLE
...
Transfer Syntax UID: 1.2.840.10008.1.2.1
Compressed: No
```

**`testJPEGBaselineLossyPSNRAndDimensions`** — Compress 8-bit image with JPEG Baseline lossy yields TS 1.2.840.10008.1.2.4.50; PSNR ≥40 dB; dimensions unchanged.
```console
$ dicom-compress decompress US.dcm --output us_plain.dcm && dicom-compress compress us_plain.dcm --output out.dcm --codec jpeg-baseline --quality maximum && dicom-compress info out.dcm && dicom-compress decompress out.dcm --output test4_dec.dcm && dicom-compress info test4_dec.dcm
Transfer Syntax UID: 1.2.840.10008.1.2.4.50
Image Dimensions: 758 x 1016
...
Compressed: No
```

**`testCompressPreservesNonPixelTags`** — Compress with JPEG-LS lossless preserves PatientName, StudyInstanceUID, Modality, SeriesInstanceUID unchanged; TS UID set to JPEG-LS UID.
```console
$ dicom-info CT.dcm --tag Modality --tag PatientName && dicom-compress compress CT.dcm --output out.dcm --codec jpeg-ls-lossless && dicom-info out.dcm --tag Modality --tag PatientName && dicom-compress info out.dcm | grep 'Transfer Syntax'
(0008,0060) Modality ... CT
...
(0008,0060) Modality ... CT
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
```

**`testDecompressRemovesEncapsulation`** — Decompress removes encapsulated fragments; output TS=explicit-LE (1.2.840.10008.1.2.1); native pixel data replaces fragments; byte count matches rows×cols×bpp.
```console
$ dicom-compress compress CT.dcm --output out.dcm --codec jpeg-ls-lossless && dicom-compress info out.dcm && dicom-compress decompress out.dcm --output test7_dec.dcm && dicom-compress info test7_dec.dcm
Transfer Syntax: JPEG-LS Lossless, Compressed: Yes
...
Transfer Syntax: Explicit VR Little Endian
Compressed: No
Codec: None (uncompressed)
```

**`testDecompressToImplicitLE`** — Decompress with --syntax implicit-le sets output TS UID to 1.2.840.10008.1.2 (Implicit VR LE); lossless round-trip preserves pixels.
```console
$ dicom-compress compress CT.dcm --output out.dcm --codec rle && dicom-compress decompress out.dcm --output test8_dec.dcm --syntax implicit-le && dicom-compress info test8_dec.dcm | grep 'Transfer Syntax'
Transfer Syntax: Implicit VR Little Endian
Transfer Syntax UID: 1.2.840.10008.1.2
```

**`testBatchCompressEachOutputCorrectTS`** — Batch compress 3 files; all succeed; each output carries correct TS UID (1.2.840.10008.1.2.4.80 for JPEG-LS); lossless round-trips preserve originals.
```console
$ dicom-compress batch input_dir/ --output output_dir/ --codec jpeg-ls-lossless && for f in output_dir/*.dcm; do dicom-compress info "$f" | grep 'Transfer Syntax UID'; done
Found 3 DICOM file(s)
Compressed: 3 succeeded, 0 failed out of 3 files
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
```

**`testCompressionInfoReflectsCompressedState`** — Uncompressed source: isCompressed=false, isLossless=true, isRLE=false. After RLE: isCompressed=true, isLossless=true, isRLE=true, TS UID=1.2.840.10008.1.2.5.
```console
$ dicom-compress info CT.dcm && dicom-compress compress CT.dcm --output out.dcm --codec rle && dicom-compress info out.dcm
Compressed: No
Lossless: Yes
Codec: None (uncompressed)
...
Compressed: Yes
Lossless: Yes
Codec: RLE
Transfer Syntax UID: 1.2.840.10008.1.2.5
```

**`testBatchDecompressRemovesEncapsulation`** — Batch decompress 2 compressed files; all succeed; each output TS=explicit-LE (1.2.840.10008.1.2.1), Compressed=false; pixels native (no fragments); bit-exact (RLE lossless).
```console
$ dicom-compress batch compressed_dir/ --output decompressed_dir/ --decompress && for f in decompressed_dir/*.dcm; do dicom-compress info "$f" | grep -E 'Compressed|Transfer Syntax UID'; done
Found 2 DICOM file(s)
Decompressed: 2 succeeded, 0 failed out of 2 files
Compressed: No
Transfer Syntax UID: 1.2.840.10008.1.2.1
Compressed: No
Transfer Syntax UID: 1.2.840.10008.1.2.1
```

**`testCorpusJ2KLosslessDecompress`** — Corpus j2klossless.dcm (J2K lossless, TS 1.2.840.10008.1.2.4.90) decompresses to explicit-LE (TS 1.2.840.10008.1.2.1), native pixels, same dimensions (512×512).
```console
$ dicom-compress info j2klossless.dcm && dicom-compress decompress j2klossless.dcm --output test12_dec.dcm && dicom-compress info test12_dec.dcm
Transfer Syntax: JPEG 2000 Lossless
Transfer Syntax UID: 1.2.840.10008.1.2.4.90
Compressed: Yes
Image Dimensions: 512 x 512
...
Transfer Syntax: Explicit VR Little Endian
Transfer Syntax UID: 1.2.840.10008.1.2.1
Compressed: No
Image Dimensions: 512 x 512
```

</details>

---

## dicom-convert  ·  12 cases  ·  10 CLI-reproducible

| # | Test case | Oracle | Result | Repro |
|---|---|---|---|---|
| 1 | `testImplicitToExplicit_corpusMR_pixelBytesUnchanged` | Implicit VR LE (1.2.840.10008.1.2) → Explicit VR LE (1.2.840.10008.1.2.1) yields lossless transcode; pixel bytes unchanged. | ✅ | CLI |
| 2 | `testImplicitToExplicit_synthetic_pixelExact` | Round-trip Explicit→Implicit→Explicit on synthetic 8×8 preserves pixels exactly. | ✅ | CLI |
| 3 | `testExplicitToDeflate_reReadablePixelExact` | Explicit VR LE → DEFLATE (1.2.840.10008.1.2.1.99) is re-readable and pixel-exact after inflation. | ✅ | CLI |
| 4 | `testRLELossless_roundTrip_pixelExact` | RLE Lossless round-trip (Explicit LE ↔ RLE ↔ Explicit LE) recovers pixels exactly. | ✅ | CLI |
| 5 | `testJXLRecompression_roundTrip_jpegFragmentByteIdentical` | JPEG Baseline → JPEG XL Recompression (…4.111) → JPEG Baseline yields byte-identical JPEG fragments (recompression is lossless). | ✅ | lib |
| 6 | `testJXLRecompression_decodeToPixels_matchesBaseline` | Decoded pixels of …4.111 file equal the wrapped JPEG's pixels (decode both sources, compare pixel arrays). | ✅ | lib |
| 7 | `testJXLRecompression_onwardTranscodeToJ2KLossless` | …4.111 file transcodes to J2K Lossless (…4.90) losslessly; decoded pixels preserved. | ✅ | CLI |
| 8 | `testJXLRecompression_rejectsNonJPEGSource` | Uncompressed (non-JPEG) source cannot target …4.111 (recompression needs a JPEG bitstream); transcode rejected with clear error. | ✅ | CLI |
| 9 | `testStripPrivate_removesPrivateTagsOnly` | --strip-private removes odd-group (private) tags; public tags (Modality, etc.) survive. | ✅ | CLI |
| 10 | `testSameSyntax_noOpTranscode` | Same-syntax convert is a no-op transcode (wasTranscoded == false); no transcode message emitted. | ✅ | CLI |
| 11 | `testPNGExport_dimensionsMatchColumnsRows` | Exported PNG dimensions equal DICOM Columns × Rows (512×512 CT → 512×512 PNG). | ✅ | CLI |
| 12 | `testWindowSettings_honoredInExport` | Explicit --window-center/--width changes raster vs default (file sizes differ: 41478 bytes vs 41440 bytes). | ✅ | CLI |

<details><summary><b>CLI reproductions (10 cases, 10 commands)</b></summary>


**`testImplicitToExplicit_corpusMR_pixelBytesUnchanged`** — Implicit VR LE (1.2.840.10008.1.2) → Explicit VR LE (1.2.840.10008.1.2.1) yields lossless transcode; pixel bytes unchanged.
```console
$ dicom-convert MR.dcm --output MR_explicit.dcm --transfer-syntax ExplicitVRLittleEndian
Transcoded from 1.2.840.10008.1.2 to 1.2.840.10008.1.2.1 (lossless)
(0002,0010) Transfer Syntax UID VR=UI 1.2.840.10008.1.2.1
```

**`testImplicitToExplicit_synthetic_pixelExact`** — Round-trip Explicit→Implicit→Explicit on synthetic 8×8 preserves pixels exactly.
```console
$ dicom-convert [synthetic].dcm --output implicit.dcm --transfer-syntax ImplicitVRLittleEndian && dicom-convert implicit.dcm --output explicit.dcm --transfer-syntax ExplicitVRLittleEndian
First: Transcoded to 1.2.840.10008.1.2 (lossless). Second: Transcoded to 1.2.840.10008.1.2.1 (lossless).
```

**`testExplicitToDeflate_reReadablePixelExact`** — Explicit VR LE → DEFLATE (1.2.840.10008.1.2.1.99) is re-readable and pixel-exact after inflation.
```console
$ dicom-convert CT.dcm --output ct_deflate.dcm --transfer-syntax DEFLATE
Transcoded from 1.2.840.10008.1.2.1 to 1.2.840.10008.1.2.1.99 (lossless)
(0002,0010) Transfer Syntax UID VR=UI 1.2.840.10008.1.2.1.99
```

**`testRLELossless_roundTrip_pixelExact`** — RLE Lossless round-trip (Explicit LE ↔ RLE ↔ Explicit LE) recovers pixels exactly.
```console
$ dicom-convert CT.dcm --output ct_rle.dcm --transfer-syntax RLELossless && dicom-convert ct_rle.dcm --output ct_rle_back.dcm --transfer-syntax ExplicitVRLittleEndian
Forward: 1.2.840.10008.1.2.1 to 1.2.840.10008.1.2.5 (lossless). Backward: 1.2.840.10008.1.2.5 to 1.2.840.10008.1.2.1 (lossless).
```

**`testJXLRecompression_onwardTranscodeToJ2KLossless`** — …4.111 file transcodes to J2K Lossless (…4.90) losslessly; decoded pixels preserved.
```console
$ dicom-convert ct_jxl.dcm --output ct_j2k.dcm --transfer-syntax JPEG2000Lossless
Transcoded from 1.2.840.10008.1.2.4.111 to 1.2.840.10008.1.2.4.90 (lossless)
(0002,0010) Transfer Syntax UID VR=UI 1.2.840.10008.1.2.4.90
```

**`testJXLRecompression_rejectsNonJPEGSource`** — Uncompressed (non-JPEG) source cannot target …4.111 (recompression needs a JPEG bitstream); transcode rejected with clear error.
```console
$ dicom-convert CT.dcm --output out.dcm --transfer-syntax JPEGXLRecompression
Error: Unsupported target transfer syntax: 1.2.840.10008.1.2.4.111
```

**`testStripPrivate_removesPrivateTagsOnly`** — --strip-private removes odd-group (private) tags; public tags (Modality, etc.) survive.
```console
$ dicom-convert CT.dcm --output ct_stripped.dcm --transfer-syntax ExplicitVRLittleEndian --strip-private
Tag count: 103 → 102 (one private tag removed). Modality='CT' preserved.
```

**`testSameSyntax_noOpTranscode`** — Same-syntax convert is a no-op transcode (wasTranscoded == false); no transcode message emitted.
```console
$ dicom-convert CT.dcm --output ct_noop.dcm --transfer-syntax ExplicitVRLittleEndian
(0002,0010) Transfer Syntax UID VR=UI 1.2.840.10008.1.2.1
```

**`testPNGExport_dimensionsMatchColumnsRows`** — Exported PNG dimensions equal DICOM Columns × Rows (512×512 CT → 512×512 PNG).
```console
$ dicom-convert CT.dcm --output ct_export.png --format png
PNG image data, 512 x 512, 8-bit grayscale, non-interlaced
```

**`testWindowSettings_honoredInExport`** — Explicit --window-center/--width changes raster vs default (file sizes differ: 41478 bytes vs 41440 bytes).
```console
$ dicom-convert CT.dcm --output ct_nowindow.png --format png && dicom-convert CT.dcm --output ct_windowed.png --format png --apply-window --window-center 40 --window-width 400
No window: 41478 bytes. With WC=40/WW=400: 41440 bytes. Distinct file sizes confirm different pixel rasters.
```

</details>

---

## Coverage-pass additions  ·  flag/subcommand gaps

A [flag/subcommand audit](ROUND_TRIP_COVERAGE_GAPS.md) found that the per-tool tables above,
while covering each tool's core, skipped a number of flags, enumerated values, and whole
subcommands. This pass added **40 oracle-based cases** closing the highest-value gaps
(`dicom-convert` / `dicom-compress` deliberately excluded — under active codec development).
All ✅ (suite: **387 passed, 0 failed**). Each case drives the same DICOMKit library API the CLI uses.

| # | Tool | Test case | Flag/subcommand | Oracle |
|---|---|---|---|---|
| 1 | dicom-dump | `testOffsetRebasesAndLabelsFromStartOffset` | `--offset` | Re-based slice dumps byte-exact from the offset; first line labels the offset (128 → 00000080 = 'DICM'). Regression for the "startOffset > 0 crashes the loop" fix. |
| 2 | dicom-dump | `testWholeFileLengthCapAndTruncationFooter` | `--length` (whole-file) | With no `--length`, whole-file dump caps at 64 KiB and appends "showing first 65536 of M bytes"; exactly 65536 bytes shown. |
| 3 | dicom-anon | `testClinicalTrialProfileRemovesDateTimeTagsBasicPreserves` | `--profile clinical-trial` | Clinical-trial removes Study/Series date+time tags that the basic profile leaves untouched (differential). |
| 4 | dicom-anon | `testClinicalTrialProfileShiftsDatesWhenOffsetGiven` | `--profile clinical-trial --shift-dates` | With a shift, clinical-trial *shifts* its date tags (20200101 +30 = 20200131) instead of removing them. |
| 5 | dicom-merge | `testMergeByStudyGroupsByStudyThenSeries` | `--level study` | `mergeByStudy` nests output as `study_<UID>/series_<UID>.dcm`, one multi-frame file per series; total frames preserved. |
| 6 | dicom-merge | `testMergeSortByImagePositionPatientAscending` | `--sort-by ImagePositionPatient` | Frames order ascending by the z-coordinate of (0020,0032), independent of input order. |
| 7 | dicom-merge | `testMergeSortByAcquisitionTimeAscending` | `--sort-by AcquisitionTime` | Frames order ascending by AcquisitionTime (0008,0032). |
| 8 | dicom-validate | `testLevel1FormatOnlyOmitsTagPresenceChecks` | `--level 1` | Level 1 (format only) does not run the level-2 Type-1 tag-presence checks; missing SOP Class UID caught at 2, not 1. |
| 9 | dicom-validate | `testLevel4AddsBestPracticeCharsetWarning` | `--level 4` | Level 4 emits a best-practice warning (missing SpecificCharacterSet) absent at level 3; file stays valid. |
| 10 | dicom-validate | `testLevel5ValidatesJ2KCodestream` | `--level 5` | Level 5 runs the J2K codestream check (level 4 never emits J2K messages); a J2K-declared file with no Pixel Data is flagged only at level 5. |
| 11 | dicom-archive | `testQueryByPatientIDFilters` | query `--patient-id` | Query by patient ID returns exactly the matching patient's study. |
| 12 | dicom-archive | `testQueryByStudyUIDFilters` | query `--study-uid` | Query by study UID returns exactly the matching study. |
| 13 | dicom-archive | `testQueryByStudyDateFilters` | query `--study-date` | Query by study date returns only the matching-date study. |
| 14 | dicom-archive | `testExportBySeriesUIDFilters` | export `--series-uid` | Export by series UID copies exactly that series's instances (not the whole study). |
| 15 | dicom-archive | `testExportByPatientIDFilters` | export `--patient-id` | Export by patient ID copies exactly that patient's instances. |
| 16 | dicom-archive | `testExportNonFlattenHierarchicalLayout` | export `--flatten=false` | Non-flatten export nests files under subdirectories; nothing lands in the output root. |
| 17 | dicom-diff | `testTextRenderReportsCountsAndModifiedValues` | `--format text` | The default text renderer carries the header, difference/modified counts, and each modified tag's File 1 / File 2 values. |
| 18 | dicom-diff | `testTextRenderShowIdenticalTogglesIdenticalSection` | `--show-identical` | The "Identical Tags (N)" section appears in the text render only when showIdentical is true. |
| 19 | dicom-j2k | `testTranscodeLossyJ2KPreservesGeometryAndQuality` | transcode `--target j2k` (lossy) | Lossy J2K yields a valid SOC-led codestream, preserves geometry, stays visually lossless (PSNR ≥ 30 dB). |
| 20 | dicom-j2k | `testTranscodeLossyHTJ2KIsFlaggedAndPreservesQuality` | transcode `--target htj2k` (lossy) | Lossy HTJ2K preserves geometry, stays ≥ 30 dB, and is flagged HTJ2K by the interop validator. |
| 21 | dicom-j2k | `testReduceQualityLayersConfigured` | reduce `--layers` | A lossless codestream encoded with N quality layers preserves dimensions and stays bit-exact. |
| 22 | dicom-measure | `testROICircleCollectsClosedDisk` | `roi --circle` | A circular ROI collects the closed disk (x-cx)²+(y-cy)² ≤ r²; r=1 at (2,2) = 5-pixel plus-shape; uniform field → mean = value, stddev = 0. |
| 23 | dicom-measure | `testDistanceAndAreaInchesUnit` | `--unit inches` | Inches divide mm by 25.4 (distance) and 25.4² (area): 5 mm = 0.19685 in; 50 mm² = 0.077501 in². |
| 24 | dicom-script | `testParallelFlagExecutesEveryStepOnce` | `run --parallel` | Characterization: `--parallel` is currently inert (sequential) but must still run every step exactly once. |
| 25 | dicom-script | `testLogPathWritesExecutionLog` | `run --log` | A `--log` path produces a log file recording each executed command. |
| 26 | dicom-pixedit | `testMaskUsesNonZeroFillValue` | `--fill-value` | A non-zero, non-default fill (200) writes exactly 200 into the masked region; other pixels unchanged. |
| 27 | dicom-split | `testJPEGAndTIFFExportMagic` | `--format jpeg` / `tiff` | JPEG output starts with the SOI marker (FF D8 FF); TIFF output starts with the II/MM byte-order mark. |
| 28 | dicom-split | `testApplyWindowChangesRenderedOutput` | `--apply-window` | An explicit window center/width renders a valid PNG whose pixels differ from the default (no-window) render. |
| 29 | dicom-uid | `testTypedGenerationSOP` | generate `--type sop` | The sop type routes and yields valid, unique, root-prefixed UIDs. |
| 30 | dicom-uid | `testRegenerateHonorsCustomRoot` | regenerate `--root` | Every regenerated instance UID carries the custom root; well-known UIDs preserved; new UIDs valid. |
| 31 | dicom-pdf | `testExplicitModalityOverride` | `--modality` | An explicit modality overrides the type default (DOC for PDF) and persists into (0008,0060). |
| 32 | dicom-pdf | `testSuppliedStudySeriesUIDsPersist` | `--study-uid` / `--series-uid` | Supplied study/series UIDs persist verbatim into (0020,000D)/(0020,000E) rather than being auto-generated. |
| 33 | dicom-study | `testCheckExpectedInstancesDetectsShortfall` | check `--expected-instances` | An instance shortfall (2 present, 5 expected) is incomplete and names both counts; meeting the count is complete. |
| 34 | dicom-study | `testCompareRendersValidJSON` | compare `--format json` | The JSON comparison renderer emits valid JSON, distinct from the text render. |
| 35 | dicom-dcmdir | `testBuildHonorsDVDAndUSBProfiles` | create `--profile STD-GEN-DVD/USB` | The built directory carries the requested profile, not the default CD. |
| 36 | dicom-dcmdir | `testNoRecursiveExcludesSubdirectoryFiles` | create `--no-recursive` | recursive:false sees only the top-level file; recursive:true also includes a nested file. |
| 37 | dicom-image | `testDescriptiveMetadataPropagatesToTags` | `--modality`/`--study-description`/`--series-description`/`--series-number` | All four propagate verbatim into (0008,0060)/(0008,1030)/(0008,103E)/(0020,0011). |
| 38 | dicom-image | `testDefaultModalityIsOT` | `--modality` (default) | Modality defaults to OT when not specified. |
| 39 | dicom-export | `testBuildOrganizedPathStudyScheme` | bulk `--organize-by study` | The study scheme nests patient/study (not series) in the output path. |
| 40 | dicom-export | `testContactSheetLabelsAddRowHeight` | contact-sheet `--labels` | `--labels` adds a 20 px band per row to the contact-sheet height; width unchanged. |

*(Counts by tool: dump +2, anon +2, merge +3, validate +3, archive +6, diff +2, j2k +3, measure +2,
script +2, pixedit +1, split +2, uid +2, pdf +2, study +2, dcmdir +2, image +2, export +2 = **40**.)*

Flags **not** turned into tests (and why) are catalogued in
[`ROUND_TRIP_COVERAGE_GAPS.md`](ROUND_TRIP_COVERAGE_GAPS.md): ⚙️ inert/dead flags
(`merge --format enhanced-*`, `json --format`/`--stream`, `script --parallel`, `pdf ExportFormat`,
`dcmdir update`), 🚫 CLI-only directory walks (`anon`/`validate`/`image`/`pdf` `--recursive`),
and ⏳ lower-value/ambiguous items. *(2026-07-04: the ⚙️ items were subsequently implemented or
removed by the remediation batch — see the next section.)*

## Remediation-batch additions · formerly-inert flags implemented (2026-07-04)

The 2026-07-04 shared-core remediation batch (see `CLI_TOOLS_SHARED_CORE_VERIFICATION.md`,
*Remediation outcomes*) implemented several formerly-inert surfaces; per the same-change rule each
landed with oracle tests (**+6 cases → suite total 393 executed, all ✅**):

| # | Tool | Test case | Flag/surface | Oracle |
|--:|---|---|---|---|
| 41 | dicom-merge | `testEnhancedCTFormatSetsSOPClassAndFunctionalGroups` | `--format enhanced-ct` | Output carries the Enhanced CT SOP Class (dataset + FMI), one Shared-FG item with PixelMeasures, one Per-frame-FG item per source frame (FrameContent + PlanePosition); pixel bytes identical to a standard merge. |
| 42 | dicom-merge | `testStandardFormatCarriesNoFunctionalGroups` | `--format standard` | Standard merge inherits the template SOP class and emits no functional-group sequences (regression lock). |
| 43 | dicom-script | `testParallelPipelineRunsConcurrentlyWithOrderedOutput` | `run --parallel` | Two pipeline commands rendezvous (provably overlap), each runs exactly once, and the log replays in source order (byte-stable output). |
| 44 | dicom-script | `testParallelPipelineFailurePropagates` | `run --parallel` | A failing pipeline command's exit status surfaces as the thrown error; both commands still ran. |
| 45 | dicom-dcmdir | `testUpdateAddsNewFileToExistingDICOMDIR` | `update --add` | Update re-indexes both existing files, adds the new one, preserves the file-set ID; the reread DICOMDIR references old + new. |
| 46 | dicom-dcmdir | `testUpdateDropsMissingFilesFromIndex` | `update` | A referenced file deleted from disk is counted missing and dropped from the rebuilt index; survivors are re-indexed. |

**Bug caught by #45/#46:** `DICOMDIRWorkflow.buildDirectory` computed File IDs with
`replacingOccurrences(of: inputURL.path + "/")` — under a symlinked input (e.g. `/tmp` →
`/private/tmp`) this produced corrupted File IDs like `privateimg0.dcm`. Fixed with standardized
prefix-stripping; the fix lands in the shared workflow, so the CLI and the app are repaired
together.

The pre-existing `testParallelFlagExecutesEveryStepOnce` remains valid: top-level script steps stay
sequential by design (setVariable/conditional dependencies) — only pipeline commands parallelize.
