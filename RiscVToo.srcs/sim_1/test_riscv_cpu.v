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

module test_riscv_cpu;

    parameter
        DMEM_SIZE = 256,
        IMEM_SIZE = 2048,
        DMEM_DELAYS = 0,
        IMEM_DELAYS = 0,
        MEM_INIT_FILE = "test1.mem",
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

    reg             timerint;
    reg             extirq;

    reg             reset;
    reg             clk;

    reg             test_pass;

    initial begin
        i_data = 'd0;
        i_data_valid = 0;
        i_fault = 0;
        d_data_rd = 'd0;
        d_data_rd_valid = 0;
        d_fault = 0;
        d_wr_done = 1;
        timerint = 0;
        extirq = 0;

        reset = 1;
        clk = 0;

        test_pass = 0;

        repeat (20) @(posedge clk);
        reset <= 0;
    end

    always #5 clk = ~clk;

    reg [31 : 0] imem[(IMEM_SIZE / 4) - 1 : 0];
    reg [31 : 0] dmem[(DMEM_SIZE / 4) - 1 : 0];

    initial begin
        $display("test_riscv_cpu: MEM_INIT_FILE=%s DMEM_DELAYS=%d IMEM_DELAYS=%d",
                 MEM_INIT_FILE, DMEM_DELAYS, IMEM_DELAYS);
        $readmemh(MEM_INIT_FILE, imem);
    end

    // Read logic, IMEM
    always @(posedge clk) begin:iblk
        reg [31 : 0] i_addr_1;
        reg [1 : 0]  r;

        if (i_addr_valid && !reset && !i_fault) begin
            i_fault <= 0;
            i_addr_1 = i_addr;

            if (IMEM_DELAYS) begin
                // Delay?
                r = $urandom_range(3, 0);
                if (r != 2'd0) begin
                    i_data_valid <= 0;
                    i_data <= 32'hXXXX_XXXX;
                    repeat (r) begin
                        @(posedge clk);
                        if (i_addr_valid) begin
                            $display("[%t] i_addr_valid when fetching data.",
                                     $time);
                            $stop;
                        end
                    end
                end
            end

            if (i_addr_1 < IMEM_SIZE) begin
                i_data <= imem[i_addr_1[31 : 2]];
                i_data_valid <= 1;
            end
            else begin
                i_data <= 32'hXXXX_XXXX;
                i_fault <= 1;
            end
        end
        else
            i_fault <= 0;
    end

    if (IBUS_VERBOSE)
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

    //  Read logic, DMEM
    reg [31 : 0]        d_addr_1;
    always @(posedge clk) begin:rblk
        reg [1 : 0] r;

        if (d_addr_valid && !d_we) begin
            d_addr_1 = d_addr;
            d_fault <= 0;

            if (DMEM_DELAYS) begin
                // Delay?
                r = $urandom_range(3, 0);
                if (r != 2'd0) begin
                    d_data_rd_valid <= 0;
                    d_data_rd <= 32'hXXXX_XXX;
                    repeat (r) begin
                        @(posedge clk);
                        if (d_addr_valid) begin
                            $display("[%t] d_addr_valid when fetching data.",
                                     $time);
                            $stop;
                        end
                    end
                end
            end

            if (d_addr_1 < DMEM_SIZE) begin
                d_data_rd <= dmem[d_addr_1[31 : 2]];
                d_data_rd_valid <= 1;
            end
            else begin
                d_data_rd <= 32'hXXXX_XXXX;
                d_fault <= 1;
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
        reg [1 : 0]  r;

        if (d_addr_valid && d_we) begin
            dataw2 = d_data_wr;
            addrw2 = d_addr;
            bew2 = d_be;

            if (DMEM_DELAYS) begin
                // Write delay?
                r = $urandom_range(3, 0);
                if (r != 2'd0) begin
                    d_wr_done <= 0;
                    repeat (r) begin
                        @(posedge clk);
                        if (d_addr_valid) begin
                            $display("[%t] d_addr_valid while stalled write.",
                                     $time);
                            $stop;
                        end
                    end
                end
            end

            $display("[%t] D: write %h to %h be=%b", $time,
                     dataw2, addrw2, bew2);

            if (addrw2 < DMEM_SIZE) begin
                // D memory
                temp = dmem[addrw2[31 : 2]];
                if (bew2[3])
                    temp[31 : 24] = dataw2[31 : 24];
                if (bew2[2])
                    temp[23 : 16] = dataw2[23 : 16];
                if (bew2[1])
                    temp[15 : 8] = dataw2[15 : 8];
                if (bew2[0])
                    temp[7 : 0] = dataw2[7 : 0];
                dmem[addrw2[31 : 2]] = temp;

                d_wr_done <= 1;
            end
            else if (addrw2 == 32'h0000_0f00) begin
                // "Magic location:"
                //  0 - do nothing
                //  2 - test finished good
                //  999 - start IRQ in 30 clocks (see below)
                //  else - stop with error.
                if(dataw2 == 32'd2) begin
                    $display("[%t] --- SUCCESS!  Test finished.", $time);
                    test_pass = 1;
                    $finish;
                end
                else if (dataw2 != 32'd0 && dataw2 != 32'd999) begin
                    $display("[%t] --- ERROR.  Stopping.", $time);
                    $stop;
                end
                d_wr_done <= 1;
            end
            else
                d_fault <= 1;

        end
        else begin
            d_wr_done <= 0;
            d_fault <= 0;
        end
    end

    // Interrupt request from magic location.
    always @(posedge clk)
        if (d_addr_valid && d_we && d_addr == 32'h0000_0f00 &&
            d_data_wr == 32'd999) begin

            repeat (30) @(posedge clk);

            $display("[%t] Starting interrupt request.", $time);
            extirq <= 1;

            // Any write clears interrupt.
            while (!d_addr_valid || !d_we)
                @(posedge clk);
            extirq <= 0;
        end

    riscv_cpu riscv_cpu_0(.i_addr(i_addr),
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

endmodule // test_riscv_cpu
