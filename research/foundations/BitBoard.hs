-- | Projection.hs
--
-- Canonical frame projection law for the Atomic Kernel control/projective stack.
--
-- This module sits above:
--
--   * Composition.hs  — builds one lawful Frame32 from tick/state
--   * Lattice.hs      — defines the normative 27x27 / 60-slot placement table
--
-- It does NOT redefine kernel truth, lattice geometry, or escape semantics.
-- It defines only the deterministic projection of a composed frame into the
-- 60 canonical lattice slots and the exact inverse needed to validate that
-- projection by reconstruction.
--
-- Design choices locked here:
--
--   1. A frame is projected as a fixed 17-byte packet:
--        [ header8 | addr32 | bitboard32 | hash64 ]
--
--   2. Projection is nibble-based and bitwise:
--        17 bytes -> 34 nibbles -> 34 occupied lattice slots
--      leaving 26 canonical slots empty for this frame.
--
--   3. Slot ordering is lawful, not visual:
--        the start offset is derived from Phase56 and header fields.
--
--   4. Inversion is exact:
--        project -> extract -> rebuild bytes -> rebuild frame -> compare.
--
--   5. Aztec geometry remains geometry only:
--        this module chooses WHICH slot carries WHICH nibble;
--        Lattice.hs chooses WHERE each slot lives in the 27x27 grid.
--
-- The implementation uses base only and prefers bitwise operations everywhere.

module BitBoard
  ( -- * Types
    ProjectionError(..)
  , SlotState(..)
  , ProjectedCell(..)
  , ProjectionPacket(..)

    -- * Packet packing / unpacking
  , framePacketBytes
  , packetBytesToNibbles
  , nibblesToPacketBytes
  , rebuildFrameFromPacket

    -- * Slot addressing
  , slotCount
  , phaseOffset60
  , slotIndexFor
  , laneOfSlot
  , channelOfSlot

    -- * Projection
  , projectFrame
  , projectFrameToGrid
  , extractPacketFromCells
  , validateProjectedFrame

    -- * Rendering helpers
  , slotStateWord
  , packetOccupancyMask

    -- * Demo
  , demoProjection
  ) where

