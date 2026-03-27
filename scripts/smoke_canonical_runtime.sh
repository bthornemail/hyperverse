#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p artifacts

sample="artifacts/canonical_sample.bin"
board="artifacts/canonical_board.txt"
recovered="artifacts/canonical_recovered.txt"
aztec="artifacts/canonical_aztec.txt"
json="artifacts/canonical_run.json"

printf 'TICK_A TICK_B REFLECT ROTATE TANGENT\n' > "$sample"

./bin/ttc_canonical_runtime encode < "$sample" > "$board"
./bin/ttc_canonical_runtime encode --aztec < "$sample" > "$aztec"
./bin/ttc_canonical_runtime encode --json < "$sample" > "$json"
./bin/ttc_canonical_runtime decode < "$board" > "$recovered"

# Determinism smoke: board generation should be byte-identical across reruns.
board2="$(mktemp)"
./bin/ttc_canonical_runtime encode < "$sample" > "$board2"
cmp "$board" "$board2"
rm -f "$board2"

echo "canonical runtime smoke passed"
echo "  board:    $board"
echo "  recovered:$recovered"
echo "  aztec:    $aztec"
echo "  json:     $json"
