-- | AtomicKernel.FanoWinner
--
-- Replaces positional sonar indexing with the Fano winner.
--
-- The key shift from Timing.hs:
--   BEFORE: position derived from tick mod 60 (physical slot index)
--   AFTER:  position derived from the Fano chirality winner at tick t
--
-- "Replacing the LED with the Fano winner" means:
--   The 240 positions are not addressed by physical index.
--   They are addressed by the output of chiralitySelect at each tick.
--   The winner IS the address. The address is computed, not stored.
--
-- 240 = 60 × 4 = 15 × 16 = (15 lanes) × (4 channels × 4 orientations)
-- Each of the 240 positions corresponds to one (channel, lane, orientation)
-- triple in the 27×27 Aztec lattice.
--
-- The Braille dual register:
--   Same 8-bit kernel state byte has two independent readings:
--     Binary interpretation:    dot_i = bit (i-1) of the byte
--     Hex-weight interpretation: dot weights = {1,2,4,64,16,8,32,128}
--                                (ISO/TR 11548-1 dot ordering)
--   These are different numbers for most byte values.
--   Binary  → the raw data channel (IPv6-style addressing)
--   Hex-wt  → the factorial address channel (configuration state)
--
-- Factorial address stack (derived from clocks 4, 7, 8):
--   4! = 24  (control)
--   7! = 5040 = master period  (Fano)
--   8! = 40320                  (codec)
--   Mixed-radix radices = [1,2,3,4,5,6,7,8,9,10] (factoradic)
--
-- Authority: algorithms and reproducible outputs only.

module AtomicKernel.FanoWinner where

import Data.Bits  ((.&.), shiftR, shiftL, xor, testBit)
import Data.List  (nub, sort, sortBy, maximumBy)
import Data.Ord   (comparing)
import Data.Word  (Word8, Word64)
import Numeric    (showHex)

-- ============================================================================
-- FANO WINNER
-- The winner is not a position. It is the output of chirality selection.
-- ============================================================================

-- | The 7 Fano lines (from AtomicKernel — replicated for locality).
fanoLines :: [(Int, Int, Int)]
fanoLines =
  [ (0,1,3), (0,2,5), (0,4,6)
  , (1,2,4), (1,5,6)
  , (2,3,6)
  , (3,4,5)
  ]

-- | FanoWinner: the result of chirality selection at one tick.
-- Instead of "which LED position", this answers "which Fano point won".
data FanoWinner = FanoWinner
  { fwTick      :: Int          -- the tick this was computed at
  , fwTriplet   :: (Int,Int,Int) -- the active Fano line
  , fwChiralBit :: Int          -- 0 or 1 (kernel-derived)
  , fwWinner    :: Int          -- winning Fano point (0..6)
  , fwLosers    :: [Int]        -- non-winning points from this line
  , fwAddr240   :: Int          -- position in 0..239 (the "LED" address)
  } deriving (Eq, Show)

-- | computeWinner: derive the Fano winner at tick t from kernel state.
-- This replaces sonarOffset — position comes FROM the winner, not tick mod N.
--
-- The winner is the point selected by chirality from the active Fano line.
-- chiralBit=0 selects the first point of the triplet.
-- chiralBit=1 selects the last point of the triplet.
-- (Middle point is the "pivot" — always present regardless of chirality.)
computeWinner :: Int -> Int -> FanoWinner
computeWinner tick chiralBit =
  let t7            = tick `mod` 7
      triplet@(p0,p1,p2) = fanoLines !! t7
      -- Chirality selects: bit=0 → first point, bit=1 → last point
      winner        = if chiralBit == 0 then p0 else p2
      pivot         = p1  -- always active (the centroid of the line)
      losers        = filter (/= winner) [p0, p1, p2]
      -- Map winner to 240-space:
      --   7 Fano points × (tick / 7) gives the cycle count
      --   240 / 7 ≈ 34.28, so we use fanoPoint × 34 + cycleOffset
      --   cycleOffset ensures full 240-space coverage over 5040 ticks
      cycleN        = tick `div` 7
      addr240       = (winner * 34 + cycleN) `mod` 240
  in FanoWinner tick triplet chiralBit winner losers addr240

