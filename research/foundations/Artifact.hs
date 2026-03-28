-- | Artifact.hs
-- Realized geometry / carrier objects derived from Tetragrammaton resolution.
--
-- Layering:
--   AtomicKernel.hs
--     -> BitBoard.hs
--     -> BlackBoard.hs
--     -> Tetragrammaton.hs   -- 4D simplex law / resolution grammar
--     -> Artifact.hs         -- realized geometry / carrier objects
--     -> SVG/XML/Aztec views
--
-- Authority:
--   This module defines concrete geometric carriers only.
--   It does not redefine kernel truth, board interpretation, or simplex law.
--   All artifacts must be derivable from Tetragrammaton resolution.
--
-- Design:
--   * triangle meshes for boundary rendering
--   * tetrahedral meshes for volumetric carriers
--   * polyhedra as named carrier families
--   * deterministic normalization and lightweight digests
--
-- Note:
--   This is an annotated canonical draft intended to be refined against your
--   existing codebase. It is written to be easy to integrate with BitBoard,
--   BlackBoard, and Tetragrammaton.

module Artifact
  ( -- ids
    VertexId(..), FaceId(..), CellId(..), ArtifactId(..)

    -- coordinates
  , Coord3(..), Coord4(..)

    -- carriers
  , Vertex(..), Edge(..), Triangle(..), Tetra(..)
  , TriangleMesh(..), TetraMesh(..)
  , PolyhedronKind(..), Polyhedron(..)
  , Artifact(..), ArtifactMeta(..), CarrierKind(..)

    -- constructors
  , mkVertex, mkTriangle, mkTetra
  , mkTriangleMesh, mkTetraMesh
  , artifactFromTriangleMesh, artifactFromTetraMesh, artifactFromPolyhedron

    -- transforms
  , boundaryOf
  , tetraMeshOf
  , dualPlaceholder

    -- normalization / digest
  , normalizeTriangleMesh
  , normalizeTetraMesh
  , artifactDigest64
  ) where

import Data.Bits
import Data.List (sort, nub)
import Data.Word (Word32, Word64)

-- ============================================================================
-- IDENTIFIERS
-- ============================================================================

newtype VertexId   = VertexId   Word32 deriving (Eq, Ord, Show)
newtype FaceId     = FaceId     Word32 deriving (Eq, Ord, Show)
newtype CellId     = CellId     Word32 deriving (Eq, Ord, Show)
newtype ArtifactId = ArtifactId Word64 deriving (Eq, Ord, Show)

-- ============================================================================
-- COORDINATES
-- ============================================================================

data Coord3 = Coord3 !Double !Double !Double
  deriving (Eq, Ord, Show)

data Coord4 = Coord4 !Double !Double !Double !Double
  deriving (Eq, Ord, Show)

-- ============================================================================
-- GEOMETRIC CARRIERS
-- ============================================================================

data Vertex = Vertex
  { vId   :: !VertexId
  , vPos3 :: !Coord3
  } deriving (Eq, Ord, Show)

data Edge = Edge !VertexId !VertexId
  deriving (Eq, Ord, Show)

data Triangle = Triangle
  { triId :: !FaceId
  , triA  :: !VertexId
  , triB  :: !VertexId
  , triC  :: !VertexId
  } deriving (Eq, Ord, Show)

data Tetra = Tetra
  { tetId :: !CellId
  , tetA  :: !VertexId
  , tetB  :: !VertexId
  , tetC  :: !VertexId
  , tetD  :: !VertexId
  } deriving (Eq, Ord, Show)

data TriangleMesh = TriangleMesh
  { tmVertices  :: ![Vertex]
  , tmTriangles :: ![Triangle]
  } deriving (Eq, Show)

data TetraMesh = TetraMesh
  { thVertices :: ![Vertex]
  , thTetras   :: ![Tetra]
  } deriving (Eq, Show)

data PolyhedronKind
  = PlatonicTetrahedron
  | PlatonicCube
  | PlatonicOctahedron
  | PlatonicDodecahedron
  | PlatonicIcosahedron
  | Archimedean !String
  | Catalan !String
  | Derived !String
  deriving (Eq, Ord, Show)

data Polyhedron = Polyhedron
  { polyKind     :: !PolyhedronKind
  , polyVertices :: ![Vertex]
  , polyFaces    :: ![Triangle]
  } deriving (Eq, Show)

data CarrierKind
  = CarrierTriangleMesh
  | CarrierTetraMesh
  | CarrierPolyhedron
  deriving (Eq, Ord, Show)

data ArtifactMeta = ArtifactMeta
  { amSource     :: !String
  , amResolution :: !String
  , amNotes      :: ![String]
  } deriving (Eq, Show)

