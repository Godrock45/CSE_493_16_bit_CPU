module top_wire(
    input clk,
    input rst,
    //debug assist
    output logic [15:0] dbg_pc,
    output logic [15:0] dbg_instr,
    output logic dbg_reg_we,
    output logic [3:0] dbg_rd,
    output logic [15:0] dbg_wb_data,
    output logic halt
    );



    logic [15:0] next_PC_loc,PC_loc,PC_plus1_loc;
    logic [15:0] IR_loc;
    logic pc_en_loc;
    logic [3:0] rd_loc;
    logic [3:0] rs1_loc;
    logic [3:0] funct4_loc;
    logic [15:0] imm_loc;
    logic [3:0] opcode_loc;
    logic [11:0] jal_addr_loc;
    logic [15:0] br_tgt_loc;
    logic RegWrite_loc;
    logic AluSrc_loc;
    logic MemRead_loc;
    logic MemWrite_loc;
    logic [3:0] AluCtrl_loc;
    logic Branch_loc;
    logic Jump_loc;
    logic AluSrcA_loc;
    logic MemToReg_loc;
    logic [15:0] wd_loc;
    logic [15:0] rd1_loc;
    logic [15:0] rd2_loc;
    logic zero_loc;
    logic take_loc;
    logic [15:0] res_loc;
    logic [15:0] mem_dat_loc;
    logic [15:0] addr_loc;
    logic [15:0] dat_loc;
    logic [15:0] OpA_loc,OpB_loc;



    PrgCo ad(.clk(clk),.rst(rst),.pc_en(pc_en_loc),.next_pc(next_PC_loc),.pc(PC_loc));
    ROME dc(.PC(PC_loc),.IR(IR_loc));
    decoder tnt(.instruct(IR_loc),.rd(rd_loc),.rs1(rs1_loc),.funct4(funct4_loc),.imm(imm_loc),.opcode(opcode_loc),.addr(jal_addr_loc));
    control pnp(.Opcode(opcode_loc),.funct4(funct4_loc),.RegWrite(RegWrite_loc),.AluSrc(AluSrc_loc),.MemRead(MemRead_loc),.MemWrite(MemWrite_loc),.AluCtrl(AluCtrl_loc),.Branch(Branch_loc),.Jump(Jump_loc),.AluSrcA(AluSrcA_loc),.MemToReg(MemToReg_loc));
    registers npn(.clk(clk),.rst(rst),.we(RegWrite_loc),.rs1(rs1_loc),.rs2(rd_loc),.rd(rd_loc),.wd(wd_loc),.rd1(rd1_loc),.rd2(rd2_loc));
    ALU tsmc(.OpA(OpA_loc),.OpB(OpB_loc),.ALUCtrl(AluCtrl_loc),.Res(res_loc));
    memory meme(.clk(clk),.addr(addr_loc),.dat(dat_loc),.write_ena(MemWrite_loc),.mem_dat(mem_dat_loc));



    assign pc_en_loc=1'b1;
    assign PC_plus1_loc=PC_loc+16'd1;
    assign OpA_loc=AluSrcA_loc?PC_loc:rd1_loc;
    assign OpB_loc=AluSrc_loc?imm_loc:rd2_loc;
    assign zero_loc=(res_loc==16'd0);
    assign take_loc=Branch_loc&(zero_loc^opcode_loc[0]);     //BEQ=0100 BNE=0101, opcode[0] flips the condition
    assign br_tgt_loc=PC_loc+{{12{imm_loc[3]}},imm_loc[3:0]};  //ALU is busy comparing, so branches get their own adder
    assign next_PC_loc=Jump_loc?{4'b0,jal_addr_loc}:take_loc?br_tgt_loc:PC_plus1_loc;
    assign addr_loc=res_loc;
    assign dat_loc=rd2_loc;
    assign wd_loc=MemToReg_loc?mem_dat_loc:Jump_loc?PC_plus1_loc:res_loc;

    assign dbg_pc=PC_loc;
    assign dbg_instr=IR_loc;
    assign dbg_reg_we=RegWrite_loc;
    assign dbg_rd=rd_loc;
    assign dbg_wb_data=wd_loc;
    assign halt=(next_PC_loc==PC_loc);      //jump-to-self



endmodule
