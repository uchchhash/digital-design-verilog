`timescale 1ns/1ps

module tb_votes;

    logic A, B, C, D;
    logic Y;

    logic expected_Y;
    int   total_passed = 0;
    int   total_failed = 0;

    // Instantiate DUT Not Reduced Majority Voter
//    votes DUT (
//        .A (A),
//        .B (B),
//        .C (C),
//        .D (D),
//        .Y (Y)
//    );

     // Instantiate DUT Reduced Majority Voter
     votes_reduced DUT (
         .A (A),
         .B (B),
         .C (C),
         .D (D),
         .Y (Y)
     );


    initial begin
        $display("Starting 4-Input Majority Voter Testbench");

        // Loop through all input combinations
        for (int i = 0; i < 16; i++) begin
            {A, B, C, D} = i;
            #10;
            calculate_expected(A, B, C, D, expected_Y);
            compare(expected_Y, Y);
        end

        report();
        $display("Testbench completed.");
        $finish();
    end

    // Task to calculate expected output
    task automatic calculate_expected(
        input  logic A,
        input  logic B,
        input  logic C,
        input  logic D,
        output logic expected_Y
    );
        int count = A + B + C + D;
        expected_Y = (count >= 3) ? 1'b1 : 1'b0;
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(input logic expected_Y, input logic actual_Y);
        if (expected_Y !== actual_Y) begin
            $display(" Mismatch: Expected=%b, Got=%b [A=%b B=%b C=%b D=%b]", expected_Y, actual_Y, A, B, C, D);
            total_failed++;
        end else begin
            $display(" Match: Output=%b [A=%b B=%b C=%b D=%b]", actual_Y, A, B, C, D);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display(" All tests passed successfully!");
        else
            $display(" Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
