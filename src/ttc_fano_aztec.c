/*
 * ttc_fano_aztec.c
 *
 * Canonical Fano -> Braille-modem -> Aztec witness encoder.
 *
 * Purpose
 * -------
 * This is a transport/projection-side encoder that sits BELOW the human-facing
 * Braille dialect and ABOVE the raw byte carrier.
 *
 * It preserves the laws already frozen elsewhere:
 *   - Delta / replay kernel remains authoritative elsewhere.
 *   - Fano timing remains period-7 and uses the canonical 7 lines.
 *   - Aztec geometry remains geometry only.
 *   - The 60-slot lattice table remains normative for placement.
 *
 * This file does NOT redefine kernel truth.
 * It defines a deterministic witness encoding from byte frames into:
 *   byte -> braille-weighted cell -> Fano winner -> 60-slot address -> 27x27 grid
 *
 * Build:
 *   gcc -O2 -std=c99 -Wall -Wextra -o ttc_fano_aztec ttc_fano_aztec.c
 *
 * Usage:
 *   cat braille.bin | ./ttc_fano_aztec > aztec.txt
 *   cat braille.bin | ./ttc_fano_aztec -m raw > aztec.pgm
 *   cat braille.bin | ./ttc_fano_aztec -f 16 -m ascii
 *
 * Modes:
 *   -m ascii   : ASCII witness grid (default)
 *   -m raw     : PGM grayscale output
 *   -m json    : JSON metadata + flattened values
 *
 * Frame size:
 *   Default frame size is 16 bytes, matching the proposed modem framing.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* =========================================================
 * Canonical Fano lines
 * Matches the 7-line schedule used in the uploaded laws.
 * ========================================================= */
static const int FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

/* =========================================================
 * Braille hex weights
 * Dot ordering is modem-side only.
 * binary: the raw byte itself
 * hexwt : weighted Braille witness value
 * ========================================================= */
static const uint8_t HEX_WEIGHT[8] = {
    0x01, 0x02, 0x04, 0x40, 0x10, 0x08, 0x20, 0x80
};

/* =========================================================
 * Normative 60-position Aztec table.
 * Order is US(15), RS(15), GS(15), FS(15).
 * This follows the 60 canonical positions / 27x27 grid law.
 * ========================================================= */
static const int AZTEC_WIDTH  = 27;
static const int AZTEC_HEIGHT = 27;
static const int AZTEC_CELLS  = 729;

static const int AZTEC_TABLE[60][2] = {
    /* US lane 1-15 */
    {17,13},{16,17},{11,17},{ 9,15},{ 9,11},{12, 9},{18, 8},{18,12},{18,16},{15,18},{10,18},{ 8,16},{ 8,12},{ 9, 8},{14, 8},
    /* RS lane 1-15 */
    {19,13},{18,19},{11,19},{ 7,17},{ 7,11},{10, 7},{17, 7},{20,10},{20,16},{17,20},{10,20},{ 6,18},{ 6,12},{ 7, 6},{14, 6},
    /* GS lane 1-15 */
    {21,13},{20,21},{11,21},{ 5,19},{ 5,11},{ 8, 5},{17, 5},{22, 8},{22,16},{19,22},{10,22},{ 4,20},{ 4,12},{ 5, 4},{14, 4},
    /* FS lane 1-15 */
    {23,13},{22,23},{11,23},{ 3,21},{ 3,11},{ 6, 3},{17, 3},{24, 6},{24,16},{21,24},{10,24},{ 2,22},{ 2,12},{ 3, 2},{14, 2}
};

typedef enum {
    MODE_ASCII = 0,
    MODE_RAW   = 1,
    MODE_JSON  = 2
} OutputMode;

typedef struct {
    uint8_t binary;
    uint8_t hexwt;
} BrailleCell;

typedef struct {
    int tick;
    int chiral;
    int winner;
    int cycle;
    int lane;
    int channel;
    int orient;
    int quadrant;
    int addr60;
    int digit;
    uint8_t byte;
    uint8_t binary;
    uint8_t hexwt;
} EncodedStep;

static void usage(const char *argv0) {
    fprintf(stderr,
        "usage: %s [-m ascii|raw|json] [-f frame_bytes]\n"
        "  reads bytes from stdin and emits a canonical Aztec witness\n",
        argv0);
}

