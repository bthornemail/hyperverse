# TTC Canonical Spec v1 (Dual-Time: 8-bit + 16-bit)

Status: Normative for v1 extraction  
Scope: Consolidates runtime-implementable rules and token-contract rules from the current repository docs/code.

## 1) Purpose and Precedence

This document defines one canonical architecture with two synchronized timing planes:

- Plane A: 7-bit time over 8-bit carrier (current executable runtime).
- Plane B: 240-time semantics over 16-bit token contract (normative contract plane).

Precedence policy:

1. Plane A runtime behavior is authoritative where executable code exists.
2. Plane B token semantics are authoritative for 16-bit contract definitions and cross-plane mapping.
3. Narrative/prose prompts and speculative sections in source markdown files are non-normative unless explicitly adopted here.

Normative sources used:

- Plane A runtime:
  - `src/ttc_asm.awk:24-40,70-93`
  - `src/ttc_vm.awk:32-44,76-110,326-360,379-398,509-543`
  - `src/ttc_fano_aztec.c:47-60,71-80,141-158,160-197,280-357`
- Plane B contract:
  - `research/Braille.md:17-20,25-33,38-46,51-61,67-90`

## 2) Plane A (Implemented): 7-bit Time / 8-bit Carrier

### 2.1 Carrier and framing

- Byte carrier uses framed trace bytes.
- Control bytes in assembler output:
  - `FRAME_START=f0`, `FRAME_END=f1`, `SEGMENT_BREAK=f2`, `HINT_START=f3`, `HINT_END=f4`, `ESCAPE=ff`.
  - Source: `src/ttc_asm.awk:27-33`.
- If explicit frame markers are absent, assembler auto-wraps output with `f0 ... f1`.
  - Source: `src/ttc_asm.awk:73-83`.
- VM trace loader requires one valid frame and ignores `f2/f3/f4/ff` (recognized but non-executed).
  - Source: `src/ttc_vm.awk:326-360`.

### 2.2 Executable opcode set

- Runtime opcodes:
  - `TICK_A=0x01`, `TICK_B=0x02`, `REFLECT=0x03`, `ROTATE=0x04`, `TANGENT=0x05`, `BOUNDARY=0x06`.
  - Source: `src/ttc_vm.awk:39-44`.
- VM executes only these opcodes; unknown values are fatal.
  - Source: `src/ttc_vm.awk:379-398`.

### 2.3 Time and state clocks

- Kernel byte: 8-bit delta clock (`K8`) with GS constant (`0x1D`).
  - Source: `src/ttc_vm.awk:32,158-160,250-255`.
- Fano: 7-step ring (`F7`), period-7 basis for winner/chirality interpretation.
  - Source: `src/ttc_vm.awk:122-124,162-164`; `src/ttc_fano_aztec.c:47-50,116-121,177-179`.
- Sonar/cursor/board: 60 and 240 bit structures in VM core.
  - Source: `src/ttc_vm.awk:125-127,166-177,180-196,220-243,279-297`.

### 2.4 Modem witness frame (implemented output)

- VM output mode `OUT=modem_raw|modem_hex` emits witness frame.
  - Source: `src/ttc_vm.awk:101-107,509-543`.
- Default `FRAME_BYTES=16`.
  - Source: `src/ttc_vm.awk:101`.
- Canonical 16-byte layout:
  - Bytes `0..7`: last 8 kernel binary bytes.
  - Bytes `8..15`: Braille hex-weight witness bytes derived from those kernel bytes.
  - Source: `src/ttc_vm.awk:510-522`.

### 2.5 Aztec projection witness (implemented consumer)

- `ttc_fano_aztec.c` consumes byte frames (default 16-byte chunks) from stdin.
  - Source: `src/ttc_fano_aztec.c:34-36,280-283,329-349`.
- Canonical 7 Fano lines and normative 60-slot table are used for addressing/projection.
  - Source: `src/ttc_fano_aztec.c:47-50,71-80,141-158`.
- Braille witness weighting uses fixed map `[01,02,04,40,10,08,20,80]`.
  - Source: `src/ttc_fano_aztec.c:58-60,123-133`.

## 3) Plane B (Contract): 240-Time / 16-bit Token Stream

### 3.1 Token contract (normative, target-state)

- Token width: 16 bits, big-endian, stream-safe, self-delimiting.
  - Source: `research/Braille.md:25-33`.
- Token structure: `type[15:12] + value[11:0]`.
  - Source: `research/Braille.md:38-46`.
- Contract classes include CONTROL (`0x0`) and RELATION (`0x1`) relevant to current runtime.
  - Source: `research/Braille.md:51-55,67-90`.

Implementation state flag:

