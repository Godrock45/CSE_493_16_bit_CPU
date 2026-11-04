// =============================================================================
// cpu_top.v -- whole CPU, gate level (equivalent of top.sv, module `top_wire`)
//
// Same ports and the same signal names (*_loc) as top.sv, so you can line
// the two files up. Every RTL expression in top.sv maps to one block here:
//
//   top.sv                                              gate-level block
//   PrgCo / ROME / decoder / control / registers        u_pc u_rom u_dec u_ctrl u_rf
//   ALU / memory                                        u_alu u_dmem
//   PC_plus1 = PC + 1                                   inc16    u_inc
//   OpA      = AluSrcA ? PC  : rd1                      mux2_16  u_opa
//   OpB      = AluSrc  ? imm : rd2                      mux2_16  u_opb
//   zero     = (res == 0)                               zero16   u_zero
//   take     = Branch & (zero ^ opcode[0])              XOR2 u_tk_x + AND2 u_tk
//   br_tgt   = PC + sext(imm[3:0])                      add16    u_brt
//   next_PC  = Jump ? {4'b0,addr} : take ? br_tgt : PC_plus1
//                                                       mux2_16  u_npc1, u_npc2
//   wd       = MemToReg ? mem_dat : Jump ? PC_plus1 : res
//                                                       mux2_16  u_wb1, u_wb2
//   halt     = (next_PC == PC)                          eq16     u_halt
//
// The register file's 2nd read port is addressed by rd (rs2 = rd), exactly as
// in top.sv: the ISA is 2-operand, so rd is both destination and 2nd source.
// =============================================================================
module cpu_top (
  input         clk,
  input         rst,
  output [15:0] dbg_pc,
  output [15:0] dbg_instr,
  output        dbg_reg_we,
  output [3:0]  dbg_rd,
  output [15:0] dbg_wb_data,
  output        halt
);
  wire [15:0] next_PC_loc, PC_loc, PC_plus1_loc, IR_loc, imm_loc;
  wire [15:0] rd1_loc, rd2_loc, OpA_loc, OpB_loc, res_loc, mem_dat_loc, wd_loc;
  wire [15:0] br_off_loc, br_tgt_loc, jmp_tgt_loc, npc_br_loc, wb_j_loc;
  wire [11:0] jal_addr_loc;
  wire [3:0]  rd_loc, rs1_loc, funct4_loc, opcode_loc, AluCtrl_loc;
  wire        RegWrite_loc, AluSrc_loc, MemRead_loc, MemWrite_loc, Branch_loc;
  wire        Jump_loc, AluSrcA_loc, MemToReg_loc, zero_loc, take_x_loc, take_loc;

  // ---- wiring only (no gates): sign-extend branch offset, zero-extend jump target ----
  assign br_off_loc  = {{12{imm_loc[3]}}, imm_loc[3:0]};   // bits 15..4 all = imm[3]
  assign jmp_tgt_loc = {4'b0000, jal_addr_loc};              // bits 15..12 = GND

  // ---- units ---------------------------------------------------------------------
  pc_reg u_pc (.clk(clk), .rst(rst), .pc_en(1'b1), .next_pc(next_PC_loc), .pc(PC_loc));
  instr_rom u_rom (.PC(PC_loc), .IR(IR_loc));
  instr_dec u_dec (
    .instruct (IR_loc),
    .rd       (rd_loc),
    .rs1      (rs1_loc),
    .funct4   (funct4_loc),
    .imm      (imm_loc),
    .opcode   (opcode_loc),
    .addr     (jal_addr_loc)
  );
  ctrl_unit u_ctrl (
    .Opcode   (opcode_loc),
    .funct4   (funct4_loc),
    .RegWrite (RegWrite_loc),
    .AluSrc   (AluSrc_loc),
    .MemRead  (MemRead_loc),
    .MemWrite (MemWrite_loc),
    .AluCtrl  (AluCtrl_loc),
    .Branch   (Branch_loc),
    .Jump     (Jump_loc),
    .AluSrcA  (AluSrcA_loc),
    .MemToReg (MemToReg_loc)
  );
  reg_file u_rf (
    .clk (clk),
    .rst (rst),
    .we  (RegWrite_loc),
    .rs1 (rs1_loc),
    .rs2 (rd_loc),
    .rd  (rd_loc),
    .wd  (wd_loc),
    .rd1 (rd1_loc),
    .rd2 (rd2_loc)
  );
  alu16 u_alu (.OpA(OpA_loc), .OpB(OpB_loc), .ALUCtrl(AluCtrl_loc), .Res(res_loc));
  data_mem u_dmem (.clk(clk), .addr(res_loc), .dat(rd2_loc), .write_ena(MemWrite_loc), .mem_dat(mem_dat_loc));

  // ---- datapath glue ---------------------------------------------------------------
  inc16 u_inc (.a(PC_loc), .s(PC_plus1_loc));  // PC + 1
  mux2_16 u_opa (.i0(rd1_loc), .i1(PC_loc),  .s(AluSrcA_loc), .y(OpA_loc));  // ALU A operand
  mux2_16 u_opb (.i0(rd2_loc), .i1(imm_loc), .s(AluSrc_loc),  .y(OpB_loc));  // ALU B operand
  zero16 u_zero (.a(res_loc), .y(zero_loc));
  XOR2 u_tk_x (.A(zero_loc),   .B(opcode_loc[0]), .Y(take_x_loc));  // BEQ: zero, BNE: ~zero
  AND2 u_tk   (.A(Branch_loc), .B(take_x_loc),    .Y(take_loc));
  add16 u_brt (.a(PC_loc), .b(br_off_loc), .cin(1'b0), .s(br_tgt_loc), .cout());  // branch target
  mux2_16 u_npc1 (.i0(PC_plus1_loc), .i1(br_tgt_loc),   .s(take_loc),     .y(npc_br_loc));
  mux2_16 u_npc2 (.i0(npc_br_loc),   .i1(jmp_tgt_loc),  .s(Jump_loc),     .y(next_PC_loc));  // next PC
  mux2_16 u_wb1  (.i0(res_loc),      .i1(PC_plus1_loc), .s(Jump_loc),     .y(wb_j_loc));
  mux2_16 u_wb2  (.i0(wb_j_loc),     .i1(mem_dat_loc),  .s(MemToReg_loc), .y(wd_loc));       // write-back data
  eq16 u_halt (.a(next_PC_loc), .b(PC_loc), .y(halt));  // jump-to-self

  // ---- debug outputs (wires) -----------------------------------------------------------
  assign dbg_pc      = PC_loc;
  assign dbg_instr   = IR_loc;
  assign dbg_reg_we  = RegWrite_loc;
  assign dbg_rd      = rd_loc;
  assign dbg_wb_data = wd_loc;
endmodule
