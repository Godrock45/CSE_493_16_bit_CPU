// =============================================================================
// blocks.v -- shared building blocks (used by several units)
//
// Built only from cells.v. Listed bottom-up: each block uses only cells and
// blocks defined ABOVE it, so this is also the order to draw them in Virtuoso.
//
//   half_adder   full_adder               arithmetic bit cells
//   reg_bit      reg_bit_r                1-bit registers (enable / enable+reset)
//   reg16        reg16_r                  16-bit registers
//   mux2_16      mux8_16      mux16_16    16-bit bus multiplexers
//   dec2to4      dec3to8_en   dec4to16_en one-hot decoders
//   add16        inc16                    16-bit adder / incrementer
//   zero16       eq16                     16-bit zero detect / equality
//
// Naming: cells are UPPERCASE with UPPERCASE pins; blocks are lowercase.
//         1'b0 = tie to GND (gnd!), 1'b1 = tie to VDD (vdd!).
// =============================================================================

// -----------------------------------------------------------------------------
// half_adder -- s = a ^ b,  c = a & b                     (1 XOR2 + 1 AND2)
// -----------------------------------------------------------------------------
module half_adder (input a, input b, output s, output c);
  XOR2 u_x (.A(a), .B(b), .Y(s));
  AND2 u_a (.A(a), .B(b), .Y(c));
endmodule

// -----------------------------------------------------------------------------
// full_adder -- s = a ^ b ^ cin,  cout = majority(a,b,cin)  (2 XOR2 + 3 NAND2)
//
//   p    = a ^ b
//   s    = p ^ cin
//   cout = NAND( NAND(a,b), NAND(p,cin) )   ( = (a & b) | (p & cin) )
//
// Same ports as a 28T mirror adder -- you may draw that instead at transistor
// level and use it as this cell.
// -----------------------------------------------------------------------------
module full_adder (input a, input b, input cin, output s, output cout);
  wire p, n_ab, n_pc;
  XOR2  u_x1 (.A(a),    .B(b),    .Y(p));
  XOR2  u_x2 (.A(p),    .B(cin),  .Y(s));
  NAND2 u_n1 (.A(a),    .B(b),    .Y(n_ab));
  NAND2 u_n2 (.A(p),    .B(cin),  .Y(n_pc));
  NAND2 u_n3 (.A(n_ab), .B(n_pc), .Y(cout));
endmodule

// -----------------------------------------------------------------------------
// reg_bit -- 1-bit register with load enable, no reset      (1 MUX2 + 1 DFF)
//
//   en = 1 : q <= d    (load)
//   en = 0 : q <= q    (hold: the MUX2 feeds q back into D)
//
//             +-------+      +-------+
//      q ---->| I0    |      |       |
//      d ---->| I1  Y |----->| D   Q |---+---> q
//     en ---->| S     |  nd  |       |   |
//             +-------+      |  CLK  |   |
//                            +---^---+   |
//                               clk      |
//      (q back to MUX2 I0) <-------------+
// -----------------------------------------------------------------------------
module reg_bit (input clk, input en, input d, output q);
  wire nd;
  MUX2 u_m (.I0(q), .I1(d),    .S(en), .Y(nd));
  DFF  u_f (.D(nd), .CLK(clk), .Q(q));
endmodule

// -----------------------------------------------------------------------------
// reg_bit_r -- 1-bit register, load enable + SYNCHRONOUS reset
//
//                                                  (1 MUX2 + 1 AND2 + 1 DFF)
//   D = rstn & (en ? d : q)        rstn = ~rst (one INV per reg16_r)
//   rst = 1 -> q <= 0 on the next clock edge (reset wins over load)
//
//             +-------+  m   +------+  nd  +-------+
//      q ---->| I0    |----->| A    |----->| D   Q |---+---> q
//      d ---->| I1  Y |      |  AND2|      |  CLK  |   |
//     en ---->| S     | rstn>| B    |      +---^---+   |
//             +-------+      +------+         clk      |
//      (q back to MUX2 I0) <---------------------------+
// -----------------------------------------------------------------------------
module reg_bit_r (input clk, input rstn, input en, input d, output q);
  wire m, nd;
  MUX2 u_m (.I0(q), .I1(d),    .S(en), .Y(m));
  AND2 u_r (.A(m),  .B(rstn),  .Y(nd));
  DFF  u_f (.D(nd), .CLK(clk), .Q(q));
