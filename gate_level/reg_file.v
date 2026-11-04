// =============================================================================
// reg_file.v -- 16 x 16-bit register file (gate-level equivalent of registers.sv)
//
//   write : on the rising clk edge, if we = 1 and rd != 0, x<rd> <= wd
//   read  : rd1 = x<rs1>, rd2 = x<rs2>   (combinational, 2 read ports)
//   reset : rst = 1 -> x1..x15 <= 0 on the clock edge (synchronous)
//   x0    : hardwired to GND -- not a register at all
//
//                +-------------+  wsel[15:1]   +-----------------+
//    rd, we ---->| dec4to16_en |-------------->| 15 x reg16_r    |  x1..x15
//                +-------------+  (en of each) | (d = wd, all)   |
//                                              +--------+--------+
//                                        x0=GND, x1..x15 |
//                                   +--------------------+------------------+
//                                   v                                       v
//                          +------------------+                    +------------------+
//                rs1 ----->| mux16_16  (rdA)  |--> rd1   rs2 ----->| mux16_16  (rdB)  |--> rd2
//                          +------------------+                    +------------------+
//
// Difference from registers.sv: its reset loop is `for (i=0; i<15; ...)`, so
// x15 is never reset there (reads X until written). Here x15 resets like the
// others. Fix in RTL: change i<15 to i<16.
// =============================================================================
module reg_file (
  input         clk,
  input         rst,
  input         we,
  input  [3:0]  rs1,
  input  [3:0]  rs2,
  input  [3:0]  rd,
  input  [15:0] wd,
  output [15:0] rd1,
  output [15:0] rd2
);
  wire [15:0] wsel;                    // one-hot write enables (wsel[0] unused: x0 is read-only)
  wire [15:0] x0, x1, x2, x3, x4, x5, x6, x7;
  wire [15:0] x8, x9, x10, x11, x12, x13, x14, x15;

  // ---- write decoder -----------------------------------------------------------
  dec4to16_en u_wdec (.a(rd), .en(we), .y(wsel));

  // ---- registers ---------------------------------------------------------------
  assign x0 = 16'h0000;                // x0 = GND on all 16 bits
  reg16_r u_x1  (.clk(clk), .rst(rst), .en(wsel[1]),  .d(wd), .q(x1));
  reg16_r u_x2  (.clk(clk), .rst(rst), .en(wsel[2]),  .d(wd), .q(x2));
  reg16_r u_x3  (.clk(clk), .rst(rst), .en(wsel[3]),  .d(wd), .q(x3));
  reg16_r u_x4  (.clk(clk), .rst(rst), .en(wsel[4]),  .d(wd), .q(x4));
  reg16_r u_x5  (.clk(clk), .rst(rst), .en(wsel[5]),  .d(wd), .q(x5));
  reg16_r u_x6  (.clk(clk), .rst(rst), .en(wsel[6]),  .d(wd), .q(x6));
  reg16_r u_x7  (.clk(clk), .rst(rst), .en(wsel[7]),  .d(wd), .q(x7));
  reg16_r u_x8  (.clk(clk), .rst(rst), .en(wsel[8]),  .d(wd), .q(x8));
  reg16_r u_x9  (.clk(clk), .rst(rst), .en(wsel[9]),  .d(wd), .q(x9));
  reg16_r u_x10 (.clk(clk), .rst(rst), .en(wsel[10]), .d(wd), .q(x10));
  reg16_r u_x11 (.clk(clk), .rst(rst), .en(wsel[11]), .d(wd), .q(x11));
  reg16_r u_x12 (.clk(clk), .rst(rst), .en(wsel[12]), .d(wd), .q(x12));
  reg16_r u_x13 (.clk(clk), .rst(rst), .en(wsel[13]), .d(wd), .q(x13));
  reg16_r u_x14 (.clk(clk), .rst(rst), .en(wsel[14]), .d(wd), .q(x14));
  reg16_r u_x15 (.clk(clk), .rst(rst), .en(wsel[15]), .d(wd), .q(x15));

  // ---- read ports --------------------------------------------------------------
  mux16_16 u_rdA (
    .d0  (x0),
    .d1  (x1),
    .d2  (x2),
    .d3  (x3),
    .d4  (x4),
    .d5  (x5),
    .d6  (x6),
    .d7  (x7),
    .d8  (x8),
    .d9  (x9),
    .d10 (x10),
    .d11 (x11),
    .d12 (x12),
    .d13 (x13),
    .d14 (x14),
    .d15 (x15),
    .sel (rs1),
    .y   (rd1)
  );
  mux16_16 u_rdB (
    .d0  (x0),
    .d1  (x1),
    .d2  (x2),
    .d3  (x3),
    .d4  (x4),
    .d5  (x5),
    .d6  (x6),
    .d7  (x7),
    .d8  (x8),
    .d9  (x9),
    .d10 (x10),
    .d11 (x11),
    .d12 (x12),
    .d13 (x13),
    .d14 (x14),
    .d15 (x15),
    .sel (rs2),
    .y   (rd2)
  );
endmodule
