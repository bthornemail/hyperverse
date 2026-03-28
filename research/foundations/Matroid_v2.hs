-- | Matroid_v2.hs
-- Constraint-oriented pregeometry / matroid layer.
--
-- This version shifts the earlier explicit set-centric formulation toward a
-- distributed-constraint style interface:
--
--   * points become variables
--   * symbolic families induce finite domains
--   * ownership / assignment are first-class
--   * costs aggregate over partial contexts
--   * matroid closure / independence remain the underlying law
--
-- So this file is still a matroid/pregeometry layer, but presented in a form
-- that can feed routine-building and later configuration layers without making
-- configurations primitive.
--
-- Layering
-- --------
--   Automaton point-sets
--     -> Matroid_v2 constraint / closure layer
--     -> Configuration routines
--
-- Principle
-- ---------
--   every routine is derived from:
--     variables + domains + ownership + cost + closure
--
-- rather than from a fixed explicit catalog of configurations.

module Matroid_v2
  ( -- symbolic families / domains
    SymbolFamily(..), familyCardinality
  , DomainValue(..), Domain(..), familyDomain

    -- variables / agents / contexts
  , AgentId(..), VariableId(..), Variable(..), Context(..)
  , Assignment(..), emptyContext, extendContext, lookupAssignment

    -- points / ownership
  , GroundPoint(..), fromPoint
  , Ownership(..), ownershipOf

    -- cost / objective / constraint layer
  , Constraint(..), ConstraintId(..), Objective(..)
  , evalConstraint, evalObjective

    -- matroid / pregeometry core
  , ClosureMap, MatroidDC(..)
  , mkMatroidDC
  , closureOf, isIndependent, basisOf, rankOf
  , flatsOf, circuitsOf

    -- DCOP-style helpers
  , variablesOf
  , inducedConstraints
  , optimizeContextCostUpperBound

    -- oriented / weighted hooks
  , Sign(..), SignedPoint(..), SignedCircuit(..), orientCircuit
  , weightRankUpperBound

    -- utilities
  , subsets, canonicalSort
  ) where

import Data.List (find, nub, sort, subsequences)
import Data.Word (Word32, Word64)

import Automaton_v3 (Point(..), PointId(..))

-- ============================================================================
-- SYMBOLIC FAMILIES / DOMAINS
-- ============================================================================

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

newtype DomainValue = DomainValue Int
  deriving (Eq, Ord, Show)

newtype Domain = Domain [DomainValue]
  deriving (Eq, Show)

familyDomain :: SymbolFamily -> Domain
familyDomain fam = Domain [DomainValue i | i <- [0 .. familyCardinality fam - 1]]

-- ============================================================================
-- VARIABLES / AGENTS / CONTEXTS
-- ============================================================================

newtype AgentId = AgentId Int
  deriving (Eq, Ord, Show)

newtype VariableId = VariableId Int
  deriving (Eq, Ord, Show)

data Variable = Variable
  { varId     :: !VariableId
  , varPoint  :: !GroundPoint
  , varDomain :: !Domain
  } deriving (Eq, Show)

data Assignment = Assignment
  { asVar   :: !VariableId
  , asValue :: !DomainValue
  } deriving (Eq, Show)

newtype Context = Context [Assignment]
  deriving (Eq, Show)

emptyContext :: Context
emptyContext = Context []

extendContext :: Context -> Assignment -> Context
extendContext (Context as) a =
  Context (a : filter ((/= asVar a) . asVar) as)

lookupAssignment :: Context -> VariableId -> Maybe DomainValue
lookupAssignment (Context as) vid = asValue <$> find ((== vid) . asVar) as

-- ============================================================================
-- POINTS / OWNERSHIP
-- ============================================================================

newtype GroundPoint = GroundPoint { unGroundPoint :: Point }
  deriving (Eq, Show)

fromPoint :: Point -> GroundPoint
fromPoint = GroundPoint

