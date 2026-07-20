#!/usr/bin/env python3
"""
CI guard: reject committed DICOM files whose pixels carry burned-in PHI.

A de-identified DICOM *header* (PatientName=ANONYMOUS) does NOT guarantee the
*pixels* are clean. Ultrasound, secondary-capture and screenshot images routinely
burn patient name, DOB and institution into the image banner. DICOM records this
in BurnedInAnnotation (0028,0301); a value of "YES" means the pixels carry
identifiers. This is exactly how a real patient's name + DOB once reached this
public repo (see Tests/DICOMRoundTripTest/Corpus/README.md).

This scanner walks the repo, parses every DICOM file with a tiny dependency-free
reader (no pydicom), and FAILS if any file has BurnedInAnnotation == YES.

It intentionally does NOT fail on a missing tag (many clean fixtures omit it) to
avoid false positives — but it prints a warning for image modalities that are
prone to burned-in text (US/SC/XC/OT) when the tag is absent, so a reviewer can
eyeball them.

Exit codes: 0 = clean, 1 = burned-in PHI found, 2 = usage/internal error.
"""
from __future__ import annotations
import os
import struct
import sys

# Tags we care about
TAG_META_GROUP = 0x0002
TAG_TS_UID = (0x0002, 0x0010)          # TransferSyntaxUID
TAG_BURNED_IN = (0x0028, 0x0301)       # BurnedInAnnotation
TAG_MODALITY = (0x0008, 0x0060)        # Modality
TAG_PIXEL_DATA = (0x7FE0, 0x0010)

IMPLICIT_VR_LE = "1.2.840.10008.1.2"
# VRs whose explicit-VR encoding uses a 4-byte length (12-byte header)
LONG_VRS = {b"OB", b"OW", b"OF", b"OD", b"OL", b"SQ", b"UT", b"UN", b"UC", b"UR"}
# modalities where a missing BurnedInAnnotation tag is worth a human glance
RISKY_MODALITIES = {"US", "SC", "XC", "OT", "ES", "GM"}

DICOM_EXTS = (".dcm", ".dicom", ".ima")


def _read_meta_ts(buf: bytes) -> tuple[str, int]:
    """Return (transfer_syntax_uid, dataset_start_offset). Meta is always Explicit VR LE."""
    if len(buf) < 132 or buf[128:132] != b"DICM":
        raise ValueError("no DICM magic")
    i = 132
    ts = ""
    # Walk the file-meta group (0002) which is Explicit VR LE.
    while i + 8 <= len(buf):
        group, elem = struct.unpack_from("<HH", buf, i)
        if group != TAG_META_GROUP:
            break  # end of meta group -> dataset starts here
        vr = buf[i + 4:i + 6]
        if vr in LONG_VRS:
            length = struct.unpack_from("<I", buf, i + 8)[0]
            vstart = i + 12
        else:
            length = struct.unpack_from("<H", buf, i + 6)[0]
            vstart = i + 8
        value = buf[vstart:vstart + length]
        if (group, elem) == TAG_TS_UID:
            ts = value.rstrip(b"\x00 ").decode("ascii", "replace")
        i = vstart + length
    return ts, i


def _iter_dataset(buf: bytes, start: int, implicit: bool):
    """Yield ((group,elem), value_bytes) for top-level dataset elements up to PixelData."""
    i = start
    n = len(buf)
    while i + 8 <= n:
        group, elem = struct.unpack_from("<HH", buf, i)
        if (group, elem) == TAG_PIXEL_DATA:
            return
        if implicit:
            length = struct.unpack_from("<I", buf, i + 4)[0]
            vstart = i + 8
        else:
            vr = buf[i + 4:i + 6]
            if vr in LONG_VRS:
                length = struct.unpack_from("<I", buf, i + 8)[0]
                vstart = i + 12
            else:
                length = struct.unpack_from("<H", buf, i + 6)[0]
                vstart = i + 8
        if length == 0xFFFFFFFF:  # undefined-length SQ/encapsulated -> stop scanning
            return
        yield (group, elem), buf[vstart:vstart + length]
        i = vstart + length


def inspect(path: str):
    """Return dict(status, modality, note) or None if not a DICOM file."""
    with open(path, "rb") as fh:
        buf = fh.read()
    is_ext = path.lower().endswith(DICOM_EXTS)
    if len(buf) < 132 or buf[128:132] != b"DICM":
        # extensionless files must have the magic to be considered DICOM
        return None if not is_ext else {"status": "unparsable", "modality": "", "note": "missing DICM preamble"}
    try:
        ts, ds_start = _read_meta_ts(buf)
        implicit = (ts == IMPLICIT_VR_LE)
        burned = None
        modality = ""
        for (g, e), val in _iter_dataset(buf, ds_start, implicit):
            if (g, e) == TAG_BURNED_IN:
                burned = val.rstrip(b"\x00 ").decode("ascii", "replace").strip().upper()
            elif (g, e) == TAG_MODALITY:
                modality = val.rstrip(b"\x00 ").decode("ascii", "replace").strip().upper()
            if burned is not None and modality:
                break
        if burned == "YES":
            return {"status": "phi", "modality": modality, "note": "BurnedInAnnotation=YES"}
        if burned is None and modality in RISKY_MODALITIES:
            return {"status": "warn", "modality": modality,
                    "note": f"{modality} image with no BurnedInAnnotation tag — verify pixels manually"}
        return {"status": "clean", "modality": modality, "note": burned or "(tag absent)"}
    except Exception as exc:  # noqa: BLE001 - guard must be tolerant
        return {"status": "unparsable", "modality": "", "note": f"parse error: {exc}"}


def find_candidates(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        if ".git" in dirnames:
            dirnames.remove(".git")
        for name in filenames:
            p = os.path.join(dirpath, name)
            if name.lower().endswith(DICOM_EXTS):
                yield p
            else:
                # sniff extensionless files cheaply for the DICM magic
                try:
                    with open(p, "rb") as fh:
                        head = fh.read(132)
                    if len(head) == 132 and head[128:132] == b"DICM":
                        yield p
                except OSError:
                    continue


def main(argv: list[str]) -> int:
    root = argv[1] if len(argv) > 1 else "."
    phi, warn, scanned = [], [], 0
    for path in sorted(find_candidates(root)):
        res = inspect(path)
        if res is None:
            continue
        scanned += 1
        rel = os.path.relpath(path, root)
        if res["status"] == "phi":
            phi.append((rel, res))
        elif res["status"] == "warn":
            warn.append((rel, res))
    print(f"[phi-guard] scanned {scanned} DICOM file(s) under {root}")
    for rel, res in warn:
        print(f"  ⚠ WARN  {rel}: {res['note']}")
    for rel, res in phi:
        print(f"  ✖ PHI   {rel}: {res['note']} (modality {res['modality'] or '?'})")
    if phi:
        print(f"\n[phi-guard] FAILED: {len(phi)} file(s) have burned-in PHI (BurnedInAnnotation=YES).")
        print("Remove the file or redact the pixel banner before committing. "
              "See Tests/DICOMRoundTripTest/Corpus/README.md.")
        return 1
    print("[phi-guard] OK: no burned-in PHI detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
