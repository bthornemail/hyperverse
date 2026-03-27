# TTC Unicode Block Registry (Normalized)

Status: normalized registry from user-provided block lists.  
Last update: 2026-03-27.

## 1) Archive and Sources

Archived source snapshot:
- `research/blocks/archive/blocks.source.snapshot.md`

Primary source fragments:
- `blocks/U+280x-U+283x`
- `blocks/U+284x-U+28Fx`
- user-provided block lists in conversation (Variation Selectors, Block Elements, Box Drawing, etc.)

Machine-readable export:
- `research/blocks/blocks.normalized.tsv`

## 2) Normalization Rules

- Normalize each item to inclusive start/end ranges.
- Expand `U+XXXXx` page notation into exact code-point ranges.
- Keep protocol byte headers (`FS/GS/RS/US`) as a non-Unicode registry row.
- Preserve block-level ranges even when some points are unassigned.

## 3) Normalized Block Table

| Block | Range | Pages | Size |
|---|---|---|---:|
| Variation Selectors | `U+FE00..U+FE0F` | `U+FE0x` | 16 |
| Block Elements | `U+2580..U+259F` | `U+258x-U+259x` | 32 |
| Control Plane Header (protocol bytes) | `0x1C..0x1F` | `FS/GS/RS/US` | 4 |
| Box Drawing | `U+2500..U+257F` | `U+250x-U+257x` | 128 |
| Symbols for Legacy Computing | `U+1FB00..U+1FBFF` | `U+1FB0x-U+1FBFx` | 256 |
| Supplemental Arrows-A | `U+27F0..U+27FF` | `U+27Fx` | 16 |
| Combining Diacritical Marks for Symbols | `U+20D0..U+20FF` | `U+20Dx-U+20Fx` | 48 |
| Optical Character Recognition | `U+2440..U+245F` | `U+244x-U+245x` | 32 |
| Superscripts and Subscripts | `U+2070..U+209F` | `U+207x-U+209x` | 48 |
| Number Forms | `U+2150..U+218F` | `U+215x-U+218x` | 64 |
| Arrows | `U+2190..U+21FF` | `U+219x-U+21Fx` | 112 |
| Mathematical Operators | `U+2200..U+22FF` | `U+220x-U+22Fx` | 256 |
| Geometric Shapes (shown subset pages) | `U+25A0..U+25FF` | `U+25Ax-U+25Fx` | 96 |
| Braille Patterns (full) | `U+2800..U+28FF` | `U+280x-U+28Fx` | 256 |

## 4) Braille Fixed-Point Scales (Clock/Header Derived)

Derived from your Braille split:

- **Scale A** (`FP_SCALE_A`): `U+2800..U+283F` -> **64** points
- **Scale B** (`FP_SCALE_B`): `U+2840..U+28FF` -> **192** points

Deterministic partition for an 8-bit Braille offset `b`:

- `0x00..0x3F` => Block A / Scale A
- `0x40..0xFF` => Block B / Scale B

## 5) Notes

- This file is a normalized registry, not a rendering chart.
- Unassigned code points remain part of normalized block ranges.
- For table/chart glyph detail, keep using the source chart files under `blocks/`.
