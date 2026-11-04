module control(
    input logic [3:0] Opcode,
    input logic [3:0] funct4,
    output logic RegWrite,
    output logic AluSrc,
    output logic MemRead,
    output logic MemWrite,
    output logic [3:0]AluCtrl,
    output logic Branch,
    output logic Jump,
    output logic AluSrcA,
    output logic MemToReg
);
always_comb begin
    RegWrite=0;
    AluCtrl=4'b1111;
    AluSrc=0;
    MemRead=0;
    MemWrite=0;
    Branch=0;
    Jump=0;
    MemToReg=0;
    AluSrcA=0;
    case(Opcode)
        4'b0000:begin                   //R type
            AluCtrl=funct4;
            RegWrite=1;
            AluSrc=0;
        end
        4'b0001:begin                   //I type Load
            AluCtrl=4'b0000;
            RegWrite=1;
            AluSrc=1;
            MemToReg=1;
            MemRead=1;
        end
        4'b0010:begin                   //I type Store
            AluCtrl=4'b0000;
            AluSrc=1;
            MemWrite=1;
        end
        4'b0011:begin                   //ADDI
            AluCtrl=4'b0000;
            AluSrc=1;
            RegWrite=1;
        end
        4'b0100:begin                   //Branch if equal
            AluCtrl=4'b0001;
            AluSrc=0;
            Branch=1;
        end
        4'b0101:begin                   //Branch if not equal
            AluCtrl=4'b0001;
            AluSrc=0;
            Branch=1;
        end
        4'b0110:begin                   //Jump (absolute addr, no link)
            Jump=1;
        end

    endcase

end


endmodule