static int fano_winner(int tick, int chiral) {
    int line = tick % 7;
    int p0 = FANO_LINES[line][0];
    int p2 = FANO_LINES[line][2];
    return chiral ? p2 : p0;
}

static BrailleCell braille_cell(uint8_t byte) {
    BrailleCell out;
    int i;
    out.binary = byte;
    out.hexwt = 0;
    for (i = 0; i < 8; i++) {
        if (byte & (uint8_t)(1u << i)) {
            out.hexwt = (uint8_t)(out.hexwt + HEX_WEIGHT[i]);
        }
    }
    return out;
}

static int factoradic_digit(int hexwt, int radix) {
    if (radix <= 0) return 0;
    return hexwt % radix;
}

/*
 * Address law:
 *   lane      = cycle mod 15
 *   channel   = winner mod 4
 *   orient    = ((cycle / 15) + (winner mod 2)) mod 4
 *   quadrant  = channel * 4 + orient
 *   addr60    = quadrant * 15 + lane
 *
 * We then fold to the canonical 60-slot table.
 * The 240-space witness remains implicit through quadrant/orient structure.
 */
static int addr60_of(int winner, int cycle) {
    int lane = cycle % 15;
    int channel = winner % 4;
    int orient = ((cycle / 15) + (winner % 2)) % 4;
    int quadrant = channel * 4 + orient;
    return (quadrant * 15 + lane) % 60;
}

static EncodedStep encode_step(uint8_t byte, int tick) {
    EncodedStep s;
    BrailleCell bc = braille_cell(byte);
    int cycle;
    int winner;
    int lane;
    int channel;
    int orient;
    int quadrant;
    int addr;
    int radix;

    s.tick = tick;
    s.byte = byte;
    s.binary = bc.binary;
    s.hexwt = bc.hexwt;

    s.chiral = (tick / 7) % 2;
    winner = fano_winner(tick, s.chiral);
    cycle = tick / 7;
    lane = cycle % 15;
    channel = winner % 4;
    orient = ((cycle / 15) + (winner % 2)) % 4;
    quadrant = channel * 4 + orient;
    addr = addr60_of(winner, cycle);

    radix = ((tick % 16) < 10) ? ((tick % 16) + 1) : 10;

    s.winner = winner;
    s.cycle = cycle;
    s.lane = lane;
    s.channel = channel;
    s.orient = orient;
    s.quadrant = quadrant;
    s.addr60 = addr;
    s.digit = factoradic_digit(bc.hexwt, radix);
    return s;
}

static void clear_grid(uint8_t grid[27][27]) {
    memset(grid, 0, 27 * 27 * sizeof(uint8_t));
}

static void place_step(uint8_t grid[27][27], const EncodedStep *s) {
    int x, y;
    if (s->addr60 < 0 || s->addr60 >= 60) return;
    x = AZTEC_TABLE[s->addr60][0];
    y = AZTEC_TABLE[s->addr60][1];
    if (x < 0 || x >= AZTEC_WIDTH || y < 0 || y >= AZTEC_HEIGHT) return;
    /* digit+1 gives visible range 1..10 */
    grid[y][x] = (uint8_t)(s->digit + 1);
}

static char glyph_for(uint8_t v) {
    if (v == 0) return ' ';
    if (v == 1) return '.';
    if (v == 2) return ':';
    if (v == 3) return '-';
    if (v == 4) return '=';
    if (v == 5) return '+';
    if (v == 6) return '*';
    if (v == 7) return '#';
    if (v == 8) return '@';
    if (v == 9) return '%';
    return '&';
}

static void emit_ascii(const uint8_t grid[27][27]) {
    int y, x;
    for (y = 0; y < AZTEC_HEIGHT; y++) {
        for (x = 0; x < AZTEC_WIDTH; x++) {
            putchar(glyph_for(grid[y][x]));
        }
        putchar('\n');
    }
}

static void emit_pgm(const uint8_t grid[27][27]) {
    int y, x;
    printf("P2\n%d %d\n255\n", AZTEC_WIDTH, AZTEC_HEIGHT);
    for (y = 0; y < AZTEC_HEIGHT; y++) {
        for (x = 0; x < AZTEC_WIDTH; x++) {
            int px = grid[y][x] * 25;
            if (px > 255) px = 255;
            printf("%d", px);
            if (x + 1 < AZTEC_WIDTH) putchar(' ');
        }
        putchar('\n');
    }
}

