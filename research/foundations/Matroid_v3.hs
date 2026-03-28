-- | Matroid_v3.hs
-- ABI/EABI-oriented matroid layer with BlockDesign extension.
--
-- Purpose
-- -------
-- This version pushes the matroid layer toward the VM-facing ABI:
--
--   * finite symbolic families
--   * fixed cardinalities
--   * BlockDesign as the ABI surface
--   * deterministic domain generation from 0-basis
--   * bitboard/board ready structure
--
-- It remains a Haskell source-of-truth draft, but is shaped so a later
-- C/EABI lowering can replace lists with bitsets and bounded loops.
--
-- Layering
-- --------
--   Automaton_v3 point-sets
--     -> Matroid_v3 / BlockDesign
--     -> Configuration routines
--
-- Key idea
-- --------
-- A BlockDesign is not a bag of Unicode tables. It is a symbolic family
-- descriptor with:
--   * family kind
--   * family cardinality
--   * rank/escape bound
--   * optional construction law (Hadamard / Pascal / Control / Legacy / etc.)
--
-- Later layers choose actual glyph/codepoint realizations.

module Matroid_v3
  ( -- symbolic families
    SymbolFamily(..), familyCardinality

    -- block design ABI
  , ConstructionLaw(..)
  , MatroidHeader(..)
  , BlockDesign(..)
  , mkBlockDesign
  , domainOf

    -- points / variables / ownership
  , GroundPoint(..), fromPoint, compareGroundPoint, canonicalSort
  , AgentId(..), VariableId(..), Variable(..), Ownership(..), ownershipOf
  , DomainValue(..), Domain(..)

    -- matroid core
  , ClosureMap, MatroidABI(..)
  , mkMatroidABI
  , closureOf, isIndependent, basisOf, rankOf, flatsOf, circuitsOf

    -- block design realization hooks
  , blockDesignVariables
  , blockDesignRankLimit
  , blockDesignGroundSize

    -- utilities
  , subsets
  ) where

import Data.List (nub, subsequences)
import Data.Word (Word8, Word16, Word32, Word64)

import Automaton_v3 (Point(..), PointId(..))

-- ============================================================================
-- SYMBOLIC FAMILIES
-- ============================================================================

data SymbolFamily
  = SF_Variation16
  | SF_Block2
  | SF_Control4
  | SF_Box8
  | SF_Legacy16
  | SF_Arrows16
  | SF_Diacritical33
  | SF_OCR11
  | SF_SuperSub48
  | SF_NumberForms59
  | SF_Arrows112
  | SF_Box128
  | SF_Math256
  | SF_SuppMath256
  | SF_SuppArrows128
  | SF_Braille256
  | SF_Geometric96
  | SF_GeometricExtended97
  | SF_Alchemical128
  | SF_HalfFull240
  | SF_Mahjong48
  | SF_Domino112
  | SF_PlayingCards82
  | SF_Chess94
  | SF_Transport106
  deriving (Eq, Ord, Show)

familyCardinality :: SymbolFamily -> Int
familyCardinality fam = case fam of
  SF_Variation16        -> 16
  SF_Block2             -> 32
  SF_Control4           -> 4
  SF_Box8               -> 128
  SF_Legacy16           -> 256
  SF_Arrows16           -> 16
  SF_Diacritical33      -> 33
  SF_OCR11              -> 11
  SF_SuperSub48         -> 48
  SF_NumberForms59      -> 59
  SF_Arrows112          -> 112
  SF_Box128             -> 128
  SF_Math256            -> 256
  SF_SuppMath256        -> 256
  SF_SuppArrows128      -> 128
  SF_Braille256         -> 256
  SF_Geometric96        -> 96
  SF_GeometricExtended97-> 97
  SF_Alchemical128      -> 128
  SF_HalfFull240        -> 240
  SF_Mahjong48          -> 48
  SF_Domino112          -> 112
  SF_PlayingCards82     -> 82
  SF_Chess94            -> 94
  SF_Transport106       -> 106

-- ============================================================================
-- BLOCK DESIGN ABI
-- ============================================================================

data ConstructionLaw
  = LawControl
  | LawHadamard
  | LawPascal
  | LawTetraDiagonal
  | LawBraille
  | LawGeometric
  | LawLegacy
  | LawMixed
  deriving (Eq, Ord, Show)

data MatroidHeader = MatroidHeader
  { mhFamily     :: !Word8
  , mhGroundSize :: !Word8
  , mhRankLimit  :: !Word8
  , mhLaw        :: !Word8
  } deriving (Eq, Show)

data BlockDesign = BlockDesign
  { bdFamily      :: !SymbolFamily
  , bdLaw         :: !ConstructionLaw
  , bdHeader      :: !MatroidHeader
  , bdDescription :: !String
  } deriving (Eq, Show)

