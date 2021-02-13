`timescale 1ns / 1ps
//
// Copyright (c) 2016-2017 Thomas Skibo.
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

module riscv_csr #(parameter DWIDTH = 32,
                   parameter AWIDTH = 32,
                   parameter [31 : 0] MTVEC = 32'h0000_01c0,
                   parameter [7 : 0] HART_ID = 8'h00)
    (
     input [1 : 0]               csr_op,
     input [11 : 0]              csr_reg,
     input [DWIDTH - 1 : 0]      csr_wr_data,
     output reg [DWIDTH - 1 : 0] csr_rd_data,

     input                       inc_instret,
     input                       do_exception,
     input [3 : 0]               exc_reason,
     input                       exc_intr,
     input [AWIDTH - 1 : 0]      exc_pc,
     input [AWIDTH - 1 : 0]      badaddr,
     input                       badaddr_set,
     input                       do_mret,
     input                       timerint,
     input                       extirq,
     output                      interrupt,
     output [AWIDTH - 1 : 0]     mret_pc,
     output [AWIDTH - 1 : 0]     mtvec,

     input                       reset,
     input                       clk);

    localparam [11 : 0]
        // Machine Info Registers
        CSR_M_VENDORID =    12'hF11,
        CSR_M_ARCHID =      12'hF12,
        CSR_M_IMPID =       12'hF13,
        CSR_M_HARTID =      12'hF14,

        // Machine Trap Setup
        CSR_M_STATUS =      12'h300,
        CSR_M_ISA =         12'h301,
        CSR_M_EDELEG =      12'h302,
        CSR_M_IDELEG =      12'h303,
        CSR_M_IE =          12'h304,
        CSR_M_TVEC =        12'h305,
        CSR_M_COUNTEREN =   12'h306,

        // Machine Trap Handling
        CSR_M_SCRATCH =     12'h340,
        CSR_M_EPC =         12'h341,
        CSR_M_CAUSE =       12'h342,
        CSR_M_TVAL =        12'h343,
        CSR_M_IP =          12'h344,

        // Machine Timers and Counters
        CSR_M_CYCLE =       12'hB00,
        CSR_M_INSTRET =     12'hB02,
        CSR_M_CYCLEH =      12'hB80,
        CSR_M_INSTRETH =    12'hB82;

    localparam [31 : 0]
        // Value in MISA register: rv32i
        CPU_MISA =  32'h4000_0100;

    localparam [3 : 0]
        // Interrupt reasons in mcause register.
        INTR_REASON_M_SW_INTR =     4'd3,
        INTR_REASON_M_TIMER_INTR =  4'd7,
        INTR_REASON_M_EXT_INTR =    4'd11;

    // CSR "operations" (bits 13:12 of csr instructions)
    localparam [1 : 0]
        CSR_OP_NONE =   2'b00,
        CSR_OP_WR =     2'b01,
        CSR_OP_S =      2'b10,
        CSR_OP_C =      2'b11;

    reg [DWIDTH - 1 : 0]         csr_rd_data_p;

    always @(posedge clk)
        if (csr_op != CSR_OP_NONE)
            csr_rd_data <= csr_rd_data_p;

    wire    csr_mod = csr_op != CSR_OP_NONE;

    wire [DWIDTH - 1 : 0] csr_bits_set = (csr_op == CSR_OP_C ? 'd0 :
                                          csr_wr_data);
    wire [DWIDTH - 1 : 0] csr_bits_clr = (csr_op == CSR_OP_WR ? ~csr_wr_data :
                                          (csr_op == CSR_OP_S ? 'd0 :
                                           csr_wr_data));


    // RDCYCLE registers
    reg [DWIDTH - 1 : 0]         cycle_reg;
    reg [DWIDTH - 1 : 0]         cycleh_reg;
    reg                          cycle_c;

    always @(posedge clk)
        if (reset)
            cycle_reg <= 'd0;
        else if (csr_mod && csr_reg == CSR_M_CYCLE)
            cycle_reg <= ((cycle_reg + 1'b1) & ~csr_bits_clr) | csr_bits_set;
        else
            cycle_reg <= cycle_reg + 1'b1;

    always @(posedge clk)
        if (reset)
            cycle_c <= 0;
        else
            cycle_c <= cycle_reg == {DWIDTH{1'b1}};

    always @(posedge clk)
        if (reset)
            cycleh_reg <= 'd0;
        else if (csr_mod && csr_reg == CSR_M_CYCLEH)
            cycleh_reg <= ((cycleh_reg + cycle_c) & ~csr_bits_clr) |
                          csr_bits_set;
        else
            cycleh_reg <= cycleh_reg + cycle_c;

    // RDINSTRET registers
    reg [DWIDTH - 1 : 0]         instret_reg;
    reg [DWIDTH - 1 : 0]         instreth_reg;
    reg                          instret_c;

    always @(posedge clk)
        if (reset)
            instret_reg <= 'd0;
        else if (csr_mod && csr_reg == CSR_M_INSTRET)
            instret_reg <= ((instret_reg + inc_instret) & ~csr_bits_clr) |
                           csr_bits_set;
        else
            instret_reg <= instret_reg + inc_instret;

    always @(posedge clk)
        if (reset)
            instret_c <= 0;
        else
            instret_c <= inc_instret && instret_reg == {DWIDTH{1'b1}};

    always @(posedge clk)
        if (reset)
            instreth_reg <= 'd0;
        else if (csr_mod && csr_reg == CSR_M_INSTRETH)
            instreth_reg <= ((instreth_reg + instret_c) & ~csr_bits_clr) |
                            csr_bits_set;
        else
            instreth_reg <= instreth_reg + instret_c;

    // MSCRATCH register
    reg [DWIDTH - 1 : 0]         mscratch_reg;
    always @(posedge clk)
        if (reset)
            mscratch_reg <= 'd0;
        else if (csr_mod && csr_reg == CSR_M_SCRATCH)
            mscratch_reg <= (mscratch_reg & ~csr_bits_clr) | csr_bits_set;

    // MSTATUS register
    reg                          mie;
    reg                          mpie;
    wire [DWIDTH - 1 : 0]        mstatus_reg = {{(DWIDTH - 13){1'b0}},
                                                5'b11_000,
                                                mpie, 3'b000,
                                                mie, 3'b000};
    always @(posedge clk)
        if (reset || do_exception)
            mie <= 0;
        else if (do_mret)
            mie <= mpie;
        else if (csr_mod && csr_reg == CSR_M_STATUS)
            mie <= (mie && !csr_bits_clr[3]) || csr_bits_set[3];

    always @(posedge clk)
        if (reset)
            mpie <= 0;
        else if (do_exception)
            mpie <= mie;
        else if (csr_mod && csr_reg == CSR_M_STATUS)
            mpie <= (mpie && !csr_bits_clr[7]) || csr_bits_set[7];

    // MIE register
    reg                 meie; // External Interrupt Enable
    reg                 mtie; // Timer Interrupt Enable
    reg                 msie; // Software Interrupt Enable
    wire [DWIDTH - 1 : 0] mie_reg = {{(DWIDTH - 12){1'b0}},
                                     meie, 3'b000, mtie, 3'b000, msie, 3'b000};
    always @(posedge clk)
        if (reset) begin
            meie <= 0;
            mtie <= 0;
            msie <= 0;
        end
        else if (csr_mod && csr_reg == CSR_M_IE) begin
            meie <= (meie && !csr_bits_clr[11]) || csr_bits_set[11];
            mtie <= (mtie && !csr_bits_clr[7]) || csr_bits_set[7];
            msie <= (msie && !csr_bits_clr[3]) || csr_bits_set[3];
        end

    wire    meip = extirq;
    wire    mtip = timerint;
    reg     msip;
    wire [DWIDTH - 1 : 0] mip_reg = {{(DWIDTH - 12){1'b0}},
                                     meip, 3'b000, mtip, 3'b000, msip, 3'b000};
    always @(posedge clk)
        if (reset)
            msip <= 0;
        else if (csr_mod && csr_reg == CSR_M_IP)
            msip <= (msip && !csr_bits_clr[3]) || csr_bits_set[3];

    assign interrupt = mie && ((meie && meip) || (mtie && mtip) ||
                               (msie && msip));

    ///// MEPC
    reg [AWIDTH - 1 : 0]  mepc_reg;
    always @(posedge clk)
        if (reset)
            mepc_reg <= 'd0;
        else if (do_exception)
            mepc_reg <= exc_pc;
        else if (csr_mod && csr_reg == CSR_M_EPC)
            mepc_reg <= (mepc_reg & ~csr_bits_clr) | csr_bits_set;

    assign mret_pc = mepc_reg;

    ///// MCAUSE
    reg                   mcause_intr;
    reg [3 : 0]           mcause_exc;
    wire [DWIDTH - 1 : 0] mcause_reg = {mcause_intr, {(DWIDTH - 5){1'b0}},
                                        mcause_exc};

    reg [3 : 0]           intr_reason;
    always @(*) begin
        intr_reason = 4'hf; // XXX: no default non-reason?
        if (interrupt) begin
            if (msie && msip)
                intr_reason = INTR_REASON_M_SW_INTR;
            else if (mtie && mtip)
                intr_reason = INTR_REASON_M_TIMER_INTR;
            else if (meie && meip)
                intr_reason = INTR_REASON_M_EXT_INTR;
        end
    end

    always @(posedge clk)
        if (reset) begin
            mcause_intr <= 0;
            mcause_exc <= 'd0;
        end
        else if (do_exception) begin
            mcause_exc <= exc_intr ? intr_reason : exc_reason;
            mcause_intr <= exc_intr;
        end

    ///// MTVAL
    reg [AWIDTH - 1 : 0] mtval_reg;
    always @(posedge clk)
        if (reset)
            mtval_reg <= 'd0;
        else if (badaddr_set)
            mtval_reg <= badaddr;
        else if (csr_mod && csr_reg == CSR_M_TVAL)
            mtval_reg <= (mtval_reg & ~csr_bits_clr) | csr_bits_set;

    ///// MTVEC
    reg [AWIDTH - 3 : 0] mtvec_reg;
    assign mtvec = {mtvec_reg, 2'b00};
    always @(posedge clk)
        if (reset)
            mtvec_reg <= MTVEC[AWIDTH - 1 : 2];
        else if (csr_mod && csr_reg == CSR_M_TVEC)
            mtvec_reg <= (mtvec_reg & ~csr_bits_clr[AWIDTH - 1 : 2]) |
                         csr_bits_set[AWIDTH - 1 : 2];

    //////////////////// Read Mux /////////////////////////
    always @(*)
        case (csr_reg)
            CSR_M_CYCLE:
                csr_rd_data_p = cycle_reg;
            CSR_M_CYCLEH:
                csr_rd_data_p = cycleh_reg;
            CSR_M_INSTRET:
                csr_rd_data_p = instret_reg;
            CSR_M_INSTRETH:
                csr_rd_data_p = instreth_reg;

            CSR_M_SCRATCH:
                csr_rd_data_p = mscratch_reg;

            CSR_M_ISA:
                csr_rd_data_p = CPU_MISA;
            CSR_M_HARTID:
                csr_rd_data_p = {{DWIDTH - 8{1'b0}}, HART_ID};

            CSR_M_STATUS:
                csr_rd_data_p = mstatus_reg;
            CSR_M_IE:
                csr_rd_data_p = mie_reg;
            CSR_M_IP:
                csr_rd_data_p = mip_reg;
            CSR_M_EPC:
                csr_rd_data_p = mepc_reg;
            CSR_M_CAUSE:
                csr_rd_data_p = mcause_reg;
            CSR_M_TVAL:
                csr_rd_data_p = mtval_reg;
            CSR_M_TVEC:
                csr_rd_data_p = mtvec;

            default:
                csr_rd_data_p = 'd0;
        endcase // case (csr_reg)

endmodule // riscv_csr
