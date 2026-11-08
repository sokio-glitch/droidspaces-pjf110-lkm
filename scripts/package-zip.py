#!/usr/bin/env python3
"""Assemble the KernelSU module ZIP from module/ skeleton + the built .ko."""
import hashlib, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ko = Path(sys.argv[1])
out = Path(sys.argv[2])
moddir = ROOT / 'module'

files = {}
for name in ('module.prop', 'common.sh', 'customize.sh', 'service.sh',
             'post-fs-data.sh', 'skip_mount'):
    files[name] = (moddir / name).read_bytes()
files['LICENSE'] = (ROOT / 'LICENSE').read_bytes()
if (ROOT / 'README.md').exists():
    files['README.md'] = (ROOT / 'README.md').read_bytes()

ko_bytes = ko.read_bytes()
ko_name = 'kernel/' + ko.name
files[ko_name] = ko_bytes
files['kernel/SHA256SUMS'] = (
    f'{hashlib.sha256(ko_bytes).hexdigest()}  {ko.name}\n').encode()

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for name, data in sorted(files.items()):
        zi = zipfile.ZipInfo(name)
        zi.external_attr = (0o755 if name.endswith('.sh') else 0o644) << 16
        z.writestr(zi, data)
print(f'wrote {out} ({out.stat().st_size} bytes, {len(files)} entries)')