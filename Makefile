CC ?= gcc
CFLAGS ?= -O2 -std=c99 -Wall -Wextra

SRC_DIR ?= src
BIN_DIR ?= bin
ARTIFACT_DIR ?= artifacts
TRIE_SAMPLE_DIR ?= $(ARTIFACT_DIR)/xX/p0/0/0

PROGRAM ?= TICK_A TICK_B REFLECT ROTATE TANGENT
MODE ?= ascii
OUT ?= $(TRIE_SAMPLE_DIR)/aztec_legacy.txt
RULES_OUT ?= $(TRIE_SAMPLE_DIR)/rules_run.ndjson

ASM := $(SRC_DIR)/ttc_asm.awk
VM := $(SRC_DIR)/ttc_vm.awk

RUNTIME_SRC := $(SRC_DIR)/ttc_runtime.c
INCIDENCE_SRC := $(SRC_DIR)/ttc_incidence.c
GRAMMAR_SRC := $(SRC_DIR)/ttc_grammar.c
ADDRESS_SRC := $(SRC_DIR)/ttc_address.c
WITNESS_SRC := $(SRC_DIR)/ttc_witness.c
PROJECTION_SRC := $(SRC_DIR)/ttc_projection.c
MATRIX_SRC := $(SRC_DIR)/ttc_matrix.c
AZTEC_SRC := $(SRC_DIR)/ttc_aztec.c

RUNTIME_OBJ := $(BIN_DIR)/ttc_runtime.o
INCIDENCE_OBJ := $(BIN_DIR)/ttc_incidence.o
GRAMMAR_OBJ := $(BIN_DIR)/ttc_grammar.o
ADDRESS_OBJ := $(BIN_DIR)/ttc_address.o
WITNESS_OBJ := $(BIN_DIR)/ttc_witness_lib.o
PROJECTION_OBJ := $(BIN_DIR)/ttc_projection.o
MATRIX_OBJ := $(BIN_DIR)/ttc_matrix.o
AZTEC_OBJ := $(BIN_DIR)/ttc_aztec.o

RUNTIME_LIB := $(BIN_DIR)/libttc_runtime.a
WITNESS_LIB := $(BIN_DIR)/libttc_witness.a
MATRIX_LIB := $(BIN_DIR)/libttc_matrix.a
AZTEC_LIB := $(BIN_DIR)/libttc_aztec.a
FRAMEWORK_LIB := $(BIN_DIR)/libttc_framework.a

ENC_BIN := $(BIN_DIR)/ttc_fano_aztec
CAN_ENC_BIN := $(BIN_DIR)/ttc_encode
CAN_DEC_BIN := $(BIN_DIR)/ttc_decode
WIT_BIN := $(BIN_DIR)/ttc_witness
CAN_RUNTIME_BIN := $(BIN_DIR)/ttc_canonical_runtime
FRAMEWORK_BIN := $(BIN_DIR)/ttc_framework

.PHONY: build pipe clean codec codec-test canonical canonical-smoke busybox-smoke busybox-uri-smoke symbolic-smoke symbolic-check factoradic-smoke factoradic-fifo-demo braille-mnemonic adapters-smoke adapters-check rules.extract rules.validate rules.digest rules.run rules.check framework-check lexicon-check ontology-check aztec-transport-check aztec-std-placeholder

build: $(RUNTIME_LIB) $(WITNESS_LIB) $(MATRIX_LIB) $(AZTEC_LIB) $(FRAMEWORK_LIB) $(ENC_BIN) $(CAN_ENC_BIN) $(CAN_DEC_BIN) $(WIT_BIN) $(CAN_RUNTIME_BIN) $(FRAMEWORK_BIN)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(RUNTIME_OBJ): $(RUNTIME_SRC) $(SRC_DIR)/ttc_runtime.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(INCIDENCE_OBJ): $(INCIDENCE_SRC) $(SRC_DIR)/ttc_incidence.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(GRAMMAR_OBJ): $(GRAMMAR_SRC) $(SRC_DIR)/ttc_grammar.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(ADDRESS_OBJ): $(ADDRESS_SRC) $(SRC_DIR)/ttc_address.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(WITNESS_OBJ): $(WITNESS_SRC) $(SRC_DIR)/ttc_witness.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(PROJECTION_OBJ): $(PROJECTION_SRC) $(SRC_DIR)/ttc_projection.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(MATRIX_OBJ): $(MATRIX_SRC) $(SRC_DIR)/ttc_matrix.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(AZTEC_OBJ): $(AZTEC_SRC) $(SRC_DIR)/ttc_aztec.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

$(RUNTIME_LIB): $(RUNTIME_OBJ)
	ar rcs $@ $<

$(WITNESS_LIB): $(INCIDENCE_OBJ) $(GRAMMAR_OBJ) $(ADDRESS_OBJ) $(WITNESS_OBJ)
	ar rcs $@ $^

