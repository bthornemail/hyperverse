/* LAYER: matrix
 * Owns TTC-specific reversible byte transport arrangement only.
 */
#include "ttc_matrix.h"

#include <stdlib.h>
#include <string.h>

#define TTC_MATRIX_DIM 27u
#define TTC_MATRIX_CENTER 13u

static int ttc_matrix_mul_u16(uint16_t a, uint16_t b, size_t *out) {
    if (!out) return TTC_MATRIX_ERR_ARG;
    *out = (size_t)a * (size_t)b;
    return TTC_MATRIX_OK;
}

static uint8_t ttc_matrix_crc8(const uint8_t *buf, size_t len) {
    size_t i;
    uint8_t crc = 0u;
    for (i = 0; i < len; i++) {
        uint8_t x = (uint8_t)(crc ^ buf[i]);
        int j;
        for (j = 0; j < 8; j++) {
            x = (uint8_t)((x & 0x80u) ? ((x << 1) ^ 0x07u) : (x << 1));
        }
        crc = x;
    }
    return crc;
}

static int ttc_matrix_is_reserved(uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
    int dx = (int)x - (int)(width / 2u);
    int dy = (int)y - (int)(height / 2u);
    return dx >= -2 && dx <= 2 && dy >= -2 && dy <= 2;
}

static int ttc_matrix_alloc_modules(ttc_matrix_symbol *sym, uint16_t width, uint16_t height) {
    size_t count = 0;
    uint8_t *modules;
    if (!sym || width == 0 || height == 0) return TTC_MATRIX_ERR_ARG;
    if (width > TTC_MATRIX_MAX_DIM || height > TTC_MATRIX_MAX_DIM) return TTC_MATRIX_ERR_RANGE;
    ttc_matrix_mul_u16(width, height, &count);
    modules = (uint8_t *)calloc(count, 1u);
    if (!modules) return TTC_MATRIX_ERR_NOMEM;
    ttc_matrix_symbol_free(sym);
    sym->modules = modules;
    sym->meta.width = width;
    sym->meta.height = height;
    return TTC_MATRIX_OK;
}

static void ttc_matrix_set_module(ttc_matrix_symbol *sym, uint16_t x, uint16_t y, uint8_t value) {
    if (!sym || !sym->modules || x >= sym->meta.width || y >= sym->meta.height) return;
    sym->modules[(size_t)y * sym->meta.width + x] = (uint8_t)(value ? 1u : 0u);
}

static uint8_t ttc_matrix_get_module(const uint8_t *modules, uint16_t width, uint16_t height, uint16_t x, uint16_t y) {
    if (!modules || x >= width || y >= height) return 0u;
    return modules[(size_t)y * width + x] ? 1u : 0u;
}

static void ttc_matrix_draw_bullseye(ttc_matrix_symbol *sym) {
    int ring;
    int x;
    int y;
    for (ring = 0; ring <= 2; ring++) {
        int on = (ring % 2 == 0) ? 1 : 0;
        for (y = -ring; y <= ring; y++) {
            for (x = -ring; x <= ring; x++) {
                if (abs(x) == ring || abs(y) == ring) {
                    ttc_matrix_set_module(sym, (uint16_t)(TTC_MATRIX_CENTER + x), (uint16_t)(TTC_MATRIX_CENTER + y), (uint8_t)on);
                }
            }
        }
    }
}

static int ttc_matrix_payload_capacity_bits(uint16_t width, uint16_t height) {
    uint16_t x;
    uint16_t y;
    int count = 0;
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            if (!ttc_matrix_is_reserved(x, y, width, height)) count++;
        }
    }
    return count;
}

static void ttc_matrix_write_bitstream(ttc_matrix_symbol *sym, const uint8_t *bitstream, size_t bit_count) {
    uint16_t x;
    uint16_t y;
    size_t bit_index = 0;
    for (y = 0; y < sym->meta.height; y++) {
        for (x = 0; x < sym->meta.width; x++) {
            if (ttc_matrix_is_reserved(x, y, sym->meta.width, sym->meta.height)) continue;
            if (bit_index < bit_count) {
                uint8_t byte = bitstream[bit_index / 8u];
                uint8_t bit = (uint8_t)((byte >> (7u - (bit_index % 8u))) & 1u);
                ttc_matrix_set_module(sym, x, y, bit);
            } else {
                ttc_matrix_set_module(sym, x, y, (uint8_t)((x + y + bit_index) & 1u));
            }
            bit_index++;
        }
    }
}

