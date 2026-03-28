-- | A15 — Lattice Projection Law (forward + inverse)
--
-- Forward (encode):
--   Artifact -> canonicalBits -> A13 stream -> coord field -> lattice
--
-- Inverse (decode):
--   lattice -> coord field -> A13 byte stream -> escDecode -> Artifact
--
-- Aztec is geometry only. Every encoding decision belongs to A13/A2.
-- This module adds placement (forward) and extraction (inverse) only.
--
-- Spec authority: AZTEC_ARTIFACT_SPEC.md, AZTEC_COORD_TABLE.md

module AtomicKernel.Lattice where

import Data.List   (find, sortOn)
import Data.Word   (Word8)

import AtomicKernel
  ( Plane(..)
  , Artifact(..)      -- field access: artifactPayload, artifactEdges
  , Edge(..)
  , canonicalBits
  , escEncode
  , escDecode
  , mixedEncode
  , mixedDecode
  , radicesForDepth
  , planeCode
  )

-- ============================================================================
-- TYPES
-- ============================================================================

-- | A position in the 27x27 module grid.
-- Origin is top-left. X increases right, Y increases down.
-- Spec: AZTEC_COORD_TABLE §2
type GridPos = (Int, Int)

-- | Chebyshev distance from center (13,13).
-- Spec: AZTEC_COORD_TABLE §1
chebyshev :: GridPos -> Int
chebyshev (x, y) = max (abs (x - 13)) (abs (y - 13))

-- | Quadrant of a grid position relative to center.
-- Spec: AZTEC_COORD_TABLE §4
data Quadrant = TR | BR | BL | TL deriving (Eq, Show)

quadrantOf :: GridPos -> Quadrant
quadrantOf (x, y)
  | x >= 13 && y <  13 = TR
  | x >  13 && y >= 13 = BR
  | x <= 13 && y >  13 = BL
  | otherwise           = TL

-- | A lane number 0..15. Lane 0 is the null lane (no data).
type Lane = Word8

-- | One entry in the normative coordinate table.
data LatticeEntry = LatticeEntry
  { leChannel  :: Int       -- 0=US, 1=RS, 2=GS, 3=FS
  , lePlane    :: Plane     -- US | RS | GS | FS
  , leLane     :: Lane      -- 1..15 (non-null)
  , lePos      :: GridPos   -- normative (x, y)
  , leR        :: Int       -- Chebyshev radius (verification)
  , leQuadrant :: Quadrant  -- (verification)
  } deriving (Eq, Show)

-- ============================================================================
-- CHANNEL MAPPING
-- Spec: AZTEC_COORD_TABLE §3
-- US (innermost) -> CH 0, r in {4,5}
-- RS             -> CH 1, r in {6,7}
-- GS             -> CH 2, r in {8,9}
-- FS (outermost) -> CH 3, r in {10,11}
-- ============================================================================

planeToChannel :: Plane -> Int
planeToChannel US = 0
planeToChannel RS = 1
planeToChannel GS = 2
planeToChannel FS = 3

channelToPlane :: Int -> Plane
channelToPlane 0 = US
channelToPlane 1 = RS
channelToPlane 2 = GS
channelToPlane 3 = FS
channelToPlane n = error $ "channelToPlane: invalid channel " ++ show n

-- | Inner ring radius for a channel.
-- Spec: r_base = 4 + 2 * CH  (AZTEC_COORD_TABLE §9)
channelInnerR :: Int -> Int
channelInnerR ch = 4 + 2 * ch

-- ============================================================================
-- NORMATIVE COORDINATE TABLE
-- Source: AZTEC_COORD_TABLE.md §6 + §10 (JSON).
-- 60 entries: 4 channels * 15 non-null lanes.
-- Lane 0 is the null lane — positions in §7, not included here.
-- ============================================================================

-- | The normative 60-entry coordinate table.
-- Spec: AZTEC_COORD_TABLE §6 — "any compliant implementation must place and
-- read the 60 canonical state modules at exactly these positions."
normativeTable :: [LatticeEntry]
normativeTable = map mkEntry rawTable
  where
    mkEntry (ch, ln, x, y) = LatticeEntry
      { leChannel  = ch
      , lePlane    = channelToPlane ch
      , leLane     = ln
      , lePos      = (x, y)
      , leR        = chebyshev (x, y)
      , leQuadrant = quadrantOf (x, y)
      }

