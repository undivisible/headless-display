#!/usr/bin/env python3
"""Fetch checksum-pinned notices and source archives for binary distribution."""
import hashlib
import json
from pathlib import Path
import subprocess
from concurrent.futures import ThreadPoolExecutor

root = Path(__file__).resolve().parent.parent
entries = json.loads((root / 'resources/release-deps.json').read_text())
def fetch(entry):
    destination = root / 'deps' / entry['path']
    destination.parent.mkdir(parents=True, exist_ok=True)
    def matches():
        return destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == entry['sha256']
    if not matches():
        temporary = destination.with_suffix(destination.suffix + '.partial')
        subprocess.run(['curl', '--fail', '--location', '--retry', '3', '--silent', '--show-error', '--proto', '=https', entry['url'], '-o', str(temporary)], check=True)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != entry['sha256']:
            temporary.unlink()
            raise RuntimeError('Checksum mismatch: ' + entry['path'])
        temporary.replace(destination)
    print('Verified ' + entry['path'], flush=True)
with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(fetch, entries))