symbolFamilyTag :: SymbolFamily -> Word8
symbolFamilyTag fam = case fam of
  SF_Variation16         -> 0x01
  SF_Block2              -> 0x02
  SF_Control4            -> 0x03
  SF_Box8                -> 0x04
  SF_Legacy16            -> 0x05
  SF_Arrows16            -> 0x06
  SF_Diacritical33       -> 0x07
  SF_OCR11               -> 0x08
  SF_SuperSub48          -> 0x09
  SF_NumberForms59       -> 0x0A
  SF_Arrows112           -> 0x0B
  SF_Box128              -> 0x0C
  SF_Math256             -> 0x0D
  SF_SuppMath256         -> 0x0E
  SF_SuppArrows128       -> 0x0F
  SF_Braille256          -> 0x10
  SF_Geometric96         -> 0x11
  SF_GeometricExtended97 -> 0x12
  SF_Alchemical128       -> 0x13
  SF_HalfFull240         -> 0x14
  SF_Mahjong48           -> 0x15
  SF_Domino112           -> 0x16
  SF_PlayingCards82      -> 0x17
  SF_Chess94             -> 0x18
  SF_Transport106        -> 0x19

lawTag :: ConstructionLaw -> Word8
lawTag law = case law of
  LawControl      -> 0x01
  LawHadamard     -> 0x02
  LawPascal       -> 0x03
  LawTetraDiagonal-> 0x04
  LawBraille      -> 0x05
  LawGeometric    -> 0x06
  LawLegacy       -> 0x07
  LawMixed        -> 0x08

defaultRankLimit :: SymbolFamily -> Int
defaultRankLimit fam = case fam of
  SF_Control4            -> 4
  SF_Variation16         -> 8
  SF_Block2              -> 8
  SF_Box8                -> 16
  SF_Legacy16            -> 16
  SF_Braille256          -> 16
  SF_Geometric96         -> 12
  SF_GeometricExtended97 -> 12
  _                      -> min 16 (familyCardinality fam)

mkBlockDesign :: SymbolFamily -> ConstructionLaw -> String -> BlockDesign
mkBlockDesign fam law desc =
  let gs = familyCardinality fam
      rl = defaultRankLimit fam
  in BlockDesign
      { bdFamily = fam
      , bdLaw = law
      , bdHeader = MatroidHeader
          { mhFamily = symbolFamilyTag fam
          , mhGroundSize = fromIntegral (min 255 gs)
          , mhRankLimit = fromIntegral (min 255 rl)
          , mhLaw = lawTag law
          }
      , bdDescription = desc
      }

newtype DomainValue = DomainValue Int
  deriving (Eq, Ord, Show)

newtype Domain = Domain [DomainValue]
  deriving (Eq, Show)

domainOf :: BlockDesign -> Domain
domainOf bd =
  let n = familyCardinality (bdFamily bd)
  in Domain [DomainValue i | i <- [0 .. n - 1]]

-- ============================================================================
-- POINTS / VARIABLES / OWNERSHIP
-- ============================================================================

newtype GroundPoint = GroundPoint { unGroundPoint :: Point }
  deriving (Eq, Show)

fromPoint :: Point -> GroundPoint
fromPoint = GroundPoint

compareGroundPoint :: GroundPoint -> GroundPoint -> Ordering
compareGroundPoint (GroundPoint (Point (PointId a) ba ta))
                   (GroundPoint (Point (PointId b) bb tb)) =
  compare (a, ba, ta) (b, bb, tb)

sortGP :: [GroundPoint] -> [GroundPoint]
sortGP [] = []
sortGP (x:xs) =
  let left  = [y | y <- xs, compareGroundPoint y x /= GT]
      right = [y | y <- xs, compareGroundPoint y x == GT]
  in sortGP left ++ [x] ++ sortGP right

canonicalSort :: [GroundPoint] -> [GroundPoint]
canonicalSort = sortGP . nub

newtype AgentId = AgentId Int
  deriving (Eq, Ord, Show)

newtype VariableId = VariableId Int
  deriving (Eq, Ord, Show)

data Variable = Variable
  { varId     :: !VariableId
  , varPoint  :: !GroundPoint
  , varDomain :: !Domain
  } deriving (Eq, Show)

data Ownership = Ownership
  { ownVariable :: !VariableId
  , ownAgent    :: !AgentId
  } deriving (Eq, Show)

ownershipOf :: Variable -> Ownership
ownershipOf v =
  let VariableId i = varId v
  in Ownership (varId v) (AgentId (i `mod` 8))

-- ============================================================================
-- MATROID CORE
-- ============================================================================

type ClosureMap = [GroundPoint] -> [GroundPoint]

