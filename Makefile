CC ?= gcc
CFLAGS ?= -O2 -std=c99 -Wall -Wextra

SRC_DIR ?= src
BIN_DIR ?= bin
ARTIFACT_DIR ?= artifacts

PROGRAM ?= TICK_A TICK_B REFLECT ROTATE TANGENT
MODE ?= ascii
OUT ?= $(ARTIFACT_DIR)/aztec.txt

ASM := $(SRC_DIR)/ttc_asm.awk
VM := $(SRC_DIR)/ttc_vm.awk
ENC_SRC := $(SRC_DIR)/ttc_fano_aztec.c
ENC_BIN := $(BIN_DIR)/ttc_fano_aztec

.PHONY: build pipe clean

build: $(ENC_BIN)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(ENC_BIN): $(ENC_SRC) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $<

pipe: $(ENC_BIN) | $(ARTIFACT_DIR)
	printf '%s\n' "$(PROGRAM)" \
	| gawk -f $(ASM) -v MODE=hex \
	| gawk -b -f $(VM) -v TRACE_HEX_STDIN=1 -v OUT=modem_raw \
	| $(ENC_BIN) -m "$(MODE)" > "$(OUT)"
	@echo "wrote $(OUT) (mode=$(MODE))"

clean:
	rm -f $(ENC_BIN)
	rm -f $(ARTIFACT_DIR)/aztec.txt $(ARTIFACT_DIR)/aztec.json $(ARTIFACT_DIR)/aztec.pgm
