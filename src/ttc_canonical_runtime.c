/*
 * ttc_canonical_runtime.c
 *
 * Canonical runtime:
 *   bytes -> transform(state,input,tick) -> 60-slot board -> optional Aztec witness
 *   board lines -> recovered state stream
 *
 * Build:
 *   gcc -O2 -std=c99 -Wall -Wextra -o ttc_canonical_runtime ttc_canonical_runtime.c
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define GS 0x1Du
#define MASTER_RESET 5040u
#define BOARD_SLOTS 60
#define AZTEC_W 27
#define AZTEC_H 27

static const uint8_t FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

static const int AZTEC_TABLE[60][2] = {
    {17,13},{16,17},{11,17},{ 9,15},{ 9,11},{12, 9},{18, 8},{18,12},{18,16},{15,18},{10,18},{ 8,16},{ 8,12},{ 9, 8},{14, 8},
    {19,13},{18,19},{11,19},{ 7,17},{ 7,11},{10, 7},{17, 7},{20,10},{20,16},{17,20},{10,20},{ 6,18},{ 6,12},{ 7, 6},{14, 6},
    {21,13},{20,21},{11,21},{ 5,19},{ 5,11},{ 8, 5},{17, 5},{22, 8},{22,16},{19,22},{10,22},{ 4,20},{ 4,12},{ 5, 4},{14, 4},
    {23,13},{22,23},{11,23},{ 3,21},{ 3,11},{ 6, 3},{17, 3},{24, 6},{24,16},{21,24},{10,24},{ 2,22},{ 2,12},{ 3, 2},{14, 2}
};

typedef struct {
    uint32_t tick;
    uint8_t input;
    uint8_t state;
    uint8_t basis7;
    uint8_t basis8;
    uint8_t law;
    uint8_t edit;
    uint8_t boundary;
    uint8_t winner;
    uint16_t braille;
    uint8_t board[BOARD_SLOTS];
} Snapshot;

typedef enum { OUT_BOARD = 0, OUT_AZTEC = 1, OUT_JSON = 2 } OutputMode;

static void usage(const char *argv0) {
    fprintf(stderr,
      "usage:\n"
      "  %s encode [--aztec|--json]\n"
      "  %s decode\n",
      argv0, argv0);
}

static uint8_t rotl8(uint8_t x, unsigned k) {
    k &= 7u;
    return (uint8_t)((x << k) | (x >> (8u - k)));
}

static uint8_t rotr8(uint8_t x, unsigned k) {
    k &= 7u;
    return (uint8_t)((x >> k) | (x << (8u - k)));
}

/*
 * Canonical bitwise transform.
 * - input 0x00 is Sabbath boundary reset.
 * - low bits (0..1) carry law channel.
 * - bits (2..3) carry projection/edit channel.
 * - input flag bit (0x80) propagates.
 */
static uint8_t transform_state(uint8_t state, uint8_t input, uint32_t tick) {
    uint8_t b7 = (uint8_t)(tick % 7u);
    uint8_t b8 = (uint8_t)(tick & 7u);
    uint8_t law;
    uint8_t proj;
    uint8_t out;

    if (input == 0x00u) {
        return 0x00u;
    }

    law = (uint8_t)((state ^ (uint8_t)(input << 1)) & 0x03u);
    proj = (uint8_t)(rotl8(state, 1) ^ input ^ b7 ^ (uint8_t)(b8 << 2));
    proj &= 0x0Cu;

    out = (uint8_t)(law | proj);
    if (input & 0x80u) out |= 0x80u;
    return out;
}

static uint8_t fold7(uint8_t state, uint8_t constant) {
    int i;
    for (i = 0; i < 7; i++) {
        state = (uint8_t)(rotl8(state,1) ^ rotl8(state,3) ^ rotr8(state,2) ^ constant);
    }
    return state;
}

static void board_clear(uint8_t board[BOARD_SLOTS]) {
    memset(board, 0, BOARD_SLOTS);
}

/*
 * Canonical board projection.
 * offset = 8*(tick mod 7) + (state & 7), modulo 60
 */
static void project_board(uint8_t board[BOARD_SLOTS], uint8_t state, uint32_t tick) {
    uint8_t offset = (uint8_t)((8u * (tick % 7u) + (state & 0x07u)) % 60u);
    unsigned i;
    board_clear(board);
    for (i = 0; i < 8; i++) {
        board[(offset + i) % BOARD_SLOTS] = (uint8_t)((state >> i) & 1u);
    }
}

static void snapshot_fill(Snapshot *s, uint32_t tick, uint8_t input, uint8_t state) {
    s->tick = tick;
    s->input = input;
    s->state = state;
    s->basis7 = (uint8_t)(tick % 7u);
    s->basis8 = (uint8_t)(tick & 7u);
    s->law = (uint8_t)(state & 0x03u);
    s->edit = (uint8_t)(state & 0x0Cu);
    s->boundary = (uint8_t)((state & 0x80u) ? 1u : 0u);
    s->winner = (uint8_t)(((tick / 7u) % 2u) ? FANO_LINES[s->basis7][2] : FANO_LINES[s->basis7][0]);
    s->braille = (uint16_t)(0x2800u + state);
    project_board(s->board, state, tick);
}

static void emit_board_line(const Snapshot *s) {
    unsigned i;
    printf("tick=%u input=0x%02X state=0x%02X basis7=%u basis8=%u law=0x%X edit=0x%X boundary=%u winner=%u braille=U+%04X board=",
           s->tick, s->input, s->state, s->basis7, s->basis8,
           s->law, s->edit, s->boundary, s->winner, s->braille);
    for (i = 0; i < BOARD_SLOTS; i++) putchar(s->board[i] ? '1' : '0');
    putchar('\n');
}

