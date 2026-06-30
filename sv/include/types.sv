`timescale 1ns / 1ps

`ifndef TYPES
`define TYPES

package types;
    localparam SR = 48000; // ADC sampling rate
    localparam DW = 24; // ADC data width
    localparam MULT_DW = 18; // all other data widths (DSP Slices are 25x18)
    localparam DAC_DW = 16; // DAC data width

    // RING MOD PARAMETERS
    localparam int CARRIER_FREQ = 256; // Hz
    localparam int LUT_BITS = 6; // 64-entry quarter-wave LUT
    localparam int LUT_SIZE = 1 << LUT_BITS; // 64
    localparam int PHASE_BITS = 32; // phase accumulator width
    localparam longint PHASE_INC = longint'((2.0 ** PHASE_BITS) * CARRIER_FREQ / SR); // 22_906_492

    // Sine LUT precision — tied to DSP48E1 B-input (18-bit)
    localparam int SIN_BITS  = MULT_DW;                    // 18
    localparam int SIN_SHIFT = SIN_BITS - 1;               // 17
    localparam int SIN_MAX   = (1 << (SIN_BITS - 1)) - 1; // 131_071

    // Saturation bounds for DW-bit signed audio
    localparam int SAT_MAX =  (1 << (DW - 1)) - 1;  //  8_388_607
    localparam int SAT_MIN = -(1 << (DW - 1));       // -8_388_608

    // VIBRATO PARAMETERS
    localparam int     VIB_RATE_HZ    = 7;
    localparam longint VIB_PHASE_INC  = longint'((2.0 ** PHASE_BITS) * VIB_RATE_HZ / SR); // 625_491
    localparam int     VIB_DEPTH_SAMP = 48;   // 1 ms @ 48 kHz
    localparam int     VIB_BASE_DELAY = 96;   // 2 ms @ 48 kHz
    localparam int     VIB_BUF_LEN    = 256;  // power-of-2 so addr wraps free

    // REVERB PARAMETERS
    localparam int REVERB_COMB_DELAYS [4]  = '{1901, 2011, 1723, 1451}; // samples, all prime
    localparam int REVERB_AP_DELAYS   [2]  = '{251, 127};
    localparam int REVERB_GAIN_SHIFT       = 10;    // denominator = 2^10 = 1024
    localparam int REVERB_COMB_GAIN_NUM    = 922;   // 922/1024 ≈ 0.90
    localparam int REVERB_AP_GAIN_NUM      = 819;   // 819/1024 ≈ 0.80
    localparam int REVERB_WET_NUM          = 768;   // 768/1024 = 0.75 (exact)
    localparam int REVERB_DRY_NUM          = 256;   // 256/1024 = 0.25 (exact)
    localparam int REVERB_COMB_ADDR_W      = 11;    // ceil(log2(2011))
    localparam int REVERB_AP_ADDR_W        = 8;     // ceil(log2(251))

    // ECHO PARAMETERS
    localparam int ECHO_DELAY_MS       = 300;   // ms between echoes
    localparam int ECHO_DELAY_SAMP     = 14400; // DELAY_MS * SR / 1000
    localparam int ECHO_FEEDBACK_SHIFT = 1;     // each echo = previous >>> 1 (50%)
    localparam int ECHO_ADDR_W         = 14;    // ceil(log2(14400)) — address width

endpackage

`endif 