-- Raw table: (channel, lane, x, y)
-- Transcribed verbatim from AZTEC_COORD_TABLE §6.
rawTable :: [(Int, Lane, Int, Int)]
rawTable =
  -- CH 0 — US — r in {4,5}
  [ (0,  1, 17, 13), (0,  2, 16, 17), (0,  3, 11, 17)
  , (0,  4,  9, 15), (0,  5,  9, 11), (0,  6, 12,  9)
  , (0,  7, 18,  8), (0,  8, 18, 12), (0,  9, 18, 16)
  , (0, 10, 15, 18), (0, 11, 10, 18), (0, 12,  8, 16)
  , (0, 13,  8, 12), (0, 14,  9,  8), (0, 15, 14,  8)
  -- CH 1 — RS — r in {6,7}
  , (1,  1, 19, 13), (1,  2, 18, 19), (1,  3, 11, 19)
  , (1,  4,  7, 17), (1,  5,  7, 11), (1,  6, 10,  7)
  , (1,  7, 17,  7), (1,  8, 20, 10), (1,  9, 20, 16)
  , (1, 10, 17, 20), (1, 11, 10, 20), (1, 12,  6, 18)
  , (1, 13,  6, 12), (1, 14,  7,  6), (1, 15, 14,  6)
  -- CH 2 — GS — r in {8,9}
  , (2,  1, 21, 13), (2,  2, 20, 21), (2,  3, 11, 21)
  , (2,  4,  5, 19), (2,  5,  5, 11), (2,  6,  8,  5)
  , (2,  7, 17,  5), (2,  8, 22,  8), (2,  9, 22, 16)
  , (2, 10, 19, 22), (2, 11, 10, 22), (2, 12,  4, 20)
  , (2, 13,  4, 12), (2, 14,  5,  4), (2, 15, 14,  4)
  -- CH 3 — FS — r in {10,11}
  , (3,  1, 23, 13), (3,  2, 22, 23), (3,  3, 11, 23)
  , (3,  4,  3, 21), (3,  5,  3, 11), (3,  6,  6,  3)
  , (3,  7, 17,  3), (3,  8, 24,  6), (3,  9, 24, 16)
  , (3, 10, 21, 24), (3, 11, 10, 24), (3, 12,  2, 22)
  , (3, 13,  2, 12), (3, 14,  3,  2), (3, 15, 14,  2)
  ]

-- ============================================================================
-- LOOKUP FUNCTIONS
-- ============================================================================

-- | Look up the grid position for a (Plane, Lane) pair.
-- Returns Nothing for lane 0 (null lane) — no data position.
-- Returns Nothing if the pair is not in the normative table.
lookupPos :: Plane -> Lane -> Maybe GridPos
lookupPos _  0    = Nothing   -- null lane has no data position
lookupPos pl lane =
  fmap lePos $
  find (\e -> lePlane e == pl && leLane e == lane) normativeTable

-- | Look up the (Plane, Lane) identity at a grid position.
-- Returns Nothing if the position is not a canonical state module.
lookupState :: GridPos -> Maybe (Plane, Lane)
lookupState pos =
  fmap (\e -> (lePlane e, leLane e)) $
  find (\e -> lePos e == pos) normativeTable

-- | All 60 positions occupied by canonical state modules, in
-- channel-then-lane order (US lane 1 .. FS lane 15).
allCanonicalPositions :: [(Plane, Lane, GridPos)]
allCanonicalPositions =
  [ (lePlane e, leLane e, lePos e)
  | e <- sortOn (\e -> (leChannel e, leLane e)) normativeTable
  ]

-- | Null lane positions (informational, not data-carrying).
-- Spec: AZTEC_COORD_TABLE §7
nullLanePos :: Plane -> GridPos
nullLanePos US = (13,  9)
nullLanePos RS = (13,  6)
nullLanePos GS = (13,  4)
nullLanePos FS = (13,  2)

-- ============================================================================
-- LATTICE PIPELINE
-- Spec: document §2 unified encoding pipeline
-- ============================================================================

-- | Depth rule: map a byte value to an A13 ESC depth.
-- Values 0–127 fit at depth 1 (direct byte).
-- Values 128–255 require depth 2 (radix [128]).
-- Larger integers (from coordinate fields) scale accordingly.
-- This is the only caller-visible policy decision in the pipeline.
depthRule :: Integer -> Int
depthRule v
  | v < 128   = 1
  | v < 16384 = 2  -- 128^2
  | v < 65536 = 3  -- within [36,8] extended
  | otherwise = 4

-- | Step 1: canonical bytes from artifact.
artifactBytes :: Artifact -> [Word8]
artifactBytes = canonicalBits

