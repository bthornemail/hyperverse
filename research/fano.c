// fano.c
// stdin -> Braille -> Aztec
// compile: gcc -O2 -o fano fano.c
// usage:  cat braille.bin | ./fano > aztec.txt

#include <stdio.h>
#include <stdint.h>
#include <string.h>

// Fano lines from your kernel
static const int FANO_LINES[7][3] = {
    {0,1,3}, {0,2,5}, {0,4,6},
    {1,2,4}, {1,5,6}, {2,3,6}, {3,4,5}
};

// Braille hex weights (ISO/TR 11548-1)
static const uint8_t HEX_WEIGHT[8] = {
    0x01, 0x02, 0x04, 0x40, 0x10, 0x08, 0x20, 0x80
};

// 27x27 Aztec grid (729 cells)
static const int AZTEC_WIDTH = 27;
static const int AZTEC_HEIGHT = 27;
static const int AZTEC_CELLS = 729;

// Aztec coordinate table (60 canonical positions)
static const int AZTEC_TABLE[60][2] = {
    // US lane 1-15
    {17,13},{16,17},{11,17},{9,15},{9,11},{12,9},{18,8},{18,12},{18,16},{15,18},{10,18},{8,16},{8,12},{9,8},{14,8},
    // RS lane 1-15
    {19,13},{18,19},{11,19},{7,17},{7,11},{10,7},{17,7},{20,10},{20,16},{17,20},{10,20},{6,18},{6,12},{7,6},{14,6},
    // GS lane 1-15
    {21,13},{20,21},{11,21},{5,19},{5,11},{8,5},{17,5},{22,8},{22,16},{19,22},{10,22},{4,20},{4,12},{5,4},{14,4},
    // FS lane 1-15
    {23,13},{22,23},{11,23},{3,21},{3,11},{6,3},{17,3},{24,6},{24,16},{21,24},{10,24},{2,22},{2,12},{3,2},{14,2}
};

// Fano winner from tick and chiral bit
static int fano_winner(int tick, int chiral) {
    int line = tick % 7;
    int p0 = FANO_LINES[line][0];
    int p2 = FANO_LINES[line][2];
    return chiral ? p2 : p0;
}

// Braille cell from byte (dual interpretation)
static void braille_cell(uint8_t byte, uint8_t* binary, uint8_t* hexwt) {
    *binary = byte;  // binary interpretation is the byte itself
    *hexwt = 0;
    for (int i = 0; i < 8; i++) {
        if (byte & (1 << i)) {
            *hexwt += HEX_WEIGHT[i];
        }
    }
}

// Factoradic digit from hexwt and radix
static int factoradic_digit(int hexwt, int radix) {
    return hexwt % radix;
}

// 240-space address from winner and cycle
static int addr240(int winner, int cycle) {
    int lane = cycle % 15;
    int channel = winner % 4;
    int orient = ((cycle / 15) + (winner % 2)) % 4;
    int quadrant = channel * 4 + orient;
    return quadrant * 15 + lane;
}

// Main: read bytes from stdin, output Aztec grid
int main() {
    uint8_t buf[16];
    int grid[AZTEC_HEIGHT][AZTEC_WIDTH];
    memset(grid, 0, sizeof(grid));
    
    int tick = 0;
    int chiral = 0;
    
    while (fread(buf, 1, 16, stdin) == 16) {
        // 16 bytes = one frame
        for (int i = 0; i < 16; i++) {
            uint8_t byte = buf[i];
            uint8_t binary, hexwt;
            braille_cell(byte, &binary, &hexwt);
            
            // Fano winner from tick (chiral cycles)
            chiral = (tick / 7) % 2;
            int winner = fano_winner(tick, chiral);
            int cycle = tick / 7;
            int addr = addr240(winner, cycle);
            
            // Factoradic digit (first 10 positions)
            int radix = (i < 10) ? (i + 1) : 10;
            int digit = factoradic_digit(hexwt, radix);
            
            // Place in Aztec grid
            if (addr < 60) {
                int x = AZTEC_TABLE[addr][0];
                int y = AZTEC_TABLE[addr][1];
                if (x >= 0 && x < AZTEC_WIDTH && y >= 0 && y < AZTEC_HEIGHT) {
                    grid[y][x] = digit + 1;  // 1-10 for display
                }
            }
            
            tick++;
        }
    }
    
    // Output Aztec grid as ASCII
    for (int y = 0; y < AZTEC_HEIGHT; y++) {
        for (int x = 0; x < AZTEC_WIDTH; x++) {
            int v = grid[y][x];
            if (v == 0) putchar(' ');
            else if (v == 1) putchar('▁');
            else if (v == 2) putchar('▂');
            else if (v == 3) putchar('▃');
            else if (v == 4) putchar('▄');
            else if (v == 5) putchar('▅');
            else if (v == 6) putchar('▆');
            else if (v == 7) putchar('▇');
            else if (v == 8) putchar('█');
            else if (v == 9) putchar('▉');
            else putchar('▊');
        }
        putchar('\n');
    }
    
    return 0;
}