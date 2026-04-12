    // System Signals
    input  logic       clk,
    input  logic       n_rst,
    
    // Control Signals
    input  logic       i2c_en,
    input  logic [6:0] slave_addr,    // 7-bit I2C address (0x18 for DAC)
    input  logic [7:0] reg_addr,      // Register to write
    input  logic [7:0] data_in,       // Data to write
    output logic       busy,
    output logic       ack_error,     // High if any NACK received
    
    // I2C bus
    inout  wire        sda,           // Bidirectional data line
    output logic       scl