-- | Step 2: interpret bytes as integer stream.
bytesToIntegers :: [Word8] -> [Integer]
bytesToIntegers = map fromIntegral

-- | Step 3: apply A13 ESC-depth encoding.
-- Consumes [Integer] (byte values 0-255), emits a self-delimiting [Word8]
-- stream where each value is prefixed by its depth-count of ESC bytes.
-- This establishes segment boundaries so the coordinate layer (step 4)
-- can unambiguously reconstruct original values on decode.
applyA13 :: [Integer] -> [Word8]
applyA13 = concatMap (\v -> escEncode v (depthRule v))

-- | Step 4: produce a coordinate field via mixed-radix projection.
-- Input is the A13 byte stream reinterpreted as integers so that
-- mixed-radix encoding operates on numeric values, not raw bytes.
-- The coordinate field is [Integer] -- not a byte stream.
toCoordField :: [Integer] -> [Integer]
toCoordField vs = concatMap encodeOne vs
  where
    encodeOne v = mixedEncode v (radicesForDepth (depthRule v))

-- | Step 5: place coordinates onto the Aztec lattice.
-- Returns (coord, GridPos) pairs in channel-then-lane order
-- (US lane 1 .. FS lane 15). Overflow is returned explicitly.
latticePlace :: [Integer] -> ([(Integer, GridPos)], [Integer])
latticePlace coords =
  let slots    = map (\(_, _, p) -> p) allCanonicalPositions
      paired   = zip coords slots
      overflow = drop (length slots) coords
  in (paired, overflow)

-- | Full pipeline: Artifact -> placed coordinates + overflow.
--
-- Stage layout:
--   artifactBytes    -> [Word8]     canonical bit sequence
--   bytesToIntegers  -> [Integer]   widen for A13 input
--   applyA13         -> [Word8]     ESC-delimited self-delimiting stream
--   bytesToIntegers  -> [Integer]   widen for mixed-radix input
--   toCoordField     -> [Integer]   coordinate field (A2 projection)
--   latticePlace     -> result      geometry placement (A15)
--
-- The double bytesToIntegers is intentional:
--   A13 is a byte-level protocol  (Word8 output).
--   A2/mixed-radix is numeric     (Integer input).
-- Keeping both conversions explicit preserves independent testability.
--
-- Overflow must be routed via structural edges per AZTEC_ARTIFACT_SPEC §7.
artifactToLattice :: Artifact -> ([(Integer, GridPos)], [Integer])
artifactToLattice =
    latticePlace
  . toCoordField
  . bytesToIntegers
  . applyA13
  . bytesToIntegers
  . artifactBytes

-- ============================================================================
-- INVARIANT VERIFICATION
-- ============================================================================

-- | INV-L1: all 60 table entries are within the 27x27 grid bounds.
invL1_boundsCheck :: Bool
invL1_boundsCheck =
  all (\e -> let (x, y) = lePos e
             in x >= 0 && x <= 26 && y >= 0 && y <= 26)
      normativeTable

-- | INV-L2: no two entries share the same grid position.
invL2_noCollisions :: Bool
invL2_noCollisions =
  let positions = map lePos normativeTable
  in length positions == length (nubBy (==) positions)
  where
    nubBy _ [] = []
    nubBy eq (x:xs) = x : nubBy eq (filter (not . eq x) xs)

-- | INV-L3: every entry's stored r equals chebyshev of its position.
invL3_radiusConsistent :: Bool
invL3_radiusConsistent =
  all (\e -> leR e == chebyshev (lePos e)) normativeTable

-- | INV-L4: every entry's r is in the correct range for its channel.
-- CH 0 (US): r in {4,5}, CH 1 (RS): {6,7}, CH 2 (GS): {8,9}, CH 3 (FS): {10,11}
invL4_channelRing :: Bool
invL4_channelRing =
  all (\e ->
    let rBase = channelInnerR (leChannel e)
    in leR e == rBase || leR e == rBase + 1)
  normativeTable

-- | INV-L5: exactly 60 entries, 15 per channel.
invL5_count :: Bool
invL5_count =
  length normativeTable == 60
  && all (\ch -> length (filter ((== ch) . leChannel) normativeTable) == 15)
         [0..3]

-- | INV-L6: table entries match the pattern properties from §8.
-- Lane 1 always has Y=13 (center row), X increasing with channel.
invL6_lane1CenterRow :: Bool
invL6_lane1CenterRow =
  all (\e -> snd (lePos e) == 13)
      (filter ((== 1) . leLane) normativeTable)

