`timescale 1ns/1ps

module tb_half_adder;

    logic A, B;
    logic Sum, Carry;

    logic expected_Sum, expected_Carry;

    int total_passed = 0;
    int total_failed = 0;

    // Instantiate DUT
    half_adder DUT (
        .A     (A),
        .B     (B),
        .Sum   (Sum),
        .Carry (Carry)
    );

    initial begin
        $display("🔷 Starting Half Adder Testbench");

        // Loop through all input combinations
        for (int i = 0; i < 4; i++) begin
            {A, B} = i[1:0];
            #10;  // wait for outputs to settle

            calculate_expected(A, B, expected_Sum, expected_Carry);
            compare("Sum", expected_Sum, Sum);
            compare("Carry", expected_Carry, Carry);
        end

        report();
        $display(" Testbench completed.");
        $finish;
    end

    // Task to calculate expected outputs
    task automatic calculate_expected(
        input  logic A,
        input  logic B,
        output logic expected_Sum,
        output logic expected_Carry
    );
        expected_Sum   = A ^ B;
        expected_Carry = A & B;
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(
        input string signal_name,
        input logic expected,
        input logic actual
    );
        if (expected !== actual) begin
            $display("  Mismatch: %s: Expected=%b, Got=%b [A=%b, B=%b]", signal_name, expected, actual, A, B);
            total_failed++;
        end else begin
            $display("  Match: %s=%b [A=%b, B=%b]", signal_name, actual, A, B);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display("  All tests passed successfully!");
        else
            $display("  Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
