#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ACTIVE = ["README.md", "docs", "dev-docs", "src", "scripts", "Makefile"]
DEFAULT_HISTORICAL = ["archive", "research"]
GOVERNANCE_META = {
    "docs/LEXICON.md",
    "docs/LEXICON.json",
    "docs/ONTOLOGY.md",
    "docs/ttc_authoritative_lexicon_v1.md",
    "docs/GOVERNANCE_ALLOWLIST.json",
    "scripts/validate_lexicon.sh",
    "scripts/validate_ontology.sh",
    "scripts/governance_audit.py",
    "scripts/validate_governance_audit.sh",
}

TEXT_SUFFIXES = {
    "",
    ".md",
    ".txt",
    ".json",
    ".ndjson",
    ".c",
    ".h",
    ".sh",
    ".awk",
    ".py",
    ".mk",
    ".tsv",
    ".ttl",
    ".xml",
}

AZTEC_ALLOWED_CONTEXT = re.compile(
    r"compat|compatibility|alias|reserved|future|standards|scanner|barcode|placeholder|not standards aztec|ttc_aztec_std",
    re.IGNORECASE,
)
AZTEC_WORD = re.compile(r"\baztec\b", re.IGNORECASE)
HISTORICAL_REF = re.compile(r"((?:research|archive)/[A-Za-z0-9_./ -]+\.[A-Za-z0-9]+)(?::\d+(?:-\d+)?)?")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repo-wide lexicon/ontology governance audit")
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--active-root", action="append", dest="active_roots")
    parser.add_argument("--historical-root", action="append", dest="historical_roots")
    parser.add_argument("--out-dir", default="artifacts/governance")
    parser.add_argument("--allowlist", default="docs/GOVERNANCE_ALLOWLIST.json")
    parser.add_argument("--strict-history", action="store_true")
    return parser.parse_args()


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def normalize_rel(root: Path, path: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return os.path.relpath(path, root).replace(os.sep, "/")


def is_text_file(path: Path) -> bool:
    if path.suffix.lower() not in TEXT_SUFFIXES and path.name != "Makefile":
        return False
    try:
        with path.open("rb") as fh:
            head = fh.read(2048)
    except OSError:
        return False
    if b"\x00" in head:
        return False
    return True


def iter_files(root: Path, entries):
    files = []
    for entry in entries:
        path = root / entry
        if not path.exists():
            continue
        if path.is_file():
            if is_text_file(path):
                files.append(path)
            continue
        for candidate in sorted(path.rglob("*")):
            if candidate.is_file() and is_text_file(candidate):
                files.append(candidate)
    return files


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_allowlist(path: Path):
    if not path.exists():
        return []
    data = load_json(path)
    entries = []
    for item in data.get("entries", []):
        entries.append(
            {
                "path_regex": re.compile(item["path_regex"]),
                "conflict_class": item["conflict_class"],
                "line_regex": re.compile(item["line_regex"]),
            }
        )
    return entries


def allowed(allowlist, rel_path: str, conflict_class: str, line: str) -> bool:
    for entry in allowlist:
        if entry["conflict_class"] != conflict_class:
            continue
        if not entry["path_regex"].search(rel_path):
            continue
        if entry["line_regex"].search(line):
            return True
    return False


def governance_meta(rel_path: str) -> bool:
    return rel_path in GOVERNANCE_META


def historical_citations(active_files, root: Path):
    cited = {}
    for path in active_files:
        rel = normalize_rel(root, path)
        if governance_meta(rel):
            continue
        text = read_text(path)
        for match in HISTORICAL_REF.finditer(text):
            ref = match.group(1).strip()
            ref_path = Path(ref).as_posix()
            cited.setdefault(ref_path, set()).add(rel)
    return cited


def add_record(records, rel_path, line_no, term, expected, conflict_class, severity, context, cited_by_active=None, relation=None):
    record = {
        "file": rel_path,
        "line": line_no,
        "term": term,
        "expected_category": expected,
        "conflict_class": conflict_class,
        "severity": severity,
        "context": context.rstrip("\n"),
    }
    if relation is not None:
        record["relation"] = relation
        record["expected"] = "invalid"
    if cited_by_active is not None:
        record["cited_by_active"] = cited_by_active
    records.append(record)


def scan_file(path: Path, root: Path, group: str, severity: str, lexicon: dict, allowlist, cited_refs):
    rel = normalize_rel(root, path)
    if governance_meta(rel):
        return []

    records = []
    text = read_text(path)
    lines = text.splitlines()

    forbidden = lexicon.get("forbidden_collisions", [])
    ontology_patterns = [
        {
            "pattern": re.compile(r"\bbytes?\s+(?:is|are|=)\s+transport\b", re.IGNORECASE),
            "term": "bytes",
            "expected": "substrate",
            "relation": "bytes -> transport",
        },
        {
            "pattern": re.compile(r"\bbytes?\s+(?:is|are|=)\s+projection\b", re.IGNORECASE),
            "term": "bytes",
            "expected": "substrate",
            "relation": "bytes -> projection",
        },
        {
            "pattern": re.compile(r"\bbytes?\s+(?:is|are|=)\s+artifact\b", re.IGNORECASE),
            "term": "bytes",
            "expected": "substrate",
            "relation": "bytes -> artifact",
        },
        {
            "pattern": re.compile(r"\bprojection\b.*\bdefines?\s+meaning\b", re.IGNORECASE),
            "term": "projection",
            "expected": "projection",
            "relation": "projection -> meaning",
        },
        {
            "pattern": re.compile(r"\btransport\b.*\bdefines?\s+semantics\b", re.IGNORECASE),
            "term": "transport",
            "expected": "transport",
            "relation": "transport -> semantics",
        },
        {
            "pattern": re.compile(r"\bmatrix\b.*\bdefines?\s+identity\b", re.IGNORECASE),
            "term": "matrix",
            "expected": "matrix",
            "relation": "matrix -> identity",
        },
        {
            "pattern": re.compile(r"\bartifact\b.*\bdefines?\s+structure\b", re.IGNORECASE),
            "term": "artifact",
            "expected": "artifact",
            "relation": "artifact -> structure",
        },
        {
            "pattern": re.compile(r"\bruntime\b.*\bdepends?\s+on\b.*\bprojection\b", re.IGNORECASE),
            "term": "runtime",
            "expected": "runtime",
            "relation": "runtime -> projection",
        },
        {
            "pattern": re.compile(r"\bprojection\b.*\baffects?\s+runtime\b", re.IGNORECASE),
            "term": "projection",
            "expected": "projection",
            "relation": "projection -> runtime",
        },
        {
            "pattern": re.compile(r"\baztec\b.*\bdefines?\s+structure\b", re.IGNORECASE),
            "term": "Aztec",
            "expected": lexicon["keywords"].get("Aztec"),
            "relation": "Aztec -> structure",
        },
    ]

    for idx, line in enumerate(lines, start=1):
        cited_by = None
        if group == "historical":
            cited_by = sorted(cited_refs.get(rel, []))

        for phrase in forbidden:
            if phrase in line and not allowed(allowlist, rel, "forbidden_collision", line):
                add_record(records, rel, idx, phrase, None, "forbidden_collision", severity, line, cited_by)

        for rule in ontology_patterns:
            if rule["pattern"].search(line) and not allowed(allowlist, rel, "ontology_violation", line):
                add_record(
                    records,
                    rel,
                    idx,
                    rule["term"],
                    rule["expected"],
                    "ontology_violation",
                    severity,
                    line,
                    cited_by,
                    relation=rule["relation"],
                )

        if "Braille" in line:
            if re.search(r"projection|render|screen|svg|pgm|ascii|grid|visual", line, re.IGNORECASE):
                if "Braille (projection)" not in line and "projection-only" not in line and not allowed(allowlist, rel, "missing_required_clarification", line):
                    add_record(records, rel, idx, "Braille", lexicon["keywords"].get("Braille"), "missing_required_clarification", severity, line, cited_by)

        if "hexagram" in line:
            if re.search(r"projection|render|screen|svg|pgm|ascii|grid|visual", line, re.IGNORECASE):
                if "hexagram (witness)" not in line and not allowed(allowlist, rel, "missing_required_clarification", line):
                    add_record(records, rel, idx, "hexagram", lexicon["keywords"].get("hexagram"), "missing_required_clarification", severity, line, cited_by)

        if AZTEC_WORD.search(line):
            if not AZTEC_ALLOWED_CONTEXT.search(line) and not allowed(allowlist, rel, "reserved_name_misuse", line):
                add_record(records, rel, idx, "Aztec", lexicon["keywords"].get("Aztec"), "reserved_name_misuse", severity, line, cited_by)

    return records


def write_ndjson(path: Path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        for record in records:
            fh.write(json.dumps(record, sort_keys=True))
            fh.write("\n")


def write_summary(path: Path, active_records, historical_records):
    by_class = {}
    for rec in active_records + historical_records:
        key = (rec["severity"], rec["conflict_class"])
        by_class[key] = by_class.get(key, 0) + 1

    lines = [
        f"active_failures={len(active_records)}",
        f"historical_warnings={len(historical_records)}",
    ]
    for key in sorted(by_class):
        lines.append(f"{key[0]}:{key[1]}={by_class[key]}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    active_roots = args.active_roots or DEFAULT_ACTIVE
    historical_roots = args.historical_roots or DEFAULT_HISTORICAL
    out_dir = (root / args.out_dir).resolve()
    allowlist = load_allowlist((root / args.allowlist).resolve())
    lexicon = load_json(root / "docs/LEXICON.json")

    active_files = iter_files(root, active_roots)
    historical_files = iter_files(root, historical_roots)
    cited_refs = historical_citations(active_files, root)

    active_records = []
    for path in active_files:
        active_records.extend(scan_file(path, root, "active", "fail", lexicon, allowlist, cited_refs))

    historical_records = []
    for path in historical_files:
        historical_records.extend(scan_file(path, root, "historical", "warn", lexicon, allowlist, cited_refs))

    write_ndjson(out_dir / "active_audit.ndjson", active_records)
    write_ndjson(out_dir / "archive_audit.ndjson", historical_records)
    write_summary(out_dir / "summary.txt", active_records, historical_records)

    print(
        f"governance audit: active_failures={len(active_records)} historical_warnings={len(historical_records)}",
        file=sys.stderr,
    )
    if historical_records:
        cited = sum(1 for rec in historical_records if rec.get("cited_by_active"))
        print(f"governance audit: cited_historical_warnings={cited}", file=sys.stderr)

    if active_records:
        for record in active_records[:20]:
            print(
                f"{record['severity']} {record['conflict_class']} {record['file']}:{record['line']} term={record['term']}",
                file=sys.stderr,
            )
        return 1

    if args.strict_history and historical_records:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