endmodule

// -----------------------------------------------------------------------------
// reg16 -- 16-bit register, load enable, no reset                 (16 reg_bit)
//
// Used for the data-memory words. Virtuoso: one reg_bit instance iterated <15:0>.
// -----------------------------------------------------------------------------
module reg16 (input clk, input en, input [15:0] d, output [15:0] q);
  reg_bit u_b0  (.clk(clk), .en(en), .d(d[0]),  .q(q[0]));
  reg_bit u_b1  (.clk(clk), .en(en), .d(d[1]),  .q(q[1]));
  reg_bit u_b2  (.clk(clk), .en(en), .d(d[2]),  .q(q[2]));
  reg_bit u_b3  (.clk(clk), .en(en), .d(d[3]),  .q(q[3]));
  reg_bit u_b4  (.clk(clk), .en(en), .d(d[4]),  .q(q[4]));
  reg_bit u_b5  (.clk(clk), .en(en), .d(d[5]),  .q(q[5]));
  reg_bit u_b6  (.clk(clk), .en(en), .d(d[6]),  .q(q[6]));
  reg_bit u_b7  (.clk(clk), .en(en), .d(d[7]),  .q(q[7]));
  reg_bit u_b8  (.clk(clk), .en(en), .d(d[8]),  .q(q[8]));
  reg_bit u_b9  (.clk(clk), .en(en), .d(d[9]),  .q(q[9]));
  reg_bit u_b10 (.clk(clk), .en(en), .d(d[10]), .q(q[10]));
  reg_bit u_b11 (.clk(clk), .en(en), .d(d[11]), .q(q[11]));
  reg_bit u_b12 (.clk(clk), .en(en), .d(d[12]), .q(q[12]));
  reg_bit u_b13 (.clk(clk), .en(en), .d(d[13]), .q(q[13]));
  reg_bit u_b14 (.clk(clk), .en(en), .d(d[14]), .q(q[14]));
  reg_bit u_b15 (.clk(clk), .en(en), .d(d[15]), .q(q[15]));
endmodule

// -----------------------------------------------------------------------------
// reg16_r -- 16-bit register, load enable + sync reset   (1 INV + 16 reg_bit_r)
//
// Used for the PC and for registers x1..x15.
// -----------------------------------------------------------------------------
module reg16_r (input clk, input rst, input en, input [15:0] d, output [15:0] q);
  wire rstn;
  INV u_rstn (.A(rst), .Y(rstn));
  reg_bit_r u_b0  (.clk(clk), .rstn(rstn), .en(en), .d(d[0]),  .q(q[0]));
  reg_bit_r u_b1  (.clk(clk), .rstn(rstn), .en(en), .d(d[1]),  .q(q[1]));
  reg_bit_r u_b2  (.clk(clk), .rstn(rstn), .en(en), .d(d[2]),  .q(q[2]));
  reg_bit_r u_b3  (.clk(clk), .rstn(rstn), .en(en), .d(d[3]),  .q(q[3]));
  reg_bit_r u_b4  (.clk(clk), .rstn(rstn), .en(en), .d(d[4]),  .q(q[4]));
  reg_bit_r u_b5  (.clk(clk), .rstn(rstn), .en(en), .d(d[5]),  .q(q[5]));
  reg_bit_r u_b6  (.clk(clk), .rstn(rstn), .en(en), .d(d[6]),  .q(q[6]));
  reg_bit_r u_b7  (.clk(clk), .rstn(rstn), .en(en), .d(d[7]),  .q(q[7]));
  reg_bit_r u_b8  (.clk(clk), .rstn(rstn), .en(en), .d(d[8]),  .q(q[8]));
  reg_bit_r u_b9  (.clk(clk), .rstn(rstn), .en(en), .d(d[9]),  .q(q[9]));
  reg_bit_r u_b10 (.clk(clk), .rstn(rstn), .en(en), .d(d[10]), .q(q[10]));
  reg_bit_r u_b11 (.clk(clk), .rstn(rstn), .en(en), .d(d[11]), .q(q[11]));
  reg_bit_r u_b12 (.clk(clk), .rstn(rstn), .en(en), .d(d[12]), .q(q[12]));
  reg_bit_r u_b13 (.clk(clk), .rstn(rstn), .en(en), .d(d[13]), .q(q[13]));
  reg_bit_r u_b14 (.clk(clk), .rstn(rstn), .en(en), .d(d[14]), .q(q[14]));
  reg_bit_r u_b15 (.clk(clk), .rstn(rstn), .en(en), .d(d[15]), .q(q[15]));