import Data.Bits
import Data.List (find, foldl', sortOn)
import Data.Word (Word8, Word32, Word64)

import Composition
  ( Control(..)
  , Plane(..)
  , Header8(..)
  , Phase56(..)
  , Bitboard32(..)
  , Frame32(..)
  , ValidationError(..)
  , phase56
  , packHeader8
  , unpackHeader8
  , expectedFrame32
  )

import AtomicKernel.Lattice
  ( GridPos
  , Lane
  , allCanonicalPositions
  , lookupPos
  )

-- ============================================================================
-- TYPES
-- ============================================================================

data ProjectionError
  = PacketSizeMismatch Int
  | NibbleCountMismatch Int
  | InvalidNibble Word8
  | InvalidSlotIndex Int
  | MissingProjectedSlot Int
  | GridLookupFailed Plane Lane
  | PacketHeaderMismatch Word8 Word8
  | PacketAddrMismatch Word32 Word32
  | PacketBitsMismatch Word32 Word32
  | PacketHashMismatch Word64 Word64
  | PacketRoundtripFailed
  | FrameRebuildFailed ValidationError
  | FrameProjectionMismatch Frame32 Frame32
  deriving (Eq, Show)

-- | One projected slot carries exactly one nibble or is empty.
-- Empty slots are explicit so occupancy can be validated visually and by code.
data SlotState
  = SlotEmpty
  | SlotNibble !Word8   -- 0x0 .. 0xF
  deriving (Eq, Show)

-- | One canonical lattice cell after projection.
-- 'pcSlot' is the lawful slot index 0..59 in canonical slot order.
-- 'pcPlane'/'pcLane'/'pcPos' are geometric witnesses from Lattice.hs.
data ProjectedCell = ProjectedCell
  { pcSlot  :: !Int
  , pcPlane :: !Plane
  , pcLane  :: !Lane
  , pcPos   :: !GridPos
  , pcState :: !SlotState
  } deriving (Eq, Show)

-- | The packet view is separated from Frame32 so projection never depends on
-- renderer assumptions. Packet bytes are the authoritative pre-geometry form.
data ProjectionPacket = ProjectionPacket
  { ppHeaderRaw :: !Word8
  , ppAddr32    :: !Word32
  , ppBits32    :: !Word32
  , ppHash64    :: !Word64
  } deriving (Eq, Show)

-- ============================================================================
-- CONSTANTS / LAYOUT
-- ============================================================================

slotCount :: Int
slotCount = 60

packetByteCount :: Int
packetByteCount = 17

packetNibbleCount :: Int
packetNibbleCount = packetByteCount * 2

-- | Canonical slot order: US lane1..15, RS lane1..15, GS lane1..15, FS lane1..15.
slotTable :: [(Int, Plane, Lane, GridPos)]
slotTable = zipWith mk [0..] allCanonicalPositions
  where
    mk ix (pl, ln, pos) = (ix, pl, ln, pos)

-- ============================================================================
-- PACKING / UNPACKING
-- ============================================================================

-- | Projectable packet bytes, exactly 17 bytes:
--
--   [0]     = packed header8
--   [1..4]  = addr32, big-endian
--   [5..8]  = bitboard32, big-endian
--   [9..16] = hash64, big-endian
--
framePacketBytes :: Frame32 -> [Word8]
framePacketBytes fr =
  [ frHeaderRaw fr ]
  ++ word32BE (frAddr fr)
  ++ word32BE (unBitboard32 (frBits fr))
  ++ word64BE (frHash fr)

word32BE :: Word32 -> [Word8]
word32BE w =
  [ fromIntegral ((w `shiftR` 24) .&. 0xFF)
  , fromIntegral ((w `shiftR` 16) .&. 0xFF)
  , fromIntegral ((w `shiftR`  8) .&. 0xFF)
  , fromIntegral ( w              .&. 0xFF)
  ]

word64BE :: Word64 -> [Word8]
word64BE w =
  [ fromIntegral ((w `shiftR` 56) .&. 0xFF)
  , fromIntegral ((w `shiftR` 48) .&. 0xFF)
  , fromIntegral ((w `shiftR` 40) .&. 0xFF)
  , fromIntegral ((w `shiftR` 32) .&. 0xFF)
  , fromIntegral ((w `shiftR` 24) .&. 0xFF)
  , fromIntegral ((w `shiftR` 16) .&. 0xFF)
  , fromIntegral ((w `shiftR`  8) .&. 0xFF)
  , fromIntegral ( w              .&. 0xFF)
  ]

bytesToWord32BE :: [Word8] -> Either ProjectionError Word32
bytesToWord32BE [a,b,c,d] =
  Right $  (fromIntegral a `shiftL` 24)
       .|. (fromIntegral b `shiftL` 16)
       .|. (fromIntegral c `shiftL`  8)
       .|.  fromIntegral d
bytesToWord32BE xs = Left (PacketSizeMismatch (length xs))

bytesToWord64BE :: [Word8] -> Either ProjectionError Word64
bytesToWord64BE [a,b,c,d,e,f,g,h] =
  Right $  (fromIntegral a `shiftL` 56)
       .|. (fromIntegral b `shiftL` 48)
       .|. (fromIntegral c `shiftL` 40)
       .|. (fromIntegral d `shiftL` 32)
       .|. (fromIntegral e `shiftL` 24)
       .|. (fromIntegral f `shiftL` 16)
       .|. (fromIntegral g `shiftL`  8)
       .|.  fromIntegral h
bytesToWord64BE xs = Left (PacketSizeMismatch (length xs))

-- | Split each byte into two nibbles, high then low.
packetBytesToNibbles :: [Word8] -> Either ProjectionError [Word8]
packetBytesToNibbles bs
  | length bs /= packetByteCount = Left (PacketSizeMismatch (length bs))
  | otherwise = Right $ concatMap splitByte bs
  where
    splitByte b = [ (b `shiftR` 4) .&. 0x0F, b .&. 0x0F ]

-- | Reassemble bytes from a 34-nibble packet.
nibblesToPacketBytes :: [Word8] -> Either ProjectionError [Word8]
nibblesToPacketBytes ns
  | length ns /= packetNibbleCount = Left (NibbleCountMismatch (length ns))
  | any (> 0x0F) ns                = Left (InvalidNibble (head (filter (> 0x0F) ns)))
  | otherwise                      = Right (go ns)
  where
    go []         = []
    go (hi:lo:xs) = ((hi `shiftL` 4) .|. lo) : go xs
    go _          = [] -- impossible due to exact length guard

packetFromBytes :: [Word8] -> Either ProjectionError ProjectionPacket
packetFromBytes bs
  | length bs /= packetByteCount = Left (PacketSizeMismatch (length bs))
  | otherwise = do
      addr <- bytesToWord32BE (take 4 (drop 1 bs))
      bits <- bytesToWord32BE (take 4 (drop 5 bs))
      hsh  <- bytesToWord64BE (take 8 (drop 9 bs))
      pure ProjectionPacket
        { ppHeaderRaw = head bs
        , ppAddr32    = addr
        , ppBits32    = bits
        , ppHash64    = hsh
        }

-- | Rebuild a Frame32 from projected packet bytes, using the original tick/phase
-- from the packet's owning projection context.
rebuildFrameFromPacket
  :: Int                 -- ^ tick
  -> [Word8]             -- ^ packet bytes
  -> Either ProjectionError Frame32
rebuildFrameFromPacket tick bs = do
  pkt <- packetFromBytes bs
  ph  <- either (Left . FrameRebuildFailed) Right (phase56 tick)
  hdr <- either (Left . FrameRebuildFailed) Right (unpackHeader8 (ppHeaderRaw pkt))
  pure Frame32
    { frTick      = tick
    , frPhase     = ph
    , frHeader    = hdr
    , frHeaderRaw = ppHeaderRaw pkt
    , frAddr      = ppAddr32 pkt
    , frBits      = Bitboard32 (ppBits32 pkt)
    , frHash      = ppHash64 pkt
    }

-- ============================================================================
-- SLOT ADDRESSING
-- ============================================================================

-- | Corrected phase factorization gives a lawful 60-slot start offset:
--
--   basis  = 0..6
--   codec  = 0..7
--
-- We use:  offset = 8*basis + codec  ∈ [0..55]
--
-- This preserves the 7×8=56 phase law and keeps the 4 remaining slot indices
-- as inert slack within the 60-slot lattice, rather than inventing false time.
phaseOffset60 :: Phase56 -> Int
phaseOffset60 ph = (8 * pFano7 ph + pCodec8 ph) `mod` slotCount

-- | Slot index for nibble ordinal i.
slotIndexFor :: Phase56 -> Int -> Int
slotIndexFor ph i = (phaseOffset60 ph + i) `mod` slotCount

laneOfSlot :: Int -> Either ProjectionError Lane
laneOfSlot ix =
  case find (\(j,_,_,_) -> j == ix) slotTable of
    Just (_,_,ln,_) -> Right ln
    Nothing         -> Left (InvalidSlotIndex ix)

channelOfSlot :: Int -> Either ProjectionError Plane
channelOfSlot ix =
  case find (\(j,_,_,_) -> j == ix) slotTable of
    Just (_,pl,_,_) -> Right pl
    Nothing         -> Left (InvalidSlotIndex ix)

posOfSlot :: Int -> Either ProjectionError GridPos
posOfSlot ix =
  case find (\(j,_,_,_) -> j == ix) slotTable of
    Just (_,_,_,pos) -> Right pos
    Nothing          -> Left (InvalidSlotIndex ix)

-- ============================================================================
-- PROJECTION
-- ============================================================================

-- | Project a frame into all 60 canonical slots.
-- 34 slots carry nibbles, the remaining 26 are explicit empties.
projectFrame :: Frame32 -> Either ProjectionError [ProjectedCell]
projectFrame fr = do
  nibbles <- packetBytesToNibbles (framePacketBytes fr)
  let filled = [ (slotIndexFor (frPhase fr) i, SlotNibble nib)
               | (i, nib) <- zip [0..] nibbles
               ]
      stateAt ix = maybe SlotEmpty id (lookup ix filled)
  mapM (mkCell stateAt) [0..slotCount-1]
  where
    mkCell stateAt ix = do
      pl  <- channelOfSlot ix
      ln  <- laneOfSlot ix
      pos <- posOfSlot ix
      pure ProjectedCell
        { pcSlot  = ix
        , pcPlane = pl
        , pcLane  = ln
        , pcPos   = pos
        , pcState = stateAt ix
        }

-- | Same projection, but reduced to the occupied grid coordinates only.
projectFrameToGrid :: Frame32 -> Either ProjectionError [(GridPos, SlotState)]
projectFrameToGrid fr = do
  cells <- projectFrame fr
  pure [ (pcPos c, pcState c) | c <- cells ]

-- | Extract packet bytes from a projected cell set, using the frame's lawful
-- phase offset to recover nibble order.
extractPacketFromCells :: Int -> [ProjectedCell] -> Either ProjectionError [Word8]
extractPacketFromCells tick cells = do
  ph <- either (Left . FrameRebuildFailed) Right (phase56 tick)
  let need ix =
        case find (\c -> pcSlot c == slotIndexFor ph ix) cells of
          Nothing -> Left (MissingProjectedSlot (slotIndexFor ph ix))
          Just c  -> case pcState c of
                       SlotNibble n -> Right n
                       SlotEmpty    -> Left (MissingProjectedSlot (slotIndexFor ph ix))
  ns <- mapM need [0..packetNibbleCount-1]
  nibblesToPacketBytes ns

-- | Validate a projected frame by full inverse reconstruction.
validateProjectedFrame :: Frame32 -> [ProjectedCell] -> Either ProjectionError ()
validateProjectedFrame fr cells = do
  bs      <- extractPacketFromCells (frTick fr) cells
  rebuilt <- rebuildFrameFromPacket (frTick fr) bs

  -- packet-field equality first, then full frame equality
  let originalBytes = framePacketBytes fr
  if bs /= originalBytes
    then Left PacketRoundtripFailed
    else pure ()

  if frHeaderRaw rebuilt /= frHeaderRaw fr
    then Left (PacketHeaderMismatch (frHeaderRaw fr) (frHeaderRaw rebuilt))
    else pure ()

  if frAddr rebuilt /= frAddr fr
    then Left (PacketAddrMismatch (frAddr fr) (frAddr rebuilt))
    else pure ()

  if unBitboard32 (frBits rebuilt) /= unBitboard32 (frBits fr)
    then Left (PacketBitsMismatch (unBitboard32 (frBits fr)) (unBitboard32 (frBits rebuilt)))
    else pure ()

  if frHash rebuilt /= frHash fr
    then Left (PacketHashMismatch (frHash fr) (frHash rebuilt))
    else pure ()

  if rebuilt /= fr
    then Left (FrameProjectionMismatch fr rebuilt)
    else pure ()

-- ============================================================================
-- RENDERING / VALIDATION HELPERS
-- ============================================================================

-- | Compact 5-bit slot state word for human/debug rendering.
--
--   bit4 = occupied
--   bit3..0 = nibble value (or 0 for empty)
slotStateWord :: SlotState -> Word8
slotStateWord SlotEmpty      = 0x00
slotStateWord (SlotNibble n) = 0x10 .|. (n .&. 0x0F)

-- | 60-bit occupancy mask, packed into a Word64.
-- Bit i = 1 iff slot i is occupied.
packetOccupancyMask :: [ProjectedCell] -> Word64
packetOccupancyMask = foldl' step 0
  where
    step acc c = case pcState c of
      SlotEmpty    -> acc
      SlotNibble _ -> setBit acc (pcSlot c)

-- ============================================================================
-- DEMO
-- ============================================================================

-- | Emit cells and validate them immediately.
demoProjection :: Frame32 -> Either ProjectionError ([ProjectedCell], Word64)
demoProjection fr = do
  cells <- projectFrame fr
  validateProjectedFrame fr cells
  pure (cells, packetOccupancyMask cells)
