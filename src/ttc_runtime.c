/* LAYER: runtime
 * Owns canonical stepping only.
 */
#include "ttc_runtime.h"

#include <string.h>

static const uint8_t TTC_FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

static uint8_t rotl8(uint8_t x, unsigned k) {
    k &= 7u;
    return (uint8_t)((x << k) | (x >> (8u - k)));
}

static uint8_t rotr8(uint8_t x, unsigned k) {
    k &= 7u;
    return (uint8_t)((x >> k) | (x << (8u - k)));
}

static uint64_t rotl64(uint64_t x, unsigned k) {
    k &= 63u;
    return (x << k) | (x >> ((64u - k) & 63u));
}

static uint64_t rotr64(uint64_t x, unsigned k) {
    k &= 63u;
    return (x >> k) | (x << ((64u - k) & 63u));
}

static uint8_t ttc_transform_state_v1(uint8_t state, uint8_t input, uint64_t tick) {
    uint8_t b7 = (uint8_t)(tick % 7u);
    uint8_t b8 = (uint8_t)(tick & 7u);
    uint8_t law;
    uint8_t proj;
    uint8_t out;

    if (input == 0x00u) {
        return 0x00u;
    }

    law = (uint8_t)((state ^ (uint8_t)(input << 1)) & 0x03u);
    proj = (uint8_t)(rotl8(state, 1) ^ input ^ b7 ^ (uint8_t)(b8 << 2));
    proj &= 0x0Cu;

    out = (uint8_t)(law | proj);
    if (input & 0x80u) {
        out |= 0x80u;
    }
    return out;
}

static uint8_t ttc_fold7_v1(uint8_t state, uint8_t constant) {
    int i;
    for (i = 0; i < 7; i++) {
        state = (uint8_t)(rotl8(state, 1) ^ rotl8(state, 3) ^ rotr8(state, 2) ^ constant);
    }
    return state;
}

static uint64_t ttc_delta_v2(uint64_t x) {
    return rotl64(x, 1) ^ rotl64(x, 3) ^ rotr64(x, 2) ^ 0x1D1D1D1D1D1D1D1DULL;
}

static uint64_t ttc_fold7_v2(uint64_t state) {
    int i;
    for (i = 0; i < 7; i++) {
        state = ttc_delta_v2(state);
    }
    return state;
}

static void ttc_project_board_v1(uint64_t state, uint64_t tick, uint8_t board[TTC_BOARD_SLOTS]) {
    uint8_t state8 = (uint8_t)(state & 0xFFu);
    uint8_t offset = (uint8_t)((8u * (tick % 7u) + (state8 & 0x07u)) % TTC_BOARD_SLOTS);
    unsigned i;

    memset(board, 0, TTC_BOARD_SLOTS);
    for (i = 0; i < 8; i++) {
        board[(offset + i) % TTC_BOARD_SLOTS] = (uint8_t)((state8 >> i) & 1u);
    }
}

static void ttc_project_board_v2(uint64_t state, uint64_t tick, uint8_t board[TTC_BOARD_SLOTS]) {
    uint8_t offset = (uint8_t)((((tick % 15u) * 4u) + (uint8_t)(state & 0x0Fu)) % TTC_BOARD_SLOTS);
    unsigned i;

    memset(board, 0, TTC_BOARD_SLOTS);
    for (i = 0; i < 60u; i++) {
        uint8_t bit = (uint8_t)((state >> (i % 64u)) & 1u);
        board[(offset + i) % TTC_BOARD_SLOTS] = bit;
    }
}

void ttc_project_board_for_state(ttc_rule_version rule_version, uint64_t state, uint64_t tick, uint8_t board[TTC_BOARD_SLOTS]) {
    if (!board) {
        return;
    }
    if (rule_version == TTC_RULE_V2_DELTA64) {
        ttc_project_board_v2(state, tick, board);
    } else {
        ttc_project_board_v1(state, tick, board);
    }
}

void ttc_project_board_for_runtime(const ttc_runtime *rt, uint8_t board[TTC_BOARD_SLOTS]) {
    if (!rt || !board) {
        return;
    }
    ttc_project_board_for_state(rt->config.rule_version, rt->state, rt->tick, board);
}

void ttc_runtime_config_default(ttc_runtime_config *config) {
    if (!config) {
        return;
    }
    config->rule_version = TTC_RULE_V1_CURRENT;
    config->seed = TTC_GS;
    config->flags = TTC_RUNTIME_FLAG_STRICT;
}

void ttc_runtime_init(ttc_runtime *rt, const ttc_runtime_config *config) {
    ttc_runtime_config local;
    if (!rt) {
        return;
    }
    if (!config) {
        ttc_runtime_config_default(&local);
        config = &local;
    }

    rt->config = *config;
    rt->tick = 0;
    if (config->rule_version == TTC_RULE_V2_DELTA64) {
        rt->state = config->seed;
    } else {
        rt->state = TTC_GS;
    }
    rt->initialized = 1u;
}

void ttc_runtime_reset(ttc_runtime *rt, const ttc_runtime_config *config) {
    ttc_runtime_init(rt, config ? config : (rt ? &rt->config : NULL));
}

int ttc_runtime_step(ttc_runtime *rt, uint8_t input, ttc_event *out) {
    uint64_t tick;
    uint64_t prev_state;
    uint64_t curr_state;
    uint8_t basis7;
    uint8_t basis8;
    uint8_t state8;

    if (!rt || !out) {
        return -1;
    }
    if (!rt->initialized) {
        ttc_runtime_init(rt, &rt->config);
    }

    tick = rt->tick;
    prev_state = rt->state;
    if (rt->config.rule_version == TTC_RULE_V2_DELTA64) {
        curr_state = ttc_delta_v2(prev_state ^ (uint64_t)input);
        if (tick > 0 && (tick % TTC_MASTER_RESET) == 0u) {
            curr_state = ttc_fold7_v2(curr_state);
        }
    } else {
        curr_state = (uint64_t)ttc_transform_state_v1((uint8_t)(prev_state & 0xFFu), input, tick);
        if (tick > 0 && (tick % TTC_MASTER_RESET) == 0u) {
            curr_state = (uint64_t)ttc_fold7_v1((uint8_t)(curr_state & 0xFFu), TTC_GS);
        }
    }

    basis7 = (uint8_t)(tick % 7u);
    basis8 = (uint8_t)(tick & 7u);
    state8 = (uint8_t)(curr_state & 0xFFu);

    out->rule_version = rt->config.rule_version;
    out->tick = tick;
    out->input = input;
    out->prev_state = prev_state;
    out->curr_state = curr_state;
    out->state8 = state8;
    out->basis7 = basis7;
    out->basis8 = basis8;
    out->law = (uint8_t)(state8 & 0x03u);
    out->edit = (uint8_t)(state8 & 0x0Cu);
    out->boundary = (uint8_t)((state8 & 0x80u) ? 1u : 0u);
    if (rt->config.rule_version == TTC_RULE_V2_DELTA64) {
        out->winner = (uint8_t)((curr_state >> (tick % 64u)) & 1u);
    } else {
        out->winner = (uint8_t)(((tick / 7u) % 2u) ? TTC_FANO_LINES[basis7][2] : TTC_FANO_LINES[basis7][0]);
    }
    out->braille = (uint16_t)(0x2800u + state8);
    ttc_project_board_for_state(rt->config.rule_version, curr_state, tick, out->board);

    rt->state = curr_state;
    rt->tick = tick + 1u;
    return 0;
}
