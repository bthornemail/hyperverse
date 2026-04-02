/* LAYER: witness
 * Owns semantic witness construction only.
 */
#include "ttc_witness.h"

#include <stdlib.h>

static const int TTC_FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

static const uint8_t TTC_HEX_WEIGHT[8] = {
    0x01, 0x02, 0x04, 0x40, 0x10, 0x08, 0x20, 0x80
};

static void *ttc_realloc_array(void *ptr, size_t elem_size, size_t count) {
    if (count == 0 || elem_size == 0) {
        free(ptr);
        return NULL;
    }
    return realloc(ptr, elem_size * count);
}

static int ttc_push_byte(uint8_t **buf, size_t *len, size_t *cap, uint8_t value) {
    uint8_t *next;
    size_t new_cap;

    if (!buf || !len || !cap) {
        return TTC_WITNESS_ERR_ARG;
    }
    if (*len == *cap) {
        new_cap = (*cap == 0) ? 256u : (*cap * 2u);
        next = (uint8_t *)ttc_realloc_array(*buf, sizeof(uint8_t), new_cap);
        if (!next) {
            return TTC_WITNESS_ERR_NOMEM;
        }
        *buf = next;
        *cap = new_cap;
    }
    (*buf)[(*len)++] = value;
    return TTC_WITNESS_OK;
}

static int ttc_fano_winner(uint64_t tick, int chiral) {
    int line = (int)(tick % 7u);
    return chiral ? TTC_FANO_LINES[line][2] : TTC_FANO_LINES[line][0];
}

static uint8_t ttc_braille_hexwt(uint8_t byte) {
    int i;
    uint8_t out = 0;
    for (i = 0; i < 8; i++) {
        if (byte & (uint8_t)(1u << i)) {
            out = (uint8_t)(out + TTC_HEX_WEIGHT[i]);
        }
    }
    return out;
}

static int ttc_factoradic_digit(int hexwt, int radix) {
    if (radix <= 0) {
        return 0;
    }
    return hexwt % radix;
}

int ttc_witness_a13_encode(const uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len) {
    size_t cap;
    size_t n = 0;
    size_t i;
    uint8_t *buf;

    if (!out || !out_len || (in_len > 0 && !in)) {
        return TTC_WITNESS_ERR_ARG;
    }

    cap = (in_len * 2u) + 2u;
    buf = (uint8_t *)malloc(cap);
    if (!buf) {
        return TTC_WITNESS_ERR_NOMEM;
    }

    buf[n++] = 0xC0u;
    for (i = 0; i < in_len; i++) {
        uint8_t b = in[i];
        if (b == 0xC0u) {
            buf[n++] = 0xDBu;
            buf[n++] = 0xDCu;
        } else if (b == 0xDBu) {
            buf[n++] = 0xDBu;
            buf[n++] = 0xDDu;
        } else {
            buf[n++] = b;
        }
    }
    buf[n++] = 0xC0u;

    *out = buf;
    *out_len = n;
    return TTC_WITNESS_OK;
}

int ttc_witness_a13_decode(const uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len) {
    size_t i;
    int in_frame = 0;
    uint8_t *buf = NULL;
    size_t n = 0;
    size_t cap = 0;
    int rc;

    if (!out || !out_len || (in_len > 0 && !in)) {
        return TTC_WITNESS_ERR_ARG;
    }

    for (i = 0; i < in_len; i++) {
        uint8_t b = in[i];
        if (!in_frame) {
            if (b == 0xC0u) {
                in_frame = 1;
            }
            continue;
        }
        if (b == 0xC0u) {
            *out = buf;
            *out_len = n;
            return TTC_WITNESS_OK;
        }
        if (b == 0xDBu) {
            if (i + 1 >= in_len) {
                free(buf);
                return TTC_WITNESS_ERR_FORMAT;
            }
            i++;
            if (in[i] == 0xDCu) {
                rc = ttc_push_byte(&buf, &n, &cap, 0xC0u);
            } else if (in[i] == 0xDDu) {
                rc = ttc_push_byte(&buf, &n, &cap, 0xDBu);
            } else {
                free(buf);
                return TTC_WITNESS_ERR_FORMAT;
            }
        } else {
            rc = ttc_push_byte(&buf, &n, &cap, b);
        }
        if (rc != TTC_WITNESS_OK) {
            free(buf);
            return rc;
        }
    }

    free(buf);
    return TTC_WITNESS_ERR_FORMAT;
}