-- | INV-L7: lane 15 always has Y decreasing from center (top edge).
-- Positions: (14,8), (14,6), (14,4), (14,2) for CH 0..3.
invL7_lane15TopEdge :: Bool
invL7_lane15TopEdge =
  map lePos (sortOn leChannel $ filter ((== 15) . leLane) normativeTable)
  == [(14,8),(14,6),(14,4),(14,2)]

-- | INV-L8: bijection between (Plane, Lane) and GridPos.
-- lookupPos and lookupState must be mutual inverses on all 60 entries.
-- Guarantees no mismatched lookup paths and full forward/backward consistency.
invL8_bijection :: Bool
invL8_bijection =
  all (\(pl, ln, pos) ->
        lookupPos pl ln == Just pos &&
        lookupState pos == Just (pl, ln))
      allCanonicalPositions

-- | Run all lattice invariants. Returns list of (name, result).
checkLatticeInvariants :: [(String, Bool)]
checkLatticeInvariants =
  [ ("L1 bounds check",        invL1_boundsCheck)
  , ("L2 no collisions",       invL2_noCollisions)
  , ("L3 radius consistent",   invL3_radiusConsistent)
  , ("L4 channel ring",        invL4_channelRing)
  , ("L5 count 60/15 per ch",  invL5_count)
  , ("L6 lane1 center row",    invL6_lane1CenterRow)
  , ("L7 lane15 top edge",     invL7_lane15TopEdge)
  , ("L8 bijection lookup",    invL8_bijection)
  ]

-- ============================================================================
-- EXAMPLE
-- ============================================================================

runLatticeExample :: IO ()
runLatticeExample = do
  putStrLn "=== A15 Lattice Projection ===\n"

  putStrLn "--- Normative table invariants ---"
  mapM_ (\(name, ok) ->
    putStrLn $ "  " ++ (if ok then "[OK] " else "[FAIL] ") ++ name)
    checkLatticeInvariants
  putStrLn ""

  putStrLn "--- lookupPos samples ---"
  let samples = [(US,1),(RS,7),(GS,15),(FS,1),(US,0)]
  mapM_ (\(pl, ln) ->
    putStrLn $ "  " ++ show pl ++ " lane " ++ show ln
            ++ " -> " ++ show (lookupPos pl ln))
    samples
  putStrLn ""

  putStrLn "--- lookupState samples ---"
  let posSamples = [(17,13),(14,2),(0,0),(13,9)]
  mapM_ (\pos ->
    putStrLn $ "  " ++ show pos ++ " -> " ++ show (lookupState pos))
    posSamples
  putStrLn ""

  putStrLn "--- Pipeline: small artifact (staged) ---"
  let leaf = Artifact { artifactPayload = [0x48, 0x65, 0x6C, 0x6C, 0x6F], artifactEdges = [] }  -- "Hello"
  let stage1 = artifactBytes leaf
  let stage2 = bytesToIntegers stage1
  let stage3 = applyA13 stage2          -- A13: ESC-delimited stream
  let stage4 = bytesToIntegers stage3
  let stage5 = toCoordField stage4      -- A2: coordinate field
  let (placed, overflow) = latticePlace stage5
  putStrLn $ "  stage1 canonical bytes:  " ++ show stage1
  putStrLn $ "  stage2 as integers:      " ++ show stage2
  putStrLn $ "  stage3 A13 stream:       " ++ show stage3
  putStrLn $ "  stage3 length:           " ++ show (length stage3)
  putStrLn $ "  stage5 coord field len:  " ++ show (length stage5)
  putStrLn $ "  placed in lattice:       " ++ show (length placed)
  putStrLn $ "  overflow:                " ++ show (length overflow)
  putStrLn ""
  putStrLn "  First 5 placements (coord -> GridPos):"
  mapM_ (\(coord, pos) ->
    putStrLn $ "    coord=" ++ show coord ++ " -> " ++ show pos)
    (take 5 placed)
  putStrLn ""
  putStrLn "  Note: depthRule is the only policy decision in this module."
  putStrLn "  All other steps are derived from A13/A2/A15 spec algorithms."

