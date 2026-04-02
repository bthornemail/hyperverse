/* LAYER: address
 * Owns lane/channel/slot/address derivation only.
 */
#include "ttc_address.h"

int ttc_address_from_structure(const ttc_incidence *incidence, const ttc_grammar_state *grammar, uint8_t winner, ttc_address *out) {
    int cycle;
    int lane;
    int channel;
    int orient;
    int quadrant;

    if (!incidence || !grammar || !out) {
        return -1;
    }

    cycle = (int)(incidence->tick / 7u);
    lane = (int)((incidence->lane_mod + grammar->scope_axis + grammar->escape_depth) % 15u);
    channel = (winner + grammar->role + grammar->header8_class) % 4;
    orient = ((cycle / 15) + (winner % 2) + grammar->structural_anchor + incidence->branch) % 4;
    quadrant = channel * 4 + orient;

    out->tick = incidence->tick;
    out->role = (uint8_t)grammar->role;
    out->escape_depth = grammar->escape_depth;
    out->scope_axis = grammar->scope_axis;
    out->structural_anchor = grammar->structural_anchor;
    out->lane = (uint8_t)lane;
    out->channel = (uint8_t)channel;
    out->orient = (uint8_t)orient;
    out->quadrant = (uint8_t)quadrant;
    out->slot = (uint8_t)((quadrant * 15 + lane) % 60);
    out->ring_index = (uint8_t)((incidence->layer + lane + grammar->escape_depth) % 60u);
    out->addr_word = (uint16_t)(((uint16_t)channel << 12u) | ((uint16_t)lane << 8u) | ((uint16_t)grammar->role << 4u) | (uint16_t)out->slot);
    out->incidence_coeff = incidence->trinomial_coeff;
    return 0;
}

void ttc_address_to_channel_lane_ref(const ttc_address *address, ttc_channel_lane_ref *out) {
    if (!address || !out) {
        return;
    }
    out->channel = address->channel;
    out->lane = address->lane;
    out->addr_word = address->addr_word;
}

void ttc_address_to_slot_ref(const ttc_address *address, ttc_slot_ref *out) {
    if (!address || !out) {
        return;
    }
    out->slot = address->slot;
    out->ring_index = address->ring_index;
}
