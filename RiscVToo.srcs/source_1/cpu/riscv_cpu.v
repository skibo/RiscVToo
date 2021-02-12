`timescale 1ns / 1ps
//
// Copyright (c) 2016 Thomas Skibo. <Thomas@Skibo.net>
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

module riscv_cpu #(parameter DWIDTH = 32,
                   parameter AWIDTH = 32,
                   parameter [31 : 0] MTVEC = 32'h0000_01c0,
                   parameter [31 : 0] RSTVEC = 32'h0000_0200,
                   parameter [7 : 0] HART_ID = 8'h00)
    (output [AWIDTH - 1 : 0]       i_addr,
     output                        i_addr_valid,
     input [31 : 0]                i_data,
     input                         i_data_valid,
     input                         i_fault,

     output [AWIDTH - 1 : 0]       d_addr,
     output                        d_addr_valid,
     input [DWIDTH - 1 : 0]        d_data_rd,
     input                         d_data_rd_valid,
     output [DWIDTH - 1 : 0]       d_data_wr,
     output                        d_we,
     output [(DWIDTH / 8) - 1 : 0] d_be,
     input                         d_wr_done,
     input                         d_fault,

     input                         timerint,
     input                         extirq,

     input                         reset,
     input                         clk);


    wire [1 : 0]                       csr_op;
    wire [11 : 0]                      csr_reg;
    wire [DWIDTH - 1 : 0]              csr_wr_data;
    wire [DWIDTH - 1 : 0]              csr_rd_data;

    wire                               inc_instret;
    wire                               do_exception;
    wire                               do_mret;
    wire                               interrupt;
    wire [3 : 0]                       exc_reason;
    wire [AWIDTH - 1 : 0]              badaddr;
    wire                               badaddr_set;
    wire                               exc_intr;
    wire [AWIDTH - 1 : 0]              exc_pc;
    wire [AWIDTH - 1 : 0]              mret_pc;
    wire [AWIDTH - 1 : 0]              mtvec;

    riscv_core #(.AWIDTH(AWIDTH),
                 .DWIDTH(DWIDTH),
                 .RSTVEC(RSTVEC))
    riscv_core_0(
                 .i_addr(i_addr),
                 .i_addr_valid(i_addr_valid),
                 .i_data(i_data),
                 .i_data_valid(i_data_valid),
                 .i_fault(i_fault),

                 .d_addr(d_addr),
                 .d_addr_valid(d_addr_valid),
                 .d_data_rd(d_data_rd),
                 .d_data_rd_valid(d_data_rd_valid),
                 .d_data_wr(d_data_wr),
                 .d_we(d_we),
                 .d_be(d_be),
                 .d_wr_done(d_wr_done),
                 .d_fault(d_fault),

                 .csr_op(csr_op),
                 .csr_reg(csr_reg),
                 .csr_wr_data(csr_wr_data),
                 .csr_rd_data(csr_rd_data),

                 .inc_instret(inc_instret),
                 .do_exception(do_exception),
                 .exc_reason(exc_reason),
                 .badaddr(badaddr),
                 .badaddr_set(badaddr_set),
                 .exc_intr(exc_intr),
                 .exc_pc(exc_pc),
                 .do_mret(do_mret),
                 .mret_pc(mret_pc),
                 .mtvec(mtvec),
                 .interrupt(interrupt),

                 .reset(reset),
                 .clk(clk)
            );

    riscv_csr #(.DWIDTH(DWIDTH),
                .AWIDTH(AWIDTH),
                .MTVEC(MTVEC),
                .HART_ID(HART_ID))
    riscv_csr_0(
                .csr_op(csr_op),
                .csr_reg(csr_reg),
                .csr_wr_data(csr_wr_data),
                .csr_rd_data(csr_rd_data),

                .inc_instret(inc_instret),
                .do_exception(do_exception),
                .exc_reason(exc_reason),
                .badaddr(badaddr),
                .badaddr_set(badaddr_set),
                .exc_intr(exc_intr),
                .exc_pc(exc_pc),
                .mtvec(mtvec),
                .do_mret(do_mret),
                .interrupt(interrupt),
                .timerint(timerint),
                .extirq(extirq),
                .mret_pc(mret_pc),

                .reset(reset),
                .clk(clk)
          );

endmodule // riscv_cpu
