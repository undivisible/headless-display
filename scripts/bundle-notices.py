#!/usr/bin/env python3
"""Preserve dependency licenses and notices from the pinned source archives."""
from pathlib import Path
import json
import tarfile
import zipfile
root = Path(__file__).resolve().parent.parent
for entry in json.loads((root/'resources/release-deps.json').read_text()):
    if not entry['path'].startswith('source/'):
        continue
    archive = root/'deps'/entry['path']
    target = root/'deps/licenses'/archive.name
    def save(name, data):
        base = Path(name).name.lower()
        if base.startswith(('license', 'licence', 'copying', 'copyright', 'notice')) and len(data) < 2_000_000:
            destination = target / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    if archive.suffix == '.zip':
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                if not member.is_dir():
                    save(member.filename, source.read(member))
    else:
        with tarfile.open(archive) as source:
            for member in source.getmembers():
                if member.isfile():
                    save(member.name, source.extractfile(member).read())
