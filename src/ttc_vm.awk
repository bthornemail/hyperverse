#!/usr/bin/env gawk -f
# ttc_vm.awk
# TTC bitwise kernel reference VM in gawk.
#
# What this file does:
# - Defines the bitwise kernel registers and state
# - Supports semantic bytecode/token execution
# - Implements the core clocks:
#     K8   : delta kernel byte
#     F7   : one-hot Fano ring
#     S60  : one-hot Sonar ring (2 x 30-bit words)
# - Implements:
#     C240 : unary cursor (8 x 30-bit words)
#     B240 : unary board  (8 x 30-bit words)
# - Uses only bitwise operations in the runtime core
#
# Usage examples:
#   gawk -f ttc_vm.awk
#   gawk -f ttc_vm.awk -v PROGRAM='TICK_A TICK_B REFLECT ROTATE TANGENT'
#   gawk -f ttc_vm.awk -v TRACE_BYTES='f0 01 02 03 04 05 f1'
#   gawk -f ttc_vm.awk -v STEPS=4
#   gawk -f ttc_asm.awk -v MODE=hex program.ttc | gawk -f ttc_vm.awk -v TRACE_HEX_STDIN=1 -v OUT=modem_raw | ./ttc_fano_aztec
#
# Notes:
# - This is a reference interpreter, not the final optimized machine.
# - Braille remains projection-only and is reported as U+2800 + K.

BEGIN {
    # ----------------------------
    # Constants
    # ----------------------------
    GS      = 0x1D
    MASK8   = 0xFF
    MASK7   = 0x7F
    MASK30  = 1073741823
    WORDS240 = 8

    # Semantic opcodes / token bytes
    OP_TICK_A   = 0x01
    OP_TICK_B   = 0x02
    OP_REFLECT  = 0x03
    OP_ROTATE   = 0x04
    OP_TANGENT  = 0x05
    OP_BOUNDARY = 0x06

    TRACE_NAME[sprintf("%02x", OP_TICK_A)]   = "TICK_A"
    TRACE_NAME[sprintf("%02x", OP_TICK_B)]   = "TICK_B"
    TRACE_NAME[sprintf("%02x", OP_REFLECT)]  = "REFLECT"
    TRACE_NAME[sprintf("%02x", OP_ROTATE)]   = "ROTATE"
    TRACE_NAME[sprintf("%02x", OP_TANGENT)]  = "TANGENT"
    TRACE_NAME[sprintf("%02x", OP_BOUNDARY)] = "BOUNDARY"

    TRACE_OPCODE["TICK_A"]   = OP_TICK_A
    TRACE_OPCODE["TICK_B"]   = OP_TICK_B
    TRACE_OPCODE["REFLECT"]  = OP_REFLECT
    TRACE_OPCODE["ROTATE"]   = OP_ROTATE
    TRACE_OPCODE["TANGENT"]  = OP_TANGENT
    TRACE_OPCODE["BOUNDARY"] = OP_BOUNDARY

    # Braille witness weights (same canonical dot map used by the C encoder)
    HEX_WEIGHT[0] = 0x01
    HEX_WEIGHT[1] = 0x02
    HEX_WEIGHT[2] = 0x04
    HEX_WEIGHT[3] = 0x40
    HEX_WEIGHT[4] = 0x10
    HEX_WEIGHT[5] = 0x08
    HEX_WEIGHT[6] = 0x20
    HEX_WEIGHT[7] = 0x80

    # ----------------------------
    # Machine init
    # ----------------------------
    vm_reset()

    # ----------------------------
    # Program loading priority:
    # 1) TRACE_BYTES hex framed carrier
    # 2) TRACE_HEX_STDIN=1 and hex bytes from stdin
    # 3) PROGRAM symbolic tokens
    # 4) default demo program
    # ----------------------------
    if (TRACE_BYTES != "") {
        load_trace_bytes(TRACE_BYTES)
    } else if (TRACE_HEX_STDIN) {
        load_trace_hex_stdin()
    } else if (PROGRAM != "") {
        load_program_tokens(PROGRAM)
    } else {
        load_program_tokens("TICK_A TICK_B REFLECT ROTATE TANGENT")
    }

    if (STEPS == "") {
        STEPS = 1
    }

    # Execute loaded program STEPS times
    for (run = 1; run <= STEPS; run++) {
        execute_program()
    }

    if (FRAME_BYTES == "") FRAME_BYTES = 16
    if (OUT == "") OUT = "report"

    if (OUT == "report") {
        dump_machine()
    } else if (OUT == "modem_hex" || OUT == "modem_raw") {
        emit_modem_frame()
    } else {
        fatal("unknown OUT mode: " OUT)
    }
    exit
}

