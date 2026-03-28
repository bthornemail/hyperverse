-- | Composition.hs
--
-- Canonical frame composition for the Atomic Kernel control/projective stack.
--
-- This module normalizes the corrected model discussed in the conversation:
--
--   * canonical temporal core = 7-step incidence cycle × 8-step codec cycle = 56
--   * codec phase factors as 4 structural modes × 2 code planes
--   * a frame is built from an 8-bit header plus a 32-bit addressed bitboard body
--   * validation is deconstructive: unpack -> recompute expected phase -> compare
--   * frame succession is lawful only if it advances one deterministic step
--
-- The implementation is self-contained (base only) and does not assume external
-- packages or mutable state. It is intended as a strict algorithmic reference.

module Composition
  ( -- * Core types
    Control(..)
  , Plane(..)
  , Header8(..)
  , Phase56(..)
  , Bitboard32(..)
  , Frame32(..)
  , FrameNode(..)
  , ValidationError(..)

    -- * Kernel / chirality
  , maskW
  , rotl
  , rotr
  , delta
  , kernelBit
  , replay

    -- * Phase decomposition
  , phase56
  , basisIndex7
  , modeOfCodec
  , planeOfCodec

    -- * Fano / incidence
  , fanoLines
  , activeLine
  , lineForBasisAndPlane

    -- * Header helpers
  , controlToNibble
  , nibbleToControl
  , planeBit
  , packHeader8
  , unpackHeader8

    -- * Bitboard helpers
  , bitAt
  , setBitAt
  , clearBitAt
  , popCount32

    -- * Frame construction / deconstruction
  , composeFrame32
  , deconstructFrame32
  , expectedFrame32
  , validateFrame32
  , nextFrame32
  , lawfulSuccessor

    -- * Linked frame chain helpers
  , mkNode
  , linkNodes
  , validateChain

    -- * Demo
  , demoFrames
  ) where

