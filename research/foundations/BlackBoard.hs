-- | BlackBoard.hs
--
-- Full point-space interpreter above BitBoard.hs.
--
-- BitBoard.hs handles one fixed-size canonical frame packet:
--
--   Header8 + Addr32 + Bitboard32 + Hash64
--
-- This module lifts from that single-frame packet view to a full board view over
-- Unicode scalar space, with explicit whole-board projections onto:
--
--   * 240 canonical board points  (control / incidence surface)
--   * 360 canonical ring degrees  (full projection / circumference surface)
--
-- The intent matches the corrected discussion in the conversation:
--
--   * BitBoard  = one whiteboard/canvas frame
--   * BlackBoard = full interpreted point-space over many codepoints
--
-- Design law locked here:
--
--   1. Codepoints are interpreted by decomposition into:
--        plane16 + offset16
--
--   2. Temporal law remains the same:
--        56 = 7 × 8
--
--   3. Whole-board projection returns both:
--        Board240  -- incidence/control occupancy
--        Ring360   -- full circumference occupancy
--
--   4. Chirality does not create new codepoints.
--      It orients traversal and point placement deterministically.
--
--   5. The board is canonicalized by bitwise occupancy words.
--      240 points are stored in four Word64 values.
--      360 degrees are stored in six Word64 values.
--
--   6. Plane handling is explicit and bounded.
--      This version uses a 16-plane board domain (0..15) exactly as requested.
--      Scalars on plane 16 are folded by modulo-16 projection unless rejected by
--      the caller before interpretation.
--
-- This file prefers base only and uses bitwise operations throughout.

module BlackBoard
  ( -- * Core point-space types
    Unicode16(..)
  , CodepointView(..)
  , Point240(..)
  , Degree360(..)
  , Board240(..)
  , Ring360(..)
  , BlackBoard(..)
  , BoardError(..)

    -- * Scalar interpretation
  , isUnicodeScalar
  , unicode16Of
  , plane16Of
  , offset16Of
  , codepointView

    -- * Deterministic point projection
  , point240Of
  , degree360Of
  , projectCodepoint

    -- * Whole-board bit operations
  , emptyBoard240
  , emptyRing360
  , setPoint240
  , clearPoint240
  , testPoint240
  , setDegree360
  , clearDegree360
  , testDegree360
  , popCount240
  , popCount360

    -- * Whole-board construction
  , buildBoard240
  , buildRing360
  , buildBlackBoard

    -- * Inverse helpers
  , occupiedPoints240
  , occupiedDegrees360

    -- * Derived timing / geometry witnesses
  , phaseWitness56
  , boardArc14
  , boardQuadrant4

    -- * Demo
  , demoBlackBoard
  ) where