endmodule

// -----------------------------------------------------------------------------
// mux2_16 -- 16-bit 2:1 bus mux:  y = s ? i1 : i0                   (16 MUX2)
//
// All 16 MUX2 share the select. Virtuoso: one MUX2 instance iterated <15:0>.
// -----------------------------------------------------------------------------
module mux2_16 (input [15:0] i0, input [15:0] i1, input s, output [15:0] y);
  MUX2 u_m0  (.I0(i0[0]),  .I1(i1[0]),  .S(s), .Y(y[0]));
  MUX2 u_m1  (.I0(i0[1]),  .I1(i1[1]),  .S(s), .Y(y[1]));
  MUX2 u_m2  (.I0(i0[2]),  .I1(i1[2]),  .S(s), .Y(y[2]));
  MUX2 u_m3  (.I0(i0[3]),  .I1(i1[3]),  .S(s), .Y(y[3]));
  MUX2 u_m4  (.I0(i0[4]),  .I1(i1[4]),  .S(s), .Y(y[4]));
  MUX2 u_m5  (.I0(i0[5]),  .I1(i1[5]),  .S(s), .Y(y[5]));
  MUX2 u_m6  (.I0(i0[6]),  .I1(i1[6]),  .S(s), .Y(y[6]));
  MUX2 u_m7  (.I0(i0[7]),  .I1(i1[7]),  .S(s), .Y(y[7]));
  MUX2 u_m8  (.I0(i0[8]),  .I1(i1[8]),  .S(s), .Y(y[8]));
  MUX2 u_m9  (.I0(i0[9]),  .I1(i1[9]),  .S(s), .Y(y[9]));
  MUX2 u_m10 (.I0(i0[10]), .I1(i1[10]), .S(s), .Y(y[10]));
  MUX2 u_m11 (.I0(i0[11]), .I1(i1[11]), .S(s), .Y(y[11]));
  MUX2 u_m12 (.I0(i0[12]), .I1(i1[12]), .S(s), .Y(y[12]));
  MUX2 u_m13 (.I0(i0[13]), .I1(i1[13]), .S(s), .Y(y[13]));
  MUX2 u_m14 (.I0(i0[14]), .I1(i1[14]), .S(s), .Y(y[14]));
  MUX2 u_m15 (.I0(i0[15]), .I1(i1[15]), .S(s), .Y(y[15]));
endmodule

// -----------------------------------------------------------------------------
// mux8_16 -- 16-bit 8:1 bus mux:  y = d<sel>                     (7 mux2_16)
//
//   d0 d1  d2 d3  d4 d5  d6 d7
//    \ /    \ /    \ /    \ /      level a: sel[0]  (4 x mux2_16)
//     a0     a1     a2     a3
//       \   /         \   /         level b: sel[1]  (2 x mux2_16)
//        b0             b1
//           \         /             level c: sel[2]  (1 x mux2_16)
//                y
// -----------------------------------------------------------------------------
module mux8_16 (
  input  [15:0] d0, d1, d2, d3, d4, d5, d6, d7,
  input  [2:0]  sel,
  output [15:0] y
);
  wire [15:0] a0, a1, a2, a3, b0, b1;
  mux2_16 u_a0 (.i0(d0), .i1(d1), .s(sel[0]), .y(a0));
  mux2_16 u_a1 (.i0(d2), .i1(d3), .s(sel[0]), .y(a1));
  mux2_16 u_a2 (.i0(d4), .i1(d5), .s(sel[0]), .y(a2));
  mux2_16 u_a3 (.i0(d6), .i1(d7), .s(sel[0]), .y(a3));
  mux2_16 u_b0 (.i0(a0), .i1(a1), .s(sel[1]), .y(b0));
  mux2_16 u_b1 (.i0(a2), .i1(a3), .s(sel[1]), .y(b1));
  mux2_16 u_c0 (.i0(b0), .i1(b1), .s(sel[2]), .y(y));
