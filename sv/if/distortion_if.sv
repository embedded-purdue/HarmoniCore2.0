interface distortion_if;
    logic clk;
    logic n_rst;
    logic signed [23:0] y_in;
    logic signed [23:0] out;

    modport src_input (
        input clk,
        input n_rst,
        input y_in
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
        output y_in
    );
endinterface

`endif
