`timescale 1ns / 1ps
//
// Copyright (c) 2018 Thomas Skibo.
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

module riscv_too_glue #(
                        parameter C_M_AXI_BURST_LEN = 4,
                        parameter C_M_AXI_ID_WIDTH = 1,
                        parameter C_M_AXI_ADDR_WIDTH = 32,
                        parameter C_M_AXI_DATA_WIDTH = 32,
                        parameter C_M_AXI_AWUSER_WIDTH = 0,
                        parameter C_M_AXI_ARUSER_WIDTH = 0,
                        parameter C_M_AXI_WUSER_WIDTH = 0,
                        parameter C_M_AXI_RUSER_WIDTH = 0,
                        parameter C_M_AXI_BUSER_WIDTH = 0,

                        parameter AWIDTH = 32,
                        parameter DWIDTH = 32,

                        parameter MEMSIZE = 16384,
                        parameter ROMSIZE = 8192,

                        parameter LOCIO_ADDR = 'h2_0000,
                        parameter LOCIO_SIZE = 'h1_0000,
                        parameter LOCIO_AWIDTH = 16)
    (
     input                                   M_AXI_ACLK,
     input                                   M_AXI_ARESETN,
     // Read address
     output reg [C_M_AXI_ADDR_WIDTH-1 : 0]   M_AXI_ARADDR,
     output reg                              M_AXI_ARVALID,
     input                                   M_AXI_ARREADY,
     output [C_M_AXI_ID_WIDTH-1 : 0]         M_AXI_ARID,
     output                                  M_AXI_ARLOCK,
     output [3 : 0]                          M_AXI_ARCACHE,
     output [2 : 0]                          M_AXI_ARPROT,
     output [7 : 0]                          M_AXI_ARLEN,
     output [2 : 0]                          M_AXI_ARSIZE,
     output [1 : 0]                          M_AXI_ARBURST,
     output [3 : 0]                          M_AXI_ARQOS,
     // Read data
     input [C_M_AXI_DATA_WIDTH-1 : 0]        M_AXI_RDATA,
     input                                   M_AXI_RVALID,
     output reg                              M_AXI_RREADY,
     input [C_M_AXI_ID_WIDTH-1 : 0]          M_AXI_RID,
     input                                   M_AXI_RLAST,
     input [1 : 0]                           M_AXI_RRESP,
     // Write address
     output reg [C_M_AXI_ADDR_WIDTH-1 : 0]   M_AXI_AWADDR,
     output reg                              M_AXI_AWVALID,
     input                                   M_AXI_AWREADY,
     output [C_M_AXI_ID_WIDTH-1 : 0]         M_AXI_AWID,
     output                                  M_AXI_AWLOCK,
     output [3 : 0]                          M_AXI_AWCACHE,
     output [2 : 0]                          M_AXI_AWPROT,
     output [7 : 0]                          M_AXI_AWLEN,
     output [2 : 0]                          M_AXI_AWSIZE,
     output [1 : 0]                          M_AXI_AWBURST,
     output [3 : 0]                          M_AXI_AWQOS,
     // Write data
     output reg [C_M_AXI_DATA_WIDTH-1 : 0]   M_AXI_WDATA,
     output reg                              M_AXI_WVALID,
     input                                   M_AXI_WREADY,
     output reg                              M_AXI_WLAST,
     output reg [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
     // Write response
     input [1 : 0]                           M_AXI_BRESP,
     input                                   M_AXI_BVALID,
     output reg                              M_AXI_BREADY,
     input [C_M_AXI_ID_WIDTH-1 : 0]          M_AXI_BID,

     // Local I/O interface
     output [LOCIO_AWIDTH - 1 : 0]           locio_addr,
     output                                  locio_addr_valid,
     output [DWIDTH - 1 : 0]                 locio_data_wr,
     output                                  locio_wr,
     input [DWIDTH - 1 : 0]                  locio_data_rd,

     // Monitor cpu I-bus
     input [AWIDTH - 1 : 0]                  i_addr,
     input                                   i_addr_valid,
     output reg                              i_data_valid,
     output reg                              i_fault,

     // Cpu D-bus
     input [AWIDTH - 1 : 0]                  d_addr,
     input                                   d_addr_valid,
     output [DWIDTH - 1 : 0]                 d_data_rd,
     input [DWIDTH - 1 : 0]                  d_data_rd_mem,
     output                                  d_data_rd_valid,
     input [DWIDTH - 1 : 0]                  d_data_wr,
     input                                   d_we,
     output                                  d_we_mem,
     input [DWIDTH / 8 - 1 : 0]              d_be,
     output                                  d_wr_done,
     output                                  d_fault
    );

    // Fixed AXI write signals.
    assign M_AXI_AWID = 0;
    assign M_AXI_AWLEN = 8'd0;      // single word writes
    assign M_AXI_AWSIZE = 3'b010;   // 4 bytes per clock
    assign M_AXI_AWBURST = 2'b01;   // INCR
    assign M_AXI_AWLOCK = 1'b0;
    assign M_AXI_AWCACHE = 4'b0000; // normal non-cacheable non-bufferable
    assign M_AXI_AWPROT = 3'd0;
    assign M_AXI_AWQOS = 4'd0;

    // Fixed AXI read channel signals.
    assign M_AXI_ARID = 0;
    assign M_AXI_ARSIZE = 3'b010;   // 4 bytes per clock
    assign M_AXI_ARLEN = 8'd0;      // single word reads
    assign M_AXI_ARBURST = 2'b01;   // INCR
    assign M_AXI_ARLOCK = 1'b0;
    assign M_AXI_ARCACHE = 4'b0000; // normal non-cacheable non-bufferable
    assign M_AXI_ARPROT = 3'd0;
    assign M_AXI_ARQOS = 4'd0;

    // Convenience signals.
    wire    clk = M_AXI_ACLK;
    wire    reset = ~M_AXI_ARESETN;

    // As long as i_addr is in onboard mem, it is valid next clock.
    always @(posedge clk)
        if (reset)
            i_data_valid <= 0;
        else if (i_addr_valid)
            i_data_valid <= i_addr < MEMSIZE;

    // Fault any instruction access outsize of onboard mem.
    always @(posedge clk)
        if (reset)
            i_fault <= 0;
        else
            i_fault <= i_addr_valid && i_addr >= MEMSIZE;

    wire    d_addr_ismem = d_addr_valid && d_addr < MEMSIZE;
    reg     d_data_ismem;
    always @(posedge clk)
        if (reset)
            d_data_ismem <= 0;
        else
            d_data_ismem <= d_addr_ismem && !d_we;

    assign d_we_mem = d_addr_ismem && d_we && d_addr >= ROMSIZE;

    wire    d_addr_islocio = d_addr_valid &&
            (d_addr >= LOCIO_ADDR && d_addr < LOCIO_ADDR + LOCIO_SIZE);
    assign  locio_wr = d_addr_islocio && d_we;
    assign  locio_data_wr = d_data_wr;
    assign  locio_addr = d_addr[LOCIO_AWIDTH - 1 : 0];
    assign  locio_addr_valid = d_addr_islocio;

    reg     d_data_islocio;
    always @(posedge clk)
        if (reset)
            d_data_islocio <= 0;
        else
            d_data_islocio <= d_addr_islocio && !d_we;

    wire    d_addr_isaxi = d_addr_valid && !d_addr_ismem && !d_addr_islocio;

    // Read mux
    assign d_data_rd = d_data_ismem ? d_data_rd_mem :
                       (d_data_islocio ? locio_data_rd :  M_AXI_RDATA);

    reg     d_wr_done_mem;
    always @(posedge clk)
        if (reset)
            d_wr_done_mem <= 0;
        else
            d_wr_done_mem <= d_we_mem;

    reg     d_wr_rom_fault;
    always @(posedge clk)
        if (reset)
            d_wr_rom_fault <= 0;
        else
            d_wr_rom_fault <= d_addr_ismem && d_we && d_addr < ROMSIZE;

    reg     d_wr_done_locio;
    always @(posedge clk)
        if (reset)
            d_wr_done_locio <= 0;
        else
            d_wr_done_locio <= d_addr_islocio && d_we;

    // AXI State machines handle data reads and writes one word at a time.

    // AXI Read state machine.
    localparam [1 : 0]
        RSM_IDLE =      2'd0,
        RSM_RADDR =     2'd1,
        RSM_RDATA =     2'd2;

    reg [1 : 0] rsm;

    always @(posedge clk)
        if (reset) begin
            M_AXI_ARVALID <= 0;
            M_AXI_RREADY <= 0;
            rsm <= RSM_IDLE;
        end
        else
            case (rsm)
                RSM_IDLE:
                    if (d_addr_valid && !d_we && d_addr_isaxi) begin
                        M_AXI_ARADDR <= d_addr;
                        M_AXI_ARVALID <= 1;
                        rsm <= RSM_RADDR;
                    end

                RSM_RADDR:
                    if (M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 0;
                        M_AXI_RREADY <= 1;
                        rsm <= RSM_RDATA;
                    end

                RSM_RDATA:
                    if (M_AXI_RVALID && M_AXI_RLAST) begin
                        M_AXI_RREADY <= 0;
                        rsm <= RSM_IDLE;
                    end

            endcase

    assign d_data_rd_valid = d_data_ismem || d_data_islocio ||
                             ((rsm == RSM_RDATA) && M_AXI_RVALID &&
                              M_AXI_RLAST && M_AXI_RRESP == 2'b00);

    wire d_rd_fault = (rsm == RSM_RDATA) && M_AXI_RVALID &&
         M_AXI_RRESP != 2'b00;

    // Register write data and be for AXI transactions
    reg [DWIDTH - 1 : 0]        d_data_wr_1;
    reg [DWIDTH / 8 - 1 : 0]    d_be_1;
    always @(posedge clk)
        if (d_addr_valid && d_we) begin
            d_data_wr_1 <= d_data_wr;
            d_be_1 <= d_be;
        end

    // AXI Write state machine.
    localparam [1 : 0]
        WSM_IDLE =      2'd0,
        WSM_WADDR =     2'd1,
        WSM_WDATA =     2'd2,
        WSM_WRESP =     2'd3;

    reg [1 : 0] wsm;

    always @(posedge clk)
        if (reset) begin
            M_AXI_AWVALID <= 0;
            M_AXI_WVALID <= 0;
            M_AXI_WLAST <= 0;
            M_AXI_WSTRB <= 'd0;
            M_AXI_BREADY <= 0;
            wsm <= WSM_IDLE;
        end
        else
            case (wsm)
                WSM_IDLE:
                    if (d_addr_valid && d_we && d_addr_isaxi) begin
                        M_AXI_AWADDR <= d_addr;
                        M_AXI_AWVALID <= 1;
                        wsm <= WSM_WADDR;
                    end

                WSM_WADDR:
                    if (M_AXI_AWREADY) begin
                        M_AXI_AWVALID <= 0;
                        M_AXI_WDATA <= d_data_wr_1;
                        M_AXI_WSTRB <= d_be_1;
                        M_AXI_WLAST <= 1;
                        M_AXI_WVALID <= 1;
                        wsm <= WSM_WDATA;
                    end

                WSM_WDATA:
                    if (M_AXI_WREADY) begin
                        M_AXI_WLAST <= 0;
                        M_AXI_WVALID <= 0;
                        M_AXI_WSTRB <= 0;
                        M_AXI_BREADY <= 1;
                        wsm <= WSM_WRESP;
                    end

                WSM_WRESP:
                    if (M_AXI_BVALID) begin
                        M_AXI_BREADY <= 0;
                        wsm <= WSM_IDLE;
                    end

            endcase // case (wsm)

    wire d_wr_done_axi = (wsm == WSM_WRESP) && M_AXI_BVALID &&
         M_AXI_BRESP == 2'b00;
    assign d_wr_done = d_wr_done_mem || d_wr_done_locio || d_wr_done_axi;

    wire d_wr_fault = d_wr_rom_fault ||
         ((wsm == WSM_WRESP) && M_AXI_BVALID && M_AXI_BRESP != 2'b00);
    assign d_fault = d_rd_fault || d_wr_fault;

endmodule // riscv_too_glue