static void emit_json_step(const Snapshot *s, int comma) {
    unsigned i;
    printf("  {\"tick\":%u,\"input\":%u,\"state\":%u,\"basis7\":%u,\"basis8\":%u,\"law\":%u,\"edit\":%u,\"boundary\":%u,\"winner\":%u,\"braille\":%u,\"board\":\"",
           s->tick, s->input, s->state, s->basis7, s->basis8,
           s->law, s->edit, s->boundary, s->winner, s->braille);
    for (i = 0; i < BOARD_SLOTS; i++) putchar(s->board[i] ? '1' : '0');
    printf("\"}%s\n", comma ? "," : "");
}

static void aztec_clear(uint8_t grid[AZTEC_H][AZTEC_W]) {
    memset(grid, 0, AZTEC_H * AZTEC_W);
}

static void aztec_place(uint8_t grid[AZTEC_H][AZTEC_W], const uint8_t board[BOARD_SLOTS]) {
    int i;
    aztec_clear(grid);
    for (i = 0; i < BOARD_SLOTS; i++) {
        if (board[i]) {
            int x = AZTEC_TABLE[i][0];
            int y = AZTEC_TABLE[i][1];
            grid[y][x] = 1u;
        }
    }
}

static void aztec_emit_ascii(const uint8_t grid[AZTEC_H][AZTEC_W]) {
    int y, x;
    for (y = 0; y < AZTEC_H; y++) {
        for (x = 0; x < AZTEC_W; x++) putchar(grid[y][x] ? '#' : '.');
        putchar('\n');
    }
}

static int parse_board_bits(const char *s, uint8_t board[BOARD_SLOTS]) {
    size_t n = strlen(s);
    size_t i;
    if (n < BOARD_SLOTS) return 0;
    for (i = 0; i < BOARD_SLOTS; i++) {
        if (s[i] == '0') board[i] = 0;
        else if (s[i] == '1') board[i] = 1;
        else return 0;
    }
    return 1;
}

static uint8_t recover_state_from_board(const uint8_t board[BOARD_SLOTS], uint32_t tick) {
    uint8_t offset_guess;
    for (offset_guess = 0; offset_guess < 60; offset_guess++) {
        uint8_t candidate = 0;
        unsigned i;
        for (i = 0; i < 8; i++) {
            uint8_t slot = (uint8_t)((offset_guess + i) % BOARD_SLOTS);
            if (board[slot]) candidate |= (uint8_t)(1u << i);
        }
        if (((8u * (tick % 7u) + (candidate & 0x07u)) % 60u) == offset_guess) {
            return candidate;
        }
    }
    return 0u;
}

static int run_encode(OutputMode out_mode) {
    int ch;
    uint32_t tick = 0;
    uint8_t state = GS;
    uint8_t grid[AZTEC_H][AZTEC_W];
    Snapshot *steps = NULL;
    size_t cap = 0, len = 0, i;

    if (out_mode == OUT_JSON) printf("[\n");

    while ((ch = getchar()) != EOF) {
        Snapshot s;
        uint8_t input = (uint8_t)ch;

        state = transform_state(state, input, tick);
        if (tick > 0 && (tick % MASTER_RESET) == 0u) state = fold7(state, GS);
        snapshot_fill(&s, tick, input, state);

        if (out_mode == OUT_BOARD) {
            emit_board_line(&s);
        } else if (out_mode == OUT_AZTEC) {
            aztec_place(grid, s.board);
            aztec_emit_ascii(grid);
            if (!feof(stdin)) putchar('\n');
        } else {
            if (len == cap) {
                size_t new_cap = cap ? cap * 2u : 64u;
                Snapshot *new_steps = (Snapshot *)realloc(steps, new_cap * sizeof(Snapshot));
                if (!new_steps) {
                    free(steps);
                    return 1;
                }
                steps = new_steps;
                cap = new_cap;
            }
            steps[len++] = s;
        }
        tick++;
    }

    if (out_mode == OUT_JSON) {
        for (i = 0; i < len; i++) emit_json_step(&steps[i], (i + 1u < len));
        printf("]\n");
    }

    free(steps);
    return 0;
}

static int run_decode(void) {
    char line[512];
    uint32_t tick = 0;

    while (fgets(line, sizeof(line), stdin)) {
        uint8_t board[BOARD_SLOTS];
        char *p = strstr(line, "board=");
        if (!p) p = line;
        else p += 6;
        while (*p == ' ' || *p == '\t') p++;

        if (!parse_board_bits(p, board)) {
            fprintf(stderr, "decode: invalid board line at tick %u\n", tick);
            return 1;
        }

        {
            uint8_t state = recover_state_from_board(board, tick);
            printf("tick=%u state=0x%02X braille=U+%04X\n", tick, state, 0x2800u + state);
        }
        tick++;
    }
    return 0;
}

int main(int argc, char **argv) {
    OutputMode out_mode = OUT_BOARD;

    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "encode") == 0) {
        int i;
        for (i = 2; i < argc; i++) {
            if (strcmp(argv[i], "--aztec") == 0) out_mode = OUT_AZTEC;
            else if (strcmp(argv[i], "--json") == 0) out_mode = OUT_JSON;
            else {
                usage(argv[0]);
                return 1;
            }
        }
        return run_encode(out_mode);
    }

    if (strcmp(argv[1], "decode") == 0) {
        return run_decode();
    }

    usage(argv[0]);
    return 1;
}
