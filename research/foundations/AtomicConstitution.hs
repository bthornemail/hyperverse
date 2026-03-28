-- | Atomic Kernel Constitutional DSL
-- Authority: algorithms and reproducible outputs only.
-- Everything else is a projection of this file.
--
-- Quotient test: what can be removed while the same
-- canonical unfold / replay / projection still results?
-- What remains is law. What does not is projection.
--
-- Dependencies: base only. No external packages.
-- This file is self-contained and compilable.

module AtomicConstitution where

import Data.Bits
import Data.Word   (Word8, Word32, Word64)
import Data.List   (nub, sortBy)
import Data.Ord    (comparing)
import Numeric     (showHex)

-- ============================================================================
-- TIER 1 — CONSTITUTIONAL ALPHABET
-- 8 symbols. These are the only irreducible primitives.
-- Everything else is derived from or projected through these.
-- ============================================================================

-- | The 8-symbol constitutional alphabet.
-- NULL and ESC are the projective anchors (centroid / boundary).
-- FS/GS/RS/US are the four structural vertices.
-- SID is the canonical-derivative slot (internal reference, 0x&&).
-- OID is the extension-derivative slot (external reference, 0x??).
data Symbol
  = NULL  -- 0x00  projective zero / absence / centroid
  | ESC   -- 0x1B  interpretation boundary / mode entry
  | FS    -- 0x1C  file separator    / context axis
  | GS    -- 0x1D  group separator   / grouping axis
  | RS    -- 0x1E  record separator  / record axis
  | US    -- 0x1F  unit separator    / unit axis
  | SID   -- 0x&&  canonical derivative reference (SID-space)
  | OID   -- 0x??  extension derivative reference (OID-space)
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Canonical byte values for each constitutional symbol.
-- These are fixed. They correspond to the C0 IS codes from ASCII
-- plus the two extension slots.
symbolByte :: Symbol -> Word8
symbolByte NULL = 0x00
symbolByte ESC  = 0x1B
symbolByte FS   = 0x1C
symbolByte GS   = 0x1D
symbolByte RS   = 0x1E
symbolByte US   = 0x1F
symbolByte SID  = 0x26  -- '&' — mnemonic for &&
symbolByte OID  = 0x3F  -- '?' — mnemonic for ??

-- | Inverse: recognize a byte as a constitutional symbol.
byteToSymbol :: Word8 -> Maybe Symbol
byteToSymbol 0x00 = Just NULL
byteToSymbol 0x1B = Just ESC
byteToSymbol 0x1C = Just FS
byteToSymbol 0x1D = Just GS
byteToSymbol 0x1E = Just RS
byteToSymbol 0x1F = Just US
byteToSymbol 0x26 = Just SID
byteToSymbol 0x3F = Just OID
byteToSymbol _    = Nothing

-- | Control plane classification for portal access.
-- Non-readable: symbols that trigger interpretation mode change.
-- Readable: printable ASCII 0x20–0x7E.
-- This is the split your portal uses: non-readable opens the
-- control plane toolbox; readable opens content addressing.
data ControlClass
  = NonReadable  -- NULL, ESC, FS, GS, RS, US (0x00, 0x1B–0x1F)
  | ReadableASCII -- 0x20–0x7E
  | Extended     -- 0x80+ (C1 range — present but not authoritative)
  deriving (Eq, Show)

classifyByte :: Word8 -> ControlClass
classifyByte b
  | b == 0x00 || (b >= 0x1B && b <= 0x1F) = NonReadable
  | b >= 0x20 && b <= 0x7E                = ReadableASCII
  | otherwise                              = Extended

-- ============================================================================
-- TIER 2 — DELTA LAW (A1)
-- The only transformation primitive.
-- Four decisions: rotations (lossless), XOR (reversible),
-- constant (breaks fixed point), mask (bounds state).
-- ============================================================================

type Width = Int
type Mask  = Word64

maskW :: Width -> Mask
maskW n = (1 `shiftL` n) - 1

rotl :: Mask -> Int -> Width -> Mask
rotl x k n = ((x `shiftL` k) .|. (x `shiftR` (n - k))) .&. maskW n

