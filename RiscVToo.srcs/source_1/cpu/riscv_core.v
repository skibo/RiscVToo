`timescale 1ns / 1ps
//
// Copyright (c) 2016-2019 Thomas Skibo. <Thomas@Skibo.net>
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//

module riscv_core #(parameter DWIDTH = 32,
                    parameter AWIDTH = 32,
                    parameter [31 : 0] RSTVEC = 32'h0000_0200)
    (output [AWIDTH - 1 : 0]           i_addr,
     output                            i_addr_valid,
     input [31 : 0]                    i_data,
     input                             i_data_valid,
     input                             i_fault,

     output [AWIDTH - 1 : 0]           d_addr,
     output                            d_addr_valid,
     input [DWIDTH - 1 : 0]            d_data_rd,
     input                             d_data_rd_valid,
     output reg [DWIDTH - 1 : 0]       d_data_wr,
     output                            d_we,
     output reg [(DWIDTH / 8) - 1 : 0] d_be,
     input                             d_wr_done,
     input                             d_fault,

     output [1 : 0]                    csr_op,
     output [11 : 0]                   csr_reg,
     output [31 : 0]                   csr_wr_data,
     input [31 : 0]                    csr_rd_data,
     output reg                        inc_instret,
     output                            do_exception,
     output reg [3 : 0]                exc_reason,
     output reg [AWIDTH - 1 : 0]       badaddr,
     output                            badaddr_set,
     output reg                        exc_intr,
     output reg [AWIDTH - 1 : 0]       exc_pc,
     output                            do_mret,
     input                             interrupt,
     input [AWIDTH - 1 : 0]            mret_pc,
     input [AWIDTH - 1 : 0]            mtvec,

     input                             reset,
     input                             clk);


    localparam [6 : 0]
        // Opcode field in bits 6 : 0 in instruction.
        OP_LUI =    7'b0110111,
        OP_AUIPC =  7'b0010111,
        OP_JAL =    7'b1101111,
        OP_JALR =   7'b1100111,
        OP_BR =     7'b1100011,
        OP_LOAD =   7'b0000011,
        OP_STORE =  7'b0100011,
        OP_ALUI =   7'b0010011,
        OP_ALUR =   7'b0110011,
        OP_FENCE =  7'b0001111,
        OP_SYS =    7'b1110011;

    localparam [2 : 0]
        // ALU funct3, bits 14 : 12 in ALU instructions
        ALU_ADD_SUB =   3'b000,
        ALU_SLL =       3'b001,
        ALU_SLT =       3'b010,
        ALU_SLTU =      3'b011,
        ALU_XOR =       3'b100,
        ALU_SRA_SRL =   3'b101,
        ALU_OR =        3'b110,
        ALU_AND =       3'b111;

    localparam [2 : 0]
        // Condition branch funct3, bits 14 : 12 in BR instructions
        BR_EQ =     3'b000,
        BR_NE =     3'b001,
        BR_LT =     3'b100,
        BR_GE =     3'b101,
        BR_LTU =    3'b110,
        BR_GEU =    3'b111;

    localparam [2 : 0]
        // Load width funct3, bits 14 : 12 in LOAD instructions
        LD_B =      3'b000,
        LD_H =      3'b001,
        LD_W =      3'b010,
        LD_BU =     3'b100,
        LD_HU =     3'b101,
        // Store width funct3, bits 14 : 12 in STORE instructions
        ST_B =      3'b000,
        ST_H =      3'b001,
        ST_W =      3'b010;

    localparam [31 : 0]
        // System instructions
        ECALL_INSTR =    32'h0000_0073,
        EBREAK_INSTR =   32'h0010_0073,
        MRET_INSTR =     32'h3020_0073,
        WFI_INSTR =      32'h1050_0073;

    localparam [3 : 0]
        // Exception Reasons
        EXC_INSTR_ADDR_MISALIGNED = 4'd0,
        EXC_INSTR_FAULT =           4'd1,
        EXC_ILLEGAL_INSTR =         4'd2,
        EXC_BREAKPOINT =            4'd3,
        EXC_LOAD_ADDR_MISALIGNED =  4'd4,
        EXC_LOAD_FAULT =            4'd5,
        EXC_STORE_ADDR_MISALIGNED = 4'd6,
        EXC_STORE_FAULT =           4'd7,
        EXC_CALL_M =                4'd11;

    // Fetch
    reg [AWIDTH - 1 : 0]        pc;
    reg                         i_fault_1;
    reg                         i_active;
    wire                        i_stall;

    // Decode Stage
    wire                        instr_d_valid;
    wire                        instr_d_ill;
    reg                         squash_d;
    wire [4 : 0]                a_reg_num_d;
    wire [4 : 0]                b_reg_num_d;
    wire [DWIDTH - 1 : 0]       a_regf_rd;
    wire [DWIDTH - 1 : 0]       b_regf_rd;
    reg [AWIDTH - 1 : 0]        pc_d;

    // Execute Stage
    reg [DWIDTH - 1 : 0]        a_reg_r;
    reg [DWIDTH - 1 : 0]        b_reg_r;
    reg [31 : 0]                instr_e;
    reg                         instr_e_valid;
    reg                         instr_e_ill;
    reg [AWIDTH - 1 : 0]        pc_e;
    wire                        w_reg_en_e;
    reg [DWIDTH - 1 : 0]        w_reg_data_e;
    wire [4 : 0]                w_reg_num_e;
    reg                         do_branch;
    reg [AWIDTH - 1 : 0]        br_target;
    wire                        load_e;
    wire                        store_e;
    wire                        csr_e;
    wire                        load_unaligned;
    wire                        store_unaligned;
    wire                        br_unaligned;
    reg                         wfi;

    // Memory Stage
    reg [DWIDTH - 1 : 0]        load_data;
    reg                         load_m;
    reg                         loading;
    reg                         storing;
    reg [AWIDTH - 1 : 0]        pc_m;
    reg                         csr_m;
    wire                        mem_stall;
    reg                         load_hazard_a_em;
    reg                         load_hazard_b_em;
    wire                        load_bubble;
    reg [2 : 0]                 load_width_r1;
    reg [AWIDTH - 1 : 0]        d_byte_addr_m;
    reg                         d_fault_l;
    reg                         d_fault_s;
    reg                         w_reg_en_m;
    reg [DWIDTH - 1 : 0]        w_reg_data_em;
    wire [DWIDTH - 1 : 0]       w_reg_data_m;
    reg [4 : 0]                 w_reg_num_m;
    ////////////////////////// Stalls ///////////////////////////

    wire                        stall = mem_stall || wfi || load_bubble;

    ///////////////////////// I-Fetch ///////////////////////////

    // PC register
    always @(posedge clk)
        if (reset)
            pc <= RSTVEC;
        else if (!stall) begin
            if (do_exception)
                pc <= mtvec;
            else if (do_branch)
                pc <= {br_target[AWIDTH - 1 : 2] + i_data_valid, 2'b00};
            else if (i_data_valid)
                pc <= pc + 3'd4;
        end

    always @(posedge clk)
        if (reset || (!i_addr_valid && i_data_valid) || i_fault)
            i_active <= 0;
        else if (i_addr_valid)
            i_active <= 1;

    assign i_stall = i_active && !i_data_valid && !i_fault;

    assign i_addr_valid = !stall && !i_stall && !reset;
    assign i_addr = do_exception ? mtvec :
                    (do_branch ? {br_target[AWIDTH - 1 : 2], 2'b00} : pc);

    // Allow last instruction before i_fault to get through EX stage.
    always @(posedge clk)
        if (reset)
            i_fault_1 <= 0;
        else if (!stall)
            i_fault_1 <= i_fault && !i_fault_1;

    ///////////////////////// Decode / Reg Rd ////////////////////

    assign  instr_d_valid = i_data_valid && !do_branch && !do_exception &&
                            !squash_d;

    always @(posedge clk)
        if (reset || (i_data_valid && !stall))
            squash_d <= 0;
        else if ((do_branch || do_exception) && !stall && !i_data_valid)
            squash_d <= 1;

    assign  a_reg_num_d = i_data[19 : 15];
    assign  b_reg_num_d = i_data[24 : 20];

    riscv_reg_file #(.DWIDTH(DWIDTH))
        regfile(.a_reg_data(a_regf_rd),
                .b_reg_data(b_regf_rd),
                .a_reg_num(a_reg_num_d),
                .b_reg_num(b_reg_num_d),
                .w_reg_num(w_reg_num_m),
                .w_reg_data(w_reg_data_m),
                .w_reg_en(w_reg_en_m),
                .clk(clk)
            );

    always @(posedge clk)
        if (i_addr_valid)
            pc_d <= i_addr;

    // Short-circuit logic.
    wire    bypass_a32 = w_reg_en_e && instr_d_valid &&
                w_reg_num_e == a_reg_num_d;
    wire    bypass_b32 = w_reg_en_e && instr_d_valid &&
            w_reg_num_e == b_reg_num_d;
    wire    bypass_a42 = w_reg_en_m && instr_d_valid &&
            w_reg_num_m == a_reg_num_d;
    wire    bypass_b42 = w_reg_en_m && instr_d_valid &&
                w_reg_num_m == b_reg_num_d;

    always @(posedge clk) begin
        if (!stall) begin
            if (bypass_a32)
                a_reg_r <= w_reg_data_e;
            else if (bypass_a42)
                a_reg_r <= w_reg_data_m;
            else
                a_reg_r <= a_regf_rd;

            if (bypass_b32)
                b_reg_r <= w_reg_data_e;
            else if (bypass_b42)
                b_reg_r <= w_reg_data_m;
            else
                b_reg_r <= b_regf_rd;
        end
        if (load_hazard_a_em)
            a_reg_r <= w_reg_data_m;
        if (load_hazard_b_em)
            b_reg_r <= w_reg_data_m;
    end

    assign instr_d_ill = instr_d_valid &&
                         i_data[6 : 0] != OP_LUI &&
                         i_data[6 : 0] != OP_AUIPC &&
                         i_data[6 : 0] != OP_JAL &&
                         i_data[6 : 0] != OP_JALR &&
                         i_data[6 : 0] != OP_BR &&
                         i_data[6 : 0] != OP_LOAD &&
                         i_data[6 : 0] != OP_STORE &&
                         i_data[6 : 0] != OP_ALUI &&
                         {i_data[25], i_data[6 : 0]} !=
                         {1'b0, OP_ALUR} &&
                         i_data[6 : 0] != OP_FENCE &&
                         i_data[6 : 0] != OP_SYS;

    ////////////////////// Exec Stage //////////////////////////

    always @(posedge clk)
        if (!stall)
            pc_e <= pc_d;

    always @(posedge clk)
        if (!stall)
            instr_e <= i_data;

    always @(posedge clk)
        if (reset)
            instr_e_valid <= 0;
        else if (!stall)
            instr_e_valid <= instr_d_valid && !instr_d_ill;

    always @(posedge clk)
        if (reset)
            instr_e_ill <= 0;
        else if (!stall)
            instr_e_ill <= instr_d_ill;

    // Register this to improve timing.  instret is a 64-bit counter.
    always @(posedge clk)
        if (reset)
            inc_instret <= 0;
        else
            inc_instret <= !stall && instr_e_valid;

    // ALU:
    reg [DWIDTH - 1 : 0]     alu_result;
    wire [DWIDTH - 1 : 0]        b_operand = instr_e[5] ?
        b_reg_r : {{(DWIDTH - 12){instr_e[31]}}, instr_e[31 : 20]};

    always @(*)
        case (instr_e[14 : 12])
            ALU_ADD_SUB:
                if (instr_e[30] && instr_e[5])
                    alu_result = $signed(a_reg_r) - $signed(b_operand);
                else
                    alu_result = $signed(a_reg_r) + $signed(b_operand);
            ALU_SLL:
                alu_result = a_reg_r << b_operand[4 : 0];
            ALU_SLT:
                alu_result = ($signed(a_reg_r) < $signed(b_operand)) ?
                             'd1 : 'd0;
            ALU_SLTU:
                alu_result = (a_reg_r < b_operand) ? 'd1 : 'd0;
            ALU_XOR:
                alu_result = a_reg_r ^ b_operand;
            ALU_SRA_SRL:
                if (instr_e[30])
                    alu_result = $signed(a_reg_r) >>> b_operand[4 : 0];
                else
                    alu_result = a_reg_r >> b_operand[4 : 0];
            ALU_OR:
                alu_result = a_reg_r | b_operand;
            ALU_AND:
                alu_result = a_reg_r & b_operand;
        endcase

    // Register write-back logic and mux.  w_reg_en_e means the instruction
    // in execute stage has a destination register.  XXX: we could this in
    // the decode stage.
    assign  w_reg_en_e = instr_e_valid && w_reg_num_e != 5'd0 &&
                             (instr_e[6 : 0] == OP_LUI ||
                              instr_e[6 : 0] == OP_AUIPC ||
                              instr_e[6 : 0] == OP_JAL ||
                              instr_e[6 : 0] == OP_JALR ||
                              instr_e[6 : 0] == OP_ALUI ||
                              instr_e[6 : 0] == OP_ALUR ||
                              instr_e[6 : 0] == OP_LOAD ||
                              csr_e);

    assign w_reg_num_e = instr_e[11 : 7];

    always @(*)
        case (instr_e[6 : 0])
            OP_ALUI, OP_ALUR:
                w_reg_data_e = alu_result;
            OP_JAL, OP_JALR:
                w_reg_data_e = pc_e + 3'd4;
            OP_LUI:
                w_reg_data_e = {instr_e[31 : 12], 12'd0};
            OP_AUIPC:
                w_reg_data_e = pc_e + {instr_e[31 : 12], 12'd0};
            default:
                w_reg_data_e = 32'hXXXX_XXXX;
        endcase

    // Load/Store addresses, control
    wire [AWIDTH - 1 : 0] d_byte_addr = a_reg_r +
                          {{(AWIDTH - 12){instr_e[31]}},
                           (instr_e[5] ?
                            {instr_e[31 : 25], instr_e[11 : 7]} : // Store
                            instr_e[31 : 20])}; // Load
    assign d_addr = {d_byte_addr[AWIDTH - 1 : 2], 2'b00};
    assign d_we = !stall && instr_e_valid && instr_e[6 : 0] == OP_STORE;

    assign d_addr_valid = !stall && instr_e_valid &&
                          (instr_e[6 : 0] == OP_STORE ||
                           instr_e[6 : 0] == OP_LOAD);

    assign load_e = instr_e_valid && instr_e[6 : 0] == OP_LOAD;
    assign store_e = instr_e_valid && instr_e[6 : 0] == OP_STORE;

    assign load_unaligned = load_e && !stall &&
         ((instr_e[14 : 12] == LD_W && d_byte_addr[1 : 0] != 2'b00) ||
          ((instr_e[14 : 12] ==  LD_H || instr_e[14 : 12] == LD_HU) &&
           d_byte_addr[0] != 1'b0));

    assign store_unaligned = store_e && !stall &&
         ((instr_e[14 : 12] == ST_W && d_byte_addr[1 : 0] != 2'b00) ||
          (instr_e[14 : 12] == ST_H && d_byte_addr[0] != 1'b0));


    // Byte-enables and write data.  XXX: hard-coded 32-bit.
    always @(*)
        case (instr_e[14 : 12])
            ST_B: begin
                d_be = 4'b0001 << d_byte_addr[1:0];
                d_data_wr = {b_reg_r[7 : 0], b_reg_r[7 : 0],
                             b_reg_r[7 : 0], b_reg_r[7 : 0]};
            end
            ST_H: begin
                d_be = d_byte_addr[1] ? 4'b1100 : 4'b0011;
                d_data_wr = {b_reg_r[15 : 0], b_reg_r[15 : 0]};
            end
            ST_W: begin
                d_be = 4'b1111;
                d_data_wr = b_reg_r;
            end
            default: begin
                d_be = 4'b0000;
                d_data_wr = 32'hXXXX_XXXX;
            end
        endcase

    // Branch target:
    always @(*) begin
        case (instr_e[6 : 0])
            OP_JAL:
                br_target = pc_e +
                            {{(AWIDTH - 19){instr_e[31]}},
                             instr_e[31],
                             instr_e[19 : 12],
                             instr_e[20],
                             instr_e[30 : 21], 1'b0};
            OP_JALR: begin
                br_target = a_reg_r +
                            {{(AWIDTH - 12){instr_e[31]}},
                             instr_e[31 : 20]};
                br_target[0] = 1'b0;
            end
            OP_BR:
                br_target = pc_e +
                            {{(AWIDTH - 13){instr_e[31]}},
                             instr_e[31],
                             instr_e[7],
                             instr_e[30 : 25],
                             instr_e[11 : 8], 1'b0};
            OP_SYS:
                br_target = mret_pc; // MRET
            default:
                br_target = {AWIDTH{1'bX}};
        endcase
    end

    always @(*)
        if (instr_e_valid)
            case (instr_e[6 : 0])
                OP_BR:
                    // Condition branch tests
                    case (instr_e[14 : 12])
                        BR_EQ:
                            do_branch = a_reg_r == b_reg_r;
                        BR_NE:
                            do_branch = a_reg_r != b_reg_r;
                        BR_LT:
                            do_branch = $signed(a_reg_r) < $signed(b_reg_r);
                        BR_GE:
                            do_branch = $signed(a_reg_r) >= $signed(b_reg_r);
                        BR_LTU:
                            do_branch = a_reg_r < b_reg_r;
                        BR_GEU:
                            do_branch = a_reg_r >= b_reg_r;
                        default:
                            do_branch = 0;
                    endcase
                OP_JAL, OP_JALR:
                    do_branch = 1;
                OP_SYS:
                    do_branch = instr_e == MRET_INSTR;
                default:
                    do_branch = 0;
            endcase
        else
            do_branch = 0;

    assign do_mret = instr_e_valid && !stall && instr_e == MRET_INSTR;

    assign br_unaligned = do_branch && br_target[1 : 0] != 2'b00;

    // CSR Access instructions.
    assign csr_e = instr_e_valid && instr_e[6 : 0] == OP_SYS &&
                   instr_e[14 : 12] != 3'b000;

    assign csr_op = (csr_e && !stall) ? instr_e[13 : 12] : 2'b00;
    assign csr_wr_data = instr_e[14] ?
                         {{DWIDTH - 5{1'b0}}, instr_e[19 : 15]} : a_reg_r;
    assign csr_reg = instr_e[31 : 20];

    ///////////////////////// Mem Stage /////////////////////////

    always @(posedge clk)
        if (!stall)
            pc_m <= pc_e;

    always @(posedge clk)
        if (reset || (stall && load_m && d_data_rd_valid))
            w_reg_en_m <= 0;
        else if (!stall)
            w_reg_en_m <= w_reg_en_e;

    always @(posedge clk)
        if (!stall) begin
            w_reg_num_m <= w_reg_num_e;
            w_reg_data_em <= w_reg_data_e;
            load_width_r1 <= instr_e[14 : 12];
            d_byte_addr_m <= d_byte_addr;
        end

    always @(posedge clk)
        if (reset) begin
            load_m <= 0;
            csr_m <= 0;
        end
        else if (!stall) begin
            load_m <= load_e;
            csr_m <= csr_e;
        end

    // Set when load comes into M stage, cleared when data valid.
    always @(posedge clk)
        if (reset || ((d_data_rd_valid || d_fault) && !(load_e && !stall)))
            loading <= 0;
        else if (!stall && load_e)
            loading <= 1;

    // Set when store comes into M stage, cleared when write done.
    always @(posedge clk)
        if (reset || ((d_wr_done || d_fault) && !(store_e && !stall)))
            storing <= 0;
        else if (!stall && store_e)
            storing <= 1;

    assign mem_stall = (loading && !d_data_rd_valid) ||
                       (storing && !d_wr_done);


    always @(*)
        case (load_width_r1)
            LD_B: begin
                load_data[7 : 0] = d_data_rd >>
                                   {d_byte_addr_m[1 : 0], 3'b000};
                load_data[31 : 8] = {24{load_data[7]}};
            end
            LD_H: begin
                load_data[15 : 0] = d_data_rd >>
                                    {d_byte_addr_m[1], 4'b0000};
                load_data[31 : 16] = {16{load_data[15]}};
            end
            LD_W:
                load_data = d_data_rd;
            LD_BU: begin
                load_data[7 : 0] = d_data_rd >>
                                   {d_byte_addr_m[1 : 0], 3'b000};
                load_data[31 : 8] = 24'd0;
            end
            LD_HU: begin
                load_data[15 : 0] = d_data_rd >>
                                    {d_byte_addr_m[1], 4'b0000};
                load_data[31 : 16] = 16'd0;
            end
            default:
                load_data = {32{1'bx}};
        endcase


    assign w_reg_data_m = csr_m ? csr_rd_data :
                          (load_m ? load_data : w_reg_data_em);

    // A load hazard happens when the execution stage is starting a load
    // and the decode stage has an instruction that uses the register that
    // we are starting to load from memory.  CSR access instructions use
    // this infrastructure too because the CSR block returns its data
    // in the mem stage.
    wire load_hazard_a_de = instr_e_valid &&
         (instr_e[6 : 0] == OP_LOAD || csr_e) &&
         instr_d_valid && w_reg_num_e == a_reg_num_d &&
         w_reg_num_e != 5'd0 &&
         (i_data[6 : 0] == OP_JALR ||
          i_data[6 : 0] == OP_BR ||
          i_data[6 : 0] == OP_LOAD ||
          i_data[6 : 0] == OP_STORE ||
          i_data[6 : 0] == OP_ALUI ||
          i_data[6 : 0] == OP_ALUR ||
          (i_data[6 : 0] == OP_SYS && !i_data[14] &&
           i_data[13 : 12] != 2'b00));
    wire load_hazard_b_de = instr_e_valid &&
         (instr_e[6 : 0] == OP_LOAD || csr_e) &&
         instr_d_valid && w_reg_num_e == b_reg_num_d &&
         w_reg_num_e != 5'd0 &&
         (i_data[6 : 0] == OP_BR ||
          i_data[6 : 0] == OP_STORE ||
          i_data[6 : 0] == OP_ALUR);

    always @(posedge clk)
        if (reset || (d_data_rd_valid || d_fault || csr_m) && load_hazard_a_em)
            load_hazard_a_em <= 0;
        else if (!stall && load_hazard_a_de)
            load_hazard_a_em <= 1;

    always @(posedge clk)
        if (reset || (d_data_rd_valid || d_fault || csr_m) && load_hazard_b_em)
            load_hazard_b_em <= 0;
        else if (!stall && load_hazard_b_de)
            load_hazard_b_em <= 1;

    assign load_bubble = load_hazard_a_em || load_hazard_b_em;

    //////////////// Exception Handling /////////////////

    always @(posedge clk)
        if (reset || (do_exception && !stall))
            d_fault_l <= 0;
        else if (d_fault && loading)
            d_fault_l <= 1;

    always @(posedge clk)
        if (reset || (do_exception && !stall))
            d_fault_s <= 0;
        else if (d_fault && storing)
            d_fault_s <= 1;

    wire ecall_e = instr_e_valid && instr_e == ECALL_INSTR && !stall;
    wire ebreak_e = instr_e_valid && instr_e == EBREAK_INSTR && !stall;

    assign do_exception = !stall && (ecall_e || ebreak_e || instr_e_ill ||
                                     load_unaligned || store_unaligned ||
                                     br_unaligned || i_fault_1 ||
                                     d_fault_l || d_fault_s || interrupt);

    // Implement priority coding of exceptions.  Determine what EPC
    // should be.  CSR block captures these.
    always @(*) begin
        exc_intr = 0;
        exc_reason = 4'hf; // XXX: no default non-reason?
        exc_pc = pc_e;

        if (br_unaligned)
            exc_reason = EXC_INSTR_ADDR_MISALIGNED;
        else if (load_unaligned)
            exc_reason = EXC_LOAD_ADDR_MISALIGNED;
        else if (store_unaligned)
            exc_reason = EXC_STORE_ADDR_MISALIGNED;
        else if (d_fault_l) begin
            exc_reason = EXC_LOAD_FAULT;
            exc_pc = pc_m;
        end
        else if (d_fault_s) begin
            exc_reason = EXC_STORE_FAULT;
            exc_pc = pc_m;
        end
        else if (i_fault_1) begin
            exc_reason = EXC_INSTR_FAULT;
            exc_pc = pc_e;
        end
        else if (instr_e_ill)
            exc_reason = EXC_ILLEGAL_INSTR;
        else if (interrupt) begin
            exc_intr = 1;
            exc_pc = do_branch ? br_target : pc_d;
        end
        else if (ecall_e)
            exc_reason = EXC_CALL_M;
        else if (ebreak_e)
            exc_reason = EXC_BREAKPOINT;
    end

    assign badaddr_set = br_unaligned || load_unaligned || store_unaligned ||
                         instr_e_ill || d_fault_l || d_fault_s;
    always @(*)
        if (br_unaligned)
            badaddr = br_target;
        else if (d_fault_l || d_fault_s)
            badaddr = d_byte_addr_m;
        else if (instr_e_ill)
            badaddr = instr_e;
        else
            badaddr = d_byte_addr;

    always @(posedge clk)
        if (reset || do_exception || interrupt)
            wfi <= 0;
        else if (!stall && instr_d_valid && i_data == WFI_INSTR)
            wfi <= 1;

`ifdef verbose
    always @(negedge clk)
        $display("[%t] ia=%h | idv=%b id=%h | iev=%b ie=%h | rwe=%b drv=%b",
                 $time, i_addr, instr_d_valid,
                 i_data, instr_e_valid, instr_e, w_reg_en_m, d_data_rd_valid);
`endif

endmodule // riscv_core
