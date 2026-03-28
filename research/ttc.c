/*
 * Triple Tetrahedral Complex (TTC)
 * Atomic Kernel: A1–A11 + A21–A30
 *
 * Architecture:
 *   Tier 1  – Control-code axes  : NULL, ESC, FS, GS, RS, US
 *   Tier 2  – Delta Law (A1)     : rotl/rotr XOR kernel
 *   Tier 3  – Fano / Sonar clock : 7-tick chirality, 60-tick lattice
 *   Tier 4  – Master Reset       : LCM(7,8,60,240,360) = 5040  (7!)
 *   Tier 5  – Braille stream     : U+2800 – U+28FF output
 *   Tier 6  – OID→SID promotion  : polynomial axes (n¹…n⁴)
 *   Tier 7  – Hadamard scaling   : (4n+1)(2n+1)(n+1) sequence
 *
 * Build:  gcc -O2 -o ttc ttc.c
 * Run:    ./ttc [ticks]   (default: one full 5040-tick epoch)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <wchar.h>

/* =========================================================
 * Tier 1 – Constitutional Symbols (C0 IS separators)
 * ========================================================= */
#define SYM_NULL  0x00u
#define SYM_ESC   0x1Bu   /* Boundary / Mode Entry      */
#define SYM_FS    0x1Cu   /* File Sep  / Control axis   */
#define SYM_GS    0x1Du   /* Group Sep / Choice axis    */
#define SYM_RS    0x1Eu   /* Record Sep/ Closure axis   */
#define SYM_US    0x1Fu   /* Unit Sep  / Agreement axis */

/* Clock constants */
#define MASTER_RESET  5040u   /* 7! = LCM(7,8,60,240,360) */
#define FANO_PERIOD      7u
#define SONAR_PERIOD    60u
#define GOAL_PERIOD    360u
#define KERNEL_STATES    8u

/* Bit-width for the Delta Law */
#define DELTA_WIDTH      8u

/* Braille Unicode base (U+2800) */
#define BRAILLE_BASE  0x2800u

/* =========================================================
 * Tier 2 – Delta Law (A1)
 *   delta(x, C, n) = (rotl(x,1,n) ^ rotl(x,3,n) ^ rotr(x,2,n) ^ C) & mask
 * ========================================================= */
static inline uint8_t rotl8(uint8_t x, int k)
{
    k &= 7;
    return (uint8_t)((x << k) | (x >> (8 - k)));
}

static inline uint8_t rotr8(uint8_t x, int k)
{
    k &= 7;
    return (uint8_t)((x >> k) | (x << (8 - k)));
}

/* A1 – single delta step */
static uint8_t delta(uint8_t x, uint8_t C)
{
    return (uint8_t)((rotl8(x, 1) ^ rotl8(x, 3) ^ rotr8(x, 2) ^ C) & 0xFFu);
}

/* A11 – 7-fold collapse (runs delta 7 times; C stays GS) */
static uint8_t fold_state(uint8_t state, uint8_t C)
{
    for (int i = 0; i < 7; ++i)
        state = delta(state, C);
    return state;
}

/* =========================================================
 * Tier 3 – State classification
 *   LOW_LAW   : bits 0–1 only  (deterministic, SID space)
 *   HIGH_EDIT : bits 2–3 set   (projective, OID space)
 *   NULL_VOID : 0x00
 * ========================================================= */
typedef enum { NULL_VOID, LOW_LAW, HIGH_EDIT } StateClass;

static StateClass classify_state(uint8_t v)
{
    if (v == 0)          return NULL_VOID;
    if (v & 0x0Cu)       return HIGH_EDIT;   /* bit 2 or 3 */
    return LOW_LAW;
}

static const char *class_name(StateClass c)
{
    switch (c) {
        case NULL_VOID: return "NULL_VOID ";
        case LOW_LAW:   return "LOW_LAW   ";
        case HIGH_EDIT: return "HIGH_EDIT ";
        default:        return "UNKNOWN   ";
    }
}

/* =========================================================
 * Tier 3b – Braille dot breakdown
 * ========================================================= */
