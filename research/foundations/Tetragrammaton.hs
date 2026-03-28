-- | Tetragrammaton.hs
-- Canonical 4D simplex law / resolution grammar.
--
-- Layering:
--   Composition/Aztec payload
--     -> Tetragrammaton resolution
--     -> Artifact geometry
--     -> Projection / rendering
--
-- Authority:
--   This module defines lawful simplicial resolution.
--   It interprets encoded composition into simplex-structured geometry using:
--     * barycentric coordinates
--     * chirality / orientation
--     * simplex subdivision
--     * deterministic phase / incidence hooks
--
-- Design:
--   * Tetragrammaton is the law layer
--   * Artifact is the realized carrier layer
--   * XML/SVG/Aztec are downstream views only
--
-- Note:
--   This file intentionally uses direct geometric terms because triangle meshes
--   and tetrahedral lattices are the computational basis.

module Tetragrammaton
  ( -- coordinates
    Coord4(..), Bary4(..)

    -- simplex law
  , Orientation(..), Chirality(..)
  , Simplex0(..), Simplex1(..), Simplex2(..), Simplex3(..)
  , TetraLattice(..), Resolution(..)

    -- core operations
  , normalizeBary4
  , baryToCoord4
  , orientSimplex3
  , subdivideSimplex3
  , latticeFromSimplex3

    -- resolution hooks
  , ResolutionInput(..)
  , resolveFrame
  ) where

import Data.List (sort)
import Data.Word (Word32, Word64)

-- ============================================================================
-- COORDINATES
-- ============================================================================

data Coord4 = Coord4 !Double !Double !Double !Double
  deriving (Eq, Ord, Show)

data Bary4 = Bary4 !Double !Double !Double !Double
  deriving (Eq, Ord, Show)

normalizeBary4 :: Bary4 -> Bary4
normalizeBary4 (Bary4 a b c d) =
  let s = a + b + c + d
  in if s == 0 then Bary4 0 0 0 0 else Bary4 (a/s) (b/s) (c/s) (d/s)

baryToCoord4 :: Bary4 -> Coord4 -> Coord4 -> Coord4 -> Coord4 -> Coord4
baryToCoord4 bary (Coord4 ax ay az aw) (Coord4 bx by bz bw)
                   (Coord4 cx cy cz cw) (Coord4 dx dy dz dw) =
  let Bary4 a b c d = normalizeBary4 bary
  in Coord4
      (a*ax + b*bx + c*cx + d*dx)
      (a*ay + b*by + c*cy + d*dy)
      (a*az + b*bz + c*cz + d*dz)
      (a*aw + b*bw + c*cw + d*dw)

-- ============================================================================
-- SIMPLEX LAW
-- ============================================================================

data Orientation = Positive | Negative
  deriving (Eq, Ord, Show)

data Chirality = ChiLeft | ChiRight
  deriving (Eq, Ord, Show)

newtype Simplex0 = Simplex0 Word32
  deriving (Eq, Ord, Show)

data Simplex1 = Simplex1 !Simplex0 !Simplex0
  deriving (Eq, Ord, Show)

data Simplex2 = Simplex2 !Simplex0 !Simplex0 !Simplex0
  deriving (Eq, Ord, Show)

data Simplex3 = Simplex3 !Simplex0 !Simplex0 !Simplex0 !Simplex0
  deriving (Eq, Ord, Show)

orientSimplex3 :: Chirality -> Simplex3 -> Simplex3
orientSimplex3 chi (Simplex3 a b c d) = case chi of
  ChiLeft  -> Simplex3 a b c d
  ChiRight -> Simplex3 a c b d

subdivideSimplex3 :: Simplex3 -> [Simplex3]
subdivideSimplex3 s@(Simplex3 a b c d) =
  -- Canonical placeholder:
  -- for now, retain one-cell identity subdivision and three oriented faces.
  [ s
  , Simplex3 a b c d
  ]

data TetraLattice = TetraLattice
  { tlVertices4 :: ![(Simplex0, Coord4)]
  , tlCells     :: ![Simplex3]
  } deriving (Eq, Show)

latticeFromSimplex3 :: [(Simplex0, Coord4)] -> [Simplex3] -> TetraLattice
latticeFromSimplex3 verts cells = TetraLattice (sort verts) (sort cells)

-- ============================================================================
-- RESOLUTION
-- ============================================================================

data ResolutionInput = ResolutionInput
  { riTick        :: !Word64
  , riPhase7      :: !Word32
  , riPhase8      :: !Word32
  , riPlaneBit    :: !Word32
  , riChirality   :: !Chirality
  , riPayloadHash :: !Word64
  } deriving (Eq, Show)

data Resolution = Resolution
  { resInput      :: !ResolutionInput
  , resOrientation :: !Orientation
  , resSimplex    :: !Simplex3
  , resLattice    :: !TetraLattice
  } deriving (Eq, Show)

resolveFrame :: ResolutionInput -> Resolution
resolveFrame input =
  let base = Simplex3 (Simplex0 0) (Simplex0 1) (Simplex0 2) (Simplex0 3)
      simplex = orientSimplex3 (riChirality input) base
      orient = case riChirality input of
        ChiLeft  -> Positive
        ChiRight -> Negative
      verts =
        [ (Simplex0 0, Coord4 1 0 0 0)
        , (Simplex0 1, Coord4 0 1 0 0)
        , (Simplex0 2, Coord4 0 0 1 0)
        , (Simplex0 3, Coord4 0 0 0 1)
        ]
      lattice = latticeFromSimplex3 verts [simplex]
  in Resolution input orient simplex lattice
