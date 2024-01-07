`timescale 1ns / 1ps
//
// Copyright (c) 2017 Thomas Skibo. <Thomas@Skibo.net>
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

module riscv_too #(
                   // Parameters of Axi Master Bus Interface M00_AXI
                   parameter integer C_M00_AXI_BURST_LEN = 4,
                   parameter integer C_M00_AXI_ID_WIDTH = 1,
                   parameter integer C_M00_AXI_ADDR_WIDTH = 32,
                   parameter integer C_M00_AXI_DATA_WIDTH = 32,
                   parameter integer C_M00_AXI_AWUSER_WIDTH = 0,
                   parameter integer C_M00_AXI_ARUSER_WIDTH = 0,
                   parameter integer C_M00_AXI_WUSER_WIDTH = 0,
                   parameter integer C_M00_AXI_RUSER_WIDTH = 0,
                   parameter integer C_M00_AXI_BUSER_WIDTH = 0,

                   parameter integer MEMSIZE = 16384,
                   parameter integer ROMSIZE = 8192,
                   parameter MEM_INIT_FILE = "bootrom.mem",

                   // Hart ID of this CPU
                   parameter [7 : 0] HART_ID = 8'h00)
    (
     // AXI4 Master interface
     input                                 M_AXI_ACLK,
     input                                 M_AXI_ARESETN,
     output [C_M00_AXI_ADDR_WIDTH-1 : 0]   M_AXI_ARADDR,
     output                                M_AXI_ARVALID,
     input                                 M_AXI_ARREADY,
     output [C_M00_AXI_ID_WIDTH-1 : 0]     M_AXI_ARID,
     output                                M_AXI_ARLOCK,
     output [3 : 0]                        M_AXI_ARCACHE,
     output [2 : 0]                        M_AXI_ARPROT,
     output [7 : 0]                        M_AXI_ARLEN,
     output [2 : 0]                        M_AXI_ARSIZE,
     output [1 : 0]                        M_AXI_ARBURST,
     output [3 : 0]                        M_AXI_ARQOS,
     input [C_M00_AXI_DATA_WIDTH-1 : 0]    M_AXI_RDATA,
     input                                 M_AXI_RVALID,
     output                                M_AXI_RREADY,
     input [C_M00_AXI_ID_WIDTH-1 : 0]      M_AXI_RID,
     input                                 M_AXI_RLAST,
     input [1 : 0]                         M_AXI_RRESP,
     output [C_M00_AXI_ADDR_WIDTH-1 : 0]   M_AXI_AWADDR,
     output                                M_AXI_AWVALID,
     input                                 M_AXI_AWREADY,
     output [C_M00_AXI_ID_WIDTH-1 : 0]     M_AXI_AWID,
     output                                M_AXI_AWLOCK,
     output [3 : 0]                        M_AXI_AWCACHE,
     output [2 : 0]                        M_AXI_AWPROT,
     output [7 : 0]                        M_AXI_AWLEN,
     output [2 : 0]                        M_AXI_AWSIZE,
     output [1 : 0]                        M_AXI_AWBURST,
     output [3 : 0]                        M_AXI_AWQOS,
     output [C_M00_AXI_DATA_WIDTH-1 : 0]   M_AXI_WDATA,
     output                                M_AXI_WVALID,
     input                                 M_AXI_WREADY,
     output                                M_AXI_WLAST,
     output [C_M00_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
     input [1 : 0]                         M_AXI_BRESP,
     input                                 M_AXI_BVALID,
     output                                M_AXI_BREADY,
     input [C_M00_AXI_ID_WIDTH-1 : 0]      M_AXI_BID,

     // External IRQ signal
      (* X_INTERFACE_INFO = "xilinx.com:interface:mbinterrupt:1.0 intr INTERRUPT" *)
     input                                 extirq
     );

    localparam
        AWIDTH = 32,
        DWIDTH = 32,
        MEM_AWIDTH = $clog2(MEMSIZE),
        LOCIO_AWIDTH = 8;

    // Convenience signal names.
    wire    clk = M_AXI_ACLK;
    wire    reset = ~M_AXI_ARESETN;

    wire [AWIDTH - 1 : 0]       i_addr;
    wire                        i_addr_valid;
    wire [DWIDTH -1 : 0]        i_data;
    wire                        i_data_valid;
    wire                        i_fault;

    wire [AWIDTH - 1 : 0]       d_addr;
    wire                        d_addr_valid;
    wire [DWIDTH - 1 : 0]       d_data_rd;
    wire                        d_data_rd_valid;
    wire [DWIDTH - 1 : 0]       d_data_wr;
    wire                        d_we;
    wire [(DWIDTH / 8) - 1 : 0] d_be;
    wire                        d_wr_done;
    wire                        d_fault;

    wire [LOCIO_AWIDTH - 1 : 0] locio_addr;
    wire                        locio_addr_valid;
    wire [DWIDTH - 1 : 0]       locio_data_wr;
    wire                        locio_wr;
    wire [DWIDTH - 1 : 0]       locio_data_rd;
    wire                        timerint;

    riscv_cpu #(.AWIDTH(AWIDTH),
                .DWIDTH(DWIDTH),
                .HART_ID(HART_ID)
    ) riscv_cpu_0 (
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

        .timerint(timerint),
        .extirq(extirq),

        .reset(reset),
        .clk(clk)
    );

    wire [DWIDTH - 1 : 0]       d_data_rd_mem;
    wire                        d_we_mem;

    riscv_too_mem #(.DWIDTH(DWIDTH),
                    .MEMSIZE(MEMSIZE),
                    .MEM_INIT_FILE(MEM_INIT_FILE))
    riscv_too_mem_0(
                    // Instruction port
                    .i_addr(i_addr[MEM_AWIDTH - 1 : 0]),
                    .i_addr_valid(i_addr_valid),
                    .i_data(i_data),

                    // Data port
                    .d_addr(d_addr[MEM_AWIDTH - 1 : 0]),
                    .d_addr_valid(d_addr_valid),
                    .d_data_rd(d_data_rd_mem),
                    .d_data_wr(d_data_wr),
                    .d_we(d_we_mem),
                    .d_be(d_be),

                    .clk(clk)
            );

    riscv_too_local_io #(.LOCIO_AWIDTH(LOCIO_AWIDTH))
    riscv_too_local_io_0(
                         .locio_addr(locio_addr),
                         .locio_addr_valid(locio_addr_valid),
                         .locio_data_wr(locio_data_wr),
                         .locio_wr(locio_wr),
                         .locio_data_rd(locio_data_rd),

                         .timerint(timerint),

                         .reset(reset),
                         .clk(clk)
            );


    riscv_too_glue #(.AWIDTH(AWIDTH),
                     .DWIDTH(DWIDTH),
                     .MEMSIZE(MEMSIZE),
                     .ROMSIZE(ROMSIZE),
                     .LOCIO_AWIDTH(LOCIO_AWIDTH))

    riscv_too_glue_0(
             // AXI master interface
             .M_AXI_ACLK(M_AXI_ACLK),
             .M_AXI_ARESETN(M_AXI_ARESETN),
             .M_AXI_ARADDR(M_AXI_ARADDR),
             .M_AXI_ARVALID(M_AXI_ARVALID),
             .M_AXI_ARREADY(M_AXI_ARREADY),
             .M_AXI_ARID(M_AXI_ARID),
             .M_AXI_ARLOCK(M_AXI_ARLOCK),
             .M_AXI_ARCACHE(M_AXI_ARCACHE),
             .M_AXI_ARPROT(M_AXI_ARPROT),
             .M_AXI_ARLEN(M_AXI_ARLEN),
             .M_AXI_ARSIZE(M_AXI_ARSIZE),
             .M_AXI_ARBURST(M_AXI_ARBURST),
             .M_AXI_ARQOS(M_AXI_ARQOS),
             .M_AXI_RDATA(M_AXI_RDATA),
             .M_AXI_RVALID(M_AXI_RVALID),
             .M_AXI_RREADY(M_AXI_RREADY),
             .M_AXI_RID(M_AXI_RID),
             .M_AXI_RLAST(M_AXI_RLAST),
             .M_AXI_RRESP(M_AXI_RRESP),
             .M_AXI_AWADDR(M_AXI_AWADDR),
             .M_AXI_AWVALID(M_AXI_AWVALID),
             .M_AXI_AWREADY(M_AXI_AWREADY),
             .M_AXI_AWID(M_AXI_AWID),
             .M_AXI_AWLOCK(M_AXI_AWLOCK),
             .M_AXI_AWCACHE(M_AXI_AWCACHE),
             .M_AXI_AWPROT(M_AXI_AWPROT),
             .M_AXI_AWLEN(M_AXI_AWLEN),
             .M_AXI_AWSIZE(M_AXI_AWSIZE),
             .M_AXI_AWBURST(M_AXI_AWBURST),
             .M_AXI_AWQOS(M_AXI_AWQOS),
             .M_AXI_WDATA(M_AXI_WDATA),
             .M_AXI_WVALID(M_AXI_WVALID),
             .M_AXI_WREADY(M_AXI_WREADY),
             .M_AXI_WLAST(M_AXI_WLAST),
             .M_AXI_WSTRB(M_AXI_WSTRB),
             .M_AXI_BRESP(M_AXI_BRESP),
             .M_AXI_BVALID(M_AXI_BVALID),
             .M_AXI_BREADY(M_AXI_BREADY),
             .M_AXI_BID(M_AXI_BID),

             .locio_addr(locio_addr),
             .locio_addr_valid(locio_addr_valid),
             .locio_data_wr(locio_data_wr),
             .locio_wr(locio_wr),
             .locio_data_rd(locio_data_rd),

             .i_addr(i_addr),
             .i_addr_valid(i_addr_valid),
             .i_data_valid(i_data_valid),
             .i_fault(i_fault),

             .d_addr(d_addr),
             .d_addr_valid(d_addr_valid),
             .d_data_rd(d_data_rd),
             .d_data_rd_mem(d_data_rd_mem),
             .d_data_rd_valid(d_data_rd_valid),
             .d_data_wr(d_data_wr),
             .d_we(d_we),
             .d_we_mem(d_we_mem),
             .d_be(d_be),
             .d_wr_done(d_wr_done),
             .d_fault(d_fault)
    );

endmodule // riscv_too
