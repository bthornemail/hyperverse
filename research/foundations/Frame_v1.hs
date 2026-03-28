-- | Frame_v1.hs
-- Deterministic frame assembly and time-window logic.
--
-- This module keeps two related ideas separate:
--
-- 1. A geometric frame:
--      blocks + projected points + derived tags
--
-- 2. A time window over frames:
--      past / current / future
--
-- Frames are pure values. A window is just a deterministic cursor over them.

module Frame_v1
  ( Frame(..)
  , FrameWindow(..)
  , buildFrame
  , frameToMesh
  , frameToColors
  , frameToAnimation
  , rotateFrameY
  , initWindow
  , makeWindowAt
  , forward
  , backward
  , replaceCurrent
  , addFuture
  ) where

import Projection_v1

-- ============================================================================
-- GEOMETRIC FRAME
-- ============================================================================

data Frame = Frame
  { frameBlocks   :: [Block]
  , framePoints   :: [[Point3 Double]]
  , frameSchlafli :: [String]
  , frameBetti    :: [(Int, Int, Int, Int)]
  } deriving (Eq, Show)

buildFrame :: [Block] -> Frame
buildFrame blocks =
  let projected = map (`projectToSphere` 1.0) blocks
      schlafli  = map blockToSchlafli blocks
      betti     = map blockToBetti blocks
  in Frame blocks projected schlafli betti

frameToMesh :: Frame -> ([Double], [Int])
frameToMesh (Frame _ pointGroups _ _) =
  let allPoints = concat pointGroups
      vertices = concatMap (\(x, y, z) -> [x, y, z]) allPoints
      n = length allPoints
      faces = concat [ [i, i + 1, i + 2] | i <- [0,3..(n - 3)] , i + 2 < n ]
  in (vertices, faces)

frameToColors :: Frame -> [(Int, Int, Int)]
frameToColors (Frame _ _ _ betti) =
  [ case b of
      (1,0,0,0) -> (255,255,255)
      (1,1,0,0) -> (255,0,0)
      (1,0,1,0) -> (0,255,0)
      (1,3,3,1) -> (0,0,255)
      _         -> (128,128,128)
  | b <- betti
  ]

frameToAnimation :: Frame -> Int -> [Frame]
frameToAnimation frame steps =
  let safeSteps = max 1 steps
      angles = [ 2 * pi * fromIntegral i / fromIntegral safeSteps | i <- [0..safeSteps-1] ]
  in map (rotateFrameY frame) angles

rotateFrameY :: Frame -> Double -> Frame
rotateFrameY (Frame blocks pointGroups schlafli betti) angle =
  let rot (x,y,z) = (x * cos angle - z * sin angle, y, x * sin angle + z * cos angle)
      rotated = map (map rot) pointGroups
  in Frame blocks rotated schlafli betti

-- ============================================================================
-- FRAME WINDOW
-- ============================================================================

data FrameWindow = FrameWindow
  { pastFrames   :: [Frame]   -- oldest first
  , currentFrame :: Frame
  , futureFrames :: [Frame]   -- nearest future first
  } deriving (Eq, Show)

initWindow :: Frame -> FrameWindow
initWindow frame = FrameWindow [] frame []

makeWindowAt :: [Frame] -> Int -> Maybe FrameWindow
makeWindowAt frames i
  | null frames = Nothing
  | i < 0 || i >= length frames = Nothing
  | otherwise =
      let past   = take i frames
          curr   = frames !! i
          future = drop (i + 1) frames
      in Just (FrameWindow past curr future)

forward :: FrameWindow -> FrameWindow
forward (FrameWindow past curr (next:rest)) =
  FrameWindow (past ++ [curr]) next rest
forward w = w

backward :: FrameWindow -> FrameWindow
backward (FrameWindow past curr future) =
  case reverse past of
    [] -> FrameWindow past curr future
    (prev:olderRev) ->
      FrameWindow (reverse olderRev) prev (curr : future)

replaceCurrent :: Frame -> FrameWindow -> FrameWindow
replaceCurrent newFrame (FrameWindow past _ future) =
  FrameWindow past newFrame future

addFuture :: Frame -> FrameWindow -> FrameWindow
addFuture newFrame (FrameWindow past curr future) =
  FrameWindow past curr (future ++ [newFrame])
