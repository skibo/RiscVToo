`timescale 1ns / 1ps
//
// Copyright (c) 2019 Thomas Skibo.
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

// This module implements the required, memory-mapped mtime and
// mtimecmp registers.  It could also be used for other simple
// "local I/O" devices given that we have to go to the trouble
// to create a close-to-the-cpu memory mapped timer device.

module riscv_too_local_io #(parameter DWIDTH = 32,
                            parameter LOCIO_AWIDTH = 16)
    (
     output reg [DWIDTH - 1 : 0]  locio_data_rd,
     input [LOCIO_AWIDTH - 1 : 0] locio_addr,
     input                        locio_addr_valid,
     input [DWIDTH - 1 : 0]       locio_data_wr,
     input                        locio_wr,

     output reg                   timerint,

     input                        reset,
     input                        clk);

    localparam [LOCIO_AWIDTH - 1 : 0]
        MTIME_ADDR =        'h0000,
        MTIMEH_ADDR =       'h0004,
        MTIMECMP_ADDR =     'h0008,
        MTIMECMPH_ADDR =    'h000c;

    reg [DWIDTH - 1 : 0]    mtime;
    reg [DWIDTH - 1 : 0]    mtimeh;
    reg [DWIDTH - 1 : 0]    mtimecmp;
    reg [DWIDTH - 1 : 0]    mtimecmph;

    wire    wr = locio_addr_valid && locio_wr;

    // MTIME
    always @(posedge clk)
        if (reset)
            mtime <= 0;
        else if (wr && locio_addr == MTIME_ADDR)
            mtime <= locio_data_wr;
        else
            mtime <= mtime + 1;

    wire    mtime_c_p1 = (mtime == {DWIDTH{1'b1}} - 1'b1);
    reg     mtime_c;

    always @(posedge clk)
        if (reset)
            mtime_c <= 0;
        else
            mtime_c <= mtime_c_p1;

    // MTIMEH
    always @(posedge clk)
        if (reset)
            mtimeh <= 0;
        else if (wr && locio_addr == MTIMEH_ADDR)
            mtimeh <= locio_data_wr;
        else if (mtime_c)
            mtimeh <= mtimeh + 1;

    // MTIMECMP
    always @(posedge clk)
        if (reset)
            mtimecmp <= {DWIDTH{1'b1}};
        else if (wr && locio_addr == MTIMECMP_ADDR)
            mtimecmp <= locio_data_wr;

    // MTIMECMPH
    always @(posedge clk)
        if (reset)
            mtimecmph <= {DWIDTH{1'b1}};
        else if (wr && locio_addr == MTIMECMPH_ADDR)
            mtimecmph <= locio_data_wr;

    // Timter interrupt logic.
    always @(posedge clk)
        if (reset || (wr && (locio_addr == MTIMECMP_ADDR ||
                             locio_addr == MTIMECMPH_ADDR)))
            timerint <= 0;
        else if (mtime == mtimecmp && mtimeh == mtimecmph)
            timerint <= 1;

    // Read mux
    reg [DWIDTH - 1 : 0] locio_data_rd_p1;
    always @(*)
        case (locio_addr)
            MTIME_ADDR:
                locio_data_rd_p1 <= mtime;
            MTIMEH_ADDR:
                locio_data_rd_p1 <= mtimeh;
            MTIMECMP_ADDR:
                locio_data_rd_p1 <= mtimecmp;
            MTIMECMPH_ADDR:
                locio_data_rd_p1 <= mtimecmph;
            default:
                locio_data_rd_p1 <= {DWIDTH{1'bX}};
        endcase

    // Read output register
    always @(posedge clk)
        locio_data_rd <= locio_data_rd_p1;

endmodule // riscv_too_local_io
