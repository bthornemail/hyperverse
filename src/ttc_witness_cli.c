#include "ttc_projection.h"
#include "ttc_witness.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum { MODE_ASCII = 0, MODE_PGM = 1, MODE_JSON = 2 } Mode;

int main(int argc, char **argv) {
    Mode mode = MODE_ASCII;
    ttc_witness_symbol *symbols = NULL;
    size_t symbol_count = 0;
    size_t cap = 0;
    unsigned int value;
    size_t idx = 0;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            i++;
            if (strcmp(argv[i], "ascii") == 0) mode = MODE_ASCII;
            else if (strcmp(argv[i], "pgm") == 0 || strcmp(argv[i], "raw") == 0) mode = MODE_PGM;
            else if (strcmp(argv[i], "json") == 0) mode = MODE_JSON;
            else {
                fprintf(stderr, "usage: %s [-m ascii|pgm|json]\n", argv[0]);
                free(symbols);
                return 2;
            }
        } else {
            fprintf(stderr, "usage: %s [-m ascii|pgm|json]\n", argv[0]);
            free(symbols);
            return 2;
        }
    }

    while (scanf("%u", &value) == 1) {
        ttc_witness_symbol *next;
        if (value > 255u) {
            fprintf(stderr, "ERROR: slot out of range\n");
            free(symbols);
            return 2;
        }
        if (idx % TTC_WITNESS_SYMBOL_SLOTS == 0u) {
            size_t new_count = symbol_count + 1u;
            if (new_count > cap) {
                size_t new_cap = cap ? cap * 2u : 8u;
                next = (ttc_witness_symbol *)realloc(symbols, new_cap * sizeof(*symbols));
                if (!next) {
                    fprintf(stderr, "ERROR: allocation failure\n");
                    free(symbols);
                    return 2;
                }
                symbols = next;
                cap = new_cap;
            }
            symbol_count = new_count;
        }
        symbols[symbol_count - 1u].coords[idx % TTC_WITNESS_SYMBOL_SLOTS] = (uint8_t)value;
        idx++;
    }

    if (idx % TTC_WITNESS_SYMBOL_SLOTS != 0u) {
        fprintf(stderr, "ERROR: expected full 60-slot symbols\n");
        free(symbols);
        return 2;
    }

    if (mode == MODE_JSON) {
        size_t s;
        printf("{\"kind\":\"ttc.witness.render.v1\",\"surface\":\"witness_slot_v1\",\"symbols\":[\n");
        for (s = 0; s < symbol_count; s++) {
            printf("{\"index\":%zu,\"chunk_len\":%u,\"continuation\":%u}%s\n",
                   s, (unsigned)symbols[s].coords[0], (unsigned)symbols[s].coords[1],
                   (s + 1u < symbol_count) ? "," : "");
        }
        printf("{}]}\n");
    } else {
        size_t s;
        for (s = 0; s < symbol_count; s++) {
            uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH];
            ttc_projection_symbol_to_grid(&symbols[s], grid);
            if (mode == MODE_ASCII) {
                printf("symbol %zu\n", s);
                ttc_projection_render_ascii(grid, stdout);
            } else {
                ttc_projection_render_pgm(grid, stdout);
            }
        }
    }

    free(symbols);
    return 0;
}
