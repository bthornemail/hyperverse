-- | Matroid.hs
-- Canonical pregeometry / matroid layer over Automaton point-sets.
--
-- Purpose
-- -------
-- This module sits after Automaton.hs and before Configuration.hs.
-- It gives a deterministic closure/independence layer over canonical points,
-- so that later configuration routines can be treated as derived routines
-- rather than primitive truth.
--
-- Architecture
-- ------------
--   Automaton point-sets
--     -> Matroid closure / independence / basis / circuit law
--     -> Configuration routines
--
-- Design notes
-- ------------
-- * Pregeometry and matroid are treated here as effectively the same layer:
--   closure, independence, basis, dimension, flats, rank.
-- * This file is finite and constructive: it avoids external choice by using
--   canonical orderings over points.
-- * The ground set is the Automaton Point type.
-- * A "routine" in the next layer can be built from:
--      - independent sets
--      - closed sets / flats
--      - circuits
--      - symbolic block-design classes
--
-- References informing this layer:
-- - pregeometry as closure/independence/basis/dimension
-- - matroid axioms via independent sets, rank, closure, flats
-- - block design families for later symbolic routines

module Matroid
  ( SymbolFamily(..), familyCardinality
  , GroundPoint(..), fromPoint
  , PointOrder(..), compareGroundPoint
  , Matroid(..), ClosureMap
  , mkMatroidFromPoints
  , mkBlockDesignMatroid
  , isIndependent
  , basisOf
  , allBases
  , circuitsOf
  , rankOf
  , nullityOf
  , closureOf
  , isClosed
  , flatsOf
  , dimensionOf
  , Sign(..), SignedPoint(..), SignedCircuit(..)
  , orientCircuit
  , weightRankUpperBound
  , GreedoidLike(..)
  , subsets
  , canonicalSort
  ) where

import Data.List (nub, subsequences, sort)

import Automaton_v3 (Point(..), PointId(..))

data SymbolFamily
  = SF_Variation16
  | SF_Block32
  | SF_Control4
  | SF_Box128
  | SF_Legacy256
  | SF_Geometric96
  | SF_GeometricExtended
  deriving (Eq, Ord, Show)

familyCardinality :: SymbolFamily -> Int
familyCardinality fam = case fam of
  SF_Variation16       -> 16
  SF_Block32           -> 32
  SF_Control4          -> 4
  SF_Box128            -> 128
  SF_Legacy256         -> 256
  SF_Geometric96       -> 96
  SF_GeometricExtended -> 97

newtype GroundPoint = GroundPoint { unGroundPoint :: Point }
  deriving (Eq, Show)

data PointOrder = ByPointIdThenBasisThenTag
  deriving (Eq, Ord, Show)

compareGroundPoint :: GroundPoint -> GroundPoint -> Ordering
compareGroundPoint (GroundPoint (Point (PointId a) ba ta))
                   (GroundPoint (Point (PointId b) bb tb)) =
  compare (a, ba, ta) (b, bb, tb)

fromPoint :: Point -> GroundPoint
fromPoint = GroundPoint

sortGP :: [GroundPoint] -> [GroundPoint]
sortGP = sortByGP
  where
    sortByGP [] = []
    sortByGP (x:xs) =
      let lessEq y = compareGroundPoint y x /= GT
          left  = [y | y <- xs, lessEq y]
          right = [y | y <- xs, not (lessEq y)]
      in sortByGP left ++ [x] ++ sortByGP right

canonicalSort :: [GroundPoint] -> [GroundPoint]
canonicalSort = sortGP . nub

type ClosureMap = [GroundPoint] -> [GroundPoint]

data Matroid = Matroid
  { mGround       :: [GroundPoint]
  , mClosure      :: ClosureMap
  , mIndependent  :: [GroundPoint] -> Bool
  , mRank         :: [GroundPoint] -> Int
  , mLabel        :: String
  }

