`timescale 1ns/1ps
// Unit-level equivalence: every gate-level block against its RTL module.
//   control / decoder / ROM : exhaustive over all inputs
//   ALU                     : every ALUCtrl x (corner values, all shift amounts, random)
//   PC / regfile / memory   : random traffic, outputs compared every cycle
// An X bit in the RTL output means "undefined in the RTL" (never-written memory
// word, uninitialised ROM word, ...) and is not compared.
module tb_units;
  integer errors = 0, checks = 0;
  integer i, j, k, n;

  function automatic bit same16(input logic [15:0] rtl, input logic [15:0] gl);
    if (rtl === gl) return 1;           // fast path: identical, no X
    for (int b = 0; b < 16; b++)
      if (rtl[b] !== 1'bx && rtl[b] !== 1'bz && rtl[b] !== gl[b]) return 0;
    return 1;
  endfunction

  task automatic check16(input [8*12:1] what, input logic [15:0] rtl, input logic [15:0] gl);
    checks = checks + 1;
    if (!same16(rtl, gl)) begin
      errors = errors + 1;
      if (errors <= 20) $display("  MISMATCH %0s @%0t: rtl=%h gl=%h", what, $time, rtl, gl);
    end
  endtask

  task automatic report(input [8*12:1] what, input integer c0, input integer e0);
    $display("  %-10s %7d checks  %0d mismatches", what, checks - c0, errors - e0);
  endtask

  // ---------------------------------------------------------------- control
  logic [3:0] c_op, c_f4;
  wire [3:0] c_ac_r, c_ac_g;
  wire c_rw_r, c_as_r, c_mr_r, c_mw_r, c_br_r, c_j_r, c_asa_r, c_m2r_r;
  wire c_rw_g, c_as_g, c_mr_g, c_mw_g, c_br_g, c_j_g, c_asa_g, c_m2r_g;
  control rtl_ctrl (.Opcode(c_op), .funct4(c_f4), .RegWrite(c_rw_r), .AluSrc(c_as_r), .MemRead(c_mr_r),
                    .MemWrite(c_mw_r), .AluCtrl(c_ac_r), .Branch(c_br_r), .Jump(c_j_r), .AluSrcA(c_asa_r),
                    .MemToReg(c_m2r_r));
  ctrl_unit gl_ctrl (.Opcode(c_op), .funct4(c_f4), .RegWrite(c_rw_g), .AluSrc(c_as_g), .MemRead(c_mr_g),
                     .MemWrite(c_mw_g), .AluCtrl(c_ac_g), .Branch(c_br_g), .Jump(c_j_g), .AluSrcA(c_asa_g),
                     .MemToReg(c_m2r_g));
  wire [15:0] c_pack_r = {4'b0, c_ac_r, c_rw_r, c_as_r, c_mr_r, c_mw_r, c_br_r, c_j_r, c_asa_r, c_m2r_r};
  wire [15:0] c_pack_g = {4'b0, c_ac_g, c_rw_g, c_as_g, c_mr_g, c_mw_g, c_br_g, c_j_g, c_asa_g, c_m2r_g};

  // ---------------------------------------------------------------- decoder
  logic [15:0] d_in;
  wire [3:0]  d_rd_r, d_rs_r, d_fn_r, d_op_r, d_rd_g, d_rs_g, d_fn_g, d_op_g;
  wire [15:0] d_im_r, d_im_g;
  wire [11:0] d_ad_r, d_ad_g;
  decoder   rtl_dec (.instruct(d_in), .rd(d_rd_r), .rs1(d_rs_r), .funct4(d_fn_r), .imm(d_im_r), .opcode(d_op_r), .addr(d_ad_r));
  instr_dec gl_dec  (.instruct(d_in), .rd(d_rd_g), .rs1(d_rs_g), .funct4(d_fn_g), .imm(d_im_g), .opcode(d_op_g), .addr(d_ad_g));

  // ---------------------------------------------------------------- ALU
  logic [15:0] a_a, a_b;
  logic [3:0]  a_c;
  wire  [15:0] a_res_r, a_res_g;
  ALU   rtl_alu (.OpA(a_a), .OpB(a_b), .ALUCtrl(a_c), .Res(a_res_r));
  alu16 gl_alu  (.OpA(a_a), .OpB(a_b), .ALUCtrl(a_c), .Res(a_res_g));
  logic [15:0] corner [0:15];
  initial begin
    corner[0]  = 16'h0000; corner[1]  = 16'h0001; corner[2]  = 16'h0002; corner[3]  = 16'h7FFF;
    corner[4]  = 16'h8000; corner[5]  = 16'h8001; corner[6]  = 16'hFFFF; corner[7]  = 16'hFFFE;
    corner[8]  = 16'h00FF; corner[9]  = 16'hFF00; corner[10] = 16'h5555; corner[11] = 16'hAAAA;
    corner[12] = 16'h1234; corner[13] = 16'hFEDC; corner[14] = 16'h0010; corner[15] = 16'h4000;
  end

  // ---------------------------------------------------------------- ROM
  logic [15:0] r_pc;
  wire  [15:0] r_ir_r, r_ir_g;
  ROME      rtl_rom (.PC(r_pc), .IR(r_ir_r));
  instr_rom gl_rom  (.PC(r_pc), .IR(r_ir_g));

  // ---------------------------------------------------------------- sequential units
  // One free-running clock, started only for the sequential tests and gated to
  // the unit under test (enables change while clk is low, so no glitches).
  // Otherwise every flip-flop -- 2048 of them in the data memory -- would be
  // clocked during every test and the run would take minutes.
  logic clk = 0, run_clk = 0, en_pc = 0, en_rf = 0, en_mem = 0;
  wire  clk_pc = clk & en_pc, clk_rf = clk & en_rf, clk_mem = clk & en_mem;
  initial begin wait (run_clk); forever #5 clk = ~clk; end

  logic        p_rst, p_en;
  logic [15:0] p_next;
  wire  [15:0] p_pc_r, p_pc_g;
  PrgCo  rtl_pc (.clk(clk_pc), .rst(p_rst), .pc_en(p_en), .next_pc(p_next), .pc(p_pc_r));
  pc_reg gl_pc  (.clk(clk_pc), .rst(p_rst), .pc_en(p_en), .next_pc(p_next), .pc(p_pc_g));

  logic        f_rst, f_we;
  logic [3:0]  f_rs1, f_rs2, f_rd;
  logic [15:0] f_wd;
  wire  [15:0] f_rd1_r, f_rd2_r, f_rd1_g, f_rd2_g;
  registers rtl_rf (.clk(clk_rf), .rst(f_rst), .we(f_we), .rs1(f_rs1), .rs2(f_rs2), .rd(f_rd), .wd(f_wd), .rd1(f_rd1_r), .rd2(f_rd2_r));
  reg_file  gl_rf  (.clk(clk_rf), .rst(f_rst), .we(f_we), .rs1(f_rs1), .rs2(f_rs2), .rd(f_rd), .wd(f_wd), .rd1(f_rd1_g), .rd2(f_rd2_g));
  // registers.sv never resets x15 (loop is i<15); reg_file does. After a reset
  // that follows a write to x15 the two legitimately differ until x15 is
  // written again, so x15 reads are skipped while that is the case.
  bit x15_written = 0, x15_differs = 0;
  always @(posedge clk_rf)
    if (f_rst) x15_differs <= x15_written;
    else if (f_we && f_rd == 4'd15) begin x15_written <= 1; x15_differs <= 0; end

  logic        m_we;
  logic [15:0] m_addr, m_dat;
  wire  [15:0] m_out_r, m_out_g;
  memory   rtl_mem (.clk(clk_mem), .addr(m_addr), .dat(m_dat), .write_ena(m_we), .mem_dat(m_out_r));
  data_mem gl_mem  (.clk(clk_mem), .addr(m_addr), .dat(m_dat), .write_ena(m_we), .mem_dat(m_out_g));

  // ---------------------------------------------------------------- stimulus
  integer c0, e0;
  initial begin
    $display("unit equivalence: gate level vs RTL");

    c0 = checks; e0 = errors;
    for (i = 0; i < 256; i = i + 1) begin
      {c_op, c_f4} = i; #1;
      check16("control", c_pack_r, c_pack_g);
    end
    report("control", c0, e0);

    c0 = checks; e0 = errors;
    for (i = 0; i < 65536; i = i + 1) begin
      d_in = i; #1;
      check16("dec.rd", d_rd_r, d_rd_g);   check16("dec.rs1", d_rs_r, d_rs_g);
      check16("dec.funct4", d_fn_r, d_fn_g); check16("dec.imm", d_im_r, d_im_g);
      check16("dec.opcode", d_op_r, d_op_g); check16("dec.addr", d_ad_r, d_ad_g);
    end
    report("decoder", c0, e0);

    c0 = checks; e0 = errors;
    for (k = 0; k < 16; k = k + 1) begin
      a_c = k;
      for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) begin a_a = corner[i]; a_b = corner[j]; #1; check16("alu", a_res_r, a_res_g); end
        for (j = 0; j < 64; j = j + 1) begin a_a = corner[i]; a_b = j; #1; check16("alu", a_res_r, a_res_g); end
      end
      for (n = 0; n < 2000; n = n + 1) begin a_a = $random; a_b = $random; #1; check16("alu", a_res_r, a_res_g); end
    end
    report("ALU", c0, e0);

    c0 = checks; e0 = errors;
    for (i = 0; i < 65536; i = i + 1) begin
      r_pc = i; #1;
      check16("rom", r_ir_r, r_ir_g);
    end
    report("ROM", c0, e0);

    // PC: random reset / enable / next value
    c0 = checks; e0 = errors;
    run_clk = 1;
    @(negedge clk); en_pc = 1; p_rst = 1; p_en = 0; p_next = 0;
    for (n = 0; n < 5000; n = n + 1) begin
      @(negedge clk);
      p_rst = ($random % 16) == 0; p_en = $random; p_next = $random;
      #3 check16("pc", p_pc_r, p_pc_g);
    end
    @(negedge clk); en_pc = 0;
    report("PC", c0, e0);

    // register file: reset first, then random writes/reads with occasional resets
    c0 = checks; e0 = errors;
    @(negedge clk); en_rf = 1; f_rst = 1; f_we = 0; f_rs1 = 0; f_rs2 = 0; f_rd = 0; f_wd = 0;
    @(negedge clk);
    for (n = 0; n < 20000; n = n + 1) begin
      @(negedge clk);
      f_rst = ($random % 500) == 0; f_we = $random; f_rd = $random; f_wd = $random;
      f_rs1 = $random; f_rs2 = $random;
      #3;
      if (!(x15_differs && f_rs1 == 15)) check16("rf.rd1", f_rd1_r, f_rd1_g);
      if (!(x15_differs && f_rs2 == 15)) check16("rf.rd2", f_rd2_r, f_rd2_g);
    end
    @(negedge clk); en_rf = 0; f_rst = 0; f_we = 0;
    report("regfile", c0, e0);

    // data memory: half the traffic in the low 32 words (so reads hit written
    // data), half anywhere in the 16-bit address space (addr[15:7] is ignored)
    c0 = checks; e0 = errors;
    @(negedge clk); en_mem = 1;
    for (n = 0; n < 10000; n = n + 1) begin
      @(negedge clk);
      m_we = $random; m_dat = $random;
      m_addr = (n % 2) ? $random : ($random & 16'h001F);
      #3 check16("mem", m_out_r, m_out_g);
    end
    @(negedge clk); en_mem = 0; m_we = 0;
    report("data mem", c0, e0);

    if (errors == 0) $display("PASS: %0d checks, 0 mismatches", checks);
    else             $display("FAIL: %0d checks, %0d mismatches", checks, errors);
    $finish;
  end
endmodule
