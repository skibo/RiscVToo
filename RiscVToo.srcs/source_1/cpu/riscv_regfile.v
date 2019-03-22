`timescale 1ns / 1ps
//
// Copyright (c) 2016 Thomas Skibo.
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

module riscv_reg_file #(parameter DWIDTH = 32)
    (output [DWIDTH - 1 : 0] a_reg_data,
     output [DWIDTH - 1 : 0] b_reg_data,
     input [4 : 0]           a_reg_num,
     input [4 : 0]           b_reg_num,
     input [4 : 0]           w_reg_num,
     input [DWIDTH - 1 : 0]  w_reg_data,
     input                   w_reg_en,
     input                   clk);

    (* ram_style = "distributed" *)
    reg [DWIDTH - 1 : 0]     regs[31 : 0];

    initial regs[0] = 'd0;

    assign a_reg_data = regs[a_reg_num];
    assign b_reg_data = regs[b_reg_num];

    always @(posedge clk)
        if (w_reg_en)
            regs[w_reg_num] <= w_reg_data;

endmodule // riscv_reg_file