import Data.Bits
import Data.List (foldl')
import Data.Word (Word8, Word16, Word32, Word64)

import Composition
  ( Plane(..)
  , Phase56(..)
  , phase56
  , kernelBit
  )

-- ============================================================================
-- TYPES
-- ============================================================================

-- | Canonical decomposition used by the full-board interpreter.
--
-- A Unicode scalar is decomposed into a 16-plane board domain plus a 16-bit
-- offset within that plane. This matches the requested "whole unicode 16 block
-- planes" model.
--
-- The original scalar is preserved for validation/debugging.
--
data Unicode16 = Unicode16
  { uScalar  :: !Word32
  , uPlane16 :: !Word8     -- 0..15
  , uOffset  :: !Word16    -- 0..65535
  } deriving (Eq, Show)

-- | Full interpreted view of one scalar under the 56-cycle law.
--
data CodepointView = CodepointView
  { cvUnicode   :: !Unicode16
  , cvPhase56   :: !Phase56
  , cvPlane2    :: !Plane
  , cvBasis7    :: !Word8
  , cvMode4     :: !Word8
  , cvChiralBit :: !Word8
  } deriving (Eq, Show)

newtype Point240  = Point240  { unPoint240  :: Int } deriving (Eq, Ord, Show)
newtype Degree360 = Degree360 { unDegree360 :: Int } deriving (Eq, Ord, Show)

-- | 240-point occupancy surface = 4 × Word64 = 256 bits with high 16 bits unused.
--
data Board240 = Board240 !Word64 !Word64 !Word64 !Word64
  deriving (Eq, Show)

-- | 360-degree occupancy surface = 6 × Word64 = 384 bits with high 24 bits unused.
--
data Ring360 = Ring360 !Word64 !Word64 !Word64 !Word64 !Word64 !Word64
  deriving (Eq, Show)

-- | Full resolved board surface.
--
data BlackBoard = BlackBoard
  { bbTick        :: !Int
  , bbState       :: !Word64
  , bbViews       :: ![CodepointView]
  , bbBoard240    :: !Board240
  , bbRing360     :: !Ring360
  } deriving (Eq, Show)

data BoardError
  = InvalidScalar !Word32
  | InvalidTickBB !Int
  | InvalidPoint240 !Int
  | InvalidDegree360 !Int
  deriving (Eq, Show)

-- ============================================================================
-- VALIDATION / DECOMPOSITION
-- ============================================================================

-- | Unicode scalar validity (surrogates excluded).
--
isUnicodeScalar :: Word32 -> Bool
isUnicodeScalar cp =
     cp <= 0x10FFFF
  && not (cp >= 0xD800 && cp <= 0xDFFF)

-- | Plane in the requested 16-plane board domain.
--
-- This is intentionally a board-plane projection, not a claim about Unicode's
-- full 17-plane scalar model. Plane 16 folds by modulo-16 if admitted.
--
plane16Of :: Word32 -> Word8
plane16Of cp = fromIntegral (((cp `shiftR` 16) .&. 0x1F) `mod` 16)

offset16Of :: Word32 -> Word16
offset16Of cp = fromIntegral (cp .&. 0xFFFF)

unicode16Of :: Word32 -> Either BoardError Unicode16
unicode16Of cp
  | not (isUnicodeScalar cp) = Left (InvalidScalar cp)
  | otherwise = Right Unicode16
      { uScalar  = cp
      , uPlane16 = plane16Of cp
      , uOffset  = offset16Of cp
      }

-- ============================================================================
-- PHASE / INTERPRETATION
-- ============================================================================

-- | Whole-board witness of the 56-cycle law.
phaseWitness56 :: Int -> Either BoardError Phase56
phaseWitness56 t =
  case phase56 t of
    Left _  -> Left (InvalidTickBB t)
    Right p -> Right p

-- | Deterministic interpreted codepoint view.
--
-- The chiral bit is derived from the same kernel law already used elsewhere.
-- We keep the kernel constant inline at 0x1D repeated, matching the GS-based
-- constant style from the constitutional layer.
--
codepointView :: Int -> Word64 -> Word32 -> Either BoardError CodepointView
codepointView t state cp = do
  u <- unicode16Of cp
  ph <- phaseWitness56 t
  let ch = fromIntegral (kernelBit 64 kernelC64 state) :: Word8
  pure CodepointView
    { cvUnicode   = u
    , cvPhase56   = ph
    , cvPlane2    = if odd (uPlane16 u) then C1 else C0
    , cvBasis7    = fromIntegral (pFano7 ph)
    , cvMode4     = fromIntegral (pMode4 ph)
    , cvChiralBit = ch
    }

kernelC64 :: Word64
kernelC64 = 0x1D1D1D1D1D1D1D1D

-- ============================================================================
-- POINT PROJECTION
-- ============================================================================

-- | 14-arc quotient of the 56-cycle.
--
--   56 = 14 × 4
--
-- This is useful for grouped board interpretation and matches the corrected
-- conversation model.
--
boardArc14 :: CodepointView -> Int
boardArc14 cv = pTick56 (cvPhase56 cv) `div` 4

-- | Quadrant-like structural partition from the 4-mode codec factor.
boardQuadrant4 :: CodepointView -> Int
boardQuadrant4 = fromIntegral . cvMode4

-- | Deterministic 240-point projection for a single codepoint.
--
-- Layout law:
--
--   offset bucket  = floor(offset * 15 / 65536)     -- 15 buckets per plane
--   plane bucket   = plane16                         -- 16 planes
--   base point     = plane * 15 + bucket            -- 0..239
--
-- Then chirality rotates the point within the 15-bucket plane row.
-- This preserves the 16 × 15 = 240 whole-board law while still respecting
-- kernel-derived directionality.
--
point240Of :: CodepointView -> Point240
point240Of cv = Point240 finalIx
  where
    u         = cvUnicode cv
    pl        = fromIntegral (uPlane16 u) :: Int
    off       = fromIntegral (uOffset u)  :: Int
    bucket15  = (off * 15) `div` 65536                -- 0..14
    base      = pl * 15 + bucket15                    -- 0..239
    rowBase   = pl * 15
    rowLocal  = base - rowBase
    shifted   = if cvChiralBit cv == 0
                  then (rowLocal + fromIntegral (cvBasis7 cv)) `mod` 15
                  else (rowLocal + 15 - fromIntegral (cvBasis7 cv)) `mod` 15
    finalIx   = rowBase + shifted

-- | Deterministic 360-degree projection for a single codepoint.
--
-- The 360 ring is the finer circumference surface. We compose:
--
--   plane contribution : 16 buckets around the ring
--   offset contribution: 360-way normalized angle
--   phase contribution : 56-cycle orientation witness
--
-- Formula is purely integer / bitwise-safe.
--
degree360Of :: CodepointView -> Degree360
degree360Of cv = Degree360 finalDeg
  where
    u          = cvUnicode cv
    off        = fromIntegral (uOffset u) :: Int
    baseDeg    = (off * 360) `div` 65536
    planeLift  = (fromIntegral (uPlane16 u) * 360) `div` 16
    phaseLift  = pTick56 (cvPhase56 cv)
    orient     = if cvChiralBit cv == 0 then phaseLift else (360 - phaseLift)
    finalDeg   = (baseDeg + planeLift + orient) `mod` 360

projectCodepoint :: Int -> Word64 -> Word32 -> Either BoardError (Point240, Degree360, CodepointView)
projectCodepoint t st cp = do
  cv <- codepointView t st cp
  pure (point240Of cv, degree360Of cv, cv)

-- ============================================================================
-- BITWISE OCCUPANCY — 240 SURFACE
-- ============================================================================

emptyBoard240 :: Board240
emptyBoard240 = Board240 0 0 0 0

loc240 :: Int -> Either BoardError (Int, Int)
loc240 ix
  | ix < 0 || ix >= 240 = Left (InvalidPoint240 ix)
  | otherwise = Right (ix `div` 64, ix `mod` 64)

setPoint240 :: Point240 -> Board240 -> Board240
setPoint240 (Point240 ix) (Board240 a b c d) =
  case loc240 ix of
    Left _ -> Board240 a b c d
    Right (w, bitIx) ->
      let mask = bit (fromIntegral bitIx) :: Word64
      in case w of
           0 -> Board240 (a .|. mask) b c d
           1 -> Board240 a (b .|. mask) c d
           2 -> Board240 a b (c .|. mask) d
           _ -> Board240 a b c (d .|. mask)

clearPoint240 :: Point240 -> Board240 -> Board240
clearPoint240 (Point240 ix) (Board240 a b c d) =
  case loc240 ix of
    Left _ -> Board240 a b c d
    Right (w, bitIx) ->
      let mask = complement (bit (fromIntegral bitIx) :: Word64)
      in case w of
           0 -> Board240 (a .&. mask) b c d
           1 -> Board240 a (b .&. mask) c d
           2 -> Board240 a b (c .&. mask) d
           _ -> Board240 a b c (d .&. mask)

testPoint240 :: Point240 -> Board240 -> Bool
testPoint240 (Point240 ix) (Board240 a b c d) =
  case loc240 ix of
    Left _ -> False
    Right (w, bitIx) ->
      let mask = bit (fromIntegral bitIx) :: Word64
          src  = case w of { 0 -> a; 1 -> b; 2 -> c; _ -> d }
      in (src .&. mask) /= 0

popCount240 :: Board240 -> Int
popCount240 (Board240 a b c d) = popCount a + popCount b + popCount c + popCount d

occupiedPoints240 :: Board240 -> [Point240]
occupiedPoints240 bd = [ Point240 i | i <- [0..239], testPoint240 (Point240 i) bd ]

-- ============================================================================
-- BITWISE OCCUPANCY — 360 SURFACE
-- ============================================================================

emptyRing360 :: Ring360
emptyRing360 = Ring360 0 0 0 0 0 0

loc360 :: Int -> Either BoardError (Int, Int)
loc360 ix
  | ix < 0 || ix >= 360 = Left (InvalidDegree360 ix)
  | otherwise = Right (ix `div` 64, ix `mod` 64)

setDegree360 :: Degree360 -> Ring360 -> Ring360
setDegree360 (Degree360 ix) (Ring360 a b c d e f) =
  case loc360 ix of
    Left _ -> Ring360 a b c d e f
    Right (w, bitIx) ->
      let mask = bit (fromIntegral bitIx) :: Word64
      in case w of
           0 -> Ring360 (a .|. mask) b c d e f
           1 -> Ring360 a (b .|. mask) c d e f
           2 -> Ring360 a b (c .|. mask) d e f
           3 -> Ring360 a b c (d .|. mask) e f
           4 -> Ring360 a b c d (e .|. mask) f
           _ -> Ring360 a b c d e (f .|. mask)

clearDegree360 :: Degree360 -> Ring360 -> Ring360
clearDegree360 (Degree360 ix) (Ring360 a b c d e f) =
  case loc360 ix of
    Left _ -> Ring360 a b c d e f
    Right (w, bitIx) ->
      let mask = complement (bit (fromIntegral bitIx) :: Word64)
      in case w of
           0 -> Ring360 (a .&. mask) b c d e f
           1 -> Ring360 a (b .&. mask) c d e f
           2 -> Ring360 a b (c .&. mask) d e f
           3 -> Ring360 a b c (d .&. mask) e f
           4 -> Ring360 a b c d (e .&. mask) f
           _ -> Ring360 a b c d e (f .&. mask)

testDegree360 :: Degree360 -> Ring360 -> Bool
testDegree360 (Degree360 ix) (Ring360 a b c d e f) =
  case loc360 ix of
    Left _ -> False
    Right (w, bitIx) ->
      let mask = bit (fromIntegral bitIx) :: Word64
          src  = case w of
                   0 -> a; 1 -> b; 2 -> c; 3 -> d; 4 -> e; _ -> f
      in (src .&. mask) /= 0

popCount360 :: Ring360 -> Int
popCount360 (Ring360 a b c d e f) =
  popCount a + popCount b + popCount c + popCount d + popCount e + popCount f

occupiedDegrees360 :: Ring360 -> [Degree360]
occupiedDegrees360 rg = [ Degree360 i | i <- [0..359], testDegree360 (Degree360 i) rg ]

-- ============================================================================
-- WHOLE-BOARD CONSTRUCTION
-- ============================================================================

buildBoard240 :: Int -> Word64 -> [Word32] -> Either BoardError ([CodepointView], Board240)
buildBoard240 t st cps = do
  triples <- mapM (projectCodepoint t st) cps
  let cvs = [ cv | (_, _, cv) <- triples ]
      bd  = foldl' (\acc (pt, _, _) -> setPoint240 pt acc) emptyBoard240 triples
  pure (cvs, bd)

buildRing360 :: Int -> Word64 -> [Word32] -> Either BoardError Ring360
buildRing360 t st cps = do
  triples <- mapM (projectCodepoint t st) cps
  pure $ foldl' (\acc (_, dg, _) -> setDegree360 dg acc) emptyRing360 triples

buildBlackBoard :: Int -> Word64 -> [Word32] -> Either BoardError BlackBoard
buildBlackBoard t st cps = do
  triples <- mapM (projectCodepoint t st) cps
  let cvs = [ cv | (_, _, cv) <- triples ]
      bd  = foldl' (\acc (pt, _, _) -> setPoint240 pt acc) emptyBoard240 triples
      rg  = foldl' (\acc (_, dg, _) -> setDegree360 dg acc) emptyRing360 triples
  pure BlackBoard
    { bbTick     = t
    , bbState    = st
    , bbViews    = cvs
    , bbBoard240 = bd
    , bbRing360  = rg
    }

-- ============================================================================
-- DEMO
-- ============================================================================

demoBlackBoard :: Either BoardError BlackBoard
demoBlackBoard =
  buildBlackBoard 19 0x1D1D1D1D1D1D1D1D
    [ 0x000041    -- 'A'
    , 0x0001F600  -- 😀
    , 0x0001D11E  -- 𝄞
    , 0x0001F4A9  -- pile of poo
    , 0x0000E9    -- é
    , 0x0010FFFD  -- near upper scalar edge
    ]
