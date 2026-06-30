
`timescale 1ns / 10ps
`include "../../include/types.sv"
`include "../../include/effects/ring_mod_if.vh"
import types::*;

module ring_mod_tb;
    parameter real FPGA_PERIOD = 6.4;  // 156 MHz

    logic clk = 1'b0;
    logic n_rst;

    always #(FPGA_PERIOD / 2.0) clk = ~clk;

    ring_mod_if rmif();
    ring_mod DUT (.clk(clk), .n_rst(n_rst), .rmif(rmif));
    ring_mod_test PROG (.clk(clk), .n_rst(n_rst), .rmif(rmif));

endmodule

program ring_mod_test (
    input  logic clk,
    output logic n_rst,
    ring_mod_if.ring_mod_tb rmif
);
    // CSV paths (relative to sv/ — where make is invoked from).
    parameter string DEF_INPUT_CSV    = "../wav/csv/nothingonyou_input.csv";
    parameter string DEF_EXPECTED_CSV = "../wav/csv/nothingonyou_output.csv";

    // Number of samples to verify.
    parameter int MAX_SAMPLES = 100000;

    // Storage 
    integer in_samples  [0:MAX_SAMPLES-1];
    integer exp_samples [0:MAX_SAMPLES-1];
    int n_in, n_exp;
    int pass_count, fail_count;

    // CSV loader
    task automatic load_csv(
        input string path,
        ref integer arr [0:MAX_SAMPLES-1],
        ref int n
    );
        integer fd, status, val;
        n  = 0;
        fd = $fopen(path, "r");
        if (!fd) $fatal(1, "ring_mod_tb: cannot open '%s'", path);
        while (!$feof(fd) && n < MAX_SAMPLES) begin
            status = $fscanf(fd, "%d\n", val);
            if (status == 1) arr[n++] = val;
        end
        $fclose(fd);
    endtask

    initial begin
        string in_path, exp_path;

        if (!$value$plusargs("INPUT_CSV=%s",    in_path))  in_path  = DEF_INPUT_CSV;
        if (!$value$plusargs("EXPECTED_CSV=%s", exp_path)) exp_path = DEF_EXPECTED_CSV;

        $display("ring_mod_tb: input    = %s", in_path);
        $display("ring_mod_tb: expected = %s", exp_path);

        load_csv(in_path,  in_samples,  n_in);
        load_csv(exp_path, exp_samples, n_exp);

        $display("ring_mod_tb: %0d input samples, %0d expected samples", n_in, n_exp);

        n_rst         = 1'b0;
        rmif.valid_in = 1'b0;
        rmif.data_in  = '0;
        repeat(4) @(negedge clk);
        n_rst = 1'b1;
        repeat(2) @(negedge clk);

        pass_count = 0;
        fail_count = 0;

        // Output = Input + 3 cycle latency
        fork
            // Input driver
            begin : driver
                for (int j = 0; j < n_in + 3; j++) begin
                    @(negedge clk);
                    if (j < n_in) begin
                        rmif.data_in  = DW'(in_samples[j]);
                        rmif.valid_in = 1'b1;
                    end else begin
                        rmif.valid_in = 1'b0;
                    end
                end
            end

            // Output chk
            begin : chk
                for (int j = 0; j < n_in + 3; j++) begin
                    @(negedge clk);
                    if (j >= 3 && rmif.valid_out) begin
                        automatic int idx     = j - 3;
                        automatic int got     = $signed(rmif.data_out);
                        automatic int exp_val = exp_samples[idx];
                        if (idx < n_exp) begin
                            if (got >= exp_val - 1 && got <= exp_val + 1) begin
                                pass_count++;
                            end else begin
                                fail_count++;
                                $display("  MISMATCH[%0d]  got=%-12d  exp=%0d  diff=%0d",
                                         idx, got, exp_val, got - exp_val);
                                if (fail_count >= 10) begin
                                    $display("ring_mod_tb: aborting after 10 mismatches");
                                    disable chk;
                                end
                            end
                        end
                    end
                end
            end

        join

        // Results
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