endmodule

// -----------------------------------------------------------------------------
// mux16_16 -- 16-bit 16:1 bus mux:  y = d<sel>       (2 mux8_16 + 1 mux2_16)
//
//   lo = d<sel[2:0]> of d0..d7,   hi = d<sel[2:0]> of d8..d15,   y = sel[3] ? hi : lo
// Used for the register-file read ports and inside each memory bank.
// -----------------------------------------------------------------------------
module mux16_16 (
  input  [15:0] d0, d1, d2,  d3,  d4,  d5,  d6,  d7,
  input  [15:0] d8, d9, d10, d11, d12, d13, d14, d15,
  input  [3:0]  sel,
  output [15:0] y
);
  wire [15:0] lo, hi;
  mux8_16 u_lo (
    .d0  (d0),
    .d1  (d1),
    .d2  (d2),
    .d3  (d3),
    .d4  (d4),
    .d5  (d5),
    .d6  (d6),
    .d7  (d7),
    .sel (sel[2:0]),
    .y   (lo)
  );
  mux8_16 u_hi (
    .d0  (d8),
    .d1  (d9),
    .d2  (d10),
    .d3  (d11),
    .d4  (d12),
    .d5  (d13),
    .d6  (d14),
    .d7  (d15),
    .sel (sel[2:0]),
    .y   (hi)
  );
  mux2_16 u_top (.i0(lo), .i1(hi), .s(sel[3]), .y(y));
endmodule

// -----------------------------------------------------------------------------
// dec2to4 -- 2:4 one-hot decoder:  y[k] = (a == k)          (2 INV + 4 AND2)
// -----------------------------------------------------------------------------
module dec2to4 (input [1:0] a, output [3:0] y);
  wire a0n, a1n;
  INV u_i0 (.A(a[0]), .Y(a0n));
  INV u_i1 (.A(a[1]), .Y(a1n));
  AND2 u_y0 (.A(a1n),  .B(a0n),  .Y(y[0]));  // a == 00
  AND2 u_y1 (.A(a1n),  .B(a[0]), .Y(y[1]));  // a == 01
  AND2 u_y2 (.A(a[1]), .B(a0n),  .Y(y[2]));  // a == 10
  AND2 u_y3 (.A(a[1]), .B(a[0]), .Y(y[3]));  // a == 11
endmodule

// -----------------------------------------------------------------------------
// dec3to8_en -- 3:8 decoder with enable:  y[k] = en & (a == k)
//
//                                          (1 dec2to4 + 1 INV + 10 AND2)
//   h0 = en & ~a[2],  h1 = en & a[2]
//   y[k] = h<k/4> & lo<k%4>     where lo = dec2to4(a[1:0])
// -----------------------------------------------------------------------------
module dec3to8_en (input [2:0] a, input en, output [7:0] y);
  wire [3:0] lo;
  wire a2n, h0, h1;
  dec2to4 u_lo (.a(a[1:0]), .y(lo));
  INV u_i2 (.A(a[2]), .Y(a2n));
  AND2 u_h0 (.A(en), .B(a2n),  .Y(h0));  // en & a[2]==0
  AND2 u_h1 (.A(en), .B(a[2]), .Y(h1));  // en & a[2]==1
  AND2 u_y0 (.A(h0), .B(lo[0]), .Y(y[0]));
  AND2 u_y1 (.A(h0), .B(lo[1]), .Y(y[1]));
  AND2 u_y2 (.A(h0), .B(lo[2]), .Y(y[2]));
  AND2 u_y3 (.A(h0), .B(lo[3]), .Y(y[3]));
  AND2 u_y4 (.A(h1), .B(lo[0]), .Y(y[4]));
  AND2 u_y5 (.A(h1), .B(lo[1]), .Y(y[5]));
  AND2 u_y6 (.A(h1), .B(lo[2]), .Y(y[6]));
  AND2 u_y7 (.A(h1), .B(lo[3]), .Y(y[7]));