# ============================================================
# VM RESET / STATE
# ============================================================

function vm_reset(    i) {
    # Kernel byte
    K = GS

    # 7-bit Fano one-hot ring: 0000001
    F = 1

    # Sonar one-hot cursor over 60 bits split into low/high 30
    S_lo = 1
    S_hi = 0

    # Direction: 0 = forward / rotl240, 1 = reverse / rotr240
    DIR = 0

    # Cursor and board (8 x 30 bits)
    for (i = 0; i < WORDS240; i++) {
        C[i] = 0
        B[i] = 0
    }

    pc = 0
    plen = 0
    tick_count = 0
    kh_len = 0
}

# ============================================================
# PRIMITIVES
# ============================================================

function rotl8(x, k) {
    k = k % 8
    return and(or(lshift(x, k), rshift(x, 8 - k)), MASK8)
}

function rotr8(x, k) {
    k = k % 8
    return and(or(rshift(x, k), lshift(x, 8 - k)), MASK8)
}

function delta8(x, Cst) {
    return and(xor(xor(rotl8(x, 1), rotl8(x, 3)), xor(rotr8(x, 2), Cst)), MASK8)
}

function rotl7(x) {
    return and(or(lshift(x, 1), rshift(x, 6)), MASK7)
}

function rotl60(lo, hi,    new_lo, new_hi, carry) {
    carry  = and(rshift(hi, 29), 1)
    new_hi = and(or(lshift(hi, 1), rshift(lo, 29)), MASK30)
    new_lo = and(or(lshift(lo, 1), carry), MASK30)
    return new_lo SUBSEP new_hi
}

function rotr60(lo, hi,    new_lo, new_hi, carry) {
    carry  = and(lo, 1)
    new_lo = and(or(rshift(lo, 1), lshift(hi, 29)), MASK30)
    new_hi = and(or(rshift(hi, 1), lshift(carry, 29)), MASK30)
    return new_lo SUBSEP new_hi
}

function rotl240(arr,    i, carry, nextbit) {
    carry = and(rshift(arr[WORDS240 - 1], 29), 1)
    for (i = WORDS240 - 1; i > 0; i--) {
        nextbit = and(rshift(arr[i - 1], 29), 1)
        arr[i] = and(or(lshift(arr[i], 1), nextbit), MASK30)
    }
    arr[0] = and(or(lshift(arr[0], 1), carry), MASK30)
}

function rotr240(arr,    i, carry, nextbit) {
    carry = and(arr[0], 1)
    for (i = 0; i < WORDS240 - 1; i++) {
        nextbit = and(arr[i + 1], 1)
        arr[i] = and(or(rshift(arr[i], 1), lshift(nextbit, 29)), MASK30)
    }
    arr[WORDS240 - 1] = and(or(rshift(arr[WORDS240 - 1], 1), lshift(carry, 29)), MASK30)
}

function xor240(dst, src,    i) {
    for (i = 0; i < WORDS240; i++) {
        dst[i] = xor(dst[i], src[i])
    }
}

function clear240(dst,    i) {
    for (i = 0; i < WORDS240; i++) {
        dst[i] = 0
    }
}

function copy240(dst, src,    i) {
    for (i = 0; i < WORDS240; i++) {
        dst[i] = src[i]
    }
}

# ============================================================
# SONAR -> CURSOR
# ============================================================

function cursor_from_sonar(    i) {
    clear240(C)

    for (i = 0; i < 30; i++) {
        if (and(rshift(S_lo, i), 1)) {
            set_cursor_column(i)
            return
        }
    }
    for (i = 0; i < 30; i++) {
        if (and(rshift(S_hi, i), 1)) {
            set_cursor_column(i + 30)
            return
        }
    }
}

function set_cursor_column(pos,    layer, idx, word, bit) {
    for (layer = 0; layer < 4; layer++) {
        idx = pos + 60 * layer
        word = int(idx / 30)
        bit  = idx % 30
        C[word] = or(C[word], lshift(1, bit))
    }
}

# ============================================================
# CORE MACROS
# ============================================================

function tick_a() {
    K = delta8(K, GS)
    F = rotl7(F)
    tick_count++
    kernel_hist[kh_len++] = and(K, MASK8)
}

