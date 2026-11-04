`timescale 1ns/1ps
// Whole-CPU lockstep check: the RTL core (top_wire, ../top.sv) and the
// gate-level core (cpu_top) run the program in ROM.sv side by side from the
// same clock and reset. Every debug output is compared every cycle until the
// program halts (jump-to-self), then the register file and data-memory words
// 0..15 are compared. An X bit in the RTL is a don't-care.
//
//   vvp tb_cpu.vvp          normal run
//   vvp tb_cpu.vvp +trace   also print one line per cycle
//   vvp tb_cpu.vvp +vcd     also dump cpu_gl.vcd (reference waveforms for
//                           comparing against a Virtuoso transient sim)
module tb_cpu;
  logic clk = 0, rst = 1;
  always #5 clk = ~clk;                // 10 ns clock (zero-delay models)

  wire [15:0] pc_r, ir_r, wb_r, pc_g, ir_g, wb_g;
  wire [3:0]  rd_r, rd_g;
  wire        we_r, we_g, halt_r, halt_g;

  top_wire rtl (.clk(clk), .rst(rst), .dbg_pc(pc_r), .dbg_instr(ir_r), .dbg_reg_we(we_r),
                .dbg_rd(rd_r), .dbg_wb_data(wb_r), .halt(halt_r));
  cpu_top  gl  (.clk(clk), .rst(rst), .dbg_pc(pc_g), .dbg_instr(ir_g), .dbg_reg_we(we_g),
                .dbg_rd(rd_g), .dbg_wb_data(wb_g), .halt(halt_g));

  // gate-level architectural state, for the final comparison
  wire [15:0] gl_x [0:15];
  wire [15:0] gl_m [0:15];
  assign gl_x[ 0] = gl.u_rf.x0;
  assign gl_x[ 1] = gl.u_rf.x1;
  assign gl_x[ 2] = gl.u_rf.x2;
  assign gl_x[ 3] = gl.u_rf.x3;
  assign gl_x[ 4] = gl.u_rf.x4;
  assign gl_x[ 5] = gl.u_rf.x5;
  assign gl_x[ 6] = gl.u_rf.x6;
  assign gl_x[ 7] = gl.u_rf.x7;
  assign gl_x[ 8] = gl.u_rf.x8;
  assign gl_x[ 9] = gl.u_rf.x9;
  assign gl_x[10] = gl.u_rf.x10;
  assign gl_x[11] = gl.u_rf.x11;
  assign gl_x[12] = gl.u_rf.x12;
  assign gl_x[13] = gl.u_rf.x13;
  assign gl_x[14] = gl.u_rf.x14;
  assign gl_x[15] = gl.u_rf.x15;
  assign gl_m[ 0] = gl.u_dmem.u_bank0.w0;
  assign gl_m[ 1] = gl.u_dmem.u_bank0.w1;
  assign gl_m[ 2] = gl.u_dmem.u_bank0.w2;
  assign gl_m[ 3] = gl.u_dmem.u_bank0.w3;
  assign gl_m[ 4] = gl.u_dmem.u_bank0.w4;
  assign gl_m[ 5] = gl.u_dmem.u_bank0.w5;
  assign gl_m[ 6] = gl.u_dmem.u_bank0.w6;
  assign gl_m[ 7] = gl.u_dmem.u_bank0.w7;
  assign gl_m[ 8] = gl.u_dmem.u_bank0.w8;
  assign gl_m[ 9] = gl.u_dmem.u_bank0.w9;
  assign gl_m[10] = gl.u_dmem.u_bank0.w10;
  assign gl_m[11] = gl.u_dmem.u_bank0.w11;
  assign gl_m[12] = gl.u_dmem.u_bank0.w12;
  assign gl_m[13] = gl.u_dmem.u_bank0.w13;
  assign gl_m[14] = gl.u_dmem.u_bank0.w14;
  assign gl_m[15] = gl.u_dmem.u_bank0.w15;

  integer errors = 0, checks = 0, cyc, i;
  bit     done = 0;

  function automatic bit same16(input logic [15:0] rtl_v, input logic [15:0] gl_v);
    if (rtl_v === gl_v) return 1;           // fast path: identical, no X
    for (int b = 0; b < 16; b++)
      if (rtl_v[b] !== 1'bx && rtl_v[b] !== 1'bz && rtl_v[b] !== gl_v[b]) return 0;
    return 1;
  endfunction

  task automatic check16(input [8*12:1] what, input logic [15:0] rtl_v, input logic [15:0] gl_v);
    checks = checks + 1;
    if (!same16(rtl_v, gl_v)) begin
      errors = errors + 1;
      if (errors <= 20) $display("  MISMATCH cycle %0d %0s: rtl=%h gl=%h", cyc, what, rtl_v, gl_v);
    end
  endtask

  initial begin
    if ($test$plusargs("vcd")) begin $dumpfile("cpu_gl.vcd"); $dumpvars(0, tb_cpu); end
    $display("whole-CPU lockstep: cpu_top (gate level) vs top_wire (RTL)");
    cyc = 0;
    @(negedge clk); @(negedge clk); rst = 0;   // two clock edges in reset
    for (cyc = 0; cyc < 1000 && !done; cyc = cyc + 1) begin
      #3;                                      // let combinational logic settle
      check16("dbg_pc", pc_r, pc_g);
      check16("dbg_instr", ir_r, ir_g);
      check16("dbg_reg_we", we_r, we_g);
      check16("dbg_rd", rd_r, rd_g);
      check16("dbg_wb_data", wb_r, wb_g);
      check16("halt", halt_r, halt_g);
      if ($test$plusargs("trace"))
        $display("  cyc %3d  pc=%0d  ir=%h  we=%b rd=%0d wb=%h  halt=%b", cyc, pc_g, ir_g, we_g, rd_g, wb_g, halt_g);
      if (halt_r === 1'b1 && halt_g === 1'b1) done = 1;
      else @(negedge clk);
    end
    $display("  halted at pc=%0d after %0d cycles", pc_g, cyc);

    for (i = 0; i < 16; i = i + 1) check16("register", rtl.npn.registers[i], gl_x[i]);
    for (i = 0; i < 16; i = i + 1) check16("memory", rtl.meme.memistan[i], gl_m[i]);
    $display("  gate-level registers:");
    for (i = 0; i < 16; i = i + 4)
      $display("    x%-2d=%h  x%-2d=%h  x%-2d=%h  x%-2d=%h", i, gl_x[i], i+1, gl_x[i+1], i+2, gl_x[i+2], i+3, gl_x[i+3]);
    $display("  gate-level memory words 0..7: %h %h %h %h %h %h %h %h",
             gl_m[0], gl_m[1], gl_m[2], gl_m[3], gl_m[4], gl_m[5], gl_m[6], gl_m[7]);

    if (halt_g !== 1'b1)  begin errors = errors + 1; $display("  gate-level CPU did not halt"); end
    if (errors == 0) $display("PASS: %0d checks, 0 mismatches", checks);
    else             $display("FAIL: %0d checks, %0d mismatches", checks, errors);
    $finish;
  end
endmodule