-- | winnerSequence: infinite stream of FanoWinner, one per tick.
-- chiralBits must be supplied externally from kernel state.
winnerSequence :: [Int] -> [FanoWinner]
winnerSequence chiralBits = zipWith computeWinner [0..] chiralBits

-- ============================================================================
-- BRAILLE DUAL REGISTER
-- Same 8-bit byte → two independent numeric values.
-- ============================================================================

-- | ISO/TR 11548-1 hex weights for each dot position (1-indexed).
-- These are the weights used to compute the Unicode Braille code point
-- offset from U+2800. They are NOT the binary bit weights.
--
-- Source: Wikipedia "Braille Patterns" / ISO/TR 11548-1
-- Dot:     1    2    3    4     5     6     7     8
-- Weight: 0x1  0x2  0x4  0x40  0x10  0x08  0x20  0x80
--
-- In decimal:  1    2    4    64   16    8    32   128
-- Note: dots 4,5,6 are permuted relative to binary (8,16,32).
hexWeightTable :: [Int]
hexWeightTable = [0x01, 0x02, 0x04, 0x40, 0x10, 0x08, 0x20, 0x80]

-- | Binary weight for dot i (1-indexed): 2^(i-1)
-- This is the standard little-endian bit mapping.
binaryWeight :: Int -> Int
binaryWeight i = 1 `shiftL` (i - 1)

-- | BrailleCell: one 8-dot cell with both interpretations computed.
data BrailleCell = BrailleCell
  { bcRaisedDots   :: [Int]    -- which dots are raised (1..8)
  , bcBinaryValue  :: Int      -- binary interpretation (0..255)
  , bcHexWtValue   :: Int      -- hex-weight interpretation (0..255)
  , bcUnicodeCP    :: Int      -- Unicode codepoint (0x2800 + hex-weight)
  , bcBrailleChar  :: Char     -- the actual Braille character
  } deriving (Eq, Show)

-- | buildBrailleCell: construct a BrailleCell from a byte value.
-- The byte is interpreted as a binary pattern (bit i → dot i+1).
buildBrailleCell :: Word8 -> BrailleCell
buildBrailleCell byte =
  let raised = [ i | i <- [1..8], testBit byte (i-1) ]
      binVal = fromIntegral byte  -- the byte IS the binary value
      -- Hex-weight value: sum of hex weights for raised dots
      hexWt  = sum [ hexWeightTable !! (d-1) | d <- raised ]
      cp     = 0x2800 + hexWt
  in BrailleCell
      { bcRaisedDots  = raised
      , bcBinaryValue = binVal
      , bcHexWtValue  = hexWt
      , bcUnicodeCP   = cp
      , bcBrailleChar = toEnum cp
      }

-- | The dual register: same byte produces two channel values.
-- Binary channel  → raw data / IPv6-style addressing
-- HexWt channel   → factorial address / configuration state
data DualRegister = DualRegister
  { drCell      :: BrailleCell
  , drBinary    :: Int          -- binary channel (0..255)
  , drHexWt     :: Int          -- hex-weight channel (0..255)
  , drTick      :: Int          -- tick this register was computed at
  } deriving (Eq, Show)

buildDualRegister :: Int -> Word8 -> DualRegister
buildDualRegister tick byte =
  let cell = buildBrailleCell byte
  in DualRegister
      { drCell   = cell
      , drBinary = bcBinaryValue cell
      , drHexWt  = bcHexWtValue  cell
      , drTick   = tick
      }

-- ============================================================================
-- FACTORIAL ADDRESS STACK
-- Mixed-radix encoding using factoradic radices.
-- Derived from clocks 4, 7, 8.
-- ============================================================================

