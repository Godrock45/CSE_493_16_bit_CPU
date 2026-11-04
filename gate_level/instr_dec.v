// =============================================================================
// instr_dec.v -- instruction field decoder (gate-level equivalent of decoder.sv)
//
// Instruction word:  [15:12] opcode  [11:8] rd  [7:4] rs1  [3:0] funct4 / imm
//                    JMP (opcode 0110): [11:0] = absolute jump address
//
//   opcode       rd          rs1         funct4      imm[3:0]    addr[11:0]
//   0000 (R)     ins[11:8]   ins[7:4]    ins[3:0]    0           0
//   0110 (JMP)   0           0           0           0           ins[11:0]
//   others (I)   ins[11:8]   ins[7:4]    0           ins[3:0]    0
//   imm[15:4] is always 0 (zero-extended), opcode = ins[15:12] always.
//
// Every field bit is one AND2: (instruction bit) & (format-valid signal).
//   is_r = (opcode == 0000)     is_j = (opcode == 0110)
//   not_j = ~is_j  (rd, rs1)    is_i = ~(is_r | is_j)  (imm)
// =============================================================================
module instr_dec (
  input  [15:0] instruct,
  output [3:0]  rd,
  output [3:0]  rs1,
  output [3:0]  funct4,
  output [15:0] imm,
  output [3:0]  opcode,
  output [11:0] addr
);
  wire n32, n10, is_r, op3n, op0n, j_hi, j_lo, is_j, not_j, is_i;

  assign opcode    = instruct[15:12];  // straight wires
  assign imm[15:4] = 12'h000;          // GND

  // ---- format detect -----------------------------------------------------------
  NOR2 u_n32   (.A(instruct[15]), .B(instruct[14]), .Y(n32));
  NOR2 u_n10   (.A(instruct[13]), .B(instruct[12]), .Y(n10));
  AND2 u_is_r  (.A(n32),          .B(n10),          .Y(is_r));  // opcode == 0000
  INV  u_op3n  (.A(instruct[15]), .Y(op3n));
  INV  u_op0n  (.A(instruct[12]), .Y(op0n));
  AND2 u_j_hi  (.A(op3n),         .B(instruct[14]), .Y(j_hi));  // opcode[3:2] == 01
  AND2 u_j_lo  (.A(instruct[13]), .B(op0n),         .Y(j_lo));  // opcode[1:0] == 10
  AND2 u_is_j  (.A(j_hi),         .B(j_lo),         .Y(is_j));  // opcode == 0110
  INV  u_not_j (.A(is_j),         .Y(not_j));
  NOR2 u_is_i  (.A(is_r),         .B(is_j),         .Y(is_i));  // neither R nor JMP

  // ---- field gating ------------------------------------------------------------
  AND2 u_rd0 (.A(instruct[8]),  .B(not_j), .Y(rd[0]));
  AND2 u_rd1 (.A(instruct[9]),  .B(not_j), .Y(rd[1]));
  AND2 u_rd2 (.A(instruct[10]), .B(not_j), .Y(rd[2]));
  AND2 u_rd3 (.A(instruct[11]), .B(not_j), .Y(rd[3]));
  AND2 u_rs0 (.A(instruct[4]), .B(not_j), .Y(rs1[0]));
  AND2 u_rs1 (.A(instruct[5]), .B(not_j), .Y(rs1[1]));
  AND2 u_rs2 (.A(instruct[6]), .B(not_j), .Y(rs1[2]));
  AND2 u_rs3 (.A(instruct[7]), .B(not_j), .Y(rs1[3]));
  AND2 u_fn0 (.A(instruct[0]), .B(is_r), .Y(funct4[0]));
  AND2 u_fn1 (.A(instruct[1]), .B(is_r), .Y(funct4[1]));
  AND2 u_fn2 (.A(instruct[2]), .B(is_r), .Y(funct4[2]));
  AND2 u_fn3 (.A(instruct[3]), .B(is_r), .Y(funct4[3]));
  AND2 u_im0 (.A(instruct[0]), .B(is_i), .Y(imm[0]));
  AND2 u_im1 (.A(instruct[1]), .B(is_i), .Y(imm[1]));
  AND2 u_im2 (.A(instruct[2]), .B(is_i), .Y(imm[2]));
  AND2 u_im3 (.A(instruct[3]), .B(is_i), .Y(imm[3]));
  AND2 u_ad0  (.A(instruct[0]),  .B(is_j), .Y(addr[0]));
  AND2 u_ad1  (.A(instruct[1]),  .B(is_j), .Y(addr[1]));
  AND2 u_ad2  (.A(instruct[2]),  .B(is_j), .Y(addr[2]));
  AND2 u_ad3  (.A(instruct[3]),  .B(is_j), .Y(addr[3]));
  AND2 u_ad4  (.A(instruct[4]),  .B(is_j), .Y(addr[4]));
  AND2 u_ad5  (.A(instruct[5]),  .B(is_j), .Y(addr[5]));
  AND2 u_ad6  (.A(instruct[6]),  .B(is_j), .Y(addr[6]));
  AND2 u_ad7  (.A(instruct[7]),  .B(is_j), .Y(addr[7]));
  AND2 u_ad8  (.A(instruct[8]),  .B(is_j), .Y(addr[8]));
  AND2 u_ad9  (.A(instruct[9]),  .B(is_j), .Y(addr[9]));
  AND2 u_ad10 (.A(instruct[10]), .B(is_j), .Y(addr[10]));
  AND2 u_ad11 (.A(instruct[11]), .B(is_j), .Y(addr[11]));
endmodule