endmodule

// -----------------------------------------------------------------------------
// dec4to16_en -- 4:16 decoder with enable:  y[k] = en & (a == k)
//
//                                          (2 dec2to4 + 20 AND2)
//   lo = dec2to4(a[1:0]),  hi = dec2to4(a[3:2]),  he[j] = hi[j] & en
//   y[k] = he<k/4> & lo<k%4>
// Used as the register-file / memory-bank write decoder and the ROM decoder.
// -----------------------------------------------------------------------------
module dec4to16_en (input [3:0] a, input en, output [15:0] y);
  wire [3:0] lo, hi, he;
  dec2to4 u_lo (.a(a[1:0]), .y(lo));
  dec2to4 u_hi (.a(a[3:2]), .y(hi));
  AND2 u_e0 (.A(hi[0]), .B(en), .Y(he[0]));
  AND2 u_e1 (.A(hi[1]), .B(en), .Y(he[1]));
  AND2 u_e2 (.A(hi[2]), .B(en), .Y(he[2]));
  AND2 u_e3 (.A(hi[3]), .B(en), .Y(he[3]));
  AND2 u_y0  (.A(he[0]), .B(lo[0]), .Y(y[0]));
  AND2 u_y1  (.A(he[0]), .B(lo[1]), .Y(y[1]));
  AND2 u_y2  (.A(he[0]), .B(lo[2]), .Y(y[2]));
  AND2 u_y3  (.A(he[0]), .B(lo[3]), .Y(y[3]));
  AND2 u_y4  (.A(he[1]), .B(lo[0]), .Y(y[4]));
  AND2 u_y5  (.A(he[1]), .B(lo[1]), .Y(y[5]));
  AND2 u_y6  (.A(he[1]), .B(lo[2]), .Y(y[6]));
  AND2 u_y7  (.A(he[1]), .B(lo[3]), .Y(y[7]));
  AND2 u_y8  (.A(he[2]), .B(lo[0]), .Y(y[8]));
  AND2 u_y9  (.A(he[2]), .B(lo[1]), .Y(y[9]));
  AND2 u_y10 (.A(he[2]), .B(lo[2]), .Y(y[10]));
  AND2 u_y11 (.A(he[2]), .B(lo[3]), .Y(y[11]));
  AND2 u_y12 (.A(he[3]), .B(lo[0]), .Y(y[12]));
  AND2 u_y13 (.A(he[3]), .B(lo[1]), .Y(y[13]));
  AND2 u_y14 (.A(he[3]), .B(lo[2]), .Y(y[14]));
  AND2 u_y15 (.A(he[3]), .B(lo[3]), .Y(y[15]));
endmodule

