#include "ttc_framework.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void usage(const char *argv0) {
    fprintf(stderr,
        "usage:\n"
        "  %s runtime [--rule current|delta64] [--seed N]\n"
        "  %s witness-slot-encode\n"
        "  %s witness-slot-decode\n"
        "  %s witness-render\n"
        "  %s matrix-encode [--ascii|--pbm|--pgm] [--module-px N]\n"
        "  %s matrix-decode\n"
        "  %s aztec-encode [compat alias; not standards Aztec]\n"
        "  %s aztec-decode [compat alias; not standards Aztec]\n",
        argv0, argv0, argv0, argv0, argv0, argv0, argv0, argv0);
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

static int cmd_runtime(int argc, char **argv) {
    ttc_runtime_config config;
    ttc_runtime rt;
    int i;
    int ch;
    uint8_t escape_depth = 0u;

    ttc_runtime_config_default(&config);
    for (i = 0; i < argc; i++) {
        if (strcmp(argv[i], "--rule") == 0 && i + 1 < argc) {
            config.rule_version = (strcmp(argv[++i], "delta64") == 0) ? TTC_RULE_V2_DELTA64 : TTC_RULE_V1_CURRENT;
        } else if (strcmp(argv[i], "--seed") == 0 && i + 1 < argc) {
            config.seed = (uint64_t)strtoull(argv[++i], NULL, 0);
        } else {
            usage("ttc_framework");
            return 1;
        }
    }

    ttc_runtime_init(&rt, &config);
    while ((ch = getchar()) != EOF) {
        ttc_event ev;
        ttc_incidence incidence;
        ttc_grammar_state grammar;
        ttc_address address;
        if (ttc_runtime_step(&rt, (uint8_t)ch, &ev) != 0) {
            return 1;
        }
        ttc_incidence_from_tick(ev.tick, ev.winner, &incidence);
        ttc_grammar_interpret_byte(ev.input, escape_depth, &grammar);
        escape_depth = grammar.escape_depth;
        if (ttc_address_from_structure(&incidence, &grammar, ev.winner, &address) != 0) {
            return 1;
        }
        printf("{\"rule_version\":%d,\"tick\":%llu,\"input\":%u,\"state8\":%u,\"curr_state\":%llu,\"incidence_coeff\":%u,\"grammar_role\":%u,\"escape_depth\":%u,\"address_slot\":%u,\"address_lane\":%u,\"address_channel\":%u}\n",
               (int)ev.rule_version, (unsigned long long)ev.tick, ev.input, ev.state8,
               (unsigned long long)ev.curr_state, incidence.trinomial_coeff, (unsigned)grammar.role, (unsigned)grammar.escape_depth,
               (unsigned)address.slot, (unsigned)address.lane, (unsigned)address.channel);
    }
    return 0;
}

static int cmd_witness_slot_encode(void) {
    size_t input_len = 0;
    uint8_t *buf = read_all_stdin(&input_len);
    uint8_t *a13 = NULL;
    ttc_witness_symbol *symbols = NULL;
    size_t count = 0;
    size_t a13_len = 0;
    int rc;
    size_t i;

    if (input_len > 0u && !buf) return 1;
    rc = ttc_witness_a13_encode(buf, input_len, &a13, &a13_len);
    if (rc != TTC_WITNESS_OK) {
        free(buf);
        return 1;
    }
    rc = ttc_witness_stream_to_symbols(a13, a13_len, &symbols, &count);
    if (rc != TTC_WITNESS_OK) {
        free(a13);
        free(buf);
        return 1;
    }
    for (i = 0; i < count; i++) {
        size_t j;
        for (j = 0; j < TTC_WITNESS_SYMBOL_SLOTS; j++) {
            if (j) putchar(' ');
            printf("%u", (unsigned)symbols[i].coords[j]);
        }
        putchar('\n');
    }
    free(symbols);
    free(a13);
    free(buf);
    return 0;
}

