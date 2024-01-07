`timescale 1ns / 1ps
//
// Copyright (c) 2018-2019 Thomas Skibo. <Thomas@Skibo.net>
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

module riscv_too_mem #(parameter integer DWIDTH = 32,
                       parameter integer MEMSIZE = 16384,
                       localparam integer AWIDTH = $clog2(MEMSIZE),
                       parameter MEM_INIT_FILE = "bootrom.mem")
    (
     input [AWIDTH - 1 : 0]       i_addr,
     input                        i_addr_valid,
     output reg [DWIDTH - 1 : 0]  i_data,

     input [AWIDTH - 1 : 0]       d_addr,
     input                        d_addr_valid,
     output reg [DWIDTH - 1 : 0]  d_data_rd,
     input [DWIDTH - 1 : 0]       d_data_wr,
     input                        d_we,
     input [(DWIDTH / 8) - 1 : 0] d_be,

     input                        clk);

    localparam LOWBIT = $clog2(DWIDTH) - 3;

    (* ram_style = "block" *)
    reg [DWIDTH - 1 : 0]          mem [(MEMSIZE * 8 / DWIDTH) - 1 : 0];

    initial $readmemh(MEM_INIT_FILE, mem);

    always @(posedge clk)
        if (i_addr_valid)
            i_data <= mem[i_addr[AWIDTH - 1 : LOWBIT]];

    always @(posedge clk)
        if (d_addr_valid) begin:byteln
            integer i;

            for (i = 0; i < DWIDTH / 8; i = i + 1)
                if (d_we && d_be[i])
                    mem[d_addr[AWIDTH - 1 : LOWBIT]][i * 8 +: 8] <=
                        d_data_wr[i * 8 +: 8];

            d_data_rd <= mem[d_addr[AWIDTH - 1 : LOWBIT]];
        end

endmodule // riscv_too_mem
