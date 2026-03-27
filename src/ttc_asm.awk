#!/usr/bin/env gawk -f
# ttc_asm.awk
# TTC assembler: symbolic trace / assembly -> framed byte stream
#
# Output format:
#   raw    : binary bytes to stdout
#   hex    : lowercase hex bytes, one line
#   escaped: shell-safe \xNN sequence
#
# Usage:
#   gawk -f ttc_asm.awk program.ttc
#   printf 'TICK_A TICK_B REFLECT ROTATE TANGENT\n' | gawk -f ttc_asm.awk
#   gawk -f ttc_asm.awk -v MODE=hex program.ttc
#   gawk -f ttc_asm.awk -v MODE=escaped program.ttc
#
# Accepted source forms:
#   TICK_A TICK_B REFLECT ROTATE TANGENT
#   FRAME_START TICK_A ... FRAME_END
#   labels/comments are ignored if present in simple form:
#     loop:
#     # comment
#     ; comment

BEGIN {
    if (MODE == "") MODE = "raw"

    TOK["FRAME_START"]   = "f0"
    TOK["FRAME_END"]     = "f1"
    TOK["SEGMENT_BREAK"] = "f2"
    TOK["HINT_START"]    = "f3"
    TOK["HINT_END"]      = "f4"
    TOK["ESCAPE"]        = "ff"

    TOK["TICK_A"]   = "01"
    TOK["TICK_B"]   = "02"
    TOK["REFLECT"]  = "03"
    TOK["ROTATE"]   = "04"
    TOK["TANGENT"]  = "05"
    TOK["BOUNDARY"] = "06"

    started = 0
    ended = 0
    nbytes = 0
}

{
    line = $0
    sub(/[;#].*$/, "", line)
    gsub(/[:,]/, " ", line)
    gsub(/[[:space:]]+/, " ", line)
    sub(/^ /, "", line)
    sub(/ $/, "", line)
    if (line == "") next

    n = split(line, a, /[[:space:]]+/)
    for (i = 1; i <= n; i++) {
        tok = a[i]
        if (tok == "") continue

        # ignore simple labels like loop
        if (!(tok in TOK)) continue

        hx = TOK[tok]
        if (hx == "f0") started++
        if (hx == "f1") ended++
        bytes[nbytes++] = hx
    }
}

END {
    if (nbytes == 0) fail("empty program")

    # auto-frame unless explicitly framed
    if (started == 0 && ended == 0) {
        shift_right_bytes()
        bytes[0] = "f0"
        bytes[nbytes++] = "f1"
    } else {
        if (started != 1) fail("program must contain exactly one FRAME_START or none")
        if (ended   != 1) fail("program must contain exactly one FRAME_END or none")
        if (bytes[0] != "f0") fail("FRAME_START must be first emitted token")
        if (bytes[nbytes-1] != "f1") fail("FRAME_END must be last emitted token")
    }

    if (MODE == "hex") {
        emit_hex()
    } else if (MODE == "escaped") {
        emit_escaped()
    } else if (MODE == "raw") {
        emit_raw()
    } else {
        fail("unknown MODE=" MODE)
    }
}

function shift_right_bytes(    i) {
    for (i = nbytes; i > 0; i--) bytes[i] = bytes[i-1]
}

function emit_hex(    i) {
    for (i = 0; i < nbytes; i++) {
        if (i) printf " "
        printf "%s", bytes[i]
    }
    printf "\n"
}

function emit_escaped(    i) {
    for (i = 0; i < nbytes; i++) {
        printf "\\x%s", bytes[i]
    }
    printf "\n"
}

function emit_raw(    i) {
    for (i = 0; i < nbytes; i++) {
        printf "%c", strtonum("0x" bytes[i])
    }
}

function fail(msg) {
    print "asm: fail: " msg > "/dev/stderr"
    exit 1
}