int ttc_witness_stream_to_symbols(const uint8_t *stream, size_t stream_len, ttc_witness_symbol **out_symbols, size_t *out_count) {
    size_t count;
    size_t s;
    ttc_witness_symbol *symbols;

    if (!out_symbols || !out_count || (stream_len > 0 && !stream)) {
        return TTC_WITNESS_ERR_ARG;
    }

    count = (stream_len + TTC_WITNESS_SYMBOL_PAYLOAD - 1u) / TTC_WITNESS_SYMBOL_PAYLOAD;
    if (count == 0) {
        count = 1;
    }

    symbols = (ttc_witness_symbol *)calloc(count, sizeof(*symbols));
    if (!symbols) {
        return TTC_WITNESS_ERR_NOMEM;
    }

    for (s = 0; s < count; s++) {
        size_t offset = s * TTC_WITNESS_SYMBOL_PAYLOAD;
        size_t remain = (stream_len > offset) ? (stream_len - offset) : 0u;
        size_t take = remain > TTC_WITNESS_SYMBOL_PAYLOAD ? TTC_WITNESS_SYMBOL_PAYLOAD : remain;
        size_t i;
        symbols[s].coords[0] = (uint8_t)take;
        symbols[s].coords[1] = (uint8_t)((s + 1u < count) ? 1u : 0u);
        for (i = 0; i < take; i++) {
            symbols[s].coords[2u + i] = stream[offset + i];
        }
    }

    *out_symbols = symbols;
    *out_count = count;
    return TTC_WITNESS_OK;
}

int ttc_witness_symbols_to_stream(const ttc_witness_symbol *symbols, size_t symbol_count, uint8_t **out_stream, size_t *out_len) {
    uint8_t *buf = NULL;
    size_t n = 0;
    size_t cap = 0;
    size_t i;
    int rc;

    if (!out_stream || !out_len || (symbol_count > 0 && !symbols)) {
        return TTC_WITNESS_ERR_ARG;
    }

    for (i = 0; i < symbol_count; i++) {
        size_t take = symbols[i].coords[0];
        size_t k;
        if (take > TTC_WITNESS_SYMBOL_PAYLOAD) {
            free(buf);
            return TTC_WITNESS_ERR_RANGE;
        }
        for (k = 0; k < take; k++) {
            rc = ttc_push_byte(&buf, &n, &cap, symbols[i].coords[2u + k]);
            if (rc != TTC_WITNESS_OK) {
                free(buf);
                return rc;
            }
        }
    }

    *out_stream = buf;
    *out_len = n;
    return TTC_WITNESS_OK;
}

int ttc_witness_encode_step(uint8_t byte, uint64_t tick, ttc_witness_step *out) {
    ttc_incidence incidence;
    ttc_grammar_state grammar;
    int winner;

    if (!out) {
        return TTC_WITNESS_ERR_ARG;
    }

    out->tick = tick;
    out->byte = byte;
    out->binary = byte;
    out->hexwt = ttc_braille_hexwt(byte);
    out->chiral = (int)((tick / 7u) % 2u);
    winner = ttc_fano_winner(tick, out->chiral);
    ttc_incidence_from_tick(tick, (uint8_t)winner, &incidence);
    ttc_grammar_interpret_byte(byte, 0u, &grammar);
    return ttc_witness_encode_step_structured(byte, &incidence, &grammar, out);
}

int ttc_witness_encode_step_structured(uint8_t byte, const ttc_incidence *incidence, const ttc_grammar_state *grammar, ttc_witness_step *out) {
    int cycle;
    int winner;
    int radix;
    if (!out || !incidence || !grammar) {
        return TTC_WITNESS_ERR_ARG;
    }
    out->tick = incidence->tick;
    out->byte = byte;
    out->binary = byte;
    out->hexwt = ttc_braille_hexwt(byte);
    out->chiral = (int)incidence->chiral;
    winner = ttc_fano_winner(incidence->tick, out->chiral);
    cycle = (int)(incidence->tick / 7u);
    radix = (int)((incidence->layer % 10u) + 1u);

    out->winner = winner;
    out->cycle = cycle;
    if (ttc_address_from_structure(incidence, grammar, (uint8_t)winner, &out->address) != 0) {
        return TTC_WITNESS_ERR_ARG;
    }
    out->digit = ttc_factoradic_digit(out->hexwt + (int)(incidence->trinomial_coeff % 10u), radix);
    return TTC_WITNESS_OK;
}
