-- | Automaton.hs
-- Canonical resolver / profunctor-style interpreter over artifact-bearing carriers.
--
-- Purpose
-- -------
-- This module defines the deterministic interaction layer that sits above:
--
--   AtomicKernel.hs
--     -> BitBoard.hs
--     -> BlackBoard.hs
--     -> Tetragrammaton.hs
--     -> Artifact.hs
--     -> Automaton.hs
--
-- and below:
--
--   Matroid.hs
--   Configuration.hs
--   Semantics.hs
--   Projection.hs
--   Frame.hs
--
-- Core idea
-- ---------
-- The automaton is NOT a loose UI framework.
-- It is a typed resolver that:
--
--   * accepts one or more canonical carriers
--   * applies an incidence timing function
--   * propagates or resolves state
--   * always returns a canonical point or a carrier reducible to one
--
-- In that sense it behaves more like a deterministic anafunctor/profunctor-style
-- interpreter than a plain function from one blob to one blob.
--
-- The automaton is basis-relative:
--
--   * canonArtifact0 = canonical null artifact
--   * canonBoard0    = canonical zero board
--   * canonPoint0    = canonical zero point
--
-- Every lawful construction can be stepped from that basis; every lawful
-- deconstruction returns to a basis-relative form.
--
-- Timing
-- ------
-- The automaton does not introduce a new time basis.
-- It consumes the existing incidence timing surface:
--
--   * Tick7  = structural / incidence click
--   * Tick56 = multiplex / resolved click
--
-- and exposes them together as IncidenceTime.
--
-- Complexity note
-- ---------------
-- ESC and NULL agreement protect interpretation boundaries:
--
--   * NULL = zero / void / point-at-basis
--   * ESC  = bounded interpretation / controlled expansion
--
-- so the automaton can admit unbounded interpretive complexity while preserving
-- O(1) access to the basis state.

module Automaton
  ( Tick7(..), Tick56(..), IncidenceTime(..)
  , tick7Of, tick56Of, incidenceTimeOf

  , Observer(..), canonObserver0

  , PointId(..), Point(..), canonPoint0, canonPoint1
  , Blob(..), Block(..), Carrier(..)
  , canonBlobVoid, canonBlockZero
  , canonArtifact0, Basis(..)

  , resolveIdentityPoint
  , resolveIdentityCarriers
  , resolveIdentity

  , SpecId(..), AutoSpec(..), AutoArrow(..)
  , StepMode(..), InputAction(..), OutputAction(..), InternalAction(..), Action(..)
  , AutoState(..), emptyState
  , choosePoint, buildChain, deconstructChain, resolveCarrier, stepAutomaton
  , applyInput, applyInternal, emitOutput
  ) where

