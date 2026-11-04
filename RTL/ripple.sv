module rip (
    input  OpA,
    input  OpB,
    input cin,
    output sum,
    output cout
);

assign cout= (OpA&OpB)|(OpA&cin)|(OpB&cin);
assign sum=OpA^OpB^cin;

endmodule

module ripple(
    input [15:0]A,
    input [15:0]B,
    input c_in,
    output reg c_out,
    output reg [15:0]sum
);
reg Opa,Opb,Opin,Op_out,Op_sum;
always_comb begin
    for(int i=0;i<15i++)begin
        Oa=A[i];
        Ob=B[i];
        Oin=(i==0)?c_in:Op_out;
        sum[i]=Op_sum[i];
        c_out=(i==15)?Op_out:0;
    end
end
rip(.OpA(Opa),.OpB(Opb),.cin(Opin),.sum(Op_sum),.cout(Op_out));

endmodule