compareGroundPoint :: GroundPoint -> GroundPoint -> Ordering
compareGroundPoint (GroundPoint (Point (PointId a) ba ta))
                   (GroundPoint (Point (PointId b) bb tb)) =
  compare (a, ba, ta) (b, bb, tb)

canonicalSort :: [GroundPoint] -> [GroundPoint]
canonicalSort = sortGP . nub
  where
    sortGP [] = []
    sortGP (x:xs) =
      let left  = [y | y <- xs, compareGroundPoint y x /= GT]
          right = [y | y <- xs, compareGroundPoint y x == GT]
      in sortGP left ++ [x] ++ sortGP right

data Ownership = Ownership
  { ownVariable :: !VariableId
  , ownAgent    :: !AgentId
  } deriving (Eq, Show)

ownershipOf :: Variable -> Ownership
ownershipOf v =
  let VariableId i = varId v
  in Ownership (varId v) (AgentId (i `mod` 8))

-- ============================================================================
-- COST / OBJECTIVE / CONSTRAINT LAYER
-- ============================================================================

newtype ConstraintId = ConstraintId Int
  deriving (Eq, Ord, Show)

data Constraint = Constraint
  { cId        :: !ConstraintId
  , cScope     :: ![VariableId]
  , cEvaluator :: Context -> Int
  }

data Objective
  = Minimize
  | Maximize
  deriving (Eq, Ord, Show)

evalConstraint :: Constraint -> Context -> Int
evalConstraint = cEvaluator

evalObjective :: Objective -> [Constraint] -> Context -> Int
evalObjective obj cs ctx =
  let total = sum (map (`evalConstraint` ctx) cs)
  in case obj of
      Minimize -> total
      Maximize -> negate total

-- ============================================================================
-- MATROID / PREGEOMETRY CORE
-- ============================================================================

type ClosureMap = [GroundPoint] -> [GroundPoint]

data MatroidDC = MatroidDC
  { mGround       :: [GroundPoint]
  , mVariables    :: [Variable]
  , mOwnership    :: [Ownership]
  , mConstraints  :: [Constraint]
  , mObjective    :: !Objective
  , mClosure      :: ClosureMap
  , mIndependent  :: [GroundPoint] -> Bool
  , mRank         :: [GroundPoint] -> Int
  , mLabel        :: String
  }

