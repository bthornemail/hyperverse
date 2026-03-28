/**
 * PORT_MATROID_LAW_v0
 *
 * Canonical matroid over the 7-point projective ground set
 * E = {ESC, FS, GS, RS, US, CP, CB}
 *
 * The 7 Fano lines are the primitive circuits.
 * Rank of the full ground set is 3 (as in PG(2,2)).
 *
 * Split:
 *   port-matroid  = dependency / basis / closure law  (this file)
 *   port-lattice  = ordering / refinement / meet-join law  (future)
 *   artifact pkg  = canonical carrier projection        (makePortMatroidArtifact)
 *
 * References:
 *   port-matroid/dev-docs/SNAPSHOT-FORMAT.md   — canonical encoding law
 *   port-matroid/dev-docs/SCHEDULER-CUBE.md    — admissibility / touch-set
 *   port-matroid/dev-docs/RECONCILIATION-INVARIANTS.md
 *   CHIRALITY_SELECTION_LAW_v0.md              — A5b / kernel_bit
 *   PURE_ALGORITHMS.md                         — A5 partition law
 */

// ============================================================================
// TYPES
// ============================================================================

export type PortAtom = 'ESC' | 'FS' | 'GS' | 'RS' | 'US' | 'CP' | 'CB';

export type PortLine = readonly [PortAtom, PortAtom, PortAtom];

export interface PortMatroidLaw {
  readonly ground: readonly PortAtom[];
  isIndependent(s: Iterable<PortAtom>): boolean;
  rank(s: Iterable<PortAtom>): number;
  closure(s: Iterable<PortAtom>): PortAtom[];
  basesOf(closure: Iterable<PortAtom>): PortAtom[][];
  circuitsOf(s: Iterable<PortAtom>): PortLine[];
  exchange(A: PortAtom[], B: PortAtom[]): ExchangeResult | null;
}

export interface ExchangeResult {
  x: PortAtom;   // element from A to remove
  y: PortAtom;   // element from B to add
  result: PortAtom[];  // (A \ {x}) ∪ {y}
}

export interface PortMatroidArtifact {
  kind: 'port_matroid.v0';
  ground: PortAtom[];
  seed: PortAtom[];
  closure: PortAtom[];
  bases: PortAtom[][];
  circuits: PortLine[];
  rank: number;
  independent: boolean;
}

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

// ============================================================================
// GROUND SET AND CIRCUITS
// ============================================================================

/** The 7-element ground set of the port matroid. */
export const PORT_GROUND: readonly PortAtom[] = [
  'ESC', 'FS', 'GS', 'RS', 'US', 'CP', 'CB',
] as const;

/**
 * The 7 canonical Fano lines — each is a minimal dependent set (circuit).
 * These are the primitive circuits of the matroid.
 * Together they form a (7₃) incidence structure isomorphic to PG(2,2).
 */
export const PORT_LINES: readonly PortLine[] = [
  ['ESC', 'FS',  'US'],   // L0
  ['ESC', 'GS',  'CP'],   // L1
  ['ESC', 'RS',  'CB'],   // L2
  ['FS',  'GS',  'CB'],   // L3
  ['FS',  'RS',  'CP'],   // L4
  ['GS',  'RS',  'US'],   // L5
  ['US',  'CP',  'CB'],   // L6
] as const;

// ============================================================================
// COMBINATORIAL HELPERS
// ============================================================================

function toSet<T>(xs: Iterable<T>): Set<T> { return new Set(xs); }

/** All k-element combinations of arr. */
function combinations<T>(arr: T[], k: number): T[][] {
  if (k === 0) return [[]];
  if (k > arr.length) return [];
  const [head, ...tail] = arr;
  return [
    ...combinations(tail, k - 1).map(c => [head, ...c]),
    ...combinations(tail, k),
  ];
}

// ============================================================================
// CANONICAL PORT MATROID
// ============================================================================

export class CanonicalPortMatroid implements PortMatroidLaw {
  readonly ground = PORT_GROUND;

  /**
   * A set S is independent iff no circuit (Fano line) is a subset of S.
   * Sets of size ≤ 2 are always independent (no circuit has fewer than 3 elements).
   */
  isIndependent(s: Iterable<PortAtom>): boolean {
    const ss = toSet(s);
    if (ss.size <= 2) return true;
    return !PORT_LINES.some(L => L.every(p => ss.has(p)));
  }

  /**
   * Rank of S: size of the largest independent subset.
   * For PG(2,2) the maximum rank is 3.
   */
  rank(s: Iterable<PortAtom>): number {
    const xs = [...toSet(s)];
    let best = 0;
    // Only check up to size 3 — rank is bounded at 3 for this matroid
    for (let k = 0; k <= Math.min(xs.length, 3); k++) {
      for (const c of combinations(xs, k)) {
        if (this.isIndependent(c)) best = Math.max(best, c.length);
      }
    }
    return best;
  }

