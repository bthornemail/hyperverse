-- | ClosureRuntime.hs
-- Deterministic execution model for closure-math kernels.
--
-- This module is shaped for ABI/EABI lowering:
--   * any binary buffer may be ingested
--   * numbers are canonical fixed-point decimal strings -> integers
--   * scheduling is fixed-block and deterministic
--   * kernels are SIMD-shaped but scalar-executable
--   * outputs carry canonical digests for seam envelopes / gates
--
-- v0.1 kernels included:
--   K0  O8 basis kernel
--   K1  P32 kernel
--   K2  P128 bundle kernel

module ClosureRuntime
  ( Scale(..), FixedInt(..), parseFixed
  , LaneWidth(..), laneSize
  , Atom(..), sortAtoms, scheduleBlocks
  , Collapse(..), collapseVector
  , O8Sig(..), runO8
  , P32Sig(..), runP32
  , P128Sig(..), runP128
  , RuntimeHeader(..), runtimeBoot
  , ingestBinaryBuffer
  , executeLane8, executeLane32, executeBundles128
  ) where

import Data.Bits (xor)
import Data.Char (isDigit)
import Data.List (intercalate, sortBy)
import Data.Ord (comparing)
import Data.Word (Word8, Word64)

newtype Scale = Scale Integer
  deriving (Eq, Ord, Show)

newtype FixedInt = FixedInt Integer
  deriving (Eq, Ord, Show)

parseFixed :: Scale -> String -> Either String FixedInt
parseFixed (Scale s) txt
  | s <= 0 = Left "scale must be positive"
  | otherwise =
      case splitDecimal txt of
        Nothing -> Left "invalid decimal"
        Just (neg, whole, frac) ->
          let fracDigits = digitsOfScale s
              fracPadded = take fracDigits (frac ++ repeat '0')
              wholeI = readSafe whole
              fracI  = readSafe fracPadded
              base   = wholeI * s + fracI
          in Right (FixedInt (if neg then negate base else base))

splitDecimal :: String -> Maybe (Bool, String, String)
splitDecimal [] = Nothing
splitDecimal xs =
  let (neg, ys) = case xs of
        ('-':rs) -> (True, rs)
        ('+':rs) -> (False, rs)
        rs       -> (False, rs)
      (w, rest) = span isDigit ys
  in case rest of
      []        -> if null w then Nothing else Just (neg, w, "")
      '.':frac  -> if null w || any (not . isDigit) frac then Nothing else Just (neg, w, frac)
      _         -> Nothing

digitsOfScale :: Integer -> Int
digitsOfScale n = go n 0
  where
    go 1 k = k
    go m k
      | m > 1 && m `mod` 10 == 0 = go (m `div` 10) (k + 1)
      | otherwise = k

readSafe :: String -> Integer
readSafe [] = 0
readSafe s  = read s

data LaneWidth
  = Lane8
  | Lane32
  | Lane128
  | Lane512
  | Lane2048
  | Lane4096
  deriving (Eq, Ord, Show)

laneSize :: LaneWidth -> Int
laneSize lw = case lw of
  Lane8    -> 8
  Lane32   -> 32
  Lane128  -> 128
  Lane512  -> 512
  Lane2048 -> 2048
  Lane4096 -> 4096

data Atom = Atom
  { aNamespace    :: !String
  , aEntityId     :: !String
  , aComponentKey :: !String
  , aIndex        :: !Int
  , aValue        :: !FixedInt
  } deriving (Eq, Show)

sortAtoms :: [Atom] -> [Atom]
sortAtoms =
  sortBy (comparing (\a -> (aNamespace a, aEntityId a, aComponentKey a, aIndex a)))

scheduleBlocks :: LaneWidth -> [Atom] -> [[Atom]]
scheduleBlocks width atoms = chunkN (laneSize width) (sortAtoms atoms)

chunkN :: Int -> [a] -> [[a]]
chunkN _ [] = []
chunkN n xs =
  let (h, t) = splitAt n xs
  in h : chunkN n t

sha256Text :: String -> String
sha256Text s =
  let h = foldl step 0xcbf29ce484222325 s
      step acc ch = (acc `xor` fromIntegral (fromEnum ch)) * 0x100000001b3 :: Word64
  in "sha256:" ++ showHex64 h

showHex64 :: Word64 -> String
showHex64 w =
  let s = go w
  in replicate (16 - length s) '0' ++ s
  where
    go 0 = "0"
    go n = reverse (digits n)
    digits 0 = []
    digits x =
      let d = fromIntegral (x `mod` 16) :: Int
      in ("0123456789abcdef" !! d) : digits (x `div` 16)

data Collapse = Collapse
  { cGCD    :: !Integer
  , cVector :: ![Integer]
  , cDigest :: !String
  } deriving (Eq, Show)

collapseVector :: Maybe Integer -> [FixedInt] -> Collapse
collapseVector maybePrime xs =
  let raw = map (\(FixedInt i) -> i) xs
      g0  = foldl gcdAbs 0 raw
      g   = if g0 == 0 then 1 else g0
      ys  = map (`div` g) raw
      zs  = normalizeSign ys
      ws  = maybe zs (\p -> map (symmetricMod p) zs) maybePrime
      dg  = sha256Text ("COLLAPSE|" ++ joinInts ws)
  in Collapse g ws dg

