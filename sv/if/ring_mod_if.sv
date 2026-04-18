interface ring_mod_if;
    logic clk;
    logic n_rst;
    logic signed [23:0] sample_in;
    logic valid;
    logic signed [23:0] out;

    modport src_input (
        input clk,
        input n_rst,
        input sample_in,
        input valid
    );

    modport src_output (
        output out
    );

    modport tb_input (
        input out
    );

    modport tb_output (
        output clk,
        output n_rst,
        output sample_in,
        output valid
    );
endinterface

`endif
