-- | Views_v1.hs
-- Pure renderers for Frame_v1.
--
-- This is deliberately projection-only:
--   Frame -> SVG / XML / Aztec / animation HTML
--
-- No authority lives here. These are local views.

module Views_v1
  ( frameToSVG
  , frameToXML
  , frameToAztec
  , renderFrame
  , renderAnimation
  ) where

import Data.List (intercalate)
import Frame_v1
import Projection_v1 (Block)

-- ============================================================================
-- ALGORITHM 1: SVG OUTPUT
-- ============================================================================

frameToSVG :: Frame -> Int -> Int -> String
frameToSVG (Frame blocks pointGroups _ _) w h =
  let header =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
        "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
        "width=\"" ++ show w ++ "\" height=\"" ++ show h ++ "\" viewBox=\"0 0 " ++ show w ++ " " ++ show h ++ "\">\n"
      cx = fromIntegral w / 2
      cy = fromIntegral h / 2
      scale = min (fromIntegral w) (fromIntegral h) / 3
      circles = concatMap (pointToCircle cx cy scale) (concat pointGroups)
      linesSvg = concatMap (blockToLines cx cy scale) (zip pointGroups blocks)
      footer = "</svg>\n"
  in header ++ linesSvg ++ circles ++ footer

pointToCircle :: Double -> Double -> Double -> (Double, Double, Double) -> String
pointToCircle cx cy s (x,y,_) =
  let px = cx + x * s
      py = cy + y * s
  in "  <circle cx=\"" ++ show px ++ "\" cy=\"" ++ show py ++ "\" r=\"3\" fill=\"black\"/>\n"

blockToLines :: Double -> Double -> Double -> ([(Double, Double, Double)], Block) -> String
blockToLines cx cy s (pts, _block) =
  let n = length pts
      pairs =
        if n < 2 then []
        else [ (pts !! i, pts !! ((i + 1) `mod` n)) | i <- [0..n-1] ]
  in concatMap draw pairs
  where
    draw ((x1,y1,_), (x2,y2,_)) =
      let px1 = cx + x1 * s
          py1 = cy + y1 * s
          px2 = cx + x2 * s
          py2 = cy + y2 * s
      in "  <line x1=\"" ++ show px1 ++ "\" y1=\"" ++ show py1 ++ "\" " ++
         "x2=\"" ++ show px2 ++ "\" y2=\"" ++ show py2 ++ "\" " ++
         "stroke=\"black\" stroke-width=\"1\"/>\n"

-- ============================================================================
-- ALGORITHM 2: XML OUTPUT
-- ============================================================================

frameToXML :: Frame -> String
frameToXML (Frame blocks pointGroups schlafli betti) =
  let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<configuration>\n"
      body = concatMap blockToXML (zip4 blocks pointGroups schlafli betti)
      footer = "</configuration>\n"
  in header ++ body ++ footer

zip4 :: [a] -> [b] -> [c] -> [d] -> [(a,b,c,d)]
zip4 (a:as) (b:bs) (c:cs) (d:ds) = (a,b,c,d) : zip4 as bs cs ds
zip4 _ _ _ _ = []

blockToXML :: (Block, [(Double, Double, Double)], String, (Int,Int,Int,Int)) -> String
blockToXML (block, pts, s, (b0,b1,b2,b3)) =
  "  <block>\n" ++
  "    <schlafli>" ++ s ++ "</schlafli>\n" ++
  "    <betti>" ++ intercalate "," (map show [b0,b1,b2,b3]) ++ "</betti>\n" ++
  "    <points>\n" ++ concatMap pointToXML pts ++ "    </points>\n" ++
  "    <patterns>\n" ++ concatMap patternToXML block ++ "    </patterns>\n" ++
  "  </block>\n"

pointToXML :: (Double, Double, Double) -> String
pointToXML (x,y,z) =
  "      <point x=\"" ++ show x ++ "\" y=\"" ++ show y ++ "\" z=\"" ++ show z ++ "\"/>\n"

patternToXML :: [Int] -> String
patternToXML dots =
  "      <pattern dots=\"" ++ intercalate "," (map show dots) ++ "\"/>\n"