/* Braille dot layout in an 8-bit cell:
 *   bit 0 = dot 1  (Law / Fano / Deterministic)
 *   bit 1 = dot 2  (Law / Sonar / Deterministic)
 *   bit 2 = dot 3  (Law / Kernel / Deterministic)
 *   bit 3 = dot 4  (Edit / High Bit / Projection)
 *   bit 4 = dot 5  (Edit / High Bit / Projection)
 *   bit 5 = dot 6  (Edit / High Bit / Projection)
 *   bit 6 = dot 7  (Extension / OID Space)
 *   bit 7 = dot 8  (Boundary / ESC / Mode Entry)
 */
static void print_braille(uint8_t v)
{
    /* UTF-8 encode U+2800+v */
    uint32_t cp = BRAILLE_BASE + v;
    /* U+2800–U+28FF always encodes as 3-byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx */
    unsigned char b0 = (unsigned char)(0xE0u | (cp >> 12));
    unsigned char b1 = (unsigned char)(0x80u | ((cp >> 6) & 0x3Fu));
    unsigned char b2 = (unsigned char)(0x80u | (cp & 0x3Fu));
    printf("%c%c%c", b0, b1, b2);
}

/* =========================================================
 * Tier 4 – Fano triplet (A6)
 *   The 7 lines of the Fano plane PG(2,2).
 *   Each line has 3 points; used to derive chirality jitter.
 * ========================================================= */
static const uint8_t FANO_LINES[7][3] = {
    {1, 2, 4},
    {2, 3, 5},
    {3, 4, 6},
    {4, 5, 0},
    {5, 6, 1},
    {6, 0, 2},
    {0, 1, 3}
};

/* Return the Fano triplet for tick t (t mod 7 selects the line) */
static void fano_triplet(uint32_t tick, uint8_t out[3])
{
    int line = (int)(tick % FANO_PERIOD);
    out[0] = FANO_LINES[line][0];
    out[1] = FANO_LINES[line][1];
    out[2] = FANO_LINES[line][2];
}

/* Chirality: 1 = Leading (Fano tick before Sonar tick), 0 = Lagging */
static int chirality(uint32_t tick)
{
    uint32_t fano_phase  = tick % FANO_PERIOD;
    uint32_t sonar_phase = tick % SONAR_PERIOD;
    return (fano_phase < sonar_phase % FANO_PERIOD) ? 1 : 0;
}

/* =========================================================
 * Tier 5 – Incidence events (A3)
 * ========================================================= */
typedef struct {
    int is_fano;   /* tick % 7  == 0 */
    int is_sonar;  /* tick % 60 == 0 */
    int is_goal;   /* tick % 360 == 0 */
    uint8_t point; /* bitmask: bit0=fano, bit1=sonar, bit2=goal */
} Incidence;

static Incidence compute_incidence(uint32_t tick)
{
    Incidence inc;
    inc.is_fano  = (tick % FANO_PERIOD  == 0);
    inc.is_sonar = (tick % SONAR_PERIOD == 0);
    inc.is_goal  = (tick % GOAL_PERIOD  == 0);
    inc.point    = (uint8_t)((inc.is_fano  ? 0x1u : 0u)
                           | (inc.is_sonar ? 0x2u : 0u)
                           | (inc.is_goal  ? 0x4u : 0u));
    return inc;
}

static const char *incidence_name(uint8_t point)
{
    switch (point) {
        case 0x7: return "TRIPLE ALIGNMENT (Full Tetrahedron)";
        case 0x3: return "Sonar-Fano Edge";
        case 0x5: return "Goal-Fano Edge";
        case 0x6: return "Goal-Sonar Edge";
        case 0x1: return "Single Fano Vertex";
        case 0x2: return "Single Sonar Vertex";
        case 0x4: return "Single Goal Vertex";
        default:  return "No Incidence";
    }
}

/* =========================================================
 * Tier 6 – OID→SID Promotion (A23, A24)
 *   Polynomial axes: FS=n¹, GS=n² (auto-granted), RS=n³, US=n⁴
 *   Promote if 2-of-3 structural axes (FS, RS, US) agree (A24)
 * ========================================================= */
typedef struct {
    int fs_agree;  /* Control / n¹ */
    int gs_agree;  /* Choice  / n² (always granted) */
    int rs_agree;  /* Closure / n³ */
    int us_agree;  /* Agreement/n⁴ */
    int count;     /* total structural agreements */
} AxisConsensus;

