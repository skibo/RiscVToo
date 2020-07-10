`timescale 1ns / 1ps
//
// Copyright (c) 2015 Thomas Skibo.
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

module axi4_my_s #(
                   parameter integer C_S_AXI_ID_WIDTH = 1,
                   parameter integer C_S_AXI_ADDR_WIDTH = 32,
                   parameter integer C_S_AXI_DATA_WIDTH = 32,
                   parameter [C_S_AXI_ADDR_WIDTH - 1 : 0] MEMBASE = 'h0,
                   parameter integer MEMSIZE = 8192,
                   parameter INIT_FILE = "",
                   parameter integer WAITRANGE = 1 // 0..15
                        ) (
                        input                                 S_AXI_ACLK,
                        input                                 S_AXI_ARESETN,
                        // Read address
                        input [C_S_AXI_ADDR_WIDTH-1 : 0]      S_AXI_ARADDR,
                        input                                 S_AXI_ARVALID,
                        output reg                            S_AXI_ARREADY,
                        input [C_S_AXI_ID_WIDTH-1 : 0]        S_AXI_ARID,
                        input                                 S_AXI_ARLOCK,
                        input [3 : 0]                         S_AXI_ARCACHE,
                        input [2 : 0]                         S_AXI_ARPROT,
                        input [7 : 0]                         S_AXI_ARLEN,
                        input [2 : 0]                         S_AXI_ARSIZE,
                        input [1 : 0]                         S_AXI_ARBURST,
                        input [3 : 0]                         S_AXI_ARQOS,
                        // Read data
                        output reg [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
                        output reg                            S_AXI_RVALID,
                        input                                 S_AXI_RREADY,
                        output reg [C_S_AXI_ID_WIDTH-1 : 0]   S_AXI_RID,
                        output reg                            S_AXI_RLAST,
                        output reg [1 : 0]                    S_AXI_RRESP,
                        // Write address
                        input [C_S_AXI_ADDR_WIDTH-1 : 0]      S_AXI_AWADDR,
                        input                                 S_AXI_AWVALID,
                        output reg                            S_AXI_AWREADY,
                        input [C_S_AXI_ID_WIDTH-1 : 0]        S_AXI_AWID,
                        input                                 S_AXI_AWLOCK,
                        input [3 : 0]                         S_AXI_AWCACHE,
                        input [2 : 0]                         S_AXI_AWPROT,
                        input [7 : 0]                         S_AXI_AWLEN,
                        input [2 : 0]                         S_AXI_AWSIZE,
                        input [1 : 0]                         S_AXI_AWBURST,
                        input [3 : 0]                         S_AXI_AWQOS,
                        // Write data
                        input [C_S_AXI_DATA_WIDTH-1 : 0]      S_AXI_WDATA,
                        input                                 S_AXI_WVALID,
                        output reg                            S_AXI_WREADY,
                        input                                 S_AXI_WLAST,
                        input [C_S_AXI_DATA_WIDTH/8-1 : 0]    S_AXI_WSTRB,
                        // Write response
                        output reg [1 : 0]                    S_AXI_BRESP,
                        output reg                            S_AXI_BVALID,
                        input                                 S_AXI_BREADY,
                        output reg [C_S_AXI_ID_WIDTH-1 : 0]   S_AXI_BID
                  );

    wire        clk = S_AXI_ACLK;
    wire        reset = ~S_AXI_ARESETN;

    reg [C_S_AXI_DATA_WIDTH-1 : 0] mem[MEMSIZE-1 : 0];

    initial begin:reads
        reg [C_S_AXI_ADDR_WIDTH-1 : 0] addr;
        reg [C_S_AXI_ID_WIDTH-1 : 0] id;
        reg [7:0] len;
        integer   r;
        integer   i;

        for (i = 0; i < MEMSIZE / (C_S_AXI_DATA_WIDTH / 8); i = i + 1)
            mem[i] = i;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);

        S_AXI_ARREADY = 1'b0;
        S_AXI_RDATA = {C_S_AXI_DATA_WIDTH{1'b0}};
        S_AXI_RVALID = 1'b0;
        S_AXI_RID = {C_S_AXI_ID_WIDTH{1'bx}};
        S_AXI_RLAST = 1'b0;
        S_AXI_RRESP = 2'bxx;

        while (reset)
            @(posedge clk);
        repeat (20) @(posedge clk);

        forever begin
            r = $urandom_range(WAITRANGE, 0);
            repeat (r) @(posedge clk);
            S_AXI_ARREADY <= 1'b1;
            @(posedge clk);

            while (!S_AXI_ARVALID)
                @(posedge clk);
            $display("[%t] %m: Read Address: %h id=%h len=%h", $time,
                     S_AXI_ARADDR, S_AXI_ARID, S_AXI_ARLEN);
            id = S_AXI_ARID;
            len = S_AXI_ARLEN + 1;
            addr = S_AXI_ARADDR;

            S_AXI_ARREADY <= 1'b0;

            S_AXI_RID <= id;
            for (i = 0; i < len; i = i + 1) begin
                r = $urandom_range(WAITRANGE, 0);
                repeat (r) @(posedge clk);
                S_AXI_RVALID <= 1'b1;
                S_AXI_RLAST <= (i == len - 1);
                if (addr >= MEMBASE && addr < MEMBASE + MEMSIZE)
                    S_AXI_RDATA <= mem[(addr - MEMBASE) /
                                       (C_S_AXI_DATA_WIDTH / 8)];
                else
                    S_AXI_RDATA <= S_AXI_RDATA + 1'b1;
                S_AXI_RRESP <= {addr[31 : 0] == 32'hdead0, 1'b0};
                addr = addr + (C_S_AXI_DATA_WIDTH / 8);
                @(posedge clk);
                while (!S_AXI_RREADY)
                       @(posedge clk);
                $display("[%t] %m: Read Data: %h", $time, S_AXI_RDATA);
                S_AXI_RVALID <= 1'b0;
                S_AXI_RRESP <= 2'bxx;
            end
            S_AXI_RLAST <= 1'b0;
            S_AXI_RID <= {C_S_AXI_ID_WIDTH{1'bx}};
        end // forever begin
    end

    initial begin:writes
        reg [C_S_AXI_ADDR_WIDTH-1 : 0] addr;
        reg [C_S_AXI_DATA_WIDTH-1 : 0] data;
        reg [C_S_AXI_ID_WIDTH-1 : 0] id;
        reg [7:0] len;
        reg       islast;
        reg       gotaddr;
        integer   r1;
        integer   r2;
        integer   i, j;

        S_AXI_AWREADY = 1'b0;
        S_AXI_WREADY = 1'b0;
        S_AXI_BRESP = 2'b00;
        S_AXI_BVALID = 1'b0;
        S_AXI_BID = {C_S_AXI_ID_WIDTH{1'bx}};
        gotaddr = 0;

        while (reset)
            @(posedge clk);
        repeat (20) @(posedge clk);

        forever begin
            fork
                begin // Address channel.
                    r1 = $urandom_range(WAITRANGE, 0);
                    repeat (r1) @(posedge clk);
                    S_AXI_AWREADY <= 1'b1;
                    @(posedge clk);

                    while (!S_AXI_AWVALID)
                        @(posedge clk);

                    $display("[%t] %m: Got write address 0x%h id=0x%h len=0x%h", $time,
                             S_AXI_AWADDR, S_AXI_AWID, S_AXI_AWLEN);
                    addr = S_AXI_AWADDR;
                    id = S_AXI_AWID;
                    len = S_AXI_AWLEN + 1;
                    S_AXI_AWREADY <= 1'b0;
                    gotaddr = 1;
                end
                begin // Data channel
                    i = 0;
                    islast = 0;
                    while (!islast) begin
                        r2 = $urandom_range(WAITRANGE, 0);
                        repeat (r2) @(posedge clk);

                        S_AXI_WREADY <= 1'b1;
                        @(posedge clk);

                        while (!S_AXI_WVALID)
                            @(posedge clk);
                        if (!gotaddr) begin
                            $display("[%t] %m: Write data came before address!", $time);
                            $stop;
                        end
                        $display("[%t] %m: Data written: %h strb=%b", $time, S_AXI_WDATA, S_AXI_WSTRB);
                        if (addr >= MEMBASE && addr < MEMBASE + MEMSIZE) begin
                            data = mem[(addr - MEMBASE) /
                                       (C_S_AXI_DATA_WIDTH / 8)];
                            for (j = 0; j < C_S_AXI_DATA_WIDTH; j = j + 1)
                                if (S_AXI_WSTRB[j / 8])
                                    data[j] = S_AXI_WDATA[j];
                            mem[(addr - MEMBASE) /
                                (C_S_AXI_DATA_WIDTH / 8)] = data;
                        end
                        addr = addr + (C_S_AXI_DATA_WIDTH / 8);
                        islast = S_AXI_WLAST;
                        i = i + 1;
                        S_AXI_WREADY <= 1'b0;
                    end
                    if (i != len) begin
                        $display("[%t] %m: unexpect num words: got %d len=%d",
                                 $time, i, len);
                        $stop;
                    end
                    @(posedge clk);
                    gotaddr = 0;
                end
            join

            S_AXI_BVALID <= 1'b1;
            S_AXI_BRESP <= {addr == 'hdead4, 1'b0};
            S_AXI_BID <= id;
            @(posedge clk);
            while (!S_AXI_BREADY)
                @(posedge clk);
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP <= 2'bxx;
            S_AXI_BID <= {C_S_AXI_ID_WIDTH{1'bx}};
        end // forever begin
    end // block: writes


endmodule // axi4_my_s
