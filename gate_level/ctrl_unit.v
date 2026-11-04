// =============================================================================
// ctrl_unit.v -- main control (gate-level equivalent of control.sv)
//
//   Opcode  instr  RegWrite AluSrc MemRead MemWrite MemToReg Branch Jump  AluCtrl
//   0000    R         1       0      0       0        0       0     0    funct4
//   0001    LW        1       1      1       0        1       0     0    0000
//   0010    SW        0       1      0       1        0       0     0    0000
//   0011    ADDI      1       1      0       0        0       0     0    0000
//   0100    BEQ       0       0      0       0        0       1     0    0001
//   0101    BNE       0       0      0       0        0       1     0    0001
//   0110    JMP       0       0      0       0        0       0     1    1111
//   others  --        0       0      0       0        0       0     0    1111
//   AluSrcA is always 0 (tied to GND).
//
// Structure ("decoder + OR plane"):
//   1) two dec2to4 + 7 AND2 give one line per instruction: is_r ... is_jmp
//   2) each control signal = OR of the instruction lines where it is 1
//   3) AluCtrl = funct4 for R, 0001 for branches, 1111 for "other" (dflt):
//        dflt       = ~(is_r | AluSrc | Branch)
//        AluCtrl[0] = (is_r & funct4[0]) | dflt | Branch
//        AluCtrl[k] = (is_r & funct4[k]) | dflt          k = 1..3
// =============================================================================
module ctrl_unit (
  input  [3:0] Opcode,
  input  [3:0] funct4,
  output       RegWrite,
  output       AluSrc,
  output       MemRead,
  output       MemWrite,
  output [3:0] AluCtrl,
  output       Branch,
  output       Jump,
  output       AluSrcA,
  output       MemToReg
);
  wire [3:0] hi, lo;
  wire       is_r, is_lw, is_addi, is_beq, is_bne;
  wire       rw_t, as_t, any_t, dflt;
  wire [3:0] f, a_t;

  // ---- one line per instruction --------------------------------------------------
  dec2to4 u_dhi (.a(Opcode[3:2]), .y(hi));
  dec2to4 u_dlo (.a(Opcode[1:0]), .y(lo));
  AND2 u_is_r    (.A(hi[0]), .B(lo[0]), .Y(is_r));      // 0000  R-type
  AND2 u_is_lw   (.A(hi[0]), .B(lo[1]), .Y(is_lw));     // 0001  LW
  AND2 u_is_sw   (.A(hi[0]), .B(lo[2]), .Y(MemWrite));  // 0010  SW   (= MemWrite)
  AND2 u_is_addi (.A(hi[0]), .B(lo[3]), .Y(is_addi));   // 0011  ADDI
  AND2 u_is_beq  (.A(hi[1]), .B(lo[0]), .Y(is_beq));    // 0100  BEQ
  AND2 u_is_bne  (.A(hi[1]), .B(lo[1]), .Y(is_bne));    // 0101  BNE
  AND2 u_is_jmp  (.A(hi[1]), .B(lo[2]), .Y(Jump));      // 0110  JMP  (= Jump)

  // ---- OR plane --------------------------------------------------------------------
  assign MemRead  = is_lw;             // straight wires
  assign MemToReg = is_lw;
  assign AluSrcA  = 1'b0;              // GND
  OR2 u_rw_t (.A(is_r),   .B(is_lw),    .Y(rw_t));
  OR2 u_rw   (.A(rw_t),   .B(is_addi),  .Y(RegWrite));  // R | LW | ADDI
  OR2 u_as_t (.A(is_lw),  .B(MemWrite), .Y(as_t));
  OR2 u_as   (.A(as_t),   .B(is_addi),  .Y(AluSrc));    // LW | SW | ADDI
  OR2 u_br   (.A(is_beq), .B(is_bne),   .Y(Branch));    // BEQ | BNE

  // ---- AluCtrl -----------------------------------------------------------------------
  OR2  u_any_t (.A(is_r),  .B(AluSrc), .Y(any_t));
  NOR2 u_dflt  (.A(any_t), .B(Branch), .Y(dflt));   // not R/LW/SW/ADDI/BEQ/BNE
  AND2 u_f0 (.A(is_r), .B(funct4[0]), .Y(f[0]));
  AND2 u_f1 (.A(is_r), .B(funct4[1]), .Y(f[1]));
  AND2 u_f2 (.A(is_r), .B(funct4[2]), .Y(f[2]));
  AND2 u_f3 (.A(is_r), .B(funct4[3]), .Y(f[3]));
  OR2 u_a_t0 (.A(f[0]),   .B(dflt),   .Y(a_t[0]));
  OR2 u_ac0  (.A(a_t[0]), .B(Branch), .Y(AluCtrl[0]));
  OR2 u_ac1  (.A(f[1]),   .B(dflt),   .Y(AluCtrl[1]));
  OR2 u_ac2  (.A(f[2]),   .B(dflt),   .Y(AluCtrl[2]));
  OR2 u_ac3  (.A(f[3]),   .B(dflt),   .Y(AluCtrl[3]));
endmodule
