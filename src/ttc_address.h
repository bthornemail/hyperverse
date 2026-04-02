#ifndef TTC_ADDRESS_H
#define TTC_ADDRESS_H

#include <stdint.h>

#include "ttc_incidence.h"
#include "ttc_grammar.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t tick;
    uint8_t role;
    uint8_t escape_depth;
    uint8_t scope_axis;
    uint8_t structural_anchor;
    uint8_t lane;
    uint8_t channel;
    uint8_t orient;
    uint8_t quadrant;
    uint8_t slot;
    uint8_t ring_index;
    uint16_t addr_word;
    uint32_t incidence_coeff;
} ttc_address;

typedef struct {
    uint8_t channel;
    uint8_t lane;
    uint16_t addr_word;
} ttc_channel_lane_ref;

typedef struct {
    uint8_t slot;
    uint8_t ring_index;
} ttc_slot_ref;

int ttc_address_from_structure(const ttc_incidence *incidence, const ttc_grammar_state *grammar, uint8_t winner, ttc_address *out);
void ttc_address_to_channel_lane_ref(const ttc_address *address, ttc_channel_lane_ref *out);
void ttc_address_to_slot_ref(const ttc_address *address, ttc_slot_ref *out);

#ifdef __cplusplus
}
#endif

#endif