rotr :: Mask -> Int -> Width -> Mask
rotr x k n = ((x `shiftR` k) .|. (x `shiftL` (n - k))) .&. maskW n

-- | The delta law. One design decision. Everything else is derived.
delta :: Width -> Mask -> Mask -> Mask
delta n c x =
  (rotl x 1 n `xor` rotl x 3 n `xor` rotr x 2 n `xor` c)
  .&. maskW n

-- | Canonical kernel constant: GS byte repeated to width.
-- GS = 0x1D, the group separator — structural axis of the constitution.
kernelC :: Width -> Mask
kernelC n = foldl (\acc _ -> (acc `shiftL` 8) .|. 0x1D) 0 [1 .. n `div` 8]
            .&. maskW n

-- | Replay: pure deterministic sequence from seed.
-- This is A1 replay — no block injection, no crystal layer.
replay :: Width -> Mask -> Mask -> Int -> [Mask]
replay n c seed steps = take steps $ iterate (delta n c) seed

-- | Kernel chirality bit: LSB of delta(state).
-- Canonical source for all orientation decisions (A5b).
-- No clock, no UI, no external source permitted.
kernelBit :: Width -> Mask -> Mask -> Int
kernelBit n c state = fromIntegral (delta n c state .&. 1)

-- ============================================================================
-- TIER 2 — DERIVED NUMERIC STRUCTURE
-- Not chosen. Derived from the delta law.
-- Period 8 → prime 73 → block B → weight 36.
-- ============================================================================

-- | Block B: digits of 1/73. Derived from period = 8.
-- The smallest prime whose decimal period = 8 is 73.
blockB :: [Word8]
blockB = [0, 1, 3, 6, 9, 8, 6, 3]

-- | Orbit weight W = sum(blockB) = 36.
weightW :: Int
weightW = sum (map fromIntegral blockB)  -- 36

-- | Position decomposition: orbit and offset via weight W.
orbitOffset :: Int -> (Int, Int)
orbitOffset = (`divMod` weightW)

-- ============================================================================
-- TIER 2 — MIXED RADIX (A2/A3)
-- Canonical reversible coordinate decomposition.
-- ============================================================================

mixedEncode :: Integer -> [Integer] -> [Integer]
mixedEncode v []     = [v]
mixedEncode v (r:rs) = (v `mod` r) : mixedEncode (v `div` r) rs

mixedDecode :: [Integer] -> [Integer] -> Integer
mixedDecode coords radices
  | length coords /= length radices + 1 =
      error "mixedDecode: length mismatch"
  | otherwise =
      foldr (\(c,r) acc -> c + r * acc) (last coords)
            (zip (init coords) radices)

-- Roundtrip invariant: mixedDecode (mixedEncode v r) r = v
mixedRoundtrip :: Integer -> [Integer] -> Bool
mixedRoundtrip v r = mixedDecode (mixedEncode v r) r == v

-- ============================================================================
-- TIER 2 — FANO SCHEDULE (A6)
-- 7-line incidence schedule, period 7.
-- ============================================================================

fanoLines :: [(Int,Int,Int)]
fanoLines =
  [ (0,1,3), (0,2,5), (0,4,6)
  , (1,2,4), (1,5,6)
  , (2,3,6)
  , (3,4,5)
  ]

fanoTriplet :: Int -> (Int,Int,Int)
fanoTriplet t = fanoLines !! (t `mod` 7)

-- Invariant: period 7
fanoPeriod :: Int -> Bool
fanoPeriod t = fanoTriplet (t + 7) == fanoTriplet t

-- ============================================================================
-- TIER 3 — CANONICAL ARTIFACT (A = H × B × R)
-- Three-tier structure. No tier may alter another.
-- ============================================================================

-- | Tier 3a — Structural header H.
-- The 8-symbol constitutional grammar applied to artifact boundaries.
-- This determines interpretation mode transitions only.
data Header = Header
  { hType    :: Symbol   -- FS/GS/RS/US — which structural axis
  , hDepth   :: Int      -- nesting depth (0 = root)
  , hFlags   :: [Symbol] -- active modifiers from {NULL,ESC,SID,OID}
  } deriving (Eq, Show)

