
`timescale 1ns/1ps

`ifndef ADC_FPGA_CDC_IF
`define ADC_FPGA_CDC_IF

`include "../include/types.sv"
import types::*;

interface adc_fpga_cdc_if;

    logic [DW-1:0] adc_data, fifo_data;
    logic adc_valid, fifo_valid, counter_flag;

    modport adc_fpga_cdc (
        input adc_data, adc_valid, counter_flag,
        output fifo_data, fifo_valid
    );

    modport adc_fpga_cdc_tb (
        input fifo_data, fifo_valid,
        output adc_data, adc_valid, counter_flag
    );
    
endinterface

`endif