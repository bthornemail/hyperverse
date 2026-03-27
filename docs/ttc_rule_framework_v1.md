# TTC Rule Framework v1 (Bytecode-Agnostic)

Status: normative extraction framework for archived conversational research.

## 1. Purpose

This framework normalizes archived research prose into deterministic rule IR consumable by a meta-circular interpreter without binding to Prolog/Datalog runtimes.

## 2. Precedence and Fail-Closed Policy

1. `src/` runtime behavior and `docs/ttc_canonical_spec_v1.md` remain authoritative for implemented semantics.
2. Rule packs in `research/rules/*.rules.ndjson` are normalized projections of archived research.
3. Any rule with `status != implemented` must not alter normative execution unless explicitly enabled by policy.
4. Unknown rule IDs, missing required fields, invalid status, or malformed sources are hard failures.

## 3. Rule IR (NDJSON)

Required keys for every rule object:

- `kind` (must be `ttc.rule.v1`)
- `rule_id` (stable identifier; e.g. `A15`, `A21.2`)
- `domain` (`alphabet|braille|projection|consensus|boot|complex`)
- `inputs` (array of symbolic inputs)
- `when` (array of predicates/guards)
- `then` (array of deterministic effects)
- `invariants` (array of must-hold assertions)
- `status` (`implemented|target_state|research_open|deprecated`)
- `sources` (array of `path:line`)

### Canonical ordering

Sort rule objects by `(domain, rule_id, source_order)` where:
- `source_order` is lexical order of `sources[0]` when present.
- Numeric rule IDs are compared numerically before suffixes (`A21` < `A21.2` < `A22`).

### Deterministic digest preimage

For each rule object, compute canonical preimage string in this field order:

`kind|rule_id|domain|inputs_join|when_join|then_join|invariants_join|status|sources_join`

Where all list joins use `\x1f` and all numeric values must be decimal strings.

## 4. Fact and Query Schemas

Fact object required keys:
- `kind` (must be `ttc.fact.v1`)
- `fact_id`
- `domain`
- `payload`
- `sources`

Query object required keys:
- `kind` (must be `ttc.query.v1`)
- `query_id`
- `select`
- `where`
- `order`
- `limit`

Example fact:

```json
{"kind":"ttc.fact.v1","fact_id":"runtime.opcodes","domain":"alphabet","payload":{"TICK_A":"0x01"},"sources":["src/ttc_vm.awk:39"]}
```

Example query:

```json
{"kind":"ttc.query.v1","query_id":"implemented_projection_rules","select":["rule_id"],"where":["domain=projection","status=implemented"],"order":["rule_id asc"],"limit":"256"}
```

## 5. Conflict Resolution

- If multiple archived occurrences map to the same A-number, preserve all as suffixed rule IDs (`A11.1`, `A11.2`, `A21.1`, `A21.2`).
- If archived rule semantics conflict with canonical runtime, set `status=research_open` or `target_state` and attach runtime reference in `invariants`.
- Non-explicit A-numbers (`A4-A9`, `A14`, `A28`) are represented as placeholders in `complex.rules.ndjson` with `status=deprecated` and empty sources.

## 6. Mapping Outputs

- Rule packs:
  - `research/rules/alphabet.rules.ndjson`
  - `research/rules/braille.rules.ndjson`
  - `research/rules/projection.rules.ndjson`
  - `research/rules/consensus.rules.ndjson`
  - `research/rules/boot.rules.ndjson`
  - `research/rules/complex.rules.ndjson`
- Traceability:
  - `research/rules/traceability.tsv`

## 7. Validation Requirements

1. Every explicit `A*` occurrence in archived sources must appear in `traceability.tsv`.
2. No duplicate `(source_doc:line, rule_id)` rows.
3. Every NDJSON line must include all required keys.
4. All `implemented` rules must cite at least one runtime/canonical anchor in `invariants` or `sources`.