-- | Factoradic radices (the factorial number system).
-- Position k uses radix (k+1), so digits are 0..k.
-- This gives any integer its unique factoradic representation.
--
-- Derived from clocks:
--   Radix 4  = control clock        (4! = 24)
--   Radix 7  = Fano clock           (7! = 5040 = master period)
--   Radix 8  = codec clock          (8! = 40320)
--   Others   = sequential additions of clock values
factoradicRadices :: [Int]
factoradicRadices = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  -- for 10 digits

-- | encodeFactoradic: encode an integer as factoradic digits.
-- Returns digits least-significant first (matching mixedEncode convention).
encodeFactoradic :: Int -> [Int]
encodeFactoradic = go factoradicRadices
  where
    go [] v      = [v]
    go (r:rs) v  = (v `mod` r) : go rs (v `div` r)

-- | decodeFactoradic: reconstruct integer from factoradic digits.
decodeFactoradic :: [Int] -> Int
decodeFactoradic digits = foldr step (last digits) (zip (init digits) factoradicRadices)
  where step (d, r) acc = d + r * acc

-- | Factoradic roundtrip invariant.
factoradicRoundtrip :: Int -> Bool
factoradicRoundtrip v =
  v >= 0 && v < product factoradicRadices
  && decodeFactoradic (encodeFactoradic v) == v

-- | FactorialAddress: the 16-digit factorial address derived from
-- two 8-byte Braille registers (binary + hex-weight = 16 bytes).
-- This replaces the 128-bit IPv6 address with a structure derived
-- entirely from the kernel state and Braille dual interpretation.
data FactorialAddress = FactorialAddress
  { faDigits      :: [Int]   -- 10 factoradic digits (0 indexed per radix)
  , faBinaryBits  :: [Word8] -- the raw binary channel (8 bytes)
  , faHexWtBits   :: [Word8] -- the hex-weight channel (8 bytes)
  , faConfigIndex :: Int     -- decoded factoradic integer
  , faFanoWinner  :: Int     -- which Fano point this address belongs to
  } deriving (Eq, Show)