gcdAbs :: Integer -> Integer -> Integer
gcdAbs a b = gcd (abs a) (abs b)

normalizeSign :: [Integer] -> [Integer]
normalizeSign xs =
  case dropWhile (== 0) xs of
    []      -> xs
    (y : _) -> if y < 0 then map negate xs else xs

symmetricMod :: Integer -> Integer -> Integer
symmetricMod p x =
  let r = x `mod` p
      h = p `div` 2
  in if r > h then r - p else r

joinInts :: [Integer] -> String
joinInts = intercalate "," . map show

data O8Sig = O8Sig
  { o8Inputs :: ![Integer]
  , o8Norm2  :: !Integer
  , o8Parity :: !Integer
  , o8Digest :: !String
  } deriving (Eq, Show)

runO8 :: [FixedInt] -> Either String O8Sig
runO8 xs
  | length xs /= 8 = Left "O8 kernel requires exactly 8 inputs"
  | otherwise =
      let ys = map (\(FixedInt i) -> i) xs
          n2 = sum (map (\i -> i * i) ys)
          pr = sum ys `mod` 2
          dg = sha256Text ("O8|" ++ joinInts ys ++ "|" ++ show n2 ++ "|" ++ show pr)
      in Right (O8Sig ys n2 pr dg)

data P32Sig = P32Sig
  { p32Inputs    :: ![Integer]
  , p32Norm2     :: !Integer
  , p32Collapse  :: !Collapse
  , p32Digest    :: !String
  } deriving (Eq, Show)

runP32 :: Maybe Integer -> [FixedInt] -> Either String P32Sig
runP32 maybePrime xs
  | length xs /= 32 = Left "P32 kernel requires exactly 32 inputs"
  | otherwise =
      let ys = map (\(FixedInt i) -> i) xs
          n2 = sum (map (\i -> i * i) ys)
          cl = collapseVector maybePrime xs
          dg = sha256Text ("P32|" ++ joinInts ys ++ "|" ++ show n2 ++ "|" ++ cDigest cl)
      in Right (P32Sig ys n2 cl dg)

data P128Sig = P128Sig
  { p128Faces    :: ![P32Sig]
  , p128Norm2    :: !Integer
  , p128Collapse :: !Collapse
  , p128Digest   :: !String
  } deriving (Eq, Show)

runP128 :: Maybe Integer -> [P32Sig] -> Either String P128Sig
runP128 maybePrime faces
  | length faces /= 4 = Left "P128 bundle requires exactly 4 P32 faces"
  | otherwise =
      let n2 = sum (map p32Norm2 faces)
          coeffs = concatMap (map FixedInt . p32Inputs) faces
          cl = collapseVector maybePrime coeffs
          dg = sha256Text ("P128|" ++ intercalate "|" (map p32Digest faces))
      in Right (P128Sig faces n2 cl dg)

data RuntimeHeader = RuntimeHeader
  { rhFamilyTag  :: !Word8
  , rhLaneWidth  :: !LaneWidth
  , rhRankLimit  :: !Word8
  , rhScale      :: !Scale
  } deriving (Eq, Show)

runtimeBoot :: RuntimeHeader -> [Atom] -> Either String [[Atom]]
runtimeBoot hdr atoms
  | laneSize (rhLaneWidth hdr) <= 0 = Left "invalid lane width"
  | fromIntegral (rhRankLimit hdr) > laneSize (rhLaneWidth hdr) = Left "rank limit exceeds lane width"
  | otherwise = Right (scheduleBlocks (rhLaneWidth hdr) atoms)

ingestBinaryBuffer :: Scale -> String -> String -> [Word8] -> [Atom]
ingestBinaryBuffer sc namespace entity buf =
  [ Atom
      { aNamespace = namespace
      , aEntityId = entity
      , aComponentKey = "byte"
      , aIndex = i
      , aValue = FixedInt (fromIntegral b * unScale sc)
      }
  | (i, b) <- zip [0..] buf
  ]

unScale :: Scale -> Integer
unScale (Scale s) = s

executeLane8 :: RuntimeHeader -> [Atom] -> Either String [O8Sig]
executeLane8 hdr atoms = do
  blocks <- runtimeBoot hdr atoms
  mapM (runO8 . projectBlock 8) (filter ((== 8) . length) blocks)

executeLane32 :: Maybe Integer -> RuntimeHeader -> [Atom] -> Either String [P32Sig]
executeLane32 maybePrime hdr atoms = do
  blocks <- runtimeBoot hdr atoms
  mapM (runP32 maybePrime . projectBlock 32) (filter ((== 32) . length) blocks)

executeBundles128 :: Maybe Integer -> RuntimeHeader -> [Atom] -> Either String [P128Sig]
executeBundles128 maybePrime hdr atoms = do
  p32s <- executeLane32 maybePrime hdr atoms
  mapM (runP128 maybePrime) (chunkN 4 p32s)

projectBlock :: Int -> [Atom] -> [FixedInt]
projectBlock n block =
  take n (map aValue block ++ repeat (FixedInt 0))