function tick_b(    tmp) {
    split_pair(rotl60(S_lo, S_hi), tmp)
    S_lo = tmp[1]
    S_hi = tmp[2]
}

function do_reflect() {
    DIR = xor(DIR, 1)
}

function do_rotate() {
    K = rotl8(K, 1)
}

function boundary() {
    cursor_from_sonar()
}

function tangent() {
    project240()
}

function project240(    ktmp, j, i, bit) {
    cursor_from_sonar()
    ktmp = K

    for (j = 0; j < 30; j++) {
        for (i = 0; i < 8; i++) {
            bit = and(rshift(ktmp, i), 1)
            if (bit) {
                xor240(B, C)
            }
            if (fano_forward()) {
                rotl240(C)
            } else {
                rotr240(C)
            }
        }
        ktmp = delta8(ktmp, GS)
    }
}

function fano_forward() {
    # Direction combines explicit reflect state plus Fano phase grouping.
    # Lower 4 one-hot positions are treated as forward-facing group.
    # Reflect toggles the final sense.
    phase_group = ((and(F, 0x0F) != 0) ? 0 : 1)
    return xor(phase_group, DIR) == 0
}

# ============================================================
# TRACE / PROGRAM LOADING
# ============================================================

function load_program_tokens(s,    n, i, a, tok) {
    plen = 0
    n = split(s, a, /[[:space:]]+/)
    for (i = 1; i <= n; i++) {
        tok = a[i]
        if (tok == "") {
            continue
        }
        if (!(tok in TRACE_OPCODE)) {
            fatal("unknown token in PROGRAM: " tok)
        }
        prog[plen++] = TRACE_OPCODE[tok]
    }
}

function load_trace_bytes(s,    n, i, a, b, inframe) {
    plen = 0
    n = split(tolower(s), a, /[[:space:]]+/)
    inframe = 0

    for (i = 1; i <= n; i++) {
        b = a[i]
        if (b == "") {
            continue
        }
        if (b == "f0") {
            if (inframe) fatal("multiple frame start")
            inframe = 1
            continue
        }
        if (b == "f1") {
            if (!inframe) fatal("frame end before frame start")
            inframe = 2
            continue
        }
        if (!inframe) {
            fatal("byte outside frame: " b)
        }
        if (b == "f2" || b == "f3" || b == "f4" || b == "ff") {
            # Carrier/control bytes recognized but not executed in this VM core.
            continue
        }
        if (!(b in TRACE_NAME)) {
            fatal("unknown trace byte: " b)
        }
        prog[plen++] = strtonum("0x" b)
    }
    if (inframe != 2) {
        fatal("missing frame end")
    }
}

function load_trace_hex_stdin(    line, s) {
    s = ""
    while ((getline line) > 0) {
        if (s != "") s = s " "
        s = s " " line
    }
    if (s == "") {
        fatal("TRACE_HEX_STDIN=1 but stdin had no hex bytes")
    }
    load_trace_bytes(s)
}

# ============================================================
# EXECUTION
# ============================================================

function execute_program(    op) {
    for (pc = 0; pc < plen; pc++) {
        op = prog[pc]
        if (op == OP_TICK_A) {
            tick_a()
        } else if (op == OP_TICK_B) {
            tick_b()
        } else if (op == OP_REFLECT) {
            do_reflect()
        } else if (op == OP_ROTATE) {
            do_rotate()
        } else if (op == OP_TANGENT) {
            tangent()
        } else if (op == OP_BOUNDARY) {
            boundary()
        } else {
            fatal(sprintf("unknown opcode 0x%02X at pc=%d", op, pc))
        }
    }
}

# ============================================================
# GEOMETRY WITNESS FROM PROGRAM CONTENT
# ============================================================

function geometry_from_program(    i, hasA, hasB, hasR, hasO, hasT) {
    hasA = hasB = hasR = hasO = hasT = 0
    for (i = 0; i < plen; i++) {
        if (prog[i] == OP_TICK_A)   hasA = 1
        if (prog[i] == OP_TICK_B)   hasB = 1
        if (prog[i] == OP_REFLECT)  hasR = 1
        if (prog[i] == OP_ROTATE)   hasO = 1
        if (prog[i] == OP_TANGENT)  hasT = 1
    }
    if (hasA && hasB && hasR && hasO) {
        if (hasT) return "triakis-lift"
        return "tetra-core"
    }
    if (plen == 0) return "empty"
    return "unknown"
}