static AxisConsensus evaluate_axes(uint8_t state, uint32_t tick)
{
    AxisConsensus ax;
    ax.gs_agree = 1;   /* GS (Choice) is always granted */
    ax.fs_agree = ((state & 0x01u) != 0);                        /* Fano bit */
    ax.rs_agree = ((state & 0x04u) != 0);                        /* Kernel bit */
    ax.us_agree = (tick % GOAL_PERIOD == 0);                     /* Goal-aligned */
    ax.count    = ax.fs_agree + ax.rs_agree + ax.us_agree;
    return ax;
}

/* A24: Fano Consensus Guard – 2-of-3 structural axes */
static const char *check_promotion(AxisConsensus ax)
{
    if (ax.count == 3)   return "SID (UNIVERSAL LAW)";
    if (ax.count >= 2)   return "LOCAL_SID (Fano Pocket)";
    return "OID (Projection/Noise)";
}

/* =========================================================
 * Tier 7 – Hadamard-Radix Scaling (A21)
 *   level 1: (4n+1)(2n+1)(n+1)
 *   level 2: (4n²+1)(2n²+1)(n²+1)
 * ========================================================= */
static uint64_t hadamard_order(uint32_t n, int level)
{
    uint64_t m;
    if (level == 1) {
        m = (uint64_t)(4*n+1) * (2*n+1) * (n+1);
    } else {
        uint64_t n2 = (uint64_t)n * n;
        m = (4*n2+1) * (2*n2+1) * (n2+1);
    }
    return m;
}

/* =========================================================
 * Main engine state
 * ========================================================= */
typedef struct {
    uint32_t tick;
    uint8_t  state;        /* current 8-bit delta state */
    uint8_t  master_hex;   /* last 7-fold collapse result */
    int      current_sys;  /* interpretation system 0–6 */
    uint32_t epoch;        /* which 5040-block we're in */
} Engine;

static void engine_init(Engine *e)
{
    e->tick        = 0;
    e->state       = SYM_GS;   /* seed = GS (A1) */
    e->master_hex  = 0;
    e->current_sys = 0;
    e->epoch       = 0;
}

/* Step one tick */
static void engine_step(Engine *e)
{
    e->tick++;

    /* A1: advance delta state */
    e->state = delta(e->state, SYM_GS);

    /* Sabbath pause: NULL-dot clears / shifts interpretation system */
    if (e->state == SYM_NULL) {
        e->current_sys = (e->current_sys + 1) % 7;
    }

    /* A11: 7-fold collapse at every Master Reset */
    if (e->tick % MASTER_RESET == 0) {
        e->master_hex = fold_state(e->state, SYM_GS);
        e->epoch++;
    }
}

/* =========================================================
 * Output helpers
 * ========================================================= */
static void print_header(void)
{
    puts("============================================================");
    puts(" Triple Tetrahedral Complex – Atomic Kernel Engine");
    puts("============================================================");
    printf(" Constants: MASTER=%u  FANO=%u  SONAR=%u  GOAL=%u\n",
           MASTER_RESET, FANO_PERIOD, SONAR_PERIOD, GOAL_PERIOD);
    printf(" Seed: GS (0x%02X)   Width: %u bits\n\n", SYM_GS, DELTA_WIDTH);
}

static void print_sync_event(uint32_t tick, uint8_t state, Incidence inc,
                             AxisConsensus ax)
{
    uint8_t fano[3];
    fano_triplet(tick, fano);

    printf("[Tick %5u] State:0x%02X  Braille:", tick, state);
    print_braille(state);
    printf("  Point:0x%X  %s\n",
           inc.point, incidence_name(inc.point));

    printf("            Class:%-12s  Chirality:%s\n",
           class_name(classify_state(state)),
           chirality(tick) ? "LEADING " : "LAGGING ");

    printf("            Fano-line:[%u,%u,%u]  Axes:{FS=%d GS=%d RS=%d US=%d} → %s\n",
           fano[0], fano[1], fano[2],
           ax.fs_agree, ax.gs_agree, ax.rs_agree, ax.us_agree,
           check_promotion(ax));
    puts("");
}