data Artifact
  = ArtifactTriangleMesh
      { artId      :: !ArtifactId
      , artMeta    :: !ArtifactMeta
      , artTriMesh :: !TriangleMesh
      }
  | ArtifactTetraMesh
      { artId       :: !ArtifactId
      , artMeta     :: !ArtifactMeta
      , artTetraMesh :: !TetraMesh
      }
  | ArtifactPolyhedron
      { artId        :: !ArtifactId
      , artMeta      :: !ArtifactMeta
      , artPolyhedron :: !Polyhedron
      }
  deriving (Eq, Show)

-- ============================================================================
-- CONSTRUCTORS
-- ============================================================================

mkVertex :: Word32 -> Coord3 -> Vertex
mkVertex n p = Vertex (VertexId n) p

mkTriangle :: Word32 -> VertexId -> VertexId -> VertexId -> Triangle
mkTriangle n a b c = Triangle (FaceId n) a b c

mkTetra :: Word32 -> VertexId -> VertexId -> VertexId -> VertexId -> Tetra
mkTetra n a b c d = Tetra (CellId n) a b c d

mkTriangleMesh :: [Vertex] -> [Triangle] -> TriangleMesh
mkTriangleMesh vs ts = TriangleMesh (sort . nub $ vs) (sort . nub $ ts)

mkTetraMesh :: [Vertex] -> [Tetra] -> TetraMesh
mkTetraMesh vs ts = TetraMesh (sort . nub $ vs) (sort . nub $ ts)

artifactFromTriangleMesh :: ArtifactMeta -> TriangleMesh -> Artifact
artifactFromTriangleMesh meta mesh =
  ArtifactTriangleMesh (ArtifactId (digestVerts (map vId (tmVertices mesh)) `xor` 0x545249)) meta (normalizeTriangleMesh mesh)

artifactFromTetraMesh :: ArtifactMeta -> TetraMesh -> Artifact
artifactFromTetraMesh meta mesh =
  ArtifactTetraMesh (ArtifactId (digestVerts (map vId (thVertices mesh)) `xor` 0x544554)) meta (normalizeTetraMesh mesh)

artifactFromPolyhedron :: ArtifactMeta -> Polyhedron -> Artifact
artifactFromPolyhedron meta poly =
  ArtifactPolyhedron (ArtifactId (digestVerts (map vId (polyVertices poly)) `xor` 0x504f4c59)) meta poly

-- ============================================================================
-- TRANSFORMS
-- ============================================================================

boundaryOf :: TetraMesh -> TriangleMesh
boundaryOf tm =
  -- Placeholder boundary extraction:
  -- in production, count oriented faces and keep only singleton faces.
  TriangleMesh (thVertices tm) []

tetraMeshOf :: TriangleMesh -> TetraMesh
tetraMeshOf mesh =
  -- Placeholder volumetric lift:
  -- in production, tetrahedralize from the boundary or constructive primitive.
  TetraMesh (tmVertices mesh) []

dualPlaceholder :: Polyhedron -> Polyhedron
dualPlaceholder poly =
  -- Placeholder dual: structural hook for Catalan/Archimedean verification.
  poly { polyKind = Derived ("dual(" ++ show (polyKind poly) ++ ")") }

-- ============================================================================
-- NORMALIZATION
-- ============================================================================

normalizeTriangleMesh :: TriangleMesh -> TriangleMesh
normalizeTriangleMesh (TriangleMesh vs ts) =
  TriangleMesh (sort . nub $ vs) (sort . nub $ fmap normalizeTri ts)
  where
    normalizeTri (Triangle fid a b c) =
      let [x,y,z] = sort [a,b,c] in Triangle fid x y z

normalizeTetraMesh :: TetraMesh -> TetraMesh
normalizeTetraMesh (TetraMesh vs ts) =
  TetraMesh (sort . nub $ vs) (sort . nub $ fmap normalizeTet ts)
  where
    normalizeTet (Tetra cid a b c d) =
      let [w,x,y,z] = sort [a,b,c,d] in Tetra cid w x y z

-- ============================================================================
-- DIGEST
-- ============================================================================

digestVerts :: [VertexId] -> Word64
digestVerts = foldl step 0xcbf29ce484222325
  where
    step acc (VertexId w) =
      let x = fromIntegral w :: Word64
      in ((acc `xor` x) * 0x100000001b3) .&. maxBound

artifactDigest64 :: Artifact -> Word64
artifactDigest64 art = case art of
  ArtifactTriangleMesh _ _ m -> digestVerts (map vId (tmVertices (normalizeTriangleMesh m))) `xor` 0xA71FAC7
  ArtifactTetraMesh _ _ m    -> digestVerts (map vId (thVertices (normalizeTetraMesh m))) `xor` 0xA71FEC7
  ArtifactPolyhedron _ _ p   -> digestVerts (map vId (polyVertices p)) `xor` 0xA71F0C7
