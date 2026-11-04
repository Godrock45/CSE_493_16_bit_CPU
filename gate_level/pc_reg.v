// =============================================================================
// pc_reg.v -- program counter (gate-level equivalent of PC.sv, module `PrgCo`)
//
//   rst = 1 -> pc <= 0;  else if pc_en -> pc <= next_pc;  else hold.
// It is exactly one reg16_r (synchronous reset + load enable).
// cpu_top ties pc_en to VDD, like top.sv does.
// =============================================================================
module pc_reg (input clk, input rst, input pc_en, input [15:0] next_pc, output [15:0] pc);
  reg16_r u_pc (.clk(clk), .rst(rst), .en(pc_en), .d(next_pc), .q(pc));
endmodule