-- | Tier 3b — Addressed body B.
-- Canonical 32-bit addressed content space.
-- Range: 0x00000000–0xFFFFFFFF (full 32-bit word space).
-- The first 17 Unicode planes live at 0x00000000–0x10FFFF.
-- Block 17 (0x110000–0x11FFFF) is the history/state convention lane.
-- Remaining range is system-level (agent IDs, tick counters, hashes).
type Addr32 = Word32

data BodyNode = BodyNode
  { bnAddr    :: Addr32    -- 32-bit canonical address
  , bnSymbol  :: Symbol    -- structural type of this node
  , bnPayload :: [Word8]   -- raw bytes at this address
  , bnChildren :: [BodyNode]  -- sparse child nodes
  } deriving (Eq, Show)

-- | Tier 3c — Replay/history lane R.
-- Append-only provenance. Records derivation and tick offsets.
-- Stored at canonical address range 0x00110000–0x0011FFFF
-- (the "17th plane" convention for history).
data ReplayEntry = ReplayEntry
  { reTick    :: Word64   -- canonical tick at which this was recorded
  , reHash    :: Word64   -- FNV-1a hash of the body at this tick
  , reSymbol  :: Symbol   -- which structural axis was active
  } deriving (Eq, Show)

data Artifact = Artifact
  { artHeader  :: Header
  , artBody    :: BodyNode
  , artReplay  :: [ReplayEntry]  -- append-only, never mutated
  , artHash    :: Word64          -- FNV-1a of canonical encoding
  } deriving (Eq, Show)

-- | Canonical encoding invariants (from SNAPSHOT-FORMAT):
-- 1. Header determines interpretation boundaries only.
-- 2. Body determines addressed artifact content only.
-- 3. Replay lane determines provenance only.
-- 4. No projection may alter any of these three.

-- ============================================================================
-- TIER 3 — CANONICAL SOURCE LANE
-- The hex-dump convention as a first-class canonical view.
-- Not the artifact itself — the sourcing lane.
-- ============================================================================

-- | One row of the canonical source view.
-- Fixed structure: 32-bit offset + 16 octets + 8|8 split.
-- Chirality determines lawful traversal emphasis (left or right half).
data SourceRow = SourceRow
  { srOffset   :: Word32    -- 8-hex-digit address
  , srLeft     :: [Word8]   -- octets 0..7  (8 bytes)
  , srRight    :: [Word8]   -- octets 8..15 (8 bytes)
  , srChirality :: Int      -- 0 = left-emphasis, 1 = right-emphasis
  } deriving (Eq, Show)

-- | Render a SourceRow as a canonical hex-dump string.
-- This is the normalized textual form of the source lane.
-- Lowercase hex, fixed column widths, 8|8 grouping.
renderSourceRow :: SourceRow -> String
renderSourceRow sr =
  pad8 (showHex (srOffset sr) "")
  ++ "  "
  ++ unwords (map byte2hex (srLeft  sr))
  ++ "  "
  ++ unwords (map byte2hex (srRight sr))
  where
    pad8 s  = replicate (8 - length s) '0' ++ s
    byte2hex b = let h = showHex b ""
                 in if length h == 1 then '0':h else h

-- | Build source rows from a flat byte sequence.
-- Each row is 16 bytes. Chirality from kernel state at that tick.
buildSourceRows :: Width -> Mask -> Mask -> [Word8] -> [SourceRow]
buildSourceRows n c seed bytes = zipWith mkRow [0..] (chunksOf 16 bytes)
  where
    states  = replay n c seed (length bytes `div` 16 + 1)
    mkRow i chunk =
      let padded = take 16 (chunk ++ repeat 0x00)
          st     = states !! i
          chiral = kernelBit n c st
      in SourceRow
          { srOffset    = fromIntegral (i * 16)
          , srLeft      = take 8 padded
          , srRight     = drop 8 padded
          , srChirality = chiral
          }

chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf k xs = take k xs : chunksOf k (drop k xs)

