#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'ABC123\0xyz' > "$tmp_dir/input.bin"

./bin/ttc_canonical_runtime encode < "$tmp_dir/input.bin" > "$tmp_dir/v1_a.txt"
./bin/ttc_canonical_runtime encode < "$tmp_dir/input.bin" > "$tmp_dir/v1_b.txt"
cmp "$tmp_dir/v1_a.txt" "$tmp_dir/v1_b.txt"

./bin/ttc_canonical_runtime encode --rule delta64 --seed 1 < "$tmp_dir/input.bin" > "$tmp_dir/v2_seed1_a.txt"
./bin/ttc_canonical_runtime encode --rule delta64 --seed 1 < "$tmp_dir/input.bin" > "$tmp_dir/v2_seed1_b.txt"
./bin/ttc_canonical_runtime encode --rule delta64 --seed 2 < "$tmp_dir/input.bin" > "$tmp_dir/v2_seed2.txt"
cmp "$tmp_dir/v2_seed1_a.txt" "$tmp_dir/v2_seed1_b.txt"
if cmp -s "$tmp_dir/v2_seed1_a.txt" "$tmp_dir/v2_seed2.txt"; then
  echo "delta64 seed did not change output" >&2
  exit 1
fi

./bin/ttc_encode -m slots < "$tmp_dir/input.bin" > "$tmp_dir/slots.txt"
./bin/ttc_decode < "$tmp_dir/slots.txt" > "$tmp_dir/recovered.bin"
cmp "$tmp_dir/input.bin" "$tmp_dir/recovered.bin"

./bin/ttc_framework runtime < "$tmp_dir/input.bin" > "$tmp_dir/runtime_layers.ndjson"
grep -q '"incidence_coeff":' "$tmp_dir/runtime_layers.ndjson"
grep -q '"grammar_role":' "$tmp_dir/runtime_layers.ndjson"
grep -q '"address_slot":' "$tmp_dir/runtime_layers.ndjson"

first_addr="$(./bin/ttc_framework runtime < "$tmp_dir/input.bin" | sed -n '1p')"
second_addr="$(./bin/ttc_framework runtime < "$tmp_dir/input.bin" | sed -n '1p')"
test "$first_addr" = "$second_addr"

echo "framework validation passed"
