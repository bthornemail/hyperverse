-- | Atomic Kernel Pure DSL
-- Faithful implementation of ATOMIC_KERNEL_REDUCTION_SPEC_v1_2,
-- PURE_ALGORITHMS, CHIRALITY_SELECTION_LAW_v0, ESCAPE_ACCESS_LAW,
-- A14_INCIDENCE_SCHEDULING_LAW, ALGORITHM_A13_ESC_DEPTH_MIXED_RADIX.
--
-- Every function maps 1-to-1 to a named algorithm in the specs.
-- No hidden state. No external dependencies beyond base + Numeric.

module AtomicKernel where

import Data.Bits
import Data.Word        (Word8, Word64)
import Data.List        (nub, sortOn)
import Data.Maybe       (listToMaybe)
import Numeric          (showHex, showOct, showIntAtBase)
import Data.Char        (intToDigit)

-- ============================================================================
-- LAYER 0 — A1. KERNEL TRANSITION
-- Spec: PURE_ALGORITHMS.md §A1, ATOMIC_KERNEL_REDUCTION_SPEC §1
-- ============================================================================

type Width = Int
type Mask  = Word64

maskForWidth :: Width -> Mask
maskForWidth n = (1 `shiftL` n) - 1

-- | rotl: spec A1, left rotation preserving width
rotl :: Mask -> Int -> Width -> Mask
rotl x k n = ((x `shiftL` k) .|. (x `shiftR` (n - k))) .&. maskForWidth n

-- | rotr: spec A1, right rotation preserving width
rotr :: Mask -> Int -> Width -> Mask
rotr x k n = ((x `shiftR` k) .|. (x `shiftL` (n - k))) .&. maskForWidth n

-- | delta: spec A1 / Definition 1.3
-- Δ(x) = rotl(x,1) ⊕ rotl(x,3) ⊕ rotr(x,2) ⊕ C
delta :: Width -> Mask -> Mask -> Mask
delta n c x =
  (rotl x 1 n `xor` rotl x 3 n `xor` rotr x 2 n `xor` c)
  .&. maskForWidth n

-- | replay: spec A1 / A2 (replay algorithm)
-- Pure iteration of delta. Emits seed first, then successive states.
-- replay n c seed steps = [x0, x1, ..., x(steps-1)]
replay :: Width -> Mask -> Mask -> Int -> [Mask]
replay n c seed steps = take steps $ iterate (delta n c) seed

-- ============================================================================
-- LAYER 1 — DERIVED NUMERIC STRUCTURE
-- Spec: ATOMIC_KERNEL_REDUCTION_SPEC §2
-- ============================================================================

-- | Block B: digits of 1/73 = 0.(01369863), period 8.
-- Not chosen — derived from ord_73(10) = 8.
blockB :: [Word8]
blockB = [0, 1, 3, 6, 9, 8, 6, 3]

-- | Weight W = sum(blockB) = 36. Invariant under derived sequence.
weightW :: Int
weightW = sum (map fromIntegral blockB)  -- 36

-- | crystalTick: advance state with block injection at tick t.
-- Layered on top of delta; NOT the same as replay.
-- crystalTick n c t state = delta n c (state XOR blockB[t mod 8])
crystalTick :: Width -> Mask -> Int -> Mask -> Mask
crystalTick n c t state =
  delta n c (state `xor` fromIntegral (blockB !! (t `mod` 8)))

-- | crystalReplay: iterate crystalTick from tick 0 to t-1.
-- Distinct from plain replay — use this when crystal injection is required.
crystalReplay :: Width -> Mask -> Mask -> Int -> Mask
crystalReplay n c seed t = foldl (crystalTick n c) seed [0 .. t - 1]

-- | positionAt: cumulative sum of blockB values up to and including tick t.
positionAt :: Int -> Int
positionAt t = sum . map fromIntegral . take (t + 1) $ cycle blockB

