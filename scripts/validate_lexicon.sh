#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

files=(
  README.md
  docs
  dev-docs
  src
  scripts
)

forbidden_patterns=(
  "Aztec transport"
  "artifact encoding"
  "matrix rendering"
  "witness grid"
  "JSON is canonical"
  "NDJSON is canonical"
  "Canvas defines meaning"
)

required_layer_files=(
  src/ttc_runtime.c
  src/ttc_incidence.c
  src/ttc_grammar.c
  src/ttc_address.c
  src/ttc_witness.c
  src/ttc_matrix.c
  src/ttc_projection.c
  src/ttc_aztec.c
)

for pattern in "${forbidden_patterns[@]}"; do
  if rg -n "$pattern" "${files[@]}" \
    -g '!docs/ttc_authoritative_lexicon_v1.md' \
    -g '!docs/LEXICON.md' \
    -g '!docs/LEXICON.json' \
    -g '!docs/GOVERNANCE_ALLOWLIST.json' \
    -g '!scripts/validate_lexicon.sh' \
    -g '!scripts/governance_audit.py' \
    -g '!scripts/validate_governance_audit.sh' >/tmp/ttc_lexicon_hits.txt 2>/dev/null; then
    echo "lexicon violation: forbidden phrase '$pattern'" >&2
    cat /tmp/ttc_lexicon_hits.txt >&2
    exit 1
  fi
done

for file in "${required_layer_files[@]}"; do
  if ! rg -q "^/\* LAYER: " "$file"; then
    echo "lexicon violation: missing LAYER header in $file" >&2
    exit 1
  fi
done

if ! rg -q "compat alias; not standards Aztec" src/ttc_framework_cli.c; then
  echo "lexicon violation: framework CLI must warn on aztec compatibility alias" >&2
  exit 1
fi

if ! rg -q "TTC Authoritative Lexicon v1" docs/ttc_authoritative_lexicon_v1.md; then
  echo "lexicon violation: authoritative lexicon document missing" >&2
  exit 1
fi

if ! python3 - <<'PY'
import json
from pathlib import Path

path = Path("docs/LEXICON.json")
if not path.exists():
    raise SystemExit("lexicon violation: docs/LEXICON.json missing")

data = json.loads(path.read_text(encoding="utf-8"))
required = {
    "Braille": "witness",
    "hexagram": "witness",
    "Pascal": "incidence",
    "simplex": "incidence",
    "matrix": "matrix",
    "grid": "projection",
    "JSON": "projection",
    "NDJSON": "projection",
    "JSON Canvas": "projection",
    "Aztec": "barcode",
    "artifact": "artifact",
    "bytes": "substrate",
    "FIFO": "transport",
    "pipe": "transport",
    "socket": "transport",
    "ArrayBuffer": "transport",
    "BLOB": "transport",
    "lane": "address",
    "channel": "address",
}

keywords = data.get("keywords")
if not isinstance(keywords, dict):
    raise SystemExit("lexicon violation: docs/LEXICON.json missing keywords map")

layers = data.get("layer_order")
if not isinstance(layers, list) or not layers:
    raise SystemExit("lexicon violation: docs/LEXICON.json missing layer_order")

substrates = data.get("substrate_order")
if not isinstance(substrates, list) or not substrates:
    raise SystemExit("lexicon violation: docs/LEXICON.json missing substrate_order")

for term, expected in required.items():
    actual = keywords.get(term)
    if actual != expected:
        raise SystemExit(f"lexicon violation: keyword {term!r} must map to {expected!r}, got {actual!r}")

for term, layer in keywords.items():
    if layer not in layers and layer not in substrates:
        raise SystemExit(f"lexicon violation: keyword {term!r} maps to unknown category {layer!r}")

for phrase in ("Aztec transport", "artifact encoding", "matrix rendering", "witness grid", "Braille transport", "JSON is canonical", "NDJSON is canonical", "Canvas defines meaning"):
    if phrase not in data.get("forbidden_collisions", []):
        raise SystemExit(f"lexicon violation: forbidden phrase {phrase!r} missing from docs/LEXICON.json")
PY
then
  exit 1
fi

if ! rg -q "TTC Authoritative Lexicon v1" docs/LEXICON.md; then
  echo "lexicon violation: docs/LEXICON.md missing" >&2
  exit 1
fi

echo "lexicon validation passed"