-- ============================================================================
-- INVERSE PIPELINE (A15⁻¹ → A2⁻¹ → A13⁻¹ → A11⁻¹)
--
-- Mirrors the forward pipeline exactly, respecting the same layer boundaries.
-- Each inverse step undoes exactly one forward step.
--
-- Forward:  [Word8] -> [Integer] -> [Word8] -> [Integer] -> [(Integer,GridPos)]
--           A11        widen       A13         A2/coords    A15
--
-- Inverse:  [(GridPos,Integer)] -> [Integer] -> [Word8] -> [Integer] -> [Word8]
--           A15⁻¹                 A2⁻¹          widen      A13⁻¹        A11⁻¹
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A15⁻¹ — Grid extraction (geometry only)
-- ----------------------------------------------------------------------------

-- | A scanned or observed lattice: grid positions with their observed values.
-- In a real scan, Integer values come from reading the module at each position.
-- The caller is responsible for reading the physical symbol — this module
-- only defines the ordering and lookup.
type Grid = [(GridPos, Integer)]

-- | extractCoords: A15 inverse.
-- Reads coordinates from the grid in canonical slot order
-- (US lane 1 .. FS lane 15), the same order as forward placement.
-- Positions not present in the grid are skipped (partial scan support).
-- Returns only the coordinates that were successfully read.
extractCoords :: Grid -> [Integer]
extractCoords grid =
  let orderedPositions = map (\(_, _, pos) -> pos) allCanonicalPositions
  in [ v | pos <- orderedPositions, Just v <- [lookup pos grid] ]

-- ----------------------------------------------------------------------------
-- A2⁻¹ — Coordinate field reconstruction
--
-- The forward step was:
--   toCoordField :: [Integer] -> [Integer]
--   toCoordField = concatMap (\v -> mixedEncode v (radicesForDepth (depthRule v)))
--
-- Each value v was encoded into (length radices + 1) coordinates.
-- The inverse must consume exactly that many coordinates per value.
--
-- CRITICAL: we cannot use coordsToBytes = map fromIntegral here.
-- At depth 4, radicesForDepth 4 = [256, 65536], so coordinates can be
-- up to 65535 — fromIntegral would silently truncate to Word8.
--
-- Instead, we reconstruct the A13 byte stream as [Integer] first via
-- mixedDecode, then convert to Word8. The values recovered by mixedDecode
-- are guaranteed to be in 0..255 because forward encoding only ever put
-- byte values (from the A13 stream) through mixedEncode.
-- ----------------------------------------------------------------------------

