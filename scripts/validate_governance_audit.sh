#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/governance_audit.py >/tmp/ttc_governance_audit.out 2>/tmp/ttc_governance_audit.err

test -f artifacts/governance/active_audit.ndjson
test -f artifacts/governance/archive_audit.ndjson
test -f artifacts/governance/summary.txt

python3 - <<'PY'
from pathlib import Path

summary = Path("artifacts/governance/summary.txt").read_text(encoding="utf-8")
assert "active_failures=" in summary
assert "historical_warnings=" in summary

for name in ("active_audit.ndjson", "archive_audit.ndjson"):
    path = Path("artifacts/governance") / name
    if not path.read_text(encoding="utf-8"):
        continue
    import json
    line = path.read_text(encoding="utf-8").splitlines()[0]
    obj = json.loads(line)
    for key in ("file", "line", "term", "expected_category", "conflict_class", "severity", "context"):
        assert key in obj, (name, key, obj)
PY

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/active" "$tmp_dir/research"

cat > "$tmp_dir/active/bad.md" <<'EOF_BAD'
Aztec transport
EOF_BAD

if ./scripts/governance_audit.py \
  --active-root "$tmp_dir/active" \
  --historical-root "$tmp_dir/research" \
  --out-dir "$tmp_dir/out" \
  --allowlist "$tmp_dir/none.json" >/dev/null 2>&1
then
  echo "expected active governance audit failure" >&2
  exit 1
fi

cat > "$tmp_dir/active/good.md" <<'EOF_GOOD'
runtime is authoritative
EOF_GOOD

cat > "$tmp_dir/research/bad.md" <<'EOF_HIST'
Aztec transport
EOF_HIST

./scripts/governance_audit.py \
  --active-root "$tmp_dir/active/good.md" \
  --historical-root "$tmp_dir/research" \
  --out-dir "$tmp_dir/out2" \
  --allowlist "$tmp_dir/none.json" >/dev/null 2>&1

python3 - <<'PY' "$tmp_dir/out2/archive_audit.ndjson"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
assert lines, "expected historical warnings"
assert any(line["severity"] == "warn" for line in lines)
assert all("conflict_class" in line for line in lines)
PY

cat > "$tmp_dir/active/ontology_bad.md" <<'EOF_ONT'
projection affects runtime
EOF_ONT

if ./scripts/governance_audit.py \
  --active-root "$tmp_dir/active/ontology_bad.md" \
  --historical-root "$tmp_dir/research" \
  --out-dir "$tmp_dir/out3" \
  --allowlist "$tmp_dir/none.json" >/dev/null 2>&1
then
  echo "expected ontology governance audit failure" >&2
  exit 1
fi

python3 - <<'PY' "$tmp_dir/out3/active_audit.ndjson"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
assert lines, "expected ontology violations"
assert any(line["conflict_class"] == "ontology_violation" for line in lines)
assert any(line.get("relation") == "projection -> runtime" for line in lines)
assert all(line.get("expected") == "invalid" for line in lines if line["conflict_class"] == "ontology_violation")
PY

echo "governance audit validation passed"