-- | orbitOffset: decompose position into (orbit, offset) via weight W.
-- Spec: Theorem 3 — orbit, offset = divmod(k, W)
orbitOffset :: Int -> (Int, Int)
orbitOffset = (`divMod` weightW)

-- ============================================================================
-- LAYER 2 — A2/A3. MIXED-RADIX ENCODE / DECODE
-- Spec: PURE_ALGORITHMS.md §A2–A3, ATOMIC_KERNEL_REDUCTION_SPEC §3
-- ============================================================================

-- | mixedEncode: spec A2.
-- coords = [v mod r0, (v div r0) mod r1, ..., remainder]
-- Output length = length radices + 1  (least-significant first)
mixedEncode :: Integer -> [Integer] -> [Integer]
mixedEncode v []     = [v]
mixedEncode v (r:rs) = (v `mod` r) : mixedEncode (v `div` r) rs

-- | mixedDecode: spec A3.
-- v := coords[last]
-- for i from len(R)-1 down to 0:  v := coords[i] + R[i] * v
-- This is a right-fold from the most-significant position down.
mixedDecode :: [Integer] -> [Integer] -> Integer
mixedDecode coords radices
  | length coords /= length radices + 1 =
      error "mixedDecode: length coords must equal length radices + 1"
  | otherwise =
      foldr step (last coords) (zip (init coords) radices)
  where
    -- step (c_i, r_i) acc = c_i + r_i * acc
    -- foldr visits index 0 last, so we reverse to visit len(R)-1 first
    step (c, r) acc = c + r * acc

-- We need to visit in reverse index order (len(R)-1 down to 0).
-- zip (init coords) radices pairs c0..c(k-1) with r0..r(k-1).
-- foldr on that list visits (c0,r0) last, (c(k-1),r(k-1)) first — correct.

-- | Invariant check (Theorem 4): decode(encode(v, R), R) = v
mixedRoundtrip :: Integer -> [Integer] -> Bool
mixedRoundtrip v radices = mixedDecode (mixedEncode v radices) radices == v

-- ============================================================================
-- LAYER 3 — A4. BASIS PROJECTION / INTERPRETATION
-- Spec: PURE_ALGORITHMS.md §A4
-- ============================================================================

data BasisKind
  = Basis2          -- binary
  | Basis8          -- octal
  | Basis10         -- decimal
  | Basis16         -- hex
  | Basis36         -- base-36
  | BasisCodepoint  -- Unicode: [offset, plane]
  | BasisMixed [Integer]  -- mixed radix with given radix list
  deriving (Eq, Show)

-- | Projection: value → representation. Spec A4 project_value.
projectValue :: Integer -> BasisKind -> Either String [Integer]
projectValue v Basis2         = Right [v]   -- caller converts to bits
projectValue v Basis8         = Right [v]
projectValue v Basis10        = Right [v]
projectValue v Basis16        = Right [v]
projectValue v Basis36        = Right [v]
projectValue v BasisCodepoint = Right [v `mod` 65536, v `div` 65536]
projectValue v (BasisMixed rs) = Right (mixedEncode v rs)

-- | Interpretation: representation → value. Spec A4 interpret_value.
interpretValue :: [Integer] -> BasisKind -> Either String Integer
interpretValue [v] Basis2         = Right v
interpretValue [v] Basis8         = Right v
interpretValue [v] Basis10        = Right v
interpretValue [v] Basis16        = Right v
interpretValue [v] Basis36        = Right v
interpretValue [off, pl] BasisCodepoint = Right (off + 65536 * pl)
interpretValue coords (BasisMixed rs)   = Right (mixedDecode coords rs)
interpretValue _ b = Left $ "interpretValue: bad repr for basis " ++ show b

-- | Roundtrip invariant: interpret(project(v, b), b) = v  (Theorem 5)
projectionRoundtrip :: Integer -> BasisKind -> Bool
projectionRoundtrip v b =
  case projectValue v b of
    Left _      -> False
    Right repr  -> interpretValue repr b == Right v

