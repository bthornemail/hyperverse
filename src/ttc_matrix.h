#ifndef TTC_MATRIX_H
#define TTC_MATRIX_H

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/* TTC matrix transport:
 * deterministic TTC-specific reversible byte transport grid.
 * This is not standards Aztec framing.
 */

#define TTC_MATRIX_MAX_DIM 151

typedef enum {
    TTC_MATRIX_OK = 0,
    TTC_MATRIX_ERR_ARG = -1,
    TTC_MATRIX_ERR_RANGE = -2,
    TTC_MATRIX_ERR_NOMEM = -3,
    TTC_MATRIX_ERR_UNSUPPORTED = -4,
    TTC_MATRIX_ERR_ECC = -5,
    TTC_MATRIX_ERR_FORMAT = -6,
    TTC_MATRIX_ERR_MISMATCH = -7
} ttc_matrix_status;

typedef enum {
    TTC_MATRIX_ECC_CHECKSUM8 = 8
} ttc_matrix_ecc_percent;

typedef enum {
    TTC_MATRIX_SYMBOL_FULL = 1
} ttc_matrix_symbol_kind;

typedef struct {
    uint16_t width;
    uint16_t height;
    uint16_t layers;
    uint16_t data_codewords;
    uint16_t ecc_codewords;
    uint8_t compact;
    uint8_t reserved[7];
} ttc_matrix_meta;

typedef struct {
    ttc_matrix_meta meta;
    uint8_t *modules;
} ttc_matrix_symbol;

typedef struct {
    ttc_matrix_symbol_kind symbol_kind;
    ttc_matrix_ecc_percent ecc_percent;
    uint8_t byte_mode_only;
    uint8_t reserved[7];
} ttc_matrix_policy;

typedef struct {
    uint16_t width;
    uint16_t height;
    uint16_t layers;
    uint8_t ecc_ok;
    uint8_t compact;
    uint8_t reserved[4];
} ttc_matrix_decode_report;

void ttc_matrix_policy_default(ttc_matrix_policy *policy);
void ttc_matrix_symbol_init(ttc_matrix_symbol *sym);
void ttc_matrix_symbol_free(ttc_matrix_symbol *sym);
int ttc_matrix_encode_bytes(const uint8_t *in_bytes, size_t in_len, const ttc_matrix_policy *policy, ttc_matrix_symbol *out_sym);
int ttc_matrix_decode_modules(const uint8_t *modules, uint16_t width, uint16_t height, uint8_t **out_bytes, size_t *out_len, ttc_matrix_decode_report *out_report);
int ttc_matrix_render_ascii(const ttc_matrix_symbol *sym, FILE *out);
int ttc_matrix_render_pbm(const ttc_matrix_symbol *sym, FILE *out);
int ttc_matrix_render_pgm(const ttc_matrix_symbol *sym, unsigned module_px, FILE *out);
int ttc_matrix_verify_roundtrip(const uint8_t *in_bytes, size_t in_len, const ttc_matrix_policy *policy);

#ifdef __cplusplus
}
#endif

#endif
