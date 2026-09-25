#!/usr/bin/env python3
"""Check the "NEMA-verified" markers of one or more modules.

Usage:
    python3 Scripts/check_nema_markers.py Sources/DICOMCore [Sources/DICOMKit ...]
    python3 Scripts/check_nema_markers.py --target 2026a --list Sources/DICOMCore

Every Swift file of a verified module carries at least one marker line:

    NEMA-verified: <edition>, checked <yyyy-mm-dd> — <what was compared>; <provenance>

(see "Verification method" in DICOMCORE_STANDARD_IMPLEMENTATION.md). This script reports
files without a marker, marker lines that do not follow the format, markers for an
edition other than the target, and markers that say nothing about what was compared.
It exits 1 if any file is missing a marker or has a malformed one, so it can gate a
module's audit as done.
"""
import argparse
import collections
import os
import re
import sys

MARKER = re.compile(r'NEMA-verified:')
WELL_FORMED = re.compile(
    r'NEMA-verified: (?P<edition>\d{4}[a-e]), checked (?P<date>\d{4}-\d{2}-\d{2}) — (?P<what>.+)')
MIN_WHAT = 20  # characters; "what was compared" must say something


def swift_files(root):
    for dirpath, _, names in os.walk(root):
        for name in sorted(names):
            if name.endswith('.swift'):
                yield os.path.join(dirpath, name)


def check(root, target, verbose):
    missing, malformed, other_edition, thin = [], [], [], []
    editions = collections.Counter()
    files = list(swift_files(root))
    for path in files:
        with open(path, encoding='utf-8') as f:
            lines = f.read().split('\n')
        markers = [(i + 1, line) for i, line in enumerate(lines) if MARKER.search(line)]
        if not markers:
            missing.append(path)
            continue
        for number, line in markers:
            m = WELL_FORMED.search(line)
            if not m:
                malformed.append(f'{path}:{number}: {line.strip()[:120]}')
                continue
            editions[m['edition']] += 1
            if m['edition'] != target:
                other_edition.append(f'{path}:{number}: {m["edition"]}')
            # The description may continue on the following comment lines.
            what = m['what']
            follow = number
            while len(what) < MIN_WHAT and follow < len(lines) and lines[follow].lstrip().startswith('//'):
                what += ' ' + lines[follow].lstrip('/ ').strip()
                follow += 1
            if len(what.strip()) < MIN_WHAT:
                thin.append(f'{path}:{number}: {line.strip()[:120]}')

    print(f'{root}: {len(files)} Swift files, {len(files) - len(missing)} with a marker, '
          f'{len(missing)} without')
    print('  marker editions: ' + (', '.join(f'{e} ×{n}' for e, n in sorted(editions.items())) or 'none'))
    sections = [('Files without a marker', missing), ('Malformed marker lines', malformed),
                (f'Markers for an edition other than {target} (allowed only for later-edition citations)',
                 other_edition),
                ('Markers that do not say what was compared', thin)]
    for title, items in sections:
        if items:
            print(f'  {title}: {len(items)}')
            if verbose or title.startswith(('Files', 'Malformed')):
                for item in items:
                    print(f'    {item}')
    return not missing and not malformed


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('modules', nargs='+', help='module source directories, e.g. Sources/DICOMCore')
    parser.add_argument('--target', default='2026a', help='target DICOM edition (default 2026a)')
    parser.add_argument('--list', action='store_true', help='list every finding, not only the blocking ones')
    args = parser.parse_args()
    ok = all([check(m, args.target, args.list) for m in args.modules])
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
