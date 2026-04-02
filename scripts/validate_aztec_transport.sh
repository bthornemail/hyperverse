#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'TTC\0\xC0\xDB\xFF' > "$tmp_dir/input.bin"

cat "$tmp_dir/input.bin" | ./bin/ttc_framework matrix-encode --ascii > "$tmp_dir/matrix_ascii.txt"
cat "$tmp_dir/input.bin" | ./bin/ttc_framework aztec-encode --ascii > "$tmp_dir/aztec_ascii.txt"
cmp "$tmp_dir/matrix_ascii.txt" "$tmp_dir/aztec_ascii.txt"

python3 - <<'PY' "$tmp_dir/input.bin" "$tmp_dir/raw_modules.bin"
import sys
src = open(sys.argv[1], 'rb').read()
ascii_grid = open(sys.argv[1].replace('input.bin', 'matrix_ascii.txt'), 'r', encoding='utf-8').read().splitlines()
mods = bytearray()
for line in ascii_grid:
    for ch in line.strip():
        mods.append(1 if ch == '#' else 0)
open(sys.argv[2], 'wb').write(mods)
PY

./bin/ttc_framework matrix-decode < "$tmp_dir/raw_modules.bin" > "$tmp_dir/recovered.bin"
cmp "$tmp_dir/input.bin" "$tmp_dir/recovered.bin"

./bin/ttc_framework aztec-decode < "$tmp_dir/raw_modules.bin" > "$tmp_dir/recovered_compat.bin"
cmp "$tmp_dir/recovered.bin" "$tmp_dir/recovered_compat.bin"

python3 - <<'PY' "$tmp_dir/raw_modules.bin" "$tmp_dir/corrupt.bin"
import sys
data = bytearray(open(sys.argv[1], 'rb').read())
data[0] ^= 1
open(sys.argv[2], 'wb').write(data)
PY

if ./bin/ttc_framework matrix-decode < "$tmp_dir/corrupt.bin" >/dev/null 2>&1; then
  echo "corrupted transport unexpectedly decoded" >&2
  exit 1
fi

./bin/ttc_framework >/tmp/ttc_framework_help.txt 2>&1 || true
grep -q 'compat alias; not standards Aztec' /tmp/ttc_framework_help.txt

echo "matrix transport validation passed"
