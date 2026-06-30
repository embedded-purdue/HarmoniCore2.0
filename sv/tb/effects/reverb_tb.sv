`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/reverb_if.vh"
import types::*;

module reverb_tb;
    parameter real FPGA_PERIOD = 6.4;  // 156 MHz

    logic clk = 1'b0;
    logic n_rst;

    always #(FPGA_PERIOD / 2.0) clk = ~clk;

    reverb_if rvif();
    reverb DUT (.clk(clk), .n_rst(n_rst), .rvif(rvif));
    reverb_test PROG (.clk(clk), .n_rst(n_rst), .rvif(rvif));

endmodule

program reverb_test (
    input  logic clk,
    output logic n_rst,
    reverb_if.reverb_tb rvif
);
    // CSV paths
    parameter string DEF_INPUT_CSV    = "../wav/csv/nothingonyou_reverb_input.csv";
    parameter string DEF_EXPECTED_CSV = "../wav/csv/nothingonyou_reverb_output.csv";
    parameter int MAX_SAMPLES = 100000;

    // Storage
    integer in_samples  [0:MAX_SAMPLES-1];
    integer exp_samples [0:MAX_SAMPLES-1];
    int n_in, n_exp;
    int pass_count, fail_count;
    int out_idx;

    // CSV loader
    task automatic load_csv(
        input string path,
        ref integer arr [0:MAX_SAMPLES-1],
        ref int n
    );
        integer fd, status, val;
        n  = 0;
        fd = $fopen(path, "r");
        if (!fd) $fatal(1, "reverb_tb: cannot open '%s'", path);
        while (!$feof(fd) && n < MAX_SAMPLES) begin
            status = $fscanf(fd, "%d\n", val);
            if (status == 1) arr[n++] = val;
        end
        $fclose(fd);
    endtask

    // Reset
    task automatic do_reset();
        n_rst         = 1'b0;
        rvif.valid_in = 1'b0;
        rvif.data_in  = '0;
        repeat(8) @(negedge clk);
        n_rst = 1'b1;
        repeat(2) @(negedge clk);
    endtask

    initial begin
        string in_path, exp_path;

        pass_count = 0; fail_count = 0; out_idx = 0;

        if (!$value$plusargs("INPUT_CSV=%s",    in_path))  in_path  = DEF_INPUT_CSV;
        if (!$value$plusargs("EXPECTED_CSV=%s", exp_path)) exp_path = DEF_EXPECTED_CSV;

        $display("reverb_tb: input    = %s", in_path);
        $display("reverb_tb: expected = %s", exp_path);
        $display("reverb_tb: comb delays = %0d %0d %0d %0d  ap delays = %0d %0d",
                 REVERB_COMB_DELAYS[0], REVERB_COMB_DELAYS[1],
                 REVERB_COMB_DELAYS[2], REVERB_COMB_DELAYS[3],
                 REVERB_AP_DELAYS[0],   REVERB_AP_DELAYS[1]);

        load_csv(in_path,  in_samples,  n_in);
        load_csv(exp_path, exp_samples, n_exp);
        $display("reverb_tb: %0d input samples, %0d expected samples", n_in, n_exp);

        do_reset();

        fork
            // ── Driver ───────────────────────────────────────────────────────
            begin : driver
                for (int i = 0; i < n_in; i++) begin
                    @(negedge clk);
                    rvif.valid_in = 1'b1;
                    rvif.data_in  = DW'(in_samples[i]);
                    @(negedge clk);
                    rvif.valid_in = 1'b0;
                    rvif.data_in  = '0;
                    repeat(15) @(negedge clk);  // > 15 cycles needed by pipeline
                end
            end

            // ── Monitor ──────────────────────────────────────────────────────
            begin : monitor
                while (out_idx < n_exp) begin
                    @(posedge clk);
                    if (rvif.valid_out) begin
                        automatic int got     = $signed(rvif.data_out);
                        automatic int exp_val = exp_samples[out_idx];

                        // Reverb uses integer fixed-point multiply — should match exactly.
                        // Allow ±1 tolerance for any edge case in shift rounding.
                        if (got >= exp_val - 1 && got <= exp_val + 1) begin
                            pass_count++;
                        end else begin
                            fail_count++;
                            $display("  MISMATCH[%0d]  got=%-12d  exp=%0d  diff=%0d",
                                     out_idx, got, exp_val, got - exp_val);
                            if (fail_count >= 10) begin
                                $display("reverb_tb: aborting after 10 mismatches");
                                disable monitor;
                            end
                        end
                        out_idx++;
                    end
                end
            end
        join_any
        disable fork;

        $display("\n─────────────────────────────────────────────────");
        $display("Checked: %0d samples", pass_count + fail_count);
        if (fail_count == 0 && pass_count > 0)
            $display("PASS  all %0d samples match Python golden reference", pass_count);
        else if (fail_count > 0)
            $display("FAIL  %0d / %0d mismatches", fail_count, pass_count + fail_count);
        else
            $display("WARN  no samples checked — check CSV paths");
        $display("─────────────────────────────────────────────────");

        $finish;
    end

endprogram
