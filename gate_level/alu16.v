// =============================================================================
// alu16.v -- 16-bit ALU (gate-level equivalent of ALU.sv)
//
// Structure:
//   alu16 = control decode (10 gates)
//         + shl16  (left barrel shifter, 64 MUX2)
//         + shr16  (right barrel shifter, 80 MUX2, logical or arithmetic)
//         + SLT logic (XOR2 + MUX2)
//         + 16 x alu_slice (adder bit + AND/OR/XOR + result mux), ripple carry
//
//   ALUCtrl  op   result                     ALUCtrl  op   result
//   0000     ADD  OpA + OpB                  0101     XOR  OpA ^ OpB
//   0001     SUB  OpA - OpB                  0110     SRL  OpA >> OpB[4:0]
//   0010     SLL  OpA << OpB[3:0]            0111     SRA  OpA >>> OpB[4:0] (signed)
//   0011     AND  OpA & OpB                  1000     OR   OpA | OpB
//   0100     SLT  signed(OpA) < signed(OpB)  others   --   0
//
// Note (same as ALU.sv): SLL uses only OpB[3:0], SRL/SRA use OpB[4:0], so a
// right shift by 16..31 gives 0 (SRL) or all sign bits (SRA).
// =============================================================================

// -----------------------------------------------------------------------------
// alu_slice -- one bit (bit i) of the ALU; alu16 uses 16 of these
//
//   a, b      OpA[i], OpB[i]
//   cin       carry from slice i-1  (slice 0: cin = sub)
//   sub       1 for SUB/SLT -> adder computes a + ~b + 1
//   shl_in    bit i of shl16 output,  shr_in: bit i of shr16 output
//   slt_in    SLT result (slice 0 only; tied to GND in slices 1..15)
//   ctrl      ALUCtrl[3:0]
//   or_en     1 when ALUCtrl[2:0] == 000  (makes 1000 = OR, other 1xxx = 0)
//   y         result bit Res[i]
//   s         adder sum bit (alu16 takes s of slice 15 for SLT)
//   cout      carry to slice i+1
//
// Gates: 2 XOR2 + 1 AND2 + 1 OR2 + 1 full_adder + 6 MUX2 + 1 AND2
//
//   bx   = b ^ sub                      (invert b for subtract)
//   {cout, s} = a + bx + cin            (full_adder)
//   m_sa = ctrl[0] ? (a & b) : shl_in   code 001x : SLL / AND
//   m_sx = ctrl[0] ? (a ^ b) : slt_in   code 010x : SLT / XOR
//   n_lo = ctrl[1] ? m_sa    : s        code 00xx : ADD,SUB / SLL,AND
//   n_hi = ctrl[1] ? shr_in  : m_sx     code 01xx : SLT,XOR / SRL,SRA
//   lo   = ctrl[2] ? n_hi    : n_lo     code 0xxx
//   hi   = (a | b) & or_en              code 1xxx : OR (1000) or 0
//   y    = ctrl[3] ? hi      : lo
// -----------------------------------------------------------------------------
module alu_slice (
  input        a, b, cin, sub,
  input        shl_in, shr_in, slt_in,
  input  [3:0] ctrl,
  input        or_en,
  output       y, s, cout
);
  wire bx, and_y, or_y, xor_y;
  wire m_sa, m_sx, n_lo, n_hi, lo, hi;
  XOR2 u_bx (.A(b), .B(sub), .Y(bx));  // b ^ sub
  full_adder u_fa (.a(a), .b(bx), .cin(cin), .s(s), .cout(cout));
  AND2 u_and (.A(a), .B(b), .Y(and_y));
  OR2  u_or  (.A(a), .B(b), .Y(or_y));
  XOR2 u_xor (.A(a), .B(b), .Y(xor_y));
  MUX2 u_m_sa (.I0(shl_in), .I1(and_y),  .S(ctrl[0]), .Y(m_sa));
  MUX2 u_m_sx (.I0(slt_in), .I1(xor_y),  .S(ctrl[0]), .Y(m_sx));
  MUX2 u_n_lo (.I0(s),      .I1(m_sa),   .S(ctrl[1]), .Y(n_lo));
  MUX2 u_n_hi (.I0(m_sx),   .I1(shr_in), .S(ctrl[1]), .Y(n_hi));
  MUX2 u_lo   (.I0(n_lo),   .I1(n_hi),   .S(ctrl[2]), .Y(lo));
  AND2 u_hi (.A(or_y), .B(or_en), .Y(hi));
  MUX2 u_y (.I0(lo), .I1(hi), .S(ctrl[3]), .Y(y));