static int ttc_matrix_read_bitstream(const uint8_t *modules, uint16_t width, uint16_t height, uint8_t *out_bits, size_t bit_count) {
    uint16_t x;
    uint16_t y;
    size_t bit_index = 0;
    if (!modules || !out_bits) return TTC_MATRIX_ERR_ARG;
    memset(out_bits, 0, (bit_count + 7u) / 8u);
    for (y = 0; y < height && bit_index < bit_count; y++) {
        for (x = 0; x < width && bit_index < bit_count; x++) {
            uint8_t bit;
            if (ttc_matrix_is_reserved(x, y, width, height)) continue;
            bit = ttc_matrix_get_module(modules, width, height, x, y);
            out_bits[bit_index / 8u] |= (uint8_t)(bit << (7u - (bit_index % 8u)));
            bit_index++;
        }
    }
    return TTC_MATRIX_OK;
}

void ttc_matrix_policy_default(ttc_matrix_policy *policy) {
    if (!policy) return;
    memset(policy, 0, sizeof(*policy));
    policy->symbol_kind = TTC_MATRIX_SYMBOL_FULL;
    policy->ecc_percent = TTC_MATRIX_ECC_CHECKSUM8;
    policy->byte_mode_only = 1u;
}

void ttc_matrix_symbol_init(ttc_matrix_symbol *sym) {
    if (!sym) return;
    memset(sym, 0, sizeof(*sym));
}

void ttc_matrix_symbol_free(ttc_matrix_symbol *sym) {
    if (!sym) return;
    free(sym->modules);
    sym->modules = NULL;
    memset(&sym->meta, 0, sizeof(sym->meta));
}

int ttc_matrix_encode_bytes(const uint8_t *in_bytes, size_t in_len, const ttc_matrix_policy *policy, ttc_matrix_symbol *out_sym) {
    ttc_matrix_policy local_policy;
    uint8_t *frame;
    size_t frame_len;
    size_t bit_count;
    int capacity_bits;
    int rc;

    if (!out_sym || (in_len > 0 && !in_bytes)) return TTC_MATRIX_ERR_ARG;
    if (!policy) {
        ttc_matrix_policy_default(&local_policy);
        policy = &local_policy;
    }
    if (!policy->byte_mode_only || policy->symbol_kind != TTC_MATRIX_SYMBOL_FULL) return TTC_MATRIX_ERR_UNSUPPORTED;
    if (in_len > 65535u) return TTC_MATRIX_ERR_RANGE;

    frame_len = 3u + in_len;
    bit_count = frame_len * 8u;
    capacity_bits = ttc_matrix_payload_capacity_bits(TTC_MATRIX_DIM, TTC_MATRIX_DIM);
    if ((int)bit_count > capacity_bits) return TTC_MATRIX_ERR_RANGE;

    rc = ttc_matrix_alloc_modules(out_sym, TTC_MATRIX_DIM, TTC_MATRIX_DIM);
    if (rc != TTC_MATRIX_OK) return rc;

    frame = (uint8_t *)calloc(frame_len, 1u);
    if (!frame) {
        ttc_matrix_symbol_free(out_sym);
        return TTC_MATRIX_ERR_NOMEM;
    }
    frame[0] = (uint8_t)((in_len >> 8u) & 0xFFu);
    frame[1] = (uint8_t)(in_len & 0xFFu);
    if (in_len > 0) memcpy(frame + 2u, in_bytes, in_len);
    frame[frame_len - 1u] = ttc_matrix_crc8(frame, frame_len - 1u);

    out_sym->meta.width = TTC_MATRIX_DIM;
    out_sym->meta.height = TTC_MATRIX_DIM;
    out_sym->meta.layers = 4u;
    out_sym->meta.data_codewords = (uint16_t)in_len;
    out_sym->meta.ecc_codewords = 1u;
    out_sym->meta.compact = 0u;

    ttc_matrix_draw_bullseye(out_sym);
    ttc_matrix_write_bitstream(out_sym, frame, bit_count);
    free(frame);
    return TTC_MATRIX_OK;
}

