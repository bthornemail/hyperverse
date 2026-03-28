-- | Automaton_v3.hs
-- Canonical stream decoupler / block-to-point-set automaton
-- with IPv6-style coordinate formatting for decoded Cartesian output.
--
-- This version extends Automaton_v2 with:
--   * IPv6-like 8x16-bit formatting for decoded coordinates
--   * dataset forms that carry rendered coordinate addresses
--   * point-set lifting that can expose symbolic geometry as IPv6-style strings
--
-- The formatter is intentionally structural:
--   Coord128 -> hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh
--
-- It is not networking; it is a canonical geometric rendering form.

module Automaton_v3
  ( Tick7(..), Tick56(..), IncidenceTime(..)
  , tick7Of, tick56Of, incidenceTimeOf

  , PointId(..), Point(..), PointSet(..), PointTuple4(..)
  , canonPoint0, samePoint, differentPoint

  , Blob(..), Block(..), Carrier(..)
  , canonBlobVoid, canonBlockZero, canonArtifact0

  , HeadToken(..), tokenizeHead8

  , Coord128(..), pointToCoord128, coord128ToIPv6Text, pointToIPv6Text

  , Dataset(..), ControlPoint(..)
  , prefixDatasets
  , liftCarrierToPointSet
  , streamToDatasets
  , datasetsToPointSet
  , datasetsToIPv6Rows

  , StepMode(..), AutoState(..), emptyState
  , stepAutomaton
  ) where

