/* LAYER: transport-compat
 * Compatibility alias only; reserved aztec name must not redefine TTC matrix.
 */
#include "ttc_aztec.h"

/* Compatibility layer only.
 * This module currently forwards to the TTC matrix transport grid.
 * It is not standards Aztec. Keep the aztec name reserved for a future
 * standards-compliant barcode/scannable framing implementation.
 */

void ttc_aztec_policy_default(ttc_aztec_policy *policy) {
    ttc_matrix_policy_default(policy);
}

void ttc_aztec_symbol_init(ttc_aztec_symbol *sym) {
    ttc_matrix_symbol_init(sym);
}

void ttc_aztec_symbol_free(ttc_aztec_symbol *sym) {
    ttc_matrix_symbol_free(sym);
}

int ttc_aztec_encode_bytes(const uint8_t *in_bytes, size_t in_len, const ttc_aztec_policy *policy, ttc_aztec_symbol *out_sym) {
    return ttc_matrix_encode_bytes(in_bytes, in_len, policy, out_sym);
}

int ttc_aztec_decode_modules(const uint8_t *modules, uint16_t width, uint16_t height, uint8_t **out_bytes, size_t *out_len, ttc_aztec_decode_report *out_report) {
    return ttc_matrix_decode_modules(modules, width, height, out_bytes, out_len, out_report);
}

int ttc_aztec_render_ascii(const ttc_aztec_symbol *sym, FILE *out) {
    return ttc_matrix_render_ascii(sym, out);
}

int ttc_aztec_render_pbm(const ttc_aztec_symbol *sym, FILE *out) {
    return ttc_matrix_render_pbm(sym, out);
}

int ttc_aztec_render_pgm(const ttc_aztec_symbol *sym, unsigned module_px, FILE *out) {
    return ttc_matrix_render_pgm(sym, module_px, out);
}

int ttc_aztec_verify_roundtrip(const uint8_t *in_bytes, size_t in_len, const ttc_aztec_policy *policy) {
    return ttc_matrix_verify_roundtrip(in_bytes, in_len, policy);
}
