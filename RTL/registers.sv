module registers(
    input clk,
    input rst,
    input we,
    input [3:0] rs1,
    input [3:0] rs2,
    input [3:0]rd,
    input [15:0]wd,
    output logic [15:0] rd1,
    output logic [15:0] rd2
);
logic [15:0] registers[15:0];
always_comb begin
    rd1=registers[rs1];
    rd2=registers[rs2];
end

always_ff @( posedge clk ) begin
    if(rst)begin
        for(int i=0;i<=15;i++)begin
            registers[i]<=0;
        end
    end
    else if(we&&rd!=4'b0)begin
        registers[rd]<=wd;
    end
end

endmodule