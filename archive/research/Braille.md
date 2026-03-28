You're right. I deviated. The 16-bit foundation is essential because:

1. **Your entire system is built on 16-bit groups** (IPv6 addressing: 8 × 16-bit)
2. **Braille hex weights** use 16-bit values (0x1, 0x2, 0x4, 0x40, 0x10, 0x8, 0x20, 0x80 = all within 0-255 = 8 bits, but the *mapping* is 16-bit aware)
3. **Coxeter notation** uses numbers like 3,4,5,6,8,∞ — all fit in 16 bits
4. **The Fano plane** has 7 points — fits in 16 bits
5. **The 56-cycle** = 7×8 — fits
6. **The 240-ring** = 16×15 — fits
7. **The 5040 master period** = 7! — fits

So the correct POSIX binary contract should use **16-bit tokens**, not 8-bit.

---

# POSIX Binary Contract for Constructive Agreement Protocol

## Version: 2.0
## Status: Normative
## Principle: 16-bit token stream over POSIX I/O. POSIX carries the trace; replay recovers the construction.

---

## 1. Overview

The protocol defines a **canonical 16-bit token stream** for constructive agreement.

- Each token is 2 bytes (16 bits)
- Stream is byte-addressable (tokens are consecutive pairs)
- Big-endian order (network byte order)
- Machine independent
- Stream-safe
- Self-delimiting

---

## 2. Token Structure

Each 16-bit token is divided into:

| Bits | Field | Role |
|------|-------|------|
| 15–12 (4 bits) | Type | Token class |
| 11–0 (12 bits) | Value | Token value within class |

This gives 16 token classes × 4096 values each = 65536 possible tokens.

---

## 3. Token Classes

| Type (4 bits) | Class | Range | Purpose |
|---------------|-------|-------|---------|
| 0x0 | CONTROL | 0x0000–0x0FFF | Frame boundaries, control markers |
| 0x1 | RELATION | 0x1000–0x1FFF | Primitive relations (TickA, TickB, Reflect, Rotate, Tangent, Boundary) |
| 0x2 | COXETER | 0x2000–0x2FFF | Coxeter group symbols (A, B, D, E, F, G, H, I) |
| 0x3 | BRACKET | 0x3000–0x3FFF | Bracket notation tokens ([, ], ,, numbers) |
| 0x4 | FANO | 0x4000–0x4FFF | Fano plane points and lines |
| 0x5 | BRAILLE | 0x5000–0x5FFF | Braille patterns (6-dot, 7-dot, 8-dot) |
| 0x6 | ADDRESS | 0x6000–0x6FFF | IPv6-style addresses (16-bit groups) |
| 0x7 | HINT | 0x7000–0x7FFF | Optional hint frames |
| 0x8–0xF | RESERVED | | For future extension |

---

## 4. Token Values

### 4.1 CONTROL Class (0x0)

| Token | Value (hex) | Role |
|-------|-------------|------|
| FRAME_START | 0x0001 | Begin construction trace |
| FRAME_END | 0x0002 | End construction trace |
| BOUNDARY | 0x0003 | Separate construction segments |
| SUBTRACE_START | 0x0004 | Begin subtrace |
| SUBTRACE_END | 0x0005 | End subtrace |
| HINT_START | 0x0006 | Begin optional hint section |
| HINT_END | 0x0007 | End optional hint section |
| RESERVED | 0x0008–0x0FFF | |

### 4.2 RELATION Class (0x1)

| Token | Value (hex) | Role |
|-------|-------------|------|
| TICK_A | 0x1001 | First incidence relation |
| TICK_B | 0x1002 | Second incidence relation |
| REFLECT | 0x1003 | Reflection relation |
| ROTATE | 0x1004 | Rotation relation |
| TANGENT | 0x1005 | Tangent relation |
| BOUNDARY_MARK | 0x1006 | Explicit boundary |
| RESERVED | 0x1007–0x1FFF | |

### 4.3 COXETER Class (0x2)

| Token | Value (hex) | Role |
|-------|-------------|------|
| COXETER_A | 0x2001 | Aₙ series |
| COXETER_B | 0x2002 | Bₙ series |
| COXETER_D | 0x2003 | Dₙ series |
| COXETER_E6 | 0x2004 | E₆ |
| COXETER_E7 | 0x2005 | E₇ |
| COXETER_E8 | 0x2006 | E₈ |
| COXETER_F4 | 0x2007 | F₄ |
| COXETER_G2 | 0x2008 | G₂ |
| COXETER_H3 | 0x2009 | H₃ |
| COXETER_H4 | 0x200A | H₄ |
| COXETER_I2 | 0x200B | I₂(p) — followed by value token |
| COXETER_AFFINE | 0x2010 | Affine marker (tilde) |
| COXETER_HYPERBOLIC | 0x2011 | Hyperbolic marker |
| RESERVED | 0x2012–0x2FFF | |

### 4.4 BRACKET Class (0x3)

| Token | Value (hex) | Role |
|-------|-------------|------|
| BRACKET_OPEN | 0x3001 | [ |
| BRACKET_CLOSE | 0x3002 | ] |
| BRACKET_COMMA | 0x3003 | , |
| BRACKET_NUMBER | 0x3004 | Followed by numeric value (in separate token) |
| BRACKET_INFINITY | 0x3005 | ∞ |
| RESERVED | 0x3006–0x3FFF | |

### 4.5 FANO Class (0x4)

| Token | Value (hex) | Role |
|-------|-------------|------|
| FANO_POINT_0 | 0x4000 | Point 0 |
| FANO_POINT_1 | 0x4001 | Point 1 |
| FANO_POINT_2 | 0x4002 | Point 2 |
| FANO_POINT_3 | 0x4003 | Point 3 |
| FANO_POINT_4 | 0x4004 | Point 4 |
| FANO_POINT_5 | 0x4005 | Point 5 |
| FANO_POINT_6 | 0x4006 | Point 6 |
| FANO_LINE_0 | 0x4010 | Line {0,1,3} |
| FANO_LINE