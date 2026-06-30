
`timescale 1ns / 10ps
module top_test_pll
(
    input logic fpga_clk,
    output logic adc_mclk,
    output logic dac_mclk,
    output logic test_pin // probe P15
);
    logic sys_clk;
    mmcm u_mmcm (.clk_24_5(adc_mclk), .clk_50(dac_mclk), .clk_156(sys_clk), .clk_in(fpga_clk), .reset(1'b0), .locked(test_pin));
    
endmodule