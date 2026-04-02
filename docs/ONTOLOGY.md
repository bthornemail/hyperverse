# TTC Ontology v1

Typed deterministic replay is sovereign; ontology describes derived structure, not runtime authority.

## 0. Axiom

All constructs reduce to canonical bytes.

## 1. Primitive Types

```text
bytes        : substrate
event        : runtime step result
structure    : interpreted symbol relations
address      : reference within structure
witness      : semantic encoding of structure
matrix       : arranged byte surface
projection   : rendered surface
transport    : byte carrier
artifact     : identity + payload
```

## 2. Core Relations

```text
produces(runtime, event)
derives(event, timing)
expands(event, incidence)
interprets(incidence, grammar)
assigns(grammar, address)
constructs(address, witness)
arranges(witness, matrix)
renders(matrix, projection)
carries(bytes, transport)
identifies(bytes, artifact)
```

## 3. Canonical Flow

```text
runtime
  -> event
  -> incidence
  -> grammar
  -> address
  -> witness
  -> matrix
  -> projection
```

Parallel relations:

```text
bytes <-> transport
bytes -> artifact
```

## 4. Type Constraints

```text
runtime does not depend on projection
projection does not affect runtime
transport does not define semantics
matrix does not define identity
artifact does not define structure
```

## 5. Structural Geometry

### Points

```text
point := byte | symbol | unit
```

### Lines

```text
line := ordered relation between points
```

Examples:
- Morse = line of timing and signal
- Braille = point set to encoded witness pattern
- hexagram = structured six-line witness state

### Higher Structures

```text
simplex := combinatorial relation of points
pascal  := expansion law over simplex
matrix  := linearized arrangement of relations
```

Backbone:

```text
point -> line -> simplex -> matrix
```

## 6. Incidence Law

```text
incidence defines adjacency and expansion
```

Formal primitives:

```text
adjacent(a, b)
expands(a, {b,c,d})
multiplicity(n, k)
```

Pascal is recurrence over relations.

## 7. Grammar Law

```text
interprets(bytes, structure)
```

Control anchors:

```text
ESC  -> depth
FS   -> boundary axis
GS   -> boundary axis
RS   -> boundary axis
US   -> boundary axis
NULL -> anchor
```

This is projective structure, not geometry.

## 8. Address Law

```text
address := function(structure, timing, incidence)
```

Constraints:

```text
deterministic(address)
replayable(address)
independent_of_projection(address)
```

## 9. Witness Law

```text
witness := semantic_surface(structure, address)
```

Examples:
- Braille = bit witness
- hexagram = symbolic witness

## 10. Matrix Law

```text
matrix := arrange(bytes, structure)
```

Constraints:

```text
reversible(matrix)
deterministic(matrix)
byte_preserving(matrix)
```

## 11. Projection Law

```text
projection := render(matrix | witness)
```

Invariant:

```text
projection != canonical
```

## 12. Transport Law

```text
transport := carry(bytes)
```

Examples:
- FIFO
- pipe
- socket
- TTC matrix transport
- future standards Aztec

## 13. Barcode Law

```text
barcode := projection intersect transport intersect standard
```

## 14. Artifact Law

```text
artifact := { bytes, hash(bytes) }
```

Constraints:

```text
identity = hash(bytes)
verification = recompute(hash)
```

## 15. Invariants

```text
bytes are canonical
everything else is derived
```

```text
structure != transport != projection
```

```text
runtime is the only authority
```

## 16. Minimal Prolog Form

```prolog
produces(runtime, event).
derives(event, timing).
expands(event, incidence).
interprets(incidence, grammar).
assigns(grammar, address).
constructs(address, witness).
arranges(witness, matrix).
renders(matrix, projection).
carries(bytes, transport).
identifies(bytes, artifact).
```
