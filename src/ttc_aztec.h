#ifndef TTC_AZTEC_H
#define TTC_AZTEC_H

#include "ttc_matrix.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Compatibility layer only.
 * This module currently aliases the TTC matrix transport grid.
 * It is not standards Aztec. The aztec name is reserved for a future
 * standards-compliant barcode/scannable framing implementation.
 */

#define TTC_AZTEC_MAX_DIM TTC_MATRIX_MAX_DIM

typedef ttc_matrix_status ttc_aztec_status;
typedef ttc_matrix_ecc_percent ttc_aztec_ecc_percent;
typedef ttc_matrix_symbol_kind ttc_aztec_symbol_kind;
typedef ttc_matrix_meta ttc_aztec_meta;
typedef ttc_matrix_symbol ttc_aztec_symbol;
typedef ttc_matrix_policy ttc_aztec_policy;
typedef ttc_matrix_decode_report ttc_aztec_decode_report;

#define TTC_AZTEC_OK TTC_MATRIX_OK
#define TTC_AZTEC_ERR_ARG TTC_MATRIX_ERR_ARG
#define TTC_AZTEC_ERR_RANGE TTC_MATRIX_ERR_RANGE
#define TTC_AZTEC_ERR_NOMEM TTC_MATRIX_ERR_NOMEM
#define TTC_AZTEC_ERR_UNSUPPORTED TTC_MATRIX_ERR_UNSUPPORTED
#define TTC_AZTEC_ERR_ECC TTC_MATRIX_ERR_ECC
#define TTC_AZTEC_ERR_FORMAT TTC_MATRIX_ERR_FORMAT
#define TTC_AZTEC_ERR_MISMATCH TTC_MATRIX_ERR_MISMATCH
#define TTC_AZTEC_ECC_CHECKSUM8 TTC_MATRIX_ECC_CHECKSUM8
#define TTC_AZTEC_SYMBOL_FULL TTC_MATRIX_SYMBOL_FULL

void ttc_aztec_policy_default(ttc_aztec_policy *policy);
void ttc_aztec_symbol_init(ttc_aztec_symbol *sym);
void ttc_aztec_symbol_free(ttc_aztec_symbol *sym);
int ttc_aztec_encode_bytes(const uint8_t *in_bytes, size_t in_len, const ttc_aztec_policy *policy, ttc_aztec_symbol *out_sym);
int ttc_aztec_decode_modules(const uint8_t *modules, uint16_t width, uint16_t height, uint8_t **out_bytes, size_t *out_len, ttc_aztec_decode_report *out_report);
int ttc_aztec_render_ascii(const ttc_aztec_symbol *sym, FILE *out);
int ttc_aztec_render_pbm(const ttc_aztec_symbol *sym, FILE *out);
int ttc_aztec_render_pgm(const ttc_aztec_symbol *sym, unsigned module_px, FILE *out);
int ttc_aztec_verify_roundtrip(const uint8_t *in_bytes, size_t in_len, const ttc_aztec_policy *policy);

#ifdef __cplusplus
}
#endif

#endif