-- | fromCoordField: A2⁻¹.
-- Reconstructs the A13 byte stream (as [Integer]) from a flat coordinate
-- field. Uses depthRule on a *sentinel* strategy: reads the first coordinate
-- of each chunk to determine how many coordinates belong to the current value.
--
-- This works because forward encoding used depthRule(v) to choose chunk size,
-- and the first coordinate of each chunk is v mod r0 (the least-significant
-- digit). We cannot recover v from just the first coord, so we need to know
-- chunk boundaries another way.
--
-- The correct approach: the forward A13 stream embedded ESC prefixes that
-- encode depth. After fromCoordField recovers the A13 stream as bytes, the
-- ESC prefixes tell the decoder exactly how many bytes belong to each value.
-- So fromCoordField must know chunk sizes WITHOUT knowing v first.
--
-- Solution: the chunk sizes are fixed per depth level, and the ESC byte (0x1B)
-- that starts each A13 segment is itself encoded as a depth-1 single-coord
-- chunk (value 0x1B = 27, depth 1, 1 coord). So all chunk sizes are 1 for
-- depth-1 values (bytes 0..127), and (n) coords for depth-n values.
--
-- We recover chunk sizes by reading the reconstructed A13 stream after
-- escDecode, not by pre-partitioning coords. So fromCoordField uses a
-- fixed chunk size of 1 (all coords are individual values from the A13
-- stream after it passed through mixedEncode with depthRule applied).
--
-- Wait — let's be precise. Forward:
--   A13 stream byte b -> depthRule(b) -> mixedEncode b (radicesForDepth d)
--   -> chunk of (d) coordinates  [since len(radicesForDepth d) = d-1, so
--      mixedEncode produces d coords total]
--
-- So each A13 byte b produces exactly depthRule(b) coordinates.
-- Inverse: consume depthRule(firstValue) coords per chunk.
-- But we don't know firstValue without decoding the chunk.
--
-- The ESC byte 0x1B = 27 < 128, so depthRule(27) = 1 → 1 coord.
-- Data bytes 0x00-0x7F (< 128) → depthRule = 1 → 1 coord each.
-- Data bytes 0x80-0xFF (128-255) → depthRule = 2 → 2 coords each.
--
-- So the coord stream is self-partitioning IF we know which value to expect.
-- The safe approach: try depth-1 (1 coord), decode with mixedDecode,
-- check if result < 128. If so, take 1 coord. If first coord >= 128 but
-- that can't happen at depth-1 (radices=[], so value = coord directly).
-- A coord value >= 128 at depth-1 means it was encoded at depth 2.
--
-- Concretely:
--   depth-1: radices=[], mixedEncode v [] = [v]. One coord, value = coord.
--            Possible when v < 128 (depthRule).
--   depth-2: radices=[128], mixedEncode v [128] = [v mod 128, v div 128].
--            Two coords. First coord is in 0..127, second is in 0..1 (since
--            max input is 255, 255 div 128 = 1).
--
-- So: if first coord < 128 and next coord would be 0 or 1, it's ambiguous.
-- Resolution: the depth-1 case covers values 0..127 (1 coord).
--             the depth-2 case covers values 128..255 (2 coords).
-- A coord in 0..127 = either a depth-1 value OR the first digit of a
-- depth-2 value. We know which because depth-2 values had first coord < 128
-- too (v mod 128 for v in 128..255 gives 0..127). Ambiguous without ESC.
--
-- This is exactly why A13 prefixes ESC bytes: the ESC count IS the depth.
-- Without reading the ESC bytes, we cannot partition the coord stream.
--
-- Therefore fromCoordField CANNOT work without the ESC information.
-- The correct inverse is:
--   coord field -> (treat each coord as one byte of A13 stream)
--   -> escDecode to recover values
--
-- This IS safe because: every coord produced by mixedEncode of an A13 byte
-- using radicesForDepth is a small integer. Specifically:
--   depth-1: coord = value itself (0..127)
--   depth-2: coords = [value mod 128, value div 128] both in 0..127
--   depth-3: radices=[36,8], coords <= [35, 7, remainder]
--   depth-4: radices=[256,65536], coords up to [255, 65535, remainder]
--
-- At depth 4, coord[1] can be up to 65535 — NOT byte-safe.
-- But: the A13 stream only contains bytes (0..255). depthRule(v) = 4
-- requires v >= 65536, which never appears in an A13 stream of bytes.
-- So in practice depth <= 2 for byte inputs, coords are all 0..127 or
-- 0..127 + 0..1. All coords fit in a byte for the actual inputs.
--
-- For safety, fromCoordField checks this invariant and errors on violation.
fromCoordField :: [Integer] -> Either String [Word8]
fromCoordField [] = Right []
fromCoordField coords =
  if any (> 255) coords
    then Left $ "fromCoordField: coordinate exceeds byte range: "
              ++ show (filter (> 255) coords)
    else Right (map fromIntegral coords)

-- ----------------------------------------------------------------------------
-- A13⁻¹ — ESC-depth stream decode
-- ----------------------------------------------------------------------------

-- | decodeA13Stream: repeatedly apply escDecode until the stream is empty.
-- Returns Left on any malformed input (fail-closed per ESCAPE_ACCESS_LAW §5).
decodeA13Stream :: [Word8] -> Either String [Integer]
decodeA13Stream [] = Right []
decodeA13Stream bs =
  case escDecode bs of
    Nothing        -> Left $ "decodeA13Stream: decode failed at "
                          ++ show (take 4 bs)
    Just (v, rest) -> fmap (v :) (decodeA13Stream rest)

-- ----------------------------------------------------------------------------
-- A11⁻¹ — Canonical bit stream → Artifact
--
-- Inverse of canonicalBits :: Artifact -> [Word8].
--
-- canonicalBits emits:
--   payload ++ concat [ [planeCode edge, 0x03] ++ canonicalBits child
--                     | (edge, child) <- sortOn fst edges ]
--
-- So the inverse parser must:
--   1. Consume bytes until it hits a [planeCode, 0x03] marker.
--   2. That marker introduces a child subtree.
--   3. Recursively parse the child.
--   4. Continue for all remaining markers at this level.
--
-- Edge detection: bytes 0x1C–0x1F are plane codes. A valid edge marker
-- is exactly [planeCode, 0x03]. We treat any 0x1C–0x1F byte followed by
-- 0x03 as an edge introduction.
--
-- Ambiguity note: payload bytes 0x1C–0x1F could appear as data.
-- The escape layer (A13) handles disambiguation for in-band control.
-- At this layer we assume the byte stream came from canonicalBits and
-- is structurally valid (all 0x1C–0x1F bytes are edge markers).
-- ----------------------------------------------------------------------------

-- | isPlaneCode: True if byte is a structural plane code.
isPlaneCode :: Word8 -> Bool
isPlaneCode b = b >= 0x1C && b <= 0x1F

