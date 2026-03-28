-- | Projection_v1.hs
-- Pure projection algorithms from block space to coordinate space.
--
-- A block is a list of Braille-derived patterns.
-- Each pattern is represented as a list of raised dot indices.
--
-- This module stays algorithmic:
--   block -> coordinates / inferred geometric tags
--
-- No rendering, no IO, no mutable state.

module Projection_v1
  ( Dot
  , Pattern
  , Block
  , Point2
  , Point3
  , Polyhedron(..)
  , projectToCircle
  , projectToGrid
  , projectToSphere
  , projectToPolyhedron
  , blockToSchlafli
  , blockToBetti
  ) where

import Data.List (nub)

type Dot = Int
type Pattern = [Dot]
type Block = [Pattern]

type Point2 a = (a, a)
type Point3 a = (a, a, a)

data Polyhedron
  = Tetrahedron
  | Cube
  | Octahedron
  | Dodecahedron
  deriving (Eq, Show)

-- ============================================================================
-- ALGORITHM 1: PROJECT BLOCK TO 2D COORDINATES
-- ============================================================================

projectToCircle :: Floating a => Block -> Int -> [Point2 a]
projectToCircle block totalPoints =
  let n = length block
      count = if totalPoints <= 0 then max 1 n else totalPoints
      angles = [ 2 * pi * fromIntegral i / fromIntegral count | i <- [0..n-1] ]
      radius = 1
  in [ (radius * cos angle, radius * sin angle) | angle <- angles ]

projectToGrid :: Block -> Int -> Int -> [(Int, Int)]
projectToGrid block rows cols =
  let n = length block
      safeCols = max 1 cols
      safeRows = max 1 rows
      positions = [ (i `div` safeCols `mod` safeRows, i `mod` safeCols) | i <- [0..n-1] ]
  in take n positions

-- ============================================================================
-- ALGORITHM 2: PROJECT BLOCK TO 3D SPHERE
-- ============================================================================

projectToSphere :: Floating a => Block -> a -> [Point3 a]
projectToSphere block radius =
  let n0 = length block
      n  = max 1 n0
      phi = pi * (3 - sqrt 5)  -- golden angle
      zs = [ -1 + 2 * fromIntegral i / fromIntegral n | i <- [0..n-1] ]
      mk i z =
        let rxy = sqrt (max 0 (1 - z*z))
            a = fromIntegral i * phi
        in ( radius * cos a * rxy
           , radius * sin a * rxy
           , radius * z
           )
  in zipWith mk [0..n-1] zs

-- ============================================================================
-- ALGORITHM 3: PROJECT BLOCK TO POLYHEDRON VERTICES
-- ============================================================================

projectToPolyhedron :: Floating a => Block -> Polyhedron -> [Point3 a]
projectToPolyhedron block poly =
  let n = length block
      phi = (1 + sqrt 5) / 2
      vertices = case poly of
        Tetrahedron ->
          [ ( 1,  1,  1)
          , ( 1, -1, -1)
          , (-1,  1, -1)
          , (-1, -1,  1)
          ]
        Cube ->
          [ ( 1,  1,  1), ( 1,  1, -1), ( 1, -1,  1), ( 1, -1, -1)
          , (-1,  1,  1), (-1,  1, -1), (-1, -1,  1), (-1, -1, -1)
          ]
        Octahedron ->
          [ ( 1,  0,  0), (-1,  0,  0), ( 0,  1,  0)
          , ( 0, -1,  0), ( 0,  0,  1), ( 0,  0, -1)
          ]
        Dodecahedron ->
          [ ( 1, 1, 1), ( 1, 1,-1), ( 1,-1, 1), ( 1,-1,-1)
          , (-1, 1, 1), (-1, 1,-1), (-1,-1, 1), (-1,-1,-1)
          , (0,  1/phi,  phi), (0,  1/phi, -phi), (0, -1/phi,  phi), (0, -1/phi, -phi)
          , ( 1/phi,  phi, 0), ( 1/phi, -phi, 0), (-1/phi,  phi, 0), (-1/phi, -phi, 0)
          , ( phi, 0,  1/phi), ( phi, 0, -1/phi), (-phi, 0,  1/phi), (-phi, 0, -1/phi)
          ]
  in take n (cycle vertices)

-- ============================================================================
-- ALGORITHM 4: PROJECT BLOCK TO SCHLÄFLI SYMBOL
-- ============================================================================

blockToSchlafli :: Block -> String
blockToSchlafli block =
  let n = length block
      dots = nub (concat block)
      has7 = 7 `elem` dots
      has8 = 8 `elem` dots
  in if has8 then "{3,3,3,4}"
     else if has7 then
       if n == 7 then "{3,3}"
       else if n == 21 then "{3,5}"
       else "{3,3,3}"
     else
       case n of
         3  -> "{3}"
         4  -> "{3,3}"
         6  -> "{3,4}"
         8  -> "{4,3}"
         12 -> "{5,3}"
         20 -> "{3,5}"
         _  -> "{}"

-- ============================================================================
-- ALGORITHM 5: PROJECT BLOCK TO BETTI NUMBERS
-- ============================================================================

blockToBetti :: Block -> (Int, Int, Int, Int)
blockToBetti block =
  let n = length block
      dots = nub (concat block)
      has7 = 7 `elem` dots
      has8 = 8 `elem` dots
  in if has8 then (1, 3, 3, 1)
     else if has7 then
       if n == 7 then (1, 0, 0, 0) else (1, 0, 0, 0)
     else case n of
       1 -> (1, 0, 0, 0)
       2 -> (1, 1, 0, 0)
       3 -> (1, 0, 1, 0)
       4 -> (1, 0, 0, 0)
       6 -> (1, 0, 0, 0)
       8 -> (1, 0, 0, 0)
       _ -> (1, 0, 0, 0)
