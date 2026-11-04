module memory(
    input clk,
    input [15:0]addr,
    input [15:0]dat,
    input write_ena,
    output logic [15:0]mem_dat
);
reg [15:0] memistan [127:0];
always_comb begin
    mem_dat=memistan[addr[6:0]];
end

always_ff @(posedge clk) begin
    if(write_ena) begin
        memistan[addr[6:0]]=dat;
    end
end

endmodule