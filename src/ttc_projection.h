#ifndef TTC_PROJECTION_H
#define TTC_PROJECTION_H

#include <stdint.h>
#include <stdio.h>

#include "ttc_address.h"
#include "ttc_witness.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTC_PROJECTION_WIDTH 27
#define TTC_PROJECTION_HEIGHT 27

void ttc_projection_clear_grid(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH]);
char ttc_projection_ascii_glyph(uint8_t v);
void ttc_projection_symbol_to_grid(const ttc_witness_symbol *symbol, uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH]);
void ttc_projection_place_address(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], const ttc_address *address, uint8_t value);
void ttc_projection_place_step(uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], const ttc_witness_step *step);
int ttc_projection_render_ascii(const uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], FILE *out);
int ttc_projection_render_pgm(const uint8_t grid[TTC_PROJECTION_HEIGHT][TTC_PROJECTION_WIDTH], FILE *out);

#ifdef __cplusplus
}
#endif

#endif
