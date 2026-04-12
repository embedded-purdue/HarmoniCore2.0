interface vibrato_if #(
    parameter int SAMPLE_W = 18
);
    logic clk;
    logic n_rst;
    logic data_valid;
    logic signed [SAMPLE_W-1:0] data_in;
    logic out_valid;
    logic signed [SAMPLE_W-1:0] data_out;

    modport src_input (
        input clk,
        input n_rst,
        input data_valid,
        input data_in
    );

    modport src_output (
        output out_valid,
        output data_out
    );

    modport tb_input (
        input out_valid,
        input data_out
    );

    modport tb_output (
        output clk,
        output n_rst,
        output data_valid,
        output data_in
    );
endinterface

`endif
