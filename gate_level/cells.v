// =============================================================================
// cells.v -- primitive cell library (the ONLY leaf cells in the netlist)
//
// Every other module in gate_level/ is built purely by instantiating these 8
// cells (directly, or through modules that are). In Virtuoso, each cell here
// becomes ONE transistor-level schematic + symbol in your cell library.
// README.md suggests a CMOS circuit and transistor count for each.
//
// The bodies below are behavioural models for SIMULATION ONLY. Do not draw
// this code -- draw the transistor circuit for the function in the table.
//
//   cell    pins             function
//   INV     A        -> Y    Y = ~A
//   NAND2   A, B     -> Y    Y = ~(A & B)
//   NOR2    A, B     -> Y    Y = ~(A | B)
//   AND2    A, B     -> Y    Y =   A & B        (NAND2 followed by INV)
//   OR2     A, B     -> Y    Y =   A | B        (NOR2 followed by INV)
//   XOR2    A, B     -> Y    Y =   A ^ B
//   MUX2    I0,I1,S  -> Y    Y = S ? I1 : I0
//   DFF     D, CLK   -> Q    Q <= D on the RISING edge of CLK (no reset pin;
//                            resets are done with logic in front of D)
// =============================================================================

module INV   (input A,                     output Y); assign Y = ~A;          endmodule
module NAND2 (input A,  input B,           output Y); assign Y = ~(A & B);    endmodule
module NOR2  (input A,  input B,           output Y); assign Y = ~(A | B);    endmodule
module AND2  (input A,  input B,           output Y); assign Y =   A & B;     endmodule
module OR2   (input A,  input B,           output Y); assign Y =   A | B;     endmodule
module XOR2  (input A,  input B,           output Y); assign Y =   A ^ B;     endmodule
module MUX2  (input I0, input I1, input S, output Y); assign Y = S ? I1 : I0; endmodule

module DFF (input D, input CLK, output reg Q);
  always @(posedge CLK) Q <= D;
endmodule