mkMatroidDC :: String -> SymbolFamily -> [Point] -> MatroidDC
mkMatroidDC label fam pts =
  let ground = canonicalSort (map fromPoint pts)
      vars   = variablesOf fam ground
      owns   = map ownershipOf vars
      cl xs  = canonicalClosure ground xs
      indep xs = all (\a -> notElem a (cl (filter (/= a) xs))) xs
      rk xs = length (basisOf' indep xs)
      cons  = inducedConstraints fam vars ground
  in MatroidDC
      { mGround = ground
      , mVariables = vars
      , mOwnership = owns
      , mConstraints = cons
      , mObjective = Minimize
      , mClosure = cl
      , mIndependent = indep . canonicalSort
      , mRank = rk . canonicalSort
      , mLabel = label
      }

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

closureOf :: MatroidDC -> [GroundPoint] -> [GroundPoint]
closureOf m = mClosure m . canonicalSort

isIndependent :: MatroidDC -> [GroundPoint] -> Bool
isIndependent m = mIndependent m . canonicalSort

basisOf :: MatroidDC -> [GroundPoint] -> [GroundPoint]
basisOf m = basisOf' (mIndependent m) . canonicalSort

basisOf' :: ([GroundPoint] -> Bool) -> [GroundPoint] -> [GroundPoint]
basisOf' indep xs = go [] (canonicalSort xs)
  where
    go acc [] = canonicalSort acc
    go acc (y:ys)
      | indep (acc ++ [y]) = go (acc ++ [y]) ys
      | otherwise          = go acc ys

rankOf :: MatroidDC -> [GroundPoint] -> Int
rankOf m = mRank m . canonicalSort

isClosed :: MatroidDC -> [GroundPoint] -> Bool
isClosed m xs = canonicalSort xs == closureOf m xs

flatsOf :: MatroidDC -> [[GroundPoint]]
flatsOf m = map canonicalSort (filter (isClosed m) (subsets (mGround m)))

circuitsOf :: MatroidDC -> [[GroundPoint]]
circuitsOf m =
  let gs = filter (not . null) (subsets (mGround m))
      deps = filter (not . isIndependent m) gs
  in map canonicalSort $
       filter (\c -> all (isIndependent m) (properSubsets c)) deps

-- ============================================================================
-- DCOP-STYLE HELPERS
-- ============================================================================

variablesOf :: SymbolFamily -> [GroundPoint] -> [Variable]
variablesOf fam pts =
  let dom = familyDomain fam
  in zipWith mk [0..] pts
  where
    mk i gp = Variable (VariableId i) gp dom

-- A small constructive set of induced constraints:
--   * unary basis/tag preference
--   * binary collision penalty on same point-id residue
--   * binary coupling penalty on shared 7/56 signatures
inducedConstraints :: SymbolFamily -> [Variable] -> [GroundPoint] -> [Constraint]
inducedConstraints _fam vars _ground =
  unaryConstraints vars ++ binaryConstraints vars

unaryConstraints :: [Variable] -> [Constraint]
unaryConstraints vars =
  zipWith mk [0..] vars
  where
    mk i v = Constraint
      { cId = ConstraintId i
      , cScope = [varId v]
      , cEvaluator = \ctx ->
          case lookupAssignment ctx (varId v) of
            Nothing -> 0
            Just (DomainValue d) ->
              let GroundPoint (Point (PointId pid) basis tag) = varPoint v
                  score = fromIntegral ((pid + fromIntegral basis + fromIntegral tag) `mod` 17)
              in abs (d - score)
      }

binaryConstraints :: [Variable] -> [Constraint]
binaryConstraints vars =
  [ Constraint
      { cId = ConstraintId (1000 + i * 256 + j)
      , cScope = [varId vi, varId vj]
      , cEvaluator = \ctx ->
          case (lookupAssignment ctx (varId vi), lookupAssignment ctx (varId vj)) of
            (Just (DomainValue a), Just (DomainValue b)) ->
              let GroundPoint (Point (PointId pi) bi ti) = varPoint vi
                  GroundPoint (Point (PointId pj) bj tj) = varPoint vj
                  sameResidue = (pi `mod` 257) == (pj `mod` 257)
                  same7 = bi == bj
                  coupled56 = ((pi `xor` pj) `mod` 56) == 0
                  clash = if a == b then 1 else 0
                  penalty =
                    (if sameResidue then 3 else 0) +
                    (if same7 then 2 else 0) +
                    (if coupled56 then 2 else 0) +
                    clash +
                    (if (ti + tj) `mod` 7 == 0 then 1 else 0)
              in penalty
            _ -> 0
      }
  | (i, vi) <- zip [0..] vars
  , (j, vj) <- zip [0..] vars
  , i < j
  ]

optimizeContextCostUpperBound :: MatroidDC -> Context -> Int
optimizeContextCostUpperBound m ctx =
  abs (evalObjective (mObjective m) (mConstraints m) ctx)

-- ============================================================================
-- ORIENTED / WEIGHTED HOOKS
-- ============================================================================

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

weightRankUpperBound :: MatroidDC -> [(GroundPoint, Int)] -> Int
weightRankUpperBound m wx =
  let pts = map fst wx
      r   = rankOf m pts
      ws  = map snd wx
  in r * (if null ws then 0 else maximum ws)

-- ============================================================================
-- UTILITIES
-- ============================================================================

subsets :: [a] -> [[a]]
subsets = subsequences

properSubsets :: [a] -> [[a]]
properSubsets xs = filter ((< length xs) . length) (subsequences xs)
