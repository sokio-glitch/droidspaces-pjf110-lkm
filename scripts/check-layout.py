#!/usr/bin/env python3
"""Fail on real ABI breaks; allow only the known benign vendor differences.

The module is compiled against GKI android14-6.1 headers, but the PJF110
vendor kernel reshapes a few types that the module never references directly
(they only appear in the module BTF transitively, via included headers):

  files_struct.dmabuf_info  removed by vendor (the slot is padding; the module
                            only calls dup_fd/copy_files/exit_files, never the
                            field itself)
  task_struct.dmabuf_info   renamed to `scx` at the *same* offset/size, so every
                            later field offset is unchanged; the module never
                            touches that slot
  mm_struct.abi_extend      union name absent; android_kabi_reserved1 sits at
                            the same offset; module never uses abi_extend
  page_pool                 vendor uses a different, larger definition; only
                            ever used via pointer by the module (never embedded),
                            so sizeof() does not matter

Any size change of another struct, any offset change of a shared field, or any
unexpected device-added field is a hard error.
"""
import json, sys

REMOVED_FIELD_OK = {
    'files_struct': {'dmabuf_info'},
    'mm_struct': {'abi_extend'},
}
# module field name -> device field name, at the same offset and size
RENAMED_SLOT_OK = {
    'task_struct': {'dmabuf_info': 'scx'},
}
SIZE_CHANGE_OK = {'page_pool'}

report = json.load(open(sys.argv[1]))
diffs = report.get('differences', {})
errors = []
for name, d in sorted(diffs.items()):
    if name in SIZE_CHANGE_OK:
        # Entire definition differs; verified unused-by-value by the module.
        continue
    mod_size, dev_size = d.get('size', [0, 0])
    if mod_size != dev_size:
        errors.append(f'{name}: size differs {mod_size} vs {dev_size}')
    device_only = d.get('device_only', {})
    for field, pair in d.get('changed', {}).items():
        mod_val, dev_val = pair
        if dev_val is not None:
            errors.append(f'{name}.{field}: offset/bits changed {pair}')
            continue
        renamed = RENAMED_SLOT_OK.get(name, {}).get(field)
        if renamed:
            if device_only.get(renamed) != mod_val:
                errors.append(
                    f'{name}.{field}: expected rename to {renamed} at {mod_val}, '
                    f'got {device_only.get(renamed)}')
        elif field not in REMOVED_FIELD_OK.get(name, set()):
            errors.append(f'{name}.{field}: module field absent on device (not whitelisted)')
    allowed_device_only = set(RENAMED_SLOT_OK.get(name, {}).values())
    for field in device_only:
        if field not in allowed_device_only:
            errors.append(f'{name}: unexpected device field {field}')

print(f"matching aggregates: {report.get('matching_aggregates')}")
print(f"module-only types (provided by module, absent on device): "
      f"{len(report.get('module_only', []))}")
if errors:
    print('LAYOUT ERRORS:')
    for e in errors:
        print('  ' + e)
    sys.exit(1)
print('Layout check passed: only whitelisted benign vendor differences.')