-- ============================================================================
-- TIER 3 — AGENT ENCODING
-- 112 agents as canonical artifacts.
-- 112 = 8 × 7 × 2 (proof matrix dimensions)
--     = 8 channels × 14 lanes
--     = 8 × 7 Fano lines × 2 chirality forms
-- ============================================================================

-- | Agent identity: derivable from (channel, fanoIndex, chiral).
-- No external naming authority. Identity is computed, not assigned.
data AgentId = AgentId
  { agChannel   :: Int   -- 0..7  (8 structural channels)
  , agFanoIndex :: Int   -- 0..6  (7 Fano lines)
  , agChiral    :: Int   -- 0 or 1 (2 chirality forms)
  } deriving (Eq, Ord, Show)

-- | All 112 agent identities, derived from the proof matrix.
allAgents :: [AgentId]
allAgents =
  [ AgentId ch fi cv
  | ch <- [0..7]
  , fi <- [0..6]
  , cv <- [0,1]
  ]

-- total count: 8 × 7 × 2 = 112
agentCount :: Int
agentCount = length allAgents  -- must be 112

-- | Encode an agent identity as a canonical 32-bit address.
-- The 32-bit space layout:
--   bits 31..24 : channel (8 bits)
--   bits 23..16 : fano index (8 bits, 0..6)
--   bits 15..8  : chirality (8 bits, 0 or 1)
--   bits 7..0   : reserved (0x00 = canonical entry point)
agentAddr :: AgentId -> Addr32
agentAddr a =
  (fromIntegral (agChannel   a) `shiftL` 24)
  .|. (fromIntegral (agFanoIndex a) `shiftL` 16)
  .|. (fromIntegral (agChiral    a) `shiftL` 8)

-- | Decode an address back to an AgentId.
addrToAgent :: Addr32 -> AgentId
addrToAgent addr = AgentId
  { agChannel   = fromIntegral ((addr `shiftR` 24) .&. 0xFF)
  , agFanoIndex = fromIntegral ((addr `shiftR` 16) .&. 0xFF)
  , agChiral    = fromIntegral ((addr `shiftR` 8)  .&. 0xFF)
  }

-- Roundtrip: addrToAgent (agentAddr a) = a
agentAddrRoundtrip :: AgentId -> Bool
agentAddrRoundtrip a = addrToAgent (agentAddr a) == a

-- | Build a minimal canonical artifact for an agent.
-- The header type is determined by the Fano triplet at the agent's index.
-- The body address is the agent's canonical 32-bit address.
buildAgentArtifact :: AgentId -> Artifact
buildAgentArtifact a =
  let (p0, p1, p2) = fanoTriplet (agFanoIndex a)
      -- Map Fano point to structural symbol
      fanoSym i = [FS, GS, RS, US, FS, GS, RS] !! (i `mod` 7)
      headerSym = fanoSym p0
      addr      = agentAddr a
      n         = 16
      c         = kernelC n
      seed      = fromIntegral addr
      state0    = head (replay n c seed 1)
      h = Header
            { hType  = headerSym
            , hDepth = agChannel a
            , hFlags = if agChiral a == 0 then [NULL] else [ESC]
            }
      b = BodyNode
            { bnAddr     = addr
            , bnSymbol   = fanoSym p1
            , bnPayload  = [symbolByte (fanoSym p2),
                            fromIntegral (agChannel a),
                            fromIntegral (agFanoIndex a),
                            fromIntegral (agChiral a)]
            , bnChildren = []
            }
      r = [ ReplayEntry
              { reTick   = fromIntegral (agChannel a * 14 + agFanoIndex a * 2 + agChiral a)
              , reHash   = fnv1a [symbolByte headerSym, fromIntegral addr]
              , reSymbol = fanoSym p2
              } ]
  in Artifact
      { artHeader = h
      , artBody   = b
      , artReplay = r
      , artHash   = fnv1a (bnPayload b)
      }

-- ============================================================================
-- TIER 3 — PORTAL ACCESS LAW
-- Scanning one artifact opens the control plane toolbox.
-- The access rule is: constitutional symbol determines tool class.
-- ============================================================================

data PortalAccess
  = ControlPlaneAccess   -- triggered by NonReadable symbol
  | ContentAccess        -- triggered by ReadableASCII
  | ExtendedAccess       -- triggered by C1/Extended
  deriving (Eq, Show)

