
`timescale 1ns / 1ps
`include "../include/types.sv"
`include "../include/adc_fpga_cdc_if.vh"
import types::*;

module adc_fpga_cdc_tb;

    parameter PERIOD = 10;
    logic clk_adc = 1, clk_fpga = 1, nRST;

    // clocks
    always #(PERIOD/10) clk_fpga = ~clk_fpga; // clk_fpga x5 faster 
    always #(PERIOD/2) clk_adc = ~clk_adc; // clk_adc slower

    adc_fpga_cdc_if adcif();

    // test program
    test PROG (
        clk_adc, clk_fpga, rst,
        adcif
    );

    // DUT
    adc_fpga_cdc DUT(clk_adc, clk_fpga, rst, adcif);

endmodule

program test (
    input logic clk_adc, clk_fpga,
    output logic rst,
    adc_fpga_cdc_if.adc_fpga_cdc_tb adcif
);

    task sendWrite (input logic [DW-1:0] data);
        adcif.adc_data = data;
        adcif.adc_valid = 1'b1;
        @(negedge clk_adc);
        adcif.adc_valid = 1'b0;
    endtask

    string test_name;
    integer i;
    initial begin

        rst = 1'b1;
        adcif.adc_valid = 1'b0;
        repeat (2) @(negedge clk_adc);
        repeat (2) @(negedge clk_fpga);
        rst = 1'b0;
        repeat (2) @(negedge clk_adc);
        repeat (2) @(negedge clk_fpga);
        
        // ************************************************************************
        // Test Case 1: ADC writing to FIFO, and FPGA reading from FIFO
        // ************************************************************************
        test_name = "ADC writing to FIFO, and FPGA reading from FIFO";
        $display("%s", test_name);

        for (i = 0; i < 30; i++) begin
            sendWrite(18'h1000 + i);
        end

        repeat (15) @(negedge clk_adc);
        $finish;

    end

endprogram
