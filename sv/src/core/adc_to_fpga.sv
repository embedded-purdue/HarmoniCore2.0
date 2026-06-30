
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/core/adc_to_fpga_if.vh"

module adc_to_fpga
import types::*;
(
    input logic fpga_clk, n_rst,
    adc_to_fpga_if.adc_to_fpga atfif
);
    // declare vars
    typedef struct packed {
        logic f_clk;
        logic b_clk;
        logic data;
    } adc_sync;
    adc_sync ff1, ff2, ff3;

    logic new_frame, can_sample;
    logic [DW-1:0] shift, next_shift;
    logic [4:0] count, next_count;

    // ************************************************************************
    // START THE CODE
    // ************************************************************************

    always_comb begin : assignFF1
        ff1.f_clk = atfif.adc_fclk;
        ff1.b_clk = atfif.adc_bclk;
        ff1.data  = atfif.adc_data;
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : FF1_TO_FF2
        if (~n_rst) ff2 <= '0;
        else        ff2 <= ff1;
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : FF2_TO_FF3
        if (~n_rst) ff3 <= '0;
        else        ff3 <= ff2;
    end

    // rising edge detection
    assign new_frame = ff2.f_clk & ~ff3.f_clk;
    assign can_sample = ff2.b_clk & ~ff3.b_clk;

    always_ff @(posedge fpga_clk, negedge n_rst) begin : sipoNextLogic
        if (~n_rst) begin
            atfif.adc_valid <= 1'b0;
            atfif.adc_data_out <= '0;
            shift <= '0;
            count <= '0;
        end
        else if (next_count == 5'd24) begin
            atfif.adc_valid <= 1'b1;
            atfif.adc_data_out  <= {~next_shift[DW-1], next_shift[DW-2:0]}; // ~MSB to unbias to -2.5V-2.5V range
            shift <= next_shift;
            count <= next_count;
        end
        else if (new_frame) begin
            atfif.adc_valid <= 1'b0;
            atfif.adc_data_out <= '0;
            shift <= '0;
            count <= '0;
        end
        else begin
            atfif.adc_valid <= 1'b0;
            atfif.adc_data_out <= '0;
            shift <= next_shift;
            count <= next_count;
        end
    end

    always_comb begin : sipoOutputLogic
        next_shift = shift;
        next_count = count;
        if (can_sample) begin
            next_shift = {shift[DW-2:0], ff2.data};
            if (count != 5'd31) next_count = count + 1;
        end
    end

endmodule