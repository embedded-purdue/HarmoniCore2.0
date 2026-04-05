module vibrato_core #(
    parameter int SAMPLE_W = 18,
    parameter int ADDR_W   = 8,
    parameter int FRAC_W   = 15,
    parameter int PTR_W    = 24,
    parameter int BUF_LEN  = 256,

    // Q9.15 delay constants for sr=44100, base_delay_ms=2.0, depth_ms=1.0
    parameter logic signed [PTR_W-1:0] BASE_DELAY_Q = 24'sd2890138,
    parameter logic signed [PTR_W-1:0] DEPTH_Q      = 24'sd1445069
)(
    input  logic                        clk,
    input  logic                        n_rst,

    input  logic                        data_valid,
    input  logic signed [SAMPLE_W-1:0]  data_in,

    output logic                        out_valid,
    output logic signed [SAMPLE_W-1:0]  data_out
);

    localparam logic signed [PTR_W-1:0] BUF_LEN_Q = (BUF_LEN <<< FRAC_W);

    typedef enum logic [2:0] {
        S_IDLE,
        S_WRITE,
        S_CALC_DELAY,
        S_READ_I0_ADDR,
        S_CAPTURE_I0_AND_READ_I1,
        S_CAPTURE_I1_AND_INTERP,
        S_OUTPUT
    } state_t;

    state_t state, next_state;

    // -----------------------------
    // Pointer / delay math signals
    // -----------------------------
    logic [ADDR_W-1:0] wr_ptr;

    logic signed [PTR_W-1:0] wr_ptr_q;
    logic signed [PTR_W-1:0] delay_q;
    logic signed [PTR_W-1:0] rd_ptr_q;

    logic [ADDR_W-1:0] i0_addr, i1_addr;
    logic [FRAC_W-1:0] frac;

    // -----------------------------
    // Ring mod signals
    // -----------------------------
    logic signed [17:0] ring_mod_out;
    logic               ring_mod_valid;
    logic signed [41:0] delay_mod_mult;   // DEPTH_Q * ring_mod_out
    logic signed [PTR_W-1:0] delay_mod_q;

    // -----------------------------
    // BRAM interface signals
    // Port A = write port
    // Port B = read port
    // -----------------------------
    logic [ADDR_W-1:0] bram_addra, bram_addrb;
    logic              bram_ena, bram_enb;
    logic              bram_wea, bram_web;
    logic signed [SAMPLE_W-1:0] bram_dina, bram_dinb;
    logic signed [SAMPLE_W-1:0] bram_douta, bram_doutb;

    // -----------------------------
    // Sample datapath registers
    // -----------------------------
    logic signed [SAMPLE_W-1:0] data_in_r;
    logic signed [SAMPLE_W-1:0] sample_i0, sample_i1;

    logic signed [SAMPLE_W:0]          diff;
    logic signed [SAMPLE_W+FRAC_W:0]   interp_mult;
    logic signed [SAMPLE_W+1:0]        interp_sum;

    // -----------------------------
    // Ring mod instantiation
    // For vibrato, sample_in is constant 1.0 in Q1.17
    // so output is just the oscillator waveform in [-1, 1)
    // -----------------------------
    ring_mod #(
        .acc_in(16'd27968)
    ) u_ring_mod (
        .clk      (clk),
        .n_rst    (n_rst),
        .sample_in(18'sd131072), // 1.0 in Q1.17 = 1 << 17
        .valid    (ring_mod_valid),
        .out      (ring_mod_out)
    );

    // -----------------------------
    // Dual-port BRAM instantiation
    // Port A: write current sample
    // Port B: read i0 / i1 across successive cycles
    // -----------------------------
    dual_port_bram u_delay_bram (
        .clka  (clk),
        .ena   (bram_ena),
        .wea   (bram_wea),
        .addra (bram_addra),
        .dina  (bram_dina),
        .douta (bram_douta),

        .clkb  (clk),
        .enb   (bram_enb),
        .web   (bram_web),
        .addrb (bram_addrb),
        .dinb  (bram_dinb),
        .doutb (bram_doutb)
    );

    // -----------------------------
    // State register
    // -----------------------------
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // -----------------------------
    // Main sequential registers
    // -----------------------------
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            wr_ptr     <= '0;
            data_in_r  <= '0;
            sample_i0  <= '0;
            sample_i1  <= '0;
            data_out   <= '0;
            out_valid  <= 1'b0;
        end else begin
            out_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (data_valid)
                        data_in_r <= data_in;
                end

                S_CAPTURE_I0_AND_READ_I1: begin
                    sample_i0 <= bram_doutb;
                end

                S_CAPTURE_I1_AND_INTERP: begin
                    sample_i1 <= bram_doutb;
                end

                S_OUTPUT: begin
                    data_out  <= interp_sum[SAMPLE_W-1:0];
                    out_valid <= 1'b1;

                    if (wr_ptr == BUF_LEN-1)
                        wr_ptr <= '0;
                    else
                        wr_ptr <= wr_ptr + 1'b1;
                end

                default: ;
            endcase
        end
    end

    // -----------------------------
    // Fixed-point / address math
    // -----------------------------
    always_comb begin
        // Convert integer write pointer to Q9.15
        wr_ptr_q = $signed({1'b0, wr_ptr, {FRAC_W{1'b0}}});

        // depth_q9.15 * ring_mod_out_q1.17 -> shift right by 17 => q9.15
        delay_mod_mult = DEPTH_Q * ring_mod_out;
        delay_mod_q    = delay_mod_mult >>> 17;

        // delay = base_delay + depth*lfo
        delay_q = BASE_DELAY_Q + delay_mod_q;

        // rd_ptr = wr_ptr - delay
        rd_ptr_q = wr_ptr_q - delay_q;

        // Wrap if negative
        if (rd_ptr_q < 0)
            rd_ptr_q = rd_ptr_q + BUF_LEN_Q;

        // Extract floor and frac from wrapped read pointer
        i0_addr = rd_ptr_q[FRAC_W +: ADDR_W];
        frac    = rd_ptr_q[FRAC_W-1:0];

        // Explicit wrap for i1
        if (i0_addr == BUF_LEN-1)
            i1_addr = '0;
        else
            i1_addr = i0_addr + 1'b1;

        // Interpolation form agreed on:
        // diff   = i1 - i0
        // interp = i0 + frac * diff
        diff        = sample_i1 - sample_i0;
        interp_mult = diff * $signed({1'b0, frac});
        interp_sum  = sample_i0 + (interp_mult >>> FRAC_W);
    end

    // -----------------------------
    // Control logic
    // -----------------------------
    always_comb begin
        next_state = state;

        // defaults
        ring_mod_valid = 1'b0;

        // BRAM defaults
        bram_ena   = 1'b0;
        bram_wea   = 1'b0;
        bram_addra = wr_ptr;
        bram_dina  = data_in_r;

        bram_enb   = 1'b0;
        bram_web   = 1'b0;
        bram_addrb = i0_addr;
        bram_dinb  = '0;

        case (state)
            S_IDLE: begin
                if (data_valid) begin
                    ring_mod_valid = 1'b1;   // advance ring mod once per sample
                    next_state     = S_WRITE;
                end
            end

            S_WRITE: begin
                // write current input sample into circular buffer
                bram_ena   = 1'b1;
                bram_wea   = 1'b1;
                bram_addra = wr_ptr;
                bram_dina  = data_in_r;

                next_state = S_CALC_DELAY;
            end

            S_CALC_DELAY: begin
                // put i0 address on BRAM read port
                bram_enb   = 1'b1;
                bram_addrb = i0_addr;

                next_state = S_READ_I0_ADDR;
            end

            S_READ_I0_ADDR: begin
                // allow synchronous BRAM read latency to occur
                bram_enb   = 1'b1;
                bram_addrb = i0_addr;

                next_state = S_CAPTURE_I0_AND_READ_I1;
            end

            S_CAPTURE_I0_AND_READ_I1: begin
                // capture i0, then request i1
                bram_enb   = 1'b1;
                bram_addrb = i1_addr;

                next_state = S_CAPTURE_I1_AND_INTERP;
            end

            S_CAPTURE_I1_AND_INTERP: begin
                // capture i1; interpolation math is combinational from regs
                next_state = S_OUTPUT;
            end

            S_OUTPUT: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule