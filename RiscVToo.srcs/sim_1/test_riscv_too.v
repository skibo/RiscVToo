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

module test_riscv_too;

    parameter integer C_M00_AXI_BURST_LEN = 4;
    parameter integer C_M00_AXI_ID_WIDTH = 1;
    parameter integer C_M00_AXI_ADDR_WIDTH = 32;
    parameter integer C_M00_AXI_DATA_WIDTH = 32;
    parameter integer C_M00_AXI_AWUSER_WIDTH = 0;
    parameter integer C_M00_AXI_ARUSER_WIDTH = 0;
    parameter integer C_M00_AXI_WUSER_WIDTH = 0;
    parameter integer C_M00_AXI_RUSER_WIDTH = 0;
    parameter integer C_M00_AXI_BUSER_WIDTH = 0;

    parameter MEM_INIT_FILE = "test_too.mem";
    parameter WAITRANGE = 1; // 0..15 (passed on to axi4_my_s

    reg               M_AXI_ACLK;
    reg               M_AXI_ARESETN;

    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR;
    wire                              M_AXI_ARVALID;
    wire                              M_AXI_ARREADY;
    wire [C_M00_AXI_ID_WIDTH-1 : 0]   M_AXI_ARID;
    wire                              M_AXI_ARLOCK;
    wire [3 : 0]                      M_AXI_ARCACHE;
    wire [2 : 0]                      M_AXI_ARPROT;
    wire [7 : 0]                      M_AXI_ARLEN;
    wire [2 : 0]                      M_AXI_ARSIZE;
    wire [1 : 0]                      M_AXI_ARBURST;
    wire [3 : 0]                      M_AXI_ARQOS;
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA;
    wire                              M_AXI_RVALID;
    wire                              M_AXI_RREADY;
    wire [C_M00_AXI_ID_WIDTH-1 : 0]   M_AXI_RID;
    wire                              M_AXI_RLAST;
    wire [1 : 0]                      M_AXI_RRESP;
    wire [C_M00_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR;
    wire                              M_AXI_AWVALID;
    wire                              M_AXI_AWREADY;
    wire [C_M00_AXI_ID_WIDTH-1 : 0]   M_AXI_AWID;
    wire                              M_AXI_AWLOCK;
    wire [3 : 0]                      M_AXI_AWCACHE;
    wire [2 : 0]                      M_AXI_AWPROT;
    wire [7 : 0]                      M_AXI_AWLEN;
    wire [2 : 0]                      M_AXI_AWSIZE;
    wire [1 : 0]                      M_AXI_AWBURST;
    wire [3 : 0]                      M_AXI_AWQOS;
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA;
    wire                              M_AXI_WVALID;
    wire                              M_AXI_WREADY;
    wire                              M_AXI_WLAST;
    wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB;
    wire [1 : 0]                        M_AXI_BRESP;
    wire                                M_AXI_BVALID;
    wire                                M_AXI_BREADY;
    wire [C_M00_AXI_ID_WIDTH-1 : 0]     M_AXI_BID;

    reg                                 extirq;

    reg                                 test_pass;

    initial begin
        $display("test_riscv_too.v: MEM_INIT_FILE=%s WAITRANGE=%d",
                 MEM_INIT_FILE, WAITRANGE);

        M_AXI_ACLK = 0;
        M_AXI_ARESETN = 0;
        extirq = 0;
        test_pass = 0;

        // wait 20 clocks and release reset
        repeat (20) @(posedge M_AXI_ACLK);
        M_AXI_ARESETN <= 1;
    end

    always #5 M_AXI_ACLK = ~M_AXI_ACLK;

    riscv_too #(.MEM_INIT_FILE(MEM_INIT_FILE))
                riscv_too_0
    (
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
        .extirq(extirq)
    );

    axi4_my_s #(.MEMSIZE(32768),
                .WAITRANGE(WAITRANGE))
    axi4_my_s_0(
                                  .S_AXI_ACLK(M_AXI_ACLK),
                                  .S_AXI_ARESETN(M_AXI_ARESETN),
                                  .S_AXI_ARADDR(M_AXI_ARADDR),
                                  .S_AXI_ARVALID(M_AXI_ARVALID),
                                  .S_AXI_ARREADY(M_AXI_ARREADY),
                                  .S_AXI_ARID(M_AXI_ARID),
                                  .S_AXI_ARLOCK(M_AXI_ARLOCK),
                                  .S_AXI_ARCACHE(M_AXI_ARCACHE),
                                  .S_AXI_ARPROT(M_AXI_ARPROT),
                                  .S_AXI_ARLEN(M_AXI_ARLEN),
                                  .S_AXI_ARSIZE(M_AXI_ARSIZE),
                                  .S_AXI_ARBURST(M_AXI_ARBURST),
                                  .S_AXI_ARQOS(M_AXI_ARQOS),
                                  .S_AXI_RDATA(M_AXI_RDATA),
                                  .S_AXI_RVALID(M_AXI_RVALID),
                                  .S_AXI_RREADY(M_AXI_RREADY),
                                  .S_AXI_RID(M_AXI_RID),
                                  .S_AXI_RLAST(M_AXI_RLAST),
                                  .S_AXI_RRESP(M_AXI_RRESP),
                                  .S_AXI_AWADDR(M_AXI_AWADDR),
                                  .S_AXI_AWVALID(M_AXI_AWVALID),
                                  .S_AXI_AWREADY(M_AXI_AWREADY),
                                  .S_AXI_AWID(M_AXI_AWID),
                                  .S_AXI_AWLOCK(M_AXI_AWLOCK),
                                  .S_AXI_AWCACHE(M_AXI_AWCACHE),
                                  .S_AXI_AWPROT(M_AXI_AWPROT),
                                  .S_AXI_AWLEN(M_AXI_AWLEN),
                                  .S_AXI_AWSIZE(M_AXI_AWSIZE),
                                  .S_AXI_AWBURST(M_AXI_AWBURST),
                                  .S_AXI_AWQOS(M_AXI_AWQOS),
                                  .S_AXI_WDATA(M_AXI_WDATA),
                                  .S_AXI_WVALID(M_AXI_WVALID),
                                  .S_AXI_WREADY(M_AXI_WREADY),
                                  .S_AXI_WLAST(M_AXI_WLAST),
                                  .S_AXI_WSTRB(M_AXI_WSTRB),
                                  .S_AXI_BRESP(M_AXI_BRESP),
                                  .S_AXI_BVALID(M_AXI_BVALID),
                                  .S_AXI_BREADY(M_AXI_BREADY),
                                  .S_AXI_BID(M_AXI_BID)
                                  );

    // Monitor writes on AXI.  Look for writes to magic location which
    // indicate test pass or failure.
    initial begin

        while (!M_AXI_ARESETN)
            @(posedge M_AXI_ACLK);

        @(posedge M_AXI_ACLK);

        forever begin
            while (!(M_AXI_AWVALID && M_AXI_AWREADY &&
                     M_AXI_AWADDR == 'hf0000))
                @(posedge M_AXI_ACLK);

            while (!(M_AXI_WVALID && M_AXI_WREADY))
                @(posedge M_AXI_ACLK);

            case (M_AXI_WDATA)
                'd0: // nothing
                    $display("[%t] wrote 0 to 0xf0000.  continuing", $time);
                'd2: begin // success!
                    $display("[%t] wrote 2 to 0xf0000!  SUCCESS!", $time);
                    test_pass = 1;
                    $finish;
                end
                default: begin // fail!
                    $display("[%t] wrote %d to 0xf0000! FAIL!", $time,
                             M_AXI_WDATA);
                    $stop;
                end
            endcase
        end
    end

endmodule // test_riscv_too
