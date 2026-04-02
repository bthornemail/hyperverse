#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

doc="docs/ONTOLOGY.md"

if [[ ! -f "$doc" ]]; then
  echo "ontology violation: $doc missing" >&2
  exit 1
fi

required_patterns=(
  "^# TTC Ontology v1"
  "All constructs reduce to canonical bytes"
  "produces\\(runtime, event\\)"
  "derives\\(event, timing\\)"
  "expands\\(event, incidence\\)"
  "interprets\\(incidence, grammar\\)"
  "assigns\\(grammar, address\\)"
  "constructs\\(address, witness\\)"
  "arranges\\(witness, matrix\\)"
  "renders\\(matrix, projection\\)"
  "carries\\(bytes, transport\\)"
  "identifies\\(bytes, artifact\\)"
  "runtime is the only authority"
)

for pattern in "${required_patterns[@]}"; do
  if ! rg -q "$pattern" "$doc"; then
    echo "ontology violation: missing pattern '$pattern' in $doc" >&2
    exit 1
  fi
done

echo "ontology validation passed"
