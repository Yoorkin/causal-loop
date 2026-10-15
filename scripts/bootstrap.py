#!/usr/bin/env python3
"""Prepare Selene's legacy HarfBuzz dependency for the October 2026 toolchain.

No global compiler/cache is modified. The original archive is SHA256-verified;
all compatibility edits are deterministic and confined to .deps/harfbuzz.
"""
import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / '.deps' / 'harfbuzz'
SHA256 = '5913988c8efc7b26e173145d694e0d39da15d623240707d9d511f6d04d10807f'
URL = 'https://download.mooncakes.io/user/moonbit-community/harfbuzz/0.1.0.zip'
MARKER = DEST / '.causal-compat-v1'

if not MARKER.exists():
    cache = Path(os.environ.get('MOON_HOME', str(Path.home() / '.moon'))) / 'registry/cache/moonbit-community/harfbuzz/0.1.0.zip'
    if cache.exists():
        data = cache.read_bytes()
    else:
        print('Downloading pinned HarfBuzz 0.1.0…', flush=True)
        with urllib.request.urlopen(URL, timeout=90) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit('HarfBuzz archive checksum mismatch; no files extracted.')
    DEST.parent.mkdir(parents=True, exist_ok=True)
    staging = tempfile.TemporaryDirectory(prefix='causal-harfbuzz-')
    prepared = Path(staging.name).resolve()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for entry in archive.infolist():
            target = (prepared / entry.filename).resolve()
            if not target.is_relative_to(prepared):
                raise SystemExit('Invalid archive path: ' + entry.filename)
        archive.extractall(prepared)
    # October MoonBit reserves `extend`. Rename one field and its parser locals.
    for name in ['src/paint/types.mbt', 'src/ot/color/colr_paint_parse.mbt']:
        path = prepared / name
        path.write_text(re.sub(r'\bextend\b', 'extend_mode', path.read_text()))
    # Retain original quoted snapshots: Debug prints quoted strings, whereas
    # current Show intentionally does not. No expected values are changed.
    for path in (prepared / 'src').rglob('*test.mbt'):
        lines = path.read_text().splitlines(keepends=True)
        for i, line in enumerate(lines):
            if 'inspect(' in line and ('content="Some(\\"' in line or 'content="[\\"' in line):
                lines[i] = line.replace('inspect(', 'debug_inspect(', 1)
        path.write_text(''.join(lines))
    subprocess.run(['moon', '-C', str(prepared), 'fmt'], check=True, cwd=prepared)
    manifest = prepared / 'moon.mod'
    manifest.write_text(manifest.read_text() + '\n// Legacy upstream style warnings, scoped to this dependency only.\nwarnings = "-a"\n')
    # This destination contains only this script's generated dependency copy.
    if DEST.exists():
        shutil.rmtree(DEST)
    shutil.copytree(prepared, DEST)
    staging.cleanup()
    MARKER.write_text(SHA256 + '\n')

subprocess.run(['moon', 'update'], check=True, cwd=ROOT)
subprocess.run(['moon', 'check', 'sim', 'game', 'web'], check=True, cwd=ROOT)
print('Dependencies ready. Run moon build --release, then python3 scripts/serve.py.', flush=True)