import Data.Bits
import Data.List (foldl', nub, sort)
import Data.Word (Word8, Word16, Word32, Word64)
import Numeric (showHex)

import Artifact
  ( Artifact(..), ArtifactId(..), ArtifactMeta(..), Polyhedron(..), PolyhedronKind(..) )

newtype Tick7  = Tick7  Word8 deriving (Eq, Ord, Show)
newtype Tick56 = Tick56 Word8 deriving (Eq, Ord, Show)

data IncidenceTime = IncidenceTime
  { it7  :: !Tick7
  , it56 :: !Tick56
  } deriving (Eq, Ord, Show)

tick7Of :: Word64 -> Tick7
tick7Of t = Tick7 (fromIntegral (t `mod` 7))

tick56Of :: Word64 -> Tick56
tick56Of t = Tick56 (fromIntegral (t `mod` 56))

incidenceTimeOf :: Word64 -> IncidenceTime
incidenceTimeOf t = IncidenceTime (tick7Of t) (tick56Of t)

newtype PointId = PointId Word64 deriving (Eq, Ord, Show)

data Point = Point
  { pId      :: !PointId
  , pBasisIx :: !Word32
  , pTag     :: !Word32
  } deriving (Eq, Ord, Show)

newtype PointSet = PointSet [Point]
  deriving (Eq, Show)

data PointTuple4 = PointTuple4 !Point !Point !Point !Point
  deriving (Eq, Show)

canonPoint0 :: Point
canonPoint0 = Point (PointId 0) 0 0

samePoint :: Point -> Point -> Bool
samePoint a b = pId a == pId b

differentPoint :: Point -> Point -> Bool
differentPoint a b = not (samePoint a b)

mkPoint :: IncidenceTime -> Word64 -> Word32 -> Point
mkPoint (IncidenceTime (Tick7 t7) (Tick56 t56)) seed tag =
  Point
    { pId      = PointId (seed `xor` fromIntegral t7 `xor` (fromIntegral t56 `shiftL` 8) `xor` fromIntegral tag)
    , pBasisIx = fromIntegral t7
    , pTag     = tag + fromIntegral t56
    }

data Blob = Blob
  { blobId    :: !Word64
  , blobBytes :: ![Word8]
  } deriving (Eq, Show)

data Block = Block
  { blockId      :: !Word64
  , blockPayload :: ![Word8]
  } deriving (Eq, Show)

data Carrier
  = CArtifact !Artifact
  | CBlock    !Block
  | CBlob     !Blob
  deriving (Eq, Show)

canonBlobVoid :: Blob
canonBlobVoid = Blob 0 []

canonBlockZero :: Block
canonBlockZero = Block 0 []

canonArtifact0 :: Artifact
canonArtifact0 =
  ArtifactPolyhedron
    { artId = ArtifactId 0
    , artMeta = ArtifactMeta
        { amSource = "canonArtifact0"
        , amResolution = "basis"
        , amNotes = ["canonical null artifact", "zero basis"]
        }
    , artPolyhedron = Polyhedron
        { polyKind = Derived "null"
        , polyVertices = []
        , polyFaces = []
        }
    }

data HeadToken
  = TNull
  | TEsc
  | TFS
  | TGS
  | TRS
  | TUS
  | TZero
  | TByte !Word8
  deriving (Eq, Ord, Show)

classifyByte :: Word8 -> HeadToken
classifyByte b = case b of
  0x00 -> TNull
  0x1B -> TEsc
  0x1C -> TFS
  0x1D -> TGS
  0x1E -> TRS
  0x1F -> TUS
  0x30 -> TZero
  _    -> TByte b

tokenizeHead8 :: [Word8] -> [HeadToken]
tokenizeHead8 = map classifyByte

newtype ControlPoint = ControlPoint Word32
  deriving (Eq, Ord, Show)

-- 128-bit Cartesian/projective formatting carrier.
data Coord128 = Coord128 !Word16 !Word16 !Word16 !Word16 !Word16 !Word16 !Word16 !Word16
  deriving (Eq, Ord, Show)

word16Hex4 :: Word16 -> String
word16Hex4 w =
  let s = showHex w ""
  in replicate (4 - length s) '0' ++ s

coord128ToIPv6Text :: Coord128 -> String
coord128ToIPv6Text (Coord128 a b c d e f g h) =
  concat
    [ word16Hex4 a, ":"
    , word16Hex4 b, ":"
    , word16Hex4 c, ":"
    , word16Hex4 d, ":"
    , word16Hex4 e, ":"
    , word16Hex4 f, ":"
    , word16Hex4 g, ":"
    , word16Hex4 h
    ]

pointToCoord128 :: Point -> Coord128
pointToCoord128 (Point (PointId pid) basis tag) =
  let s0 = fromIntegral ((pid `shiftR` 48) .&. 0xffff)
      s1 = fromIntegral ((pid `shiftR` 32) .&. 0xffff)
      s2 = fromIntegral ((pid `shiftR` 16) .&. 0xffff)
      s3 = fromIntegral (pid .&. 0xffff)
      s4 = fromIntegral ((fromIntegral basis :: Word64) .&. 0xffff)
      s5 = fromIntegral (((fromIntegral tag :: Word64) `shiftR` 16) .&. 0xffff)
      s6 = fromIntegral ((fromIntegral tag :: Word64) .&. 0xffff)
      s7 = fromIntegral (((pid `xor` fromIntegral basis `xor` fromIntegral tag) * 0x9e37) .&. 0xffff)
  in Coord128 s0 s1 s2 s3 s4 s5 s6 s7

pointToIPv6Text :: Point -> String
pointToIPv6Text = coord128ToIPv6Text . pointToCoord128

data Dataset
  = DS_Null
  | DS_BitBoard0
  | DS_Board0
  | DS_Artifact0
  | DS_Blob !Blob
  | DS_Block !Block
  | DS_Artifact !Artifact
  | DS_ControlPoint !ControlPoint
  | DS_Point !Point
  | DS_PointSet !PointSet
  | DS_PointTuple !PointTuple4
  | DS_IPv6Point !String
  | DS_Fragment ![Word8]
  deriving (Eq, Show)

controlPointFromTokens :: [HeadToken] -> ControlPoint
controlPointFromTokens toks =
  let cp = foldl' step 0 toks
  in ControlPoint cp
  where
    step acc tok = acc * 33 + tokenValue tok
    tokenValue t = case t of
      TNull   -> 0x00
      TEsc    -> 0x1B
      TFS     -> 0x1C
      TGS     -> 0x1D
      TRS     -> 0x1E
      TUS     -> 0x1F
      TZero   -> 0x30
      TByte w -> fromIntegral w

pointTupleFromTokens :: IncidenceTime -> [HeadToken] -> PointTuple4
pointTupleFromTokens time toks =
  let base = fromIntegral (length toks) :: Word64
      p = mkPoint time (base + 0x50) 0x50
      q = mkPoint time (base + 0x51) 0x51
      r = mkPoint time (base + 0x52) 0x52
      s = mkPoint time (base + 0x53) 0x53
  in PointTuple4 p q r s

prefixDatasets :: IncidenceTime -> [Word8] -> [Dataset]
prefixDatasets time bytes =
  let toks = tokenizeHead8 bytes
      cp   = controlPointFromTokens toks
      pt4@(PointTuple4 p _ _ _) = pointTupleFromTokens time toks
  in case toks of
      [] ->
        [DS_Null, DS_IPv6Point (pointToIPv6Text canonPoint0)]

      (TNull : TEsc : _) ->
        []

      (TZero : _) ->
        let p0 = mkPoint time 0xB170 0x01
        in [DS_BitBoard0, DS_IPv6Point (pointToIPv6Text p0)]

      (t0 : rest) | t0 /= TNull ->
        case rest of
          [] ->
            let p0 = mkPoint time 0xB0A0 0x02
            in [DS_Board0, DS_IPv6Point (pointToIPv6Text p0)]

          (t1 : rest2) | t1 /= TFS ->
            case rest2 of
              [] ->
                let p0 = mkPoint time 0xB0A0 0x02
                in [DS_Board0, DS_IPv6Point (pointToIPv6Text p0)]

              (t2 : _) | t2 /= TFS ->
                [ DS_BitBoard0
                , DS_Board0
                , DS_Artifact0
                , DS_ControlPoint cp
                , DS_PointTuple pt4
                , DS_IPv6Point (pointToIPv6Text p)
                ]

              _ ->
                let p0 = mkPoint time 0xB0A0 0x02
                in [DS_Board0, DS_IPv6Point (pointToIPv6Text p0)]

          _ ->
            let p0 = mkPoint time 0xB0A0 0x02
            in [DS_Board0, DS_IPv6Point (pointToIPv6Text p0)]

      _ ->
        [DS_Fragment bytes]

datasetPoint :: IncidenceTime -> Dataset -> Maybe Point
datasetPoint time ds = case ds of
  DS_Null              -> Just canonPoint0
  DS_BitBoard0         -> Just (mkPoint time 0xB170 0x01)
  DS_Board0            -> Just (mkPoint time 0xB0A0 0x02)
  DS_Artifact0         -> Just (mkPoint time 0xA170 0x03)
  DS_ControlPoint (ControlPoint cp) -> Just (mkPoint time (fromIntegral cp) 0x04)
  DS_Point p           -> Just p
  DS_PointSet (PointSet (p:_)) -> Just p
  DS_PointTuple (PointTuple4 p _ _ _) -> Just p
  DS_Blob (Blob bid _) -> Just (mkPoint time bid 0x05)
  DS_Block (Block bid _) -> Just (mkPoint time bid 0x06)
  DS_Artifact art      -> Just (mkPoint time (artifactId64 art) 0x07)
  DS_Fragment bs       -> Just (mkPoint time (fromIntegral (length bs)) 0x08)
  DS_IPv6Point _       -> Nothing
  where
    artifactId64 a = case a of
      ArtifactTriangleMesh{artId = ArtifactId i} -> i
      ArtifactTetraMesh{artId = ArtifactId i}    -> i
      ArtifactPolyhedron{artId = ArtifactId i}   -> i

datasetsToPointSet :: IncidenceTime -> [Dataset] -> PointSet
datasetsToPointSet time dss =
  PointSet . sort . nub $ foldr collect [] dss
  where
    collect ds acc = case ds of
      DS_PointSet (PointSet ps)           -> ps ++ acc
      DS_PointTuple (PointTuple4 p q r s) -> [p,q,r,s] ++ acc
      _ -> case datasetPoint time ds of
        Just p  -> p : acc
        Nothing -> acc

liftCarrierToPointSet :: IncidenceTime -> Carrier -> PointSet
liftCarrierToPointSet time c =
  let ds = case c of
        CBlob b     -> [DS_Blob b]
        CBlock b    -> [DS_Block b]
        CArtifact a -> [DS_Artifact a]
  in datasetsToPointSet time ds

streamToDatasets :: IncidenceTime -> [Word8] -> [Dataset]
streamToDatasets time bytes =
  let headD = prefixDatasets time bytes
  in if null headD then [] else headD

datasetsToIPv6Rows :: IncidenceTime -> [Dataset] -> [String]
datasetsToIPv6Rows time dss =
  let PointSet ps = datasetsToPointSet time dss
  in map pointToIPv6Text ps

data StepMode
  = ParseStep
  | LiftStep
  | ClassifyStep
  deriving (Eq, Ord, Show)

data AutoState = AutoState
  { stTick      :: !Word64
  , stTime      :: !IncidenceTime
  , stMode      :: !StepMode
  , stDatasets  :: ![Dataset]
  , stPointSet  :: !PointSet
  , stIPv6Rows  :: ![String]
  } deriving (Eq, Show)

emptyState :: AutoState
emptyState = AutoState
  { stTick = 0
  , stTime = incidenceTimeOf 0
  , stMode = ParseStep
  , stDatasets = [DS_Null, DS_IPv6Point (pointToIPv6Text canonPoint0)]
  , stPointSet = PointSet [canonPoint0]
  , stIPv6Rows = [pointToIPv6Text canonPoint0]
  }

stepAutomaton :: AutoState -> [Word8] -> AutoState
stepAutomaton st bytes =
  let t'   = stTick st + 1
      time = incidenceTimeOf t'
      dss  = streamToDatasets time bytes
      pts  = datasetsToPointSet time dss
      rows = datasetsToIPv6Rows time dss
      mode = if null bytes then ClassifyStep else LiftStep
  in AutoState
      { stTick = t'
      , stTime = time
      , stMode = mode
      , stDatasets = dss
      , stPointSet = pts
      , stIPv6Rows = rows
      }