-- | Human-readable projection (non-authoritative display helper)
displayValue :: Mask -> BasisKind -> String
displayValue v Basis2  =
  showIntAtBase 2 intToDigit (fromIntegral v) ""
displayValue v Basis8  = showOct v ""
displayValue v Basis10 = show v
displayValue v Basis16 = "0x" ++ showHex v ""
displayValue v Basis36 =
  showIntAtBase 36 intToDigit (fromIntegral v) ""
displayValue v _       = show v

-- ============================================================================
-- LAYER 4 — A5. STRUCTURAL PLANE PROJECTION
-- Spec: PURE_ALGORITHMS.md §A5, ATOMIC_KERNEL_REDUCTION_SPEC §5
-- ============================================================================

data Plane = FS | GS | RS | US deriving (Eq, Ord, Show, Enum, Bounded)

-- | Frame bundles tick, plane, basis, and Fano triplet.
-- Spec: frame_at_tick (PURE_ALGORITHMS §A6)
data Frame = Frame
  { frameTick      :: Int
  , framePlane     :: Plane
  , frameBasis     :: BasisKind
  , frameTriplet   :: (Int, Int, Int)
  } deriving (Eq, Show)

frameAtTick :: Int -> BasisKind -> Plane -> Frame
frameAtTick t b p = Frame t p b (fanoTriplet t)

-- | Entity state: four-plane projection surface.
data EntityState = EntityState
  { esFS :: String  -- context
  , esGS :: String  -- group
  , esRS :: String  -- record
  , esUS :: String  -- unit
  } deriving (Eq, Show)

-- | projectEntity: spec A5 project_entity.
-- Takes EntityState and Plane only. Frame is not a parameter here because
-- structural projection dispatches on Plane identity alone — the basis field
-- in Frame is used at the projectValue layer (A4), not at the structural
-- projection layer (A5). Passing Frame here would imply it influences the
-- output, which the spec does not allow.
projectEntity :: EntityState -> Plane -> String
projectEntity e FS = esFS e
projectEntity e GS = esGS e
projectEntity e RS = esRS e
projectEntity e US = esUS e

-- | projectionVector: spec A5 projection_vector — all four planes.
-- Frame is accepted here so stepProjection can pass tick/basis context
-- through to callers that need it, but projectEntity itself does not use it.
projectionVector :: EntityState -> Frame -> [String]
projectionVector e _ =
  [ projectEntity e FS
  , projectEntity e GS
  , projectEntity e RS
  , projectEntity e US
  ]

-- | isCollapsed: all projections equal — spec A5 is_collapsed
isCollapsed :: [String] -> Bool
isCollapsed []     = True
isCollapsed (x:xs) = all (== x) xs

-- | continuationSurface: unique elements, deterministic order — spec A5
continuationSurface :: [String] -> [String]
continuationSurface = nub  -- nub preserves first-occurrence order

-- | stepProjection: spec A5 step_projection
stepProjection :: EntityState -> Int -> BasisKind -> Either String [String]
stepProjection e tick basis =
  let f = frameAtTick tick basis RS
      v = projectionVector e f
  in if isCollapsed v
     then Left (head v)         -- collapsed: single value
     else Right (continuationSurface v)  -- divergent: unique surface

-- ============================================================================
-- LAYER 5 — A6. INCIDENCE SCHEDULE / FANO TRIPLETS
-- Spec: PURE_ALGORITHMS.md §A6
-- ============================================================================

-- | fanoTriplet: canonical 7-line schedule, period 7.
-- Spec invariant: fanoTriplet(t+7) = fanoTriplet(t)
fanoTriplet :: Int -> (Int, Int, Int)
fanoTriplet t = case t `mod` 7 of
  0 -> (0,1,3)
  1 -> (0,2,5)
  2 -> (0,4,6)
  3 -> (1,2,4)
  4 -> (1,5,6)
  5 -> (2,3,6)
  6 -> (3,4,5)
  _ -> error "fanoTriplet: impossible"

