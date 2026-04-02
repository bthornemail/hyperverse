/* LAYER: incidence
 * Owns Pascal/simplex expansion metadata only.
 */
#include "ttc_incidence.h"

static uint32_t ttc_choose_u32(uint32_t n, uint32_t k) {
    uint32_t i;
    uint32_t r = 1u;
    if (k > n) return 0u;
    if (k > n - k) k = n - k;
    for (i = 1u; i <= k; i++) {
        r = (r * (n - k + i)) / i;
    }
    return r;
}

void ttc_incidence_from_tick(uint64_t tick, uint8_t winner, ttc_incidence *out) {
    uint32_t layer;
    uint32_t left;
    uint32_t middle;
    uint32_t right;
    if (!out) return;
    layer = (uint32_t)(tick % 16u);
    left = (uint32_t)(winner % (layer + 1u));
    middle = (uint32_t)((tick / 7u) % (layer + 1u - left));
    right = layer - left - middle;

    out->tick = tick;
    out->arity = 3u;
    out->line_index = (uint8_t)(tick % 7u);
    out->chiral = (uint8_t)((tick / 7u) % 2u);
    out->branch = (uint8_t)(winner % 3u);
    out->layer = (uint8_t)layer;
    out->lane_mod = (uint8_t)((left + 2u * middle + 3u * right) % 15u);
    out->binomial_left = (uint16_t)ttc_choose_u32(layer, left);
    out->binomial_right = (uint16_t)ttc_choose_u32(layer, right);
    out->trinomial_coeff = ttc_choose_u32(layer, left) * ttc_choose_u32(layer - left, middle);
}