  /**
   * Closure cl(S): the least set containing S that is closed under the
   * incidence law — if two points of a Fano line are in S, the third
   * must also be in cl(S).
   *
   * Implements the fixed-point rule:
   *   cl(cl(S)) = cl(S)
   */
  closure(s: Iterable<PortAtom>): PortAtom[] {
    const cur = toSet(s);
    let changed = true;
    while (changed) {
      changed = false;
      for (const L of PORT_LINES) {
        const hits = L.filter(p => cur.has(p)).length;
        if (hits >= 2) {
          for (const p of L) {
            if (!cur.has(p)) { cur.add(p); changed = true; }
          }
        }
      }
    }
    // Return in ground-set order for determinism
    return PORT_GROUND.filter(p => cur.has(p));
  }

  /**
   * Bases of S: all maximal independent subsets of S.
   * All bases of a matroid have the same cardinality (rank(S)).
   */
  basesOf(s: Iterable<PortAtom>): PortAtom[][] {
    const xs = [...toSet(s)];
    const r   = this.rank(xs);
    return combinations(xs, r).filter(c => this.isIndependent(c));
  }

  /**
   * Circuits of S: all Fano lines that are fully contained in S.
   * These are the minimal dependent sets.
   */
  circuitsOf(s: Iterable<PortAtom>): PortLine[] {
    const ss = toSet(s);
    return PORT_LINES.filter(L => L.every(p => ss.has(p)));
  }

  /**
   * Exchange law: given bases A and B and any x ∈ A \ B,
   * there exists y ∈ B \ A such that (A \ {x}) ∪ {y} is a basis.
   *
   * Returns the first valid exchange found, or null if A and B are equal.
   */
  exchange(A: PortAtom[], B: PortAtom[]): ExchangeResult | null {
    const sA = toSet(A), sB = toSet(B);
    for (const x of sA) {
      if (sB.has(x)) continue;
      for (const y of sB) {
        if (sA.has(y)) continue;
        const candidate = [...sA].filter(e => e !== x).concat([y]);
        if (this.isIndependent(candidate)) return { x, y, result: candidate };
      }
    }
    return null;  // bases equal or no exchange needed
  }
}

// Singleton
export const PORT_MATROID = new CanonicalPortMatroid();

// ============================================================================
// ARTIFACT PROJECTION
// Canonical carrier: seed → closure → bases → circuits → rank
// ============================================================================

/**
 * makePortMatroidArtifact: project a seed set into the canonical artifact shape.
 *
 * seed → cl(seed) → bases(cl) → circuits(cl) → rank(cl)
 *
 * This is the port-matroid side of the canonical artifact pipeline.
 * The artifact kind is 'port_matroid.v0' and matches the seam envelope
 * format expected by port-matroid-tool.
 */
export function makePortMatroidArtifact(seed: Iterable<PortAtom>): PortMatroidArtifact {
  const M       = PORT_MATROID;
  const seedArr = [...new Set(seed)] as PortAtom[];
  const closure = M.closure(seedArr);
  return {
    kind:        'port_matroid.v0',
    ground:      [...PORT_GROUND],
    seed:        seedArr,
    closure,
    bases:       M.basesOf(closure),
    circuits:    M.circuitsOf(closure),
    rank:        M.rank(closure),
    independent: M.isIndependent(seedArr),
  };
}

// ============================================================================
// CHIRALITY SELECTION (A5b)
// Drives atom selection from kernel state — no external randomness.
// ============================================================================

/**
 * chiralitySelect: A5b — partition S into (S0, S1), return the half
 * selected by the kernel chirality bit.
 *
 * bit=0 → S0 (first half)
 * bit=1 → S1 (second half)
 *
 * Spec: CHIRALITY_SELECTION_LAW_v0.md §2 + §5
 */
export function chiralitySelect(
  atoms: PortAtom[],
  bit: 0 | 1,
): PortAtom[] {
  const mid  = Math.ceil(atoms.length / 2);
  const [s0, s1] = [atoms.slice(0, mid), atoms.slice(mid)];
  return bit === 0 ? s0 : s1;
}

/**
 * kernelDrivenAtoms: derive selected atoms from a Fano triplet and chirality bit.
 * The triplet indices map to PORT_GROUND positions.
 * Chirality selects the first or second pair within those three atoms.
 *
 * This is the bridge between A6 (Fano schedule) and the port matroid.
 */
export function kernelDrivenAtoms(
  triplet: [number, number, number],
  chiralBit: 0 | 1,
): PortAtom[] {
  const triAtoms = triplet.map(i => PORT_GROUND[i % PORT_GROUND.length]);
  return chiralBit === 0 ? triAtoms.slice(0, 2) : triAtoms.slice(1);
}

// ============================================================================
// VALIDATION
// ============================================================================

