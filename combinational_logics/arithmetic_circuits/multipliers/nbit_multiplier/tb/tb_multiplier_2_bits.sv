
`timescale 1ns/1ps

module tb_multiplier_2_bits;

    logic [1:0] a, b;
    logic [3:0] p;

    logic [3:0] expected_p;

    int total_passed = 0;
    int total_failed = 0;

    // Instantiate DUT
    multiplier_2_bits DUT (
        .a (a),
        .b (b),
        .p (p)
    );

    initial begin
        $display("🔷 Starting 2×2 Multiplier Testbench");

        // Loop through all input combinations
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 4; j++) begin
                a = i[1:0];
                b = j[1:0];
                #5;  // wait for outputs to settle

                calculate_expected(a, b, expected_p);
                compare("Product", expected_p, p);
            end
        end

        report();
        $display(" Testbench completed.");
        $finish;
    end

    // Task to calculate expected output
    task automatic calculate_expected(
        input  logic [1:0] a,
        input  logic [1:0] b,
        output logic [3:0] expected_p
    );
        expected_p = a * b;
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(
        input string signal_name,
        input logic [3:0] expected,
        input logic [3:0] actual
    );
        if (expected !== actual) begin
            $display("  ❌ Mismatch: %s: Expected=%0d, Got=%0d [a=%0d, b=%0d]", signal_name, expected, actual, a, b);
            total_failed++;
        end else begin
            $display("  ✅ Match: %s=%0d [a=%0d, b=%0d]", signal_name, actual, a, b);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display("  🎉 All tests passed successfully!");
        else
            $display("  ⚠️ Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
