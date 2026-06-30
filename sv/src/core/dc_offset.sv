
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/core/dc_offset_if.vh"

// Two-stage pipeline to meet 156 MHz timing.
//
// Stage 1 (comb → reg):  diff = adc_data - mean
//                         temp = diff[24:10]  (with ±1 floor)
//                         next_mean = mean + temp
//                         → registers: mean, p1_next_mean, p1_adc_data, p1_valid
//
// Stage 2 (comb → reg):  dc_data = p1_adc_data - p1_next_mean
//                         → registers: dcif.dc_data, dcif.dc_valid
//
// Net effect is identical to the original single-stage version, shifted by 1 cycle.

module dc_offset
import types::*;
(
    input logic fpga_clk, n_rst,
    dc_offset_if.dc_offset dcif
);
    logic signed [DW-1:0] mean, next_mean;
    logic signed [DW:0]   diff;
    logic signed [14:0]   temp;

    // Stage 1 → stage 2 pipeline registers
    logic signed [DW-1:0] p1_adc_data, p1_next_mean;
    logic                  p1_valid;

    // Stage 1: purely combinational
    always_comb begin
        diff      = '0;
        temp      = '0;
        next_mean = mean;

        if (dcif.adc_valid) begin
            diff = dcif.adc_data - mean;
            temp = diff[24:10];

            if      (temp == '0 && diff > 0) temp = 15'b1;
            else if (temp == '0 && diff < 0) temp = '1;

            next_mean = mean + temp;
        end
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin
        if (~n_rst) begin
            mean          <= '0;
            p1_adc_data   <= '0;
            p1_next_mean  <= '0;
            p1_valid      <= '0;
            dcif.dc_data  <= '0;
            dcif.dc_valid <= '0;
        end else begin
            // Stage 1 → register next_mean and delay input for stage 2
            mean         <= next_mean;
            p1_adc_data  <= dcif.adc_data;
            p1_next_mean <= next_mean;
            p1_valid     <= dcif.adc_valid;

            // Stage 2 → subtract registered next_mean from delayed adc_data
            dcif.dc_data  <= p1_adc_data - p1_next_mean;
            dcif.dc_valid <= p1_valid;
        end
    end

endmodule
