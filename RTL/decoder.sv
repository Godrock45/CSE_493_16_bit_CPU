    module decoder(
        input [15:0] instruct,
        output reg [3:0] rd,
        output reg [3:0] rs1,
        output reg [3:0] funct4,
        output reg [15:0] imm,
        output reg [3:0] opcode,
        output reg [11:0] addr
    );
    reg t;
    always_comb begin
        rd=4'b0;
        rs1=4'b0;
        funct4=4'b0;
        opcode=instruct[15:12];
        t=|opcode;
        imm=16'b0;
        addr=12'b0;
        case(t)
            0: begin
                rd=instruct[11:8];
                rs1=instruct[7:4];
                funct4=instruct[3:0];
            end
            1:begin
                if(opcode==4'b0110) begin       //jmp
                    addr=instruct[11:0];
                end
                else begin
                    rd=instruct[11:8];
                    rs1=instruct[7:4];
                    imm=instruct[3:0];
                end
            end
        endcase

    end


    endmodule