
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/core/fpga_to_dac_if.vh"
import types::*;

module fpga_to_dac_tb;
    // Clock periods
    parameter FPGA_PERIOD  = 6.4;   // 156MHz
    parameter FRAME_PERIOD = 20000; // 50kHz
    parameter BIT_PERIOD   = 625;   // 50kHz * 32 bclks = 1.6MHz (standard I2S framing)

    logic fpga_clk  = 0;
    logic frame_clk = 0;
    logic bit_clk   = 0;
    logic n_rst;

    always #(FPGA_PERIOD/2)   fpga_clk  = ~fpga_clk;
    always #(FRAME_PERIOD/2)  frame_clk = ~frame_clk;
    always #(BIT_PERIOD/2)    bit_clk   = ~bit_clk;

    fpga_to_dac_if ftdif();

    // DUT
    fpga_to_dac DUT (.fpga_clk(fpga_clk), .n_rst(n_rst), .ftdif(ftdif));

    // test program
    fpga_to_dac_test PROG (
        .fpga_clk(fpga_clk),
        .n_rst(n_rst),
        .ftdif(ftdif)
    );

    assign ftdif.dac_fclk = frame_clk;
    assign ftdif.dac_bclk = bit_clk;

endmodule

program fpga_to_dac_test (
    input logic fpga_clk,
    output logic n_rst,
    fpga_to_dac_if.fpga_to_dac_tb ftdif
);
    string test_name;
    integer i;
    initial begin
        n_rst = 1'b0;
        repeat (2) @(negedge fpga_clk);
        n_rst = 1'b1;
        repeat (2) @(negedge fpga_clk);

        // ************************************************************************
        // Test Case 1: Test FPGA to DAC
        // ************************************************************************
        test_name = "Test FPGA to DAC";
        $display("%s", test_name);

        ftdif.audio_data = 24'hA5A5A5;
        ftdif.audio_valid = 1'b1;
        @(negedge fpga_clk);

        repeat (2048) @(negedge fpga_clk);
        $finish;
    end

endprogram