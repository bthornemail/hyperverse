#include "ttc_projection.h"
#include "ttc_witness.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
    MODE_ASCII = 0,
    MODE_RAW = 1,
    MODE_JSON = 2
} OutputMode;

static void usage(const char *argv0) {
    fprintf(stderr,
        "usage: %s [-m ascii|raw|json] [-f frame_bytes]\n"
        "  reads bytes from stdin and emits a semantic witness projection\n",
        argv0);
}

static uint8_t *read_all_stdin(size_t *out_len) {
    uint8_t *buf = NULL;
    size_t len = 0;
    size_t cap = 0;
    int ch;
    while ((ch = fgetc(stdin)) != EOF) {
        if (len == cap) {
            size_t new_cap = cap ? cap * 2u : 256u;
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

static void emit_json(const uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH], const ttc_witness_step *steps, size_t step_count, int frame_bytes) {
    int y;
    int x;
    size_t i;
    printf("{\n");
    printf("  \"kind\":\"ttc.witness.projection.v1\",\n");
    printf("  \"surface\":\"semantic_witness_v1\",\n");
    printf("  \"width\":%d,\n", TTC_WITNESS_WIDTH);
    printf("  \"height\":%d,\n", TTC_WITNESS_HEIGHT);
    printf("  \"frame_bytes\":%d,\n", frame_bytes);
    printf("  \"steps\":[\n");
    for (i = 0; i < step_count; i++) {
        const ttc_witness_step *s = &steps[i];
        printf("    {\"tick\":%llu,\"byte\":%u,\"binary\":%u,\"hexwt\":%u,\"chiral\":%d,\"winner\":%d,\"cycle\":%d,\"lane\":%u,\"channel\":%u,\"orient\":%u,\"quadrant\":%u,\"slot\":%u,\"ring_index\":%u,\"addr_word\":%u,\"incidence_coeff\":%u,\"digit\":%d}%s\n",
               (unsigned long long)s->tick, s->byte, s->binary, s->hexwt, s->chiral, s->winner,
               s->cycle, (unsigned)s->address.lane, (unsigned)s->address.channel, (unsigned)s->address.orient,
               (unsigned)s->address.quadrant, (unsigned)s->address.slot, (unsigned)s->address.ring_index,
               (unsigned)s->address.addr_word, (unsigned)s->address.incidence_coeff, s->digit,
               (i + 1u < step_count) ? "," : "");
    }
    printf("  ],\n");
    printf("  \"grid\":[\n");
    for (y = 0; y < TTC_WITNESS_HEIGHT; y++) {
        printf("    [");
        for (x = 0; x < TTC_WITNESS_WIDTH; x++) {
            printf("%u", (unsigned)grid[y][x]);
            if (x + 1 < TTC_WITNESS_WIDTH) {
                putchar(',');
            }
        }
        printf("]%s\n", (y + 1 < TTC_WITNESS_HEIGHT) ? "," : "");
    }
    printf("  ]\n");
    printf("}\n");
}

int main(int argc, char **argv) {
    OutputMode mode = MODE_ASCII;
    int frame_bytes = 16;
    uint8_t *buf = NULL;
    size_t buf_len = 0;
    uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH];
    ttc_witness_step *steps = NULL;
    size_t step_count = 0;
    size_t step_cap = 0;
    size_t offset;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
            i++;
            if (strcmp(argv[i], "ascii") == 0) mode = MODE_ASCII;
            else if (strcmp(argv[i], "raw") == 0 || strcmp(argv[i], "pgm") == 0) mode = MODE_RAW;
            else if (strcmp(argv[i], "json") == 0) mode = MODE_JSON;
            else {
                usage(argv[0]);
                return 1;
            }
        } else if (strcmp(argv[i], "-f") == 0 && i + 1 < argc) {
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

    buf = read_all_stdin(&buf_len);
    if (buf_len > 0u && !buf) {
        fprintf(stderr, "allocation failure\n");
        return 1;
    }

    ttc_projection_clear_grid(grid);
    for (offset = 0; offset + (size_t)frame_bytes <= buf_len; offset += (size_t)frame_bytes) {
        size_t j;
        for (j = 0; j < (size_t)frame_bytes; j++) {
            ttc_witness_step step;
            ttc_witness_step *next;
            if (ttc_witness_encode_step(buf[offset + j], step_count, &step) != TTC_WITNESS_OK) {
                free(steps);
                free(buf);
                fprintf(stderr, "witness projection failure\n");
                return 1;
            }
            ttc_projection_place_step(grid, &step);
            if (step_count == step_cap) {
                size_t new_cap = step_cap ? step_cap * 2u : 64u;
                next = (ttc_witness_step *)realloc(steps, new_cap * sizeof(*steps));
                if (!next) {
                    free(steps);
                    free(buf);
                    fprintf(stderr, "allocation failure\n");
                    return 1;
                }
                steps = next;
                step_cap = new_cap;
            }
            steps[step_count++] = step;
        }
    }

    if (mode == MODE_ASCII) {
        ttc_projection_render_ascii(grid, stdout);
    } else if (mode == MODE_RAW) {
        ttc_projection_render_pgm(grid, stdout);
    } else {
        emit_json(grid, steps, step_count, frame_bytes);
    }

    free(steps);
    free(buf);
    return 0;
}