int ttc_matrix_decode_modules(const uint8_t *modules, uint16_t width, uint16_t height, uint8_t **out_bytes, size_t *out_len, ttc_matrix_decode_report *out_report) {
    size_t payload_len;
    size_t frame_len;
    size_t bit_count;
    uint8_t *frame;
    uint8_t crc;
    int rc;
    if (!modules || !out_bytes || !out_len || width != TTC_MATRIX_DIM || height != TTC_MATRIX_DIM) return TTC_MATRIX_ERR_ARG;
    *out_bytes = NULL;
    *out_len = 0;

    if (out_report) {
        memset(out_report, 0, sizeof(*out_report));
        out_report->width = width;
        out_report->height = height;
        out_report->layers = 4u;
        out_report->compact = 0u;
    }

    bit_count = 24u;
    frame = (uint8_t *)calloc((bit_count + 7u) / 8u, 1u);
    if (!frame) return TTC_MATRIX_ERR_NOMEM;
    rc = ttc_matrix_read_bitstream(modules, width, height, frame, bit_count);
    if (rc != TTC_MATRIX_OK) {
        free(frame);
        return rc;
    }
    payload_len = ((size_t)frame[0] << 8u) | (size_t)frame[1];
    frame_len = payload_len + 3u;
    free(frame);

    bit_count = frame_len * 8u;
    if ((int)bit_count > ttc_matrix_payload_capacity_bits(width, height)) return TTC_MATRIX_ERR_FORMAT;
    frame = (uint8_t *)calloc(frame_len, 1u);
    if (!frame) return TTC_MATRIX_ERR_NOMEM;
    rc = ttc_matrix_read_bitstream(modules, width, height, frame, bit_count);
    if (rc != TTC_MATRIX_OK) {
        free(frame);
        return rc;
    }

    crc = ttc_matrix_crc8(frame, frame_len - 1u);
    if (crc != frame[frame_len - 1u]) {
        free(frame);
        if (out_report) out_report->ecc_ok = 0u;
        return TTC_MATRIX_ERR_ECC;
    }
    if (payload_len > 0) {
        *out_bytes = (uint8_t *)malloc(payload_len);
        if (!*out_bytes) {
            free(frame);
            return TTC_MATRIX_ERR_NOMEM;
        }
        memcpy(*out_bytes, frame + 2u, payload_len);
    }
    *out_len = payload_len;
    if (out_report) out_report->ecc_ok = 1u;
    free(frame);
    return TTC_MATRIX_OK;
}

int ttc_matrix_render_ascii(const ttc_matrix_symbol *sym, FILE *out) {
    uint16_t y;
    uint16_t x;
    if (!sym || !sym->modules || !out) return TTC_MATRIX_ERR_ARG;
    for (y = 0; y < sym->meta.height; y++) {
        for (x = 0; x < sym->meta.width; x++) {
            fputc(ttc_matrix_get_module(sym->modules, sym->meta.width, sym->meta.height, x, y) ? '#' : '.', out);
        }
        fputc('\n', out);
    }
    return TTC_MATRIX_OK;
}

int ttc_matrix_render_pbm(const ttc_matrix_symbol *sym, FILE *out) {
    uint16_t y;
    uint16_t x;
    if (!sym || !sym->modules || !out) return TTC_MATRIX_ERR_ARG;
    fprintf(out, "P1\n%u %u\n", sym->meta.width, sym->meta.height);
    for (y = 0; y < sym->meta.height; y++) {
        for (x = 0; x < sym->meta.width; x++) {
            fprintf(out, "%u", (unsigned)ttc_matrix_get_module(sym->modules, sym->meta.width, sym->meta.height, x, y));
            if (x + 1u < sym->meta.width) fputc(' ', out);
        }
        fputc('\n', out);
    }
    return TTC_MATRIX_OK;
}

int ttc_matrix_render_pgm(const ttc_matrix_symbol *sym, unsigned module_px, FILE *out) {
    uint16_t y;
    uint16_t x;
    unsigned yy;
    unsigned xx;
    if (!sym || !sym->modules || !out || module_px == 0u) return TTC_MATRIX_ERR_ARG;
    fprintf(out, "P2\n%u %u\n255\n", sym->meta.width * module_px, sym->meta.height * module_px);
    for (y = 0; y < sym->meta.height; y++) {
        for (yy = 0; yy < module_px; yy++) {
            for (x = 0; x < sym->meta.width; x++) {
                unsigned pix = ttc_matrix_get_module(sym->modules, sym->meta.width, sym->meta.height, x, y) ? 0u : 255u;
                for (xx = 0; xx < module_px; xx++) {
                    fprintf(out, "%u", pix);
                    if (!(x + 1u == sym->meta.width && xx + 1u == module_px)) fputc(' ', out);
                }
            }
            fputc('\n', out);
        }
    }
    return TTC_MATRIX_OK;
}

int ttc_matrix_verify_roundtrip(const uint8_t *in_bytes, size_t in_len, const ttc_matrix_policy *policy) {
    ttc_matrix_symbol sym;
    uint8_t *decoded = NULL;
    size_t decoded_len = 0;
    int rc;
    ttc_matrix_symbol_init(&sym);
    rc = ttc_matrix_encode_bytes(in_bytes, in_len, policy, &sym);
    if (rc != TTC_MATRIX_OK) {
        ttc_matrix_symbol_free(&sym);
        return rc;
    }
    rc = ttc_matrix_decode_modules(sym.modules, sym.meta.width, sym.meta.height, &decoded, &decoded_len, NULL);
    if (rc != TTC_MATRIX_OK) {
        ttc_matrix_symbol_free(&sym);
        free(decoded);
        return rc;
    }
    if (decoded_len != in_len || (in_len > 0 && memcmp(decoded, in_bytes, in_len) != 0)) {
        ttc_matrix_symbol_free(&sym);
        free(decoded);
        return TTC_MATRIX_ERR_MISMATCH;
    }
    ttc_matrix_symbol_free(&sym);
    free(decoded);
    return TTC_MATRIX_OK;
}
