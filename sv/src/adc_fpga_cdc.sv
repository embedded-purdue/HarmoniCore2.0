
`timescale 1ns / 10ps
`include "../include/types.sv"
`include "../include/adc_fpga_cdc_if.vh"

module adc_fpga_cdc
import types::*;
(
    input logic adc_clk, fpga_clk, rst,
    adc_fpga_cdc_if.adc_fpga_cdc adcif
);
    // declare interfaces
    fifowrapper_if fifoif();

    // declare modules
    fifowrapper fifoDUT(adc_clk, fpga_clk, rst, fifoif);

    // additional signals
    logic [DW-1:0] fifo_wr_data;
    logic fifo_wr_en, fifo_rd_en;

    // ************************************************************************
    // START THE CODE
    // ************************************************************************

    always_comb begin : adcWritingToFifo
        if (fifoif.can_write & !fifoif.full & adcif.adc_valid) begin
            fifo_wr_en = 1'b1;
            fifo_wr_data = adcif.adc_data;
        end
        else begin
            fifo_wr_en = 1'b0;
            fifo_wr_data = '0;
        end
    end

    always_ff @(posedge adc_clk) begin : fpgaSampleFifo
        if (rst) fifo_rd_en <= 1'b0;
        else if (!fifoif.empty & fifoif.can_read) fifo_rd_en <= 1'b1;
        else fifo_rd_en <= 1'b0;
    end

    fifowrapper FIFO(adc_clk, fpga_clk, rst, fifoif);

    always_comb begin : fifowrapperSignals
        // input
        fifoif.wr_en = fifo_wr_en;
        fifoif.wr_data = fifo_wr_data;
        fifoif.rd_en = fifo_rd_en;

        // output
        adcif.fifo_valid = fifoif.valid;;
        adcif.fifo_data = fifoif.rd_data;
    end

endmodule