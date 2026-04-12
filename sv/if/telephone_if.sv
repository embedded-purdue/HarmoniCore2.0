interface telephone_if 
(
    input logic clk,
    input logic n_rst,
    input logic signed [23:0] y_in, 
    input logic sample_en,

    output logic signed [23:0] out     
);

modport dut (
    input clk,
    input n_rst,
    input y_in,
    input sample_en,
    output out
);

endinterface