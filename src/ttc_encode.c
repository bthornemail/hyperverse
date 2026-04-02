#include "ttc_projection.h"
#include "ttc_witness.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    MODE_JSON = 0,
    MODE_ASCII = 1,
    MODE_SLOTS = 2,
    MODE_PGM = 3
} OutputMode;

static void emit_hex(const uint8_t *buf, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        printf("%02x", (unsigned)buf[i]);
    }
}

static uint8_t *read_all_stdin(size_t *out_len) {
    uint8_t *buf = NULL;
    size_t len = 0;
    size_t cap = 0;
    int ch;
    while ((ch = fgetc(stdin)) != EOF) {
        if (len == cap) {
            size_t new_cap = cap ? cap * 2u : 1024u;
            uint8_t *next = (uint8_t *)realloc(buf, new_cap);
            if (!next) {
                free(buf);
                return NULL;
            }
            buf = next;
            cap = new_cap;
        }
        buf[len++] = (uint8_t)ch;
    }
    *out_len = len;
    return buf;
}

static void emit_ascii(const ttc_witness_symbol *symbols, size_t count) {
    size_t i;
    for (i = 0; i < count; i++) {
        uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH];
        int y;
        int x;
        ttc_projection_symbol_to_grid(&symbols[i], grid);
        printf("symbol %zu\n", i);
        for (y = 0; y < TTC_WITNESS_HEIGHT; y++) {
            for (x = 0; x < TTC_WITNESS_WIDTH; x++) {
                putchar(ttc_projection_ascii_glyph(grid[y][x]));
            }
            putchar('\n');
        }
    }
}

static void emit_slots(const ttc_witness_symbol *symbols, size_t count) {
    size_t i;
    for (i = 0; i < count; i++) {
        size_t j;
        for (j = 0; j < TTC_WITNESS_SYMBOL_SLOTS; j++) {
            if (j) {
                putchar(' ');
            }
            printf("%u", (unsigned)symbols[i].coords[j]);
        }
        putchar('\n');
    }
}

static void emit_pgm(const ttc_witness_symbol *symbols, size_t count) {
    uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH];
    if (count == 0) {
        return;
    }
    ttc_projection_symbol_to_grid(&symbols[0], grid);
    ttc_projection_render_pgm(grid, stdout);
}

static void emit_json(const ttc_witness_symbol *symbols, size_t count, const uint8_t *a13, size_t a13_len) {
    size_t i;
    printf("{\n");
    printf("  \"kind\":\"ttc.witness.slot.encode.v1\",\n");
    printf("  \"surface\":\"witness_slot_v1\",\n");
    printf("  \"a13_profile\":\"slip-v1\",\n");
    printf("  \"symbols\":[\n");
    for (i = 0; i < count; i++) {
        size_t j;
        printf("    {\"index\":%zu,\"chunk_len\":%u,\"continuation\":%u,\"coords\":[", i,
               (unsigned)symbols[i].coords[0], (unsigned)symbols[i].coords[1]);
        for (j = 0; j < TTC_WITNESS_SYMBOL_SLOTS; j++) {
            if (j) {
                putchar(',');
            }
            printf("%u", (unsigned)symbols[i].coords[j]);
        }
        printf("]}%s\n", (i + 1u < count) ? "," : "");
    }
    printf("  ],\n");
    printf("  \"a13_hex\":\"");
    emit_hex(a13, a13_len);
    printf("\"\n");
    printf("}\n");
}

static OutputMode parse_mode(const char *mode) {
    if (strcmp(mode, "json") == 0) return MODE_JSON;
    if (strcmp(mode, "ascii") == 0) return MODE_ASCII;
    if (strcmp(mode, "slots") == 0) return MODE_SLOTS;
    if (strcmp(mode, "pgm") == 0 || strcmp(mode, "raw") == 0) return MODE_PGM;
    return MODE_JSON;
}

int main(int argc, char **argv) {
    OutputMode mode = MODE_JSON;
    uint8_t *artifact = NULL;
    uint8_t *a13 = NULL;
    ttc_witness_symbol *symbols = NULL;
    size_t artifact_len = 0;
    size_t a13_len = 0;
    size_t symbol_count = 0;
    int rc;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            mode = parse_mode(argv[++i]);
        } else {
            fprintf(stderr, "usage: %s [-m json|ascii|slots|pgm]\n", argv[0]);
            return 2;
        }
    }

    artifact = read_all_stdin(&artifact_len);
    if (artifact_len > 0 && !artifact) {
        fprintf(stderr, "ERROR: allocation failure\n");
        return 2;
    }

    rc = ttc_witness_a13_encode(artifact, artifact_len, &a13, &a13_len);
    if (rc != TTC_WITNESS_OK) {
        free(artifact);
        fprintf(stderr, "ERROR: witness encode failed\n");
        return 2;
    }
    rc = ttc_witness_stream_to_symbols(a13, a13_len, &symbols, &symbol_count);
    if (rc != TTC_WITNESS_OK) {
        free(a13);
        free(artifact);
        fprintf(stderr, "ERROR: witness symbolization failed\n");
        return 2;
    }

    if (mode == MODE_JSON) emit_json(symbols, symbol_count, a13, a13_len);
    else if (mode == MODE_ASCII) emit_ascii(symbols, symbol_count);
    else if (mode == MODE_SLOTS) emit_slots(symbols, symbol_count);
    else emit_pgm(symbols, symbol_count);

    free(symbols);
    free(a13);
    free(artifact);
    return 0;
}