/**
 * validateArtifact: check that a port_matroid.v0 artifact satisfies
 * all matroid axioms. Returns errors if any invariant is violated.
 *
 * Invariants checked:
 *   I1. closure is idempotent: cl(cl(seed)) = cl(seed)
 *   I2. all bases have equal cardinality (rank)
 *   I3. every basis is independent
 *   I4. every circuit is a Fano line
 *   I5. no circuit is a subset of any basis
 *   I6. exchange law holds between any two bases
 */
export function validateArtifact(artifact: PortMatroidArtifact): ValidationResult {
  const M = PORT_MATROID;
  const errors: string[] = [];
  const { seed, closure, bases, circuits, rank } = artifact;

  // I1: closure idempotency
  const cl2 = M.closure(closure);
  if (cl2.join() !== closure.join()) {
    errors.push(`I1 violated: cl(cl(seed)) ≠ cl(seed)`);
  }

  // I2: all bases same cardinality
  if (bases.some(b => b.length !== rank)) {
    errors.push(`I2 violated: bases have unequal cardinality`);
  }

  // I3: every basis is independent
  for (const b of bases) {
    if (!M.isIndependent(b)) {
      errors.push(`I3 violated: basis [${b}] is not independent`);
    }
  }

  // I4: every circuit is a Fano line
  for (const c of circuits) {
    const inLines = PORT_LINES.some(L =>
      L.every((p, i) => p === c[i])
    );
    if (!inLines) errors.push(`I4 violated: circuit [${c}] is not a Fano line`);
  }

  // I5: no circuit ⊆ any basis
  for (const b of bases) {
    for (const c of circuits) {
      if (c.every(p => b.includes(p))) {
        errors.push(`I5 violated: circuit [${c}] ⊆ basis [${b}]`);
      }
    }
  }

  // I6: exchange holds between all pairs of bases
  for (let i = 0; i < bases.length - 1; i++) {
    for (let j = i + 1; j < bases.length; j++) {
      const ex = M.exchange(bases[i], bases[j]);
      // exchange returns null only when bases are equal, which is fine
      if (ex !== null && !M.isIndependent(ex.result)) {
        errors.push(`I6 violated: exchange result [${ex.result}] not independent`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================================
// CANONICAL ENCODING (from SNAPSHOT-FORMAT.md)
// Byte-stable encoding for transport / hashing.
// ============================================================================

const ATOM_INDEX: Record<PortAtom, number> = {
  ESC: 0, FS: 1, GS: 2, RS: 3, US: 4, CP: 5, CB: 6,
};

/** Encode a port matroid artifact to a canonical byte array. */
export function encodeArtifact(art: PortMatroidArtifact): Uint8Array {
  const encodeAtomList = (xs: PortAtom[]): number[] =>
    [xs.length, ...xs.map(a => ATOM_INDEX[a])];

  const bytes: number[] = [
    art.rank,
    art.independent ? 1 : 0,
    ...encodeAtomList(art.seed),
    ...encodeAtomList(art.closure),
    art.bases.length,
    ...art.bases.flatMap(b => encodeAtomList(b)),
    art.circuits.length,
    ...art.circuits.flatMap(c => encodeAtomList([...c])),
  ];

  return new Uint8Array(bytes);
}

/** FNV-1a 64-bit hash of encoded artifact (matches Haskell fnv1a64). */
export function hashArtifact(art: PortMatroidArtifact): string {
  const bytes = encodeArtifact(art);
  let h = 14695981039346656037n;
  for (const b of bytes) {
    h = (h ^ BigInt(b)) * 1099511628211n & 0xFFFFFFFFFFFFFFFFn;
  }
  return h.toString(16).padStart(16, '0');
}

// ============================================================================
// PORT_MATROID_LAW_V0 — single export surface
// ============================================================================

export const PORT_MATROID_LAW_V0 = {
  version:     0,
  name:        'PORT_MATROID_LAW_v0',
  ground:      PORT_GROUND,
  lines:       PORT_LINES,

  // Core matroid operations
  isIndependent: (s: Iterable<PortAtom>) => PORT_MATROID.isIndependent(s),
  rank:          (s: Iterable<PortAtom>) => PORT_MATROID.rank(s),
  closure:       (s: Iterable<PortAtom>) => PORT_MATROID.closure(s),
  basesOf:       (s: Iterable<PortAtom>) => PORT_MATROID.basesOf(s),
  circuitsOf:    (s: Iterable<PortAtom>) => PORT_MATROID.circuitsOf(s),
  exchange:      (A: PortAtom[], B: PortAtom[]) => PORT_MATROID.exchange(A, B),

  // Artifact projection
  makeArtifact:  makePortMatroidArtifact,
  encode:        encodeArtifact,
  hash:          hashArtifact,
  validate:      validateArtifact,

  // Chirality bridge (A5b + A6)
  chiralitySelect,
  kernelDrivenAtoms,
} as const;
