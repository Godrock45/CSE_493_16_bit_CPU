// =============================================================================
// data_mem.v -- data memory (gate-level equivalent of data_mem.sv, module `memory`)
//
// 128 words x 16 bits, word-addressed by addr[6:0] (addr[15:7] ignored).
//   write : on the rising clk edge, if write_ena = 1, mem[addr] <= dat
//   read  : mem_dat = mem[addr]   (combinational)
//   no reset (same as the RTL)
//
// Built from 8 identical banks of 16 words:
//   addr[6:4] picks the bank   (dec3to8_en for writes, mux8_16 for reads)
//   addr[3:0] picks the word inside the bank
//
// THIS IS BY FAR THE LARGEST BLOCK: 2048 DFFs, ~4000 MUX2 -- more than the
// whole rest of the CPU. If you do not need 128 words, use data_mem_16w
// (bottom of this file) instead: 1 bank, 16 words, same ports. The demo
// program in ROM.sv only touches mem[4] and mem[5], and passes with it.
// =============================================================================

// -----------------------------------------------------------------------------
// mem_bank16 -- 16 words x 16 bits             (dec4to16_en + 16 reg16 + mux16_16)
// -----------------------------------------------------------------------------
module mem_bank16 (input clk, input we, input [3:0] a, input [15:0] d, output [15:0] y);
  wire [15:0] wsel;
  wire [15:0] w0, w1, w2, w3, w4, w5, w6, w7;
  wire [15:0] w8, w9, w10, w11, w12, w13, w14, w15;
  dec4to16_en u_wdec (.a(a), .en(we), .y(wsel));
  reg16 u_w0  (.clk(clk), .en(wsel[0]),  .d(d), .q(w0));
  reg16 u_w1  (.clk(clk), .en(wsel[1]),  .d(d), .q(w1));
  reg16 u_w2  (.clk(clk), .en(wsel[2]),  .d(d), .q(w2));
  reg16 u_w3  (.clk(clk), .en(wsel[3]),  .d(d), .q(w3));
  reg16 u_w4  (.clk(clk), .en(wsel[4]),  .d(d), .q(w4));
  reg16 u_w5  (.clk(clk), .en(wsel[5]),  .d(d), .q(w5));
  reg16 u_w6  (.clk(clk), .en(wsel[6]),  .d(d), .q(w6));
  reg16 u_w7  (.clk(clk), .en(wsel[7]),  .d(d), .q(w7));
  reg16 u_w8  (.clk(clk), .en(wsel[8]),  .d(d), .q(w8));
  reg16 u_w9  (.clk(clk), .en(wsel[9]),  .d(d), .q(w9));
  reg16 u_w10 (.clk(clk), .en(wsel[10]), .d(d), .q(w10));
  reg16 u_w11 (.clk(clk), .en(wsel[11]), .d(d), .q(w11));
  reg16 u_w12 (.clk(clk), .en(wsel[12]), .d(d), .q(w12));
  reg16 u_w13 (.clk(clk), .en(wsel[13]), .d(d), .q(w13));
  reg16 u_w14 (.clk(clk), .en(wsel[14]), .d(d), .q(w14));
  reg16 u_w15 (.clk(clk), .en(wsel[15]), .d(d), .q(w15));
  mux16_16 u_rd (
    .d0  (w0),
    .d1  (w1),
    .d2  (w2),
    .d3  (w3),
    .d4  (w4),
    .d5  (w5),
    .d6  (w6),
    .d7  (w7),
    .d8  (w8),
    .d9  (w9),
    .d10 (w10),
    .d11 (w11),
    .d12 (w12),
    .d13 (w13),
    .d14 (w14),
    .d15 (w15),
    .sel (a),
    .y   (y)
  );
endmodule

// -----------------------------------------------------------------------------
// data_mem -- 128 words = 8 x mem_bank16           (same ports as module `memory`)
// -----------------------------------------------------------------------------
module data_mem (
  input         clk,
  input  [15:0] addr,
  input  [15:0] dat,
  input         write_ena,
  output [15:0] mem_dat
);
  wire [7:0] bwe;                      // one-hot bank write enable
  wire [15:0] bank_y0, bank_y1, bank_y2, bank_y3, bank_y4, bank_y5, bank_y6, bank_y7;
  dec3to8_en u_bdec (.a(addr[6:4]), .en(write_ena), .y(bwe));
  mem_bank16 u_bank0 (.clk(clk), .we(bwe[0]), .a(addr[3:0]), .d(dat), .y(bank_y0));
  mem_bank16 u_bank1 (.clk(clk), .we(bwe[1]), .a(addr[3:0]), .d(dat), .y(bank_y1));
  mem_bank16 u_bank2 (.clk(clk), .we(bwe[2]), .a(addr[3:0]), .d(dat), .y(bank_y2));
  mem_bank16 u_bank3 (.clk(clk), .we(bwe[3]), .a(addr[3:0]), .d(dat), .y(bank_y3));
  mem_bank16 u_bank4 (.clk(clk), .we(bwe[4]), .a(addr[3:0]), .d(dat), .y(bank_y4));
  mem_bank16 u_bank5 (.clk(clk), .we(bwe[5]), .a(addr[3:0]), .d(dat), .y(bank_y5));
  mem_bank16 u_bank6 (.clk(clk), .we(bwe[6]), .a(addr[3:0]), .d(dat), .y(bank_y6));
  mem_bank16 u_bank7 (.clk(clk), .we(bwe[7]), .a(addr[3:0]), .d(dat), .y(bank_y7));
  mux8_16 u_rd (
    .d0  (bank_y0),
    .d1  (bank_y1),
    .d2  (bank_y2),
    .d3  (bank_y3),
    .d4  (bank_y4),
    .d5  (bank_y5),
    .d6  (bank_y6),
    .d7  (bank_y7),
    .sel (addr[6:4]),
    .y   (mem_dat)
  );
endmodule

// -----------------------------------------------------------------------------
// data_mem_16w -- OPTIONAL reduced memory: 16 words = 1 mem_bank16
//
// Same ports as data_mem. Only addr[3:0] is used, so addresses wrap every 16
// words -- NOT identical to the RTL for addresses >= 16. To use it, change
// `data_mem` to `data_mem_16w` on the u_dmem line of cpu_top.v.
// -----------------------------------------------------------------------------
module data_mem_16w (
  input         clk,
  input  [15:0] addr,
  input  [15:0] dat,
  input         write_ena,
  output [15:0] mem_dat
);
  mem_bank16 u_bank0 (.clk(clk), .we(write_ena), .a(addr[3:0]), .d(dat), .y(mem_dat));
endmodule