# ============================================================
# OUTPUT
# ============================================================

function dump_machine(    i, geom) {
    geom = geometry_from_program()

    print "status=pass"
    print "ticks=" tick_count
    print "geometry=" geom
    printf "kernel=0x%02X\n", K
    printf "braille_codepoint=U+%04X\n", 0x2800 + K
    printf "fano=0x%02X\n", F
    printf "sonar_lo=0x%08X\n", S_lo
    printf "sonar_hi=0x%08X\n", S_hi
    print "direction=" (DIR ? "reverse" : "forward")

    printf "trace="
    for (i = 0; i < plen; i++) {
        if (i) printf " "
        printf "%s", TRACE_NAME[sprintf("%02x", prog[i])]
    }
    printf "\n"

    print "board_words="
    for (i = 0; i < WORDS240; i++) {
        printf "B%d=0x%08X\n", i, B[i]
    }

    print "cursor_words="
    for (i = 0; i < WORDS240; i++) {
        printf "C%d=0x%08X\n", i, C[i]
    }

    print "board_ascii="
    dump_board_ascii(B)

    if (geom == "tetra-core") {
        print "ascii="
        print "    A"
        print "   /|\\"
        print "  / | \\"
        print " B--+--C"
        print "  \\ | /"
        print "   \\|/"
        print "    D"
    } else if (geom == "triakis-lift") {
        print "ascii="
        print "         t1"
        print "        /|\\"
        print "       / | \\"
        print "      A--+--B"
        print "     / \\ | / \\"
        print "   t3--- C ---t2"
        print "     \\ / | \\ /"
        print "      D--+--"
        print "       \\ | /"
        print "        \\|/"
        print "         t4"
    }
}

function ensure_kernel_history(n,    guard, before) {
    if (plen <= 0) fatal("no loaded program")
    guard = 0
    while (kh_len < n) {
        before = kh_len
        execute_program()
        guard++
        if (kh_len == before) {
            fatal("program has no TICK_A; cannot synthesize modem frame bytes")
        }
        if (guard > 100000) {
            fatal("modem frame synthesis exceeded guard limit")
        }
    }
}

function braille_hexwt(byte,    i, v) {
    v = 0
    for (i = 0; i < 8; i++) {
        if (and(rshift(byte, i), 1)) {
            v += HEX_WEIGHT[i]
        }
    }
    return and(v, MASK8)
}

function emit_modem_frame(    start, i, b) {
    # Canonical 16-byte modem frame:
    #   bytes 0..7   = kernel binary bytes
    #   bytes 8..15  = Braille hex-weight witness bytes
    # For non-16 frame requests, emit last FRAME_BYTES kernel bytes.
    if (FRAME_BYTES <= 0) fatal("FRAME_BYTES must be > 0")

    if (FRAME_BYTES == 16) {
        ensure_kernel_history(8)
        start = kh_len - 8
        for (i = 0; i < 8; i++) {
            frame[i] = and(kernel_hist[start + i], MASK8)
            frame[8 + i] = braille_hexwt(frame[i])
        }
    } else {
        ensure_kernel_history(FRAME_BYTES)
        start = kh_len - FRAME_BYTES
        for (i = 0; i < FRAME_BYTES; i++) {
            frame[i] = and(kernel_hist[start + i], MASK8)
        }
    }

    if (OUT == "modem_hex") {
        for (i = 0; i < FRAME_BYTES; i++) {
            if (i) printf " "
            printf "%02x", frame[i]
        }
        printf "\n"
    } else {
        for (i = 0; i < FRAME_BYTES; i++) {
            b = and(frame[i], MASK8)
            printf "%c", b
        }
    }
}

function dump_board_ascii(arr,    w, b, line, count) {
    line = ""
    count = 0
    for (w = 0; w < WORDS240; w++) {
        for (b = 0; b < 30; b++) {
            line = line ((and(rshift(arr[w], b), 1)) ? "#" : ".")
            count++
            if (count % 60 == 0) {
                print line
                line = ""
            }
        }
    }
}

# ============================================================
# HELPERS
# ============================================================

function split_pair(s, out,    a) {
    split(s, a, SUBSEP)
    out[1] = a[1] + 0
    out[2] = a[2] + 0
}

function fatal(msg) {
    print "status=fail"
    print "reason=" msg
    exit 1
}
