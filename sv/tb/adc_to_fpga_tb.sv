
`timescale 1ns / 10ps
`include "../include/types.sv"
`include "../include/adc_to_fpga_if.vh"
import types::*;

module adc_to_fpga_tb;
    // Clock periods
    parameter FPGA_PERIOD  = 40;    // 25MHz
    parameter FRAME_PERIOD = 20000; // 50kHz
    parameter BIT_PERIOD   = 625; // 50kHz * 32 bits

    logic fpga_clk  = 0;
    logic frame_clk = 0;
    logic bit_clk   = 0;
    logic n_rst;

    always #(FPGA_PERIOD/2)   fpga_clk  = ~fpga_clk;
    always #(FRAME_PERIOD/2)  frame_clk = ~frame_clk;
    always #(BIT_PERIOD/2)    bit_clk   = ~bit_clk;

    adc_to_fpga_if atfif();

    // DUT
    adc_to_fpga DUT (.fpga_clk(fpga_clk), .n_rst(n_rst), .atfif(atfif));

    // test program
    adc_to_fpga_test PROG (
        .fpga_clk(fpga_clk),
        .n_rst(n_rst),
        .atfif(atfif)
    );

    assign atfif.adc_fclk = frame_clk;
    assign atfif.adc_bclk = bit_clk;

endmodule

program adc_to_fpga_test (
    input logic fpga_clk,
    output logic n_rst,
    adc_to_fpga_if.adc_to_fpga_tb atfif
);
    string test_name;
    integer i;
    initial begin
        n_rst = 1'b0;
        repeat (2) @(negedge fpga_clk);
        n_rst = 1'b1;
        repeat (2) @(negedge fpga_clk);

        // ************************************************************************
        // Test Case 1: Test ADC to FPGA
        // ************************************************************************
        test_name = "Test ADC to FPGA";
        $display("%s", test_name);

        for (i = 0; i < 1536; i++) begin
            atfif.adc_data = $urandom_range(0, 1);
            @(negedge fpga_clk);
        end

        repeat (15) @(negedge fpga_clk);
        $finish;
    end

endprogram