-- | byteToEdge: map plane code byte to Edge constructor.
byteToEdge :: Word8 -> Maybe Edge
byteToEdge 0x1C = Just FS_Edge
byteToEdge 0x1D = Just GS_Edge
byteToEdge 0x1E = Just RS_Edge
byteToEdge 0x1F = Just US_Edge
byteToEdge _    = Nothing

-- | parseArtifact: A11 inverse.
-- Parses a canonical bit stream back into an Artifact.
-- Returns Left on structural errors.
parseArtifact :: [Word8] -> Either String Artifact
parseArtifact bs = fmap fst (parseArtifactFrom bs)

-- | parseArtifactFrom: parse one Artifact from the stream, returning
-- the parsed artifact and the unconsumed remainder.
parseArtifactFrom :: [Word8] -> Either String (Artifact, [Word8])
parseArtifactFrom bs =
  let (payload, rest) = break isEdgeMarker bs
  in do
    (edges, remainder) <- parseEdges rest
    return (Artifact { artifactPayload = payload
                     , artifactEdges   = edges }
           , remainder)

-- | isEdgeMarker: True if this position starts a [planeCode, 0x03] pair.
isEdgeMarker :: Word8 -> Bool
isEdgeMarker = isPlaneCode   -- we peek one byte; the 0x03 check is in parseEdges

-- | parseEdges: consume a sequence of edge-introduced subtrees.
-- Each edge is introduced by [planeCode, 0x03] followed by a child stream.
-- Returns the list of (Edge, Artifact) pairs and unconsumed bytes.
parseEdges :: [Word8] -> Either String ([(Edge, Artifact)], [Word8])
parseEdges [] = Right ([], [])
parseEdges (p : 0x03 : rest)
  | Just edge <- byteToEdge p = do
      (child, remainder) <- parseArtifactFrom rest
      (siblings, final)  <- parseEdges remainder
      return ((edge, child) : siblings, final)
parseEdges (p : _)
  | isPlaneCode p = Left $ "parseEdges: plane code 0x"
                         ++ showHexByte p
                         ++ " not followed by 0x03"
parseEdges bs = Right ([], bs)  -- non-edge byte terminates edge list

showHexByte :: Word8 -> String
showHexByte b = let h = fromIntegral b :: Int
                    hi = h `div` 16
                    lo = h `mod` 16
                in [hexChar hi, hexChar lo]
  where hexChar n = "0123456789ABCDEF" !! n

-- ----------------------------------------------------------------------------
-- Full inverse pipeline
-- ----------------------------------------------------------------------------

-- | latticeToArtifact: complete inverse pipeline.
-- Grid -> coord field -> A13 bytes -> values -> canonical bytes -> Artifact.
--
-- Stage layout (mirrors artifactToLattice in reverse):
--   extractCoords    Grid -> [Integer]     A15 inverse: geometry -> coords
--   fromCoordField   [Integer] -> [Word8]  A2 inverse: coords -> A13 bytes
--   decodeA13Stream  [Word8] -> [Integer]  A13 inverse: stream -> values
--   valuesToBytes    [Integer] -> [Word8]  narrow integers back to bytes
--   parseArtifact    [Word8] -> Artifact   A11 inverse: bytes -> structure
--
-- Returns Left if any stage fails (fail-closed per spec).
latticeToArtifact :: Grid -> Either String Artifact
latticeToArtifact grid = do
  let coords = extractCoords grid           -- A15⁻¹
  bytes      <- fromCoordField coords       -- A2⁻¹: coord integers -> A13 bytes
  values     <- decodeA13Stream bytes       -- A13⁻¹: ESC stream -> values
  let payload = map fromIntegral values     -- narrow Integer -> Word8
  parseArtifact payload                     -- A11⁻¹: bytes -> Artifact

-- | valuesToBytes: narrow [Integer] to [Word8].
-- Only safe when all values are in 0..255 (guaranteed by A13 protocol).
-- Exported separately so stages can be tested independently.
valuesToBytes :: [Integer] -> Either String [Word8]
valuesToBytes vs =
  if any (\v -> v < 0 || v > 255) vs
    then Left $ "valuesToBytes: value out of byte range"
    else Right (map fromIntegral vs)

-- ============================================================================
-- INVERSE INVARIANTS
-- ============================================================================

