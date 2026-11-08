#!/usr/bin/env python3
"""Fail the build on real ABI breaks; allow the known benign vendor field removals.

The module is compiled against GKI android14-6.1 headers; the PJF110 vendor
kernel drops a few fields that live in padding and that this module never
touches (files_struct.dmabuf_info, mm_struct.abi_extend). Those are allowed.
Any size change, any offset change of a shared field, or any device-added field
is a hard error.
"""
import json, sys

ALLOWED_REMOVED = {
    'files_struct': {'dmabuf_info'},
    'mm_struct': {'abi_extend'},
}

report = json.load(open(sys.argv[1]))
diffs = report.get('differences', {})
errors = []
for name, d in sorted(diffs.items()):
    sizes = d.get('size', [0, 0])
    if sizes[0] != sizes[1]:
        errors.append(f'{name}: size differs {sizes}')
    if d.get('device_only'):
        errors.append(f'{name}: device adds fields {sorted(d["device_only"])}')
    for field, pair in d.get('changed', {}).items():
        mod_val, dev_val = pair
        if dev_val is not None:
            errors.append(f'{name}.{field}: offset/bits changed {pair}')
        elif field not in ALLOWED_REMOVED.get(name, set()):
            errors.append(f'{name}.{field}: module field absent on device (not whitelisted)')

print(f"matching aggregates: {report.get('matching_aggregates')}")
print(f"module-only types (not in device, provided by module): {len(report.get('module_only', []))}")
if errors:
    print('LAYOUT ERRORS:')
    for e in errors:
        print('  ' + e)
    sys.exit(1)
print('Layout check passed: only whitelisted benign vendor field removals.')