mkMatroidFromPoints :: String -> [Point] -> Matroid
mkMatroidFromPoints label pts =
  let ground = canonicalSort (map fromPoint pts)
      cl xs  = canonicalClosure ground xs
      indep xs = all (\a -> notElem a (cl (filter (/= a) xs))) xs
      rk xs = length (basisOf' indep xs)
  in Matroid
      { mGround = ground
      , mClosure = cl
      , mIndependent = indep . canonicalSort
      , mRank = rk . canonicalSort
      , mLabel = label
      }

mkBlockDesignMatroid :: SymbolFamily -> [Point] -> Matroid
mkBlockDesignMatroid fam pts =
  let base = mkMatroidFromPoints ("BlockDesign:" ++ show fam) pts
      cap  = familyCardinality fam
      cl0  = mClosure base
      cl1 xs = take cap (cl0 xs)
      rk1 xs = min cap (mRank base xs)
  in base { mClosure = cl1, mRank = rk1 }

canonicalClosure :: [GroundPoint] -> [GroundPoint] -> [GroundPoint]
canonicalClosure ground seed =
  let base = canonicalSort seed
      generated = filter (generatedBy base) ground
  in canonicalSort (base ++ generated)

generatedBy :: [GroundPoint] -> GroundPoint -> Bool
generatedBy seed gp@(GroundPoint (Point (PointId pid) basis tag)) =
  gp `elem` seed || any matches seed
  where
    matches (GroundPoint (Point (PointId qid) qb qt)) =
      ((pid `mod` 257) == (qid `mod` 257)) ||
      (basis == qb && ((tag + qt) `mod` 7 == 0)) ||
      (((pid `xor` qid) `mod` 56) == 0)

isIndependent :: Matroid -> [GroundPoint] -> Bool
isIndependent m = mIndependent m . canonicalSort

basisOf :: Matroid -> [GroundPoint] -> [GroundPoint]
basisOf m = basisOf' (mIndependent m) . canonicalSort

basisOf' :: ([GroundPoint] -> Bool) -> [GroundPoint] -> [GroundPoint]
basisOf' indep xs = go [] (canonicalSort xs)
  where
    go acc [] = canonicalSort acc
    go acc (y:ys)
      | indep (acc ++ [y]) = go (acc ++ [y]) ys
      | otherwise          = go acc ys

allBases :: Matroid -> [[GroundPoint]]
allBases m =
  let gs = subsets (mGround m)
      indeps = filter (isIndependent m) gs
      maxr = maximum (0 : map length indeps)
  in map canonicalSort (filter ((== maxr) . length) indeps)

circuitsOf :: Matroid -> [[GroundPoint]]
circuitsOf m =
  let gs = filter (not . null) (subsets (mGround m))
      deps = filter (not . isIndependent m) gs
  in map canonicalSort $
       filter (\c -> all (isIndependent m) (properSubsets c)) deps

rankOf :: Matroid -> [GroundPoint] -> Int
rankOf m = mRank m . canonicalSort

nullityOf :: Matroid -> [GroundPoint] -> Int
nullityOf m xs = length xs - rankOf m xs

closureOf :: Matroid -> [GroundPoint] -> [GroundPoint]
closureOf m = mClosure m . canonicalSort

isClosed :: Matroid -> [GroundPoint] -> Bool
isClosed m xs = canonicalSort xs == closureOf m xs

flatsOf :: Matroid -> [[GroundPoint]]
flatsOf m =
  let gs = subsets (mGround m)
  in map canonicalSort (filter (isClosed m) gs)

dimensionOf :: Matroid -> [GroundPoint] -> Int
dimensionOf = rankOf

data Sign = Pos | Neg
  deriving (Eq, Ord, Show)

data SignedPoint = SignedPoint
  { spSign  :: Sign
  , spPoint :: GroundPoint
  } deriving (Eq, Show)

newtype SignedCircuit = SignedCircuit [SignedPoint]
  deriving (Eq, Show)

orientCircuit :: [GroundPoint] -> SignedCircuit
orientCircuit pts =
  let sorted = canonicalSort pts
      signed = zipWith assign [0 :: Int ..] sorted
      assign i p = SignedPoint (if even i then Pos else Neg) p
  in SignedCircuit signed

weightRankUpperBound :: Matroid -> [(GroundPoint, Int)] -> Int
weightRankUpperBound m wx =
  let pts = map fst wx
      r   = rankOf m pts
      ws  = map snd wx
  in r * (if null ws then 0 else maximum ws)

data GreedoidLike = GreedoidLike
  { gFeasible :: [[GroundPoint]]
  , gLabel    :: String
  } deriving (Eq, Show)

subsets :: [a] -> [[a]]
subsets = subsequences

properSubsets :: [a] -> [[a]]
properSubsets xs = filter ((< length xs) . length) (subsequences xs)