$(MATRIX_LIB): $(MATRIX_OBJ)
	ar rcs $@ $<

$(AZTEC_LIB): $(MATRIX_OBJ) $(AZTEC_OBJ)
	ar rcs $@ $^

$(FRAMEWORK_LIB): $(RUNTIME_OBJ) $(INCIDENCE_OBJ) $(GRAMMAR_OBJ) $(ADDRESS_OBJ) $(WITNESS_OBJ) $(PROJECTION_OBJ) $(MATRIX_OBJ) $(AZTEC_OBJ)
	ar rcs $@ $^

$(ENC_BIN): $(SRC_DIR)/ttc_fano_aztec.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_witness.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_fano_aztec.c $(FRAMEWORK_LIB)

$(CAN_ENC_BIN): $(SRC_DIR)/ttc_encode.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_witness.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_encode.c $(FRAMEWORK_LIB)

$(CAN_DEC_BIN): $(SRC_DIR)/ttc_decode.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_witness.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_decode.c $(FRAMEWORK_LIB)

$(WIT_BIN): $(SRC_DIR)/ttc_witness_cli.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_witness.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_witness_cli.c $(FRAMEWORK_LIB)

$(CAN_RUNTIME_BIN): $(SRC_DIR)/ttc_canonical_runtime.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_runtime.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_canonical_runtime.c $(FRAMEWORK_LIB)

$(FRAMEWORK_BIN): $(SRC_DIR)/ttc_framework_cli.c $(FRAMEWORK_LIB) $(SRC_DIR)/ttc_framework.h | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $(SRC_DIR)/ttc_framework_cli.c $(FRAMEWORK_LIB)

codec: $(CAN_ENC_BIN) $(CAN_DEC_BIN) $(WIT_BIN) | $(ARTIFACT_DIR)
	mkdir -p $(TRIE_SAMPLE_DIR)
	printf 'TICK_A TICK_B REFLECT ROTATE TANGENT\n' > $(TRIE_SAMPLE_DIR)/codec_sample.txt
	$(CAN_ENC_BIN) -m slots < $(TRIE_SAMPLE_DIR)/codec_sample.txt > $(TRIE_SAMPLE_DIR)/codec_slots.txt
	$(CAN_DEC_BIN) < $(TRIE_SAMPLE_DIR)/codec_slots.txt > $(TRIE_SAMPLE_DIR)/codec_roundtrip.bin
	$(WIT_BIN) -m ascii < $(TRIE_SAMPLE_DIR)/codec_slots.txt > $(TRIE_SAMPLE_DIR)/codec_witness.txt
	@echo "wrote codec artifacts in $(TRIE_SAMPLE_DIR)"

codec-test: codec
	cmp $(TRIE_SAMPLE_DIR)/codec_sample.txt $(TRIE_SAMPLE_DIR)/codec_roundtrip.bin
	@echo "codec roundtrip ok"

canonical: $(CAN_RUNTIME_BIN)

canonical-smoke: $(CAN_RUNTIME_BIN) | $(ARTIFACT_DIR)
	./scripts/smoke_canonical_runtime.sh

framework-check: $(FRAMEWORK_BIN) $(CAN_RUNTIME_BIN) $(CAN_ENC_BIN) $(CAN_DEC_BIN)
	./scripts/validate_framework.sh

lexicon-check:
	./scripts/validate_lexicon.sh

ontology-check:
	./scripts/validate_ontology.sh

aztec-transport-check: $(FRAMEWORK_BIN)
	./scripts/validate_aztec_transport.sh

aztec-std-placeholder:
	@echo "ttc_aztec_std reserved for future standards-compliant Aztec framing; not implemented"

busybox-smoke: | $(ARTIFACT_DIR)
	printf '120 88 95 1 2 3 255 0 42\n' | ./scripts/ttc_busybox.sh > $(TRIE_SAMPLE_DIR)/busybox_trace.txt
	@echo "wrote $(TRIE_SAMPLE_DIR)/busybox_trace.txt"

busybox-uri-smoke: | $(ARTIFACT_DIR)
	printf '120 88 95 1 2 3 255 0 42\n' | ./scripts/ttc_busybox.sh --no-write > $(TRIE_SAMPLE_DIR)/busybox_trace_uri.txt
	gawk -f ./scripts/ttc_uri.awk < $(TRIE_SAMPLE_DIR)/busybox_trace_uri.txt > $(TRIE_SAMPLE_DIR)/busybox_uri.tsv
	gawk -v MODE=rdf -f ./scripts/ttc_uri.awk < $(TRIE_SAMPLE_DIR)/busybox_trace_uri.txt > $(TRIE_SAMPLE_DIR)/busybox_uri.ttl
	@echo "wrote $(TRIE_SAMPLE_DIR)/busybox_uri.tsv and $(TRIE_SAMPLE_DIR)/busybox_uri.ttl"

