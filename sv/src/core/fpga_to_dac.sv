
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/core/fpga_to_dac_if.vh"

module fpga_to_dac
import types::*;
(
    input logic fpga_clk, n_rst,
    fpga_to_dac_if.fpga_to_dac ftdif
);
    // declare vars
    typedef struct packed {
        logic f_clk;
        logic b_clk;
    } dac_sync;
    dac_sync ff1, ff2, ff3;

    logic new_frame, can_send;
    logic [DAC_DW-1:0] shift, next_shift, data_reg;
    logic [4:0] count, next_count;

    // ************************************************************************
    // START THE CODE
    // ************************************************************************

    always_comb begin : assignFF1
        ff1.f_clk = ftdif.dac_fclk;
        ff1.b_clk = ftdif.dac_bclk;
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : FF1_TO_FF2
        if (~n_rst) ff2 <= '0;
        else           ff2 <= ff1;
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : FF2_TO_FF3
        if (~n_rst) ff3 <= '0;
        else           ff3 <= ff2;
    end

    // rising edge detection
    assign new_frame = ff2.f_clk & ~ff3.f_clk;
    assign can_send = ff2.b_clk & ~ff3.b_clk;

    always_ff @(posedge fpga_clk, negedge n_rst) begin : holdValidData
        if (~n_rst)              data_reg <= '0;
        else if (ftdif.audio_valid) data_reg <= ftdif.audio_data[DW-1:DW-DAC_DW];
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : pisoNextLogic
        if (~n_rst) begin
            shift <= '0;
            count <= '0;
        end
        else if (new_frame) begin
            shift <= data_reg;
            count <= '0;
        end
        else if (next_count == 5'd16) begin
            shift <= data_reg;
            count <= '0;
        end
        else begin
            shift <= next_shift;
            count <= next_count;
        end
    end

    always_comb begin : pisoOutputLogic
        next_shift = shift;
        next_count = count;
        if (can_send) begin
            next_shift = {shift[DAC_DW-2:0], 1'b0};
            next_count = count + 1;
        end
    end

    always_ff @(posedge fpga_clk, negedge n_rst) begin : dacSerialOut
        if (~n_rst) ftdif.dac_data_out <= 1'b0;
        else           ftdif.dac_data_out <= shift[DAC_DW-1];
    end

endmodule