endmodule

// -----------------------------------------------------------------------------
// shl16 -- logical left barrel shifter: y = a << amt  (amt = 0..15)   (64 MUX2)
//
// 4 rows of 16 MUX2. Row k shifts left by 2^k when amt[k] = 1:
//   out[i] = amt[k] ? in[i - 2^k] : in[i]       (in[negative] = GND)
// -----------------------------------------------------------------------------
module shl16 (input [15:0] a, input [3:0] amt, output [15:0] y);
  wire [15:0] s1, s2, s3;
  // row a: shift by 1 (amt[0])
  MUX2 u_a0  (.I0(a[0]),  .I1(1'b0),  .S(amt[0]), .Y(s1[0]));
  MUX2 u_a1  (.I0(a[1]),  .I1(a[0]),  .S(amt[0]), .Y(s1[1]));
  MUX2 u_a2  (.I0(a[2]),  .I1(a[1]),  .S(amt[0]), .Y(s1[2]));
  MUX2 u_a3  (.I0(a[3]),  .I1(a[2]),  .S(amt[0]), .Y(s1[3]));
  MUX2 u_a4  (.I0(a[4]),  .I1(a[3]),  .S(amt[0]), .Y(s1[4]));
  MUX2 u_a5  (.I0(a[5]),  .I1(a[4]),  .S(amt[0]), .Y(s1[5]));
  MUX2 u_a6  (.I0(a[6]),  .I1(a[5]),  .S(amt[0]), .Y(s1[6]));
  MUX2 u_a7  (.I0(a[7]),  .I1(a[6]),  .S(amt[0]), .Y(s1[7]));
  MUX2 u_a8  (.I0(a[8]),  .I1(a[7]),  .S(amt[0]), .Y(s1[8]));
  MUX2 u_a9  (.I0(a[9]),  .I1(a[8]),  .S(amt[0]), .Y(s1[9]));
  MUX2 u_a10 (.I0(a[10]), .I1(a[9]),  .S(amt[0]), .Y(s1[10]));
  MUX2 u_a11 (.I0(a[11]), .I1(a[10]), .S(amt[0]), .Y(s1[11]));
  MUX2 u_a12 (.I0(a[12]), .I1(a[11]), .S(amt[0]), .Y(s1[12]));
  MUX2 u_a13 (.I0(a[13]), .I1(a[12]), .S(amt[0]), .Y(s1[13]));
  MUX2 u_a14 (.I0(a[14]), .I1(a[13]), .S(amt[0]), .Y(s1[14]));
  MUX2 u_a15 (.I0(a[15]), .I1(a[14]), .S(amt[0]), .Y(s1[15]));
  // row b: shift by 2 (amt[1])
  MUX2 u_b0  (.I0(s1[0]),  .I1(1'b0),   .S(amt[1]), .Y(s2[0]));
  MUX2 u_b1  (.I0(s1[1]),  .I1(1'b0),   .S(amt[1]), .Y(s2[1]));
  MUX2 u_b2  (.I0(s1[2]),  .I1(s1[0]),  .S(amt[1]), .Y(s2[2]));
  MUX2 u_b3  (.I0(s1[3]),  .I1(s1[1]),  .S(amt[1]), .Y(s2[3]));
  MUX2 u_b4  (.I0(s1[4]),  .I1(s1[2]),  .S(amt[1]), .Y(s2[4]));
  MUX2 u_b5  (.I0(s1[5]),  .I1(s1[3]),  .S(amt[1]), .Y(s2[5]));
  MUX2 u_b6  (.I0(s1[6]),  .I1(s1[4]),  .S(amt[1]), .Y(s2[6]));
  MUX2 u_b7  (.I0(s1[7]),  .I1(s1[5]),  .S(amt[1]), .Y(s2[7]));
  MUX2 u_b8  (.I0(s1[8]),  .I1(s1[6]),  .S(amt[1]), .Y(s2[8]));
  MUX2 u_b9  (.I0(s1[9]),  .I1(s1[7]),  .S(amt[1]), .Y(s2[9]));
  MUX2 u_b10 (.I0(s1[10]), .I1(s1[8]),  .S(amt[1]), .Y(s2[10]));
  MUX2 u_b11 (.I0(s1[11]), .I1(s1[9]),  .S(amt[1]), .Y(s2[11]));
  MUX2 u_b12 (.I0(s1[12]), .I1(s1[10]), .S(amt[1]), .Y(s2[12]));
  MUX2 u_b13 (.I0(s1[13]), .I1(s1[11]), .S(amt[1]), .Y(s2[13]));
  MUX2 u_b14 (.I0(s1[14]), .I1(s1[12]), .S(amt[1]), .Y(s2[14]));
  MUX2 u_b15 (.I0(s1[15]), .I1(s1[13]), .S(amt[1]), .Y(s2[15]));
  // row c: shift by 4 (amt[2])
  MUX2 u_c0  (.I0(s2[0]),  .I1(1'b0),   .S(amt[2]), .Y(s3[0]));
  MUX2 u_c1  (.I0(s2[1]),  .I1(1'b0),   .S(amt[2]), .Y(s3[1]));
  MUX2 u_c2  (.I0(s2[2]),  .I1(1'b0),   .S(amt[2]), .Y(s3[2]));
  MUX2 u_c3  (.I0(s2[3]),  .I1(1'b0),   .S(amt[2]), .Y(s3[3]));
  MUX2 u_c4  (.I0(s2[4]),  .I1(s2[0]),  .S(amt[2]), .Y(s3[4]));
  MUX2 u_c5  (.I0(s2[5]),  .I1(s2[1]),  .S(amt[2]), .Y(s3[5]));
  MUX2 u_c6  (.I0(s2[6]),  .I1(s2[2]),  .S(amt[2]), .Y(s3[6]));
  MUX2 u_c7  (.I0(s2[7]),  .I1(s2[3]),  .S(amt[2]), .Y(s3[7]));
  MUX2 u_c8  (.I0(s2[8]),  .I1(s2[4]),  .S(amt[2]), .Y(s3[8]));
  MUX2 u_c9  (.I0(s2[9]),  .I1(s2[5]),  .S(amt[2]), .Y(s3[9]));
  MUX2 u_c10 (.I0(s2[10]), .I1(s2[6]),  .S(amt[2]), .Y(s3[10]));
  MUX2 u_c11 (.I0(s2[11]), .I1(s2[7]),  .S(amt[2]), .Y(s3[11]));
  MUX2 u_c12 (.I0(s2[12]), .I1(s2[8]),  .S(amt[2]), .Y(s3[12]));
  MUX2 u_c13 (.I0(s2[13]), .I1(s2[9]),  .S(amt[2]), .Y(s3[13]));
  MUX2 u_c14 (.I0(s2[14]), .I1(s2[10]), .S(amt[2]), .Y(s3[14]));
  MUX2 u_c15 (.I0(s2[15]), .I1(s2[11]), .S(amt[2]), .Y(s3[15]));
  // row d: shift by 8 (amt[3])
  MUX2 u_d0  (.I0(s3[0]),  .I1(1'b0),  .S(amt[3]), .Y(y[0]));
  MUX2 u_d1  (.I0(s3[1]),  .I1(1'b0),  .S(amt[3]), .Y(y[1]));
  MUX2 u_d2  (.I0(s3[2]),  .I1(1'b0),  .S(amt[3]), .Y(y[2]));
  MUX2 u_d3  (.I0(s3[3]),  .I1(1'b0),  .S(amt[3]), .Y(y[3]));
  MUX2 u_d4  (.I0(s3[4]),  .I1(1'b0),  .S(amt[3]), .Y(y[4]));
  MUX2 u_d5  (.I0(s3[5]),  .I1(1'b0),  .S(amt[3]), .Y(y[5]));
  MUX2 u_d6  (.I0(s3[6]),  .I1(1'b0),  .S(amt[3]), .Y(y[6]));
  MUX2 u_d7  (.I0(s3[7]),  .I1(1'b0),  .S(amt[3]), .Y(y[7]));
  MUX2 u_d8  (.I0(s3[8]),  .I1(s3[0]), .S(amt[3]), .Y(y[8]));
  MUX2 u_d9  (.I0(s3[9]),  .I1(s3[1]), .S(amt[3]), .Y(y[9]));
  MUX2 u_d10 (.I0(s3[10]), .I1(s3[2]), .S(amt[3]), .Y(y[10]));
  MUX2 u_d11 (.I0(s3[11]), .I1(s3[3]), .S(amt[3]), .Y(y[11]));
  MUX2 u_d12 (.I0(s3[12]), .I1(s3[4]), .S(amt[3]), .Y(y[12]));
  MUX2 u_d13 (.I0(s3[13]), .I1(s3[5]), .S(amt[3]), .Y(y[13]));
  MUX2 u_d14 (.I0(s3[14]), .I1(s3[6]), .S(amt[3]), .Y(y[14]));
  MUX2 u_d15 (.I0(s3[15]), .I1(s3[7]), .S(amt[3]), .Y(y[15]));
endmodule

// -----------------------------------------------------------------------------
// shr16 -- right barrel shifter: y = a >> amt, shifting in `fill`  (80 MUX2)
//
//   fill = 0     -> logical shift (SRL)
//   fill = a[15] -> arithmetic shift (SRA)   (alu16 generates fill)
// 4 rows of 16 MUX2 shift right by 1,2,4,8; row e (amt[4]) forces every bit
// to fill, because a shift of 16..31 empties the word.
//   out[i] = amt[k] ? in[i + 2^k] : in[i]       (in[>15] = fill)
// -----------------------------------------------------------------------------
module shr16 (input [15:0] a, input [4:0] amt, input fill, output [15:0] y);
  wire [15:0] s1, s2, s3, s4;
  // row a: shift by 1 (amt[0])
  MUX2 u_a0  (.I0(a[0]),  .I1(a[1]),  .S(amt[0]), .Y(s1[0]));
  MUX2 u_a1  (.I0(a[1]),  .I1(a[2]),  .S(amt[0]), .Y(s1[1]));
  MUX2 u_a2  (.I0(a[2]),  .I1(a[3]),  .S(amt[0]), .Y(s1[2]));
  MUX2 u_a3  (.I0(a[3]),  .I1(a[4]),  .S(amt[0]), .Y(s1[3]));
  MUX2 u_a4  (.I0(a[4]),  .I1(a[5]),  .S(amt[0]), .Y(s1[4]));
  MUX2 u_a5  (.I0(a[5]),  .I1(a[6]),  .S(amt[0]), .Y(s1[5]));
  MUX2 u_a6  (.I0(a[6]),  .I1(a[7]),  .S(amt[0]), .Y(s1[6]));
  MUX2 u_a7  (.I0(a[7]),  .I1(a[8]),  .S(amt[0]), .Y(s1[7]));
  MUX2 u_a8  (.I0(a[8]),  .I1(a[9]),  .S(amt[0]), .Y(s1[8]));
  MUX2 u_a9  (.I0(a[9]),  .I1(a[10]), .S(amt[0]), .Y(s1[9]));
  MUX2 u_a10 (.I0(a[10]), .I1(a[11]), .S(amt[0]), .Y(s1[10]));
  MUX2 u_a11 (.I0(a[11]), .I1(a[12]), .S(amt[0]), .Y(s1[11]));
  MUX2 u_a12 (.I0(a[12]), .I1(a[13]), .S(amt[0]), .Y(s1[12]));
  MUX2 u_a13 (.I0(a[13]), .I1(a[14]), .S(amt[0]), .Y(s1[13]));
  MUX2 u_a14 (.I0(a[14]), .I1(a[15]), .S(amt[0]), .Y(s1[14]));
  MUX2 u_a15 (.I0(a[15]), .I1(fill),  .S(amt[0]), .Y(s1[15]));
  // row b: shift by 2 (amt[1])
  MUX2 u_b0  (.I0(s1[0]),  .I1(s1[2]),  .S(amt[1]), .Y(s2[0]));
  MUX2 u_b1  (.I0(s1[1]),  .I1(s1[3]),  .S(amt[1]), .Y(s2[1]));
  MUX2 u_b2  (.I0(s1[2]),  .I1(s1[4]),  .S(amt[1]), .Y(s2[2]));
  MUX2 u_b3  (.I0(s1[3]),  .I1(s1[5]),  .S(amt[1]), .Y(s2[3]));
  MUX2 u_b4  (.I0(s1[4]),  .I1(s1[6]),  .S(amt[1]), .Y(s2[4]));
  MUX2 u_b5  (.I0(s1[5]),  .I1(s1[7]),  .S(amt[1]), .Y(s2[5]));
  MUX2 u_b6  (.I0(s1[6]),  .I1(s1[8]),  .S(amt[1]), .Y(s2[6]));
  MUX2 u_b7  (.I0(s1[7]),  .I1(s1[9]),  .S(amt[1]), .Y(s2[7]));
  MUX2 u_b8  (.I0(s1[8]),  .I1(s1[10]), .S(amt[1]), .Y(s2[8]));
  MUX2 u_b9  (.I0(s1[9]),  .I1(s1[11]), .S(amt[1]), .Y(s2[9]));
  MUX2 u_b10 (.I0(s1[10]), .I1(s1[12]), .S(amt[1]), .Y(s2[10]));
  MUX2 u_b11 (.I0(s1[11]), .I1(s1[13]), .S(amt[1]), .Y(s2[11]));
  MUX2 u_b12 (.I0(s1[12]), .I1(s1[14]), .S(amt[1]), .Y(s2[12]));
  MUX2 u_b13 (.I0(s1[13]), .I1(s1[15]), .S(amt[1]), .Y(s2[13]));
  MUX2 u_b14 (.I0(s1[14]), .I1(fill),   .S(amt[1]), .Y(s2[14]));
  MUX2 u_b15 (.I0(s1[15]), .I1(fill),   .S(amt[1]), .Y(s2[15]));
  // row c: shift by 4 (amt[2])
  MUX2 u_c0  (.I0(s2[0]),  .I1(s2[4]),  .S(amt[2]), .Y(s3[0]));
  MUX2 u_c1  (.I0(s2[1]),  .I1(s2[5]),  .S(amt[2]), .Y(s3[1]));
  MUX2 u_c2  (.I0(s2[2]),  .I1(s2[6]),  .S(amt[2]), .Y(s3[2]));
  MUX2 u_c3  (.I0(s2[3]),  .I1(s2[7]),  .S(amt[2]), .Y(s3[3]));
  MUX2 u_c4  (.I0(s2[4]),  .I1(s2[8]),  .S(amt[2]), .Y(s3[4]));
  MUX2 u_c5  (.I0(s2[5]),  .I1(s2[9]),  .S(amt[2]), .Y(s3[5]));
  MUX2 u_c6  (.I0(s2[6]),  .I1(s2[10]), .S(amt[2]), .Y(s3[6]));
  MUX2 u_c7  (.I0(s2[7]),  .I1(s2[11]), .S(amt[2]), .Y(s3[7]));
  MUX2 u_c8  (.I0(s2[8]),  .I1(s2[12]), .S(amt[2]), .Y(s3[8]));
  MUX2 u_c9  (.I0(s2[9]),  .I1(s2[13]), .S(amt[2]), .Y(s3[9]));
  MUX2 u_c10 (.I0(s2[10]), .I1(s2[14]), .S(amt[2]), .Y(s3[10]));
  MUX2 u_c11 (.I0(s2[11]), .I1(s2[15]), .S(amt[2]), .Y(s3[11]));
  MUX2 u_c12 (.I0(s2[12]), .I1(fill),   .S(amt[2]), .Y(s3[12]));
  MUX2 u_c13 (.I0(s2[13]), .I1(fill),   .S(amt[2]), .Y(s3[13]));
  MUX2 u_c14 (.I0(s2[14]), .I1(fill),   .S(amt[2]), .Y(s3[14]));
  MUX2 u_c15 (.I0(s2[15]), .I1(fill),   .S(amt[2]), .Y(s3[15]));
  // row d: shift by 8 (amt[3])
  MUX2 u_d0  (.I0(s3[0]),  .I1(s3[8]),  .S(amt[3]), .Y(s4[0]));
  MUX2 u_d1  (.I0(s3[1]),  .I1(s3[9]),  .S(amt[3]), .Y(s4[1]));
  MUX2 u_d2  (.I0(s3[2]),  .I1(s3[10]), .S(amt[3]), .Y(s4[2]));
  MUX2 u_d3  (.I0(s3[3]),  .I1(s3[11]), .S(amt[3]), .Y(s4[3]));
  MUX2 u_d4  (.I0(s3[4]),  .I1(s3[12]), .S(amt[3]), .Y(s4[4]));
  MUX2 u_d5  (.I0(s3[5]),  .I1(s3[13]), .S(amt[3]), .Y(s4[5]));
  MUX2 u_d6  (.I0(s3[6]),  .I1(s3[14]), .S(amt[3]), .Y(s4[6]));
  MUX2 u_d7  (.I0(s3[7]),  .I1(s3[15]), .S(amt[3]), .Y(s4[7]));
  MUX2 u_d8  (.I0(s3[8]),  .I1(fill),   .S(amt[3]), .Y(s4[8]));
  MUX2 u_d9  (.I0(s3[9]),  .I1(fill),   .S(amt[3]), .Y(s4[9]));
  MUX2 u_d10 (.I0(s3[10]), .I1(fill),   .S(amt[3]), .Y(s4[10]));
  MUX2 u_d11 (.I0(s3[11]), .I1(fill),   .S(amt[3]), .Y(s4[11]));
  MUX2 u_d12 (.I0(s3[12]), .I1(fill),   .S(amt[3]), .Y(s4[12]));
  MUX2 u_d13 (.I0(s3[13]), .I1(fill),   .S(amt[3]), .Y(s4[13]));
  MUX2 u_d14 (.I0(s3[14]), .I1(fill),   .S(amt[3]), .Y(s4[14]));
  MUX2 u_d15 (.I0(s3[15]), .I1(fill),   .S(amt[3]), .Y(s4[15]));
  // row e: shift by 16 (amt[4]) -> all bits = fill
  MUX2 u_e0  (.I0(s4[0]),  .I1(fill), .S(amt[4]), .Y(y[0]));
  MUX2 u_e1  (.I0(s4[1]),  .I1(fill), .S(amt[4]), .Y(y[1]));
  MUX2 u_e2  (.I0(s4[2]),  .I1(fill), .S(amt[4]), .Y(y[2]));
  MUX2 u_e3  (.I0(s4[3]),  .I1(fill), .S(amt[4]), .Y(y[3]));
  MUX2 u_e4  (.I0(s4[4]),  .I1(fill), .S(amt[4]), .Y(y[4]));
  MUX2 u_e5  (.I0(s4[5]),  .I1(fill), .S(amt[4]), .Y(y[5]));
  MUX2 u_e6  (.I0(s4[6]),  .I1(fill), .S(amt[4]), .Y(y[6]));
  MUX2 u_e7  (.I0(s4[7]),  .I1(fill), .S(amt[4]), .Y(y[7]));
  MUX2 u_e8  (.I0(s4[8]),  .I1(fill), .S(amt[4]), .Y(y[8]));
  MUX2 u_e9  (.I0(s4[9]),  .I1(fill), .S(amt[4]), .Y(y[9]));
  MUX2 u_e10 (.I0(s4[10]), .I1(fill), .S(amt[4]), .Y(y[10]));
  MUX2 u_e11 (.I0(s4[11]), .I1(fill), .S(amt[4]), .Y(y[11]));
  MUX2 u_e12 (.I0(s4[12]), .I1(fill), .S(amt[4]), .Y(y[12]));
  MUX2 u_e13 (.I0(s4[13]), .I1(fill), .S(amt[4]), .Y(y[13]));
  MUX2 u_e14 (.I0(s4[14]), .I1(fill), .S(amt[4]), .Y(y[14]));
  MUX2 u_e15 (.I0(s4[15]), .I1(fill), .S(amt[4]), .Y(y[15]));
endmodule

// -----------------------------------------------------------------------------
// alu16 -- top of the ALU (same ports as ALU.sv)
//
// Control decode (computed once, shared by all slices):
//   sub   = ~c3 & ~c1 & (c2 ^ c0)     -> 1 for 0001 (SUB) and 0100 (SLT)
//   sra   = ~c3 & c2 & c1 & c0        -> 1 for 0111 (SRA)
//   or_en = ~(c2 | c1 | c0)           -> ALUCtrl[2:0] == 000
//   fill  = sra & OpA[15]             -> bit shifted in by shr16
// SLT (signed less-than), using the adder in subtract mode (sum = OpA - OpB):
//   signs differ (OpA[15] ^ OpB[15]) -> OpA < OpB  iff  OpA is negative
//   signs equal                      -> OpA < OpB  iff  sum[15] (no overflow possible)
//   slt = (OpA[15] ^ OpB[15]) ? OpA[15] : sum[15]
// -----------------------------------------------------------------------------
module alu16 (
  input  [15:0] OpA,
  input  [15:0] OpB,
  input  [3:0]  ALUCtrl,
  output [15:0] Res
);
  wire        c3n, t_x, t_n, sub, t_a, t_b, sra, t_o, or_en, fill;
  wire        sgn_diff, slt;
  wire [15:0] shl, shr, sum;
  wire [16:1] c;                       // c[i] = carry INTO slice i (c[16] unused)

  // ---- control decode --------------------------------------------------------
  INV  u_c3n   (.A(ALUCtrl[3]), .Y(c3n));
  XOR2 u_t_x   (.A(ALUCtrl[2]), .B(ALUCtrl[0]), .Y(t_x));
  NOR2 u_t_n   (.A(ALUCtrl[3]), .B(ALUCtrl[1]), .Y(t_n));
  AND2 u_sub   (.A(t_x),        .B(t_n),        .Y(sub));    // SUB or SLT
  AND2 u_t_a   (.A(ALUCtrl[2]), .B(ALUCtrl[1]), .Y(t_a));
  AND2 u_t_b   (.A(ALUCtrl[0]), .B(c3n),        .Y(t_b));
  AND2 u_sra   (.A(t_a),        .B(t_b),        .Y(sra));    // SRA
  OR2  u_t_o   (.A(ALUCtrl[2]), .B(ALUCtrl[1]), .Y(t_o));
  NOR2 u_or_en (.A(t_o),        .B(ALUCtrl[0]), .Y(or_en));  // ALUCtrl[2:0]==000
  AND2 u_fill  (.A(sra),        .B(OpA[15]),    .Y(fill));   // shift-in bit for shr16

  // ---- shifters ------------------------------------------------------------
  shl16 u_shl (.a(OpA), .amt(OpB[3:0]), .y(shl));
  shr16 u_shr (.a(OpA), .amt(OpB[4:0]), .fill(fill), .y(shr));

  // ---- set-less-than (signed) ------------------------------------------------
  XOR2 u_sgn (.A(OpA[15]),  .B(OpB[15]),  .Y(sgn_diff));
  MUX2 u_slt (.I0(sum[15]), .I1(OpA[15]), .S(sgn_diff), .Y(slt));

  // ---- 16 bit-slices: ripple carry from slice 0 (cin = sub) up to slice 15 -----
  alu_slice u_s0  (.a(OpA[0]),  .b(OpB[0]),  .cin(sub),   .sub(sub), .shl_in(shl[0]),  .shr_in(shr[0]),  .slt_in(slt),  .ctrl(ALUCtrl), .or_en(or_en), .y(Res[0]),  .s(sum[0]),  .cout(c[1]));
  alu_slice u_s1  (.a(OpA[1]),  .b(OpB[1]),  .cin(c[1]),  .sub(sub), .shl_in(shl[1]),  .shr_in(shr[1]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[1]),  .s(sum[1]),  .cout(c[2]));
  alu_slice u_s2  (.a(OpA[2]),  .b(OpB[2]),  .cin(c[2]),  .sub(sub), .shl_in(shl[2]),  .shr_in(shr[2]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[2]),  .s(sum[2]),  .cout(c[3]));
  alu_slice u_s3  (.a(OpA[3]),  .b(OpB[3]),  .cin(c[3]),  .sub(sub), .shl_in(shl[3]),  .shr_in(shr[3]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[3]),  .s(sum[3]),  .cout(c[4]));
  alu_slice u_s4  (.a(OpA[4]),  .b(OpB[4]),  .cin(c[4]),  .sub(sub), .shl_in(shl[4]),  .shr_in(shr[4]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[4]),  .s(sum[4]),  .cout(c[5]));
  alu_slice u_s5  (.a(OpA[5]),  .b(OpB[5]),  .cin(c[5]),  .sub(sub), .shl_in(shl[5]),  .shr_in(shr[5]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[5]),  .s(sum[5]),  .cout(c[6]));
  alu_slice u_s6  (.a(OpA[6]),  .b(OpB[6]),  .cin(c[6]),  .sub(sub), .shl_in(shl[6]),  .shr_in(shr[6]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[6]),  .s(sum[6]),  .cout(c[7]));
  alu_slice u_s7  (.a(OpA[7]),  .b(OpB[7]),  .cin(c[7]),  .sub(sub), .shl_in(shl[7]),  .shr_in(shr[7]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[7]),  .s(sum[7]),  .cout(c[8]));
  alu_slice u_s8  (.a(OpA[8]),  .b(OpB[8]),  .cin(c[8]),  .sub(sub), .shl_in(shl[8]),  .shr_in(shr[8]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[8]),  .s(sum[8]),  .cout(c[9]));
  alu_slice u_s9  (.a(OpA[9]),  .b(OpB[9]),  .cin(c[9]),  .sub(sub), .shl_in(shl[9]),  .shr_in(shr[9]),  .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[9]),  .s(sum[9]),  .cout(c[10]));
  alu_slice u_s10 (.a(OpA[10]), .b(OpB[10]), .cin(c[10]), .sub(sub), .shl_in(shl[10]), .shr_in(shr[10]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[10]), .s(sum[10]), .cout(c[11]));
  alu_slice u_s11 (.a(OpA[11]), .b(OpB[11]), .cin(c[11]), .sub(sub), .shl_in(shl[11]), .shr_in(shr[11]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[11]), .s(sum[11]), .cout(c[12]));
  alu_slice u_s12 (.a(OpA[12]), .b(OpB[12]), .cin(c[12]), .sub(sub), .shl_in(shl[12]), .shr_in(shr[12]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[12]), .s(sum[12]), .cout(c[13]));
  alu_slice u_s13 (.a(OpA[13]), .b(OpB[13]), .cin(c[13]), .sub(sub), .shl_in(shl[13]), .shr_in(shr[13]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[13]), .s(sum[13]), .cout(c[14]));
  alu_slice u_s14 (.a(OpA[14]), .b(OpB[14]), .cin(c[14]), .sub(sub), .shl_in(shl[14]), .shr_in(shr[14]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[14]), .s(sum[14]), .cout(c[15]));
  alu_slice u_s15 (.a(OpA[15]), .b(OpB[15]), .cin(c[15]), .sub(sub), .shl_in(shl[15]), .shr_in(shr[15]), .slt_in(1'b0), .ctrl(ALUCtrl), .or_en(or_en), .y(Res[15]), .s(sum[15]), .cout(c[16]));
endmodule
