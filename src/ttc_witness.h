#ifndef TTC_WITNESS_H
#define TTC_WITNESS_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "ttc_address.h"
#include "ttc_incidence.h"
#include "ttc_grammar.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTC_WITNESS_WIDTH 27
#define TTC_WITNESS_HEIGHT 27
#define TTC_WITNESS_SYMBOL_SLOTS 60
#define TTC_WITNESS_SYMBOL_PAYLOAD 58

typedef enum {
    TTC_WITNESS_OK = 0,
    TTC_WITNESS_ERR_ARG = -1,
    TTC_WITNESS_ERR_RANGE = -2,
    TTC_WITNESS_ERR_NOMEM = -3,
    TTC_WITNESS_ERR_FORMAT = -4
} ttc_witness_status;

typedef struct {
    uint8_t coords[TTC_WITNESS_SYMBOL_SLOTS];
} ttc_witness_symbol;

typedef struct {
    uint64_t tick;
    int chiral;
    int winner;
    int cycle;
    int digit;
    uint8_t byte;
    uint8_t binary;
    uint8_t hexwt;
    ttc_address address;
} ttc_witness_step;

int ttc_witness_a13_encode(const uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len);
int ttc_witness_a13_decode(const uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len);
int ttc_witness_stream_to_symbols(const uint8_t *stream, size_t stream_len, ttc_witness_symbol **out_symbols, size_t *out_count);
int ttc_witness_symbols_to_stream(const ttc_witness_symbol *symbols, size_t symbol_count, uint8_t **out_stream, size_t *out_len);
int ttc_witness_encode_step(uint8_t byte, uint64_t tick, ttc_witness_step *out);
int ttc_witness_encode_step_structured(uint8_t byte, const ttc_incidence *incidence, const ttc_grammar_state *grammar, ttc_witness_step *out);

#ifdef __cplusplus
}
#endif

#endif