static void emit_json(const uint8_t grid[27][27], const EncodedStep *steps, int nsteps, int frame_bytes) {
    int y, x, i;
    printf("{\n");
    printf("  \"width\": %d,\n", AZTEC_WIDTH);
    printf("  \"height\": %d,\n", AZTEC_HEIGHT);
    printf("  \"frame_bytes\": %d,\n", frame_bytes);
    printf("  \"steps\": [\n");
    for (i = 0; i < nsteps; i++) {
        const EncodedStep *s = &steps[i];
        printf("    {\"tick\":%d,\"byte\":%u,\"binary\":%u,\"hexwt\":%u,\"chiral\":%d,\"winner\":%d,\"cycle\":%d,\"lane\":%d,\"channel\":%d,\"orient\":%d,\"quadrant\":%d,\"addr60\":%d,\"digit\":%d}%s\n",
            s->tick, s->byte, s->binary, s->hexwt, s->chiral, s->winner,
            s->cycle, s->lane, s->channel, s->orient, s->quadrant,
            s->addr60, s->digit,
            (i + 1 < nsteps) ? "," : "");
    }
    printf("  ],\n");
    printf("  \"grid\": [\n");
    for (y = 0; y < AZTEC_HEIGHT; y++) {
        printf("    [");
        for (x = 0; x < AZTEC_WIDTH; x++) {
            printf("%u", (unsigned)grid[y][x]);
            if (x + 1 < AZTEC_WIDTH) printf(",");
        }
        printf("]%s\n", (y + 1 < AZTEC_HEIGHT) ? "," : "");
    }
    printf("  ]\n");
    printf("}\n");
}

int main(int argc, char **argv) {
    OutputMode mode = MODE_ASCII;
    int frame_bytes = 16;
    uint8_t *buf = NULL;
    uint8_t grid[27][27];
    EncodedStep *steps = NULL;
    int steps_cap = 0;
    int steps_len = 0;
    int tick = 0;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0) {
            if (i + 1 >= argc) {
                usage(argv[0]);
                return 1;
            }
            i++;
            if (strcmp(argv[i], "ascii") == 0) mode = MODE_ASCII;
            else if (strcmp(argv[i], "raw") == 0) mode = MODE_RAW;
            else if (strcmp(argv[i], "json") == 0) mode = MODE_JSON;
            else {
                usage(argv[0]);
                return 1;
            }
        } else if (strcmp(argv[i], "-f") == 0) {
            if (i + 1 >= argc) {
                usage(argv[0]);
                return 1;
            }
            frame_bytes = atoi(argv[++i]);
            if (frame_bytes <= 0) {
                fprintf(stderr, "invalid frame byte count\n");
                return 1;
            }
        } else {
            usage(argv[0]);
            return 1;
        }
    }

    buf = (uint8_t *)malloc((size_t)frame_bytes);
    if (!buf) {
        fprintf(stderr, "allocation failure\n");
        return 1;
    }

    clear_grid(grid);

    while (fread(buf, 1, (size_t)frame_bytes, stdin) == (size_t)frame_bytes) {
        for (i = 0; i < frame_bytes; i++) {
            EncodedStep s = encode_step(buf[i], tick);
            place_step(grid, &s);

            if (steps_len >= steps_cap) {
                int new_cap = (steps_cap == 0) ? 64 : steps_cap * 2;
                EncodedStep *new_steps = (EncodedStep *)realloc(steps, (size_t)new_cap * sizeof(EncodedStep));
                if (!new_steps) {
                    free(steps);
                    free(buf);
                    fprintf(stderr, "allocation failure\n");
                    return 1;
                }
                steps = new_steps;
                steps_cap = new_cap;
            }
            steps[steps_len++] = s;
            tick++;
        }
    }

    if (mode == MODE_ASCII) {
        emit_ascii(grid);
    } else if (mode == MODE_RAW) {
        emit_pgm(grid);
    } else {
        emit_json(grid, steps, steps_len, frame_bytes);
    }

    free(steps);
    free(buf);
    return 0;
}
