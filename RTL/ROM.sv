module ROME(
    input [15:0]PC,
    output [15:0] IR
);
reg [15:0] registan [127:0];
initial begin
    // [15:12] opcode  [11:8] rt/rd  [7:4] rs  [3:0] funct/imm
    registan[0]  = 16'h3105;   //addi: r1 = r0 + 5                 -> 5
    registan[1]  = 16'h3203;  // addi: r2 = r0 + 3                 -> 3
    registan[2]  = 16'h0120;    // add  : r1 = r2 + r1                -> 8
    registan[3]  = 16'h0211; // sub : r2 = r1 - r2                -> 5
    registan[4]  = 16'h3302;   // addi : r3 = r0 + 2                 -> 2
    registan[5]  = 16'h0322; // sll : r3 = r2 << r3               -> 20
    registan[6]  = 16'h340C; // addi: r4 = r0 + 12                -> 12
    registan[7]  = 16'h0433;    // and : r4 = r3 & r4                -> 4
    registan[8]  = 16'h2304;  // sw : mem[r0+4] = r3              -> mem[4] = 20
    registan[9]  = 16'h1504;   // lw : r5 = mem[r0+4]              -> 20
    registan[10] = 16'h4532;   // beq : r3 == r5 ? pc+2 (12)        taken
    registan[11] = 16'h360F;   // addi : r6 = r0 + 15                skipped
    registan[12] = 16'h5532;    // bne : r3 != r5 ? pc+2             not taken
    registan[13] = 16'h3771;  // addi : r7 = r7 + 1                 loop start
    registan[14] = 16'h0870;    // add  : r8 = r7 + r8
    registan[15] = 16'h572E; // bne  : r2 != r7 ? pc-2 (13)        loops until r7 = 5, r8 = 1+2+3+4+5
    registan[16] = 16'h6012;    // jmp : 18
    registan[17] = 16'h360E;    // addi : r6 = r0 + 14                skipped
    registan[18] = 16'h3007;   // addi : r0 = r0 + 7                 r0 must stay 0
    registan[19] = 16'h2805;   // sw : mem[r0+5] = r8              -> mem[5] = 15
    registan[20] = 16'h6014;  // jmp : 20, jump to self = halt
end
assign IR=registan[PC[6:0]];


endmodule