static int cmd_witness_slot_decode(void) {
    ttc_witness_symbol *symbols = NULL;
    size_t symbol_count = 0;
    size_t cap = 0;
    unsigned int value;
    size_t idx = 0;
    uint8_t *stream = NULL;
    uint8_t *artifact = NULL;
    size_t stream_len = 0;
    size_t artifact_len = 0;
    int rc;

    while (scanf("%u", &value) == 1) {
        ttc_witness_symbol *next;
        if (value > 255u) {
            free(symbols);
            return 1;
        }
        if (idx % TTC_WITNESS_SYMBOL_SLOTS == 0u) {
            size_t new_count = symbol_count + 1u;
            if (new_count > cap) {
                size_t new_cap = cap ? cap * 2u : 8u;
                next = (ttc_witness_symbol *)realloc(symbols, new_cap * sizeof(*symbols));
                if (!next) {
                    free(symbols);
                    return 1;
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
        free(symbols);
        return 1;
    }
    rc = ttc_witness_symbols_to_stream(symbols, symbol_count, &stream, &stream_len);
    free(symbols);
    if (rc != TTC_WITNESS_OK) return 1;
    rc = ttc_witness_a13_decode(stream, stream_len, &artifact, &artifact_len);
    free(stream);
    if (rc != TTC_WITNESS_OK) {
        free(artifact);
        return 1;
    }
    if (artifact_len > 0u) fwrite(artifact, 1u, artifact_len, stdout);
    free(artifact);
    return 0;
}

static int cmd_witness_render(void) {
    ttc_witness_symbol *symbols = NULL;
    size_t symbol_count = 0;
    size_t cap = 0;
    unsigned int value;
    size_t idx = 0;

    while (scanf("%u", &value) == 1) {
        ttc_witness_symbol *next;
        if (value > 255u) {
            free(symbols);
            return 1;
        }
        if (idx % TTC_WITNESS_SYMBOL_SLOTS == 0u) {
            size_t new_count = symbol_count + 1u;
            if (new_count > cap) {
                size_t new_cap = cap ? cap * 2u : 8u;
                next = (ttc_witness_symbol *)realloc(symbols, new_cap * sizeof(*symbols));
                if (!next) {
                    free(symbols);
                    return 1;
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
        free(symbols);
        return 1;
    }
    if (symbol_count > 0u) {
        uint8_t grid[TTC_WITNESS_HEIGHT][TTC_WITNESS_WIDTH];
        ttc_projection_symbol_to_grid(&symbols[0], grid);
        free(symbols);
        return ttc_projection_render_ascii(grid, stdout) == TTC_WITNESS_OK ? 0 : 1;
    }
    free(symbols);
    return 0;
}

static int cmd_matrix_encode(int argc, char **argv) {
    ttc_matrix_symbol sym;
    ttc_matrix_policy policy;
    size_t len = 0;
    uint8_t *buf;
    unsigned module_px = 4u;
    enum { MODE_ASCII, MODE_PBM, MODE_PGM } mode = MODE_ASCII;
    int i;
    int rc;

    for (i = 0; i < argc; i++) {
        if (strcmp(argv[i], "--ascii") == 0) mode = MODE_ASCII;
        else if (strcmp(argv[i], "--pbm") == 0) mode = MODE_PBM;
        else if (strcmp(argv[i], "--pgm") == 0) mode = MODE_PGM;
        else if (strcmp(argv[i], "--module-px") == 0 && i + 1 < argc) module_px = (unsigned)strtoul(argv[++i], NULL, 0);
        else {
            usage("ttc_framework");
            return 1;
        }
    }

    buf = read_all_stdin(&len);
    if (len > 0u && !buf) return 1;
    ttc_matrix_policy_default(&policy);
    ttc_matrix_symbol_init(&sym);
    rc = ttc_matrix_encode_bytes(buf, len, &policy, &sym);
    free(buf);
    if (rc != TTC_MATRIX_OK) return 1;
    if (mode == MODE_ASCII) rc = ttc_matrix_render_ascii(&sym, stdout);
    else if (mode == MODE_PBM) rc = ttc_matrix_render_pbm(&sym, stdout);
    else rc = ttc_matrix_render_pgm(&sym, module_px, stdout);
    ttc_matrix_symbol_free(&sym);
    return rc == TTC_MATRIX_OK ? 0 : 1;
}

static int cmd_matrix_decode(void) {
    size_t len = 0;
    uint8_t *buf = read_all_stdin(&len);
    uint8_t *out = NULL;
    size_t out_len = 0;
    int rc;

    if (!buf || len != (27u * 27u)) {
        free(buf);
        return 1;
    }
    rc = ttc_matrix_decode_modules(buf, 27u, 27u, &out, &out_len, NULL);
    free(buf);
    if (rc != TTC_MATRIX_OK) {
        free(out);
        return 1;
    }
    if (out_len > 0u) fwrite(out, 1u, out_len, stdout);
    free(out);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }
    if (strcmp(argv[1], "runtime") == 0) return cmd_runtime(argc - 2, argv + 2);
    if (strcmp(argv[1], "witness-slot-encode") == 0) return cmd_witness_slot_encode();
    if (strcmp(argv[1], "witness-slot-decode") == 0) return cmd_witness_slot_decode();
    if (strcmp(argv[1], "witness-render") == 0) return cmd_witness_render();
    if (strcmp(argv[1], "matrix-encode") == 0) return cmd_matrix_encode(argc - 2, argv + 2);
    if (strcmp(argv[1], "matrix-decode") == 0) return cmd_matrix_decode();
    if (strcmp(argv[1], "aztec-encode") == 0) return cmd_matrix_encode(argc - 2, argv + 2);
    if (strcmp(argv[1], "aztec-decode") == 0) return cmd_matrix_decode();
    usage(argv[0]);
    return 1;
}
