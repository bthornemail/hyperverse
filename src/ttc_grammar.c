/* LAYER: grammar
 * Owns structural interpretation of control symbols only.
 */
#include "ttc_grammar.h"

void ttc_grammar_interpret_byte(uint8_t input, uint8_t prior_escape_depth, ttc_grammar_state *out) {
    if (!out) return;
    out->input = input;
    out->role = TTC_GRAMMAR_ROLE_PAYLOAD;
    out->escape_depth = prior_escape_depth;
    out->scope_axis = 0u;
    out->structural_anchor = 0u;
    out->header8_class = (uint8_t)((input >> 5u) & 0x07u);

    switch (input) {
        case 0x00u:
            out->role = TTC_GRAMMAR_ROLE_NULL;
            out->structural_anchor = 1u;
            out->escape_depth = 0u;
            break;
        case 0x1Bu:
            out->role = TTC_GRAMMAR_ROLE_ESC;
            out->structural_anchor = 1u;
            out->escape_depth = (uint8_t)(prior_escape_depth + 1u);
            break;
        case 0x1Cu:
            out->role = TTC_GRAMMAR_ROLE_FS;
            out->scope_axis = 1u;
            break;
        case 0x1Du:
            out->role = TTC_GRAMMAR_ROLE_GS;
            out->scope_axis = 2u;
            break;
        case 0x1Eu:
            out->role = TTC_GRAMMAR_ROLE_RS;
            out->scope_axis = 3u;
            break;
        case 0x1Fu:
            out->role = TTC_GRAMMAR_ROLE_US;
            out->scope_axis = 4u;
            break;
        default:
            if (prior_escape_depth > 0u) {
                out->escape_depth = (uint8_t)(prior_escape_depth - 1u);
            }
            break;
    }
}
