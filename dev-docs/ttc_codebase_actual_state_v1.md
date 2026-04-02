# TTC Codebase Actual State v1 (March 27, 2026)

This document describes what the code **actually does now** in this repository, including drift points where behavior and expectations are not aligned.

## 1) Runtime Authority (What Is Authoritative)

Primary runtime authority is split across:

- `src/ttc_canonical_runtime.c`
- `scripts/ttc_busybox.sh`
- `scripts/materialize_trie_artifacts.sh`
- `scripts/leaf_contract.sh`

Projection/transport tools (non-kernel authority):

- `src/ttc_fano_aztec.c`
- `src/ttc_encode.c`
- `src/ttc_decode.c`
- `src/ttc_witness.c`

## 2) Addressing and Variant Classes (`xx/xX/Xx/XX`)

Current class computation is bitwise and deterministic in both main generators.

From busybox/materializer logic:

- `c0 = (input >> 5) & 1`
- `c1 = tick & 1`
- `class_idx = (c1 << 1) | c0`

Mapping:

- `0 -> xx`
- `1 -> xX`
- `2 -> Xx`
- `3 -> XX`

Path shape in current trie materializers:

- `artifacts/<class>/<point>/<lane>/<leaf>/`

`artifact_resolve.awk` packs these into one deterministic 23-bit address:

- `class(2) | point(2) | lane(6) | leaf(13)`

Important: resolver reads the **path**, not dotfile body content.

## 3) What `artifacts/` Is vs What `blocks/` Is (Current Behavior)

### `artifacts/`

Deterministic addressed instance tree intended for interpreter/runtime-facing consumption.

Each leaf is written with fixed surfaces:

- `.canon`
- `.block`
- `.artifact`
- `.bitboard`
- `.golden`
- `.negative`

### `blocks/`

Currently written as a mirror surface by `ttc_write_leaf_contract` (in `leaf_contract.sh`) under:

- `blocks/<class>/<point>/<lane>/<leaf>/`

This mirror is generated from the same computed tuple, not independently resolved.

## 4) Dotfile Participation in Resolve

Dotfiles are currently **not** used to derive identity/address.

- Resolve/import identity is path-derived (`artifact_resolve.awk`).
- Dotfiles are witness/declaration surfaces for that identity.

So today:

- Path decides identity.
- Dotfiles do not participate in address derivation.

## 5) Row Encoding in Dotfiles (Current)

`leaf_contract.sh` emits Braille rows.

### Artifacts leaf rows

Form:

- `FS ADDR GS LEFT US RIGHT RS`

(using Braille control tokens; no word labels).

### Blocks mirror rows

Form:

- `ROW_OPEN ADDR_OPEN ADDR ADDR_CLOSE PAYLOAD_OPEN LEFT US RIGHT PAYLOAD_CLOSE ROW_CLOSE`

All six dotfiles at one leaf share the same framing shape; `.negative` mutates payload bytes.

## 6) Matrix / Aztec Compatibility Functionality (Current)

There are two matrix-related paths, with `aztec` retained only as compatibility naming:

1. `ttc_canonical_runtime encode --matrix`
- Produces per-tick 27x27 ASCII matrix projections (`#`/`.`).
- `--aztec` is a compatibility alias only and does not mean standards Aztec.
- This is projection output, not leaf ABI/object writing.

2. `ttc_encode`/`ttc_decode`/`ttc_witness` and `ttc_fano_aztec`
- `ttc_encode -m slots` exports 60-slot symbols.
- `ttc_decode` imports 60-slot symbols back to bytes.
- `ttc_witness` emits witness semantics for later projection.
- `ttc_fano_aztec` accepts framed bytes (default frame size 16) and emits ascii/raw/json witnesses.

Important constraint:

- `ttc_fano_aztec` processes only complete frames.
- Short input smaller than frame size yields empty `steps`/empty placement.

## 7) What Is Currently Off (Drift List)

These are the main inconsistencies causing confusion.

1. README drift
- README still references old registry/meta/trace expectations that no longer match emitted leaves.

2. Legacy registry assumptions
- Some scripts still reference `blocks/registry/divisors_5040.tsv` fallback behavior.
- Runtime block lookup falls back to built-in defaults if registry is missing.

3. `.bitboard` content
- In `leaf_contract.sh`, `.bitboard` currently writes the same row structure as `.artifact` (not a distinct packed board witness payload).

4. `.canon` gating
- `.canon` is currently emitted every write, not gated to special milestones.

5. Legacy smoke checks
- `scripts/smoke_canonical_runtime.sh` still contains `meta.json` hashing expectations while primary leaf surfaces are dotfiles.

6. Artifacts vs blocks population can diverge operationally
- If users delete one tree manually, mirror assumptions may break until regeneration pipelines are rerun.

## 8) Minimal, Deterministic Regeneration Paths

### A) Runtime-board to artifact leaves

```bash
cat input.bin | ./bin/ttc_canonical_runtime encode --blocks blocks > /tmp/board.txt
./scripts/materialize_trie_artifacts.sh --board-file /tmp/board.txt --out-root artifacts --clear-targets
```

### B) Busybox direct leaf writes

```bash
printf '120 88 95\n' | ./scripts/ttc_busybox.sh --out-root artifacts
```

### C) Matrix compatibility position import/export boundary

```bash
cat artifact.bin | ./bin/ttc_encode -m slots > aztec.pos
cat aztec.pos | ./bin/ttc_decode > artifact.bin
cat aztec.pos | ./bin/ttc_witness -m ascii
```

## 9) Practical Interpretation for Meta-Interpreter ABI

Current code supports this split in practice:

- `artifacts/*/.artifact`: runtime-facing Braille capsule row
- `blocks/*`: shared framing/vocabulary mirror rows

But identity remains path-first today. If identity must be dotfile-first, resolver changes are still required.

## 10) Immediate Documentation Freeze Recommendation

Use this as the working truth until code/docs are reconciled:

1. Address identity is deterministic and path-derived.
2. Dotfiles are fixed six-surface declarations.
3. Artifacts rows are ABI-facing Braille capsules.
4. Blocks rows are framed mirror/reference capsules.
5. Aztec is projection/import-export at slot/board boundaries, not current leaf identity law.
