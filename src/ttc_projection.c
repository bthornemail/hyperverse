/* LAYER: projection
 * Owns rendering/materialization only.
 */
#include "ttc_projection.h"

#include <string.h>

static const int TTC_PROJECTION_AZTEC_TABLE[TTC_WITNESS_SYMBOL_SLOTS][2] = {
    {17,13},{16,17},{11,17},{ 9,15},{ 9,11},{12, 9},{18, 8},{18,12},{18,16},{15,18},{10,18},{ 8,16},{ 8,12},{ 9, 8},{14, 8},
    {19,13},{18,19},{11,19},{ 7,17},{ 7,11},{10, 7},{17, 7},{20,10},{20,16},{17,20},{10,20},{ 6,18},{ 6,12},{ 7, 6},{14, 6},
    {21,13},{20,21},{11,21},{ 5,19},{ 5,11},{ 8, 5},{17, 5},{22, 8},{22,16},{19,22},{10,22},{ 4,20},{ 4,12},{ 5, 4},{14, 4},
    {23,13},{22,23},{11,23},{ 3,21},{ 3,11},{ 6, 3},{17, 3},{24, 6},{24,16},{21,24},{10,24},{ 2,22},{ 2,12},{ 3, 2},{14, 2}
};

static const uint8_t TTC_PROJECTION_HEX_WEIGHT[8] = {
    0x01, 0x02, 0x04, 0x40, 0x10, 0x08, 0x20, 0x80
};

static const int TTC_PROJECTION_FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

static int ttc_projection_fano_winner(uint64_t tick, int chiral) {
    int line = (int)(tick % 7u);
    return chiral ? TTC_PROJECTION_FANO_LINES[line][2] : TTC_PROJECTION_FANO_LINES[line][0];
}

static uint8_t ttc_projection_braille_hexwt(uint8_t byte) {
    int i;
    uint8_t out = 0;
    for (i = 0; i < 8; i++) {
        if (byte & (uint8_t)(1u << i)) {
            out = (uint8_t)(out + TTC_PROJECTION_HEX_WEIGHT[i]);
        }
    }
    return out;
}

void ttc_projection_clear_grid(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH]) {
    memset(grid, 0, TTC_PROJECTION_HEIGHT * TTC_PROJECTION_WIDTH);
}

char ttc_projection_ascii_glyph(uint8_t v) {
    if (v == 0u) return ' ';
    if (v <= 1u) return '.';
    if (v <= 2u) return ':';
    if (v <= 3u) return '-';
    if (v <= 4u) return '=';
    if (v <= 5u) return '+';
    if (v <= 6u) return '*';
    if (v <= 7u) return '#';
    if (v <= 8u) return '@';
    return '%';
}

void ttc_projection_symbol_to_grid(const ttc_witness_symbol *symbol, uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH]) {
    int i;
    ttc_projection_clear_grid(grid);
    if (!symbol) {
        return;
    }
    for (i = 0; i < TTC_WITNESS_SYMBOL_SLOTS; i++) {
        int x = TTC_PROJECTION_AZTEC_TABLE[i][0];
        int y = TTC_PROJECTION_AZTEC_TABLE[i][1];
        int winner = ttc_projection_fano_winner((uint64_t)i, (int)(((uint64_t)i / 7u) % 2u));
        uint8_t b = symbol->coords[i];
        uint8_t hexwt = ttc_projection_braille_hexwt(b);
        uint8_t intensity = (uint8_t)(((hexwt + winner) % 10) + 1);
        grid[y][x] = intensity;
    }
}

void ttc_projection_place_address(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], const ttc_address *address, uint8_t value) {
    int x;
    int y;
    if (!grid || !address || address->slot >= 60u) {
        return;
    }
    x = TTC_PROJECTION_AZTEC_TABLE[address->slot][0];
    y = TTC_PROJECTION_AZTEC_TABLE[address->slot][1];
    grid[y][x] = value;
}

void ttc_projection_place_step(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], const ttc_witness_step *step) {
    if (!grid || !step) {
        return;
    }
    ttc_projection_place_address(grid, &step->address, (uint8_t)(step->digit + 1));
}

int ttc_projection_render_ascii(const uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], FILE *out) {
    int y;
    int x;
    if (!grid || !out) {
        return TTC_WITNESS_ERR_ARG;
    }
    for (y = 0; y < TTC_PROJECTION_HEIGHT; y++) {
        for (x = 0; x < TTC_PROJECTION_WIDTH; x++) {
            fputc(ttc_projection_ascii_glyph(grid[y][x]), out);
        }
        fputc('\n', out);
    }
    return TTC_WITNESS_OK;
}

int ttc_projection_render_pgm(const uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], FILE *out) {
    int y;
    int x;
    if (!grid || !out) {
        return TTC_WITNESS_ERR_ARG;
    }
    fprintf(out, "P2\n%d %d\n255\n", TTC_PROJECTION_WIDTH, TTC_PROJECTION_HEIGHT);
    for (y = 0; y < TTC_PROJECTION_HEIGHT; y++) {
        for (x = 0; x < TTC_PROJECTION_WIDTH; x++) {
            int px = grid[y][x] * 25;
            if (px > 255) {
                px = 255;
            }
            fprintf(out, "%d", px);
            if (x + 1 < TTC_PROJECTION_WIDTH) {
                fputc(' ', out);
            }
        }
        fputc('\n', out);
    }
    return TTC_WITNESS_OK;
}