data MatroidABI = MatroidABI
  { mBlockDesign  :: !BlockDesign
  , mGround       :: [GroundPoint]
  , mVariables    :: [Variable]
  , mOwnership    :: [Ownership]
  , mClosure      :: ClosureMap
  , mIndependent  :: [GroundPoint] -> Bool
  , mRank         :: [GroundPoint] -> Int
  } 

mkMatroidABI :: BlockDesign -> [Point] -> MatroidABI
mkMatroidABI bd pts =
  let ground = canonicalSort (map fromPoint pts)
      vars   = blockDesignVariables bd ground
      owns   = map ownershipOf vars
      cl xs  = canonicalClosure (bdLaw bd) ground xs
      indep xs = all (\a -> notElem a (cl (filter (/= a) xs))) xs
      rk xs = length (basisOf' indep xs)
  in MatroidABI
      { mBlockDesign = bd
      , mGround = ground
      , mVariables = vars
      , mOwnership = owns
      , mClosure = cl
      , mIndependent = indep . canonicalSort
      , mRank = min (blockDesignRankLimit bd) . rk . canonicalSort
      }

blockDesignVariables :: BlockDesign -> [GroundPoint] -> [Variable]
blockDesignVariables bd pts =
  let dom = domainOf bd
  in zipWith mk [0..] pts
  where
    mk i gp = Variable (VariableId i) gp dom

blockDesignRankLimit :: BlockDesign -> Int
blockDesignRankLimit = fromIntegral . mhRankLimit . bdHeader

blockDesignGroundSize :: BlockDesign -> Int
blockDesignGroundSize = fromIntegral . mhGroundSize . bdHeader

canonicalClosure :: ConstructionLaw -> [GroundPoint] -> [GroundPoint] -> [GroundPoint]
canonicalClosure law ground seed =
  let base = canonicalSort seed
      generated = filter (generatedBy law base) ground
  in canonicalSort (base ++ generated)

generatedBy :: ConstructionLaw -> [GroundPoint] -> GroundPoint -> Bool
generatedBy law seed gp@(GroundPoint (Point (PointId pid) basis tag)) =
  gp `elem` seed || any matches seed
  where
    matches (GroundPoint (Point (PointId qid) qb qt)) = case law of
      LawControl ->
        basis == qb || ((tag + qt) `mod` 7 == 0)
      LawHadamard ->
        ((pid `xor` qid) `mod` 2 == 0) || (((pid `xor` qid) `mod` 56) == 0)
      LawPascal ->
        ((pid + qid) `mod` 2 == 0) || ((pid + qid) `mod` 3 == 0)
      LawTetraDiagonal ->
        (basis == qb) || ((tag + qt) `mod` 4 == 0) || (((pid `xor` qid) `mod` 56) == 0)
      LawBraille ->
        ((pid `mod` 256) == (qid `mod` 256))
      LawGeometric ->
        ((pid `mod` 97) == (qid `mod` 97)) || (basis == qb)
      LawLegacy ->
        ((pid `mod` 257) == (qid `mod` 257))
      LawMixed ->
        ((pid `mod` 257) == (qid `mod` 257)) ||
        (basis == qb && ((tag + qt) `mod` 7 == 0)) ||
        (((pid `xor` qid) `mod` 56) == 0)

closureOf :: MatroidABI -> [GroundPoint] -> [GroundPoint]
closureOf m = mClosure m . canonicalSort

isIndependent :: MatroidABI -> [GroundPoint] -> Bool
isIndependent m = mIndependent m . canonicalSort

basisOf :: MatroidABI -> [GroundPoint] -> [GroundPoint]
basisOf m = basisOf' (mIndependent m) . canonicalSort

basisOf' :: ([GroundPoint] -> Bool) -> [GroundPoint] -> [GroundPoint]
basisOf' indep xs = go [] (canonicalSort xs)
  where
    go acc [] = canonicalSort acc
    go acc (y:ys)
      | indep (acc ++ [y]) = go (acc ++ [y]) ys
      | otherwise          = go acc ys

rankOf :: MatroidABI -> [GroundPoint] -> Int
rankOf m = mRank m . canonicalSort

isClosed :: MatroidABI -> [GroundPoint] -> Bool
isClosed m xs = canonicalSort xs == closureOf m xs

flatsOf :: MatroidABI -> [[GroundPoint]]
flatsOf m = map canonicalSort (filter (isClosed m) (subsets (mGround m)))

circuitsOf :: MatroidABI -> [[GroundPoint]]
circuitsOf m =
  let gs = filter (not . null) (subsets (mGround m))
      deps = filter (not . isIndependent m) gs
  in map canonicalSort $
       filter (\c -> all (isIndependent m) (properSubsets c)) deps

-- ============================================================================
-- UTILITIES
-- ============================================================================

subsets :: [a] -> [[a]]
subsets = subsequences

properSubsets :: [a] -> [[a]]
properSubsets xs = filter ((< length xs) . length) (subsequences xs)
