module ALU(
    input logic [15:0] OpA,
    input logic [15:0] OpB,
    input logic [3:0] ALUCtrl,
    output logic [15:0] Res
);

always_comb begin
    case(ALUCtrl)
    4'b0000: Res=OpA+OpB;                          //ADD
    4'b0001: Res=OpA-OpB;                          //SUB
    4'b0010: Res=OpA << (OpB[3:0]);                //SLL
    4'b0011: Res=OpA&OpB;                          //AND
    4'b0100: Res=$signed(OpA)<$signed(OpB);        //SLT
    4'b0101: Res= OpA^OpB;                         //XOR
    4'b0110: Res= OpA >> OpB[4:0];                 //SRL
    4'b0111: Res= $signed(OpA)>>>OpB[4:0];         //SRA
    4'b1000: Res= OpA|OpB;                         //OR
    default:
    Res=16'b0;
    endcase
    
end

endmodule