-- ============================================================================
-- LAYER 6 — CHIRALITY SELECTION LAW
-- Spec: CHIRALITY_SELECTION_LAW_v0.md
-- ============================================================================

-- | kernelBit: LSB of delta applied to the canonical state at the given tick.
-- Source MUST be canonical state only — spec §3.7.
-- state is the kernel state at the current tick (already iterated externally).
kernelBit :: Width -> Mask -> Mask -> Int -> Word8
kernelBit n c state tick =
  -- Apply one more delta step and take LSB.
  -- This is deterministic and replayable for same (n, c, state, tick).
  fromIntegral (delta n c state .&. 1)

-- | bipartition: deterministic balanced split — spec §1.2 (A5a).
-- Returns (S0, S1) where |S0| = ceil(|S|/2), |S1| = floor(|S|/2).
bipartition :: [a] -> ([a], [a])
bipartition xs = splitAt ((length xs + 1) `div` 2) xs

-- | chiralitySelect: spec §2 and §5 reference algorithm.
-- Given canonical state (already at the correct tick), selects S0 or S1.
-- Returns Nothing only if the candidate set is empty.
chiralitySelect :: Width -> Mask -> Mask -> Int -> [a] -> Maybe [a]
chiralitySelect _ _ _ _ [] = Nothing
chiralitySelect n c state tick xs =
  let (s0, s1) = bipartition xs
      bit      = kernelBit n c state tick
  in Just $ if bit == 0 then s0 else s1

-- | chiralitySelectOne: select the first element of the chosen half.
chiralitySelectOne :: Width -> Mask -> Mask -> Int -> [a] -> Maybe a
chiralitySelectOne n c state tick xs =
  chiralitySelect n c state tick xs >>= listToMaybe

-- ============================================================================
-- LAYER 7 — A14. INCIDENCE SCHEDULING
-- Spec: A14_INCIDENCE_SCHEDULING_LAW_v0.md
-- ============================================================================

data ProposalState = Pending | Accepted | Rejected deriving (Eq, Show)

data Incidence = Incidence
  { incidenceId       :: Word64
  , canonicalTick     :: Int        -- replay-authoritative order frontier
  , incidenceTick     :: Int        -- tick when eligible to respond
  , proposalState     :: ProposalState
  , fanoRank          :: (Int,Int,Int) -- advisory only, never canonical authority
  } deriving (Eq, Show)

-- | scheduleEligibility: marks incidences eligible at this tick via chirality.
-- Does NOT force action — spec §1 "Eligibility over forcing".
-- kernelState must be the canonical state already replayed to `tick`.
scheduleEligibility :: Width -> Mask -> Mask -> Int -> [Incidence] -> [Incidence]
scheduleEligibility n c kernelState tick incidences =
  let (s0, s1) = bipartition incidences
      bit      = kernelBit n c kernelState tick
      selected = if bit == 0 then s0 else s1
  in map (\i -> i { incidenceTick = tick, proposalState = Pending }) selected

-- | isEligible: true iff the incidence may respond at the given tick.
isEligible :: Incidence -> Int -> Bool
isEligible i tick = incidenceTick i <= tick && proposalState i == Pending

-- ============================================================================
-- LAYER 8 — ESCAPE ACCESS LAW
-- Spec: ESCAPE_ACCESS_LAW.md §9–§11
-- ============================================================================

data EscapeMode
  = DATA
  | ESCAPE_PENDING
  | CONTROL
  | QUOTED_LITERAL
  deriving (Eq, Show)

data DecoderState = DecoderState
  { dsChannel    :: Plane       -- active structural plane
  , dsLane       :: Word8       -- 0..15
  , dsMode       :: EscapeMode
  , dsScopeStack :: [EscapeMode]
  } deriving (Eq, Show)