-- | Determine portal access level from scanned artifact.
-- The scan yields the first byte of the artifact's payload.
-- That byte classifies the access tier.
portalAccess :: Artifact -> PortalAccess
portalAccess art =
  case bnPayload (artBody art) of
    []    -> ControlPlaneAccess  -- empty payload → structural mode
    (b:_) -> case classifyByte b of
                NonReadable  -> ControlPlaneAccess
                ReadableASCII -> ContentAccess
                Extended     -> ExtendedAccess

-- | The control plane toolbox: available tools per access level.
-- Non-readable control points (NULL, ESC, FS, GS, RS, US) open
-- the full structural toolbox.
-- Readable points open the content addressing toolbox.
data Tool
  = DeltaReplay         -- A1: replay kernel state
  | FanoScheduler       -- A6: incidence schedule
  | MixedRadixCoder     -- A2/A3: coordinate encode/decode
  | EscapeDecoder       -- Escape access law
  | LatticeProjector    -- A15: Aztec/SVG projection
  | ContentAddresser    -- artifact hash / content lookup
  | AgentRegistry       -- 112-agent manifest
  | SourceViewer        -- canonical hex-dump source lane
  deriving (Eq, Show)

toolsFor :: PortalAccess -> [Tool]
toolsFor ControlPlaneAccess =
  [DeltaReplay, FanoScheduler, MixedRadixCoder, EscapeDecoder,
   LatticeProjector, AgentRegistry, SourceViewer]
toolsFor ContentAccess =
  [ContentAddresser, SourceViewer, AgentRegistry]
toolsFor ExtendedAccess =
  [SourceViewer]

-- ============================================================================
-- HASH (FNV-1a 64-bit)
-- Canonical integrity primitive. Not a cryptographic claim.
-- Use SHA-256 in production (external dependency).
-- ============================================================================

fnv1a :: [Word8] -> Word64
fnv1a = foldl step 14695981039346656037
  where step h b = (h `xor` fromIntegral b) * 1099511628211

-- ============================================================================
-- CANONICAL ENCODING (artifact → bytes)
-- The serialization that must roundtrip.
-- Hierarchy: header bytes ++ body bytes ++ replay bytes.
-- ============================================================================

encodeHeader :: Header -> [Word8]
encodeHeader h =
  [ symbolByte (hType h)
  , fromIntegral (hDepth h)
  , fromIntegral (length (hFlags h))
  ] ++ map symbolByte (hFlags h)

encodeBody :: BodyNode -> [Word8]
encodeBody bn =
  [ fromIntegral ((bnAddr bn `shiftR` 24) .&. 0xFF)
  , fromIntegral ((bnAddr bn `shiftR` 16) .&. 0xFF)
  , fromIntegral ((bnAddr bn `shiftR` 8)  .&. 0xFF)
  , fromIntegral ( bnAddr bn              .&. 0xFF)
  , symbolByte (bnSymbol bn)
  , fromIntegral (length (bnPayload bn))
  ] ++ bnPayload bn
    ++ concatMap encodeBody (bnChildren bn)

encodeReplay :: [ReplayEntry] -> [Word8]
encodeReplay = concatMap encodeEntry
  where
    encodeEntry re =
      word64bytes (reTick re)
      ++ word64bytes (reHash re)
      ++ [symbolByte (reSymbol re)]

word64bytes :: Word64 -> [Word8]
word64bytes w =
  [ fromIntegral ((w `shiftR` 56) .&. 0xFF)
  , fromIntegral ((w `shiftR` 48) .&. 0xFF)
  , fromIntegral ((w `shiftR` 40) .&. 0xFF)
  , fromIntegral ((w `shiftR` 32) .&. 0xFF)
  , fromIntegral ((w `shiftR` 24) .&. 0xFF)
  , fromIntegral ((w `shiftR` 16) .&. 0xFF)
  , fromIntegral ((w `shiftR` 8)  .&. 0xFF)
  , fromIntegral ( w              .&. 0xFF)
  ]