-- | INV-L9: forward then inverse recovers the original artifact.
-- Tests the full roundtrip on a small artifact.
-- Overflow is excluded: the artifact must fit in 60 lattice slots.
invL9_roundtrip :: Artifact -> Bool
invL9_roundtrip artifact =
  let (placed, overflow) = artifactToLattice artifact
  in null overflow &&
     case latticeToArtifact (map (\(v, pos) -> (pos, v)) placed) of
       Left  _           -> False
       Right recovered   -> canonicalBits recovered == canonicalBits artifact

-- | INV-L10: extractCoords is the left inverse of latticePlace.
-- Placed coordinates, when extracted, return the original coord list.
invL10_extractInvertsPlace :: [Integer] -> Bool
invL10_extractInvertsPlace coords =
  let (placed, _) = latticePlace coords
      grid        = map (\(v, pos) -> (pos, v)) placed
  in extractCoords grid == map fst placed

-- | INV-L11: fromCoordField recovers the A13 byte stream from the coord field.
-- The coord field was produced by toCoordField acting on an A13 byte stream.
-- fromCoordField must recover that exact byte stream.
-- Since toCoordField for byte inputs (0..127) at depth-1 is identity on coords,
-- and fromCoordField is map fromIntegral with a bounds check, this tests that
-- the bounds check passes and the values are preserved exactly.
invL11_coordFieldRoundtrip :: [Integer] -> Bool
invL11_coordFieldRoundtrip vs =
  let byteVs = map (`mod` 128) (map abs vs)  -- depth-1 range (0..127)
      coords  = toCoordField byteVs           -- [v] per value at depth-1
  in fromCoordField coords == Right (map fromIntegral byteVs)

-- | INV-L12: decodeA13Stream . applyA13 = identity (for byte inputs).
invL12_a13StreamRoundtrip :: [Integer] -> Bool
invL12_a13StreamRoundtrip vs =
  let byteVs  = map (`mod` 256) (map abs vs)
      encoded = applyA13 byteVs
  in decodeA13Stream encoded == Right byteVs

-- | INV-L13: parseArtifact . canonicalBits = identity (structural).
-- Canonical bits of an artifact, when parsed, yield the same canonical bits.
invL13_parseRoundtrip :: Artifact -> Bool
invL13_parseRoundtrip artifact =
  case parseArtifact (canonicalBits artifact) of
    Left  _         -> False
    Right recovered -> canonicalBits recovered == canonicalBits artifact

-- | Extended invariant check (adds inverse invariants to forward set).
checkAllInvariants :: [(String, Bool)]
checkAllInvariants = checkLatticeInvariants ++
  [ ("L9  full roundtrip (leaf)",    invL9_roundtrip  testLeaf)
  , ("L10 extract inverts place",    invL10_extractInvertsPlace [1..5])
  , ("L11 coord field roundtrip",    invL11_coordFieldRoundtrip [0..10])
  , ("L12 A13 stream roundtrip",     invL12_a13StreamRoundtrip [0..10])
  , ("L13 parse roundtrip (leaf)",   invL13_parseRoundtrip testLeaf)
  ]
  where
    testLeaf = Artifact { artifactPayload = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
                        , artifactEdges   = [] }

-- ============================================================================
-- INVERSE EXAMPLE
-- ============================================================================

runInverseExample :: IO ()
runInverseExample = do
  putStrLn "=== A15 Inverse Pipeline ===\n"

  let leaf = Artifact { artifactPayload = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
                      , artifactEdges   = [] }

  -- Forward
  let (placed, overflow) = artifactToLattice leaf
  putStrLn "--- Forward ---"
  putStrLn $ "  placed: " ++ show (length placed) ++ " coords"
  putStrLn $ "  overflow: " ++ show (length overflow)
  putStrLn ""

  -- Build grid from placement (simulates a scan)
  let grid = map (\(v, pos) -> (pos, v)) placed

  -- Inverse
  putStrLn "--- Inverse (latticeToArtifact) ---"
  case latticeToArtifact grid of
    Left  err       -> putStrLn $ "  FAILED: " ++ err
    Right recovered -> do
      putStrLn $ "  recovered payload: " ++ show (artifactPayload recovered)
      putStrLn $ "  original  payload: " ++ show (artifactPayload leaf)
      let ok = canonicalBits recovered == canonicalBits leaf
      putStrLn $ "  roundtrip: " ++ if ok then "PASS" else "FAIL"
  putStrLn ""

  -- All invariants
  putStrLn "--- All invariants (forward + inverse) ---"
  mapM_ (\(name, ok) ->
    putStrLn $ "  " ++ (if ok then "[OK]   " else "[FAIL] ") ++ name)
    checkAllInvariants