static void print_master_fold(uint32_t tick, uint8_t master_hex, uint32_t epoch)
{
    printf("╔══════════════════════════════════════════════════════╗\n");
    printf("║ MASTER FOLD #%u  tick=%u  7-fold: 0x%02X  Braille: ",
           epoch, tick, master_hex);
    print_braille(master_hex);
    printf("\n║ GS-axis held. New epoch begins at NULL centroid.\n");
    printf("╚══════════════════════════════════════════════════════╝\n\n");
}

/* =========================================================
 * Hadamard table (informational, printed once)
 * ========================================================= */
static void print_hadamard_table(void)
{
    puts("--- Hadamard-Radix Scaling Table (A21) ---");
    puts("  n  | Level-1 order          | Level-2 order");
    puts("-----|------------------------|---------------------------");
    for (uint32_t n = 1; n <= 8; ++n) {
        printf("  %2u | %-22llu | %llu\n",
               n,
               (unsigned long long)hadamard_order(n, 1),
               (unsigned long long)hadamard_order(n, 2));
    }
    puts("");
}

/* =========================================================
 * Summary statistics
 * ========================================================= */
typedef struct {
    uint32_t triple;     /* full 0x7 alignments   */
    uint32_t sonar_fano; /* 0x3 Sonar-Fano edges  */
    uint32_t single;     /* single vertex events  */
    uint32_t promoted;   /* LOCAL_SID promotions  */
    uint32_t universal;  /* SID (UNIVERSAL LAW)   */
    uint32_t sabbaths;   /* NULL-dot pauses        */
    uint32_t high_edits; /* HIGH_EDIT states       */
} Stats;

/* =========================================================
 * Main
 * ========================================================= */
int main(int argc, char *argv[])
{
    uint32_t max_ticks = MASTER_RESET;   /* default: one full epoch */

    if (argc >= 2) {
        long v = strtol(argv[1], NULL, 10);
        if (v > 0) max_ticks = (uint32_t)v;
    }

    setlocale(LC_ALL, "");

    print_header();
    print_hadamard_table();

    puts("--- Sync Log (incidence events only) ---\n");

    Engine  e;
    Stats   s = {0};

    engine_init(&e);

    for (uint32_t t = 0; t < max_ticks; ++t) {
        engine_step(&e);

        Incidence    inc = compute_incidence(e.tick);
        AxisConsensus ax = evaluate_axes(e.state, e.tick);
        StateClass    sc = classify_state(e.state);

        /* Accumulate stats */
        if (e.state == SYM_NULL)  s.sabbaths++;
        if (sc == HIGH_EDIT)      s.high_edits++;

        const char *promo = check_promotion(ax);
        if (strncmp(promo, "SID (UNIV",  9) == 0) s.universal++;
        if (strncmp(promo, "LOCAL_SID",  9) == 0) s.promoted++;

        /* Print sync events */
        if (inc.point > 0) {
            switch (inc.point) {
                case 0x7: s.triple++;     break;
                case 0x3: s.sonar_fano++; break;
                default:  s.single++;     break;
            }
            print_sync_event(e.tick, e.state, inc, ax);
        }

        /* Master fold printout */
        if (e.tick % MASTER_RESET == 0) {
            print_master_fold(e.tick, e.master_hex, e.epoch);
        }
    }

    /* Summary */
    puts("=== Summary ===");
    printf("  Ticks run         : %u\n",  max_ticks);
    printf("  Epochs completed  : %u\n",  e.epoch);
    printf("  Triple alignments : %u\n",  s.triple);
    printf("  Sonar-Fano edges  : %u\n",  s.sonar_fano);
    printf("  Single vertex evt : %u\n",  s.single);
    printf("  Sabbath (NULL)    : %u\n",  s.sabbaths);
    printf("  HIGH_EDIT states  : %u\n",  s.high_edits);
    printf("  LOCAL_SID promo   : %u\n",  s.promoted);
    printf("  UNIVERSAL LAW     : %u\n",  s.universal);
    printf("  Final state       : 0x%02X  Braille: ", e.state);
    print_braille(e.state);
    printf("\n  Last 7-fold hex   : 0x%02X\n", e.master_hex);

    return 0;
}