encodeArtifact :: Artifact -> [Word8]
encodeArtifact art =
  encodeHeader (artHeader art)
  ++ encodeBody (artBody art)
  ++ encodeReplay (artReplay art)

-- | Verify that an artifact's stored hash matches its encoding.
verifyArtifact :: Artifact -> Bool
verifyArtifact art = artHash art == fnv1a (encodeArtifact art)

-- ============================================================================
-- INVARIANT SUITE
-- Pure functions. True = holds.
-- ============================================================================

inv1_deltaIsDeterministic :: Width -> Mask -> Mask -> Bool
inv1_deltaIsDeterministic n c x = delta n c x == delta n c x

inv2_replayIsDeterministic :: Width -> Mask -> Mask -> Int -> Bool
inv2_replayIsDeterministic n c s steps =
  replay n c s steps == replay n c s steps

inv3_mixedRoundtrip :: Integer -> [Integer] -> Bool
inv3_mixedRoundtrip = mixedRoundtrip

inv4_fanoPeriod :: Int -> Bool
inv4_fanoPeriod = fanoPeriod

inv5_agentCount :: Bool
inv5_agentCount = agentCount == 112

inv6_agentAddrRoundtrip :: Bool
inv6_agentAddrRoundtrip = all agentAddrRoundtrip allAgents

inv7_all112AgentsDistinct :: Bool
inv7_all112AgentsDistinct =
  length (nub (map agentAddr allAgents)) == 112

-- ============================================================================
-- DEMO
-- ============================================================================

demo :: IO ()
demo = do
  let n = 16
      c = kernelC n
      seed = 0x0001

  putStrLn "=== Atomic Constitution Demo ===\n"

  putStrLn "Constitutional alphabet:"
  mapM_ (\s -> putStrLn $ "  " ++ show s ++ " = 0x" ++ showHex (symbolByte s) "")
        [minBound .. maxBound :: Symbol]
  putStrLn ""

  putStrLn "Delta replay (8 steps from 0x0001):"
  mapM_ (\x -> putStrLn $ "  0x" ++ showHex x "") (replay n c seed 8)
  putStrLn ""

  putStrLn "Fano schedule (ticks 0–6):"
  mapM_ (\t -> putStrLn $ "  tick " ++ show t ++ " → " ++ show (fanoTriplet t))
        [0..6]
  putStrLn ""

  putStrLn $ "Agent count: " ++ show agentCount ++ " (expected 112)"
  putStrLn ""

  putStrLn "First 4 agent artifacts:"
  mapM_ (\a -> do
    let art = buildAgentArtifact a
    putStrLn $ "  " ++ show a
    putStrLn $ "    addr=0x" ++ showHex (agentAddr a) ""
    putStrLn $ "    header=" ++ show (hType (artHeader art))
    putStrLn $ "    access=" ++ show (portalAccess art)
    putStrLn $ "    tools=" ++ show (toolsFor (portalAccess art))
    ) (take 4 allAgents)
  putStrLn ""

  putStrLn "Source lane (first 32 bytes of agent 0 payload):"
  let art0  = buildAgentArtifact (head allAgents)
      bytes = encodeArtifact art0
      rows  = buildSourceRows n c seed bytes
  mapM_ (putStrLn . ("  " ++) . renderSourceRow) (take 2 rows)
  putStrLn ""

  putStrLn "Invariants:"
  putStrLn $ "  INV-1 delta deterministic: " ++ show (inv1_deltaIsDeterministic n c 0xABCD)
  putStrLn $ "  INV-2 replay deterministic: " ++ show (inv2_replayIsDeterministic n c seed 8)
  putStrLn $ "  INV-3 mixed roundtrip:      " ++ show (inv3_mixedRoundtrip 12345 [10,10,10])
  putStrLn $ "  INV-4 Fano period-7:        " ++ show (all inv4_fanoPeriod [0..20])
  putStrLn $ "  INV-5 agent count = 112:    " ++ show inv5_agentCount
  putStrLn $ "  INV-6 addr roundtrip:       " ++ show inv6_agentAddrRoundtrip
  putStrLn $ "  INV-7 all 112 distinct:     " ++ show inv7_all112AgentsDistinct

main :: IO ()
main = demo