- CONTROL/RELATION token semantics: **Target-state contract**, not directly parsed by current AWK/C runtime.
- 8-bit framed transport/opcodes: **Implemented runtime**.

### 3.2 Canonical token identities for runtime-equivalent ops

- CONTROL:
  - `FRAME_START=0x0001`, `FRAME_END=0x0002`, `BOUNDARY=0x0003`.
- RELATION:
  - `TICK_A=0x1001`, `TICK_B=0x1002`, `REFLECT=0x1003`, `ROTATE=0x1004`, `TANGENT=0x1005`, `BOUNDARY_MARK=0x1006`.
- Source: `research/Braille.md:67-90`.

## 4) Cross-Plane Mapping (Normative)

### 4.1 Frame boundary mapping

- Plane A frame markers map to Plane B CONTROL class:
  - `f0` ↔ `FRAME_START (0x0001)`
  - `f1` ↔ `FRAME_END (0x0002)`
  - `06` as runtime opcode `BOUNDARY` ↔ RELATION `BOUNDARY_MARK (0x1006)`
  - optional segment/hint bytes (`f2/f3/f4`) ↔ CONTROL subtrace/hint family (`0x0004..0x0007`) by semantic intent.

### 4.2 Opcode identity mapping

| Runtime byte | Symbol | 16-bit token |
|---|---|---|
| `0x01` | `TICK_A` | `0x1001` |
| `0x02` | `TICK_B` | `0x1002` |
| `0x03` | `REFLECT` | `0x1003` |
| `0x04` | `ROTATE` | `0x1004` |
| `0x05` | `TANGENT` | `0x1005` |
| `0x06` | `BOUNDARY` | `0x1006` |

### 4.3 Modem witness mapping

- Plane A witness frame is the executable transport used today.
- Plane B interpretation of that frame:
  - Lower half (`binary` channel): 8 kernel-state witness bytes.
  - Upper half (`hexwt` channel): 8 Braille-weight witness bytes.
- This realizes dual-channel witness semantics while preserving 16-byte packet compatibility with the current projection encoder.

## 5) Resolved Conflicts

### 5.1 `0x00` vs `0x80` boundary semantics

Resolution:

- In this v1 canonical spec, **frame boundaries are transport markers**:
  - Plane A: `f0/f1` frame delimiters.
  - Plane B: `0x0001/0x0002` CONTROL tokens.
- `0x00` and `0x80` claims in prose docs are treated as non-normative metaphors unless bound to explicit executable/token rules above.

### 5.2 FS/GS/RS/US placement conflicts

Resolution:

- FS/GS/RS/US remain semantic axis identifiers in higher-level interpretation.
- They are **not** used as transport delimiters in Plane A runtime framing.
- Where byte-range partition claims conflict (`0x80+` control plane vs `0x1C..0x1F` axes), transport precedence is given to implemented framing/opcode tables and token-class definitions.

### 5.3 Prose-only “normative” claims

Resolution:

- Claims lacking executable or token-table backing are demoted to Research/Open.
- No such claims are binding in sections 1–5 of this spec.

## 6) Worked Examples

### Example A: Symbolic program -> framed carrier (8-bit)

Input symbols:

```text
TICK_A TICK_B REFLECT ROTATE TANGENT
```

Assembler hex output (observed):

```text
f0 01 02 03 04 f1
```

(Reference command: `printf 'TICK_A TICK_B REFLECT ROTATE TANGENT\n' | gawk -f ttc_asm.awk -v MODE=hex`)

### Example B: VM output -> canonical 16-byte modem witness frame

Pipeline output (observed, hex):

```text
88 f3 14 06 66 d1 af 8e c0 bb 14 06 2e b1 cf c6
```

(Reference command: `... | gawk -b -f ttc_vm.awk -v TRACE_HEX_STDIN=1 -v OUT=modem_hex`)

### Example C: Same intent as 16-bit token sequence

Equivalent 16-bit sequence (big-endian words):

```text
0001 1001 1002 1003 1004 1005 0002
```

Mapping note:

- This is Plane B contract representation of Example A.
- Current runtime path requires conversion to Plane A framed bytes for execution.

## 7) Research/Open (Explicitly Non-Normative)

The following remain open research topics and are intentionally outside normative behavior in this spec:

- Sabbath semantics tied to `0x00` or `0x80` as universal boundary symbols in prose docs.
- Claims linking SID/OID/FLAG triples to transport-layer framing without executable/token-table enforcement.
- Any 128-bit addressing, Hadamard, or lattice assertions not represented in current code paths or in the 16-bit token table definitions adopted above.

---

This document is the canonical extraction for v1 dual-time operation: executable Plane A + normative Plane B contract.
