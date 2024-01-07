`timescale 1ns / 1ps
//
// Copyright (c) 2016-2018 Thomas Skibo.
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

module test_riscv_compl;

    parameter
        MEM_SIZE = 32768,
        MEM_INIT_FILE = "xxx",  // Must be set externally.
        IBUS_VERBOSE = 0;

    wire [31 : 0]   i_addr;
    wire            i_addr_valid;
    reg [31 : 0]    i_data;
    reg             i_data_valid;
    reg             i_fault;

    wire [31 : 0]   d_addr;
    wire            d_addr_valid;
    reg [31 : 0]    d_data_rd;
    reg             d_data_rd_valid;
    wire [31 : 0]   d_data_wr;
    wire            d_we;
    wire [3 : 0]    d_be;
    reg             d_wr_done;
    reg             d_fault;

    reg             extirq;

    reg             reset;
    reg             clk;

    reg             test_pass;

    initial begin
        $display("test_riscv_compl:  STARTING TEST: %s", MEM_INIT_FILE);

        i_data = 'd0;
        i_data_valid = 0;
        i_fault = 0;
        d_data_rd = 'd0;
        d_data_rd_valid = 0;
        d_fault = 0;
        d_wr_done = 1;
        extirq = 0;

        reset = 1;
        clk = 0;

        test_pass = 0;

        repeat (20) @(posedge clk);
        reset <= 0;
    end

    always #5 clk = ~clk;

    reg [31 : 0] mem[(MEM_SIZE / 4) - 1 : 0];

    initial $readmemh(MEM_INIT_FILE, mem);

    // Read logic, IMEM
    always @(posedge clk) begin:iblk
        reg [31 : 0] i_addr_1;

        if (i_addr_valid && !reset && !i_fault) begin
            i_fault <= 0;
            i_addr_1 = i_addr;

            if (i_addr_1[31] && i_addr_1[30 : 0] < MEM_SIZE) begin
                i_data <= mem[i_addr_1[30 : 2]];
                i_data_valid <= 1;
            end
            else begin
                $display("[%t] I: address out of range: %h", $time, i_addr_1);
                $stop;
                i_data <= 32'hXXXX_XXXX;
                i_fault <= 1;
            end
        end
        else
            i_fault <= 0;
    end

    generate
        if (IBUS_VERBOSE) begin
            always @(posedge clk) begin:ird
                reg [31 : 0] iaddr_1;
                if (i_addr_valid)
                    iaddr_1 <= i_addr;
                if (i_data_valid)
                    $display("[%t] I: data read %h from %h", $time, i_data,
                             iaddr_1);
                if (i_fault)
                    $display("[%t] I: fault at addr %h", $time, iaddr_1);
            end
        end
    endgenerate

    //  Read logic, DMEM
    reg [31 : 0]        d_addr_1;
    always @(posedge clk) begin
        if (d_addr_valid && !d_we) begin
            d_addr_1 = d_addr;
            d_fault <= 0;

            if (d_addr_1[31] && d_addr_1[30 : 0] < MEM_SIZE) begin
                d_data_rd <= mem[d_addr_1[30 : 2]];
                d_data_rd_valid <= 1;
            end
            // XXX: handle I/O requests
            else begin
                d_data_rd <= 32'hXXXX_XXXX;
                d_fault <= 1;
                $display("[%t] D read: data addr out of range: %h",
                         $time, d_addr_1);
                $stop;
            end
        end
        else begin
            d_data_rd_valid <= 0;
            d_data_rd <= 32'hXXXX_XXXX;
        end
    end

    always @(posedge clk)
        if (d_data_rd_valid) begin
            $display("[%t] D: data read %h from %h", $time, d_data_rd,
                     d_addr_1);
            while (!d_addr_valid)
                @(posedge clk);
        end

    // Write logic.
    always @(posedge clk) begin:wr_block
        reg [31 : 0] dataw2;
        reg [31 : 0] addrw2;
        reg [31 : 0] temp;
        reg [3 : 0]  bew2;

        if (d_addr_valid && d_we) begin
            dataw2 = d_data_wr;
            addrw2 = d_addr;
            bew2 = d_be;

            $display("[%t] D: write %h to %h be=%b", $time,
                     dataw2, addrw2, bew2);

            if (addrw2 == 32'h8000_1000) begin
                if (dataw2 == 32'h0000_0001) begin
                    $display("TEST PASSED! %s", MEM_INIT_FILE);
                    test_pass = 1;
                    $finish;
                end
                else begin
                    $display("TEST FAILED!! %s", MEM_INIT_FILE);
                    $stop;
                end
            end

            if (addrw2[31] && addrw2[30 : 0] < MEM_SIZE) begin
                temp = mem[addrw2[30 : 2]];
                if (bew2[3])
                    temp[31 : 24] = dataw2[31 : 24];
                if (bew2[2])
                    temp[23 : 16] = dataw2[23 : 16];
                if (bew2[1])
                    temp[15 : 8] = dataw2[15 : 8];
                if (bew2[0])
                    temp[7 : 0] = dataw2[7 : 0];
                mem[addrw2[30 : 2]] = temp;

                d_wr_done <= 1;
            end
            // XXX: handle I/O writes?
            else begin
                $display("[%t] D write: data addr out of range: %h",
                         $time, addrw2);
                $stop;
                d_fault <= 1;
            end

        end
        else begin
            d_wr_done <= 0;
            d_fault <= 0;
        end
    end

    riscv_cpu #(.MTVEC(32'h8000_0004),
                .RSTVEC(32'h8000_0000))
    riscv_cpu_0(.i_addr(i_addr),
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

                .extirq(extirq),

                .reset(reset),
                .clk(clk)
    );

endmodule // test_riscv_compl