import Data.Bits
import Data.List (foldl')
import Data.Word (Word8, Word16, Word32, Word64)

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

-- ============================================================================
-- OBSERVER / RESOLUTION IDENTITY
-- ============================================================================

-- | The observer is the synchronizer over the multiplex timing surface.
-- | It does not create truth; it aligns basis resolution.
data Observer = Observer
  { obsTrail :: !Word32
  , obsFrame :: !Word32
  , obsPhase :: !Word32
  } deriving (Eq, Ord, Show)

canonObserver0 :: Observer
canonObserver0 = Observer 0 0 0

newtype PointId = PointId Word64 deriving (Eq, Ord, Show)

data Point = Point
  { pId      :: !PointId
  , pBasisIx :: !Word32
  , pTag     :: !Word32
  } deriving (Eq, Ord, Show)

canonPoint0 :: Point
canonPoint0 = Point (PointId 0) 0 0

-- | First determinate canonical point produced by basis resolution.
canonPoint1 :: Point
canonPoint1 = Point (PointId 1) 0 1

-- | Resolution Identity:
-- |   resolve(observer, NULL, ESC, 0) = 1
-- |
-- | Operationally this means:
-- |   * NULL  -> void / basis boundary
-- |   * ESC   -> lawful interpretation admission
-- |   * 0     -> zero carrier / zero board / zero artifact
-- |   * 1     -> first determinate canonical point
-- |
-- | In code, the identity is represented as a basis-returning function.
resolveIdentityPoint :: Observer -> Point
resolveIdentityPoint _ = canonPoint1

data Blob = Blob
  { blobId    :: !Word64
  , blobBytes :: ![Word8]
  } deriving (Eq, Show)

data Block = Block
  { blockId      :: !Word64
  , blockPoint   :: !Point
  , blockFamily  :: !Word8
  , blockIndex   :: !Word16
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
canonBlockZero = Block 0 canonPoint0 0 0 []

canonArtifact0 :: Artifact

resolveIdentityCarriers :: Observer -> [Carrier]
resolveIdentityCarriers obs =
  [ CArtifact canonArtifact0
  , CBlock canonBlockZero { blockPoint = resolveIdentityPoint obs }
  , CBlob canonBlobVoid
  ]

resolveIdentity :: Observer -> (Point, [Carrier])
resolveIdentity obs = (resolveIdentityPoint obs, resolveIdentityCarriers obs)

data Basis = Basis
  { basisPoint    :: !Point
  , basisBlob     :: !Blob
  , basisBlock    :: !Block
  , basisArtifact :: !Artifact
  } deriving (Eq, Show)

newtype SpecId = SpecId Word64 deriving (Eq, Ord, Show)

data AutoSpec = AutoSpec
  { asSpecId   :: !SpecId
  , asSource   :: ![Carrier]
  , asTarget   :: ![Carrier]
  , asPoint    :: !Point
  } deriving (Eq, Show)

data AutoArrow = AutoArrow
  { aaSpec   :: !AutoSpec
  , aaTime   :: !IncidenceTime
  , aaDigest :: !Word64
  } deriving (Eq, Show)

data StepMode = BuildStep | ResolveStep | ClassifyStep
  deriving (Eq, Ord, Show)

data InputAction = InNone | InCarrier !Carrier | InMany ![Carrier]
  deriving (Eq, Show)

data OutputAction = OutBasis | OutCarrier !Carrier | OutMany ![Carrier]
  deriving (Eq, Show)

data InternalAction = IntAdvance | IntBuild | IntResolve | IntClassify
  deriving (Eq, Ord, Show)

data Action = AIn !InputAction | AOut !OutputAction | AInt !InternalAction
  deriving (Eq, Show)

data AutoState = AutoState
  { stTick      :: !Word64
  , stTime      :: !IncidenceTime
  , stMode      :: !StepMode
  , stChain     :: ![Block]
  , stCarriers  :: ![Carrier]
  , stLastPoint :: !Point
  } deriving (Eq, Show)

emptyState :: AutoState
emptyState = AutoState 0 (incidenceTimeOf 0) ResolveStep [] [] canonPoint0

choosePoint :: IncidenceTime -> [Carrier] -> Point
choosePoint (IncidenceTime (Tick7 t7) (Tick56 t56)) cs =
  let n = fromIntegral (length cs) :: Word64
      h = foldl' mix 0x9e3779b97f4a7c15 (map carrierHash cs)
      pid = h `xor` fromIntegral t7 `xor` (fromIntegral t56 `shiftL` 8) `xor` (n `shiftL` 16)
  in Point (PointId pid) (fromIntegral t7) (fromIntegral t56)
  where
    mix a b = (a `xor` b) * 0x100000001b3
    mix8 acc w = (acc `xor` fromIntegral w) * 0x100000001b3
    carrierHash c = case c of
      CBlob (Blob bid bs) -> bid `xor` foldl' mix8 0 bs
      CBlock (Block bid _ f i p) ->
        bid `xor` fromIntegral f `xor` fromIntegral i `xor` foldl' mix8 0 p
      CArtifact art -> case art of
        ArtifactTriangleMesh{artId = ArtifactId i} -> i
        ArtifactTetraMesh{artId = ArtifactId i}    -> i
        ArtifactPolyhedron{artId = ArtifactId i}   -> i

buildChain :: IncidenceTime -> [Carrier] -> [Block] -> [Block]
buildChain time cs chain =
  let pt = choosePoint time cs
      nextIx = fromIntegral (length chain) :: Word16
      fam = case cs of
        []  -> 0
        [_] -> 1
        _   -> 2
      blk = Block
        { blockId = fromIntegral nextIx
        , blockPoint = pt
        , blockFamily = fam
        , blockIndex = nextIx
        , blockPayload = [fromIntegral nextIx]
        }
  in chain ++ [blk]

deconstructChain :: [Block] -> Carrier
deconstructChain xs = case xs of
  []  -> CBlock canonBlockZero
  [b] -> CBlock b
  bs  ->
    let bytes = concatMap blockPayload bs
        bid = fromIntegral (length bytes)
    in CBlob (Blob bid bytes)

resolveCarrier :: IncidenceTime -> [Carrier] -> Carrier
resolveCarrier time cs =
  case cs of
    []  -> CBlock canonBlockZero { blockPoint = choosePoint time [] }
    [c] -> c
    _   -> deconstructChain (buildChain time cs [])

stepAutomaton :: AutoState -> InputAction -> (AutoState, OutputAction)
stepAutomaton st input =
  let t' = stTick st + 1
      time' = incidenceTimeOf t'
      carriersIn = case input of
        InNone      -> []
        InCarrier c -> [c]
        InMany cs   -> cs
      carriers' = if null carriersIn then stCarriers st else carriersIn
      mode' = case input of
        InNone      -> ClassifyStep
        InCarrier _ -> BuildStep
        InMany _    -> ResolveStep
      chain' = case mode' of
        BuildStep    -> buildChain time' carriers' (stChain st)
        ResolveStep  -> buildChain time' carriers' (stChain st)
        ClassifyStep -> stChain st
      point' = choosePoint time' carriers'
      out = case input of
        InNone ->
          OutMany
            [ CArtifact canonArtifact0
            , CBlock canonBlockZero { blockPoint = point' }
            , CBlob canonBlobVoid
            ]
        _ ->
          OutCarrier (resolveCarrier time' carriers')
      st' = AutoState t' time' mode' chain' carriers' point'
  in (st', out)

applyInput :: AutoState -> Carrier -> (AutoState, OutputAction)
applyInput st c = stepAutomaton st (InCarrier c)

applyInternal :: AutoState -> InternalAction -> (AutoState, OutputAction)
applyInternal st ia = case ia of
  IntAdvance  -> stepAutomaton st InNone
  IntBuild    -> stepAutomaton st (InMany (stCarriers st))
  IntResolve  -> stepAutomaton st (InMany (stCarriers st))
  IntClassify -> stepAutomaton st InNone

emitOutput :: AutoState -> OutputAction
emitOutput st = snd (stepAutomaton st InNone)