-- ============================================================================
-- ALGORITHM 3: AZTEC-LIKE GRID OUTPUT
-- ============================================================================

frameToAztec :: Frame -> Int -> [String]
frameToAztec (Frame blocks pointGroups schlafli _) size =
  let safe = max 1 size
      emptyGrid = replicate safe (replicate safe 0)
      placed = foldl placeBlock emptyGrid (zip3 blocks pointGroups schlafli)
  in [ concatMap cellToChar row | row <- placed ]

placeBlock :: [[Int]] -> (Block, [(Double, Double, Double)], String) -> [[Int]]
placeBlock grid (_block, pts, s) =
  foldl placePoint grid pts
  where
    n = length grid
    val = valueFromSchlafli s
    placePoint g (x,y,_) =
      let cx = clamp 0 (n - 1) (floor ((x + 1) * fromIntegral n / 2))
          cy = clamp 0 (n - 1) (floor ((y + 1) * fromIntegral n / 2))
      in setCell g cx cy val

clamp :: Ord a => a -> a -> a -> a
clamp lo hi x = max lo (min hi x)

setCell :: [[Int]] -> Int -> Int -> Int -> [[Int]]
setCell grid x y v =
  take x grid ++
  [ take y (grid !! x) ++ [v] ++ drop (y + 1) (grid !! x) ] ++
  drop (x + 1) grid

valueFromSchlafli :: String -> Int
valueFromSchlafli s =
  case s of
    "{3}"       -> 1
    "{3,3}"     -> 2
    "{3,3,3}"   -> 3
    "{3,4}"     -> 4
    "{4,3}"     -> 5
    "{3,5}"     -> 6
    "{5,3}"     -> 7
    "{3,3,3,4}" -> 8
    _           -> 0

cellToChar :: Int -> String
cellToChar 0 = " "
cellToChar 1 = "▀"
cellToChar 2 = "▄"
cellToChar 3 = "█"
cellToChar 4 = "▐"
cellToChar 5 = "▌"
cellToChar 6 = "▚"
cellToChar 7 = "▞"
cellToChar _ = "●"

-- ============================================================================
-- ALGORITHM 4: COMBINED OUTPUT
-- ============================================================================

renderFrame :: Frame -> String -> String
renderFrame frame fmt =
  case fmt of
    "svg"   -> frameToSVG frame 800 600
    "xml"   -> frameToXML frame
    "aztec" -> unlines (frameToAztec frame 27)
    _       -> "Unknown format"

-- ============================================================================
-- ALGORITHM 5: STREAMING OUTPUT
-- ============================================================================

renderAnimation :: [Frame] -> String -> Int -> String
renderAnimation frames fmt delay =
  case fmt of
    "svg" ->
      let payload = concatMap (\f -> frameToSVG f 800 600) frames
      in "<svg xmlns=\"http://www.w3.org/2000/svg\">\n" ++
         "<!-- delay_ms=" ++ show delay ++ " frames=" ++ show (length frames) ++ " -->\n" ++
         payload ++
         "</svg>\n"
    "html" ->
      let frameDivs = concat
            [ "<div class=\"frame\" id=\"frame-" ++ show i ++ "\" style=\"display:" ++ if i == 0 then "block" else "none" ++ ";\">\n"
              ++ frameToSVG f 800 600 ++
              "</div>\n"
            | (i, f) <- zip [0 :: Int ..] frames
            ]
      in "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"UTF-8\"/>\n" ++
         "<style>body{margin:0;background:#111}.frame{position:absolute;top:0;left:0;width:100%;height:100%;}</style>\n" ++
         "</head>\n<body>\n" ++
         frameDivs ++
         "<script>\n" ++
         "const frames = Array.from(document.querySelectorAll('.frame'));\n" ++
         "let i = 0;\n" ++
         "setInterval(() => {\n" ++
         "  frames.forEach((f, idx) => { f.style.display = idx === i ? 'block' : 'none'; });\n" ++
         "  i = (i + 1) % frames.length;\n" ++
         "}, " ++ show delay ++ ");\n" ++
         "</script>\n</body>\n</html>\n"
    _ -> "Unknown animation format"