// -----------------------------------------------------------------------------
// add16 -- 16-bit ripple-carry adder: {cout, s} = a + b + cin    (16 full_adder)
//
//   cin -> fa0 -> c[1] -> fa1 -> c[2] -> ... -> fa15 -> cout
// -----------------------------------------------------------------------------
module add16 (input [15:0] a, input [15:0] b, input cin, output [15:0] s, output cout);
  wire [15:1] c;                       // c[i] = carry INTO bit i
  full_adder u_fa0  (.a(a[0]),  .b(b[0]),  .cin(cin),   .s(s[0]),  .cout(c[1]));
  full_adder u_fa1  (.a(a[1]),  .b(b[1]),  .cin(c[1]),  .s(s[1]),  .cout(c[2]));
  full_adder u_fa2  (.a(a[2]),  .b(b[2]),  .cin(c[2]),  .s(s[2]),  .cout(c[3]));
  full_adder u_fa3  (.a(a[3]),  .b(b[3]),  .cin(c[3]),  .s(s[3]),  .cout(c[4]));
  full_adder u_fa4  (.a(a[4]),  .b(b[4]),  .cin(c[4]),  .s(s[4]),  .cout(c[5]));
  full_adder u_fa5  (.a(a[5]),  .b(b[5]),  .cin(c[5]),  .s(s[5]),  .cout(c[6]));
  full_adder u_fa6  (.a(a[6]),  .b(b[6]),  .cin(c[6]),  .s(s[6]),  .cout(c[7]));
  full_adder u_fa7  (.a(a[7]),  .b(b[7]),  .cin(c[7]),  .s(s[7]),  .cout(c[8]));
  full_adder u_fa8  (.a(a[8]),  .b(b[8]),  .cin(c[8]),  .s(s[8]),  .cout(c[9]));
  full_adder u_fa9  (.a(a[9]),  .b(b[9]),  .cin(c[9]),  .s(s[9]),  .cout(c[10]));
  full_adder u_fa10 (.a(a[10]), .b(b[10]), .cin(c[10]), .s(s[10]), .cout(c[11]));
  full_adder u_fa11 (.a(a[11]), .b(b[11]), .cin(c[11]), .s(s[11]), .cout(c[12]));
  full_adder u_fa12 (.a(a[12]), .b(b[12]), .cin(c[12]), .s(s[12]), .cout(c[13]));
  full_adder u_fa13 (.a(a[13]), .b(b[13]), .cin(c[13]), .s(s[13]), .cout(c[14]));
  full_adder u_fa14 (.a(a[14]), .b(b[14]), .cin(c[14]), .s(s[14]), .cout(c[15]));
  full_adder u_fa15 (.a(a[15]), .b(b[15]), .cin(c[15]), .s(s[15]), .cout(cout));
endmodule