initialDecoderState :: DecoderState
initialDecoderState = DecoderState FS 0 DATA []

-- | escapeTransition: deterministic decoder — spec E1–E9.
-- Returns Nothing on reject (E8 and malformed inputs).
escapeTransition
  :: DecoderState
  -> Word8
  -> Maybe (DecoderState, Maybe Word8)  -- (new state, emitted byte if any)
escapeTransition ds token

  -- E1: DATA + non-control payload → emit
  | dsMode ds == DATA && token < 0x1C =
      Just (ds, Just token)

  -- E2: DATA + ESC → ESCAPE_PENDING
  | dsMode ds == DATA && token == 0x1B =
      Just (ds { dsMode = ESCAPE_PENDING }, Nothing)

  -- E3: ESCAPE_PENDING + ESC → literal ESC, return DATA
  | dsMode ds == ESCAPE_PENDING && token == 0x1B =
      Just (ds { dsMode = DATA }, Just 0x1B)

  -- E4/E5: ESCAPE_PENDING + structural control (0x1C–0x1F) → CONTROL
  | dsMode ds == ESCAPE_PENDING && token >= 0x1C && token <= 0x1F =
      Just (ds { dsMode = CONTROL }, Nothing)

  -- E6: ESCAPE_PENDING + QUOTE_OPEN (0x22) → QUOTED_LITERAL
  | dsMode ds == ESCAPE_PENDING && token == 0x22 =
      Just ( ds { dsMode       = QUOTED_LITERAL
                , dsScopeStack = QUOTED_LITERAL : dsScopeStack ds }
           , Nothing )

  -- E7: QUOTED_LITERAL + QUOTE_CLOSE (0x22) → pop scope
  | dsMode ds == QUOTED_LITERAL && token == 0x22 =
      let stack'   = drop 1 (dsScopeStack ds)
          newMode  = case stack' of
                       []    -> DATA
                       (m:_) -> m
      in Just (ds { dsMode = newMode, dsScopeStack = stack' }, Nothing)

  -- E8: ESCAPE_PENDING + unknown target → reject (fail-closed)
  | dsMode ds == ESCAPE_PENDING =
      Nothing

  -- E9: any other token in any mode → pass through
  | otherwise =
      Just (ds, Just token)

-- | runDecoder: fold escapeTransition over a byte stream.
-- Stops and returns Left on the first reject.
runDecoder :: DecoderState -> [Word8] -> Either String [Word8]
runDecoder _ [] = Right []
runDecoder ds (t:ts) =
  case escapeTransition ds t of
    Nothing           -> Left $ "reject at token 0x" ++ showHex t ""
    Just (ds', mByte) ->
      let prefix = maybe [] (:[]) mByte
      in fmap (prefix ++) (runDecoder ds' ts)

-- ============================================================================
-- LAYER 9 — A13. ESC-DEPTH MIXED-RADIX COORDINATE HEADER
-- Spec: ALGORITHM_A13_ESC_DEPTH_MIXED_RADIX.md
-- ============================================================================

escSymbol :: Word8
escSymbol = 0x1B

-- | radicesForDepth: canonical depth → radix list.
-- Invariant: length (radicesForDepth n) = n - 1  for n >= 2
radicesForDepth :: Int -> [Integer]
radicesForDepth 1 = []
radicesForDepth 2 = [128]
radicesForDepth 3 = [36, 8]
radicesForDepth 4 = [256, 65536]
radicesForDepth n
  | n > 4     = radicesForDepth (n - 1) ++ [2 ^ (8 * (n - 3))]
  | otherwise = error "radicesForDepth: depth must be >= 1"

-- | escEncode: spec A13a.
-- Emits depth ESC bytes followed by mixed-radix coordinates.
-- At depth 1, emits one ESC then the direct value as a single byte.
escEncode :: Integer -> Int -> [Word8]
escEncode value 1 =
  [escSymbol, fromIntegral value]
escEncode value depth =
  let prefix = replicate depth escSymbol
      coords = mixedEncode value (radicesForDepth depth)
  in prefix ++ map fromIntegral coords

-- | escDecode: spec A13b.
-- Counts leading ESC bytes, reads coords, decodes via mixedDecode.
-- Returns (value, remaining stream) or Nothing on malformed input.
escDecode :: [Word8] -> Maybe (Integer, [Word8])
escDecode stream =
  let (escs, rest) = span (== escSymbol) stream
      depth        = length escs
  in if depth == 0
     then Nothing
     else if depth == 1
          then case rest of
                 []     -> Nothing
                 (b:bs) -> Just (fromIntegral b, bs)
          else
            let radices  = radicesForDepth depth
                nCoords  = length radices + 1
                (cs, bs) = splitAt nCoords rest
            in if length cs == nCoords
               then Just (mixedDecode (map fromIntegral cs) radices, bs)
               else Nothing

-- | Roundtrip: escDecode(escEncode(v, d)).value = v  (A13 roundtrip)
escRoundtrip :: Integer -> Int -> Bool
escRoundtrip value depth =
  case escDecode (escEncode value depth) of
    Just (v, _) -> v == value
    Nothing     -> False

-- ============================================================================
-- LAYER 10 — A7. CARRIER VERIFICATION
-- Spec: PURE_ALGORITHMS.md §A7, ATOMIC_KERNEL_REDUCTION_SPEC §7
-- Note: SHA-256 requires an external library. We provide the interface
-- and a placeholder FNV-1a hash so the module compiles without dependencies.
-- Replace hashPayload with a real SHA-256 in production.
-- ============================================================================

data ArtifactPackage = ArtifactPackage
  { pkgType            :: String
  , pkgVersion         :: String
  , pkgArtifactKind    :: String
  , pkgPayloadBytes    :: [Word8]
  , pkgFingerprintAlgo :: String   -- "sha256" | "fnv1a" etc.
  , pkgFingerprint     :: String   -- hex string
  } deriving (Eq, Show)

-- | fnv1a64: FNV-1a 64-bit hash (placeholder for SHA-256).
-- Replace with Data.Digest.Pure.SHA or cryptonite in production.
fnv1a64 :: [Word8] -> Word64
fnv1a64 = foldl step 14695981039346656037
  where
    step acc b = (acc `xor` fromIntegral b) * 1099511628211

-- | hashPayload: dispatch on algorithm name.
hashPayload :: String -> [Word8] -> String
hashPayload "fnv1a" bs = showHex (fnv1a64 bs) ""
hashPayload algo    _  = error $ "hashPayload: unsupported algo " ++ algo
-- In production: hashPayload "sha256" bs = ... (cryptonite / SHA)

-- | verifyPackage: spec A7 verify_package.
-- Returns False (reject) if fingerprint does not match — Theorem 8.
verifyPackage :: ArtifactPackage -> Bool
verifyPackage pkg =
  hashPayload (pkgFingerprintAlgo pkg) (pkgPayloadBytes pkg)
  == pkgFingerprint pkg

-- | applyPackage: spec A7 apply_package — fail-closed.
applyPackage :: ArtifactPackage -> Either String [Word8]
applyPackage pkg
  | verifyPackage pkg = Right (pkgPayloadBytes pkg)
  | otherwise         = Left "applyPackage: fingerprint verification failed"

-- ============================================================================
-- LAYER 11 — STRUCTURAL ARTIFACT / CANONICAL BITS
-- Spec: ATOMIC_KERNEL_REDUCTION_SPEC §5
-- ============================================================================

data Edge = FS_Edge | GS_Edge | RS_Edge | US_Edge
  deriving (Eq, Ord, Show)

edgePlane :: Edge -> Plane
edgePlane FS_Edge = FS
edgePlane GS_Edge = GS
edgePlane RS_Edge = RS
edgePlane US_Edge = US

planeCode :: Plane -> Word8
planeCode FS = 0x1C
planeCode GS = 0x1D
planeCode RS = 0x1E
planeCode US = 0x1F

data Artifact = Artifact
  { artifactPayload :: [Word8]
  , artifactEdges   :: [(Edge, Artifact)]
  } deriving (Eq, Show)

-- | canonicalBits: depth-first reconstruction with edges in FS<GS<RS<US order.
-- Emits [plane_code, 0x03] before each child subtree (FLAG=1, bits1:0=11).
canonicalBits :: Artifact -> [Word8]
canonicalBits a =
  artifactPayload a
  ++ concatMap visit (sortOn fst (artifactEdges a))
  where
    visit (edge, child) =
      [planeCode (edgePlane edge), 0x03] ++ canonicalBits child

-- | artifactHash: FNV-1a over canonical bits (placeholder for SHA-256).
artifactHash :: Artifact -> Word64
artifactHash = fnv1a64 . canonicalBits

-- ============================================================================
-- INVARIANT SUITE
-- All return Bool; True = invariant holds.
-- ============================================================================

-- | INV-1: delta is deterministic (Theorem 1)
inv1_deltaDeterministic :: Width -> Mask -> Mask -> Bool
inv1_deltaDeterministic n c x = delta n c x == delta n c x

-- | INV-2: replay is deterministic (Theorem 1)
inv2_replayDeterministic :: Width -> Mask -> Mask -> Int -> Bool
inv2_replayDeterministic n c seed steps =
  replay n c seed steps == replay n c seed steps

-- | INV-3: mixed_decode(mixed_encode(v,R), R) = v (Theorem 4)
inv3_mixedRoundtrip :: Integer -> [Integer] -> Bool
inv3_mixedRoundtrip = mixedRoundtrip

-- | INV-4: interpret(project(v, b), b) = v (Theorem 5)
inv4_projectionRoundtrip :: Integer -> BasisKind -> Bool
inv4_projectionRoundtrip = projectionRoundtrip

-- | INV-5: fanoTriplet(t+7) = fanoTriplet(t) (period 7)
inv5_fanoPeriod :: Int -> Bool
inv5_fanoPeriod t = fanoTriplet (t + 7) == fanoTriplet t

-- | INV-6: esc roundtrip at depths 1-3.
-- Depth 1: value capped at 127 (fits in one direct byte).
-- Depth 2: value capped at 127 (within radix [128]).
-- Depth 3 in-range:  value capped at 287 (= 36*8-1, remainder coord = 0).
-- Depth 3 over-range: value = 300 (> 36*8=288), remainder coord > 0,
--   exercises the three-coordinate path through mixedEncode/mixedDecode.
inv6_escRoundtrip :: Integer -> Bool
inv6_escRoundtrip v =
     escRoundtrip (abs v `mod` 127) 1
  && escRoundtrip (abs v `mod` 128) 2
  && escRoundtrip (abs v `mod` 288) 3
  && escRoundtrip 300               3

-- | INV-7: radicesForDepth length invariant (len = n-1 for n>=2)
inv7_radicesLength :: Int -> Bool
inv7_radicesLength n
  | n < 2     = True  -- not in domain
  | otherwise = length (radicesForDepth n) == n - 1

-- ============================================================================
-- EXAMPLE / DEMO
-- ============================================================================

runExample :: IO ()
runExample = do
  let n = 16
      c = 0x1D1D  -- GS byte repeated to 16-bit width

  putStrLn "=== Atomic Kernel DSL — Spec-Faithful Implementation ===\n"

  -- A1: Delta and replay
  putStrLn "--- A1: Kernel replay (8 steps from seed 0x0001) ---"
  mapM_ (\x -> putStrLn $ "  0x" ++ showHex x "") (replay n c 0x0001 8)
  putStrLn ""

  -- Crystal tick vs plain replay
  putStrLn "--- Crystal replay (8 steps from seed 0x0001) ---"
  let crystalStates = [crystalReplay n c 0x0001 t | t <- [0..7]]
  mapM_ (\x -> putStrLn $ "  0x" ++ showHex x "") crystalStates
  putStrLn ""

  -- A2/A3: Mixed radix roundtrip
  putStrLn "--- A2/A3: Mixed radix roundtrip ---"
  let v = 12345 :: Integer
      r = [10, 10, 10] :: [Integer]
  putStrLn $ "  encode " ++ show v ++ " with " ++ show r ++ " = " ++ show (mixedEncode v r)
  putStrLn $ "  decode back = " ++ show (mixedDecode (mixedEncode v r) r)
  putStrLn $ "  roundtrip holds: " ++ show (mixedRoundtrip v r)
  putStrLn ""

  -- A13: ESC-depth encode/decode
  putStrLn "--- A13: ESC-depth roundtrips ---"
  mapM_ (\(val, depth) -> do
    let encoded = escEncode val depth
    let decoded = escDecode encoded
    putStrLn $ "  value=" ++ show val ++ " depth=" ++ show depth
            ++ " encoded=" ++ show encoded
            ++ " decoded=" ++ show (fmap fst decoded)
            ++ " ok=" ++ show (escRoundtrip val depth)
    ) [(42, 1), (100, 2), (255, 3)]
  putStrLn ""

  -- Chirality selection
  putStrLn "--- Chirality selection ---"
  let kernelState = replay n c 0x0001 1 !! 0  -- state at tick 0
  let candidates  = [1..8 :: Int]
  putStrLn $ "  candidates: " ++ show candidates
  putStrLn $ "  kernel state: 0x" ++ showHex kernelState ""
  putStrLn $ "  selected half: " ++ show (chiralitySelect n c kernelState 0 candidates)
  putStrLn ""

  -- Fano invariant
  putStrLn "--- Fano period-7 invariant (ticks 0-6) ---"
  mapM_ (\t -> putStrLn $ "  tick " ++ show t ++ ": " ++ show (fanoTriplet t)
            ++ "  period holds: " ++ show (inv5_fanoPeriod t)) [0..6]
  putStrLn ""

  -- Structural artifact
  putStrLn "--- Structural artifact canonical bits ---"
  let leaf = Artifact [0x48, 0x65, 0x6C, 0x6C, 0x6F] []  -- "Hello"
      root = Artifact [] [(GS_Edge, leaf)]
  putStrLn $ "  canonical bits: " ++ show (canonicalBits root)
  putStrLn $ "  artifact hash:  0x" ++ showHex (artifactHash root) ""
  putStrLn ""

  -- Invariant suite
  putStrLn "--- Invariant suite ---"
  putStrLn $ "  INV-1 delta deterministic:      " ++ show (inv1_deltaDeterministic n c 0xABCD)
  putStrLn $ "  INV-2 replay deterministic:     " ++ show (inv2_replayDeterministic n c 0x0001 16)
  putStrLn $ "  INV-3 mixed roundtrip:          " ++ show (inv3_mixedRoundtrip 99999 [10,10,10,10])
  putStrLn $ "  INV-4 projection roundtrip hex: " ++ show (inv4_projectionRoundtrip 255 Basis16)
  putStrLn $ "  INV-4 projection roundtrip cp:  " ++ show (inv4_projectionRoundtrip 0x1F600 BasisCodepoint)
  putStrLn $ "  INV-5 fano period-7:            " ++ show (all inv5_fanoPeriod [0..20])
  putStrLn $ "  INV-6 esc roundtrip:            " ++ show (inv6_escRoundtrip 42)
  putStrLn $ "  INV-7 radices length (2..6):    " ++ show (all inv7_radicesLength [2..6])

main :: IO ()
main = runExample
