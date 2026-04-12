
`timescale 1ns / 10ps
module top_test_pll
(
    input logic fpga_clk,
    output logic adc_mclk,
    output logic dac_mclk,
    output logic sys_clk,
    output logic output_led
);
    mmcm u_mmcm (.clk_24_5(adc_mclk), .clk_50(dac_mclk), .clk_156(sys_clk), .clk_in(fpga_clk), .reset(1'b0), .locked(output_led));
    
endmodule