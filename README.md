# Hyperverse TTC

Public package for the TTC dual-time toolchain.

## Layout

- `src/` runtime sources
- `docs/` canonical public spec
- `research/` non-normative derivation material
- `artifacts/` generated outputs
- `bin/` compiled binaries (generated)

## Build

```bash
make build
```

## Run End-to-End

```bash
make pipe
```

Output defaults to `artifacts/aztec.txt`.

## Alternate Output Modes

```bash
make pipe MODE=raw OUT=artifacts/aztec.pgm
make pipe MODE=json OUT=artifacts/aztec.json
```
