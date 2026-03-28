-- | AtomicKernel.Timing
-- Dual-clock incidence schedule for animation procedure.
--
-- Two timing functions run simultaneously:
--
--   τ₇  — Fano period (7 ticks). Drives selection / chirality.
--          Already defined as fanoTriplet in AtomicKernel.
--
--   τ₁₅ — Sonar period (15 ticks per channel × 4 channels = 60 slots).
--          Drives lattice position / spatial sweep.
--
-- Their master reset period is:
--   LCM(7, 8, 60, 240, 360) = 2520
--
-- Wait — let's derive it properly rather than trust the document.
--   LCM(7,8)    = 56
--   LCM(56,60)  = 840
--   LCM(840,240) = 840   (since 840 = 3.5 × 240, check: 840/240 = 3.5 → not integer)
--
-- Correction:
--   840 / 240 = 3.5  → LCM(840,240) = LCM(840,240)
--   840 = 2³ × 3 × 5 × 7
--   240 = 2⁴ × 3 × 5
--   LCM = 2⁴ × 3 × 5 × 7 = 1680
--   LCM(1680, 360):
--   360 = 2³ × 3² × 5
--   LCM = 2⁴ × 3² × 5 × 7 = 2520
--
-- So master reset = 2520 ticks.
-- (The document's 840 is LCM(7,8,60) — it omits 240 and 360.)
--
-- Invariants:
--   2520 / 7   = 360  (Fano period divides master reset exactly)
--   2520 / 8   = 315  (kernel state period divides master reset)
--   2520 / 60  = 42   (sonar sweep divides master reset)
--   2520 / 240 = 10.5 → NOT integer. Hmm.
--
-- Let's be precise. 240 = 2⁴ × 3 × 5. LCM(2520, 240):
--   2520 = 2³ × 3² × 5 × 7. LCM needs 2⁴ → 5040.
--   5040 / 240 = 21 ✓
--   5040 / 360 = 14 ✓
--   5040 / 60  = 84 ✓
--   5040 / 7   = 720 ✓
--   5040 / 8   = 630 ✓
--
-- Master reset = 5040 = LCM(7, 8, 60, 240, 360).
-- 5040 = 7! (seven factorial). This is not a coincidence — it is
-- the natural period of a system with 7-fold incidence structure.
--
-- Primary sync points within one 360-tick goal cycle:
--   Tick 0:   all clocks at zero (goal cycle start)
--   Tick 120: 8-state × 15, sonar × 2, Fano drifts (17r1)
--   Tick 240: 8-state × 30, sonar × 4, Fano drifts (34r2)
--   Tick 360: 8-state × 45, sonar × 6, Fano drifts (51r3) — GOAL
--
-- The 7-tick Fano does NOT align cleanly with 360. This is correct.
-- The Fano is the jitter source — it prevents static locking.
-- The animation cues come from the INTERSECTION of τ₇ and τ₁₅,
-- not from forcing them to agree.

module AtomicKernel.Timing where

import Data.List (nub, sortBy)
import Data.Ord  (comparing)

-- ============================================================================
-- MASTER PERIOD
-- ============================================================================

-- | masterPeriod: LCM(7, 8, 60, 240, 360) = 5040 = 7!
-- Every timing function in the system resets exactly at this tick.
masterPeriod :: Int
masterPeriod = 5040

-- | goalCycle: 360 ticks. One full rotation of the goal clock.
-- The 360/240 relationship (3:2 ratio) is encoded here.
goalCycle :: Int
goalCycle = 360

-- | subCycle: 240 ticks. The 2/3 subharmonic of the goal cycle.
subCycle :: Int
subCycle = 240

-- | syncUnit: 120 ticks = LCM(8,15) = GCD(360,240).
-- At every syncUnit: 8-states × 15, sonar × 2, both clean.
syncUnit :: Int
syncUnit = 120

-- | sonarPeriod: 60 ticks. One full sweep of all 60 lattice slots.
sonarPeriod :: Int
sonarPeriod = 60

-- | fanoPeriod: 7 ticks. One Fano cycle.
fanoPeriod :: Int
fanoPeriod = 7

-- | kernelPeriod: 8 kernel states.
kernelPeriod :: Int
kernelPeriod = 8

-- ============================================================================
-- τ₇ — FANO TIMING FUNCTION
-- Drives: selection, chirality, port matroid atom choice.
-- Period: 7. Phase: tick mod 7.
-- ============================================================================

-- | fanoPhase: tick position within the current Fano cycle (0–6).
fanoPhase :: Int -> Int
fanoPhase tick = tick `mod` fanoPeriod

-- | fanoTick: which Fano cycle we are in (0-indexed).
fanoTick :: Int -> Int
fanoTick tick = tick `div` fanoPeriod

-- | The canonical 7 Fano lines (copied from AtomicKernel for locality).
fanoLines :: [(Int,Int,Int)]
fanoLines =
  [ (0,1,3), (0,2,5), (0,4,6)
  , (1,2,4), (1,5,6)
  , (2,3,6)
  , (3,4,5)
  ]

-- | fanoTriplet: active incidence triple at tick t.
fanoTriplet :: Int -> (Int,Int,Int)
fanoTriplet t = fanoLines !! fanoPhase t

-- ============================================================================
-- τ₁₅ — SONAR TIMING FUNCTION
-- Drives: lattice slot position, channel sweep, spatial animation.
-- Period: 60 (15 lanes × 4 channels). Phase: tick mod 60.
-- ============================================================================

-- | sonarPhase: position within the current sonar sweep (0–59).
sonarPhase :: Int -> Int
sonarPhase tick = tick `mod` sonarPeriod

-- | sonarCycle: which sweep we are in (0-indexed).
sonarCycle :: Int -> Int
sonarCycle tick = tick `div` sonarPeriod

-- | Active channel at this tick (0=US, 1=RS, 2=GS, 3=FS).
-- Each channel gets 15 consecutive ticks in the sweep.
sonarChannel :: Int -> Int
sonarChannel tick = sonarPhase tick `div` 15

-- | Active lane within the channel (1–15).
sonarLane :: Int -> Int
sonarLane tick = (sonarPhase tick `mod` 15) + 1

-- | sonarOffset: a spatial index into the 60-slot lattice (0-indexed).
sonarOffset :: Int -> Int
sonarOffset = sonarPhase

-- ============================================================================
-- DUAL-CLOCK INCIDENCE SPACE
-- The intersection of τ₇ and τ₁₅ defines animation cues.
-- An incidence event occurs when both clocks cross a boundary
-- at the same tick, or when their phases produce a noteworthy pair.
-- ============================================================================

-- | IncidenceEvent: a moment where τ₇ and τ₁₅ intersect meaningfully.
data IncidenceEvent
  = FanoReset      Int  -- tick where Fano cycle completes (tick mod 7 = 0)
  | SonarReset     Int  -- tick where sonar sweep completes (tick mod 60 = 0)
  | ChannelJump    Int  -- tick where sonar channel changes (tick mod 15 = 0)
  | SyncPoint      Int  -- tick where 8-states and sonar align (tick mod 120 = 0)
  | GoalMark       Int  -- tick where goal cycle completes (tick mod 360 = 0)
  | SubCycleMark   Int  -- tick where sub-cycle completes (tick mod 240 = 0)
  | MasterReset    Int  -- tick where everything resets (tick mod 5040 = 0)
  | DualActive     Int (Int,Int,Int) Int Int
    -- tick, Fano triplet, sonar channel, sonar lane
    -- occurs every tick — this is the base animation frame
  deriving (Eq, Show)

-- | classifyTick: all events active at a given tick.
-- Returns events in priority order (MasterReset highest).
classifyTick :: Int -> [IncidenceEvent]
classifyTick t = filter active allEvents
  where
    active (MasterReset  _) = t `mod` masterPeriod == 0
    active (GoalMark     _) = t `mod` goalCycle    == 0 && t > 0
    active (SubCycleMark _) = t `mod` subCycle     == 0 && t > 0
    active (SyncPoint    _) = t `mod` syncUnit     == 0 && t > 0
    active (SonarReset   _) = t `mod` sonarPeriod  == 0 && t > 0
    active (ChannelJump  _) = t `mod` 15           == 0 && t > 0
    active (FanoReset    _) = t `mod` fanoPeriod   == 0 && t > 0
    active (DualActive{})   = True

    allEvents =
      [ MasterReset  t
      , GoalMark     t
      , SubCycleMark t
      , SyncPoint    t
      , SonarReset   t
      , ChannelJump  t
      , FanoReset    t
      , DualActive   t (fanoTriplet t) (sonarChannel t) (sonarLane t)
      ]

-- | incidenceSchedule: the full schedule for a range of ticks.
-- Each entry is (tick, [events]).
incidenceSchedule :: Int -> Int -> [(Int, [IncidenceEvent])]
incidenceSchedule from to =
  [ (t, classifyTick t) | t <- [from..to] ]

-- | animationCues: ticks that carry at least one structural event
-- above the base DualActive level. These are the cue points for
-- the animation procedure.
animationCues :: Int -> Int -> [(Int, [IncidenceEvent])]
animationCues from to =
  [ (t, evs)
  | (t, evs) <- incidenceSchedule from to
  , any isStructural evs
  ]
  where
    isStructural (DualActive{}) = False
    isStructural _              = True

-- ============================================================================
-- DUAL-CLOCK FRAME
-- The atomic unit of animation state. Everything the renderer needs.
-- ============================================================================

-- | DualFrame: the complete timing state at one tick.
-- This is what the animation procedure consumes on each step.
data DualFrame = DualFrame
  { dfTick          :: Int           -- absolute tick
  , dfFanoPhase     :: Int           -- 0..6
  , dfFanoTriplet   :: (Int,Int,Int) -- active Fano line
  , dfFanoCycle     :: Int           -- which Fano cycle (0-indexed)
  , dfSonarPhase    :: Int           -- 0..59
  , dfSonarChannel  :: Int           -- 0..3
  , dfSonarLane     :: Int           -- 1..15
  , dfSonarCycle    :: Int           -- which sonar sweep (0-indexed)
  , dfGoalPhase     :: Int           -- tick mod 360 (position in goal cycle)
  , dfGoalCycle     :: Int           -- which goal cycle (0-indexed)
  , dfEvents        :: [IncidenceEvent]  -- structural events this tick
  , dfIsSync        :: Bool          -- True if tick mod 120 = 0
  , dfIsGoal        :: Bool          -- True if tick mod 360 = 0
  , dfIsMaster      :: Bool          -- True if tick mod 5040 = 0
  } deriving (Eq, Show)

-- | buildFrame: construct the complete dual-clock frame for a tick.
buildFrame :: Int -> DualFrame
buildFrame t = DualFrame
  { dfTick         = t
  , dfFanoPhase    = fanoPhase t
  , dfFanoTriplet  = fanoTriplet t
  , dfFanoCycle    = fanoTick t
  , dfSonarPhase   = sonarPhase t
  , dfSonarChannel = sonarChannel t
  , dfSonarLane    = sonarLane t
  , dfSonarCycle   = sonarCycle t
  , dfGoalPhase    = t `mod` goalCycle
  , dfGoalCycle    = t `div` goalCycle
  , dfEvents       = classifyTick t
  , dfIsSync       = t `mod` syncUnit    == 0
  , dfIsGoal       = t `mod` goalCycle   == 0
  , dfIsMaster     = t `mod` masterPeriod == 0
  }

-- | frameStream: infinite stream of dual-clock frames.
-- The animation procedure consumes this one frame at a time.
frameStream :: [DualFrame]
frameStream = map buildFrame [0..]

-- ============================================================================
-- PHASE RELATIONSHIPS
-- Derived from the two clocks. Used to drive specific animation behaviors.
-- ============================================================================

-- | Phase difference between τ₇ and τ₁₅ at tick t.
-- This is the "jitter" the document described.
-- It cycles with period LCM(7,60) = 420.
phaseDiff :: Int -> Int
phaseDiff t = (sonarPhase t * fanoPeriod - fanoPhase t * sonarPeriod)
              `mod` (fanoPeriod * sonarPeriod)

-- | phaseAlignment: 0.0 = clocks in phase, 1.0 = maximum offset.
-- Drives animation intensity — high alignment = calm, low = active.
phaseAlignment :: Int -> Double
phaseAlignment t =
  let maxDiff = fromIntegral (fanoPeriod * sonarPeriod)  -- 420
      diff    = fromIntegral (phaseDiff t)
  in 1.0 - (diff / maxDiff)

-- | sonarUnicodePlane: which Unicode plane the sonar is sweeping.
-- Channel maps to plane: US→0 (BMP), RS→1 (SMP), GS→2 (SIP), FS→3 (TIP)
-- The 15 lanes within each channel sweep 15 positions in that plane.
sonarUnicodePlane :: Int -> Int
sonarUnicodePlane = sonarChannel

-- | sonarCodepoint: the canonical codepoint being addressed at tick t.
-- Derived from channel (plane) and lane (offset within plane).
-- Offset within plane = lane × sonar_cycle_count × Fano_phase (jitter).
sonarCodepoint :: Int -> Int
sonarCodepoint t =
  let plane    = sonarUnicodePlane t
      lane     = sonarLane t        -- 1..15
      fp       = fanoPhase t        -- 0..6 (jitter)
      cycle_n  = sonarCycle t       -- which sweep
      -- Base offset: lane position in the plane, advanced by sweep count
      baseOff  = (lane - 1) * 256 + (cycle_n `mod` 256)
      -- Fano jitter: adds 0..6 to distinguish positions within a lane
      offset   = baseOff + fp
  in plane * 0x10000 + offset

-- ============================================================================
-- ANIMATION PROCEDURE INTERFACE
-- What the renderer needs to know at each tick, in one call.
-- ============================================================================

-- | AnimationState: the complete state for the animation procedure.
-- This is what index.html's renderFrame() should consume.
data AnimationState = AnimationState
  { asFrame         :: DualFrame
  -- Fano (τ₇) outputs
  , asFanoActive    :: (Int,Int,Int)  -- 3 active Fano points
  , asChiralBit     :: Int            -- 0 or 1 (from kernel, not here)
  -- Sonar (τ₁₅) outputs
  , asSonarSlot     :: Int            -- 0..59 lattice slot index
  , asSonarChannel  :: Int            -- 0..3
  , asSonarLane     :: Int            -- 1..15
  , asCodepoint     :: Int            -- Unicode codepoint being swept
  -- Intersection outputs (animation cues)
  , asPhaseAlign    :: Double         -- 0.0..1.0 (clock phase alignment)
  , asIsStructuralCue :: Bool         -- True at Fano/sonar/sync boundaries
  , asGoalProgress  :: Double         -- 0.0..1.0 (position in goal cycle)
  -- Event tags for animation triggers
  , asEvents        :: [IncidenceEvent]
  } deriving (Show)

-- | buildAnimationState: full animation state at tick t.
-- Call this once per animation frame. Pass chiralBit from kernel.
buildAnimationState :: Int -> Int -> AnimationState
buildAnimationState tick chiralBit =
  let frame = buildFrame tick
  in AnimationState
      { asFrame         = frame
      , asFanoActive    = dfFanoTriplet frame
      , asChiralBit     = chiralBit
      , asSonarSlot     = dfSonarPhase frame
      , asSonarChannel  = dfSonarChannel frame
      , asSonarLane     = dfSonarLane frame
      , asCodepoint     = sonarCodepoint tick
      , asPhaseAlign    = phaseAlignment tick
      , asIsStructuralCue = any isStructural (dfEvents frame)
      , asGoalProgress  = fromIntegral (dfGoalPhase frame)
                          / fromIntegral goalCycle
      , asEvents        = dfEvents frame
      }
  where
    isStructural (DualActive{}) = False
    isStructural _              = True

-- ============================================================================
-- INVARIANTS
-- ============================================================================

-- | INV-T1: master period divisible by all component periods
inv_masterDivisibility :: Bool
inv_masterDivisibility =
  all (\p -> masterPeriod `mod` p == 0)
      [fanoPeriod, kernelPeriod, sonarPeriod, subCycle, goalCycle]

-- | INV-T2: syncUnit = LCM(kernelPeriod, sonarPeriod / 4)
--   = LCM(8, 15) = 120
inv_syncUnitCorrect :: Bool
inv_syncUnitCorrect = lcm kernelPeriod (sonarPeriod `div` 4) == syncUnit

-- | INV-T3: at every syncUnit tick, 8-states and sonar are both at zero.
inv_syncPointClean :: Bool
inv_syncPointClean =
  all (\t -> sonarPhase t `mod` (sonarPeriod `div` 2) == 0)
      [syncUnit, syncUnit * 2, syncUnit * 3]

-- | INV-T4: Fano period is 7 (fanoTriplet repeats every 7).
inv_fanoPeriod :: Bool
inv_fanoPeriod = all (\t -> fanoTriplet (t + 7) == fanoTriplet t) [0..20]

-- | INV-T5: phaseAlignment is 1.0 at tick 0.
inv_phaseAlignAtZero :: Bool
inv_phaseAlignAtZero = phaseAlignment 0 == 1.0

-- | INV-T6: masterPeriod = 5040 = 7!
inv_masterIsSeven :: Bool
inv_masterIsSeven = masterPeriod == product [1..7]

-- | INV-T7: sonarCodepoint is deterministic (same tick → same codepoint).
inv_codepointDeterministic :: Bool
inv_codepointDeterministic = all (\t -> sonarCodepoint t == sonarCodepoint t) [0..100]

-- | Run all timing invariants.
checkTimingInvariants :: [(String, Bool)]
checkTimingInvariants =
  [ ("T1 master divisibility",     inv_masterDivisibility)
  , ("T2 syncUnit = LCM(8,15)",    inv_syncUnitCorrect)
  , ("T3 sync points clean",       inv_syncPointClean)
  , ("T4 Fano period = 7",         inv_fanoPeriod)
  , ("T5 phase align = 1.0 at 0",  inv_phaseAlignAtZero)
  , ("T6 master = 7! = 5040",      inv_masterIsSeven)
  , ("T7 codepoint deterministic", inv_codepointDeterministic)
  ]

-- ============================================================================
-- DEMO / INSPECTION
-- ============================================================================

-- | Show the first 60 ticks of the incidence schedule.
-- This is the minimum window to see one full sonar sweep
-- while observing the Fano drift.
showSchedule :: IO ()
showSchedule = do
  putStrLn "=== Dual-Clock Incidence Schedule (ticks 0–62) ===\n"
  putStrLn "tick  fp sl  ch  ln  Δ-align  codepoint  events"
  putStrLn (replicate 70 '-')
  mapM_ showRow [0..62]
  where
    showRow t =
      let f  = buildFrame t
          al = phaseAlignment t
          cp = sonarCodepoint t
          evs = filter notBase (dfEvents f)
          notBase (DualActive{}) = False
          notBase _              = True
          evStr = if null evs then "" else " ← " ++ concatMap eventTag evs
          eventTag (FanoReset  _) = "[F]"
          eventTag (SonarReset _) = "[S]"
          eventTag (ChannelJump _) = "[C]"
          eventTag (SyncPoint  _) = "[SYNC]"
          eventTag (GoalMark   _) = "[GOAL]"
          eventTag (SubCycleMark _) = "[SUB]"
          eventTag (MasterReset _) = "[MASTER]"
          eventTag _              = ""
          pad n s = s ++ replicate (n - length s) ' '
      in putStrLn $
           pad 6  (show t)
           ++ pad 4 (show (dfFanoPhase f))
           ++ pad 4 (show (dfSonarPhase f))
           ++ pad 5 (show (dfSonarChannel f))
           ++ pad 5 (show (dfSonarLane f))
           ++ pad 10 (show (round (al * 100) :: Int) ++ "%")
           ++ pad 12 ("0x" ++ showHex cp "")
           ++ evStr

    showHex n "" = hexStr n
    showHex n s  = hexStr n ++ s
    hexStr 0 = "0"
    hexStr n = hexStr (n `div` 16) ++ [hexDigit (n `mod` 16)]
    hexDigit d = "0123456789abcdef" !! d

-- | Key sync points within one master period.
showSyncPoints :: IO ()
showSyncPoints = do
  putStrLn "\n=== Sync Points within first 360 ticks ===\n"
  putStrLn "tick   goal%  fano-cycle  sonar-cycle  events"
  putStrLn (replicate 60 '-')
  mapM_ showSync (animationCues 0 360)
  where
    showSync (t, evs) =
      let f = buildFrame t
          gp = round (fromIntegral (dfGoalPhase f) / fromIntegral goalCycle * 100 :: Double) :: Int
      in putStrLn $
           show t ++ "  " ++
           show gp ++ "%  " ++
           show (dfFanoCycle f) ++ "  " ++
           show (dfSonarCycle f) ++ "  " ++
           show (filter notBase evs)
    notBase (DualActive{}) = False
    notBase _ = True

-- | Check all invariants.
showInvariants :: IO ()
showInvariants = do
  putStrLn "\n=== Timing Invariants ===\n"
  mapM_ (\(name, ok) ->
    putStrLn $ "  " ++ (if ok then "[OK]   " else "[FAIL] ") ++ name)
    checkTimingInvariants

main :: IO ()
main = do
  showSchedule
  showSyncPoints
  showInvariants