-- | buildFactorialAddress: construct a FactorialAddress from 8 kernel bytes.
-- The 8 bytes come from 8 consecutive kernel states at ticks t..t+7.
-- Each byte feeds one dual register.
buildFactorialAddress :: Int -> [Word8] -> FactorialAddress
buildFactorialAddress startTick bytes =
  let registers = zipWith buildDualRegister [startTick..] bytes
      binBytes  = map (fromIntegral . drBinary) registers
      hexBytes  = map (fromIntegral . drHexWt)  registers
      -- Use hex-weight bytes as factoradic digits (mod each radix)
      digits    = zipWith (\b r -> fromIntegral b `mod` r)
                           hexBytes
                           (factoradicRadices ++ repeat 10)
      -- Config index: decode first 10 digits
      configIdx = decodeFactoradic (take 10 digits)
      -- Fano winner at startTick (from first byte's parity)
      fanoW     = fromIntegral (head bytes) `mod` 7
  in FactorialAddress
      { faDigits      = take 10 digits
      , faBinaryBits  = map fromIntegral binBytes
      , faHexWtBits   = map fromIntegral hexBytes
      , faConfigIndex = configIdx
      , faFanoWinner  = fanoW
      }

-- ============================================================================
-- 240-SPACE ADDRESSING
-- 240 = 60 × 4 = 15 × 16 = (Fano-winner-derived)
-- ============================================================================

-- | Addr240: a position in the 240-space, fully derived from
-- the Fano winner and the factorial address.
--
-- Structure: 240 = 15 × 16
--   15 = number of non-null lanes per channel (from Aztec lattice)
--   16 = 4 channels × 4 orientations (Klein four-group × 4 rotations)
data Addr240 = Addr240
  { a240Raw       :: Int    -- 0..239
  , a240LaneIdx   :: Int    -- 0..14 (which of 15 lanes)
  , a240Quadrant  :: Int    -- 0..15 (which of 16 channel/orientation combos)
  , a240Channel   :: Int    -- 0..3 (US=0, RS=1, GS=2, FS=3)
  , a240Lane      :: Int    -- 1..15 (lane within channel)
  , a240Orient    :: Int    -- 0..3 (orientation / chirality power)
  } deriving (Eq, Show)

-- | addr240FromWinner: construct a 240-space address from the Fano winner.
-- This is the replacement for sonarOffset.
-- Position = winner × 34 + cycleN, where cycleN advances the coverage.
addr240FromWinner :: FanoWinner -> Addr240
addr240FromWinner fw =
  let raw      = fwAddr240 fw
      laneIdx  = raw `mod` 15          -- 0..14
      quadrant = (raw `div` 15) `mod` 16  -- 0..15
      channel  = quadrant `div` 4      -- 0..3
      orient   = quadrant `mod` 4      -- 0..3
      lane     = laneIdx + 1           -- 1..15
  in Addr240
      { a240Raw      = raw
      , a240LaneIdx  = laneIdx
      , a240Quadrant = quadrant
      , a240Channel  = channel
      , a240Lane     = lane
      , a240Orient   = orient
      }

-- | channelName: US/RS/GS/FS
channelName :: Int -> String
channelName 0 = "US"
channelName 1 = "RS"
channelName 2 = "GS"
channelName 3 = "FS"
channelName n = "CH" ++ show n

-- ============================================================================
-- THE WINNER FRAME
-- Combines FanoWinner + DualRegister + Addr240 into one animation unit.
-- This is what replaces DualFrame from Timing.hs when using winner addressing.
-- ============================================================================

data WinnerFrame = WinnerFrame
  { wfTick       :: Int
  , wfWinner     :: FanoWinner
  , wfRegister   :: DualRegister
  , wfAddr240    :: Addr240
  , wfFactAddr   :: FactorialAddress  -- from 8-tick window
  -- Derived display values
  , wfBrailleChar :: Char             -- the Braille glyph for this tick
  , wfUnicodeCP   :: Int              -- U+28xx
  , wfConfigLabel :: String           -- human-readable config description
  } deriving (Eq, Show)

-- | buildWinnerFrame: construct a complete WinnerFrame at tick t.
-- kernelByte is the LSB of the kernel state at tick t.
-- winnerHistory is the last 8 kernelBytes (for factorial address).
buildWinnerFrame :: Int -> Int -> Word8 -> [Word8] -> WinnerFrame
buildWinnerFrame tick chiralBit kernelByte history =
  let winner   = computeWinner tick chiralBit
      reg      = buildDualRegister tick kernelByte
      addr     = addr240FromWinner winner
      factAddr = buildFactorialAddress (tick - 7) (take 8 history)
      cell     = drCell reg
  in WinnerFrame
      { wfTick        = tick
      , wfWinner      = winner
      , wfRegister    = reg
      , wfAddr240     = addr
      , wfFactAddr    = factAddr
      , wfBrailleChar = bcBrailleChar cell
      , wfUnicodeCP   = bcUnicodeCP cell
      , wfConfigLabel = describeConfig addr factAddr winner
      }

-- | Describe the configuration at this winner frame.
describeConfig :: Addr240 -> FactorialAddress -> FanoWinner -> String
describeConfig addr fa fw =
  channelName (a240Channel addr)
  ++ "/lane" ++ show (a240Lane addr)
  ++ "/orient" ++ show (a240Orient addr)
  ++ " fano=" ++ show (fwWinner fw)
  ++ " cfg=" ++ show (faConfigIndex fa)

-- ============================================================================
-- INVARIANTS
-- ============================================================================

-- | INV-W1: computeWinner is deterministic (same inputs → same outputs).
invW1_deterministic :: Bool
invW1_deterministic =
  all (\(t, b) -> computeWinner t b == computeWinner t b)
      [(t, b) | t <- [0..20], b <- [0,1]]

-- | INV-W2: all 240 addresses are reachable within one master period.
invW2_fullCoverage :: Bool
invW2_fullCoverage =
  let addrs = [ fwAddr240 (computeWinner t (t `mod` 2))
              | t <- [0..5039] ]
  in length (nub addrs) == 240

-- | INV-W3: Braille dual register binary value = fromIntegral of input byte.
invW3_binaryIsIdentity :: Bool
invW3_binaryIsIdentity =
  all (\b -> bcBinaryValue (buildBrailleCell b) == fromIntegral b)
      [minBound .. maxBound :: Word8]

-- | INV-W4: hex-weight value is always in range [0..255].
invW4_hexWtInRange :: Bool
invW4_hexWtInRange =
  all (\b -> let v = bcHexWtValue (buildBrailleCell b)
             in v >= 0 && v <= 255)
      [minBound .. maxBound :: Word8]

-- | INV-W5: binary and hex-weight differ for most bytes
-- (they are NOT the same mapping).
invW5_distinctMappings :: Bool
invW5_distinctMappings =
  let pairs = [ (bcBinaryValue c, bcHexWtValue c)
              | b <- [minBound .. maxBound :: Word8]
              , let c = buildBrailleCell b ]
      different = filter (uncurry (/=)) pairs
  in length different > 200  -- most bytes give different values

-- | INV-W6: factoradic roundtrip holds for values in range.
invW6_factoradicRoundtrip :: Bool
invW6_factoradicRoundtrip =
  let maxV = product factoradicRadices - 1
  in all factoradicRoundtrip [0 .. min maxV 9999]

-- | INV-W7: addr240 is always in [0..239].
invW7_addr240Range :: Bool
invW7_addr240Range =
  all (\(t, b) -> fwAddr240 (computeWinner t b) `elem` [0..239])
      [(t, b) | t <- [0..100], b <- [0,1]]

-- | INV-W8: known Braille examples from Wikipedia.
-- DOTS-125 (dots 1,2,5 raised) → U+2813, hex-weight = 0x13 = 19.
-- DOTS-12378 → U+28C7, hex-weight = 0xC7 = 199.
-- DOTS-12345678 → U+28FF, hex-weight = 0xFF = 255.
invW8_knownBraille :: Bool
invW8_knownBraille =
  let -- DOTS-125: bits 0,1,4 set (dots 1,2,5) → binary = 1+2+16 = 19
      cell125  = buildBrailleCell 0x13  -- binary 00010011 = dots 1,2,5
      -- hex-weight of dots 1,2,5 = 0x1 + 0x2 + 0x10 = 0x13 = 19
      ok125    = bcUnicodeCP cell125 == 0x2813

      -- DOTS-12345678: all dots raised → binary = 0xFF, hex-weight = 0xFF
      cellAll  = buildBrailleCell 0xFF
      okAll    = bcUnicodeCP cellAll == 0x28FF
  in ok125 && okAll

-- | Run all winner frame invariants.
checkWinnerInvariants :: [(String, Bool)]
checkWinnerInvariants =
  [ ("W1 computeWinner deterministic",     invW1_deterministic)
  , ("W2 full 240-space coverage",         invW2_fullCoverage)
  , ("W3 binary = fromIntegral byte",      invW3_binaryIsIdentity)
  , ("W4 hex-weight in [0..255]",          invW4_hexWtInRange)
  , ("W5 binary ≠ hex-weight (distinct)",  invW5_distinctMappings)
  , ("W6 factoradic roundtrip",            invW6_factoradicRoundtrip)
  , ("W7 addr240 in [0..239]",             invW7_addr240Range)
  , ("W8 known Braille examples",          invW8_knownBraille)
  ]

-- ============================================================================
-- DEMO
-- ============================================================================

showWinnerFrame :: WinnerFrame -> String
showWinnerFrame wf =
  "tick=" ++ show (wfTick wf)
  ++ " " ++ wfBrailleChar wf : ""
  ++ " U+" ++ showHex (wfUnicodeCP wf) ""
  ++ " bin=" ++ show (drBinary (wfRegister wf))
  ++ " hexwt=" ++ show (drHexWt (wfRegister wf))
  ++ " addr240=" ++ show (a240Raw (wfAddr240 wf))
  ++ " " ++ wfConfigLabel wf

showBrailleTable :: IO ()
showBrailleTable = do
  putStrLn "=== Braille Dual Register (first 16 bytes) ===\n"
  putStrLn "byte  dots   binary  hexwt  U+      char"
  putStrLn (replicate 55 '-')
  mapM_ showRow [0x00, 0x01, 0x03, 0x07, 0x0F, 0x1F, 0x3F, 0x7F,
                 0x80, 0x13, 0xC7, 0xFF, 0x55, 0xAA, 0x12, 0x48]
  where
    showRow b =
      let c    = buildBrailleCell (fromIntegral b)
          dots = if null (bcRaisedDots c) then "—"
                 else concatMap show (bcRaisedDots c)
          pad n s = s ++ replicate (n - length s) ' '
      in putStrLn $
           pad 6  ("0x" ++ showHex b "")
           ++ pad 8  dots
           ++ pad 8  (show (bcBinaryValue c))
           ++ pad 7  (show (bcHexWtValue c))
           ++ pad 8  ("U+" ++ showHex (bcUnicodeCP c) "")
           ++ [bcBrailleChar c]

showWinnerSequence :: [Int] -> IO ()
showWinnerSequence chiralBits = do
  putStrLn "\n=== Fano Winner Sequence (ticks 0–13) ===\n"
  putStrLn "tick  bit  triplet    winner  losers  addr240  ch/ln"
  putStrLn (replicate 60 '-')
  mapM_ showRow (take 14 (zip [0..] chiralBits))
  where
    showRow (t, b) =
      let fw   = computeWinner t b
          addr = addr240FromWinner fw
          (p0,p1,p2) = fwTriplet fw
          pad n s = s ++ replicate (n - length s) ' '
      in putStrLn $
           pad 6  (show t)
           ++ pad 5  (show b)
           ++ pad 12 ("(" ++ show p0 ++ "," ++ show p1 ++ "," ++ show p2 ++ ")")
           ++ pad 8  (show (fwWinner fw))
           ++ pad 9  (show (fwLosers fw))
           ++ pad 9  (show (fwAddr240 fw))
           ++ channelName (a240Channel addr) ++ "/" ++ show (a240Lane addr)

showFactoradicDemo :: IO ()
showFactoradicDemo = do
  putStrLn "\n=== Factoradic Address Stack ===\n"
  putStrLn "  Derived from clocks 4, 7, 8:"
  putStrLn $ "  4!  = " ++ show (product [1..4])  ++ " (control)"
  putStrLn $ "  7!  = " ++ show (product [1..7])  ++ " (Fano / master period)"
  putStrLn $ "  8!  = " ++ show (product [1..8])  ++ " (codec)"
  putStrLn $ "  10! = " ++ show (product [1..10]) ++ " (full factoradic range)"
  putStrLn ""
  putStrLn "  Factoradic encoding examples:"
  mapM_ showFact [0, 1, 10, 100, 1000, 3628799]
  where
    showFact v =
      putStrLn $ "  " ++ show v
              ++ " → " ++ show (encodeFactoradic v)
              ++ " → " ++ show (decodeFactoradic (encodeFactoradic v))

showInvariants :: IO ()
showInvariants = do
  putStrLn "\n=== Winner Frame Invariants ===\n"
  mapM_ (\(name, ok) ->
    putStrLn $ "  " ++ (if ok then "[OK]   " else "[FAIL] ") ++ name)
    checkWinnerInvariants

main :: IO ()
main = do
  putStrLn "=== AtomicKernel.FanoWinner ===\n"
  showBrailleTable
  -- Use alternating chirality bits for demo
  let chiralBits = cycle [0,1,0,0,1,1,0,1]
  showWinnerSequence chiralBits
  showFactoradicDemo
  showInvariants
