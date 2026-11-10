#!/usr/bin/env bash
# Build the optional PJF110 extension modules (devtmpfs / netfilter / compat /
# userns) against the android14-6.1 DDK and check their kernel imports against
# the recorded device kallsyms. Informational: failures here do not block the
# core namespace module release.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
OUT="$ROOT/out/ext"
mkdir -p "$OUT"

if [ -z "${KDIR:-}" ]; then
  for d in /opt/ddk/kdir/android14-6.1 /opt/ddk/*/android14-6.1; do
    [ -d "$d" ] && export KDIR="$d" && break
  done
fi
[ -n "${KDIR:-}" ] || { echo "KDIR not found"; exit 1; }
echo "Using KDIR=$KDIR"

gunzip -c "$ROOT/device/kallsyms.txt.gz" | awk '{print $3}' | sort -u > "$OUT/device-symbols.txt"

build_one() {
  local target="$1"
  echo "=============================================================="
  echo "=== build TARGET=$target ==="
  echo "=============================================================="
  if ! make TARGET="$target" OUT="$OUT/$target" -j"$(nproc)" 2>&1 | tee "$OUT/$target.log"; then
    echo "RESULT: BUILD_FAILED $target"
    return 1
  fi
  local ko
  ko=$(find "$OUT/$target" -name '*.ko' | head -1)
  if [ -z "$ko" ]; then
    echo "RESULT: NO_KO $target"
    return 1
  fi
  llvm-nm -u "$ko" | awk '{print $NF}' | sort -u > "$OUT/$target.imports"
  local missing
  missing=$(comm -23 "$OUT/$target.imports" "$OUT/device-symbols.txt")
  if [ -n "$missing" ]; then
    echo "RESULT: MISSING_IMPORTS $target"
    echo "$missing"
    return 1
  fi
  echo "RESULT: IMPORTS_OK $target ($(wc -l < "$OUT/$target.imports") imports)"
  cp "$ko" "$OUT/$(basename "$ko" .ko)-pjf110.ko"
  return 0
}

fail=0
for t in "${EXT_TARGETS:-devtmpfs}"; do
  build_one "$t" || fail=$((fail + 1))
done
echo "=============================================================="
echo "Extension build summary: $fail failure(s) out of ${EXT_TARGETS:-devtmpfs}"
exit 0