import Data.Bits
import Data.Char (toLower)
import Data.List (foldl')
import Data.Word (Word8, Word32, Word64)
import Numeric (showHex)

-- ============================================================================
-- TIER 0 — CORE CONTROL / PLANE TYPES
-- ============================================================================

data Control = ESC | FS | GS | RS | US
  deriving (Eq, Ord, Enum, Bounded, Show)

data Plane = C0 | C1
  deriving (Eq, Ord, Enum, Bounded, Show)

-- | Canonical compact header view.
--
-- The header is represented both structurally and as a packed octet.
-- High nibble = control mode (1..5), bit 3 of low nibble = plane,
-- low three bits = basis index (0..6).
--
-- Layout:
--
--   7 6 5 4   3   2 1 0
--   --------  --- ------
--   control   pl  basis
--
-- Example: FS/C1/basis=3 => 0x2B
--
data Header8 = Header8
  { hControl :: !Control
  , hPlane   :: !Plane
  , hBasis   :: !Word8    -- 0..6
  } deriving (Eq, Show)

-- | Canonical 56-state phase decomposition.
--
--   tick mod 56 determines everything below.
--   codec = tick mod 8
--   fano  = tick mod 7
--
-- We expose the factored interpretation of codec:
--
--   codec = 4 structural modes × 2 code planes
--
data Phase56 = Phase56
  { pTick56  :: !Int      -- 0..55
  , pFano7   :: !Int      -- 0..6
  , pCodec8  :: !Int      -- 0..7
  , pMode4   :: !Int      -- 0..3
  , pPlane2  :: !Plane    -- C0 | C1
  } deriving (Eq, Show)

newtype Bitboard32 = Bitboard32 { unBitboard32 :: Word32 }
  deriving (Eq, Ord)

instance Show Bitboard32 where
  show (Bitboard32 w) = "0x" ++ pad8 (map toLower (showHex w ""))
    where
      pad8 s = replicate (8 - length s) '0' ++ s

-- | One canonical frame: 8-bit header + 32-bit addressed bitboard body.
--
-- 'frAddr' is not a pointer in the mutable sense; it is the addressed body slot
-- for this frame.
--
data Frame32 = Frame32
  { frTick      :: !Int
  , frPhase     :: !Phase56
  , frHeader    :: !Header8
  , frHeaderRaw :: !Word8
  , frAddr      :: !Word32
  , frBits      :: !Bitboard32
  , frHash      :: !Word64
  } deriving (Eq, Show)

-- | Structural linked-frame node.
--
-- The link is lawful only if it obeys the deterministic successor law.
-- This is a pure structural linked list, not a mutable heap pointer.
--
data FrameNode = FrameNode
  { fnFrame :: !Frame32
  , fnNext  :: !(Maybe Frame32)
  } deriving (Eq, Show)

data ValidationError
  = InvalidTick Int
  | InvalidBasis Word8
  | InvalidPackedControlNibble Word8
  | HeaderRoundtripFailed Header8 Word8
  | PhaseMismatch Phase56 Phase56
  | HeaderMismatch Header8 Header8
  | AddressMismatch Word32 Word32
  | BitboardMismatch Bitboard32 Bitboard32
  | HashMismatch Word64 Word64
  | NotLawfulSuccessor Frame32 Frame32
  deriving (Eq, Show)

-- ============================================================================
-- TIER 1 — KERNEL TRANSITION / CHIRALITY
-- ============================================================================

type Width = Int
type Mask  = Word64

maskW :: Width -> Mask
maskW n = (1 `shiftL` n) - 1

rotl :: Mask -> Int -> Width -> Mask
rotl x k n = ((x `shiftL` k) .|. (x `shiftR` (n - k))) .&. maskW n

rotr :: Mask -> Int -> Width -> Mask
rotr x k n = ((x `shiftR` k) .|. (x `shiftL` (n - k))) .&. maskW n

-- | The canonical delta law.
delta :: Width -> Mask -> Mask -> Mask
delta n c x =
  (rotl x 1 n `xor` rotl x 3 n `xor` rotr x 2 n `xor` c) .&. maskW n

kernelBit :: Width -> Mask -> Mask -> Int
kernelBit n c state = fromIntegral (delta n c state .&. 1)

replay :: Width -> Mask -> Mask -> Int -> [Mask]
replay n c seed steps = take steps (iterate (delta n c) seed)

-- ============================================================================
-- TIER 2 — TEMPORAL / CODEC FACTORIZATION
-- ============================================================================

phase56 :: Int -> Either ValidationError Phase56
phase56 tick
  | tick < 0   = Left (InvalidTick tick)
  | otherwise  = Right $ Phase56
      { pTick56 = tick `mod` 56
      , pFano7  = tick `mod` 7
      , pCodec8 = tick `mod` 8
      , pMode4  = modeOfCodec (tick `mod` 8)
      , pPlane2 = planeOfCodec (tick `mod` 8)
      }

-- | Corrected factorization of codec phase.
--
-- We interpret the 8-step codec cycle as 4 structural modes × 2 planes.
-- Pairing convention:
--
--   0 -> (mode 0, C0)
--   1 -> (mode 0, C1)
--   2 -> (mode 1, C0)
--   3 -> (mode 1, C1)
--   4 -> (mode 2, C0)
--   5 -> (mode 2, C1)
--   6 -> (mode 3, C0)
--   7 -> (mode 3, C1)
--
modeOfCodec :: Int -> Int
modeOfCodec codec = (codec `mod` 8) `div` 2

planeOfCodec :: Int -> Plane
planeOfCodec codec = if odd (codec `mod` 8) then C1 else C0

planeBit :: Plane -> Word8
planeBit C0 = 0
planeBit C1 = 1

-- | Basis index is the 7-step incidence / clock basis.
basisIndex7 :: Phase56 -> Word8
basisIndex7 = fromIntegral . pFano7

-- ============================================================================
-- TIER 3 — FANO / INCIDENCE LAYER
-- ============================================================================

-- | Canonical cyclic Fano lines generated from {0,1,3}.
fanoLines :: [(Word8, Word8, Word8)]
fanoLines =
  [ (0,1,3)
  , (1,2,4)
  , (2,3,5)
  , (3,4,6)
  , (4,5,0)
  , (5,6,1)
  , (6,0,2)
  ]

activeLine :: Phase56 -> (Word8, Word8, Word8)
activeLine ph = fanoLines !! pFano7 ph

-- | For one basis point and one plane, deterministically choose one of the
-- three incident positions from the active Fano line.
--
-- C0 selects the first matching incidence; C1 selects the second matching
-- incidence when available, otherwise wraps to the first. This gives a stable
-- 7 × 2 = 14 incidence-plane surface without inventing an eighth step.
lineForBasisAndPlane :: Word8 -> Plane -> (Word8, Word8, Word8)
lineForBasisAndPlane basis plane =
  let ls = filter (contains basis) fanoLines
      ix = case plane of
             C0 -> 0
             C1 -> if length ls > 1 then 1 else 0
  in ls !! ix
  where
    contains x (a,b,c) = x == a || x == b || x == c

-- ============================================================================
-- TIER 4 — HEADER PACKING / UNPACKING
-- ============================================================================

controlToNibble :: Control -> Word8
controlToNibble ESC = 0x1
controlToNibble FS  = 0x2
controlToNibble GS  = 0x3
controlToNibble RS  = 0x4
controlToNibble US  = 0x5

nibbleToControl :: Word8 -> Either ValidationError Control
nibbleToControl 0x1 = Right ESC
nibbleToControl 0x2 = Right FS
nibbleToControl 0x3 = Right GS
nibbleToControl 0x4 = Right RS
nibbleToControl 0x5 = Right US
nibbleToControl n   = Left (InvalidPackedControlNibble n)

packHeader8 :: Header8 -> Either ValidationError Word8
packHeader8 h
  | hBasis h > 6 = Left (InvalidBasis (hBasis h))
  | otherwise    = Right $
      (controlToNibble (hControl h) `shiftL` 4)
      .|. (planeBit (hPlane h) `shiftL` 3)
      .|. (hBasis h .&. 0x07)

unpackHeader8 :: Word8 -> Either ValidationError Header8
unpackHeader8 raw = do
  ctl <- nibbleToControl ((raw `shiftR` 4) .&. 0x0F)
  let pl = if testBit raw 3 then C1 else C0
      bs = raw .&. 0x07
  if bs > 6
    then Left (InvalidBasis bs)
    else Right Header8 { hControl = ctl, hPlane = pl, hBasis = bs }

-- ============================================================================
-- TIER 5 — BITBOARD HELPERS
-- ============================================================================

bitAt :: Bitboard32 -> Int -> Bool
bitAt (Bitboard32 w) i = testBit w i

setBitAt :: Bitboard32 -> Int -> Bitboard32
setBitAt (Bitboard32 w) i = Bitboard32 (setBit w i)

clearBitAt :: Bitboard32 -> Int -> Bitboard32
clearBitAt (Bitboard32 w) i = Bitboard32 (clearBit w i)

popCount32 :: Bitboard32 -> Int
popCount32 (Bitboard32 w) = popCount w

-- | Render one active Fano line into a 32-bit bitboard.
--
-- Bits 0..6   = one-hot basis / incidence line membership
-- Bits 8..10  = active line triple (duplicated, for quick structural checks)
-- Bit  16     = plane C0/C1 flag
-- Bits 24..25 = structural mode (0..3)
-- Bit  31     = chirality
--
renderBitboard32 :: Phase56 -> Int -> Bitboard32
renderBitboard32 ph chirality =
  let (a,b,c) = lineForBasisAndPlane (basisIndex7 ph) (pPlane2 ph)
      base0   = 0 :: Word32
      withInc = foldl' setLine base0 [fromIntegral a, fromIntegral b, fromIntegral c]
      withDup = foldl' setLine withInc [8 + fromIntegral a, 8 + fromIntegral b, 8 + fromIntegral c]
      withPl  = if pPlane2 ph == C1 then setBit withDup 16 else withDup
      withMd0 = if testBit (fromIntegral (pMode4 ph) :: Word32) 0 then setBit withPl 24 else withPl
      withMd1 = if testBit (fromIntegral (pMode4 ph) :: Word32) 1 then setBit withMd0 25 else withMd0
      withCh  = if chirality == 1 then setBit withMd1 31 else withMd1
  in Bitboard32 withCh
  where
    setLine acc i = setBit acc i

-- ============================================================================
-- TIER 6 — FRAME COMPOSITION / DECONSTRUCTION
-- ============================================================================

-- | Structural mode to control mapping. We intentionally collapse 4 modes onto
-- the 5-symbol control family without inventing additional primitive controls.
-- Mode 0 is reserved for ESC boundary semantics.
controlOfMode :: Int -> Control
controlOfMode 0 = ESC
controlOfMode 1 = FS
controlOfMode 2 = GS
controlOfMode 3 = RS
controlOfMode _ = US

-- | Address law for one frame.
--
-- We use a deterministic 32-bit address slice:
--
--   high 16 = tick mod 56
--   next  8 = packed header
--   low   8 = line signature (sum of line points mod 256)
--
frameAddress32 :: Phase56 -> Header8 -> Word32
frameAddress32 ph h =
  let hdr = either (const 0) id (packHeader8 h)
      (a,b,c) = lineForBasisAndPlane (hBasis h) (hPlane h)
      sig = fromIntegral ((fromIntegral a + fromIntegral b + fromIntegral c) `mod` 256) :: Word32
  in  (fromIntegral (pTick56 ph) `shiftL` 16)
      .|. (fromIntegral hdr `shiftL` 8)
      .|. sig

-- | Small, deterministic non-cryptographic frame hash.
frameHash64 :: Word8 -> Word32 -> Bitboard32 -> Word64
frameHash64 hdr addr (Bitboard32 bits) =
  fnv1a64 [ fromIntegral hdr
          , fromIntegral ( addr              .&. 0xFF)
          , fromIntegral ((addr `shiftR` 8 ) .&. 0xFF)
          , fromIntegral ((addr `shiftR` 16) .&. 0xFF)
          , fromIntegral ((addr `shiftR` 24) .&. 0xFF)
          , fromIntegral ( bits              .&. 0xFF)
          , fromIntegral ((bits `shiftR` 8 ) .&. 0xFF)
          , fromIntegral ((bits `shiftR` 16) .&. 0xFF)
          , fromIntegral ((bits `shiftR` 24) .&. 0xFF)
          ]

fnv1a64 :: [Word8] -> Word64
fnv1a64 = foldl' step 14695981039346656037
  where
    prime = 1099511628211
    step h b = (h `xor` fromIntegral b) * prime

-- | Compose one frame from tick and current kernel state.
composeFrame32 :: Width -> Mask -> Mask -> Int -> Mask -> Either ValidationError Frame32
composeFrame32 n c _seed tick state = do
  ph <- phase56 tick
  let chir = kernelBit n c state
      hdr0 = Header8
        { hControl = controlOfMode (pMode4 ph)
        , hPlane   = pPlane2 ph
        , hBasis   = basisIndex7 ph
        }
  raw <- packHeader8 hdr0
  hdr1 <- unpackHeader8 raw
  let addr = frameAddress32 ph hdr1
      bits = renderBitboard32 ph chir
      hsh  = frameHash64 raw addr bits
  pure Frame32
    { frTick      = tick
    , frPhase     = ph
    , frHeader    = hdr1
    , frHeaderRaw = raw
    , frAddr      = addr
    , frBits      = bits
    , frHash      = hsh
    }

-- | Recompute what a frame must be, based solely on tick and state.
expectedFrame32 :: Width -> Mask -> Mask -> Int -> Mask -> Either ValidationError Frame32
expectedFrame32 = composeFrame32

-- | Deconstruct a frame into its structural components and verify header roundtrip.
deconstructFrame32 :: Frame32 -> Either ValidationError (Header8, Word32, Bitboard32)
deconstructFrame32 fr = do
  hdr <- unpackHeader8 (frHeaderRaw fr)
  raw' <- packHeader8 hdr
  if raw' /= frHeaderRaw fr
    then Left (HeaderRoundtripFailed hdr raw')
    else pure (hdr, frAddr fr, frBits fr)

validateFrame32 :: Width -> Mask -> Mask -> Mask -> Frame32 -> [ValidationError]
validateFrame32 n c seed state fr =
  case (deconstructFrame32 fr, expectedFrame32 n c seed (frTick fr) state) of
    (Left e, _) -> [e]
    (_, Left e) -> [e]
    (Right (hdr, addr, bits), Right ex) ->
      concat
        [ [ HeaderMismatch (frHeader ex) hdr | hdr /= frHeader ex ]
        , [ AddressMismatch (frAddr ex) addr | addr /= frAddr ex ]
        , [ BitboardMismatch (frBits ex) bits | bits /= frBits ex ]
        , [ PhaseMismatch (frPhase ex) (frPhase fr) | frPhase fr /= frPhase ex ]
        , [ HashMismatch (frHash ex) (frHash fr) | frHash fr /= frHash ex ]
        ]

nextFrame32 :: Width -> Mask -> Mask -> Int -> Mask -> Either ValidationError Frame32
nextFrame32 n c seed tick state = expectedFrame32 n c seed (tick + 1) (delta n c state)

lawfulSuccessor :: Width -> Mask -> Mask -> Mask -> Frame32 -> Frame32 -> Bool
lawfulSuccessor n c seed state a b =
  case nextFrame32 n c seed (frTick a) state of
    Left _   -> False
    Right ex -> b == ex

-- ============================================================================
-- TIER 7 — LINKED FRAME CHAIN HELPERS
-- ============================================================================

mkNode :: Frame32 -> FrameNode
mkNode fr = FrameNode fr Nothing

linkNodes :: Width -> Mask -> Mask -> Mask -> Frame32 -> Frame32 -> Either ValidationError FrameNode
linkNodes n c seed state a b
  | lawfulSuccessor n c seed state a b = Right (FrameNode a (Just b))
  | otherwise                          = Left (NotLawfulSuccessor a b)

validateChain :: Width -> Mask -> Mask -> Mask -> [Frame32] -> [ValidationError]
validateChain _ _ _ _ []  = []
validateChain _ _ _ _ [_] = []
validateChain n c seed state (a:b:rest) =
  let cur  = if lawfulSuccessor n c seed state a b
               then []
               else [NotLawfulSuccessor a b]
      st'  = delta n c state
  in cur ++ validateChain n c seed st' (b:rest)

-- ============================================================================
-- DEMO
-- ============================================================================

-- | Emit a small sequence of demo frames.
--
-- Example:
--
-- > demoFrames 16 0x1D1D 0x0001 4
--
demoFrames :: Width -> Mask -> Mask -> Int -> [Either ValidationError Frame32]
demoFrames n c seed count =
  let states = replay n c seed (max 1 count)
  in zipWith (composeFrame32 n c seed) [0..count-1] states