symbolic-smoke: | $(ARTIFACT_DIR)
	printf '27 28 29 30 31 38 63 0 120 88 95 255 42\n' | ./scripts/ttc_busybox.sh > $(TRIE_SAMPLE_DIR)/symbolic_core_in.txt
	./scripts/ttc_symbolic_encode --format line --vs-overlay on --out-root $(ARTIFACT_DIR) < $(TRIE_SAMPLE_DIR)/symbolic_core_in.txt > $(TRIE_SAMPLE_DIR)/symbolic.line
	./scripts/ttc_symbolic_encode --format ndjson --vs-overlay on --write-overlay --out-root $(ARTIFACT_DIR) < $(TRIE_SAMPLE_DIR)/symbolic_core_in.txt > $(TRIE_SAMPLE_DIR)/symbolic.events.ndjson
	./scripts/ttc_symbolic_decode --format line < $(TRIE_SAMPLE_DIR)/symbolic.line > $(TRIE_SAMPLE_DIR)/symbolic_core_out.txt
	./scripts/export_adapters.sh --symbolic-events $(TRIE_SAMPLE_DIR)/symbolic.events.ndjson --out-dir $(TRIE_SAMPLE_DIR)/adapters_symbolic
	@echo "wrote symbolic artifacts under $(TRIE_SAMPLE_DIR)"

symbolic-check: adapters-check symbolic-smoke
	./scripts/validate_symbolic.sh
	@echo "symbolic check passed"

factoradic-smoke: | $(ARTIFACT_DIR)
	printf '120 88 95 1 2 3 255 0 42\n' | ./scripts/materialize_factoradic_5040.sh

factoradic-fifo-demo: | $(ARTIFACT_DIR)
	./scripts/factoradic_fifo_demo.sh

braille-mnemonic: $(CAN_RUNTIME_BIN) | $(ARTIFACT_DIR)
	./scripts/build_braille_mnemonic_sample.sh

adapters-smoke: | $(ARTIFACT_DIR)
	printf '120 88 95 1 2 3 255 0 42\n' | ./scripts/export_adapters.sh

adapters-check: adapters-smoke
	./scripts/validate_adapters.sh

pipe: $(ENC_BIN) | $(ARTIFACT_DIR)
	mkdir -p $(dir $(OUT))
	printf '%s\n' "$(PROGRAM)" \
	| gawk -f $(ASM) -v MODE=hex \
	| gawk -b -f $(VM) -v TRACE_HEX_STDIN=1 -v OUT=modem_raw \
	| $(ENC_BIN) -m "$(MODE)" > "$(OUT)"
	@echo "wrote $(OUT) (mode=$(MODE))"

clean:
	rm -f $(ENC_BIN) $(CAN_ENC_BIN) $(CAN_DEC_BIN) $(WIT_BIN) $(CAN_RUNTIME_BIN) $(FRAMEWORK_BIN)
	rm -f $(RUNTIME_OBJ) $(INCIDENCE_OBJ) $(GRAMMAR_OBJ) $(ADDRESS_OBJ) $(WITNESS_OBJ) $(PROJECTION_OBJ) $(MATRIX_OBJ) $(AZTEC_OBJ) $(RUNTIME_LIB) $(WITNESS_LIB) $(MATRIX_LIB) $(AZTEC_LIB) $(FRAMEWORK_LIB)
	rm -f $(ARTIFACT_DIR)/*.txt $(ARTIFACT_DIR)/*.json $(ARTIFACT_DIR)/*.pgm $(ARTIFACT_DIR)/*.ndjson $(ARTIFACT_DIR)/*.bin
	find $(ARTIFACT_DIR)/xx $(ARTIFACT_DIR)/xX $(ARTIFACT_DIR)/Xx $(ARTIFACT_DIR)/XX -type f \( -name "trace.log" -o -name "state.bin" -o -name "board.txt" -o -name "aztec.txt" -o -name "meta.json" -o -name ".canon" -o -name ".block" -o -name ".artifact" -o -name ".bitboard" -o -name ".golden" -o -name ".negative" -o -name ".vs_overlay" \) 2>/dev/null | xargs -r rm -f
	find blocks/xx blocks/xX blocks/Xx blocks/XX -type f \( -name ".canon" -o -name ".block" -o -name ".artifact" -o -name ".bitboard" -o -name ".golden" -o -name ".negative" \) 2>/dev/null | xargs -r rm -f

rules.extract:
	./scripts/extract_rules.sh

rules.validate:
	./scripts/validate_rules.sh

rules.digest:
	./scripts/rules_digest.sh

rules.run:
	mkdir -p $(dir $(RULES_OUT))
	./scripts/rule_runtime.sh > $(RULES_OUT)
	@echo "wrote $(RULES_OUT)"

rules.check: rules.extract rules.validate rules.digest rules.run
	@echo "rules check passed"