// -----------------------------------------------------------------------------
// inc16 -- 16-bit incrementer: s = a + 1 (carry out of bit 15 dropped)
//
//                                                           (16 half_adder)
// Half-adder chain. Bit 0's second input is tied to VDD (the "+1").
// -----------------------------------------------------------------------------
module inc16 (input [15:0] a, output [15:0] s);
  wire [16:1] c;                       // c[i] = carry INTO bit i (c[16] unused)
  half_adder u_ha0  (.a(a[0]),  .b(1'b1),  .s(s[0]),  .c(c[1]));
  half_adder u_ha1  (.a(a[1]),  .b(c[1]),  .s(s[1]),  .c(c[2]));
  half_adder u_ha2  (.a(a[2]),  .b(c[2]),  .s(s[2]),  .c(c[3]));
  half_adder u_ha3  (.a(a[3]),  .b(c[3]),  .s(s[3]),  .c(c[4]));
  half_adder u_ha4  (.a(a[4]),  .b(c[4]),  .s(s[4]),  .c(c[5]));
  half_adder u_ha5  (.a(a[5]),  .b(c[5]),  .s(s[5]),  .c(c[6]));
  half_adder u_ha6  (.a(a[6]),  .b(c[6]),  .s(s[6]),  .c(c[7]));
  half_adder u_ha7  (.a(a[7]),  .b(c[7]),  .s(s[7]),  .c(c[8]));
  half_adder u_ha8  (.a(a[8]),  .b(c[8]),  .s(s[8]),  .c(c[9]));
  half_adder u_ha9  (.a(a[9]),  .b(c[9]),  .s(s[9]),  .c(c[10]));
  half_adder u_ha10 (.a(a[10]), .b(c[10]), .s(s[10]), .c(c[11]));
  half_adder u_ha11 (.a(a[11]), .b(c[11]), .s(s[11]), .c(c[12]));
  half_adder u_ha12 (.a(a[12]), .b(c[12]), .s(s[12]), .c(c[13]));
  half_adder u_ha13 (.a(a[13]), .b(c[13]), .s(s[13]), .c(c[14]));
  half_adder u_ha14 (.a(a[14]), .b(c[14]), .s(s[14]), .c(c[15]));
  half_adder u_ha15 (.a(a[15]), .b(c[15]), .s(s[15]), .c(c[16]));
endmodule

// -----------------------------------------------------------------------------
// zero16 -- y = (a == 16'h0000)                        (14 OR2 + 1 NOR2)
//
//   OR tree 16 -> 8 -> 4 -> 2, then a NOR2 gives "none of the bits is 1".
// -----------------------------------------------------------------------------
module zero16 (input [15:0] a, output y);
  wire [7:0] o1;
  wire [3:0] o2;
  wire [1:0] o3;
  OR2 u_o1_0 (.A(a[0]),  .B(a[1]),  .Y(o1[0]));
  OR2 u_o1_1 (.A(a[2]),  .B(a[3]),  .Y(o1[1]));
  OR2 u_o1_2 (.A(a[4]),  .B(a[5]),  .Y(o1[2]));
  OR2 u_o1_3 (.A(a[6]),  .B(a[7]),  .Y(o1[3]));
  OR2 u_o1_4 (.A(a[8]),  .B(a[9]),  .Y(o1[4]));
  OR2 u_o1_5 (.A(a[10]), .B(a[11]), .Y(o1[5]));
  OR2 u_o1_6 (.A(a[12]), .B(a[13]), .Y(o1[6]));
  OR2 u_o1_7 (.A(a[14]), .B(a[15]), .Y(o1[7]));
  OR2 u_o2_0 (.A(o1[0]), .B(o1[1]), .Y(o2[0]));
  OR2 u_o2_1 (.A(o1[2]), .B(o1[3]), .Y(o2[1]));
  OR2 u_o2_2 (.A(o1[4]), .B(o1[5]), .Y(o2[2]));
  OR2 u_o2_3 (.A(o1[6]), .B(o1[7]), .Y(o2[3]));
  OR2 u_o3_0 (.A(o2[0]), .B(o2[1]), .Y(o3[0]));
  OR2 u_o3_1 (.A(o2[2]), .B(o2[3]), .Y(o3[1]));
  NOR2 u_nz (.A(o3[0]), .B(o3[1]), .Y(y));
endmodule

// -----------------------------------------------------------------------------
// eq16 -- y = (a == b)                                (16 XOR2 + 1 zero16)
//
//   d = a ^ b (bitwise difference), y = (d == 0)
// -----------------------------------------------------------------------------
module eq16 (input [15:0] a, input [15:0] b, output y);
  wire [15:0] d;
  XOR2 u_x0  (.A(a[0]),  .B(b[0]),  .Y(d[0]));
  XOR2 u_x1  (.A(a[1]),  .B(b[1]),  .Y(d[1]));
  XOR2 u_x2  (.A(a[2]),  .B(b[2]),  .Y(d[2]));
  XOR2 u_x3  (.A(a[3]),  .B(b[3]),  .Y(d[3]));
  XOR2 u_x4  (.A(a[4]),  .B(b[4]),  .Y(d[4]));
  XOR2 u_x5  (.A(a[5]),  .B(b[5]),  .Y(d[5]));
  XOR2 u_x6  (.A(a[6]),  .B(b[6]),  .Y(d[6]));
  XOR2 u_x7  (.A(a[7]),  .B(b[7]),  .Y(d[7]));
  XOR2 u_x8  (.A(a[8]),  .B(b[8]),  .Y(d[8]));
  XOR2 u_x9  (.A(a[9]),  .B(b[9]),  .Y(d[9]));
  XOR2 u_x10 (.A(a[10]), .B(b[10]), .Y(d[10]));
  XOR2 u_x11 (.A(a[11]), .B(b[11]), .Y(d[11]));
  XOR2 u_x12 (.A(a[12]), .B(b[12]), .Y(d[12]));
  XOR2 u_x13 (.A(a[13]), .B(b[13]), .Y(d[13]));
  XOR2 u_x14 (.A(a[14]), .B(b[14]), .Y(d[14]));
  XOR2 u_x15 (.A(a[15]), .B(b[15]), .Y(d[15]));
  zero16 u_z (.a(d), .y(y));
endmodule
