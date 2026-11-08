#!/usr/bin/env bash
# Build the PJF110 namespace module against the android14-6.1 DDK, validate it
# against the recorded device BTF/kallsyms, and package a KernelSU module ZIP.
# Runs inside ghcr.io/ylarod/ddk-min:android14-6.1-20260313 (KDIR preset).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
OUT="$ROOT/out/pjf110"
mkdir -p "$OUT"

echo "=== Environment ==="
echo "KDIR=${KDIR:-<unset>}"; command -v clang; clang --version | head -1
if [ -z "${KDIR:-}" ]; then
  for d in /opt/ddk/kdir/android14-6.1 /opt/ddk/*/android14-6.1; do
    [ -d "$d" ] && export KDIR="$d" && break
  done
fi
[ -n "${KDIR:-}" ] || { echo "KDIR not found"; exit 1; }
echo "Using KDIR=$KDIR"

echo "=== Build namespace module (port61ds) ==="
make TARGET=namespace PORT_DIR=src/port61ds OUT="$OUT/build" -j"$(nproc)"
KO="$OUT/build/droidspaces_ns.ko"
[ -f "$KO" ] || { echo "build produced no .ko"; find "$OUT" -name '*.ko'; exit 1; }
llvm-strip -d "$KO" || true
cp "$KO" "$OUT/droidspaces_ns-pjf110.ko"

echo "=== Module imports vs device kallsyms ==="
llvm-nm -u "$KO" | awk '{print $NF}' | sort -u > "$OUT/imports.txt"
gunzip -c "$ROOT/device/kallsyms.txt.gz" | awk '{print $3}' | sort -u > "$OUT/device-symbols.txt"
missing=$(comm -23 "$OUT/imports.txt" "$OUT/device-symbols.txt")
if [ -n "$missing" ]; then
  echo "ERROR: unresolved kernel imports:"; echo "$missing"; exit 1
fi
echo "All $(wc -l < "$OUT/imports.txt") imports resolve on the device."

echo "=== Layout comparison: module BTF vs device BTF ==="
if command -v pahole >/dev/null 2>&1; then
  pahole -F dwarf --btf_gen_optimized --btf_encode_detached="$OUT/module.btf" "$KO"
  python3 "$ROOT/scripts/abi/compare-btf.py" "$OUT/module.btf" "$ROOT/device/btf-vmlinux.bin" \
      > "$OUT/layout-report.json"
  cat "$OUT/layout-report.json"
  python3 "$ROOT/scripts/check-layout.py" "$OUT/layout-report.json"
else
  echo "pahole unavailable; skipping BTF layout report (runtime gate is the BTF fingerprint)."
fi

echo "=== Package KernelSU module ==="
python3 "$ROOT/scripts/package-zip.py" "$OUT/droidspaces_ns-pjf110.ko" "$OUT/Droidspaces-PJF110-LKM.zip"
echo "Done: $OUT/Droidspaces-PJF110-LKM.zip"